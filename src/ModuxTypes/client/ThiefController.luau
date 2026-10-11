--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Record = {
	State: string,
	StartedAt: number,
	Duration: number,
}
type Mount = {
	Adornee: Instance,
	Gui: BillboardGui,
	Unmount: () -> (),
}

export type Public = {
	Duration: Vide.Source<number>,
	Gui: Instance?,
	Mount: Mount?,
	Now: Vide.Source<number>,
	StartedAt: Vide.Source<number>,
	State: Vide.Source<string>,
	Ticker: RBXScriptConnection?,
	Vehicle: Instance?,
	VehicleConnections: { RBXScriptConnection },
	Setup: (self: Public) -> (),
	Progress: (self: Public) -> number,
	Apply: (self: Public, record: Record) -> (),
	Tick: (self: Public) -> (),
	FindVehicle: (self: Public) -> Instance?,
	PlayOpen: (self: Public) -> (),
	Clear: (self: Public) -> (),
	Draw: (self: Public, adornee: Instance, offset: Vector3) -> (),
	Resolve: (self: Public) -> (),
	Track: (self: Public) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
