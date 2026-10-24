--!strict
--[[
	OrderBoardController (owner request 2026-10-17: the MenuStrip becomes the kitchen order screen)

	Presents the orders on the trailer's MenuStrip (TRL/Kitchen/BackCounter/MenuStrip) as a big kitchen display
	(Interface/Components/OrderBoard). Decides nothing: it only reads the sets the server writes.

	The part: a BasePart with the attribute OrderBoard = true, else the part named MenuStrip under BackCounter / Kitchen
	/ TRL. Found at start and on workspace.DescendantAdded (streaming, the restaurant swap); dropped when it leaves the
	workspace. The SurfaceGui lives in PlayerGui with the part as Adornee (local, nothing replicates).
	Face: the attribute OrderBoardFace (a NormalId name) if set; else, of the two faces across the part's thinnest axis,
	the one whose normal looks at the middle of the TRL model (the inside of the kitchen); else Front.

	The cards (oldest on the left):
	  - one card per customer with a taken order: Customers record in State Waiting (order taken), not a pair partner
	    (Leader = nil; the leader's Order2 is the 2nd row of its card)
	  - restaurant on: an order still being told at a tablet (Tablets State Talking, its Order) is a "NEW" card with
	    every item faded and no bar, until the customer is Waiting
	  - #n = Customers.Number (FEAT-043); without it (trailer flow) ((NpcId - 1) % 99) + 1, the same on every client
	  - age = Plates.Since (restaurant), else the start of the Order clock (PatienceEndsAt - PatienceSpan), else the
	    first time this client saw the order
	  - patience bar = (PatienceEndsAt - now) / PatienceSpan while Phase = Order; "!" under Restaurant.Rules.UrgentAt
	  - state, restaurant on (Content.Restaurant.Rules.Enabled) and a plate with this ticket (Plates.Npc):
	      nothing on the plate = Queued, bun or sausage = Preparing, bun + sausage + every topping = Ready; the icons
	      not on the plate yet are faded. No plate any more (taken off by a player) = the last state seen, at least
	      Preparing. Restaurant off (trailer flow, no plate on the wire): the oldest order is Preparing, the others
	      Queued (Provisional: the kitchen works oldest first; the trailer has no per-order progress on the wire)
	Rebuilt on a set change and at TICK_RATE while there are cards (the bars drain).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local OrderBoard = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.OrderBoard)

const TICK_RATE = 4 -- Hz: patience bars
const BOARD_ATTRIBUTE = "OrderBoard"
const FACE_ATTRIBUTE = "OrderBoardFace"
const PART_NAME = "MenuStrip"
-- MenuStrip ancestry, nearest first (TRL/Kitchen/BackCounter/MenuStrip)
const PATH = { "BackCounter", "Kitchen", "TRL" }
const TRAILER_NAME = "TRL"
-- canvas: about this many px across the strip, within the PixelsPerStud bounds
const CANVAS_WIDTH = 1200
const PPS_MIN = 40
const PPS_MAX = 200
const GUI_NAME = "OrderBoard"
const NUMBER_WRAP = 99

export type Record = {
	State: string,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
	Leader: number?,
	PatienceEndsAt: number,
	PatienceSpan: number,
	Phase: string,
	Number: number?,
	Pickup: number?,
	Bread: boolean?, -- the order is a bun alone (Content.OrderRules.BreadOnly, ANM-011)
}

export type Tablet = {
	State: string,
	Npc: number,
	StartedAt: number,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
}

export type Plate = {
	Npc: number,
	Line: number,
	Bun: boolean,
	Sausage: boolean,
	Toppings: { [string]: boolean },
	Since: number,
}

type Mounted = { Part: BasePart, Destroy: () -> (), Gui: SurfaceGui, Connections: { RBXScriptConnection } }

const OrderBoardController = Modux.Controller("OrderBoardController", { Priority = 300 })

function OrderBoardController:Setup()
	self.Customers = {} :: { [number]: Record }
	self.Plates = {} :: { [number]: Plate }
	self.Tablets = {} :: { [number]: Tablet }
	-- first time this client saw each order (server time); fallback age
	self.FirstSeen = {} :: { [number]: number }
	-- last state seen on a plate per customer (the plate taken off keeps it)
	self.LastState = {} :: { [number]: OrderBoard.CardState }
	self.Cards = Vide.source({}) :: Vide.Source<{ OrderBoard.Card }>
	self.Board = nil :: Mounted?
end

-- Topping keys of a bitfield in display order (Content.Ingredients.ToppingKeys), max MaxToppings.
local function toppingsOf(order: { [string]: boolean }?): { string }
	const list: { string } = {}
	if order == nil then
		return list
	end
	for _, key in Content.Ingredients.ToppingKeys do
		if order[key] then
			table.insert(list, key)
			if #list >= Content.OrderRules.MaxToppings then
				break
			end
		end
	end
	return list
end

-- One icon row: bun, sausage, the toppings; Done from the plate (nil = no plate, drawn full). `bread` = the bun alone.
local function rowOf(order: { [string]: boolean }?, plate: Plate?, plated: boolean, bread: boolean?): { OrderBoard.Item }
	local function done(value: boolean): boolean?
		return if plated then value else nil
	end
	if bread then
		return { { Key = "bun", Done = done(plate ~= nil and plate.Bun) } }
	end
	const row: { OrderBoard.Item } = {
		{ Key = "bun", Done = done(plate ~= nil and plate.Bun) },
		{ Key = "sausage", Done = done(plate ~= nil and plate.Sausage) },
	}
	for _, key in toppingsOf(order) do
		table.insert(row, { Key = key, Done = done(plate ~= nil and plate.Toppings[key] == true) })
	end
	return row
end


const QUEUED: OrderBoard.CardState = "Queued"
const PREPARING: OrderBoard.CardState = "Preparing"
const READY: OrderBoard.CardState = "Ready"
const RANK: { [OrderBoard.CardState]: number } = { Queued = 1, Preparing = 2, Ready = 3 }
const BY_RANK: { OrderBoard.CardState } = { QUEUED, PREPARING, READY }

local function plateState(plate: Plate, order: { [string]: boolean }?, bread: boolean?): OrderBoard.CardState
	if not plate.Bun and not plate.Sausage then
		return QUEUED
	end
	if bread then
		return if plate.Sausage then PREPARING else READY -- the bun alone is the whole order
	end
	if not (plate.Bun and plate.Sausage) then
		return PREPARING
	end
	for _, key in toppingsOf(order) do
		if plate.Toppings[key] ~= true then
			return PREPARING
		end
	end
	return READY
end

-- The cards from the current records, oldest first.
function OrderBoardController:Build(): { OrderBoard.Card }
	const now = workspace:GetServerTimeNow()
	const urgentAt = Content.Restaurant.Rules.UrgentAt

	-- plates by ticket and line
	const plates: { [number]: { [number]: Plate } } = {}
	for _, plate in self.Plates do
		if plate.Npc ~= 0 then
			const lines = plates[plate.Npc] or {}
			lines[if plate.Line == 2 then 2 else 1] = plate
			plates[plate.Npc] = lines
		end
	end

	type Entry = { Card: OrderBoard.Card, Since: number }
	const entries: { Entry } = {}
	for id, record in self.Customers do
		if record.State ~= "Waiting" or record.Leader ~= nil then
			self.FirstSeen[id] = nil
			continue
		end
		if self.FirstSeen[id] == nil then
			self.FirstSeen[id] = now
		end
		const lines = plates[id]
		const pair = record.Order2 ~= nil
		const plated = lines ~= nil
		const first = if lines then lines[1] else nil
		const second = if lines then lines[2] else nil
		const rows = { rowOf(record.Order, first, plated, record.Bread) }
		if pair then
			table.insert(rows, rowOf(record.Order2, second, plated))
		end

		-- age: plate stamp, else start of the Order clock, else first seen here
		local since = self.FirstSeen[id]
		local plateSince = math.huge
		if first and first.Since > 0 then
			plateSince = first.Since
		end
		if second and second.Since > 0 then
			plateSince = math.min(plateSince, second.Since)
		end
		if plateSince < math.huge then
			since = plateSince
		elseif record.Phase == "Order" and record.PatienceEndsAt > 0 and record.PatienceSpan > 0 then
			since = record.PatienceEndsAt - record.PatienceSpan
		end

		local state = QUEUED
		if lines then
			-- a pair is as far as its slowest hot dog
			local rank = RANK.Ready
			if first then
				rank = RANK[plateState(first, record.Order, record.Bread)]
			end
			if pair and second then
				rank = math.min(rank, RANK[plateState(second, record.Order2)])
			end
			state = BY_RANK[rank]
			self.LastState[id] = state
		else
			-- the plate left the pass: in a player's hands
			const last = self.LastState[id]
			state = if last == nil then QUEUED elseif last == READY then READY else PREPARING
		end

		local patience = -1
		if record.Phase == "Order" and record.PatienceEndsAt > 0 and record.PatienceSpan > 0 then
			patience = math.clamp((record.PatienceEndsAt - now) / record.PatienceSpan, 0, 1)
		end

		table.insert(entries, {
			Since = since,
			Card = {
				Id = id,
				Number = record.Number or ((id - 1) % NUMBER_WRAP) + 1,
				Rows = rows,
				State = state,
				Patience = patience,
				Urgent = patience >= 0 and patience <= urgentAt,
			},
		})
	end

	-- restaurant: an order still being told at a tablet (FEAT-043) is the newest card, "NEW", no bar yet
	for _, tablet in self.Tablets do
		const record = self.Customers[tablet.Npc]
		if tablet.State ~= "Talking" or tablet.Npc == 0 or (record ~= nil and record.State == "Waiting") then
			continue
		end
		const rows = { rowOf(tablet.Order, nil, true, record ~= nil and record.Bread) }
		if tablet.Order2 ~= nil then
			table.insert(rows, rowOf(tablet.Order2, nil, true))
		end
		table.insert(entries, {
			Since = if tablet.StartedAt > 0 then tablet.StartedAt else now,
			Card = { Id = tablet.Npc, Number = 0, Rows = rows, State = QUEUED, Patience = -1 },
		})
	end

	table.sort(entries, function(a: Entry, b: Entry): boolean
		if a.Since ~= b.Since then
			return a.Since < b.Since
		end
		return a.Card.Id < b.Card.Id
	end)

	const cards: { OrderBoard.Card } = {}
	for index, entry in entries do
		-- trailer flow: the oldest order is the one being made
		table.insert(cards, entry.Card)
	end
	return cards
end

function OrderBoardController:Refresh()
	self.Cards(self:Build())
end

function OrderBoardController:WriteCustomer(id: number, record: Record?)
	if record == nil then
		self.Customers[id] = nil
		self.FirstSeen[id] = nil
		self.LastState[id] = nil
	else
		self.Customers[id] = record
	end
	self:Refresh()
end

function OrderBoardController:WritePlate(id: number, plate: Plate?)
	self.Plates[id] = plate
	self:Refresh()
end

function OrderBoardController:WriteTablet(id: number, tablet: Tablet?)
	self.Tablets[id] = tablet
	self:Refresh()
end

-- Is this the order board part (attribute, else the MenuStrip path)?
local function isBoard(instance: Instance): boolean
	if not instance:IsA("BasePart") then
		return false
	end
	if instance:GetAttribute(BOARD_ATTRIBUTE) == true then
		return true
	end
	if instance.Name ~= PART_NAME then
		return false
	end
	local node: Instance? = instance.Parent
	for _, name in PATH do
		if node == nil or node.Name ~= name then
			return false
		end
		node = node.Parent
	end
	return true
end

-- The face that shows the board (attribute, else the broad face looking into the trailer, else Front).
local function faceOf(part: BasePart): Enum.NormalId
	const named = part:GetAttribute(FACE_ATTRIBUTE)
	if typeof(named) == "string" then
		for _, face in Enum.NormalId:GetEnumItems() do
			if face.Name == named then
				return face
			end
		end
	end
	const trailer = part:FindFirstAncestor(TRAILER_NAME)
	if trailer == nil then
		return Enum.NormalId.Front
	end
	local inside: Vector3
	if trailer:IsA("Model") then
		inside = trailer:GetBoundingBox().Position
	elseif trailer:IsA("BasePart") then
		inside = trailer.Position
	else
		return Enum.NormalId.Front
	end
	const size = part.Size
	local pair = { Enum.NormalId.Front, Enum.NormalId.Back }
	if size.X <= size.Y and size.X <= size.Z then
		pair = { Enum.NormalId.Right, Enum.NormalId.Left }
	elseif size.Y <= size.X and size.Y <= size.Z then
		pair = { Enum.NormalId.Top, Enum.NormalId.Bottom }
	end
	const toward = inside - part.Position
	local best = pair[1]
	local bestDot = -math.huge
	for _, face in pair do
		const dot = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)):Dot(toward)
		if dot > bestDot then
			best = face
			bestDot = dot
		end
	end
	return best
end

-- Studs of the face (width, height) as the SurfaceGui lays it out.
local function faceSize(part: BasePart, face: Enum.NormalId): Vector2
	const size = part.Size
	if face == Enum.NormalId.Left or face == Enum.NormalId.Right then
		return Vector2.new(size.Z, size.Y)
	elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
		return Vector2.new(size.X, size.Z)
	end
	return Vector2.new(size.X, size.Y)
end

function OrderBoardController:Unmount()
	const board = self.Board
	if board == nil then
		return
	end
	self.Board = nil
	for _, connection in board.Connections do
		connection:Disconnect()
	end
	board.Destroy()
	board.Gui:Destroy()
end

function OrderBoardController:Mount(part: BasePart)
	const current = self.Board
	if current ~= nil and current.Part == part then
		return
	end
	self:Unmount()
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	const face = faceOf(part)
	const studs = faceSize(part, face)
	const pps = math.clamp(CANVAS_WIDTH / math.max(studs.X, 0.1), PPS_MIN, PPS_MAX)
	const destroy, gui = Vide.root(function(): SurfaceGui
		const canvas = Vide.source(studs * pps)
		const board = OrderBoard({
			Name = GUI_NAME,
			Adornee = part,
			Face = face,
			PixelsPerStud = pps,
			Cards = self.Cards,
			CanvasSize = canvas,
			WarnAt = Content.Moods.Rules.AnnoyedAt,
		})
		-- the strip can be resized in Studio: keep the canvas in step
		const resized = part:GetPropertyChangedSignal("Size"):Connect(function()
			canvas(faceSize(part, face) * pps)
		end)
		Vide.cleanup(resized)
		return board
	end)
	gui.Parent = playerGui
	const mounted: Mounted = { Part = part, Destroy = destroy, Gui = gui, Connections = {} }
	self.Board = mounted
	table.insert(
		mounted.Connections,
		part.AncestryChanged:Connect(function()
			if not part:IsDescendantOf(workspace) and self.Board == mounted then
				self:Unmount()
				self:Find()
			end
		end)
	)
	-- a new face from Studio (attribute) rebuilds the board on that face
	table.insert(
		mounted.Connections,
		part:GetAttributeChangedSignal(FACE_ATTRIBUTE):Connect(function()
			if self.Board == mounted then
				self:Unmount()
				self:Mount(part)
			end
		end)
	)
end

-- First board part in the workspace (attribute or path).
function OrderBoardController:Find()
	for _, instance in workspace:GetDescendants() do
		if isBoard(instance) then
			self:Mount(instance :: BasePart)
			return
		end
	end
end

OrderBoardController:OnInit(function(self)
	self:Setup()

	-- listeners before Lync.start (README "Rede"); late joiners get the records through onAdded
	const net = self.Libs.Net
	net.Customers:onAdded(function(id, record)
		self:WriteCustomer(id, record :: any)
	end)
	net.Customers:onChanged(function(id, record)
		self:WriteCustomer(id, record :: any)
	end)
	net.Customers:onRemoved(function(id)
		self:WriteCustomer(id, nil)
	end)

	const restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant) :: any
	restaurant.Plates:onAdded(function(id: number, plate: Plate)
		self:WritePlate(id, plate)
	end)
	restaurant.Plates:onChanged(function(id: number, plate: Plate)
		self:WritePlate(id, plate)
	end)
	restaurant.Plates:onRemoved(function(id: number)
		self:WritePlate(id, nil)
	end)
	restaurant.Tablets:onAdded(function(id: number, tablet: Tablet)
		self:WriteTablet(id, tablet)
	end)
	restaurant.Tablets:onChanged(function(id: number, tablet: Tablet)
		self:WriteTablet(id, tablet)
	end)
	restaurant.Tablets:onRemoved(function(id: number)
		self:WriteTablet(id, nil)
	end)
end)

OrderBoardController:OnStart(function(self)
	workspace.DescendantAdded:Connect(function(instance)
		if self.Board == nil and isBoard(instance) then
			self:Mount(instance :: BasePart)
		end
	end)
	-- PlayerGui and the map may arrive a little late; do not hold up the other OnStart
	task.spawn(function()
		Players.LocalPlayer:WaitForChild("PlayerGui")
		if self.Board == nil then
			self:Find()
		end
	end)
end)

OrderBoardController:OnTick(function(self)
	if #Vide.untrack(self.Cards) > 0 then
		self:Refresh()
	end
end, TICK_RATE)

return OrderBoardController
