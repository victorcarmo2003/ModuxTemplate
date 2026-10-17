--!strict
--[[
	Kiosk: the three roll-up shutters of the Gear Stand (TASK-140; FEAT-015 v2; MAP-01 §18.4; Q-176 A Provisional).
	Plain module, client only: no Modux, no network. MarketController decides open/closed from the server's business
	hours (Content.Mart.Hours, GearStandService) and calls Set; Step runs every frame from its OnTick.

	Map contract (TASK-138), tolerant:
	  * Model tagged `GearShutter` (Content.Mart.Tags.Shutter), attribute `Slot` = "L" | "C" | "R" (Mart.Doors[].Key),
	    authored CLOSED (door down). Inside it:
	      - `Slat_*` BaseParts: every slat moves up by the open fraction x door height and is hidden once it is inside
	        the roll (its bottom above the top of the door);
	      - or `Door_Panel` BaseParts (one panel with a slat Texture, TASK-137): shrunk from the bottom, top fixed;
	      - `Roll` or `Door_Drum` BasePart (optional): turns about its longest axis as the slats wind in.
	  * No GearShutter for a key once the map is ready: a test shutter of Parts is generated on this client in front of
	    the bench prompt anchors (Mart.Fallback; 1 warning per key). A real model that streams in later replaces it.
	Late joiner / stream-in: the current state is applied without animation.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)

const MART = Content.Mart
const SLAT_PREFIX = "Slat_"
const PANEL = "Door_Panel"
const ROLLS = { Roll = true, Door_Drum = true }
const HIDE_EPSILON = 0.05
const MIN_PANEL = 0.02
-- fallback look (style guide palette: warm wood, Ink roll)
const WOOD = Color3.fromHex("#B5793F")
const WOOD_DARK = Color3.fromHex("#8E5A2B")
const ROLL_COLOR = Color3.fromHex("#4A3D57")
const SLAT = 0.5 -- studs, MAP-01 §18.4 (14 slats of 0.5)
const ROLL_DIAMETER = 1.4

type Slat = {
	Part: BasePart,
	Closed: CFrame,
	Transparency: number,
	CanCollide: boolean,
	Bottom: number, -- world Y of the slat bottom when closed
}

type Panel = {
	Part: BasePart,
	Closed: CFrame,
	Size: Vector3,
	Axis: Vector3, -- local axis that points up (unit, signed)
	Height: number,
	Transparency: number,
	CanCollide: boolean,
}

type Roll = {
	Part: BasePart,
	Closed: CFrame,
	Axis: Vector3, -- local axis of rotation
	Radius: number,
}

type Door = {
	Key: string,
	Order: number, -- 0-based position in Mart.Doors (stagger)
	Model: Instance,
	Generated: boolean,
	Slats: { Slat },
	Panels: { Panel },
	Rolls: { Roll },
	Top: number,
	Height: number,
	Open: number, -- shown fraction 0 (down) .. 1 (up)
	From: number,
	To: number,
	StartAt: number,
	Duration: number,
}

export type Kiosk = {
	Doors: { [string]: Door },
	Wanted: boolean, -- open?
	Known: boolean, -- Set was called at least once
	Warned: { [string]: boolean },
	Set: (self: Kiosk, open: boolean, animate: boolean) -> (),
	Add: (self: Kiosk, model: Instance) -> (),
	Remove: (self: Kiosk, model: Instance) -> (),
	Fallback: (self: Kiosk, anchors: { [string]: Instance }) -> (),
	Step: (self: Kiosk, now: number) -> boolean,
	Center: (self: Kiosk) -> Vector3?,
	Destroy: (self: Kiosk) -> (),
}

const ORDER: { [string]: number } = {}
for index, door in MART.Doors do
	ORDER[door.Key] = index - 1
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- Local axis of `cf` closest to world up (signed), and the matching size component.
local function upAxis(cf: CFrame, size: Vector3): (Vector3, number)
	const axes = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
	const sizes = { size.X, size.Y, size.Z }
	local best, bestDot, index = Vector3.yAxis, -1, 2
	for i, axis in axes do
		const dot = cf:VectorToWorldSpace(axis):Dot(Vector3.yAxis)
		if math.abs(dot) > bestDot then
			bestDot = math.abs(dot)
			best = if dot < 0 then -axis else axis
			index = i
		end
	end
	return best, sizes[index]
end

-- Longest local axis of a roll and the radius from the other two sizes.
local function rollAxis(size: Vector3): (Vector3, number)
	if size.X >= size.Y and size.X >= size.Z then
		return Vector3.xAxis, math.min(size.Y, size.Z) / 2
	elseif size.Y >= size.Z then
		return Vector3.yAxis, math.min(size.X, size.Z) / 2
	end
	return Vector3.zAxis, math.min(size.X, size.Y) / 2
end

local function partTop(part: BasePart): number
	const _, half = upAxis(part.CFrame, part.Size)
	return part.Position.Y + half / 2
end

local function partBottom(part: BasePart): number
	const _, half = upAxis(part.CFrame, part.Size)
	return part.Position.Y - half / 2
end

local function read(key: string, model: Instance, generated: boolean): Door?
	const slats: { Slat } = {}
	const panels: { Panel } = {}
	const rolls: { Roll } = {}
	local top, bottom = -math.huge, math.huge
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if string.sub(part.Name, 1, #SLAT_PREFIX) == SLAT_PREFIX then
			table.insert(slats, {
				Part = part,
				Closed = part.CFrame,
				Transparency = part.Transparency,
				CanCollide = part.CanCollide,
				Bottom = partBottom(part),
			})
			top = math.max(top, partTop(part))
			bottom = math.min(bottom, partBottom(part))
		elseif part.Name == PANEL then
			const axis, height = upAxis(part.CFrame, part.Size)
			table.insert(panels, {
				Part = part,
				Closed = part.CFrame,
				Size = part.Size,
				Axis = axis,
				Height = height,
				Transparency = part.Transparency,
				CanCollide = part.CanCollide,
			})
			top = math.max(top, partTop(part))
			bottom = math.min(bottom, partBottom(part))
		elseif ROLLS[part.Name] then
			const axis, radius = rollAxis(part.Size)
			table.insert(rolls, { Part = part, Closed = part.CFrame, Axis = axis, Radius = math.max(radius, 0.1) })
		end
	end
	if #slats == 0 and #panels == 0 then
		return nil
	end
	return {
		Key = key,
		Order = ORDER[key] or 0,
		Model = model,
		Generated = generated,
		Slats = slats,
		Panels = panels,
		Rolls = rolls,
		Top = top,
		Height = math.max(top - bottom, 0.1),
		Open = 0,
		From = 0,
		To = 0,
		StartAt = 0,
		Duration = 0,
	}
end

-- Pose of a door at open fraction `p` (0 = authored closed pose).
local function apply(door: Door, p: number)
	door.Open = p
	const lift = p * door.Height
	for _, slat in door.Slats do
		const part = slat.Part
		const hidden = slat.Bottom + lift >= door.Top - HIDE_EPSILON
		part.CFrame = slat.Closed + Vector3.new(0, lift, 0)
		part.Transparency = if hidden then 1 else slat.Transparency
		part.CanCollide = slat.CanCollide and not hidden
	end
	for _, panel in door.Panels do
		const part = panel.Part
		const height = panel.Height * (1 - p)
		if height < MIN_PANEL then
			part.Transparency = 1
			part.CanCollide = false
			continue
		end
		const axis = panel.Axis
		const absAxis = Vector3.new(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z))
		part.Size = panel.Size - absAxis * (panel.Height - height)
		-- keep the top edge: move the centre up by half of what was removed
		part.CFrame = panel.Closed * CFrame.new(axis * ((panel.Height - height) / 2))
		part.Transparency = panel.Transparency
		part.CanCollide = panel.CanCollide
	end
	for _, roll in door.Rolls do
		roll.Part.CFrame = roll.Closed * CFrame.fromAxisAngle(roll.Axis, lift / roll.Radius)
	end
end

local function restore(door: Door)
	apply(door, 0)
end

-- Test shutter made of Parts (no GearShutter in the map): `from`..`to` along `side`, `ahead` of the anchors.
local function build(key: string, base: Vector3, side: Vector3, front: Vector3, from: number, to: number, bottom: number): Model
	const model = Instance.new("Model")
	model.Name = `GearShutter_Fallback_{key}`
	const height = MART.Fallback.DoorHeight
	const width = to - from
	const center = base + side * ((from + to) / 2)
	const look = CFrame.lookAt(Vector3.zero, front) -- -Z = front, X = side (or -side)
	const count = math.max(1, math.floor(height / SLAT + 0.5))
	for i = 1, count do
		const part = Instance.new("Part")
		part.Name = string.format("%s%02d", SLAT_PREFIX, i)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Wood
		part.Color = if i % 2 == 0 then WOOD else WOOD_DARK
		part.Size = Vector3.new(width, SLAT * 0.96, 0.15)
		const y = bottom + (i - 0.5) * SLAT
		part.CFrame = CFrame.new(center.X, y, center.Z) * look
		part.Parent = model
	end
	const roll = Instance.new("Part")
	roll.Name = "Roll"
	roll.Shape = Enum.PartType.Cylinder
	roll.Anchored = true
	roll.CanCollide = false
	roll.CanQuery = false
	roll.CanTouch = false
	roll.Material = Enum.Material.SmoothPlastic
	roll.Color = ROLL_COLOR
	roll.Size = Vector3.new(width, ROLL_DIAMETER, ROLL_DIAMETER)
	roll.CFrame = CFrame.new(center.X, bottom + count * SLAT + ROLL_DIAMETER / 2, center.Z) * look
	roll.Parent = model
	model.Parent = Workspace
	return model
end

const Kiosk = {}
Kiosk.__index = Kiosk

function Kiosk.new(): Kiosk
	const self = setmetatable({
		Doors = {},
		Wanted = true,
		Known = false,
		Warned = {},
	}, Kiosk)
	return (self :: any) :: Kiosk
end

local function warnOnce(self: Kiosk, key: string, message: string)
	if not self.Warned[key] then
		self.Warned[key] = true
		warn(`[MarketController] {message}`)
	end
end

-- A GearShutter model streamed in (or was tagged). Replaces a generated one with the same key.
function Kiosk.Add(self: Kiosk, model: Instance)
	if not model:IsDescendantOf(Workspace) then
		return
	end
	const key = model:GetAttribute(MART.Tags.Slot)
	if typeof(key) ~= "string" or ORDER[key] == nil then
		warnOnce(self, "slot:" .. model:GetFullName(), `GearShutter {model:GetFullName()}: Slot "{tostring(key)}" is not a door of Content.Mart.Doors`)
		return
	end
	const current = self.Doors[key]
	if current then
		if current.Model == model then
			return
		end
		if current.Generated then
			current.Model:Destroy()
		else
			restore(current)
		end
	end
	const door = read(key, model, false)
	if door == nil then
		self.Doors[key] = nil
		warnOnce(self, "parts:" .. key, `GearShutter {key}: no {SLAT_PREFIX}* or {PANEL} part, the door does not move`)
		return
	end
	self.Doors[key] = door
	const p = if self.Wanted then 1 else 0
	door.From, door.To, door.Duration = p, p, 0
	apply(door, p)
end

function Kiosk.Remove(self: Kiosk, model: Instance)
	for key, door in self.Doors do
		if door.Model == model then
			self.Doors[key] = nil
		end
	end
end

-- Generates the missing doors in front of the bench prompt anchors (BenchSlot -> anchor). Called once the map is
-- ready; a key that already has a model is left alone.
function Kiosk.Fallback(self: Kiosk, anchors: { [string]: Instance })
	local first: Vector3?, last: Vector3? = nil, nil
	const positions: { [string]: Vector3 } = {}
	local owner: Instance? = nil
	for _, row in MART.Pedestals do
		const anchor = anchors[row.Slot]
		if anchor == nil then
			continue
		end
		const position = if anchor:IsA("Attachment") then anchor.WorldPosition elseif anchor:IsA("BasePart") then anchor.Position else nil
		if position == nil then
			continue
		end
		positions[row.Slot] = position
		first = first or position
		last = position
		owner = owner or anchor:FindFirstAncestorWhichIsA("Model")
	end
	if first == nil or last == nil then
		return -- nothing to stand the doors on
	end
	const firstAt: Vector3 = first :: Vector3
	const lastAt: Vector3 = last :: Vector3
	const span: Vector3 = (lastAt - firstAt) * Vector3.new(1, 0, 1)
	if span.Magnitude < 0.1 then
		return
	end
	const side = span.Unit
	local front = side:Cross(Vector3.yAxis)
	if owner and owner:IsA("Model") then
		const into = (owner:GetPivot().Position - firstAt) * Vector3.new(1, 0, 1)
		if into:Dot(front) > 0 then
			front = -front -- doors stand on the player's side of the anchors
		end
	end
	const base = firstAt + front * MART.Fallback.DoorAhead
	const bottom = firstAt.Y - MART.Fallback.AnchorHeight
	const margin = MART.Fallback.Margin

	-- span of each door along `side`, from its pedestals; doors without pedestals fill the gap between neighbours
	const spans: { [string]: { number } } = {}
	for _, door in MART.Doors do
		local lo, hi = math.huge, -math.huge
		for _, slot in door.Pedestals do
			const position = positions[slot]
			if position then
				const s = (position - firstAt):Dot(side)
				lo = math.min(lo, s)
				hi = math.max(hi, s)
			end
		end
		if lo <= hi then
			spans[door.Key] = { lo - margin, hi + margin }
		end
	end
	for index, door in MART.Doors do
		if spans[door.Key] or #door.Pedestals > 0 then
			continue
		end
		const before = MART.Doors[index - 1]
		const after = MART.Doors[index + 1]
		const a = if before then spans[before.Key] else nil
		const b = if after then spans[after.Key] else nil
		if a and b and b[1] - a[2] > 0.5 then
			spans[door.Key] = { a[2], b[1] }
		end
	end

	for _, row in MART.Doors do
		if self.Doors[row.Key] then
			continue
		end
		const span = spans[row.Key]
		if span == nil then
			continue
		end
		warnOnce(self, "fallback:" .. row.Key, `no GearShutter with Slot "{row.Key}": test shutter generated on this client`)
		const model = build(row.Key, base, side, front, span[1], span[2], bottom)
		const door = read(row.Key, model, true)
		if door then
			self.Doors[row.Key] = door
			const p = if self.Wanted then 1 else 0
			door.From, door.To, door.Duration = p, p, 0
			apply(door, p)
		end
	end
end

-- open = shutters up. animate = false snaps (first record, late joiner).
function Kiosk.Set(self: Kiosk, open: boolean, animate: boolean)
	if self.Known and self.Wanted == open then
		return
	end
	self.Known = true
	self.Wanted = open
	const now = os.clock()
	const target = if open then 1 else 0
	const time = if open then MART.Door.OpenTime else MART.Door.CloseTime
	for _, door in self.Doors do
		if animate then
			door.From = door.Open
			door.To = target
			door.StartAt = now + door.Order * MART.Door.Stagger
			door.Duration = time * math.abs(target - door.Open)
		else
			door.From, door.To, door.Duration = target, target, 0
			apply(door, target)
		end
	end
end

-- Advances the animations; true while any door is moving.
function Kiosk.Step(self: Kiosk, now: number): boolean
	local moving = false
	for _, door in self.Doors do
		if door.Open == door.To then
			continue
		end
		if not door.Model:IsDescendantOf(Workspace) then
			continue
		end
		if door.Duration <= 0 then
			apply(door, door.To)
			continue
		end
		const t = math.clamp((now - door.StartAt) / door.Duration, 0, 1)
		apply(door, door.From + (door.To - door.From) * smooth(t))
		if t < 1 then
			moving = true
		else
			apply(door, door.To)
		end
	end
	return moving
end

-- Middle of the shutters in the world (the stand's door SFX plays here); nil without any shutter in Workspace.
function Kiosk.Center(self: Kiosk): Vector3?
	local sum, count = Vector3.zero, 0
	for _, door in self.Doors do
		const model = door.Model
		if not model:IsDescendantOf(Workspace) then
			continue
		end
		if model:IsA("Model") then
			sum += model:GetPivot().Position
			count += 1
		elseif model:IsA("BasePart") then
			sum += model.Position
			count += 1
		end
	end
	return if count > 0 then sum / count else nil
end

function Kiosk.Destroy(self: Kiosk)
	for _, door in self.Doors do
		if door.Generated then
			door.Model:Destroy()
		end
	end
	table.clear(self.Doors)
end

-- Every GearShutter currently tagged in the Workspace.
function Kiosk.Tagged(): { Instance }
	const out: { Instance } = {}
	for _, model in CollectionService:GetTagged(MART.Tags.Shutter) do
		if model:IsDescendantOf(Workspace) then
			table.insert(out, model)
		end
	end
	return out
end

return Kiosk
