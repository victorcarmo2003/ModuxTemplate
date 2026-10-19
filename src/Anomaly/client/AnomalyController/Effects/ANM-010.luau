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
	  * "Run" (TASK-334, owner 2026-10-15: he did not understand what to do): a fresh Hush cuts a security camera view
	    (Kit/Watch), Walt says it on the radio (Kit/Radio), a pulsing Mustard banner at the top says RUN TO THE MART and
	    the 3D guide arrow (Interface/Arrow3D) stands over the safe point SS; inside the safe radius the banner turns to
	    "Stay inside the Mart". Gone when the record leaves Active.
	Cue `jumpscare` (TASK-334): Entity = UserId % 65536 of a player caught outside; only that client shows the face.
	Cue `hush_fog` (flavor of the error, DEC-195): a bank of fog drifts through the current vehicle for a few seconds.

	PROVISIONAL (frontend-coder, TASK-118): fog look, density and rates below until AST-067 (`T_Fog` 256²) and the
	art-director's AST-084 values; built-in particle texture as placeholder. "City sounds fade" is not done: no
	controller plays a city ambience at night yet (amb_night_street has no player).
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Arrow3D = require(StarterPlayer.StarterPlayerScripts.client.Interface.Arrow3D)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Effect = require(script.Parent.Parent.Effect)
local Jumpscare = require(script.Parent.Kit.Jumpscare)
local Radio = require(script.Parent.Kit.Radio)
local Watch = require(script.Parent.Kit.Watch)
local VehicleRoot = require(ReplicatedStorage.shared.Vehicle.VehicleRoot)

-- "Run" warning (TASK-334; PROVISIONAL)
const RUN_FRESH = 4 -- s: a record older than this when mounted does not replay the radio line
const RUN_LINE = "The lamps are dying! Run INSIDE the Mart, now!"
const RUN_LINE_TIME = 6
const RUN_TEXT = "RUN TO THE MART!"
const STAY_TEXT = "Stay inside the Mart"
const SAFE_POINT = "SS"
-- TASK-490 (restaurant: no Mart): the answer is the shop light OFF, kept off; the arrow stands over the light switch
const SHOP_LINE = "The lamps outside are dying! Kill the lights in here, NOW!"
const SHOP_RUN_TEXT = "TURN OFF THE LIGHTS!"
const SHOP_STAY_TEXT = "Keep the lights off"
const SWITCH_GROUP = "trailer_interior" -- the party switch's group (Content.LightGroups)
const SWITCH_LIFT = 2.5
const SAFE_RADIUS = 10 -- Rules/ANM-010 Params.Radius (the server also counts the Mart interior LZ-4)
const ARROW_LIFT = 7 -- studs above SS where the arrow tip rests
const PULSE = 0.45 -- s per banner pulse
const BANNER_INK = Color3.fromHex("#2B2233")
const BANNER_MUSTARD = Color3.fromHex("#F6C12B")
const BANNER_CREAM = Color3.fromHex("#FFF1D6")
const ENTITY_MOD = 65536

const FOG_IN = 4 -- seconds
const FOG_OUT = 5
const FOG_AREA = 160 -- studs, box around the camera
const FOG_HEIGHT = 1.5 -- AST-067: emitters at 1.5 studs
const FOG_FOLLOW = 0.25 -- seconds between box moves
const FOG_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- placeholder until T_Fog (AST-067)
const FOG_COLOR = Color3.fromHex("#9AA3C0")
const GROUND_POINT = "SS" -- ground reference (MAP-01: Y 0); fallback 0
const POST_GROUP = "juniper_posts"

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
local function vehicleModel(ctx: Effect.Context): Instance?
	return VehicleRoot.Find(Vide.untrack(ctx.Round.Vehicle))
end

-- Error flavor: a bank of fog drifts through the vehicle (one shot)
local function seep(ctx: Effect.Context, cue: Effect.Cue)
	const vehicle = vehicleModel(ctx)
	if vehicle == nil then
		return
	end
	const cf, size = VehicleRoot.Box(vehicle)
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

-- Run warning ---------------------------------------------------------------------------------------------------

local function banner(): (ScreenGui, TextLabel, UIScale)
	const gui = Instance.new("ScreenGui")
	gui.Name = "HushRun"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 42
	const pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 74)
	pill.Size = UDim2.fromOffset(360, 58)
	pill.BackgroundColor3 = BANNER_INK
	pill.BackgroundTransparency = 0.08
	pill.Parent = gui
	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	const stroke = Instance.new("UIStroke")
	stroke.Color = BANNER_MUSTARD
	stroke.Thickness = 4
	stroke.Parent = pill
	const scale = Instance.new("UIScale")
	scale.Parent = pill
	const label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -24, 1, -10)
	label.Position = UDim2.fromOffset(12, 5)
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextScaled = true
	label.Text = RUN_TEXT
	label.TextColor3 = BANNER_MUSTARD
	label.Parent = pill
	return gui, label, scale
end

local function nearSafe(ctx: Effect.Context): boolean
	return not ctx.Light:GroupOn(SWITCH_GROUP)
end

-- Banner + arrow while the record is Active; returns the stop function
local function runWarning(ctx: Effect.Context, occ: Effect.Occurrence): () -> ()
	if occ.Elapsed() <= RUN_FRESH then
		task.spawn(function()
			Watch.Interrupt()
			Radio.Say(ctx, SHOP_LINE, RUN_LINE_TIME)
		end)
	end
	const gui, label, scale = banner()
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	gui.Parent = playerGui
	const arrow = Arrow3D.new()
	const reduced = Motion.Reduced()
	const started = os.clock()
	const connection = RunService.RenderStepped:Connect(function()
		const safe = nearSafe(ctx)
		label.Text = (if safe then SHOP_STAY_TEXT else SHOP_RUN_TEXT)
		label.TextColor3 = if safe then BANNER_CREAM else BANNER_MUSTARD
		if not reduced and not safe then
			scale.Scale = 1 + 0.06 * math.abs(math.sin((os.clock() - started) * math.pi / PULSE))
		else
			scale.Scale = 1
		end
		local aim: Vector3? = nil
		const anchor = ctx.Light:SwitchAnchor()
		if anchor ~= nil and anchor:IsA("Attachment") then
			aim = anchor.WorldPosition + Vector3.new(0, SWITCH_LIFT, 0)
		elseif anchor ~= nil and anchor:IsA("BasePart") then
			aim = anchor.Position + Vector3.new(0, SWITCH_LIFT, 0)
		elseif anchor ~= nil and anchor:IsA("Model") then
			aim = anchor:GetPivot().Position + Vector3.new(0, SWITCH_LIFT, 0)
		end
		if aim ~= nil and not safe then
			arrow.Show(ctx.Folder())
			arrow.Step(aim, 2.5, true)
		elseif arrow.Mounted() then
			arrow.Hide()
		end
	end)
	return function()
		connection:Disconnect()
		if arrow.Mounted() then
			arrow.Detach()
		end
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.delay(0.35, function()
			gui:Destroy()
		end)
	end
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

		local stopRun: (() -> ())? = nil
		Vide.effect(function()
			const phase = occ.Record().Phase
			state.Rising = phase == "Signal" or phase == "Active"
			if not state.Rising then
				ctx.Audio:Loop("amb_fog", nil, false)
			end
			Vide.untrack(function()
				if state.Rising and stopRun == nil then
					stopRun = runWarning(ctx, occ)
				elseif not state.Rising and stopRun ~= nil then
					(stopRun :: () -> ())()
					stopRun = nil
				end
			end)
		end)
		Vide.cleanup(function()
			-- the record left the set: fade out on our own, then destroy
			state.Orphan = true
			ctx.Audio:Loop("amb_fog", nil, false)
			if stopRun ~= nil then
				(stopRun :: () -> ())()
				stopRun = nil
			end
		end)
	end,
	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "hush_fog" then
			seep(ctx, cue)
		elseif cue.Cue == "jumpscare" then
			if cue.Entity == Players.LocalPlayer.UserId % ENTITY_MOD then
				Jumpscare.Show(ctx)
			end
		end
	end,
} :: Effect.Module
