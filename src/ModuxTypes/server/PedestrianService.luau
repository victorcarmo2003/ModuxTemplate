--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(ReplicatedStorage.shared.Traffic.Motion)
local WalkGeo = require(ReplicatedStorage.shared.Pedestrian.WalkGeo)

type WalkPath = typeof(Content.WalkPaths.List[1])
type Stop = {
	At: number, -- absolute distance of the record
	Kind: "Crossing" | "Pause",
	Crosswalk: string?,
	Exit: number, -- Crossing: far curb (absolute); Pause: = At
}
type Walker = {
	Id: number,
	Npc: number, -- reservation id (-slot)
	Geo: WalkGeo.Geo,
	Profile: Motion.Profile,
	Record: Record,
	Cursor: Motion.Cursor,
	Dist: number,
	Speed: number,
	Stop: Stop?, -- stop the current record heads to
	ParkedAt: number?,
	-- on the road under a reservation: crosswalk and far curb (absolute)
	Crossing: { Crosswalk: string, Exit: number }?,
	-- leaving: Loop -> removed at this distance (lap seam)
	Leaving: boolean,
	LapEnd: number?,
	-- braking / standing for the customer side (adoption): no crosswalk request until released or taken
	Noticed: boolean,
}
export type Handoff = { Species: string, Outfit: string, Position: Vector3, Heading: Vector3, Node: string }
type Hold = {
	Holder: number, -- reservation id given to TrafficService
	Expires: number, -- server time: GrantedAt + the duration asked (mirror of TrafficService, >= Crossing.MaxWait)
	Riders: { [number]: boolean }, -- walker slots on the road under it
}
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

export type Public = {
	Adoption: { Force: () -> string, Status: () -> string }?,
	Drawn: boolean,
	Enabled: boolean,
	FillPending: boolean,
	GeoRetryAt: { [string]: number },
	Geos: { [string]: WalkGeo.Geo },
	Holds: { [string]: Hold },
	NextSpawnAt: number,
	OutfitList: { string },
	Rng: Random,
	SpeciesList: { string },
	TargetCount: number,
	TargetNight: boolean,
	Walkers: { [number]: Walker },
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	Count: (self: Public) -> number,
	Target: (self: Public) -> number,
	CanWalk: (self: Public) -> boolean,
	GeoOf: (self: Public, row: WalkPath) -> WalkGeo.Geo?,
	Publish: (self: Public, walker: Walker, added: boolean) -> (),
	Anchor: (self: Public, walker: Walker, dist: number, inclusive: boolean, t: number, added: boolean) -> (),
	FreeSlot: (self: Public) -> number?,
	Spawn: (self: Public, row: WalkPath, geo: WalkGeo.Geo, dist: number, t: number) -> Walker?,
	Remove: (self: Public, walker: Walker) -> (),
	RemoveAll: (self: Public) -> (),
	OffRoad: (self: Public, walker: Walker) -> (),
	TryCross: (self: Public, walker: Walker, stop: Stop, t: number) -> (),
	StepWalker: (self: Public, walker: Walker, t: number) -> (),
	Retarget: (self: Public) -> (),
	TrimExtras: (self: Public) -> (),
	PickPath: (self: Public, night: boolean, startClear: boolean) -> (WalkPath?, WalkGeo.Geo?),
	RandomSpot: (self: Public, geo: WalkGeo.Geo) -> number?,
	TrySpawn: (self: Public, t: number) -> (),
	Step: (self: Public) -> (),
	AdoptPick: (self: Public, center: Vector3, radius: number, accept: (species: string, outfit: string) -> boolean) -> number?,
	NoticedWalker: (self: Public, slot: number) -> Walker?,
	AdoptPeek: (self: Public, slot: number) -> Handoff?,
	AdoptTake: (self: Public, slot: number) -> boolean,
	AdoptRelease: (self: Public, slot: number) -> (),
	Status: (self: Public) -> string,
	DevSpawn: (self: Public, pathKey: string?) -> string,
	DevAdopt: (self: Public) -> string,
	DevClear: (self: Public) -> number,
}

return {}
