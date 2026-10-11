--!strict
--[[
	Minis: the floating miniatures of the Gear Stand pedestals (TASK-140; FEAT-015 v2; MAP-01 §18.4).
	Plain module, client only: no Modux, no network, never decides anything. MarketController computes the Target of
	each slot (which piece, which state) from the Upgrades/Shift sets and calls Set; Step runs from its OnTick.

	Where a miniature floats (first found):
	  1. fitting `Slot_<Slot>` (Attachment or BasePart) inside the pedestal, or inside the Model that owns the bench
	     prompt anchor (AST-049 / GEAR_STAND contract, architecture.md §18.4): its world position is the centre;
	  2. pedestal = instance tagged `GearPedestal` (Content.Mart.Tags.Pedestal) with attribute `Slot` = BenchSlot:
	     top of its bounding box + Mini.Lift;
	  3. the bench prompt anchor itself, pushed Mini.Size/2 behind it (away from the player).
	Optional pedestal parts named `Ring*`: lit (Neon) while the slot sells, dark otherwise.

	What a miniature is (first found), scaled so its largest dimension = Mini.Size:
	  1. ReplicatedStorage.Assets.Equipment.Minis.Mini_<Part> (TASK-137);
	  2. ReplicatedStorage.Assets.Equipment.UpgradePieces.<vehicle>.<Part> (kit of TASK-084), any vehicle as a fallback;
	  3. a Teal box with the upgrade initial (1 warning per Part).
	Clones are local, anchored, without collision/query/touch, scripts, prompts, lights, tags and attributes.

	Motion: bob ±Mini.Bob over Mini.BobPeriod and one turn per Mini.SpinPeriod, only while the shutter is open and
	the camera is within Mini.ActiveRadius of the miniature (farther: frozen, zero per-frame cost). "Maxed" and
	"Trailer only" are still; "Trailer only" is drawn at Mini.LockedTransparency.
	Purchase (Celebrate before the new Target): the old miniature spins fast and pops (scale 1 -> PopScale -> 0 in
	PopTime); RiseDelay after the purchase the new one rises out of the pedestal in RiseTime.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)

const MINI = Content.Mart.Mini
const PURCHASE = Content.Mart.Purchase
const TAU = math.pi * 2
const CELEBRATE_WINDOW = 1 -- s: a Celebrate is used by the next Target change within this time
const RING_PREFIX = "Ring"
const RING_OFF = Enum.Material.SmoothPlastic
const RING_DARKEN = 0.55
const BOX_COLOR = Color3.fromHex("#3FA7B5")
const INK = Color3.fromHex("#4A3D57")
const CREAM = Color3.fromHex("#FFF8EC")

export type State = "Hidden" | "Sale" | "Maxed" | "Locked" | "Empty"

export type Target = {
	State: State,
	Part: string, -- Content.Upgrades level Part ("" = no miniature)
	Vehicle: string, -- vehicle whose kit piece is cloned
	Badge: string, -- initial for the placeholder box
}

type Shown = {
	Model: Model,
	Offset: Vector3, -- pivot position relative to the bounding-box centre, at scale 1
	Rotation: CFrame, -- pivot rotation at yaw 0
	BaseScale: number, -- Model scale that makes the largest side = Mini.Size
}

type Pop = {
	Shown: Shown,
	StartAt: number,
	Yaw: number,
}

type Slot = {
	Slot: string,
	Phase: number, -- bob phase offset (s)
	Pedestal: Instance?,
	Anchor: Instance?,
	Target: Target,
	Key: string, -- vehicle/Part currently shown ("" = none)
	Shown: Shown?,
	Pop: Pop?,
	RiseAt: number, -- os.clock when the rise starts (0 = no rise)
	Buried: boolean, -- the new miniature waits hidden inside the pedestal
	Center: Vector3?, -- cached locate() (Bind, Set, Relocate): Step never searches the map
	Host: Instance?,
	CelebrateAt: number,
	Yaw: number,
	Rings: { [BasePart]: { Material: Enum.Material, Color: Color3 } },
}

export type Minis = {
	Slots: { [string]: Slot },
	Warned: { [string]: boolean },
	Bind: (self: Minis, slot: string, pedestal: Instance?, anchor: Instance?) -> (),
	Set: (self: Minis, slot: string, target: Target) -> (),
	Celebrate: (self: Minis, slot: string) -> (),
	Where: (self: Minis, slot: string) -> (Vector3?, Instance?),
	Relocate: (self: Minis) -> (),
	Step: (self: Minis, now: number, dt: number, camera: Vector3, open: boolean) -> (),
	Destroy: (self: Minis) -> (),
}

const HIDDEN: Target = { State = "Hidden", Part = "", Vehicle = "", Badge = "" }

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

local function easeOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

local function child(parent: Instance?, name: string): Instance?
	return if parent then parent:FindFirstChild(name) else nil
end

-- Kit model for a level Part: Minis.Mini_<Part>, else UpgradePieces/<vehicle>/<Part>, else any vehicle folder.
local function source(part: string, vehicle: string): Instance?
	const equipment = child(child(ReplicatedStorage, "Assets"), "Equipment")
	const mini = child(child(equipment, "Minis"), "Mini_" .. part)
	if mini then
		return mini
	end
	const pieces = child(equipment, "UpgradePieces")
	const own = child(child(pieces, vehicle), part)
	if own then
		return own
	end
	if pieces then
		for _, folder in pieces:GetChildren() do
			const found = folder:FindFirstChild(part)
			if found then
				return found
			end
		end
	end
	return nil
end

-- Local, inert copy: no scripts, prompts, lights, effects, tags or attributes; parts anchored and non-colliding.
local function strip(model: Model)
	for _, item in model:GetDescendants() do
		if
			item:IsA("LuaSourceContainer")
			or item:IsA("ProximityPrompt")
			or item:IsA("Light")
			or item:IsA("ParticleEmitter")
			or item:IsA("Sound")
			or item:IsA("BillboardGui")
			or item:IsA("ClickDetector")
		then
			item:Destroy()
			continue
		end
		for _, tag in item:GetTags() do
			item:RemoveTag(tag)
		end
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.CastShadow = false
			item.Massless = true
		end
	end
	for _, tag in model:GetTags() do
		model:RemoveTag(tag)
	end
	for name in model:GetAttributes() do
		model:SetAttribute(name, nil)
	end
end

local function box(badge: string): Model
	const model = Instance.new("Model")
	const part = Instance.new("Part")
	part.Name = "Box"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = BOX_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.Size = Vector3.one
	part.Parent = model
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		const gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.CanvasSize = Vector2.new(100, 100)
		const text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = CREAM
		text.TextStrokeColor3 = INK
		text.TextStrokeTransparency = 0
		text.Text = badge
		text.Parent = gui
		gui.Parent = part
	end
	model.PrimaryPart = part
	return model
end

const Minis = {}
Minis.__index = Minis

function Minis.new(): Minis
	const slots: { [string]: Slot } = {}
	for index, row in Content.Mart.Pedestals do
		slots[row.Slot] = {
			Slot = row.Slot,
			Phase = index * 0.37,
			Pedestal = nil,
			Anchor = nil,
			Target = HIDDEN,
			Key = "",
			Shown = nil,
			Pop = nil,
			RiseAt = 0,
			Buried = false,
			Center = nil,
			Host = nil,
			CelebrateAt = -math.huge,
			Yaw = index * 0.9,
			Rings = {},
		}
	end
	const self = setmetatable({ Slots = slots, Warned = {} }, Minis)
	return (self :: any) :: Minis
end

local function warnOnce(self: Minis, key: string, message: string)
	if not self.Warned[key] then
		self.Warned[key] = true
		warn(`[MarketController] {message}`)
	end
end

-- Centre of the miniature (no bob) and the instance that hosts sounds, or nil when nothing is streamed in.
local function locate(slot: Slot): (Vector3?, Instance?)
	const pedestal = if slot.Pedestal and slot.Pedestal:IsDescendantOf(Workspace) then slot.Pedestal else nil
	const anchor = if slot.Anchor and slot.Anchor:IsDescendantOf(Workspace) then slot.Anchor else nil
	const fittingName = "Slot_" .. slot.Slot
	local fitting = if pedestal then pedestal:FindFirstChild(fittingName, true) else nil
	if fitting == nil and anchor then
		const owner = anchor:FindFirstAncestorWhichIsA("Model")
		fitting = if owner then owner:FindFirstChild(fittingName, true) else nil
	end
	const fittingAt = if fitting then positionOf(fitting) else nil
	if fittingAt then
		return fittingAt, pedestal or anchor or fitting
	end
	if pedestal then
		local center: Vector3, top: number
		if pedestal:IsA("Model") then
			const cf, size = pedestal:GetBoundingBox()
			center, top = cf.Position, cf.Position.Y + size.Y / 2
		elseif pedestal:IsA("BasePart") then
			center, top = pedestal.Position, pedestal.Position.Y + pedestal.Size.Y / 2
		else
			return nil, nil
		end
		return Vector3.new(center.X, top + MINI.Lift, center.Z), pedestal
	end
	if anchor then
		const at = positionOf(anchor)
		if at == nil then
			return nil, nil
		end
		const owner = anchor:FindFirstAncestorWhichIsA("Model")
		local back = Vector3.zero
		if owner then
			const into = (owner:GetPivot().Position - at) * Vector3.new(1, 0, 1)
			if into.Magnitude > 0.1 then
				back = into.Unit
			end
		end
		return at + back * (MINI.Size / 2), anchor
	end
	return nil, nil
end

local function readRings(slot: Slot)
	table.clear(slot.Rings)
	const pedestal = slot.Pedestal
	if pedestal == nil then
		return
	end
	for _, part in pedestal:GetDescendants() do
		if part:IsA("BasePart") and string.sub(part.Name, 1, #RING_PREFIX) == RING_PREFIX then
			slot.Rings[part] = { Material = part.Material, Color = part.Color }
		end
	end
end

local function light(slot: Slot, lit: boolean)
	for part, original in slot.Rings do
		if lit then
			part.Material = original.Material
			part.Color = original.Color
		else
			part.Material = RING_OFF
			part.Color = original.Color:Lerp(Color3.new(0, 0, 0), RING_DARKEN)
		end
	end
end

local function clear(shown: Shown?)
	if shown then
		shown.Model:Destroy()
	end
end

local function make(self: Minis, target: Target): Shown?
	if target.Part == "" then
		return nil
	end
	const template = source(target.Part, target.Vehicle)
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
		strip(model)
	elseif template and template:IsA("BasePart") then
		model = Instance.new("Model")
		const part = template:Clone()
		part.Parent = model
		model.PrimaryPart = part
		strip(model)
	else
		warnOnce(self, "mini:" .. target.Part, `no kit model for miniature "{target.Part}": placeholder box`)
		model = box(target.Badge)
	end
	model.Name = "GearMini_" .. target.Part
	const _, size = model:GetBoundingBox()
	const largest = math.max(size.X, size.Y, size.Z)
	if largest <= 0 then
		model:Destroy()
		return nil
	end
	const scale = model:GetScale() * (MINI.Size / largest)
	model:ScaleTo(scale)
	const cf = model:GetBoundingBox()
	const pivot = model:GetPivot()
	if target.State == "Locked" then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = MINI.LockedTransparency
			end
		end
	end
	-- parented by place(), once the miniature has a position (never shown at the kit origin)
	return {
		Model = model,
		Offset = pivot.Position - cf.Position,
		Rotation = pivot.Rotation,
		BaseScale = scale,
	}
end

-- Pivot of a shown miniature with its centre at `center`, turned `yaw`, at `factor` x its base size.
local function place(shown: Shown, center: Vector3, yaw: number, factor: number)
	const model = shown.Model
	if math.abs(model:GetScale() - shown.BaseScale * factor) > 1e-4 then
		model:ScaleTo(math.max(shown.BaseScale * factor, 1e-3))
	end
	const turn = CFrame.Angles(0, yaw, 0)
	model:PivotTo(CFrame.new(center) * turn * CFrame.new(shown.Offset * factor) * shown.Rotation)
	if model.Parent == nil then
		model.Parent = Workspace
	end
end

function Minis.Bind(self: Minis, slotKey: string, pedestal: Instance?, anchor: Instance?)
	const slot = self.Slots[slotKey]
	if slot == nil then
		return
	end
	if slot.Pedestal ~= pedestal then
		light(slot, true) -- give the old rings back their look
		slot.Pedestal = pedestal
		readRings(slot)
		light(slot, slot.Target.State == "Sale")
	end
	slot.Anchor = anchor
	slot.Center, slot.Host = locate(slot)
	const shown = slot.Shown
	const center = slot.Center
	if shown and center then
		place(shown, center, slot.Yaw, 1)
	end
end

-- Marks the next Target change of the slot as a purchase (pop + rise instead of a swap).
function Minis.Celebrate(self: Minis, slotKey: string)
	const slot = self.Slots[slotKey]
	if slot then
		slot.CelebrateAt = os.clock()
	end
end

function Minis.Set(self: Minis, slotKey: string, target: Target)
	const slot = self.Slots[slotKey]
	if slot == nil then
		return
	end
	const previous = slot.Target
	slot.Target = target
	light(slot, target.State == "Sale")
	const key = if target.Part == "" then "" else `{target.Vehicle}/{target.Part}/{target.State}`
	if key == slot.Key then
		return
	end
	const now = os.clock()
	const celebrate = now - slot.CelebrateAt <= CELEBRATE_WINDOW and previous.State ~= "Hidden"
	slot.CelebrateAt = -math.huge
	slot.Key = key
	if slot.Pop then
		clear(slot.Pop.Shown)
		slot.Pop = nil
	end
	const old = slot.Shown
	slot.Shown = make(self, target)
	if celebrate and old then
		slot.Pop = { Shown = old, StartAt = now, Yaw = slot.Yaw }
		slot.RiseAt = now + PURCHASE.RiseDelay
	else
		clear(old)
		slot.RiseAt = 0
	end
	const shown = slot.Shown
	slot.Buried = shown ~= nil and slot.RiseAt > 0
	if shown then
		if slot.Buried then
			-- hidden inside the pedestal until the rise starts
			for _, part in shown.Model:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 1
				end
			end
		end
		slot.Center, slot.Host = locate(slot)
		const center = slot.Center
		if center then
			place(shown, center, slot.Yaw, 1)
		end
	end
end

-- Centre of the miniature and the instance that hosts its sounds.
function Minis.Where(self: Minis, slotKey: string): (Vector3?, Instance?)
	const slot = self.Slots[slotKey]
	if slot == nil then
		return nil, nil
	end
	slot.Center, slot.Host = locate(slot)
	return slot.Center, slot.Host
end

-- Re-reads every miniature position (pedestals streaming in/out); the controller calls it every few seconds.
function Minis.Relocate(self: Minis)
	for _, slot in self.Slots do
		const before = slot.Center
		slot.Center, slot.Host = locate(slot)
		const shown = slot.Shown
		if shown and slot.Center and slot.Center ~= before and slot.Pop == nil and slot.RiseAt == 0 then
			place(shown, slot.Center :: Vector3, slot.Yaw, 1)
		end
	end
end

local function reveal(shown: Shown, locked: boolean)
	for _, part in shown.Model:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if locked then MINI.LockedTransparency else 0
		end
	end
end

function Minis.Step(self: Minis, now: number, dt: number, camera: Vector3, open: boolean)
	for _, slot in self.Slots do
		const center = slot.Center
		if center == nil then
			continue
		end
		const busy = slot.Pop ~= nil or slot.RiseAt > 0
		const near = (camera - center).Magnitude <= MINI.ActiveRadius
		if not busy and not (open and near) then
			continue -- frozen: no per-frame cost (FEAT-015 v2)
		end
		const moving = slot.Target.State == "Sale" and open
		if not busy and not moving then
			continue -- still miniature ("Maxed", "Trailer only"): placed once by Set/Bind/Relocate
		end
		if moving then
			slot.Yaw = (slot.Yaw + TAU / MINI.SpinPeriod * dt) % TAU
		end
		const bob = if moving then MINI.Bob * math.sin(TAU * (now + slot.Phase) / MINI.BobPeriod) else 0
		const at = center + Vector3.new(0, bob, 0)

		const pop = slot.Pop
		if pop then
			const t = math.clamp((now - pop.StartAt) / PURCHASE.PopTime, 0, 1)
			const factor = if t < 0.5 then 1 + (PURCHASE.PopScale - 1) * smooth(t * 2) else PURCHASE.PopScale * (1 - smooth((t - 0.5) * 2))
			place(pop.Shown, at, pop.Yaw + TAU * PURCHASE.PopTurns * easeOut(t), factor)
			if t >= 1 then
				clear(pop.Shown)
				slot.Pop = nil
			end
		end

		const shown = slot.Shown
		if shown == nil then
			slot.RiseAt = 0
			slot.Buried = false
			continue
		end
		if slot.RiseAt > 0 then
			if now < slot.RiseAt then
				place(shown, at, slot.Yaw, 1)
				continue
			end
			const t = math.clamp((now - slot.RiseAt) / PURCHASE.RiseTime, 0, 1)
			if slot.Buried then
				slot.Buried = false
				reveal(shown, slot.Target.State == "Locked")
			end
			const depth = (MINI.Lift + MINI.Size) * (1 - easeOut(t))
			place(shown, at - Vector3.new(0, depth, 0), slot.Yaw, 0.5 + 0.5 * easeOut(t))
			if t >= 1 then
				slot.RiseAt = 0
			end
			continue
		end
		place(shown, at, slot.Yaw, 1)
	end
end

function Minis.Destroy(self: Minis)
	for _, slot in self.Slots do
		light(slot, true)
		clear(slot.Shown)
		if slot.Pop then
			clear(slot.Pop.Shown)
		end
		slot.Shown = nil
		slot.Pop = nil
	end
end

return Minis
