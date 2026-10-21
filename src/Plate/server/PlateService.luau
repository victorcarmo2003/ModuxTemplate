--!strict
-- The plate in hand of the world kitchen (docs/tech/kitchen-world.md §1-§3; DEC-306, DEC-308; TASK-569, TASK-581). Run place
-- only. Owner of the ticket of every plate and single writer of the Net.Restaurant Plates set; the central table, the conveyor
-- and the old PLATE-n pass are gone (TASK-581).
--
-- A plate is a Tool in a hand (shared/Plate/PlateTool): `plate` while it is empty or half made, `hot_dog` once it has bun and
-- sausage (KitchenService.FillPlate swaps the Tool and carries PlateId, Ticket, TicketLine, Since, Flipped). This service keeps
-- one entry per PlateId (1..255) and follows the Tools through ItemService.Changed: the entry goes when no Tool of its player
-- carries the id any more (served, bin, ClearAltered, drop, death, player left).
--
-- Take Plate (plate_take, tap on Prompt_Plate of the plate pile): one plate per hand (Provisional; a plate or a plate's hot dog
-- in the hotbar = hands_full), room in the HotDog category (ItemService.CanGive). The plate is tied to the OLDEST ticket line
-- without a plate (Ticket = NpcId, TicketLine = 1 / 2 of a pair, Since = when the order was taken); none free = a plate with no
-- ticket, which takes the oldest ticket that lands while it is held (OnTicket) or the oldest one at the hand-over (Pickup).
-- A customer that leaves frees its plates: Ticket 0 (the plate is judged against whoever takes it at the hand-over).
--
-- Plate slots (owner 2026-10-19, DEC-311): the plates of the front counter (the parts with PlateIndex 1..8, Kitchen/Plates/MarkN/
-- PLATE-n) each stand for ONE ticket line. A free ticket line (order taken, no plate in a hand) gets the lowest empty slot; the slot
-- part carries the attributes Ticket (NpcId) and TicketLine for the clients (the plate shows, with the order card over it) and its
-- Prompt_Plate is on. An empty slot has no Ticket: the client hides the plate and the prompt is off. Take Plate on a slot ties
-- the plate to THAT slot's ticket line (the player picks which order to make).
--
-- PICKUP (kitchen-world.md §1 #10): the gate "PlateTicket" on pickup_serve (and serve on a PU-n rig) refuses a `plate` not
-- made yet (plate_not_ready) and a hot dog whose ticket customer is not Waiting in the pickup line (ticket_other, Value = #n).
-- The sale and the grade are CustomerService's (Grade.Assembly at SellLine).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Lync = require(ReplicatedStorage.Packages.Lync)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local PlateTool = require(ReplicatedStorage.shared.Plate.PlateTool)
local Modux = require(ServerScriptService.server.Modux)

-- One plate slot of the front counter
export type Slot = { Index: number, Part: BasePart, Anchor: Attachment, Npc: number, Line: number }

-- One live plate (a Tool in a hand)
export type Entry = {
	Id: number,
	Player: Player,
	Tool: Tool,
	Ticket: number, -- NpcId, 0 = none
	Line: number, -- 1 leader, 2 pair partner, 0 = none
	Since: number, -- server time the order was taken, 0 = none
}

-- What the Plates set carries (sent untyped: Lync's own struct)
type Wire = {
	Npc: number,
	Bun: boolean,
	Sausage: boolean,
	Toppings: { [string]: boolean },
	Since: number,
	Altered: boolean?,
}

const TAKE = "plate_take"
const PICKUP_SERVE = "pickup_serve"
const SERVE = "serve"
const TAKE_ORDER = "take_order"
const SLOT_INDEX = "PlateIndex" -- attribute of a slot part (1..8) and of its Prompt_Plate
const SLOT_TICKET = "Ticket" -- slot part: NpcId of the ticket line it shows (nil = empty)
const SLOT_LINE = "TicketLine" -- slot part: 1 / 2 of a pair
const SLOT_ANCHOR = "Prompt_Plate"
const SLOT_RATE = 2 -- Hz: slots re-read the tickets
const TICKET_GATE = "PlateTicket"
const WAITING = "Waiting"
const LEAVING = "Leaving"
const PLATE = PlateTool.Plate
const HOT_DOG = PlateTool.HotDog
const ATTR = PlateTool.Attr
-- Notices (Content.Notices)
const HANDS_FULL = "hands_full"
const PLATE_NOT_READY = "plate_not_ready"
const TICKET_OTHER = "ticket_other"
-- Same notice to the same player at most once per this many seconds (FEAT-005 anti-spam), as CustomerService NOTICE_GAP
const NOTICE_GAP = 2
-- Plates record ids (Net.Restaurant Plates): one per live plate
const MAX_ID = 255

local function now(): number
	return workspace:GetServerTimeNow()
end

local function sameWire(a: Wire, b: Wire): boolean
	if a.Npc ~= b.Npc or a.Bun ~= b.Bun or a.Sausage ~= b.Sausage or a.Since ~= b.Since or a.Altered ~= b.Altered then
		return false
	end
	for key, on in a.Toppings do
		if b.Toppings[key] ~= on then
			return false
		end
	end
	for key, on in b.Toppings do
		if a.Toppings[key] ~= on then
			return false
		end
	end
	return true
end

const PlateService = Modux.Service("PlateService", {
	Require = {
		"PlaceService",
		"NetService",
		"RunStateService",
		"RoundService",
		"InteractionService",
		"ItemService",
		"CustomerService",
	},
	Priority = 566,
})

function PlateService:Setup()
	self.Enabled = false :: boolean
	-- Live plates by PlateId
	self.Plates = {} :: { [number]: Entry }
	-- Last record sent per PlateId (nil = not on the wire)
	self.Sent = {} :: { [number]: Wire }
	-- Last time each notice went to each player (FEAT-005 anti-spam)
	self.NoticeAt = {} :: { [Player]: { [string]: number } }
	-- A plate changed (id): born, filled, ticket, gone (dev, QA, Metrics)
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<number>
	-- Plate slots of the front counter by PlateIndex (DEC-311)
	self.Slots = {} :: { [number]: Slot }
end

-- Reads ---------------------------------------------------------------------------------------------------------------

-- Plates alive (in a hand)
function PlateService:AliveCount(): number
	local count = 0
	for _ in self.Plates do
		count += 1
	end
	return count
end

-- Kept for TabletService ("Kitchen full" lamp): the world kitchen has no plate cap, a plate pile is always there
function PlateService:HasRoomFor(_npc: number?): boolean
	return true
end

-- Frozen copy of a plate, nil = unknown
function PlateService:Of(id: number): Entry?
	const entry = self.Plates[id]
	return if entry ~= nil then table.freeze(table.clone(entry)) :: Entry else nil
end

-- The live plate of a player (one per hand), nil = none
function PlateService:PlateOf(player: Player): Entry?
	for _, entry in self.Plates do
		if entry.Player == player then
			return entry
		end
	end
	return nil
end

-- #n over the customer's head (Customers.Number), 0 = none
function PlateService:NumberOf(npc: number): number
	const customer = if npc ~= 0 then self.Dependencies.CustomerService:Get(npc) else nil
	return if customer ~= nil and customer.Number ~= nil then customer.Number else 0
end

-- A ticket line waiting for a plate
export type FreeTicket = { Npc: number, Line: number, Since: number }

-- Ticket lines that still wait for a hot dog, oldest order first: { npc, line, since } without a live plate on them
function PlateService:FreeTickets(): { FreeTicket }
	const customers = self.Dependencies.CustomerService
	const taken: { [string]: boolean } = {}
	for _, entry in self.Plates do
		if entry.Ticket ~= 0 then
			taken[`{entry.Ticket}:{entry.Line}`] = true
		end
	end
	const out: { FreeTicket } = {}
	for npc, ticket in customers.Tickets do
		const customer = customers:Get(npc)
		if ticket.TakenAt <= 0 or customer == nil or customer.State == LEAVING then
			continue
		end
		for index, line in ticket.Lines do
			if line.Result == nil and not taken[`{npc}:{index}`] then
				table.insert(out, { Npc = npc, Line = index, Since = ticket.TakenAt })
			end
		end
	end
	table.sort(out, function(a: FreeTicket, b: FreeTicket): boolean
		if a.Since ~= b.Since then
			return a.Since < b.Since
		elseif a.Npc ~= b.Npc then
			return a.Npc < b.Npc
		end
		return a.Line < b.Line
	end)
	return out
end

-- Wire ----------------------------------------------------------------------------------------------------------------

function PlateService:WireOf(entry: Entry): Wire
	const bun, sausage = PlateTool.Parts(entry.Tool)
	const toppings: { [string]: boolean } = {}
	for _, key in PlateTool.Toppings(entry.Tool) do
		toppings[key] = true
	end
	return {
		Npc = entry.Ticket,
		Bun = bun,
		Sausage = sausage,
		Toppings = toppings,
		Since = entry.Since,
		Altered = if entry.Tool:GetAttribute(ATTR.Altered) == true then true else nil,
	}
end

function PlateService:Publish(id: number)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	const entry = self.Plates[id]
	const last = self.Sent[id]
	if entry == nil then
		if last ~= nil then
			Restaurant.Plates:remove(id)
			self.Sent[id] = nil
		end
		return
	end
	const record = self:WireOf(entry)
	if last ~= nil and sameWire(last, record) then
		return
	end
	-- the wire struct is Lync's: send it untyped (the optional cleared with Lync.none on update)
	const wire: any = table.clone(record)
	if last == nil then
		Restaurant.Plates:add(id, wire)
	else
		if wire.Altered == nil then
			wire.Altered = Lync.none
		end
		Restaurant.Plates:update(id, wire)
	end
	self.Sent[id] = record
end

-- Sends `key` to `player` unless the same key went to them less than NOTICE_GAP s ago.
function PlateService:NotifyThrottled(player: Player, key: string, value: number?)
	const t = os.clock()
	local sent = self.NoticeAt[player]
	if sent == nil then
		sent = {}
		self.NoticeAt[player] = sent
	end
	const last = sent[key]
	if last ~= nil and t - last < NOTICE_GAP then
		return
	end
	sent[key] = t
	self.Dependencies.RunStateService:Notify(player, key, value)
end

-- Tools ---------------------------------------------------------------------------------------------------------------

-- Ticket attributes on the plate's Tool
function PlateService:Stamp(entry: Entry)
	const tool = entry.Tool
	tool:SetAttribute(ATTR.Id, entry.Id)
	tool:SetAttribute(ATTR.Ticket, if entry.Ticket ~= 0 then entry.Ticket else nil)
	tool:SetAttribute(ATTR.Line, if entry.Line ~= 0 then entry.Line else nil)
	tool:SetAttribute(ATTR.Since, if entry.Since > 0 then entry.Since else nil)
end

function PlateService:FreeId(): number?
	for id = 1, MAX_ID do
		if self.Plates[id] == nil then
			return id
		end
	end
	return nil
end

-- Ties a free ticket line to the plate (none = it stays ticketless). Returns true when it got one.
function PlateService:Bind(entry: Entry): boolean
	const free = self:FreeTickets()[1]
	if free == nil then
		return false
	end
	entry.Ticket = free.Npc
	entry.Line = free.Line
	entry.Since = free.Since
	self:Stamp(entry)
	return true
end

-- The player's Tools changed (Give, Consume, a topping, a plate filled, a Tool lost): each entry of theirs follows the Tool that
-- carries its id now (the plate -> hot_dog swap) or goes away.
function PlateService:Follow(player: Player)
	const items = self.Dependencies.ItemService
	const byId: { [number]: Tool } = {}
	if player.Parent ~= nil then
		for _, tool in items:Tools(player) do
			const id = PlateTool.Id(tool)
			if id > 0 and PlateTool.IsPlate(tool) then
				byId[id] = tool
			end
		end
	end
	for id, entry in self.Plates do
		if entry.Player ~= player then
			continue
		end
		const tool = byId[id]
		if tool == nil then
			self.Plates[id] = nil
		else
			entry.Tool = tool
			if PlateTool.Ticket(tool) ~= entry.Ticket then
				self:Stamp(entry) -- the swap carries the attributes; a stale copy is rewritten
			end
		end
		self:Publish(id)
		self.Changed:Fire(id)
	end
	-- a plate that left a hand unserved (bin, drop, death) gives its ticket line back to a slot
	self:RefreshSlots()
end

-- plate_take ----------------------------------------------------------------------------------------------------------

function PlateService:ValidateTake(player: Player): boolean
	if not self.Dependencies.RunStateService:IsActive(player) then
		return false
	end
	if self:PlateOf(player) ~= nil then
		self:NotifyThrottled(player, HANDS_FULL)
		return false
	end
	const ok, notice, value = self.Dependencies.ItemService:CanGive(player, PLATE)
	if not ok then
		if notice ~= nil then
			self:NotifyThrottled(player, notice, value)
		end
		return false
	end
	return true
end

-- Slot -> hand: an empty plate tied to the ticket line of the slot `anchor` belongs to (no slot: the oldest free line)
function PlateService:Take(player: Player, anchor: Instance?): Entry?
	if not self:ValidateTake(player) then
		return nil
	end
	const slot = if anchor ~= nil then self:SlotOf(anchor) else nil
	if slot ~= nil and slot.Npc == 0 then
		return nil -- an empty slot (its prompt is off; a stale request)
	end
	const id = self:FreeId()
	if id == nil then
		warn("[PlateService] no free PlateId (255 plates alive)")
		return nil
	end
	const tool = self.Dependencies.ItemService:Give(player, PLATE)
	if tool == nil then
		return nil
	end
	tool:SetAttribute(ATTR.Bun, false)
	tool:SetAttribute(ATTR.Sausage, false)
	const entry: Entry = { Id = id, Player = player, Tool = tool, Ticket = 0, Line = 0, Since = 0 }
	self.Plates[id] = entry
	if slot ~= nil then
		const ticket = self.Dependencies.CustomerService.Tickets[slot.Npc]
		entry.Ticket = slot.Npc
		entry.Line = slot.Line
		entry.Since = if ticket ~= nil then ticket.TakenAt else 0
		self:Stamp(entry)
	else
		self:Stamp(entry)
		self:Bind(entry)
	end
	self:Publish(id)
	self.Changed:Fire(id)
	self:RefreshSlots()
	return entry
end

-- Slots -----------------------------------------------------------------------------------------------------------------

-- The slot an anchor (Prompt_Plate) or slot part belongs to, nil = none
function PlateService:SlotOf(instance: Instance): Slot?
	local current: Instance? = instance
	while current ~= nil and current ~= workspace do
		const index = current:GetAttribute(SLOT_INDEX)
		if type(index) == "number" then
			const slot = self.Slots[index]
			if slot ~= nil and (slot.Part == current or slot.Anchor == current or current:IsAncestorOf(slot.Part)) then
				return slot
			end
		end
		current = current.Parent
	end
	return nil
end

-- Finds the slot parts of the map (a BasePart with PlateIndex and MapId PLATE-n) and gives each one a Prompt_Plate
function PlateService:BindSlots()
	table.clear(self.Slots)
	for _, part in workspace:GetDescendants() do
		const index = part:GetAttribute(SLOT_INDEX)
		const mapId = part:GetAttribute("MapId")
		if not part:IsA("BasePart") or type(index) ~= "number" or type(mapId) ~= "string" or string.sub(mapId, 1, 6) ~= "PLATE-" then
			continue
		end
		-- the counter's MarkN model names the slot (copied marks may keep the PlateIndex of the one they came from)
		const mark = part:FindFirstAncestorOfClass("Model")
		const number = if mark ~= nil then tonumber(string.match(mark.Name, "^Mark(%d+)$")) else nil
		const slotIndex = number or index
		if self.Slots[slotIndex] ~= nil then
			warn(`[PlateService] two plate slots with index {slotIndex}: {part:GetFullName()} is skipped`)
			continue
		end
		local anchor = part:FindFirstChild(SLOT_ANCHOR)
		if anchor == nil or not anchor:IsA("Attachment") then
			const made = Instance.new("Attachment")
			made.Name = SLOT_ANCHOR
			made.Position = Vector3.new(0, 0.5, 0)
			made.Parent = part
			anchor = made
		end
		const attachment = anchor :: Attachment
		attachment:SetAttribute("PromptAction", TAKE)
		attachment:SetAttribute(SLOT_INDEX, slotIndex)
		part:SetAttribute(SLOT_INDEX, slotIndex)
		CollectionService:AddTag(attachment, "Interactable")
		self.Slots[slotIndex] = { Index = slotIndex, Part = part, Anchor = attachment, Npc = 0, Line = 0 }
	end
	self:RefreshSlots()
end

-- Every free ticket line keeps its slot or gets the lowest empty one; a slot whose line got a plate (or left) empties
function PlateService:RefreshSlots()
	const free = self:FreeTickets()
	const open: { [string]: boolean } = {}
	for _, ticket in free do
		open[`{ticket.Npc}:{ticket.Line}`] = true
	end
	const shown: { [string]: boolean } = {}
	for _, slot in self.Slots do
		if slot.Npc ~= 0 and not open[`{slot.Npc}:{slot.Line}`] then
			slot.Npc, slot.Line = 0, 0
		elseif slot.Npc ~= 0 then
			shown[`{slot.Npc}:{slot.Line}`] = true
		end
	end
	const indexes: { number } = {}
	for index in self.Slots do
		table.insert(indexes, index)
	end
	table.sort(indexes)
	for _, ticket in free do
		if shown[`{ticket.Npc}:{ticket.Line}`] then
			continue
		end
		for _, index in indexes do
			const slot = self.Slots[index]
			if slot.Npc == 0 then
				slot.Npc, slot.Line = ticket.Npc, ticket.Line
				break
			end
		end
	end
	const interaction = self.Dependencies.InteractionService
	for _, slot in self.Slots do
		slot.Part:SetAttribute(SLOT_TICKET, if slot.Npc ~= 0 then slot.Npc else nil)
		slot.Part:SetAttribute(SLOT_LINE, if slot.Npc ~= 0 then slot.Line else nil)
		interaction:SetPrompt(slot.Anchor, slot.Npc ~= 0)
	end
end

-- Tickets -------------------------------------------------------------------------------------------------------------

-- A new order was taken: the oldest ticketless plate in a hand takes its first free line
function PlateService:OnTicket(_npc: number)
	const waiting: { Entry } = {}
	for _, entry in self.Plates do
		if entry.Ticket == 0 then
			table.insert(waiting, entry)
		end
	end
	table.sort(waiting, function(a: Entry, b: Entry): boolean
		return a.Id < b.Id
	end)
	for _, entry in waiting do
		if not self:Bind(entry) then
			break
		end
		self:Publish(entry.Id)
		self.Changed:Fire(entry.Id)
	end
	self:RefreshSlots()
end

-- The customer left (served, gave up, shift end): its plates lose the ticket. Returns how many plates it touched.
function PlateService:Release(npc: number): number
	local count = 0
	for id, entry in self.Plates do
		if entry.Ticket == npc then
			entry.Ticket = 0
			entry.Line = 0
			entry.Since = 0
			self:Stamp(entry)
			self:Publish(id)
			self.Changed:Fire(id)
			count += 1
		end
	end
	self:RefreshSlots()
	return count
end

-- New shift: plates in hand go (a hot dog in hand stays a hot dog with no ticket)
function PlateService:Clear()
	const items = self.Dependencies.ItemService
	for id, entry in table.clone(self.Plates) do
		self.Plates[id] = nil
		if items:ItemOf(entry.Tool) == PLATE then
			items:Consume(entry.Player, entry.Tool)
		else
			for _, name in PlateTool.Carried do
				entry.Tool:SetAttribute(name, nil)
			end
		end
		self:Publish(id)
		self.Changed:Fire(id)
	end
	self:RefreshSlots()
end

-- PICKUP ----------------------------------------------------------------------------------------------------------------

-- Gate "PlateTicket": a half plate never; a hot dog with a ticket only to its customer waiting in the pickup line. Mirrors the
-- Tool CustomerService:ServeAtPickup uses (the equipped one, else the first hot dog of the hotbar).
function PlateService:CheckPickup(player: Player, action: string, anchor: Instance): (boolean, string?)
	const customers = self.Dependencies.CustomerService
	if action == SERVE then
		const target = customers:IdOf(anchor)
		const rig = if target ~= nil then customers:Get(target) else nil
		if rig == nil or rig.Pickup == 0 then
			return true, nil
		end
	elseif action ~= PICKUP_SERVE then
		return true, nil
	end
	const items = self.Dependencies.ItemService
	const held = items:GetHeld(player)
	const heldKey = if held ~= nil then items:ItemOf(held) else nil
	if heldKey == PLATE then
		self:NotifyThrottled(player, PLATE_NOT_READY)
		return false, PLATE_NOT_READY
	end
	local tool: Tool? = if heldKey == HOT_DOG then held else nil
	if tool == nil then
		for _, candidate in items:Tools(player) do
			if items:ItemOf(candidate) == HOT_DOG then
				tool = candidate
				break
			end
		end
	end
	if tool == nil then
		return true, nil -- nothing to hand over: ServeAtPickup sends its own hint
	end
	const owner = customers:TicketOwner(tool :: Tool)
	if owner == nil then
		return true, nil -- no ticket (or its customer left): the oldest waiting customer takes it (Pickup.choose)
	end
	const customer = customers:Get(owner)
	if customer ~= nil and customer.State ~= LEAVING and (customer.Pickup == 0 or customer.State ~= WAITING) then
		self:NotifyThrottled(player, TICKET_OTHER, self:NumberOf(owner))
		return false, TICKET_OTHER
	end
	return true, nil
end

-- Dev (PlaceService:IsDev; /dev plate) --------------------------------------------------------------------------------

function PlateService:DevCheck()
	if not self.Dependencies.PlaceService:IsDev() then
		error("[PlateService] dev mode only", 3)
	end
	if not self.Enabled then
		error("plates off (not the run place)", 0)
	end
end

function PlateService:DevList(): string
	self:DevCheck()
	const lines: { string } = { `plates alive {self:AliveCount()}, free tickets {#self:FreeTickets()}` }
	const ids: { number } = {}
	for id in self.Plates do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		const entry = self.Plates[id]
		const bun, sausage = PlateTool.Parts(entry.Tool)
		table.insert(
			lines,
			string.format(
				"plate %d: %s %s ticket %d/%d (#%d) bun %s dog %s toppings [%s]%s%s",
				id,
				entry.Player.Name,
				self.Dependencies.ItemService:ItemOf(entry.Tool) or "?",
				entry.Ticket,
				entry.Line,
				self:NumberOf(entry.Ticket),
				tostring(bun),
				tostring(sausage),
				table.concat(PlateTool.Toppings(entry.Tool), ","),
				if entry.Tool:GetAttribute(ATTR.Flipped) == true then " flip" else "",
				if entry.Tool:GetAttribute(ATTR.Altered) == true then " altered" else ""
			)
		)
	end
	return table.concat(lines, "\n")
end

-- A plate for `player` as if they used the pile
function PlateService:DevGive(player: Player): string
	self:DevCheck()
	const entry = self:Take(player)
	if entry == nil then
		return "refused (hands full, one plate per hand, or not an active player)"
	end
	return `plate {entry.Id} -> {player.Name}, ticket {entry.Ticket}/{entry.Line} (#{self:NumberOf(entry.Ticket)})`
end

function PlateService:DevClear(): string
	self:DevCheck()
	self:Clear()
	return "every plate gone"
end

PlateService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	-- Priority 566 < 730: InteractionService already built its handler table
	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction(TAKE, {
		Validate = function(player: Player, _anchor: Instance): boolean
			return self:ValidateTake(player)
		end,
		Run = function(player: Player, anchor: Instance)
			self:Take(player, anchor)
		end,
	})
	-- Only the ticket owner gets a ticketed hot dog at the PICKUP (Q-383 A); a half plate never
	interaction:AddGate(TICKET_GATE, function(player: Player, action: string, anchor: Instance): (boolean, string?)
		return self:CheckPickup(player, action, anchor)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		for id, entry in self.Plates do
			if entry.Player == player then
				self.Plates[id] = nil
				self:Publish(id)
				self.Changed:Fire(id)
			end
		end
		self.NoticeAt[player] = nil
		-- owner 2026-10-20: the plate of a player who left goes back to the table now (its ticket line gets a slot again)
		self:RefreshSlots()
	end)
end)

PlateService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- the plate slots of the counter (DEC-311); a Take Plate anchor outside them (an old pile) stays on
	self:BindSlots()
	for _, anchor in CollectionService:GetTagged("Interactable") do
		if anchor:GetAttribute("PromptAction") == TAKE and anchor:IsDescendantOf(workspace) and self:SlotOf(anchor) == nil then
			self.Dependencies.InteractionService:SetPrompt(anchor, true)
		end
	end
	-- deferred: KitchenService stamps the hot dog after ItemService:Give fired Changed
	self.Dependencies.ItemService.Changed:Connect(function(player: Player)
		task.defer(function()
			self:Follow(player)
		end)
	end)
	const customers = self.Dependencies.CustomerService
	customers.Acted:Connect(function(id: number, action: string)
		if action == TAKE_ORDER then
			self:OnTicket(id)
		end
	end)
	customers.Left:Connect(function(id: number)
		self:Release(id)
	end)
	customers.Removed:Connect(function(id: number)
		self:Release(id)
	end)
	self.Dependencies.RoundService.ShiftStarted:Connect(function()
		self:Clear()
	end)
end)

-- The slots follow the tickets every SLOT_RATE: the tutorial customer's order never fires Acted (take_order), and a ticket line
-- freed by a lost plate shows again without waiting for another event
PlateService:OnTick(function(self)
	if self.Enabled and next(self.Slots) ~= nil then
		self:RefreshSlots()
	end
end, SLOT_RATE)

return PlateService
