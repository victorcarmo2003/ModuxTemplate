--!strict
-- Completion sparkles in the world (user request 2026-10-11): a few Mustard -> Cream stars burst from the prompt's
-- anchor when PromptController fires an Interact. One pooled Attachment + ParticleEmitter (Rate 0, Emit only), so a
-- burst costs a handful of particles and no new instances. Built-in Roblox sparkle texture (platform asset).
-- Plain module (not Modux); presentation only.
local StarterPlayer = game:GetService("StarterPlayer")
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

const COUNT = 8
const TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
const LIFT = 0.4 -- studs above the anchor

local holder: Attachment? = nil
local emitter: ParticleEmitter? = nil

local function build(): ParticleEmitter
	const attachment = Instance.new("Attachment")
	attachment.Name = "PromptBurst"

	const e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Texture = TEXTURE
	e.Rate = 0
	e.Enabled = true
	e.LightInfluence = 0
	e.LightEmission = 0.4
	e.Color = ColorSequence.new(Theme.Tone.Mustard.Top, Theme.Color.Cream)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.25, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.35, 0.55)
	e.Speed = NumberRange.new(5, 8)
	e.SpreadAngle = Vector2.new(70, 70)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -14, 0)
	e.Drag = 3
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.ZOffset = 1
	e.Parent = attachment

	attachment.Parent = workspace.Terrain
	holder = attachment
	emitter = e
	return e
end

const Burst = {}

function Burst.Emit(at: Vector3)
	const current = emitter
	const e: ParticleEmitter = if current and holder and holder.Parent then current else build()
	const attachment = holder :: Attachment
	attachment.WorldPosition = at + Vector3.yAxis * LIFT
	e:Emit(COUNT)
end

return table.freeze(Burst)
