--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

type Show = {
	Id: number,
	Event: Content.SuspenseEvent,
	Model: Model,
	Head: Vector3,
	EndsAt: number, -- os.clock
	Seen: boolean,
	Connection: RBXScriptConnection?,
}

export type Public = {
	Folder: Folder?,
	NoticeAt: number,
	Noticed: { [number]: boolean },
	Show: Show?,
	Setup: (self: Public) -> (),
	FolderOf: (self: Public) -> Folder,
	Clear: (self: Public) -> (),
	InSight: (self: Public, point: Vector3, range: number, margin: number, ignore: { Instance }) -> boolean,
	StepNoticed: (self: Public) -> (),
	Startle: (self: Public, point: Vector3) -> (),
	Glanced: (self: Public, show: Show) -> boolean,
	Catch: (self: Public, show: Show) -> (),
	Begin: (self: Public, data: { Id: number, Event: string, Spot: string, Seed: number }) -> (),
	Reset: (self: Public) -> (),
}

return {}
