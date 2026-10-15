--!strict
--[[
	ANM-005 The Raincoat Lady, client effect (TASK-112; anomalies.md N5; style guide §2.4, §4.3, §10; AST-059,
	AST-095; DEC-195, DEC-203). Presents what AnomalyService/Anomalies/ANM-005 (TASK-111) decides; never a verb or a
	payment.

	Already done elsewhere (TASK-110): eyes closed (RigController, Variant "raincoat", when `EyesClosed` exists).
	Here, bound to the rig's Variant (Kit.WhileVariant, so it stays while she walks off):
	  - placeholder raincoat until AST-059 (TASK-125): yellow `#F2C230` coat over the torso, sleeves, green boots,
	    local parts welded to the limbs. The face stays visible (full, kind face: not N1). Skipped when the rig
	    already wears a raincoat piece of the kit (an `Accessory`/Outfit containing "raincoat");
	  - drips (owner request 2026-10-14, Provisional): water-blue square drops on every R6 body part falling with gravity,
    plus a ground emitter at her feet that spreads flat puddle quads; both stop (and die out) when the Variant leaves.
	  - cue `raincoat_drip` (she reaches Q1): a puddle under her that grows to Ø 2.5 while she stands there, and dries
	    out a few seconds after she leaves. A late joiner (Mount long after the start) gets the puddle under her if she
	    is standing still.
	No rain over the trailer and no "Thank you, dear.": DEC-195 keeps them out (no cue for them in Content).
	Nothing points at her (§4.4): the water is the sign.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Effect)
local Kit = require(script.Parent.Kit.CustomerActor)

const VARIANT = "raincoat"
const COAT = Color3.fromHex("#F2C230") -- reserved raincoat yellow (style guide §2.4)
const BOOTS = Color3.fromHex("#5FA36A")
const DROP = Color3.fromHex("#6FB6EA") -- water blue drops (§10)
const PUDDLE = Color3.fromHex("#4C6A8A") -- wet ground at night (same as the ending's puddle)
-- Assets/textures/vfx/T_VFX_Square.png (white 64x64 square), uploaded 2026-10-14.
const SQUARE_TEXTURE = "rbxassetid://136202879109639"
const DROP_NAME = "RaincoatDrips"
const SPREAD_NAME = "RaincoatSpread"
const BODY = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
const DROP_RATE = 1.5 -- per body part (6 parts: a constant trickle, ~9/s in total)
const DROP_GRAVITY = 30 -- studs/s^2 down
const DROP_SQUASH = -0.6 -- ParticleEmitter.Squash: stretches the square into a drop (flip the sign if it reads wide)
const PUDDLE_WATER = Color3.fromHex("#5C86B0") -- water spreading on the ground
const SPREAD_RATE = 5
const EMIT_NEAR = 80 -- studs from the camera: farther away the emitters are off
const EMIT_STEP = 0.5
const EMIT_LINGER = 2.5 -- s: longest particle life + margin before the emitters are destroyed
const LOCAL_TAG = "RaincoatLocal" -- attribute on the local pieces

const PUDDLE_NAME = "RaincoatPuddle"
const PUDDLE_START = 0.6 -- studs Ø
const PUDDLE_MAX = 2.5 -- studs Ø (AST-095)
const PUDDLE_GROW = 12 -- s from start to max
const PUDDLE_NEAR = 2.5 -- studs: she still stands on it
const PUDDLE_DRY_DELAY = 6 -- s after she leaves
const PUDDLE_DRY = 3 -- s of fade
const PUDDLE_ALPHA = 0.3
const PUDDLE_STEP = 0.1
const LATE = 6 -- s after the start: a Mount this late is a late joiner
const STILL = 0.3 -- studs moved in 1 s that still count as standing

-- Pieces that the kit raincoat (AST-059) would bring: if any is there, no placeholder.
local function wearsKitRaincoat(model: Model): boolean
	const outfit = model:GetAttribute("Outfit")
	if typeof(outfit) == "string" and string.find(string.lower(outfit), "raincoat", 1, true) then
		return true
	end
	for _, child in model:GetChildren() do
		const accessory = child:GetAttribute("Accessory")
		if typeof(accessory) == "string" and string.find(string.lower(accessory), "raincoat", 1, true) then
			return true
		end
	end
	return false
end

local function piece(name: string, size: Vector3, color: Color3): Part
	const part = Kit.Part(name, size, color)
	part.CastShadow = true
	part:SetAttribute(LOCAL_TAG, true)
	return part
end

-- Placeholder coat (AST-059 until TASK-125). Returns the local parts.
local function dressCoat(model: Model): { BasePart }
	const parts: { BasePart } = {}
	if wearsKitRaincoat(model) then
		return parts
	end
	const torso = Kit.Limb(model, "Torso")
	if torso ~= nil then
		const size = torso.Size
		const coat = piece("Raincoat", Vector3.new(size.X * 1.12, size.Y * 1.45, size.Z * 1.2), COAT)
		Kit.Attach(coat, torso, CFrame.new(0, -size.Y * 0.22, 0))
		table.insert(parts, coat)
	end
	for _, side in { "Left", "Right" } do
		const arm = Kit.Limb(model, `{side} Arm`)
		if arm ~= nil then
			const size = arm.Size
			const sleeve = piece("RaincoatSleeve", Vector3.new(size.X * 1.15, size.Y * 0.8, size.Z * 1.15), COAT)
			Kit.Attach(sleeve, arm, CFrame.new(0, size.Y * 0.1, 0))
			table.insert(parts, sleeve)
		end
		const leg = Kit.Limb(model, `{side} Leg`)
		if leg ~= nil then
			const size = leg.Size
			const boot = piece("RaincoatBoot", Vector3.new(size.X * 1.12, size.Y * 0.35, size.Z * 1.15), BOOTS)
			Kit.Attach(boot, leg, CFrame.new(0, -size.Y * 0.325, 0))
			table.insert(parts, boot)
		end
	end
	return parts
end

-- Water emitters (owner request 2026-10-14, Provisional): the Raincoat Lady is a wet sheep dripping on a dry night.
-- Every R6 body part drips; one more emitter at her feet spreads a puddle on the ground. Presentation only.
local function dripEmitter(host: BasePart): ParticleEmitter
	const emitter = Instance.new("ParticleEmitter")
	emitter.Name = DROP_NAME
	emitter.Texture = SQUARE_TEXTURE
	emitter.Color = ColorSequence.new(DROP)
	emitter.LightEmission = 0.1
	emitter.LightInfluence = 1
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.6, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new(0.1)
	emitter.Squash = NumberSequence.new(DROP_SQUASH)
	emitter.Lifetime = NumberRange.new(0.5, 0.8)
	emitter.Speed = NumberRange.new(0, 0.4)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Acceleration = Vector3.new(0, -DROP_GRAVITY, 0)
	emitter.Rate = DROP_RATE
	emitter.Parent = host -- Box shape of the part: drops are born inside the body
	return emitter
end

-- Puddle on the ground at her feet: flat quads that open outward and fade (continuous while she is the Lady).
local function spreadEmitter(model: Model, root: BasePart): ParticleEmitter
	-- feet height in root space (lowest leg bottom), so it follows the rig scale
	local feet = -root.Size.Y / 2 - 2
	for _, name in { "Left Leg", "Right Leg" } do
		const leg = Kit.Limb(model, name)
		if leg ~= nil then
			feet = math.min(feet, root.CFrame:PointToObjectSpace(leg.Position - Vector3.new(0, leg.Size.Y / 2, 0)).Y)
		end
	end
	const attachment = Instance.new("Attachment")
	attachment.Name = "RaincoatSpread"
	attachment.Position = Vector3.new(0, feet + 0.08, 0)
	attachment.Parent = root

	const emitter = Instance.new("ParticleEmitter")
	emitter.Name = SPREAD_NAME
	emitter.Texture = SQUARE_TEXTURE
	emitter.Color = ColorSequence.new(PUDDLE_WATER)
	emitter.LightEmission = 0
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.55),
		NumberSequenceKeypoint.new(0.6, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 2.2) })
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel -- plane follows the outward (horizontal) velocity
	emitter.Shape = Enum.ParticleEmitterShape.Disc
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Lifetime = NumberRange.new(1.6, 2.2)
	emitter.Speed = NumberRange.new(0.5, 1)
	emitter.Drag = 1.2 -- very soft slowdown: opens like water spreading
	emitter.SpreadAngle = Vector2.new(0, 0)
	emitter.RotSpeed = NumberRange.new(0)
	emitter.Rate = SPREAD_RATE
	emitter.Parent = attachment
	return emitter
end

-- Drips on all 6 body parts + the ground puddle, while the rig is the Raincoat Lady.
local function dress(model: Model): Kit.Undo
	const made: { Instance } = {}
	const emitters: { ParticleEmitter } = {}
	for _, part in dressCoat(model) do
		table.insert(made, part)
	end
	for _, name in BODY do
		const limb = Kit.Limb(model, name)
		if limb ~= nil then
			const emitter = dripEmitter(limb)
			table.insert(emitters, emitter)
			table.insert(made, emitter)
		end
	end
	const root = Kit.Root(model)
	if root ~= nil then
		const spread = spreadEmitter(model, root)
		table.insert(emitters, spread)
		table.insert(made, spread)
		table.insert(made, spread.Parent :: Instance)
	end

	-- performance: emitters only run while the camera is near (re-checked twice a second)
	local running = true
	task.spawn(function()
		while running do
			const camera = workspace.CurrentCamera
			const anchor = Kit.Root(model)
			if camera ~= nil and anchor ~= nil then
				const near = (camera.CFrame.Position - anchor.Position).Magnitude <= EMIT_NEAR
				for _, emitter in emitters do
					emitter.Enabled = near
				end
			end
			task.wait(EMIT_STEP)
		end
	end)

	return function()
		running = false
		-- stop emitting and let the live particles die, then clean up (Fade.Out would clear them at once)
		for _, emitter in emitters do
			emitter.Enabled = false
		end
		for _, instance in made do
			if instance:IsA("ParticleEmitter") or instance:IsA("Attachment") then
				Debris:AddItem(instance, EMIT_LINGER)
			else
				instance:Destroy()
			end
		end
	end
end

-- Puddles by rig (one at a time per rig)
const puddles: { [Model]: BasePart } = setmetatable({}, { __mode = "k" }) :: any

local function setDiameter(puddle: BasePart, centre: Vector3, diameter: number)
	puddle.Size = Vector3.new(0.04, diameter, diameter)
	puddle.CFrame = CFrame.new(centre + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

-- Puddle under `model`; grows while she stands on it, dries after she leaves. `grown` 0..1 = head start.
local function puddleUnder(ctx: Effect.Context, model: Model, grown: number)
	const existing = puddles[model]
	if existing ~= nil and existing.Parent ~= nil then
		return
	end
	const centre = Kit.Ground(ctx, model)
	if centre == nil then
		return
	end
	const puddle = Kit.Part(PUDDLE_NAME, Vector3.one, PUDDLE)
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Material = Enum.Material.Glass
	puddle.Reflectance = 0.15
	puddle.Transparency = PUDDLE_ALPHA
	local size = PUDDLE_START + (PUDDLE_MAX - PUDDLE_START) * math.clamp(grown, 0, 1)
	setDiameter(puddle, centre, size)
	puddle.Parent = ctx.Folder()
	puddles[model] = puddle

	task.spawn(function()
		local leftAt: number? = nil
		while puddle.Parent ~= nil do
			const root = Kit.Root(model)
			const near = root ~= nil
				and model:IsDescendantOf(workspace)
				and Kit.VariantOf(model) == VARIANT
				and (Vector3.new(root.Position.X, centre.Y, root.Position.Z) - centre).Magnitude <= PUDDLE_NEAR
			if near then
				leftAt = nil
				if size < PUDDLE_MAX then
					size = math.min(PUDDLE_MAX, size + (PUDDLE_MAX - PUDDLE_START) * PUDDLE_STEP / PUDDLE_GROW)
					setDiameter(puddle, centre, size)
				end
			else
				const now = os.clock()
				const since = leftAt or now
				leftAt = since
				const dry = (now - since - PUDDLE_DRY_DELAY) / PUDDLE_DRY
				if dry >= 1 then
					break
				elseif dry > 0 then
					puddle.Transparency = PUDDLE_ALPHA + (1 - PUDDLE_ALPHA) * dry
				end
			end
			task.wait(PUDDLE_STEP)
		end
		if puddles[model] == puddle then
			puddles[model] = nil
		end
		puddle:Destroy()
	end)
end

-- Late joiner: she has been around for a while; if she stands still now, the puddle is already there.
local function lateJoin(ctx: Effect.Context, occ: Effect.Occurrence, model: Model)
	if occ.MountedAt - occ.Record().StartedAt < LATE then
		return
	end
	task.spawn(function()
		const root = Kit.Root(model)
		if root == nil then
			return
		end
		const before = root.Position
		task.wait(1)
		if root.Parent ~= nil and (root.Position - before).Magnitude <= STILL and Kit.VariantOf(model) == VARIANT then
			puddleUnder(ctx, model, 1)
		end
	end)
end

return {
	Ref = "ANM-005",
	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		Vide.cleanup(Kit.Follow(ctx, occ, VARIANT, "raincoat_look", function(model: Model): Kit.Undo
			lateJoin(ctx, occ, model)
			return dress(model)
		end))
	end,
	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue ~= "raincoat_drip" then
			return
		end
		const model = if cue.Entity > 0 then ctx.Npc(cue.Entity) else nil
		if model ~= nil and Kit.VariantOf(model) == VARIANT then
			puddleUnder(ctx, model, 0)
		end
	end,
} :: Effect.Module
