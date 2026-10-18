--!strict
-- Ground fog of every night (owner 2026-10-18: "quero que o game tenha essa névoa por padrão, o jogo inteiro" - the low
-- mist the Hush brings). A box of FOG_AREA studs follows the camera at ground level with two banks of slow, wide
-- particles (same look as Effects/ANM-010). On while it is night (Workspace attribute Atmosphere, AtmosphereService);
-- fades in / out over FADE s. Indoors it is not culled: the banks sit at FOG_HEIGHT and the floor of the kitchen is
-- above the street, so the mist reads outside the window. Local only, presentation only.
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

type Bank = { Rate: number, Size: { number }, Lifetime: { number }, Speed: { number }, Peak: number }

const FOG_AREA = 170
const FOG_HEIGHT = 1.2
const FOG_FOLLOW = 0.25
const FADE = 6
const TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
const COLOR = Color3.fromHex("#8E97B4")
const GROUND_Y = 0.4 -- street level of MAP-01 (the patio is 0.45)
const BANKS: { Bank } = {
	{ Rate = 5, Size = { 16, 26 }, Lifetime = { 9, 12 }, Speed = { 0.4, 1 }, Peak = 0.76 },
	{ Rate = 3, Size = { 8, 12 }, Lifetime = { 6, 8 }, Speed = { 0.2, 0.6 }, Peak = 0.68 },
}

local function emitter(bank: Bank): ParticleEmitter
	const e = Instance.new("ParticleEmitter")
	e.Name = "NightFog"
	e.Texture = TEXTURE
	e.Color = ColorSequence.new(COLOR)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, bank.Peak),
		NumberSequenceKeypoint.new(0.7, bank.Peak),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, bank.Size[1]),
		NumberSequenceKeypoint.new(1, bank.Size[2]),
	})
	e.Lifetime = NumberRange.new(bank.Lifetime[1], bank.Lifetime[2])
	e.Speed = NumberRange.new(bank.Speed[1], bank.Speed[2])
	e.SpreadAngle = Vector2.new(180, 10)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-6, 6)
	e.LightEmission = 0
	e.LightInfluence = 0.35
	e.Drag = 0.5
	e.Rate = 0
	return e
end

return function()
	const box = Instance.new("Part")
	box.Name = "NightFog"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = Vector3.new(FOG_AREA, 1, FOG_AREA)
	box.CFrame = CFrame.new(0, GROUND_Y + FOG_HEIGHT, 0)
	const emitters: { ParticleEmitter } = {}
	for _, bank in BANKS do
		const e = emitter(bank)
		e.Parent = box
		table.insert(emitters, e)
	end
	box.Parent = Workspace
	local alpha = 0
	local nextFollow = 0
	RunService.Heartbeat:Connect(function(dt: number)
		const night = Workspace:GetAttribute("Atmosphere") ~= nil
		alpha = math.clamp(alpha + (if night then dt else -dt) / FADE, 0, 1)
		for index, e in emitters do
			e.Rate = BANKS[index].Rate * alpha
		end
		const clock = os.clock()
		if alpha > 0 and clock >= nextFollow then
			nextFollow = clock + FOG_FOLLOW
			const camera = Workspace.CurrentCamera
			if camera ~= nil then
				const eye = camera.CFrame.Position
				box.CFrame = CFrame.new(eye.X, GROUND_Y + FOG_HEIGHT, eye.Z)
			end
		end
	end)
end
