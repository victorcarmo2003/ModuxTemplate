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
	Sub: string?, -- Text: small line on the tag under the title ("Ninth & Juniper")
	Hold: number?, -- Text: s the title stays (nil = the controller's TITLE_HOLD)
}

-- Camera language of a scene (owner request 2026-10-12, PROVISIONAL). Shots are sorted by At and last until the next
-- one (or the scene's Duration). Every From/To pair eases over the shot (Sine by default), and the first
-- Blend seconds cross-fade from where the previous shot ended (no pop), unless the shot starts with a Dip (a short
-- fade through black). The camera is still the avatar's head, except in a Boom shot (detached "establishing" camera).
-- Vectors are camera space (X right, Y up, Z forward) unless said otherwise; angles are degrees.
export type Shot = {
	At: number,
	Name: string,
	Cut: "Dip"?, -- begins with a fade through black (Cinema.DipDown / DipUp), the shot changes at the black
	Blend: number?, -- s of cross-fade from the previous shot (nil = Cinema.Blend)
	Ease: ("Sine" | "Quad")?,
	Fov: { number }?, -- {from, to}; overrides the Focus beat's Fov while the shot holds (30..60 in the intro)
	Dolly: { Vector3 }?, -- {from, to} offset of the eye, camera space (push-in = +Z)
	Boom: { Vector3 }?, -- {from, to} detached camera, walker space (X right, Y up, Z forward of the own body)
	BoomLook: Vector3?, -- point looked at in a Boom shot, walker space (from the head)
	Orbit: { number }?, -- {from, to} degrees the eye circles the focus target (Poster, Phone...)
	Roll: { number }?, -- {from, to} degrees of dutch angle
	Sway: number?, -- 0..1 hand-held shake (off with reduced motion)
	Far: number?, -- depth of field far blur intensity (nil = the controller's own)
	Rack: number?, -- 1/s how fast the depth of field follows the focus (rack focus)
	Cue: string?, -- Content.Sounds key played when the shot starts (live only)
}

export type Cinema = {
	Ratio: number, -- letterbox aspect (2.35)
	MaxBar: number, -- most a bar may take of the screen height
	MinAspect: number, -- below this screen aspect (portrait phone) there are no bars
	BarsIn: number, -- s the bars take to close in from the start
	BarsOut: number, -- s they take to open before the end fade
	DipDown: number, -- s to black before a Dip shot
	DipUp: number, -- s back from black
	Blend: number, -- default shot cross-fade
	Vignette: number, -- 0..1 edge darkness
	TitleSound: string, -- Content.Sounds key when a title appears
	DipSound: string, -- Content.Sounds key on a Dip
	Sway: { Amp: number, Tilt: number, Rate: number }, -- studs and degrees at Sway = 1, Hz
	Quality: { MaxFrameTime: number }, -- s: a slower average frame turns particles off
}

-- Passers-by of the background, client only (Ambience.luau): a rig walking From -> To (MapPoint "a|b@f" ids, fractions
-- may pass 0..1) at Lateral studs to the right of the walking direction; they stay at the end of the walk.
export type Extra = {
	Start: number, -- s into the scene
	From: string,
	To: string,
	Lateral: number,
	Speed: number,
	Species: string,
	Outfit: string,
}

-- A flock crossing the sky: Count birds from Point + Start to Point + End (world axes, studs) in Time s from At.
export type Flock = {
	At: number,
	Time: number,
	Point: string,
	Start: Vector3,
	End: Vector3,
	Count: number,
	Gull: boolean, -- gulls (big, white) or pigeons (small, grey)
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
	-- The stop is right in front of the sign: Distance studs out of its printed face (the face turned towards the
	-- sidewalk line Line[1] -> Line[2]), on the ground, facing it. Several tagged: a card wider than MinWidth studs
	-- wins (the big one), then the first along the line within Range studs of it. None: Fallback MapPoint.
	Sign: {
		Tag: string,
		Line: { string },
		Distance: number,
		MinWidth: number,
		Range: number,
		Fallback: string,
	},
	Voices: { [string]: Voice },
	Cars: { [string]: Car },
	Cinema: Cinema,
	Extras: { Extra },
	Flocks: { Flock },
	-- s the server holds a chain for the participants' ClientReady (loading screen) before it starts anyway
	ReadyTimeout: number,
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
	-- cinematic dressing (owner request 2026-10-12; nil = none): letterbox, vignette, shots, Look preset, ambience
	Cinema: boolean?,
	Look: string?, -- Content.LightPresets key LightController applies while this scene plays ("Cinematic")
	Shots: { Shot }?,
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
		Line = { "CS-2", "CS-3" }, -- the trailer's sidewalk after the crossing (owner D3 2026-10-12); the intro does not stop at a sign any more
		Distance = 3.5, -- user feedback 2026-10-11: stop close, right in front of the sign (~3-4 studs)
		MinWidth = 3, -- the big AST-033 card (3.96 studs wide); the window cards are smaller
		Range = 30,
		Fallback = "CS-2",
	},
	Voices = {
		-- user feedback 2026-10-11: a calmer, slower Walt (was 0.95)
		walt = { VoiceId = "1", Speed = 0.9, Volume = 1 },
		crew = { VoiceId = "2", Speed = 1.05, Volume = 0.9 },
	},
	-- no street cars in the intro (owner D3 2026-10-12: short, clean scene); the type stays for other scenes
	Cars = {},
	-- PROVISIONAL (frontend-coder, 2026-10-12, owner request "more cinematic"): every number
	Cinema = {
		Ratio = 2.35,
		MaxBar = 0.13,
		MinAspect = 1.5,
		BarsIn = 1.6,
		BarsOut = 0.9,
		DipDown = 0.18,
		DipUp = 0.35,
		Blend = 0.9,
		Vignette = 0.3,
		TitleSound = "toast",
		DipSound = "curtain",
		Sway = { Amp = 0.06, Tilt = 0.35, Rate = 1.3 },
		Quality = { MaxFrameTime = 1 / 28 },
	},
	-- No passers-by and no birds crossing the street in the intro (owner D3 2026-10-12); the dust, leaves, papers and
	-- trailer steam of Ambience stay
	Extras = {},
	Flocks = {},
	ReadyTimeout = 30, -- s: above the loading gate STEP_CAP (18 s) + 10 s margin for a laggy ClientReady (playtest 2026-10-11)
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
	-- Opening, ~35 s (FEAT-004; owner D3 2026-10-12 rev. 2, PROVISIONAL: short and objective; was 44 s, before 73 s).
	-- It starts on the NORTH sidewalk of the Ninth, across from the trailer's Pad (MapPoints CutsceneMark1..4;
	-- tools/assetplace/cutscene_points.luau), walks east to the crosswalk CW-4 (CS-1, the nearest one to the flyer and the
	-- widest: 12 studs), CROSSES the empty street on its stripes (CS-1 -> CS-3; traffic is held for the whole scene and no
	-- car or passer-by is in it) and arrives at the P-01 post with the Help Wanted flyer (it stands on the trailer's side
	-- of the Ninth, at the south end of CW-4), reads it, calls Walt and ends looking at the trailer (MapPoint TRL).
	-- Lines are short (<= 6 words; Walt on the phone: 3 lines). The call is ~12 s of voice + pauses, so the scene cannot
	-- be much shorter than 35 s: Cap 38 = Duration + 3. Starts once every participant's client is ready
	-- (Rules.ReadyTimeout), so the Intro phase cap (Shift.luau) covers that wait + Cap.
	{
		Key = "intro",
		Duration = 35,
		Cap = 38,
		Skippable = true,
		Participants = "ConnectedAtStart",
		Music = "lobby", -- PROVISIONAL stand-in for MUS-005 (Abertura); the shift track waits for the end of the chain
		Marks = { "CutsceneMark1", "CutsceneMark2", "CutsceneMark3", "CutsceneMark4" },
		Cinema = true,
		Look = "Cinematic",
		-- Shots (owner request 2026-10-12, PROVISIONAL): the cuts follow the beats below.
		Shots = {
			-- 1 establishing: a detached camera behind and above the walker, craning down, over the title
			{
				At = 0,
				Name = "Establish",
				Boom = { Vector3.new(4, 22, -26), Vector3.new(2.5, 12.5, -15) },
				BoomLook = Vector3.new(0, 2, 24),
				Fov = { 36, 46 },
				Far = 0.5,
				Rack = 3,
			},
			-- 2 the walk and the crossing: back to the head through a dip, hand-held
			{ At = 3.8, Name = "Walk", Cut = "Dip", Fov = { 54, 56 }, Sway = 0.6, Far = 0 },
			-- 3 the poster: lazy orbit, then the push-in while it reads
			{
				At = 12,
				Name = "Poster",
				Fov = { 58, 48 },
				Orbit = { -10, 3 },
				Dolly = { Vector3.zero, Vector3.new(0, 0, 0.4) },
				Sway = 0.12,
				Far = 0.5,
				Rack = 3,
			},
			{
				At = 14.4,
				Name = "Read",
				Fov = { 46, 34 },
				Orbit = { 3, 9 },
				Dolly = { Vector3.new(0, 0, 0.4), Vector3.new(0, 0, 0.9) },
				Sway = 0.1,
				Far = 0.6,
			},
			-- 4 the call: match cut through black on the number, slow push-in while it rings
			{
				At = 17,
				Name = "Phone",
				Cut = "Dip",
				Fov = { 50, 36 },
				Orbit = { 0, -7 },
				Sway = 0.08,
				Far = 0.6,
				Rack = 2.5,
			},
			{
				At = 26,
				Name = "Drift",
				Fov = { 36, 40 },
				Orbit = { -7, 4 },
				Roll = { 0, 0.8 },
				Sway = 0.1,
				Far = 0.6,
				Blend = 1.5,
			},
			-- 5 the trailer: crane up to reveal it in the sun
			{
				At = 31.8,
				Name = "Reveal",
				Fov = { 44, 54 },
				Dolly = { Vector3.new(0, -0.8, 0), Vector3.new(0, 1.2, 0) },
				Sway = 0.2,
				Far = 0.3,
				Blend = 1,
			},
		},
		Beats = {
			{ At = 0, Kind = "Fade", Target = "In" },
			{ At = 0.6, Kind = "Text", Target = "Title", Text = "Sell Hotdogs!", Sub = "Ninth & Juniper", Hold = 3.2 },
			-- Beat 1, the walk: one run from CutsceneMark (north sidewalk, across from the trailer) east to CS-1 (curb, in line
			-- with the crosswalk), straight across the stripes (CS-2, then a bend east) to CS-3 (their south end, east of the P-01 pole) and
			-- to the stand in front of the P-01 flyer (Rules.Stand), eased to a stop by 14 s
			focus(3.8, "Walk"),
			{ At = 3.8, Kind = "MoveTo", Target = "CS-1" },
			{ At = 3.9, Kind = "MoveTo", Target = "CS-2" },
			{ At = 4, Kind = "MoveTo", Target = "CS-3" },
			{ At = 4.1, Kind = "MoveTo", Target = "CS-P{slot}", Arrive = 14 },
			crew(4.4, "I really need a job."),
			-- Beat 2, the poster: seen from the sidewalk, read it
			focus(12, "Poster", 55),
			crew(13.4, "Help wanted?"),
			focus(14.4, "Poster", 45), -- reading the flyer and its number
			crew(15.4, "I'll call them.", "Solo"),
			crew(15.4, "Let's call them.", "Party"),
			-- Beat 3, the call (the number is only on the prompt and the flyer: nobody says digits)
			focus(17, "Phone", 55),
			{ At = 17.2, Kind = "Prompt", Target = "Phone", Text = `Call {PHONE}` },
			{ At = 18.4, Kind = "Actor", Target = "FlipPhone" }, -- slot 1 only, already open (AST-038)
			-- the voice speaks sentence by sentence with a pause after . ? ! (Speech.Pieces); the hang-up (Actors
			-- FLIP_TIME, after the flip beat) waits for the last line
			walt(19, "Bramble's Corner Dogs. Walt here."),
			walt(23.3, "You noticed the flyer. Good."),
			walt(27.1, "Start today. Keys under the mustard."),
			-- Beat 4: the focus stays on the phone/poster through the call; the flip closes (hang-up click), a breath,
			-- then everyone turns to the trailer (MapPoint TRL, eased) and holds on it; fade out; the game fades in after
			focus(31.8, "TRL", 55),
			{ At = 33.4, Kind = "Fade", Target = "Out" },
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
