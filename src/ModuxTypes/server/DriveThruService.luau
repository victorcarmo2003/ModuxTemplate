--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lane = require(ReplicatedStorage.shared.DriveThru.Lane)

export type Car = {
	Npc: number,
	Look: number,
	Spot: number,
	State: CarState,
	At: number, -- server time of the State change
	From: number, -- distance along the lane when the move started
	To: number, -- distance it moves to
	Ends: number, -- server time the move ends
	Joined: boolean, -- reached a spot once (JoinDrive done)
	Model: Model?, -- the driver's rig (its DriveThru attribute is cleared however the customer goes)
}
export type CarState = "Arriving" | "Waiting" | "Leaving"

export type Public = {
	Cars: { [number]: Car },
	Enabled: boolean,
	Force: boolean,
	Lane: Lane.Lane?,
	Published: { [number]: boolean },
	Rng: Random,
	Window: Attachment?,
	WindowOn: boolean,
	Setup: (self: Public) -> (),
	CarOf: (self: Public, npc: number) -> Car?,
	Allowed: (self: Public, party: number) -> number,
	NextSpot: (self: Public, allowed: number) -> number,
	DistOf: (self: Public, car: Car, t: number) -> number,
	Try: (self: Public, party: number, counter: number) -> number?,
	TryTutorial: (self: Public) -> number?,
	Spawn: (self: Public, spot: number, tutorial: boolean) -> number?,
	DriverPose: (self: Public, s: number) -> CFrame,
	Anchor: (self: Public, id: number, on: boolean) -> (),
	PlaceDriver: (self: Public, car: Car) -> (),
	Left: (self: Public, id: number) -> (),
	Drop: (self: Public, spot: number) -> (),
	Release: (self: Public, car: Car) -> (),
	Unhide: (self: Public, car: Car) -> (),
	Arrive: (self: Public, car: Car, t: number) -> (),
	Compact: (self: Public, t: number) -> (),
	Step: (self: Public) -> (),
	Publish: (self: Public, spot: number) -> (),
	Unpublish: (self: Public, spot: number) -> (),
	ServeTarget: (self: Public) -> number?,
	SyncWindow: (self: Public) -> (),
	WindowSpot: (self: Public) -> (Vector3?, Vector3),
	MakeAnchors: (self: Public) -> (),
	DevCheck: (self: Public) -> (),
	DevCar: (self: Public) -> string,
	DevState: (self: Public) -> string,
	DevServe: (self: Public, player: Player, exact: boolean?) -> string,
}

return {}
