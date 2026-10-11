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

	Screen layer (AST-084, Rascunho; only on this client, DEC-038; no red, no shake):
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
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Vignette = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Vignette)

export type LifeState = "Active" | "Down" | "Reviving" | "Spectator" | "Away"
export type Band = "Day" | "Mid" | "Night"

-- Fields of the Vitals record (network.md §13.1).
-- Smoothed screen values (the pulse and the faint go on top).
export type Shown = { Vignette: number, Saturation: number, Tint: number }

export type Member = {
	State: LifeState,
	StateEndsAt: number,
	KnockedUntil: number,
	Class: string,
}

-- Screen values from AST-084 (Rascunho, art-director). Art numbers, not game rules: no Content table for them.
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

const NO_TICK = -math.huge
const DARK_HOLD = 1.6 -- seconds after the last dark tick (server ticks at 1 Hz)
const EPSILON = 0.002
const COLOR_NAME = "VitalColor"
const BLUR_NAME = "VitalBlur"
const BANDS = Content.Sanity.Bands
const COFFEE_SOUND = "coffee_drink"
const FAINT_SOUND = "faint"
const REVIVE_SOUND = "revive"
const COFFEE_AFTER_ACTIVE = 1 -- s: a rise this soon after coming back to Active is the revive resend, not coffee

local function approach(current: number, target: number, dt: number): number
	-- Exponential ease, ~98% of the way in EnterTime.
	const alpha = 1 - math.exp(-dt * 4 / LOOK.EnterTime)
	return current + (target - current) * alpha
end

const VitalController = Modux.Controller("VitalController", { Require = { "AudioController" }, Priority = 800 })

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

	const blackout, closing = self:FaintAmount(now)
	edge = math.max(edge, closing)
	blurSize = math.max(blurSize, LOOK.BlurSize * closing)

	write(self.Vignette, math.clamp(edge, 0, 1))
	write(self.Blackout, math.clamp(blackout, 0, 1))

	const color, blur = self:Effects()
	const colorOn = math.abs(shown.Saturation) > EPSILON or shown.Tint > EPSILON
	if color.Enabled ~= colorOn then
		color.Enabled = colorOn
	end
	if colorOn then
		color.Saturation = shown.Saturation
		color.TintColor = Color3.new(1, 1, 1):Lerp(LOOK.Tint, math.clamp(shown.Tint, 0, 1))
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
		})
	end)
	self.Unmount = unmount
	self.Gui = gui
	gui.Parent = playerGui
end

VitalController:OnInit(function(self)
	self:Setup()

	const net = self.Libs.Net

	net.Sanity:onClient(function(data)
		self:ApplySanity(data.Value, data.Max)
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
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return VitalController
