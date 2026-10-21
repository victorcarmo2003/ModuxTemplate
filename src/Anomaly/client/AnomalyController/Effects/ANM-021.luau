--!strict
-- ANM-021 The red fog, client look (owner 2026-10-18; server Anomalies/ANM-021; the directed layer - bell, bangs on the
-- glass, words, heart, bars, red grading - is Content.HorrorScenes anm_021_red_fog). Presentation only (T10).
--   * Fog: the Atmosphere turns thick and red over LightController's preset (ctx.Light.Applied), and banks of red fog
--     (particles) roll over the patio and the street, outside the service window. Rises over FOG_IN while the record is
--     Signal / Active, goes over FOG_OUT after (the last Atmosphere write is exactly the preset again).
--   * TASK-593 (owner Play 2026-10-19): the single runner is gone. In its place SEVERAL ghosts walk out of the fog to the
--     window and the door, seen with the bare eye (the scene's named Silhouettes, Scene/Kit/Silhouette, Seen "Eyes");
--     what beats on the glass is never seen: each blow leaves a black paw print and rocks the pane (Glass "Paw").
--   * cue jumpscare: only the client whose UserId % 65536 = Entity shows the face (Kit/Jumpscare).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Effect)
local Jumpscare = require(script.Parent.Kit.Jumpscare)

const ENTITY_MOD = 65536
const FOG_IN = 8
const FOG_OUT = 4
const DENSITY = 0.66
const HAZE = 3
const COLOR = Color3.fromHex("#8A161C")
const DECAY = Color3.fromHex("#4A080C")
const PARTICLE = Color3.fromRGB(150, 26, 30)

-- fog volume over the patio and the street (world box; outside the window, Z > the counter front)
const FOG_CENTER = Vector3.new(-42, 1.4, 48)
const FOG_SIZE = Vector3.new(130, 2, 68)
const FOG_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
const FOG_RATES = { 46, 30 } -- particles/s per bank at full fog (owner 2026-10-18: "mais névoa vermelha")

type State = {
	Alpha: number,
	Rising: boolean,
	Orphan: boolean,
	Done: boolean,
	Box: Part,
	Emitters: { ParticleEmitter },
	Phase: string,
	Connection: RBXScriptConnection?,
}

local function write(ctx: Effect.Context, alpha: number)
	const light = ctx.Light
	const atmosphere = light.Atmosphere
	const preset = light.Applied
	if atmosphere == nil or preset == nil then
		return
	end
	atmosphere.Density = preset.AtmDensity + (math.max(DENSITY, preset.AtmDensity) - preset.AtmDensity) * alpha
	atmosphere.Haze = preset.AtmHaze + (math.max(HAZE, preset.AtmHaze) - preset.AtmHaze) * alpha
	atmosphere.Color = preset.AtmColor:Lerp(COLOR, alpha)
	atmosphere.Decay = preset.AtmDecay:Lerp(DECAY, alpha)
end

local function fogBox(parent: Instance): (Part, { ParticleEmitter })
	const box = Instance.new("Part")
	box.Name = "RedFog"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = FOG_SIZE
	box.CFrame = CFrame.new(FOG_CENTER)
	const emitters: { ParticleEmitter } = {}
	for index, bank in { { 14, 20, 34, 0.42 }, { 22, 10, 18, 0.5 } } do
		const e = Instance.new("ParticleEmitter")
		e.Name = `Bank{index}`
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Texture = FOG_TEXTURE
		e.Color = ColorSequence.new(PARTICLE)
		e.LightEmission = 0.4
		e.LightInfluence = 0.3
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, bank[2]),
			NumberSequenceKeypoint.new(1, bank[3]),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, bank[4]),
			NumberSequenceKeypoint.new(0.7, bank[4]),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(7, 11)
		e.Speed = NumberRange.new(0.6, 1.6)
		e.SpreadAngle = Vector2.new(180, 10)
		e.RotSpeed = NumberRange.new(-8, 8)
		e.Rotation = NumberRange.new(0, 360)
		e.Rate = 0
		e.Parent = box
		table.insert(emitters, e)
	end
	box.Parent = parent
	return box, emitters
end

local function step(ctx: Effect.Context, state: State, dt: number)
	if state.Rising and not state.Orphan then
		state.Alpha = math.min(1, state.Alpha + dt / FOG_IN)
	else
		state.Alpha = math.max(0, state.Alpha - dt / FOG_OUT)
	end
	for index, e in state.Emitters do
		e.Rate = FOG_RATES[index] * state.Alpha
	end
	write(ctx, state.Alpha)

	if state.Alpha <= 0 and not state.Rising then
		state.Done = true
		if state.Connection ~= nil then
			state.Connection:Disconnect()
			state.Connection = nil
		end
		write(ctx, 0)
		ctx.Audio:Loop("amb_fog", nil, false)
		state.Box:Destroy()
	end
end

return {
	Ref = "ANM-021",

	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		const record = Vide.untrack(occ.Record)
		const box, emitters = fogBox(ctx.Folder())
		const state: State = {
			Alpha = if record.Phase ~= "Signal" then 1 else math.clamp(occ.Elapsed() / FOG_IN, 0, 1),
			Rising = record.Phase == "Signal" or record.Phase == "Active",
			Orphan = false,
			Done = false,
			Box = box,
			Emitters = emitters,
			Phase = record.Phase,
			Connection = nil,
		}
		ctx.Audio:Loop("amb_fog", nil, true)
		state.Connection = RunService.RenderStepped:Connect(function(dt: number)
			if not state.Done then
				step(ctx, state, dt)
			end
		end)
		Vide.effect(function()
			const phase = occ.Record().Phase
			Vide.untrack(function()
				state.Phase = phase
				state.Rising = phase == "Signal" or phase == "Active"
				if not state.Rising then
					ctx.Audio:Loop("amb_fog", nil, false)
				end
			end)
		end)
		Vide.cleanup(function()
			state.Orphan = true
			state.Rising = false
			if state.Phase == "Signal" or state.Phase == "Active" then
				state.Phase = "Resolved"
			end
			ctx.Audio:Loop("amb_fog", nil, false)
		end)
	end,

	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "jumpscare" and cue.Entity == Players.LocalPlayer.UserId % ENTITY_MOD then
			Jumpscare.Show(ctx)
		end
	end,
} :: Effect.Module
