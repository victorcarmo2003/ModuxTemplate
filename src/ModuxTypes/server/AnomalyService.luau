--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Api = require(ServerScriptService.server.Anomaly.AnomalyService.Api)
local Scheduler = require(ServerScriptService.server.Anomaly.AnomalyService.Scheduler)
local Pressure = require(ServerScriptService.server.Anomaly.AnomalyService.Pressure)
local Trip = require(ServerScriptService.server.Anomaly.AnomalyService.Trip)
local Director = require(ServerScriptService.server.Anomaly.AnomalyService.Director)
local Behind = require(ServerScriptService.server.Anomaly.AnomalyService.Behind)

export type Occurrence = Api.Occurrence
export type Event = Api.Event
export type Context = Api.Context
export type Module = Api.Module
export type Rule = Api.Rule
export type Entry = Scheduler.Entry
export type Trace = {
	Key: string,
	Day: number,
	Night: number,
	Attempt: number,
	StartedAt: number,
	Party: { number },
	Marks: { [string]: number },
	FailedAt: { [number]: number },
}
export type Run = {
	Occ: Api.Occurrence,
	Row: Content.Anomaly,
	Module: Api.Module,
	Record: Wire,
	Added: boolean,
	Starting: boolean,
	FinishPending: boolean,
	Done: boolean,
	Cues: { { Cue: string, Entity: number, User: number? } },
	Failed: { [number]: boolean },
	CriticalSent: boolean,
	Seen: { [number]: number },
	SeenDone: { [number]: boolean },
	-- TASK-482 stare pressure per UserId (rows with Stare only)
	Stares: { [number]: Stare },
	-- UserIds Active when the occurrence started (Ended, TASK-335)
	Party: { number },
	Trace: Trace,
	-- Started was fired: Staged only follows it
	Announced: boolean,
}
export type Due = { Entry: Scheduler.Entry, RetryAt: number, Done: boolean }
export type Gaze = { Yaw: number, Pitch: number, At: number }
export type Stare = { Time: number, Away: number, Owed: number, Taken: number }
type TrafficHook = { Hold: (self: any, reason: string, on: boolean) -> () }
export type Wire = { Anomaly: string, Phase: Api.Phase, StartedAt: number, Step: number, Anchor: number }

export type Public = {
	Behind: Behind.State,
	Context: Api.Context?,
	DevHeld: boolean,
	DevSerial: number,
	Director: Director.State,
	Enabled: boolean,
	Ended: SignalLib.Signal<string, { Player }>,
	Example: Api.Module?,
	Gazes: { [Player]: Gaze },
	Hold: (() -> boolean)?,
	InNight: boolean,
	LastStartAt: number,
	Live: boolean,
	Modules: { [string]: Api.Module },
	NextId: number,
	NextScareAt: number,
	Opening: string,
	Outcome: SignalLib.Signal<string, string, { Player }, number, string, Trace>,
	Pressure: Pressure.State,
	Queue: { Due },
	Removing: { [number]: number },
	Running: { [number]: Run },
	Scares: { number },
	Security: any,
	Shift: { Day: number, Night: number, IsNight: boolean, Attempt: number },
	Staged: SignalLib.Signal<Trace, string>,
	Started: SignalLib.Signal<string, number, Trace>,
	Tension: SignalLib.Signal<boolean>,
	TensionOn: boolean,
	Traffic: TrafficHook?,
	Trip: Trip.State,
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	LoadModules: (self: Public) -> (),
	IsTension: (self: Public) -> boolean,
	IsRunning: (self: Public, anomaly: string) -> boolean,
	HasModule: (self: Public, anomaly: string) -> boolean,
	GetRule: (self: Public, anomaly: string) -> Api.Rule?,
	ActivePlayers: (self: Public) -> { Player },
	IsProtected: (self: Public, player: Player) -> boolean,
	InZone: (self: Public, player: Player, pointId: string, radius: number) -> boolean,
	Looking: (self: Public, player: Player, target: Vector3, range: number, angle: number?) -> boolean,
	Pitch: (self: Public, player: Player) -> number?,
	IsWatching: (self: Public, player: Player) -> boolean,
	OnGaze: (self: Public, value: any, player: Player) -> (),
	RunOf: (self: Public, occ: Api.Occurrence) -> Run?,
	AllocateId: (self: Public) -> number?,
	Write: (self: Public, run: Run) -> (),
	Publish: (self: Public, occ: Api.Occurrence, fields: Api.Fields) -> (),
	FireCue: (self: Public, run: Run, cue: string, entity: number, user: number?) -> (),
	Cue: (self: Public, occ: Api.Occurrence, cue: string, entity: number?, user: number?) -> (),
	Fail: (self: Public, occ: Api.Occurrence, who: { Player } | "active") -> (),
	Succeed: (self: Public, occ: Api.Occurrence) -> (),
	EmitEnded: (self: Public, run: Run, reason: Api.StopReason) -> (),
	CallStop: (self: Public, run: Run, reason: Api.StopReason) -> (),
	Finish: (self: Public, occ: Api.Occurrence) -> (),
	StopAll: (self: Public, reason: Api.StopReason) -> (),
	StartOccurrence: (self: Public, key: string, module: Api.Module, slot: number) -> (boolean, string?),
	See: (self: Public, occ: Api.Occurrence, player: Player) -> (),
	SeenTick: (self: Public, occ: Api.Occurrence, target: Vector3, range: number, dt: number) -> (),
	StareTick: (self: Public, run: Run, target: Vector3, range: number, dt: number) -> (),
	RefreshTension: (self: Public) -> (),
	Emit: (self: Public, event: Api.Event) -> (),
	BuildContext: (self: Public) -> Api.Context,
	BuildAgenda: (self: Public, info: { Day: number, Night: number, IsNight: boolean, Attempt: number }) -> (),
	SanityOf: (self: Public, player: Player) -> (number, number),
	Scare: (self: Public, player: Player) -> (),
	ScareGapUntil: (self: Public) -> number,
	Queued: (self: Public) -> { Scheduler.Entry },
	Enqueue: (self: Public, entry: Scheduler.Entry) -> (),
	AnyRunning: (self: Public) -> boolean,
	TripBusy: (self: Public) -> boolean,
	TripBreaker: (self: Public) -> boolean,
	CrewSize: (self: Public) -> number,
	CrewEvents: (self: Public) -> number,
	RunningCount: (self: Public) -> number,
	BeatDueIn: (self: Public, future: boolean?) -> number,
	BeatClear: (self: Public, kind: string) -> boolean,
	BeatBegin: (self: Public, key: string, hold: number?) -> (),
	BeatEnd: (self: Public, key: string) -> (),
	BehindWhy: (self: Public) -> string?,
	BehindCalm: (self: Public) -> boolean,
	BehindTargets: (self: Public) -> { Player },
	BehindScare: (self: Public, player: Player, key: string) -> number,
	Limits: (self: Public) -> Scheduler.Limits,
	RunningCandidates: (self: Public) -> { Scheduler.Candidate },
	SetHold: (self: Public, hold: () -> boolean) -> (),
	TutorialHeld: (self: Public) -> boolean,
	InGrace: (self: Public, minutes: number) -> boolean,
	Held: (self: Public, minutes: number) -> boolean,
	StepAgenda: (self: Public, t: number) -> (),
	StepRuns: (self: Public, t: number) -> (),
	StepRemovals: (self: Public, t: number) -> (),
	Step: (self: Public) -> (),
	OnShiftStarted: (self: Public, info: { Day: number, Night: number, IsNight: boolean, Attempt: number }) -> (),
	OnPhase: (self: Public, phase: string) -> (),
	DevCheck: (self: Public) -> (),
	DevForce: (self: Public, anomaly: string, example: boolean) -> string,
	DevStop: (self: Public) -> string,
	DevHoldAgenda: (self: Public, on: boolean) -> (),
	DevIsHeld: (self: Public) -> boolean,
	DevRuns: (self: Public) -> { any },
	DevOccurrence: (self: Public, anomaly: string) -> any,
	DevStopKey: (self: Public, anomaly: string) -> number,
	DevEmit: (self: Public, event: any) -> (),
	DevStatus: (self: Public) -> string,
	DevAgenda: (self: Public) -> string,
	DevPressure: (self: Public, nowToo: boolean) -> string,
	DevTrip: (self: Public, nowToo: boolean) -> string,
	DevBehindPosture: (self: Public, player: Player) -> string,
	DevBehind: (self: Public, arg: string?, caller: Player?) -> string,
	DevBeats: (self: Public) -> string,
}

return {}
