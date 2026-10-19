--!strict
--[[
	TutorialController (user request 2026-10-11; Provisional until a FEAT/TASK is written for it)

	First-hot-dog tutorial, on Day 1 of every run for everyone (user request 2026-10-11, Provisional; nothing is saved: no profile flag).
	It walks the player through the first sale, following the order of one tutorial customer
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
	tutorial stock: a party with a veteran) the talk step "mart" stands in for the four. mart_go / mart_back also draw a
	dashed trail on the ground from the trailer door to the Mart door and back (Trail.luau, TASK-322).
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
	arrow bobbing over it, grown with the distance so it keeps a readable size from far away), TutorialPointer on the screen
	edge ONLY while neither the arrow tip nor the target is on screen (EdgePointer; owner request 2026-10-14: the arrow is
	always the 3D one, the 2D badge only points the way when it is out of view), and Spotlight on the
	money pill for the UI step. Pieces without a
	visible part of their own (the OPEN sign's anchor on its stand, an invisible Mart shelf anchor) mark the small model
	around them or the nearest visible piece (highlightOf). A step completed (the panel number goes up) turns the chip Green with a check for
	CHECK_TIME s and plays `prompt_done`.
	Prompt focus: Focuses(anchor) says whether a prompt belongs to the current step (true for every prompt when the
	tutorial is not running or the step has no world target). PromptController can use it to hide or dim the others;
	that hook is the PromptController owner's (not wired from here).

	Progressive HUD (owner request 2026-10-12): which HUD element appears at which step is Content.HudReveal; HudController
	reads Step / Finished / FirstRun from here (self.StepKey, self.Finished, :FirstRun()) and decides. Everything shows
	when the tutorial ends, is skipped, or when it is not a first run. HudController also plugs a DevClient command in
	through SetDevHandler ("hud_reveal", /dev hud reveal).

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

	Restaurant (TASK-393; design/tutorial-restaurant.md, Provisional; only with Content.Restaurant.Rules.Enabled, else
	everything above is unchanged): after the window, the tutorial customer's order is taken at the tablet (r_tablet,
	r_listen while Tablets says Talking), then the plate furthest along (WorkPlate: the tutorial customer has no plate
	ticket) is built: r_cut -> r_bun_plate -> r_grill -> r_cooking -> r_flip -> r_collect -> r_rail -> r_dog_plate ->
	r_take_plate -> r_toppings (or r_discard) -> r_pickup ("Hand Over" at PICKUP); r_crew while a crewmate holds the hot
	dog. After the money step, with TutorialRules.Restock and a take_box bay in the map (infinite stock room, owner
	2026-10-17): r_box (take_box at a StockShelf bay) -> r_restock (the station of the box's ingredient); over once any
	station's stock goes up. The Day 1 upgrade lesson below is on in the restaurant (TutorialRules.Upgrade).

	PROVISIONAL: texts, IDLE, PROGRESS, CALL_WAIT, NUDGE, TALK_TIME, TALK_MIN, REASK, CHECK_TIME, skip keys (Q, DPadDown), "a served
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
local Objective = require(StarterPlayer.StarterPlayerScripts.client.Interface.Objective)
local Spotlight = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Spotlight)
local TutorialPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TutorialPanel)
local TutorialPointer = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TutorialPointer)
local EdgePointer = require(StarterPlayer.StarterPlayerScripts.client.Interface.EdgePointer)
local TutorialDebug = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TutorialDebug)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Rules = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Rules)
local TutorialRules = require(ReplicatedStorage.shared.Tutorial.Rules)
local Beacon = require(script.Beacon)
local Call = require(script.Call)
local Steps = require(script.Steps)
local Trail = require(script.Trail)
-- the plate of the 3D prep mode (module state shared with PrepController): the "deliver" step reads it (TASK-254)
local PrepPlate = require(StarterPlayer.StarterPlayerScripts.client.Prep.PrepController.Stages.Build.Session)
local Verbose = require(ReplicatedStorage.shared.Verbose)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)

const TAG = "Interactable"
const TRAIL_RETRY = 1 -- s between two route builds (map still streaming in, or the player strayed) (TASK-322)
const TRAIL_STRAY = 5 -- studs off the trail before it is rebuilt from the player
const VEHICLE_TAG = "Vehicle"
const STATION_TAG = "Station"
const WORK_ACTION = "prep_work" -- Prompt_Work of Station_n (PrepService)
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
-- Day 1 upgrade lesson (owner request 2026-10-14, Provisional): Walt's call, the upgrade to buy, the Gear Stand reach
const LESSON = TutorialRules.Upgrade
const LESSON_REACH = Content.Mart.Hint.Reach * 2 -- studs from the pedestal where "go" becomes "buy"
const CALL_WAIT = 12 -- s of a silent phone before the tutorial goes on without Walt (panel only)
const RUSH_TIME = 4 -- s between two step changes under which the player is rushing (no praise)
const NUDGE = 20 -- s on the same step before Walt says it again (steps without Remind)
const IDLE = 12 -- s without progress on a step with Remind before it turns urgent (and again every IDLE s)
const PROGRESS = 2 -- studs closer to the target that count as progress (walking to it resets IDLE)
const TALK_MIN = 1.5 -- s a talk step stays at least while Walt is on the line
const TALK_TIME = 7 -- s of a talk step without the call
const STEP_SOUND = "prompt_done"
const SKIP_BIND = "TutorialSkip"
-- Owner request 2026-10-14 (Provisional): no Skip (Q / D-pad / button) and no top tutorial panel: Walt explains every step on the
-- phone, the arrow / highlight still guide. The talk steps move on by themselves (TALK_TIME / Walt done). false = off
const SKIPPABLE = false
const SHOW_PANEL = false
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
const PANEL_TOP_EDGE = 6 -- px at scale 1: the card hugs the top edge
const ROBLOX_BAR = 270 -- px: width of the Roblox logo + menu / chat / mic cluster at the top left
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
const NEAR_CRATE = 12 -- back at the trailer: "Restock the buns"
-- Voices ahead / dev tools
const PROFILE_WAIT = 3 -- s PreloadVoices waits for the Profile packet before it gives up (Tick prepares later)
const DEBUG_BIND = "TutorialDebug"
const DEBUG_RATE = 0.25 -- s between two refreshes of the debug panel text
const VOICE_WAIT = 20 -- s the voice test waits for one line to load
const VOICE_TAIL = 0.4 -- s after a line of the voice test before the next one
const DEV_PREFIX = "[TutorialDev]"
-- Restaurant (TASK-393; design/tutorial-restaurant.md): actions and items of the restaurant loop and of the restock
const RESTAURANT = Content.Restaurant
const TABLET_TAKE = "tablet_take"
const BUN_SLICE = "bun_slice"
const PLATE_PUT = "plate_put"
const PLATE_TAKE = "plate_take"
const GRILL_FLIP = "grill_flip"
const RAIL_TAKE = "rail_take"
const PICKUP_SERVE = "pickup_serve"
const TAKE_BOX = "take_box"
const RESTOCK = "restock"
const BUN_SLICED = "bun_sliced"
const SAUSAGE_GRILLED = "sausage_grilled"
const RESTOCK_STEPS: { [string]: boolean } = { r_box = true, r_restock = true }
-- package Tool item key -> its Packages row (a box in hand)
const PACKAGE_OF_ITEM: { [string]: Content.Package } = {}
for _, row in Content.Packages.List do
	PACKAGE_OF_ITEM[row.Item] = row
end
-- Restaurant set record fields read here (Net.Restaurant)
type PlateRecord = { Npc: number, Bun: boolean, Sausage: boolean }
type TabletRecord = { State: string, Npc: number }
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
	-- edge pointer maths (hysteresis state); the badge shows only while the arrow tip and the target are both off screen
	self.Edge = EdgePointer.new(EDGE_MARGIN) :: EdgePointer.EdgePointer
	-- no progress on the step for IDLE s: reminder, stronger pulse (until the step changes)
	self.Urgent = Vide.source(false) :: Vide.Source<boolean>
	-- os.clock of the last progress on the step (step start, getting closer, a reminder) and the closest distance
	self.IdleAt = 0 :: number
	self.IdleDistance = math.huge :: number
	-- green check on the panel chip: a step was just completed (until CheckUntil, os.clock)
	self.Checked = Vide.source(false) :: Vide.Source<boolean>
	self.CheckUntil = 0 :: number
	self.Folder = nil :: Folder?
	-- invisible markers of Prompt_Work attachments (WorkMarker)
	self.Markers = {} :: { [Attachment]: BasePart }
	-- Highlight + 3D arrow on the piece of the current step
	self.Beacon = Beacon.new(function(): Instance
		return self:FxFolder()
	end) :: Beacon.Beacon
	-- dashed ground trail trailer <-> Mart on mart_go / mart_back (TASK-322); Route cached once the map is streamed
	self.Trail = Trail.new(function(): Instance
		return self:FxFolder()
	end) :: Trail.Trail
	self.TrailRoute = nil :: { Vector3 }? -- current route, from the player's feet (Trail.RouteFrom)
	self.TrailKey = "" :: string -- step the route was built for
	self.TrailInside = false :: boolean -- the route was built from inside the trailer
	self.TrailTriedAt = 0 :: number -- os.clock of the last Trail.RouteFrom try
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
	-- restaurant restock steps after the first sale (TASK-393); the stock marks they began from (Restocked)
	self.Restocking = false :: boolean
	self.RestockFrom = {} :: { [string]: number }
	self.Unmounts = {} :: { () -> () }
	-- Dev tools: step forced by /dev tutorial step (nil = the live flow), debug panel, voice test run, one-time note
	self.Forced = nil :: string?
	self.Debug = Vide.source(false) :: Vide.Source<boolean>
	self.DebugText = Vide.source("") :: Vide.Source<string>
	self.DebugAt = 0 :: number
	self.VoiceRun = 0 :: number
	self.DevNoted = false :: boolean
	self.Mounted = false :: boolean
	-- DevClient commands other controllers plug in (SetDevHandler): command -> handler(text)
	self.DevHandlers = {} :: { [string]: (text: string) -> () }
	-- Day 1 upgrade lesson: this player ran the tutorial this session (a rookie), Walt's lesson call was heard, the
	-- lesson is on screen, the player reached the stand once, skipped it
	self.Rookie = false :: boolean
	self.LessonHeard = false :: boolean
	self.LessonOn = false :: boolean
	self.LessonNear = false :: boolean
	self.LessonSkipped = false :: boolean
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
	if step and step.Lesson then
		return `STEP {step.Number} OF {Steps.LessonTotal}`
	end
	return if step then `STEP {step.Number} OF {Steps.Total}` else ""
end

-- The line under the instruction: the short reminder while the player makes no progress, the prep wording while seated at a station
function TutorialController:PanelHint(): string
	const step = self:Step()
	if step == nil then
		return ""
	end
	if self.Urgent() and step.Remind then
		return step.Remind
	end
	return if self:Focused() and step.PrepHint then step.PrepHint else step.Hint
end

-- Owner request 2026-10-14 (Provisional): the tutorial has no Skip any more (Walt leads it); "" = no Skip on the cards
function TutorialController:SkipText(): string
	if not SKIPPABLE then
		return ""
	end
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

-- Units of an ingredient in the trailer (Stock set, record id = Content.Ingredients.IndexOf). nil = not replicated yet.
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
	-- TASK-258: seated in the prep mode there is no world arrow (the mode has its own coach paw)
	const seated = self:Seated()
	if forced ~= nil then
		return forced, if seated then nil else forcedTarget, forcedItem
	end
	return key, if seated then nil else target, item
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
	-- restaurant, after the first sale: phone order -> box -> Restock (TASK-393)
	if self.Restocking then
		return self:DecideRestock()
	end

	-- Walt is on the line (or never called): the trailer is opened first (Prep: the window lever by the phone; opening the
	-- window opens the shop, TASK-284), then the tutorial customer comes
	if Vide.untrack(self.Dependencies.RoundController.Phase) == "Prep" then
		return "open", self:Anchor("shutter_toggle", false), ""
	end

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
	-- restaurant loop (TASK-393): tablet -> cut -> plate -> grill -> plate -> take -> toppings -> pickup
	if TutorialRules.Restaurant then
		return self:DecideRestaurant(guestId, guest, rig)
	end
	if guest.State == "Ordering" then
		return "order", self:Anchor("take_order", false, onGuest) or rig, ""
	end

	const held = self:Held()
	if held and held.Item == HOT_DOG then
		-- a topping they did not ask for: Wrong at the counter, throw it away
		for key in held.Toppings do
			if not guest.Order[key] then
				-- the street bin first: the one of the kitchen is hidden in the focused mode
				return "discard", self:Anchor("discard", true) or self:Anchor("discard", false), ""
			end
		end
		-- focused kitchen: the toppings were chosen on the Build tab before the hot dog existed and no world prompt adds
		-- one now; a hot dog short of a topping is served as it is (Incomplete counts as the first sale)
		if not self:Focused() then
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
		end
		-- the hot dog is right: serve it (the trailer was opened before the customer came)
		return "serve", self:Anchor("serve", false, onGuest) or rig, ""
	end

	-- TASK-254: in the 3D prep mode the plate is built (bun cut, sausage in). TASK-258: first the order's toppings on the
	-- Toppings view, then drag the plate onto the customer's delivery area. No world arrow while seated (the prep coach paw)
	if self:Seated() and Vide.untrack(PrepPlate.Open) and Vide.untrack(PrepPlate.Placed) then
		const missing = self:MissingTopping(guest.Order)
		if missing ~= nil then
			const row = Content.Ingredients.ByKey[missing]
			return "toppings", nil, if row then row.Name else missing
		end
		return "deliver", nil, ""
	end

	-- Day 1 cut (2026-10-17): the focused kitchen is one step ("cook"); the prep mode's coach paw leads inside it
	if self:Focused() then
		return "cook", self:KitchenAnchor(WORK_ACTION, false), ""
	end
	const kitchen = self:Kitchen()
	if kitchen.Rail > 0 and kitchen.BoardReady then
		return "assemble", self:KitchenAnchor("board_add_sausage", false), ""
	end
	if kitchen.GrillReady then
		return "collect", self:KitchenAnchor("grill_collect", true), ""
	end
	if kitchen.Rail == 0 and not kitchen.GrillWorking then
		return "grill", self:KitchenAnchor("grill_place", false), ""
	end
	if not kitchen.BoardReady and not kitchen.BoardWorking then
		return "slice", self:KitchenAnchor("bun_cut", false), ""
	end
	if kitchen.BoardWorking then
		return "slicing", nil, ""
	end
	-- grill working, bun sliced: wait for the sausage
	return "cooking", self:KitchenAnchor("grill_collect", false), ""
end

-- Restaurant (TASK-393; design/tutorial-restaurant.md) ------------------------------------------------------------

-- PLATE-n index of a plate anchor (the anchor or an ancestor tagged Binding.PlateTag), nil = not a plate anchor
local function plateIndexOf(anchor: Instance): number?
	local current: Instance? = anchor
	while current and current ~= Workspace do
		if CollectionService:HasTag(current, RESTAURANT.Binding.PlateTag) then
			const index = current:GetAttribute(RESTAURANT.Binding.PlateIndex)
			return if typeof(index) == "number" then index else nil
		end
		current = current.Parent
	end
	return nil
end

-- The plate the tutorial works on (Plates set). The tutorial customer gets no plate ticket and the verdict goes by the
-- toppings, so any plate serves: the one furthest along (bun and dog > one of them > empty), one without a ticket
-- first, then the lowest index. Progress = 0..2 (bun + dog on it); nil = no plate bound.
function TutorialController:WorkPlate(): (PlateRecord?, number?, number)
	local best: PlateRecord? = nil
	local bestIndex: number? = nil
	local bestScore = -1
	for index, raw in Restaurant.Plates:entries() do
		const record = raw :: PlateRecord
		const progress = (if record.Bun then 1 else 0) + (if record.Sausage then 1 else 0)
		const score = progress * 4 + (if record.Npc == 0 then 2 else 0)
		if score > bestScore or (score == bestScore and bestIndex ~= nil and index < bestIndex) then
			best, bestIndex, bestScore = record, index, score
		end
	end
	const progress = if best then (if best.Bun then 1 else 0) + (if best.Sausage then 1 else 0) else 0
	return best, bestIndex, progress
end

-- A prompt of the plate `index` (nil = the nearest plate)
function TutorialController:PlateAnchor(action: string, index: number?): Instance?
	if index == nil then
		return self:Anchor(action, false)
	end
	return self:Anchor(action, false, function(anchor: Instance): boolean
		return plateIndexOf(anchor) == index
	end) or self:Anchor(action, false)
end

-- Another player of the server holds a hot dog (co-op: a crewmate has the plate)
local function crewHasHotDog(): boolean
	for _, player in Players:GetPlayers() do
		if player == Players.LocalPlayer then
			continue
		end
		const character = player.Character
		const tool = if character then character:FindFirstChildOfClass("Tool") else nil
		if tool and tool:GetAttribute("Item") == HOT_DOG then
			return true
		end
	end
	return false
end

-- Restaurant loop of the tutorial customer from the replicated state (whoever does a step, it counts for everyone)
function TutorialController:DecideRestaurant(guestId: number, guest: GuestRecord, rig: Model?): (string, Instance?, string)
	local function onGuest(anchor: Instance): boolean
		return npcIdOf(anchor) == guestId
	end
	if guest.State == "Ordering" then
		for _, raw in Restaurant.Tablets:entries() do
			const record = raw :: TabletRecord
			if record.Npc == guestId and record.State == "Talking" then
				return "r_listen", nil, ""
			end
		end
		return "r_tablet", self:Anchor(TABLET_TAKE, true) or self:Anchor(TABLET_TAKE, false) or rig, ""
	end
	const held = self:Held()
	if held and held.Item == HOT_DOG then
		for key in held.Toppings do
			if not guest.Order[key] then
				return "r_discard", self:Anchor("discard", true) or self:Anchor("discard", false), ""
			end
		end
		for _, key in Content.Ingredients.ToppingKeys do
			if guest.Order[key] and not held.Toppings[key] then
				const row = Content.Ingredients.ByKey[key]
				return "r_toppings",
					self:Anchor("topping_add", false, function(anchor)
						return anchor:GetAttribute("Ingredient") == key
					end),
					if row then row.Name else key
			end
		end
		return "r_pickup", self:Anchor(PICKUP_SERVE, false) or self:Anchor("serve", false, onGuest) or rig, ""
	end
	const plate, index, progress = self:WorkPlate()
	if progress == 0 and crewHasHotDog() then
		return "r_crew", self:Anchor(PICKUP_SERVE, false), ""
	end
	if held and held.Item == BUN_SLICED and not (plate and plate.Bun) then
		return "r_bun_plate", self:PlateAnchor(PLATE_PUT, index), ""
	end
	if held and held.Item == SAUSAGE_GRILLED and not (plate and plate.Sausage) then
		return "r_dog_plate", self:PlateAnchor(PLATE_PUT, index), ""
	end
	if plate and plate.Bun and plate.Sausage then
		return "r_take_plate", self:PlateAnchor(PLATE_TAKE, index), ""
	end
	if not (plate and plate.Bun) then
		return "r_cut", self:Anchor(BUN_SLICE, true) or self:Anchor(BUN_SLICE, false), ""
	end
	-- the dog: grill -> (pause) flip -> collect -> take it off the hot pile
	const kitchen = self:Kitchen()
	if kitchen.Rail > 0 then
		return "r_rail", self:Anchor(RAIL_TAKE, true) or self:Anchor(RAIL_TAKE, false), ""
	end
	if kitchen.GrillReady then
		return "r_collect", self:Anchor("grill_collect", true) or self:Anchor("grill_collect", false), ""
	end
	const flip = self:Anchor(GRILL_FLIP, true)
	if flip then
		return "r_flip", flip, ""
	end
	if kitchen.GrillWorking then
		return "r_cooking", self:Anchor("grill_collect", false), ""
	end
	return "r_grill", self:Anchor("grill_place", false), ""
end

-- Restock steps start after the first sale: Supply on and a stock room bay (take_box) in the map
function TutorialController:CanRestock(): boolean
	return TutorialRules.Restock and self:Anchor(TAKE_BOX, false) ~= nil
end

-- Units of every ingredient now (Stock set)
function TutorialController:StockAll(): { [string]: number }
	const out: { [string]: number } = {}
	for id, raw in self.Libs.Net.Stock:entries() do
		const key = Content.Ingredients.Keys[id]
		if key ~= nil then
			out[key] = (raw :: { Amount: number }).Amount
		end
	end
	return out
end

-- Restock steps over: some ingredient went above what it had when they began (whoever restocked). A lower amount
-- lowers the mark (a unit used in between never hides the restock)
function TutorialController:Restocked(): boolean
	for key, amount in self:StockAll() do
		const from = self.RestockFrom[key]
		if from == nil or amount < from then
			self.RestockFrom[key] = amount
		elseif amount > from then
			return true
		end
	end
	return false
end

-- The restock anchor of the station of `ingredient` (anchor or station attribute Ingredient, or the station kind of the
-- ingredient row), else the nearest one
function TutorialController:StationRestock(ingredient: string): Instance?
	const row = Content.Ingredients.ByKey[ingredient]
	const kind = if row then row.Station else nil
	return self:Anchor(RESTOCK, false, function(anchor: Instance): boolean
		const own = anchor:GetAttribute("Ingredient")
		if own ~= nil then
			return own == ingredient
		end
		const station = ancestorWith(anchor, function(instance)
			return CollectionService:HasTag(instance, STATION_TAG)
		end)
		if station == nil then
			return false
		end
		const stationIngredient = station:GetAttribute("Ingredient")
		if stationIngredient ~= nil then
			return stationIngredient == ingredient
		end
		return kind ~= nil and station:GetAttribute("StationKind") == kind
	end) or self:Anchor(RESTOCK, false)
end

-- Restock step from the hand and the stock room bays (always a box there)
function TutorialController:DecideRestock(): (string, Instance?, string)
	const held = self:Held()
	const package = if held then PACKAGE_OF_ITEM[held.Item] else nil
	if package ~= nil then
		return "r_restock", self:StationRestock(package.Ingredient), ""
	end
	return "r_box", self:Anchor(TAKE_BOX, true) or self:Anchor(TAKE_BOX, false), ""
end

-- Starts the restock steps (after the money step, or forced by /dev tutorial step)
function TutorialController:BeginRestock()
	self.Restocking = true
	table.clear(self.RestockFrom)
	self:Restocked() -- the marks of now
	const key, target, item = self:DecideRestock()
	self:SetStep(key, target, item)
end

-- Focused prep mode (Content.Prep.Rules.WorldKitchenPrompts = false): the kitchen prompts of the world are gone and the
-- kitchen steps are done at a station of the trailer (prep-mode.md §5; shim until the rewrite, TASK-183/184)
function TutorialController:Focused(): boolean
	return not Content.Prep.Rules.WorldKitchenPrompts
end

-- First topping of the order not on the 3D prep plate yet (PrepPlate.Toppings), in the order of the catalog; nil = all on
function TutorialController:MissingTopping(order: { [string]: boolean }): string?
	const onPlate: { [string]: boolean } = {}
	for _, entry in PrepPlate.Toppings() do
		onPlate[entry.Key] = true
	end
	for _, key in Content.Ingredients.ToppingKeys do
		if order[key] and not onPlate[key] then
			return key
		end
	end
	return nil
end

-- The player works at a station now (the server sets Working = n on the character, PrepService)
function TutorialController:Seated(): boolean
	const character = Players.LocalPlayer.Character
	return character ~= nil and typeof(character:GetAttribute("Working")) == "number"
end

-- What a kitchen step points at: the world prompt of the action, or in the focused mode the Work prompt of the nearest
-- station (nothing while the player is already at one: the prep UI is the guide)
function TutorialController:KitchenAnchor(action: string, enabled: boolean): Instance?
	if not self:Focused() then
		return self:Anchor(action, enabled)
	end
	if self:Seated() then
		return nil
	end
	-- TASK-258: every kitchen step points at the Work prompt that enters the mode. Only the grill one is on (owner decision
	-- 2026-10-14, PrepService:SilenceSpareWork): the board one sits off by the bun crate, so a disabled prompt is never
	-- the target while an enabled one exists (the disabled one only as a fallback before PromptEnabled replicates)
	return self:Anchor(WORK_ACTION, true) or self:Anchor(WORK_ACTION, false, function(anchor: Instance): boolean
		return anchor:GetAttribute("PromptStep") == "Grill"
	end)
end

-- Presentation ---------------------------------------------------------------------------------------------------

-- Invisible client part on a Prompt_Work attachment: what the 3D arrow of a kitchen step stands on (focused prep mode)
function TutorialController:WorkMarker(anchor: Attachment): BasePart
	local marker = self.Markers[anchor]
	if marker == nil or marker.Parent == nil then
		marker = Instance.new("Part")
		marker.Name = "TutorialWorkMarker"
		marker.Size = Vector3.one
		marker.Transparency = 1
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.CastShadow = false
		marker.Parent = self:FxFolder()
		self.Markers[anchor] = marker
	end
	marker.CFrame = anchor.WorldCFrame
	return marker
end

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
	-- Prompt_Work of a station: its model holds only attachments, nothing to outline (SetHighlight puts a marker)
	if anchor:IsA("Attachment") and anchor:GetAttribute("PromptAction") == WORK_ACTION then
		return nil
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
		-- never the whole trailer (a vehicle model can be that small)
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
	local adornee = if anchor then highlightOf(anchor) else nil
	if adornee == nil and anchor ~= nil and anchor:IsA("Attachment") and anchor:GetAttribute("PromptAction") == WORK_ACTION then
		-- Prompt_Work of a station is an Attachment inside a model with no parts: the arrow stands on an invisible marker
		adornee = self:WorkMarker(anchor)
	end
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
		self.Spot(false)
	end)
	self.Edge.Reset()
	self:SetHighlight(nil)
	self.Trail.Hide()
	self:ResetIdle()
end

-- Ground trail of the shopping walk (TASK-322): trailer -> Mart on mart_go, the way back on mart_back, gone on any
-- other step (reaching the door / the crate changes the step). Every frame, before Trail.Step.
function TutorialController:UpdateTrail()
	const key = if Vide.untrack(self.Running) then Vide.untrack(self.StepKey) else ""
	if key ~= "mart_go" and key ~= "mart_back" then
		if self.Trail.Shown() then
			self.Trail.Hide()
		end
		return
	end
	-- the trail starts at the player (owner request 2026-10-16): rebuilt when he strays TRAIL_STRAY studs from it or
	-- crosses the trailer wall (inside, it only leads to the Exit Trailer door)
	const feet = Trail.Feet()
	if feet == nil then
		return
	end
	const inside = Trail.Inside(feet)
	local route = self.TrailRoute
	if route == nil or self.TrailKey ~= key or self.TrailInside ~= inside or Trail.Off(route, feet) > TRAIL_STRAY then
		const now = os.clock()
		if now - self.TrailTriedAt >= TRAIL_RETRY or (route ~= nil and (self.TrailKey ~= key or self.TrailInside ~= inside)) then
			self.TrailTriedAt = now
			local fresh = Trail.RouteFrom(feet, if key == "mart_go" then "Mart" else "Trailer")
			if fresh == nil and (self.TrailKey ~= key or self.TrailInside ~= inside) then
				route = nil -- the old route no longer fits: none until the map answers (retried every TRAIL_RETRY)
				self.Trail.Hide()
			end
			self.TrailRoute = fresh or route
			self.TrailKey = key
			self.TrailInside = inside
			route = self.TrailRoute
		end
	end
	if route then
		self.Trail.Show(route)
	end
end

-- Edge pointer toward the target, ONLY while neither the arrow tip nor the target is on screen (EdgePointer; every
-- frame, after Beacon.Step so the tip is current). The overlay ignores the GUI inset, so its pixels are viewport pixels;
-- the margin that places the badge follows the UI scale, so the scaled badge never leaves the screen.
function TutorialController:UpdatePointer()
	const target = Vide.untrack(self.Target)
	const position = if target then positionOf(target) else nil
	if position == nil or not Vide.untrack(self.Running) then
		self.Edge.Reset()
		if Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
		return
	end
	const tip = self.Beacon.TipPosition()
	const points = if tip then { tip, position } else { position }
	const shown, at, angle = self.Edge.Update(points, Vide.untrack(self.Scale))
	if not shown then
		if Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
		return
	end
	Vide.batch(function()
		self.PointerAt(at)
		self.PointerAngle(angle)
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
			-- onboarding funnel (analytics): the server logs each step once
			const index = table.find(Content.Metrics.TutorialSteps, key)
			if index ~= nil then
				self.Libs.Net.MetricTutorial:fireServer({ Step = index })
			end
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
		if TutorialRules.Restaurant then
			-- restaurant (TASK-393): the restock steps when the supply is on and a stock room bay is in the map, else done
			if self:CanRestock() then
				self:BeginRestock()
			else
				self:Finish("done")
			end
			return
		end
		if not TutorialRules.Shopping then
			self:Finish("done") -- 2026-10-17 cut: Day 1 ends on the first sale (the Mart is a low-bun hint later)
			return
		end
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
	if self.LessonOn then
		-- the upgrade lesson: off for this player (the server lets the 6 PM hold go once no rookie is left)
		self.LessonSkipped = true
		self.Libs.Net.TutorialLessonSkip:fireServer()
		self:TickLesson()
		return
	end
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
		self.Libs.Net.TutorialComplete:fireServer({
			How = if reason == "done" or reason == "skip" then reason :: any else "over",
		})
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
	-- the Day 1 upgrade lesson (6 PM) owns the panel while it runs
	if self:TickLesson() then
		return
	end
	const firstRun = Vide.untrack(function(): boolean
		return self:FirstRun()
	end)
	if not firstRun then
		-- TASK-475: the run left Day 1 mid-step (the phone ringing): take the arrow + highlight down with it
		if Vide.untrack(self.Running) then
			self.Running(false)
			self:ClearGuidance()
		end
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
	if ready and phase ~= "Prep" and not Vide.untrack(self.ClockRevealed) then
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
	self.Rookie = true
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
	-- restaurant restock over: a station got stock back (whoever restocked)
	if self.Restocking and self:Restocked() then
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

-- Upgrade lesson (owner request 2026-10-14, Provisional) ------------------------------------------------------------

-- Level of an upgrade on the current vehicle from the Upgrades set (nil = record not here yet)
function TutorialController:UpgradeLevel(key: string): number?
	const index = Content.Upgrades.IndexOf[key]
	for id, record in self.Libs.Net.Upgrades:entries() do
		if id == index then
			return record.Level
		end
	end
	return nil
end

-- Any Gear Stand line above its start level (nil = the levels are not known yet)
function TutorialController:BoughtGear(): boolean?
	local known = false
	for id, record in self.Libs.Net.Upgrades:entries() do
		const upgrade = Content.Upgrades.List[id]
		if upgrade == nil or upgrade.SoldAt ~= "Bench" then
			continue
		end
		known = true
		if record.Level > upgrade.StartLevel then
			return true
		end
	end
	return if known then false else nil
end

-- Key of the upgrade the lesson asks for while it runs for this player (nil = no lesson): a rookie of this session,
-- the day Closing of Day 1 (6 PM), Walt's lesson call heard, nothing bought on the Gear Stand yet, not skipped.
-- MarketController reads this to hide its own closing-time arrow (one arrow at a time).
function TutorialController:UpgradeLesson(): string?
	if
		not TutorialRules.Upgrade.Enabled
		or not self.Rookie
		or self.LessonSkipped
		or not self.Dependencies.PlaceController:Is("Run")
	then
		return nil
	end
	const round = self.Dependencies.RoundController
	if
		not Vide.untrack(round.Ready)
		or Vide.untrack(round.Day) > 1
		or Vide.untrack(round.IsNight)
		or Vide.untrack(round.Phase) ~= "Closing"
	then
		return nil
	end
	if not self.LessonHeard then
		const boss = self.Dependencies.BossController
		if Vide.untrack(boss.Call) ~= LESSON.Call or Vide.untrack(boss.State) == "Idle" then
			return nil
		end
		self.LessonHeard = true
	end
	if self:BoughtGear() ~= false then
		return nil
	end
	return LESSON.Key
end

-- The pedestal (or bench prompt anchor) that sells `key` on the Gear Stand
function TutorialController:LessonStand(key: string): Instance?
	const upgrade = Content.Upgrades.ByKey[key]
	if upgrade == nil then
		return nil
	end
	const tags = Content.Mart.Tags
	for _, pedestal in CollectionService:GetTagged(tags.Pedestal) do
		if pedestal:GetAttribute(tags.Slot) == upgrade.BenchSpot and pedestal:IsDescendantOf(Workspace) then
			return pedestal
		end
	end
	for _, anchor in CollectionService:GetTagged(TAG) do
		if anchor:GetAttribute("BenchSlot") == upgrade.BenchSpot and anchor:IsDescendantOf(Workspace) then
			return anchor
		end
	end
	-- restaurant (TASK-393): the stand inside the shop may only carry the buy prompt; the nearest one is the way there
	return if TutorialRules.Restaurant then self:Anchor("bench_buy_upgrade", false) else nil
end

-- One tick of the lesson; true = it owns the panel this tick (the first-hot-dog flow waits)
function TutorialController:TickLesson(): boolean
	const key = self:UpgradeLesson()
	if key == nil then
		if self.LessonOn then
			self.LessonOn = false
			Vide.batch(function()
				self.Running(false)
				self.StepKey("")
			end)
			self:ClearGuidance()
		end
		return false
	end
	if not Vide.untrack(self.Finished) then
		-- the first-hot-dog flow is over with the day (normally already done): close it without a goodbye
		self:Finish("over")
	end
	self.LessonOn = true
	if not Vide.untrack(self.Running) then
		self.Running(true)
	end
	const stand = self:LessonStand(key)
	if stand ~= nil and self:DistanceTo(stand) <= LESSON_REACH then
		self.LessonNear = true
	end
	const stepKey = if self.LessonNear then "upg_buy" else "upg_go"
	self:SetStep(stepKey, stand, "")
	const step = Steps.ByKey[stepKey]
	if step then
		self:TickIdle(step, stand)
	end
	return true
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
	if self:IsDev() and Verbose.On() then
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
	const opened = key == "open" and Vide.untrack(self.Dependencies.RoundController.Phase) ~= "Prep"
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
	if RESTOCK_STEPS[key] then
		-- restaurant restock steps (TASK-393): decided from the hand and the stock room bays
		self.Forced = nil
		self.Shopping = false
		Vide.batch(function()
			self.CashRevealed(true)
			self.ClockRevealed(true)
		end)
		self:BeginRestock()
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
	self.Restocking = false
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
		`arrow      pointer {flag(Vide.untrack(self.PointerShown))}  panel {flag(self.Mounted and panel ~= nil)}`,
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
	self.Restocking = false
	table.clear(self.RestockFrom)
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
	const handler = self.DevHandlers[command]
	if handler ~= nil then
		handler(text)
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

-- Another controller handles a DevClient command (dev mode only; HudController: "hud_reveal")
function TutorialController:SetDevHandler(command: string, handler: (text: string) -> ())
	self.DevHandlers[command] = handler
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
		-- the step as data for the prep shell (Objective); Skip goes through the same method as the key
		Objective.SetSkip(function()
			self:Skip()
		end)
		Vide.effect(function()
			const step = self:Step()
			-- TASK-255: no tutorial card in the prep shell either while the panel is off (SHOW_PANEL)
			const card: Objective.Card | false = if SHOW_PANEL and shown() and step ~= nil
				then {
					Step = step.Number,
					Total = Steps.Total,
					Text = self:PanelText(),
					Hint = self:PanelHint(),
					Label = self:StepLabel(),
					Done = self.Checked(),
					Urgent = self.Urgent(),
					SkipText = self:SkipText(),
				}
				else false
			Vide.untrack(function()
				Objective.SetCard(card)
				return nil
			end)
		end)
		Vide.cleanup(function()
			Objective.SetCard(false)
			Objective.SetSkip(nil)
		end)
		Vide.effect(function()
			const on = self.Running() and SKIPPABLE
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
				-- the focused prep mode shows the step in its own progress card (Objective): one card on top, not two
				Shown = function()
					return SHOW_PANEL and shown() and not Objective.Hosted()
				end,
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
					return self:PanelHint()
				end,
				Urgent = self.Urgent,
				SkipText = function()
					return self:SkipText()
				end,
				OnSkip = function()
					self:Skip()
				end,
				Scale = scale,
				-- top edge, right of the Roblox top-left buttons (user request 2026-10-12: the card sat too low and covered the
				-- scene; it goes in the red box of the screenshot: y 6, left edge after the Roblox cluster)
				Position = function()
					const s = scale()
					const camera = workspace.CurrentCamera
					const width = if camera ~= nil then camera.ViewportSize.X else 1280
					const panelWidth = math.clamp(width * 0.5, 300, 460) -- the panel's own constraint (TutorialPanel)
					const centre = math.max(width / 2, ROBLOX_BAR + panelWidth / 2 + 8)
					return UDim2.new(0, centre, 0, PANEL_TOP_EDGE * s)
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
		self:UpdateTrail()
		self.Trail.Step()
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
