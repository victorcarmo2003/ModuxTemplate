--!strict
-- Slot helpers shared by the Grill, Rail and Board parts (TASK-030; architecture.md §18.4, §18.9.5; network.md §3.5).
-- Plain module (no Modux, no network). Functions that connect or create instances must run inside the part's Vide
-- root (KitchenController.Mount): they register their own `Vide.cleanup`.
--
--   StationId(station)       reactive StationId attribute (written by KitchenService at runtime, may come late)
--   Reader(...)              reactive Stations record of one slot (StationId * 100 + Slot), nil if Kind differs
--   Spots(station, along)    slot anchors (`Slot` attribute) -> pose for the food, kept relative to the host part
--   Clock(active)            server time, refreshed every frame only while `active()` is true
--   Progress(read, clock)    0..1 from StartedAt/Duration (Ready = 1)
--   Food(name, spot, parent) local clone of ReplicatedStorage.Assets.Items.Food.<name>, welded to the host part
--   Bar(spot, ...)           ProgressBar (style guide §7.3: 1.0 stud above the food)
--
-- Food lies flat on the anchor with its pivot (base centre, §18.9.5) on the anchor position. Orientation comes from
-- the slot layout, not from the anchor rotation (the .fbx empties carry no reliable rotation): the model's X (its
-- long axis) runs along the line of slots (`along = true`, buns end to end on the board) or across it (`false`,
-- sausages side by side on the rollers and on the rail). Provisional until the visual check in the place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Components = StarterPlayer.StarterPlayerScripts.client.Interface.Components
local ProgressBar = require(Components.ProgressBar)
local Context = require(script.Parent.Context)

const source = Vide.source
const cleanup = Vide.cleanup

const BAR_GAP = 1.0 -- style guide §7.3: bar 1.0 stud above the food
const BAR_MAX_DISTANCE = 40
const MIN_SPAN = 0.05
-- the pivot of food is the base centre: a turn about the long axis goes through the middle of the body, half of AST-002's 0.24
const FLIP_CENTER = 0.12

export type Spot = {
	Slot: number,
	Host: BasePart, -- the food and the bar follow this part (vehicle PivotTo, T36)
	Offset: CFrame, -- food pose in Host space
}

export type Reader = () -> Context.SlotRecord?

-- What the 3D prep mode (World/Stages/Grill) reads about a slot: where the food goes (Spot), and, for a grill slot, the models
-- on it right now (Container holds Raw and Over, the grilled one laid over the raw one and faded in by the cooking time).
-- Container = nil while the slot is empty. Written by the Grill part, read through KitchenController:SlotView.
export type Live = {
	Station: Instance,
	Kind: string,
	Slot: number,
	Spot: Spot,
	Container: Model?,
	Raw: Model?,
	Over: Model?,
}

const Slots = {}

Slots.FlipCenter = FLIP_CENTER

-- Live slots by station, then by `kind:slot` (weak on the station: a destroyed station drops out). Listeners hear every change.
const live: { [Instance]: { [string]: Live } } = setmetatable({}, { __mode = "k" }) :: any
const listeners: { (entry: Live) -> () } = {}

-- StationId -----------------------------------------------------------------------------------------------------------

local function readStationId(station: Instance): number | false
	const value = station:GetAttribute("StationId")
	return if typeof(value) == "number" then value else false
end

function Slots.StationId(station: Instance): () -> number?
	const id = source(readStationId(station))
	cleanup(station:GetAttributeChangedSignal("StationId"):Connect(function()
		id(readStationId(station))
	end))
	return function(): number?
		const value = id()
		return if value then value else nil
	end
end

-- Reactive record of one slot; a record of another Kind (wrong StationId) reads as nil.
function Slots.Reader(context: Context.Context, stationId: () -> number?, slot: number, kind: string): Reader
	return function(): Context.SlotRecord?
		const id = stationId()
		if id == nil then
			return nil
		end
		const record = context.Slot(id * 100 + slot)
		return if record and record.Kind == kind then record else nil
	end
end

-- Spots ---------------------------------------------------------------------------------------------------------------

local function anchorPosition(anchor: Instance): Vector3?
	if anchor:IsA("Attachment") then
		return anchor.WorldPosition
	elseif anchor:IsA("BasePart") then
		return anchor.Position
	end
	return nil
end

local function anchorHost(anchor: Instance): BasePart?
	if anchor:IsA("BasePart") then
		return anchor
	end
	const parent = anchor.Parent
	return if parent and parent:IsA("BasePart") then parent else nil
end

local function flat(vector: Vector3): Vector3?
	const horizontal = Vector3.new(vector.X, 0, vector.Z)
	return if horizontal.Magnitude >= MIN_SPAN then horizontal.Unit else nil
end

-- Slot anchors of the station: Attachment/BasePart with an integer `Slot` >= 1. When a slot has several anchors
-- (one per upgrade `Level`, §18.4), the one without `Level` wins, else the lowest Level (Provisional: the grill
-- binding of TASK-005 has none today).
function Slots.Spots(station: Instance, along: boolean): { [number]: Spot }
	const anchors: { [number]: Instance } = {}
	for _, descendant in station:GetDescendants() do
		if not (descendant:IsA("Attachment") or descendant:IsA("BasePart")) then
			continue
		end
		const slot = descendant:GetAttribute("Slot")
		if typeof(slot) ~= "number" or slot < 1 or slot % 1 ~= 0 then
			continue
		end
		const current = anchors[slot]
		if current == nil then
			anchors[slot] = descendant
			continue
		end
		const level = descendant:GetAttribute("Level")
		const currentLevel = current:GetAttribute("Level")
		if currentLevel ~= nil and (level == nil or (typeof(level) == "number" and typeof(currentLevel) == "number" and level < currentLevel)) then
			anchors[slot] = descendant
		end
	end

	-- line of slots: first -> last; fallback = the station's own X
	local first, last = math.huge, -math.huge
	for slot in anchors do
		first = math.min(first, slot)
		last = math.max(last, slot)
	end
	local line: Vector3? = nil
	if last > first then
		const a = anchorPosition(anchors[first])
		const b = anchorPosition(anchors[last])
		if a and b then
			line = flat(b - a)
		end
	end
	if line == nil and station:IsA("PVInstance") then
		line = flat(station:GetPivot().RightVector)
	end
	const lineAxis = line or Vector3.xAxis
	const xAxis = if along then lineAxis else lineAxis:Cross(Vector3.yAxis).Unit

	const spots: { [number]: Spot } = {}
	for slot, anchor in anchors do
		const position = anchorPosition(anchor)
		const host = anchorHost(anchor)
		if position and host then
			const pose = CFrame.fromMatrix(position, xAxis, Vector3.yAxis)
			spots[slot] = {
				Slot = slot,
				Host = host,
				Offset = host.CFrame:ToObjectSpace(pose),
			}
		end
	end
	return spots
end

-- Time ----------------------------------------------------------------------------------------------------------------

function Slots.Clock(active: () -> boolean): () -> number
	const now = source(workspace:GetServerTimeNow())
	cleanup(RunService.Heartbeat:Connect(function()
		-- read outside any reactive scope: no tracking here
		if active() then
			now(workspace:GetServerTimeNow())
		end
	end))
	return now
end

function Slots.AnyWorking(readers: { [number]: Reader }): boolean
	for _, read in readers do
		const record = read()
		if record and record.State == "Working" then
			return true
		end
	end
	return false
end

function Slots.Progress(read: Reader, clock: () -> number): number
	const record = read()
	if record == nil then
		return 0
	elseif record.State == "Ready" then
		return 1
	elseif record.State ~= "Working" or record.Duration <= 0 then
		return 0
	end
	return math.clamp((clock() - record.StartedAt) / record.Duration, 0, 1)
end

-- Food ----------------------------------------------------------------------------------------------------------------

const warned: { [string]: boolean } = {}

local function kit(name: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const food = if items then items:FindFirstChild("Food") else nil
	const model = if food then food:FindFirstChild(name) else nil
	if model and model:IsA("Model") then
		return model
	end
	if not warned[name] then
		warned[name] = true
		warn(`[KitchenController] ReplicatedStorage.Assets.Items.Food.{name} missing (build_items.luau, TASK-007)`)
	end
	return nil
end

-- Altered food (TASK-110, AST-061) -> the normal model it replaces 1:1, used only while the kit lacks it (TASK-099).
const FALLBACK = table.freeze({
	SausageWrong = "SausageGrilled",
	BunBitten = "BunOpen",
}) :: { [string]: string }

-- Local clone on the spot (client only; the server never creates station food, §18.9.5). Destroyed with the scope.
-- options.Turn = radians about the long axis of the food (a flipped sausage), options.Scale = uniform scale (the overlay).
function Slots.Food(name: string, spot: Spot, parent: Instance, options: { Turn: number?, Scale: number? }?): Model?
	const fallback = FALLBACK[name]
	const template = kit(name) or (if fallback then kit(fallback) else nil)
	if template == nil or spot.Host.Parent == nil then
		return nil
	end
	const copy = template:Clone()
	copy.Name = `{name}_Slot{spot.Slot}`
	const parts: { BasePart } = {}
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			table.insert(parts, descendant)
		end
	end
	if options ~= nil and options.Scale ~= nil and options.Scale ~= 1 then
		copy:ScaleTo(options.Scale)
	end
	const turn = if options ~= nil and options.Turn ~= nil then options.Turn else 0
	copy:PivotTo(spot.Host.CFrame * spot.Offset * CFrame.new(0, FLIP_CENTER, 0) * CFrame.Angles(turn, 0, 0) * CFrame.new(0, -FLIP_CENTER, 0))
	copy.Parent = parent
	cleanup(copy)
	-- welded (not anchored) so it rides along when the vehicle is moved by the server
	for _, part in parts do
		const weld = Instance.new("WeldConstraint")
		weld.Part0 = spot.Host
		weld.Part1 = part
		weld.Parent = part
		part.Anchored = false
	end
	return copy
end

-- Weld / unweld a model to its host, so the 3D prep mode can animate it (flip, hop) and give it back ---------------------------

-- Anchored and free of its welds: the caller moves it with PivotTo.
function Slots.Detach(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

-- Welds the model, where it is now, to the host again (the vehicle can move it once more).
function Slots.Attach(model: Model, host: BasePart)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			const weld = Instance.new("WeldConstraint")
			weld.Part0 = host
			weld.Part1 = descendant
			weld.Parent = descendant
			descendant.Anchored = false
		end
	end
end

-- Live registry ----------------------------------------------------------------------------------------------------------------

-- Registers a slot of the station (inside the part's Vide root: it leaves with the station).
function Slots.Track(station: Instance, kind: string, spot: Spot): Live
	const entry: Live = { Station = station, Kind = kind, Slot = spot.Slot, Spot = spot, Container = nil, Raw = nil, Over = nil }
	const key = `{kind}:{spot.Slot}`
	local byKey = live[station]
	if byKey == nil then
		byKey = {}
		live[station] = byKey
	end
	byKey[key] = entry
	cleanup(function()
		const current = live[station]
		if current ~= nil and current[key] == entry then
			current[key] = nil
		end
		entry.Container = nil
		entry.Raw = nil
		entry.Over = nil
		for _, fn in table.clone(listeners) do
			fn(entry)
		end
	end)
	return entry
end

function Slots.Notify(entry: Live)
	for _, fn in table.clone(listeners) do
		fn(entry)
	end
end

-- Every tracked slot of a kind on the stations accepted by `current`.
function Slots.Find(kind: string, slot: number, current: (station: Instance) -> boolean): Live?
	for station, byKey in live do
		const entry = byKey[`{kind}:{slot}`]
		if entry ~= nil and station.Parent ~= nil and current(station) then
			return entry
		end
	end
	return nil
end

function Slots.OnChanged(fn: (entry: Live) -> ()): () -> ()
	table.insert(listeners, fn)
	return function()
		const index = table.find(listeners, fn)
		if index ~= nil then
			table.remove(listeners, index)
		end
	end
end

-- Bar -----------------------------------------------------------------------------------------------------------------

-- The focused prep mode draws the cooking itself (the ring, the colour of the sausage, the light arc of HintMark): the dark world bars of the
-- slots would be a second, ugly copy of it (playtest 2026-10-12). PrepController flips this while the mode is on screen.
const barsHidden = Vide.source(false)

function Slots.SetBarsHidden(hidden: boolean)
	if Vide.untrack(barsHidden) ~= hidden then
		barsHidden(hidden)
	end
end

function Slots.Bar(spot: Spot, height: number, progress: () -> number, visible: () -> boolean)
	const anchor = Instance.new("Attachment")
	anchor.Name = `Bar_Slot{spot.Slot}`
	anchor.CFrame = spot.Offset * CFrame.new(0, height + BAR_GAP, 0)
	anchor.Parent = spot.Host
	cleanup(anchor)

	const gui = ProgressBar({
		Name = `ProgressBar_Slot{spot.Slot}`,
		Adornee = anchor,
		Progress = progress,
		Visible = function(): boolean
			return visible() and not barsHidden()
		end,
		StudsOffset = Vector3.zero,
		MaxDistance = BAR_MAX_DISTANCE,
	})
	gui.Parent = spot.Host
	cleanup(gui)
end

return table.freeze(Slots)
