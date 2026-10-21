--!strict
-- Suspense events (TASK-481; DEC-294; design/horror-cinematic.md §7; tech/suspense.md). Owner: game-designer (numbers)
-- + level-designer (spots). Every number Provisional until the owner's Play.
--
-- A suspense event is NOT an anomaly: no rule, no verb, no warning. A creature appears at once on a spot nobody is
-- looking at; whoever catches it at a glance gets the camera pulled to it (~0.4 s), a deep "sub drop", loses
-- Rules.Cost sanity (the server draws it) and the creature is gone. Mild (DEC-172): short scare, no blood.
--
-- Rows = the events (creatures). Spots = where one may appear. The server (SuspenseService) schedules, picks the event
-- and the spot, checks that nobody looks and charges; the client (SuspenseController) shows it and detects the glance.

-- Placeholder bodies of the family B kit (Anomaly/client/.../Kit/Hide.luau, Hide.Build)
export type Style = "Grin" | "Walk" | "Crawl" | "Roof"

export type Event = {
	Key: string,
	Ref: string, -- design reference (ANM-018 = the Sorriso concept)
	Style: Style,
	Asset: string?, -- Model under ReplicatedStorage.Assets that replaces the placeholder (pivot at the feet, facing -Z)
	Spots: { string }, -- keys of Spots it may appear on
	FromNight: number, -- first night it can be drawn
	Weight: number, -- draw weight among the events open on the night
	Scale: number, -- model scale on top of the spot's Scale
	Head: number, -- studs above the feet of the "seen" target (server cone, client screen test), before scale
}

export type Spot = {
	Key: string,
	-- MapPoint id that overrides Position/Face when the place has it (level-designer: pose = the feet, LookVector = where
	-- it looks). Absent = Position/Face below (MAP-01 rev. 4 coordinates)
	Point: string,
	Position: Vector3, -- feet (the client drops it to the floor with a raycast)
	Face: Vector3, -- the point it looks at
	Scale: number,
}

export type Hijack = {
	Duration: number, -- s the camera is taken (pull + zoom)
	Pull: number, -- degrees the look is pulled towards the creature (<= HorrorScenes.Rules.MaxPull)
	Fov: number, -- degrees of zoom (negative = in; |Fov| <= HorrorScenes.Rules.MaxFov)
	Shake: string, -- HorrorScenes.Rules.Shakes profile
	Vignette: number, -- 0..HorrorScenes.Rules.MaxVignette
	VignetteFor: number, -- s until the edges open again
	Pulse: number, -- s of Screen.Pulse (<= 0.3)
	Linger: number, -- s the creature stays after the glance before it vanishes
	Words: number, -- s of whispers (HorrorScenes.Words.suspense) after the pull
}

-- The forgotten customer (owner 2026-10-19): a customer waits in the queue unseen by every player; the first glance at it
-- after At of its queue patience is gone is a jumpscare for whoever finally looks (owner 2026-10-19: "sequestra a câmera, dá
-- zoom no npc, treme e faz aqueles efeitos, coisa de 1-2 segundos"): the look pulled onto its head, a hard zoom held, a shake,
-- a sting, a pulse and the edges closing.
-- Per player (owner 2026-10-21, Provisional; was "seen earlier by anyone = no scare"): each player has to find it on their
-- own, another player's glance spares nobody else. Not during the tutorial, not from a cooking focus
export type Forgotten = {
	At: number, -- share of the queue patience gone (0..1) from which the first glance scares
	Range: number, -- studs: the glance counts up to this distance
	ScreenMargin: number, -- 0..0.5 share of the screen edge that does not count
	Pull: number, -- degrees the look is pulled to its head
	Duration: number, -- s of the pull
	Fov: number, -- degrees of zoom (negative = in; |Fov| <= HorrorScenes.Rules.MaxFov)
	Hold: number, -- s the zoom lasts (reaches Fov fast, eases back over the rest)
	Shake: string, -- HorrorScenes.Rules.Shakes profile
	Sound: string, -- Content.Sounds key (Scare)
	Pulse: number, -- s of Screen.Pulse (<= 0.3)
	Vignette: number, -- 0..HorrorScenes.Rules.MaxVignette
	VignetteFor: number, -- s until the edges open again
}

export type Rules = {
	FromNight: number, -- no event before this night
	PerNight: { number }, -- { min, max } events drawn per night
	Window: { number }, -- game minutes of the night when they may start (inside Nights.Windows.Shift)
	MinGap: number, -- s between two events
	AfterAnomaly: number, -- s of quiet after any anomaly occurrence ends (never during one)
	Retry: number, -- s between two tries of a due event that found no free spot
	Life: number, -- s the creature waits for a glance; then it is gone unseen
	Cost: { number }, -- { min, max } sanity lost by whoever catches it (server draws once per event)
	HiddenAngle: number, -- degrees, full cone: a player whose gaze has the spot inside this cone "is looking"
	HiddenRange: number, -- studs: farther than this nobody counts as looking
	MinDistance: number, -- studs: never on a spot this close to any active player
	SeenRange: number, -- studs: the glance counts up to this distance
	SeenAngle: number, -- degrees, full cone the server accepts for a "seen" claim (generous: Gaze is 10 Hz)
	ScreenMargin: number, -- 0..0.5 share of the screen edge that does not count yet (the corner of the eye)
	Hijack: Hijack,
	Forgotten: Forgotten,
}

const rules: Rules = {
	FromNight = 2, -- DEC-294
	PerNight = { 1, 3 }, -- DEC-294
	Window = { 1290, 1710 }, -- 9:30 PM -> 4:30 AM
	MinGap = 90,
	AfterAnomaly = 20,
	Retry = 4,
	Life = 12,
	Cost = { 5, 10 }, -- DEC-294
	HiddenAngle = 110,
	HiddenRange = 160,
	MinDistance = 10,
	SeenRange = 140,
	SeenAngle = 150,
	ScreenMargin = 0.04,
	Hijack = {
		Duration = 0.4, -- DEC-294
		Pull = 25,
		Fov = -6,
		Shake = "Jolt",
		Vignette = 0.45,
		VignetteFor = 1.6,
		Pulse = 0.25,
		Linger = 0.35,
		Words = 2.5,
	},
	-- owner 2026-10-19 ("chegando a barra em 70%, 80%"; "um pequeno susto e um pequeno foco"). Provisional, judged in Play
	Forgotten = {
		At = 0.45, -- owner 2026-10-19 after Play: the scare came too late (~80% of the bar); 0.7 -> 0.5 -> 0.45 (owner 2026-10-20)
		Range = 60,
		ScreenMargin = 0.12,
		-- owner 2026-10-19 again: "não está funcionando" - the old one (12 deg, -4 fov, 0.35 s, no shake) was not felt
		Pull = 30,
		Duration = 0.45,
		Fov = -16,
		Hold = 1.5,
		Shake = "Scare",
		Sound = "horror_sting",
		Pulse = 0.3,
		Vignette = 0.5,
		VignetteFor = 1.8,
	},
}

const spots = {
	-- the back bench (stations), east end of the back corridor: behind whoever works the front counter / the plates
	{
		Key = "prep_counter",
		Point = "SUS-PREP",
		Position = Vector3.new(57.5, 0.45, 66.2),
		Face = Vector3.new(42, 4, 58),
		Scale = 0.55,
	},
	-- outside the drive-thru window, the face filling the opening
	{
		Key = "drive_thru",
		Point = "SUS-DT",
		Position = Vector3.new(63.2, 0.45, 61),
		Face = Vector3.new(50, 4.5, 61),
		Scale = 0.75,
	},
	-- inside the pantry, seen through DOOR-P from the back corridor
	{
		Key = "pantry",
		Point = "SUS-PANTRY",
		Position = Vector3.new(29, 0.45, 75.5),
		Face = Vector3.new(29, 4, 64),
		Scale = 1,
	},
	-- far end of the street, seen through the front windows
	{
		Key = "street_end",
		Point = "SUS-STREET",
		Position = Vector3.new(112, 0.45, 9),
		Face = Vector3.new(42, 4, 52),
		Scale = 1.3,
	},
} :: { Spot }

const events = {
	-- the first event (DEC-294): the Sorriso, a huge round dark face with a white grin (ANM-018 concept)
	{
		Key = "sorriso",
		Ref = "ANM-018",
		Style = "Grin",
		Spots = { "drive_thru", "prep_counter" },
		FromNight = 2,
		Weight = 3,
		Scale = 1,
		Head = 6.5,
	},
	-- the tall dark figure, far or half hidden
	{
		Key = "figure",
		Ref = "ANM-007",
		Style = "Walk",
		Spots = { "pantry", "street_end" },
		FromNight = 3,
		Weight = 2,
		Scale = 1,
		Head = 6.3,
	},
} :: { Event }

local Table = require(script.Parent.Table)

const spotTable = Table.new(spots)

return Table.with(Table.new(events), {
	Spots = spotTable,
	SpotKeys = spotTable.Keys,
	Rules = Table.record(rules),
})
