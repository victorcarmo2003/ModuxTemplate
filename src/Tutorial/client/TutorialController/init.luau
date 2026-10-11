--!strict
--[[
	TutorialController (user request 2026-10-11; Provisional until a FEAT/TASK is written for it)

	First-hot-dog tutorial, only while the own profile says TutorialDone = false (ProfileController, Profile packet).
	After the intro cutscene it walks the player through the first sale:
	  answer the phone -> grill -> slice -> (cooking) -> collect -> assemble -> open shop (Prep only) -> take order
	  -> toppings -> serve -> money (UI step: the money pill pops in under a spotlight) -> mart (restock, talk only)
	  -> Walt's goodbye
	Steps.luau holds the texts; which step is current is decided live (Decide) from what the server replicated: the
	Stations set (grill / rail / board records), the Customers set, the CustomerController order card, the Tool in the
	own hand (ItemService parents it) and the `Sale` packet. Nothing is predicted: a step only moves when the server
	state moved, whoever made it move (a crewmate grilling also counts), and going back (hot dog thrown away) shows
	the earlier step again.

	Walt on the phone (user request 2026-10-11, Provisional): BossService rings the tutorial call (BossCalls Trigger
	Tutorial) while this player has the tutorial ahead, and holds it open. Step 1 points at the ringing phone; once the
	call is Talking, Walt leads: each step's Say lines go to the call subtitle (BossController:Hold/Say) and to Walt's
	text-to-speech voice (Call.luau), his Done praise when the player moves past a step, a reminder after NUDGE s on
	the same step. Talk steps (money, mart) move on when Walt finished them or on "Got it". At the end (or on Skip) Walt
	says goodbye and TutorialComplete goes out; the server hangs up Rules.Tutorial.Goodbye s later (the click). No call
	within CALL_WAIT s of a silent phone = the tutorial goes on with the panel only.

	Guidance: TutorialPanel (Cream card, top centre: "3/7", instruction, hint, Skip), TutorialArrow (bouncing arrow
	over the prompt anchor to use), a Highlight on the station or customer, TutorialPointer on the screen edge while
	the target is off screen, and Spotlight on the money pill for the UI step.

	Progressive HUD (HudController reads ShowCash / ShowClock): during a first run the money pill stays hidden until
	the first sale, the clock and day pills until the shift opens (phase Open). Everything shows when the tutorial
	ends, is skipped, or when it is not a first run.

	End: after the talk steps (Walt finished them or "Got it"), on Skip (Q / D-pad down / the Skip tag on touch), or when
	the day shift is over without a sale (Closing, Summary, night). Each end fires `TutorialComplete` once; the server
	(TutorialService) saves TutorialDone = true, so it never runs again for this player.

	PROVISIONAL: texts, CALL_WAIT, NUDGE, TALK_TIME, TALK_MIN, skip keys (Q, DPadDown), "any served sale while the step is serve or a hot dog was
	in hand in the last SALE_WINDOW s" as the first sale, ending on the day shift end.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)
local Spotlight = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Spotlight)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local TutorialArrow = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TutorialArrow)
local TutorialPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TutorialPanel)
local TutorialPointer = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TutorialPointer)
local Rules = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Rules)
local Call = require(script.Call)
local Steps = require(script.Steps)

const TAG = "Interactable"
const VEHICLE_TAG = "Vehicle"
const STATION_TAG = "Station"
const HOT_DOG = "hot_dog"
const TICK_RATE = 10
-- Phases where the tutorial runs (day shift, before the summary)
const RUN_PHASES: { [string]: boolean } = { Prep = true, Open = true }
-- Phases that end a tutorial still running without a sale (the day is over)
const END_PHASES: { [string]: boolean } = { Closing = true, Summary = true }
const SERVED: { [string]: boolean } = { Perfect = true, Complete = true, Incomplete = true, Wrong = true }
const SALE_WINDOW = 3 -- s: a sale this soon after the hot dog left the own hand counts as the first sale
const TUTORIAL_CALL = Content.BossCallRules.Tutorial.Call
const CALL_WAIT = 12 -- s of a silent phone before the tutorial goes on without Walt (panel only)
const NUDGE = 20 -- s on the same step before Walt says it again
const TALK_MIN = 1.5 -- s a talk step stays at least while Walt is on the line
const TALK_TIME = 7 -- s of a talk step without the call
const STEP_SOUND = "prompt_done"
const SKIP_BIND = "TutorialSkip"
const SKIP_TEXT: { [string]: string } = {
	KeyboardMouse = "Skip (Q)",
	Gamepad = "Skip (D-pad Down)",
	Touch = "Skip",
}
const DONE_TEXT: { [string]: string } = {
	KeyboardMouse = "Got it (Q)",
	Gamepad = "Got it (D-pad Down)",
	Touch = "Got it",
}
-- Highlight a station model only when it is about this big (studs); else the part of the anchor
const HIGHLIGHT_MAX = 7
const ARROW_LIFT = Vector3.new(0, 1.2, 0)
const CUSTOMER_LIFT = Vector3.new(0, 3.6, 0) -- over the order bubble and the prompt pill on the neck
const EDGE_MARGIN = 56 -- px from the screen edge for the pointer
-- UI scale like the HUD: 1 on the smallest phone (375 px tall), up to 2
const BASE_HEIGHT = 540
const MAX_SCALE = 2
const PANEL_TOP = 62 -- px at scale 1, under the clock row (HudScreen TOP 6 + 48 + gap 8)
const CASH_NAME = "Cash" -- HudPill of the money in the Hud ScreenGui
const MONEY_STEP = "money"

-- Stations set record fields read here (network.md §3.5)
type SlotRecord = { Kind: string, State: string, Count: number }
type Held = { Item: string, Toppings: { [string]: boolean } }
type Kitchen = {
	GrillWorking: boolean,
	GrillReady: boolean,
	Rail: number,
	BoardWorking: boolean,
	BoardReady: boolean,
}

const TutorialController = Modux.Controller("TutorialController", {
	Require = {
		"ProfileController",
		"RoundController",
		"CustomerController",
		"InputController",
		"AudioController",
		"PlaceController",
		"BossController",
	},
	Priority = 520,
})

function TutorialController:Setup()
	-- ended (finished, skipped or the day ran out) in this session; the profile flag follows from the server
	self.Finished = Vide.source(false) :: Vide.Source<boolean>
	self.Running = Vide.source(false) :: Vide.Source<boolean>
	self.CashRevealed = Vide.source(false) :: Vide.Source<boolean>
	self.ClockRevealed = Vide.source(false) :: Vide.Source<boolean>
	self.StepKey = Vide.source("") :: Vide.Source<string>
	-- topping name of the "toppings" step
	self.Item = Vide.source("") :: Vide.Source<string>
	-- false = none (a Source of an optional type is ambiguous to call under the new solver)
	self.Target = Vide.source(false :: Instance | false) :: Vide.Source<Instance | false>
	self.Spot = Vide.source(false :: GuiObject | false) :: Vide.Source<GuiObject | false>
	self.PointerShown = Vide.source(false) :: Vide.Source<boolean>
	self.PointerAt = Vide.source(Vector2.zero) :: Vide.Source<Vector2>
	self.PointerAngle = Vide.source(0) :: Vide.Source<number>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.Highlight = nil :: Highlight?
	self.Folder = nil :: Folder?
	-- os.clock() of the last tick with a hot dog in hand (0 = never)
	self.LastHotDogAt = 0 :: number
	-- Walt on the line: the tutorial call was answered (from here he leads), the greeting went out, no call came
	self.Answered = false :: boolean
	self.Greeted = false :: boolean
	self.Uncalled = false :: boolean
	-- os.clock of the first tick with a silent phone (0 = not waiting)
	self.WaitStarted = 0 :: number
	-- os.clock the current step started (talk steps, reminder)
	self.StepAt = 0 :: number
	-- BossController strip held by this tutorial
	self.Holding = false :: boolean
	self.Prepared = false :: boolean
	self.Call = Call.new(function(text: string?)
		self.Dependencies.BossController:Say(text)
	end, function(): number
		return self:VoiceVolume()
	end) :: Call.Call
	self.Sent = false :: boolean
	self.Unmounts = {} :: { () -> () }
end

-- Reactive -------------------------------------------------------------------------------------------------------

-- This player still has the tutorial ahead (first run) and it did not end in this session
function TutorialController:FirstRun(): boolean
	if not self.Dependencies.PlaceController:Is("Run") then
		return false
	end
	const profile = self.Dependencies.ProfileController
	return profile.Ready() and not profile.TutorialDone() and not self.Finished()
end

-- HUD reveal (HudController): money pill / clock + day pills. A night shift always shows everything (a first-run
-- player who joined a run at night gets the tutorial on the next day shift).
function TutorialController:ShowCash(): boolean
	return not self:FirstRun() or self.CashRevealed() or self.Dependencies.RoundController.IsNight()
end

function TutorialController:ShowClock(): boolean
	return not self:FirstRun() or self.ClockRevealed() or self.Dependencies.RoundController.IsNight()
end

function TutorialController:Step(): Steps.Step?
	return Steps.ByKey[self.StepKey()]
end

function TutorialController:PanelText(): string
	const step = self:Step()
	if step == nil then
		return ""
	end
	return (string.gsub(step.Text, "{item}", (string.gsub(self.Item(), "%%", "%%%%"))))
end

function TutorialController:SkipText(): string
	const device = self.Dependencies.InputController.Device()
	const step = self:Step()
	const texts = if step and step.Talk then DONE_TEXT else SKIP_TEXT
	return texts[device] or texts.KeyboardMouse
end

-- World reads (server-replicated state only) ---------------------------------------------------------------------

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

local function ancestorWith(instance: Instance, test: (Instance) -> boolean): Instance?
	local current = instance.Parent
	while current and current ~= Workspace do
		if test(current) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function npcIdOf(anchor: Instance): number?
	const rig = ancestorWith(anchor, function(instance)
		return typeof(instance:GetAttribute("NpcId")) == "number"
	end)
	const id = if rig then rig:GetAttribute("NpcId") else nil
	return if typeof(id) == "number" then id else nil
end

function TutorialController:Root(): BasePart?
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Tool in the own hand (ItemService parents it on the server; the client only reads it)
function TutorialController:Held(): Held?
	const character = Players.LocalPlayer.Character
	const tool = if character then character:FindFirstChildOfClass("Tool") else nil
	if tool == nil then
		return nil
	end
	const item = tool:GetAttribute("Item")
	if typeof(item) ~= "string" then
		return nil
	end
	const toppings = tool:GetAttribute("Toppings")
	return { Item = item, Toppings = Rules.ParseToppings(if typeof(toppings) == "string" then toppings else nil) }
end

function TutorialController:Kitchen(): Kitchen
	const state: Kitchen = { GrillWorking = false, GrillReady = false, Rail = 0, BoardWorking = false, BoardReady = false }
	for _, raw in self.Libs.Net.Stations:entries() do
		const record = raw :: SlotRecord
		if record.Kind == "grill" then
			state.GrillWorking = state.GrillWorking or record.State == "Working"
			state.GrillReady = state.GrillReady or record.State == "Ready"
		elseif record.Kind == "rail" then
			state.Rail += record.Count
		elseif record.Kind == "board" then
			state.BoardWorking = state.BoardWorking or record.State == "Working"
			state.BoardReady = state.BoardReady or record.State == "Ready"
		end
	end
	return state
end

-- NpcIds of customers at the counter waiting for "Take Order"
function TutorialController:Ordering(): { [number]: boolean }
	const ids: { [number]: boolean } = {}
	for id, record in self.Libs.Net.Customers:entries() do
		if record.State == "Ordering" then
			ids[id] = true
		end
	end
	return ids
end

-- Nearest live anchor of `action` (vehicle in use only); `enabled` = only anchors the server switched on
function TutorialController:Anchor(action: string, enabled: boolean, filter: ((Instance) -> boolean)?): Instance?
	const root = self:Root()
	const origin = if root then root.Position else nil
	const vehicle = Vide.untrack(self.Dependencies.RoundController.Vehicle)
	local best: Instance? = nil
	local bestDistance = math.huge
	for _, anchor in CollectionService:GetTagged(TAG) do
		if anchor:GetAttribute("PromptAction") ~= action or not anchor:IsDescendantOf(Workspace) then
			continue
		end
		if enabled and anchor:GetAttribute("PromptEnabled") == false then
			continue
		end
		const owner = ancestorWith(anchor, function(instance)
			return CollectionService:HasTag(instance, VEHICLE_TAG)
		end)
		if owner and owner:GetAttribute("Vehicle") ~= vehicle then
			continue
		end
		if filter and not filter(anchor) then
			continue
		end
		const position = positionOf(anchor)
		if position == nil then
			continue
		end
		const distance = if origin then (position - origin).Magnitude else 0
		if distance < bestDistance then
			best, bestDistance = anchor, distance
		end
	end
	return best
end

-- Walt on the phone ----------------------------------------------------------------------------------------------

function TutorialController:VoiceVolume(): number
	const volumes = self.Dependencies.AudioController.Volumes
	return (volumes.Master or 1) * (volumes.Voice or 1)
end

-- "ringing" / "talking" = the tutorial call; "busy" = another call on the phone; "idle" = silent phone
function TutorialController:CallState(): string
	const boss = self.Dependencies.BossController
	const state = Vide.untrack(boss.State)
	if state == "Idle" then
		return "idle"
	end
	if Vide.untrack(boss.Call) ~= TUTORIAL_CALL then
		return "busy"
	end
	return if state == "Talking" then "talking" else "ringing"
end

-- Walt is on the line for this player: the tutorial call was answered and is still talking
function TutorialController:Voiced(): boolean
	return self.Answered and self:CallState() == "talking"
end

-- Subtitle strip and line queue in step with the call (every tick, also after the tutorial ended: the goodbye)
function TutorialController:UpdateCall()
	const voiced = self:Voiced()
	if voiced ~= self.Holding then
		self.Holding = voiced
		if not voiced then
			self.Call.Cut() -- hides the strip while still held
		end
		self.Dependencies.BossController:Hold(voiced)
	end
	if voiced then
		self.Call.Step()
	end
end

-- Walt's lines for a step change: the greeting first, the praise of a step left forward, then the new step
function TutorialController:SpeakStep(before: Steps.Step?, after: Steps.Step?)
	if after == nil or not self:Voiced() then
		return
	end
	const lines: { string } = {}
	if not self.Greeted then
		self.Greeted = true
		for _, text in Steps.Greeting do
			table.insert(lines, text)
		end
	elseif before and before.Done and (Steps.IndexOf[after.Key] or 0) > (Steps.IndexOf[before.Key] or 0) then
		table.insert(lines, before.Done)
	end
	for _, text in after.Say or {} do
		table.insert(lines, text)
	end
	if #lines > 0 then
		self.Call.Replace(lines)
	end
end

-- Before Walt is on the line: the phone step (or waiting for the call). nil = the call is on, or never came.
function TutorialController:DecidePhone(): (string?, Instance?)
	if self.Answered then
		return nil, nil
	end
	const state = self:CallState()
	if state == "talking" then
		self.Answered = true
		return nil, nil
	end
	-- without the call so far, only the tutorial call itself brings the phone step back
	const ringing = Vide.untrack(self.Dependencies.BossController.State) == "Ringing"
		and (not self.Uncalled or state == "ringing")
	if ringing then
		-- any ringing call is answered the same way (a late tutorial call takes the lead back from the panel)
		self.WaitStarted = 0
		self.Uncalled = false
		return "phone", self:Anchor("answer_phone", true)
	end
	if self.Uncalled then
		return nil, nil
	end
	if state == "busy" then
		-- another call talking: the tutorial call is queued after it
		self.WaitStarted = 0
		return "wait_call", nil
	end
	-- silent phone: BossService queues the call within a tick; without a call the panel goes on alone
	const now = os.clock()
	if self.WaitStarted == 0 then
		self.WaitStarted = now
	end
	if now - self.WaitStarted > CALL_WAIT then
		self.Uncalled = true
		return nil, nil
	end
	return "wait_call", nil
end

-- Decide ---------------------------------------------------------------------------------------------------------

-- Current step and the anchor to point at, from the replicated state
function TutorialController:Decide(): (string, Instance?, string)
	const phoneKey, phoneTarget = self:DecidePhone()
	if phoneKey then
		return phoneKey, phoneTarget, ""
	end

	const round = self.Dependencies.RoundController
	const phase = Vide.untrack(round.Phase)
	const held = self:Held()

	if held and held.Item == HOT_DOG then
		self.LastHotDogAt = os.clock()
		if phase == "Prep" then
			return "open", self:Anchor("open_sign", false), ""
		end
		const customer = self.Dependencies.CustomerController
		const cardShown = Vide.untrack(function(): boolean
			return customer:CardShown()
		end)
		if cardShown then
			const focus = Vide.untrack(customer.Focus)
			const order = Vide.untrack(function(): { string }
				return customer:CardToppings()
			end)
			for _, key in order do
				if not held.Toppings[key] then
					const row = Content.Ingredients.ByKey[key]
					return "toppings",
						self:Anchor("topping_add", false, function(anchor)
							return anchor:GetAttribute("Ingredient") == key
						end),
						if row then row.Name else key
				end
			end
			return "serve", self:Anchor("serve", false, function(anchor)
				return focus == 0 or npcIdOf(anchor) == focus
			end), ""
		end
		const ordering = self:Ordering()
		if next(ordering) ~= nil then
			return "order", self:Anchor("take_order", false, function(anchor)
				const id = npcIdOf(anchor)
				return id ~= nil and ordering[id] == true
			end), ""
		end
		return "wait_customer", nil, ""
	end

	const kitchen = self:Kitchen()
	if kitchen.Rail > 0 and kitchen.BoardReady then
		return "assemble", self:Anchor("board_add_sausage", false), ""
	end
	if kitchen.GrillReady then
		return "collect", self:Anchor("grill_collect", true), ""
	end
	if kitchen.Rail == 0 and not kitchen.GrillWorking then
		return "grill", self:Anchor("grill_place", false), ""
	end
	if not kitchen.BoardReady and not kitchen.BoardWorking then
		return "slice", self:Anchor("bun_cut", false), ""
	end
	if kitchen.BoardWorking then
		return "slicing", nil, ""
	end
	-- grill working, bun sliced: wait for the sausage
	return "cooking", self:Anchor("grill_collect", false), ""
end

-- Presentation ---------------------------------------------------------------------------------------------------

function TutorialController:FxFolder(): Folder
	const existing = self.Folder
	if existing and existing.Parent then
		return existing
	end
	const folder = Instance.new("Folder")
	folder.Name = "TutorialFx"
	folder.Parent = Workspace
	self.Folder = folder
	return folder
end

-- What the Highlight wraps: the customer rig, a small station model, else the part of the anchor
local function highlightOf(anchor: Instance): Instance?
	const rig = ancestorWith(anchor, function(instance)
		return typeof(instance:GetAttribute("NpcId")) == "number" and instance:IsA("Model")
	end)
	if rig then
		return rig
	end
	const station = ancestorWith(anchor, function(instance)
		return CollectionService:HasTag(instance, STATION_TAG)
	end)
	if station and station:IsA("Model") then
		const _, size = station:GetBoundingBox()
		if math.max(size.X, size.Y, size.Z) <= HIGHLIGHT_MAX then
			return station
		end
	end
	if anchor:IsA("BasePart") then
		return anchor
	end
	const parent = anchor.Parent
	if parent and parent:IsA("BasePart") then
		return parent
	end
	return station
end

function TutorialController:SetHighlight(anchor: Instance?)
	const adornee = if anchor then highlightOf(anchor) else nil
	local highlight = self.Highlight
	if adornee == nil then
		if highlight then
			highlight.Enabled = false
			highlight.Adornee = nil
		end
		return
	end
	if highlight == nil or highlight.Parent == nil then
		const created = Instance.new("Highlight")
		created.Name = "TutorialHighlight"
		created.FillColor = Theme.Color.Mustard
		created.FillTransparency = 0.7
		created.OutlineColor = Theme.Color.Mustard
		created.OutlineTransparency = 0
		created.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		created.Parent = self:FxFolder()
		self.Highlight = created
		highlight = created
	end
	if highlight then
		if highlight.Adornee ~= adornee then
			highlight.Adornee = adornee
		end
		highlight.Enabled = true
	end
end

function TutorialController:ClearGuidance()
	Vide.batch(function()
		self.Target(false)
		self.PointerShown(false)
		self.Spot(false)
	end)
	self:SetHighlight(nil)
end

-- Edge pointer toward the target while it is off screen (every frame; the overlay ignores the GUI inset, so its
-- pixels are viewport pixels)
function TutorialController:UpdatePointer()
	const target = Vide.untrack(self.Target)
	const camera = Workspace.CurrentCamera
	const position = if target then positionOf(target) else nil
	if position == nil or camera == nil or not Vide.untrack(self.Running) then
		if Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
		return
	end
	const viewport = camera.ViewportSize
	const point, onScreen = camera:WorldToViewportPoint(position)
	const centre = viewport / 2
	local delta = Vector2.new(point.X, point.Y) - centre
	if point.Z < 0 then
		-- behind the camera: the projection is mirrored
		delta = -delta
	end
	const inside = onScreen
		and point.X > EDGE_MARGIN
		and point.X < viewport.X - EDGE_MARGIN
		and point.Y > EDGE_MARGIN
		and point.Y < viewport.Y - EDGE_MARGIN
	if inside or delta.Magnitude < 1 then
		if Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
		return
	end
	const halfX = math.max(viewport.X / 2 - EDGE_MARGIN, 1)
	const halfY = math.max(viewport.Y / 2 - EDGE_MARGIN, 1)
	const t = math.min(
		if delta.X ~= 0 then halfX / math.abs(delta.X) else math.huge,
		if delta.Y ~= 0 then halfY / math.abs(delta.Y) else math.huge
	)
	Vide.batch(function()
		self.PointerAt(centre + delta * t)
		self.PointerAngle(math.deg(math.atan2(delta.Y, delta.X)))
		if not Vide.untrack(self.PointerShown) then
			self.PointerShown(true)
		end
	end)
end

function TutorialController:Rescale()
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	const scale = math.clamp(camera.ViewportSize.Y / BASE_HEIGHT, 1, MAX_SCALE)
	if math.abs(scale - Vide.untrack(self.Scale)) > 0.01 then
		self.Scale(scale)
	end
end

-- Flow -----------------------------------------------------------------------------------------------------------

function TutorialController:SetStep(key: string, target: Instance?, item: string)
	const previous = Vide.untrack(self.StepKey)
	const before = Steps.ByKey[previous]
	const after = Steps.ByKey[key]
	Vide.batch(function()
		if previous ~= key then
			self.StepKey(key)
		end
		if Vide.untrack(self.Item) ~= item then
			self.Item(item)
		end
		if Vide.untrack(self.Target) ~= (target or false) then
			self.Target(target or false)
		end
	end)
	self:SetHighlight(target)
	if before and after and after.Number > before.Number then
		self.Dependencies.AudioController:Play(STEP_SOUND)
	end
	if previous ~= key then
		self.StepAt = os.clock()
		self:SpeakStep(before, after)
	end
end

-- The money pill of the HUD (spotlight target of the UI step)
local function cashPill(): GuiObject?
	const gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	const hud = if gui then gui:FindFirstChild("Hud") else nil
	const pill = if hud then hud:FindFirstChild(CASH_NAME, true) else nil
	return if pill and pill:IsA("GuiObject") then pill else nil
end

function TutorialController:OnSale(result: string)
	if not Vide.untrack(self.Running) or not SERVED[result] then
		return
	end
	const step = Vide.untrack(self.StepKey)
	const current = Steps.ByKey[step]
	if current and current.Talk then
		return
	end
	if step ~= "serve" and os.clock() - self.LastHotDogAt > SALE_WINDOW then
		return
	end
	Vide.batch(function()
		self.CashRevealed(true)
		self.ClockRevealed(true)
	end)
	self:SetStep(MONEY_STEP, nil, "")
	self.Target(false)
	self:SetHighlight(nil)
	-- the pill pops in this frame: spotlight it once it is laid out
	task.defer(function()
		if Vide.untrack(self.StepKey) == MONEY_STEP then
			self.Spot(cashPill() or false)
		end
	end)
end

-- Talk step: over once Walt said it (at least TALK_MIN s), or after TALK_TIME s without the call
function TutorialController:TickTalk()
	const elapsed = os.clock() - self.StepAt
	const over = if self:Voiced() then elapsed >= TALK_MIN and not self.Call.Busy() else elapsed >= TALK_TIME
	if over then
		self:NextTalk()
	end
end

-- Next talk step; after the last one the tutorial is done
function TutorialController:NextTalk()
	const current = Vide.untrack(self.StepKey)
	local nextKey: string? = nil
	for index, key in Steps.Talks do
		if key == current then
			nextKey = Steps.Talks[index + 1]
			break
		end
	end
	if nextKey == nil then
		self:Finish("done")
		return
	end
	self.Spot(false)
	self:SetStep(nextKey, nil, "")
end

-- Skip key / tag: "Got it" on a talk step (next one), else skips the tutorial
function TutorialController:Skip()
	const step = Steps.ByKey[Vide.untrack(self.StepKey)]
	if step and step.Talk then
		if self:Voiced() then
			self.Call.Cut()
		end
		self:NextTalk()
		return
	end
	self:Finish("skip")
end

-- Ends the tutorial for good; the server saves the flag (and hangs up the call after Walt's goodbye).
-- reason: "done" (last talk step), "skip" (the player skipped), "over" (the day shift ended first)
function TutorialController:Finish(reason: string)
	if Vide.untrack(self.Finished) then
		return
	end
	if self:Voiced() then
		if reason == "done" then
			self.Call.Replace(Steps.Goodbye)
		elseif reason == "skip" then
			self.Call.Cut()
			self.Call.Queue(Steps.SkipGoodbye)
		else
			self.Call.Cut()
		end
	end
	Vide.batch(function()
		self.Finished(true)
		self.Running(false)
		self.StepKey("")
	end)
	self:ClearGuidance()
	if not self.Sent then
		self.Sent = true
		self.Libs.Net.TutorialComplete:fireServer()
	end
end

function TutorialController:Tick()
	self:Rescale()
	self:UpdateCall()
	const firstRun = Vide.untrack(function(): boolean
		return self:FirstRun()
	end)
	if not firstRun then
		return
	end
	const round = self.Dependencies.RoundController
	const phase = Vide.untrack(round.Phase)
	const ready = Vide.untrack(round.Ready)
	const night = Vide.untrack(round.IsNight)

	-- the day shift is over without a sale: end it, show the whole HUD
	if ready and Vide.untrack(self.Running) and (night or END_PHASES[phase]) then
		self:Finish("over")
		return
	end
	if ready and phase ~= "Prep" and phase ~= "Intro" and not Vide.untrack(self.ClockRevealed) then
		self.ClockRevealed(true)
	end

	const canRun = ready and not night and RUN_PHASES[phase] == true and not Vide.untrack(Cinematic.Active)
	if not canRun then
		if Vide.untrack(self.Running) then
			self.Running(false)
			self:ClearGuidance()
		end
		return
	end
	if not Vide.untrack(self.Running) then
		self.Running(true)
	end
	if not self.Prepared then
		-- generate Walt's voice ahead, while the phone rings
		self.Prepared = true
		self.Call.Prepare(Steps.Lines)
	end
	const current = Steps.ByKey[Vide.untrack(self.StepKey)]
	if current and current.Talk then
		self:TickTalk()
		return
	end
	const key, target, item = self:Decide()
	self:SetStep(key, target, item)
	-- reminder: the same step for NUDGE s and Walt quiet
	const step = Steps.ByKey[key]
	if step and step.Say and not self.Call.Busy() and os.clock() - self.StepAt > NUDGE and self:Voiced() then
		self.StepAt = os.clock()
		self.Call.Queue(step.Say)
	end
end

-- Skip: Q / D-pad down while it runs; touch uses the Skip tag of the panel
function TutorialController:BindSkip(on: boolean)
	const input = self.Dependencies.InputController
	if not on then
		input:Unbind(SKIP_BIND)
		return
	end
	if input.Handles[SKIP_BIND] ~= nil then
		return
	end
	input
		:Bind({
			Name = SKIP_BIND,
			Key = Enum.KeyCode.Q,
			Keys = { Enum.KeyCode.DPadDown },
			Context = "Gameplay",
		})
		.OnPress(function()
			self:Skip()
		end)
end

function TutorialController:Mount(playerGui: Instance)
	const scale = function(): number
		return math.max(self.Scale(), 1)
	end
	const shown = function(): boolean
		return self.Running() and self.StepKey() ~= ""
	end

	const unmount = Vide.root(function()
		Vide.effect(function()
			const on = self.Running()
			Vide.untrack(function()
				self:BindSkip(on)
				return nil
			end)
		end)

		const panel = Vide.create("ScreenGui")({
			Name = "Tutorial",
			ResetOnSpawn = false,
			IgnoreGuiInset = false,
			ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 6,
			Enabled = function()
				return not Cinematic.Active()
			end,
			TutorialPanel({
				Shown = shown,
				Step = function()
					const step = self:Step()
					return if step then step.Number else 1
				end,
				Total = function()
					return Steps.Total
				end,
				Text = function()
					return self:PanelText()
				end,
				Hint = function()
					const step = self:Step()
					return if step then step.Hint else ""
				end,
				SkipText = function()
					return self:SkipText()
				end,
				OnSkip = function()
					self:Skip()
				end,
				Scale = scale,
				-- under the clock row, scaled like the HUD
				Position = function()
					return UDim2.new(0.5, 0, 0, PANEL_TOP * scale())
				end,
			}),
		})
		panel.Parent = playerGui

		const overlay = Vide.create("ScreenGui")({
			Name = "TutorialOverlay",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 5,
			Enabled = function()
				return not Cinematic.Active()
			end,
			Spotlight({
				Shown = function()
					return shown() and self.Spot() ~= false
				end,
				Target = function(): GuiObject?
					const spot = self.Spot()
					return if spot then spot else nil
				end,
			}),
			TutorialPointer({
				Shown = function()
					return shown() and self.PointerShown()
				end,
				Position = self.PointerAt,
				Angle = self.PointerAngle,
			}),
		})
		overlay.Parent = playerGui

		const arrow = TutorialArrow({
			Name = "TutorialArrow",
			Adornee = function(): Instance?
				const target = self.Target()
				return if target then target else nil
			end,
			Shown = function()
				return shown() and not Cinematic.Active()
			end,
			Offset = ARROW_LIFT,
		})
		Vide.effect(function()
			const target = self.Target()
			arrow.StudsOffsetWorldSpace = if target and npcIdOf(target) then CUSTOMER_LIFT else ARROW_LIFT
		end)
		arrow.Parent = playerGui
	end)
	table.insert(self.Unmounts, unmount)
end

TutorialController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Sale:onClient(function(sale)
		self:OnSale(sale.Result)
	end)
end)

TutorialController:OnStart(function(self)
	if not self.Dependencies.PlaceController:Is("Run") then
		return
	end
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
	RunService.Heartbeat:Connect(function()
		if Vide.untrack(self.Running) then
			self:UpdatePointer()
		elseif Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
	end)
end)

TutorialController:OnTick(function(self)
	self:Tick()
end, TICK_RATE)

return TutorialController
