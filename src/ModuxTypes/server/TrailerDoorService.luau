--!strict

export type Public = {
	Busy: { [Player]: boolean },
	Enabled: boolean,
	EnterAnchors: { [Instance]: boolean },
	ExitAnchors: { [Instance]: boolean },
	LastUse: { [Player]: number },
	Tries: number,
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	Model: (self: Public) -> Model?,
	IsPadded: (self: Public) -> boolean,
	Register: (self: Public, anchor: Instance) -> (),
	Host: (self: Public, model: Model) -> BasePart?,
	Create: (self: Public, model: Model, host: BasePart, pad: CFrame, name: string, action: string, offset: Vector3) -> (),
	EnsureAnchors: (self: Public) -> boolean,
	Refresh: (self: Public) -> (),
	CastParams: (self: Public) -> RaycastParams,
	Ground: (self: Public, x: number, z: number, fromY: number, params: RaycastParams) -> Vector3?,
	IsFree: (self: Public, floor: Vector3) -> boolean,
	OutsideFor: (self: Public, player: Player) -> Vector3?,
	InsideFor: (self: Public, player: Player) -> Vector3?,
	CanUse: (self: Public, player: Player, anchor: Instance, action: string) -> boolean,
	Use: (self: Public, player: Player, action: string) -> (),
	Move: (self: Public, player: Player, action: string) -> (),
}

return {}
