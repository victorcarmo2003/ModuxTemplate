--!strict
-- World/Juice: the sweetness of the 3D prep (polish of 2026-10-12, decision 4 of the owner: "dopamina ALTA"). One small kit the
-- stages call when something good happens, so the feedback is the same everywhere:
--   Pop(part)           squash and stretch of a landing (an inert local Model or Part), settles in Rules.World.Juice.Pop.Time
--   Burst(kind, at)     particles: Dust, Sparks (Mustard), Steam, Crumbs, Confetti, Coins, Ring. Own budget (Juice.Particles,
--                       Juice.Emitters), apart from the 150 of KitchenController/Fx
--   Float(text, at)     a word that rises and fades over a point ("PERFECT"), at most Juice.Floats at once
--   Flash(target)       a short bright Highlight over an object (one of the Juice.Flashes instances kept out of the Highlight budget)
--   Streak              Perfects in a row (a Vide source the shell reads for its small chip); Note(band) feeds it
--   Tone(key, at, step) a sound with the pitch one step higher per Perfect in a row (Rules.World.Juice.Combo.Pitch)
-- Respects Motion.Reduced (no motion, no bursts: a still flash and a still word instead) and the low graphics quality (no bursts,
-- no flashes), and never exceeds its budget: what does not fit is dropped silently. Everything lives under the PrepWorld folder (the
-- floats are BillboardGuis in the PlayerGui, adorned to Parts of the folder) and goes with `Destroy`. No Modux, no network.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Haptics = require(StarterPlayer.StarterPlayerScripts.client.Input.Haptics)

export type Kind = "Dust" | "Sparks" | "Steam" | "Crumbs" | "Confetti" | "Coins" | "Ring"

export type Audio = (key: string, at: Vector3?, speed: number?) -> ()

export type Juice = {
	Pop: (self: Juice, target: Instance, strength: number?) -> (),
	Burst: (self: Juice, kind: Kind, at: Vector3, count: number?, color: Color3?) -> (),
	Float: (self: Juice, text: string, at: Vector3, color: Color3?, size: number?) -> (),
	Flash: (self: Juice, target: Instance?, color: Color3?) -> (),
	-- Perfects in a row after this band (a Perfect adds one, anything else resets); returns it.
	Note: (self: Juice, band: string) -> number,
	Tone: (self: Juice, key: string, at: Vector3?, steps: number?) -> (),
	-- The grade burst of a stage: sparks, flash, word and tone by band (Perfect strongest, Good lighter, Messy a puff).
	Grade: (self: Juice, band: string, at: Vector3, target: Instance?, word: string?) -> (),
	Step: (self: Juice, dt: number) -> (),
	Destroy: (self: Juice) -> (),
}

const source = Vide.source

const Juice = {}

-- The Perfects in a row, read by the shell chip (a module level source: it outlives one visit and is reset on Enter).
Juice.Streak = source(0) :: Vide.Source<number>

const TEXTURE = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

-- colours of food and gold, never red (palette of the house)
const MUSTARD = Theme.Color.Mustard
const CREAM = Theme.Color.Cream
const CRUMB = Color3.fromHex("#D9A35E")
const DUST = Color3.fromHex("#E8DCC4")
const CONFETTI = {
	ColorSequenceKeypoint.new(0, Theme.Color.Mustard),
	ColorSequenceKeypoint.new(0.25, Theme.Color.Cream),
	ColorSequenceKeypoint.new(0.5, Theme.Color.Teal),
	ColorSequenceKeypoint.new(0.75, Theme.Color.Green),
	ColorSequenceKeypoint.new(1, Theme.Color.Gold),
}

type Spec = {
	Texture: string,
	Lifetime: NumberRange,
	Speed: NumberRange,
	Spread: number,
	Size: NumberSequence,
	Acceleration: Vector3,
	LightEmission: number,
	Color: ColorSequence,
	Transparency: NumberSequence?,
	RotSpeed: number,
}

const FADE_OUT = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })

const SPECS: { [Kind]: Spec } = {
	Sparks = {
		Texture = TEXTURE.Sparkle,
		Lifetime = NumberRange.new(0.45, 0.8),
		Speed = NumberRange.new(2.5, 4.5),
		Spread = 80,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		Acceleration = Vector3.new(0, -4, 0),
		LightEmission = 0.8,
		Color = ColorSequence.new(MUSTARD, CREAM),
		Transparency = nil,
		RotSpeed = 180,
	},
	Dust = {
		Texture = TEXTURE.Smoke,
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(0.8, 1.8),
		Spread = 85,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.8) }),
		Acceleration = Vector3.new(0, 0.4, 0),
		LightEmission = 0,
		Color = ColorSequence.new(DUST),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		RotSpeed = 40,
	},
	Steam = {
		Texture = TEXTURE.Smoke,
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(0.8, 1.4),
		Spread = 25,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.1) }),
		Acceleration = Vector3.new(0, 1.2, 0),
		LightEmission = 0.1,
		Color = ColorSequence.new(Color3.fromHex("#F5F1EA")),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		RotSpeed = 30,
	},
	Crumbs = {
		Texture = TEXTURE.Sparkle,
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(1.5, 3),
		Spread = 60,
		Size = NumberSequence.new(0.1),
		Acceleration = Vector3.new(0, -14, 0),
		LightEmission = 0,
		Color = ColorSequence.new(CRUMB, CREAM),
		Transparency = FADE_OUT,
		RotSpeed = 200,
	},
	Confetti = {
		Texture = TEXTURE.Sparkle,
		Lifetime = NumberRange.new(0.9, 1.4),
		Speed = NumberRange.new(4, 7.5),
		Spread = 55,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0.14) }),
		Acceleration = Vector3.new(0, -9, 0),
		LightEmission = 0.25,
		Color = ColorSequence.new(CONFETTI),
		Transparency = FADE_OUT,
		RotSpeed = 360,
	},
	Coins = {
		Texture = TEXTURE.Sparkle,
		Lifetime = NumberRange.new(0.6, 0.85),
		Speed = NumberRange.new(4, 5.5),
		Spread = 30,
		Size = NumberSequence.new(0.3),
		Acceleration = Vector3.new(0, -16, 0),
		LightEmission = 0.4,
		Color = ColorSequence.new(MUSTARD),
		Transparency = FADE_OUT,
		RotSpeed = 120,
	},
	Ring = {
		Texture = TEXTURE.Sparkle,
		Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(3, 3.5),
		Spread = 180,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) }),
		Acceleration = Vector3.zero,
		LightEmission = 0.7,
		Color = ColorSequence.new(CREAM, MUSTARD),
		Transparency = nil,
		RotSpeed = 0,
	},
}

type PopEntry = { Target: Instance, Time: number, T: number, Amount: number, Base: number }

-- The scale a pop returns to. A model keeps it in the attribute `PopBase`, with the last scale a pop wrote in `PopLast`: while the
-- model still wears PopLast (a pop is wobbling or ended there) the base is the stored one, so a second pop that lands in the middle
-- of the first never takes the inflated scale for its base (the plate "grew" a little at every grade); a model somebody else
-- rescaled in the meantime (`ScaleTo` of a topping that grows) starts again from the scale it has now.
local function baseOf(model: Model): number
	const now = model:GetScale()
	const stored = model:GetAttribute("PopBase")
	const last = model:GetAttribute("PopLast")
	if type(stored) == "number" and type(last) == "number" and math.abs(now - last) < 1e-3 then
		return stored
	end
	model:SetAttribute("PopBase", now)
	model:SetAttribute("PopLast", now)
	return now
end

-- Writes a scale of a pop and remembers it (PopLast).
local function popScale(model: Model, scale: number)
	const wanted = math.max(scale, 0.01)
	model:ScaleTo(wanted)
	model:SetAttribute("PopLast", model:GetScale())
end
type FloatEntry = { Anchor: Part, Gui: BillboardGui, Label: TextLabel, T: number, Time: number, From: Vector3, Rise: number, Alive: boolean }
type FlashEntry = { Light: Highlight, T: number, Time: number, Fill: number, Alive: boolean }

local function lowQuality(): boolean
	const ok, level = pcall(function(): any
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok then
		return false
	end
	const value = (level :: Enum.SavedQualitySetting).Value
	return value ~= 0 and value <= Content.Prep.Rules.World.Budget.LowQuality
end

-- The no-op Juice used while the 3D world is not running (a stage can always call it).
function Juice.None(): Juice
	const none = {} :: any
	function none.Pop(_: any) end
	function none.Burst(_: any) end
	function none.Float(_: any) end
	function none.Flash(_: any) end
	function none.Note(_: any, _band: string): number
		return 0
	end
	function none.Tone(_: any) end
	function none.Grade(_: any) end
	function none.Step(_: any) end
	function none.Destroy(_: any) end
	return none :: Juice
end

function Juice.new(folder: Folder, rules: Content.PrepWorldRules, audio: Audio?): Juice
	const cfg = rules.Juice
	const reduced = Motion.Reduced()
	const low = lowQuality()
	const pops: { PopEntry } = {}
	const floats: { FloatEntry } = {}
	const flashes: { FlashEntry } = {}
	const spare: { Highlight } = {}
	const live: { { Expires: number, Count: number } } = {}
	local streak = 0
	Juice.Streak(0)
	local dead = false

	for _ = 1, cfg.Flashes do
		if low then
			break
		end
		const light = Instance.new("Highlight")
		light.Name = "JuiceFlash"
		light.FillColor = CREAM
		light.OutlineColor = MUSTARD
		light.FillTransparency = 1
		light.OutlineTransparency = 1
		-- a flash must be seen through the steam and the tool: it is short
		light.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		light.Enabled = false
		light.Parent = folder
		table.insert(spare, light)
	end

	local function liveParticles(): (number, number)
		const now = os.clock()
		local particles, emitters = 0, 0
		for index = #live, 1, -1 do
			const entry = live[index]
			if entry.Expires <= now then
				table.remove(live, index)
			else
				particles += entry.Count
				emitters += 1
			end
		end
		return particles, emitters
	end

	const self = {} :: any

	function self.Pop(_: any, target: Instance, strength: number?)
		if reduced or dead then
			return
		end
		for index = #pops, 1, -1 do
			if pops[index].Target == target then
				-- one pop per object: the older one ends where it stands
				const old = pops[index]
				if target:IsA("Model") and old.Target.Parent ~= nil then
					popScale(target, old.Base)
				end
				table.remove(pops, index)
			end
		end
		if #pops >= 6 then
			return
		end
		const base = if target:IsA("Model") then baseOf(target) else 1
		table.insert(pops, { Target = target, Time = cfg.Pop.Time, T = 0, Amount = cfg.Pop.Amount * (strength or 1), Base = base })
	end

	function self.Burst(_: any, kind: Kind, at: Vector3, count: number?, color: Color3?)
		if dead or low or reduced then
			return
		end
		const amount = count or 8
		if amount <= 0 then
			return
		end
		const spec = SPECS[kind]
		const particles, emitters = liveParticles()
		if particles + amount > cfg.Particles or emitters >= cfg.Emitters then
			return
		end
		const holder = Instance.new("Attachment")
		holder.Name = `Juice_{kind}`
		holder.WorldPosition = at
		holder.Parent = workspace.Terrain
		const emitter = Instance.new("ParticleEmitter")
		emitter.Texture = spec.Texture
		emitter.Color = if color ~= nil then ColorSequence.new(color) else spec.Color
		emitter.Lifetime = spec.Lifetime
		emitter.Speed = spec.Speed
		emitter.SpreadAngle = Vector2.new(spec.Spread, spec.Spread)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Size = spec.Size
		emitter.Acceleration = spec.Acceleration
		emitter.LightEmission = spec.LightEmission
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-spec.RotSpeed, spec.RotSpeed)
		if spec.Transparency ~= nil then
			emitter.Transparency = spec.Transparency
		end
		emitter.Rate = 0
		emitter.Enabled = false
		emitter.Parent = holder
		emitter:Emit(amount)
		table.insert(live, { Expires = os.clock() + spec.Lifetime.Max + 0.1, Count = amount })
		Debris:AddItem(holder, spec.Lifetime.Max + 0.3)
	end

	function self.Float(_: any, text: string, at: Vector3, color: Color3?, size: number?)
		if dead then
			return
		end
		-- the oldest word makes room
		if #floats >= cfg.Floats then
			const oldest = table.remove(floats, 1)
			if oldest ~= nil then
				oldest.Gui:Destroy()
				oldest.Anchor:Destroy()
			end
		end
		const anchor = Instance.new("Part")
		anchor.Name = "JuiceFloatAnchor"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.1
		anchor.Position = at
		anchor.Parent = folder
		const gui = Instance.new("BillboardGui")
		gui.Name = "JuiceFloat"
		gui.Adornee = anchor
		gui.AlwaysOnTop = true
		gui.Size = UDim2.fromOffset(220, 60)
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		const label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.FontFace = Theme.Font.Title
		label.TextSize = size or cfg.Float.Size
		label.Text = text
		label.TextColor3 = color or MUSTARD
		label.TextStrokeColor3 = Theme.Color.Ink
		label.TextStrokeTransparency = 0
		label.Parent = gui
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		table.insert(floats, {
			Anchor = anchor,
			Gui = gui,
			Label = label,
			T = 0,
			Time = cfg.Float.Time,
			From = at,
			Rise = if reduced then 0 else cfg.Float.Rise,
			Alive = true,
		})
	end

	function self.Flash(_: any, target: Instance?, color: Color3?)
		if dead or low or target == nil or target.Parent == nil then
			return
		end
		const light = table.remove(spare)
		if light == nil then
			return
		end
		light.Adornee = target
		light.FillColor = color or CREAM
		light.FillTransparency = cfg.Flash.Fill
		light.OutlineTransparency = 0
		light.Enabled = true
		table.insert(flashes, { Light = light, T = 0, Time = if reduced then cfg.Flash.Time * 1.4 else cfg.Flash.Time, Fill = cfg.Flash.Fill, Alive = true })
	end

	function self.Note(_: any, band: string): number
		if band == "Perfect" then
			streak += 1
		else
			streak = 0
		end
		Juice.Streak(streak)
		return streak
	end

	function self.Tone(_: any, key: string, at: Vector3?, steps: number?)
		if audio == nil then
			return
		end
		const step = math.clamp(steps or streak, 0, cfg.Combo.Cap)
		audio(key, at, 1 + cfg.Combo.Pitch * step)
	end

	function self.Grade(_: any, band: string, at: Vector3, target: Instance?, word: string?)
		if band == "Perfect" then
			const run = self:Note(band)
			self:Burst("Sparks", at, 14, MUSTARD)
			self:Burst("Ring", at, 10, CREAM)
			self:Flash(target, CREAM)
			self:Float(word or Content.Prep.Texts.Perfect, at + Vector3.new(0, 0.5, 0), MUSTARD, nil)
			if run >= cfg.Combo.Show then
				self:Float(string.format(Content.Prep.Texts.Combo, run), at + Vector3.new(0.5, 0.15, 0), CREAM, 20)
			end
			self:Tone("grill_ready", at, run)
			-- the mark was hit: one light kick (TASK-268)
			Haptics.Play("Mark")
		elseif band == "Good" then
			self:Note(band)
			Haptics.Play("Good")
			self:Burst("Sparks", at, 6, CREAM)
			self:Flash(target, CREAM)
			self:Tone("grill_collect", at, 0)
		else
			self:Note(band)
			self:Burst("Dust", at, 5)
		end
	end

	function self.Step(_: any, dt: number)
		for index = #pops, 1, -1 do
			const entry = pops[index]
			entry.T += dt
			const t = math.clamp(entry.T / entry.Time, 0, 1)
			-- a damped wobble: up, under, settle
			const wobble = math.sin(t * math.pi * 3) * (1 - t) * (1 - t)
			const scale = entry.Base * (1 + entry.Amount * wobble)
			const target = entry.Target
			if target.Parent == nil then
				table.remove(pops, index)
			else
				if target:IsA("Model") then
					popScale(target, scale)
				end
				if t >= 1 then
					if target:IsA("Model") then
						popScale(target, entry.Base)
					end
					table.remove(pops, index)
				end
			end
		end
		for index = #floats, 1, -1 do
			const entry = floats[index]
			entry.T += dt
			const t = math.clamp(entry.T / entry.Time, 0, 1)
			entry.Anchor.Position = entry.From + Vector3.new(0, entry.Rise * (1 - (1 - t) * (1 - t)), 0)
			-- the word pops in (overshoot), stays, fades
			const grow = if t < 0.18 then 0.6 + 0.6 * (t / 0.18) elseif t < 0.3 then 1.2 - 0.2 * ((t - 0.18) / 0.12) else 1
			entry.Label.TextTransparency = if t < 0.65 then 0 else (t - 0.65) / 0.35
			entry.Label.TextStrokeTransparency = entry.Label.TextTransparency
			entry.Gui.Size = UDim2.fromOffset(220 * grow, 60 * grow)
			if t >= 1 then
				entry.Gui:Destroy()
				entry.Anchor:Destroy()
				table.remove(floats, index)
			end
		end
		for index = #flashes, 1, -1 do
			const entry = flashes[index]
			entry.T += dt
			const t = math.clamp(entry.T / entry.Time, 0, 1)
			entry.Light.FillTransparency = entry.Fill + (1 - entry.Fill) * t
			entry.Light.OutlineTransparency = t * t
			if t >= 1 then
				entry.Light.Enabled = false
				entry.Light.Adornee = nil
				table.insert(spare, entry.Light)
				table.remove(flashes, index)
			end
		end
	end

	function self.Destroy(_: any)
		dead = true
		for _, entry in pops do
			if entry.Target.Parent ~= nil and entry.Target:IsA("Model") then
				entry.Target:ScaleTo(entry.Base)
			end
		end
		table.clear(pops)
		for _, entry in floats do
			entry.Gui:Destroy()
			entry.Anchor:Destroy()
		end
		table.clear(floats)
		for _, entry in flashes do
			entry.Light:Destroy()
		end
		table.clear(flashes)
		for _, light in spare do
			light:Destroy()
		end
		table.clear(spare)
		Juice.Streak(0)
	end

	return self :: Juice
end

return Juice
