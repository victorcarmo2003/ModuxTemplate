--!strict
-- Types of Content.HorrorScenes (TASK-586): apart from the init so the scene modules of Scenes/ can type their steps
-- without requiring the init that requires them. The step kinds and fields are documented in the init header.

-- "Queue" (owner 2026-10-22): a customer anomaly waiting for its order in the delivery queue (init header)
export type Phase = "Signal" | "Active" | "Queue" | "Resolved" | "Failed"
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
	-- TASK-586 (design/horror-cinematic.md §11.3): the blackout's bar for every anomaly; one module each in
	-- AnomalyController/Scene/Kit, stubs until TASK-587/588/589 plug them in
	| "Pose" -- the anomaly's CustomerActor: Lift | Tilt | Turn | Scale | Float | Blink | Mimic (Target)
	| "Prop" -- local props near Point: Shake | Float | Sway | Puddle | Lift | Drop (Target)
	| "Glass" -- the glass at Point: Fog | Knock | Bang | Hand | Rattle | Paw (Target; Paw = TASK-593, a black paw print)
	| "Glare" -- headlights: Flash | Sweep (Target)
	| "Silhouette" -- a big dark shape crossing outside the windows, Point -> To over Duration (TASK-593: Text names one
	-- of several per run, "*" on a Leave = all of them)
	| "Lantern" -- the blackout's white light as a piece: Glow (around the local player) | Beacon (at Point) | Eyes (on an actor)

-- TASK-586: who is where (§3.0) and which eyes see a step (§11.3)
export type Where = "Inside" | "Outside"
export type Seen = "All" | "Cameras" | "Eyes"

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
	-- Actor / Pose / Prop / Silhouette: who sees it. "Cameras" = only through a security camera (Kit/Watch); "Eyes" = only
	-- with the bare eye (gone on the cameras); nil/"All" = always
	Seen: Seen?,
	-- TASK-586 (§3.0): "Inside" / "Outside" = only for a client inside / outside the shop (OutsideStage); nil = both
	Where: Where?,
}

export type Scene = {
	Key: string, -- = Content.Anomalies key
	Name: string, -- English, dev/log only
	-- true = the client player (TASK-462) plays it in the real game; nil/false = only through `/dev scene <key>`
	-- (kept off while an Effects/ module still does the same job, so no sound or light is doubled; TASK-467 turns the
	-- blackout on)
	Live: boolean?,
	Steps: { Step }, -- any order; the player sorts by phase, then At
	-- TASK-586: word lists of its own (Scenes/ modules), merged into HorrorScenes.Words; a key must not exist already
	Words: { [string]: { string } }?,
	-- TASK-589: a Scenes/ module with Extend = true ADDS its Steps to the scene of the same Key instead of replacing it
	-- (Name and Live of the original stay); for a layer on top of a scene that is already right (Fora, cameras)
	Extend: boolean?,
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

return nil
