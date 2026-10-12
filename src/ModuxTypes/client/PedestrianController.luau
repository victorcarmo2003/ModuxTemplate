--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Motion = require(ReplicatedStorage.shared.Traffic.Motion)
local WalkGeo = require(ReplicatedStorage.shared.Pedestrian.WalkGeo)

export type Record = {
	Path: number,
	Species: string,
	Outfit: string,
	Speed: number,
	AnchorAt: number,
	AnchorDist: number,
	StopDist: number,
	HeldUntil: number,
}
type Walk = {
	Line: Motion.Path,
	Loop: boolean,
	Geo: WalkGeo.Geo, -- same geometry as the server (crossings, lane offsets)
}
type Walker = {
	Id: number,
	Record: Record,
	Walk: Walk?,
	Profile: Motion.Profile?,
	Cursor: Motion.Cursor?,
	Model: Model?,
	Root: BasePart?,
	Shown: boolean,
	Dist: number,
	Blend: number, -- studs added to Dist, decays to 0 in BLEND_TIME
	BlendAt: number,
}

export type Public = {
	Count: Vide.Source<number>,
	Folder: Folder?,
	MapReady: boolean,
	Pool: { [string]: { Model } },
	Pooled: number,
	WalkRetryAt: { [number]: number },
	Walkers: { [number]: Walker },
	Walks: { [number]: Walk },
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	Container: (self: Public) -> Folder,
	WarnOnce: (self: Public, key: string, message: string) -> (),
	WalkOf: (self: Public, index: number) -> Walk?,
	TakeRig: (self: Public, record: Record) -> Model?,
	ReleaseRig: (self: Public, walker: Walker) -> (),
	Reanchor: (self: Public, walker: Walker) -> (),
	Distance: (self: Public, walker: Walker, now: number) -> number?,
	Apply: (self: Public, id: number, record: Record) -> (),
	Remove: (self: Public, id: number) -> (),
	Hide: (self: Public, walker: Walker) -> (),
	Show: (self: Public, walker: Walker) -> BasePart?,
	Step: (self: Public) -> (),
}

return {}
