--!strict
-- Neon tube signs (user request 2026-10-11; tools/assetplace/decor_mart.luau): Models tagged NeonSign (attribute
-- Color = lit colour, optional Flicker = true) made of Neon Parts ("Tube" cylinders, "Joint" balls). NeonController
-- (client, visual only) keeps them lit and, on Flicker signs, plays a sporadic neon failure: Material Neon <->
-- SmoothPlastic with the colour darkened. Owner: art-director. Numbers PROVISIONAL (frontend-coder).

export type Range = { number } -- {min, max}

export type Neon = {
	Tag: string, -- CollectionService tag of a sign Model
	FlickerAttribute: string, -- boolean attribute on the Model: this sign fails now and then
	ColorAttribute: string, -- Color3 attribute on the Model: lit colour (fallback for a part found already off)
	OverrideAttribute: string, -- boolean attribute (Model or Part): another system owns the look, hands off
	PartNames: { string }, -- tube parts (also any BasePart with Material Neon at discovery)
	OffMaterial: Enum.Material,
	OffDarken: number, -- 0..1: off colour = lit colour lerped toward black by this much
	Interval: Range, -- s between two failure bursts of one sign
	Blinks: Range, -- integer: short blinks per burst
	BlinkOff: Range, -- s each blink stays out
	BlinkOn: Range, -- s lit between two blinks
	LongOffChance: number, -- 0..1: the burst ends with a longer outage
	LongOff: number, -- s of that outage
	FlickerByDay: boolean, -- false = Flicker signs only fail at night
	Sound: string, -- key of Content.Sounds played at the sign when a burst starts
	SoundVolume: number, -- multiplier over the row Volume
	SoundRange: number, -- studs: the sound only plays within this distance of the camera
	-- Realistic lighting style blows Neon out (owner 2026-10-20): lit colours scaled by Scale (1 = untouched), on
	-- sign tubes and on loose Neon parts under the Workspace children named in Roots. Attribute marks a dimmed part.
	Dim: { Scale: number, Roots: { string }, Attribute: string },
}

const neon: Neon = {
	Tag = "NeonSign",
	FlickerAttribute = "Flicker",
	ColorAttribute = "Color",
	OverrideAttribute = "NeonOverride",
	PartNames = { "Tube", "Joint" },
	OffMaterial = Enum.Material.SmoothPlastic,
	OffDarken = 0.45,
	Interval = { 6, 14 },
	Blinks = { 2, 5 },
	BlinkOff = { 0.04, 0.14 },
	BlinkOn = { 0.04, 0.14 },
	LongOffChance = 0.35,
	LongOff = 0.6,
	FlickerByDay = true,
	Sound = "neon_click", -- SFX-133
	SoundVolume = 0.35,
	SoundRange = 60,
	Dim = { Scale = 0.75, Roots = { "LOBBY_Assets" }, Attribute = "NeonDimmed" },
}

return table.freeze(neon)
