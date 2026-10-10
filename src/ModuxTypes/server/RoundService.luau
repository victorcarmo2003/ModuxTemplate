--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Flow = require(ServerScriptService.server.Round.RoundService.Flow)

export type Phase =
	"Resume"
	| "Intro"
	| "Prep"
	| "Open"
	| "Closing"
	| "Summary"
	| "Call"
	| "Night"
	| "NightEnd"
	| "NightLost"
	| "Finale"
	| "RunEnd"
export type ShiftInfo = Flow.Info
export type NightWindow = Flow.Window
export type LoseReason = "wipe" | "critical"
export type NightResult = "Won" | "Lost"
export type RunResult = "Success" | "Failed"
export type RunReportStep = (player: Player, report: RunReport) -> ()
type Step = { Name: string, Run: RunReportStep }
export type Record = {
	Day: number,
	Night: number,
	IsNight: boolean,
	Attempt: number,
	Phase: string,
	PhaseStartedAt: number,
	PhaseDuration: number,
	ClockFrom: number,
	ClockTo: number,
	Vehicle: string,
	Chances: number,
	WipeEndsAt: number,
	WipeFrozen: boolean,
}
export type RunReport = { Result: RunResult, Day: number, Night: number, Gems: number }

export type Public = {
	Attempt: Charm.Atom<number>,
	BeforeShift: SignalLib.Signal<ShiftInfo>,
	Busy: boolean,
	Day: Charm.Atom<number>,
	Held: Charm.Atom<number>,
	LostReason: LoseReason,
	Night: Charm.Atom<number>,
	NightEndedAt: number,
	NightResolved: SignalLib.Signal<ShiftInfo, NightResult, LoseReason?>,
	NightShift: Charm.Atom<boolean>,
	Phase: Charm.Atom<Phase>,
	PhaseChanged: SignalLib.Signal<Phase, number, number>,
	PhaseStartedAt: Charm.Atom<number>,
	Probes: { [string]: () -> boolean },
	Result: RunResult,
	RunEnded: SignalLib.Signal<RunResult>,
	RunSteps: { Step },
	ShiftEnded: SignalLib.Signal<ShiftInfo>,
	ShiftStarted: SignalLib.Signal<ShiftInfo>,
	Started: boolean,
	VehicleProbe: (() -> string)?,
	VerdictProbe: (() -> boolean)?,
	WipeEndsAt: Charm.Atom<number>,
	WipeFrozen: Charm.Atom<boolean>,
	Setup: (self: Public) -> (),
	GetPhase: (self: Public) -> Phase,
	GetDay: (self: Public) -> number,
	GetNight: (self: Public) -> number,
	IsNight: (self: Public) -> boolean,
	IsStarted: (self: Public) -> boolean,
	Info: (self: Public) -> ShiftInfo,
	IsSelling: (self: Public) -> boolean,
	NightDuration: (self: Public, night: number) -> number,
	Timing: (self: Public, phase: Phase) -> Flow.Timing,
	Deadline: (self: Public) -> number,
	ClockAt: (self: Public, t: number) -> number,
	Minutes: (self: Public) -> number,
	NightWindow: (self: Public) -> NightWindow?,
	NightEndsAt: (self: Public) -> number,
	CurrentVehicle: (self: Public) -> string,
	VehicleHasNight: (self: Public) -> boolean,
	Record: (self: Public) -> Record,
	SetPhaseProbe: (self: Public, phase: Phase, probe: () -> boolean) -> (),
	SetCounterProbe: (self: Public, probe: () -> boolean) -> (),
	SetVehicleProbe: (self: Public, probe: () -> string) -> (),
	SetVerdict: (self: Public, probe: () -> boolean) -> (),
	SetWipe: (self: Public, endsAt: number, frozen: boolean) -> (),
	AddRunReportStep: (self: Public, name: string, step: RunReportStep) -> (),
	HasProbe: (self: Public, phase: string) -> boolean,
	ProbeSaysEnd: (self: Public, phase: Phase) -> boolean,
	Verdict: (self: Public) -> boolean,
	Resolve: (self: Public, phase: string, info: ShiftInfo) -> Phase,
	IsSign: (self: Public, anchor: Instance) -> boolean,
	RefreshSign: (self: Public, anchor: Instance) -> (),
	RefreshSigns: (self: Public) -> (),
	Enter: (self: Public, phase: Phase, startedAt: number, info: ShiftInfo?, held: number?) -> (),
	Go: (self: Public, phase: Phase, startedAt: number) -> (),
	StartShift: (self: Public, info: ShiftInfo, startedAt: number, capture: boolean, newRun: boolean) -> (),
	EnterResume: (self: Public, info: ShiftInfo, startedAt: number) -> (),
	Lose: (self: Public, reason: LoseReason, startedAt: number) -> (),
	WinNight: (self: Public, startedAt: number) -> (),
	Boundary: (self: Public, startedAt: number) -> (),
	EndLost: (self: Public, startedAt: number) -> (),
	EndRun: (self: Public, startedAt: number) -> (),
	Advance: (self: Public, startedAt: number) -> (),
	Step: (self: Public) -> (),
	LoseNight: (self: Public, reason: LoseReason) -> boolean,
	StartRun: (self: Public) -> (),
	SendRunReports: (self: Public, result: RunResult) -> (),
	HookEconomy: (self: Public) -> (),
	CaptureShift: (self: Public) -> { [string]: any },
	RestoreShift: (self: Public, data: { [string]: any }, mode: string) -> (),
	DevCheck: (self: Public, name: string) -> (),
	DevSkipPhase: (self: Public) -> (),
	DevSetDay: (self: Public, day: number) -> (),
	DevSetNight: (self: Public, night: number) -> (),
	DevWinNight: (self: Public) -> (),
}

return {}
