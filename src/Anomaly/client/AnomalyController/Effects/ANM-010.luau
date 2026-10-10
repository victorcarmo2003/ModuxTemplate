--!strict
--[[
	ANM-010 The Hush: client effect (TASK-118; anomalies.md N10; architecture.md §19.6 Client, §19.13; AST-067,
	AST-084, AST-095 row 010; sound-list SFX-160; T117-11, T118-03).

	Presents only. The posts going out one by one are drawn by LightController from the `Lights` set (Order x Step
	since At, same on every client); the safe point rule is AnomalyService on the server (zone SS).

	Mount (one occurrence of the `Anomalies` set):
	  * low fog (AST-067 placeholder): an invisible box that follows the camera at ground level with 2 emitters at
	    1.5 studs (slow wide banks + a thinner low layer). Fades in over FOG_IN; a late joiner gets it at once.
	  * `Atmosphere` heavier and greyer, blended over LightController's current preset (ctx.Light.Applied) every
	    frame; when the fog leaves, the last write is exactly the preset again (T118-03 "volta ao preset").
	  * `amb_fog` loop on screen while the fog is up.
	  * "tunk" (`post_tunk`) at each Juniper post the frame LightController turns it off (lamp lit -> unlit while this
	    occurrence lives). Posts already out when this client mounted stay quiet.
	  * Phase Resolved / Failed, or the record leaves: the fog fades out over FOG_OUT, then everything is destroyed.
	Cue `hush_fog` (flavor of the error, DEC-195): a bank of fog drifts through the current vehicle for a few seconds.

	PROVISIONAL (frontend-coder, TASK-118): fog look, density and rates below until AST-067 (`T_Fog` 256²) and the
	art-director's AST-084 values; built-in particle texture as placeholder. "City sounds fade" is not done: no
	controller plays a city ambience at night yet (amb_night_street has no player).
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Effect)

const FOG_IN = 4 -- seconds
const FOG_OUT = 5
const FOG_AREA = 160 -- studs, box around the camera
const FOG_HEIGHT = 1.5 -- AST-067: emitters at 1.5 studs
const FOG_FOLLOW = 0.25 -- seconds between box moves
const FOG_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- placeholder until T_Fog (AST-067)
const FOG_COLOR = Color3.fromHex("#9AA3C0")
const GROUND_POINT = "SS" -- ground reference (MAP-01: Y 0); fallback 0
const POST_GROUP = "juniper_posts"
const VEHICLE_TAG = "Vehicle"

-- Atmosphere over the night preset (AST-084 values pending; never darker than the §5.3 reading minimum: only
-- density/haze/colour move, Ambient is untouched)
const ATM_DENSITY_ADD = 0.22
const ATM_DENSITY_MAX = 0.72
const ATM_HAZE_ADD = 1.4
const ATM_HAZE_MAX = 3.5
const ATM_COLOR = Color3.fromHex("#3A4060")
const ATM_COLOR_SHARE = 0.6

-- Error flavor: fog through the vehicle
const SEEP_TIME = 4
const SEEP_COUNT = 14

type Bank = {
	Rate: number,
	Size: { number },
	Lifetime: { number },
	Speed: { number },
	Peak: number, -- lowest transparency of a particle
}

const BANKS: { Bank } = {
	{ Rate = 6, Size = { 16, 26 }, Lifetime = { 9, 12 }, Speed = { 0.4, 1 }, Peak = 0.72 },
	{ Rate = 4, Size = { 8, 12 }, Lifetime = { 6, 8 }, Speed = { 0.2, 0.6 }, Peak = 0.62 },
}

type FogState = {
	Ctx: Effect.Context,
	Box: BasePart,
	Emitters: { ParticleEmitter },
	Alpha: number, -- 0..1 fog strength
	Rising: boolean, -- fog wanted
	Orphan: boolean,
	Done: boolean,
	NextFollow: number,
	Posts: { [any]: boolean }, -- fixture -> last seen lamp state
	Connection: RBXScriptConnection?,
}

local function emitter(bank: Bank): ParticleEmitter
	const e = Instance.new("ParticleEmitter")
	e.Name = "HushFog"
	e.Texture = FOG_TEXTURE
	e.Color = ColorSequence.new(FOG_COLOR)
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
	e.LightInfluence = 0.35 -- still readable at night (style guide §5.3), not glowing
	e.Drag = 0.5
	e.Rate = 0
	e.Parent = nil
	return e
end

local function groundY(ctx: Effect.Context): number
	const point = ctx.Point(GROUND_POINT)
	return if point then point.Position.Y else 0
end

local function invisibleBox(name: string, size: Vector3): Part
	const box = Instance.new("Part")
	box.Name = name
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = size
	return box
end

-- Atmosphere -------------------------------------------------------------------------------------------------------

local function writeAtmosphere(ctx: Effect.Context, alpha: number)
	const light = ctx.Light
	const atmosphere = light.Atmosphere
	const preset = light.Applied
	if atmosphere == nil or preset == nil then
		return
	end
	const density = math.min(preset.AtmDensity + ATM_DENSITY_ADD, math.max(ATM_DENSITY_MAX, preset.AtmDensity))
	const haze = math.min(preset.AtmHaze + ATM_HAZE_ADD, math.max(ATM_HAZE_MAX, preset.AtmHaze))
	atmosphere.Density = preset.AtmDensity + (density - preset.AtmDensity) * alpha
	atmosphere.Haze = preset.AtmHaze + (haze - preset.AtmHaze) * alpha
	atmosphere.Color = preset.AtmColor:Lerp(ATM_COLOR, ATM_COLOR_SHARE * alpha)
	atmosphere.Decay = preset.AtmDecay
end

-- Posts ------------------------------------------------------------------------------------------------------------

local function scanPosts(state: FogState, play: boolean)
	const fixtures = state.Ctx.Light.Fixtures[POST_GROUP]
	if fixtures == nil then
		return
	end
	for _, fixture in fixtures do
		const lit = fixture.Lit == true
		if play and state.Posts[fixture] == true and not lit then
			state.Ctx.Audio:Play("post_tunk", fixture.Position)
		end
		state.Posts[fixture] = lit
	end
end

-- Lifecycle --------------------------------------------------------------------------------------------------------

local function finish(state: FogState)
	if state.Done then
		return
	end
	state.Done = true
	const connection = state.Connection
	if connection then
		connection:Disconnect()
		state.Connection = nil
	end
	writeAtmosphere(state.Ctx, 0) -- exactly the preset again
	state.Ctx.Audio:Loop("amb_fog", nil, false)
	state.Box:Destroy()
end

local function step(state: FogState, dt: number)
	const ctx = state.Ctx
	if state.Box.Parent == nil then
		finish(state) -- night-end safety net emptied the folder
		return
	end
	if state.Rising and not state.Orphan then
		state.Alpha = math.min(1, state.Alpha + dt / FOG_IN)
	else
		state.Alpha = math.max(0, state.Alpha - dt / FOG_OUT)
		if state.Alpha <= 0 then
			finish(state)
			return
		end
	end
	for i, e in state.Emitters do
		e.Rate = BANKS[i].Rate * state.Alpha
	end
	writeAtmosphere(ctx, state.Alpha)

	const clock = os.clock()
	if clock >= state.NextFollow then
		state.NextFollow = clock + FOG_FOLLOW
		const camera = Workspace.CurrentCamera
		if camera then
			const eye = camera.CFrame.Position
			const y = state.Box.Position.Y
			state.Box.CFrame = CFrame.new(eye.X, y, eye.Z)
		end
	end
	if state.Rising and not state.Orphan then
		scanPosts(state, true) -- ~10 posts: cheap every frame, in step with LightController's 20 Hz paint
	end
end

-- Current vehicle of the party (Vehicle tag with the RoundController Vehicle key)
local function vehicleModel(ctx: Effect.Context): Model?
	const key = Vide.untrack(ctx.Round.Vehicle)
	for _, instance in CollectionService:GetTagged(VEHICLE_TAG) do
		if instance:GetAttribute("Vehicle") == key and instance:IsA("Model") then
			return instance
		end
	end
	return nil
end

-- Error flavor: a bank of fog drifts through the vehicle (one shot)
local function seep(ctx: Effect.Context, cue: Effect.Cue)
	const vehicle = vehicleModel(ctx)
	if vehicle == nil then
		return
	end
	const cf, size = vehicle:GetBoundingBox()
	const box = invisibleBox("HushSeep", Vector3.new(size.X, 1, size.Z))
	const across = if cue.Rng:NextNumber() < 0.5 then cf.RightVector else -cf.RightVector
	box.CFrame = CFrame.lookAt(cf.Position - Vector3.new(0, size.Y / 2 - FOG_HEIGHT, 0), cf.Position + across)
	const e = emitter({ Rate = 0, Size = { 5, 9 }, Lifetime = { SEEP_TIME - 1, SEEP_TIME }, Speed = { 3, 5 }, Peak = 0.6 })
	e.EmissionDirection = Enum.NormalId.Front
	e.SpreadAngle = Vector2.new(25, 5)
	e.Parent = box
	box.Parent = ctx.Folder()
	e:Emit(SEEP_COUNT)
	task.delay(SEEP_TIME + 1, function()
		box:Destroy()
	end)
end

return {
	Ref = "ANM-010",
	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		const box = invisibleBox("HushFog", Vector3.new(FOG_AREA, 1, FOG_AREA))
		box.CFrame = CFrame.new(0, groundY(ctx) + FOG_HEIGHT, 0)
		const emitters: { ParticleEmitter } = {}
		for _, bank in BANKS do
			const e = emitter(bank)
			e.Parent = box
			table.insert(emitters, e)
		end
		box.Parent = ctx.Folder()

		const record = Vide.untrack(occ.Record)
		const state: FogState = {
			Ctx = ctx,
			Box = box,
			Emitters = emitters,
			-- a late joiner (or a reconnect mid-Hush) gets the fog at once
			Alpha = if occ.Elapsed() >= FOG_IN then 1 else 0,
			Rising = record.Phase == "Signal" or record.Phase == "Active",
			Orphan = false,
			Done = false,
			NextFollow = 0,
			Posts = setmetatable({}, { __mode = "k" }) :: any,
			Connection = nil,
		}
		scanPosts(state, false) -- posts already out stay quiet
		ctx.Audio:Loop("amb_fog", nil, true)
		state.Connection = RunService.RenderStepped:Connect(function(dt: number)
			step(state, dt)
		end)

		Vide.effect(function()
			const phase = occ.Record().Phase
			state.Rising = phase == "Signal" or phase == "Active"
			if not state.Rising then
				ctx.Audio:Loop("amb_fog", nil, false)
			end
		end)
		Vide.cleanup(function()
			-- the record left the set: fade out on our own, then destroy
			state.Orphan = true
			ctx.Audio:Loop("amb_fog", nil, false)
		end)
	end,
	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "hush_fog" then
			seep(ctx, cue)
		end
	end,
} :: Effect.Module
