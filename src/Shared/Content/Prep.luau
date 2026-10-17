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
export type Delivery = "Prompt" | "Window"
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
	| "Plate"

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
	-- Procedural pose (feedback 2026-10-12, G): when Pitch or Distance is not 0 the frame is DERIVED from the Focus attachment
	-- (Poses.luau) instead of read from the Anchor: Pitch in degrees (negative looks down), Distance in studs from the eye to the
	-- point looked at, Dolly = studs the point slides along the way the anchor faces (+ = away from the player), Side = studs it
	-- slides toward the screen right (+ = right). The anchor then only gives the yaw (and the fallback when the Focus is missing).
	Pitch: number,
	Distance: number,
	Dolly: number,
	Side: number,
}

export type LegacyViewRow = { Key: string, Anchor: string, Focus: string }

-- Free pan along the trail of stations (feedback 2026-10-12, H; Provisional). The camera follows a point `u` of the trail (Grill ->
-- Board -> Toppings, one station per tab) that a finger on empty space or the mouse at the screen edge moves 1:1; it coasts and stops
-- anywhere. The active station (stage, targets) is the nearest one, with hysteresis.
export type PanRules = {
	Slop: number, -- px: a press on empty space that moves more than this is a pan (small: the drag is 1:1 with the pointer)
	Decay: number, -- 1/s: after a release (or leaving the screen edge) the speed fades as exp(-Decay t); nothing snaps to a station
	StopSpeed: number, -- studs per second: below this the coast ends
	Hyst: number, -- trail units (0..1): the active station changes when another is this much closer than the current one
	Edge: number, -- fraction of the screen width at the border where the mouse scrolls
	EdgeSpeed: number, -- studs per second at the very border (smooth ramp from 0 at the inner line)
	Dots: { Size: number, Active: number, Gap: number }, -- px of the indicator dots (the hit area stays 44)
}

-- The 3D Board section (TASK-204): the working bun is drawn Scale times the kit bun so a finger can cut it; every number Provisional
export type BoardRules = {
	Scale: number, -- the working bun, x the AST-001 bun
	Lift: number, -- studs over the board
	Guide: { Dashes: number, Width: number, Lift: number }, -- the dashed cut line (Parts, pool of Dashes)
	Open: { Time: number, Hop: number }, -- BunClosed -> BunOpen: seconds and hop in studs
	Close: number, -- s: the bun closes over the plate on Next
	Knife: { Height: number, Tilt: number, Spring: number }, -- the tool: studs over the bun, degrees of lean, 1/s catch-up
	Carry: { Spring: number, Alpha: number }, -- a carried sausage / plate: catch-up and ghost Transparency
	Bin: { Right: number, Back: number, Size: number }, -- PLACEHOLDER bin on the bench: studs to the right / toward the player of the plate
	Shift: { Right: number, Back: number }, -- the plate slides this far (studs, from the middle of the board) when the Toppings view takes over: to the middle of the bowls (Right) and in front of them, between them and the player (Back)
	Slide: number, -- s: that slide
	Crumbs: number, -- particles of the cut
}

-- The 3D Toppings section (TASK-205): tools in hand and the sauce stroke; every number Provisional
export type ToppingRules = {
	Stroke: {
		Width: number, -- studs (x the bun scale): the sauce tube diameter
		Height: number,
		Smooth: number, -- cylinders per Catmull-Rom piece
		Joint: number, -- joint ball diameter x the tube diameter (1 = no bulge)
		Taper: number, -- share of the width lost at the tip
		Shine: number, -- Reflectance (wet shine)
		Variance: number, -- share of the width that breathes along the stroke (slow, smooth)
		Threshold: number, -- studs the pointer must move over the bun after the press before the sauce flows (select, then drag)
		Done: number, -- share of the guide covered that lands the topping on release (1 = never early)
		MinAmount: number, -- path lengths of sauce below which a deselect drops the stroke instead of landing it
		Margin: { X: number, Y: number }, -- bun lengths / widths past the bun edge where the sauce still records (the plane of the bun)
	},
	Bottle: { Length: number, Radius: number, Tilt: number, Rise: number, Spring: number }, -- placeholder bottle (degrees, studs)
	Dot: { Size: number, Step: number }, -- guide dots of the zig-zag
	Ring: { Radius: number, Thick: number }, -- bacon rings and the potato target ring (x the bun scale)
	Potato: { From: number }, -- share of the mound at the start of the hold
	Hand: { Spring: number, Rise: number }, -- cheese slice / strip / pinch following the pointer
}

-- The juice of the 3D prep (World/Juice, 2026-10-12 polish): pops, bursts, floating words, flashes. Its OWN particle budget, apart
-- from the 150 of KitchenController/Fx, and the Highlights it keeps out of Budget.Highlights. Reduced motion and LowQuality skip bursts.
export type PresenceRules = {
	Palette: { Color3 },
	Highlights: number,
	Fill: number, -- Highlight.FillTransparency of the working arm
	Range: number,
	Tag: { Width: number, Height: number, Lift: number },
}

-- Live drag (DEC-259, closes Q-233; TASK-349/350): the colleague's held item seen by everyone, and the grill / rail claim
export type GhostRules = {
	Hz: number, -- PrepPointer send rate (the Net packet is newest(Hz))
	MaxDistance: number, -- studs: a pointer farther than this from the seat's board is dropped by the server
	Stale: number, -- s without a PrepGhost of a station before its ghost fades out (clients)
	Lerp: number, -- smoothing of the ghost position (exponential rate per s, clients)
	GrabLease: number, -- s a grill / rail claim lives without being renewed or released (server)
	Fill: number, -- Highlight.FillTransparency of the ghost item (colour = Presence.Palette[station])
}

export type JuiceRules = {
	Particles: number, -- live particles of the prep (own budget)
	Emitters: number, -- live emitters of the prep
	Flashes: number, -- Highlight instances reserved to Flash (taken from Budget.Highlights)
	Floats: number, -- floating words alive at once
	Pop: { Time: number, Amount: number }, -- squash and stretch of a landing: seconds, share of the size
	Float: { Rise: number, Time: number, Size: number }, -- a floating word: studs it rises, seconds, TextSize
	Flash: { Time: number, Fill: number }, -- a flash: seconds, starting FillTransparency
	Combo: { Show: number, Pitch: number, Cap: number }, -- Perfects in a row before the chip shows; PlaybackSpeed per step; steps counted
	Count: number, -- s: the grade counter of the seal rolls 0 -> N
	Confetti: { Perfect: number, Good: number, Messy: number }, -- pieces by band
}

-- The drag tutorial (World/Coach, 2026-10-12): a 3D ghost hand loops the gesture of the section once per station per session.
export type CoachRules = {
	Loop: number, -- s: one pass of the gesture
	Rest: number, -- s: pause between two passes
	Hand: { Palm: number, Lift: number, Alpha: number }, -- studs of the palm, studs over the work plane, Transparency
	Dashes: number, -- the trail of the gesture
	Max: number, -- passes before it stops by itself
}

-- The virtual bin of each view (World/Bin, 2026-10-12): a local clone of the bin anchored to the camera frame of the view, lower
-- left of the screen, so a sausage or a plate can be dragged to it from any section.
export type BinRules = {
	Screen: { X: number, Y: number }, -- share of the viewport (0,0 = top left) where its centre sits
	Depth: number, -- share of the distance from the camera to the plate (the focus of the view) the bin stands at: it is as big as what it takes
	Size: number, -- studs of the lid
	Hit: number, -- studs of the (invisible) hitbox, a finger needs 44 px
	Lid: number, -- degrees the lid opens on hover
	Eat: number, -- s: the item shrinks and falls in
}

-- The placeholder bar grill (World/GrillRig, decision of 2026-10-12): Parts only until AST-120 exists. Bars run across the slots,
-- the sausage lies across them and is FLIPPED (not rolled). Numbers in studs of the slot pose (X = along the sausage).
export type GrillRigRules = {
	Placeholder: boolean, -- false = the roller grill of the trailer stays visible and nothing here is drawn
	-- AST-120 (the final model, another task): 4.6 x 2.6 studs, 0.62 high to the top of the bars, pivot at the centre of the base,
	-- Bar_1..Bar_14 along the depth, 8 slots (2 columns x 4 rows), the sausage lies along X with its centre 0.12 over the bars.
	-- The placeholder names its Parts like the model (Base, Frame, Bar_n, Tray, Burner, Flame) so the swap is a model swap.
	Bars: number, -- Bar_1..Bar_n
	BarRadius: number,
	BarGap: number, -- studs between two bars (along the depth)
	Margin: number, -- studs of plate around the outer slots
	Height: number, -- studs from the base to the top of the bars
	Tray: { Depth: number, Drop: number }, -- the drip tray in front
	Heat: { Cold: number, Warm: number, Hot: number }, -- cooking share where the bars are grey, orange, bright
	Marks: { Count: number, Width: number, Length: number }, -- grill marks on the face that was down
	-- AST-120 slot grid for the day the map is re-authored: Slot n at (X, depth) in studs of the model, depth + toward the player
	Slots: { { X: number, Depth: number } },
}

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
		FocusRadius: number, -- studs: the ring of the flip focus screen around the sausage that waits (World/FlipFocus)
		Early: number, -- s: the shiver of a tap before the window (nothing is sent)
		CheckSize: number, -- studs: the check mark of a ready sausage
		Drag: number, -- px: a press that moves further than this is a drag, not a tap
	},
	-- the 3D serve at the window (TASK-206; Provisional, TASK-212 retouches): the plate rests on the cook side of the sill and is
	-- dragged (or tapped, or Serve) to the Hatch; the customer takes it
	Serve: {
		RestSide: number, -- studs: the resting plate sits this far to the left of the tray (the Window view looks steeply down at the sill)
		RestAway: number, -- studs: and this far from the camera toward the window
		PlateRadius: number, -- studs: the placeholder plate (no plate model exists yet, AST-120+)
		TrayLength: number, -- studs: the placeholder tray on the sill (the Hatch target)
		Fly: number, -- s: the plate flies to the customer after Serve is sent
		Return: number, -- s: it flies back (refused, or a Wrong verdict that keeps the plate)
		Verdict: number, -- s: the verdict line stays over the customer (under the 1.2 s the plate is cleared after)
		HandLift: number, -- studs over the customer's root part the plate ends at
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
	-- the 3D Board and Toppings sections (TASK-204, 205; Provisional, TASK-212 retouches): the working bun, the cut guide, the tools
	Board: BoardRules,
	Toppings: ToppingRules,
	Editable: boolean, -- EditableMesh layer (prep-3d.md §6A); false until the S1b spike passes
	GhostHand: boolean, -- colleague's live drag (DEC-259; was Q-233): PrepPointer / PrepGhost / PrepGrab / PrepClaims
	Ghost: GhostRules,
	Presence: PresenceRules, -- co-op presence: the colleague's working arm, name and colour (Rig/Mates.luau)
	Juice: JuiceRules,
	Coach: CoachRules,
	Bin: BinRules,
	Rig: GrillRigRules,
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
	-- how the finished hot dog reaches the customer (owner decision 2026-10-12). "Prompt" = the prep mode ends after the seal and
	-- the hot dog is in the hand; the customer's world `serve` prompt delivers it (no Serve tab, step or view). "Window" = the old
	-- Serve tab (rollback without code; the legacy and 3D Serve stages come back with it).
	Delivery: Delivery,
	DoneHold: number, -- s: the seal and the confetti stay after an accepted Finish before the mode ends by itself (Delivery = "Prompt")
	World: WorldRules,
	Camera: {
		Fov: number,
		Travel: number,
		Min: number,
		Max: number,
		Leave: number,
		Pitch: number,
		Distance: number,
		Fade: number,
		Pan: PanRules,
	},
	ForcedExit: { Signal: number, NoInput: number }, -- s: leave animation on an anomaly signal, input block after it
	CueLock: number, -- s: re-entry locked after a forced exit by anomaly signal (Provisional, Q-221)
	ClientIdle: number, -- s without input before the client leaves (Parked)
	SeatIdle: number, -- s without a heartbeat before the server frees the seat
	Heartbeat: number, -- s between PrepTab keep-alives
	PlateMax: number, -- s: ceiling of a plausible plate age (Grade.Plausible); no plate is dropped by time any more (TASK-289)
	-- s: the open plate never ages past this on the server (it never expires: first a rookie's only, every plate since TASK-289,
	-- owner request 2026-10-14); the client caps PrepFinish.Ms at it too, so the clocks stay plausible
	-- (owner report 2026-10-14 "my bun disappeared", docs/tasks/playtest-2026-10-14.md)
	TutorialPlateAge: number,
	Reach: number, -- studs: a thief inside this radius of the trailer forces the exit (FEAT-039)
	MinPlate: number, -- s: server floor for cut + place (bun, sausage), plus PerTopping x K
	PerTopping: number, -- s per topping, floor of both the refusal and the Perfect cap
	PerfectMin: number, -- s: plate faster than this + PerTopping x K cannot be Perfect
	MsSlack: number, -- s: PrepFinish.Ms may exceed the server clock by this much
	Assist: number, -- tolerance multiplier of the Assist option
	TouchOffset: number, -- px: cursor drawn above the finger
	-- Flip: the sausage cooks its first side (Duration - PostFlip s), WAITS for the flip (the progress is paused, the window is
	-- open), and PostFlip s after the flip it is ready. Target / From / To = the window on the progress the client draws (the
	-- pause sits on Target); Reaction = flip score error per second of delay after the pause (Tolerances grill_flip).
	-- Swing (TASK-257, owner request 2026-10-14): s the flip cursor takes from one end of the bar to the other; in the pause it goes
	-- back and forth until the tap, and the flip is graded by where it is (Grade.SwingAt / FlipScore). Reaction: unused since then
	Grill: { Target: number, From: number, To: number, PostFlip: number, Reaction: number, Swing: number },
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
	Done: string, -- the corner button of the last step when Rules.Delivery = "Prompt"
	Serve: string,
	Take: string,
	Leave: string,
	Trash: string,
	Assist: string,
	Waiting: string,
	Taken: string,
	Perfect: string,
	Combo: string,
	BinTip: string,
	TrashBusy: string,
	TrashEmpty: string,
	Trashed: string,
	FlipAlert: string, -- the chip that calls the player back to the grill while a flip window is open on another tab
	Coach: { Pan: string, Grill: string, Board: string, Sausage: string, Toppings: string, Deliver: string, Serve: string },
}

-- Delivery (Rules.Delivery). "Prompt": the Serve tab, its steps and the Window view leave every set; the last step of the plate is
-- Done (Next = Done) and the mode ends. The raw lists below keep the Serve rows for "Window" (rollback without code).
const DELIVERY: Delivery = "Prompt"

local function withoutServe<T>(list: { T }, doneLabel: boolean): { T }
	if DELIVERY ~= "Prompt" then
		return list
	end
	const kept: { T } = {}
	for _, row in list do
		const key = (row :: any).Key
		if key ~= "serve" and key ~= "Serve" and key ~= "Window" then
			table.insert(kept, row)
		end
	end
	if doneLabel and #kept > 0 then
		const last = table.clone(kept[#kept] :: any)
		last.NextLabel = "Done"
		kept[#kept] = last
	end
	return kept
end

-- Tabs, 2D set (top bar, Rules.ThreeD = false). Order is the bar order.
const tabsLegacyRaw = {
	{ Key = "Order", Label = "Order", Hint = "Take a ticket", Icon = "" },
	{ Key = "Grill", Label = "Grill", Hint = "Add sausages, flip near the middle", Icon = "" },
	{ Key = "Build", Label = "Build", Hint = "Slice, place, add toppings", Icon = "" },
	{ Key = "Serve", Label = "Serve", Hint = "Pick the matching customer", Icon = "" },
} :: { TabRow }
const tabsLegacy = Table.new(withoutServe(tabsLegacyRaw, false))

-- Tabs, 3D set (bottom bar, sections in sequence; prep-3d.md §3.0, DT-22). Order left the bar (Take is on the ticket and on
-- the customer in the Window view); Build split into Board and Toppings. Hints are one line, 36 characters at most.
const tabs3DRaw = {
	{ Key = "Grill", Label = "Grill", Hint = "Flip when the bar stops", Icon = "" },
	{ Key = "Board", Label = "Board", Hint = "Cut the bun, place the sausage", Icon = "" },
	{ Key = "Toppings", Label = "Toppings", Hint = "Pick a topping, or press Next", Icon = "" },
	{ Key = "Serve", Label = "Serve", Hint = "Drag the plate to the window", Icon = "" },
} :: { TabRow }
const tabs3D = Table.new(withoutServe(tabs3DRaw, false))

-- Steps, 2D set: ordered flow of one plate; Bun and Build share the Build tab. View = the section it belongs to in 3D.
const stepsLegacyRaw = {
	{
		Key = "grill",
		Tab = "Grill",
		View = "Grill",
		Label = "Grill",
		Hint = "Tap to flip when the bar stops",
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
} :: { Step }
const stepsLegacy = Table.new(withoutServe(stepsLegacyRaw, true))

-- Steps, 3D set: the old `build` splits into `place` (Board section) and `toppings` (Toppings section).
const steps3DRaw = {
	{
		Key = "grill",
		Tab = "Grill",
		View = "Grill",
		Label = "Grill",
		Hint = "Flip when the bar stops",
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
} :: { Step }
const steps3D = Table.new(withoutServe(steps3DRaw, true))

-- Camera views, one per 3D section (prep-3d.md §4.1, DT-14). The anchors live in each Station_n model; a missing anchor falls
-- back through Fallback (Poses, TASK-198). Toppings is the wide one: the bun in the middle and the bowls on both sides.
const viewsRaw = {
	-- Grill: the sausage container (SausageStock, +X of the grill) and the roller grill in one frame, seen from above. Pitch /
	-- Distance / Dolly / Side derive the frame from the Focus (Poses.luau); Side moves the middle of the frame toward the container.
	{
		Key = "Grill",
		Tab = "Grill",
		Label = "Grill",
		Anchor = "CamAnchor",
		Focus = "Focus",
		Fallback = "",
		Fov = 0,
		Pitch = -65,
		Distance = 5.9,
		Dolly = 0,
		Side = -1.2, -- 2026-10-14: was -2.4; the owner could not centre the sausage container, the frame moves 1.2 studs to the screen right
	},
	-- Board and Toppings share Pitch, Distance and Fov, so going from one to the other is a plain slide of the frame: the bun keeps
	-- its size on screen (before, the two views had different distances and the bun "grew").
	{
		Key = "Board",
		Tab = "Board",
		Label = "Board",
		Anchor = "CamAnchor_Board",
		Focus = "Focus_Board",
		Fallback = "Build",
		Fov = 0,
		Pitch = -65,
		Distance = 5.9,
		Dolly = 0,
		Side = 0,
	},
	{
		Key = "Toppings",
		Tab = "Toppings",
		Label = "Toppings",
		Anchor = "CamAnchor_Toppings",
		Focus = "Focus_Toppings",
		Fallback = "Board",
		Fov = 76, -- wider than the Board view (62): the real board AND the bowls in one frame, same eye height (the roof stops a farther eye)
		Pitch = -65,
		Distance = 5.9,
		Dolly = 0,
		Side = 3.0, -- 2026-10-14: was -0.5, which centred the bun crate; the bowls and the plate are ~3.4 studs to the screen right (x -51.9)
	},
	{
		Key = "Window",
		Tab = "Serve",
		Label = "Window",
		Anchor = "CamAnchor_Window",
		Focus = "Focus_Window",
		Fallback = "Board",
		Fov = 0,
		Pitch = 0,
		Distance = 0,
		Dolly = 0,
		Side = 0,
	},
} :: { View }
const views = Table.new(withoutServe(viewsRaw, false))

-- The pair of the 2D mode, the Fallback "Build" of the Board view
const legacyView: LegacyViewRow = { Key = "Build", Anchor = "CamAnchor_Build", Focus = "Focus_Build" }

-- Every tab key that can cross the wire (PrepTab.Step, PrepSeats.Step enum), in first-seen order. Lync sorts enum names.
local wireTabs: { string } = {}
const tabsLegacyKeys: { string } = {}
const tabs3DKeys: { string } = {}
for _, row in tabsLegacyRaw do
	table.insert(tabsLegacyKeys, row.Key)
end
for _, row in tabs3DRaw do
	table.insert(tabs3DKeys, row.Key)
end
do
	const seen: { [string]: boolean } = {}
	for _, set in { tabsLegacyKeys, tabs3DKeys } do
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
--   grill_flip      distance of the swinging cursor's centre from the middle of the bar, % of the bar (Grade.FlipScore; TASK-257).
--                   TASK-318 (owner 2026-10-15, easier): Perfect 5 -> 7, Good 10 -> 14 (bands 40% wider; drawn by GrillBar at 2x)
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
	{ Key = "grill_flip", Gesture = "taps", Unit = "PercentDuration", Perfect = 7, Good = 14, Worst = 50, ExcessWeight = 0, Icon = "" },
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
	{ Key = "OneSausage", Notice = "tutorial_one_sausage" },
	{ Key = "HandsFull", Notice = "hands_full" },
	{ Key = "Rate" },
	{ Key = "NoTicket" },
	{ Key = "Held" }, -- DEC-259: a colleague holds that grill / rail sausage (PrepClaims); the client names who
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
	Delivery = DELIVERY,
	DoneHold = 0.8,
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
			FocusRadius = 0.95,
			Early = 0.25,
			CheckSize = 0.5,
			Drag = 14,
		},
		Serve = {
			RestSide = 2.3,
			RestAway = 0.35,
			PlateRadius = 0.58,
			TrayLength = 2.2,
			Fly = 0.32,
			Return = 0.25,
			Verdict = 1.0,
			HandLift = 0.2,
		},
		Budget = {
			Hitboxes = 40,
			RaysPerFrame = 1,
			Highlights = 12,
			Rings = 10,
			SauceSegmentsPerStroke = 80,
			SauceSegmentsPerPlate = 200,
			SaucePool = 200,
			SauceMinStep = 0.03,
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
		Stages = { Grill = true, Board = true, Toppings = true, Order = true, Serve = true },
		Board = {
			Scale = 2.5,
			Lift = 0.01,
			Guide = { Dashes = 14, Width = 0.05, Lift = 0.03 },
			Open = { Time = 0.28, Hop = 0.22 },
			Close = 0.4,
			Knife = { Height = 0.3, Tilt = 26, Spring = 20 },
			Carry = { Spring = 22, Alpha = 0.4 },
			Bin = { Right = -0.9, Back = 1.3, Size = 0.8 },
			Shift = { Right = 0, Back = 0 }, -- 0: the bun stays on the REAL board (the Toppings view frames the board and the bowls together, prep_targets); a number here is an extra slide from the board
			Slide = 0.4,
			Crumbs = 8,
		},
		Toppings = {
			Stroke = {
				Width = 0.09,
				Height = 0.07,
				Smooth = 2,
				Joint = 1.0,
				Taper = 0.4,
				Shine = 0,
				Variance = 0.035,
				Threshold = 0.15,
				Done = 0.97,
				MinAmount = 0.1,
				Margin = { X = 0.15, Y = 0.45 },
			},
			Bottle = { Length = 1.5, Radius = 0.24, Tilt = 105, Rise = 0.6, Spring = 18 },
			Dot = { Size = 0.05, Step = 0.17 },
			Ring = { Radius = 0.34, Thick = 0.05 },
			Potato = { From = 0.15 },
			Hand = { Spring = 16, Rise = 0.5 },
		},
		Editable = false,
		GhostHand = true, -- DEC-259
		Ghost = { Hz = 10, MaxDistance = 16, Stale = 0.6, Lerp = 14, GrabLease = 5, Fill = 0.55 }, -- Provisional
		Presence = {
			-- one colour per seat (station 1..4 take the first four), never red; Teal, Mustard, Lilac, Mint, Apricot, Sky, Pink, Lime
			Palette = {Color3.fromHex("#3FA7B5"), Color3.fromHex("#F6C12B"), Color3.fromHex("#A98BD6"), Color3.fromHex("#6FCF97"), Color3.fromHex("#F29B6B"), Color3.fromHex("#5BA8F0"), Color3.fromHex("#E58BC0"), Color3.fromHex("#B7D84B")},
			Highlights = 3, -- taken out of Budget.Highlights (Outline gets the rest); none at LowQuality
			Fill = 0.55,
			Range = 60, -- studs: the name tag fades out beyond it
			Tag = { Width = 4.4, Height = 1.0, Lift = 1.1 }, -- studs
		},
		Juice = {
			Particles = 120,
			Emitters = 6,
			Flashes = 3,
			Floats = 3,
			Pop = { Time = 0.28, Amount = 0.14 },
			Float = { Rise = 0.9, Time = 0.9, Size = 28 },
			Flash = { Time = 0.28, Fill = 0.1 },
			Combo = { Show = 2, Pitch = 0.06, Cap = 8 },
			Count = 0.6,
			Confetti = { Perfect = 22, Good = 10, Messy = 0 },
		},
		Coach = {
			Loop = 1.7,
			Rest = 0.9,
			Hand = { Palm = 0.85, Lift = 0.3, Alpha = 0.1 },
			Dashes = 7,
			Max = 10,
		},
		Bin = {
			Screen = { X = 0.1, Y = 0.74 },
			Depth = 0.92,
			Size = 0.5,
			Hit = 0.8,
			Lid = 70,
			Eat = 0.32,
		},
		Rig = {
			Placeholder = true,
			Bars = 14,
			BarRadius = 0.035,
			BarGap = 0.25,
			Margin = 0.3,
			Height = 0.62,
			Tray = { Depth = 0.34, Drop = 0.1 },
			Heat = { Cold = 0.0, Warm = 0.45, Hot = 0.9 },
			Marks = { Count = 3, Width = 0.035, Length = 0.17 },
			Slots = {
				{ X = -1, Depth = -0.9 },
				{ X = 1, Depth = -0.9 },
				{ X = -1, Depth = -0.3 },
				{ X = 1, Depth = -0.3 },
				{ X = -1, Depth = 0.3 },
				{ X = 1, Depth = 0.3 },
				{ X = -1, Depth = 0.9 },
				{ X = 1, Depth = 0.9 },
			},
		},
	},
	Camera = { Fov = 70, Travel = 0.35, Min = 0.25, Max = 0.45, Leave = 0.30, Pitch = -55, Distance = 2.5, Fade = 0.15, Pan = { Slop = 8, Decay = 4.5, StopSpeed = 0.5, Hyst = 0.07, Edge = 0.07, EdgeSpeed = 11, Dots = { Size = 14, Active = 34, Gap = 4 } } }, -- FEAT-039; Fov 62 in every view (polish 2026-10-12, C-3): no zoom pop between sections; Travel/Min/Max in s by distance
	ForcedExit = { Signal = 0.4, NoInput = 0.5 }, -- Q-221 A
	CueLock = 6,
	ClientIdle = 20, -- FEAT-039: 20 s without input = Parked
	SeatIdle = 60,
	Heartbeat = 15,
	PlateMax = 90,
	TutorialPlateAge = 80,
	Reach = 14,
	-- skilled plate with K = 2 takes ~6..8 s of gesture time: floor 3.4 s (refused), Perfect cap 4.6 s
	MinPlate = 1.8,
	PerTopping = 0.8,
	PerfectMin = 3.0,
	MsSlack = 1.5,
	Assist = 1.3,
	TouchOffset = 0, -- owner 2026-10-17: the sauce must land under the finger (was 28 px above it)
	Grill = { Target = 0.5, From = 0.4, To = 0.6, PostFlip = 2, Reaction = 20, Swing = 1.2 }, -- 2026-10-14: the pause waits for the flip; TASK-318 (2026-10-15): Swing 1.1 -> 1.2 (cursor ~9% slower)
	Rates = { Enter = 2, Leave = 2, Tab = 4, Grill = 6, Begin = 1, Finish = 1, Trash = 4, Order = 4 },
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
	Done = "Done",
	Serve = "Serve",
	Take = "Take",
	Leave = "Leave",
	Trash = "Trash",
	Assist = "Assist",
	Waiting = "Waiting for the grill",
	Taken = "Taken",
	Perfect = "PERFECT",
	Combo = "x%d",
	BinTip = "Drag it to the bin",
	TrashBusy = "Keep one frank for the plate",
	TrashEmpty = "Nothing to throw",
	Trashed = "Thrown away",
	FlipAlert = "Flip!",
	-- the drag tutorial lines (World/Coach): short, and they say DRAG
	Coach = {
		Pan = "Drag left or right to change station", -- TASK-262
		Grill = "Drag a sausage from the box onto the grill",
		Board = "Drag the knife along the dashes",
		Sausage = "Drag the sausage into the bun", -- owner request 2026-10-14
		Deliver = "Drag the plate onto the customer", -- TASK-254
		Toppings = "Drag a bowl onto the bun",
		Serve = "Drag the plate to the window",
	},
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
	-- model toppings (cheese, owner report 2026-10-14): a release this far outside the bun (bun-space share) still lands, a
	-- drag shorter than DragMin (bun heights) is a click (selects the bowl, no refusal toast)
	DropSlack = 0.15,
	DragMin = 0.25,
	-- the delivery AREA of the Toppings view (TASK-253): a box over the body of the customer at the window, studs; Lift = its
	-- centre over the root part. The drop target of the plate is the same box (Depth deep)
	Deliver = { Width = 2.2, Height = 2.6, Depth = 1.8, Lift = 0.9 },
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
		Ready = "Hot dog in hand. Serve it",
		NoBun = "Out of buns",
		Closed = "We are closed",
		Retry = "Pick the tab again to retry",
		Expired = "Too slow! Bun back in the crate", -- the server lost the plate (shop closed): its bun was refunded (2026-10-14)
		Full = "Plate is full. Press Next",
		-- model toppings (owner report 2026-10-14): a drop off the bun, a press too short to settle / fill
		DropOnBun = "Drop it on the bun",
		HoldLonger = "Hold it a little longer",
		DropOnCustomer = "Drop the plate on the customer", -- TASK-253
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
	-- the words of the gamepad button chips over the hint pill (TASK-268; Provisional, English, <= 12 characters)
	Pad = {
		Grab = "Grab",
		Pour = "Pour",
		Free = "Free draw",
		Guided = "Guided",
	},
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
		"Plate",
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
	Acts = { "Enter", "Leave", "Tab", "Grill", "Begin", "Finish", "Trash", "Order", "Kick", "Grab" },
	-- PrepResult.Grade (wire enum); None = the act has no grade
	GradeKeys = { "None", "Messy", "Good", "Perfect" },
	GrillActs = { "Place", "Flip", "Collect" }, -- PrepGrill.Act
	TrashFrom = { "Plate", "Grill", "Rail" }, -- PrepTrash.From (the bin takes the plate, a sausage of the grill, the front of the rail); PrepResult.Value of a Trash = index - 1
	OrderActs = { "Take", "Serve" }, -- PrepOrder.Act (no Refuse since TASK-354: refusing is closing the window)
	GrabFrom = { "Grill", "Rail" }, -- PrepGrab.From; PrepClaims record id = (index of From - 1) * 8 + Slot (DEC-259)
	Stations = 4, -- PrepEnter.Station 1..4, PrepSeats records (BoardSlots of the trailer)
	-- TASK-354 (owner request 2026-10-17, Provisional): the grill Work prompt slides along the counter with the player
	-- (shared/Prep/WorkSlide). Model = the counter-wide Model of the vehicle (its bounding box is the counter); Fraction = how
	-- far from the end nearest the authored prompt it may follow (0.7 = about where the toppings start); Step = the PromptStep
	-- of the anchor that slides (the other Work prompts are silenced anyway).
	WorkSlide = { Model = "PrepTargets", Fraction = 0.7, Step = "Grill" },
})
