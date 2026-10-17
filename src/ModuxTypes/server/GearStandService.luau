--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

export type Public = {
	ClosesAt: number,
	Enabled: boolean,
	Open: Charm.Atom<boolean>,
	Scheduled: boolean,
	Warned: boolean,
	Setup: (self: Public) -> (),
	IsOpen: (self: Public) -> boolean,
	Publish: (self: Public) -> (),
	Set: (self: Public, open: boolean, notify: boolean) -> (),
	Schedule: (self: Public, now: number) -> (),
	OnPhase: (self: Public, phase: string) -> (),
	Step: (self: Public) -> (),
	Force: (self: Public, open: boolean) -> (),
	Report: (self: Public) -> string,
}

return {}
