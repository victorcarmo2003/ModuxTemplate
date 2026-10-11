--!strict
-- Cutscenes (content-data.md §3.19, §6.11; architecture.md §19.16; network.md §6.2; FEAT-004, FEAT-027;
-- script.md §1; ending.md §2.2, §2.4; MAP-01 §11; DEC-021, DEC-075, DEC-078, DEC-088, DEC-097, DEC-194, DEC-205).
-- Keys are the Cutscene.Scene wire enum (sentinel "none" first). Owner: narrative-writer (lines) + level-designer
-- (marks, targets); architect (shape). Texts are placeholders until ui-text.md.
--
-- Only intro and finale/credits are cutscenes (FEAT-004). Vehicle swap and lost night are world transitions.
-- Duration: real seconds of the scene (beats end by then); Cap: hard cap the server enforces.
-- Skippable: by vote, >= ceil(0.5 x connected) per segment (DEC-194). Participants: connected at the start; a late
-- member waits and spawns at the end (DEC-205).
-- Next: scene that plays right after this one, as a new segment with 0 votes (finale -> credits).
-- Marks: start slots of the party, in order (slot 1 = the player that made the party; visual only, DEC-067).
-- Beats (sorted by At, seconds since StartedAt):
--   Fade     Target "In" | "Out"
--   Text     on-screen title, Text
--   MoveTo   every avatar walks to Target (MapPoint name; "{slot}" = the avatar's slot 1..4; "a|b@f" = the point at
--            fraction f (default 0.5) from MapPoint a to b, facing a -> b; "Sign" = the sidewalk spot in front of the
--            NO HELP WANTED sign, facing it (Rules.Sign); Rules.Stand.Target = in front of the phone/poster)
--            Arrive (optional): the walk is over (eased to a stop) by this time and the body waits there for the next
--            MoveTo. Without Arrive the walk flows into the next MoveTo without stopping (one smooth run through
--            every waypoint, corners rounded). Rules.Walk sets the pace.
--            Accel / Brake (optional, on the beat that closes a run): studs/s^2 of its start / its stop (a startled
--            stop is a hard Brake). Backward (optional): the body keeps its end facing while it walks (a step back).
--            Face (optional): anchor the body turns to at the end of the run ("Poster", "Sign", a MapPoint).
--   LookAt   every POV turns to Target (MapPoint/anchor name)
--   Focus    every POV turns to a live target: an actor key (follows it), "Poster", "Phone", "Sign" (the tagged
--            NO HELP WANTED sign, Rules.Sign), "Windows" (nearest NO HELP WANTED card ahead), a MapPoint or "Walk"
--            (where the body walks). Fov (optional) narrows the view.
--   Prompt   world prompt that completes by itself on Target, label Text (script.md §1: input locked)
--   Line     subtitle Text said by Speaker ("walt", "crew" = a balloon over each avatar); Variant Solo/Party.
--            Voiced by text-to-speech with Voices[Speaker] when the engine has it (subtitles only otherwise).
--   Actor    client-only actor or prop Target appears/acts (Walt, Raincoat Lady, street cars, flip phone, flyer)
-- The camera is always the avatar's head (DEC-088, DEC-097): it eases to the focus of each beat and allows an elastic
-- free look around it (Rules.Look), springing back when the player lets go.
-- No night or anomaly element ever enters the intro (only Day props, street cars of the traffic kit, the flyer).
local Table = require(script.Parent.Table)

export type BeatKind = "Fade" | "Text" | "MoveTo" | "LookAt" | "Focus" | "Prompt" | "Line" | "Actor"
export type Variant = "Solo" | "Party"

export type Beat = {
	At: number,
	Kind: BeatKind,
	Target: string,
	Text: string?,
	Speaker: string?,
	Variant: Variant?, -- nil = both
	Arrive: number?, -- MoveTo: stop here by this time (seconds since StartedAt)
	Fov: number?, -- LookAt/Focus: field of view while this focus holds (nil = the player's)
	Accel: number?, -- MoveTo: studs/s^2 of the start of the run this beat closes (nil = Rules.Walk.Accel)
	Brake: number?, -- MoveTo: studs/s^2 of the stop of the run this beat closes (nil = Rules.Walk.Accel)
	Backward: boolean?, -- MoveTo: the run keeps its end facing (steps back instead of turning around)
	Face: string?, -- MoveTo: anchor faced at the end of the run (nil = the target's own facing)
}

-- Text-to-speech voice of a speaker (AudioTextToSpeech). VoiceId "" = no voice for that speaker.
-- PROVISIONAL (frontend-coder, 2026-10-11): ids and numbers until the audio pass picks the voices.
export type Voice = {
	VoiceId: string,
	Speed: number?, -- AudioTextToSpeech.Speed (nil = engine default)
	Pitch: number?, -- AudioTextToSpeech.Pitch (nil = engine default)
	Volume: number, -- 0..1, multiplied by the Voice group of AudioController
}

-- Street car actor: a real car of the traffic kit on a TrafficPath of the binding (never off the road)
export type Car = {
	Route: string, -- TrafficPath PathId (Content.Traffic.Routes[].Path)
	Near: string, -- what it passes: a MapPoint id, "Poster", "Phone" or "a|b" (middle of two MapPoints)
	Pass: number, -- s after the Actor beat when it is nearest to Near
	Look: number, -- Content.Traffic look index (shape x paint)
	Horn: string, -- Content.Sounds key, played HornLead s before the pass
	-- Synced to the walker instead of the beat clock: the car's clock starts when the own body reaches fraction At of
	-- the crossing From -> To (MapPoints), and it passes Near when the body has stopped (end of that walk) + After s.
	-- Before that moment the car is placed from the planned walk, so it is already coming (never pops in). Pass is
	-- not used then.
	Cross: CarCross?,
}

export type CarCross = { From: string, To: string, At: number, After: number }

export type Rules = {
	-- shared by CutsceneService (bodies) and CutsceneController (walk, camera, prompt)
	LineSpacing: number, -- studs between avatars on a shared MoveTo target
	SnapDistance: number, -- studs off the planned walk that make the server re-place a body at a MoveTo
	Walk: {
		Accel: number, -- studs/s^2, start and stop
		MinSpeed: number,
		MaxSpeed: number,
		Cruise: number, -- pace of a walk without Arrive
		Corner: number, -- studs of corner rounding at a waypoint
	},
	-- MoveTo Target that stands the party in front of the phone/poster (instead of the fixed MapPoints)
	Stand: {
		Target: string,
		Slots: { { Distance: number, Angle: number } }, -- per slot: studs in front of the phone, degrees off its face
	},
	-- Elastic focus: the player may look around the focus of the beat, but the look input loses gain the farther the
	-- view is from the focus (gain = 1 - (angle / limit)^Exponent, full gain when turning back), and once the input
	-- stops for Recenter s a critically damped spring (Spring, 1/s) brings the view back. A focus change eases the
	-- base view over Transition (Min + PerHalfTurn x turned / 180 degrees, capped at Max s); a live target is then
	-- followed at Follow (1/s). Same for mouse, touch and gamepad.
	Look: {
		Yaw: number, -- degrees each side of the focus where the gain reaches 0
		Pitch: number, -- degrees up and down
		Exponent: number,
		Recenter: number,
		Spring: number,
		Follow: number,
		Transition: { Min: number, PerHalfTurn: number, Max: number },
	},
	-- Help Wanted flyer on the P-01 post (script.md §1 "Panfleto")
	Poster: {
		Names: { string }, -- instance names searched in the Workspace (tag HelpWantedPoster wins)
		Lines: { string }, -- printed lines, top to bottom
		Phone: string, -- the number (fictional 555)
	},
	-- NO HELP WANTED sign of the first stop (instances tagged Tag, read at runtime; the user moves them in Studio).
	-- The stop is the point of the sidewalk line Line[1] -> Line[2] nearest to the sign, at least MinDistance studs
	-- from it (pulled back along the line), facing it. Several tagged: a card wider than MinWidth studs wins (the big
	-- one), then the first along the line within Range studs of it. None: Fallback MapPoint.
	Sign: {
		Tag: string,
		Line: { string },
		MinDistance: number,
		MinWidth: number,
		Range: number,
		Fallback: string,
	},
	Voices: { [string]: Voice },
	Cars: { [string]: Car },
}

const PHONE = "555-0179" -- script.md §1 ("Call Bramble's Corner Dogs — 555-0179")

export type Cutscene = {
	Key: string,
	Duration: number,
	Cap: number,
	Skippable: boolean,
	Participants: "ConnectedAtStart",
	Next: string?,
	Music: string?, -- Content.Music cue pushed while this scene plays (nil = no cutscene music; the phase cue rules)
	Marks: { string },
	Beats: { Beat },
}

local function walt(at: number, text: string, variant: Variant?): Beat
	return { At = at, Kind = "Line", Target = "walt", Speaker = "walt", Text = text, Variant = variant }
end

local function crew(at: number, text: string, variant: Variant?): Beat
	return { At = at, Kind = "Line", Target = "crew", Speaker = "crew", Text = text, Variant = variant }
end

local function focus(at: number, target: string, fov: number?): Beat
	return { At = at, Kind = "Focus", Target = target, Fov = fov }
end

-- PROVISIONAL (frontend-coder, 2026-10-11): every number of the record below
const rules: Rules = {
	LineSpacing = 2.5, -- 4 avatars fit inside the 8-stud CW-1 stripes (MAP-01 P46)
	SnapDistance = 8,
	Walk = {
		Accel = 8,
		MinSpeed = 5,
		MaxSpeed = 15,
		Cruise = 10,
		Corner = 2.5,
	},
	Stand = {
		Target = "CS-P{slot}",
		-- slot 1 makes the call, ~3 studs in front; mates in a half moon behind and to the sides
		Slots = {
			{ Distance = 3, Angle = 0 },
			{ Distance = 4.6, Angle = 38 },
			{ Distance = 4.6, Angle = -38 },
			{ Distance = 6.2, Angle = 0 },
		},
	},
	Look = {
		Yaw = 40,
		Pitch = 20,
		Exponent = 2,
		Recenter = 0.6,
		Spring = 5,
		Follow = 6,
		Transition = { Min = 0.55, PerHalfTurn = 0.9, Max = 1.6 },
	},
	Poster = {
		Names = { "P-01_Flyer", "HelpWantedPoster", "HelpWanted_Flyer", "Flyer_HelpWanted" },
		Lines = { "HELP WANTED!", "Run a hot dog cart.", "No experience needed.", "Must notice things." },
		Phone = PHONE,
	},
	Sign = {
		Tag = "NoHelpWantedSign",
		Line = { "CS-1", "CS-3" }, -- Ninth north sidewalk, walked east (MAP-01 §11.1)
		MinDistance = 4.5,
		MinWidth = 3, -- the big AST-033 card (3.96 studs wide); the window cards are smaller
		Range = 30,
		Fallback = "CS-2",
	},
	Voices = {
		walt = { VoiceId = "1", Speed = 0.95, Volume = 1 },
		crew = { VoiceId = "2", Speed = 1.05, Volume = 0.9 },
	},
	Cars = {
		-- eastbound on the Ninth (south half, MAP-01 §2), in front of the party stopped mid CW-2: its clock starts when
		-- the own body reaches 40% of CS-3 -> CS-4 and it crosses the stripes 0.35 s after the startled stop
		CarNinth = {
			Route = "TR-1",
			Near = "CS-3|CS-4@0.62",
			Pass = 1.6,
			Look = 5,
			Horn = "car_honk_soft",
			Cross = { From = "CS-3", To = "CS-4", At = 0.4, After = 0.35 },
		},
		-- eastbound on the Ninth, in front of the party at the phone, before the turn to the cart
		CarCorner = { Route = "TR-1", Near = "Phone", Pass = 2, Look = 7, Horn = "car_honk_soft" },
	},
}

const scenes = Table.new({
	{
		Key = "none",
		Duration = 0,
		Cap = 0,
		Skippable = false,
		Participants = "ConnectedAtStart",
		Marks = {},
		Beats = {},
	},
	-- Opening, ~65 s with dramatic pauses, cap 70 (FEAT-004; PROVISIONAL frontend-coder 2026-10-11, user feedback after
	-- play); script.md §1 shots 1-10; MAP-01 §11.1 CS-1..CS-7
	{
		Key = "intro",
		Duration = 67.2,
		Cap = 70,
		Skippable = true,
		Participants = "ConnectedAtStart",
		Music = "lobby", -- PROVISIONAL stand-in for MUS-005 (Abertura); the shift track waits for the end of the chain
		Marks = { "CutsceneMark1", "CutsceneMark2", "CutsceneMark3", "CutsceneMark4" },
		Beats = {
			{ At = 0, Kind = "Fade", Target = "In" },
			{ At = 0, Kind = "Text", Target = "Title", Text = "Bellmoor" },
			-- Beat 1, the NO HELP WANTED sign: east along the Ninth north sidewalk, stop in front of the sign
			-- (Rules.Sign, read from the map), turn to it, read it, pause.
			{ At = 1.2, Kind = "MoveTo", Target = "Sign", Arrive = 6.4 },
			crew(2.4, "Empty. Again."),
			focus(5, "Sign", 55),
			crew(6.9, "Hm, a job?"),
			crew(8.8, '..."No help wanted." Of course.'),
			-- Beat 2, CW-2: one flowing walk to the NW corner and into the stripes. At 40% of the crossing the car
			-- (synced to the body, Rules.Cars.CarNinth.Cross) is due; hard stop near the middle, the car crosses right
			-- in front, "Whoa!", a step back, a pause, then the rest of the crossing.
			focus(11.4, "Walk"),
			{ At = 11.6, Kind = "MoveTo", Target = "CS-3" },
			{ At = 11.8, Kind = "MoveTo", Target = "CS-3|CS-4@0.46", Arrive = 20.4, Brake = 40 },
			{ At = 14, Kind = "Actor", Target = "CarNinth" }, -- real car on its lane, never brakes (DEC-130, DEC-133)
			focus(19.9, "CarNinth"),
			crew(20.5, "Whoa!"),
			{
				At = 20.6,
				Kind = "MoveTo",
				Target = "CS-3|CS-4@0.4",
				Arrive = 21.3,
				Accel = 25,
				Brake = 25,
				Backward = true,
			},
			focus(22.3, "CS-4"),
			-- Beat 3, CW-1 and the poster: seen from the far curb, stop, look, "What's that?", walk up to it, read
			{ At = 23.6, Kind = "MoveTo", Target = "CS-4" },
			{ At = 23.8, Kind = "MoveTo", Target = "CS-5W" }, -- west curb of CW-1, along the Juniper South sidewalk
			focus(24, "Walk"),
			{ At = 24.2, Kind = "MoveTo", Target = "CS-5E", Arrive = 31.8, Face = "Poster" }, -- across CW-1
			focus(31, "Poster", 60),
			crew(32.4, "What's that?"),
			{ At = 34.4, Kind = "MoveTo", Target = "CS-P{slot}", Arrive = 37 }, -- in front of the poster (Rules.Stand)
			focus(36.4, "Poster", 45), -- reading the flyer and its number (shot 6)
			crew(39.6, "At least it's a job opportunity..."),
			crew(42.2, "I think I'll give them a call.", "Solo"),
			crew(42.2, "Let's give them a call.", "Party"),
			-- Beat 4, the call (shots 7-8)
			focus(44.9, "Phone", 55),
			crew(45.1, `{PHONE}...`),
			{ At = 45.2, Kind = "Prompt", Target = "Phone", Text = `Call {PHONE}` },
			{ At = 46.5, Kind = "Actor", Target = "FlipPhone" }, -- slot 1 only, already open (AST-038)
			walt(47, "Bramble's Corner Dogs! Walt speaking."),
			walt(49.6, "The flyer? Huh. Nobody's called about that one in years.", "Solo"),
			walt(49.6, "The flyer? All of you? Huh. Nobody's called in years.", "Party"),
			walt(52.4, "But you noticed it. That counts for a lot.", "Solo"),
			walt(52.4, "You all noticed it. That counts for a lot. Heh.", "Party"),
			walt(55, "Can you start today? Great. Wonderful."),
			walt(57.4, "The cart's right on the corner. Ninth and Juniper."),
			walt(59.9, "Keys are under the mustard. See you around, Rookie."),
			{ At = 61, Kind = "Actor", Target = "CarCorner" }, -- street life on the Ninth, no camera focus
			-- Beat 5: everyone turns to the cart (CS-7) and holds on it; fade out; the game fades in after the chain
			focus(62.6, "CART", 55),
			{ At = 65.8, Kind = "Fade", Target = "Out" },
		},
	},
	-- Dawn of Night 10, variant A1 (DEC-075, DEC-076); <= 60 s; MAP-01 §11.3 SS-1..4, WALT-1, RL-1 -> RL-END
	{
		Key = "finale",
		Duration = 60,
		Cap = 60,
		Skippable = true,
		Participants = "ConnectedAtStart",
		Next = "credits",
		Music = "finale",
		Marks = { "SS-1", "SS-2", "SS-3", "SS-4" },
		Beats = {
			{ At = 0, Kind = "Fade", Target = "In" },
			{ At = 1, Kind = "Actor", Target = "MartDoor" },
			{ At = 1.5, Kind = "Actor", Target = "Walt" }, -- MKT-DOOR -> WALT-1, two coffees
			{ At = 3, Kind = "LookAt", Target = "WALT-1" },
			walt(6, "Ten nights. You kept the light on."),
			walt(9, "I watched every one. From in here. Best seat in town."),
			walt(12, "I worked that corner forty years. Since '79."),
			walt(15, "The corner's a crossing, Rookie. At night, the late crowd comes through."),
			walt(18, "They like the light. And the smell of food. Heh."),
			walt(21, "Keep the rules, and they stay polite. That's the deal."),
			walt(24, "Somebody has to keep the light on. Every night."),
			walt(27, "My knees are done. But you... you notice things."),
			{ At = 30, Kind = "Actor", Target = "WaltCoffee" }, -- held out to each POV
			walt(30, "The night shift is yours. If you want it."),
			{ At = 36, Kind = "Actor", Target = "RaincoatLady" }, -- RL-1 -> RL-END, vanishes in a puddle
			{ At = 37, Kind = "LookAt", Target = "RL-END" },
			walt(46, "Morning, Marigold."),
			{ At = 57, Kind = "Fade", Target = "Out" },
		},
	},
	-- Credits + post-credits flyer (ending.md §2.4); <= 75 s
	{
		Key = "credits",
		Duration = 75,
		Cap = 75,
		Skippable = true,
		Participants = "ConnectedAtStart",
		Marks = { "SS-1", "SS-2", "SS-3", "SS-4" },
		Beats = {
			{ At = 0, Kind = "Text", Target = "Credits", Text = "Credits" }, -- roll from docs/art/credits.md
			{ At = 60, Kind = "Fade", Target = "In" },
			{ At = 60, Kind = "LookAt", Target = "P-01" },
			{ At = 61, Kind = "Actor", Target = "Flyer" }, -- "NIGHT SHIFT — NOW HIRING" (AN-03)
			{ At = 72, Kind = "Fade", Target = "Out" },
		},
	},
} :: { Cutscene })

return Table.with(scenes, { Rules = rules })
