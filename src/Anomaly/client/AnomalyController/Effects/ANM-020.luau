--!strict
--[[
	ANM-020 The blackout: client effect (V2 family C "falha de energia"; DEC-254, DEC-255, DEC-256;
	design/anomalies-v2-proposal.md §3 C; TASK-273). Presents only: the dark rule, the breaker and the attack are the
	server's (LightService blackout, Anomalies/ANM-020).

	The lamps going out are LightController's (Lights set: every HushOff group off, posts with At = 0 so they all drop
	in the same frame). On top of that, while the record is Active:
	  * a ColorCorrectionEffect of our own (`ANM020_Blackout`) stacked over whatever the night look is (LightController
	    preset, Atmosphere/TASK-275): nothing of theirs is written, so when it is destroyed their state is untouched;
	  * the current vehicle's other lights (sign, side neon, anything LightController does not own) go off locally and
	    come back as they were;
	  * no flashlight exists in the game, so a minimum local glow rides on the local character (only this client);
	  * a faint Mustard glow pulses on the breaker anchor (PromptAction breaker_reset) so it can be found in the dark;
	  * noises around the player (steps on the roof, whisper, creak, knock), denser as the dark goes on;
	  * a shape (dark silhouette) at the corner of the eye: it stands 60-80 degrees off the look direction for a
	    moment and is gone the instant the player looks at it. Closer and more often as the dark goes on.
	Cues: blackout_start (the crack), blackout_restore (power hum back), jumpscare (Entity 0: the face from
	Kit/Jumpscare for whoever stands in the trailer zone, the same zone the server attacks; the faint is the server's).
	Restaurant (TASK-444): blackout_warn = the omen while the record is Signal (the kitchen lights flicker 1-2 times,
	locally, like Kit/Hide); the dark itself starts on Active. blackout_start plays the owner's "lights off" snap
	(lights_off; post_tunk while that row has no audio). jumpscare with Entity = UserId % 65536 = only that player (the
	one the server made pay: not hidden in the back). The music steps and the "POWER OUT" caption are Score/'s (the director).
	Total blackout (restaurant only, owner request 2026-10-17; Kit/Blackout, Content.LightPresets.Blackout): besides the
	vehicle, every light / Neon / table torch / SurfaceGui glow of the restaurant goes off locally (the emergency lamp
	EMERG-P stays), and Lighting blends to a darker look for as long as the dark lasts, back to the night values after.

	PROVISIONAL (TASK-273): look numbers below, sound keys reused from Content.Sounds until the sound-list has its own,
	shape made of Parts until the art-director's sheet. ESCALATE_OVER only paces the presentation (the real window is
	in Rules/ANM-020, server only).
]]
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Effect)
local Blackout = require(script.Parent.Kit.Blackout)
local Jumpscare = require(script.Parent.Kit.Jumpscare)
local Watch = require(script.Parent.Kit.Watch)

const VEHICLE_TAG = "Vehicle"
const ANCHOR_TAG = "Interactable"
const BREAKER_ACTION = "breaker_reset"
const ZONE_POINT = "TRL"
const ATTACK_RADIUS = 24 -- studs (flat) from TRL: Rules/ANM-020 Params.Radius
const ESCALATE_OVER = 30 -- s of dark over which noises and the shape get closer and more frequent

-- Dark look stacked over the night preset
const CC_NAME = "ANM020_Blackout"
const DARK_IN = 0.15 -- s: the crack is instant
const DARK_OUT = 1.2
const CC_BRIGHTNESS = -0.1
const CC_CONTRAST = 0.12
const CC_SATURATION = -0.45
const CC_TINT = Color3.fromHex("#B8C2E0")

-- Minimum local glow (no flashlight in the game)
const GLOW_NAME = "ANM020_Glow"
const GLOW_RANGE = 9
const GLOW_BRIGHTNESS = 0.45
const GLOW_COLOR = Color3.fromHex("#A9B6DA")

-- Breaker beacon (house Mustard, never alert red)
const BEACON_NAME = "ANM020_Beacon"
const BEACON_RANGE = 5
const BEACON_BRIGHTNESS = 0.9
const BEACON_PULSE = 1.6 -- s per pulse
const BEACON_COLOR = Color3.fromHex("#E8B23A")
const HIGHLIGHT_NAME = "ANM020_Highlight"
const HIGHLIGHT_MODEL = "TRL-BREAKER" -- panel model (tools/assetplace/breaker.luau)
const HIGHLIGHT_FILL = 0.75 -- fill transparency, pulses with the beacon
const HIGHLIGHT_OUTLINE = 0

const LAMP_OFF_MATERIAL = Enum.Material.SmoothPlastic
const LAMP_OFF_COLOR = Color3.fromHex("#3A3540")

-- Omen flicker (TASK-444): off / on / off / on, s each (1-2 blinks), on the kitchen fixtures LightController owns
const OMEN_FLICKER = { 0.09, 0.14, 0.07, 0.45, 0.16, 0.1 }
const OMEN_GROUPS = { "trailer_interior", "trailer_lights" }
const ENTITY_MOD = 65536 -- AnomalyCue.Entity range (Kit/Hide.EntityOf on the server)

-- Noises around the player
const NOISES: { string } = { "roof_step", "whisper", "door_creak", "door_knock", "roof_step" }
const NOISE_GAP_START = { 3.5, 6 } -- s between two noises at the start
const NOISE_GAP_END = { 1.5, 3 } -- near the end
const NOISE_DISTANCE = { 6, 14 } -- studs from the player

-- The shape
const SHAPE_GAP_START = { 6, 9 }
const SHAPE_GAP_END = { 2.5, 4 }
const SHAPE_DISTANCE_START = { 18, 26 }
const SHAPE_DISTANCE_END = { 9, 13 }
const SHAPE_SIDE = { 60, 80 } -- degrees off the look direction
const SHAPE_LIFE = { 0.6, 1.2 } -- s on screen when nobody looks
const SHAPE_SEEN = 32 -- degrees: inside this cone the shape is gone at once
const SHAPE_COLOR = Color3.fromHex("#0B0910")

-- TASK-467: while the directed scene (Content.HorrorScenes, Scene/) plays this anomaly, its steps own the sounds of the
-- dark (steps to the door, handle, latch); the random noises here would talk over them, so they stay quiet. The corner
-- shape stays (it is not in the scene).
const SCENE = Content.HorrorScenes.ByKey["anm_020_blackout"]
const SCENE_LIVE = SCENE ~= nil and SCENE.Live == true
const SHAPE_TRANSPARENCY = 0.08

type Saved = { Light: Light?, Enabled: boolean, Part: BasePart?, Material: Enum.Material, Color: Color3 }

type Session = {
	Ctx: Effect.Context,
	Started: number, -- server time the power went out
	Rng: Random,
	Correction: ColorCorrectionEffect,
	Glow: PointLight,
	Beacon: PointLight?,
	BeaconHolder: Instance?,
	Highlight: Highlight?,
	Shape: Model,
	ShapeUntil: number, -- os.clock(); 0 = hidden
	NextShape: number,
	NextNoise: number,
	Saved: { Saved },
	Map: Blackout.Handle?, -- restaurant total blackout (Kit/Blackout)
	Connection: RBXScriptConnection?,
	Ended: boolean,
}

-- One live session at a time (the server never runs two blackouts at once)
local current: Session? = nil

local function between(rng: Random, range: { number }, t: number?, endRange: { number }?): number
	local low, high = range[1], range[2]
	if t ~= nil and endRange ~= nil then
		low += (endRange[1] - low) * t
		high += (endRange[2] - high) * t
	end
	return low + (high - low) * rng:NextNumber()
end

local function progress(session: Session): number
	return math.clamp((session.Ctx.Now() - session.Started) / ESCALATE_OVER, 0, 1)
end

local function rootOf(player: Player): BasePart?
	const character = player.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- Vehicle lights --------------------------------------------------------------------------------------------------

local function vehicleModel(ctx: Effect.Context): Model?
	const key = Vide.untrack(ctx.Round.Vehicle)
	for _, instance in CollectionService:GetTagged(VEHICLE_TAG) do
		if instance:GetAttribute("Vehicle") == key and instance:IsA("Model") then
			return instance
		end
	end
	return nil
end

-- Lights and lamp parts LightController owns (it repaints them from the Lights set; never touched here)
local function owned(ctx: Effect.Context): { [Instance]: boolean }
	const out: { [Instance]: boolean } = {}
	for _, fixtures in ctx.Light.Fixtures do
		for _, fixture in fixtures do
			for _, light in fixture.Lights do
				out[light] = true
			end
			for _, lamp in fixture.Lamps do
				out[lamp.Part] = true
			end
		end
	end
	return out
end

-- Sign, side neon and other lights of the vehicle that LightController does not drive: off locally, saved.
local function darkenVehicle(session: Session)
	const vehicle = vehicleModel(session.Ctx)
	if vehicle == nil then
		return
	end
	const skip = owned(session.Ctx)
	for _, d in vehicle:GetDescendants() do
		if skip[d] then
			continue
		end
		if d:IsA("Light") and d.Enabled then
			table.insert(session.Saved, {
				Light = d,
				Enabled = true,
				Part = nil,
				Material = LAMP_OFF_MATERIAL,
				Color = LAMP_OFF_COLOR,
			})
			d.Enabled = false
		elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon and d.Transparency < 1 then
			table.insert(session.Saved, { Light = nil, Enabled = false, Part = d, Material = d.Material, Color = d.Color })
			d.Material = LAMP_OFF_MATERIAL
			d.Color = LAMP_OFF_COLOR
		end
	end
end

local function restoreVehicle(session: Session)
	for _, saved in session.Saved do
		const light = saved.Light
		const part = saved.Part
		-- only what is still in the state we left it in (another system may have changed it meanwhile)
		if light ~= nil and light.Parent ~= nil and not light.Enabled then
			light.Enabled = saved.Enabled
		elseif part ~= nil and part.Parent ~= nil and part.Material == LAMP_OFF_MATERIAL then
			part.Material = saved.Material
			part.Color = saved.Color
		end
	end
	table.clear(session.Saved)
end

-- Breaker beacon --------------------------------------------------------------------------------------------------

local function breakerAnchor(): Instance?
	for _, anchor in CollectionService:GetTagged(ANCHOR_TAG) do
		if anchor:GetAttribute("PromptAction") == BREAKER_ACTION and anchor:IsDescendantOf(Workspace) then
			return anchor
		end
	end
	return nil
end

-- Parented to the anchor when it is a part or an attachment (the runtime anchor of LightService is an Attachment)
local function placeBeacon(session: Session)
	const beacon = session.Beacon
	if beacon ~= nil and beacon.Parent ~= nil and beacon.Parent == session.BeaconHolder then
		return
	end
	const anchor = breakerAnchor()
	if anchor == nil or not (anchor:IsA("Attachment") or anchor:IsA("BasePart")) then
		return
	end
	local light: PointLight
	if beacon ~= nil then
		light = beacon
	else
		light = Instance.new("PointLight")
		light.Name = BEACON_NAME
		light.Range = BEACON_RANGE
		light.Color = BEACON_COLOR
		light.Shadows = false
		session.Beacon = light
	end
	light.Parent = anchor
	session.BeaconHolder = anchor

	-- Highlight over the whole panel (seen through walls, so the guide never loses it)
	local adornee: Instance? = anchor:FindFirstAncestor(HIGHLIGHT_MODEL)
	if adornee == nil then
		adornee = if anchor:IsA("Attachment") then anchor.Parent else anchor
	end
	local highlight = session.Highlight
	if highlight == nil then
		const created = Instance.new("Highlight")
		created.Name = HIGHLIGHT_NAME
		created.FillColor = BEACON_COLOR
		created.OutlineColor = BEACON_COLOR
		created.FillTransparency = HIGHLIGHT_FILL
		created.OutlineTransparency = HIGHLIGHT_OUTLINE
		created.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		session.Highlight = created
		highlight = created
	end
	if highlight ~= nil and adornee ~= nil then
		highlight.Adornee = adornee
		highlight.Parent = adornee
	end
end

-- The shape -------------------------------------------------------------------------------------------------------

local function shapePart(name: string, shape: Enum.PartType, size: Vector3): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = SHAPE_COLOR
	part.Transparency = 1
	return part
end

-- A tall thin silhouette (body + head), pivot at the body centre; hidden (Transparency 1) until shown.
local function buildShape(): Model
	const model = Instance.new("Model")
	model.Name = "BlackoutShape"
	const body = shapePart("Body", Enum.PartType.Block, Vector3.new(1.4, 3.6, 0.8))
	body.Parent = model
	const head = shapePart("Head", Enum.PartType.Ball, Vector3.new(1.3, 1.3, 1.3))
	head.CFrame = body.CFrame * CFrame.new(0, 2.45, 0)
	head.Parent = model
	model.PrimaryPart = body
	return model
end

local function setShapeVisible(session: Session, visible: boolean)
	for _, part in session.Shape:GetChildren() do
		if part:IsA("BasePart") then
			part.Transparency = if visible then SHAPE_TRANSPARENCY else 1
		end
	end
end

local function groundAt(position: Vector3, ignore: { Instance }): number?
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	const hit = Workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	return if hit ~= nil then hit.Position.Y else nil
end

local function showShape(session: Session)
	const camera = Workspace.CurrentCamera
	const root = rootOf(Players.LocalPlayer)
	if camera == nil or root == nil then
		return
	end
	const rng = session.Rng
	const t = progress(session)
	const look = camera.CFrame.LookVector
	const flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	const side = if rng:NextNumber() < 0.5 then -1 else 1
	const angle = math.rad(between(rng, SHAPE_SIDE)) * side
	const direction = (CFrame.fromAxisAngle(Vector3.yAxis, angle) * flat.Unit) :: Vector3
	const distance = between(rng, SHAPE_DISTANCE_START, t, SHAPE_DISTANCE_END)
	const spot = root.Position + direction * distance
	const character = Players.LocalPlayer.Character
	const ignore: { Instance } = { session.Shape, session.Ctx.Folder() }
	if character ~= nil then
		table.insert(ignore, character)
	end
	const ground = groundAt(spot, ignore) or (root.Position.Y - 3)
	const at = Vector3.new(spot.X, ground + 2.3, spot.Z)
	session.Shape:PivotTo(CFrame.lookAt(at, Vector3.new(root.Position.X, at.Y, root.Position.Z)))
	setShapeVisible(session, true)
	session.ShapeUntil = os.clock() + between(rng, SHAPE_LIFE)
end

local function hideShape(session: Session, whoosh: boolean)
	if session.ShapeUntil == 0 then
		return
	end
	session.ShapeUntil = 0
	setShapeVisible(session, false)
	if whoosh then
		session.Ctx.Play("shadow_whoosh", session.Shape:GetPivot().Position)
	end
end

-- The local camera is looking at the shape (inside SHAPE_SEEN degrees)
local function looked(session: Session): boolean
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return false
	end
	const offset = session.Shape:GetPivot().Position - camera.CFrame.Position
	if offset.Magnitude < 0.01 then
		return true
	end
	return camera.CFrame.LookVector:Dot(offset.Unit) >= math.cos(math.rad(SHAPE_SEEN))
end

-- Loop ------------------------------------------------------------------------------------------------------------

local function noise(session: Session)
	const root = rootOf(Players.LocalPlayer)
	if root == nil then
		return
	end
	const rng = session.Rng
	const angle = rng:NextNumber() * math.pi * 2
	const distance = between(rng, NOISE_DISTANCE)
	const at = root.Position + Vector3.new(math.cos(angle) * distance, rng:NextNumber() * 4, math.sin(angle) * distance)
	session.Ctx.Play(NOISES[rng:NextInteger(1, #NOISES)], at)
end

local function step(session: Session)
	const clock = os.clock()
	const t = progress(session)

	-- minimum glow on the local character (follows a respawn)
	const root = rootOf(Players.LocalPlayer)
	if root ~= nil and session.Glow.Parent ~= root then
		session.Glow.Parent = root
	end

	placeBeacon(session)
	const beacon = session.Beacon
	if beacon ~= nil then
		const wave = 0.5 + 0.5 * math.sin(clock * math.pi * 2 / BEACON_PULSE)
		beacon.Brightness = BEACON_BRIGHTNESS * (0.35 + 0.65 * wave)
		const highlight = session.Highlight
		if highlight ~= nil then
			highlight.FillTransparency = HIGHLIGHT_FILL + (1 - HIGHLIGHT_FILL) * 0.6 * (1 - wave)
		end
	end

	if session.ShapeUntil > 0 then
		if looked(session) then
			hideShape(session, true)
			session.NextShape = clock + between(session.Rng, SHAPE_GAP_START, t, SHAPE_GAP_END)
		elseif clock >= session.ShapeUntil then
			hideShape(session, false)
			session.NextShape = clock + between(session.Rng, SHAPE_GAP_START, t, SHAPE_GAP_END)
		end
	elseif clock >= session.NextShape then
		showShape(session)
		if session.ShapeUntil == 0 then
			session.NextShape = clock + 1 -- no camera or character yet: try again soon
		end
	end

	if clock >= session.NextNoise then
		if not SCENE_LIVE then
			noise(session)
		end
		session.NextNoise = clock + between(session.Rng, NOISE_GAP_START, t, NOISE_GAP_END)
	end
end

local function begin(ctx: Effect.Context, occ: Effect.Occurrence): Session
	const correction = Instance.new("ColorCorrectionEffect")
	correction.Name = CC_NAME
	correction.Brightness = 0
	correction.Contrast = 0
	correction.Saturation = 0
	correction.TintColor = Color3.new(1, 1, 1)
	correction.Parent = Lighting
	TweenService:Create(correction, TweenInfo.new(DARK_IN), {
		Brightness = CC_BRIGHTNESS,
		Contrast = CC_CONTRAST,
		Saturation = CC_SATURATION,
		TintColor = CC_TINT,
	}):Play()

	const glow = Instance.new("PointLight")
	glow.Name = GLOW_NAME
	glow.Range = GLOW_RANGE
	glow.Brightness = GLOW_BRIGHTNESS
	glow.Color = GLOW_COLOR
	glow.Shadows = false

	const shape = buildShape()
	shape.Parent = ctx.Folder()

	const clock = os.clock()
	const rng = Random.new()
	const session: Session = {
		Ctx = ctx,
		Started = Vide.untrack(occ.Record).StartedAt,
		Rng = rng,
		Correction = correction,
		Glow = glow,
		Beacon = nil,
		BeaconHolder = nil,
		Highlight = nil,
		Shape = shape,
		ShapeUntil = 0,
		NextShape = clock + between(rng, SHAPE_GAP_START),
		NextNoise = clock + between(rng, NOISE_GAP_START),
		Saved = {},
		Map = nil,
		Connection = nil,
		Ended = false,
	}
	darkenVehicle(session)
	if Content.Restaurant.Rules.Enabled then
		-- total blackout (owner 2026-10-17): the rest of the restaurant, never what LightController or the vehicle pass own
		const skip = owned(ctx)
		for _, saved in session.Saved do
			const instance: Instance? = saved.Light or saved.Part
			if instance ~= nil then
				skip[instance] = true
			end
		end
		session.Map = Blackout.Darken(skip)
		Blackout.Look(true)
	end
	session.Connection = RunService.RenderStepped:Connect(function()
		step(session)
	end)
	current = session
	return session
end

local function finish(session: Session)
	if session.Ended then
		return
	end
	session.Ended = true
	if current == session then
		current = nil
	end
	const connection = session.Connection
	if connection ~= nil then
		connection:Disconnect()
		session.Connection = nil
	end
	restoreVehicle(session)
	const map = session.Map
	if map ~= nil then
		session.Map = nil
		map.Restore()
		Blackout.Look(false)
	end
	session.Glow:Destroy()
	const beacon = session.Beacon
	if beacon ~= nil then
		beacon:Destroy()
	end
	const highlight = session.Highlight
	if highlight ~= nil then
		highlight:Destroy()
	end
	session.Shape:Destroy()
	-- back to whatever the night look is: only our own effect fades and goes away
	const correction = session.Correction
	const tween = TweenService:Create(correction, TweenInfo.new(DARK_OUT), {
		Brightness = 0,
		Contrast = 0,
		Saturation = 0,
		TintColor = Color3.new(1, 1, 1),
	})
	tween.Completed:Once(function()
		correction:Destroy()
	end)
	tween:Play()
end

-- The omen: the kitchen lamps blink off 1-2 times and come back (fixtures marked so LightController leaves them, then
-- unmarked so it repaints them from the Lights set; same trick as Kit/Hide's warning)
local function flicker(ctx: Effect.Context)
	const light = ctx.Light
	local off = true
	for _, wait in OMEN_FLICKER do
		for _, key in OMEN_GROUPS do
			const fixtures = light.Fixtures[key]
			if fixtures == nil then
				continue
			end
			for _, fixture in fixtures do
				for _, lamp in fixture.Lamps do
					if off then
						lamp.Part.Material = LAMP_OFF_MATERIAL
						lamp.Part.Color = LAMP_OFF_COLOR
					else
						lamp.Part.Material = lamp.Material
						lamp.Part.Color = lamp.Color
					end
				end
				for _, item in fixture.Lights do
					item.Enabled = not off
				end
				fixture.Lit = true
				fixture.Live = true
			end
		end
		off = not off
		task.wait(wait)
	end
	for _, key in OMEN_GROUPS do
		const fixtures = light.Fixtures[key]
		if fixtures == nil then
			continue
		end
		for _, fixture in fixtures do
			fixture.Lit = nil
			fixture.Live = nil
		end
	end
end

-- The local character stands in the zone the server attacks (TRL, flat radius)
local function inZone(ctx: Effect.Context): boolean
	const root = rootOf(Players.LocalPlayer)
	const point = ctx.Point(ZONE_POINT)
	if root == nil or point == nil then
		return false
	end
	const offset = root.Position - point.Position
	return Vector2.new(offset.X, offset.Z).Magnitude <= ATTACK_RADIUS
end

return {
	Ref = "ANM-020",
	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		local session: Session? = nil
		Vide.effect(function()
			const phase = occ.Record().Phase
			-- Signal is the omen (TASK-444, restaurant): the dark starts with the power cut (Active); a record first seen
			-- Failed is still dark (the power is out until the breaker / the restore)
			const dark = phase == "Active" or (phase == "Failed" and session == nil)
			Vide.untrack(function()
				if dark and session == nil then
					session = begin(ctx, occ)
				elseif not dark and session ~= nil then
					-- Failed keeps the dark until the server brings the power back (record leaves / restore cue)
					if phase == "Resolved" then
						finish(session :: Session)
					end
				end
			end)
		end)
		Vide.cleanup(function()
			if session ~= nil then
				finish(session :: Session)
				session = nil
			end
		end)
	end,
	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "blackout_start" then
			-- no power, no cameras (TASK-337): a watcher is cut back to the head
			Watch.Interrupt()
			-- the owner's "lights off" snap (TASK-444); the old crack while that row has no audio
			if ctx.Play("lights_off") == nil then
				ctx.Play("post_tunk")
			end
			ctx.Play("neon_click")
		elseif cue.Cue == "blackout_warn" then
			flicker(ctx)
		elseif cue.Cue == "blackout_restore" then
			const session = current
			if session ~= nil then
				finish(session)
			end
			ctx.Play("neon_click")
			ctx.Play("post_buzz")
		elseif cue.Cue == "jumpscare" then
			if cue.Entity ~= 0 then
				-- restaurant (TASK-444): only the player the server made pay
				if cue.Entity ~= Players.LocalPlayer.UserId % ENTITY_MOD then
					return
				end
			elseif not inZone(ctx) then
				return
			end
			const session = current
			if session ~= nil then
				hideShape(session, false)
			end
			Jumpscare.Show(ctx)
		end
	end,
} :: Effect.Module
