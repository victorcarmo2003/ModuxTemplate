--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

export type Status = "Waiting" | "Playing" | "Ending"

export type Public = {
	Seconds: Charm.Atom<number>,
	Status: Charm.Atom<Status>,
	Setup: (self: Public) -> (),
	Enter: (self: Public, status: Status, seconds: number) -> (),
	Advance: (self: Public) -> (),
}

return {}
