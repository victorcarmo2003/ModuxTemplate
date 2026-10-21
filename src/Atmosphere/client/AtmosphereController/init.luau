--!strict
--[[
	AtmosphereController (TASK-275; DEC-257; design/anomalies-v2-proposal.md §4; Content.Atmospheres)

	Draws the night's atmosphere (ATM-#) over LightController's preset. Ambience only, nothing here feeds a rule.

	Source: Workspace attribute Content.Atmospheres.Rules.Attribute ("Atmosphere"), written by AtmosphereService
	(night start = the night's key, day = nil). Apply(key) is a local override for previews; Apply(nil) gives the
	attribute back.

	Stacking (src/Light is not touched): LightController writes its preset only when it changes (Heartbeat tick) and
	exposes it as `Applied`. Every frame, in a render step before the frame is drawn, this controller rewrites only
	the fields its atmosphere overrides, blended from `Applied` by Alpha (FadeIn at night start, FadeOut back to the
	day). When the fade-out ends the last write is exactly `Applied` again, so LightController owns everything after.
	A change of LightController's preset (night k blend, day) is seen as a new `Applied` and rewritten the same frame.
	ANM-010 (Hush) writes its fog on Heartbeat; on a night with an Atmosphere override the atmosphere wins the frame.

	Pieces (see Rain.luau, Lightning.luau):
	  * Light       overrides of Lighting / Atmosphere / ColorCorrection / Bloom (LightPresets field names)
	  * PostScale   Brightness of the street-post lights (StreetLight fixtures with an Order), restored at the end
	  * Rain        cells around the camera, each off when a roof is above the camera; splashes on the ground
	  * Lightning   one strike per server-time window (same on every client): flash + thunder; OnStrike(callback)
	  * MoonSize    Sky.MoonAngularSize, restored at the end
	  * Sound       looped bed (AudioController), volume follows Alpha

	A change of key while one is on fades the old one out, then the new one in.
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Rain = require(script.Rain)
local Lightning = require(script.Lightning)
local Flicker = require(script.Flicker)
local GroundFog = require(script.GroundFog)
local Dread = require(script.Dread)

type AtmosphereRow = Content.Atmosphere
type Preset = Content.LightPreset

const ATMOSPHERES = Content.Atmospheres
const RULES = ATMOSPHERES.Rules
const RENDER_STEP = "AtmosphereController"
const RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 2 -- after the camera moved (rain cells follow it)
const NO_ALPHA = -1 -- LastAlpha before the first write
const POST_REFRESH = 0.5 -- s between post-light rescans (LightController rescans fixtures on streaming)

const AtmosphereController = Modux.Controller(
	"AtmosphereController",
	{ Require = { "LightController", "AudioController", "PlaceController" }, Priority = 450 }
)

-- Field -> writer. Names are Content.LightPresets fields; each writer gets the LightController effects.
type Effects = { Atmosphere: Atmosphere?, ColorCorrection: ColorCorrectionEffect?, Bloom: BloomEffect? }
type Writer = (fx: Effects, value: any) -> ()

const WRITERS: { [string]: Writer } = {
	Brightness = function(_, v)
		Lighting.Brightness = v
	end,
	Exposure = function(_, v)
		Lighting.ExposureCompensation = v
	end,
	Ambient = function(_, v)
		Lighting.Ambient = v
	end,
	OutdoorAmbient = function(_, v)
		Lighting.OutdoorAmbient = v
	end,
	ColorShiftTop = function(_, v)
		Lighting.ColorShift_Top = v
	end,
	ColorShiftBottom = function(_, v)
		Lighting.ColorShift_Bottom = v
	end,
	EnvDiffuse = function(_, v)
		Lighting.EnvironmentDiffuseScale = v
	end,
	EnvSpecular = function(_, v)
		Lighting.EnvironmentSpecularScale = v
	end,
	ShadowSoftness = function(_, v)
		Lighting.ShadowSoftness = v
	end,
	AtmDensity = function(fx, v)
		if fx.Atmosphere then
			fx.Atmosphere.Density = v
		end
	end,
	AtmHaze = function(fx, v)
		if fx.Atmosphere then
			fx.Atmosphere.Haze = v
		end
	end,
	AtmOffset = function(fx, v)
		if fx.Atmosphere then
			fx.Atmosphere.Offset = v
		end
	end,
	AtmGlare = function(fx, v)
		if fx.Atmosphere then
			fx.Atmosphere.Glare = v
		end
	end,
	AtmColor = function(fx, v)
		if fx.Atmosphere then
			fx.Atmosphere.Color = v
		end
	end,
	AtmDecay = function(fx, v)
		if fx.Atmosphere then
			fx.Atmosphere.Decay = v
		end
	end,
	CCBrightness = function(fx, v)
		if fx.ColorCorrection then
			fx.ColorCorrection.Brightness = v
		end
	end,
	Saturation = function(fx, v)
		if fx.ColorCorrection then
			fx.ColorCorrection.Saturation = v
		end
	end,
	Contrast = function(fx, v)
		if fx.ColorCorrection then
			fx.ColorCorrection.Contrast = v
		end
	end,
	Tint = function(fx, v)
		if fx.ColorCorrection then
			fx.ColorCorrection.TintColor = v
		end
	end,
	BloomIntensity = function(fx, v)
		if fx.Bloom then
			fx.Bloom.Intensity = v
		end
	end,
	BloomSize = function(fx, v)
		if fx.Bloom then
			fx.Bloom.Size = v
		end
	end,
	BloomThreshold = function(fx, v)
		if fx.Bloom then
			fx.Bloom.Threshold = v
		end
	end,
}

-- Fields the lightning flash adds to (written while a storm is on even when the atmosphere does not override them)
const FLASH_FIELDS = table.freeze({ "Brightness", "Exposure", "CCBrightness", "Tint" })

local function mix(a: any, b: any, t: number): any
	if typeof(a) == "Color3" then
		return (a :: Color3):Lerp(b :: Color3, t)
	end
	return (a :: number) + ((b :: number) - (a :: number)) * t
end

local function attributeKey(): string?
	const value = Workspace:GetAttribute(RULES.Attribute)
	return if type(value) == "string" and value ~= "" and ATMOSPHERES.ByKey[value] ~= nil then value else nil
end

function AtmosphereController:Setup()
	self.Enabled = false :: boolean
	-- Apply(key) preview; nil = follow the attribute
	self.Override = nil :: string?
	self.HasOverride = false :: boolean
	-- key that should be shown
	self.Target = nil :: string?
	-- row being shown (kept while fading out)
	self.Current = nil :: AtmosphereRow?
	self.Alpha = 0 :: number
	-- fields written for Current
	self.Fields = {} :: { string }
	self.LastBase = nil :: Preset?
	self.LastAlpha = NO_ALPHA :: number
	self.LastFlash = 0 :: number
	self.Rain = nil :: Rain.Rain?
	self.Lightning = Lightning.new() :: Lightning.Lightning
	self.Sound = nil :: Sound?
	self.SoundBase = 0 :: number
	self.Sky = nil :: Sky?
	self.MoonOriginal = nil :: number?
	self.PostOriginals = setmetatable({}, { __mode = "k" }) :: { [Light]: number }
	self.NextPosts = 0 :: number
end

-- Public API ------------------------------------------------------------------------------------------------------

-- Local preview: shows `key` on this client only ("" = none); nil gives the server attribute back.
function AtmosphereController:Apply(key: string?)
	if key ~= nil and key ~= "" and ATMOSPHERES.ByKey[key] == nil then
		warn(`[AtmosphereController] unknown atmosphere "{key}"`)
		return
	end
	self.HasOverride = key ~= nil
	self.Override = if key == "" then nil else key
	self:Retarget()
end

-- Key being shown or faded in (nil = none).
function AtmosphereController:Get(): string?
	return self.Target
end

-- Blend 0..1 of the atmosphere on screen.
function AtmosphereController:Level(): number
	return self.Alpha
end

-- callback(serverTime) on each lightning strike seen by this client (ATM-5); returns a disconnect function.
function AtmosphereController:OnStrike(callback: (number) -> ()): () -> ()
	return self.Lightning:Listen(callback)
end

-- Internals -------------------------------------------------------------------------------------------------------

function AtmosphereController:Retarget()
	self.Target = if self.HasOverride then self.Override else attributeKey()
end

function AtmosphereController:Effects(): Effects
	const light = self.Dependencies.LightController
	return { Atmosphere = light.Atmosphere, ColorCorrection = light.ColorCorrection, Bloom = light.Bloom }
end

function AtmosphereController:Begin(row: AtmosphereRow)
	self.Current = row
	const fields: { string } = {}
	const seen: { [string]: boolean } = {}
	for field in row.Light :: { [string]: any } do
		if WRITERS[field] then
			table.insert(fields, field)
			seen[field] = true
		end
	end
	if row.Lightning then
		for _, field in FLASH_FIELDS do
			if not seen[field] then
				table.insert(fields, field)
			end
		end
	end
	self.Fields = fields
	self.LastAlpha = NO_ALPHA
	self.Lightning:Reset()
	if row.Rain then
		self.Rain = Rain.new(row.Rain, RULES)
	end
	if row.Sound then
		const sound = self.Dependencies.AudioController:Loop(row.Sound, nil, true)
		if sound then
			self.Sound = sound
			self.SoundBase = sound.Volume
			sound.Volume = 0
		end
	end
	if row.MoonSize then
		const sky = Lighting:FindFirstChildOfClass("Sky")
		if sky then
			self.Sky = sky
			self.MoonOriginal = sky.MoonAngularSize
		end
	end
end

-- Puts back everything the row touched (the Lighting fields go back through Write with Alpha 0).
function AtmosphereController:Finish()
	const row = self.Current
	if row == nil then
		return
	end
	const base = self.Dependencies.LightController.Applied
	if base then
		self:Write(row, base, 0, 0)
	end
	self:ScalePosts(1, true)
	if self.Rain then
		self.Rain:Destroy()
		self.Rain = nil
	end
	if row.Sound then
		self.Dependencies.AudioController:Loop(row.Sound, nil, false)
	end
	self.Sound = nil
	const sky = self.Sky
	if sky and self.MoonOriginal then
		sky.MoonAngularSize = self.MoonOriginal
	end
	self.Sky = nil
	self.MoonOriginal = nil
	self.Current = nil
	self.Fields = {}
	self.LastBase = nil
end

function AtmosphereController:Write(row: AtmosphereRow, base: Preset, alpha: number, flash: number)
	const fx = self:Effects()
	const overrides = row.Light :: { [string]: any }
	const preset = base :: any
	const bolt = row.Lightning
	for _, field in self.Fields do
		const from = preset[field]
		const to = overrides[field]
		local value = if to ~= nil then mix(from, to, alpha) else from
		if bolt and flash > 0 then
			if field == "Brightness" then
				value += bolt.Brightness * flash
			elseif field == "Exposure" then
				value += bolt.Exposure * flash
			elseif field == "CCBrightness" then
				value += 0.12 * flash
			elseif field == "Tint" then
				value = (value :: Color3):Lerp(bolt.Tint, flash)
			end
		end
		WRITERS[field](fx, value)
	end
end

-- Street-post lights: Brightness x lerp(1, PostScale, alpha). restore = put the originals back and forget them.
function AtmosphereController:ScalePosts(scale: number, restore: boolean)
	const originals = self.PostOriginals
	if restore then
		for light, brightness in originals do
			if light.Parent ~= nil then
				light.Brightness = brightness
			end
		end
		table.clear(originals)
		return
	end
	for _, fixtures in self.Dependencies.LightController.Fixtures do
		for _, fixture in fixtures do
			if fixture.Order > 0 then
				for _, light in fixture.Lights do
					local original = originals[light]
					if original == nil then
						original = light.Brightness
						originals[light] = original
					end
					light.Brightness = original * scale
				end
			end
		end
	end
end

function AtmosphereController:Step(dt: number)
	-- target / fade
	const wanted = if self.Target then ATMOSPHERES.ByKey[self.Target] else nil
	const current = self.Current
	if current ~= nil and current ~= wanted then
		self.Alpha = math.max(0, self.Alpha - dt / RULES.FadeOut)
		if self.Alpha <= 0 then
			self:Finish()
		end
	elseif current == nil and wanted ~= nil then
		self:Begin(wanted)
	elseif current ~= nil then
		self.Alpha = math.min(1, self.Alpha + dt / RULES.FadeIn)
	end

	const row = self.Current
	if row == nil then
		return
	end
	const base = self.Dependencies.LightController.Applied
	if base == nil then
		return
	end
	const alpha = self.Alpha
	const eased = alpha * alpha * (3 - 2 * alpha)

	-- lightning (strikes only while the storm is mostly in)
	local flash = 0
	if row.Lightning then
		flash = self.Lightning:Step(row.Lightning, Workspace:GetServerTimeNow(), eased > 0.5, function()
			self.Dependencies.AudioController:Play("thunder")
		end)
	end

	if base ~= self.LastBase or eased ~= self.LastAlpha or flash ~= self.LastFlash then
		self.LastBase = base
		self.LastAlpha = eased
		self.LastFlash = flash
		self:Write(row, base, eased, flash)
	end

	-- posts
	if row.PostScale ~= 1 then
		const now = os.clock()
		if now >= self.NextPosts or eased < 1 then
			self.NextPosts = now + POST_REFRESH
			self:ScalePosts(1 + (row.PostScale - 1) * eased, false)
		end
	end

	-- moon, sound, rain
	const sky = self.Sky
	if sky and self.MoonOriginal and row.MoonSize then
		sky.MoonAngularSize = self.MoonOriginal + (row.MoonSize - self.MoonOriginal) * eased
	end
	const sound = self.Sound
	if sound then
		sound.Volume = self.SoundBase * eased
	end
	const rain = self.Rain
	if rain then
		rain:Step(eased)
	end
end

-- Lifecycle -------------------------------------------------------------------------------------------------------

AtmosphereController:OnInit(function(self)
	self:Setup()
end)

AtmosphereController:OnStart(function(self)
	if not self.Dependencies.PlaceController:Is("Run") then
		return
	end
	self.Enabled = true
	-- owner 2026-10-18: a kitchen tube flickers now and then at night, with light_flicker
	Flicker(self.Dependencies.LightController :: any, self.Dependencies.AudioController :: any)
	-- owner 2026-10-18: the low mist of the Hush on every night, by default
	GroundFog()
	-- owner 2026-10-19: the lights left off too long turn the place terrifying (VitalService DreadAttribute)
	Dread(self.Dependencies.AudioController :: any)
	self:Retarget()
	-- late joiner / reconnect: the night's atmosphere is already full
	if self.Target then
		const row = ATMOSPHERES.ByKey[self.Target]
		if row then
			self:Begin(row)
			self.Alpha = 1
		end
	end
	Workspace:GetAttributeChangedSignal(RULES.Attribute):Connect(function()
		self:Retarget()
	end)
	RunService:BindToRenderStep(RENDER_STEP, RENDER_PRIORITY, function(dt: number)
		self:Step(dt)
	end)
end)

return AtmosphereController
