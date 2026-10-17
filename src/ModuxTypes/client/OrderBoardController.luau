--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local OrderBoard = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.OrderBoard)

export type Record = {
	State: string,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
	Leader: number?,
	PatienceEndsAt: number,
	PatienceSpan: number,
	Phase: string,
	Number: number?,
	Pickup: number?,
}
export type Tablet = {
	State: string,
	Npc: number,
	StartedAt: number,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
}
export type Plate = {
	Npc: number,
	Line: number,
	Bun: boolean,
	Sausage: boolean,
	Toppings: { [string]: boolean },
	Since: number,
}
type Mounted = { Part: BasePart, Destroy: () -> (), Gui: SurfaceGui, Connections: { RBXScriptConnection } }

export type Public = {
	Board: Mounted?,
	Cards: Vide.Source<{ OrderBoard.Card }>,
	Customers: { [number]: Record },
	FirstSeen: { [number]: number },
	LastState: { [number]: OrderBoard.CardState },
	Plates: { [number]: Plate },
	Tablets: { [number]: Tablet },
	Setup: (self: Public) -> (),
	Build: (self: Public) -> { OrderBoard.Card },
	Refresh: (self: Public) -> (),
	WriteCustomer: (self: Public, id: number, record: Record?) -> (),
	WritePlate: (self: Public, id: number, plate: Plate?) -> (),
	WriteTablet: (self: Public, id: number, tablet: Tablet?) -> (),
	Unmount: (self: Public) -> (),
	Mount: (self: Public, part: BasePart) -> (),
	Find: (self: Public) -> (),
}

return {}
