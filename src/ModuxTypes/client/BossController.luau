--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)

export type Record = {
	Call: string,
	State: string,
	StartedAt: number,
}
type Phone = {
	Model: Instance,
	Lamps: { Lamp },
	Ripple: Instance?, -- adornee of the ripples
	RippleOffset: Vector3,
	Speaker: BasePart?, -- host of the ring Sound
}
type Lamp = {
	Part: BasePart,
	Color: Color3,
	Material: Enum.Material,
}

export type Public = {
	Call: Vide.Source<string>,
	Gui: ScreenGui?,
	LampOn: boolean,
	LineIndex: number,
	Lines: { Content.BossCallLine },
	LinesNight: number,
	Phone: Phone?,
	RingSound: Sound?,
	RippleAt: Vide.Source<number>,
	RippleGui: BillboardGui?,
	RippleUnmount: (() -> ())?,
	Scale: Vide.Source<number>,
	Showing: Vide.Source<boolean>,
	Speaker: Vide.Source<string>,
	StartedAt: number,
	State: Vide.Source<string>,
	Text: Vide.Source<string>,
	Vehicle: Instance?,
	VehicleConnections: { RBXScriptConnection },
	Setup: (self: Public) -> (),
	Night: (self: Public) -> number,
	Apply: (self: Public, record: Record) -> (),
	Refresh: (self: Public) -> (),
	FindVehicle: (self: Public) -> Instance?,
	SetLamp: (self: Public, on: boolean) -> (),
	SetRing: (self: Public, on: boolean) -> (),
	NewSound: (self: Public, key: string, host: BasePart) -> Sound?,
	PlayOnce: (self: Public, key: string) -> (),
	ClearPhone: (self: Public) -> (),
	UsePhone: (self: Public, model: Instance?) -> (),
	Track: (self: Public) -> (),
	Rescale: (self: Public, camera: Camera?) -> (),
	WatchViewport: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
