--!strict
--[[
	DoorController (user request after Play: the Mart doors open by proximity)

	Every `AutoDoor`-tagged instance is an automatic door. Purely local: each client animates its own copy, nothing
	goes on the network and no rule depends on it.

	  * Leaf = the parts that move. Tag on a BasePart: that part. Tag on a Model: its descendant BaseParts named
	    "*Leaf*" or "Door" / attribute `DoorLeaf = true`; with none of those, every BasePart of the model. A leaf wider
	    than MAX_LEAF_WIDTH (the whole wall got the tag) is skipped with a warning, so a wall never moves.
	  * Opens when any Humanoid character (players, customers, pedestrians, client-only rigs) is within `DoorRadius`
	    (default RADIUS) of the closed leaf centre; closes CLOSE_DELAY s after the last one left RADIUS + MARGIN.
	  * Motion (simplest robust default): slide along the leaf's widest horizontal axis by its width (`DoorSlide`,
	    signed studs, overrides the distance and the side). With `DoorHinge = "Left" | "Right"` it swings instead,
	    `DoorAngle` degrees (default 90) around that vertical edge, away from the side the character came from.
	  * Open (moving or open) = CanCollide false on the leaf; the original value comes back when fully closed.
	    Local CanCollide only frees the local character (its physics run here); server-simulated NPCs that walk
	    through the door need the server copy of the leaf with CanCollide false (map binding).
	  * Leaf parts must be Anchored (an unanchored leaf is skipped with a warning).

	  * Sound (user request 2026-10-10): `door_creak` when it starts to open, `door_close` when it starts to close,
	    from the closed leaf centre (AudioController, spatial).

	Scripted doors (user request 2026-10-12, Provisional): a BasePart tagged `ScriptedDoor` is a door driven by the server
	instead of by proximity: its leaf is that part plus every BasePart under it (the glass hatch), and it is open while
	the nearest ancestor Model with the attribute `DoorOpen` has it true (TrailerDoorService sets it on the trailer for
	the Exit / Enter Trailer use). Same motion and sounds as above (`DoorHinge`, `DoorAngle`, `DoorSlide`); the swing goes
	away from the middle of that ancestor Model (the trailer interior), i.e. outward. The Door_Back of the trailer has
	DoorHinge = "Right", DoorAngle = 80 (tools/assetplace/trailer_door_switches.luau).

	Held shut (TASK-467, horror scenes, Provisional): while the door instance has the attribute `DoorHeld = true` (set
	locally by a horror scene, Anomaly/Scene/Kits, e.g. the pantry's exit door during the blackout) it stays closed: it does
	not open for anyone near and, if open, closes now.

	Manual (owner 2026-10-18, restaurant back door DOOR-B): an AutoDoor with the attribute `DoorManual = true` ignores
	proximity: it is open while its own `DoorOpen` attribute is true (Vehicle/RestaurantDoorService, prompt Open / Close),
	swinging away from the side of the player who opened it (attribute `DoorFrom`, a Vector3). DoorHeld still wins.
	No input, no packet, never writes a set.
]]
local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const TAG = "AutoDoor"
const SCRIPTED_TAG = "ScriptedDoor" -- door driven by the DoorOpen attribute of an ancestor Model
const STATE_ATTRIBUTE = "DoorOpen"
const HELD_ATTRIBUTE = "DoorHeld" -- local: a horror scene keeps the door shut (TASK-467)
const RADIUS = 5 -- studs (owner 2026-10-18: was 8, the doors opened from too far)
const MARGIN = 1 -- hysteresis: closes beyond RADIUS + MARGIN
const CLOSE_DELAY = 1 -- s with nobody near before closing
const OPEN_TIME = 0.45 -- s
const CLOSE_TIME = 0.6 -- s
const SWING_ANGLE = 90 -- degrees
const MAX_LEAF_WIDTH = 10 -- studs; wider = the wall itself got the tag
const TICK_RATE = 10
const LEAF_PATTERN = "leaf"
const OPEN_SOUND = "door_creak"
const CLOSE_SOUND = "door_close"

type Leaf = {
	Part: BasePart,
	Offset: CFrame, -- part CFrame relative to the closed pivot
	CanCollide: boolean,
}

type Door = {
	Instance: Instance,
	Leaves: { Leaf },
	Closed: CFrame, -- pivot (leaf bounding box) when closed
	Width: number, -- along the slide / swing axis
	Axis: Vector3, -- local unit axis of the width (X or Z)
	Radius: number,
	Open: boolean,
	LastNear: number,
	Value: CFrameValue, -- animated pivot
	Tween: Tween?,
	Connection: RBXScriptConnection,
	Overlap: OverlapParams,
	Scripted: boolean,
}

const DoorController = Modux.Controller("DoorController", { Require = { "AudioController" }, Priority = 300 })

function DoorController:Setup()
	self.Doors = {} :: { [Instance]: Door }
end

local function isLeafName(part: BasePart): boolean
	if part:GetAttribute("DoorLeaf") == true then
		return true
	end
	const name = string.lower(part.Name)
	return name == "door" or string.find(name, LEAF_PATTERN, 1, true) ~= nil
end

local function leafParts(instance: Instance, scripted: boolean): { BasePart }
	if instance:IsA("BasePart") then
		const parts: { BasePart } = { instance }
		if scripted then
			for _, descendant in instance:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
				end
			end
		end
		return parts
	end
	const named: { BasePart } = {}
	const all: { BasePart } = {}
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(all, descendant)
			if isLeafName(descendant) then
				table.insert(named, descendant)
			end
		end
	end
	return if #named > 0 then named else all
end

-- Bounding box of the leaf parts (world CFrame, size), oriented like the first part.
local function bounds(parts: { BasePart }): (CFrame, Vector3)
	const frame = parts[1].CFrame.Rotation
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = -min
	for _, part in parts do
		const half = part.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					const corner = frame:PointToObjectSpace(part.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z)))
					min = min:Min(corner)
					max = max:Max(corner)
				end
			end
		end
	end
	const center = frame:PointToWorldSpace((min + max) / 2)
	return CFrame.new(center) * frame, max - min
end

local function numberAttribute(instance: Instance, name: string): number?
	const value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

function DoorController:Add(instance: Instance, scripted: boolean)
	if self.Doors[instance] ~= nil or not instance:IsDescendantOf(workspace) then
		return
	end
	const parts = leafParts(instance, scripted)
	if #parts == 0 then
		return
	end
	for _, part in parts do
		if not part.Anchored then
			warn(`[DoorController] {instance:GetFullName()}: leaf part {part.Name} is not Anchored; door skipped`)
			return
		end
	end
	const closed, size = bounds(parts)
	const axis = if size.X >= size.Z then Vector3.xAxis else Vector3.zAxis
	const width = if size.X >= size.Z then size.X else size.Z
	if width > MAX_LEAF_WIDTH then
		warn(
			`[DoorController] {instance:GetFullName()}: leaf {string.format("%.1f", width)} studs wide (> {MAX_LEAF_WIDTH}); `
				.. `tag the door leaf (or name it "*Leaf*" / set DoorLeaf = true), not the wall. Door skipped`
		)
		return
	end

	const leaves: { Leaf } = {}
	for _, part in parts do
		table.insert(leaves, { Part = part, Offset = closed:ToObjectSpace(part.CFrame), CanCollide = part.CanCollide })
	end

	const value = Instance.new("CFrameValue")
	value.Value = closed
	const door: Door = {
		Instance = instance,
		Leaves = leaves,
		Closed = closed,
		Width = width,
		Axis = axis,
		Radius = numberAttribute(instance, "DoorRadius") or RADIUS,
		Open = false,
		LastNear = 0,
		Value = value,
		Tween = nil,
		Connection = value.Changed:Connect(function(pivot: CFrame)
			for _, leaf in leaves do
				leaf.Part.CFrame = pivot * leaf.Offset
			end
		end),
		Overlap = OverlapParams.new(),
		Scripted = scripted,
	}
	door.Overlap.FilterType = Enum.RaycastFilterType.Exclude
	const exclude: { Instance } = {}
	for _, part in parts do
		table.insert(exclude, part)
	end
	door.Overlap.FilterDescendantsInstances = exclude
	self.Doors[instance] = door
end

function DoorController:Remove(instance: Instance)
	const door = self.Doors[instance]
	if door == nil then
		return
	end
	self.Doors[instance] = nil
	const tween = door.Tween
	if tween then
		tween:Cancel()
	end
	door.Connection:Disconnect()
	door.Value:Destroy()
end

-- Position of the nearest Humanoid character within `radius` of the closed leaf centre (nil = nobody).
local function nearest(door: Door, radius: number): Vector3?
	const center = door.Closed.Position
	local best: Vector3? = nil
	local bestDistance = math.huge
	const seen: { [Instance]: boolean } = {}
	for _, part in workspace:GetPartBoundsInRadius(center, radius, door.Overlap) do
		const model = part.Parent
		if model == nil or seen[model] then
			continue
		end
		seen[model] = true
		const humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid == nil or humanoid.Health <= 0 or not model:IsA("Model") then
			continue
		end
		const position = model:GetPivot().Position
		const distance = (position - center).Magnitude
		if distance < bestDistance then
			best, bestDistance = position, distance
		end
	end
	return best
end

-- Open pivot: slide along the width axis, or swing around the hinge edge away from `from`.
function DoorController:OpenPivot(door: Door, from: Vector3): CFrame
	const instance = door.Instance
	const hinge = instance:GetAttribute("DoorHinge")
	if hinge == "Left" or hinge == "Right" then
		const side = if hinge == "Left" then -1 else 1
		const edge = door.Closed * CFrame.new(door.Axis * (side * door.Width / 2))
		-- free end direction from the hinge (leaf space); a +Y turn moves it along (d.Z, 0, -d.X)
		const free = door.Axis * -side
		const tangent = Vector3.new(free.Z, 0, -free.X)
		const relative = door.Closed:PointToObjectSpace(from)
		const away = if tangent:Dot(Vector3.new(relative.X, 0, relative.Z)) > 0 then -1 else 1
		const angle = math.rad(numberAttribute(instance, "DoorAngle") or SWING_ANGLE) * away
		return edge * CFrame.Angles(0, angle, 0) * edge:ToObjectSpace(door.Closed)
	end
	const slide = numberAttribute(instance, "DoorSlide") or door.Width
	return door.Closed * CFrame.new(door.Axis * slide)
end

function DoorController:SetCollide(door: Door, closed: boolean)
	for _, leaf in door.Leaves do
		leaf.Part.CanCollide = if closed then leaf.CanCollide else false
	end
end

function DoorController:Animate(door: Door, open: boolean, from: Vector3?)
	door.Open = open
	const old = door.Tween
	if old then
		old:Cancel()
	end
	if open then
		self:SetCollide(door, false)
	end
	const goal = if open and from then self:OpenPivot(door, from) else door.Closed
	const tween = TweenService:Create(
		door.Value,
		TweenInfo.new(if open then OPEN_TIME else CLOSE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = goal }
	)
	door.Tween = tween
	self.Dependencies.AudioController:Play(if open then OPEN_SOUND else CLOSE_SOUND, door.Closed.Position)
	if not open then
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not door.Open then
				self:SetCollide(door, true)
			end
		end)
	end
	tween:Play()
end

-- Scripted door: nearest ancestor Model that carries the DoorOpen attribute (nil = none yet) and its middle
local function stateOwner(instance: Instance): Model?
	local current: Instance? = instance.Parent
	while current ~= nil and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute(STATE_ATTRIBUTE) ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- A scripted door follows the DoorOpen attribute of its owner Model (absent = closed)
function DoorController:TickScripted(door: Door)
	const owner = stateOwner(door.Instance)
	const wanted = owner ~= nil and owner:GetAttribute(STATE_ATTRIBUTE) == true
	if wanted == door.Open then
		return
	end
	if wanted then
		-- swing away from the middle of the owner (the trailer interior)
		const middle = if owner ~= nil then owner:GetPivot().Position else door.Closed.Position
		self:Animate(door, true, Vector3.new(middle.X, door.Closed.Position.Y, middle.Z))
	else
		self:Animate(door, false, nil)
	end
end

function DoorController:Tick()
	const now = os.clock()
	for _, door in self.Doors do
		if door.Scripted then
			self:TickScripted(door)
			continue
		end
		if door.Instance:GetAttribute(HELD_ATTRIBUTE) == true then
			if door.Open then
				self:Animate(door, false, nil)
			end
			continue
		end
		if door.Instance:GetAttribute("DoorManual") == true then
			const wanted = door.Instance:GetAttribute("DoorOpen") == true
			if wanted ~= door.Open then
				const side = door.Instance:GetAttribute("DoorFrom")
				self:Animate(door, wanted, if wanted and typeof(side) == "Vector3" then side else nil)
			end
			continue
		end
		const from = nearest(door, if door.Open then door.Radius + MARGIN else door.Radius)
		if from then
			door.LastNear = now
			if not door.Open then
				self:Animate(door, true, from)
			end
		elseif door.Open and now - door.LastNear >= CLOSE_DELAY then
			self:Animate(door, false, nil)
		end
	end
end

DoorController:OnInit(function(self)
	self:Setup()
end)

DoorController:OnStart(function(self)
	for _, tag in { TAG, SCRIPTED_TAG } do
		const scripted = tag == SCRIPTED_TAG
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			self:Add(instance, scripted)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
			self:Remove(instance)
		end)
		for _, instance in CollectionService:GetTagged(tag) do
			self:Add(instance, scripted)
		end
	end
end)

DoorController:OnTick(function(self)
	self:Tick()
end, TICK_RATE)

return DoorController
