--!strict

export type Active = {
	At: number, -- server time it started
	DeadlineAt: number, -- 0 = none
	Paid: boolean,
	Mask: number,
	Anchors: { [Instance]: number }, -- anchor -> spot index (rats) or 0
	Model: Instance?, -- grill model / camera model
}

export type Public = {
	Active: { [string]: Active },
	Count: number,
	Enabled: boolean,
	Models: { [string]: Instance },
	NextAt: number,
	Night: number,
	Published: boolean,
	Random: Random,
	Setup: (self: Public) -> (),
	ModelOf: (self: Public, mapId: string) -> Model?,
	CameraModel: (self: Public, index: number) -> Model?,
	Folder: (self: Public) -> Folder,
	Anchor: (self: Public, name: string, action: string, at: Vector3, host: BasePart?) -> Attachment,
	Write: (self: Public, key: string) -> (),
	Start: (self: Public, key: string) -> boolean,
	End: (self: Public, key: string) -> (),
	EndAll: (self: Public) -> (),
	Penalize: (self: Public, key: string) -> (),
	Limit: (self: Public) -> number,
	Between: (self: Public) -> number,
	Pick: (self: Public, avoid: { [string]: boolean }) -> string?,
	DrawOne: (self: Public) -> string?,
	Step: (self: Public) -> (),
	OnShift: (self: Public, info: { Day: number, Night: number, IsNight: boolean, Attempt: number }) -> (),
	Owns: (self: Public, key: string, anchor: Instance) -> number?,
	InSight: (self: Public, player: Player, anchor: Instance) -> boolean,
	Blocked: (self: Public, action: string, anchor: Instance) -> string?,
	DevDescribe: (self: Public) -> string,
	DevRun: (self: Public, args: { string }) -> string,
}

return {}
