--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Window = "Calm" | "Shift" | "Last"
export type Clock = {
	PhaseStartedAt: number,
	PhaseDuration: number,
	ClockFrom: number,
	ClockTo: number,
}
export type Record = {
	Day: number,
	Night: number,
	IsNight: boolean,
	Attempt: number,
	Phase: string,
	Vehicle: string,
	PhaseStartedAt: number,
	PhaseDuration: number,
	ClockFrom: number,
	ClockTo: number,
}

export type Public = {
	Attempt: Vide.Source<number>,
	Clock: Clock?,
	ClockText: Vide.Source<string>,
	Day: Vide.Source<number>,
	InNight: boolean,
	IsNight: Vide.Source<boolean>,
	Minutes: number,
	Night: Vide.Source<number>,
	NightWindow: Vide.Source<Window?>,
	Phase: Vide.Source<string>,
	Ready: Vide.Source<boolean>,
	Vehicle: Vide.Source<string>,
	Format: (self: Public, minutes: number) -> string,
	MinutesAt: (self: Public, clock: Clock, now: number) -> number,
	WindowAt: (self: Public, minutes: number) -> Window?,
	DurationOf: (self: Public, record: Record) -> number,
	HeldMinutes: (self: Public, isNight: boolean) -> number,
	Setup: (self: Public) -> (),
	Refresh: (self: Public) -> (),
	Apply: (self: Public, record: Record) -> (),
}

return {}
