--!strict
--[[
	KitchenController (TASK-029 core; TASK-030 adds the grill, rail and board visuals)

	Presents the kitchen from the server's sets; decides nothing (KitchenService owns stock and stations).

	  - Stock set (network.md §3.4)    -> one Vide source per ingredient: `self:StockOf(key)`
	  - Stations set (network.md §3.5) -> one Vide source per record id (StationId * 100 + Slot): `self:SlotOf(id)`
	  - every `Station`-tagged model in the Workspace is handed to the visual parts listed in PARTS whose `Kinds`
	    contain its StationKind; each mount runs in its own Vide root and is destroyed when the station leaves.

	Listeners are attached in OnInit (before Lync.start, README "Rede"); the late joiner gets the current records
	through onAdded. Station models are scanned in OnStart (tag + added/removed signals).

	Extension (TASK-030, architecture.md §18.11): add `Grill`, `Rail`, `Board` next to `Stock` as Context.Part
	modules (`Kinds = { grill = true }`, ...) and list them in PARTS. They read `context.Slot(id)` with the id from
	the station's `StationId` attribute; nothing else in this file needs to change.

	Sound and VFX (TASK-079): the Context also carries `Audio` (AudioController hooks that stay silent for stations
	of a vehicle not in use, and for keys not yet in Content.Sounds); the parts play on the record transitions they
	already watch. Particles go through Fx.luau (shared budget: <= 150 particles, <= 8 emitters near the camera).

	Altered item (TASK-110; ANM-002, ITM-020; network.md §13.5): the record's `Altered` field is copied as a number
	(nil = 0). Grill/Board draw AST-061 (`SausageWrong` / `BunBitten`) on a slot with Altered >= 1; the Rail draws
	`SausageWrong` on the slot at position Altered. Same model boxes as the normal food (1:1 swap). The client never
	decides that an item is altered: it only draws the server's field.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Context = require(script.Context)
local Slots = require(script.Slots)
local Stock = require(script.Stock)
local Grill = require(script.Grill)
local Rail = require(script.Rail)
local Board = require(script.Board)

const STATION_TAG = "Station"
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle" -- key of Content.Vehicles on the tagged Model (architecture.md §18.1, T36)
-- Clamp of the playback speed fitted by PlayOptions.Fit: past it the clip just runs a bit long/short (no chipmunk).
const FIT_MIN = 0.8
const FIT_MAX = 1.6

-- Visual parts, in mount order (Grill, Rail, Board: TASK-030; shared slot helpers in Slots.luau).
const PARTS: { Context.Part } = { Stock, Grill, Rail, Board, require(script.Coffee) :: Context.Part } -- Coffee: TASK-069

export type StockRecord = Context.StockRecord
export type SlotRecord = Context.SlotRecord

const KitchenController =
	Modux.Controller("KitchenController", { Require = { "AudioController", "RoundController" }, Priority = 680 })

function KitchenController:Setup()
	-- All 9 ingredients exist from the start (network.md §3.4); false until the first record arrives
	-- (false, not nil: a Source of an optional type makes the 0-argument call ambiguous for the solver).
	self.Stock = {} :: { [string]: Vide.Source<StockRecord | false> }
	for _, key in Content.Ingredients.Keys do
		self.Stock[key] = Vide.source(false :: StockRecord | false)
	end
	-- Created on first read or write: record ids depend on the runtime StationId.
	self.Slots = {} :: { [number]: Vide.Source<SlotRecord | false> }
	-- Mounted station -> destroy of its Vide root
	self.Views = {} :: { [Instance]: () -> () }
end

-- Reactive read of an ingredient's stock record (nil = not received yet or unknown key).
function KitchenController:StockOf(ingredient: string): StockRecord?
	const source = self.Stock[ingredient]
	return if source then source() or nil else nil
end

function KitchenController:SlotSource(id: number): Vide.Source<SlotRecord | false>
	local source = self.Slots[id]
	if source == nil then
		source = Vide.source(false :: SlotRecord | false)
		self.Slots[id] = source
	end
	return source
end

-- Reactive read of a Stations record (grill/board slot, rail).
function KitchenController:SlotOf(id: number): SlotRecord?
	return self:SlotSource(id)() or nil
end

-- Copies: the set may reuse its record table between frames, and Vide needs a new value to notice a change.
function KitchenController:WriteStock(id: number, record: StockRecord?)
	const row = Content.Ingredients.List[id]
	const source = if row then self.Stock[row.Key] else nil
	if source == nil then
		return
	end
	if record == nil then
		source(false)
		return
	end
	source({
		Amount = record.Amount,
		Capacity = record.Capacity,
		Blocked = record.Blocked,
		Wrapped = record.Wrapped == true,
	})
end

function KitchenController:WriteSlot(id: number, record: SlotRecord?)
	const source = self:SlotSource(id)
	if record == nil then
		source(false)
		return
	end
	source({
		Kind = record.Kind,
		State = record.State,
		StartedAt = record.StartedAt,
		Duration = record.Duration,
		Count = record.Count,
		Altered = record.Altered or 0, -- wave 3 (TASK-110): optional on the wire, nil = nothing altered
		Flip = record.Flip or 0, -- prep-3d N2: flip score + 1, nil = not flipped
	})
end

-- Vehicle model a station belongs to (nil = station on the street, e.g. the street trash can)
local function vehicleOf(station: Instance): Instance?
	local node = station.Parent
	while node and node ~= workspace do
		if CollectionService:HasTag(node, VEHICLE_TAG) then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- Not reactive: reads Shift.Vehicle untracked, so a part may call it inside its effects.
function KitchenController:IsCurrent(station: Instance): boolean
	const vehicle = vehicleOf(station)
	if vehicle == nil then
		return true
	end
	const current = Vide.untrack(self.Dependencies.RoundController.Vehicle)
	return vehicle:GetAttribute(VEHICLE_ATTRIBUTE) == current
end

-- PlaybackSpeed so the clip lasts `seconds` (bun_slice ends with the cut bar). TimeLength is 0 until the clip loads;
-- the pooled Sounds are usually loaded already (AudioController preloads), otherwise it fits on Loaded.
local function fitLength(sound: Sound, seconds: number)
	local function apply()
		const length = sound.TimeLength
		if length > 0 then
			sound.PlaybackSpeed = math.clamp(length / seconds, FIT_MIN, FIT_MAX)
		end
	end
	if sound.IsLoaded then
		apply()
	else
		sound.Loaded:Once(apply)
	end
end

-- Sound hooks handed to the parts (TASK-079; Context.Audio). Keys still missing from Content.Sounds are skipped
-- without a warn (the row is added by the Content owner; then it just plays).
function KitchenController:Audio(): Context.Audio
	const audio = self.Dependencies.AudioController
	return {
		Play = function(station: Instance, key: string, at: (Instance | Vector3)?, opts: Context.PlayOptions?)
			if Content.Sounds.ByKey[key] == nil or not self:IsCurrent(station) then
				return
			end
			const sound = audio:Play(key, at, if opts then { Volume = opts.Volume, Speed = opts.Speed } else nil)
			const fit = if opts then opts.Fit else nil
			if sound and fit and fit > 0 then
				fitLength(sound, fit)
			end
		end,
		Loop = function(station: Instance, key: string, at: Instance, on: boolean, volume: number?)
			const row = Content.Sounds.ByKey[key]
			if row == nil then
				return
			end
			if not on or not self:IsCurrent(station) then
				audio:Loop(key, at, false)
				return
			end
			const sound = audio:Loop(key, at, true)
			if sound and volume then
				sound.Volume = math.clamp(row.Volume * volume, 0, 1)
			end
		end,
		Current = function(station: Instance): boolean
			return self:IsCurrent(station)
		end,
	}
end

function KitchenController:Context(): Context.Context
	return {
		Audio = self:Audio(),
		Stock = function(ingredient: string): StockRecord?
			return self:StockOf(ingredient)
		end,
		Slot = function(id: number): SlotRecord?
			return self:SlotOf(id)
		end,
	}
end

-- The live slot of a kind ("grill", "rail") on the station in use: its Spot (where the food goes), and the models on it. Used by the
-- 3D prep mode (World/Stages/Grill). Not reactive: read it each frame or on `OnSlotChanged`.
function KitchenController:SlotView(kind: string, slot: number): Slots.Live?
	return Slots.Find(kind, slot, function(station: Instance): boolean
		return self:IsCurrent(station)
	end)
end

-- fn(entry) when a slot's models were made or destroyed. Returns the disconnect.
function KitchenController:OnSlotChanged(fn: (entry: Slots.Live) -> ()): () -> ()
	return Slots.OnChanged(fn)
end

function KitchenController:Mount(station: Instance)
	if self.Views[station] or not station:IsDescendantOf(workspace) then
		return
	end
	const kind = station:GetAttribute("StationKind")
	if typeof(kind) ~= "string" then
		return
	end
	const parts: { Context.Part } = {}
	for _, part in PARTS do
		if part.Kinds[kind] then
			table.insert(parts, part)
		end
	end
	if #parts == 0 then
		return
	end
	const context = self:Context()
	const ok, destroy = pcall(Vide.root, function(destroy: () -> ())
		for _, part in parts do
			part.Mount(station, context)
		end
		return destroy
	end)
	if not ok then
		warn(`[KitchenController] {station:GetFullName()} ({kind}): {destroy}`)
		return
	end
	self.Views[station] = destroy
end

function KitchenController:Unmount(station: Instance)
	const destroy = self.Views[station]
	if destroy then
		self.Views[station] = nil
		destroy()
	end
end

function KitchenController:Watch()
	CollectionService:GetInstanceAddedSignal(STATION_TAG):Connect(function(station)
		-- the tag can arrive before the model's children; mount on the next resumption point
		task.defer(function()
			self:Mount(station)
		end)
	end)
	CollectionService:GetInstanceRemovedSignal(STATION_TAG):Connect(function(station)
		self:Unmount(station)
	end)
	for _, station in CollectionService:GetTagged(STATION_TAG) do
		self:Mount(station)
	end
end

KitchenController:OnInit(function(self)
	self:Setup()

	const net = self.Libs.Net

	net.Stock:onAdded(function(id, record)
		self:WriteStock(id, record)
	end)
	net.Stock:onChanged(function(id, record)
		self:WriteStock(id, record)
	end)
	net.Stock:onRemoved(function(id)
		self:WriteStock(id, nil)
	end)

	net.Stations:onAdded(function(id, record)
		self:WriteSlot(id, record)
	end)
	net.Stations:onChanged(function(id, record)
		self:WriteSlot(id, record)
	end)
	net.Stations:onRemoved(function(id)
		self:WriteSlot(id, nil)
	end)
end)

KitchenController:OnStart(function(self)
	self:Watch()
end)

return KitchenController
