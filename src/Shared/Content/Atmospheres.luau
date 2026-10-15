--!strict
-- Night atmospheres ATM-1..ATM-7 (TASK-275; DEC-257; design/anomalies-v2-proposal.md §4). Owner: art-director (look)
-- + frontend-coder. Ambience only: nothing here feeds a game rule.
--
-- One atmosphere per night, fixed (DEC-257). AtmosphereService (server) picks the key of the night and publishes it
-- as the Workspace attribute `Rules.Attribute` ("Atmosphere"); AtmosphereController (client) lays the look over the
-- LightController night preset and takes it away when the attribute clears (day).
--   Key        "ATM-<n>", the ID used by Content.Nights (field `Atmosphere`, TASK-271) and by `/dev atmosphere`
--   Light      overrides of Content.LightPresets fields: a field present here REPLACES the night preset value,
--              blended in over Rules.FadeIn and out over Rules.FadeOut; absent fields keep the preset (empty = ATM-1)
--   PostScale  multiplier of the street-post lights' Brightness (StreetLight fixtures with an Order; 1 = untouched)
--   Rain       rain bound to the camera (cells above the camera, off under a roof) + splashes on the ground
--   Lightning  storm: one strike per Every window of server time (same strikes on every client), flash + late thunder
--   MoonSize   Sky.MoonAngularSize while active (nil = untouched)
--   Sound      key of Content.Sounds looped on screen while active (volume follows the blend)
--
-- Base = the darker cold night of TASK-293 (LightPresets Night1..Night10). Every number PROVISIONAL
-- (frontend-coder, 2026-10-15) until the art-director's pass and the owner's Play. No red alert UI here; ATM-3 and ATM-7 are cartoon crimson/plum air, never blood (no splats, no drips, no saturated red).
local Table = require(script.Parent.Table)

export type LightOverride = {
	Brightness: number?,
	Exposure: number?,
	Ambient: Color3?,
	OutdoorAmbient: Color3?,
	ColorShiftTop: Color3?,
	ColorShiftBottom: Color3?,
	EnvDiffuse: number?,
	EnvSpecular: number?,
	ShadowSoftness: number?,
	AtmDensity: number?,
	AtmHaze: number?,
	AtmOffset: number?,
	AtmGlare: number?,
	AtmColor: Color3?,
	AtmDecay: Color3?,
	CCBrightness: number?,
	Saturation: number?,
	Contrast: number?,
	Tint: Color3?,
	BloomIntensity: number?,
	BloomSize: number?,
	BloomThreshold: number?,
}

export type Rain = {
	Rate: number, -- drops per second per open cell
	Speed: { number }, -- min, max studs/s (straight down plus Wind)
	Wind: Vector3, -- studs/s added to every drop (slant)
	Length: number, -- drop length in studs (particle Size; the streak texture is a thin line, Squash narrows it)
	Transparency: number, -- 0..1, base of the drop
	Color: Color3,
	Splash: number, -- splashes per second per open cell (0 = none)
}

export type Lightning = {
	Every: number, -- s of server time per strike window (one strike in each)
	Flash: number, -- s of the flash (two quick pulses inside it)
	Exposure: number, -- ExposureCompensation added at the peak
	Brightness: number, -- Lighting.Brightness added at the peak
	Tint: Color3, -- ColorCorrection tint at the peak (cold white)
	ThunderDelay: { number }, -- min, max s between flash and thunder
}

export type Atmosphere = {
	Key: string,
	Name: string, -- English, dev/log only
	Light: LightOverride,
	PostScale: number,
	Rain: Rain?,
	Lightning: Lightning?,
	MoonSize: number?,
	Sound: string?,
}

export type Rules = {
	Attribute: string, -- Workspace attribute with the active key ("" / nil = none)
	Default: string, -- key used when a night row has no (or an unknown) Atmosphere
	-- night index -> key, used only while Content.Nights rows have no `Atmosphere` field (TASK-271 adds it);
	-- the §5 suggestion of the proposal (N5 never rain, DEC-251)
	Fallback: { string },
	FadeIn: number, -- s, night start (late joiner: at once)
	FadeOut: number, -- s, back to the day
	RainCell: number, -- studs, side of one rain cell
	RainCells: number, -- cells per side around the camera (odd)
	RainHeight: number, -- studs above the camera where drops spawn
	RoofCheck: number, -- s between roof raycasts
	RainTexture: string, -- T_VFX_RainStreak (original, docs/art/credits.md)
	SplashTexture: string, -- T_VFX_RainSplash (original)
}

const rain: Rain = {
	Rate = 70,
	Speed = { 70, 85 },
	Wind = Vector3.new(4, 0, 2),
	Length = 2.2,
	Transparency = 0.45,
	Color = Color3.fromRGB(196, 210, 230),
	Splash = 10,
}

const storm: Rain = {
	Rate = 110,
	Speed = { 85, 105 },
	Wind = Vector3.new(14, 0, 6),
	Length = 2.8,
	Transparency = 0.4,
	Color = Color3.fromRGB(190, 204, 226),
	Splash = 16,
}

const base = Table.new({
	{
		Key = "ATM-1",
		Name = "Normal night",
		Light = {},
		PostScale = 1,
	},
	{
		-- clients only read up close: dark air, almost no ambient, weak posts (the reading minimum of style guide §5.3
		-- is waived on purpose for this one; the trailer interior lights are untouched)
		Key = "ATM-2",
		Name = "Pitch black",
		Light = {
			Brightness = 0.08,
			Exposure = -0.6,
			Ambient = Color3.fromRGB(22, 19, 26),
			OutdoorAmbient = Color3.fromRGB(16, 14, 22),
			ColorShiftTop = Color3.fromRGB(28, 22, 18),
			AtmDensity = 0.6,
			AtmHaze = 0.4,
			AtmColor = Color3.fromRGB(10, 9, 14),
			AtmDecay = Color3.fromRGB(8, 6, 10),
			Saturation = -0.3,
			BloomIntensity = 0.55,
		},
		PostScale = 0.35,
	},
	{
		-- cartoon crimson-plum fog (not blood): dense air, warm pink tint, a bit more contrast
		Key = "ATM-3",
		Name = "Red mist",
		Light = {
			OutdoorAmbient = Color3.fromRGB(58, 34, 42),
			ColorShiftTop = Color3.fromRGB(120, 52, 54),
			AtmDensity = 0.6,
			AtmHaze = 2.6,
			AtmOffset = 0.2,
			AtmColor = Color3.fromRGB(120, 42, 58),
			AtmDecay = Color3.fromRGB(80, 26, 36),
			Saturation = -0.05,
			Contrast = 0.14,
			Tint = Color3.fromRGB(255, 216, 216),
		},
		PostScale = 0.9,
	},
	{
		-- rain: cold grey-blue air, glossy ground (full specular), rain on the camera, rain bed
		Key = "ATM-4",
		Name = "Rain",
		Light = {
			Brightness = 0.22,
			EnvSpecular = 1,
			EnvDiffuse = 0.85,
			AtmDensity = 0.46,
			AtmHaze = 1.9,
			AtmColor = Color3.fromRGB(34, 40, 56),
			AtmDecay = Color3.fromRGB(24, 28, 40),
			Saturation = -0.25,
			Tint = Color3.fromRGB(224, 230, 242),
		},
		PostScale = 0.9,
		Rain = rain,
		Sound = "amb_rain",
	},
	{
		-- storm: heavier slanted rain + lightning (flash 0.2 s, thunder 0.6-2.4 s later)
		Key = "ATM-5",
		Name = "Storm",
		Light = {
			Brightness = 0.18,
			EnvSpecular = 1,
			EnvDiffuse = 0.85,
			AtmDensity = 0.52,
			AtmHaze = 2.3,
			AtmColor = Color3.fromRGB(28, 32, 48),
			AtmDecay = Color3.fromRGB(20, 22, 34),
			Saturation = -0.3,
			Contrast = 0.14,
			Tint = Color3.fromRGB(218, 224, 240),
		},
		PostScale = 0.85,
		Rain = storm,
		Lightning = {
			Every = 18,
			Flash = 0.2,
			Exposure = 1.6,
			Brightness = 2.5,
			Tint = Color3.fromRGB(236, 242, 255),
			ThunderDelay = { 0.6, 2.4 },
		},
		Sound = "amb_rain",
	},
	{
		-- dense white fog: the queue "appears" out of it
		Key = "ATM-6",
		Name = "White fog",
		Light = {
			OutdoorAmbient = Color3.fromRGB(58, 60, 70),
			AtmDensity = 0.72,
			AtmHaze = 0.2,
			AtmOffset = 0,
			AtmGlare = 0,
			AtmColor = Color3.fromRGB(150, 156, 168),
			AtmDecay = Color3.fromRGB(120, 126, 140),
			Saturation = -0.35,
			Contrast = -0.04,
			Tint = Color3.fromRGB(236, 238, 244),
		},
		PostScale = 1,
	},
	{
		-- night 10: crimson sky and a big moon over a washed-out scene (the tint, not the saturation, carries the red)
		Key = "ATM-7",
		Name = "Blood moon",
		Light = {
			OutdoorAmbient = Color3.fromRGB(52, 30, 36),
			ColorShiftTop = Color3.fromRGB(150, 46, 40),
			AtmDensity = 0.42,
			AtmHaze = 1.8,
			AtmGlare = 0.6,
			AtmColor = Color3.fromRGB(128, 34, 42),
			AtmDecay = Color3.fromRGB(160, 40, 34),
			Saturation = -0.55,
			Contrast = 0.12,
			Tint = Color3.fromRGB(255, 204, 198),
		},
		PostScale = 0.8,
		MoonSize = 32,
	},
} :: { Atmosphere })

const rules: Rules = {
	Attribute = "Atmosphere",
	Default = "ATM-1",
	Fallback = { "ATM-1", "ATM-1", "ATM-4", "ATM-2", "ATM-6", "ATM-3", "ATM-5", "ATM-2", "ATM-3", "ATM-7" },
	FadeIn = 6,
	FadeOut = 4,
	RainCell = 20,
	RainCells = 5,
	RainHeight = 32,
	RoofCheck = 0.25,
	RainTexture = "rbxassetid://133719420594904",
	SplashTexture = "rbxassetid://140140944653214",
}

return Table.with(base, {
	Rules = Table.record(rules),
})
