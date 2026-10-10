--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Mode = "FirstPerson" | "Spectate" | "Fixed" | "External"
type Group = "Head" | "Arm" | "Body"

export type Public = {
	Applied: boolean,
	ArmsVisible: Vide.Source<boolean>,
	Bound: boolean,
	CanSwitch: Vide.Source<boolean>,
	Character: Model?,
	CharacterConnections: { RBXScriptConnection },
	Dirty: boolean,
	DownAt: number?,
	FallPoint: string?,
	FixedPoint: Vide.Source<string?>,
	Groups: { [BasePart]: Group },
	LastPosition: Vector3?,
	LastState: string,
	Mode: Vide.Source<Mode>,
	NextDrive: number,
	NextPointRetry: number,
	NextStream: number,
	PointId: string?,
	Target: number?,
	Watching: Vide.Source<number?>,
	Setup: (self: Public) -> (),
	SetMode: (self: Public, mode: Mode) -> (),
	SetArmsVisible: (self: Public, visible: boolean) -> (),
	Spectate: (self: Public, userId: number) -> (),
	Fixed: (self: Public, pointId: string) -> (),
	Mates: (self: Public) -> { number },
	Next: (self: Public) -> (),
	NearestPoint: (self: Public, position: Vector3?) -> string,
	PointFrame: (self: Public, id: string?) -> CFrame?,
	Stream: (self: Public, force: boolean) -> (),
	SetSwitchBind: (self: Public, on: boolean) -> (),
	Drive: (self: Public) -> (),
	Body: (self: Public) -> Model?,
	ApplyCamera: (self: Public) -> (),
	IsFirstPerson: (self: Public) -> boolean,
	Track: (self: Public, character: Model?) -> (),
	Restore: (self: Public) -> (),
	Update: (self: Public) -> (),
}

return {}
