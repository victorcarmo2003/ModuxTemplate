--!strict

export type Bin = { Root: Instance, Drop: Vector3, Id: string }

export type Public = {
	Ready: boolean,
	Setup: (self: Public) -> (),
	NearestBin: (self: Public, from: Vector3) -> Bin?,
	Fly: (self: Public, tray: Model, bin: Bin) -> (),
	Sink: (self: Public, tray: Model, bin: Bin) -> (),
	Toss: (self: Public, tray: Model) -> boolean,
	DevToss: (self: Public, index: number) -> (),
}

return {}
