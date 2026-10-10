--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Clock = {
	PhaseStartedAt: number,
	PhaseDuration: number,
	ClockFrom: number,
	ClockTo: number,
}
export type Record = {
	Day: number,
	IsNight: boolean,
	Phase: string,
	PhaseStartedAt: number,
	PhaseDuration: number,
	ClockFrom: number,
	ClockTo: number,
}

export type Public = {
	Clock: Clock?,
	ClockText: Vide.Source<string>,
	Day: Vide.Source<number>,
	IsNight: Vide.Source<boolean>,
	Minutes: number,
	Phase: Vide.Source<string>,
	Ready: Vide.Source<boolean>,
	Format: (self: Public, minutes: number) -> string,
	MinutesAt: (self: Public, clock: Clock, now: number) -> number,
	Setup: (self: Public) -> (),
	Refresh: (self: Public) -> (),
	Apply: (self: Public, record: Record) -> (),
}

return {}
