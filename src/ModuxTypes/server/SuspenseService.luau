--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

type Info = { Day: number, Night: number, IsNight: boolean, Attempt: number }
export type Live = {
	Id: number,
	Event: Content.SuspenseEvent,
	Spot: Content.SuspenseSpot,
	Target: Vector3, -- the "seen" point (head of the creature)
	StartedAt: number,
	EndsAt: number,
	Cost: number,
	Paid: { [number]: boolean },
	-- UserIds whose Gaze was inside Rules.SeenAngle at some tick of this event
	Glimpsed: { [number]: boolean },
}

export type Public = {
	Agenda: { number },
	BusyAt: number,
	Caught: SignalLib.Signal<string, Player, number>,
	Enabled: boolean,
	LastAt: number,
	Live: Live?,
	NextId: number,
	Night: number,
	Noticed: { [number]: number },
	RetryAt: number,
	Rng: Random,
	Setup: (self: Public) -> (),
	IsLive: (self: Public) -> boolean,
	AnomalyBusy: (self: Public) -> boolean,
	IsHidden: (self: Public, target: Vector3) -> boolean,
	OnNoticed: (self: Public, value: any, _player: Player) -> (),
	OnShiftStarted: (self: Public, info: Info) -> (),
	OnPhase: (self: Public, phase: string) -> (),
	Start: (self: Public, eventKey: string?, spotKey: string?, force: boolean) -> (boolean, string),
	OnSeen: (self: Public, value: any, player: Player) -> (),
	Step: (self: Public) -> (),
	DevForce: (self: Public, eventKey: string?, spotKey: string?) -> string,
	DevList: (self: Public) -> string,
	DevStatus: (self: Public) -> string,
}

return {}
