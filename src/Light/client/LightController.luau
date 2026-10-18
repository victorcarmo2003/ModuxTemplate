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
	  * Lighting preset (Content.LightPresets, warm pass 2026-10-11): lobby servers = Lobby (fixed night clock); game =
	    day locked with ClockTime following the clock, golden hour 4 -> 6 PM; night interpolated Night 1 -> Night 10.
	    While a cutscene with a Look plays (attribute CutsceneLook of the local player, set by CutsceneController) the
	    day preset is replaced by Content.LightPresets.Cinematic (owner request 2026-10-12) and comes back after it.
	    On a night shift (the intro of a run that starts on Night 1, DEC-300) the look is a late afternoon at
	    DuskClock with every lamp off; when it leaves (CutsceneNightfall = s of blend) the night comes over that time
	    and the lamps come on.
	    Changes blend (smoothstep) over BLEND_TIME; the first write happens in OnStart, without blend.

	Fixtures (binding, MAP-01 §16):
	  * StreetLight tag (Group, Order): every Light descendant + lamp parts.
	  * Vehicle tag: `Light_Interior` (AST-079 fitting on AST-027) -> trailer_interior. AST-079 is not modelled
	    yet: with no Light_Interior a local PointLight goes on top of the group's Block LightZone (LZ-1). PROVISIONAL.
	  * Instances with attribute Upgrade = <group.Upgrade> (UpgradePiece of AST-023, Light_Main/Light_String*) ->
	    that group (trailer_lights).
	  Lamp parts = BasePart with Material Neon at discovery, attribute Emissive = true, or a name with
	  bulb/neon/disc or ending in "lamp(s)". Off = SmoothPlastic Cream (AST-036: "de dia, Cream sem Neon").

	No input (the switch is a prompt, PromptController), no packet, never writes a set.

	Sound (user request 2026-10-10): `switch_click` at the switch (PromptAction switch_light in the current vehicle, else
	the group's first fixture) when a Switch group record flips by the party switch. The record also flips with the
	shift, the vehicle and the Hush, so the click needs, once the update batch landed: night, no night / attempt /
	vehicle change in the last CONTEXT_GRACE s, and every Always / Posts group on (day end and Hush put them out).
	Provisional: the server sends no event for the switch. Never on the first record (join).
]]
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
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
	Exposure: number,
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

const STREET_LIGHT_TAG = "StreetLight"
const VEHICLE_TAG = "Vehicle"
const LIGHT_ZONE_TAG = "LightZone"
const INTERIOR_FITTING = "Light_Interior" -- AST-027 fitting for AST-079 (bind_map01 warns while missing)
-- The trailer body's ceiling lamp mesh: while the vehicle has no Light_Interior, the interior light hangs under it
-- (owner 2026-10-15: the fallback used to land on the first LightZone found, LZ-2 at the back, not over the lamp)
const CEILING_LAMP = "Lamp_Ceiling"
const CEILING_DROP = 0.6 -- studs under the lamp mesh, so the shadowed light is not inside it
const DECAL_NAME = "Pool_Decal" -- AST-036 On_Fake
const EMISSIVE_ATTRIBUTE = "Emissive"
const POST_GROUP_DEFAULT = "juniper_posts"
const FALLBACK_NAME = "LightController_Fallback"
const SWITCH_ACTION = "switch_light" -- PromptAction of the switch anchor (LightService)
const SWITCH_SOUND = "switch_click"
const CONTEXT_GRACE = 1.5 -- s after a night / attempt / vehicle change in which a Switch flip is the shift's, not a click

const TICK_RATE = 20 -- Hz: Hush steps of 1.5 s and preset blends stay smooth; each pass only writes on change
const POST_LIGHT_RANGE = 150 -- studs from the camera (T31)
const REAL_POST_EVERY = 2 -- T31: one real light every two posts (8 studs apart -> one per 16)
const BLEND_TIME = Content.LightPresets.BlendTime -- s of preset blend on day <-> night and night k -> k+1
const DECAL_TRANSPARENCY = 0.6 -- Pool_Decal when shown (Cream translucent)
const NIGHT_CLOCK = Content.LightPresets.NightClock -- style guide §5.3: ClockTime fixed near 0
const GOLDEN_FROM = Content.LightPresets.GoldenFrom -- 4:00 PM (style guide §5.2)
const GOLDEN_TO = Content.LightPresets.GoldenTo -- 6:00 PM
const LOBBY_CLOCK = Content.LightPresets.LobbyClock
-- Lighting children owned by another controller (VitalController's sanity look): never taken as the preset's effect
const VITAL_EFFECTS = table.freeze({ VitalColor = true, VitalBlur = true } :: { [string]: boolean })
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

-- Presets live in Content.LightPresets (warm pass, user request 2026-10-11; PROVISIONAL). This controller is the only
-- writer of Lighting / Atmosphere / the place's ColorCorrection, Bloom and SunRays: ANM-010 lays its fog over
-- `Applied`, VitalController owns its own ColorCorrection (VITAL_EFFECTS) stacked on top.
const PRESETS = Content.LightPresets
const DAY: Preset = PRESETS.Day
const GOLDEN: Preset = PRESETS.Golden
const NIGHT_1: Preset = PRESETS.Night1
const NIGHT_10: Preset = PRESETS.Night10
const LOBBY: Preset = PRESETS.Lobby
const CINEMATIC: Preset = PRESETS.Cinematic
-- attribute of the local player CutsceneController sets while a scene with a Look plays (Content.Cutscenes[].Look)
const LOOK_ATTRIBUTE = "CutsceneLook"
-- s of blend into the night when the look leaves at a scene's Nightfall (DEC-300; set by CutsceneController)
const NIGHTFALL_ATTRIBUTE = "CutsceneNightfall"
const DUSK_CLOCK = Content.LightPresets.DuskClock

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
		Exposure = lerp(a.Exposure, b.Exposure, t),
		Ambient = a.Ambient:Lerp(b.Ambient, t),
		OutdoorAmbient = a.OutdoorAmbient:Lerp(b.OutdoorAmbient, t),
		ColorShiftTop = a.ColorShiftTop:Lerp(b.ColorShiftTop, t),
		ColorShiftBottom = a.ColorShiftBottom:Lerp(b.ColorShiftBottom, t),
		EnvDiffuse = lerp(a.EnvDiffuse, b.EnvDiffuse, t),
		EnvSpecular = lerp(a.EnvSpecular, b.EnvSpecular, t),
		ShadowSoftness = lerp(a.ShadowSoftness, b.ShadowSoftness, t),
		AtmDensity = lerp(a.AtmDensity, b.AtmDensity, t),
		AtmHaze = lerp(a.AtmHaze, b.AtmHaze, t),
		AtmOffset = lerp(a.AtmOffset, b.AtmOffset, t),
		AtmGlare = lerp(a.AtmGlare, b.AtmGlare, t),
		AtmColor = a.AtmColor:Lerp(b.AtmColor, t),
		AtmDecay = a.AtmDecay:Lerp(b.AtmDecay, t),
		CCBrightness = lerp(a.CCBrightness, b.CCBrightness, t),
		Saturation = lerp(a.Saturation, b.Saturation, t),
		Contrast = lerp(a.Contrast, b.Contrast, t),
		Tint = a.Tint:Lerp(b.Tint, t),
		BloomIntensity = lerp(a.BloomIntensity, b.BloomIntensity, t),
		BloomSize = lerp(a.BloomSize, b.BloomSize, t),
		BloomThreshold = lerp(a.BloomThreshold, b.BloomThreshold, t),
		SunRays = lerp(a.SunRays, b.SunRays, t),
		SunRaysSpread = lerp(a.SunRaysSpread, b.SunRaysSpread, t),
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

-- Lighting child of the class (the place's own, or a new one): the preset owns its values on this client.
-- Skips the effects other controllers own (VITAL_EFFECTS), so two systems never write the same instance.
local function effect(className: string): any
	for _, child in Lighting:GetChildren() do
		if child.ClassName == className and not VITAL_EFFECTS[child.Name] then
			return child
		end
	end
	const created = Instance.new(className :: any)
	created.Parent = Lighting
	return created
end

const LightController = Modux.Controller(
	"LightController",
	{ Require = { "RoundController", "AudioController", "PlaceController" }, Priority = 500 }
)

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
	self.BlendTime = BLEND_TIME :: number
	self.Mode = "" :: string -- "day" | "night:<k>"; a change starts a blend
	-- os.clock() of the last night / attempt / vehicle change (switch click guard)
	self.ContextAt = 0 :: number
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
		const hasFitting = vehicle:FindFirstChild(INTERIOR_FITTING, true) ~= nil
		for _, d in vehicle:GetDescendants() do
			if interior and not hasFitting and d.Name == CEILING_LAMP and d:IsA("BasePart") then
				-- no AST-079 fitting: the light hangs under the ceiling lamp, the lamp glows with it
				const fixture = self:NewFixture(interior, d, 0)
				if #fixture.Lights == 0 then
					const hook = Instance.new("Attachment")
					hook.Name = FALLBACK_NAME
					hook.Position = Vector3.new(0, -CEILING_DROP, 0)
					hook.Parent = d
					const light = self:FallbackLight()
					light.Parent = hook
					table.insert(fixture.Lights, light)
				end
				self:Add(fixture)
			elseif interior and d.Name == INTERIOR_FITTING then
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
			-- PadHideController: lights of the hidden cart / Pad stay off while the trailer is the vehicle
			light.Enabled = live and light:GetAttribute("PadHidden") ~= true
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
	-- the day look of a cutscene keeps every lamp off, also on a night shift (until its Nightfall, DEC-300)
	const daylight = Players.LocalPlayer:GetAttribute(LOOK_ATTRIBUTE) == "Cinematic"
	for key, fixtures in self.Fixtures do
		const groupOn = not daylight and self:GroupOn(key)
		for _, fixture in fixtures do
			const lit = not daylight and self:FixtureLit(fixture, groupOn, now)
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

-- Cutscene look on top of the day: the scene's own preset instead of the day one (same clock), blended like any change.
-- On a night shift (DEC-300: the run's intro on Night 1) the look holds a late afternoon (DuskClock) until the scene's
-- Nightfall takes it away.
function LightController:Target(): (Preset, number, string)
	const preset, clock, mode = self:BaseTarget()
	const look = Players.LocalPlayer:GetAttribute(LOOK_ATTRIBUTE)
	if look == "Cinematic" and mode == "day" then
		return CINEMATIC, clock, `look:{look}`
	elseif look == "Cinematic" and string.sub(mode, 1, 6) == "night:" then
		return CINEMATIC, DUSK_CLOCK, `look:{look}`
	end
	return preset, clock, mode
end

function LightController:BaseTarget(): (Preset, number, string)
	if self.Dependencies.PlaceController:Is("Lobby") then
		return LOBBY, LOBBY_CLOCK, "lobby"
	end
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
	Lighting.ExposureCompensation = preset.Exposure
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	Lighting.ColorShift_Top = preset.ColorShiftTop
	Lighting.ColorShift_Bottom = preset.ColorShiftBottom
	Lighting.EnvironmentDiffuseScale = preset.EnvDiffuse
	Lighting.EnvironmentSpecularScale = preset.EnvSpecular
	Lighting.ShadowSoftness = preset.ShadowSoftness
	Lighting.ClockTime = clock

	const atmosphere = self.Atmosphere :: Atmosphere
	atmosphere.Density = preset.AtmDensity
	atmosphere.Haze = preset.AtmHaze
	atmosphere.Offset = preset.AtmOffset
	atmosphere.Glare = preset.AtmGlare
	atmosphere.Color = preset.AtmColor
	atmosphere.Decay = preset.AtmDecay

	const correction = self.ColorCorrection :: ColorCorrectionEffect
	correction.Brightness = preset.CCBrightness
	correction.Saturation = preset.Saturation
	correction.Contrast = preset.Contrast
	correction.TintColor = preset.Tint

	const bloom = self.Bloom :: BloomEffect
	bloom.Intensity = preset.BloomIntensity
	bloom.Size = preset.BloomSize
	bloom.Threshold = preset.BloomThreshold

	const rays = self.SunRaysEffect :: SunRaysEffect
	rays.Intensity = preset.SunRays
	rays.Spread = preset.SunRaysSpread
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
		const nightfall = Players.LocalPlayer:GetAttribute(NIGHTFALL_ATTRIBUTE)
		self.BlendTime = if type(nightfall) == "number" and nightfall > 0 then nightfall else BLEND_TIME
	end
	local preset = target
	local outClock = clock
	const from = self.From
	if from then
		local alpha = (now - self.BlendStart) / self.BlendTime
		if alpha >= 1 then
			self.From = nil
		else
			alpha = alpha * alpha * (3 - 2 * alpha) -- smoothstep: eases in and out
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

-- Switch click ---------------------------------------------------------------------------------------------------

-- Marks every night / attempt / vehicle change (the Lights records that change with it are not a click)
function LightController:WatchContext()
	const round = self.Dependencies.RoundController
	Vide.root(function()
		local last = ""
		Vide.effect(function()
			const context = `{round.IsNight()}:{round.Night()}:{round.Attempt()}:{round.Vehicle()}`
			if context ~= last then
				last = context
				self.ContextAt = os.clock()
			end
		end)
	end)
end

-- Switch anchor of the current vehicle; nil when it is not streamed in
function LightController:SwitchAnchor(): Instance?
	const current = self.Dependencies.RoundController.Vehicle()
	for _, vehicle in CollectionService:GetTagged(VEHICLE_TAG) do
		if vehicle:GetAttribute("Vehicle") ~= current then
			continue
		end
		for _, d in vehicle:GetDescendants() do
			if d:GetAttribute("PromptAction") == SWITCH_ACTION and (d:IsA("BasePart") or d:IsA("Attachment")) then
				return d
			end
		end
	end
	return nil
end

-- A Switch group record flipped (deferred: the whole update batch is stored)
function LightController:CheckSwitch(key: string, on: boolean)
	const record = self.Records[key]
	if record == nil or record.On ~= on then
		return
	end
	if not self.Dependencies.RoundController.IsNight() or os.clock() - self.ContextAt < CONTEXT_GRACE then
		return
	end
	for _, group in Content.LightGroups.List do
		if group.Kind == "Always" or group.Kind == "Posts" then
			const other = self.Records[group.Key]
			if other == nil or not other.On then
				return
			end
		end
	end
	local at: Vector3 | Instance | nil = self:SwitchAnchor()
	if at == nil then
		const fixtures = self.Fixtures[key]
		if fixtures and fixtures[1] then
			at = fixtures[1].Position
		end
	end
	self.Dependencies.AudioController:Play(SWITCH_SOUND, at)
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
		const key = keys[id]
		const group = if key then Content.LightGroups.ByKey[key] else nil
		const previous = if key then self.Records[key] else nil
		store(id, record)
		if key == nil or group == nil or group.Kind ~= "Switch" then
			return
		end
		if previous ~= nil and previous.On ~= record.On then
			const on = record.On
			task.defer(function()
				self:CheckSwitch(key, on)
			end)
		end
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
	-- first write right away (no blend): the place's own Lighting (cold, edit-time) never shows past this point
	self:RefreshPreset()

	self:Track(STREET_LIGHT_TAG, true)
	self:Track(VEHICLE_TAG, true)
	self:Track("UpgradePiece", true)
	self:Track(LIGHT_ZONE_TAG, false)
	self:WatchContext()
end)

LightController:OnTick(function(self)
	if self.Atmosphere == nil then
		return
	end
	self:RefreshFixtures()
	self:RefreshPreset()
end, TICK_RATE)

return LightController
