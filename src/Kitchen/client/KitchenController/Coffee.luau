--!strict
-- Coffee machine visuals (TASK-069; FEAT-021, DEC-055, DEC-125; architecture.md §19.8, network.md §3.5; AST-022).
-- One Stations record (StationId * 100 + 0, Kind = coffee_machine), written by KitchenService/CoffeeMachine (TASK-068):
--   Empty     no bar, no cup, no steam (waiting for stock: the machine brews by itself, TASK-328)
--   Working   BrewTag "Brewing..." (Mustard) at `Bar_Brew` with the seconds left + steam at `VFX_Steam`
--   Ready     BrewTag "Coffee ready!" (Green) + coffee cup standing on the counter in front of the machine + steam,
--             until someone takes it
--   Cleaning  BrewTag "Next cup in" (Teal) counting down the clean time after a cup was taken (the machine cooldown,
--             owner request 2026-10-17), no cup, no steam
-- Cup spot (owner request 2026-10-17, Provisional): centred in front of the machine, halfway between its front face and
-- the counter edge (raycast, local; the owner moved the machine back to free that strip). If that strip has no room:
-- the authored `Att_Cup`, right in front, then beside the machine (TASK-328 search).
-- The bar is computed from the record and the server clock, so a late joiner (onAdded) sees the right point.
-- Presentation only: the server owns the brew, the stock and the Tool. Fittings missing from the binding
-- (Bar_Brew, Att_Cup, VFX_Steam: TRL-COFFEE warns about them) fall back to local attachments derived from the
-- station box and its Prompt_Brew (Provisional until AST-022 carries the empties).
-- Coffee stock (Fill / counter) is not drawn here: Stock.luau does not list coffee_machine (out of scope).
-- Sound (TASK-079; sound-list §5.3 SFX-033): `coffee_brew` loop at the machine while Working; Working -> Ready plays
-- `coffee_ready` (the soft bell at the end, style guide §10). The steam counts in the shared VFX budget (Fx.luau).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Components = StarterPlayer.StarterPlayerScripts.client.Interface.Components
local BrewTag = require(Components.BrewTag)
local Context = require(script.Parent.Context)
local Fx = require(script.Parent.Fx)
local Slots = require(script.Parent.Slots)

const create = Vide.create
const effect = Vide.effect
const derive = Vide.derive
const cleanup = Vide.cleanup
const untrack = Vide.untrack

const KIND = "coffee_machine"
const RECORD_SLOT = 0 -- single-record station (network.md §3.5)
const ITEM_KEY = "coffee" -- ReplicatedStorage.Assets.Items.Tools.coffee (AST-010, build_items.luau)

const BAR_RISE = 0.75 -- fallback `Bar_Brew`: the tag centre this far above the machine top
const BAR_MAX_DISTANCE = 40
const CUP_FRONT_GAP = 0.35 -- fallback cup: this far in front of the machine face that holds Prompt_Brew
const STEAM_RISE = 0.2
const MIN_SPAN = 0.05
const MODES: { [string]: BrewTag.Mode } = { Working = "Brewing", Cleaning = "Cooldown", Ready = "Ready" }
-- Cup spot search (TASK-328): footprint radius of the cup, how far the surface may sit from the machine bottom, steps
const CUP_RADIUS = 0.17 -- the coffee Tool's Handle is 0.33 x 0.35 (was 0.2: the 0.37 strip of TRL-COFFEE never fitted it)
const CUP_SURFACE_SLACK = 0.35
const CUP_SIDE_GAP = 0.3
const CUP_SCAN_STEP = 0.05 -- studs per step when looking for the counter edge in front of the machine
const CUP_SCAN_MAX = 3
const INVISIBLE = 0.95 -- a surface at least this transparent does not hold the cup (an invisible collider)

-- Placeholder steam (style guide palette: soft white, no asset id). Low rate for the reference phone.
const STEAM_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
const STEAM_RATE_WORKING = 6
const STEAM_RATE_READY = 3

-- Geometry -------------------------------------------------------------------------------------------------------------

local function worldPosition(instance: Instance): Vector3?
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

-- Part the local visuals follow (vehicle PivotTo, T36): PrimaryPart, else the biggest part.
local function hostPart(station: Instance): BasePart?
	if station:IsA("Model") and station.PrimaryPart then
		return station.PrimaryPart
	end
	local best: BasePart? = nil
	for _, descendant in station:GetDescendants() do
		if descendant:IsA("BasePart") and (best == nil or descendant.Size.Magnitude > best.Size.Magnitude) then
			best = descendant
		end
	end
	return best
end

type Box = { Frame: CFrame, Size: Vector3, Center: Vector3 }

local function boxOf(station: Instance, host: BasePart): Box
	if station:IsA("Model") then
		const frame, size = station:GetBoundingBox()
		return { Frame = frame, Size = size, Center = frame.Position }
	end
	return { Frame = host.CFrame, Size = host.Size, Center = host.Position }
end

-- Half extent of the (oriented) box along a world direction.
local function reach(box: Box, direction: Vector3): number
	const frame = box.Frame
	return math.abs(frame.RightVector:Dot(direction)) * box.Size.X / 2
		+ math.abs(frame.UpVector:Dot(direction)) * box.Size.Y / 2
		+ math.abs(frame.LookVector:Dot(direction)) * box.Size.Z / 2
end

local function flat(vector: Vector3): Vector3?
	const horizontal = Vector3.new(vector.X, 0, vector.Z)
	return if horizontal.Magnitude >= MIN_SPAN then horizontal.Unit else nil
end

-- Horizontal direction from the machine toward the operator: the box face on the Prompt_Brew side (the prompt sits off
-- centre, so its own direction would skew the cup sideways); fallback = station look.
local function frontOf(station: Instance, box: Box): Vector3
	const prompt = Context.Find(station, "Prompt_Brew")
	const position = if prompt then worldPosition(prompt) else nil
	const toward = if position then flat(position - box.Center) else nil
	if toward then
		local best: Vector3? = nil
		local score = 0
		for _, axis in { box.Frame.LookVector, box.Frame.RightVector } do
			const level = flat(axis)
			if level then
				const dot = level:Dot(toward)
				if math.abs(dot) > score then
					score = math.abs(dot)
					best = if dot >= 0 then level else -level
				end
			end
		end
		return best or toward
	end
	const look = if station:IsA("PVInstance") then flat(station:GetPivot().LookVector) else nil
	return look or -Vector3.zAxis
end

-- Authored fitting (Attachment or BasePart) or a local attachment on the host at `fallback` (removed with the view).
local function fitting(station: Instance, host: BasePart, name: string, fallback: () -> Vector3): Instance
	const authored = Context.Find(station, name)
	if authored and (authored:IsA("Attachment") or authored:IsA("BasePart")) then
		return authored
	end
	const attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = host
	attachment.WorldPosition = fallback()
	cleanup(attachment)
	return attachment
end

-- Cup spot (TASK-328) ---------------------------------------------------------------------------------------------------

-- Height of the surface under `point` if a cup fits there: every footprint ray lands within the slack of the machine
-- bottom (a counter, not the floor or the counter lip) on a part you can see. nil = no room. Owner 2026-10-23 (print: the
-- cup floated past the counter): an invisible collider (the old CoffeeBench blockout, Transparency 1) is no surface.
local function surfaceAt(point: Vector3, top: number, bottom: number, params: RaycastParams): number?
	const drop = top - bottom + 2
	local height: number? = nil
	for _, offset in { Vector3.zero, Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		const origin = Vector3.new(point.X, top + 0.5, point.Z) + offset * CUP_RADIUS
		const hit = workspace:Raycast(origin, Vector3.new(0, -drop, 0), params)
		if hit == nil or math.abs(hit.Position.Y - bottom) > CUP_SURFACE_SLACK then
			return nil
		end
		if hit.Instance.Transparency >= INVISIBLE then
			return nil
		end
		height = if height then math.max(height, hit.Position.Y) else hit.Position.Y
	end
	return height
end

-- Centre of the free counter strip in front of the machine: walks out from the front face until the cup no longer fits
-- (counter edge) and takes the middle. nil = no room in front.
local function frontStrip(box: Box, front: Vector3, top: number, bottom: number, params: RaycastParams): Vector3?
	const face = reach(box, front)
	local last: number? = nil
	local distance = face + CUP_RADIUS
	while distance <= face + CUP_SCAN_MAX do
		if surfaceAt(box.Center + front * distance, top, bottom, params) == nil then
			break
		end
		last = distance
		distance += CUP_SCAN_STEP
	end
	if last == nil then
		return nil
	end
	const edge = last + CUP_RADIUS
	return box.Center + front * ((face + edge) / 2)
end

-- Where the ready cup stands: centred in the free strip in front of the machine, else the authored Att_Cup if it is over
-- the counter, else right in front of the machine, else beside it (left, then right, toward the front); `fallback` when
-- nothing fits (old placement).
local function findCupSpot(station: Instance, box: Box, front: Vector3, top: number, bottom: number, fallback: Vector3): Vector3
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = { station }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true

	const side = front:Cross(Vector3.yAxis).Unit
	const halfDepth = reach(box, front)
	const halfWidth = reach(box, side)
	const candidates: { Vector3 } = {}
	const strip = frontStrip(box, front, top, bottom, params)
	if strip then
		table.insert(candidates, strip)
	end
	const authored = Context.Find(station, "Att_Cup")
	const authoredAt = if authored then worldPosition(authored) else nil
	if authoredAt then
		table.insert(candidates, authoredAt)
	end
	table.insert(candidates, box.Center + front * (halfDepth + CUP_RADIUS + 0.05))
	const along = halfDepth - CUP_RADIUS - 0.1
	const out = halfWidth + CUP_SIDE_GAP + CUP_RADIUS
	for _, sign in { -1, 1 } do
		table.insert(candidates, box.Center + front * along + side * (sign * out))
		table.insert(candidates, box.Center + side * (sign * out))
	end
	for _, point in candidates do
		const height = surfaceAt(point, top, bottom, params)
		if height then
			return Vector3.new(point.X, height, point.Z)
		end
	end
	return fallback
end

-- Cup ------------------------------------------------------------------------------------------------------------------

local warned = false

local function cupTemplate(): Tool?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const tools = if items then items:FindFirstChild("Tools") else nil
	const tool = if tools then tools:FindFirstChild(ITEM_KEY) else nil
	if tool and tool:IsA("Tool") then
		return tool
	end
	if not warned then
		warned = true
		warn(`[KitchenController] ReplicatedStorage.Assets.Items.Tools.{ITEM_KEY} missing (build_items.luau, TASK-007)`)
	end
	return nil
end

-- Local, non-interactive copy of the coffee Tool's parts, standing upright on `spot`, welded to the anchor's part.
-- Destroyed with the scope.
local function showCup(station: Instance, spot: Instance, host: BasePart, facing: Vector3)
	const template = cupTemplate()
	const position = worldPosition(spot)
	if template == nil or position == nil or host.Parent == nil then
		return
	end
	const copy = template:Clone()
	const handle = copy:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		copy:Destroy()
		return
	end
	const model = Instance.new("Model")
	model.Name = "CoffeeCup"
	for _, child in copy:GetChildren() do
		child.Parent = model
	end
	copy:Destroy()
	-- the Tool Handle carries a turned PivotOffset (hand pose): without this PivotTo lays the cup on its side (TASK-328)
	handle.PivotOffset = CFrame.identity
	model.PrimaryPart = handle

	const parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			table.insert(parts, descendant)
		end
	end
	-- the Handle sits at its box centre; its box starts at the cup base (AST-010)
	const base = CFrame.lookAt(position, position + facing)
	model:PivotTo(base * CFrame.new(0, handle.Size.Y / 2, 0))
	model.Parent = station
	cleanup(model)

	const anchorPart = if spot:IsA("Attachment") and spot.Parent and spot.Parent:IsA("BasePart")
		then spot.Parent
		elseif spot:IsA("BasePart") then spot
		else host
	for _, part in parts do
		const weld = Instance.new("WeldConstraint")
		weld.Part0 = anchorPart
		weld.Part1 = part
		weld.Parent = part
		part.Anchored = false
	end
end

-- Steam ----------------------------------------------------------------------------------------------------------------

-- Emitter of the fitting (authored one if VFX_Steam brings it, else a placeholder created here).
local function steamEmitter(spot: Instance): ParticleEmitter
	const authored = spot:FindFirstChildWhichIsA("ParticleEmitter")
	if authored then
		const wasEnabled = authored.Enabled
		cleanup(function()
			authored.Enabled = wasEnabled
		end)
		return authored
	end
	const emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Steam"
	emitter.Texture = STEAM_TEXTURE
	emitter.Color = ColorSequence.new(Color3.fromHex("#FFF8EC"))
	emitter.LightEmission = 0.2
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	emitter.Lifetime = NumberRange.new(1, 1.6)
	emitter.Speed = NumberRange.new(0.6, 1)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Acceleration = Vector3.new(0, 0.4, 0)
	emitter.Enabled = false
	emitter.Parent = spot
	cleanup(emitter)
	return emitter
end

-- Part -----------------------------------------------------------------------------------------------------------------

const Coffee = {}

Coffee.Kinds = table.freeze({ [KIND] = true }) :: { [string]: boolean }

function Coffee.Mount(station: Instance, context: Context.Context)
	const host = hostPart(station)
	if host == nil then
		return
	end
	const read = Slots.Reader(context, Slots.StationId(station), RECORD_SLOT, KIND)
	const state = derive(function(): string
		const record = read()
		return if record then record.State else "Empty"
	end)
	const clock = Slots.Clock(function()
		const current = state()
		return current == "Working" or current == "Cleaning"
	end)
	local function progress(): number
		const record = read()
		if record and record.State == "Cleaning" then
			-- Slots.Progress knows Working / Ready only; the clean wait fills the same way (TASK-328)
			return if record.Duration > 0 then math.clamp((clock() - record.StartedAt) / record.Duration, 0, 1) else 1
		end
		return Slots.Progress(read, clock)
	end

	const box = boxOf(station, host)
	const front = frontOf(station, box)
	const halfHeight = reach(box, Vector3.yAxis)
	const top = box.Center.Y + halfHeight
	const bottom = box.Center.Y - halfHeight
	const halfDepth = reach(box, front)

	-- Tag: authored Bar_Brew (tag centred on it), else above the machine top
	const barAnchor = fitting(station, host, "Bar_Brew", function()
		return Vector3.new(box.Center.X, top + BAR_RISE, box.Center.Z)
	end)
	const tag = BrewTag({
		Name = "BrewTag",
		Adornee = barAnchor,
		Visible = function()
			return MODES[state()] ~= nil
		end,
		Mode = function(): BrewTag.Mode
			return MODES[state()] or "Ready"
		end,
		Progress = progress,
		Seconds = function(): number
			const record = read()
			if record == nil or (record.State ~= "Working" and record.State ~= "Cleaning") then
				return 0
			end
			return math.max(0, record.StartedAt + record.Duration - clock())
		end,
		MaxDistance = BAR_MAX_DISTANCE,
	})
	tag.Parent = host
	cleanup(tag)

	-- Cup: standing on the counter by the machine (cupSpot); a local attachment on the host follows the vehicle
	const cupSpot = Instance.new("Attachment")
	cupSpot.Name = "CupSpot"
	cupSpot.Parent = host
	cupSpot.WorldPosition = findCupSpot(station, box, front, top, bottom, (function(): Vector3
		const position = box.Center + front * (halfDepth + CUP_FRONT_GAP)
		return Vector3.new(position.X, bottom, position.Z)
	end)())
	cleanup(cupSpot)
	const cupHost = host
	effect(function()
		if state() == "Ready" then
			showCup(station, cupSpot, cupHost, front)
		end
	end)

	-- Steam: authored VFX_Steam, else just above the machine top
	const steamSpot = fitting(station, host, "VFX_Steam", function()
		return Vector3.new(box.Center.X, top + STEAM_RISE, box.Center.Z)
	end)
	const emitter = steamEmitter(steamSpot)
	effect(function()
		const current = state()
		emitter.Enabled = current == "Working" or current == "Ready"
		emitter.Rate = if current == "Working" then STEAM_RATE_WORKING else STEAM_RATE_READY
		if emitter.Enabled then
			Fx.Track(emitter)
		else
			Fx.Untrack(emitter)
		end
	end)
	cleanup(function()
		Fx.Untrack(emitter)
	end)

	-- Cup on the counter (Content.CoffeeCup, CoffeeCupController): mirror the state on the station, client side only.
	-- Seconds first, then the state, so the listener reads a consistent pair.
	const cupState = Content.CoffeeCup.StationStateAttribute
	const cupSeconds = Content.CoffeeCup.StationSecondsAttribute
	effect(function()
		const record = read()
		const current = state()
		local left = 0
		if current == "Working" and record then
			left = math.max(0, record.StartedAt + record.Duration - workspace:GetServerTimeNow())
		end
		station:SetAttribute(cupSeconds, left)
		-- the counter mug knows Empty / Working / Ready: a cleaning machine has no coffee in it
		station:SetAttribute(cupState, if current == "Cleaning" then "Empty" else current)
	end)
	cleanup(function()
		station:SetAttribute(cupState, nil)
		station:SetAttribute(cupSeconds, nil)
	end)

	-- Sound: brew loop while Working; bell on Working -> Ready (first record of a late joiner is silent)
	const audio = context.Audio
	local last: string? = nil
	effect(function()
		const current = state()
		const previous = last
		last = current
		untrack(function()
			audio.Loop(station, "coffee_brew", host, current == "Working")
			if previous == "Working" and current == "Ready" then
				audio.Play(station, "coffee_ready", cupSpot)
			end
			return nil
		end)
	end)
	cleanup(function()
		audio.Loop(station, "coffee_brew", host, false)
	end)
end

return table.freeze(Coffee) :: Context.Part
