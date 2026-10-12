--!strict
-- Coffee machine visuals (TASK-069; FEAT-021, DEC-055, DEC-125; architecture.md §19.8, network.md §3.5; AST-022).
-- One Stations record (StationId * 100 + 0, Kind = coffee_machine), written by KitchenService/CoffeeMachine (TASK-068):
--   Empty     no bar, no cup, no steam
--   Working   ProgressBar at `Bar_Brew` from StartedAt/Duration (orange) + steam at `VFX_Steam`
--   Ready     full green bar + coffee cup at `Att_Cup` + steam, until someone takes it ("Take Coffee")
-- The bar is computed from the record and the server clock, so a late joiner (onAdded) sees the right point.
-- Presentation only: the server owns the brew, the stock and the Tool. Fittings missing from the binding
-- (Bar_Brew, Att_Cup, VFX_Steam: TRL-COFFEE warns about them) fall back to local attachments derived from the
-- station box and its Prompt_Brew (Provisional until AST-022 carries the empties).
-- Coffee stock (Fill / counter) is not drawn here: Stock.luau does not list coffee_machine (out of scope).
-- Sound (TASK-079; sound-list §5.3 SFX-033): `coffee_brew` loop at the machine while Working; Working -> Ready plays
-- `coffee_ready` (the soft bell at the end, style guide §10). The steam counts in the shared VFX budget (Fx.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Components = StarterPlayer.StarterPlayerScripts.client.Interface.Components
local ProgressBar = require(Components.ProgressBar)
local Context = require(script.Parent.Context)
local Fx = require(script.Parent.Fx)
local Slots = require(script.Parent.Slots)

const effect = Vide.effect
const derive = Vide.derive
const cleanup = Vide.cleanup
const untrack = Vide.untrack

const KIND = "coffee_machine"
const RECORD_SLOT = 0 -- single-record station (network.md §3.5)
const ITEM_KEY = "coffee" -- ReplicatedStorage.Assets.Items.Tools.coffee (AST-010, build_items.luau)

const BAR_RISE = 1.0 -- style guide §7.3: bar 1.0 stud above the item (fallback: above the machine top)
const BAR_MAX_DISTANCE = 40
const CUP_FRONT_GAP = 0.35 -- fallback cup: this far in front of the machine face that holds Prompt_Brew
const STEAM_RISE = 0.2
const MIN_SPAN = 0.05

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

-- Horizontal direction from the machine toward the operator (Prompt_Brew side); fallback = station look.
local function frontOf(station: Instance, box: Box): Vector3
	const prompt = Context.Find(station, "Prompt_Brew")
	const position = if prompt then worldPosition(prompt) else nil
	const toward = if position then flat(position - box.Center) else nil
	if toward then
		return toward
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
		return state() == "Working"
	end)
	local function progress(): number
		return Slots.Progress(read, clock)
	end

	const box = boxOf(station, host)
	const front = frontOf(station, box)
	const halfHeight = reach(box, Vector3.yAxis)
	const top = box.Center.Y + halfHeight
	const bottom = box.Center.Y - halfHeight
	const halfDepth = reach(box, front)

	-- Bar: authored Bar_Brew (bar right on it), else above the machine top
	const barAnchor = fitting(station, host, "Bar_Brew", function()
		return Vector3.new(box.Center.X, top + BAR_RISE, box.Center.Z)
	end)
	const bar = ProgressBar({
		Name = "ProgressBar_Brew",
		Adornee = barAnchor,
		Progress = progress,
		Visible = function()
			return state() ~= "Empty"
		end,
		StudsOffset = Vector3.zero,
		MaxDistance = BAR_MAX_DISTANCE,
	})
	bar.Parent = host
	cleanup(bar)

	-- Cup: authored Att_Cup, else on the counter in front of the Prompt_Brew face
	const cupSpot = fitting(station, host, "Att_Cup", function()
		const position = box.Center + front * (halfDepth + CUP_FRONT_GAP)
		return Vector3.new(position.X, bottom, position.Z)
	end)
	const cupHost = if cupSpot:IsA("Attachment") and cupSpot.Parent and cupSpot.Parent:IsA("BasePart")
		then cupSpot.Parent
		else host
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
		emitter.Enabled = current ~= "Empty"
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
		station:SetAttribute(cupState, current)
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
