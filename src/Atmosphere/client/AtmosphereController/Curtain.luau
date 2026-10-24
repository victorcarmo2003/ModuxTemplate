--!strict
-- Fog curtain (owner 2026-10-21: "a névoa ainda está muito fraca"). Lighting.Atmosphere alone reads as plain darkness
-- at night; this is the wall of grey that rolls a few metres out, Silent Hill style. Rules.Curtain.Count emitters on a
-- ring of Radius studs around the camera (they follow it on X/Z), each breathing big slow smoke puffs from the ground
-- up to Height. World-space particles, so they drift and stay behind. Inside the trailer / restaurant the ring sits
-- past the walls: only the windows show it. Rate scales with the atmosphere blend. Local only, presentation only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)

type Spec = typeof(Content.Atmospheres.Rules.Curtain)

const TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- same puffs as GroundFog / Effects/ANM-010

export type Curtain = {
	Spec: Spec,
	Folder: Folder,
	Holders: { BasePart },
	Emitters: { ParticleEmitter },
	Alpha: number,
	Step: (self: Curtain, alpha: number) -> (),
	Destroy: (self: Curtain) -> (),
}

const Curtain = {}
Curtain.__index = Curtain

function Curtain.new(spec: Spec): Curtain
	const camera = Workspace.CurrentCamera
	const folder = Instance.new("Folder")
	folder.Name = "AtmosphereCurtain"
	folder.Parent = camera or Workspace

	const holders: { BasePart } = {}
	const emitters: { ParticleEmitter } = {}
	const arc = 2 * math.pi * spec.Radius / spec.Count
	for _ = 1, spec.Count do
		const part = Instance.new("Part")
		part.Name = "FogBank"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = Vector3.new(arc, spec.Height, arc * 0.5)
		part.Parent = folder

		const e = Instance.new("ParticleEmitter")
		e.Name = "Curtain"
		e.Texture = TEXTURE
		e.Color = ColorSequence.new(spec.Color)
		e.LightEmission = spec.Glow
		e.LightInfluence = 0.5
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, spec.Peak),
			NumberSequenceKeypoint.new(0.7, spec.Peak),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, spec.Size[1]),
			NumberSequenceKeypoint.new(1, spec.Size[2]),
		})
		e.Lifetime = NumberRange.new(spec.Lifetime[1], spec.Lifetime[2])
		e.Speed = NumberRange.new(0.3, 1)
		e.SpreadAngle = Vector2.new(180, 20)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-6, 6)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Rate = 0
		e.Parent = part

		table.insert(holders, part)
		table.insert(emitters, e)
	end

	return setmetatable({
		Spec = spec,
		Folder = folder,
		Holders = holders,
		Emitters = emitters,
		Alpha = -1,
	}, Curtain) :: any
end

function Curtain.Step(self: Curtain, alpha: number)
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	const spec = self.Spec
	const eye = camera.CFrame.Position
	const frames: { CFrame } = {}
	for index = 1, #self.Holders do
		const angle = (index / #self.Holders) * math.pi * 2
		const out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		const at = Vector3.new(eye.X, spec.Ground + spec.Height / 2, eye.Z) + out * spec.Radius
		table.insert(frames, CFrame.lookAt(at, at + out))
	end
	Workspace:BulkMoveTo(self.Holders, frames, Enum.BulkMoveMode.FireCFrameChanged)
	if alpha ~= self.Alpha then
		self.Alpha = alpha
		for _, e in self.Emitters do
			e.Rate = spec.Rate * alpha
		end
	end
end

function Curtain.Destroy(self: Curtain)
	self.Folder:Destroy()
	table.clear(self.Holders)
	table.clear(self.Emitters)
end

return Curtain
