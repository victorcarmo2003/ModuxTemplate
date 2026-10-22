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
	Paused: boolean,
	Chances: number,
	WipeEndsAt: number,
}

export type Public = {
	Attempt: Vide.Source<number>,
	Chances: Vide.Source<number>,
	Clock: Clock?,
	ClockText: Vide.Source<string>,
	Dark: Vide.Source<boolean>,
	Day: Vide.Source<number>,
	InNight: boolean,
	IsNight: Vide.Source<boolean>,
	Minutes: number,
	Night: Vide.Source<number>,
	NightWindow: Vide.Source<Window?>,
	Paused: Vide.Source<boolean>,
	Phase: Vide.Source<string>,
	PhaseDuration: Vide.Source<number>,
	PhaseStartedAt: Vide.Source<number>,
	Ready: Vide.Source<boolean>,
	Vehicle: Vide.Source<string>,
	WipeEndsAt: Vide.Source<number>,
	Format: (self: Public, minutes: number) -> string,
	MinutesAt: (self: Public, clock: Clock, now: number) -> number,
	WindowAt: (self: Public, minutes: number) -> Window?,
	DurationOf: (self: Public, record: Record) -> number,
	HeldMinutes: (self: Public, isNight: boolean) -> number,
	Setup: (self: Public) -> (),
	Refresh: (self: Public) -> (),
	SyncDark: (self: Public) -> (),
	Apply: (self: Public, record: Record) -> (),
}

return {}
