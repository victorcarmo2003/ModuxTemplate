--!strict

type Sign = {
	Model: Instance,
	Tubes: { Tube },
	Known: { [BasePart]: true },
	Flicker: boolean,
	NextAt: number, -- os.clock() of the next step (burst start or next blink edge)
	Steps: { number }, -- durations of the running burst, alternating out / lit, starting with out
	Step: number, -- index into Steps; 0 = idle
	Sound: Sound?,
	Connections: { RBXScriptConnection },
}
type Tube = {
	Part: BasePart,
	Lit: Color3,
	Off: Color3?, -- the colour read back after this controller switched the part off; nil = not switched off
}

export type Public = {
	Rng: Random,
	Signs: { [Instance]: Sign },
	Setup: (self: Public) -> (),
	Track: (self: Public, sign: Sign, part: Instance) -> (),
	Add: (self: Public, model: Instance) -> (),
	Remove: (self: Public, model: Instance) -> (),
	SwitchOff: (self: Public, sign: Sign) -> (),
	SwitchOn: (self: Public, sign: Sign) -> (),
	EndBurst: (self: Public, sign: Sign, now: number) -> (),
	StartBurst: (self: Public, sign: Sign, now: number) -> (),
	Tick: (self: Public) -> (),
}

return {}
