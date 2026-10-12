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

export type Tab = "Order" | "Grill" | "Build" | "Serve"
export type Band = "Perfect" | "Good" | "Messy"
export type Need = "Nothing" | "BunCut" | "PlateBuilt" | "TicketPicked"

export type TabRow = {
	Key: string, -- Tab (wire enum value, PascalCase)
	Label: string,
	Hint: string,
	Icon: string, -- rbxassetid, "" = placeholder
}

export type Step = {
	Key: string,
	Tab: Tab,
	Label: string,
	Hint: string,
	NextLabel: string, -- text of the corner button on this step
	Needs: Need, -- what enables the corner button
	Icon: string,
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

-- Tabs (top bar). Order is the bar order.
const tabs = Table.new({
	{ Key = "Order", Label = "Order", Hint = "Take a ticket", Icon = "" },
	{ Key = "Grill", Label = "Grill", Hint = "Add sausages, flip near the middle", Icon = "" },
	{ Key = "Build", Label = "Build", Hint = "Slice, place, add toppings", Icon = "" },
	{ Key = "Serve", Label = "Serve", Hint = "Pick the matching customer", Icon = "" },
} :: { TabRow })

-- Steps: ordered flow of one plate; Bun and Build share the Build tab.
const steps = Table.new({
	{ Key = "grill", Tab = "Grill", Label = "Grill", Hint = "Flip when the ring glows", NextLabel = "Next", Needs = "Nothing", Icon = "" },
	{ Key = "bun", Tab = "Build", Label = "Bun", Hint = "Drag the knife along the line", NextLabel = "Next", Needs = "BunCut", Icon = "" },
	{
		Key = "build",
		Tab = "Build",
		Label = "Build",
		Hint = "Drag the sausage in, then add toppings",
		NextLabel = "Next",
		Needs = "PlateBuilt",
		Icon = "",
	},
	{ Key = "serve", Tab = "Serve", Label = "Serve", Hint = "Pick the matching customer", NextLabel = "Serve", Needs = "TicketPicked", Icon = "" },
} :: { Step })

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

return Table.record({
	Rules = rules,
	Tabs = tabs,
	Steps = steps,
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
