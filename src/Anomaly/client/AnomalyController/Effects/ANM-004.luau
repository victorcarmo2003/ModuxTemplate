--!strict
--[[
	ANM-004 The copies, client effect (TASK-112; anomalies.md N4; style guide §2.4, §4.4; AST-062, AST-081).
	Presents what AnomalyService/Anomalies/ANM-004 (TASK-111) decides; never a verb or a payment.

	Already done elsewhere (TASK-110): the mirrored outfit sheet `<outfit>_mirror` (RigController, Variant
	"mirror"; inverted shirt text = the main read on a phone). Here:
	  - accessories on the other side: every accessory piece of the copy (parts with the `Accessory` attribute,
	    CrewRig.Build) welded to a side limb, or off-centre on the head/torso, is hidden locally
	    (LocalTransparencyModifier) and a local clone is welded at its mirror image on the opposite limb. The server's
	    pieces and welds are never changed. Bound to the rig's Variant (Kit.WhileVariant): the copy stays mirrored while
	    it walks off, and a pooled rig gets its pieces back.
	  - cue `mirror_smile` (DEC-195 flavor, sent on "Take Order" on the copy = the failure): the copy smiles and the
	    smile holds a second longer than it should (Smile for the cue Duration + HOLD_EXTRA), then the face goes back
	    to whatever the customer layer set; the walk-away plays `copy_backwalk` (AST-069; Id "" = nothing until the
	    clip exists) while the rig is still the copy.
	Nothing else differs from the original (AST-062 "Proibido": colour, size, face).

	"The copy knocks" (DEC-247, Provisional; server flow in Anomalies/ANM-004.luau). Cues:
	  - `copy_knock` (Entity = knock 1..3): the copy of the counter stands OUTSIDE the trailer back door, facing it, and
	    the `door_knock` sound plays at the door. Only for who is INSIDE the trailer (own character in the LightZone
	    LZ-1, the same volume VehicleService:IsInside reads): outside, nothing is built and nothing is heard. The copy
	    is a client-only actor (like the Walker): a local rig built with CrewRig.Build, Variant "mirror" (mirrored
	    outfit, normal skin, EyesWhite via RigController), anchored, no Humanoid, parented under ctx.Folder() while the
	    own character is inside and unparented when it leaves. Its look (species, outfit, type, pack) is the one of the
	    copy seen at the counter (read on `mirror_smile`); without it, a fallback look.
	  - `copy_grab`: the door was opened. The copy walks in through the door to the nearest body (the one that opened,
	    fainted by the server), a short lunge, then it fades (Kit/Fade, 2 s) and is destroyed. Mild: no blood, no weapon.
	  - `copy_vanish`: nobody opened: the copy fades (Kit/Fade, 2 s) and is destroyed.

	Provisional (frontend-coder): the clone is the same mesh, so a piece with its own handedness (watch face) reads
	"other wrist", not "mirrored mesh"; mirrored hair meshes (3 parted hairs, AST-062) come with the kit.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Zones = require(ReplicatedStorage.shared.Light.Zones)
local Effect = require(script.Parent.Parent.Effect)
local Fade = require(script.Parent.Kit.Fade)
local Kit = require(script.Parent.Kit.CustomerActor)
local Haptics = require(StarterPlayer.StarterPlayerScripts.client.Input.Haptics)
local VehicleRoot = require(ReplicatedStorage.shared.Vehicle.VehicleRoot)

const VARIANT = "mirror"
const ACCESSORY_ATTRIBUTE = "Accessory" -- CrewRig.Build marks every accessory piece
const CLONE_ATTRIBUTE = "MirrorOf" -- local clones (never confused with a server piece)
const CENTRE = 0.15 -- studs: head/torso pieces closer than this to the middle are symmetric enough
const SMILE = "Smile" -- Content.Looks.Expressions
const HOLD_EXTRA = 1 -- s: "o sorriso fica parado um segundo a mais"
const HOLD_STEP = 0.1
const BACKWALK = "copy_backwalk" -- Content.Animations (N4)
-- Door flow (DEC-247, Provisional numbers)
const DOOR_NAME = "Door_Back"
const INTERIOR_ZONE = "LZ-1" -- LightZone volume of the trailer interior (VehicleService:IsInside)
const KNOCK_SOUND = "door_knock"
const OUT_DISTANCE = 2.6 -- studs from the door centre to the copy, outside
const BODY_LIFT = 3 -- HumanoidRootPart over the ground (CrewRig.Build)
const GROUND_RAY = 14
const WATCH_STEP = 0.2 -- s between two "is the own player inside" looks
const MAX_LIFE = 40 -- s: a copy that never got its vanish / grab cue goes away alone
const WALK_IN = 0.5 -- s from the doorstep to the door
const LUNGE = 0.55 -- s from the door to the body
const LUNGE_STOP = 1.6 -- studs short of the body
const LUNGE_LEAN = math.rad(14)
const NPC_SET = "npc" -- Content.Animations.Locomotion
const OPPOSITE: { [string]: string } = {
	["Left Arm"] = "Right Arm",
	["Right Arm"] = "Left Arm",
	["Left Leg"] = "Right Leg",
	["Right Leg"] = "Left Leg",
}

-- Mirror image across the limb's YZ plane (R6: local X is the rig's side axis): S * cf * S, S = diag(-1, 1, 1).
local function reflect(cf: CFrame): CFrame
	const x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- Limb a piece is welded to (CrewRig.Build: WeldConstraint inside the piece, Part0 = limb).
local function anchorOf(piece: BasePart): BasePart?
	for _, child in piece:GetChildren() do
		if child:IsA("WeldConstraint") then
			const other = if child.Part0 == piece then child.Part1 else child.Part0
			if other ~= nil then
				return other
			end
		end
	end
	return nil
end

local function mirrorAccessories(model: Model): Kit.Undo
	const hidden: { BasePart } = {}
	const clones: { BasePart } = {}
	for _, child in model:GetChildren() do
		if not child:IsA("BasePart") or child:GetAttribute(ACCESSORY_ATTRIBUTE) == nil then
			continue
		end
		if child:GetAttribute(CLONE_ATTRIBUTE) ~= nil then
			continue
		end
		const anchor = anchorOf(child)
		if anchor == nil then
			continue
		end
		const offset = anchor.CFrame:ToObjectSpace(child.CFrame)
		const oppositeName = OPPOSITE[anchor.Name]
		if oppositeName == nil and math.abs(offset.X) < CENTRE then
			continue -- centred on the head/torso: the mirror image is the same place
		end
		const target = if oppositeName ~= nil then Kit.Limb(model, oppositeName) else anchor
		if target == nil then
			continue
		end
		const clone = child:Clone()
		for _, inner in clone:GetChildren() do
			if inner:IsA("WeldConstraint") or inner:IsA("JointInstance") then
				inner:Destroy()
			end
		end
		clone:SetAttribute(ACCESSORY_ATTRIBUTE, nil)
		clone:SetAttribute(CLONE_ATTRIBUTE, child.Name)
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.LocalTransparencyModifier = 0
		Kit.Attach(clone, target, reflect(offset))
		child.LocalTransparencyModifier = 1
		table.insert(hidden, child)
		table.insert(clones, clone)
	end
	return function()
		for _, clone in clones do
			clone:Destroy()
		end
		for _, piece in hidden do
			piece.LocalTransparencyModifier = 0
		end
	end
end

-- The copy at the back door (DEC-247) ---------------------------------------------------------------------------------

type Look = { Species: string, Outfit: string, CustomerType: string?, LookPack: string? }

type DoorGeo = {
	Center: Vector3, -- middle of the leaf
	Out: Vector3, -- flat unit vector from the trailer to the outside
	Bottom: number, -- Y of the lower edge of the leaf
}

type Copy = {
	Model: Model,
	Geo: DoorGeo,
	Alive: boolean,
	Seen: boolean, -- parented now (own character inside)
	Busy: boolean, -- a grab / fade is running: it owns the root CFrame
	Fade: Fade.Handle?,
	BornAt: number,
}

-- look of the copy seen at the counter (set on mirror_smile); the door copy is that same customer
local lastLook: Look? = nil
local copy: Copy? = nil

local function stringAttribute(model: Model, name: string): string?
	const value = model:GetAttribute(name)
	return if typeof(value) == "string" and value ~= "" then value else nil
end

local function rememberLook(model: Model)
	const species = stringAttribute(model, "Species")
	const outfit = stringAttribute(model, "Outfit")
	if species == nil or outfit == nil then
		return
	end
	lastLook = {
		Species = species,
		Outfit = outfit,
		CustomerType = stringAttribute(model, "CustomerType"),
		LookPack = stringAttribute(model, "LookPack"),
	}
end

-- Own character inside the trailer: LightZone LZ-1, the volume VehicleService:IsInside reads on the server.
local function insideTrailer(): boolean
	const character = Players.LocalPlayer.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	for _, instance in CollectionService:GetTagged(Zones.Tag) do
		if instance:IsA("BasePart") and instance:GetAttribute("ZoneId") == INTERIOR_ZONE then
			const zone = Zones.read(instance)
			return zone ~= nil and Zones.contains(zone, root.Position)
		end
	end
	return false
end

local function vehicleModel(ctx: Effect.Context): Instance?
	return VehicleRoot.Find(Vide.untrack(ctx.Round.Vehicle))
end

-- Door leaf and the outside direction (the vehicle axis that points from its centre toward the door)
local function doorGeo(ctx: Effect.Context): DoorGeo?
	const vehicle = vehicleModel(ctx)
	if vehicle == nil then
		return nil
	end
	const door = vehicle:FindFirstChild(DOOR_NAME, true)
	local centre: Vector3
	local size: Vector3
	if door ~= nil and door:IsA("Model") then
		const cf, extent = door:GetBoundingBox()
		centre, size = cf.Position, extent
	elseif door ~= nil and door:IsA("BasePart") then
		centre, size = door.Position, door.Size
	else
		return nil
	end
	const frame = VehicleRoot.Pivot(vehicle)
	const toDoor = Vector3.new(centre.X - frame.Position.X, 0, centre.Z - frame.Position.Z)
	local best = frame.RightVector
	local bestDot = -math.huge
	for _, axis in { frame.RightVector, -frame.RightVector, frame.LookVector, -frame.LookVector } do
		const flat = Vector3.new(axis.X, 0, axis.Z)
		if flat.Magnitude > 0.01 then
			const dot = flat.Unit:Dot(toDoor)
			if dot > bestDot then
				bestDot = dot
				best = flat.Unit
			end
		end
	end
	return { Center = centre, Out = best, Bottom = centre.Y - size.Y / 2 }
end

local function groundY(ctx: Effect.Context, model: Model, spot: Vector3, fallback: number): number
	const ignore: { Instance } = { model, ctx.Folder() }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	const hit = Workspace:Raycast(spot + Vector3.new(0, 2, 0), Vector3.new(0, -GROUND_RAY, 0), params)
	return if hit ~= nil then hit.Position.Y else fallback
end

local function stand(ctx: Effect.Context, entry: Copy): CFrame
	const spot = entry.Geo.Center + entry.Geo.Out * OUT_DISTANCE
	const y = groundY(ctx, entry.Model, spot, entry.Geo.Bottom) + BODY_LIFT
	const at = Vector3.new(spot.X, y, spot.Z)
	return CFrame.lookAt(at, at - entry.Geo.Out)
end

-- Local mirror rig (Pedestrian recipe): tagged, no Humanoid, anchored, no collision; dressed before it is parented
local function buildRig(ctx: Effect.Context): Model?
	const look: Look = lastLook
		or { Species = "penguin", Outfit = "civil_a", CustomerType = "office_worker", LookPack = "Day" } -- fallback look
	const options: CrewRig.BuildOptions = {
		Name = "MirrorCopy",
		CustomerType = look.CustomerType,
		Anchored = true,
		Tag = true,
		LookPack = CrewRig.AsPack(look.LookPack) or "Day",
		Cap = false,
	}
	const ok, result = pcall(function(): Model
		return CrewRig.Build(look.Species, look.Outfit, options)
	end)
	if not ok then
		warn(`[ANM-004] could not build the copy {look.Species}/{look.Outfit}: {result}`)
		return nil
	end
	const model = result :: Model
	const humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid:Destroy()
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	model:SetAttribute("Variant", VARIANT) -- RigController: mirrored outfit, EyesWhite
	ctx.Rig:Prepare(model)
	ctx.Anim:Bind(model, NPC_SET)
	return model
end

local function retire(entry: Copy)
	if not entry.Alive then
		return
	end
	entry.Alive = false
	if entry.Fade ~= nil then
		entry.Fade:Cancel()
	end
	if copy == entry then
		copy = nil
	end
	entry.Model:Destroy()
end

-- Parent while the own character is inside, unparent when it is not (the other players do not see the copy)
local function show(ctx: Effect.Context, entry: Copy, on: boolean)
	if on == entry.Seen then
		return
	end
	entry.Seen = on
	if on then
		entry.Model.Parent = ctx.Folder()
		Kit.WhileVariant(entry.Model, VARIANT, "mirror_accessories", mirrorAccessories)
	else
		entry.Model.Parent = nil
	end
end

local function watch(ctx: Effect.Context, entry: Copy)
	task.spawn(function()
		while entry.Alive do
			if os.clock() - entry.BornAt > MAX_LIFE then
				retire(entry)
				return
			end
			show(ctx, entry, insideTrailer())
			if entry.Seen then
				Kit.WhileVariant(entry.Model, VARIANT, "mirror_accessories", mirrorAccessories)
			end
			task.wait(WATCH_STEP)
		end
	end)
end

-- The copy at the door (built on the first knock heard from inside; nil when it cannot stand there)
local function ensureCopy(ctx: Effect.Context, geo: DoorGeo): Copy?
	if copy ~= nil and copy.Alive then
		return copy
	end
	const model = buildRig(ctx)
	if model == nil then
		return nil
	end
	const entry: Copy = { Model = model, Geo = geo, Alive = true, Seen = false, Busy = false, Fade = nil, BornAt = os.clock() }
	model.Parent = ctx.Folder() -- stand() raycasts with the model in the Workspace folder
	entry.Seen = true
	model:PivotTo(stand(ctx, entry))
	copy = entry
	Kit.WhileVariant(model, VARIANT, "mirror_accessories", mirrorAccessories)
	watch(ctx, entry)
	return entry
end

local function copyKnock(ctx: Effect.Context)
	if not insideTrailer() then
		return
	end
	const geo = doorGeo(ctx)
	if geo == nil then
		return
	end
	if ensureCopy(ctx, geo) == nil then
		return
	end
	ctx.Audio:Play(KNOCK_SOUND, geo.Center)
end

-- Fade-out of the copy (Kit/Fade, 2 s) and destroy
local function vanish(entry: Copy, duration: number)
	entry.Busy = true
	if entry.Fade ~= nil then
		entry.Fade:Cancel()
	end
	entry.Fade = Fade.Out(entry.Model, {
		Duration = duration,
		OnDone = function()
			retire(entry)
		end,
	})
end

local function copyVanish(cue: Effect.Cue)
	const entry = copy
	if entry == nil or not entry.Alive or entry.Busy then
		return
	end
	vanish(entry, cue.Row.Duration)
end

-- Root of the body nearest to the door (the one that opened it; the server fainted it)
local function nearestBody(geo: DoorGeo): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		const character = player.Character
		const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			const distance = (root.Position - geo.Center).Magnitude
			if distance < bestDistance then
				best = root
				bestDistance = distance
			end
		end
	end
	return best
end

-- The door was opened: in through the leaf, a short lunge at the body, then the fade.
local function copyGrab()
	const entry = copy
	if entry == nil or not entry.Alive or entry.Busy then
		return
	end
	entry.Busy = true
	const start = entry.Model:GetPivot()
	const geo = entry.Geo
	const doorAt = Vector3.new(geo.Center.X, start.Position.Y, geo.Center.Z)
	task.spawn(function()
		local t0 = os.clock()
		while entry.Alive do
			const t = math.clamp((os.clock() - t0) / WALK_IN, 0, 1)
			entry.Model:PivotTo(CFrame.lookAt(start.Position:Lerp(doorAt, t), doorAt - geo.Out * 5))
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if not entry.Alive then
			return
		end
		const body = nearestBody(geo)
		const from = entry.Model:GetPivot().Position
		const target = if body ~= nil then body.Position else doorAt - geo.Out * 4
		const flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
		const reach = if flat.Magnitude > LUNGE_STOP then flat.Unit * (flat.Magnitude - LUNGE_STOP) else Vector3.zero
		const goal = Vector3.new(from.X + reach.X, from.Y, from.Z + reach.Z)
		const facing = if flat.Magnitude > 0.01 then flat.Unit else -geo.Out
		t0 = os.clock()
		while entry.Alive do
			const t = math.clamp((os.clock() - t0) / LUNGE, 0, 1)
			const lean = CFrame.Angles(-LUNGE_LEAN * math.sin(t * math.pi), 0, 0)
			entry.Model:PivotTo(CFrame.lookAt(from:Lerp(goal, t), from:Lerp(goal, t) + facing) * lean)
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if entry.Alive then
			entry.Model:PivotTo(CFrame.lookAt(goal, goal + facing))
			-- the copy grabbed the own player: strong and short (TASK-268)
			const own = Players.LocalPlayer.Character
			if body ~= nil and own ~= nil and body:IsDescendantOf(own) then
				Haptics.Play("Grab")
			end
			vanish(entry, Fade.Duration)
		end
	end)
end

-- The copy smiles a second too long, then walks off (backwards when the clip exists).
local function mirrorSmile(ctx: Effect.Context, cue: Effect.Cue)
	const model = if cue.Entity > 0 then ctx.Npc(cue.Entity) else nil
	if model == nil or Kit.VariantOf(model) ~= VARIANT then
		return
	end
	rememberLook(model) -- the copy that will knock at the back door is this same customer (DEC-247)
	const rig = ctx.Rig
	-- whatever the customer layer writes meanwhile is kept and given back at the end
	local latest = rig.Expressions[model]
	rig:SetExpression(model, SMILE)
	Kit.WhileVariant(model, VARIANT, "mirror_backwalk", function(target: Model): Kit.Undo
		ctx.Anim:Play(target, BACKWALK, { Looped = true })
		return function()
			ctx.Anim:Stop(target, BACKWALK)
		end
	end)
	const ends = os.clock() + cue.Row.Duration + HOLD_EXTRA
	while os.clock() < ends and model.Parent ~= nil do
		const now = rig.Expressions[model]
		if now ~= SMILE then
			latest = now
			rig:SetExpression(model, SMILE)
		end
		task.wait(HOLD_STEP)
	end
	if rig.Expressions[model] == SMILE then
		rig:SetExpression(model, latest)
	end
end

return {
	Ref = "ANM-004",
	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		Vide.cleanup(Kit.Follow(ctx, occ, VARIANT, "mirror_accessories", mirrorAccessories))
	end,
	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "mirror_smile" then
			mirrorSmile(ctx, cue)
		elseif cue.Cue == "copy_knock" then
			copyKnock(ctx)
		elseif cue.Cue == "copy_grab" then
			copyGrab()
		elseif cue.Cue == "copy_vanish" then
			copyVanish(cue)
		end
	end,
} :: Effect.Module
