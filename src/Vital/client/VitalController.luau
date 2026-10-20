--!strict
--[[
	VitalController (TASK-063; architecture.md §19.7 Client, network.md §13.1; FEAT-019, FEAT-025; DEC-038, 167)

	Presents what VitalService decides. Never changes sanity or life state locally.

	Sources:
	  Sanity, Max   own sanity (packet `Sanity`, only to the owner). Max = 0: no sanity (day), HUD hides the meter
	  Band          "Day" | "Mid" | "Night" from Content.Sanity.Bands (DEC-167); always "Day" while Max = 0
	  State         State[userId] of every run member (set `Vitals`, id = UserId); `StateOf(uid)` reads it
	  Members       the full `Vitals` record per member (StateEndsAt, KnockedUntil, Class) for Hud/Camera
	  LocalState    own life state ("Active" until the first record: wave 1 and day without VitalService)
	  Dark          predicted "in the dark" (see below)
	  Vignette, Blackout  what the screen layer shows (0..1)

	Screen layer (AST-084, Draft; only on this client, DEC-038; no red, no shake):
	  dark           vignette 0.25, Saturation -0.10
	  band Mid       vignette 0.20
	  band Night     vignette 0.35, Saturation -0.15, colder Tint
	  sanity < 25    vignette breathes at 0.5 Hz; rare Blur 4 for 0.4 s
	  Down (own)     edges close + Blur 4 in 1.5 s -> dark screen, then fades so the spectate view shows
	Effects only while the owner is `Active` (the faint is the only exception). The skin change by band is the
	server's `LookPack` (instant, no VFX) and is not touched here.

	Dark prediction (Provisional): the client has no `Zones` yet (TASK-059). The server sends `Sanity` at most once a
	second and only on change; a drop of up to 2 x DarkPerSecond counts as a dark tick, and the dark holds for
	DARK_HOLD seconds after the last one. Bigger drops (anomaly, broken rule) do not light the dark vignette.
	Swap for `Zones.IsLit(HRP)` over the `Lights` set when TASK-059 lands.

	Anomaly seen (user request 2026-10-10): the server sends no event for VitalService:SeeAnomaly, so a single drop of
	at least Sanity.SeeAnomaly and below Sanity.RuleBroken (dark ticks are <= 2 x DarkPerSecond) plays
	SoundRules.Stings.AnomalySeen (anomaly_see) on screen with the DEC-173 cap. Provisional: a packet would be exact.

	Sounds (user request 2026-10-10), never for the first record of a member (join / admission):
	  coffee_drink  own sanity goes up at night while Active (coffee is the only restore, VitalService:Drink). On
	                screen, at the end of the drink. Provisional: no packet for the use; dev "sanity" also rises.
	  faint         a member's record goes Active -> Down; at that member's character (spatial: crewmates nearby hear it)
	  revive        a member's record goes back to Active from Down / Reviving / Spectator; at the character

	Coffee payoff (TASK-479, owner feedback 2026-10-18 "more responsiveness, bigger feedback"; Provisional): on the
	server cue `Gain` (Amount > 0) a warm pulse of COFFEE.Time s on this client only: the dark edges lift, a soft
	Mustard-amber edge glow, a short warm / brighter ColorCorrection, and a burst of Cream sparkles + 2 steam wisps at
	the own head. Reduced motion (Motion.Reduced) keeps the colour fade and drops the particles. No red, no shake.
]]
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Vignette = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Vignette)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)

export type LifeState = "Active" | "Down" | "Reviving" | "Spectator" | "Away"
export type Band = "Day" | "Mid" | "Night"
export type Gain = { Amount: number, Id: number }

-- Fields of the Vitals record (network.md §13.1).
-- Smoothed screen values (the pulse and the faint go on top).
export type Shown = { Vignette: number, Saturation: number, Tint: number }

export type Member = {
	State: LifeState,
	StateEndsAt: number,
	KnockedUntil: number,
	Class: string,
}

-- Screen values from AST-084 (Draft, art-director). Art numbers, not game rules: no Content table for them.
const LOOK = table.freeze({
	Dark = table.freeze({ Vignette = 0.25, Saturation = -0.10 }),
	Mid = table.freeze({ Vignette = 0.20, Saturation = 0 }),
	Night = table.freeze({ Vignette = 0.35, Saturation = -0.15 }),
	SaturationFloor = -0.25, -- dark + Night together never wash the screen further
	Tint = Color3.fromHex("#DCE4FF"), -- "Tint mais frio": cold blue-white, never red
	PulseBelow = 25, -- sanity value under which the vignette breathes
	PulseHz = 0.5,
	PulseDepth = 0.2, -- +-20% of the vignette
	BlurSize = 4, -- style guide §10: Blur <= 4 for <= 0.5 s
	BlurTime = 0.4,
	BlurEvery = { 25, 45 }, -- seconds between two rare blurs (random in range)
	EnterTime = 1, -- "entra em 1 s"
	FaintIn = 1.5, -- edges + blur up to a dark screen
	FaintHold = 1,
	FaintOut = 1,
})

-- Coffee payoff (TASK-479). Art numbers, Provisional: warm, never red, under ~1.2 s.
const COFFEE = table.freeze({
	Time = 1.1, -- s of the whole pulse
	Rise = 0.12, -- s up to the peak, then it eases out
	Lift = 0.7, -- fraction of the dark edges taken away at the peak
	Glow = 0.4, -- warm edge opacity at the peak
	GlowColor = Color3.fromHex("#FFB84D"), -- Mustard-amber
	Saturation = 0.15,
	Brightness = 0.06,
	Tint = Color3.fromHex("#FFE9C4"), -- warm Cream
	Sparkles = 14,
	SparkleColor = Color3.fromHex("#FFF1D6"), -- Theme Cream
	SparkleAccent = Color3.fromHex("#F6C12B"), -- Theme Mustard
	Steam = 2,
	Life = 0.9, -- s a particle lives (the attachment goes after Life + 0.2)
})
const SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
const STEAM_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

const NO_TICK = -math.huge
const DARK_HOLD = 1.6 -- seconds after the last dark tick (server ticks at 1 Hz)
const EPSILON = 0.002
const COLOR_NAME = "VitalColor"
const BLUR_NAME = "VitalBlur"
const BANDS = Content.Sanity.Bands
const COFFEE_SOUND = "coffee_drink"
const FAINT_SOUND = "faint"
const REVIVE_SOUND = "revive"
const STATION_TAG = "Station"
const MACHINE_KIND = "coffee_machine"
const MACHINE_LIFT = 1.2 -- studs between the top of the machine and the arrow tip
const HINT_RETRY = 0.5 -- s between two looks for the machine while it is not in the Workspace yet
const COFFEE_AFTER_ACTIVE = 1 -- s: a rise this soon after coming back to Active is the revive resend, not coffee
-- Low-sanity whispers (DEC-293, owner 2026-10-18): while sanity is in the low band ("Night", below Sanity.Bands.Mid) the
-- character's own words on screen say what to do ("LOW SANITY", "DRINK COFFEE"...): a short burst every LOW_WHISPER_EVERY s.
const LOW_WHISPER_EVERY = 20
const LOW_WHISPER_FOR = 3
const LOW_WHISPER_RATE = 0.5
const LOW_WHISPER_FIRST = 4 -- s after entering the band before the first burst
local Whispers = require(StarterPlayer.StarterPlayerScripts.client.Anomaly.AnomalyController.Effects.Kit.Whispers)

local function approach(current: number, target: number, dt: number): number
	-- Exponential ease, ~98% of the way in EnterTime.
	const alpha = 1 - math.exp(-dt * 4 / LOOK.EnterTime)
	return current + (target - current) * alpha
end

const VitalController = Modux.Controller("VitalController", { Require = { "AudioController", "ObjectiveController" }, Priority = 800 })

function VitalController:Setup()
	self.Sanity = Vide.source(0) :: Vide.Source<number>
	self.Max = Vide.source(0) :: Vide.Source<number>
	self.Band = Vide.source("Day" :: Band) :: Vide.Source<Band>
	self.State = Vide.source({} :: { [number]: LifeState }) :: Vide.Source<{ [number]: LifeState }>
	self.Members = Vide.source({} :: { [number]: Member }) :: Vide.Source<{ [number]: Member }>
	self.LocalState = Vide.source("Active" :: LifeState) :: Vide.Source<LifeState>
	self.Dark = Vide.source(false) :: Vide.Source<boolean>
	self.Vignette = Vide.source(0) :: Vide.Source<number>
	self.Blackout = Vide.source(0) :: Vide.Source<number>
	-- Night 1 coffee lesson (server cue SanityCue): the HUD ring is on while true; the last coffee gain (new table per gain)
	self.CoffeeHint = Vide.source(false) :: Vide.Source<boolean>
	self.CoffeeGain = Vide.source(nil :: Gain?) :: Vide.Source<Gain?>
	self.GainId = 0 :: number
	self.HintUntil = 0 :: number -- server time the emphasis ends
	self.HintMachine = nil :: Instance? -- coffee machine marked by this emphasis
	self.CoffeeAt = nil :: number? -- os.clock of the last coffee payoff (TASK-479)
	-- warm edge glow 0..1
	self.Warm = Vide.source(0) :: Vide.Source<number>
	-- tip card of the last fall (FaintCause, DEC-317 etapa D); nil = none yet this night
	self.FaintTip = Vide.source(nil :: Content.FaintTip?) :: Vide.Source<Content.FaintTip?>

	self.DarkTickAt = NO_TICK :: number
	self.FaintAt = nil :: number?
	self.ActiveSince = 0 :: number
	self.NextBlurAt = 0 :: number
	self.BlurUntil = 0 :: number
	self.Shown = { Vignette = 0, Saturation = 0, Tint = 0 } :: Shown
	self.Color = nil :: ColorCorrectionEffect?
	self.Blur = nil :: BlurEffect?
	self.Gui = nil :: ScreenGui?
	self.Unmount = nil :: (() -> ())?
end

-- Band of a sanity value (DEC-167). Max = 0 (day) is always "Day".
function VitalController:BandOf(value: number, max: number): Band
	if max <= 0 or value >= BANDS.High then
		return "Day"
	elseif value >= BANDS.Mid then
		return "Mid"
	end
	return "Night"
end

-- Life state of a run member, reactive inside Vide scopes; nil = not a member (or no record yet).
function VitalController:StateOf(userId: number): LifeState?
	return self.State()[userId]
end

-- Own state is Active (or no Vitals record yet).
function VitalController:IsActive(): boolean
	return self.LocalState() == "Active"
end

function VitalController:ApplySanity(value: number, max: number)
	const previous = Vide.untrack(self.Sanity)
	const previousMax = Vide.untrack(self.Max)
	if max > 0 and previousMax > 0 and value < previous then
		if previous - value <= Content.Sanity.DarkPerSecond * 2 then
			self.DarkTickAt = os.clock()
		end
	end
	if max > 0 and previousMax > 0 then
		const drop = previous - value
		if drop >= Content.Sanity.SeeAnomaly and drop < Content.Sanity.RuleBroken then
			self.Dependencies.AudioController:Play(Content.SoundRules.Stings.AnomalySeen, nil, { Scare = true })
		end
		if
			value > previous
			and Vide.untrack(self.LocalState) == "Active"
			and os.clock() - self.ActiveSince >= COFFEE_AFTER_ACTIVE
		then
			self.Dependencies.AudioController:Play(COFFEE_SOUND)
		end
	end
	if max <= 0 then
		self.DarkTickAt = NO_TICK
	end
	Vide.batch(function()
		self.Sanity(value)
		self.Max(max)
		self.Band(self:BandOf(value, max))
	end)
end

-- Coffee lesson (Night 1) ----------------------------------------------------------------------------------------------

-- Coffee machine Model of the vehicle in use (tag Station, StationKind coffee_machine); nil while not streamed in
function VitalController:FindCoffeeMachine(): Instance?
	for _, station in CollectionService:GetTagged(STATION_TAG) do
		if station:GetAttribute("StationKind") == MACHINE_KIND and station:IsDescendantOf(workspace) then
			return station
		end
	end
	return nil
end

-- Server cue: emphasis on until `untilT` (server time) or an End / the first coffee. Arrow + Highlight on the machine.
function VitalController:BeginHint(untilT: number)
	self.HintUntil = untilT
	if Vide.untrack(self.CoffeeHint) then
		return
	end
	self.CoffeeHint(true)
	task.spawn(function()
		while Vide.untrack(self.CoffeeHint) do
			const objective = self.Dependencies.ObjectiveController
			if workspace:GetServerTimeNow() >= self.HintUntil then
				self:EndHint()
				return
			end
			if self.HintMachine == nil then
				const machine = self:FindCoffeeMachine()
				if machine ~= nil then
					self.HintMachine = machine
					objective:Mark(machine, MACHINE_LIFT)
				end
			end
			task.wait(HINT_RETRY)
		end
	end)
end

function VitalController:EndHint()
	if Vide.untrack(self.CoffeeHint) then
		self.CoffeeHint(false)
	end
	const machine = self.HintMachine
	self.HintMachine = nil
	-- only takes down our own mark (the objective of another system stays)
	if machine ~= nil and self.Dependencies.ObjectiveController.Beacon.Marked() == machine then
		self.Dependencies.ObjectiveController:Clear()
	end
end

function VitalController:ApplyCue(kind: string, amount: number, untilT: number)
	if kind == "Hint" then
		self:BeginHint(untilT)
	elseif kind == "Gain" then
		self.GainId += 1
		self.CoffeeGain({ Amount = amount, Id = self.GainId })
		if amount > 0 then
			self:CoffeePayoff()
		end
		self:EndHint()
	else
		self:EndHint()
	end
end

-- Coffee payoff (TASK-479) ---------------------------------------------------------------------------------------------

-- Starts the warm pulse (Step reads CoffeeAt) and, unless reduced motion, the sparkle + steam burst at the own head.
function VitalController:CoffeePayoff()
	self.CoffeeAt = os.clock()
	if Motion.Reduced() then
		return
	end
	const character = Players.LocalPlayer.Character
	const anchor = if character
		then character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
		else nil
	if anchor == nil or not anchor:IsA("BasePart") then
		return
	end
	const attachment = Instance.new("Attachment")
	attachment.Name = "CoffeeFx"
	attachment.Position = Vector3.new(0, 0.6, 0)

	const sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = SPARKLE_TEXTURE
	sparkle.Enabled = false
	sparkle.LightEmission = 0.6
	sparkle.LightInfluence = 0
	sparkle.Color = ColorSequence.new(COFFEE.SparkleColor, COFFEE.SparkleAccent)
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.Transparency = NumberSequence.new(0, 1)
	sparkle.Lifetime = NumberRange.new(COFFEE.Life * 0.6, COFFEE.Life)
	sparkle.Speed = NumberRange.new(3, 6)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Drag = 4
	sparkle.Acceleration = Vector3.new(0, 2, 0)
	sparkle.RotSpeed = NumberRange.new(-180, 180)
	sparkle.Parent = attachment

	const steam = Instance.new("ParticleEmitter")
	steam.Texture = STEAM_TEXTURE
	steam.Enabled = false
	steam.LightInfluence = 0
	steam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	steam.Size = NumberSequence.new(0.4, 1.2)
	steam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	steam.Lifetime = NumberRange.new(COFFEE.Life)
	steam.Speed = NumberRange.new(1.5, 2.5)
	steam.SpreadAngle = Vector2.new(20, 20)
	steam.EmissionDirection = Enum.NormalId.Top
	steam.Parent = attachment

	attachment.Parent = anchor
	sparkle:Emit(COFFEE.Sparkles)
	steam:Emit(COFFEE.Steam)
	task.delay(COFFEE.Life + 0.2, function()
		attachment:Destroy()
	end)
end

-- 0..1 strength of the coffee pulse now: quick rise, eased fall; 0 when idle.
function VitalController:CoffeeAmount(now: number): number
	const at = self.CoffeeAt
	if at == nil then
		return 0
	end
	const t = now - at
	if t >= COFFEE.Time then
		self.CoffeeAt = nil
		return 0
	elseif t < COFFEE.Rise then
		const up = t / COFFEE.Rise
		return 1 - (1 - up) * (1 - up)
	end
	const down = (t - COFFEE.Rise) / (COFFEE.Time - COFFEE.Rise)
	return (1 - down) * (1 - down)
end

function VitalController:ApplyMember(userId: number, record: Member)
	const previous = Vide.untrack(self.State)[userId]
	if previous ~= nil and previous ~= record.State then
		self:PlayLifeSound(userId, previous, record.State)
	end
	const members = table.clone(Vide.untrack(self.Members))
	const states = table.clone(Vide.untrack(self.State))
	members[userId] = table.clone(record) :: Member
	states[userId] = record.State
	Vide.batch(function()
		self.Members(members)
		self.State(states)
		if userId == Players.LocalPlayer.UserId then
			self:SetLocalState(record.State)
		end
	end)
end

function VitalController:RemoveMember(userId: number)
	const members = table.clone(Vide.untrack(self.Members))
	const states = table.clone(Vide.untrack(self.State))
	members[userId] = nil
	states[userId] = nil
	Vide.batch(function()
		self.Members(members)
		self.State(states)
		if userId == Players.LocalPlayer.UserId then
			self:SetLocalState("Active")
		end
	end)
end

function VitalController:SetLocalState(state: LifeState)
	const previous = Vide.untrack(self.LocalState)
	if previous == state then
		return
	end
	if state == "Down" then
		self.FaintAt = os.clock()
	elseif state == "Active" then
		self.FaintAt = nil
		self.ActiveSince = os.clock()
		self.FaintTip(nil) -- back on my feet: the tip of that fall is over
	end
	self.LocalState(state)
end

-- faint / revive at the member's character; the own one falls back to the screen, a crewmate without a character
-- (streamed out, far away) plays nothing.
function VitalController:PlayLifeSound(userId: number, previous: LifeState, state: LifeState)
	local key: string? = nil
	if state == "Down" and previous ~= "Away" then
		key = FAINT_SOUND
	elseif state == "Active" and (previous == "Down" or previous == "Reviving" or previous == "Spectator") then
		key = REVIVE_SOUND
	end
	if key == nil then
		return
	end
	const player = Players:GetPlayerByUserId(userId)
	const character = if player then player.Character else nil
	const anchor = if character
		then character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
		else nil
	if anchor == nil and userId ~= Players.LocalPlayer.UserId then
		return
	end
	self.Dependencies.AudioController:Play(key, anchor)
end

-- 0..1 dark screen of the faint and how far the closing part is (0..1); (0, 0) when no faint is running.
function VitalController:FaintAmount(now: number): (number, number)
	const at = self.FaintAt
	if at == nil then
		return 0, 0
	end
	const t = now - at
	if t < LOOK.FaintIn then
		const closing = t / LOOK.FaintIn
		return closing * closing, closing
	elseif t < LOOK.FaintIn + LOOK.FaintHold then
		return 1, 1
	elseif t < LOOK.FaintIn + LOOK.FaintHold + LOOK.FaintOut then
		const opening = (t - LOOK.FaintIn - LOOK.FaintHold) / LOOK.FaintOut
		return 1 - opening, 0
	end
	self.FaintAt = nil
	return 0, 0
end

function VitalController:Effects(): (ColorCorrectionEffect, BlurEffect)
	local color = self.Color
	if color == nil or color.Parent == nil then
		const made = Instance.new("ColorCorrectionEffect")
		made.Name = COLOR_NAME
		made.Enabled = false
		made.Parent = Lighting
		color = made
		self.Color = made
	end
	local blur = self.Blur
	if blur == nil or blur.Parent == nil then
		const made = Instance.new("BlurEffect")
		made.Name = BLUR_NAME
		made.Size = 0
		made.Enabled = false
		made.Parent = Lighting
		blur = made
		self.Blur = made
	end
	return color :: ColorCorrectionEffect, blur :: BlurEffect
end

local function write(target: Vide.Source<number>, value: number)
	if math.abs(Vide.untrack(target) - value) > EPSILON or (value == 0 and Vide.untrack(target) ~= 0) then
		target(value)
	end
end

function VitalController:Step(dt: number)
	const now = os.clock()
	const max = Vide.untrack(self.Max)
	const sanity = Vide.untrack(self.Sanity)
	const active = Vide.untrack(self.LocalState) == "Active"
	const night = max > 0

	const dark = night and active and now - self.DarkTickAt <= DARK_HOLD
	if Vide.untrack(self.Dark) ~= dark then
		self.Dark(dark)
	end

	-- Targets of the steady layer.
	local vignette = 0
	local saturation = 0
	local tint = 0
	if night and active then
		const band = Vide.untrack(self.Band)
		if band == "Mid" then
			vignette = LOOK.Mid.Vignette
			saturation += LOOK.Mid.Saturation
		elseif band == "Night" then
			vignette = LOOK.Night.Vignette
			saturation += LOOK.Night.Saturation
			tint = 1
		end
		if dark then
			vignette = math.max(vignette, LOOK.Dark.Vignette)
			saturation += LOOK.Dark.Saturation
		end
		saturation = math.max(saturation, LOOK.SaturationFloor)
	end

	const shown = self.Shown
	shown.Vignette = approach(shown.Vignette, vignette, dt)
	shown.Saturation = approach(shown.Saturation, saturation, dt)
	shown.Tint = approach(shown.Tint, tint, dt)

	local edge = shown.Vignette
	local blurSize = 0
	const low = night and active and sanity < LOOK.PulseBelow
	if low then
		edge *= 1 + LOOK.PulseDepth * math.sin(now * 2 * math.pi * LOOK.PulseHz)
		if self.NextBlurAt == 0 then
			self.NextBlurAt = now + math.random(LOOK.BlurEvery[1], LOOK.BlurEvery[2])
		elseif now >= self.NextBlurAt then
			self.BlurUntil = now + LOOK.BlurTime
			self.NextBlurAt = now + math.random(LOOK.BlurEvery[1], LOOK.BlurEvery[2])
		end
		if now < self.BlurUntil then
			blurSize = LOOK.BlurSize
		end
	else
		self.NextBlurAt = 0
		self.BlurUntil = 0
	end

	-- coffee: the dark edges lift and a warm glow shows (own client only, while Active)
	const coffee = if active then self:CoffeeAmount(now) else 0
	edge *= 1 - COFFEE.Lift * coffee
	write(self.Warm, math.clamp(COFFEE.Glow * coffee, 0, 1))

	const blackout, closing = self:FaintAmount(now)
	edge = math.max(edge, closing)
	blurSize = math.max(blurSize, LOOK.BlurSize * closing)

	write(self.Vignette, math.clamp(edge, 0, 1))
	write(self.Blackout, math.clamp(blackout, 0, 1))

	const color, blur = self:Effects()
	const colorOn = math.abs(shown.Saturation) > EPSILON or shown.Tint > EPSILON or coffee > EPSILON
	if color.Enabled ~= colorOn then
		color.Enabled = colorOn
	end
	if colorOn then
		color.Saturation = shown.Saturation + COFFEE.Saturation * coffee
		color.Brightness = COFFEE.Brightness * coffee
		color.TintColor = Color3.new(1, 1, 1)
			:Lerp(LOOK.Tint, math.clamp(shown.Tint, 0, 1))
			:Lerp(COFFEE.Tint, math.clamp(coffee, 0, 1))
	end
	const blurOn = blurSize > 0.05
	if blur.Enabled ~= blurOn then
		blur.Enabled = blurOn
	end
	if blurOn then
		blur.Size = blurSize
	end
end

function VitalController:Mount(playerGui: Instance)
	const unmount, gui = Vide.root(function()
		return Vide.create("ScreenGui")({
			Name = "Vignette",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 0, -- under the HUD (1)

			Vignette({
				Strength = self.Vignette,
				Blackout = self.Blackout,
			}),
			-- coffee payoff: warm edge glow over the dark edges (TASK-479)
			Vignette({
				Name = "CoffeeGlow",
				Strength = self.Warm,
				Color = COFFEE.GlowColor,
			}),
		})
	end)
	self.Unmount = unmount
	self.Gui = gui
	gui.Parent = playerGui
end

-- What got me and how to get past it (Content.FaintTips): an anomaly cause reads its Journal page, unless the player
-- has not met it yet (no spoiler); suspense / dark / other causes have their own lines.
function VitalController:TipOf(cause: string, known: boolean): Content.FaintTip
	const tips = Content.FaintTips
	const kind, key = string.match(cause, "^([%w_]+):(.+)$")
	if kind == nil then
		return tips.Kinds[cause] or tips.Generic
	end
	if kind == "anomaly" or kind == "stare" or kind == "see" then
		if not known then
			return tips.Unknown
		end
		const page = Content.Journal.ByKey[key :: string]
		const row = Content.Anomalies.ByKey[key :: string]
		const title = if page then page.Title elseif row then row.Name else tips.Unknown.Title
		if kind == "stare" then
			return { Title = title, Tip = tips.Stare }
		end
		const fight = if page then page.Fight[1] else nil
		return { Title = title, Tip = fight or tips.Anomaly.Tip }
	end
	return tips.Kinds[kind :: string] or tips.Generic
end

VitalController:OnInit(function(self)
	self:Setup()

	const net = self.Libs.Net

	net.FaintCause:onClient(function(data)
		self.FaintTip(self:TipOf(data.Cause, data.Known))
	end)
	net.Sanity:onClient(function(data)
		self:ApplySanity(data.Value, data.Max)
	end)

	net.SanityCue:onClient(function(cue)
		self:ApplyCue(cue.Kind, cue.Amount, cue.Until)
	end)

	net.Vitals:onAdded(function(id, record)
		self:ApplyMember(id, record :: Member)
	end)

	net.Vitals:onChanged(function(id, record)
		self:ApplyMember(id, record :: Member)
	end)

	net.Vitals:onRemoved(function(id)
		self:RemoveMember(id)
	end)
end)

VitalController:OnStart(function(self)
	RunService.RenderStepped:Connect(function(dt: number)
		self:Step(dt)
	end)
	-- DEC-293: hints on screen while sanity is low (a night only: Max > 0; never while down or spectating)
	task.spawn(function()
		local nextAt = math.huge
		while true do
			task.wait(1)
			const low = Vide.untrack(self.Max) > 0
				and Vide.untrack(self.Band) == "Night"
				and Vide.untrack(self.LocalState) == "Active"
			if not low then
				nextAt = math.huge
			elseif nextAt == math.huge then
				nextAt = os.clock() + LOW_WHISPER_FIRST
			elseif os.clock() >= nextAt then
				nextAt = os.clock() + LOW_WHISPER_EVERY
				task.spawn(Whispers.Play, LOW_WHISPER_FOR, Content.HorrorScenes.Words.low_sanity, LOW_WHISPER_RATE)
			end
		end
	end)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return VitalController
