--!strict
--[[
	ItemController (TASK-067; FEAT-036; AST-096; architecture.md §19.12 "Client"; style guide §1.1, §2.1, §10)

	Presentation only for items that leave a hand without being used (hit by a car, spectator stash). The server
	(ItemService/Drops.luau, TASK-066) decides everything: what drops, where, who may take it, when it vanishes.
	Nothing here touches the hotbar, the count or the prompt.

	  * Keep drop (package, Rescue Whistle): a ring drawn flat on the ground under the model, pulsing slowly, lit
	    independently of the scene light so it can be found in the dark. Replaces the "light outline" of FEAT-036:
	    no permanent Highlight (style guide §1.1). Gone with the model.
	  * Lost drop (Hot Dog, Coffee): a local "splat" (Mustard comic star with light Ketchup drops) or a coffee
	    spill, Items[k].DropDespawn seconds (2 s), plus a mini dust puff (style guide §10, Emit(3)). Local only:
	    each client draws its own, nothing is replicated back.

	How a drop is recognized (PROVISIONAL, TASK-067; the contract only says "display model" / "model Splat",
	§19.12 — ItemService should follow this, note on the board):
	  * the model carries the CollectionService tag `ItemDrop` and the attribute `Item` (Content.Items key);
	  * attribute `Drop` = "Keep" | "Lost"; without it, a model named "Splat" is Lost and anything else is Keep.
	Attributes written after the model arrives (or streamed in later) are picked up through AttributeChanged.

	The ring is drawn with a SurfaceGui (UICorner + UIStroke) until `T_DropRing` (AST-096, TASK-126) is uploaded;
	set RING_IMAGE to its asset id and the same part shows the texture instead.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

type Kind = "Keep" | "Lost"

type Drop = {
	Model: Model,
	Kind: Kind?, -- nil while the Item attribute is not there yet
	Ring: BasePart?,
	Tween: Tween?,
	Links: { RBXScriptConnection },
}

const TAG = "ItemDrop"
const SPLAT_NAME = "Splat"
const COFFEE = "coffee"
const FOLDER_NAME = "ItemDropVfx"

-- AST-096 placeholder art (style guide §2.1). Nothing dark red (§10).
const RING_IMAGE = "" -- T_DropRing asset id once uploaded (TASK-126); "" = drawn ring
const COFFEE_COLOR = Color3.fromHex("#5A3A2A")
const KETCHUP_LIGHT = Color3.fromHex("#E2402E")
const CHEESE = Color3.fromHex("#FFD45A")
const DUST_COLOR = Color3.fromHex("#EAD6B0") -- Cream base, light dust

-- Ring geometry (studs) and pulse.
const RING_SCALE = 1.6 -- ring diameter = widest footprint side x this
const RING_MIN = 1.6
const RING_MAX = 4
const RING_STROKE = 0.12 -- stroke thickness as a fraction of the ring size (UIStroke is in pixels, see below)
const RING_PIXELS = 200 -- SurfaceGui pixels per stud
const RING_LIFT = 0.04 -- above the ground, avoids z-fighting
const RING_PULSE_TIME = 1.2 -- seconds per half cycle ("pulsa devagar", AST-096)
const RING_PULSE_MIN = 0.85 -- size factor at the low end of the pulse
const RING_BRIGHTNESS = 1.5 -- SurfaceGui brightness, readable at night without lighting

-- Ground probe under a drop.
const PROBE_UP = 1
const PROBE_DOWN = 12
const TICK_RATE = 10 -- Hz; ring follows a bouncing model (AST-096: one physical bounce)

-- Splat / spill.
const SPLAT_SIZE = 2.4 -- studs
const SPILL_SIZE = 2
const SPLAT_POP = 0.15 -- seconds to scale in
const FADE_SHARE = 0.4 -- last share of the lifetime spent fading out
const DROP_DOTS = 5 -- ketchup drops around the star
const DUST_COUNT = 3 -- style guide §10 "Item derrubado: mini poeira", Emit(3)
const FALLBACK_LOST_TIME = 2 -- seconds, only if Items has no numeric DropDespawn for the key

local function itemOf(model: Model): string?
	const value = model:GetAttribute("Item")
	return if typeof(value) == "string" and value ~= "" then value else nil
end

local function kindOf(model: Model): Kind?
	const value = model:GetAttribute("Drop")
	if value == "Keep" or value == "Lost" then
		return value
	end
	if model.Name == SPLAT_NAME then
		return "Lost"
	end
	-- Keep needs the item to be known (the attribute may land a frame after the model).
	return if itemOf(model) ~= nil then "Keep" else nil
end

local function lostTime(item: string?): number
	const row = if item then Content.Items.ByKey[item] else nil
	if row ~= nil and typeof(row.DropDespawn) == "number" and row.DropDespawn > 0 then
		return row.DropDespawn
	end
	return FALLBACK_LOST_TIME
end

-- Invisible, non-interactive flat part that only carries a SurfaceGui.
local function flatPart(name: string, size: number): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(size, 0.05, size)
	return part
end

local function surface(part: BasePart): SurfaceGui
	const gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = RING_PIXELS
	gui.LightInfluence = 0
	gui.Brightness = RING_BRIGHTNESS
	gui.ClipsDescendants = false
	gui.Adornee = part
	gui.Parent = part
	return gui
end

local function circle(parent: Instance, color: Color3, size: UDim2, position: UDim2, transparency: number): Frame
	const frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

const ItemController = Modux.Controller("ItemController", { Priority = 500 })

function ItemController:Setup()
	self.Drops = {} :: { [Model]: Drop }
	-- Keep drops currently in the world (read by anyone who wants to show them; nothing reads it in wave 2).
	self.Count = Vide.source(0) :: Vide.Source<number>
	self.Folder = nil :: Folder?
	self.Probe = RaycastParams.new() :: RaycastParams
	self.Probe.FilterType = Enum.RaycastFilterType.Exclude
	self.Random = Random.new() :: Random
end

function ItemController:VfxFolder(): Folder
	const existing = self.Folder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	const folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	self.Folder = folder
	return folder
end

-- Ground point under a position, ignoring the drop itself, the VFX and every character.
function ItemController:Ground(origin: Vector3, ignore: { Instance }): Vector3?
	const filter = table.clone(ignore)
	table.insert(filter, self:VfxFolder())
	for _, player in Players:GetPlayers() do
		const character = player.Character
		if character ~= nil then
			table.insert(filter, character)
		end
	end
	self.Probe.FilterDescendantsInstances = filter
	const result = Workspace:Raycast(origin + Vector3.yAxis * PROBE_UP, Vector3.yAxis * -(PROBE_UP + PROBE_DOWN), self.Probe)
	return if result then result.Position else nil
end

-- Footprint of the model: center at the bottom of the bounding box, widest horizontal side.
local function footprint(model: Model): (Vector3, number)
	const cframe, size = model:GetBoundingBox()
	const bottom = cframe.Position - Vector3.yAxis * (size.Y / 2)
	return bottom, math.max(size.X, size.Z)
end

-- Keep ---------------------------------------------------------------------------------------------------------------

function ItemController:BuildRing(drop: Drop)
	const bottom, width = footprint(drop.Model)
	const size = math.clamp(width * RING_SCALE, RING_MIN, RING_MAX)
	const part = flatPart("DropRing", size)
	const gui = surface(part)
	const holder = Instance.new("Frame")
	holder.Name = "Pulse"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	if RING_IMAGE ~= "" then
		const image = Instance.new("ImageLabel")
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = RING_IMAGE
		image.Parent = holder
	else
		-- Cream ring with a Mustard edge (AST-096): an empty circle whose stroke is the ring.
		const pixels = size * RING_PIXELS
		const outer = circle(holder, Theme.Color.Mustard, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), 1)
		const edge = Instance.new("UIStroke")
		edge.Color = Theme.Color.Mustard
		edge.Thickness = math.max(2, pixels * RING_STROKE * 0.35)
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = outer
		const inner = circle(holder, Theme.Color.Cream, UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.5, 0.5), 1)
		const body = Instance.new("UIStroke")
		body.Color = Theme.Color.Cream
		body.Thickness = math.max(2, pixels * RING_STROKE * 0.6)
		body.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		body.Parent = inner
	end
	const ground = self:Ground(bottom, { drop.Model }) or bottom
	part.CFrame = CFrame.new(ground + Vector3.yAxis * RING_LIFT)
	part.Parent = self:VfxFolder()
	drop.Ring = part
	const tween = TweenService:Create(
		holder,
		TweenInfo.new(RING_PULSE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = UDim2.fromScale(RING_PULSE_MIN, RING_PULSE_MIN) }
	)
	tween:Play()
	drop.Tween = tween
end

-- Keeps the ring under a model that is still bouncing or was moved to the sidewalk.
function ItemController:FollowRings()
	for model, drop in self.Drops do
		const ring = drop.Ring
		if ring == nil or model.Parent == nil then
			continue
		end
		const bottom = footprint(model)
		const ground = self:Ground(bottom, { model }) or bottom
		const target = ground + Vector3.yAxis * RING_LIFT
		if (ring.Position - target).Magnitude > 0.02 then
			ring.CFrame = CFrame.new(target)
		end
	end
end

-- Lost ---------------------------------------------------------------------------------------------------------------

-- Mustard 8-point star (two rotated squares over a disc) with light Ketchup drops around it.
function ItemController:DrawSplat(holder: GuiObject)
	const center = UDim2.fromScale(0.5, 0.5)
	for _, rotation in { 0, 45 } do
		const square = Instance.new("Frame")
		square.AnchorPoint = Vector2.new(0.5, 0.5)
		square.Position = center
		square.Size = UDim2.fromScale(0.62, 0.62)
		square.Rotation = rotation
		square.BackgroundColor3 = Theme.Color.Mustard
		square.BorderSizePixel = 0
		square.Parent = holder
	end
	circle(holder, Theme.Color.Mustard, UDim2.fromScale(0.66, 0.66), center, 0)
	circle(holder, CHEESE, UDim2.fromScale(0.34, 0.34), center, 0)
	for index = 1, DROP_DOTS do
		const angle = (index / DROP_DOTS) * math.pi * 2 + self.Random:NextNumber(-0.3, 0.3)
		const radius = self.Random:NextNumber(0.38, 0.47)
		const dot = self.Random:NextNumber(0.07, 0.11)
		circle(
			holder,
			KETCHUP_LIGHT,
			UDim2.fromScale(dot, dot),
			UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.5 + math.sin(angle) * radius),
			0
		)
	end
end

-- Coffee puddle: one blob and two smaller lobes.
function ItemController:DrawSpill(holder: GuiObject)
	circle(holder, COFFEE_COLOR, UDim2.fromScale(0.7, 0.6), UDim2.fromScale(0.5, 0.5), 0.1)
	for _ = 1, 2 do
		const angle = self.Random:NextNumber(0, math.pi * 2)
		const lobe = self.Random:NextNumber(0.3, 0.4)
		circle(
			holder,
			COFFEE_COLOR,
			UDim2.fromScale(lobe, lobe),
			UDim2.fromScale(0.5 + math.cos(angle) * 0.28, 0.5 + math.sin(angle) * 0.24),
			0.1
		)
	end
end

function ItemController:Dust(at: Vector3)
	const part = flatPart("DropDust", 0.5)
	part.CFrame = CFrame.new(at + Vector3.yAxis * 0.2)
	const emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(DUST_COLOR)
	emitter.LightInfluence = 0.5
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.9) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.4, 0.6)
	emitter.Speed = NumberRange.new(2, 3)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = part
	part.Parent = self:VfxFolder()
	emitter:Emit(DUST_COUNT)
	task.delay(1, function()
		part:Destroy()
	end)
end

-- Local splat or spill for DropDespawn seconds. Not tied to the server model: it stays even if the model goes first.
function ItemController:PlayLost(model: Model)
	const item = itemOf(model)
	const bottom = footprint(model)
	const ground = self:Ground(bottom, { model }) or bottom
	const coffee = item == COFFEE
	const size = if coffee then SPILL_SIZE else SPLAT_SIZE
	const part = flatPart(if coffee then "CoffeeSpill" else "HotDogSplat", size)
	part.CFrame = CFrame.new(ground + Vector3.yAxis * RING_LIFT) * CFrame.Angles(0, self.Random:NextNumber(0, math.pi * 2), 0)
	const gui = surface(part)
	gui.Brightness = 1
	const holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.2, 0.2)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	const group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.Parent = holder
	if coffee then
		self:DrawSpill(group)
	else
		self:DrawSplat(group)
	end
	part.Parent = self:VfxFolder()
	self:Dust(ground)

	const lifetime = lostTime(item)
	const fade = lifetime * FADE_SHARE
	TweenService:Create(holder, TweenInfo.new(SPLAT_POP, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1, 1),
	}):Play()
	task.delay(lifetime - fade, function()
		if part.Parent == nil then
			return
		end
		TweenService:Create(group, TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			GroupTransparency = 1,
		}):Play()
	end)
	task.delay(lifetime, function()
		part:Destroy()
	end)
end

-- Registry -----------------------------------------------------------------------------------------------------------

function ItemController:Resolve(drop: Drop)
	if drop.Kind ~= nil then
		return
	end
	const kind = kindOf(drop.Model)
	if kind == nil then
		return
	end
	drop.Kind = kind
	if kind == "Lost" then
		self:PlayLost(drop.Model)
	else
		self:BuildRing(drop)
		self.Count(self.Count() + 1)
	end
end

function ItemController:Add(instance: Instance)
	if not instance:IsA("Model") or self.Drops[instance] ~= nil or not instance:IsDescendantOf(Workspace) then
		return
	end
	const model = instance
	const drop: Drop = { Model = model, Kind = nil, Ring = nil, Tween = nil, Links = {} }
	self.Drops[model] = drop
	table.insert(
		drop.Links,
		model.AttributeChanged:Connect(function(name: string)
			if name == "Item" or name == "Drop" then
				self:Resolve(drop)
			end
		end)
	)
	table.insert(
		drop.Links,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then
				self:Remove(model)
			end
		end)
	)
	self:Resolve(drop)
end

function ItemController:Remove(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	const drop = self.Drops[instance]
	if drop == nil then
		return
	end
	self.Drops[instance] = nil
	for _, link in drop.Links do
		link:Disconnect()
	end
	if drop.Tween ~= nil then
		drop.Tween:Cancel()
	end
	if drop.Ring ~= nil then
		drop.Ring:Destroy()
		self.Count(math.max(0, self.Count() - 1))
	end
end

ItemController:OnInit(function(self)
	self:Setup()
end)

ItemController:OnStart(function(self)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
		self:Add(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		self:Remove(instance)
	end)
	for _, instance in CollectionService:GetTagged(TAG) do
		self:Add(instance)
	end
end)

ItemController:OnTick(function(self)
	self:FollowRings()
end, TICK_RATE)

return ItemController
