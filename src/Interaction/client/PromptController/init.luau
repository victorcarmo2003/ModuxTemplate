--!strict
--[[
	PromptController (TASK-014, FEAT-005; DEC-066 port of AnimalPlane `ProximityPromptController`)

	Every `Interactable` anchor in the Workspace gets a Prompt (billboard under PlayerGui). At 10 Hz the
	controller picks the target: the live prompt within `Content.Actions[...].Radius` of the character that is
	closest to the screen centre, with hysteresis so two neighbours do not flicker. Only the target shows the
	pill ("Prompt"); other candidates show the dot ("Indicator"); one pill at a time.

	Input: while there is a target, one InputController binding "Interact" is live: E (PC), ButtonX (gamepad) and
	a fixed touch button near jump (mobile). Tapping the pill also works. Tap actions fire on press; hold actions
	fire only if held for the whole `PromptHold`/`Actions.Hold` (releasing early sends nothing).

	The client only presents: it fires `Interact{Id, Action}` and the server decides (InteractionService
	revalidates range, hand, stock and state). Nothing is applied locally.

	Wave 2 (TASK-078, architecture.md §19.7-§19.8): actions show up to `RunParams.BindingWave`; no prompt while
	`Vitals[me].State` is not Active; anchors on the local character (own `Prompt_Give`) are never candidates;
	`PromptText` changes ("Take Coffee") update the pill live and cancel a hold in progress; `give_coffee` is
	pre-checked against the mate's state and equipped Tool.

	Sound (user request 2026-10-10): `prompt_hold` (Ui) plays on screen while a hold is in progress and stops when it
	ends (released, cancelled or fired). `trash` (user request 2026-10-10) plays at the bin once a fired `discard`
	actually took the hand Tool away (the server decided; no Tool gone within DISCARD_WAIT s = rejected = silence).

	Completion pop (user request 2026-10-11): the moment an Interact is actually sent (hold completed or tap), the
	pill pops (Prompt.Celebrate -> PromptBillboard bump/flash/check), a few sparkles burst at the anchor (Burst) and
	`prompt_done` (Ui) plays. It confirms the input, not the result: the server still decides.
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Prompt = require(script.Prompt)
local Rules = require(script.Rules)
local Burst = require(script.Burst)

const TAG = "Interactable"
const TICK_RATE = 10
const MAX_SCREEN_DISTANCE_FRACTION = 0.35
const HYSTERESIS_MARGIN_FRACTION = 0.05
const BIND_NAME = "Interact"
-- Client-side floor between two Interact (network.md §4.1: <= 8/s); the server drops the excess anyway.
const MIN_FIRE_INTERVAL = 1 / 8
const TOUCH_SIZE = 72
const KEY_LABEL = { KeyboardMouse = "E", Gamepad = "X", Touch = "" }
const HOLD_SOUND = "prompt_hold"
const DONE_SOUND = "prompt_done"
const DISCARD_ACTION = "discard"
const DISCARD_SOUND = "trash"
const DISCARD_WAIT = 1.5 -- s for the server to remove the thrown Tool

const PromptController = Modux.Controller(
	"PromptController",
	{ Require = { "InputController", "RoundController", "AudioController" }, Priority = 620 }
)

function PromptController:Setup()
	self.Prompts = {} :: { [Instance]: Prompt.Prompt }
	self.Target = nil :: Prompt.Prompt?
	self.Holding = nil :: Prompt.Prompt?
	self.HoldThread = nil :: thread?
	self.HoldSound = nil :: Sound?
	self.LastFire = 0 :: number
	self.Gui = nil :: Instance?
end

function PromptController:Add(anchor: Instance)
	-- Anchors outside the Workspace (pooled rigs, kits) are kept but never live (Prompt.IsLive, §18.0 rule 5).
	if self.Prompts[anchor] then
		return
	end
	const gui = self.Gui
	if gui == nil then
		return
	end
	const input = self.Dependencies.InputController
	self.Prompts[anchor] = Prompt.new(anchor, {
		Parent = gui,
		KeyLabel = function()
			return KEY_LABEL[input.Device()]
		end,
		Tappable = function()
			return input.Device() == "Touch"
		end,
		OnPress = function(prompt)
			self:BeginHold(prompt)
		end,
		OnRelease = function(_prompt)
			self:EndHold()
		end,
	})
end

function PromptController:Remove(anchor: Instance)
	const prompt = self.Prompts[anchor]
	if prompt == nil then
		return
	end
	if prompt == self.Target then
		self:SetTarget(nil)
	end
	self.Prompts[anchor] = nil
	Prompt.Destroy(prompt)
end

function PromptController:Fire(prompt: Prompt.Prompt)
	const id = prompt.Id
	const action = prompt.Target.Action
	-- fireServer is typed `any`: keep the payload inside the schema (Id int 1..65535, Action in Content.Actions).
	if id == nil or id < 1 or id > 65535 or id % 1 ~= 0 or Content.Actions.ByKey[action] == nil then
		return
	end
	const now = os.clock()
	if now - self.LastFire < MIN_FIRE_INTERVAL then
		return
	end
	self.LastFire = now
	self.Libs.Net.Interact:fireServer({ Id = id, Action = action })
	self:Celebrate(prompt)
	if action == DISCARD_ACTION then
		self:WatchDiscard(prompt.Anchor)
	end
end

-- Completion feedback, in the same frame as the fire.
function PromptController:Celebrate(prompt: Prompt.Prompt)
	Prompt.Celebrate(prompt)
	const position = Prompt.Position(prompt)
	if position then
		Burst.Emit(position)
	end
	self.Dependencies.AudioController:Play(DONE_SOUND)
end

-- `trash` at the bin when the server removes the Tool the local character held (Throw Away accepted)
function PromptController:WatchDiscard(anchor: Instance)
	const character = Players.LocalPlayer.Character
	const tool = if character then character:FindFirstChildOfClass("Tool") else nil
	if character == nil or tool == nil then
		return
	end
	local connection: RBXScriptConnection? = nil
	const timeout = task.delay(DISCARD_WAIT, function()
		if connection then
			connection:Disconnect()
		end
	end)
	connection = tool.AncestryChanged:Connect(function()
		if tool:IsDescendantOf(character) then
			return
		end
		if connection then
			connection:Disconnect()
		end
		if coroutine.status(timeout) == "suspended" then
			task.cancel(timeout)
		end
		-- moved to the Backpack = unequipped, not thrown
		const backpack = Players.LocalPlayer:FindFirstChildOfClass("Backpack")
		if backpack and tool:IsDescendantOf(backpack) then
			return
		end
		self.Dependencies.AudioController:Play(DISCARD_SOUND, anchor)
	end)
end

function PromptController:CancelHold()
	const thread = self.HoldThread
	if thread then
		self.HoldThread = nil
		if coroutine.running() ~= thread then
			task.cancel(thread)
		end
	end
	const holding = self.Holding
	if holding then
		self.Holding = nil
		Prompt.SetHolding(holding, false)
	end
	const sound = self.HoldSound
	if sound then
		self.HoldSound = nil
		sound:Stop()
	end
end

function PromptController:BeginHold(prompt: Prompt.Prompt)
	if prompt ~= self.Target or self.Holding then
		return
	end

	if prompt.Hold <= 0 then
		self:Fire(prompt)
		return
	end

	self.Holding = prompt
	Prompt.SetHolding(prompt, true)
	self.HoldSound = self.Dependencies.AudioController:Play(HOLD_SOUND)
	const id, action, text = prompt.Id, prompt.Target.Action, prompt.Text()
	self.HoldThread = task.delay(prompt.Hold, function()
		self.HoldThread = nil
		-- Same target, same entity, action and text ("Brew Coffee" -> "Take Coffee"), still live: otherwise nothing
		-- is sent.
		const valid = self.Target == prompt
			and prompt.Id == id
			and prompt.Target.Action == action
			and prompt.Text() == text
			and Prompt.IsLive(prompt)
		-- Fire before clearing the hold, so the pill goes from full straight into the pop (no drain in between).
		if valid then
			self:Fire(prompt)
		end
		self:CancelHold()
	end)
end

-- Any release ends the hold in progress (the press may have come from another input).
function PromptController:EndHold()
	self:CancelHold()
end

function PromptController:SetTarget(prompt: Prompt.Prompt?)
	if prompt == self.Target then
		return
	end

	self:CancelHold()
	self.Target = prompt

	const input = self.Dependencies.InputController
	if prompt == nil then
		input:Unbind(BIND_NAME)
		return
	end

	if input.Handles[BIND_NAME] == nil then
		input
			:Bind({
				Name = BIND_NAME,
				Key = Enum.KeyCode.E,
				Keys = { Enum.KeyCode.ButtonX },
				TouchButton = true,
				Title = "Use",
				TouchSize = TOUCH_SIZE,
				Priority = Enum.ContextActionPriority.High.Value,
				Context = "Gameplay",
			})
			.OnPress(function()
				const target = self.Target
				if target then
					self:BeginHold(target)
				end
			end)
			.OnRelease(function()
				self:EndHold()
			end)
	end
end

function PromptController:HideAll()
	self:SetTarget(nil)
	for _, prompt in self.Prompts do
		Prompt.SetState(prompt, "Hidden")
	end
end

function PromptController:Held(character: Model): Rules.Held?
	const tool = character:FindFirstChildOfClass("Tool")
	if tool == nil then
		return nil
	end
	const item = tool:GetAttribute("Item")
	if typeof(item) ~= "string" then
		return nil
	end
	const toppings = tool:GetAttribute("Toppings")
	return {
		Item = item,
		Toppings = Rules.ParseToppings(if typeof(toppings) == "string" then toppings else nil),
	}
end

function PromptController:RulesContext(character: Model): Rules.Context
	const net = self.Libs.Net
	const round = self.Dependencies.RoundController
	return {
		Phase = round.Phase(),
		IsNight = round.IsNight(),
		SelfId = Players.LocalPlayer.UserId,
		Held = self:Held(character),
		Stock = function(ingredient: string): Rules.StockRecord?
			const index = Content.Ingredients.IndexOf[ingredient]
			return if index then net.Stock:get(index) else nil
		end,
		Slot = function(stationId: number, slot: number): Rules.SlotRecord?
			return net.Stations:get(stationId * 100 + slot)
		end,
		Customer = function(npcId: number): Rules.CustomerRecord?
			return net.Customers:get(npcId)
		end,
		Vital = function(userId: number): Rules.VitalRecord?
			return net.Vitals:get(userId)
		end,
		MemberHeld = function(userId: number): Rules.Held?
			const player = Players:GetPlayerByUserId(userId)
			const mate = if player then player.Character else nil
			return if mate then self:Held(mate) else nil
		end,
	}
end

function PromptController:Tick()
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	const camera = workspace.CurrentCamera
	if
		self.Dependencies.InputController.Context ~= "Gameplay"
		or character == nil
		or root == nil
		or not root:IsA("BasePart")
		or humanoid == nil
		or humanoid.Health <= 0
		or camera == nil
	then
		self:HideAll()
		return
	end

	const context = self:RulesContext(character)
	if not Rules.CanInteract(context) then
		self:HideAll()
		return
	end
	const viewport = camera.ViewportSize
	const center = viewport / 2
	const maxScreenDistance = viewport.Y * MAX_SCREEN_DISTANCE_FRACTION
	const margin = viewport.Y * HYSTERESIS_MARGIN_FRACTION

	const candidates: { [Prompt.Prompt]: number } = {}
	local best: Prompt.Prompt? = nil
	local bestDistance = math.huge

	for _, prompt in self.Prompts do
		if not Prompt.IsLive(prompt) or prompt.Anchor:IsDescendantOf(character) then
			continue
		end
		const position = Prompt.Position(prompt)
		if position == nil or (position - root.Position).Magnitude > prompt.Radius then
			continue
		end
		if not Rules.Allows(prompt.Target, context) then
			continue
		end
		const point, onScreen = camera:WorldToViewportPoint(position)
		if not onScreen then
			continue
		end
		const distance = (Vector2.new(point.X, point.Y) - center).Magnitude
		candidates[prompt] = distance
		if distance < bestDistance then
			bestDistance = distance
			best = prompt
		end
	end

	const current = self.Target
	const currentDistance = if current then candidates[current] else nil
	const bestInView = if best and bestDistance <= maxScreenDistance then best else nil
	if current == nil or currentDistance == nil then
		-- No target yet, or the target left range/screen or became impossible.
		self:SetTarget(bestInView)
	elseif self.Holding == nil and best and best ~= current and bestDistance < currentDistance - margin then
		-- Hysteresis; never switch in the middle of a hold.
		self:SetTarget(best)
	end

	for _, prompt in self.Prompts do
		if prompt == self.Target then
			Prompt.SetState(prompt, "Prompt")
		elseif candidates[prompt] then
			Prompt.SetState(prompt, "Indicator")
		else
			Prompt.SetState(prompt, "Hidden")
		end
	end
end

PromptController:OnInit(function(self)
	self:Setup()
end)

PromptController:OnStart(function(self)
	self.Dependencies.InputController:OnContextChange(function(context)
		if context ~= "Gameplay" then
			self:HideAll()
		end
	end)

	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

function PromptController:Watch(gui: Instance)
	self.Gui = gui
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(anchor)
		self:Add(anchor)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(anchor)
		self:Remove(anchor)
	end)
	for _, anchor in CollectionService:GetTagged(TAG) do
		self:Add(anchor)
	end
end

PromptController:OnTick(function(self)
	if self.Gui then
		self:Tick()
	end
end, TICK_RATE)

return PromptController
