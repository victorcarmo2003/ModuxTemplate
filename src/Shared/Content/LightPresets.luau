--!strict
-- Lighting presets drawn by LightController (client, visual only; style-guide.md §5.2, §5.3; FEAT-020). Single
-- record. Owner: art-director. Warm pass (user request 2026-10-11: "iluminação geral no mapa do lobby e no mapa do
-- jogo, com cores quentes"): every number PROVISIONAL (frontend-coder) until the art-director reviews §5.
--
--   Day     the shift's day, locked until GoldenFrom (soft golden hour: cream tint, warm ambient, less blue air)
--   Golden  GoldenFrom -> GoldenTo, blended from Day by the shift clock
--   Night1  first night; Night10 last night; nights in between are interpolated. Dark and tense (light horror)
--           with a faint sodium-amber ambient; ambient luminance never below #1B2140 (§5.3 reading minimum)
--   Lobby   lobby servers (ServerRole Lobby / PrivateLobby): warm, cosy night, ClockTime fixed at LobbyClock
--
-- Never coral (#FF8A65) in any of these: reserved for the Mart's safe-spot neon (§2.4).
-- ANM-010 (the Hush) reads the applied preset to lay its fog over it; VitalController stacks its own effect on top.

export type LightPreset = {
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	ColorShiftTop: Color3,
	ColorShiftBottom: Color3,
	EnvDiffuse: number, -- Lighting.EnvironmentDiffuseScale
	EnvSpecular: number, -- Lighting.EnvironmentSpecularScale
	ShadowSoftness: number,
	AtmDensity: number, -- Atmosphere
	AtmHaze: number,
	AtmOffset: number,
	AtmGlare: number,
	AtmColor: Color3,
	AtmDecay: Color3,
	CCBrightness: number, -- ColorCorrectionEffect
	Saturation: number,
	Contrast: number,
	Tint: Color3,
	BloomIntensity: number, -- BloomEffect
	BloomSize: number,
	BloomThreshold: number,
	SunRays: number, -- SunRaysEffect
	SunRaysSpread: number,
}

export type LightPresets = {
	Day: LightPreset,
	Golden: LightPreset,
	Night1: LightPreset,
	Night10: LightPreset,
	Lobby: LightPreset,
	LobbyClock: number, -- ClockTime of the lobby (the user set it at night)
	NightClock: number, -- ClockTime of every night (§5.3: fixed near 0)
	GoldenFrom: number, -- hour the golden hour starts (§5.2: 4 PM)
	GoldenTo: number, -- hour it is full (6 PM)
	BlendTime: number, -- s of the smooth (eased) blend between two presets
}

local Table = require(script.Parent.Table)

const presets: LightPresets = {
	Day = {
		Brightness = 2.8,
		Ambient = Color3.fromRGB(104, 90, 78),
		OutdoorAmbient = Color3.fromRGB(132, 112, 94),
		ColorShiftTop = Color3.fromRGB(255, 226, 186),
		ColorShiftBottom = Color3.fromRGB(0, 0, 0),
		EnvDiffuse = 1,
		EnvSpecular = 0.8,
		ShadowSoftness = 0.25,
		AtmDensity = 0.4,
		AtmOffset = 1,
		AtmGlare = 1.6,
		AtmHaze = 0.6,
		AtmColor = Color3.fromRGB(214, 190, 168),
		AtmDecay = Color3.fromRGB(232, 170, 118),
		CCBrightness = 0.03,
		Saturation = 0.4,
		Contrast = 0.1,
		Tint = Color3.fromRGB(255, 244, 228),
		BloomIntensity = 0.8,
		BloomSize = 24,
		BloomThreshold = 2,
		SunRays = 0.04,
		SunRaysSpread = 0.1,
	},
	Golden = {
		Brightness = 2.4,
		Ambient = Color3.fromRGB(108, 82, 64),
		OutdoorAmbient = Color3.fromRGB(138, 102, 76),
		ColorShiftTop = Color3.fromRGB(255, 186, 116),
		ColorShiftBottom = Color3.fromRGB(0, 0, 0),
		EnvDiffuse = 1,
		EnvSpecular = 0.8,
		ShadowSoftness = 0.25,
		AtmDensity = 0.42,
		AtmOffset = 1,
		AtmGlare = 2.2,
		AtmHaze = 1.2,
		AtmColor = Color3.fromRGB(190, 146, 136),
		AtmDecay = Color3.fromRGB(226, 140, 82),
		CCBrightness = 0.02,
		Saturation = 0.35,
		Contrast = 0.1,
		Tint = Color3.fromRGB(255, 233, 210),
		BloomIntensity = 0.9,
		BloomSize = 24,
		BloomThreshold = 1.8,
		SunRays = 0.06,
		SunRaysSpread = 0.12,
	},
	Night1 = {
		Brightness = 0.6,
		Ambient = Color3.fromRGB(60, 48, 52), -- luminance ~50 (>= #1B2140 ~34)
		OutdoorAmbient = Color3.fromRGB(72, 56, 56),
		ColorShiftTop = Color3.fromRGB(92, 64, 42), -- faint sodium from above
		ColorShiftBottom = Color3.fromRGB(0, 0, 0),
		EnvDiffuse = 1,
		EnvSpecular = 1,
		ShadowSoftness = 0.2,
		AtmDensity = 0.35,
		AtmOffset = 1,
		AtmGlare = 0,
		AtmHaze = 1.5,
		AtmColor = Color3.fromRGB(58, 42, 64), -- purple-amber night air
		AtmDecay = Color3.fromRGB(72, 42, 26),
		CCBrightness = 0,
		Saturation = -0.15,
		Contrast = 0.1,
		Tint = Color3.fromRGB(244, 224, 206),
		BloomIntensity = 0.8,
		BloomSize = 24,
		BloomThreshold = 1.2,
		SunRays = 0,
		SunRaysSpread = 0.1,
	},
	Night10 = {
		Brightness = 0.4,
		Ambient = Color3.fromRGB(50, 40, 56), -- luminance ~43 (>= #1B2140 ~34)
		OutdoorAmbient = Color3.fromRGB(58, 46, 58),
		ColorShiftTop = Color3.fromRGB(72, 50, 36),
		ColorShiftBottom = Color3.fromRGB(0, 0, 0),
		EnvDiffuse = 1,
		EnvSpecular = 1,
		ShadowSoftness = 0.2,
		AtmDensity = 0.45,
		AtmOffset = 1,
		AtmGlare = 0,
		AtmHaze = 2.2,
		AtmColor = Color3.fromRGB(46, 34, 56),
		AtmDecay = Color3.fromRGB(48, 26, 18),
		CCBrightness = 0,
		Saturation = -0.25,
		Contrast = 0.1,
		Tint = Color3.fromRGB(232, 210, 198),
		BloomIntensity = 0.8,
		BloomSize = 24,
		BloomThreshold = 1.2,
		SunRays = 0,
		SunRaysSpread = 0.1,
	},
	Lobby = {
		Brightness = 1.2,
		Ambient = Color3.fromRGB(95, 70, 55),
		OutdoorAmbient = Color3.fromRGB(120, 90, 70),
		ColorShiftTop = Color3.fromRGB(224, 162, 110), -- soft amber
		ColorShiftBottom = Color3.fromRGB(48, 30, 22),
		EnvDiffuse = 0.7,
		EnvSpecular = 0.5,
		ShadowSoftness = 0.3,
		AtmDensity = 0.3, -- moderate: the ~60x60 lobby stays clear, the far edge goes soft
		AtmOffset = 0.5,
		AtmGlare = 0.4,
		AtmHaze = 1,
		AtmColor = Color3.fromRGB(176, 124, 124), -- muted peach-mauve (not coral)
		AtmDecay = Color3.fromRGB(122, 70, 82), -- warm purple
		CCBrightness = 0.02,
		Saturation = 0.15,
		Contrast = 0.08,
		Tint = Color3.fromRGB(255, 236, 215), -- cream-amber
		BloomIntensity = 0.6, -- soft glow on the lobby neons
		BloomSize = 28,
		BloomThreshold = 1.4,
		SunRays = 0,
		SunRaysSpread = 0.1,
	},
	LobbyClock = 20.75,
	NightClock = 0,
	GoldenFrom = 16,
	GoldenTo = 18,
	BlendTime = 3,
}

return Table.record(presets)
