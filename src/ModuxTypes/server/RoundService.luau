--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Phase = "Prep" | "Open" | "Closing" | "Summary"
export type ShiftInfo = { Day: number, Night: number, IsNight: boolean, Attempt: number }
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

export type Public = {
	CounterEmpty: (() -> boolean)?,
	Day: Charm.Atom<number>,
	Phase: Charm.Atom<Phase>,
	PhaseChanged: SignalLib.Signal<Phase, number, number>,
	PhaseStartedAt: Charm.Atom<number>,
	ShiftEnded: SignalLib.Signal<ShiftInfo>,
	ShiftStarted: SignalLib.Signal<ShiftInfo>,
	Started: boolean,
	Setup: (self: Public) -> (),
	GetPhase: (self: Public) -> Phase,
	GetDay: (self: Public) -> number,
	IsNight: (self: Public) -> boolean,
	IsStarted: (self: Public) -> boolean,
	Info: (self: Public) -> ShiftInfo,
	Row: (self: Public, phase: Phase) -> Content.Phase,
	Deadline: (self: Public) -> number,
	Minutes: (self: Public) -> number,
	Record: (self: Public) -> Record,
	SetCounterProbe: (self: Public, probe: () -> boolean) -> (),
	IsSign: (self: Public, anchor: Instance) -> boolean,
	RefreshSign: (self: Public, anchor: Instance) -> (),
	RefreshSigns: (self: Public) -> (),
	Enter: (self: Public, phase: Phase, startedAt: number, day: number?) -> (),
	StartShift: (self: Public, day: number, startedAt: number, capture: boolean) -> (),
	EndPhase: (self: Public, startedAt: number) -> (),
	Step: (self: Public) -> (),
	StartRun: (self: Public) -> (),
	CaptureShift: (self: Public) -> { [string]: any },
	RestoreShift: (self: Public, data: { [string]: any }) -> (),
	DevSkipPhase: (self: Public) -> (),
	DevSetDay: (self: Public, day: number) -> (),
}

return {}
