--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Record = {
	Cash: number,
	Drawer: number,
}

export type Public = {
	Cash: Vide.Source<number>,
	FlyGui: ScreenGui?,
	Gui: Instance?,
	LandSerial: number,
	Ready: Vide.Source<boolean>,
	Shown: Vide.Source<number>,
	Setup: (self: Public) -> (),
	Apply: (self: Public, record: Record) -> (),
	Land: (self: Public, cash: number, ready: boolean) -> (),
	SalePosition: (self: Public, npc: number) -> Vector3?,
	Chime: (self: Public, amount: number, npc: number) -> (),
	FlyScreen: (self: Public) -> ScreenGui?,
	PillTarget: (self: Public, scale: number, viewport: Vector2) -> Vector2,
	FlyPiece: (self: Public, position: Vector3?, coin: boolean, delay: number) -> (),
	Fly: (self: Public, amount: number, position: Vector3?) -> (),
}

return {}
