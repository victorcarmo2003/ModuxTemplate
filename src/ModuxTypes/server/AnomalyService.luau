--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Api = require(ServerScriptService.server.Anomaly.AnomalyService.Api)
local Scheduler = require(ServerScriptService.server.Anomaly.AnomalyService.Scheduler)

export type Occurrence = Api.Occurrence
export type Event = Api.Event
export type Context = Api.Context
export type Module = Api.Module
export type Rule = Api.Rule
export type Run = {
	Occ: Api.Occurrence,
	Row: Content.Anomaly,
	Module: Api.Module,
	Record: Wire,
	Added: boolean,
	Starting: boolean,
	FinishPending: boolean,
	Done: boolean,
	Cues: { { Cue: string, Entity: number } },
	Failed: { [number]: boolean },
	CriticalSent: boolean,
	Seen: { [number]: number },
	SeenDone: { [number]: boolean },
	-- UserIds Active when the occurrence started (Ended, TASK-335)
	Party: { number },
}
export type Due = { Entry: Scheduler.Entry, RetryAt: number, Done: boolean }
export type Gaze = { Yaw: number, Pitch: number, At: number }
type TrafficHook = { Hold: (self: any, reason: string, on: boolean) -> () }
export type Entry = Scheduler.Entry
export type Wire = { Anomaly: string, Phase: Api.Phase, StartedAt: number, Step: number, Anchor: number }

export type Public = {
	Context: Api.Context?,
	DevHeld: boolean,
	DevSerial: number,
	Enabled: boolean,
	Ended: SignalLib.Signal<string, { Player }>,
	Example: Api.Module?,
	Gazes: { [Player]: Gaze },
	InNight: boolean,
	LastStartAt: number,
	Live: boolean,
	Modules: { [string]: Api.Module },
	NextId: number,
	Queue: { Due },
	Removing: { [number]: number },
	Running: { [number]: Run },
	Scares: { number },
	Security: any,
	Shift: { Day: number, Night: number, IsNight: boolean, Attempt: number },
	Tension: SignalLib.Signal<boolean>,
	TensionOn: boolean,
	Traffic: TrafficHook?,
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
	Looking: (self: Public, player: Player, target: Vector3, range: number) -> boolean,
	IsWatching: (self: Public, player: Player) -> boolean,
	OnGaze: (self: Public, value: any, player: Player) -> (),
	RunOf: (self: Public, occ: Api.Occurrence) -> Run?,
	AllocateId: (self: Public) -> number?,
	Write: (self: Public, run: Run) -> (),
	Publish: (self: Public, occ: Api.Occurrence, fields: Api.Fields) -> (),
	FireCue: (self: Public, run: Run, cue: string, entity: number) -> (),
	Cue: (self: Public, occ: Api.Occurrence, cue: string, entity: number?) -> (),
	Fail: (self: Public, occ: Api.Occurrence, who: { Player } | "active") -> (),
	Succeed: (self: Public, occ: Api.Occurrence) -> (),
	EmitEnded: (self: Public, run: Run, reason: Api.StopReason) -> (),
	CallStop: (self: Public, run: Run, reason: Api.StopReason) -> (),
	Finish: (self: Public, occ: Api.Occurrence) -> (),
	StopAll: (self: Public, reason: Api.StopReason) -> (),
	StartOccurrence: (self: Public, key: string, module: Api.Module, slot: number) -> (boolean, string?),
	See: (self: Public, occ: Api.Occurrence, player: Player) -> (),
	SeenTick: (self: Public, occ: Api.Occurrence, target: Vector3, range: number, dt: number) -> (),
	RefreshTension: (self: Public) -> (),
	Emit: (self: Public, event: Api.Event) -> (),
	BuildContext: (self: Public) -> Api.Context,
	BuildAgenda: (self: Public, info: { Day: number, Night: number, IsNight: boolean, Attempt: number }) -> (),
	Limits: (self: Public) -> Scheduler.Limits,
	RunningCandidates: (self: Public) -> { Scheduler.Candidate },
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
}

return {}
