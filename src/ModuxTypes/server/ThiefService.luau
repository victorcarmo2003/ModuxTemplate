--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Draw = require(ServerScriptService.server.Thief.ThiefService.Draw)

export type State = "None" | "Lurking" | "Approaching" | "Opening" | "Fleeing"
export type Record = { State: State, StartedAt: number, Duration: number }
export type Outcome = "caught" | "stole" | "empty" | "gave_up" | "closed"
type Active = {
	Id: number, -- NpcId
	Lurk: string,
	Token: number, -- matches self.Token while this thief is the current one
	Arrived: boolean, -- reached the lurk point
	LurkStartedAt: number, -- server time of arrival at the lurk point
	EmptyFor: number, -- seconds the zone has been empty (Lurking)
	ApproachEndsAt: number,
	OpenEndsAt: number,
}

export type Public = {
	Current: Active?,
	Enabled: boolean,
	Plan: Draw.Plan?,
	Record: Charm.Atom<Record>,
	RetryAt: number,
	Today: number,
	Token: number,
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	GetState: (self: Public) -> State,
	GetPlan: (self: Public) -> Draw.Plan?,
	SetState: (self: Public, state: State, duration: number?) -> (),
	IsDaySelling: (self: Public) -> boolean,
	ZoneCenter: (self: Public) -> Vector3?,
	ZoneGuarded: (self: Public) -> boolean,
	Alive: (self: Public, active: Active) -> boolean,
	Humanoid: (self: Public, id: number) -> Humanoid?,
	MoveDirect: (self: Public, active: Active, target: Vector3) -> boolean,
	WalkIn: (self: Public, active: Active) -> (),
	ExitOrder: (self: Public, from: Vector3) -> { string },
	RunAway: (self: Public, active: Active) -> (),
	Spawn: (self: Public, lurk: string) -> (number?, string?),
	Remove: (self: Public) -> (),
	Abort: (self: Public) -> (),
	Approach: (self: Public, active: Active) -> (),
	Open: (self: Public, active: Active) -> (),
	Flee: (self: Public, active: Active, _outcome: Outcome) -> (),
	Caught: (self: Public, active: Active) -> (),
	Rob: (self: Public, active: Active) -> (),
	OnShiftStarted: (self: Public) -> (),
	OnPhase: (self: Public) -> (),
	StepPlan: (self: Public) -> (),
	StepActive: (self: Public, dt: number) -> (),
	Step: (self: Public, dt: number) -> (),
	DevNow: (self: Public, lurk: string?) -> number,
}

return {}
