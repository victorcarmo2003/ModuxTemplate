--!strict
-- Cutscenes (content-data.md §3.19, §6.11; architecture.md §19.16; network.md §6.2; FEAT-004, FEAT-027;
-- script.md §1; ending.md §2.2, §2.4; MAP-01 §11; DEC-021, DEC-075, DEC-078, DEC-088, DEC-097, DEC-194, DEC-205, DEC-309;
-- "The Second Coffee", owner request 2026-10-22, PROVISIONAL).
-- Keys are the Cutscene.Scene wire enum (sentinel "none" first). Owner: narrative-writer (lines) + level-designer
-- (marks, targets); architect (shape). Texts are placeholders until ui-text.md.
--
-- Only the finale and the credits are cutscenes (FEAT-004, FEAT-027); the opening scene was removed (DEC-309). Vehicle swap and lost night are world transitions.
-- The finale of the run is Rules.Finale: "The Second Coffee" (Night 10, Walt revealed), three chained segments
-- second_coffee (dawn, the street) -> second_coffee_in (the pantry) -> second_coffee_out (the street at night) -> credits.
-- "finale" (the kind A1 ending) stays as the fallback chain.
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
--   Actor    client-only actor or prop Target appears/acts (Walt, Raincoat Lady, street cars, flip phone, flyer; the
--            Second Coffee: WaltDawn, HandCup, WaltTurn, DoorBlast, WaltLoom, WaltGrip, Crowd - CutsceneController/Finale.luau)
--            Value (optional): DoorBlast = s from the beat to the blast
--   Sound    Content.Sounds key Target played on screen once (live beats only, never on catch-up)
--   Mash     a cosmetic "mash to break free" bar for Duration s: every tap (E / Space / gamepad X, A / the touch button)
--            fills it and kicks the camera, the bar never goes above Value (0..1) and always drains to nothing by the end of
--            the window; nothing is decided by it. Text = what follows "MASH E" on the bar.
--   Fade also takes Duration (s of that fade; nil = the controller's own second)
-- Fx (Cutscene.Fx, sorted by At): full-screen and audio effects that are a pure function of the scene time (see Fx).
-- The camera is always the avatar's head (DEC-088, DEC-097): it eases to the focus of each beat and allows an elastic
-- free look around it (Rules.Look), springing back when the player lets go.
local Table = require(script.Parent.Table)

export type BeatKind = "Fade" | "Text" | "MoveTo" | "LookAt" | "Focus" | "Prompt" | "Line" | "Actor" | "Mash" | "Sound"
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
	Value: number?, -- Mash: the bar never goes above this (0..1); Actor DoorBlast: s from the beat to the blast
	Duration: number?, -- Mash: s of the window; Fade: s of the fade
}

-- Screen and audio effects of a scene (Cutscene.Fx; CutsceneController/Fx.luau). Each is a pure function of the scene time,
-- so a late client lands on the same frame. Rules:
--   Blur    BlurEffect size Value -> To (nil = Value) over Duration from At, then holds
--   Grade   ColorCorrection saturation Value -> To (nil = Value) and tint -> Color (nil = white) over Duration, then holds;
--           the tint starts from the Color of the previous Grade (white before the first)
--   Flash   a full-screen Color (default white) of alpha Value (<= 0.9), decaying over Duration (softened to 30% with
--           reduced motion; a Color of black is a light blink)
--   Quake   camera shake of amplitude Value (0..1.5) fading over Duration at Rate Hz (default 14); 25% with reduced motion
--   Duck    Music volume multiplier Value -> To over Duration, then holds (it also holds into the next segment of the chain)
-- A scene without a Blur / Grade effect running has none (neutral); a Duck holds until the end of the chain.
export type FxKind = "Blur" | "Grade" | "Flash" | "Quake" | "Duck"

export type Fx = {
	At: number,
	Kind: FxKind,
	Value: number,
	To: number?,
	Duration: number,
	Rate: number?,
	Color: Color3?,
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
	Fov: { number }?, -- {from, to}; overrides the Focus beat's Fov while the shot holds (30..60)
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

-- Credits roll (TASK-657, DEC-363; CutsceneController/Credits.luau). One entry of a section: a centred Text and an
-- optional smaller Note under it (license, source).
export type CreditsLine = { Text: string, Note: string? }
export type CreditsSection = { Title: string, Lines: { CreditsLine } }

-- The roll of scene Scene: from At s it scrolls from under the screen until it is gone above it, in Roll s (a pure
-- function of the scene time, so a late client lands on the same line). Shown over the black of that scene.
export type Credits = {
	Scene: string,
	At: number,
	Roll: number,
	Title: string, -- big title on top of the roll
	Tagline: string?, -- small line under it
	Sections: { CreditsSection },
	Closing: string?, -- last line, after a gap
}

export type Rules = {
	-- the credits roll of the "credits" scene (TASK-657)
	Credits: Credits,
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
	-- scene the Finale phase plays (the chain starts here); "finale" is the older ending kept as a fallback
	Finale: string,
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
	-- s into the scene when its Look leaves and the light blends to the night of the shift over Time s (LightController;
	-- only on a night shift; no scene uses it since the intro was removed, DEC-309). nil = the Look holds to the end.
	Nightfall: { At: number, Time: number }?,
	-- "The Second Coffee": s into the scene when the sky of a Dawn Look goes back to the night over Time s, ClockTime running
	-- BACKWARDS (LightController, attribute CutsceneRegress). nil = no regress.
	Regress: { At: number, Time: number }?,
	Fx: { Fx }?,
}

local function walt(at: number, text: string, variant: Variant?): Beat
	return { At = at, Kind = "Line", Target = "walt", Speaker = "walt", Text = text, Variant = variant }
end

local function crew(at: number, text: string, variant: Variant?): Beat
	return { At = at, Kind = "Line", Target = "crew", Speaker = "crew", Text = text, Variant = variant }
end

-- The Walt of the pantry (CHR-001 once the night shows him): same TTS voice, slower and lower
local function waltDark(at: number, text: string): Beat
	return { At = at, Kind = "Line", Target = "walt_dark", Speaker = "walt_dark", Text = text }
end

-- The stranger on the radio (hallucination radio_voice)
local function radio(at: number, text: string): Beat
	return { At = at, Kind = "Line", Target = "radio", Speaker = "radio", Text = text }
end

local function sound(at: number, key: string): Beat
	return { At = at, Kind = "Sound", Target = key }
end

local function focus(at: number, target: string, fov: number?): Beat
	return { At = at, Kind = "Focus", Target = target, Fov = fov }
end

-- CC-BY 3.0 attribution (docs/art/credits.md: "<Title> by <Author> (<page>), CC-BY 3.0"). No web links on screen
-- (Roblox: no off-platform links); the source and the license by name. PROVISIONAL (frontend-coder, 2026-10-23).
local function ccBy(title: string, author: string, page: string): CreditsLine
	return { Text = `"{title}" by {author}`, Note = `{page} · Licensed under CC BY 3.0` }
end

-- Credits roll (TASK-657; every mandatory attribution of docs/art/credits.md). PROVISIONAL (frontend-coder,
-- 2026-10-23): the wording, the order, the game title and the author line (the owner fills it, DEC-363).
const credits: Credits = {
	Scene = "credits",
	At = 0.5,
	Roll = 57, -- ends at 57.5 s, before the post-credits fade in (60 s)
	Title = "Sell Hotdogs", -- PROVISIONAL: the public name of the game
	Tagline = "Thanks for keeping the light on.",
	Sections = {
		{
			Title = "Made by",
			Lines = {
				-- PROVISIONAL: the author line, the owner fills it (DEC-363)
				{ Text = "Axiom Project Studio", Note = "Created, directed and playtested by the owner" },
				{ Text = "Built with AI", Note = "Design, code and art made with Claude (Anthropic)" },
			},
		},
		{
			Title = "Voices",
			Lines = {
				{ Text = "Walt", Note = "Phone calls recorded by the owner" },
				{ Text = "Additional voices", Note = "Kokoro-82M by hexgrad (Apache 2.0), AI-generated speech" },
			},
		},
		{
			Title = "Third-Party Assets",
			Lines = {
				-- mandatory CC-BY 3.0 credits (docs/art/credits.md); the 2026-10-11 Poly Pizza batch is credited whole
				ccBy("POS Machine", "J-Toastie", "Poly Pizza"),
				ccBy("Low poly phone", "Anastasiia Ku", "Poly Pizza"),
				ccBy("Picnic Table", "J-Toastie", "Poly Pizza"),
				ccBy("Planter & Bushes", "J-Toastie", "Poly Pizza"),
				ccBy("Coffee Machine", "J-Toastie", "Poly Pizza"),
				ccBy("Shelves", "J-Toastie", "Poly Pizza"),
				ccBy("Supermarket Freezer", "Dave Edwards", "Poly Pizza"),
				ccBy("Cash register", "Poly by Google", "Poly Pizza"),
				-- CC0 packs (credit not required, given anyway)
				{
					Text = "Kenney (kenney.nl)",
					Note = "Food Kit, Car Kit, City Kits, Mini Market, Furniture Kit, Nature Kit, Survival Kit, Trashcan (CC0)",
				},
				{ Text = "Mini Market extras", Note = "Fleur Keijsers, Guus Vermeulen (CC0)" },
				{ Text = "Kay Lousberg (kaylousberg.com)", Note = "KayKit Restaurant, Furniture and City Builder Bits (CC0)" },
				{ Text = "Quaternius", Note = "Padlock, Market Stand, Column Round and more (CC0)" },
				{ Text = "RhosGFX", Note = "UI icons (Rhos Vectors)" },
				{ Text = "Aeresei (Fancy Ducc)", Note = "CommunityR6 animation rig" },
			},
		},
		{
			Title = "Music & Sound",
			Lines = {
				{ Text = "Music and ambience", Note = "Axiom Project Studio (AI-generated)" },
				{ Text = "Sound effects", Note = "Pro Sound Effects library, Roblox Creator Store" },
				{ Text = '"The Labyrinth (b)"', Note = "APM Music, Roblox Creator Store" },
				{ Text = "Additional sounds", Note = "Axiom Project Studio and the Roblox audio library" },
			},
		},
		{
			Title = "Tools",
			Lines = {
				{ Text = "Roblox Studio, Luau, Rojo, Wally" },
				{ Text = "Vide, Lync, Charm, ProfileStore, Conch, UI Labs, Modux" },
				{ Text = "Blender, ffmpeg, Kokoro" },
				{ Text = "Fredoka One and Builder Sans fonts" },
			},
		},
		{
			Title = "Special Thanks",
			Lines = {
				{ Text = "Everyone who played the early nights" },
				{ Text = "Bramble's Corner Dogs, open since '79" },
			},
		},
	},
	Closing = "And you. The night shift is yours.",
}

-- PROVISIONAL (frontend-coder, 2026-10-11): every number of the record below
const rules: Rules = {
	Credits = credits,
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
		Line = { "CS-2", "CS-3" }, -- the trailer's sidewalk after the crossing (owner D3 2026-10-12); no scene stops at a sign any more
		Distance = 3.5, -- user feedback 2026-10-11: stop close, right in front of the sign (~3-4 studs)
		MinWidth = 3, -- the big AST-033 card (3.96 studs wide); the window cards are smaller
		Range = 30,
		Fallback = "CS-2",
	},
	Voices = {
		-- user feedback 2026-10-11: a calmer, slower Walt (was 0.95)
		-- owner 2026-10-23: every voice 40% louder, then 60% more (x2.24; was walt 1, crew 0.9, radio 0.8, walt_dark 1)
		walt = { VoiceId = "1", Speed = 1, Volume = 2.24 }, -- owner 2026-10-18: a quicker call (was 0.9)
		crew = { VoiceId = "2", Speed = 1.05, Volume = 2.02 },
		-- owner 2026-10-18: the stranger on the radio (hallucination radio_voice) has a voice of its own
		radio = { VoiceId = "3", Speed = 0.9, Volume = 1.79 },
		-- owner 2026-10-22: Walt once the morning is over - the same voice, slow and low
		walt_dark = { VoiceId = "1", Speed = 0.8, Pitch = 0.8, Volume = 2.24 },
	},
	Finale = "second_coffee",
	-- no street cars in the remaining scenes; the type stays
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
	-- No passers-by and no birds crossing the street (owner D3 2026-10-12); the dust, leaves, papers and trailer steam
	-- of Ambience stay
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
	-- "The Second Coffee" (owner request 2026-10-22, PROVISIONAL): the new ending of Night 10. Walt is the villain; three chained
	-- segments (each one ends in a fade to black, so the server moves the body under the black):
	--   second_coffee      the street at dawn, outside the pantry door: the warm A1 lines, the coffee, the sun stops and the
	--                      sky runs back to the night (Regress), Walt turns
	--   second_coffee_in   the pantry: held breath, the handle, a silence, DOOR-B bursts in, Walt (bigger), the grab, the lift,
	--                      mash to break free (cosmetic), "Now I get the mornings", thrown out
	--   second_coffee_out  the street at night, camera on the ground, the late crowd's hands close in, black, the radio
	-- Marks: the street = SCENE-DOOR-OUT; the pantry = 38% of the way from SCENE-DOOR to REV-4 (about 8 studs in, along the
	-- pantry; the camera is turned to SCENE-DOOR by the first Focus). Times that tie an Actor to other beats are noted where
	-- they matter (CutsceneController/Finale.luau holds the matching constants).
	{
		Key = "second_coffee",
		Duration = 39,
		Cap = 43,
		Skippable = true,
		Participants = "ConnectedAtStart",
		Next = "second_coffee_in",
		Music = "finale",
		Marks = { "SCENE-DOOR-OUT" },
		Cinema = true,
		Look = "Dawn",
		Regress = { At = 28.2, Time = 7 },
		Beats = {
			{ At = 0, Kind = "Fade", Target = "In", Duration = 2 },
			focus(0.5, "SCENE-STEPS-FAR", 56), -- the street Walt comes down
			{ At = 1.5, Kind = "Actor", Target = "WaltDawn" }, -- SCENE-STEPS-FAR -> a few studs from the own body, two coffees
			focus(2.6, "WaltDawn"),
			walt(7.2, "Ten nights. You kept the light on."),
			walt(10.2, "I watched every one. From in here. Best seat in town."),
			walt(14, "I worked that corner forty years. Since '79."),
			walt(17.8, "Keep the rules, and they stay polite. That's the deal."),
			walt(21.4, "My knees are done. But you... you notice things."),
			walt(25, "Here. Morning coffee. You earned it."),
			{ At = 25.6, Kind = "Actor", Target = "HandCup" }, -- the cup flies to the own hand, touches at ~1 s
			sound(28.2, "hum_die"), -- the sun stops (the Regress starts)
			{ At = 29.6, Kind = "Actor", Target = "WaltTurn" }, -- his face goes to the Night pack
			waltDark(30.6, "Forty years, Rookie. Forty years of nights."),
			sound(33, "heartbeat"),
			sound(35.4, "heartbeat"),
			{ At = 36.4, Kind = "Fade", Target = "Out", Duration = 1 },
		},
		Fx = {
			{ At = 28, Kind = "Duck", Value = 1, To = 0, Duration = 3.5 },
			{ At = 28.2, Kind = "Grade", Value = 0, To = -0.55, Duration = 6, Color = Color3.fromRGB(150, 170, 235) },
			{ At = 35.4, Kind = "Quake", Value = 0.18, Duration = 1.2, Rate = 9 },
		},
		Shots = {
			{ At = 0, Name = "Street", Fov = { 58, 56 }, Dolly = { Vector3.zero, Vector3.new(0, 0, 0.4) }, Sway = 0.25 },
			{ At = 6.8, Name = "Arrival", Fov = { 54, 48 }, Dolly = { Vector3.new(0, 0, 0.2), Vector3.new(0, 0, 0.9) }, Sway = 0.15 },
			{ At = 25, Name = "Offer", Fov = { 46, 38 }, Dolly = { Vector3.new(0, 0, 0.5), Vector3.new(0.12, -0.1, 1.1) }, Sway = 0.2 },
			{
				At = 28.2,
				Name = "Wrong",
				Fov = { 38, 34 },
				Dolly = { Vector3.new(0.1, -0.1, 1.1), Vector3.new(0.1, -0.05, 1.6) },
				Roll = { 0, -2.5 },
				Sway = 0.5,
			},
			{
				At = 30.4,
				Name = "Turn",
				Fov = { 34, 28 },
				Dolly = { Vector3.new(0, -0.05, 1.6), Vector3.new(0, 0, 2.1) },
				Roll = { -2.5, -4 },
				Sway = 0.6,
				Far = 0.6,
			},
		},
	},
	{
		Key = "second_coffee_in",
		Duration = 34,
		Cap = 38,
		Skippable = true,
		Participants = "ConnectedAtStart",
		Next = "second_coffee_out",
		Marks = { "SCENE-DOOR|REV-4@0.38" },
		Cinema = true,
		Look = "Night",
		Beats = {
			focus(0, "SCENE-DOOR", 52),
			sound(0.4, "breath_held"),
			{ At = 1.6, Kind = "Fade", Target = "In", Duration = 1.6 },
			sound(3, "floor_creak"),
			sound(3.9, "breath_held"),
			sound(5, "light_flicker"), -- with the black blink of Fx
			sound(6.4, "light_flicker"),
			sound(7.3, "breath_held"),
			-- DoorBlast: the handle rattles at +0, +1.3, +2.9 (the sounds below) and the door bursts in Value = 8 s after the beat
			-- (17 s); after the last rattle (12.2 s) nothing at all until then
			{ At = 9, Kind = "Actor", Target = "DoorBlast", Value = 8 },
			sound(9, "handle_rattle"),
			sound(10.3, "handle_rattle"),
			sound(11.9, "handle_rattle"),
			sound(15.2, "heartbeat"),
			sound(17, "door_force"),
			sound(17, "anger_thud"),
			{ At = 17, Kind = "Actor", Target = "WaltLoom" }, -- in the doorway at once, strides in from +1.6 s, arrives at +4.6 s
			sound(17.1, "plate_smash"),
			focus(17.2, "WaltLoom", 50),
			sound(18.2, "suspense_drop"),
			sound(18.9, "steps_stop"), -- the five strides, with a small Quake each
			sound(19.5, "steps_stop"),
			sound(20.1, "steps_stop"),
			sound(20.7, "steps_stop"),
			sound(21.3, "steps_stop"),
			sound(21.6, "anger_thud"), -- the grab
			{ At = 21.6, Kind = "Actor", Target = "WaltGrip" },
			{ At = 21.7, Kind = "Mash", Target = "Break", Text = "TO BREAK FREE", Value = 0.8, Duration = 6.2 },
			sound(23.4, "breath_held"),
			sound(25, "breath_held"),
			waltDark(28.4, "Now I get the mornings."),
			sound(31.2, "shadow_whoosh"), -- thrown out
			sound(31.2, "anger_thud"),
			{ At = 31.3, Kind = "Fade", Target = "Out", Duration = 0.3 },
		},
		Fx = {
			{ At = 0, Kind = "Duck", Value = 0, Duration = 0 },
			{ At = 0, Kind = "Grade", Value = -0.55, Duration = 0, Color = Color3.fromRGB(150, 170, 235) },
			{ At = 5, Kind = "Flash", Value = 0.55, Duration = 0.12, Color = Color3.new(0, 0, 0) },
			{ At = 6.4, Kind = "Flash", Value = 0.45, Duration = 0.1, Color = Color3.new(0, 0, 0) },
			{ At = 17, Kind = "Flash", Value = 0.85, Duration = 0.35 },
			{ At = 17, Kind = "Quake", Value = 1.1, Duration = 1.4, Rate = 22 },
			{ At = 17, Kind = "Blur", Value = 28, To = 0, Duration = 0.7 },
			{ At = 17.2, Kind = "Grade", Value = -0.55, To = -0.8, Duration = 0.6, Color = Color3.fromRGB(190, 200, 240) },
			{ At = 18.9, Kind = "Quake", Value = 0.35, Duration = 0.3, Rate = 18 },
			{ At = 19.5, Kind = "Quake", Value = 0.35, Duration = 0.3, Rate = 18 },
			{ At = 20.1, Kind = "Quake", Value = 0.35, Duration = 0.3, Rate = 18 },
			{ At = 20.7, Kind = "Quake", Value = 0.35, Duration = 0.3, Rate = 18 },
			{ At = 21.3, Kind = "Quake", Value = 0.35, Duration = 0.3, Rate = 18 },
			{ At = 21.6, Kind = "Quake", Value = 1, Duration = 0.9, Rate = 16 },
			{ At = 31.2, Kind = "Quake", Value = 1.4, Duration = 0.8, Rate = 20 },
			{ At = 31.2, Kind = "Blur", Value = 0, To = 30, Duration = 0.3 },
		},
		Shots = {
			{ At = 0, Name = "Door", Fov = { 52, 48 }, Dolly = { Vector3.zero, Vector3.new(0, 0, 0.3) }, Sway = 0.35 },
			{ At = 12.2, Name = "Hold", Fov = { 46, 40 }, Dolly = { Vector3.new(0, 0, 0.3), Vector3.new(0, 0, 0.9) }, Sway = 0.5 },
			{
				At = 17,
				Name = "Blast",
				Fov = { 40, 56 },
				Ease = "Quad",
				Blend = 0.1,
				Dolly = { Vector3.new(0, 0, 0.9), Vector3.new(0, 0, -0.5) },
				Roll = { 0, 5 },
				Sway = 1,
			},
			{
				At = 19,
				Name = "Loom",
				Fov = { 56, 52 },
				Dolly = { Vector3.new(0, 0, -0.5), Vector3.zero },
				Roll = { 5, 0 },
				Sway = 0.6,
			},
			{
				At = 21.6,
				Name = "Lift",
				Fov = { 52, 56 },
				Ease = "Quad",
				Blend = 0.15,
				Dolly = { Vector3.zero, Vector3.new(0, 1.5, 0.2) },
				Roll = { 0, -7 },
				Sway = 1,
			},
			{
				At = 22.9,
				Name = "Held",
				Fov = { 56, 48 },
				Dolly = { Vector3.new(0, 1.5, 0.2), Vector3.new(0, 1.55, 0.5) },
				Roll = { -7, -4 },
				Sway = 0.9,
			},
			{
				At = 28,
				Name = "Close",
				Fov = { 48, 42 },
				Dolly = { Vector3.new(0, 1.55, 0.5), Vector3.new(0, 1.6, 0.7) },
				Roll = { -4, -2 },
				Sway = 0.5,
				Far = 0.9,
			},
		},
	},
	{
		Key = "second_coffee_out",
		Duration = 19.5,
		Cap = 23,
		Skippable = true,
		Participants = "ConnectedAtStart",
		Next = "credits",
		Marks = { "SCENE-DOOR-OUT" },
		Cinema = true,
		Look = "Night",
		Beats = {
			{ At = 0, Kind = "Fade", Target = "In", Duration = 2.2 },
			focus(0, "SCENE-STEPS-FAR", 58),
			sound(0.6, "breath_held"),
			{ At = 1, Kind = "Actor", Target = "Crowd" }, -- the hands close in from the edges until 8 s, the whispers start
			sound(1.4, "heartbeat"),
			sound(5, "heartbeat"),
			sound(7.5, "scary_violins"),
			{ At = 9, Kind = "Fade", Target = "Out", Duration = 1.6 },
			sound(11.4, "camera_static"),
			sound(12, "camera_fixed"),
			radio(13.6, "...welcome to the other side, Rookie..."),
		},
		Fx = {
			{ At = 0, Kind = "Duck", Value = 0, Duration = 0 },
			{ At = 0, Kind = "Grade", Value = -0.8, Duration = 0, Color = Color3.fromRGB(190, 200, 240) },
			{ At = 0, Kind = "Blur", Value = 14, To = 0, Duration = 2.5 },
			{ At = 4.5, Kind = "Quake", Value = 0.25, Duration = 6, Rate = 9 },
		},
		Shots = {
			{
				At = 0,
				Name = "Floor",
				Fov = { 60, 54 },
				Dolly = { Vector3.new(0, -3.2, 0), Vector3.new(0, -3.3, 0.3) },
				Roll = { 9, 11 },
				Sway = 0.8,
				Far = 0.5,
			},
			{
				At = 7,
				Name = "Swarm",
				Fov = { 54, 44 },
				Dolly = { Vector3.new(0, -3.3, 0.3), Vector3.new(0, -3.4, 0.6) },
				Roll = { 11, 16 },
				Sway = 1,
			},
		},
	},
	-- Credits + post-credits flyer (ending.md §2.4); <= 75 s. The roll is Rules.Credits (over the black until the fade in)
	{
		Key = "credits",
		Duration = 75,
		Cap = 75,
		Skippable = true,
		Participants = "ConnectedAtStart",
		Marks = { "SS-1", "SS-2", "SS-3", "SS-4" },
		Beats = {
			{ At = 60, Kind = "Fade", Target = "In" },
			{ At = 60, Kind = "LookAt", Target = "P-01" },
			{ At = 61, Kind = "Actor", Target = "Flyer" }, -- "NIGHT SHIFT — NOW HIRING" (AN-03)
			{ At = 72, Kind = "Fade", Target = "Out" },
		},
		-- after "The Second Coffee" the music (ducked to nothing there) comes back slowly; a dip and rise on the older chain
		Fx = { { At = 0, Kind = "Duck", Value = 0, To = 1, Duration = 8 } },
	},
} :: { Cutscene })

return Table.with(scenes, { Rules = rules })
