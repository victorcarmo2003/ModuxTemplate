--!strict

type Signal = {
	Root: Instance,
	Axis: string,
	IsPed: boolean,
	Lamps: { Lamp }, -- head: [1] Red [2] Yellow [3] Green; ped: [1] Walk [2] Hand
	Count: number, -- lamps found (a late-streamed lamp triggers a rescan)
	Key: number, -- last painted phase * 10 + ped; -1 = repaint
	Link: RBXScriptConnection?,
}
type Lamp = {
	Part: BasePart,
	OnColor: Color3?,
	Lit: boolean?, -- last look written
}

export type Public = {
	Beat: RBXScriptConnection?,
	ByRoot: { [Instance]: Signal },
	Signals: { Signal },
	Setup: (self: Public) -> (),
	Add: (self: Public, root: Instance, isPed: boolean) -> (),
	Remove: (self: Public, root: Instance) -> (),
	Step: (self: Public) -> (),
}

return {}
