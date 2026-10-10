--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Record = {
	Route: number,
	Look: number,
	AnchorAt: number,
	AnchorDist: number,
	StopDist: number,
	HeldUntil: number,
}
type Path = {
	Points: { Vector3 },
	Cum: { number }, -- distance at each point
	Length: number,
	Slow: { { number } }, -- [from, to] stretches inside the X-T footprint (SpeedCrossing)
}
type Kit = {
	Model: Model,
	Look: number,
	Parts: { BasePart },
	Offsets: { CFrame }, -- part CFrame in pivot space
	Wheels: { Wheel },
	Size: Vector3,
	Lamps: { BasePart },
	LampLook: { { Color: Color3, Material: Enum.Material } },
	Beams: { Beam },
}
type Car = {
	Id: number,
	Record: Record,
	Path: Path?,
	Kit: Kit?,
	-- grid integration (Motion); state at step K and K + 1
	K: number,
	S0: number,
	U0: number,
	S1: number,
	U1: number,
	-- shown state
	Dist: number,
	Speed: number,
	Blend: number, -- studs added to Dist, decays to 0 in BLEND_TIME
	BlendAt: number,
	Spin: number, -- wheel angle (rad)
	Hit: boolean, -- already reported a hit on the own character
	Parked: boolean,
	NextFarAt: number,
	CFrame: CFrame?,
}
type Wheel = {
	Index: number, -- position in Car.Parts
	Centre: Vector3, -- axle centre, pivot space
	Radius: number,
}

export type Public = {
	Cars: { [number]: Car },
	Count: Vide.Source<number>,
	Folder: Folder?,
	GetUpThread: thread?,
	ImmuneUntil: number,
	MapReady: boolean,
	Night: boolean,
	PathRetryAt: { [string]: number },
	Paths: { [string]: Path },
	Pool: { [number]: { Kit } },
	Setup: (self: Public) -> (),
	Container: (self: Public) -> Folder,
	PathOf: (self: Public, route: number) -> Path?,
	TakeKit: (self: Public, look: number) -> Kit,
	ReleaseKit: (self: Public, kit: Kit) -> (),
	Advance: (self: Public, car: Car, path: Path, now: number) -> (),
	CarMotion: (self: Public, car: Car, path: Path, now: number) -> (number, number),
	Reanchor: (self: Public, car: Car) -> (),
	Apply: (self: Public, id: number, record: Record) -> (),
	Remove: (self: Public, id: number) -> (),
	SetNight: (self: Public, night: boolean) -> (),
	Place: (self: Public, car: Car, kit: Kit, pivot: CFrame, spin: boolean) -> (),
	OwnRoot: (self: Public, clock: number) -> BasePart?,
	PredictHit: (self: Public, root: BasePart, carFront: Vector3, clock: number) -> (),
	TestHit: (self: Public, car: Car, kit: Kit, pivot: CFrame, root: BasePart, clock: number) -> boolean,
	Step: (self: Public, dt: number) -> (),
}

return {}
