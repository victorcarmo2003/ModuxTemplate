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

	One prompt per customer (user playtest 2026-10-11, Q-201): the customer has two server anchors (`Prompt_Customer` =
	Take Order / Serve and `Prompt_Refuse`), but the pill shows ONE. While the customer prompt is a candidate, the
	Refuse anchor is never a candidate (no second pill or dot next to the ketchup); with the customer prompt as target
	the second action runs on R (gamepad Y, a second touch button "Refuse"), held Refuse.Hold, and the pill says
	"hold R: Refuse". When there is no customer prompt (a customer waiting for food and an empty hand) the Refuse
	anchor is an ordinary prompt on E, as before. The server still checks everything on the Refuse anchor.

	Interaction menu (user request 2026-10-12): when two or more prompts are in view at once (counter: Take Order, Collect
	Cash, ketchup...) the pills give way to ONE ordered column of buttons (Interface/Components/InteractionMenu, order and
	selection in `Menu`): priority tier then distance, stable (new rows are inserted, listed rows never reshuffle), a row that
	leaves reach stays 1.5 s dimmed. The selected row is the target: E / X / the touch button / hold act on it. PC: wheel or
	Up/Down moves, 1..4 pick and press directly; gamepad D-pad up/down; touch taps the rows (held rows fill). Refuse stays on
	R / Y with the customer row. One candidate = the pill as before. Billboards show the dot while the menu is up. Same
	Interact packet, same server checks: the menu only chooses which prompt the existing path fires.

	Completion pop (user request 2026-10-11): the moment an Interact is actually sent (hold completed or tap), the
	pill pops (Prompt.Celebrate -> PromptBillboard bump/flash/check), a few sparkles burst at the anchor (Burst) and
	`prompt_done` (Ui) plays. It confirms the input, not the result: the server still decides.
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local InteractionMenu = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.InteractionMenu)
local Prompt = require(script.Prompt)
local Rules = require(script.Rules)
local Burst = require(script.Burst)
local Menu = require(script.Menu)

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
const ALT_BIND_NAME = "InteractAlt"
const REFUSE_ACTION = "refuse"
const CUSTOMER_ANCHOR = "Prompt_Customer"
const REFUSE_ANCHOR = "Prompt_Refuse"
const ALT_KEY_LABEL = { KeyboardMouse = "R", Gamepad = "Y", Touch = "" }
-- InteractionMenu (user request 2026-10-12): rows beyond one candidate; see the header
const MENU_NEXT_BIND = "InteractMenuNext"
const MENU_PREV_BIND = "InteractMenuPrev"
const MENU_PICK_BIND = "InteractMenuPick"
const MENU_PICK_KEYS: { Enum.KeyCode } = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
const MENU_PICK_PAD: { Enum.KeyCode } =
	{ Enum.KeyCode.KeypadOne, Enum.KeyCode.KeypadTwo, Enum.KeyCode.KeypadThree, Enum.KeyCode.KeypadFour }
const MENU_RIGHT = 16
const MENU_RIGHT_TOUCH = 190 -- clears the jump and use buttons of a phone

const PromptController = Modux.Controller(
	"PromptController",
	{ Require = { "InputController", "RoundController", "AudioController" }, Priority = 620 }
)

function PromptController:Setup()
	self.Prompts = {} :: { [Instance]: Prompt.Prompt }
	self.Target = nil :: Prompt.Prompt?
	self.Holding = nil :: Prompt.Prompt?
	-- Second action of the target (Refuse of the customer prompt) and whether the hold in progress is that one
	self.Alt = nil :: Prompt.Prompt?
	self.AltHolding = false :: boolean
	self.HoldThread = nil :: thread?
	self.HoldSound = nil :: Sound?
	self.LastFire = 0 :: number
	self.Gui = nil :: Instance?
	-- Presentation filter (TutorialPromptGate): false = the anchor shows no prompt. nil = no filter. Never decides
	-- anything: the server revalidates every Interact.
	self.Gate = nil :: ((Instance) -> boolean)?
	-- InteractionMenu state: Menu.State is the order / selection, the sources feed the component
	self.MenuState = Menu.new() :: Menu.State
	self.MenuActive = false :: boolean
	self.MenuBound = 0 :: number -- number keys currently bound
	self.MenuItems = {} :: { [Prompt.Prompt]: { Item: InteractionMenu.Item, Enabled: Vide.Source<boolean> } }
	self.MenuPrompts = {} :: { [InteractionMenu.Item]: Prompt.Prompt }
	self.MenuList = Vide.source({}) :: Vide.Source<{ InteractionMenu.Item }>
	self.MenuSelected = Vide.source(nil) :: Vide.Source<InteractionMenu.Item?>
	self.MenuVisible = Vide.source(false) :: Vide.Source<boolean>
	self.Refuses = {} :: { [Prompt.Prompt]: Prompt.Prompt }
end

function PromptController:SetGate(gate: ((Instance) -> boolean)?)
	self.Gate = gate
end

-- A failing gate never hides prompts (fails open)
function PromptController:Gated(anchor: Instance): boolean
	const gate = self.Gate
	if gate == nil then
		return true
	end
	const ok, allowed = pcall(gate, anchor)
	return not ok or allowed ~= false
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
	self:ForgetMenu(prompt)
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
		if self.AltHolding then
			self.AltHolding = false
			Prompt.Refresh(holding) -- the pill goes back to the hold of its own action
		end
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

-- R / Y / the second touch button: Refuse on the customer prompt that is the target (hold, same rules as BeginHold)
function PromptController:BeginAltHold()
	const target = self.Target
	const alt = self.Alt
	if target == nil or alt == nil or self.Holding then
		return
	end
	self.Holding = target
	self.AltHolding = true
	Prompt.SetHolding(target, true)
	target.HoldDuration(alt.Hold)
	self.HoldSound = self.Dependencies.AudioController:Play(HOLD_SOUND)
	const id = alt.Id
	self.HoldThread = task.delay(alt.Hold, function()
		self.HoldThread = nil
		if self.Target == target and self.Alt == alt and alt.Id == id and Prompt.IsLive(alt) then
			self:Fire(alt)
			Prompt.Celebrate(target)
		end
		self:CancelHold()
	end)
end

-- Sets the second action of the target (nil = none): binds / unbinds its input and writes the pill hint.
function PromptController:SetAlt(alt: Prompt.Prompt?)
	const target = self.Target
	if alt ~= self.Alt then
		self:CancelHold()
		self.Alt = alt
		const input = self.Dependencies.InputController
		if alt == nil then
			input:Unbind(ALT_BIND_NAME)
		elseif input.Handles[ALT_BIND_NAME] == nil then
			input
				:Bind({
					Name = ALT_BIND_NAME,
					Key = Enum.KeyCode.R,
					Keys = { Enum.KeyCode.ButtonY },
					TouchButton = true,
					Title = "Refuse",
					TouchSize = TOUCH_SIZE,
					Priority = Enum.ContextActionPriority.High.Value,
					Context = "Gameplay",
				})
				.OnPress(function()
					self:BeginAltHold()
				end)
				.OnRelease(function()
					if self.AltHolding then
						self:EndHold()
					end
				end)
		end
	end
	-- Hint on the pill of the target only (touch has its own button)
	const device = self.Dependencies.InputController.Device()
	const key = ALT_KEY_LABEL[device]
	const hint = if alt ~= nil and key ~= nil and key ~= "" then `  ·  hold {key}: {alt.Text()}` else ""
	for _, prompt in self.Prompts do
		const wanted = if prompt == target then hint else ""
		if prompt.Hint() ~= wanted then
			prompt.Hint(wanted)
		end
	end
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

-- Menu helpers (user request 2026-10-12) ---------------------------------------------------------------------------

-- One stable Item per prompt: the component keys its rows by the table, so a row keeps its instances and animation.
function PromptController:MenuItemOf(prompt: Prompt.Prompt): InteractionMenu.Item
	const existing = self.MenuItems[prompt]
	if existing then
		return existing.Item
	end
	const enabled = Vide.source(true)
	const item: InteractionMenu.Item = {
		Text = prompt.Text,
		-- reads Text first: the icon follows the same refresh (a topping prompt changes ingredient with its text)
		Icon = function()
			prompt.Text()
			return Menu.IconOf(prompt.Target)
		end,
		Holding = prompt.Holding,
		HoldDuration = prompt.HoldDuration,
		Done = prompt.Done,
		Enabled = enabled,
		Hint = prompt.Hint,
	}
	self.MenuItems[prompt] = { Item = item, Enabled = enabled }
	self.MenuPrompts[item] = prompt
	return item
end

function PromptController:ForgetMenu(prompt: Prompt.Prompt)
	Menu.Forget(self.MenuState, prompt)
	const entry = self.MenuItems[prompt]
	if entry == nil then
		return
	end
	self.MenuItems[prompt] = nil
	self.MenuPrompts[entry.Item] = nil
	const list = Vide.untrack(self.MenuList)
	if table.find(list, entry.Item) then
		const kept: { InteractionMenu.Item } = {}
		for _, item in list do
			if item ~= entry.Item then
				table.insert(kept, item)
			end
		end
		self.MenuList(kept)
	end
	if Vide.untrack(self.MenuSelected) == entry.Item then
		self.MenuSelected(nil)
	end
end

-- Pushes order, selection and "in reach" flags to the component (only writes what changed).
function PromptController:PublishMenu()
	const state = self.MenuState
	const list: { InteractionMenu.Item } = {}
	for _, prompt in state.Order do
		table.insert(list, self:MenuItemOf(prompt))
	end
	const published = Vide.untrack(self.MenuList)
	local same = #published == #list
	if same then
		for index, item in list do
			if published[index] ~= item then
				same = false
				break
			end
		end
	end
	if not same then
		self.MenuList(list)
	end
	for prompt, entry in self.MenuItems do
		entry.Enabled(state.Current[prompt] ~= nil)
	end
	const selected = if state.Selected then self:MenuItemOf(state.Selected) else nil
	if Vide.untrack(self.MenuSelected) ~= selected then
		self.MenuSelected(selected)
	end
end

-- The selected row is the target: E / X / the touch button / the hold all act on it.
function PromptController:ApplyMenuTarget()
	const selected = self.MenuState.Selected
	self:SetTarget(selected)
	self:SetAlt(if selected then self.Refuses[selected] else nil)
	self:PublishMenu()
end

-- Wheel / arrows / D-pad. Never in the middle of a hold.
function PromptController:MenuStep(delta: number)
	if not self.MenuActive or self.Holding then
		return
	end
	if Menu.Move(self.MenuState, delta) then
		self:ApplyMenuTarget()
	end
end

-- Number key / tap: select the row and press it (same path as E).
function PromptController:MenuPress(prompt: Prompt.Prompt)
	if not self.MenuActive or self.Holding then
		return
	end
	if not Menu.Select(self.MenuState, prompt) then
		return
	end
	self:ApplyMenuTarget()
	self:BeginHold(prompt)
end

-- Direct keys 1..n for the listed rows, kept in step with the list length while the menu is up.
function PromptController:BindMenuPicks(count: number)
	const wanted = if self.MenuActive then math.min(count, #MENU_PICK_KEYS) else 0
	if wanted == self.MenuBound then
		return
	end
	const input = self.Dependencies.InputController
	for index = wanted + 1, self.MenuBound do
		input:Unbind(MENU_PICK_BIND .. index)
	end
	for index = self.MenuBound + 1, wanted do
		input
			:Bind({
				Name = MENU_PICK_BIND .. index,
				Key = MENU_PICK_KEYS[index],
				Keys = { MENU_PICK_PAD[index] },
				Priority = Enum.ContextActionPriority.High.Value,
				Context = "Gameplay",
			})
			.OnPress(function()
				const prompt = self.MenuState.Order[index]
				if prompt then
					self:MenuPress(prompt)
				end
			end)
			.OnRelease(function()
				self:EndHold()
			end)
	end
	self.MenuBound = wanted
end

function PromptController:SetMenuActive(active: boolean)
	if self.MenuActive == active then
		return
	end
	self.MenuActive = active
	self.MenuVisible(active)
	const input = self.Dependencies.InputController
	if active then
		input
			:Bind({
				Name = MENU_NEXT_BIND,
				Key = Enum.KeyCode.Down,
				Keys = { Enum.KeyCode.DPadDown },
				Priority = Enum.ContextActionPriority.High.Value,
				Context = "Gameplay",
			})
			.OnPress(function()
				self:MenuStep(1)
			end)
		input
			:Bind({
				Name = MENU_PREV_BIND,
				Key = Enum.KeyCode.Up,
				Keys = { Enum.KeyCode.DPadUp },
				Priority = Enum.ContextActionPriority.High.Value,
				Context = "Gameplay",
			})
			.OnPress(function()
				self:MenuStep(-1)
			end)
	else
		input:Unbind(MENU_NEXT_BIND)
		input:Unbind(MENU_PREV_BIND)
	end
	self:BindMenuPicks(#self.MenuState.Order)
end

function PromptController:MountMenu(gui: Instance)
	const input = self.Dependencies.InputController
	const _unmount, menuGui = Vide.root(function()
		return Vide.create("ScreenGui")({
			Name = "InteractionMenu",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 2,

			InteractionMenu({
				Items = self.MenuList,
				Selected = self.MenuSelected,
				Visible = self.MenuVisible,
				Device = input.Device,
				Tappable = function()
					return input.Device() == "Touch"
				end,
				Right = function()
					return if input.Device() == "Touch" then MENU_RIGHT_TOUCH else MENU_RIGHT
				end,
				-- a tap selects and presses in one go
				OnPress = function(item)
					const prompt = self.MenuPrompts[item]
					if prompt then
						self:MenuPress(prompt)
					end
				end,
				OnRelease = function(_item)
					self:EndHold()
				end,
			}),
		})
	end)
	menuGui.Parent = gui
end

function PromptController:HideAll()
	self:SetTarget(nil)
	self:SetAlt(nil)
	Menu.Clear(self.MenuState)
	self:SetMenuActive(false)
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

-- Prompt of the anchor called `name` that shares the parent (the rig root) of `prompt`'s anchor
function PromptController:Sibling(prompt: Prompt.Prompt, name: string): Prompt.Prompt?
	const parent = prompt.Anchor.Parent
	const found = if parent then parent:FindFirstChild(name) else nil
	return if found then self.Prompts[found] else nil
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

	for _, prompt in self.Prompts do
		if not Prompt.IsLive(prompt) or prompt.Anchor:IsDescendantOf(character) or not self:Gated(prompt.Anchor) then
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
		candidates[prompt] = (Vector2.new(point.X, point.Y) - center).Magnitude
	end

	-- One pill per customer: the Refuse anchor yields to the customer prompt of the same rig (see the header)
	const refuses: { [Prompt.Prompt]: Prompt.Prompt } = {}
	for prompt in candidates do
		if prompt.Target.Action == REFUSE_ACTION then
			const sibling = self:Sibling(prompt, CUSTOMER_ANCHOR)
			if sibling ~= nil and candidates[sibling] ~= nil then
				refuses[sibling] = prompt
			end
		end
	end
	for _, refuse in refuses do
		candidates[refuse] = nil
	end

	self.Refuses = refuses

	-- InteractionMenu: several candidates in view -> an ordered list of buttons instead of one pill (see Menu.luau).
	-- A row the tutorial gate no longer allows goes at once; the others get a grace period.
	const menu = self.MenuState
	const inView: { [Prompt.Prompt]: number } = {}
	for prompt, distance in candidates do
		if distance <= maxScreenDistance then
			inView[prompt] = distance
		end
	end
	for _, prompt in table.clone(menu.Order) do
		if not self:Gated(prompt.Anchor) then
			Menu.Forget(menu, prompt)
		end
	end
	Menu.Update(menu, inView, os.clock(), self.Holding ~= nil, margin)
	-- Enter with two live rows; stay while two rows remain (one may be in grace) so the list does not collapse under
	-- the selection.
	const showMenu = Menu.CurrentCount(menu) >= 2 or (self.MenuActive and #menu.Order >= 2)
	self:SetMenuActive(showMenu)

	if showMenu then
		self:SetTarget(menu.Selected)
		self:SetAlt(if menu.Selected then refuses[menu.Selected] else nil)
		self:PublishMenu()
		self:BindMenuPicks(#menu.Order)
	else
		local best: Prompt.Prompt? = nil
		local bestDistance = math.huge
		for prompt, distance in candidates do
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

		-- The Refuse that rides on the (new) target, if the customer prompt is the target
		const target = self.Target
		self:SetAlt(if target ~= nil then refuses[target] else nil)
	end

	for _, prompt in self.Prompts do
		if prompt == self.Target and not showMenu then
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

	-- Mouse wheel walks the interaction menu (observe only: the camera is locked first person, nothing else uses it)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseWheel and input.Position.Z ~= 0 then
			self:MenuStep(if input.Position.Z > 0 then -1 else 1)
		end
	end)

	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

function PromptController:Watch(gui: Instance)
	self.Gui = gui
	self:MountMenu(gui)
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
