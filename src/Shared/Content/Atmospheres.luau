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
--   Rain       cartoon drops around the camera (none under a roof), splashes on the ground, drips off the open
--              service / drive-thru window flaps (Vehicle attribute Shutter, server)
--   Showers    the rain is not steady: it comes in showers at random moments of the night (same on every client),
--              each one opening with a loud thunder clap + flash (owner 2026-10-21); a row without Showers rains
--              all night. Natural lightning strikes only while a shower is on
--   Lightning  one strike chance per Every window of server time (same strikes on every client), flash + late thunder;
--              a Near strike is a scare (brighter, thunder almost at once, camera jolt). /dev bolt forces one
--   Fog        every row is laid over Rules.Fog (the Silent Hill grey, owner 2026-10-21): a row's own Atm* fields win;
--              under a roof (trailer, restaurant) density and haze drop a little (Rules.Indoor) so the counter stays
--              legible; Rules.Curtain adds a ring of tall fog banks around the camera (seen through the windows)
--   MoonSize   Sky.MoonAngularSize while active (nil = untouched)
--   Sound      key of Content.Sounds looped on screen while active (volume follows the blend)
--
-- Base = the darker cold night of TASK-293 (LightPresets Night1..Night10). Every number PROVISIONAL
-- (frontend-coder, 2026-10-15; cartoon rain, lightning chances and fog 2026-10-21, Q-453) until the art-director's pass and the owner's Play. No red alert UI here; ATM-3 and ATM-7 are cartoon crimson/plum air, never blood (no splats, no drips, no saturated red).
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
	Drops: number, -- drops alive around the camera at full blend (part pool)
	Speed: { number }, -- min, max studs/s (straight down plus Wind)
	Wind: Vector3, -- studs/s added to every drop (slant)
	Length: number, -- studs, drop body (a stretched ball: the cartoon drop)
	Width: number, -- studs
	Transparency: number, -- 0..1
	Color: Color3,
	Splash: number, -- 0..1 chance a landing drop pops a cartoon splash (disc + three droplets)
	Drips: number, -- drips per second per stud of open window flap edge (0 = none)
}

export type Lightning = {
	Every: number, -- s of server time per strike window (at most one strike in each, at a random moment)
	Chance: number, -- 0..1 a window has a strike
	Near: number, -- 0..1 a strike is a near one (the scare)
	Flash: number, -- s of the flash (two quick pulses inside it)
	Exposure: number, -- ExposureCompensation added at the peak
	Brightness: number, -- Lighting.Brightness added at the peak
	Tint: Color3, -- ColorCorrection tint at the peak (cold white)
	FogGlow: number, -- 0..1 of Tint lerped into the fog colour at the peak (the fog lights up)
	ThunderDelay: { number }, -- min, max s between flash and thunder (far)
	Volume: number, -- thunder volume multiplier (far: played slower, a rumble)
	NearScale: number, -- flash multiplier of a near strike
	NearDelay: { number }, -- min, max s between flash and thunder (near: the crack comes almost at once)
	NearVolume: number, -- thunder volume multiplier (near; clamped by the scare cap)
	Shake: string, -- HorrorScenes.Rules.Shakes profile of a near strike
	ShakeScale: number,
}

export type Showers = {
	Every: number, -- s of server time per shower window (at most one shower in each, never across two)
	Chance: number, -- 0..1 a window has a shower
	Length: { number }, -- min, max s of a shower (<= Every)
	Fade: number, -- s the rain takes to come in / go away
	Near: boolean, -- the opening strike is a near one (louder crack, camera jolt) instead of a far one
}

export type Atmosphere = {
	Key: string,
	Name: string, -- English, dev/log only
	Light: LightOverride,
	PostScale: number,
	Rain: Rain?,
	Showers: Showers?, -- nil = the Rain falls all night
	Lightning: Lightning?, -- nil = no natural strikes (a forced one uses Rules.Strike)
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
	RainRadius: number, -- studs, drops fall inside this disc around the camera
	RainLead: number, -- 0..1 of RainRadius the disc centre is pushed along the camera look (drops where you look)
	RainHeight: number, -- studs above the camera where drops spawn
	Splashes: number, -- splash pool size
	SplashLife: number, -- s
	SplashSize: number, -- studs, final disc diameter
	DripRange: number, -- studs, window flaps farther than this from the camera do not drip
	DripGrow: number, -- s a drip hangs and swells on the edge before it falls
	RoofCheck: number, -- s between the camera roof raycasts (fog indoors)
	Fog: LightOverride, -- Atm* fields under every row (Silent Hill grey; a row's own fields win)
	Indoor: { Density: number, Haze: number, Fade: number }, -- multipliers under a roof, s of the blend
	Curtain: {
		Count: number, -- fog banks on the ring
		Radius: number, -- studs from the camera
		Height: number, -- studs of each bank, from Ground up
		Ground: number, -- Y of the street (MAP-01)
		Rate: number, -- puffs per second per bank at full blend
		Size: { number }, -- studs, puff size at birth and at death
		Lifetime: { number }, -- s
		Peak: number, -- transparency of a puff at its thickest
		Glow: number, -- LightEmission: the fog must read grey at night, not black
		Color: Color3,
	},
	ShowerAttribute: string, -- Workspace attribute "<server time start>:<length s>" of a forced shower (/dev shower)
	Strike: Lightning, -- bolt of a forced strike (/dev bolt, AtmosphereService:Strike) on a row without Lightning
	StrikeAttribute: string, -- Workspace attribute "<server time>:<0|1 near>" written by AtmosphereService:Strike
}

-- cartoon drops: chunky light-blue stretched balls, slower than real rain so the shape reads
const rain: Rain = {
	Drops = 170,
	Speed = { 46, 58 },
	Wind = Vector3.new(4, 0, 2),
	Length = 1.1,
	Width = 0.3,
	Transparency = 0.3,
	Color = Color3.fromRGB(170, 214, 255),
	Splash = 0.35,
	Drips = 1.6,
}

const storm: Rain = {
	Drops = 250,
	Speed = { 58, 72 },
	Wind = Vector3.new(14, 0, 6),
	Length = 1.3,
	Width = 0.32,
	Transparency = 0.28,
	Color = Color3.fromRGB(160, 206, 255),
	Splash = 0.4,
	Drips = 2.6,
}

-- showers: rare on a dry night (~1 in 2 windows of 150 s), most of the time on the rain / storm nights
const sparse: Showers = { Every = 150, Chance = 0.45, Length = { 25, 50 }, Fade = 4, Near = true }
const often: Showers = { Every = 80, Chance = 0.85, Length = { 35, 60 }, Fade = 4, Near = true }
const stormy: Showers = { Every = 70, Chance = 0.9, Length = { 40, 62 }, Fade = 3, Near = true }

-- storm bolt: a strike in ~3 of 4 windows of 16 s, 1 in 4 of them near (the scare)
const stormBolt: Lightning = {
	Every = 16,
	Chance = 0.75,
	Near = 0.25,
	Flash = 0.22,
	Exposure = 1.8,
	Brightness = 2.8,
	Tint = Color3.fromRGB(236, 242, 255),
	FogGlow = 0.55,
	ThunderDelay = { 0.8, 2.6 },
	Volume = 1,
	NearScale = 1.6,
	NearDelay = { 0.05, 0.2 },
	NearVolume = 1.6,
	Shake = "Jolt",
	ShakeScale = 0.8,
}

-- rain bolt: rare, far and soft (a glow behind the fog); a near one stays possible but rare
const rainBolt: Lightning = {
	Every = 40,
	Chance = 0.5,
	Near = 0.08,
	Flash = 0.18,
	Exposure = 0.9,
	Brightness = 1.2,
	Tint = Color3.fromRGB(226, 234, 255),
	FogGlow = 0.35,
	ThunderDelay = { 2, 4 },
	Volume = 0.6,
	NearScale = 1.4,
	NearDelay = { 0.08, 0.25 },
	NearVolume = 1.3,
	Shake = "Jolt",
	ShakeScale = 0.6,
}

-- Silent Hill fog under every row (owner 2026-10-21: "fog bem mais intensa ... estilo Silent Hill"): dense flat grey,
-- little haze tint, short sight. The night presets (LightPresets Night1..10) sit at density 0.72 blue-grey.
-- 2nd pass (owner 2026-10-21 print: "a névoa ainda está muito fraca"): denser and lighter grey, so it reads as fog
-- and not as darkness
const fog: LightOverride = {
	AtmDensity = 0.92,
	AtmOffset = 0.4,
	AtmHaze = 1,
	AtmGlare = 0,
	AtmColor = Color3.fromRGB(118, 122, 130),
	AtmDecay = Color3.fromRGB(96, 100, 108),
}

-- a row's Light over the fog: the row's own fields win
local function foggy(light: LightOverride): LightOverride
	const out = table.clone(light) :: { [string]: any }
	for field, value in fog :: { [string]: any } do
		if out[field] == nil then
			out[field] = value
		end
	end
	return out :: any
end

const base = Table.new({
	{
		Key = "ATM-1",
		Name = "Normal night",
		Light = foggy({}),
		PostScale = 1,
		Rain = rain,
		Showers = sparse,
		Sound = "amb_rain",
	},
	{
		-- clients only read up close: dark air, almost no ambient, weak posts (the reading minimum of style guide §5.3
		-- is waived on purpose for this one; the trailer interior lights are untouched)
		Key = "ATM-2",
		Name = "Pitch black",
		Light = foggy({
			Brightness = 0.08,
			Exposure = -0.6,
			Ambient = Color3.fromRGB(22, 19, 26),
			OutdoorAmbient = Color3.fromRGB(16, 14, 22),
			ColorShiftTop = Color3.fromRGB(28, 22, 18),
			AtmDensity = 0.82,
			AtmHaze = 0.4,
			AtmColor = Color3.fromRGB(10, 9, 14),
			AtmDecay = Color3.fromRGB(8, 6, 10),
			Saturation = -0.3,
			BloomIntensity = 0.55,
		}),
		PostScale = 0.35,
		Rain = rain,
		Showers = sparse,
		Sound = "amb_rain",
	},
	{
		-- cartoon crimson-plum fog (not blood): dense air, warm pink tint, a bit more contrast
		Key = "ATM-3",
		Name = "Red mist",
		Light = foggy({
			OutdoorAmbient = Color3.fromRGB(58, 34, 42),
			ColorShiftTop = Color3.fromRGB(120, 52, 54),
			AtmDensity = 0.84,
			AtmHaze = 2.6,
			AtmOffset = 0.2,
			AtmColor = Color3.fromRGB(120, 42, 58),
			AtmDecay = Color3.fromRGB(80, 26, 36),
			Saturation = -0.05,
			Contrast = 0.14,
			Tint = Color3.fromRGB(255, 216, 216),
		}),
		PostScale = 0.9,
		Rain = rain,
		Showers = sparse,
		Sound = "amb_rain",
	},
	{
		-- rain: cold grey-blue fog, glossy ground (full specular), cartoon rain, rare far lightning, rain bed
		Key = "ATM-4",
		Name = "Rain",
		Light = foggy({
			Brightness = 0.22,
			EnvSpecular = 1,
			EnvDiffuse = 0.85,
			AtmDensity = 0.86,
			AtmHaze = 1.2,
			AtmColor = Color3.fromRGB(70, 76, 88),
			AtmDecay = Color3.fromRGB(52, 56, 68),
			Saturation = -0.25,
			Tint = Color3.fromRGB(224, 230, 242),
		}),
		PostScale = 0.9,
		Rain = rain,
		Showers = often,
		Lightning = rainBolt,
		Sound = "amb_rain",
	},
	{
		-- storm: heavier slanted rain + frequent lightning, some of it near (the scare); the flash lights the fog up
		Key = "ATM-5",
		Name = "Storm",
		Light = foggy({
			Brightness = 0.18,
			EnvSpecular = 1,
			EnvDiffuse = 0.85,
			AtmDensity = 0.88,
			AtmHaze = 1.4,
			AtmColor = Color3.fromRGB(60, 64, 78),
			AtmDecay = Color3.fromRGB(44, 46, 58),
			Saturation = -0.3,
			Contrast = 0.14,
			Tint = Color3.fromRGB(218, 224, 240),
		}),
		PostScale = 0.85,
		Rain = storm,
		Showers = stormy,
		Lightning = stormBolt,
		Sound = "amb_rain",
	},
	{
		-- densest white fog: the queue "appears" out of it
		Key = "ATM-6",
		Name = "White fog",
		Light = foggy({
			OutdoorAmbient = Color3.fromRGB(58, 60, 70),
			AtmDensity = 0.94,
			AtmHaze = 0.2,
			AtmOffset = 0,
			AtmGlare = 0,
			AtmColor = Color3.fromRGB(150, 156, 168),
			AtmDecay = Color3.fromRGB(120, 126, 140),
			Saturation = -0.35,
			Contrast = -0.04,
			Tint = Color3.fromRGB(236, 238, 244),
		}),
		PostScale = 1,
		Rain = rain,
		Showers = sparse,
		Sound = "amb_rain",
	},
	{
		-- night 10: crimson sky and a big moon over a washed-out scene (the tint, not the saturation, carries the red)
		Key = "ATM-7",
		Name = "Blood moon",
		-- the moon must still read through the fog: lighter than the Silent Hill base
		Light = foggy({
			OutdoorAmbient = Color3.fromRGB(52, 30, 36),
			ColorShiftTop = Color3.fromRGB(150, 46, 40),
			AtmDensity = 0.6,
			AtmHaze = 1.8,
			AtmGlare = 0.6,
			AtmColor = Color3.fromRGB(128, 34, 42),
			AtmDecay = Color3.fromRGB(160, 40, 34),
			Saturation = -0.55,
			Contrast = 0.12,
			Tint = Color3.fromRGB(255, 204, 198),
		}),
		PostScale = 0.8,
		MoonSize = 32,
		Rain = rain,
		Showers = sparse,
		Sound = "amb_rain",
	},
} :: { Atmosphere })

const rules: Rules = {
	Attribute = "Atmosphere",
	Default = "ATM-1",
	Fallback = { "ATM-1", "ATM-1", "ATM-4", "ATM-2", "ATM-6", "ATM-3", "ATM-5", "ATM-2", "ATM-3", "ATM-7" },
	FadeIn = 6,
	FadeOut = 4,
	RainRadius = 34,
	RainLead = 0.45,
	RainHeight = 18,
	Splashes = 40,
	SplashLife = 0.32,
	SplashSize = 1.4,
	DripRange = 70,
	DripGrow = 0.35,
	RoofCheck = 0.25,
	Fog = fog,
	-- under a roof the fog thins a little (the counter is a few studs away: it stays legible); 2nd pass: was 0.55 / 0.4,
	-- it killed the fog seen from the trailer window
	Indoor = { Density = 0.9, Haze = 0.8, Fade = 0.8 },
	Curtain = {
		Count = 12,
		Radius = 30,
		Height = 16,
		Ground = 0.4,
		Rate = 2.5,
		Size = { 18, 30 },
		Lifetime = { 8, 12 },
		Peak = 0.7,
		Glow = 0.25,
		Color = Color3.fromRGB(150, 156, 166),
	},
	ShowerAttribute = "AtmosphereShower",
	Strike = stormBolt,
	StrikeAttribute = "AtmosphereStrike",
}

return Table.with(base, {
	Rules = Table.record(rules),
})
