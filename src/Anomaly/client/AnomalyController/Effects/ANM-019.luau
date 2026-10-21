--!strict
--[[
	ANM-019 The roof walker, client effect: "don't look up" (TASK-484; DEC-294, DEC-295 / Q-367 A, Q-396;
	design/horror-cinematic.md ANM-019 §6.1). Presents only: who looked up and who pays is the server's
	(Anomalies/ANM-019, Gaze pitch; numbers in Rules/ANM-019).

	The walk itself (steps over the head, dust, lamps, whispers "DON'T LOOK UP", heartbeat, bars, the soft nudge down)
	is the horror scene anm_019_roof_walker (Content.HorrorScenes, Scene/Kits Roof + HeadDown). Here (Q-396, owner
	2026-10-19: "the ceiling stays clean, I look, nothing happens, I die later"):
	  * the record turning Signal (it lands on the roof) cuts a security-camera watcher back to the head (Kit/Watch);
	  * Signs, while Signal / Active: under the walk (Kits.RoofAt) a dark wet stain soaks through the ceiling and
	    follows it, bloody prints of its steps bleed through behind it, red drops fall from the stain and splat on the
	    floor (the splats stay until the record goes), the ceiling creaks above. Something is up there, and it is
	    right over you at ~7 s;
	  * the look, a readable countdown (Active, from LOOK_FROM s): this client reads its own camera at once (no
	    network wait). Past LOOK_PITCH the stain slides to where the player looks and opens its eyes, a hiss; while
	    the look stays up the heat climbs to 1 in LOOK_WARN s: blur, red, drained colour, a racing heart, shaking.
	    LOOK_WARN < Rules LookGrace (1.2 s), so the full warning always comes before the server can count it.
	    Looking down in time: the eyes close, it creaks and slides back to the walk, the heat falls, nothing paid;
	  * the cue `jumpscare` with Entity = this player (UserId % 65536) = the server caught this player: the shape
	    drops head first out of the ceiling where the stain is (where the player looked) into the face, hangs with its
	    white eyes, jolt, FOV, a pull towards it, the face (Kit/Jumpscare, ~0.6 s, Mild DEC-172), yanked back up.
	    ~1.4 s, presentation only; the sanity hit (-RuleBroken) lands on the same server tick.
	PROVISIONAL (TASK-484, Q-396): the shape, stain, prints and drops are local Parts until the art-director's sheet;
	LOOK_PITCH / LOOK_FROM mirror Rules/ANM-019 (rules are server only, T10) and must move with them.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Effect)
local Kits = require(script.Parent.Parent.Scene.Kits)
local Jumpscare = require(script.Parent.Kit.Jumpscare)
local Watch = require(script.Parent.Kit.Watch)

const ENTITY_MOD = 65536 -- AnomalyCue.Entity range (server: UserId % 65536)
-- the look (mirror of Rules/ANM-019: LookPitch 22, LookFrom 1, LookGrace 1.2)
-- TASK-593: was 35. The shop's ceiling is ~4.4 studs over the eye (MAP01 Trailer.Shell.Ceiling 9.4, floor 0.45), so
-- looking at the stain a few studs ahead is ~25-30 degrees and never counted: owner Play 2026-10-19 "I look up, nothing"
const LOOK_PITCH = 22 -- degrees above the horizon
const LOOK_FROM = 1 -- s into Active before the look counts
const LOOK_WARN = 0.95 -- s of a held look up to the full warning (< LookGrace)
const LOOK_COOL = 0.5 -- s the heat takes to fall from 1 to 0 once the look is down
-- studs camera-head: farther = not first person (the server never counts it either). TASK-593: was 2.5, too tight
-- for the head offset + the horror shake / nudge of the scene; the camera is LockFirstPerson in play anyway
const FIRST_PERSON = 5
-- signs
const PROBE_UP = 40 -- studs up from the eye to find the ceiling
const PROBE_DOWN = 30 -- studs down from the ceiling to find the floor
const OPEN_ABOVE = 10 -- studs above the eye when there is no ceiling (outside)
const UNDER = 0.06 -- studs under the ceiling the stain and prints sit
const STAIN_COLOR = Color3.fromHex("#2A0A0C")
const STAIN_FROM = 1.6 -- studs of the stain when it lands
const STAIN_TO = 4.2 -- studs when it is right over the player
const STAIN_LOOK = 5.5 -- studs when it is looking back
const STAIN_FOLLOW = 3 -- 1/s it eases towards the walk
const STAIN_SNAP = 9 -- 1/s it slides towards the look
const PRINT_COLOR = Color3.fromHex("#4A0B0E")
const PRINT_EVERY = 2.2 -- studs of walk between two prints
const PRINT_SIDE = 0.55 -- studs left / right of the line
const PRINT_LIFE = 7 -- s a print takes to fade
const DRIP_COLOR = Color3.fromHex("#7A0E12")
const DRIP_EVERY = { 0.45, 0.95 } -- s between two drops
const DRIP_FALL = 60 -- studs/s^2
const SPLAT_MAX = 36 -- splats on the floor at most (the oldest go)
const CREAK_EVERY = { 2.6, 4.2 } -- s between two creaks above
const CREAK_KEY = "floor_creak"
const HISS_KEY = "suspense_hiss"
const BEAT_KEY = "heartbeat"
const BREATH_KEY = "breath_held"
const LOOK_BLUR = 16 -- BlurEffect.Size at full heat
const LOOK_TINT = Color3.fromRGB(255, 120, 110)
const TINT_NAME = "ANM019_Look"
-- the drop
const HANG_AHEAD = 3.2 -- studs ahead of the eye it hangs
const HANG_DROP = 0.22 -- s of the fall
const HANG_HOLD = 0.4 -- s it hangs there before the face
const PULL_UP = 0.35 -- s it is yanked back up
const SHADOW_COLOR = Color3.fromHex("#0B0B12")
const EYE_COLOR = Color3.fromHex("#F4F1E8")
const DROP_KEY = "shadow_whoosh"
const HANG_KEY = "steps_stop"

type Shape = { Model: Model, Eyes: { BasePart } }

-- What the live occurrence shows (shared with the drop: it falls out of the stain)
type Live = {
	Stain: Part,
	Eyes: { BasePart },
	At: Vector3, -- stain centre (just under the ceiling)
	Size: number,
	Heat: number, -- 0..1 countdown of the look
	Dropped: boolean,
}

local busy = false
local live: Live? = nil

local function part(parent: Instance, name: string, size: Vector3, at: CFrame, color: Color3, shape: Enum.PartType?): Part
	const piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Shape = shape or Enum.PartType.Block
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.CFrame = at
	piece.Parent = parent
	return piece
end

local function rayParams(ctx: Effect.Context): RaycastParams
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = { ctx.Folder() }
	const character = Players.LocalPlayer.Character
	if character ~= nil then
		table.insert(ignore, character)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

-- Y of the ceiling underside above the flat point (from the eye's height); open sky = a little above the eye
local function ceilingAt(ctx: Effect.Context, flat: Vector3, eyeY: number): number
	const hit = Workspace:Raycast(Vector3.new(flat.X, eyeY, flat.Z), Vector3.new(0, PROBE_UP, 0), rayParams(ctx))
	return if hit ~= nil then hit.Position.Y else eyeY + OPEN_ABOVE
end

local function floorAt(ctx: Effect.Context, from: Vector3): Vector3?
	const hit = Workspace:Raycast(from - Vector3.new(0, 0.2, 0), Vector3.new(0, -PROBE_DOWN, 0), rayParams(ctx))
	return if hit ~= nil then hit.Position else nil
end

-- A flat disc lying under a ceiling / on a floor (the cylinder's axis turned vertical)
local function disc(parent: Instance, name: string, at: Vector3, size: number, color: Color3): Part
	const piece = part(parent, name, Vector3.new(0.04, size, size), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
	piece.Material = Enum.Material.Glass -- a wet sheen
	piece.Reflectance = 0.05
	return piece
end

local function eye(): CFrame?
	const view = Workspace.CurrentCamera
	return if view ~= nil then view.CFrame else nil
end

-- Degrees above the horizon of this client's look in first person, nil otherwise (third person, dead, no head)
local function lookPitch(): number?
	const view = Workspace.CurrentCamera
	const character = Players.LocalPlayer.Character
	const head = if character ~= nil then character:FindFirstChild("Head") else nil
	const humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if view == nil or head == nil or not head:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	if (view.CFrame.Position - head.Position).Magnitude > FIRST_PERSON then
		return nil
	end
	return math.deg(math.asin(math.clamp(view.CFrame.LookVector.Y, -1, 1)))
end

-- Where the look meets the ceiling (flat point), or nil when it hits nothing close
local function lookHit(ctx: Effect.Context, view: CFrame): Vector3?
	const hit = Workspace:Raycast(view.Position, view.LookVector * PROBE_UP, rayParams(ctx))
	return if hit ~= nil and hit.Normal.Y < -0.5 then hit.Position else nil
end

-- One red drop from the stain to the floor, then a splat that stays
local function drip(ctx: Effect.Context, folder: Folder, from: Vector3, splats: { Part }, rng: Random)
	const start = from + Vector3.new(rng:NextNumber(-0.8, 0.8), -0.12, rng:NextNumber(-0.8, 0.8))
	const floor = floorAt(ctx, start)
	if floor == nil then
		return
	end
	const drop = part(ctx.Folder(), "ANM019_Drip", Vector3.new(0.16, 0.26, 0.16), CFrame.new(start), DRIP_COLOR, Enum.PartType.Ball)
	drop.Material = Enum.Material.Glass
	const height = start.Y - floor.Y
	const fall = math.sqrt(2 * math.max(height, 0.1) / DRIP_FALL)
	TweenService:Create(drop, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(floor + Vector3.new(0, 0.1, 0)) }):Play()
	task.delay(fall, function()
		drop:Destroy()
		if folder.Parent == nil then
			return
		end
		const splat = disc(folder, "ANM019_Splat", floor + Vector3.new(0, 0.03, 0), rng:NextNumber(0.35, 0.8), DRIP_COLOR)
		table.insert(splats, splat)
		if #splats > SPLAT_MAX then
			const oldest = table.remove(splats, 1)
			if oldest ~= nil then
				oldest:Destroy()
			end
		end
	end)
end

-- A bloody print of a step bleeding through the ceiling, fading out
local function bleed(ctx: Effect.Context, at: Vector3, heading: Vector3, foot: number)
	const side = Vector3.new(-heading.Z, 0, heading.X)
	const centre = at + side * foot * PRINT_SIDE
	const piece = part(ctx.Folder(), "ANM019_Print", Vector3.new(0.6, 0.04, 1.3), CFrame.lookAt(centre, centre + heading), PRINT_COLOR)
	piece.Transparency = 0.15
	TweenService:Create(piece, TweenInfo.new(PRINT_LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	task.delay(PRINT_LIFE, piece.Destroy, piece)
end

-- The look's blur / red / drained colour (own effects, so the scene's Blur / Grade steps are left alone)
type Look = { Blur: BlurEffect, Tint: ColorCorrectionEffect }

local function lookEffects(): Look
	const blur = Instance.new("BlurEffect")
	blur.Name = TINT_NAME
	blur.Size = 0
	blur.Parent = Lighting
	const tint = Instance.new("ColorCorrectionEffect")
	tint.Name = TINT_NAME
	tint.Parent = Lighting
	return { Blur = blur, Tint = tint }
end

local function applyHeat(look: Look, heat: number)
	const k = heat * heat -- slow start, sharp end: the last instant is the loudest
	look.Blur.Size = LOOK_BLUR * k
	look.Tint.TintColor = Color3.new(1, 1, 1):Lerp(LOOK_TINT, k)
	look.Tint.Saturation = -0.5 * k
	look.Tint.Contrast = 0.25 * k
end

-- Signs + the look countdown while the walk is on (Signal / Active), under `folder` (the Mount's: the splats stay in it
-- until the record goes); returns the stop function
local function haunt(ctx: Effect.Context, occ: Effect.Occurrence, folder: Folder, activeAt: () -> number?): () -> ()
	const view0 = eye()
	const start = Kits.RoofAt() or (if view0 ~= nil then view0.Position else Vector3.zero)
	const eyeY0 = if view0 ~= nil then view0.Position.Y else start.Y
	const at0 = Vector3.new(start.X, ceilingAt(ctx, start, eyeY0) - UNDER, start.Z)
	const stain = disc(folder, "ANM019_Stain", at0, STAIN_FROM, STAIN_COLOR)
	stain.Transparency = 0.25
	const eyes: { BasePart } = {}
	for index = 1, 2 do
		const piece = part(folder, "ANM019_Eye", Vector3.new(0.42, 0.05, 0.22), CFrame.new(at0), EYE_COLOR)
		piece.Material = Enum.Material.Neon
		piece.Transparency = 1
		eyes[index] = piece
	end
	const state: Live = { Stain = stain, Eyes = eyes, At = at0, Size = STAIN_FROM, Heat = 0, Dropped = false }
	live = state
	const look = lookEffects()
	const splats: { Part } = {}
	const rng = Random.new(occ.Id * 7919 + 19)
	local lastPrint: Vector3? = nil
	local foot = 1
	local nextDrip = os.clock() + 0.6
	local nextCreak = os.clock() + 1.5
	local nextBeat = 0
	local looking = false
	local alive = true

	const connection = RunService.RenderStepped:Connect(function(dt: number)
		if not alive then
			return
		end
		const view = eye()
		if view == nil then
			return
		end
		const clock = os.clock()
		const walk = Kits.RoofAt()
		const since = activeAt()
		-- the countdown: this client's own look, at once
		const pitch = lookPitch()
		const counts = not state.Dropped and since ~= nil and clock - since >= LOOK_FROM
		const up = counts and pitch ~= nil and pitch > LOOK_PITCH
		if up and not looking then
			looking = true
			ctx.Play(HISS_KEY, state.At)
			ctx.Play(BREATH_KEY)
			for _, piece in eyes do
				piece.Transparency = 0
			end
		elseif not up and looking then
			looking = false
			ctx.Play(CREAK_KEY, state.At) -- it lets go and moves on
			for _, piece in eyes do
				piece.Transparency = 1
			end
		end
		state.Heat = if up
			then math.min(1, state.Heat + dt / LOOK_WARN)
			else math.max(0, state.Heat - dt / LOOK_COOL)
		applyHeat(look, if state.Dropped then 0 else state.Heat)
		if state.Heat > 0 and clock >= nextBeat then
			ctx.Play(BEAT_KEY)
			nextBeat = clock + 0.62 - 0.4 * state.Heat
			const camera = Kits.Camera()
			if camera ~= nil then
				camera:HorrorShake("Step", 0.6 + 2.4 * state.Heat)
			end
		end
		-- the stain: on the walk, or on the spot the player looks at while the look is up
		local target = state.At
		local size = STAIN_FROM
		local rate = STAIN_FOLLOW
		if walk ~= nil then
			const ceiling = ceilingAt(ctx, walk, view.Position.Y)
			target = Vector3.new(walk.X, ceiling - UNDER, walk.Z)
			const flat = Vector2.new(walk.X - view.Position.X, walk.Z - view.Position.Z).Magnitude
			size = STAIN_FROM + (STAIN_TO - STAIN_FROM) * math.clamp(1 - flat / 25, 0, 1)
			-- prints bleed through behind it
			if lastPrint == nil or (walk - (lastPrint :: Vector3)).Magnitude >= PRINT_EVERY then
				if lastPrint ~= nil then
					const heading = (walk - (lastPrint :: Vector3)) * Vector3.new(1, 0, 1)
					if heading.Magnitude > 0.01 then
						bleed(ctx, target - Vector3.new(0, 0.01, 0), heading.Unit, foot)
						foot = -foot
					end
				end
				lastPrint = walk
			end
		end
		if looking then
			const hit = lookHit(ctx, view)
			if hit ~= nil then
				target = hit - Vector3.new(0, UNDER, 0)
			end
			size = STAIN_LOOK
			rate = STAIN_SNAP
		end
		const k = 1 - math.exp(-rate * dt)
		state.At = state.At:Lerp(target, k)
		state.Size += (size * (1 + 0.15 * state.Heat) - state.Size) * k
		stain.CFrame = CFrame.new(state.At) * CFrame.Angles(0, 0, math.rad(90))
		stain.Size = Vector3.new(0.04, state.Size, state.Size)
		-- the eyes look down out of the stain, at the player
		const toward = (view.Position - state.At) * Vector3.new(1, 0, 1)
		const facing = if toward.Magnitude > 0.01 then toward.Unit else Vector3.new(0, 0, -1)
		const across = Vector3.new(-facing.Z, 0, facing.X)
		for index, piece in eyes do
			const offset = across * (if index == 1 then -0.4 else 0.4) + facing * 0.5
			const point = state.At + offset - Vector3.new(0, 0.03, 0)
			piece.CFrame = CFrame.lookAt(point, point + facing)
		end
		-- drops and creaks
		if clock >= nextDrip then
			nextDrip = clock + rng:NextNumber(DRIP_EVERY[1], DRIP_EVERY[2]) * (if looking then 0.4 else 1)
			drip(ctx, folder, state.At, splats, rng)
		end
		if clock >= nextCreak then
			nextCreak = clock + rng:NextNumber(CREAK_EVERY[1], CREAK_EVERY[2])
			ctx.Play(CREAK_KEY, state.At + Vector3.new(0, 1, 0))
		end
	end)

	return function()
		if not alive then
			return
		end
		alive = false
		connection:Disconnect()
		if live == state then
			live = nil
		end
		look.Blur:Destroy()
		look.Tint:Destroy()
		-- the stain and the eyes fade; the splats stay until the record goes (the Mount destroys the folder)
		for _, piece in eyes do
			piece.Transparency = 1
		end
		TweenService:Create(stain, TweenInfo.new(2.5), { Transparency = 1 }):Play()
		task.delay(2.6, function()
			stain:Destroy()
			for _, piece in eyes do
				piece:Destroy()
			end
		end)
	end
end

-- Upside-down silhouette (head at the bottom, long arms hanging past it), built at the origin facing -Z; the pivot is
-- the head, so PivotTo puts the face where it hangs
local function shape(folder: Folder): Shape
	const model = Instance.new("Model")
	model.Name = "ANM019_Drop"
	part(model, "Body", Vector3.new(1.9, 3.4, 0.7), CFrame.new(0, 1.9, 0), SHADOW_COLOR)
	part(model, "Head", Vector3.new(1.7, 1.7, 1.7), CFrame.new(0, -0.6, 0), SHADOW_COLOR, Enum.PartType.Ball)
	part(model, "ArmL", Vector3.new(0.4, 3.6, 0.4), CFrame.new(-1.25, 0.2, 0) * CFrame.Angles(0, 0, math.rad(-8)), SHADOW_COLOR)
	part(model, "ArmR", Vector3.new(0.4, 3.6, 0.4), CFrame.new(1.25, 0.2, 0) * CFrame.Angles(0, 0, math.rad(8)), SHADOW_COLOR)
	const eyes: { BasePart } = {
		part(model, "EyeL", Vector3.new(0.38, 0.22, 0.1), CFrame.new(-0.36, -0.75, -0.82), EYE_COLOR),
		part(model, "EyeR", Vector3.new(0.38, 0.22, 0.1), CFrame.new(0.36, -0.75, -0.82), EYE_COLOR),
	}
	for _, piece in eyes do
		piece.Material = Enum.Material.Neon
		piece.Transparency = 1
	end
	model.WorldPivot = CFrame.new(0, -0.6, 0)
	model.Parent = folder
	return { Model = model, Eyes = eyes }
end

-- It drops out of the ceiling where the stain is (where the player looked) into the face, hangs, the face, it is
-- gone (one at a time; yields ~1.4 s)
local function drop(ctx: Effect.Context)
	if busy then
		return
	end
	busy = true
	const view = Workspace.CurrentCamera
	if view == nil then
		busy = false
		Jumpscare.Show(ctx)
		return
	end
	const eyePos = view.CFrame.Position
	const _, yaw = view.CFrame:ToOrientation()
	const forward = CFrame.fromOrientation(0, yaw, 0).LookVector
	const shown = live
	local ceiling = ceilingAt(ctx, eyePos, eyePos.Y)
	if shown ~= nil then
		shown.Dropped = true
		ceiling = shown.At.Y
		for _, piece in shown.Eyes do
			piece.Transparency = 1
		end
		shown.Stain.Transparency = 0.05
	end
	-- it hangs right in front of the face, a touch below the eye (the nudge pulls the look down onto it)
	const at = eyePos + forward * HANG_AHEAD - Vector3.new(0, 0.3, 0)
	const facing = CFrame.lookAt(at, Vector3.new(eyePos.X, at.Y, eyePos.Z))
	const fromY = math.max(ceiling + 2.5, at.Y + 4)
	const from = facing + Vector3.new(0, fromY - at.Y, 0)
	const built = shape(ctx.Folder())
	const model = built.Model
	model:PivotTo(from)
	ctx.Play(DROP_KEY, nil, true)
	const pivot = Instance.new("CFrameValue")
	pivot.Value = from
	pivot.Changed:Connect(function(value: CFrame)
		if model.Parent ~= nil then
			model:PivotTo(value)
		end
	end)
	TweenService:Create(pivot, TweenInfo.new(HANG_DROP, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = facing }):Play()
	task.wait(HANG_DROP)
	ctx.Play(HANG_KEY, at)
	for _, piece in built.Eyes do
		piece.Transparency = 0
	end
	const camera = Kits.Camera()
	if camera ~= nil then
		camera:HorrorShake("Jolt", 1)
		camera:HorrorFov(-5, 0, 0.9)
		camera:HorrorNudge(at, 3, 0.4)
	end
	-- it hangs and sways a touch
	TweenService
		:Create(pivot, TweenInfo.new(HANG_HOLD, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Value = facing * CFrame.Angles(0, 0, math.rad(6)),
		})
		:Play()
	task.wait(HANG_HOLD)
	task.spawn(Jumpscare.Show, ctx)
	TweenService:Create(pivot, TweenInfo.new(PULL_UP, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = from }):Play()
	task.wait(PULL_UP)
	pivot:Destroy()
	model:Destroy()
	busy = false
end

const RoofWalker: Effect.Module = {
	Ref = "ANM-019",

	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		local interrupted = false
		local activeAt: number? = nil
		local stop: (() -> ())? = nil
		const folder = Instance.new("Folder")
		folder.Name = "ANM019_Signs"
		folder.Parent = ctx.Folder()
		Vide.effect(function()
			const phase = occ.Record().Phase
			if phase == "Signal" or phase == "Active" then
				if not interrupted then
					interrupted = true
					Watch.Interrupt()
				end
				if phase == "Active" and activeAt == nil then
					activeAt = os.clock()
				end
				if stop == nil then
					stop = Vide.untrack(function()
						return haunt(ctx, occ, folder, function()
							return activeAt
						end)
					end)
				end
			elseif stop ~= nil then
				const ending = stop
				stop = nil
				ending()
				-- TASK-593: the walk is over, the steps stop now (the scene's Thud / Leave still play after this)
				Kits.RoofStop()
			end
		end)
		Vide.cleanup(function()
			if stop ~= nil then
				stop()
				stop = nil
			end
			Kits.RoofStop()
			folder:Destroy()
		end)
	end,

	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue ~= "jumpscare" or cue.Entity ~= Players.LocalPlayer.UserId % ENTITY_MOD then
			return
		end
		drop(ctx)
	end,
}

return RoofWalker
