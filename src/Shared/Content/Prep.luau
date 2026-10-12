--!strict
-- Focused prep mode (docs/tech/prep-mode.md §6; FEAT-039; DEC-223). Exported by Content as Prep.
-- Pure data, Provisional numbers (FEAT-039 tables) and short English UI texts. Icon = "" where the sprite does not exist
-- yet (Q-152): the UI draws Mustard/Cream/Ink shapes meanwhile.
-- The client measures every gesture and sends 0..100 scores per stage; the SERVER turns scores into bands with Grades
-- (src/Prep/shared/Grade.luau, same math on both sides). Retouching a number is a data change only.
--   score from the raw error of a target (Tolerances): piecewise line through
--     (0 -> 100), (Perfect -> Grades.Bands.Perfect), (Good -> Grades.Bands.Good), (Worst -> 0)
--   band = Perfect if score >= Bands.Perfect, Good if >= Bands.Good, else Messy
--   stage points = Grades.Points[band]; plate = mean of the stage points (sausage grill stage included when known)
--   plate Perfect if mean >= Plate.PerfectAvg and no Messy stage, Good if >= Plate.GoodAvg, else Messy
--   time floor: a plate under PerfectMin + PerTopping x K seconds never passes Good; under MinPlate + PerTopping x K it
--   is refused (Rules, server clock)
local Table = require(script.Parent.Table)

-- Every tab key that exists on the wire. Order and Build are the 2D set (Rules.ThreeD = false, the one that runs today);
-- Board and Toppings are the 3D set (prep-3d.md §3.0). Grill and Serve are in both.
export type Tab = "Order" | "Grill" | "Build" | "Board" | "Toppings" | "Serve"
export type Band = "Perfect" | "Good" | "Messy"
-- SausagePlaced = the 3D Board section: bun cut AND sausage in the groove (prep-3d.md §3.0)
export type Need = "Nothing" | "BunCut" | "PlateBuilt" | "SausagePlaced" | "TicketPicked"

-- Camera views, one per 3D section (prep-3d.md §4.1). Window is the view of the Serve tab.
export type ViewKey = "Grill" | "Board" | "Toppings" | "Window"

-- Things the pointer ray can hit (TargetKind attribute of a PrepTarget hitbox, prep-3d.md §2.2)
export type TargetKind =
	"GrillSlot"
	| "SausageStock"
	| "Rail"
	| "BunCrate"
	| "Board"
	| "Knife"
	| "Topping"
	| "Bin"
	| "Hatch"
	| "Customer"

-- What the pointer carries (prep-3d.md §2.6). Knife cuts, Sausage is the grilled one, Bottle pours a sauce, Ladle spoons,
-- Slice is the cheese, Strip a bacon strip, Pinch the potato sticks, Plate carries the finished plate to the Hatch or the Bin,
-- Spatula is the optional grill cursor.
export type ToolKind = "None" | "Knife" | "Sausage" | "Bottle" | "Ladle" | "Slice" | "Strip" | "Pinch" | "Plate" | "Spatula"

-- Render state of one grill slot in the 3D world (client only, derived from Stations + the server clock + local prediction)
export type SlotPhase = "Free" | "Ghost" | "Cooking" | "FlipWindow" | "Late" | "Flipped" | "Ready"

-- One thing the ray can hit. Id is unique inside a seat (`GrillSlot:3`, `Topping:ketchup`, `Bin`); Slot 1..8 for GrillSlot and
-- Rail (the seat number for Board), 0 otherwise; Topping = Ingredients key for Topping, "" otherwise. Authoring: tag `PrepTarget`
-- on an invisible hitbox, attributes TargetKind / Slot / Key (World.Attr).
export type PrepTarget = {
	Kind: TargetKind,
	Id: string,
	Slot: number,
	Topping: string,
}

export type TabRow = {
	Key: string, -- Tab (wire enum value, PascalCase)
	Label: string,
	Hint: string,
	Icon: string, -- rbxassetid, "" = placeholder
}

export type Step = {
	Key: string,
	Tab: Tab,
	View: ViewKey, -- camera view of the step (Views row)
	Label: string,
	Hint: string,
	NextLabel: string, -- text of the corner button on this step
	Needs: Need, -- what enables the corner button
	Icon: string,
}

-- One camera view = one 3D section. Anchor / Focus are the child names inside Station_n (CFrame of the camera, point looked at).
-- Fallback = the view tried when this one has no anchor: a Views key, "Build" (the legacy CamAnchor_Build / Focus_Build pair,
-- LegacyView) or "" (then the Grill view, which always exists, then the TRL fallback of Poses). Fov 0 = Rules.Camera.Fov; an
-- anchor attribute `Fov` overrides both.
export type View = {
	Key: ViewKey,
	Tab: Tab, -- the tab that shows it
	Label: string,
	Anchor: string,
	Focus: string,
	Fallback: string,
	Fov: number,
}

export type LegacyViewRow = { Key: string, Anchor: string, Focus: string }

-- Numbers of the 3D world (prep-3d.md §2, §8, §9; all Provisional, TASK-212 retouches them)
export type WorldRules = {
	-- tag and attribute names of the PrepTarget authoring contract (§2.2)
	Tag: string,
	Attr: { Kind: string, Slot: string, Key: string, Fov: string },
	-- hitbox sizing (§2.1): a target is at least MinPx on screen (touch target) and MinStuds in the world, x AssistScale with
	-- Assist; the sausage hitbox is Sausage.Length x Sausage.Width studs
	Hitbox: { MinPx: number, MinStuds: number, AssistScale: number, Sausage: { Length: number, Width: number } },
	Lift: number, -- studs: carried objects float this far over the work plane (§2.3)
	-- flip ring (§2.4): scale From -> To while the grill progress goes through Rules.Grill From..To; the ring is Good thick
	-- (Perfect thick inside the Perfect window); Late = scale of the small opaque ring after the window
	Ring: { From: number, To: number, Good: number, Perfect: number, Late: number, Turn: number, Hop: number },
	Hover: { Grow: number, Rise: number }, -- hovered target: scale x (1 + Grow), up Rise studs
	Attract: number, -- px: gamepad cursor snaps to a target closer than this (§9)
	Marker: number, -- studs: diameter of the 3D pointer marker
	Settle: number, -- s: snap with a tween when the server disagrees with the prediction (§2.5)
	-- the 3D grill (TASK-203; Provisional, TASK-212 retouches): ghost, ring and the little animations
	Grill: {
		GhostAlpha: number, -- Transparency of the ghost sausage on a free roller
		GhostBreath: number, -- how much it breathes (Transparency swing)
		RingRadius: number, -- studs: radius of the flip ring at Ring scale 1.0 (about the length of the sausage)
		Collect: number, -- s: flight of a collected sausage to the rail
		CollectArc: number, -- studs: height of that flight
		Shake: number, -- s: refusal shake of a sausage / the box
		ShakeAmount: number, -- studs
		Early: number, -- s: the shiver of a tap before the window (nothing is sent)
		CheckSize: number, -- studs: the check mark of a ready sausage
		Drag: number, -- px: a press that moves further than this is a drag, not a tap
	},
	-- per player client budget (§8); the 3D code never exceeds a row
	Budget: {
		Hitboxes: number,
		RaysPerFrame: number,
		Highlights: number,
		Rings: number,
		SauceSegmentsPerStroke: number,
		SauceSegmentsPerPlate: number,
		SaucePool: number,
		SauceMinStep: number, -- studs: stroke samples closer than this are dropped
		Tools: number,
		Ghosts: number,
		Sausages: number,
		Particles: number,
		Emitters: number,
		Tweens: number,
		ColorHz: number, -- cooking colour refresh
		EditableMeshes: number,
		LowQuality: number, -- GraphicsQualityLevel at or under which Highlight and bursts are skipped
	},
	-- Per-stage switch (prep-3d.md §11.3): false = that stage stays 2D. Only read when Rules.ThreeD is true.
	Stages: { Grill: boolean, Board: boolean, Toppings: boolean, Order: boolean, Serve: boolean },
	Editable: boolean, -- EditableMesh layer (prep-3d.md §6A); false until the S1b spike passes
	GhostHand: boolean, -- colleague's ghost hand (Q-233)
}

-- Cosmetic plate mask on PrepTab.Plate / PrepSeats.Plate (prep-3d.md §7.2 N3), see Prep/shared/PlateMask.luau
export type PlateMaskRules = {
	Bits: number, -- wire bits (Lync.int(0, 255))
	Cut: number, -- bit index of "bun cut"
	Sausage: number, -- bit index of "sausage placed"
	FirstTopping: number, -- bit index of Ingredients.ToppingKeys[1]; topping i is bit FirstTopping + i - 1
	MaxToppingKeys: number, -- Validate: #Ingredients.ToppingKeys must fit
}

export type Gesture = {
	Key: string,
	Hz: number, -- pointer sampling rate; 0 = discrete events (taps)
	MinPoints: number, -- fewer samples than this = no gesture (empty stroke)
	MaxPoints: number, -- the client keeps at most this many points (stroke reuse)
	Drag: boolean, -- the pointer is held down during the gesture
}

export type Tolerance = {
	Key: string, -- an Ingredients topping key, or bun_cut / sausage_place / grill_flip
	Gesture: string, -- key of Gestures
	Unit: string, -- what the raw error measures (documentation for the stage code)
	Perfect: number, -- largest raw error that still scores Perfect
	Good: number, -- largest raw error that still scores Good
	Worst: number, -- raw error where the score reaches 0
	ExcessWeight: number, -- sauces only: error = max(100 - coverage, excess x this); 0 elsewhere
	Icon: string,
}

export type Reason = {
	Key: string, -- PrepResult.Reason (wire enum value)
	Notice: string?, -- key of Notices shown to the owner, nil = silent
}

export type Rules = {
	Enabled: boolean,
	-- true brings the old world prompts back (grill_place ... discard); false hides them (prep-mode.md §7, DT-5)
	WorldKitchenPrompts: boolean,
	-- 3D-first prep (docs/tech/prep-3d.md, TASK-194). false = the 2D mode that runs today: `Tabs` and `Steps` below are the
	-- legacy sets (Order, Grill, Build, Serve). true = the 3D sets (Grill, Board, Toppings, Serve) and World.Stages decides per
	-- stage. Rollback without code: Stages.<X> = false, or ThreeD = false.
	ThreeD: boolean,
	World: WorldRules,
	Camera: { Fov: number, Travel: number, Leave: number, Pitch: number, Distance: number },
	ForcedExit: { Signal: number, NoInput: number }, -- s: leave animation on an anomaly signal, input block after it
	CueLock: number, -- s: re-entry locked after a forced exit by anomaly signal (Provisional, Q-221)
	ClientIdle: number, -- s without input before the client leaves (Parked)
	SeatIdle: number, -- s without a heartbeat before the server frees the seat
	Heartbeat: number, -- s between PrepTab keep-alives
	PlateMax: number, -- s: a plate open longer than this is dropped
	Reach: number, -- studs: a thief inside this radius of the trailer forces the exit (FEAT-039)
	MinPlate: number, -- s: server floor for cut + place (bun, sausage), plus PerTopping x K
	PerTopping: number, -- s per topping, floor of both the refusal and the Perfect cap
	PerfectMin: number, -- s: plate faster than this + PerTopping x K cannot be Perfect
	MsSlack: number, -- s: PrepFinish.Ms may exceed the server clock by this much
	Assist: number, -- tolerance multiplier of the Assist option
	TouchOffset: number, -- px: cursor drawn above the finger
	Grill: { Target: number, From: number, To: number }, -- flip window as fractions of the Duration
	-- max packets per second per player (PrepService); Finish and Begin are 1/s on purpose
	Rates: {
		Enter: number,
		Leave: number,
		Tab: number,
		Grill: number,
		Begin: number,
		Finish: number,
		Trash: number,
		Order: number,
	},
}

export type Grades = {
	Points: { Perfect: number, Good: number, Messy: number },
	Bands: { Perfect: number, Good: number }, -- minimum 0..100 score of each band
	Plate: { PerfectAvg: number, GoodAvg: number },
	Unflipped: number, -- score of a sausage that was never flipped (Q-222: Messy)
	Effects: { [Band]: { Tip: number?, TipWindow: number, Mood: number } }, -- Tip nil = as today (OrderRules.TipAmount)
	Labels: { [Band]: string },
}

export type Texts = {
	Next: string,
	Serve: string,
	Take: string,
	Leave: string,
	Trash: string,
	Assist: string,
	Waiting: string,
	Taken: string,
}

-- Tabs, 2D set (top bar, Rules.ThreeD = false). Order is the bar order.
const tabsLegacy = Table.new({
	{ Key = "Order", Label = "Order", Hint = "Take a ticket", Icon = "" },
	{ Key = "Grill", Label = "Grill", Hint = "Add sausages, flip near the middle", Icon = "" },
	{ Key = "Build", Label = "Build", Hint = "Slice, place, add toppings", Icon = "" },
	{ Key = "Serve", Label = "Serve", Hint = "Pick the matching customer", Icon = "" },
} :: { TabRow })

-- Tabs, 3D set (bottom bar, sections in sequence; prep-3d.md §3.0, DT-22). Order left the bar (Take is on the ticket and on
-- the customer in the Window view); Build split into Board and Toppings. Hints are one line, 36 characters at most.
const tabs3D = Table.new({
	{ Key = "Grill", Label = "Grill", Hint = "Flip when the ring closes", Icon = "" },
	{ Key = "Board", Label = "Board", Hint = "Cut the bun, place the sausage", Icon = "" },
	{ Key = "Toppings", Label = "Toppings", Hint = "Pick a topping, or press Next", Icon = "" },
	{ Key = "Serve", Label = "Serve", Hint = "Drag the plate to the window", Icon = "" },
} :: { TabRow })

-- Steps, 2D set: ordered flow of one plate; Bun and Build share the Build tab. View = the section it belongs to in 3D.
const stepsLegacy = Table.new({
	{
		Key = "grill",
		Tab = "Grill",
		View = "Grill",
		Label = "Grill",
		Hint = "Flip when the ring glows",
		NextLabel = "Next",
		Needs = "Nothing",
		Icon = "",
	},
	{
		Key = "bun",
		Tab = "Build",
		View = "Board",
		Label = "Bun",
		Hint = "Drag the knife along the line",
		NextLabel = "Next",
		Needs = "BunCut",
		Icon = "",
	},
	{
		Key = "build",
		Tab = "Build",
		View = "Board",
		Label = "Build",
		Hint = "Drag the sausage in, then add toppings",
		NextLabel = "Next",
		Needs = "PlateBuilt",
		Icon = "",
	},
	{
		Key = "serve",
		Tab = "Serve",
		View = "Window",
		Label = "Serve",
		Hint = "Pick the matching customer",
		NextLabel = "Serve",
		Needs = "TicketPicked",
		Icon = "",
	},
} :: { Step })

-- Steps, 3D set: the old `build` splits into `place` (Board section) and `toppings` (Toppings section).
const steps3D = Table.new({
	{
		Key = "grill",
		Tab = "Grill",
		View = "Grill",
		Label = "Grill",
		Hint = "Flip when the ring closes",
		NextLabel = "Next",
		Needs = "Nothing",
		Icon = "",
	},
	{
		Key = "bun",
		Tab = "Board",
		View = "Board",
		Label = "Bun",
		Hint = "Drag the knife along the line",
		NextLabel = "Next",
		Needs = "BunCut",
		Icon = "",
	},
	{
		Key = "place",
		Tab = "Board",
		View = "Board",
		Label = "Place",
		Hint = "Drag the sausage into the bun",
		NextLabel = "Next",
		Needs = "SausagePlaced",
		Icon = "",
	},
	{
		Key = "toppings",
		Tab = "Toppings",
		View = "Toppings",
		Label = "Toppings",
		Hint = "Pick a topping, or press Next",
		NextLabel = "Next",
		Needs = "Nothing",
		Icon = "",
	},
	{
		Key = "serve",
		Tab = "Serve",
		View = "Window",
		Label = "Serve",
		Hint = "Drag the plate to the window",
		NextLabel = "Serve",
		Needs = "TicketPicked",
		Icon = "",
	},
} :: { Step })

-- Camera views, one per 3D section (prep-3d.md §4.1, DT-14). The anchors live in each Station_n model; a missing anchor falls
-- back through Fallback (Poses, TASK-198). Toppings is the wide one: the bun in the middle and the bowls on both sides.
const views = Table.new({
	{ Key = "Grill", Tab = "Grill", Label = "Grill", Anchor = "CamAnchor", Focus = "Focus", Fallback = "", Fov = 0 },
	{ Key = "Board", Tab = "Board", Label = "Board", Anchor = "CamAnchor_Board", Focus = "Focus_Board", Fallback = "Build", Fov = 0 },
	{
		Key = "Toppings",
		Tab = "Toppings",
		Label = "Toppings",
		Anchor = "CamAnchor_Toppings",
		Focus = "Focus_Toppings",
		Fallback = "Board",
		Fov = 62,
	},
	{ Key = "Window", Tab = "Serve", Label = "Window", Anchor = "CamAnchor_Window", Focus = "Focus_Window", Fallback = "Board", Fov = 0 },
} :: { View })

-- The pair of the 2D mode, the Fallback "Build" of the Board view
const legacyView: LegacyViewRow = { Key = "Build", Anchor = "CamAnchor_Build", Focus = "Focus_Build" }

-- Every tab key that can cross the wire (PrepTab.Step, PrepSeats.Step enum), in first-seen order. Lync sorts enum names.
local wireTabs: { string } = {}
do
	const seen: { [string]: boolean } = {}
	for _, set in { tabsLegacy.Keys, tabs3D.Keys } do
		for _, key in set do
			if not seen[key] then
				seen[key] = true
				table.insert(wireTabs, key)
			end
		end
	end
	table.freeze(wireTabs)
end

-- Tab key of the other mode with the same meaning: lets the server and the map attribute `PromptStep` survive the flag
-- (resolve with `Tabs.ByKey[key] and key or TabAlias[key]`). Order was never a prompt step; it maps to the first section.
const tabAlias: { [string]: string } = { Order = "Grill", Build = "Board", Board = "Build", Toppings = "Build" }

-- Tool each topping puts in the hand (prep-3d.md §3.4; Provisional, TASK-201 fichas). Ladle is the spoon for a topping that
-- gets scooped; no topping uses it yet.
const toolOf = {
	ketchup = "Bottle",
	mustard = "Bottle",
	cream_cheese = "Bottle",
	cheese = "Slice",
	bacon = "Strip",
	potato_sticks = "Pinch",
}

-- Gestures. Sampling 30 Hz; a sauce stroke is resampled to at most 64 points (prep-mode.md §6, performance).
const gestures = Table.new({
	{ Key = "slice", Hz = 30, MinPoints = 8, MaxPoints = 120, Drag = true },
	{ Key = "place", Hz = 30, MinPoints = 3, MaxPoints = 90, Drag = true },
	{ Key = "trace", Hz = 30, MinPoints = 12, MaxPoints = 64, Drag = true },
	{ Key = "slide", Hz = 30, MinPoints = 4, MaxPoints = 90, Drag = true },
	{ Key = "taps", Hz = 0, MinPoints = 3, MaxPoints = 3, Drag = false },
	{ Key = "hold", Hz = 30, MinPoints = 2, MaxPoints = 90, Drag = false },
} :: { Gesture })

-- Tolerances (FEAT-039 tables; Provisional, Q-219). Raw error, lower is better:
--   bun_cut         mean lateral deviation from the guide, % of the bun width (Perfect <= 6, Good <= 15)
--   sausage_place   distance of the centre to the target, % of the bun length (<= 10, <= 22)
--   sauces          max(100 - coverage %, excess % x ExcessWeight): Perfect = coverage >= 85 and excess <= 10 (15),
--                   Good = coverage >= 60 and excess <= 25 (40; excess is allowed up to 26.7, the pair collapses to one number)
--   cheese          deviation of the slice from the target, % (<= 12, <= 25)
--   bacon           mean timing error of the 3 taps, ms (<= 120, <= 250)
--   potato_sticks   release distance from the green band, % of the bar (<= 8, <= 18)
--   grill_flip      |flip time - half of the Duration|, % of the Duration (window 40%..60%: Good <= 10, Perfect <= 5)
-- A new topping is one row here (key = Ingredients key).
const tolerances = Table.new({
	{ Key = "bun_cut", Gesture = "slice", Unit = "PercentWidth", Perfect = 6, Good = 15, Worst = 40, ExcessWeight = 0, Icon = "" },
	{ Key = "sausage_place", Gesture = "place", Unit = "PercentLength", Perfect = 10, Good = 22, Worst = 60, ExcessWeight = 0, Icon = "" },
	{ Key = "ketchup", Gesture = "trace", Unit = "PercentCoverage", Perfect = 15, Good = 40, Worst = 80, ExcessWeight = 1.5, Icon = "" },
	{ Key = "mustard", Gesture = "trace", Unit = "PercentCoverage", Perfect = 15, Good = 40, Worst = 80, ExcessWeight = 1.5, Icon = "" },
	{ Key = "cream_cheese", Gesture = "trace", Unit = "PercentCoverage", Perfect = 15, Good = 40, Worst = 80, ExcessWeight = 1.5, Icon = "" },
	{ Key = "cheese", Gesture = "slide", Unit = "PercentTarget", Perfect = 12, Good = 25, Worst = 60, ExcessWeight = 0, Icon = "" },
	{ Key = "bacon", Gesture = "taps", Unit = "Milliseconds", Perfect = 120, Good = 250, Worst = 600, ExcessWeight = 0, Icon = "" },
	{ Key = "potato_sticks", Gesture = "hold", Unit = "PercentBar", Perfect = 8, Good = 18, Worst = 50, ExcessWeight = 0, Icon = "" },
	{ Key = "grill_flip", Gesture = "taps", Unit = "PercentDuration", Perfect = 5, Good = 10, Worst = 50, ExcessWeight = 0, Icon = "" },
} :: { Tolerance })

-- PrepResult.Reason. Notice = what the owner reads (Notices key); nil = the UI reacts on its own.
const reasons = Table.new({
	{ Key = "None" },
	{ Key = "Busy", Notice = "prep_busy" },
	{ Key = "Seated" },
	{ Key = "NotSelling", Notice = "shop_closed" },
	{ Key = "NoStation" },
	{ Key = "Locked", Notice = "prep_locked" },
	{ Key = "Invalid" },
	{ Key = "TooFast", Notice = "prep_too_fast" },
	{ Key = "NoSession" },
	{ Key = "NoStock", Notice = "out_of_stock" },
	{ Key = "NoSausage", Notice = "prep_no_sausage" },
	{ Key = "HandsFull", Notice = "hands_full" },
	{ Key = "Rate" },
	{ Key = "NoTicket" },
	-- forced exits (PrepResult Act = Kick)
	{ Key = "KickSignal", Notice = "prep_kicked" },
	{ Key = "KickSanity", Notice = "prep_kicked" },
	{ Key = "KickDown", Notice = "prep_kicked" },
	{ Key = "KickCutscene" },
	{ Key = "KickCall" },
	{ Key = "KickClosing" },
	{ Key = "KickThief", Notice = "prep_kicked" },
	{ Key = "KickIdle", Notice = "prep_idle" },
	{ Key = "KickAway" },
} :: { Reason })

const rules: Rules = {
	Enabled = true,
	WorldKitchenPrompts = false, -- DEC-223: the world prompts of the kitchen are hidden; true = rollback without code
	ThreeD = true, -- prep-3d.md §11.3: flips Tabs / Steps to the 3D sets and arms World.Stages (the 2D mode runs while false). On since TASK-203 (the owner plays the 3D grill); Board, Toppings and Serve still use the 2D stages through TabAlias
	World = {
		Tag = "PrepTarget",
		Attr = { Kind = "TargetKind", Slot = "Slot", Key = "Key", Fov = "Fov" },
		-- 44 px touch target = 0.31 stud at 2.5 studs from the camera (prep-3d.md §2.1); x1.3 with Assist (Rules.Assist applies to
		-- the tolerances, this one to the hitboxes)
		Hitbox = { MinPx = 44, MinStuds = 0.31, AssistScale = 1.3, Sausage = { Length = 1.1, Width = 0.5 } },
		Lift = 0.35,
		Ring = { From = 1.8, To = 1.0, Good = 0.06, Perfect = 0.1, Late = 0.6, Turn = 0.2, Hop = 0.25 },
		Hover = { Grow = 0.04, Rise = 0.05 },
		Attract = 80,
		Marker = 0.12,
		Settle = 0.15,
		Grill = {
			GhostAlpha = 0.5,
			GhostBreath = 0.08,
			RingRadius = 0.62,
			Collect = 0.22,
			CollectArc = 0.45,
			Shake = 0.3,
			ShakeAmount = 0.06,
			Early = 0.25,
			CheckSize = 0.34,
			Drag = 14,
		},
		Budget = {
			Hitboxes = 40,
			RaysPerFrame = 1,
			Highlights = 12,
			Rings = 10,
			SauceSegmentsPerStroke = 24,
			SauceSegmentsPerPlate = 72,
			SaucePool = 80,
			SauceMinStep = 0.08,
			Tools = 1,
			Ghosts = 3,
			Sausages = 8,
			Particles = 150,
			Emitters = 8,
			Tweens = 6,
			ColorHz = 10,
			EditableMeshes = 6,
			LowQuality = 3,
		},
		Stages = { Grill = true, Board = false, Toppings = false, Order = false, Serve = false },
		Editable = false,
		GhostHand = false,
	},
	Camera = { Fov = 55, Travel = 0.35, Leave = 0.30, Pitch = -55, Distance = 2.5 }, -- FEAT-039
	ForcedExit = { Signal = 0.4, NoInput = 0.5 }, -- Q-221 A
	CueLock = 6,
	ClientIdle = 20, -- FEAT-039: 20 s without input = Parked
	SeatIdle = 60,
	Heartbeat = 15,
	PlateMax = 90,
	Reach = 14,
	-- skilled plate with K = 2 takes ~6..8 s of gesture time: floor 3.4 s (refused), Perfect cap 4.6 s
	MinPlate = 1.8,
	PerTopping = 0.8,
	PerfectMin = 3.0,
	MsSlack = 1.5,
	Assist = 1.3,
	TouchOffset = 28,
	Grill = { Target = 0.5, From = 0.4, To = 0.6 }, -- FEAT-039 / Q-222: flip near the middle, no burning
	Rates = { Enter = 2, Leave = 2, Tab = 4, Grill = 6, Begin = 1, Finish = 1, Trash = 2, Order = 4 },
}

-- What the code sees as `Tabs` / `Steps`: the set of the current mode. All 2D code keeps reading these and gets the legacy
-- sets while Rules.ThreeD is false (compat, TASK-194); the 3D code and the wire read the named sets.
const tabs = if rules.ThreeD then tabs3D else tabsLegacy
const steps = if rules.ThreeD then steps3D else stepsLegacy

-- PrepTab.Plate / PrepSeats.Plate (prep-3d.md §7.2 N3): bit 0 bun cut, bit 1 sausage placed, bits 2..7 the toppings in the
-- order of Ingredients.ToppingKeys. Cosmetic only (the colleague's puppet); the server accepts a mask that only grows and
-- has at most OrderRules.MaxToppings topping bits; zero at Begin / Finish / Trash / Leave. Helpers: Prep/shared/PlateMask.
const plateMask: PlateMaskRules = { Bits = 8, Cut = 0, Sausage = 1, FirstTopping = 2, MaxToppingKeys = 6 }

const grades: Grades = {
	Points = { Perfect = 100, Good = 70, Messy = 30 }, -- FEAT-039
	Bands = { Perfect = 85, Good = 55 },
	Plate = { PerfectAvg = 88, GoodAvg = 60 }, -- FEAT-039
	Unflipped = 0,
	Effects = {
		Perfect = { Tip = 2, TipWindow = 4, Mood = 0 }, -- Q-219 B: only tip and mood, never the price
		Good = { TipWindow = 0, Mood = 0 },
		Messy = { Tip = 0, TipWindow = 0, Mood = -1 },
	},
	Labels = { Perfect = "Perfect!", Good = "Good", Messy = "Messy" },
}

const texts: Texts = {
	Next = "Next",
	Serve = "Serve",
	Take = "Take",
	Leave = "Leave",
	Trash = "Trash",
	Assist = "Assist",
	Waiting = "Waiting for the grill",
	Taken = "Taken",
}

-- Build tab (TASK-176 gestures, TASK-178 stages; Provisional, no DEC). Geometry in the space of the BUN: 0..1 on both axes,
-- x to the right, y down (the bun is wider than tall, so lengths in % use the bun width / length). Times in seconds.
--   Cut       knife line: Y (middle), From..To (where the line starts and ends), Done (the cut is complete past this x),
--             Hold (seconds of the hold-instead-of-drag sweep)
--   Groove    where the sausage and the cheese slice belong; Magnet = a drop closer than this (% of the bun length) snaps in
--   Sauce     zig-zag Path to trace, Reach (a path point counts as covered when a stroke is this close, in bun heights),
--             Spill (a stroke point farther than this from the path is excess), Meter (amount of sauce, 1 = the path length;
--             the window is what the meter shows as the green zone), Fill (seconds of the hold-instead-of-trace pour)
--   Bacon     Count rings, one every Gap s, each shrinking for Shrink s, the first shows Lead s after the pick; a ring
--             not tapped Late s after it closed is a miss worth Miss ms of error
--   Potato    hold fills the bar in Fill s; release at Target (0..1) of the bar
--   MinHold   a press shorter than this is a stray touch, not a gesture
const build = {
	Cut = { Y = 0.5, From = 0.04, To = 0.96, Done = 0.94, Hold = 1.0 },
	Groove = { X = 0.5, Y = 0.5 },
	Magnet = 20,
	HoldPlace = 0.35,
	Sauce = {
		Path = { { X = 0.10, Y = 0.20 }, { X = 0.30, Y = 0.80 }, { X = 0.50, Y = 0.20 }, { X = 0.70, Y = 0.80 }, { X = 0.90, Y = 0.20 } },
		Reach = 0.15,
		Spill = 0.4,
		Meter = { Target = 0.77, Window = 0.31, Max = 1.3 },
		Fill = 1.4,
	},
	Bacon = { Count = 3, Gap = 0.55, Shrink = 0.9, Lead = 0.5, Late = 0.45, Miss = 600, X = { 0.25, 0.5, 0.75 }, Y = 0.5 },
	Potato = { Fill = 1.4, Target = 0.7, Window = 0.36 },
	MinHold = 0.15,
	-- short UI lines of the Build tab (English, DEC-022)
	Texts = {
		Sausage = "Sausage",
		HoldMode = "Hold",
		PlaceFirst = "Place the sausage first",
		Ready = "Plate ready. Serve it",
		NoBun = "Out of buns",
		Closed = "We are closed",
		Retry = "Pick the tab again to retry",
		Expired = "Plate expired",
		Full = "Plate is full. Press Next",
		Hints = {
			slice = "Drag the knife along the line",
			slice_hold = "Hold on the line",
			place = "Drag the sausage into the bun",
			place_hold = "Hold where the sausage goes",
			trace = "Trace the zig-zag",
			trace_hold = "Hold to pour, release in the green",
			slide = "Drag the slice onto the bun",
			slide_hold = "Hold where the slice goes",
			taps = "Tap each ring as it closes",
			hold = "Hold, release in the green",
			add = "Add a topping or press Next",
		},
	},
}

return Table.record({
	Build = build,
	Rules = rules,
	Tabs = tabs,
	Steps = steps,
	-- the fixed sets, whatever Rules.ThreeD says (Tabs / Steps above equal one of each pair)
	TabsLegacy = tabsLegacy,
	Tabs3D = tabs3D,
	StepsLegacy = stepsLegacy,
	Steps3D = steps3D,
	WireTabs = wireTabs, -- every tab key on the wire: Net PrepTab.Step and PrepSeats.Step
	TabAlias = tabAlias,
	Views = views,
	LegacyView = legacyView,
	TargetKinds = {
		"GrillSlot",
		"SausageStock",
		"Rail",
		"BunCrate",
		"Board",
		"Knife",
		"Topping",
		"Bin",
		"Hatch",
		"Customer",
	} :: { TargetKind },
	ToolKinds = { "None", "Knife", "Sausage", "Bottle", "Ladle", "Slice", "Strip", "Pinch", "Plate", "Spatula" } :: { ToolKind },
	ToolOf = toolOf :: { [string]: ToolKind },
	SlotPhases = { "Free", "Ghost", "Cooking", "FlipWindow", "Late", "Flipped", "Ready" } :: { SlotPhase },
	PlateMask = plateMask,
	Gestures = gestures,
	Tolerances = tolerances,
	Grades = grades,
	Reasons = reasons,
	Texts = texts,
	-- PrepResult.Act (wire enum)
	Acts = { "Enter", "Leave", "Tab", "Grill", "Begin", "Finish", "Trash", "Order", "Kick" },
	-- PrepResult.Grade (wire enum); None = the act has no grade
	GradeKeys = { "None", "Messy", "Good", "Perfect" },
	GrillActs = { "Place", "Flip", "Collect" }, -- PrepGrill.Act
	OrderActs = { "Take", "Serve", "Refuse" }, -- PrepOrder.Act
	Stations = 4, -- PrepEnter.Station 1..4, PrepSeats records (BoardSlots of the trailer)
})
