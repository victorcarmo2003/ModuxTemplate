--!strict
-- Lighting presets drawn by LightController (client, visual only; style-guide.md §5.2, §5.3; FEAT-020). Single
-- record. Owner: art-director. Warm pass (user request 2026-10-11: "iluminação geral no mapa do lobby e no mapa do
-- jogo, com cores quentes"): every number PROVISIONAL (frontend-coder) until the art-director reviews §5.
--
--   Day     the shift's day, locked until GoldenFrom (soft golden hour: cream tint, warm ambient, less blue air)
--   Golden  GoldenFrom -> GoldenTo, blended from Day by the shift clock
--   Night1  first night; Night10 last night; nights in between are interpolated. Dark, cold and tense (light horror,
--           TASK-293): blue-grey ambient, the warm light comes from posts, signs and the trailer; ambient
--           luminance never below #1B2140 (§5.3 reading minimum)
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

-- ANM-020 total blackout in the restaurant (owner request 2026-10-17; values approved by the owner, darker than the style
-- guide on purpose, only while the power is out; PROVISIONAL until a DEC). Effects/Kit/Blackout.luau: the Lighting
-- fields below blend in over FadeIn s and back to the night values over FadeOut s; every Light / Neon / flame / SurfaceGui
-- under Roots goes off locally (SurfaceGuis keep showing at SignBrightness with SignLightInfluence), except what sits
-- under an instance named in KeepNames or with a MapId in KeepMapIds (the emergency lamp EMERG-P).
export type BlackoutLook = {
	Ambient: Color3,
	OutdoorAmbient: Color3,
	EnvDiffuse: number, -- Lighting.EnvironmentDiffuseScale
	EnvSpecular: number, -- Lighting.EnvironmentSpecularScale
	Brightness: number,
	Exposure: number, -- Lighting.ExposureCompensation
	FadeIn: number, -- s
	FadeOut: number, -- s
	SignBrightness: number, -- SurfaceGui.Brightness while dark
	SignLightInfluence: number, -- SurfaceGui.LightInfluence while dark (1 = follows the dark)
	Roots: { { string } }, -- Workspace paths darkened (besides the vehicle and the LightController fixtures)
	FlameName: string, -- parts / models with this name are flames (torches on the tables): hidden locally
	KeepNames: { string },
	KeepMapIds: { string },
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
	Blackout: BlackoutLook,
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
	-- TASK-293 (owner print 2026-10-15: "night looks like late afternoon"). Darker and cold: low Brightness and
	-- exposure, blue-grey ambient just above the §5.3 reading minimum (#1B2140, luminance ~34), dark blue air, cold
	-- tint, lower bloom threshold so the warm posts / signs / string lights / trailer read as the light sources.
	-- Before: Night1 Brightness 0.6, Exposure 0, Ambient (60,48,52), Outdoor (72,56,56), Atm (58,42,64) purple-amber,
	-- Sat -0.15, Tint (244,224,206); Night10 0.4, Ambient (50,40,56), Outdoor (58,46,58), Atm (46,34,56). PROVISIONAL.
	Night1 = {
		Brightness = 0.25,
		Exposure = -0.3,
		Ambient = Color3.fromRGB(36, 40, 60), -- luminance ~40 (>= #1B2140 ~34)
		OutdoorAmbient = Color3.fromRGB(32, 38, 62),
		ColorShiftTop = Color3.fromRGB(70, 84, 120), -- faint cold moonlight from above
		ColorShiftBottom = Color3.fromRGB(0, 0, 0),
		EnvDiffuse = 0.6,
		EnvSpecular = 0.8,
		ShadowSoftness = 0.2,
		AtmDensity = 0.38,
		AtmOffset = 1,
		AtmGlare = 0,
		AtmHaze = 1.2,
		AtmColor = Color3.fromRGB(24, 28, 46), -- dark blue night air
		AtmDecay = Color3.fromRGB(18, 20, 36),
		CCBrightness = -0.02,
		Saturation = -0.2,
		Contrast = 0.16,
		Tint = Color3.fromRGB(228, 234, 255), -- mild cold tint (warm lamps still read warm)
		BloomIntensity = 0.9,
		BloomSize = 24,
		BloomThreshold = 1,
		SunRays = 0,
		SunRaysSpread = 0.1,
	},
	Night10 = {
		Brightness = 0.18,
		Exposure = -0.4,
		Ambient = Color3.fromRGB(32, 35, 54), -- luminance ~35 (>= #1B2140 ~34)
		OutdoorAmbient = Color3.fromRGB(28, 32, 54),
		ColorShiftTop = Color3.fromRGB(56, 66, 100),
		ColorShiftBottom = Color3.fromRGB(0, 0, 0),
		EnvDiffuse = 0.6,
		EnvSpecular = 0.8,
		ShadowSoftness = 0.2,
		AtmDensity = 0.45,
		AtmOffset = 1,
		AtmGlare = 0,
		AtmHaze = 1.8,
		AtmColor = Color3.fromRGB(20, 22, 40),
		AtmDecay = Color3.fromRGB(14, 14, 28),
		CCBrightness = -0.03,
		Saturation = -0.28,
		Contrast = 0.18,
		Tint = Color3.fromRGB(220, 226, 252),
		BloomIntensity = 0.95,
		BloomSize = 24,
		BloomThreshold = 1,
		SunRays = 0,
		SunRaysSpread = 0.1,
	},
	Lobby = {
		-- TASK-313 (owner 2026-10-15, Play: "lobby too bright"). Same spirit as the TASK-293 night: a darker, cosy night,
		-- a touch cooler (dusky plum-grey air and ambient), so the warm light reads from the neon signs (START SHIFT,
		-- CODES), posts, string lights and pads; ambient kept readable for buttons, signs, pads and the path to them.
		-- Before (warm pass 2, 2026-10-12, Q-208): Brightness 1.3, Exposure -0.3, Ambient (112,82,66), Outdoor
		-- (138,102,80), ShiftTop (240,170,112), ShiftBottom (52,30,30), Atm 0.32/1.4 (172,116,92)/(120,64,56),
		-- CC 0.04/0.15/0.1 Tint (255,226,196), Bloom 0.5/28/1.4. All PROVISIONAL.
		Brightness = 0.55,
		Exposure = -0.45,
		Ambient = Color3.fromRGB(64, 56, 68), -- luminance ~59 (well above the #1B2140 reading minimum)
		OutdoorAmbient = Color3.fromRGB(68, 62, 82),
		ColorShiftTop = Color3.fromRGB(176, 128, 96), -- dimmer amber
		ColorShiftBottom = Color3.fromRGB(30, 24, 36), -- plum shadows, a little cooler
		EnvDiffuse = 0.6,
		EnvSpecular = 0.6,
		ShadowSoftness = 0.2,
		AtmDensity = 0.34, -- the ~110x110 lobby stays clear, the far edge goes soft
		AtmOffset = 0.5,
		AtmGlare = 0.2,
		AtmHaze = 1.2,
		AtmColor = Color3.fromRGB(70, 58, 76), -- dusky plum haze
		AtmDecay = Color3.fromRGB(84, 52, 58), -- dim amber-plum horizon
		CCBrightness = -0.01,
		Saturation = 0.05,
		Contrast = 0.14,
		Tint = Color3.fromRGB(246, 236, 236), -- near neutral, a hint cool (the warmth comes from the lights)
		BloomIntensity = 0.75, -- the neons and bulbs glow against the darker air
		BloomSize = 28,
		BloomThreshold = 1.1,
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
	Blackout = {
		Ambient = Color3.fromRGB(16, 17, 28),
		OutdoorAmbient = Color3.fromRGB(22, 26, 44),
		EnvDiffuse = 0.2,
		EnvSpecular = 0.35,
		Brightness = 0.15,
		Exposure = -0.45,
		FadeIn = 0.15,
		FadeOut = 1.2,
		SignBrightness = 0.1,
		SignLightInfluence = 1,
		Roots = { { "MAP01_Restaurant" }, { "MAP01_Assets", "Extra" } },
		FlameName = "Flame",
		KeepNames = { "Emergency" },
		KeepMapIds = { "EMERG-P" },
	},
}

return Table.record(presets)
