--!strict
--[[
	TutorialController (user request 2026-10-11; Provisional until a FEAT/TASK is written for it)

	First-hot-dog tutorial, on Day 1 of every run for everyone (user request 2026-10-11, Provisional; nothing is saved: no profile flag).
	After the intro cutscene it walks the player through the first sale, following the order of one tutorial customer
	(user request 2026-10-11, Provisional):
	  answer the phone -> (the tutorial customer walks up) take the order -> grill -> slice -> (cooking) -> collect
	  -> assemble -> toppings of the order (or throw away a wrong one) -> open the shop (only if still in Prep: the
	  drawer is closed there) -> serve -> money (UI step: the money pill pops in under a spotlight) -> shopping ->
	  Walt's goodbye
	Shopping (user request 2026-10-11, Provisional): the tutorial run starts with one bun (TutorialService, server), so
	the first sale empties the crate. With the bun stock at 0 after the money step: mart_go (arrow on the Mart door,
	MapPoint MKT-DOOR / its AutoDoor) -> mart_buy (the BAKERY shelf anchor, buy_package of TutorialRules.Package; from
	the moment the player reached the door or the shelf) -> mart_back (the pack in hand, arrow on the bun crate restock
	anchor) -> restock (near the crate) -> the bun stock goes above 0 (whoever restocked) = done. With buns left (no
	tutorial stock: a party with a veteran) the talk step "mart" stands in for the four.
	Tutorial customer: once the call is answered (or it never came) `TutorialBegin` goes out once; TutorialService has
	CustomerService spawn one customer with the rig attribute shared.Tutorial.Rules.Attribute (fixed order, no time
	limit, out of the grade). Asked again every REASK s while none is around and no sale came.
	Steps.luau holds the texts; which step is current is decided live (Decide) from what the server replicated: the
	Stations set (grill / rail / board records), the Customers record of the tutorial customer (State, Order), the Tool
	in the own hand (ItemService parents it), the round phase and the `Sale` packet of that customer. Nothing is
	predicted: a step only moves when the server state moved, whoever made it move (a crewmate grilling also counts),
	and going back (hot dog thrown away) shows the earlier step again.

	Walt on the phone (user request 2026-10-11, Provisional): BossService rings the tutorial call (BossCalls Trigger
	Tutorial) while this player has the tutorial ahead, and holds it open. Step 1 points at the ringing phone; once the
	call is Talking, Walt leads: each step's Say lines go to the call subtitle (BossController:Hold/Say) and to Walt's
	text-to-speech voice (Call.luau), his Done praise when the player moves past a step, a reminder after NUDGE s on
	the same step. Talk steps (money, mart) move on when Walt finished them or on "Got it". At the end (or on Skip) Walt
	says goodbye and TutorialComplete goes out; the server hangs up Rules.Tutorial.Goodbye s later (the click). No call
	within CALL_WAIT s of a silent phone = the tutorial goes on with the panel only.

	Guidance (user request 2026-10-11: "very clear what to interact with"): TutorialPanel (Cream card, top centre:
	"3/9" chip, "STEP 3 OF 9", the instruction starting with the verb, hint, Skip), Beacon.luau (pulsing Mustard
	Highlight on the exact piece of the step: the pot, the grill, the bun crate, the board, the customer; and a 3D
	arrow bobbing over it), TutorialPointer on the screen edge while the target is off screen, and Spotlight on the
	money pill for the UI step. From far away (camera > ARROW_FAR studs from the target) the 3D arrow gets small, so a
	screen-sized bouncing billboard arrow (TutorialArrow, scaled like the HUD) hangs over the same spot; a step with
	AlwaysArrow (the OPEN sign, playtest 2026-10-11) shows it at any distance. Pieces without a
	visible part of their own (the OPEN sign's anchor on its stand, an invisible Mart shelf anchor) mark the small model
	around them or the nearest visible piece (highlightOf). A step completed (the panel number goes up) turns the chip Green with a check for
	CHECK_TIME s and plays `prompt_done`.
	Prompt focus: Focuses(anchor) says whether a prompt belongs to the current step (true for every prompt when the
	tutorial is not running or the step has no world target). PromptController can use it to hide or dim the others;
	that hook is the PromptController owner's (not wired from here).

	Progressive HUD (HudController reads ShowCash / ShowClock): during a first run the money pill stays hidden until
	the first sale, the clock and day pills until the shift opens (phase Open). Everything shows when the tutorial
	ends, is skipped, or when it is not a first run.

	End: after the talk steps (Walt finished them or "Got it"), on Skip (Q / D-pad down / the Skip tag on touch), or when
	the day shift is over without a sale (Closing, Summary, night). Each end fires `TutorialComplete` once; the server
	(TutorialService) only remembers it in memory for this run (never saved). Past Day 1 it does not come back (FirstRun).

	No progress (playtest 2026-10-11: on "Open the shop" a distracted player thought the game froze): a step with a
	Remind line and no progress for IDLE s (same step, not getting PROGRESS studs closer to the target) turns urgent:
	Walt says the short Remind line (when on the line and quiet), the panel hint shows it on a Mustard card that pulses,
	the Highlight / 3D arrow / billboard arrow / edge pointer pulse harder. Again every IDLE s; over when the step changes.
	Steps without Remind (waiting rows) keep the plain NUDGE repeat of their Say lines.

	One ring (user request 2026-10-11, Provisional): the phone rings once at the start; answered once (Answered stays
	true for the session), Walt stays on the line through the whole tutorial, Mart trip included (BossService holds the
	call with no proximity rule and, if it was cut anyway, resumes it Talking without a second ring). No "phone" step
	after the first one.

	Voices ahead (user request 2026-10-11): LoadingController calls PreloadVoices under the loading screen of a rookie
	(Day 1 of the run, FirstRun rules), so Walt's lines are "Loaded" when the call starts (Steps.Lines is in the order the call
	needs them).

	Dev tools (Studio Run place only, user request 2026-10-11): the dev-only `DevClient` packet (from the DevService chat
	commands, DevService/Commands/Tutorial.luau) runs here: tutorial_reset (restart the session state after the server
	reopened it in this run), tutorial_step <key> (jump to a step until the live flow passes it; "auto" = back
	to the live flow), tutorial_status (prints the debug readout), voice <text> / voice_tutorial / voice_stop (Walt's
	voice through the call's Speech, status per line: Queued/Loading/Loaded/Failed, reason, Master x Voice, fader),
	tutdebug (the TutorialDebug panel; F8 too). With dev mode on, past Day 1, or done or skipped, says
	so once in the Output (the tutorial never runs for it: /dev tutorial reset).

	PROVISIONAL: texts, IDLE, PROGRESS, ARROW_FAR, CALL_WAIT, NUDGE, TALK_TIME, TALK_MIN, REASK, CHECK_TIME, skip keys (Q, DPadDown), "a served
	sale of the tutorial customer" as the first sale, ending on the day shift end.
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
local TutorialPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TutorialPanel)
local TutorialArrow = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TutorialArrow)
local TutorialPointer = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TutorialPointer)
local TutorialDebug = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TutorialDebug)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Rules = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Rules)
local TutorialRules = require(ReplicatedStorage.shared.Tutorial.Rules)
local Beacon = require(script.Beacon)
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
-- a sale of the tutorial customer with these results is the first sale (Wrong keeps the hot dog in hand)
const SERVED: { [string]: boolean } = { Perfect = true, Complete = true, Incomplete = true }
const REASK = 15 -- s without a tutorial customer around before TutorialBegin goes out again
const CHECK_TIME = 0.9 -- s the panel chip shows the green check of a completed step
const TUTORIAL_CALL = Content.BossCallRules.Tutorial.Call
const CALL_WAIT = 12 -- s of a silent phone before the tutorial goes on without Walt (panel only)
const RUSH_TIME = 4 -- s between two step changes under which the player is rushing (no praise)
const NUDGE = 20 -- s on the same step before Walt says it again (steps without Remind)
const IDLE = 12 -- s without progress on a step with Remind before it turns urgent (and again every IDLE s)
const PROGRESS = 2 -- studs closer to the target that count as progress (walking to it resets IDLE)
const ARROW_FAR = 22 -- studs from the camera to the target from where the billboard arrow shows
const ARROW_MAX = 400 -- studs: the billboard arrow's MaxDistance (the Mart door across the street)
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
-- a plain model around an anchor outside any station (the OPEN sign stand) is marked whole up to this size (studs)
const MODEL_MAX = 12
-- a part this transparent does not show a Highlight: mark a visible piece next to it instead
const INVISIBLE = 0.95
const NEARBY = 3 -- studs around an invisible anchor part where a visible piece is looked for
const ARROW_LIFT = 0.8 -- studs between the top of the marked piece and the 3D arrow tip
const CUSTOMER_LIFT = 3.2 -- over the head: above the order bubble and the prompt pill on the neck
const EDGE_MARGIN = 56 -- px from the screen edge for the pointer
-- UI scale like the HUD: global rule (Theme.ScaleOf)
const PANEL_TOP = 50 -- px at scale 1, under the clock row (HudScreen TOP 6 + 38 + gap 6)
-- Narrow screens (under 520 px at scale 1, phone in portrait): money and day stack at the top right and would touch the
-- 260 px panel, so the panel sits under them (6 + 38 + 6 + 32 + 6 = 88)
const PANEL_TOP_NARROW = 88
const PANEL_NARROW = 520
const CASH_NAME = "Cash" -- HudPill of the money in the Hud ScreenGui
const MONEY_STEP = "money"
const MART_TALK = "mart"
-- Shopping steps (PROVISIONAL distances, studs)
const BUN = "bun"
const PACK = TutorialRules.Package -- package Tool item key of the shopping steps (pack_buns)
const POINT_TAG = "MapPoint"
const DOOR_TAG = "AutoDoor"
const MART_DOOR = "MKT-DOOR" -- MapPoint of the Mart entrance (MAP-01)
const DOOR_SEARCH = 16 -- an AutoDoor this close to MKT-DOOR is the one marked
const NEAR_DOOR = 8 -- the player reached the Mart: from here the shelf is marked
const NEAR_SHELF = 18
const NEAR_CRATE = 12 -- back at the cart: "Restock the buns"
-- Voices ahead / dev tools
const PROFILE_WAIT = 3 -- s PreloadVoices waits for the Profile packet before it gives up (Tick prepares later)
const DEBUG_BIND = "TutorialDebug"
const DEBUG_RATE = 0.25 -- s between two refreshes of the debug panel text
const VOICE_WAIT = 20 -- s the voice test waits for one line to load
const VOICE_TAIL = 0.4 -- s after a line of the voice test before the next one
const DEV_PREFIX = "[TutorialDev]"
-- Stations set record fields read here (network.md §3.5)
type SlotRecord = { Kind: string, State: string, Count: number }
-- Customers set record fields read here (network.md §3.6)
type GuestRecord = { State: string, Order: { [string]: boolean } }
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
		"PromptController",
	},
	Priority = 520,
})

function TutorialController:Setup()
	-- ended (finished, skipped or the day ran out) in this session; the profile flag follows from the server
	self.Finished = Vide.source(false) :: Vide.Source<boolean>
	-- the run went past Day 1 (latched) / the dev reset brought the tutorial back in this run
	self.PastDay1 = Vide.source(false) :: Vide.Source<boolean>
	self.Revived = Vide.source(false) :: Vide.Source<boolean>
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
	-- billboard arrow shown (the target is on screen and far from the camera)
	self.ArrowFar = Vide.source(false) :: Vide.Source<boolean>
	-- no progress on the step for IDLE s: reminder, stronger pulse (until the step changes)
	self.Urgent = Vide.source(false) :: Vide.Source<boolean>
	-- os.clock of the last progress on the step (step start, getting closer, a reminder) and the closest distance
	self.IdleAt = 0 :: number
	self.IdleDistance = math.huge :: number
	-- green check on the panel chip: a step was just completed (until CheckUntil, os.clock)
	self.Checked = Vide.source(false) :: Vide.Source<boolean>
	self.CheckUntil = 0 :: number
	self.Folder = nil :: Folder?
	-- Highlight + 3D arrow on the piece of the current step
	self.Beacon = Beacon.new(function(): Instance
		return self:FxFolder()
	end) :: Beacon.Beacon
	-- Tutorial customer: TutorialBegin sent (os.clock of the last one, 0 = never); its NpcId once seen (0 = none)
	self.AskedAt = 0 :: number
	self.GuestId = 0 :: number
	-- Walt on the line: the tutorial call was answered (from here he leads), the greeting went out, no call came
	self.Answered = false :: boolean
	self.Greeted = false :: boolean
	self.GreetPinned = false :: boolean -- the greeting survives step changes until the first action step is past
	self.SpokeAt = 0 :: number -- os.clock of the last SpeakStep (rush detection)
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
	end, function(message: string)
		self:Trace(`call: {message}`)
	end) :: Call.Call
	self.Sent = false :: boolean
	-- shopping steps after the first sale (the buns ran out); InMart = the player reached the Mart once
	self.Shopping = false :: boolean
	self.InMart = false :: boolean
	-- bun stock when the shopping steps began (they end once it goes above: whoever restocked)
	self.ShopFrom = 0 :: number
	self.Unmounts = {} :: { () -> () }
	-- Dev tools: step forced by /dev tutorial step (nil = the live flow), debug panel, voice test run, one-time note
	self.Forced = nil :: string?
	self.Debug = Vide.source(false) :: Vide.Source<boolean>
	self.DebugText = Vide.source("") :: Vide.Source<string>
	self.DebugAt = 0 :: number
	self.VoiceRun = 0 :: number
	self.DevNoted = false :: boolean
	self.Mounted = false :: boolean
end

-- Reactive -------------------------------------------------------------------------------------------------------

-- The tutorial runs on Day 1 of every run (user request 2026-10-11, Provisional; Q-### in open-questions.md), for
-- everyone, and is never saved: it has the tutorial ahead while the run is on Day 1 (PastDay1 latches once the run
-- moves on, so a return to Day 1 does not bring it back) and it did not end (finished / skipped) in this session.
-- /dev tutorial reset (Revived) ignores the day.
function TutorialController:FirstRun(): boolean
	if not self.Dependencies.PlaceController:Is("Run") then
		return false
	end
	if self.Finished() then
		return false
	end
	if self.Revived() then
		return true
	end
	return self.Dependencies.ProfileController.Ready()
		and not self.PastDay1()
		and self.Dependencies.RoundController.Day() <= 1
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

-- "STEP 3 OF 9" over the instruction
function TutorialController:StepLabel(): string
	const step = self:Step()
	return if step then `STEP {step.Number} OF {Steps.Total}` else ""
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

-- Glass is never what a step marks (a Highlight on a pane reads as "the window"): glass material, see-through or named
-- like a pane
const GLASS_TRANSPARENCY = 0.3
local function isGlass(part: BasePart): boolean
	if part.Material == Enum.Material.Glass or part.Transparency > GLASS_TRANSPARENCY then
		return true
	end
	const name = string.lower(part.Name)
	return string.find(name, "glass", 1, true) ~= nil
		or string.find(name, "pane", 1, true) ~= nil
		or string.find(name, "window", 1, true) ~= nil
		or string.find(name, "vitrine", 1, true) ~= nil
end

-- Whether a model has glass in it (a Highlight on the model would light the panes too)
local function hasGlass(model: Instance): boolean
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and isGlass(descendant) and descendant.Transparency < 1 then
			return true
		end
	end
	return false
end

-- Door parts MartDoor resolved: highlightOf marks exactly the part (never the wall model around it)
const doorPieces: { [Instance]: true } = setmetatable({}, { __mode = "k" }) :: any

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

-- The tutorial customer (rig attribute TutorialRules.Attribute, set by CustomerService): NpcId, record and rig.
-- nil = none around (not spawned yet, or its record is gone).
function TutorialController:Guest(): (number?, GuestRecord?, Model?)
	const models = self.Dependencies.CustomerController.Models
	for id, raw in self.Libs.Net.Customers:entries() do
		const model = models[id]
		if model and model:GetAttribute(TutorialRules.Attribute) == true and model:GetAttribute("NpcId") == id then
			return id, raw :: GuestRecord, model
		end
	end
	return nil, nil, nil
end

-- Asks the server for the tutorial customer (TutorialBegin); again every REASK s while none is around
function TutorialController:AskGuest()
	const now = os.clock()
	if self.AskedAt > 0 and now - self.AskedAt < REASK then
		return
	end
	self.AskedAt = now
	self.Libs.Net.TutorialBegin:fireServer()
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

-- Units of an ingredient in the cart (Stock set, record id = Content.Ingredients.IndexOf). nil = not replicated yet.
function TutorialController:StockAmount(ingredient: string): number?
	const index = Content.Ingredients.IndexOf[ingredient]
	if index == nil then
		return nil
	end
	for id, raw in self.Libs.Net.Stock:entries() do
		if id == index then
			const record = raw :: { Amount: number }
			return record.Amount
		end
	end
	return nil
end

-- Studs from the own character to an instance (math.huge = unknown)
function TutorialController:DistanceTo(instance: Instance?): number
	const root = self:Root()
	const position = if instance then positionOf(instance) else nil
	if root == nil or position == nil then
		return math.huge
	end
	return (position - root.Position).Magnitude
end

-- What marks the Mart entrance: the AutoDoor next to MapPoint MKT-DOOR, else the point part itself (nil = not
-- streamed in)
function TutorialController:MartDoor(): Instance?
	local point: BasePart? = nil
	for _, instance in CollectionService:GetTagged(POINT_TAG) do
		if
			instance:IsA("BasePart")
			and instance:GetAttribute("PointId") == MART_DOOR
			and instance:IsDescendantOf(Workspace)
		then
			point = instance
			break
		end
	end
	if point == nil then
		return nil
	end
	-- the nearest AutoDoor leaf that is not glass; else the nearest leaf of any kind (its model holds the solid door)
	local solid: BasePart? = nil
	local solidDistance = DOOR_SEARCH
	local anyLeaf: BasePart? = nil
	local anyDistance = DOOR_SEARCH
	for _, door in CollectionService:GetTagged(DOOR_TAG) do
		if not door:IsA("BasePart") or not door:IsDescendantOf(Workspace) then
			continue
		end
		const distance = (door.Position - point.Position).Magnitude
		if distance < anyDistance then
			anyLeaf, anyDistance = door, distance
		end
		if distance < solidDistance and not isGlass(door) then
			solid, solidDistance = door, distance
		end
	end
	if solid ~= nil then
		doorPieces[solid] = true
		return solid
	end
	-- only glass leaves: the door itself is a solid part of the same model (a leaf named door/leaf, not frame/wall)
	const model = if anyLeaf then anyLeaf:FindFirstAncestorOfClass("Model") else nil
	if model ~= nil then
		local best: BasePart? = nil
		local bestDistance = math.huge
		for _, descendant in model:GetDescendants() do
			if not descendant:IsA("BasePart") or isGlass(descendant) or descendant.Transparency >= INVISIBLE then
				continue
			end
			const name = string.lower(descendant.Name)
			if
				(string.find(name, "door", 1, true) == nil and string.find(name, "leaf", 1, true) == nil)
				or string.find(name, "frame", 1, true) ~= nil
				or string.find(name, "wall", 1, true) ~= nil
				or string.find(name, "jamb", 1, true) ~= nil
				or string.find(name, "header", 1, true) ~= nil
				or string.find(name, "sign", 1, true) ~= nil
			then
				continue
			end
			const distance = (descendant.Position - point.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = descendant, distance
			end
		end
		if best ~= nil then
			doorPieces[best] = true
			return best
		end
	end
	-- no solid door piece: the invisible MKT-DOOR point (highlightOf looks for a solid piece next to it, never glass)
	return point
end

-- The "restock" anchor of the bun crate on the vehicle in use
function TutorialController:CrateAnchor(): Instance?
	return self:Anchor("restock", false, function(anchor)
		const own = anchor:GetAttribute("Ingredient")
		if own ~= nil then
			return own == BUN
		end
		const station = ancestorWith(anchor, function(instance)
			return CollectionService:HasTag(instance, STATION_TAG)
		end)
		return station ~= nil
			and (station:GetAttribute("Ingredient") == BUN or station:GetAttribute("StationKind") == "bun_crate")
	end)
end

-- Shopping step and its target, from the hand, the bun stock and where the player stands
function TutorialController:DecideShop(): (string, Instance?, string)
	const held = self:Held()
	if held and held.Item == PACK then
		const crate = self:CrateAnchor()
		if crate ~= nil and self:DistanceTo(crate) <= NEAR_CRATE then
			return "restock", crate, ""
		end
		return "mart_back", crate, ""
	end
	const shelf = self:Anchor("buy_package", true, function(anchor)
		return anchor:GetAttribute("Package") == PACK
	end)
	const door = self:MartDoor()
	if not self.InMart and (self:DistanceTo(door) <= NEAR_DOOR or self:DistanceTo(shelf) <= NEAR_SHELF) then
		self.InMart = true
	end
	if self.InMart then
		return "mart_buy", shelf or door, ""
	end
	return "mart_go", door or shelf, ""
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
		self:Trace(
			`voiced {tostring(voiced)} (answered {tostring(self.Answered)}, call {self:CallState()}, greeted {tostring(self.Greeted)})`
		)
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

-- Walt's lines for a step change, in step with the player (user request 2026-10-11: rushing the tutorial). The step
-- on screen is the one Walt talks about: a change cuts the line in progress (voice and subtitle) and drops what was
-- queued, then says the praise of the step left (only when Walt was idle and the player is not rushing, and no step
-- with lines was skipped) and the lines of the new step. Exceptions: the greeting is never cut before the first action
-- step is past; a silent waiting row of the same number (slicing) lets the line in progress finish.
function TutorialController:SpeakStep(before: Steps.Step?, after: Steps.Step?)
	if after == nil then
		return
	end
	if not self:Voiced() then
		self:Trace(`step {after.Key}: Walt not on the line, no lines (answered {tostring(self.Answered)}, call {self:CallState()})`)
		return
	end
	const now = os.clock()
	const lastAt = self.SpokeAt
	self.SpokeAt = now
	const say = after.Say or {}
	const afterIndex = Steps.IndexOf[after.Key] or 0
	if not self.Greeted then
		self.Greeted = true
		self.GreetPinned = true
		self.Call.Queue(Steps.Greeting, true)
		self.Call.Queue(say)
		self:Trace(`step {after.Key}: greeting + {#say} line(s) queued`)
		return
	end
	if before == nil then
		self.Call.Queue(say)
		return
	end
	const beforeIndex = Steps.IndexOf[before.Key] or 0
	if self.GreetPinned and afterIndex > (Steps.IndexOf.order or 0) then
		self.GreetPinned = false -- past the first action: the greeting is obsolete
	end
	if self.GreetPinned then
		-- the greeting stays (at most the unspoken lines of an older step are dropped)
		self.Call.Replace(say)
		self:Trace(`step {after.Key}: greeting kept, {#say} line(s) replaced`)
		return
	end
	if #say == 0 and after.Number == before.Number then
		return -- silent waiting row of the same step: what Walt is saying still holds
	end
	const lines: { string } = {}
	if before.Done and afterIndex > beforeIndex and afterIndex - beforeIndex <= 1 and not self.Call.Busy()
		and now - lastAt >= RUSH_TIME then
		table.insert(lines, before.Done)
	end
	for _, text in say do
		table.insert(lines, text)
	end
	self:Trace(`step {after.Key}: interrupt, {#lines} line(s)`)
	self.Call.Interrupt(lines)
end

-- Before Walt is on the line: the phone step (or waiting for the call). nil = the call is on, or never came.
function TutorialController:DecidePhone(): (string?, Instance?)
	if self.Answered then
		return nil, nil
	end
	const state = self:CallState()
	if state == "talking" then
		self:Trace("answered: the tutorial call is talking")
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

-- Current step and the anchor to point at: the live flow, or the step forced by /dev tutorial step until the live
-- flow passes it
function TutorialController:Decide(): (string, Instance?, string)
	const key, target, item = self:DecideLive()
	const forced, forcedTarget, forcedItem = self:DecideForced(key)
	if forced ~= nil then
		return forced, forcedTarget, forcedItem
	end
	return key, target, item
end

-- Current step and the anchor to point at, from the replicated state
function TutorialController:DecideLive(): (string, Instance?, string)
	const phoneKey, phoneTarget = self:DecidePhone()
	if phoneKey then
		return phoneKey, phoneTarget, ""
	end

	-- after the first sale with the buns gone: the shopping steps
	if self.Shopping then
		return self:DecideShop()
	end

	-- Walt is on the line (or never called): the tutorial customer comes
	const guestId, guest, rig = self:Guest()
	if guestId == nil or guest == nil or guest.State == "Leaving" then
		self:AskGuest()
		return "wait_customer", nil, ""
	end
	self.GuestId = guestId
	local function onGuest(anchor: Instance): boolean
		return npcIdOf(anchor) == guestId
	end
	if guest.State == "Arriving" or guest.State == "Queued" then
		-- walking up: mark the customer itself
		return "wait_customer", rig, ""
	end
	if guest.State == "Ordering" then
		return "order", self:Anchor("take_order", false, onGuest) or rig, ""
	end

	const held = self:Held()
	if held and held.Item == HOT_DOG then
		-- a topping they did not ask for: Wrong at the counter, throw it away
		for key in held.Toppings do
			if not guest.Order[key] then
				return "discard", self:Anchor("discard", false), ""
			end
		end
		for _, key in Content.Ingredients.ToppingKeys do
			if guest.Order[key] and not held.Toppings[key] then
				const row = Content.Ingredients.ByKey[key]
				return "toppings",
					self:Anchor("topping_add", false, function(anchor)
						return anchor:GetAttribute("Ingredient") == key
					end),
					if row then row.Name else key
			end
		end
		-- the hot dog is right: the drawer must be open to sell (Prep: open the shop first)
		if Vide.untrack(self.Dependencies.RoundController.Phase) == "Prep" then
			return "open", self:Anchor("open_sign", false), ""
		end
		return "serve", self:Anchor("serve", false, onGuest) or rig, ""
	end

	-- the shop opens right after the order (never in the middle of serving); `open` below covers a hot dog already in hand
	if Vide.untrack(self.Dependencies.RoundController.Phase) == "Prep" then
		return "open_first", self:Anchor("open_sign", false), ""
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

local function extent(instance: Instance): number
	if instance:IsA("Model") then
		const _, size = instance:GetBoundingBox()
		return math.max(size.X, size.Y, size.Z)
	elseif instance:IsA("BasePart") then
		return math.max(instance.Size.X, instance.Size.Y, instance.Size.Z)
	end
	return math.huge
end

-- Outermost part or model holding the anchor below its station (one pot of a toppings station), or nil
local function pieceOf(anchor: Instance): Instance?
	local best: Instance? = if anchor:IsA("BasePart") then anchor else nil
	local current = anchor.Parent
	while current and current ~= Workspace and not CollectionService:HasTag(current, STATION_TAG) do
		if current:IsA("BasePart") or current:IsA("Model") then
			best = current
		end
		current = current.Parent
	end
	return best
end

-- Nearest visible small piece around an invisible anchor part (a Mart shelf anchor: the rack or the packs on it), or
-- nil. Cached per anchor part (the map does not move; a weak table forgets parts that are gone).
const nearbyCache: { [BasePart]: BasePart | false } = setmetatable({}, { __mode = "k" }) :: any
local function visibleNear(host: BasePart): BasePart?
	const cached = nearbyCache[host]
	if cached ~= nil then
		return if cached and cached:IsDescendantOf(Workspace) then cached else nil
	end
	const params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { host }
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, found in Workspace:GetPartBoundsInRadius(host.Position, NEARBY, params) do
		if found.Transparency >= INVISIBLE or extent(found) > HIGHLIGHT_MAX or isGlass(found) then
			continue
		end
		-- never a character (a player or an NPC walking by)
		const rig = found:FindFirstAncestorOfClass("Model")
		if rig and rig:FindFirstChildOfClass("Humanoid") then
			continue
		end
		const distance = (found.Position - host.Position).Magnitude
		if distance < bestDistance then
			best, bestDistance = found, distance
		end
	end
	nearbyCache[host] = best or false
	return best
end

-- What the Highlight and the arrow mark: the customer rig, the exact pot of a per-ingredient anchor (one topping of
-- the toppings station), a small station model (the grill, the bun crate, the board), else the part of the anchor
local function highlightOf(anchor: Instance): Instance?
	if anchor:IsA("Model") and typeof(anchor:GetAttribute("NpcId")) == "number" then
		return anchor
	end
	const rig = ancestorWith(anchor, function(instance)
		return typeof(instance:GetAttribute("NpcId")) == "number" and instance:IsA("Model")
	end)
	if rig then
		return rig
	end
	if typeof(anchor:GetAttribute("Ingredient")) == "string" then
		const piece = pieceOf(anchor)
		if piece and extent(piece) <= HIGHLIGHT_MAX then
			return piece
		end
	end
	const station = ancestorWith(anchor, function(instance)
		return CollectionService:HasTag(instance, STATION_TAG)
	end)
	-- the Mart door: exactly its solid part (the wall model around it has the windows)
	if doorPieces[anchor] and anchor:IsA("BasePart") and not isGlass(anchor) then
		return anchor
	end
	if station and station:IsA("Model") and extent(station) <= HIGHLIGHT_MAX and not hasGlass(station) then
		return station
	end
	const parent = anchor.Parent
	const host: BasePart? = if anchor:IsA("BasePart")
		then anchor
		elseif parent and parent:IsA("BasePart") then parent
		else nil
	if station == nil then
		-- outside any station (the OPEN sign: an Attachment on one part of its stand): the whole small model around it
		const model = ancestorWith(anchor, function(instance)
			return instance:IsA("Model")
		end)
		-- never the whole cart / trailer (a vehicle model can be that small)
		if
			model
			and not CollectionService:HasTag(model, VEHICLE_TAG)
			and extent(model) <= MODEL_MAX
			and not hasGlass(model)
		then
			return model
		end
	end
	if host then
		if host.Transparency < INVISIBLE and not isGlass(host) then
			return host
		end
		-- never glass: a solid piece next to it, else the (invisible) anchor part itself
		return visibleNear(host) or (if isGlass(host) and host.Transparency < INVISIBLE then nil else host)
	end
	-- a plain model target (the Mart door)
	return station or (if anchor:IsA("Model") then anchor else nil)
end

-- Pulsing Highlight + 3D arrow on what the anchor belongs to (Beacon.luau); nil clears both
function TutorialController:SetHighlight(anchor: Instance?)
	const adornee = if anchor then highlightOf(anchor) else nil
	const lift = if adornee and adornee:IsA("Model") and typeof(adornee:GetAttribute("NpcId")) == "number"
		then CUSTOMER_LIFT
		else ARROW_LIFT
	self.Beacon.Set(adornee, lift)
end

-- Whether a prompt anchor belongs to the current step (for PromptController to hide or dim the others). true for
-- every anchor while the tutorial does not run or the step has no world target.
function TutorialController:Focuses(anchor: Instance): boolean
	if not Vide.untrack(self.Running) then
		return true
	end
	const target = Vide.untrack(self.Target)
	if target == false then
		return true
	end
	if anchor == target then
		return true
	end
	-- same piece (the customer rig with its two anchors, one pot): the step's own action only
	const step = Steps.ByKey[Vide.untrack(self.StepKey)]
	return step ~= nil
		and anchor:GetAttribute("PromptAction") == step.Action
		and highlightOf(anchor) == highlightOf(target)
end

-- TutorialPromptGate (user request 2026-10-11: "too many prompts, confusing"): while the tutorial runs for this player,
-- only the prompts of the current step's action, of the next step(s) (Steps.NextActions: so getting ahead never locks
-- the player out) and Steps.AlwaysActions show. Everything shows again the moment the tutorial is not running
-- (Finish / skip / past Day 1 / night / cinematic). Presentation only: the server still decides every Interact.
function TutorialController:PromptAllowed(anchor: Instance): boolean
	if not Vide.untrack(self.Running) or Vide.untrack(self.Finished) or not self:FirstRun() then
		return true
	end
	const action = anchor:GetAttribute("PromptAction")
	if typeof(action) ~= "string" then
		return true
	end
	if table.find(Steps.AlwaysActions, action) ~= nil then
		return true
	end
	const key = Vide.untrack(self.StepKey)
	const step = Steps.ByKey[key]
	if step == nil then
		return true
	end
	if step.Action == action then
		return true
	end
	const next = Steps.NextActions[key]
	return next ~= nil and table.find(next, action) ~= nil
end

function TutorialController:ClearGuidance()
	Vide.batch(function()
		self.Target(false)
		self.PointerShown(false)
		self.ArrowFar(false)
		self.Spot(false)
	end)
	self:SetHighlight(nil)
	self:ResetIdle()
end

-- Billboard arrow over the target only from far away (the 3D arrow reads fine up close)
function TutorialController:SetFar(far: boolean)
	if Vide.untrack(self.ArrowFar) ~= far then
		self.ArrowFar(far)
	end
end

-- Edge pointer toward the target while it is off screen (every frame; the overlay ignores the GUI inset, so its
-- pixels are viewport pixels). Its margin follows the UI scale, so the scaled badge never leaves the screen.
function TutorialController:UpdatePointer()
	const target = Vide.untrack(self.Target)
	const camera = Workspace.CurrentCamera
	const position = if target then positionOf(target) else nil
	if position == nil or camera == nil or not Vide.untrack(self.Running) then
		if Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
		self:SetFar(false)
		return
	end
	const margin = EDGE_MARGIN * Vide.untrack(self.Scale)
	const viewport = camera.ViewportSize
	const point, onScreen = camera:WorldToViewportPoint(position)
	-- steps with AlwaysArrow (the OPEN sign) keep the billboard arrow up close too
	const step = Steps.ByKey[Vide.untrack(self.StepKey)]
	const always = step ~= nil and step.AlwaysArrow == true
	self:SetFar(onScreen and (always or (position - camera.CFrame.Position).Magnitude > ARROW_FAR))
	const centre = viewport / 2
	local delta = Vector2.new(point.X, point.Y) - centre
	if point.Z < 0 then
		-- behind the camera: the projection is mirrored
		delta = -delta
	end
	const inside = onScreen
		and point.X > margin
		and point.X < viewport.X - margin
		and point.Y > margin
		and point.Y < viewport.Y - margin
	if inside or delta.Magnitude < 1 then
		if Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
		return
	end
	const halfX = math.max(viewport.X / 2 - margin, 1)
	const halfY = math.max(viewport.Y / 2 - margin, 1)
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
	const scale = Theme.ScaleOf(camera.ViewportSize)
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
		-- step completed: short sound + green check on the panel chip
		self.Dependencies.AudioController:Play(STEP_SOUND)
		self.CheckUntil = os.clock() + CHECK_TIME
		if not Vide.untrack(self.Checked) then
			self.Checked(true)
		end
	end
	if previous ~= key then
		self.StepAt = os.clock()
		self:ResetIdle()
		self:SpeakStep(before, after)
	end
end

-- No progress ----------------------------------------------------------------------------------------------------

-- A new step (or the tutorial stopped): not urgent, the IDLE count starts over
function TutorialController:ResetIdle()
	self.IdleAt = os.clock()
	self.IdleDistance = math.huge
	if Vide.untrack(self.Urgent) then
		self.Urgent(false)
	end
	self.Beacon.Urge(false)
end

-- Every tick on a step that waits for the player: getting PROGRESS studs closer to the target is progress; IDLE s
-- without it turns the step urgent (Remind line, stronger pulse), again every IDLE s. Steps without Remind keep the
-- NUDGE repeat of their Say lines.
function TutorialController:TickIdle(step: Steps.Step, target: Instance?)
	const now = os.clock()
	const remind = step.Remind
	if remind == nil then
		if step.Say and not self.Call.Busy() and now - self.StepAt > NUDGE and self:Voiced() then
			self.StepAt = now
			self.Call.Queue(step.Say)
		end
		return
	end
	const distance = self:DistanceTo(target)
	if distance < math.huge and distance < self.IdleDistance - PROGRESS then
		self.IdleDistance = distance
		self.IdleAt = now
	end
	if now - self.IdleAt < IDLE then
		return
	end
	self.IdleAt = now
	if not Vide.untrack(self.Urgent) then
		self.Urgent(true)
	end
	self.Beacon.Urge(true)
	if self:Voiced() and not self.Call.Busy() then
		self.Call.Queue({ remind })
	end
end

-- The money pill of the HUD (spotlight target of the UI step)
local function cashPill(): GuiObject?
	const gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	const hud = if gui then gui:FindFirstChild("Hud") else nil
	const pill = if hud then hud:FindFirstChild(CASH_NAME, true) else nil
	return if pill and pill:IsA("GuiObject") then pill else nil
end

-- Sale packet: the tutorial customer paid (whoever served it) = the first sale
function TutorialController:OnSale(npc: number, result: string)
	if not Vide.untrack(self.Running) or not SERVED[result] or npc ~= self.GuestId or self.GuestId == 0 then
		return
	end
	const current = Steps.ByKey[Vide.untrack(self.StepKey)]
	if current and current.Talk then
		return
	end
	self.Forced = nil
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

-- Next talk step; after the last one the tutorial is done. After "money": the shopping steps when the buns ran out
-- (the tutorial stock of one bun), else the talk step "mart".
function TutorialController:NextTalk()
	const current = Vide.untrack(self.StepKey)
	if current == MONEY_STEP then
		self.Spot(false)
		if self:StockAmount(BUN) == 0 then
			self.Shopping = true
			self.ShopFrom = 0
			const key, target, item = self:DecideShop()
			self:SetStep(key, target, item)
		else
			self:SetStep(MART_TALK, nil, "")
		end
		return
	end
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
	self.Forced = nil
	if self:Voiced() then
		if reason == "done" then
			-- the praise of the last step first ("Stocked up!"), then the goodbye
			const lines: { string } = {}
			const last = Steps.ByKey[Vide.untrack(self.StepKey)]
			if last and last.Done then
				table.insert(lines, last.Done)
			end
			for _, text in Steps.Goodbye do
				table.insert(lines, text)
			end
			self.Call.Replace(lines)
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
	if Vide.untrack(self.Checked) and os.clock() >= self.CheckUntil then
		self.Checked(false)
	end
	self:RefreshDebug()
	-- latch: once the run is past Day 1 the tutorial never comes back in this run
	if
		not Vide.untrack(self.PastDay1)
		and Vide.untrack(self.Dependencies.RoundController.Ready)
		and Vide.untrack(self.Dependencies.RoundController.Day) > 1
	then
		self.PastDay1(true)
	end
	const firstRun = Vide.untrack(function(): boolean
		return self:FirstRun()
	end)
	if not firstRun then
		self:NoteDone()
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
	self:ApplyForced()
	const current = Steps.ByKey[Vide.untrack(self.StepKey)]
	if current and current.Talk then
		self:TickTalk()
		return
	end
	-- shopping over: the buns are back in the crate (whoever restocked)
	if self.Shopping and (self:StockAmount(BUN) or 0) > self.ShopFrom then
		self:Finish("done")
		return
	end
	const key, target, item = self:Decide()
	self:SetStep(key, target, item)
	-- reminder: no progress for IDLE s (Remind), or the same waiting step for NUDGE s and Walt quiet
	const step = Steps.ByKey[key]
	if step then
		self:TickIdle(step, target)
	end
end

-- Voices ahead ---------------------------------------------------------------------------------------------------

-- LoadingController, under the loading screen: Walt's tutorial lines loaded ahead for a rookie (yields until settled
-- or `timeout` s; the rest keeps loading in the background). Waits up to PROFILE_WAIT s (inside `timeout`) for the
-- Profile packet; a veteran, another place or a late profile get progress 1 at once (Tick prepares them later).
-- true = the lines were queued.
function TutorialController:PreloadVoices(timeout: number, progress: ((number) -> ())?): boolean
	const started = os.clock()
	const profile = self.Dependencies.ProfileController
	while not Vide.untrack(profile.Ready) and os.clock() - started < math.min(PROFILE_WAIT, timeout) do
		task.wait(0.1)
	end
	-- every run starts on Day 1 with the tutorial (no saved flag); a run already past Day 1 skips the preload
	const rookie = self.Dependencies.PlaceController:Is("Run")
		and Vide.untrack(self.Dependencies.RoundController.Day) <= 1
		and not Vide.untrack(self.PastDay1)
	if not rookie then
		if progress ~= nil then
			progress(1)
		end
		return false
	end
	self.Prepared = true
	self.Call.Preload(Steps.Lines, math.max(timeout - (os.clock() - started), 1), progress)
	return true
end

-- Dev tools ------------------------------------------------------------------------------------------------------

function TutorialController:IsDev(): boolean
	return self.Dependencies.PlaceController:IsDev()
end

-- One diagnostic line per transition of the call (dev mode only)
function TutorialController:Trace(message: string)
	if self:IsDev() then
		print(`{DEV_PREFIX} {message}`)
	end
end

-- Dev mode: says once why the tutorial is off in this run (nothing is saved: Day 1 of every run has it)
function TutorialController:NoteDone()
	if self.DevNoted or not self:IsDev() then
		return
	end
	if not self.Dependencies.PlaceController:Is("Run") or not Vide.untrack(self.Dependencies.RoundController.Ready) then
		return
	end
	const day = Vide.untrack(self.Dependencies.RoundController.Day)
	const reason = if Vide.untrack(self.Finished)
		then "done or skipped this run"
		elseif Vide.untrack(self.PastDay1) or day > 1 then `day {day} is past day 1`
		else nil
	if reason == nil then
		return
	end
	self.DevNoted = true
	print(`{DEV_PREFIX} tutorial off: {reason}. "/dev tutorial reset" runs it again in this run.`)
end

-- The step forced by /dev tutorial step and its target, while the live flow (`live`) has not passed it
function TutorialController:DecideForced(live: string): (string?, Instance?, string)
	const key = self.Forced
	if key == nil then
		return nil, nil, ""
	end
	const step = Steps.ByKey[key]
	const passed = (Steps.IndexOf[live] or 0) > (Steps.IndexOf[key] or 0)
	const opened = (key == "open" or key == "open_first") and Vide.untrack(self.Dependencies.RoundController.Phase) ~= "Prep"
	if step == nil or passed or opened then
		self.Forced = nil
		print(`{DEV_PREFIX} forced step {key} done: back to the live flow ({live})`)
		return nil, nil, ""
	end
	const guestId, _, rig = self:Guest()
	local function onGuest(anchor: Instance): boolean
		return guestId ~= nil and npcIdOf(anchor) == guestId
	end
	if key == "wait_customer" then
		return key, rig, ""
	elseif key == "order" or key == "serve" then
		return key, self:Anchor(step.Action or "", false, onGuest) or rig, ""
	elseif key == "toppings" then
		const topping = TutorialRules.Order[1]
		const row = Content.Ingredients.ByKey[topping]
		return key,
			self:Anchor("topping_add", false, function(anchor)
				return anchor:GetAttribute("Ingredient") == topping
			end),
			if row then row.Name else topping
	end
	const action = step.Action
	return key, if action then self:Anchor(action, false) else nil, ""
end

-- Steps that are not decided from the world (talk, shopping, phone) take effect at once; the others stay forced
-- (DecideForced) until the live flow passes them
function TutorialController:ApplyForced()
	const key = self.Forced
	if key == nil then
		return
	end
	const step = Steps.ByKey[key]
	if step == nil then
		self.Forced = nil
		return
	end
	if table.find(Steps.Shopping, key) ~= nil then
		self.Forced = nil
		self.Shopping = true
		self.InMart = key ~= "mart_go"
		self.ShopFrom = self:StockAmount(BUN) or 0
		Vide.batch(function()
			self.CashRevealed(true)
			self.ClockRevealed(true)
		end)
		const shopKey, target, item = self:DecideShop()
		self:SetStep(shopKey, target, item)
		return
	end
	self.Shopping = false
	if step.Talk then
		self.Forced = nil
		if key == MONEY_STEP then
			Vide.batch(function()
				self.CashRevealed(true)
				self.ClockRevealed(true)
			end)
		end
		self:SetStep(key, nil, "")
		return
	end
	if key == "phone" or key == "wait_call" then
		self.Forced = nil
		self.Answered = false
		self.Uncalled = false
		self.WaitStarted = 0
	end
end

-- Effective voice volume and the state of the call's text-to-speech, one line
function TutorialController:VolumeText(): string
	const volumes = self.Dependencies.AudioController.Volumes
	const master = volumes.Master or 1
	const voice = volumes.Voice or 1
	const stats = self.Call.Voice().Stats()
	const fader = if stats.Fader ~= nil then string.format("%.2f", stats.Fader) else "none yet"
	const tts = if stats.Enabled
		then "on"
		else `OFF ({if stats.OffReason ~= "" then stats.OffReason else "destroyed"})`
	return string.format("master %.2f x voice %.2f = %.2f, fader %s, tts %s", master, voice, master * voice, fader, tts)
end

local function nameOf(instance: Instance?): string
	if instance == nil then
		return "none"
	end
	if instance.Parent == nil then
		return `{instance.Name} (gone)`
	end
	const full = instance:GetFullName()
	return if #full > 60 then "..." .. string.sub(full, -57) else full
end

local function flag(value: boolean): string
	return if value then "yes" else "no"
end

-- Debug readout (panel and /dev tutorial)
function TutorialController:DebugLines(): string
	const profile = self.Dependencies.ProfileController
	const round = self.Dependencies.RoundController
	const boss = self.Dependencies.BossController
	const key = Vide.untrack(self.StepKey)
	const step = Steps.ByKey[key]
	const target = Vide.untrack(self.Target)
	const stats = self.Call.Voice().Stats()
	const guestId, guest = self:Guest()
	const firstRun = Vide.untrack(function(): boolean
		return self:FirstRun()
	end)
	const gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	const panel = if gui then gui:FindFirstChild("Tutorial") else nil
	const guestText = if guestId ~= nil then `{guestId} {if guest then guest.State else "?"}` else "none"
	return table.concat({
		`profile    ready {flag(Vide.untrack(profile.Ready))}  day {Vide.untrack(round.Day)}  past day 1 {flag(Vide.untrack(self.PastDay1))}  revived {flag(Vide.untrack(self.Revived))}  finished {flag(Vide.untrack(self.Finished))}`,
		`first run  {flag(firstRun)}  running {flag(Vide.untrack(self.Running))}  cinematic {flag(Vide.untrack(Cinematic.Active))}`,
		`round      {Vide.untrack(round.Phase)}  ready {flag(Vide.untrack(round.Ready))}  night {flag(Vide.untrack(round.IsNight))}`,
		`step       {if key ~= "" then key else "-"} ({if step then step.Number else 0}/{Steps.Total})  forced {self.Forced or "-"}  shop {flag(self.Shopping)}`,
		`call       {self:CallState()}  boss {Vide.untrack(boss.State)} {Vide.untrack(boss.Call)}`,
		`answered   {flag(self.Answered)}  voiced {flag(self:Voiced())}  greeted {flag(self.Greeted)}  uncalled {flag(self.Uncalled)}  held {flag(self.Holding)}`,
		`target     {nameOf(if target then target else nil)}`,
		`beacon     mounted {flag(self.Beacon.Mounted())}  marked {nameOf(self.Beacon.Marked())}`,
		`arrow      far {flag(Vide.untrack(self.ArrowFar))}  pointer {flag(Vide.untrack(self.PointerShown))}  panel {flag(self.Mounted and panel ~= nil)}`,
		`guest      {guestText}`,
		`voice      queued {stats.Queued}  loading {stats.Loading}  loaded {stats.Loaded}  failed {stats.Failed}  waiting {stats.Waiting}`,
		`lines      to say {self.Call.Pending()}  busy {flag(self.Call.Busy())}`,
		`volume     {self:VolumeText()}`,
	}, "\n")
end

function TutorialController:RefreshDebug()
	if not Vide.untrack(self.Debug) then
		return
	end
	const now = os.clock()
	if now - self.DebugAt < DEBUG_RATE then
		return
	end
	self.DebugAt = now
	const text = self:DebugLines()
	if text ~= Vide.untrack(self.DebugText) then
		self.DebugText(text)
	end
end

function TutorialController:ToggleDebug()
	self.Debug(not Vide.untrack(self.Debug))
	self.DebugAt = 0
	self:RefreshDebug()
	print(`{DEV_PREFIX} debug panel {if Vide.untrack(self.Debug) then "on" else "off"}`)
end

-- /dev tutorial reset (after the server reopened the tutorial in this run): the session state starts over
function TutorialController:DevReset()
	self.VoiceRun += 1
	self.Call.Cut()
	if self.Holding then
		self.Holding = false
		self.Dependencies.BossController:Hold(false)
	end
	self.DevNoted = false
	Vide.batch(function()
		self.Revived(true)
		self.Finished(false)
		self.Running(false)
		self.StepKey("")
		self.Item("")
		self.CashRevealed(false)
		self.ClockRevealed(false)
		self.Spot(false)
	end)
	self:ClearGuidance()
	self.Answered = false
	self.Greeted = false
	self.GreetPinned = false
	self.SpokeAt = 0
	self.Uncalled = false
	self.WaitStarted = 0
	self.AskedAt = 0
	self.GuestId = 0
	self.StepAt = 0
	self.Sent = false
	self.Shopping = false
	self.InMart = false
	self.ShopFrom = 0
	self.Forced = nil
	self.DevNoted = false
	print(`{DEV_PREFIX} tutorial reset: it starts on the next day Prep/Open tick (phone first)`)
end

-- /dev voice: says each text with Walt's voice (the call's Speech), printing the load status of every line
function TutorialController:VoiceTest(texts: { string })
	self.VoiceRun += 1
	const run = self.VoiceRun
	task.spawn(function()
		const speech = self.Call.Voice()
		const lines: { Content.CutsceneBeat } = {}
		for _, text in texts do
			table.insert(lines, self.Call.Line(text))
		end
		speech.Prepare(lines)
		print(`{DEV_PREFIX} voice test: {#lines} line(s); {self:VolumeText()}`)
		local voiced = 0
		for index, line in lines do
			if self.VoiceRun ~= run then
				print(`{DEV_PREFIX} voice test stopped`)
				return
			end
			const text = line.Text or ""
			const started = os.clock()
			local last = ""
			local status = speech.Fetch(line)
			while (status == "Queued" or status == "Loading") and os.clock() - started < VOICE_WAIT do
				if status ~= last then
					last = status
					print(`{DEV_PREFIX} {index}/{#lines} {status}: "{text}"`)
				end
				task.wait(0.1)
				if self.VoiceRun ~= run then
					print(`{DEV_PREFIX} voice test stopped`)
					return
				end
				status = speech.Fetch(line)
			end
			const reason = speech.Reason(line)
			const length = speech.Length(line)
			const why = if reason ~= "" then ` ({reason})` else ""
			const span = if length ~= nil then string.format("%.1f s", length) else "?"
			print(
				`{DEV_PREFIX} {index}/{#lines} {status} after {string.format("%.1f", os.clock() - started)} s{why}, length {span}: "{text}"; {self:VolumeText()}`
			)
			if status == "Loaded" then
				voiced += 1
				speech.Say(line)
				task.wait((length or 2) + VOICE_TAIL)
			end
		end
		print(`{DEV_PREFIX} voice test done: {voiced}/{#lines} voiced`)
	end)
end

-- DevClient packet (dev mode only; DevService/Commands/Tutorial.luau)
function TutorialController:OnDev(command: string, text: string)
	if not self:IsDev() then
		return
	end
	if command == "tutorial_reset" then
		self:DevReset()
	elseif command == "tutorial_step" then
		if text == "auto" then
			self.Forced = nil
			print(`{DEV_PREFIX} back to the live flow`)
			return
		end
		if Steps.ByKey[text] == nil then
			const keys: { string } = {}
			for _, step in Steps.List do
				table.insert(keys, step.Key)
			end
			warn(`{DEV_PREFIX} unknown step "{text}"; steps: {table.concat(keys, ", ")}, auto`)
			return
		end
		const firstRun = Vide.untrack(function(): boolean
			return self:FirstRun()
		end)
		if not firstRun then
			warn(`{DEV_PREFIX} the tutorial is not on for this profile: "/dev tutorial reset" first`)
			return
		end
		self.Forced = text
		print(`{DEV_PREFIX} step {text} forced (until the live flow passes it; "/dev tutorial step auto" = live flow)`)
	elseif command == "tutorial_status" then
		print(`{DEV_PREFIX} status\n{self:DebugLines()}`)
	elseif command == "voice" then
		self:VoiceTest({ text })
	elseif command == "voice_tutorial" then
		self:VoiceTest(Steps.Lines)
	elseif command == "voice_stop" then
		self.VoiceRun += 1
		self.Call.Voice().Stop()
	elseif command == "tutdebug" then
		self:ToggleDebug()
	end
end

-- F8 toggles the debug panel (dev mode only; "/dev tutdebug" from the chat on any device)
function TutorialController:BindDebug()
	if not self:IsDev() then
		return
	end
	self.Dependencies.InputController
		:Bind({
			Name = DEBUG_BIND,
			Key = Enum.KeyCode.F8,
		})
		.OnPress(function()
			self:ToggleDebug()
		end)
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
		return self.Scale()
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
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
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
				Label = function()
					return self:StepLabel()
				end,
				Done = self.Checked,
				-- no progress for a while: the short reminder in place of the hint
				Hint = function()
					const step = self:Step()
					if step == nil then
						return ""
					end
					return if self.Urgent() and step.Remind then step.Remind else step.Hint
				end,
				Urgent = self.Urgent,
				SkipText = function()
					return self:SkipText()
				end,
				OnSkip = function()
					self:Skip()
				end,
				Scale = scale,
				-- under the clock row, scaled like the HUD
				Position = function()
					const s = scale()
					const camera = workspace.CurrentCamera
					const narrow = camera ~= nil and camera.ViewportSize.X / s < PANEL_NARROW
					return UDim2.new(0.5, 0, 0, (if narrow then PANEL_TOP_NARROW else PANEL_TOP) * s)
				end,
			}),
		})
		panel.Parent = playerGui

		-- Spotlight in a ScreenGui with the HUD's insets (the money pill's ScreenGui): both frames share one origin, so
		-- the hole sits exactly on the pill on any device / top bar / UI scale; its dim bands overscan the insets
		-- (playtest 2026-10-11: undimmed strip at the top, hole off the pill)
		const focus = Vide.create("ScreenGui")({
			Name = "TutorialSpotlight",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
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
		})
		focus.Parent = playerGui

		-- Edge pointer: viewport pixels (WorldToViewportPoint), so the whole screen with no inset
		const overlay = Vide.create("ScreenGui")({
			Name = "TutorialOverlay",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 5,
			Enabled = function()
				return not Cinematic.Active()
			end,
			TutorialPointer({
				Shown = function()
					return shown() and self.PointerShown()
				end,
				Position = self.PointerAt,
				Angle = self.PointerAngle,
				Scale = scale,
				Strong = self.Urgent,
			}),
		})
		overlay.Parent = playerGui

		-- Screen-sized bouncing arrow over the target (Beacon's tip part) while it is far from the camera; straight in
		-- PlayerGui (a BillboardGui does not draw inside a ScreenGui)
		const arrow = TutorialArrow({
			Name = "TutorialWorldArrow",
			Adornee = function(): Instance?
				return if self.Target() ~= false then self.Beacon.Tip else nil
			end,
			Shown = function()
				return shown() and self.ArrowFar() and not Cinematic.Active()
			end,
			Offset = Vector3.zero,
			MaxDistance = ARROW_MAX,
			Scale = scale,
			Strong = self.Urgent,
		})
		arrow.Parent = playerGui

		-- dev only: tutorial debug readout (F8 / "/dev tutdebug"), shown even when the tutorial is off
		if self:IsDev() then
			const debug = Vide.create("ScreenGui")({
				Name = "TutorialDebug",
				ResetOnSpawn = false,
				ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
				ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
				DisplayOrder = 50,
				TutorialDebug({
					Shown = self.Debug,
					Text = self.DebugText,
				}),
			})
			debug.Parent = playerGui
		end
	end)
	self.Mounted = true
	table.insert(self.Unmounts, unmount)
end

TutorialController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Sale:onClient(function(sale)
		self:OnSale(sale.Npc, sale.Result)
	end)
	-- dev-only client commands (sent by TutorialService:DevSend in dev mode; ignored otherwise)
	self.Libs.Net.DevClient:onClient(function(data)
		self:OnDev(data.Command, data.Text)
	end)
end)

TutorialController:OnStart(function(self)
	if not self.Dependencies.PlaceController:Is("Run") then
		return
	end
	-- TutorialPromptGate: PromptController asks this for every anchor (presentation only)
	self.Dependencies.PromptController:SetGate(function(anchor: Instance): boolean
		return self:PromptAllowed(anchor)
	end)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
	self:BindDebug()
	RunService.Heartbeat:Connect(function()
		-- the Beacon only moves while something is marked (ClearGuidance unmarks it when the tutorial stops)
		self.Beacon.Step()
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
