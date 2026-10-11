--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Motion = require(ReplicatedStorage.shared.Traffic.Motion)
local VitalTypes = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.VitalController)

export type Record = {
	Route: number,
	Look: number,
	AnchorAt: number,
	AnchorDist: number,
	StopDist: number,
	HeldUntil: number,
}
type Path = {
	Line: Motion.Path,
	Profile: Motion.Profile,
	Length: number,
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
	-- Motion grid state of the current record (nil until the path is known)
	Cursor: Motion.Cursor?,
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
	Engine: Model?, -- model the `car_engine` loop is on (nil = silent)
}
type Wheel = {
	Index: number, -- position in Car.Parts
	Centre: Vector3, -- axle centre, pivot space
	Radius: number,
}

export type Public = {
	BoingAt: number,
	Cars: { [number]: Car },
	Count: Vide.Source<number>,
	Folder: Folder?,
	GetUpThread: thread?,
	ImmuneUntil: number,
	KnockSeen: { [number]: number },
	MapReady: boolean,
	Night: boolean,
	PathRetryAt: { [string]: number },
	Paths: { [string]: Path },
	Pool: { [number]: { Kit } },
	Setup: (self: Public) -> (),
	Container: (self: Public) -> Folder,
	PathOf: (self: Public, route: number) -> Path?,
	TakeKit: (self: Public, look: number) -> Kit,
	SetEngine: (self: Public, car: Car, on: boolean) -> (),
	ReleaseKit: (self: Public, kit: Kit) -> (),
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
	Engines: (self: Public, near: { Car }, distance: { [Car]: number }) -> (),
	OnMembers: (self: Public, members: { [number]: VitalTypes.Member }) -> (),
}

return {}
