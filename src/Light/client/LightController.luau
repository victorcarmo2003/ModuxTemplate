--!strict
--[[
	LightController (TASK-060; architecture.md §19.6 Client, §12.5 T31; network.md §13.2; FEAT-020; DEC-126, DEC-189;
	style-guide.md §5.1-§5.3; AST-023, AST-036, AST-079)

	Draws the light the server decided. The game rule "dark" lives in LightService (LightZone volumes, T8); nothing
	here feeds a rule: this file only turns visible lamps on and off and sets the Lighting preset.

	  * Lights set (one record per Content.LightGroups row, id = IndexOf): On -> the group's fixtures light up
	    (Light.Enabled + Neon lamp parts). No record yet (LightService not running): fallback by the shift
	    (posts/mart lit at night, trailer interior lit at night on the trailer, Trailer Lights off).
	  * Hush (ANM-010): a Posts group with On = false at night is in the Hush; post Order o goes out at
	    At + o * Step (Content.LightGroups Step). Pure function of server time, so a late joiner sees the same posts.
	  * T31: every post keeps its Neon lamp; the real SpotLight only on every other post counted from the corner
	    (P-01 = highest Order included) and only within POST_LIGHT_RANGE of the camera. A post without a live real
	    light shows its Pool_Decal (On_Fake, AST-036) when lit.
	  * Lighting preset (style guide §5.2-§5.3): day locked on the "nice day" with ClockTime following the clock,
	    golden hour 4 -> 6 PM; night interpolated Night 1 -> Night 10. Changes blend over BLEND_TIME.

	Fixtures (binding, MAP-01 §16):
	  * StreetLight tag (Group, Order): every Light descendant + lamp parts.
	  * Vehicle tag: `Light_Interior` (AST-079 fitting on AST-027) -> trailer_interior. AST-079 is not modelled
	    yet: with no Light_Interior a local PointLight goes on top of the group's Block LightZone (LZ-1). PROVISIONAL.
	  * Instances with attribute Upgrade = <group.Upgrade> (UpgradePiece of AST-023, Light_Main/Light_String*) ->
	    that group (trailer_lights).
	  Lamp parts = BasePart with Material Neon at discovery, attribute Emissive = true, or a name with
	  bulb/neon/disc or ending in "lamp(s)". Off = SmoothPlastic Cream (AST-036: "de dia, Cream sem Neon").

	No input (the switch is a prompt, PromptController), no packet, never writes a set.
]]
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

type LightGroup = Content.LightGroup
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
	EnvDiffuse: number,
	EnvSpecular: number,
	ShadowSoftness: number,
	AtmDensity: number,
	AtmHaze: number,
	AtmColor: Color3,
	AtmDecay: Color3,
	Saturation: number,
	Contrast: number,
	Tint: Color3,
	BloomIntensity: number,
	BloomSize: number,
	BloomThreshold: number,
	SunRays: number,
}

const STREET_LIGHT_TAG = "StreetLight"
const VEHICLE_TAG = "Vehicle"
const LIGHT_ZONE_TAG = "LightZone"
const INTERIOR_FITTING = "Light_Interior" -- AST-027 fitting for AST-079 (bind_map01 warns while missing)
const DECAL_NAME = "Pool_Decal" -- AST-036 On_Fake
const EMISSIVE_ATTRIBUTE = "Emissive"
const POST_GROUP_DEFAULT = "juniper_posts"
const FALLBACK_NAME = "LightController_Fallback"

const TICK_RATE = 20 -- Hz: Hush steps of 1.5 s and preset blends stay smooth; each pass only writes on change
const POST_LIGHT_RANGE = 150 -- studs from the camera (T31)
const REAL_POST_EVERY = 2 -- T31: one real light every two posts (8 studs apart -> one per 16)
const BLEND_TIME = 3 -- seconds of preset blend on day <-> night and night k -> k+1
const DECAL_TRANSPARENCY = 0.6 -- Pool_Decal when shown (Cream translucent)
const NIGHT_CLOCK = 0 -- style guide §5.3: ClockTime fixed near 0
const GOLDEN_FROM = 16 -- 4:00 PM (style guide §5.2)
const GOLDEN_TO = 18 -- 6:00 PM
const DAY_CLOCK_MIN = 6.5 -- keep the sun above the horizon on the day shift
const DAY_CLOCK_MAX = 17.4
const HOURS = 24
const FIRST_NIGHT = 1
const LAST_NIGHT = Content.RunParams.Nights

-- Fallback interior light (AST-079 missing): PROVISIONAL values in the AST-079 sheet spirit (warm, shadowed)
const FALLBACK_RANGE = 14
const FALLBACK_BRIGHTNESS = 1.6
const FALLBACK_COLOR = Color3.fromHex("#FFE7C2")
const FALLBACK_DROP = 0.4 -- studs below the zone ceiling

const LAMP_OFF_MATERIAL = Enum.Material.SmoothPlastic
const LAMP_OFF_COLOR = Color3.fromHex("#EAD6B0") -- Cream (style guide §2.1)

-- Style guide §5.2 (day) and §5.3 (Night 1 / Night 10). GOLDEN and the night fields the guide leaves open
-- (ColorShift_Top, Bloom Size, Night 10 Contrast/colours) are PROVISIONAL (frontend-coder, TASK-060).
const DAY: Preset = {
	Brightness = 2.2,
	Ambient = Color3.fromHex("#8C8378"),
	OutdoorAmbient = Color3.fromHex("#A89E8E"),
	ColorShiftTop = Color3.fromHex("#FFF1D6"),
	EnvDiffuse = 0.5,
	EnvSpecular = 0.15,
	ShadowSoftness = 0.35,
	AtmDensity = 0.25,
	AtmHaze = 1,
	AtmColor = Color3.fromHex("#C7E6F5"),
	AtmDecay = Color3.fromHex("#F2D8B0"),
	Saturation = 0.1,
	Contrast = 0.05,
	Tint = Color3.new(1, 1, 1),
	BloomIntensity = 0.35,
	BloomSize = 24,
	BloomThreshold = 1.8,
	SunRays = 0.04,
}

const GOLDEN: Preset = {
	Brightness = 2,
	Ambient = Color3.fromHex("#8F7A6A"),
	OutdoorAmbient = Color3.fromHex("#B09078"),
	ColorShiftTop = Color3.fromHex("#FFC98A"),
	EnvDiffuse = 0.5,
	EnvSpecular = 0.15,
	ShadowSoftness = 0.35,
	AtmDensity = 0.28,
	AtmHaze = 1.2,
	AtmColor = Color3.fromHex("#E6C9B0"),
	AtmDecay = Color3.fromHex("#F2B27A"),
	Saturation = 0.12,
	Contrast = 0.06,
	Tint = Color3.fromHex("#FFF2E2"),
	BloomIntensity = 0.4,
	BloomSize = 24,
	BloomThreshold = 1.7,
	SunRays = 0.06,
}

const NIGHT_1: Preset = {
	Brightness = 0.6,
	Ambient = Color3.fromHex("#262B4A"),
	OutdoorAmbient = Color3.fromHex("#2A3058"),
	ColorShiftTop = Color3.fromHex("#3A4270"),
	EnvDiffuse = 0.5,
	EnvSpecular = 0.15,
	ShadowSoftness = 0.35,
	AtmDensity = 0.35,
	AtmHaze = 1.5,
	AtmColor = Color3.fromHex("#1E2448"),
	AtmDecay = Color3.fromHex("#0B0D1E"),
	Saturation = -0.2,
	Contrast = 0.08,
	Tint = Color3.fromHex("#D2DAFF"),
	BloomIntensity = 0.8,
	BloomSize = 24,
	BloomThreshold = 1.2,
	SunRays = 0,
}

const NIGHT_10: Preset = {
	Brightness = 0.4,
	Ambient = Color3.fromHex("#1E2240"), -- never below #1B2140 (style guide §5.3 reading minimum)
	OutdoorAmbient = Color3.fromHex("#202546"),
	ColorShiftTop = Color3.fromHex("#30385F"),
	EnvDiffuse = 0.5,
	EnvSpecular = 0.15,
	ShadowSoftness = 0.35,
	AtmDensity = 0.45,
	AtmHaze = 2.2,
	AtmColor = Color3.fromHex("#1E2448"),
	AtmDecay = Color3.fromHex("#0B0D1E"),
	Saturation = -0.3,
	Contrast = 0.08,
	Tint = Color3.fromHex("#C8D2FF"),
	BloomIntensity = 0.8,
	BloomSize = 24,
	BloomThreshold = 1.2,
	SunRays = 0,
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function blend(a: Preset, b: Preset, t: number): Preset
	if t <= 0 then
		return a
	elseif t >= 1 then
		return b
	end
	return {
		Brightness = lerp(a.Brightness, b.Brightness, t),
		Ambient = a.Ambient:Lerp(b.Ambient, t),
		OutdoorAmbient = a.OutdoorAmbient:Lerp(b.OutdoorAmbient, t),
		ColorShiftTop = a.ColorShiftTop:Lerp(b.ColorShiftTop, t),
		EnvDiffuse = lerp(a.EnvDiffuse, b.EnvDiffuse, t),
		EnvSpecular = lerp(a.EnvSpecular, b.EnvSpecular, t),
		ShadowSoftness = lerp(a.ShadowSoftness, b.ShadowSoftness, t),
		AtmDensity = lerp(a.AtmDensity, b.AtmDensity, t),
		AtmHaze = lerp(a.AtmHaze, b.AtmHaze, t),
		AtmColor = a.AtmColor:Lerp(b.AtmColor, t),
		AtmDecay = a.AtmDecay:Lerp(b.AtmDecay, t),
		Saturation = lerp(a.Saturation, b.Saturation, t),
		Contrast = lerp(a.Contrast, b.Contrast, t),
		Tint = a.Tint:Lerp(b.Tint, t),
		BloomIntensity = lerp(a.BloomIntensity, b.BloomIntensity, t),
		BloomSize = lerp(a.BloomSize, b.BloomSize, t),
		BloomThreshold = lerp(a.BloomThreshold, b.BloomThreshold, t),
		SunRays = lerp(a.SunRays, b.SunRays, t),
	}
end

-- Forward-only clock blend (17.4 -> 0 passes through dusk, never back through noon)
local function blendClock(a: number, b: number, t: number): number
	const forward = (b - a) % HOURS
	return (a + forward * math.clamp(t, 0, 1)) % HOURS
end

local function isLampName(name: string): boolean
	const lower = string.lower(name)
	if string.find(lower, "bulb", 1, true) or string.find(lower, "neon", 1, true) or string.find(lower, "disc", 1, true) then
		return true
	end
	return string.sub(lower, -4) == "lamp" or string.sub(lower, -5) == "lamps"
end

-- Lighting child of the class (the place's own, or a new one): the preset owns its values on this client
local function effect(className: string): any
	const found = Lighting:FindFirstChildOfClass(className :: any)
	if found then
		return found
	end
	const created = Instance.new(className :: any)
	created.Parent = Lighting
	return created
end

const LightController = Modux.Controller("LightController", { Require = { "RoundController" }, Priority = 500 })

function LightController:Setup()
	self.Records = {} :: { [string]: Record }
	self.Fixtures = {} :: { [string]: { Fixture } }
	self.Dirty = true :: boolean
	self.Watched = {} :: { [Instance]: { RBXScriptConnection } }
	-- original look of every lamp part, kept across rescans (a rescan sees the part already switched off)
	self.Originals = setmetatable({}, { __mode = "k" }) :: { [BasePart]: Lamp }
	self.Fallbacks = {} :: { [string]: Instance }
	self.Atmosphere = nil :: Atmosphere?
	self.ColorCorrection = nil :: ColorCorrectionEffect?
	self.Bloom = nil :: BloomEffect?
	self.SunRaysEffect = nil :: SunRaysEffect?
	-- preset state
	self.Applied = nil :: Preset?
	self.AppliedClock = DAY_CLOCK_MIN :: number
	self.From = nil :: Preset?
	self.FromClock = DAY_CLOCK_MIN :: number
	self.BlendStart = 0 :: number
	self.Mode = "" :: string -- "day" | "night:<k>"; a change starts a blend
end

-- Night number of the shift (RoundController.Night lands with TASK-055; until then first night).
function LightController:NightNumber(): number
	const getter: unknown = (self.Dependencies.RoundController :: any).Night
	if type(getter) == "function" then
		const value = (getter :: () -> unknown)()
		if typeof(value) == "number" and value >= FIRST_NIGHT then
			return math.min(value, LAST_NIGHT)
		end
	end
	return FIRST_NIGHT
end

-- Hour of the shift clock (0..24) from RoundController's interpolated clock; nil before the first record.
function LightController:Hour(): number?
	const round = self.Dependencies.RoundController
	const clock = round.Clock
	if clock == nil then
		return nil
	end
	if clock.ClockFrom == 0 and clock.ClockTo == 0 then
		return nil -- clock held (Resume, NightLost, RunEnd): keep the previous hour
	end
	return (round:MinutesAt(clock, Workspace:GetServerTimeNow()) / 60) % HOURS
end

-- Fixtures -------------------------------------------------------------------------------------------------------

function LightController:CollectLamps(root: Instance, out: { Lamp })
	const candidates: { Instance } = root:GetDescendants()
	table.insert(candidates, root)
	for _, d in candidates do
		if not d:IsA("BasePart") then
			continue
		end
		local original = self.Originals[d]
		if original == nil then
			if d.Transparency >= 1 then
				continue
			end
			const marked = d:GetAttribute(EMISSIVE_ATTRIBUTE) == true
			if not (marked or d.Material == Enum.Material.Neon or isLampName(d.Name)) then
				continue
			end
			original = { Part = d, Color = d.Color, Material = d.Material }
			self.Originals[d] = original
		end
		table.insert(out, original :: Lamp)
	end
end

function LightController:NewFixture(group: string, root: Instance, order: number): Fixture
	const lights: { Light } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Light") then
			table.insert(lights, d)
		end
	end
	if root:IsA("Light") then
		table.insert(lights, root)
	end
	const decals: { Decal } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Decal") and d.Name == DECAL_NAME then
			table.insert(decals, d)
		end
	end
	local position = Vector3.zero
	if root:IsA("PVInstance") then
		position = (root :: any):GetPivot().Position
	elseif root:IsA("Attachment") then
		position = root.WorldPosition
	end
	const fixture: Fixture = {
		Group = group,
		Order = order,
		Real = false,
		Position = position,
		Lights = lights,
		Lamps = {},
		Decals = decals,
		Lit = nil,
		Live = nil,
	}
	self:CollectLamps(root, fixture.Lamps)
	return fixture
end

function LightController:Add(fixture: Fixture)
	local list = self.Fixtures[fixture.Group]
	if list == nil then
		list = {}
		self.Fixtures[fixture.Group] = list
	end
	table.insert(list :: { Fixture }, fixture)
end

-- Rebuilds the fixture lists from the tags (cheap: a handful of models; runs only after a tag/descendant change).
function LightController:Rescan()
	self.Dirty = false
	table.clear(self.Fixtures)

	-- posts
	const posts: { Fixture } = {}
	local maxOrder = 0
	for _, post in CollectionService:GetTagged(STREET_LIGHT_TAG) do
		const group = post:GetAttribute("Group")
		const order = post:GetAttribute("Order")
		const fixture = self:NewFixture(
			if type(group) == "string" then group else POST_GROUP_DEFAULT,
			post,
			if type(order) == "number" then order else 0
		)
		maxOrder = math.max(maxOrder, fixture.Order)
		table.insert(posts, fixture)
		self:Add(fixture)
	end
	for _, fixture in posts do
		fixture.Real = (maxOrder - fixture.Order) % REAL_POST_EVERY == 0
	end

	-- vehicle fittings and upgrade pieces by group
	const upgradeGroup: { [string]: string } = {}
	const interiorGroups: { [string]: string } = {} -- vehicle key -> group key (Kind Switch)
	for _, group in Content.LightGroups.List do
		if group.Kind == "Upgrade" and group.Upgrade then
			upgradeGroup[group.Upgrade] = group.Key
		elseif group.Kind == "Switch" and group.Vehicle then
			interiorGroups[group.Vehicle] = group.Key
		end
	end
	const seenPieces: { [Instance]: boolean } = {}
	local function addPiece(piece: Instance)
		const upgrade = piece:GetAttribute("Upgrade")
		const key = if type(upgrade) == "string" then upgradeGroup[upgrade] else nil
		if key and not seenPieces[piece] then
			seenPieces[piece] = true
			self:Add(self:NewFixture(key, piece, 0))
		end
	end
	for _, vehicle in CollectionService:GetTagged(VEHICLE_TAG) do
		const vehicleKey = vehicle:GetAttribute("Vehicle")
		const interior = if type(vehicleKey) == "string" then interiorGroups[vehicleKey] else nil
		for _, d in vehicle:GetDescendants() do
			if interior and d.Name == INTERIOR_FITTING then
				const fixture = self:NewFixture(interior, d, 0)
				if #fixture.Lights == 0 and (d:IsA("Attachment") or d:IsA("BasePart")) then
					-- fitting without a light (AST-079 pending): local light on it. PROVISIONAL
					const light = self:FallbackLight()
					light.Parent = d
					table.insert(fixture.Lights, light)
				end
				self:Add(fixture)
			elseif d:GetAttribute("Upgrade") ~= nil then
				addPiece(d)
			end
		end
	end
	for _, piece in CollectionService:GetTagged("UpgradePiece") do
		addPiece(piece)
	end

	self:EnsureFallbacks()
end

function LightController:FallbackLight(): PointLight
	const light = Instance.new("PointLight")
	light.Name = FALLBACK_NAME
	light.Range = FALLBACK_RANGE
	light.Brightness = FALLBACK_BRIGHTNESS
	light.Color = FALLBACK_COLOR
	light.Shadows = true -- the only shadowed trailer light (style guide §5.1)
	light.Enabled = false
	return light
end

-- AST-079 not modelled: a local PointLight under the ceiling of the group's first Block LightZone. PROVISIONAL.
function LightController:EnsureFallbacks()
	for _, group in Content.LightGroups.List do
		if group.Kind ~= "Switch" then
			continue
		end
		const existing = self.Fallbacks[group.Key]
		const fixtures = self.Fixtures[group.Key]
		const hasReal = fixtures ~= nil and #(fixtures :: { Fixture }) > 0
		if hasReal then
			if existing then
				existing:Destroy()
				self.Fallbacks[group.Key] = nil
			end
			continue
		end
		local holder = existing
		if holder == nil or holder.Parent == nil then
			holder = nil
			for _, zone in CollectionService:GetTagged(LIGHT_ZONE_TAG) do
				if zone:GetAttribute("Group") == group.Key and zone:IsA("Part") and zone.Shape == Enum.PartType.Block then
					const attachment = Instance.new("Attachment")
					attachment.Name = FALLBACK_NAME
					attachment.Position = Vector3.new(0, zone.Size.Y / 2 - FALLBACK_DROP, 0)
					self:FallbackLight().Parent = attachment
					attachment.Parent = zone
					holder = attachment
					break
				end
			end
			self.Fallbacks[group.Key] = holder
		end
		if holder then
			self:Add(self:NewFixture(group.Key, holder, 0))
		end
	end
end

function LightController:Watch(instance: Instance)
	if self.Watched[instance] then
		return
	end
	const mark = function()
		self.Dirty = true
	end
	self.Watched[instance] = {
		instance.DescendantAdded:Connect(mark),
		instance.DescendantRemoving:Connect(mark),
	}
	self.Dirty = true
end

function LightController:Unwatch(instance: Instance)
	const connections = self.Watched[instance]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		self.Watched[instance] = nil
	end
	self.Dirty = true
end

function LightController:Track(tag: string, watch: boolean)
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		if watch then
			self:Watch(instance)
		end
		self.Dirty = true
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		if watch then
			self:Unwatch(instance)
		end
		self.Dirty = true
	end)
	if watch then
		for _, instance in CollectionService:GetTagged(tag) do
			self:Watch(instance)
		end
	end
end

-- Group state ----------------------------------------------------------------------------------------------------

-- Is the group lit now? No record -> fallback by the shift (the server has not written the group yet).
function LightController:GroupOn(key: string): boolean
	const record = self.Records[key]
	if record then
		return record.On
	end
	const group = Content.LightGroups.ByKey[key]
	const round = self.Dependencies.RoundController
	if group == nil or not round.IsNight() then
		return false
	end
	if group.Kind == "Upgrade" then
		return false
	elseif group.Kind == "Switch" then
		return group.Vehicle == nil or group.Vehicle == round.Vehicle()
	end
	return true
end

-- Lamp state of one fixture at `now` (Hush: posts go out by Order x Step since At).
function LightController:FixtureLit(fixture: Fixture, groupOn: boolean, now: number): boolean
	if groupOn then
		return true
	end
	const record = self.Records[fixture.Group]
	const group = Content.LightGroups.ByKey[fixture.Group]
	if record == nil or group == nil or group.Kind ~= "Posts" or group.Step <= 0 then
		return false
	end
	if not self.Dependencies.RoundController.IsNight() then
		return false
	end
	return now < record.At + fixture.Order * group.Step
end

function LightController:Paint(fixture: Fixture, lit: boolean, live: boolean)
	if fixture.Lit ~= lit then
		fixture.Lit = lit
		for _, lamp in fixture.Lamps do
			if lit then
				lamp.Part.Material = Enum.Material.Neon
				lamp.Part.Color = lamp.Color
			else
				lamp.Part.Material = LAMP_OFF_MATERIAL
				lamp.Part.Color = LAMP_OFF_COLOR
			end
		end
	end
	if fixture.Live ~= live then
		fixture.Live = live
		for _, light in fixture.Lights do
			light.Enabled = live
		end
	end
	const showDecal = lit and not live
	for _, decal in fixture.Decals do
		decal.Transparency = if showDecal then DECAL_TRANSPARENCY else 1
	end
end

function LightController:RefreshFixtures()
	if self.Dirty then
		self:Rescan()
	end
	const now = Workspace:GetServerTimeNow()
	const camera = Workspace.CurrentCamera
	const eye = if camera then camera.CFrame.Position else nil
	for key, fixtures in self.Fixtures do
		const groupOn = self:GroupOn(key)
		for _, fixture in fixtures do
			const lit = self:FixtureLit(fixture, groupOn, now)
			local live = lit
			if fixture.Order > 0 then
				live = lit
					and fixture.Real
					and (eye == nil or (fixture.Position - (eye :: Vector3)).Magnitude <= POST_LIGHT_RANGE)
			end
			self:Paint(fixture, lit, live)
		end
	end
end

-- Lighting preset ------------------------------------------------------------------------------------------------

function LightController:Target(): (Preset, number, string)
	const round = self.Dependencies.RoundController
	if round.IsNight() then
		const night = self:NightNumber()
		const t = if LAST_NIGHT > FIRST_NIGHT then (night - FIRST_NIGHT) / (LAST_NIGHT - FIRST_NIGHT) else 0
		return blend(NIGHT_1, NIGHT_10, t), NIGHT_CLOCK, `night:{night}`
	end
	const hour = self:Hour() or self.AppliedClock
	const golden = math.clamp((hour - GOLDEN_FROM) / (GOLDEN_TO - GOLDEN_FROM), 0, 1)
	return blend(DAY, GOLDEN, golden), math.clamp(hour, DAY_CLOCK_MIN, DAY_CLOCK_MAX), "day"
end

function LightController:Write(preset: Preset, clock: number)
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	Lighting.ColorShift_Top = preset.ColorShiftTop
	Lighting.EnvironmentDiffuseScale = preset.EnvDiffuse
	Lighting.EnvironmentSpecularScale = preset.EnvSpecular
	Lighting.ShadowSoftness = preset.ShadowSoftness
	Lighting.ClockTime = clock

	const atmosphere = self.Atmosphere :: Atmosphere
	atmosphere.Density = preset.AtmDensity
	atmosphere.Haze = preset.AtmHaze
	atmosphere.Color = preset.AtmColor
	atmosphere.Decay = preset.AtmDecay

	const correction = self.ColorCorrection :: ColorCorrectionEffect
	correction.Saturation = preset.Saturation
	correction.Contrast = preset.Contrast
	correction.TintColor = preset.Tint

	const bloom = self.Bloom :: BloomEffect
	bloom.Intensity = preset.BloomIntensity
	bloom.Size = preset.BloomSize
	bloom.Threshold = preset.BloomThreshold

	const rays = self.SunRaysEffect :: SunRaysEffect
	rays.Intensity = preset.SunRays
end

function LightController:RefreshPreset()
	const target, clock, mode = self:Target()
	const now = os.clock()
	const previous = self.Applied
	if previous == nil then
		-- first pass (join / reconnect): no blend, the late joiner sees the right sky at once
		self.Mode = mode
		self.Applied = target
		self.AppliedClock = clock
		self:Write(target, clock)
		return
	end
	if mode ~= self.Mode then
		self.Mode = mode
		self.From = previous
		self.FromClock = self.AppliedClock
		self.BlendStart = now
	end
	local preset = target
	local outClock = clock
	const from = self.From
	if from then
		const alpha = (now - self.BlendStart) / BLEND_TIME
		if alpha >= 1 then
			self.From = nil
		else
			preset = blend(from, target, alpha)
			outClock = blendClock(self.FromClock, clock, alpha)
		end
	end
	if preset == previous and outClock == self.AppliedClock then
		return
	end
	self.Applied = preset
	self.AppliedClock = outClock
	self:Write(preset, outClock)
end

-- Lifecycle ------------------------------------------------------------------------------------------------------

LightController:OnInit(function(self)
	self:Setup()

	const lights = self.Libs.Net.Lights
	const keys = Content.LightGroups.Keys
	const store = function(id: number, record: Record)
		const key = keys[id]
		if key then
			self.Records[key] = { On = record.On, At = record.At }
		end
	end
	lights:onAdded(store)
	lights:onChanged(function(id, record)
		store(id, record)
	end)
	lights:onRemoved(function(id)
		const key = keys[id]
		if key then
			self.Records[key] = nil
		end
	end)
end)

LightController:OnStart(function(self)
	self.Atmosphere = effect("Atmosphere") :: Atmosphere
	self.ColorCorrection = effect("ColorCorrectionEffect") :: ColorCorrectionEffect
	self.Bloom = effect("BloomEffect") :: BloomEffect
	self.SunRaysEffect = effect("SunRaysEffect") :: SunRaysEffect

	self:Track(STREET_LIGHT_TAG, true)
	self:Track(VEHICLE_TAG, true)
	self:Track("UpgradePiece", true)
	self:Track(LIGHT_ZONE_TAG, false)
end)

LightController:OnTick(function(self)
	if self.Atmosphere == nil then
		return
	end
	self:RefreshFixtures()
	self:RefreshPreset()
end, TICK_RATE)

return LightController
