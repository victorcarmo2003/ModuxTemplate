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
--   Heartbeat  single heartbeats (Content.Sounds heartbeat) at Value BPM ramping to To BPM over Duration, louder and a
--              touch higher as it speeds up; Value = 0 stops it (owner 2026-10-18)
--   Cinema     film look: black bars (Value = height of each bar, fraction of the screen, 0..0.2) eased over Duration,
--              and the game HUD (coins, shop, hotbar, chat) hidden; Value = 0 brings the HUD back. Prompts stay.
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
--   Roof       (TASK-484) heavy steps on the roof along a line through each client's own position (so it always passes
--              overhead; same seeded heading everywhere). Target "Walk" = from Value to To (fractions 0..1 of the line)
--              over Duration; "Leave" = from where it is to To (default 1), fading; "Thud" = one landing at Value (nil =
--              where it is). Each step: Sound (default roof_step) above the ceiling, dust falling, lamps near it swaying
--   HeadDown   (TASK-484) held: while it lasts, a look pitched above Value degrees is nudged softly back below the
--              horizon (To degrees per nudge, <= Rules.MaxNudge); Value = 0 stops it. Helps, never locks
--   Grade      (TASK-493, owner 2026-10-18 "distorção de cores") colour distortion of the whole screen: strength Value ->
--              To (0..1) over Duration; Target "Cold" (default: drained, blue) | "Red" | "Sick" (green). Held; 0 = off
--   Blur       (TASK-493) screen blur: Value -> To (0..Rules.MaxBlur) over Duration. Held; 0 = off
--   Silence    (TASK-493, the dramatic pause) music, ambience and the kitchen fade to Value -> To (volume scale 0..1)
--              over Duration; the Sfx (steps, heart, breath, the hit) are untouched. 1 = back
-- Every number PROVISIONAL (DEC-290) until the owner's Play. Mild (DEC-172): no blood, scares <= 1 s, no clipped scream.
local Table = require(script.Parent.Table)
local Restaurant = require(script.Parent.Restaurant)

export type Phase = "Signal" | "Active" | "Resolved" | "Failed"
export type Who = "All" | "Caught" | "Safe"
export type StepKind =
	"Sound"
	| "Music"
	| "Lights"
	| "Lightning"
	| "Whispers"
	| "Heartbeat"
	| "Cinema"
	| "Vignette"
	| "Shake"
	| "Fov"
	| "Nudge"
	| "Text"
	| "Actor"
	| "Door"
	| "Shadow"
	| "Roof"
	| "HeadDown"
	| "Grade"
	| "Blur"
	| "Silence"

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
	Sound: string?, -- Actor / Roof: Content.Sounds key of its steps
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

-- Stare pressure, the look (TASK-482; DEC-294, DEC-295 Q-368 A; tech/stare-pressure.md). The timing (cone, Delay,
-- Release) is Content.Sanity.Stare, shared with the server drain; these are presentation only. Pressure 0..1 builds over
-- Build s once the stare passed Delay and falls back to 0 over Sanity.Stare.Release when the player looks away.
export type Stare = {
	Build: number, -- s from the start of the pressure to its peak
	HeartFrom: number, -- BPM when the pressure starts
	HeartTo: number, -- BPM at the peak
	Vignette: number, -- screen edge darkness at the peak (<= Rules.MaxVignette)
	Flicker: number, -- +- edge flicker at the peak ("glaucoma"), off with Motion.Reduced
	HeadSpeed: number, -- degrees/s the head turns to follow the camera at the peak (slow = creepy)
	HeadMax: number, -- degrees the head may turn past its own pose
	-- degrees the head tilts sideways at the peak: a customer that already faces the camera (at the window) has nothing to
	-- turn, so the tilt is what shows the stare moved it
	HeadTilt: number,
	FaceStretch: number, -- face shell scale share at the peak (taller and narrower)
	FaceRoll: number, -- degrees of face tilt at the peak, swaying
	WhisperFrom: number, -- whisper rate when the pressure starts (1 = Kit default)
	WhisperTo: number, -- whisper rate at the peak
	Words: { [string]: string }, -- anomaly key -> key of Words; missing = "stare"
}

export type Rules = {
	Latency: number, -- s a one-shot may start late and still play
	ReduceMotion: number, -- scale of Shake/Fov/Nudge when Motion.Reduced() (the game's existing reduced-motion setting)
	MaxControlLock: number, -- s; no step may take the camera longer than this
	MaxVignette: number,
	MaxFov: number, -- degrees
	MaxNudge: number, -- degrees
	-- degrees; a suspense event's camera hijack (CameraController:HorrorPull, Content.Suspense.Rules.Hijack.Pull), not a scene step
	MaxPull: number,
	MaxBlur: number, -- TASK-493: BlurEffect Size at most
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
		-- film look: black bars close in and the HUD goes (coins, shop, hotbar, chat); prompts stay (owner 2026-10-18)
		{ At = 0, Phase = "Active", Kind = "Cinema", Value = 0.11, Duration = 0.8 },
		-- the heart starts as the steps get near, speeds up, and stops dead just before the note dies: 0.6 s of
		-- violin alone, then the jumpscare
		{ At = 14, Phase = "Active", Kind = "Heartbeat", Value = 62, To = 150, Duration = 15 },
		{ At = 29.4, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
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
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 1, Phase = "Failed", Kind = "Actor", Target = "AST-064_Walker", Point = "SCENE-DOOR-OUT", To = "SCENE-STEPS-FAR", Duration = 6, Sound = "walker_step", Seen = "Cameras", Value = 1 },
		{ At = 1, Phase = "Failed", Kind = "Shadow", Target = "Leave", Point = "SCENE-DOOR", To = "SCENE-STEPS-FAR", Duration = 1.2 },
		{ At = 1, Phase = "Failed", Kind = "Vignette", Value = 0.5, To = 0.15, Duration = 4 },
		-- the breaker held in time (Resolved): the power comes back
		{ At = 0, Phase = "Resolved", Kind = "Sound", Target = "power_up" },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.4, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 0.8 },
		{ At = 0, Phase = "Resolved", Kind = "Shadow", Target = "Leave", Point = "SCENE-DOOR", To = "SCENE-STEPS-FAR", Duration = 0.8 },
		-- the Walker goes back if it had come (no Point: nothing when the breaker held before t = 18)
		{ At = 0, Phase = "Resolved", Kind = "Actor", Target = "AST-064_Walker", To = "SCENE-STEPS-FAR", Duration = 6, Sound = "walker_step", Seen = "Cameras", Value = 1 },
		{ At = 0.3, Phase = "Resolved", Kind = "Sound", Target = "lamps_cascade" },
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Vignette", Value = 0, To = 0, Duration = 0.6 },
		-- TASK-493: the colour drains out of the dark as the steps come; a blur on the push of the door
		{ At = 5, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.6, Duration = 22 },
		{ At = 28.2, Phase = "Active", Kind = "Blur", Value = 5, To = 0, Duration = 0.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.9, To = 0.35, Duration = 3 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 14, To = 0, Duration = 1.5 },
		{ At = 0, Phase = "Resolved", Kind = "Grade", Value = 0.6, To = 0, Duration = 1.5 },
	},
}

-- ANM-019 The roof walker, "don't look up" (TASK-484; DEC-294, DEC-295 / Q-367 A; design/horror-cinematic.md). Fitted to
-- Rules/ANM-019: Signal = OmenFor 3 s (it lands on the roof), Active = WalkFor 16 s (the rule counts from 1 s: a look
-- above 35 degrees held 0.6 s), then Failed (somebody looked up: it drops in front of that player's window, the others
-- hear it leave) or Resolved (it reached the far end and went), LeaveFor 5 s each. The walk passes over every player's
-- own head at ~7 s and stands there, silent, 2.5 s before it goes on. The caught player's drop and hit are cue-driven
-- (Effects/ANM-019, on the jumpscare cue); the scene adds what everyone hears and feels.
const roofWalker: Scene = {
	Key = "anm_019_roof_walker",
	Name = "The roof walker",
	Live = true,
	Steps = {
		-- omen (Signal, 3 s): something heavy lands at one end of the roof
		{ At = 0, Phase = "Signal", Kind = "Roof", Target = "Thud", Value = 0 },
		{ At = 0, Phase = "Signal", Kind = "Sound", Target = "horror_sting", Value = 0.7 },
		{ At = 0, Phase = "Signal", Kind = "Fov", Value = -2, To = 0, Duration = 0.6 },
		{ At = 0.2, Phase = "Signal", Kind = "Cinema", Value = 0.11, Duration = 1 },
		{ At = 0.5, Phase = "Signal", Kind = "HeadDown", Value = 20, To = 3, Duration = 3 },
		{ At = 0.6, Phase = "Signal", Kind = "Whispers", Target = "roof", Value = 0.5, To = 1.2, Duration = 3 },
		{ At = 0.8, Phase = "Signal", Kind = "Heartbeat", Value = 70, To = 90, Duration = 2.5 },
		{ At = 1.2, Phase = "Signal", Kind = "Sound", Target = "breath_held" },
		-- the walk (Active, 16 s): towards the player, overhead at ~7 s
		{ At = 0, Phase = "Active", Kind = "Roof", Target = "Walk", Value = 0, To = 0.5, Duration = 7 },
		{ At = 0, Phase = "Active", Kind = "HeadDown", Value = 20, To = 3, Duration = 16 },
		{ At = 0, Phase = "Active", Kind = "Whispers", Target = "roof", Value = 0.8, To = 2.4, Duration = 7 },
		{ At = 0, Phase = "Active", Kind = "Heartbeat", Value = 90, To = 140, Duration = 7 },
		{ At = 0, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.32, Duration = 7 },
		-- it stops right above: the words go quiet, the heart races, then one burst of DON'T LOOK UP
		{ At = 7, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 7, Phase = "Active", Kind = "Heartbeat", Value = 150, To = 160, Duration = 2.5 },
		{ At = 7, Phase = "Active", Kind = "Vignette", Value = 0.32, To = 0.42, Duration = 2.5 },
		{ At = 7.3, Phase = "Active", Kind = "Sound", Target = "breath_held" },
		{ At = 7.8, Phase = "Active", Kind = "Whispers", Target = "roof", Value = 3, To = 3, Duration = 1.5 },
		-- it goes on to the far end
		{ At = 9.5, Phase = "Active", Kind = "Roof", Target = "Walk", Value = 0.5, To = 1, Duration = 6 },
		{ At = 9.5, Phase = "Active", Kind = "Whispers", Target = "roof", Value = 1.5, To = 0.3, Duration = 6 },
		{ At = 9.5, Phase = "Active", Kind = "Heartbeat", Value = 140, To = 90, Duration = 6 },
		{ At = 9.5, Phase = "Active", Kind = "Vignette", Value = 0.42, To = 0.15, Duration = 6 },
		-- nobody looked up (Resolved): it jumps off the far end and is gone
		{ At = 0, Phase = "Resolved", Kind = "HeadDown", Value = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.2, Phase = "Resolved", Kind = "Roof", Target = "Thud", Value = 1 },
		{ At = 0.4, Phase = "Resolved", Kind = "Vignette", Value = 0.15, To = 0, Duration = 1.5 },
		{ At = 0.8, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },
		-- somebody looked up (Failed): the caught one gets the drop + hit (Effects/ANM-019); everyone else hears it
		-- jump off the roof and run
		{ At = 0, Phase = "Failed", Kind = "HeadDown", Value = 0 },
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.3, Phase = "Failed", Who = "Safe", Kind = "Roof", Target = "Thud" },
		{ At = 0.5, Phase = "Failed", Who = "Safe", Kind = "Sound", Target = "shadow_whoosh", Value = 0.6 },
		{ At = 0.8, Phase = "Failed", Who = "Safe", Kind = "Roof", Target = "Leave", To = 1, Duration = 2.4 },
		{ At = 0.8, Phase = "Failed", Who = "Safe", Kind = "Vignette", Value = 0.3, To = 0, Duration = 2.5 },
		{ At = 1.4, Phase = "Failed", Who = "Caught", Kind = "Heartbeat", Value = 150, To = 80, Duration = 3 },
		{ At = 1.4, Phase = "Failed", Who = "Caught", Kind = "Vignette", Value = 0.5, To = 0, Duration = 3.5 },
		{ At = 3.5, Phase = "Failed", Who = "Caught", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 3.5, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
		-- TASK-493: drained colour; right above you the world goes quiet, then comes back as it walks on
		{ At = 0.5, Phase = "Signal", Kind = "Grade", Target = "Cold", Value = 0, To = 0.25, Duration = 3 },
		{ At = 0, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0.25, To = 0.55, Duration = 7 },
		{ At = 7, Phase = "Active", Kind = "Silence", Value = 1, To = 0.1, Duration = 0.5 },
		{ At = 7, Phase = "Active", Kind = "Blur", Value = 0, To = 2.5, Duration = 2.5 },
		{ At = 9.5, Phase = "Active", Kind = "Silence", Value = 0.1, To = 1, Duration = 2 },
		{ At = 9.5, Phase = "Active", Kind = "Blur", Value = 2.5, To = 0, Duration = 1.5 },
		{ At = 9.5, Phase = "Active", Kind = "Grade", Value = 0.55, To = 0.25, Duration = 6 },
		-- TASK-493: colour and sound come back
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0.4, Phase = "Resolved", Kind = "Grade", Value = 0.4, To = 0, Duration = 2 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		-- TASK-493: the hit on whoever was caught: red, blurred, then back
		{ At = 0.6, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0.6, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0.6, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 2.1, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.4, To = 0, Duration = 2.5 },
	},
}

-- ANM-017 The crawler, "get off the floor" (TASK-483; DEC-294; design/horror-cinematic.md §6.2). Restaurant only (the
-- trailer keeps the HideZone and its own warning). Fitted to Rules/ANM-017 with the restaurant on: Signal = WarnFor 10 s
-- (it scratches under the kitchen floor, the boards give), Active = PassFor 9 s (it bursts out at the east end of the
-- aisle, runs between the counters, rears up in the middle at 3-6 s looking up at whoever climbed: the look window
-- of the rule), then Failed (someone stayed on the floor: jumpscare + faint, Effects/Kit/Hide) or Resolved. The body
-- and its path are Effects/ANM-017; the scene adds the words (real hints: get off the floor), heart, edges and bars.
const crawler: Scene = {
	Key = "anm_017_crawler",
	Name = "The crawler",
	Live = Restaurant.Rules.Enabled,
	Steps = {
		-- the warning (Signal, 10 s): something under the floor
		{ At = 0, Phase = "Signal", Kind = "Sound", Target = "horror_sting", Value = 0.6 },
		{ At = 0, Phase = "Signal", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Signal", Kind = "Cinema", Value = 0.11, Duration = 1 },
		{ At = 0.3, Phase = "Signal", Kind = "Sound", Target = "floor_creak", Point = "TRL" },
		{ At = 0.5, Phase = "Signal", Kind = "Whispers", Target = "crawler", Value = 0.5, To = 2.6, Duration = 8 },
		{ At = 0.5, Phase = "Signal", Kind = "Heartbeat", Value = 72, To = 135, Duration = 9 },
		{ At = 0.5, Phase = "Signal", Kind = "Vignette", Value = 0, To = 0.3, Duration = 9 },
		{ At = 4, Phase = "Signal", Kind = "Sound", Target = "floor_creak", Point = "TRL", Value = 0.8 },
		{ At = 6, Phase = "Signal", Kind = "Shake", Target = "Step" },
		{ At = 7.5, Phase = "Signal", Kind = "Shake", Target = "Step" },
		{ At = 8.5, Phase = "Signal", Kind = "Sound", Target = "breath_held" },
		-- a breath of silence before it comes out
		{ At = 9.3, Phase = "Signal", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		-- the pass (Active, 9 s): it bursts out and runs the aisle
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -4, To = 0, Duration = 0.6 },
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "shadow_whoosh", Point = "TRL" },
		{ At = 0, Phase = "Active", Kind = "Heartbeat", Value = 140, To = 165, Duration = 3 },
		{ At = 0, Phase = "Active", Kind = "Vignette", Value = 0.3, To = 0.45, Duration = 3 },
		-- it rears up and looks for feet on the floor: one burst of the words, then nothing
		{ At = 3, Phase = "Active", Kind = "Sound", Target = "breath_held" },
		{ At = 3, Phase = "Active", Kind = "Whispers", Target = "crawler", Value = 3, To = 3, Duration = 1.2 },
		{ At = 4.2, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 6, Phase = "Active", Kind = "Heartbeat", Value = 150, To = 90, Duration = 3 },
		{ At = 6, Phase = "Active", Kind = "Vignette", Value = 0.45, To = 0.15, Duration = 3 },
		{ At = 6.5, Phase = "Active", Kind = "Sound", Target = "floor_creak", Point = "TRL", Value = 0.5 },
		-- everyone stayed up (Resolved): it is gone under the floor
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Vignette", Value = 0.15, To = 0, Duration = 1 },
		{ At = 0.5, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },
		-- someone stayed on the floor (Failed): the caught one gets the face (Effects/Kit/Hide), the others watch it go on
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.8, Phase = "Failed", Who = "Caught", Kind = "Vignette", Value = 0.5, To = 0, Duration = 3 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Heartbeat", Value = 155, To = 85, Duration = 4 },
		{ At = 4, Phase = "Failed", Who = "Safe", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 1, Phase = "Failed", Who = "Safe", Kind = "Vignette", Value = 0.4, To = 0, Duration = 3 },
		{ At = 4, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
		-- TASK-493: sick colour while it is under the floor; one beat of silence, then it bursts out loud
		{ At = 0.5, Phase = "Signal", Kind = "Grade", Target = "Sick", Value = 0, To = 0.45, Duration = 9 },
		{ At = 9.3, Phase = "Signal", Kind = "Silence", Value = 1, To = 0.05, Duration = 0.4 },
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 0.05, To = 1, Duration = 0.2 },
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 1 },
		{ At = 0, Phase = "Active", Kind = "Blur", Value = 7, To = 0, Duration = 0.9 },
		{ At = 3, Phase = "Active", Kind = "Grade", Target = "Sick", Value = 0.45, To = 0.75, Duration = 1.5 },
		{ At = 3, Phase = "Active", Kind = "Blur", Value = 0, To = 3, Duration = 1.5 },
		{ At = 6, Phase = "Active", Kind = "Blur", Value = 3, To = 0, Duration = 2 },
		{ At = 6, Phase = "Active", Kind = "Grade", Value = 0.75, To = 0.3, Duration = 3 },
		-- TASK-493: colour and sound come back
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0.4, Phase = "Resolved", Kind = "Grade", Value = 0.4, To = 0, Duration = 2 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		-- TASK-493: the hit on whoever was caught: red, blurred, then back
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.4, To = 0, Duration = 2.5 },
	},
}

-- ANM-012 The turned neck (TASK-483; DEC-294 "needs terror"; design/horror-cinematic.md §6.3). Anchored to the actor's
-- record: Active = she spawned and walks to the counter (Kit/CustomerActor), then Resolved (refused: cue neck_snap,
-- Anomalies/ANM-012) or Failed (her order taken: jumpscare + faint). The terror of looking at her is the stare pressure
-- (TASK-482: heart, edges, head following, face, "STOP STARING"), so the scene has NO heart and keeps its words to the
-- first seconds (hints: refuse her) before the stare can start; then cracks of her neck from the counter and the bars.
const turnedNeck: Scene = {
	Key = "anm_012_turned_neck",
	Name = "The turned neck",
	Live = true,
	Steps = {
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "neck_crack", Point = "Q1", Value = 0.35 },
		{ At = 1.5, Phase = "Active", Kind = "Cinema", Value = 0.08, Duration = 1.5 },
		{ At = 2, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.18, Duration = 8 },
		{ At = 2.5, Phase = "Active", Kind = "Whispers", Target = "neck", Value = 0.3, To = 1.1, Duration = 7 },
		{ At = 6, Phase = "Active", Kind = "Sound", Target = "neck_crack", Point = "Q1", Value = 0.6 },
		{ At = 9.5, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 11, Phase = "Active", Kind = "Sound", Target = "neck_crack", Point = "Q1", Value = 0.8 },
		-- the bars go with the words (owner 2026-10-18: no black bars left alone after the warning)
		{ At = 9.5, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
		{ At = 9.5, Phase = "Active", Kind = "Vignette", Value = 0.18, To = 0.08, Duration = 3 },
		-- refused (Resolved): her neck snaps round (cue), then the room breathes again
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0.3, Phase = "Resolved", Kind = "Shake", Target = "Door" },
		{ At = 1, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 1.2, Phase = "Resolved", Kind = "Vignette", Value = 0.18, To = 0, Duration = 1.5 },
		{ At = 1.5, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },
		-- her order taken (Failed): the face (Kit Scare); everyone else hears the crack
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Sound", Target = "neck_crack", Point = "Q1" },
		{ At = 0.8, Phase = "Failed", Kind = "Vignette", Value = 0.4, To = 0, Duration = 3 },
		{ At = 2, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
		-- TASK-493: the colour leaves the counter as she waits; the loud crack blurs the view
		{ At = 2, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.32, Duration = 10 },
		{ At = 10.6, Phase = "Active", Kind = "Silence", Value = 1, To = 0.2, Duration = 0.4 },
		{ At = 11, Phase = "Active", Kind = "Silence", Value = 0.2, To = 1, Duration = 1.5 },
		{ At = 11, Phase = "Active", Kind = "Blur", Value = 4, To = 0, Duration = 1 },
		{ At = 9.5, Phase = "Active", Kind = "Grade", Value = 0.32, To = 0.12, Duration = 3 },
		-- TASK-493: colour and sound come back
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0.4, Phase = "Resolved", Kind = "Grade", Value = 0.4, To = 0, Duration = 2 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		-- TASK-493: the hit on whoever was caught: red, blurred, then back
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.4, To = 0, Duration = 2.5 },
	},
}

-- ANM-004 The copies (TASK-483; DEC-294 "tie it to the mental pressure"; design/horror-cinematic.md §6.4). Anchored to the
-- copy's record: Active = the copy spawned (Anomalies/ANM-004), Resolved = refused, Failed = its order taken (cue
-- mirror_smile; in the restaurant there is no back door, so it only costs sanity). Staring at it is the stare pressure
-- with its own words (Words.stare_copy); the scene gives the first hint (they already left) and the bars.
const copies: Scene = {
	Key = "anm_004_copies",
	Name = "The copies",
	Live = true,
	Steps = {
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 0.35 },
		{ At = 0.5, Phase = "Active", Kind = "Cinema", Value = 0.08, Duration = 1.5 },
		{ At = 2, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.15, Duration = 8 },
		{ At = 2, Phase = "Active", Kind = "Whispers", Target = "copy", Value = 0.3, To = 1, Duration = 8 },
		{ At = 10, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 10, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
		{ At = 10, Phase = "Active", Kind = "Vignette", Value = 0.15, To = 0.06, Duration = 3 },
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0.5, Phase = "Resolved", Kind = "Vignette", Value = 0.15, To = 0, Duration = 1.5 },
		{ At = 1, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Shake", Target = "Jolt" },
		{ At = 0.2, Phase = "Failed", Kind = "Vignette", Value = 0.35, To = 0, Duration = 3 },
		{ At = 2.5, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
		{ At = 2, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.28, Duration = 8 },
		{ At = 10, Phase = "Active", Kind = "Grade", Value = 0.28, To = 0.1, Duration = 3 },
		-- TASK-493: colour and sound come back
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0.4, Phase = "Resolved", Kind = "Grade", Value = 0.4, To = 0, Duration = 2 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		-- TASK-493: the hit on whoever was caught: red, blurred, then back
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.4, To = 0, Duration = 2.5 },
	},
}

-- ANM-006 The stalker, "don't look" (TASK-490; DEC-260; design/horror-cinematic.md §6.5). Fitted to Anomalies/ANM-006:
-- Signal = it stands outside and only comes closer while someone stares (up to AutoOff 28 s), Active = it reached the
-- window (LeapDelay 1 s: the last chance to close it), then Failed (it leapt in: jumpscare + faint of the nearest) or
-- Resolved (window closed: it bangs and goes; or nobody looked: it fades). The words are the two hints: don't look, and
-- close the window when it is there.
const stalker: Scene = {
	Key = "anm_006_stalker",
	Name = "The stalker",
	Live = true,
	Steps = {
		{ At = 0, Phase = "Signal", Kind = "Sound", Target = "horror_sting", Value = 0.4 },
		{ At = 0.3, Phase = "Signal", Kind = "Cinema", Value = 0.09, Duration = 1.5 },
		{ At = 1, Phase = "Signal", Kind = "Whispers", Target = "stalker", Value = 0.3, To = 1.6, Duration = 12 },
		{ At = 1, Phase = "Signal", Kind = "Heartbeat", Value = 60, To = 100, Duration = 20 },
		{ At = 1, Phase = "Signal", Kind = "Vignette", Value = 0, To = 0.25, Duration = 20 },
		{ At = 13, Phase = "Signal", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		-- at the window: one second to shut it
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -3, To = 0, Duration = 0.6 },
		{ At = 0, Phase = "Active", Kind = "Heartbeat", Value = 160, To = 160, Duration = 1 },
		{ At = 0, Phase = "Active", Kind = "Whispers", Target = "stalker_window", Value = 3, To = 3, Duration = 1 },
		{ At = 0, Phase = "Active", Kind = "Vignette", Value = 0.25, To = 0.45, Duration = 0.6 },
		-- gone (Resolved)
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.3, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
		{ At = 0.5, Phase = "Resolved", Kind = "Vignette", Value = 0.3, To = 0, Duration = 1.5 },
		{ At = 1, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },
		-- it leapt in (Failed)
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Heartbeat", Value = 150, To = 80, Duration = 3 },
		{ At = 3, Phase = "Failed", Who = "Safe", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.8, Phase = "Failed", Kind = "Vignette", Value = 0.45, To = 0, Duration = 2.5 },
		{ At = 3, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
		-- TASK-493: drained, cold street; at the glass the room goes silent for a breath, then the hit
		{ At = 1, Phase = "Signal", Kind = "Grade", Target = "Cold", Value = 0, To = 0.45, Duration = 20 },
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 1, To = 0.05, Duration = 0.25 },
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 1 },
		{ At = 0, Phase = "Active", Kind = "Blur", Value = 6, To = 1.5, Duration = 0.8 },
		{ At = 0, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0.45, To = 0.7, Duration = 0.6 },
		-- TASK-493: colour and sound come back
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0.4, Phase = "Resolved", Kind = "Grade", Value = 0.4, To = 0, Duration = 2 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		-- TASK-493: the hit on whoever was caught: red, blurred, then back
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.4, To = 0, Duration = 2.5 },
	},
}

-- ANM-008 The long car (TASK-490; DEC-279 "to the drive-thru"; design/horror-cinematic.md §6.6). Fitted to Rules/ANM-008:
-- Signal = it rolls down the lane (5.6 s), floors it (1.8 s), brakes at the window (8.2 s) and waits 2.5 s; Active = the
-- high beam (whoever is not behind a closed window pays); StayFor 6 s with the beam on; then Failed / Resolved as it
-- backs out. The car, beam, horn and engine are Effects/ANM-008; the scene adds the words (close the window), the heart
-- racing with the engine, the jolt of the brake and the silence before the beam.
const longCar: Scene = {
	Key = "anm_008_long_car",
	Name = "The long car",
	Live = true,
	Steps = {
		{ At = 0.5, Phase = "Signal", Kind = "Cinema", Value = 0.1, Duration = 1.5 },
		{ At = 0.5, Phase = "Signal", Kind = "Whispers", Target = "car", Value = 0.3, To = 2.6, Duration = 8 },
		{ At = 0.5, Phase = "Signal", Kind = "Heartbeat", Value = 70, To = 150, Duration = 8 },
		{ At = 0.5, Phase = "Signal", Kind = "Vignette", Value = 0, To = 0.35, Duration = 8 },
		{ At = 5.6, Phase = "Signal", Kind = "Fov", Value = 2, To = 0, Duration = 1.8 },
		-- it brakes in front of the window: jolt, then nothing but the engine
		{ At = 8.2, Phase = "Signal", Kind = "Shake", Target = "Jolt" },
		{ At = 8.4, Phase = "Signal", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 8.6, Phase = "Signal", Kind = "Sound", Target = "breath_held" },
		{ At = 8.6, Phase = "Signal", Kind = "Heartbeat", Value = 155, To = 165, Duration = 2 },
		-- the high beam
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -4, To = 0, Duration = 0.7 },
		{ At = 0, Phase = "Active", Kind = "Vignette", Value = 0.35, To = 0.5, Duration = 0.4 },
		{ At = 0.4, Phase = "Active", Kind = "Heartbeat", Value = 150, To = 100, Duration = 5.5 },
		{ At = 0.6, Phase = "Active", Kind = "Whispers", Target = "car_hold", Value = 0.5, To = 0.5, Duration = 5 },
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.5, Phase = "Resolved", Kind = "Vignette", Value = 0.5, To = 0, Duration = 2 },
		{ At = 1.5, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.5, Phase = "Failed", Kind = "Vignette", Value = 0.5, To = 0, Duration = 2.5 },
		{ At = 2.5, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
		-- TASK-493: colour drains as it comes; parked, everything but the engine goes silent; the beam blinds
		{ At = 0.5, Phase = "Signal", Kind = "Grade", Target = "Cold", Value = 0, To = 0.4, Duration = 8 },
		{ At = 8.4, Phase = "Signal", Kind = "Silence", Value = 1, To = 0.08, Duration = 0.6 },
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 0.08, To = 1, Duration = 0.3 },
		{ At = 0, Phase = "Active", Kind = "Blur", Value = 12, To = 1, Duration = 1.2 },
		{ At = 0, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0.85, To = 0.45, Duration = 2 },
		{ At = 1.2, Phase = "Active", Kind = "Blur", Value = 1, To = 0, Duration = 4 },
		-- TASK-493: colour and sound come back
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0.4, Phase = "Resolved", Kind = "Grade", Value = 0.4, To = 0, Duration = 2 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		-- TASK-493: the hit on whoever was caught: red, blurred, then back
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.4, To = 0, Duration = 2.5 },
	},
}

-- ANM-010 The Hush (TASK-490; design/horror-cinematic.md §6.7). Fitted to Rules/ANM-010: Active from the start (the lamps
-- outside go out one by one, the corner one at PostsOff 15 s), the hold until the posts come back (HoldFor 20 s), then
-- Resolved / Failed. Restaurant: the answer is the shop light off and kept off; trailer: run to the Mart. The words say
-- which (Words.hush_shop / Words.hush). After the corner post: silence, a slow heart.
const hush: Scene = {
	Key = "anm_010_hush",
	Name = "The Hush",
	Live = true,
	Steps = {
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "horror_sting", Value = 0.4 },
		{ At = 0.5, Phase = "Active", Kind = "Cinema", Value = 0.09, Duration = 1.5 },
		{ At = 1, Phase = "Active", Kind = "Whispers", Target = if Restaurant.Rules.Enabled then "hush_shop" else "hush", Value = 0.4, To = 2.2, Duration = 13 },
		{ At = 1, Phase = "Active", Kind = "Heartbeat", Value = 60, To = 130, Duration = 14 },
		{ At = 1, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.3, Duration = 14 },
		-- the corner post: the street is gone; hold still in the dark
		{ At = 15, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 15, Phase = "Active", Kind = "Shake", Target = "Step" },
		{ At = 15.3, Phase = "Active", Kind = "Sound", Target = "breath_held" },
		{ At = 15.3, Phase = "Active", Kind = "Heartbeat", Value = 120, To = 80, Duration = 18 },
		{ At = 25, Phase = "Active", Kind = "Whispers", Target = if Restaurant.Rules.Enabled then "hush_shop_hold" else "hush_hold", Value = 0.2, To = 0.2, Duration = 6 },
		{ At = 36, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
		{ At = 36, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.3, Phase = "Resolved", Kind = "Sound", Target = "lamps_cascade" },
		{ At = 0.5, Phase = "Resolved", Kind = "Vignette", Value = 0.3, To = 0, Duration = 2 },
		{ At = 1, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.5, Phase = "Failed", Kind = "Vignette", Value = 0.4, To = 0, Duration = 2.5 },
		{ At = 2.5, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
		-- TASK-493: colour drains with every lamp; at the corner post the world goes mute (the Hush), then slowly back
		{ At = 1, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.55, Duration = 14 },
		{ At = 15, Phase = "Active", Kind = "Silence", Value = 1, To = 0.08, Duration = 1.2 },
		{ At = 15, Phase = "Active", Kind = "Blur", Value = 0, To = 2, Duration = 3 },
		{ At = 30, Phase = "Active", Kind = "Silence", Value = 0.08, To = 0.6, Duration = 6 },
		{ At = 30, Phase = "Active", Kind = "Blur", Value = 2, To = 0, Duration = 4 },
		{ At = 36, Phase = "Active", Kind = "Grade", Value = 0.55, To = 0.2, Duration = 4 },
		{ At = 36, Phase = "Active", Kind = "Silence", Value = 0.6, To = 1, Duration = 2 },
		-- TASK-493: colour and sound come back
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0.4, Phase = "Resolved", Kind = "Grade", Value = 0.4, To = 0, Duration = 2 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		-- TASK-493: the hit on whoever was caught: red, blurred, then back
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.4, To = 0, Duration = 2.5 },
	},
}

-- ANM-009 The knock, "it's me, Walt" (owner 2026-10-18; TASK-561; restaurant only: the pantry's exit door DOOR-B is
-- opened by hand, Vehicle/RestaurantDoorService; design/anomalies-v3-restaurant.md §8.3, horror-cinematic.md §2 curve).
-- Fitted to Rules/ANM-009 with the restaurant on: Active 20 s + DoorGrace 2 (Resolved at 22 when nobody opened). The
-- knocks and the voice are Effects/ANM-009 (server cues at 0 / 4.5 / 8.5 / 12.5): far and soft, closer and rhythmic,
-- Walt's voice, the voice wrong. The scene builds around them: the room goes quiet, cold and narrow; the words say
-- don't open; after the wrong voice a dead silence (no heart, no words); then the handle, a push, the latch holds;
-- two seconds of nothing. The answer is the simplest thing - do nothing - and the scene makes it hard.
-- Opened (Failed): the face (Effects/ANM-009 jumpscare) with a white-out blur, red, a lunge of the view and the sting
-- for who opened; the others hear the door bang and the sting from the pantry. Ignored (Resolved): one last soft
-- knock, the steps walk away, the room and the colour come back, a breath out.
const knock: Scene = {
	Key = "anm_009_knock",
	Name = "The knock",
	Live = Restaurant.Rules.Enabled,
	Steps = {
		-- 0 s, first series far and soft: the room starts to hush, bars close in
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 1, To = 0.55, Duration = 2 },
		{ At = 0.5, Phase = "Active", Kind = "Cinema", Value = 0.1, Duration = 1.5 },
		{ At = 0.5, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.6, Duration = 16 },
		{ At = 1, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.3, Duration = 13 },
		-- 4.5 s, second series closer: the heart starts, a few words
		{ At = 4.5, Phase = "Active", Kind = "Heartbeat", Value = 64, To = 128, Duration = 11 },
		{ At = 5, Phase = "Active", Kind = "Whispers", Target = "knock", Value = 0.3, To = 1.6, Duration = 8 },
		{ At = 5, Phase = "Active", Kind = "Silence", Value = 0.55, To = 0.3, Duration = 3 },
		-- 8.5 s, Walt's voice: a small push of the view towards the door
		{ At = 8.5, Phase = "Active", Kind = "Nudge", Value = 3, Point = "SCENE-DOOR", Duration = 0.8 },
		{ At = 8.5, Phase = "Active", Kind = "Fov", Value = -2, To = 0, Duration = 4 },
		-- 12.5 s, the voice wrong: the words en masse, a blur that breathes
		{ At = 12.5, Phase = "Active", Kind = "Whispers", Target = "knock", Value = 2.4, To = 3, Duration = 2 },
		{ At = 12.5, Phase = "Active", Kind = "Blur", Value = 0, To = 2.5, Duration = 2 },
		{ At = 12.5, Phase = "Active", Kind = "Vignette", Value = 0.3, To = 0.42, Duration = 2 },
		-- 14.6 s, silence before the peak: no words, no heart, the world muted; only a held breath
		{ At = 14.6, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 14.6, Phase = "Active", Kind = "Silence", Value = 0.3, To = 0.02, Duration = 0.6 },
		{ At = 14.6, Phase = "Active", Kind = "Blur", Value = 2.5, To = 0, Duration = 1.5 },
		{ At = 15.4, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 15.6, Phase = "Active", Kind = "Sound", Target = "breath_held" },
		-- 17 s, it tries the handle; 18.3 s it pushes, hard; 19.3 s the latch holds
		{ At = 17, Phase = "Active", Kind = "Door", Target = "Rattle", Point = "SCENE-DOOR", Duration = 0.9 },
		{ At = 17, Phase = "Active", Kind = "Sound", Target = "handle_rattle", Point = "SCENE-DOOR" },
		{ At = 17, Phase = "Active", Kind = "Shake", Target = "Door", Point = "SCENE-DOOR" },
		{ At = 18.3, Phase = "Active", Kind = "Door", Target = "Push", Point = "SCENE-DOOR", Duration = 0.6 },
		{ At = 18.3, Phase = "Active", Kind = "Sound", Target = "door_force", Point = "SCENE-DOOR", Value = 1.3 },
		{ At = 18.3, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 18.3, Phase = "Active", Kind = "Blur", Value = 4, To = 0, Duration = 0.8 },
		{ At = 18.3, Phase = "Active", Kind = "Vignette", Value = 0.42, To = 0.5, Duration = 1 },
		{ At = 19.3, Phase = "Active", Kind = "Door", Target = "Hold", Point = "SCENE-DOOR", Duration = 0.4 },
		{ At = 19.3, Phase = "Active", Kind = "Sound", Target = "latch_hold", Point = "SCENE-DOOR" },
		-- 19.8 s, the grace: the heart comes back slow, nothing else; it is still out there
		{ At = 19.8, Phase = "Active", Kind = "Heartbeat", Value = 120, To = 90, Duration = 2.5 },
		-- nobody opened (Resolved): one last soft knock, the steps go away, the room comes back, a breath out
		{ At = 0, Phase = "Resolved", Kind = "Sound", Target = "door_knock", Point = "SCENE-DOOR-OUT", Value = 0.25 },
		{ At = 0.8, Phase = "Resolved", Kind = "Sound", Target = "walker_step", Point = "SCENE-DOOR-OUT", To = "SCENE-STEPS-FAR", Duration = 4 },
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 1, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 1.5, Phase = "Resolved", Kind = "Silence", Value = 0.05, To = 1, Duration = 3 },
		{ At = 2, Phase = "Resolved", Kind = "Sound", Target = "breath_held", Value = 0.6 },
		{ At = 2, Phase = "Resolved", Kind = "Grade", Value = 0.6, To = 0, Duration = 3 },
		{ At = 2, Phase = "Resolved", Kind = "Vignette", Value = 0.5, To = 0, Duration = 3 },
		{ At = 2.5, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1.2 },
		-- someone opened it (Failed): the climax for who opened, the bang for the others
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Sound", Target = "horror_sting", Value = 2.5 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 20, To = 0, Duration = 1.6 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 1, To = 0, Duration = 3.2 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Fov", Value = -6, To = 0, Duration = 1.2 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Shake", Target = "Jolt", Value = 1.5 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Vignette", Value = 0.55, To = 0, Duration = 3.5 },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Sound", Target = "door_force", Point = "SCENE-DOOR", Value = 1.4 },
		{ At = 0.1, Phase = "Failed", Who = "Safe", Kind = "Sound", Target = "horror_sting", Value = 0.8 },
		{ At = 0.1, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Door", Point = "SCENE-DOOR" },
		{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Blur", Value = 0, To = 0, Duration = 0 },
		{ At = 1, Phase = "Failed", Who = "Safe", Kind = "Vignette", Value = 0.5, To = 0, Duration = 3 },
		{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.6, To = 0, Duration = 2.5 },
		{ At = 3, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

-- ANM-021 The red fog (owner 2026-10-18). Fitted to Rules/ANM-021: Signal = OmenFor 12 s (the fog rises red over the
-- street, Effects/ANM-021; the bell tolls; everything turns red; the words say shut the window), Active = BangFor 14 s
-- (it reaches the glass: heavy blows on the windows in cutscene look, the heart racing, a silence between the blows,
-- the biggest one last), then Resolved / Failed (Linger 5 s, the fog recedes).
const redFog: Scene = {
	Key = "anm_021_red_fog",
	Name = "The red fog",
	Live = true,
	Steps = {
		-- the bell, three times, the colour bleeding red
		{ At = 0, Phase = "Signal", Kind = "Sound", Target = "church_bell" },
		{ At = 0, Phase = "Signal", Kind = "Grade", Target = "Red", Value = 0, To = 0.55, Duration = 11 },
		{ At = 0.3, Phase = "Signal", Kind = "Cinema", Value = 0.1, Duration = 1.5 },
		{ At = 1, Phase = "Signal", Kind = "Whispers", Target = "red_fog", Value = 0.4, To = 2.4, Duration = 10 },
		{ At = 1, Phase = "Signal", Kind = "Heartbeat", Value = 70, To = 145, Duration = 11 },
		{ At = 1, Phase = "Signal", Kind = "Vignette", Value = 0, To = 0.35, Duration = 11 },
		{ At = 4, Phase = "Signal", Kind = "Sound", Target = "church_bell", Value = 0.9 },
		{ At = 8, Phase = "Signal", Kind = "Sound", Target = "church_bell", Value = 1.1 },
		{ At = 8, Phase = "Signal", Kind = "Silence", Value = 1, To = 0.4, Duration = 3 },
		{ At = 11, Phase = "Signal", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 11.2, Phase = "Signal", Kind = "Silence", Value = 0.4, To = 0.03, Duration = 0.5 },
		{ At = 11.4, Phase = "Signal", Kind = "Sound", Target = "breath_held" },
		-- it reaches the glass: blows, a pause, blows, the last and biggest
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 0.03, To = 0.6, Duration = 0.2 },
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "window_slam", Point = "SCENE-WINDOW-EYES", Value = 1.3 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Door", Value = 1.6 },
		{ At = 0, Phase = "Active", Kind = "Blur", Value = 6, To = 0, Duration = 0.8 },
		{ At = 0, Phase = "Active", Kind = "Grade", Target = "Red", Value = 0.75, To = 0.6, Duration = 1 },
		{ At = 0.6, Phase = "Active", Kind = "Sound", Target = "window_slam", Point = "SCENE-WINDOW-EYES" },
		{ At = 0.6, Phase = "Active", Kind = "Shake", Target = "Door" },
		{ At = 1.3, Phase = "Active", Kind = "Sound", Target = "window_slam", Point = "SCENE-WINDOW-EYES", Value = 1.1 },
		{ At = 1.3, Phase = "Active", Kind = "Shake", Target = "Door", Value = 1.2 },
		{ At = 1.5, Phase = "Active", Kind = "Whispers", Target = "red_fog_hold", Value = 1.2, To = 2.6, Duration = 4 },
		{ At = 1.5, Phase = "Active", Kind = "Heartbeat", Value = 150, To = 170, Duration = 4 },
		{ At = 5.5, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 5.6, Phase = "Active", Kind = "Silence", Value = 0.6, To = 0.05, Duration = 0.4 },
		{ At = 6, Phase = "Active", Kind = "Heartbeat", Value = 120, To = 120, Duration = 1 },
		{ At = 8.5, Phase = "Active", Kind = "Silence", Value = 0.05, To = 0.6, Duration = 0.1 },
		{ At = 8.5, Phase = "Active", Kind = "Sound", Target = "window_slam", Point = "SCENE-WINDOW-EYES", Value = 1.5 },
		{ At = 8.5, Phase = "Active", Kind = "Shake", Target = "Jolt", Value = 1.5 },
		{ At = 8.5, Phase = "Active", Kind = "Fov", Value = -5, To = 0, Duration = 0.8 },
		{ At = 8.5, Phase = "Active", Kind = "Blur", Value = 10, To = 0, Duration = 1 },
		{ At = 8.6, Phase = "Active", Kind = "Heartbeat", Value = 170, To = 170, Duration = 2 },
		{ At = 9, Phase = "Active", Kind = "Sound", Target = "window_slam", Point = "SCENE-WINDOW-EYES", Value = 1.2 },
		{ At = 9, Phase = "Active", Kind = "Shake", Target = "Door", Value = 1.4 },
		{ At = 9.4, Phase = "Active", Kind = "Sound", Target = "window_slam", Point = "SCENE-WINDOW-EYES", Value = 1.2 },
		{ At = 9.5, Phase = "Active", Kind = "Whispers", Target = "red_fog_hold", Value = 3, To = 3, Duration = 2 },
		{ At = 11.5, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 11.5, Phase = "Active", Kind = "Heartbeat", Value = 150, To = 100, Duration = 3 },
		-- it held (Resolved): the fog recedes, colour and sound come back
		{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Resolved", Kind = "Silence", Value = 0.6, To = 1, Duration = 3 },
		{ At = 0.5, Phase = "Resolved", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.5, Phase = "Resolved", Kind = "Grade", Value = 0.6, To = 0, Duration = 4 },
		{ At = 0.5, Phase = "Resolved", Kind = "Vignette", Value = 0.35, To = 0, Duration = 3 },
		{ At = 1.5, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1.2 },
		-- someone opened / was outside (Failed)
		{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Failed", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 14, To = 0, Duration = 1.4 },
		{ At = 0, Phase = "Failed", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 1, Phase = "Failed", Kind = "Grade", Value = 0.8, To = 0, Duration = 4 },
		{ At = 1, Phase = "Failed", Kind = "Vignette", Value = 0.5, To = 0, Duration = 3 },
		{ At = 3, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

-- Odd customers (family A and the copy's cousins; TASK-491; design/horror-cinematic.md §6.8). One shape for every
-- customer anomaly anchored to the actor's record (Kit/CustomerActor: Active = it spawned and walks to the counter,
-- Resolved = refused / handled, Failed = the wrong verb: jumpscare + faint of who did it). Short and quiet, like the
-- turned neck: a low sting when it arrives, thin bars, the edges closing a little, the hint words for the first
-- seconds (before the stare pressure of the starable ones can start), the bars gone at 16 s so the work goes on.
-- `words` = key of Words for its hints; `sting` = the arrival sound (Content.Sounds key).
local function oddScene(key: string, name: string, words: string, sting: string?): Scene
	return {
		Key = key,
		Name = name,
		Live = true,
		Steps = {
			{ At = 0, Phase = "Active", Kind = "Sound", Target = sting or "horror_sting", Value = 0.3 },
			{ At = 1, Phase = "Active", Kind = "Cinema", Value = 0.08, Duration = 1.5 },
			{ At = 2, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.16, Duration = 8 },
			{ At = 2.5, Phase = "Active", Kind = "Whispers", Target = words, Value = 0.3, To = 1, Duration = 7 },
			{ At = 9.5, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
			{ At = 9.5, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
			{ At = 9.5, Phase = "Active", Kind = "Vignette", Value = 0.16, To = 0.06, Duration = 3 },
			{ At = 0, Phase = "Resolved", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
			{ At = 0.8, Phase = "Resolved", Kind = "Sound", Target = "breath_held" },
			{ At = 0.5, Phase = "Resolved", Kind = "Vignette", Value = 0.16, To = 0, Duration = 1.5 },
			{ At = 1, Phase = "Resolved", Kind = "Cinema", Value = 0, Duration = 1 },
			{ At = 0, Phase = "Failed", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
			{ At = 0, Phase = "Failed", Who = "Safe", Kind = "Shake", Target = "Jolt" },
			{ At = 0.8, Phase = "Failed", Kind = "Vignette", Value = 0.4, To = 0, Duration = 3 },
			{ At = 2, Phase = "Failed", Kind = "Cinema", Value = 0, Duration = 1 },
			-- TASK-493: drained colour while it waits; the hit on whoever took its order
			{ At = 2, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.25, Duration = 8 },
			{ At = 9.5, Phase = "Active", Kind = "Grade", Value = 0.25, To = 0.08, Duration = 3 },
			{ At = 0.4, Phase = "Resolved", Kind = "Grade", Value = 0.25, To = 0, Duration = 2 },
			{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Grade", Target = "Red", Value = 0.85, To = 0, Duration = 2.8 },
			{ At = 0, Phase = "Failed", Who = "Caught", Kind = "Blur", Value = 12, To = 0, Duration = 1.4 },
			{ At = 1.5, Phase = "Failed", Who = "Safe", Kind = "Grade", Value = 0.25, To = 0, Duration = 2 },
		},
	}
end

const oddScenes: { Scene } = {
	oddScene("anm_001_blank_folks", "The blank folks", "blank"),
	oddScene("anm_005_raincoat_lady", "The Raincoat Lady", "raincoat"),
	oddScene("anm_011_shaker", "The shaker", "shaker"),
	oddScene("anm_013_white_eyes", "The white eyes", "white_eyes"),
	oddScene("anm_014_big_head", "The big head", "big_head"),
	oddScene("anm_015_floater", "The floater", "floater"),
	oddScene("anm_016_starer", "The starer", "starer"),
}

-- Outside the shop at night (owner 2026-10-18; server Anomaly/OutsideService, client OutsideController). Personal: only
-- the player outside sees it. Rise = 30 s of rising dread (words few then en masse, bars, "glaucoma" edges, heart, the
-- colour draining, a hush at the end); Chase = the bell and the runner on him, the words turn to the chase; Escape = he
-- got inside; Caught = the hit. Step.At is s since that stage began (Phase is unused here: "Active").
export type OutsideScene = { Rise: { Step }, Chase: { Step }, Escape: { Step }, Caught: { Step } }

const outside: OutsideScene = {
	Rise = {
		{ At = 0, Phase = "Active", Kind = "Whispers", Target = "outside", Value = 0.2, To = 3, Duration = 29 },
		{ At = 0, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.5, Duration = 30 },
		{ At = 0, Phase = "Active", Kind = "Heartbeat", Value = 60, To = 155, Duration = 30 },
		{ At = 2, Phase = "Active", Kind = "Cinema", Value = 0.1, Duration = 3 },
		{ At = 2, Phase = "Active", Kind = "Grade", Target = "Cold", Value = 0, To = 0.55, Duration = 28 },
		{ At = 25, Phase = "Active", Kind = "Silence", Value = 1, To = 0.15, Duration = 4 },
		{ At = 28.5, Phase = "Active", Kind = "Sound", Target = "breath_held" },
	},
	-- owner 2026-10-18: during the chase no whispers, only a rare red RUN / HIDE; the edges pulse instead of closing in
	-- (he must see where he runs); a touch brighter, the night's blue kept (Grade Lift)
	Chase = {
		{ At = 0, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 0.15, To = 1, Duration = 0.2 },
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "church_bell", Value = 1.2 },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -4, To = 0, Duration = 0.8 },
		{ At = 0, Phase = "Active", Kind = "Blur", Value = 8, To = 0, Duration = 1 },
		{ At = 0, Phase = "Active", Kind = "Grade", Target = "Lift", Value = 0, To = 0.7, Duration = 1.2 },
		{ At = 0, Phase = "Active", Kind = "Heartbeat", Value = 165, To = 175, Duration = 20 },
		{ At = 1.5, Phase = "Active", Kind = "Whispers", Target = "chase", Text = "Red", Value = 0.12, To = 0.12, Duration = 120 },
	},
	Escape = {
		{ At = 0, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0.3, Phase = "Active", Kind = "Sound", Target = "breath_held" },
		{ At = 0, Phase = "Active", Kind = "Heartbeat", Value = 140, To = 80, Duration = 4 },
		{ At = 4, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0.5, Phase = "Active", Kind = "Grade", Value = 0.6, To = 0, Duration = 3 },
		{ At = 0.5, Phase = "Active", Kind = "Vignette", Value = 0.5, To = 0, Duration = 3 },
		{ At = 1.5, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.2 },
	},
	Caught = {
		{ At = 0, Phase = "Active", Kind = "Whispers", Value = 0, To = 0, Duration = 0 },
		{ At = 0, Phase = "Active", Kind = "Silence", Value = 1, To = 1, Duration = 0 },
		{ At = 0, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		{ At = 0, Phase = "Active", Kind = "Grade", Target = "Red", Value = 0.9, To = 0, Duration = 3 },
		{ At = 0, Phase = "Active", Kind = "Blur", Value = 14, To = 0, Duration = 1.4 },
		{ At = 1, Phase = "Active", Kind = "Vignette", Value = 0.5, To = 0, Duration = 2.5 },
		{ At = 2.5, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1 },
	},
}

-- the chase's pulsing edges: 0.5 <-> 0.18 every 0.7 s for two minutes (generated, not typed)
do
	local t = 0
	while t < 120 do
		const close: Step = { At = t, Phase = "Active", Kind = "Vignette", Value = 0.5, To = 0.18, Duration = 0.35 }
		const open: Step = { At = t + 0.35, Phase = "Active", Kind = "Vignette", Value = 0.18, To = 0.5, Duration = 0.35 }
		table.insert(outside.Chase, close)
		table.insert(outside.Chase, open)
		t += 0.7
	end
end

-- Whisper word lists (DEC-293, owner 2026-10-18): the words on screen are real hints for the player, said in the
-- character's voice. blackout / roof / crawler / neck / copy = the scenes' Whispers steps (TASK-484, TASK-483); low_sanity = VitalController while sanity is in the low band;
-- suspense = after a suspense event's glance (SuspenseController, TASK-481).
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
	-- TASK-482 stare pressure (DEC-294 §8): staring at an odd customer
	stare = {
		"STOP STARING",
		"STOP STARING",
		"DON'T LOOK",
		"DON'T LOOK",
		"LOOK AWAY",
		"don't look...",
		"it knows",
		"it sees you looking",
	},
	stare_copy = {
		"DON'T LOOK AT IT",
		"DON'T LOOK AT IT",
		"STOP STARING",
		"LOOK AWAY",
		"that's not them",
		"don't look...",
	},
	roof = {
		"DON'T LOOK UP",
		"DON'T LOOK UP",
		"DON'T LOOK UP",
		"KEEP YOUR HEAD DOWN",
		"KEEP YOUR HEAD DOWN",
		"IT'S ON THE ROOF",
		"IT'S ON THE ROOF",
		"eyes down...",
		"it's right above you",
		"don't look...",
	},
	-- TASK-483: the crawler (restaurant: get off the floor), the turned neck and the copy (refuse them)
	crawler = {
		"GET OFF THE FLOOR",
		"GET OFF THE FLOOR",
		"CLIMB ON THE COUNTER",
		"CLIMB ON THE COUNTER",
		"UP! GET UP!",
		"IT'S UNDER THE FLOOR",
		"don't touch the floor",
		"stay up...",
	},
	neck = {
		"DON'T TAKE HER ORDER",
		"DON'T TAKE HER ORDER",
		"SEND HER AWAY",
		"REFUSE HER",
		"her neck...",
		"it's turned all the way round",
		"don't look at her",
	},
	copy = {
		"THAT'S NOT THEM",
		"THEY ALREADY LEFT",
		"THEY ALREADY LEFT",
		"IT'S A COPY",
		"DON'T TAKE ITS ORDER",
		"SEND IT AWAY",
		"it's backwards...",
	},
	-- TASK-490: the stalker, the long car, the Hush
	stalker = {
		"DON'T LOOK AT IT",
		"DON'T LOOK AT IT",
		"IT MOVES WHEN YOU LOOK",
		"IT MOVES WHEN YOU LOOK",
		"LOOK AWAY",
		"don't look outside",
		"it's closer...",
	},
	stalker_window = {
		"CLOSE THE WINDOW!",
		"CLOSE THE WINDOW!",
		"SHUT IT!",
	},
	car = {
		"CLOSE THE WINDOW",
		"CLOSE THE WINDOW",
		"SHUT THE DRIVE-THRU",
		"DON'T LET IT SEE YOU",
		"it's coming fast",
		"that car is too long...",
	},
	car_hold = {
		"KEEP IT SHUT",
		"don't open it",
		"wait for it to leave",
	},
	hush = {
		"RUN TO THE MART",
		"RUN TO THE MART",
		"THE LIGHTS ARE DYING",
		"GET INSIDE",
		"hurry...",
	},
	hush_hold = {
		"stay inside",
		"don't go out",
	},
	hush_shop = {
		"TURN OFF THE LIGHTS",
		"TURN OFF THE LIGHTS",
		"KILL THE LIGHTS",
		"THE LAMPS ARE DYING",
		"it can see the light...",
		"the switch!",
	},
	hush_shop_hold = {
		"keep them off",
		"don't touch the switch",
	},
	-- TASK-491: odd customers. Refuse them (the Raincoat Lady is the exception: serve her fast)
	blank = {
		"IT HAS NO FACE",
		"DON'T TAKE ITS ORDER",
		"SEND IT AWAY",
		"where is its face?",
	},
	raincoat = {
		"SERVE HER FAST",
		"SERVE HER FAST",
		"DON'T CLOSE THE WINDOW",
		"it isn't raining...",
		"she's dripping",
	},
	shaker = {
		"WHY IS IT SHAKING?",
		"DON'T TAKE ITS ORDER",
		"SEND IT AWAY",
		"it can't stop...",
	},
	white_eyes = {
		"LOOK AT ITS EYES",
		"DON'T TAKE ITS ORDER",
		"SEND IT AWAY",
		"those aren't eyes...",
	},
	big_head = {
		"ITS HEAD IS WRONG",
		"DON'T TAKE ITS ORDER",
		"SEND IT AWAY",
		"too big...",
	},
	floater = {
		"LOOK AT ITS FEET",
		"DON'T TAKE ITS ORDER",
		"SEND IT AWAY",
		"it isn't touching the ground",
	},
	starer = {
		"IT NEVER BLINKS",
		"DON'T TAKE ITS ORDER",
		"SEND IT AWAY",
		"it's watching you",
	},
	-- owner 2026-10-18: Walt knocking (real hints: do not open, Walt has a key)
	knock = {
		"DON'T OPEN THE DOOR",
		"DON'T OPEN THE DOOR",
		"THAT'S NOT WALT",
		"WALT HAS A KEY",
		"stay quiet...",
		"don't answer",
	},
	-- ANM-021 the red fog: shut the window, keep it shut
	red_fog = {
		"CLOSE THE WINDOW",
		"CLOSE THE WINDOW",
		"SHUT IT NOW",
		"THE FOG IS COMING",
		"don't let it in",
		"the bell...",
	},
	red_fog_hold = {
		"KEEP IT SHUT",
		"KEEP IT SHUT",
		"DON'T OPEN IT",
		"STAY INSIDE",
		"it wants in",
	},
	-- outside the shop at night (OutsideController): get back in, then the chase
	outside = {
		"GET INSIDE",
		"GET INSIDE",
		"GO BACK",
		"IT'S NOT SAFE OUT HERE",
		"you're too far",
		"something is coming",
		"it can smell you",
		"back inside...",
	},
	chase = {
		"RUN",
		"HIDE",
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
	suspense = {
		"WHAT WAS THAT?",
		"WHAT WAS THAT?",
		"DON'T TURN AROUND",
		"DID YOU SEE IT?",
		"it's gone...",
		"keep working",
	},
}

const rules: Rules = {
	Latency = 0.15,
	ReduceMotion = 0.25,
	MaxControlLock = 2,
	MaxVignette = 0.6,
	MaxFov = 6,
	MaxNudge = 3,
	MaxPull = 30, -- TASK-481 (DEC-294), Provisional
	MaxBlur = 18, -- TASK-493, Provisional (readable through it)
	Shakes = {
		Jolt = { Amplitude = 0.12, Frequency = 18, Duration = 0.15 },
		Step = { Amplitude = 0.03, Frequency = 10, Duration = 0.12 },
		Door = { Amplitude = 0.08, Frequency = 22, Duration = 0.35 },
	},
}

-- TASK-482 (Provisional until the owner's Play; mild, DEC-172)
const stare: Stare = {
	Build = 6,
	HeartFrom = 72,
	HeartTo = 140,
	Vignette = 0.42,
	Flicker = 0.08,
	HeadSpeed = 28,
	HeadMax = 150,
	HeadTilt = 28, -- owner 2026-10-18: the customer at the window "did not move" while stared at
	FaceStretch = 0.14,
	FaceRoll = 9,
	WhisperFrom = 0.15,
	WhisperTo = 0.9,
	Words = {
		anm_004_copies = "stare_copy",
	},
}

const scenes: { Scene } = { blackout, roofWalker, crawler, turnedNeck, copies, stalker, longCar, hush, knock, redFog }
for _, scene in oddScenes do
	table.insert(scenes, scene)
end

return Table.with(Table.new(scenes), {
	Rules = Table.record(rules),
	Stare = Table.record(stare),
	Outside = Table.record(outside),
	Words = Table.record(words),
	PhaseOrder = table.freeze({ Signal = 1, Active = 2, Resolved = 3, Failed = 3 }),
})
