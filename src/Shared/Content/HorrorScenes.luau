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
--   Whispers   the "HIDE" words on screen (Effects/Kit/Whispers), ramping: Value = rate at the start, To = rate at the
--              end (1 = Kit default), over Duration (owner DEC-291: "few HIDE at first, then en masse")
--   Vignette   screen darkening: Value -> To over Duration (0..Rules.MaxVignette)
--   Shake      camera shake: Target = profile key of Rules.Shakes, Value = scale (default 1)
--   Fov        field of view delta: Value degrees (|Value| <= Rules.MaxFov), To = 0 to come back, over Duration
--   Nudge      the view is pulled at most Value degrees towards Point (<= Rules.MaxNudge); never locks input
--   Text       on-screen warning Text (English placeholder until ui-text.md), held Duration s (DEC-283)
--   Actor      client-only actor at Point: Target = model name under ReplicatedStorage.Assets (or the anomaly's own
--              placeholder); To = MapPoint it walks to over Duration
--   Door       the hiding door: Target "Rattle" | "Push" | "Hold"; Point = door MapPoint; Duration
--   Shadow     a shadow crosses the light under the door: Point = door MapPoint, Duration
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
}

export type Scene = {
	Key: string, -- = Content.Anomalies key
	Name: string, -- English, dev/log only
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

-- ANM-020 blackout, the owner's reference scene (DEC-290; design/horror-cinematic.md §2). Sound bank of TASK-466
-- (sound-list.md §5.19): breaker clunk, hum, steps stopping, handle rattle, door forced, latch, held breath, power-up and
-- lamp cascade. The approaching steps stay on walker_step until heavy_steps has an Id. TASK-467 tunes it in Play.
const blackout: Scene = {
	Key = "anm_020_blackout",
	Name = "The blackout",
	Steps = {
		-- omen (Signal): the kitchen lights flicker once or twice
		{ At = 0, Phase = "Signal", Kind = "Lights", Target = "Flicker", Duration = 1.2 },
		{ At = 0, Phase = "Signal", Kind = "Sound", Target = "hum_rise" },
		-- t = 0: everything goes dark with the breaker sound, a jolt and the bell
		{ At = 0, Phase = "Active", Kind = "Lights", Target = "Off", Duration = 0 },
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "power_cut" },
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "hum_die" },
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "lights_off" },
		{ At = 0, Phase = "Active", Kind = "Shake", Target = "Jolt" },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = -3, To = 0, Duration = 0.8 },
		{ At = 1.5, Phase = "Active", Kind = "Sound", Target = "church_bell" },
		{ At = 1.5, Phase = "Active", Kind = "Text", Text = "THE POWER IS OUT. HIDE IN THE PANTRY!", Duration = 4 },
		-- the HIDE words ramp: a few at first, then all over the screen (owner, DEC-291)
		{ At = 3, Phase = "Active", Kind = "Whispers", Value = 0.4, To = 3, Duration = 15 },
		{ At = 3, Phase = "Active", Kind = "Music", Target = "score_violins" },
		{ At = 3, Phase = "Active", Kind = "Vignette", Value = 0, To = 0.35, Duration = 15 },
		-- the steps: the words stop, heavy steps come closer to the pantry door
		{ At = 18, Phase = "Active", Kind = "Music", Target = "Stop" },
		{ At = 18, Phase = "Active", Kind = "Sound", Target = "walker_step", Point = "SCENE-STEPS-FAR", To = "SCENE-DOOR-OUT", Duration = 12 },
		{ At = 18, Phase = "Active", Kind = "Fov", Value = 1, To = 0, Duration = 12 },
		{ At = 22, Phase = "Active", Kind = "Sound", Who = "Safe", Target = "breath_held" },
		{ At = 24, Phase = "Active", Kind = "Shadow", Point = "SCENE-DOOR", Duration = 1.5 },
		-- the steps stop at the door; silence, then the creature tries the door once and cannot open it
		{ At = 30, Phase = "Active", Kind = "Sound", Target = "steps_stop", Point = "SCENE-DOOR-OUT" },
		{ At = 30, Phase = "Active", Kind = "Vignette", Value = 0.35, To = 0.45, Duration = 2 },
		{ At = 32, Phase = "Active", Kind = "Door", Target = "Rattle", Point = "SCENE-DOOR", Duration = 1.2 },
		{ At = 32, Phase = "Active", Kind = "Sound", Target = "handle_rattle", Point = "SCENE-DOOR" },
		{ At = 32, Phase = "Active", Kind = "Shake", Target = "Door", Point = "SCENE-DOOR" },
		{ At = 33.4, Phase = "Active", Kind = "Door", Target = "Push", Point = "SCENE-DOOR", Duration = 0.6 },
		{ At = 33.4, Phase = "Active", Kind = "Sound", Target = "door_force", Point = "SCENE-DOOR" },
		{ At = 34, Phase = "Active", Kind = "Door", Target = "Hold", Point = "SCENE-DOOR", Duration = 0.4 },
		{ At = 34, Phase = "Active", Kind = "Sound", Target = "latch_hold", Point = "SCENE-DOOR" },
		-- it leaves; the choir fades with it (DEC-283)
		{ At = 36, Phase = "Active", Kind = "Music", Target = "score_coral" },
		{ At = 36, Phase = "Active", Kind = "Sound", Target = "walker_step", Point = "SCENE-DOOR-OUT", To = "SCENE-STEPS-FAR", Duration = 8 },
		{ At = 36, Phase = "Active", Kind = "Vignette", Value = 0.45, To = 0, Duration = 6 },
		-- whoever stayed out: the eyes at the window for an instant (Q-356, Provisional), then the rule's own failure
		{ At = 30, Phase = "Active", Kind = "Actor", Who = "Caught", Point = "SCENE-WINDOW-EYES", Duration = 1 },
		-- relief: the power comes back in a cascade
		{ At = 0, Phase = "Resolved", Kind = "Sound", Target = "power_up" },
		{ At = 0.3, Phase = "Resolved", Kind = "Lights", Target = "Cascade", Duration = 1.5 },
		{ At = 0.3, Phase = "Resolved", Kind = "Sound", Target = "lamps_cascade" },
		{ At = 0, Phase = "Resolved", Kind = "Music", Target = "Stop" },
		{ At = 0, Phase = "Resolved", Kind = "Vignette", Value = 0, To = 0, Duration = 0.5 },
		{ At = 0, Phase = "Failed", Kind = "Sound", Target = "power_up" },
		{ At = 0.3, Phase = "Failed", Kind = "Lights", Target = "Cascade", Duration = 1.5 },
		{ At = 0.3, Phase = "Failed", Kind = "Sound", Target = "lamps_cascade" },
		{ At = 0, Phase = "Failed", Kind = "Music", Target = "Stop" },
		{ At = 0, Phase = "Failed", Kind = "Vignette", Value = 0, To = 0, Duration = 0.5 },
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
	PhaseOrder = table.freeze({ Signal = 1, Active = 2, Resolved = 3, Failed = 3 }),
})
