--!strict

type Switch = {
	Box: BasePart,
	Lever: BasePart,
	Rel: CFrame, -- authored Lever in Box space
	Pivot: Vector3, -- tilt pivot in Box space (the Lever base on the Box surface)
	Action: string,
	Vehicle: Instance?, -- shutter lever: the `Vehicle`-tagged ancestor carrying the Shutter attribute
	Angle: number,
	From: number,
	To: number,
	StartedAt: number?,
	Seen: boolean, -- the first state is set without a flip
}

export type Public = {
	LightOn: boolean,
	Step: RBXScriptConnection?,
	Switches: { [Instance]: Switch },
	Setup: (self: Public) -> (),
	Register: (self: Public, anchor: Instance) -> (),
	IsOn: (self: Public, switch: Switch) -> boolean,
	Apply: (self: Public, switch: Switch) -> (),
	Refresh: (self: Public) -> (),
	StepLevers: (self: Public) -> (),
}

return {}
