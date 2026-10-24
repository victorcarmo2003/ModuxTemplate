--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

export type Public = {
	Anchor: Attachment?,
	Enabled: boolean,
	Paper: Instance?,
	ScareSerial: number,
	WaitSince: number?,
	Written: Charm.Atom<number>,
	Setup: (self: Public) -> (),
	GetWritten: (self: Public) -> number,
	CallPending: (self: Public) -> boolean,
	Write: (self: Public, night: number) -> (),
	WaltSaysRule: (self: Public, night: number) -> boolean,
	Step: (self: Public) -> (),
	Build: (self: Public) -> (),
	Open: (self: Public, player: Player) -> (),
	DevWrite: (self: Public, night: number?) -> number,
	DevReset: (self: Public) -> (),
	ArmScare: (self: Public, player: Player) -> (),
	DevState: (self: Public) -> string,
}

return {}
