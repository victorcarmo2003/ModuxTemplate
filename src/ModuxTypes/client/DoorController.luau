--!strict

type Door = {
	Instance: Instance,
	Leaves: { Leaf },
	Closed: CFrame, -- pivot (leaf bounding box) when closed
	Width: number, -- along the slide / swing axis
	Axis: Vector3, -- local unit axis of the width (X or Z)
	Radius: number,
	Open: boolean,
	LastNear: number,
	Value: CFrameValue, -- animated pivot
	Tween: Tween?,
	Connection: RBXScriptConnection,
	Overlap: OverlapParams,
}
type Leaf = {
	Part: BasePart,
	Offset: CFrame, -- part CFrame relative to the closed pivot
	CanCollide: boolean,
}

export type Public = {
	Doors: { [Instance]: Door },
	Setup: (self: Public) -> (),
	Add: (self: Public, instance: Instance) -> (),
	Remove: (self: Public, instance: Instance) -> (),
	OpenPivot: (self: Public, door: Door, from: Vector3) -> CFrame,
	SetCollide: (self: Public, door: Door, closed: boolean) -> (),
	Animate: (self: Public, door: Door, open: boolean, from: Vector3?) -> (),
	Tick: (self: Public) -> (),
}

return {}
