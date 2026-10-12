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
	Exposure: number, -- Lighting.ExposureCompensation
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
	Cinematic: LightPreset, -- the opening cutscene only (Cutscenes[].Look): warm, contrasty, soft bloom and sun rays
	LobbyClock: number, -- ClockTime of the lobby (the user set it at night)
	NightClock: number, -- ClockTime of every night (§5.3: fixed near 0)
	GoldenFrom: number, -- hour the golden hour starts (§5.2: 4 PM)
	GoldenTo: number, -- hour it is full (6 PM)
	BlendTime: number, -- s of the smooth (eased) blend between two presets
}

local Table = require(script.Parent.Table)

const presets: LightPresets = {
	-- 2026-10-12 pass 2 (still blown out): Day Brightness 2.0 -> 1.3, Exposure 0 -> -0.5, EnvDiffuse 1 -> 0.6, Specular 0.8 -> 0.6, ambient darker,
	-- Haze 0.6 -> 0.35, Sat 0.2 -> 0.1, Contrast 0.05 -> 0.1, Bloom 0.5 -> 0.22; Golden 1.9 -> 1.25, Cinematic 2.4 -> 1.6, Lobby 1.6 -> 1.3 (nights untouched). PROVISIONAL.
	-- 2026-10-12 (owner: Studio "estourado", white clipping): Day Brightness 2.8 -> 2.0, Saturation 0.4 -> 0.2, Contrast 0.1 -> 0.05,
	-- Bloom 0.8 -> 0.5; Golden 2.4 -> 1.9, sat 0.35 -> 0.2, contrast 0.05, bloom 0.9 -> 0.6; Cinematic 3 -> 2.4, bloom 1.05 -> 0.8. PROVISIONAL.
	Day = {
		Brightness = 1.3,
		Exposure = -0.5,
		Ambient = Color3.fromRGB(86, 74, 64),
		OutdoorAmbient = Color3.fromRGB(110, 94, 80),
		ColorShiftTop = Color3.fromRGB(255, 226, 186),
		ColorShiftBottom = Color3.fromRGB(0, 0, 0),
		EnvDiffuse = 0.6,
		EnvSpecular = 0.6,
		ShadowSoftness = 0.25,
		AtmDensity = 0.35,
		AtmOffset = 1,
		AtmGlare = 1.2,
		AtmHaze = 0.35,
		AtmColor = Color3.fromRGB(214, 190, 168),
		AtmDecay = Color3.fromRGB(232, 170, 118),
		CCBrightness = 0,
		Saturation = 0.1,
		Contrast = 0.1,
		Tint = Color3.fromRGB(255, 244, 228),
		BloomIntensity = 0.22,
		BloomSize = 24,
		BloomThreshold = 2,
		SunRays = 0.03,
		SunRaysSpread = 0.1,
	},
	Golden = {
		Brightness = 1.25,
		Exposure = -0.45,
		Ambient = Color3.fromRGB(92, 70, 56),
		OutdoorAmbient = Color3.fromRGB(116, 86, 66),
		ColorShiftTop = Color3.fromRGB(255, 186, 116),
		ColorShiftBottom = Color3.fromRGB(0, 0, 0),
		EnvDiffuse = 0.6,
		EnvSpecular = 0.6,
		ShadowSoftness = 0.25,
		AtmDensity = 0.42,
		AtmOffset = 1,
		AtmGlare = 1.6,
		AtmHaze = 0.8,
		AtmColor = Color3.fromRGB(190, 146, 136),
		AtmDecay = Color3.fromRGB(226, 140, 82),
		CCBrightness = 0,
		Saturation = 0.12,
		Contrast = 0.1,
		Tint = Color3.fromRGB(255, 233, 210),
		BloomIntensity = 0.25,
		BloomSize = 24,
		BloomThreshold = 1.8,
		SunRays = 0.04,
		SunRaysSpread = 0.12,
	},
	Night1 = {
		Brightness = 0.6,
		Exposure = 0,
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
		Exposure = 0,
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
		-- Warm pass 2 (owner 2026-10-12: "lobby too cold"; then "same look as the run, still night, warm with a hint of unease"). All PROVISIONAL (Q-208). Brightness and ambient
		-- readable for 20-30 players, but moody: low warm-dark haze, deep plum shadows, amber pools of light against the dark; every blue/mauve tone moved to amber/peach/cream; shadows warm plum-brown (ColorShiftBottom).
		-- Before: Brightness 1.2, Ambient (95,70,55), Outdoor (120,90,70), Atm (176,124,124)/(122,70,82), Sat 0.15.
		Brightness = 1.3,
		Exposure = -0.3,
		Ambient = Color3.fromRGB(112, 82, 66),
		OutdoorAmbient = Color3.fromRGB(138, 102, 80),
		ColorShiftTop = Color3.fromRGB(240, 170, 112), -- soft amber
		ColorShiftBottom = Color3.fromRGB(52, 30, 30), -- warm plum-brown shadows (no blue)
		EnvDiffuse = 0.6,
		EnvSpecular = 0.5,
		ShadowSoftness = 0.2,
		AtmDensity = 0.32, -- moderate: the ~110x110 lobby stays clear, the far edge goes soft
		AtmOffset = 0.5,
		AtmGlare = 0.3,
		AtmHaze = 1.4,
		AtmColor = Color3.fromRGB(172, 116, 92), -- peach haze (not coral)
		AtmDecay = Color3.fromRGB(120, 64, 56), -- warm amber-plum horizon
		CCBrightness = 0.04,
		Saturation = 0.15,
		Contrast = 0.1,
		Tint = Color3.fromRGB(255, 226, 196), -- cream-amber
		BloomIntensity = 0.5, -- soft amber glow on the lobby neons (Bloom has no colour: the warmth comes from Tint)
		BloomSize = 28,
		BloomThreshold = 1.4,
		SunRays = 0,
		SunRaysSpread = 0.1,
	},
	-- Intro cutscene look (owner request 2026-10-12, PROVISIONAL): the Day preset pushed warmer and more contrasty, a
	-- softer wider bloom, stronger sun rays, a touch more haze for depth. LightController applies it while a scene
	-- with `Look = "Cinematic"` plays (blend over BlendTime) and takes it away at the end; the clock stays the day's.
	Cinematic = {
		Brightness = 1.6,
		Exposure = -0.4,
		Ambient = Color3.fromRGB(88, 74, 64),
		OutdoorAmbient = Color3.fromRGB(110, 92, 76),
		ColorShiftTop = Color3.fromRGB(255, 214, 160),
		ColorShiftBottom = Color3.fromRGB(0, 0, 0),
		EnvDiffuse = 0.7,
		EnvSpecular = 0.7,
		ShadowSoftness = 0.3,
		AtmDensity = 0.42,
		AtmOffset = 1,
		AtmGlare = 2.2,
		AtmHaze = 0.8,
		AtmColor = Color3.fromRGB(222, 192, 162),
		AtmDecay = Color3.fromRGB(238, 164, 108),
		CCBrightness = 0,
		Saturation = 0.3,
		Contrast = 0.15,
		Tint = Color3.fromRGB(255, 238, 212),
		BloomIntensity = 0.4,
		BloomSize = 34,
		BloomThreshold = 1.6,
		SunRays = 0.09,
		SunRaysSpread = 0.28,
	},
	LobbyClock = 20.75,
	NightClock = 0,
	GoldenFrom = 16,
	GoldenTo = 18,
	BlendTime = 3,
}

return Table.record(presets)
