--!strict
-- Horror scenes (TASK-461; DEC-290; design/horror-cinematic.md; tech/horror-scene.md). Owner: game-designer (timing)
-- + art-director (look); architect (shape). Presentation only (T10): a scene never decides an anomaly rule.
--
-- One scene per anomaly key (Key = Content.Anomalies key). The client plays it from the replicated `Anomalies` record
-- (Libs/Net): every step is anchored to the moment the record ENTERED Step.Phase (record.StartedAt of that phase), so
-- every client plays the same timeline with no new packet. Random choices (which strike, which pan) use the record
-- index (occurrence) as the seed.
--   At      s since the record entered Phase. A late joiner skips one-shot steps already past (> Rules.Latency late)
--           and applies the held state of the persistent kinds (Lights, Vignette, Lightning, Music) where it is.
--   Phase   "Signal" | "Active" | "Resolved" | "Failed" (the record phases)
--   Who     nil/"All" = every client of the party; "Caught" = only the client that got the anomaly's caught cue
--           (Cue "jumpscare" with Entity = its UserId % 65536); "Safe" = every other client
-- Kinds:
--   Sound      one-shot of Content.Sounds[Target] (Value = volume scale, default 1; Point = MapPoint for 3D sound,
--              To = MapPoint it travels to over Duration, for steps passing by)
--   Music      score step of the music system (TASK-443): Target = key of Content.Sounds (Group Music) or "Stop"
--   Lights     Target "Off" | "On" | "Flicker" | "Cascade" over Duration (the anomaly's own light roots)
--   Lightning  storm ramp: Value = first interval s, To = last interval s, over Duration; Burst = strikes per window at
--              the end (rain/thunder of AtmosphereController, seeded)
--   Whispers   the words on screen (Effects/Kit/Whispers), ramping: Value = rate at the start, To = rate at the end
--              (1 = Kit default), over Duration (DEC-291: few at first, then en masse). Target = key of Words (the
--              list said; DEC-293: real hints, not just HIDE); nil = the Kit's own HIDE list
--   Vignette   screen darkening: Value -> To over Duration (0..Rules.MaxVignette)
--   Shake      camera shake: Target = profile key of Rules.Shakes, Value = scale (default 1)
--   Fov        field of view delta: Value degrees (|Value| <= Rules.MaxFov), To = 0 to come back, over Duration
--   Nudge      the view is pulled at most Value degrees towards Point (<= Rules.MaxNudge); never locks input
--   Text       on-screen warning Text (English placeholder until ui-text.md), held Duration s (DEC-283)
--   Actor      client-only actor (TASK-472). Target nil = two white eyes at Point for Duration s. Target = Model name
--              anywhere under ReplicatedStorage.Assets (pivot at the feet, facing -Z; a dark placeholder while the art is
--              missing): walks from where it stands (or from Point, where it appears, when not there yet; no Point = only
--              if already there) to the MapPoint To over Duration, then stands (one actor per Target and run). Sound =
--              Content.Sounds key played on its feet at each step while it walks (the steps belong to the model).
--              Seen "Cameras" = invisible (no light, no shadow) unless this client looks through a security camera
--              (Kit/Watch); nil/"All" = always seen. Value = 1: gone when it arrives (walks off). Held: a late joiner
--              gets it where it should be.
--   Door       the hiding door: Target "Rattle" | "Push" | "Hold" | "Lock" (kept shut until the run ends); Point = door MapPoint; Duration
--   Shadow     a shadow on the light under the door: Point = door MapPoint, To = MapPoint of the side it comes from / goes to
--              (the steps), Target "Pass" (crosses, default) | "Arrive" (comes in from that side and stays in the middle) |
--              "Leave" (the one standing there goes back out to that side), over Duration
-- Every number PROVISIONAL (DEC-290) until the owner's Play. Mild (DEC-172): no blood, scares <= 1 s, no clipped scream.
local Table = require(script.Parent.Table)

export type Phase = "Signal" | "Active" | "Resolved" | "Failed"
export type Who = "All" | "Caught" | "Safe"
export type StepKind =
	"Sound"
	| "Music"
	| "Lights"
	| "Lightning"
	| "Whispers"
	| "Vignette"
	| "Shake"
	| "Fov"
	| "Nudge"
	| "Text"
	| "Actor"
	| "Door"
	| "Shadow"

export type Step = {
	At: number,
	Phase: Phase,
	Kind: StepKind,
	Who: Who?,
	Target: string?,
	Value: number?,
	To: (number | string)?,
	Duration: number?,
	Point: string?,
	Burst: number?,
	Text: string?,
	Sound: string?, -- Actor: Content.Sounds key of its steps
	Seen: ("All" | "Cameras")?, -- Actor: who sees it
}

export type Scene = {
	Key: string, -- = Content.Anomalies key
	Name: string, -- English, dev/log only
	-- true = the client player (TASK-462) plays it in the real game; nil/false = only through `/dev scene <key>`
	-- (kept off while an Effects/ module still does the same job, so no sound or light is doubled; TASK-467 turns the
	-- blackout on)
	Live: boolean?,
	Steps: { Step }, -- any order; the player sorts by phase, then At
}

export type ShakeProfile = {
	Amplitude: number, -- studs, camera space
	Frequency: number, -- Hz
	Duration: number, -- s
}

export type Rules = {
	Latency: number, -- s a one-shot may start late and still play
	ReduceMotion: number, -- scale of Shake/Fov/Nudge when Motion.Reduced() (the game's existing reduced-motion setting)
	MaxControlLock: number, -- s; no step may take the camera longer than this
	MaxVignette: number,
	MaxFov: number, -- degrees
	MaxNudge: number, -- degrees
	Shakes: { [string]: ShakeProfile },
}

-- ANM-020 blackout, the owner's reference scene (DEC-290, DEC-291; design/horror-cinematic.md §2). TASK-467: fitted to the
-- restaurant timeline of Rules/ANM-020 (Signal = omen ~2.5 s; Active = the dark, RestaurantWindow 15 s to hold the
-- breaker; then Failed = the shape came: whoever was not hidden pays, the dark lasts until the breaker or MaxDark).
-- What Effects/ANM-020 + Score/ already do is NOT repeated here: the lights going out / flicker / coming back, the
-- "lights off" snap, the music steps and the POWER OUT caption. The scene adds the directed layer: the jolt, the bell,
-- the HIDE words ramping (few, then en masse), the vignette, the steps coming to the pantry's back door, the shadow on
-- the light under it, the handle tried and the latch holding just as the window ends, the eyes at the window for
-- whoever stayed out, the steps leaving. Sound bank of TASK-466 (sound-list.md §5.19); the approaching steps stay on
-- walker_step until heavy_steps has an Id. TASK-472: the steps are The Walker's own (Actor), seen only on the cameras.
const blackout: Scene = {
	Key = "anm_020_blackout",
	Name = "The blackout",
	Live = true,
	-- owner 2026-10-18: the phone glitch starts the omen (6.5 s file, played whole); 2 s later the power cuts (OmenFor 2);
	-- the dark lasts 30 s (RestaurantWindow) under the score's Rise stage (violin notes looped, rising, over one rising note
	-- cut dead at 30 s); the jumpscare lands on that second (Effects/ANM-020). Hiding no longer saves (DEC-292).
	Steps = {
		-- omen (Signal, 2 s): the phone glitch; its strange voice runs ~4.5 s into the dark
		{ At = 0, Phase = "Signal", Kind = "Sound", Target = "phone_glitch" },
		-- t = 0: the breaker drops, the hum dies, a jolt
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "power_cut" },
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "hum_die" },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -3, To = 0, Duration = 0.8 },
		-- the bell the moment the lights go out (owner 2026-10-18)
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "church_bell" },
		-- the HIDE words: a few, then all over the screen (DEC-291); the edges close in
		{ At = 5, Phase = "Active", Kind = "Whispers", Target = "blackout", Value = 0.4, To = 3, Duration = 17 },
		{ At = 5, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.35, Duration = 17 },
		-- the steps: The Walker (AST-064) from the back alley to the pantry's exit door, its own steps on its feet; seen
		-- only through the security cameras, never in first person (owner 2026-10-18, TASK-472)
		{ At = 18, Phase = "Active", Kind = "Actor", Target = "AST-064_Walker", Point = "SCENE-STEPS-FAR", To = "SCENE-DOOR-OUT", Duration = 8, Sound = "walker_step", Seen = "Cameras" },
		{ At = 18, Phase = "Active", Kind = "Fov", Value = 1, To = 0, Duration = 8 },
		{ At = 20, Phase = "Active", Kind = "Sound", Target = "breath_held" },
		{ At = 22, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		-- its shadow comes in under the door from the side of its steps and stops there (owner 2026-10-18)
		{ At = 24.8, Phase = "Active", Kind = "Shadow", Target = "Arrive", Point = "SCENE-DOOR", To = "SCENE-STEPS-FAR", Duration = 1.2 },
		{ At = 26, Phase = "Active", Kind = "Sound", Target = "steps_stop", Point = "SCENE-DOOR-OUT" },
		{ At = 26, Phase = "Active", Kind = "Vignette", Value = 0.35, To = 0.5, Duration = 3.5 },
		-- it tries the door once: the handle, a push, the latch holds - right before the note dies
		{ At = 27, Phase = "Active", Kind = "Door", Target = "Rattle", Point = "SCENE-DOOR", Duration = 0.9 },
		{ At = 27, Phase = "Active", Kind = "Sound", Target = "handle_rattle", Point = "SCENE-DOOR" },
		{ At = 27, Phase = "Active", Kind = "Shake", Target = "Door", Point = "SCENE-DOOR" },
		{ At = 28.2, Phase = "Active", Kind = "Door", Target = "Push", Point = "SCENE-DOOR", Duration = 0.5 },
		{ At = 28.2, Phase = "Active", Kind = "Sound", Target = "door_force", Point = "SCENE-DOOR" },
		{ At = 29, Phase = "Active", Kind = "Door", Target = "Hold", Point = "SCENE-DOOR", Duration = 0.4 },
		{ At = 29, Phase = "Active", Kind = "Sound", Target = "latch_hold", Point = "SCENE-DOOR" },
		-- 30 s (Failed): the jumpscare (Effects/ANM-020, on the beat), then it walks away; the dark stays until the breaker
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 1, Phase = "Failed", Kind = "Actor", Target = "AST-064_Walker", Point = "SCENE-DOOR-OUT", To = "SCENE-STEPS-FAR", Duration = 6, Sound = "walker_step", Seen = "Cameras", Value = 1 },
		{ At = 1, Phase = "Failed", Kind = "Shadow", Target = "Leave", Point = "SCENE-DOOR", To = "SCENE-STEPS-FAR", Duration = 1.2 },
		{ At = 1, Phase = "Failed", Kind = "Vignette", Value = 0.5, To = 0.15, Duration = 4 },
		-- the breaker held in time (Resolved): the power comes back
		{ At = 0, Phase = "Resolved", Kind = "Sound", Target = "power_up" },
		{ At = 0, Phase = "Resolved", Kind = "Shadow", Target = "Leave", Point = "SCENE-DOOR", To = "SCENE-STEPS-FAR", Duration = 0.8 },
		-- the Walker goes back if it had come (no Point: nothing when the breaker held before t = 18)
		{ At = 0, Phase = "Resolved", Kind = "Actor", Target = "AST-064_Walker", To = "SCENE-STEPS-FAR", Duration = 6, Sound = "walker_step", Seen = "Cameras", Value = 1 },
		{ At = 0.3, Phase = "Resolved", Kind = "Sound", Target = "lamps_cascade" },
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Vignette", Value = 0, To = 0, Duration = 0.6 },
	},
}

-- Whisper word lists (DEC-293, owner 2026-10-18): the words on screen are real hints for the player, said in the
-- character's voice. blackout = the scene's Whispers step; low_sanity = VitalController while sanity is in the low band.
const words: { [string]: { string } } = {
	blackout = {
		"HE'S COMING",
		"HE'S COMING",
		"WHERE'S THE BREAKER?",
		"WHERE'S THE BREAKER?",
		"I NEED TO FIX THE LIGHTS",
		"FIX THE LIGHTS",
		"THE BREAKER IS OUTSIDE",
		"hurry...",
		"he's close",
		"don't let him in",
	},
	low_sanity = {
		"LOW SANITY",
		"DRINK COFFEE",
		"I NEED COFFEE",
		"I NEED COFFEE",
		"WHERE'S THE COFFEE?",
		"coffee...",
		"the coffee machine",
	},
}

const rules: Rules = {
	Latency = 0.15,
	ReduceMotion = 0.25,
	MaxControlLock = 2,
	MaxVignette = 0.6,
	MaxFov = 6,
	MaxNudge = 3,
	Shakes = {
		Jolt = { Amplitude = 0.12, Frequency = 18, Duration = 0.15 },
		Step = { Amplitude = 0.03, Frequency = 10, Duration = 0.12 },
		Door = { Amplitude = 0.08, Frequency = 22, Duration = 0.35 },
	},
}

return Table.with(Table.new({ blackout } :: { Scene }), {
	Rules = Table.record(rules),
	Words = Table.record(words),
	PhaseOrder = table.freeze({ Signal = 1, Active = 2, Resolved = 3, Failed = 3 }),
})
