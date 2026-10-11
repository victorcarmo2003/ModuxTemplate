--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Reason = "unknown" | "not_on_vehicle" | "maxed" | "locked" | "busy" | "not_enough_cash"
export type Levels = { [string]: { [string]: number } }

export type Public = {
	BoughtAt: { [string]: number },
	Changed: SignalLib.Signal<string, number, string>,
	Levels: Charm.Atom<Levels>,
	Vehicle: Charm.Atom<string>,
	Setup: (self: Public) -> (),
	GetVehicle: (self: Public) -> string,
	GetLevel: (self: Public, key: string, vehicle: string?) -> number?,
	CurrentRow: (self: Public, key: string, vehicle: string?) -> Content.UpgradeLevel?,
	NextLevel: (self: Public, key: string) -> Content.UpgradeLevel?,
	IsMaxed: (self: Public, key: string) -> boolean,
	GetEffect: (self: Public, stat: string, vehicle: string?) -> number,
	GuardKey: (self: Public, key: string) -> string,
	CanBuy: (self: Public, key: string) -> (boolean, Reason?),
	Buy: (self: Public, key: string, player: Player?, quiet: boolean?) -> (boolean, Reason?),
	SetLevel: (self: Public, vehicle: string, key: string, level: number) -> (),
	SetVehicle: (self: Public, vehicle: string) -> (),
	Capture: (self: Public) -> { [string]: { [string]: number } },
	Restore: (self: Public, data: any) -> (),
	RefreshPiece: (self: Public, instance: Instance) -> (),
	RefreshPieces: (self: Public) -> (),
	Records: (self: Public) -> { { Level: number } },
}

return {}
