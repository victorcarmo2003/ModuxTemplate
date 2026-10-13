--!strict
-- Placeholder particles of AST-092 (TASK-079; style guide §10; asset-list AST-092 / AST-082). Plain module, client
-- only, no network, no Modux. Kitchen parts, EconomyController (coins) and MarketController (confetti) share it so
-- the budget is one for the whole screen (AST-092 "Teto", style guide §9.2):
--   * a burst never takes the live total over MAX_PARTICLES (150), counting the continuous emitters registered here
--     at their steady state (Rate x Lifetime);
--   * at most MAX_EMITTERS (8) live emitters within NEAR studs of the camera (bursts + continuous);
--   * low graphics quality (saved level 1..3) turns the grill smoke off and skips bursts (AST-092: smoke "desliga em
--     qualidade baixa"; Provisional: bursts too, to keep the reference phone smooth).
-- Textures are Roblox built-ins until the `T_VFX_Kitchen` sheet (AST-092) exists: swap TEXTURE.* then.
local Debris = game:GetService("Debris")

const MAX_PARTICLES = 150
const MAX_EMITTERS = 8
const NEAR = 60 -- studs from the camera counted as "near"
const LOW_QUALITY = 3 -- SavedQualityLevel 1..3 = low (Automatic counts as high)

const TEXTURE = table.freeze({
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
})

-- Palette (style guide §2.1)
const MUSTARD = Color3.fromHex("#F6C12B")
const CREAM = Color3.fromHex("#FFF8EC")
const DUST = Color3.fromHex("#E8DCC4")
const CONFETTI = { Color3.fromHex("#E2402E"), MUSTARD, Color3.fromHex("#4FA3D9"), Color3.fromHex("#6CC26A") }

export type Preset = "Ready" | "Drops" | "Dust" | "Coins" | "Tip" | "Confetti"

type Spec = {
	Texture: string,
	Lifetime: NumberRange,
	Speed: NumberRange,
	Spread: number,
	Size: NumberSequence,
	Acceleration: Vector3,
	LightEmission: number,
}

const SPECS: { [Preset]: Spec } = {
	-- ReadyVFX: 10 Mustard/white stars
	Ready = {
		Texture = TEXTURE.Sparkle,
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(2, 3.5),
		Spread = 70,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }),
		Acceleration = Vector3.new(0, -2, 0),
		LightEmission = 0.6,
	},
	-- sauce: 6 droplets in the sauce colour
	Drops = {
		Texture = TEXTURE.Sparkle,
		Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(1.5, 2.5),
		Spread = 35,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.05) }),
		Acceleration = Vector3.new(0, -12, 0),
		LightEmission = 0,
	},
	-- restock: light dust puff
	Dust = {
		Texture = TEXTURE.Smoke,
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(1, 2),
		Spread = 80,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Acceleration = Vector3.new(0, 0.5, 0),
		LightEmission = 0,
	},
	-- payment: 4 Mustard coins hop and fall into the drawer (AST-082 has no mesh yet)
	Coins = {
		Texture = TEXTURE.Sparkle,
		Lifetime = NumberRange.new(0.5, 0.7),
		Speed = NumberRange.new(4, 5),
		Spread = 25,
		Size = NumberSequence.new(0.3),
		Acceleration = Vector3.new(0, -18, 0),
		LightEmission = 0.3,
	},
	-- tip: +1 brighter Mustard coin (never Gold, AST-082)
	Tip = {
		Texture = TEXTURE.Sparkle,
		Lifetime = NumberRange.new(0.7, 0.7),
		Speed = NumberRange.new(5, 5),
		Spread = 10,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.45) }),
		Acceleration = Vector3.new(0, -14, 0),
		LightEmission = 0.8,
	},
	-- upgrade installed: 14 pieces of confetti
	Confetti = {
		Texture = TEXTURE.Sparkle,
		Lifetime = NumberRange.new(0.9, 1.2),
		Speed = NumberRange.new(5, 7),
		Spread = 50,
		Size = NumberSequence.new(0.22),
		Acceleration = Vector3.new(0, -9, 0),
		LightEmission = 0.2,
	},
}

const DEFAULT_COLOR: { [Preset]: ColorSequence } = {
	Ready = ColorSequence.new(MUSTARD, CREAM),
	Drops = ColorSequence.new(MUSTARD),
	Dust = ColorSequence.new(DUST),
	Coins = ColorSequence.new(MUSTARD),
	Tip = ColorSequence.new(MUSTARD, CREAM),
	Confetti = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CONFETTI[1]),
		ColorSequenceKeypoint.new(0.33, CONFETTI[2]),
		ColorSequenceKeypoint.new(0.66, CONFETTI[3]),
		ColorSequenceKeypoint.new(1, CONFETTI[4]),
	}),
}

-- Live emitters: emitter -> steady particle count (bursts: count until they die; continuous: Rate x Lifetime)
const live: { [ParticleEmitter]: number } = {}

local function liveParticles(): number
	local total = 0
	for emitter, count in live do
		if emitter.Parent == nil then
			live[emitter] = nil
		elseif emitter.Enabled or count > 0 then
			total += count
		end
	end
	return total
end

local function nearEmitters(position: Vector3): number
	const camera = workspace.CurrentCamera
	const eye = if camera then camera.CFrame.Position else position
	local count = 0
	for emitter in live do
		const parent = emitter.Parent
		if parent and parent:IsA("Attachment") and (parent.WorldPosition - eye).Magnitude <= NEAR then
			count += 1
		end
	end
	return count
end

const Fx = {}

-- true on low graphics quality (smoke off, bursts skipped)
function Fx.Low(): boolean
	const ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok or level == Enum.SavedQualitySetting.Automatic then
		return false
	end
	return level.Value <= LOW_QUALITY
end

-- One-shot burst at a world position; dropped (silently) when it would break the budget.
function Fx.Burst(position: Vector3, preset: Preset, count: number, color: Color3?)
	if Fx.Low() or count <= 0 then
		return
	end
	const camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > NEAR * 2 then
		return -- too far to be seen: not worth a slot
	end
	if liveParticles() + count > MAX_PARTICLES or nearEmitters(position) >= MAX_EMITTERS then
		return
	end
	const spec = SPECS[preset]
	const holder = Instance.new("Attachment")
	holder.Name = `Fx_{preset}`
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain

	const emitter = Instance.new("ParticleEmitter")
	emitter.Texture = spec.Texture
	emitter.Color = if color then ColorSequence.new(color) else DEFAULT_COLOR[preset]
	emitter.Lifetime = spec.Lifetime
	emitter.Speed = spec.Speed
	emitter.SpreadAngle = Vector2.new(spec.Spread, spec.Spread)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size = spec.Size
	emitter.Acceleration = spec.Acceleration
	emitter.LightEmission = spec.LightEmission
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = holder
	live[emitter] = count
	emitter:Emit(count)
	Debris:AddItem(holder, spec.Lifetime.Max + 0.2)
end

-- Continuous grill smoke (AST-092: Rate 3 per busy slot, Lifetime 1.2 s). The caller owns the emitter (Vide cleanup)
-- and drives it with Fx.SetSmoke.
const SMOKE_RATE = 3
const SMOKE_LIFETIME = 1.2
-- Near camera (the focused prep mode looks at the grill from ~2.5 studs, 2026-10-12): the same puffs read as ONE dot there, so they
-- grow, rise and come more often. Fx.SetNear flips every smoke emitter of the grill.
const SMOKE_SIZE_FAR = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.7) })
const SMOKE_SIZE_NEAR = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.35),
	NumberSequenceKeypoint.new(0.4, 0.9),
	NumberSequenceKeypoint.new(1, 1.6),
})
const SMOKE_NEAR_RATE = 2.2 -- x the rate
const smokes: { [ParticleEmitter]: boolean } = {}
local nearSmoke = false

function Fx.Smoke(parent: Attachment): ParticleEmitter
	const emitter = Instance.new("ParticleEmitter")
	emitter.Name = "GrillSmoke"
	emitter.Texture = TEXTURE.Smoke
	emitter.Color = ColorSequence.new(Color3.fromHex("#E9E4DC"))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = if nearSmoke then SMOKE_SIZE_NEAR else SMOKE_SIZE_FAR
	emitter.Lifetime = NumberRange.new(SMOKE_LIFETIME, SMOKE_LIFETIME)
	emitter.Speed = if nearSmoke then NumberRange.new(1.0, 1.6) else NumberRange.new(0.8, 1.2)
	emitter.SpreadAngle = if nearSmoke then Vector2.new(18, 18) else Vector2.new(10, 10)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.Enabled = false
	emitter.Parent = parent
	live[emitter] = 0
	smokes[emitter] = true
	return emitter
end

-- The camera is close to the grill (true: the prep mode is up) or far again: size, speed and spread of every smoke emitter.
function Fx.SetNear(on: boolean)
	if nearSmoke == on then
		return
	end
	nearSmoke = on
	for emitter in smokes do
		if emitter.Parent == nil then
			smokes[emitter] = nil
			continue
		end
		emitter.Size = if on then SMOKE_SIZE_NEAR else SMOKE_SIZE_FAR
		emitter.Speed = if on then NumberRange.new(1.0, 1.6) else NumberRange.new(0.8, 1.2)
		emitter.SpreadAngle = if on then Vector2.new(18, 18) else Vector2.new(10, 10)
		emitter.Rate *= if on then SMOKE_NEAR_RATE else 1 / SMOKE_NEAR_RATE
	end
end

-- busy = slots with a sausage on the rollers
function Fx.SetSmoke(emitter: ParticleEmitter, busy: number)
	const on = busy > 0 and not Fx.Low()
	emitter.Rate = SMOKE_RATE * busy * (if nearSmoke then SMOKE_NEAR_RATE else 1)
	emitter.Enabled = on
	live[emitter] = if on then math.ceil(SMOKE_RATE * busy * SMOKE_LIFETIME) else 0
end

-- Continuous emitter made elsewhere (coffee steam): counted in the budget at Rate x Lifetime while enabled.
function Fx.Track(emitter: ParticleEmitter)
	live[emitter] = math.ceil(emitter.Rate * emitter.Lifetime.Max)
end

function Fx.Untrack(emitter: ParticleEmitter)
	live[emitter] = nil
end

return table.freeze(Fx)
