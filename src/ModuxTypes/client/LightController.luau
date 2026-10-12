--!strict

type Record = { On: boolean, At: number }
type Lamp = { Part: BasePart, Color: Color3, Material: Enum.Material }
type Fixture = {
	Group: string,
	Order: number, -- StreetLight Order; 0 = not a post
	Real: boolean, -- T31: this post may carry a real light
	Position: Vector3,
	Lights: { Light },
	Lamps: { Lamp },
	Decals: { Decal },
	Lit: boolean?, -- last applied lamp state
	Live: boolean?, -- last applied real-light state
}
type Preset = {
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	ColorShiftTop: Color3,
	ColorShiftBottom: Color3,
	EnvDiffuse: number,
	EnvSpecular: number,
	ShadowSoftness: number,
	AtmDensity: number,
	AtmHaze: number,
	AtmOffset: number,
	AtmGlare: number,
	AtmColor: Color3,
	AtmDecay: Color3,
	CCBrightness: number,
	Saturation: number,
	Contrast: number,
	Tint: Color3,
	BloomIntensity: number,
	BloomSize: number,
	BloomThreshold: number,
	SunRays: number,
	SunRaysSpread: number,
}

export type Public = {
	Applied: Preset?,
	AppliedClock: number,
	Atmosphere: Atmosphere?,
	BlendStart: number,
	Bloom: BloomEffect?,
	ColorCorrection: ColorCorrectionEffect?,
	ContextAt: number,
	Dirty: boolean,
	Fallbacks: { [string]: Instance },
	Fixtures: { [string]: { Fixture } },
	From: Preset?,
	FromClock: number,
	Mode: string,
	Originals: { [BasePart]: Lamp },
	Records: { [string]: Record },
	SunRaysEffect: SunRaysEffect?,
	Watched: { [Instance]: { RBXScriptConnection } },
	Setup: (self: Public) -> (),
	NightNumber: (self: Public) -> number,
	Hour: (self: Public) -> number?,
	CollectLamps: (self: Public, root: Instance, out: { Lamp }) -> (),
	NewFixture: (self: Public, group: string, root: Instance, order: number) -> Fixture,
	Add: (self: Public, fixture: Fixture) -> (),
	Rescan: (self: Public) -> (),
	FallbackLight: (self: Public) -> PointLight,
	EnsureFallbacks: (self: Public) -> (),
	Watch: (self: Public, instance: Instance) -> (),
	Unwatch: (self: Public, instance: Instance) -> (),
	Track: (self: Public, tag: string, watch: boolean) -> (),
	GroupOn: (self: Public, key: string) -> boolean,
	FixtureLit: (self: Public, fixture: Fixture, groupOn: boolean, now: number) -> boolean,
	Paint: (self: Public, fixture: Fixture, lit: boolean, live: boolean) -> (),
	RefreshFixtures: (self: Public) -> (),
	Target: (self: Public) -> (Preset, number, string),
	BaseTarget: (self: Public) -> (Preset, number, string),
	Write: (self: Public, preset: Preset, clock: number) -> (),
	RefreshPreset: (self: Public) -> (),
	WatchContext: (self: Public) -> (),
	SwitchAnchor: (self: Public) -> Instance?,
	CheckSwitch: (self: Public, key: string, on: boolean) -> (),
}

return {}
