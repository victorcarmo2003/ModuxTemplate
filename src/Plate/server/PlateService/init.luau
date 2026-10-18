--!strict
-- Central table of the restaurant and owner of every plate (tech/prep-conveyor.md §6, §7, §8, §10.1; DEC-302..DEC-305;
-- DT-E7, DT-E8, DT-E10; TASK-516). Run place only, and only with Content.Prep.Rules.Mode = "Conveyor" (restaurant on):
-- otherwise nothing is bound, no action is registered and no gate is added (the trailer flow is untouched). Single
-- writer of the Net.Restaurant Plates set and of the plate attributes of the plate / hot_dog Tools (PlateId, Ticket,
-- TicketLine, Orphan, Bun, Dog, Toppings, FlipBonus; Quality / Sauce / Altered through ItemService).
--
-- A plate is a server object kept in CenterTable.luau, in exactly one form: Table (a slot of the central table, record
-- of the Plates set), Hand (a Tool of its holder: `plate` while not assembled, `hot_dog` once it has a grade) or Belt
-- (on the conveyor; PrepService has the position). Every move is one synchronous call here (§10.1), so a plate is never
-- in two forms nor in none: AliveCount() before = after any take / put / borrow / giveback / shelve.
--
-- Birth (DEC-304): CustomerService.Acted(id, "take_order") (the tablet ends its talk with TakeOrderFor) -> Assign: one
-- empty plate per line of the order on the highest free slot, unless an assembled orphan with the same toppings adopts
-- the ticket (Rules.OrphanReuse). The tablet keeps asking HasRoomFor before the talk: AliveCount + lines <= TicketCap
-- (min(ActivePlates[party], CenterTable.Slots, bound slots)), so there is always a free slot to put a plate back.
-- Gate "Plates" on take_order / tablet_take refuses with plates_full when there is no room.
--
-- Take = hold E on the Prompt_Take of a slot (plate_take): any active player with room in the HotDog category (2;
-- otherwise hands_full); two players on the same slot: the first takes, the second gets plate_gone. Put = click / tap
-- on a free slot (packet CenterPut, PutRate per s, within CenterTable.Reach): the EQUIPPED plate / hot_dog of this
-- server goes on it; taken slot = slot_taken.
--
-- PICKUP (prep-conveyor.md §8; Q-383 A): the gate "PlateTicket" on pickup_serve (and serve on a PU-n rig) refuses a
-- `plate` not assembled (plate_not_ready), an orphan / unknown ticket (ticket_gone) and a ticket whose customer is not
-- Waiting in the pickup line (ticket_other, Value = #n). Pickup.choose (strict in Conveyor mode) then picks only the
-- ticket owner. The sale is CustomerService's (SellLine reads Quality and FlipBonus off the hot_dog, TASK-517).
--
-- Left / Removed customer -> Release (§7.6): an empty plate off the belt goes away (Tool consumed), one with something
-- on it becomes an orphan. A Tool lost outside this service (served, bin, ClearAltered, drop) ends its plate; if the
-- customer still waits for more lines than it has plates, an empty plate is born again with the ticket (P22). A player
-- leaving puts their plates back on the table (§2.3). New shift: every plate goes (Clear).
--
-- The old pass PLATE-n (TASK-379; plate_put / plate_take on Binding.PlateTag) is not bound in Conveyor mode: its prompts
-- are switched off here and plate_take on one of its anchors is refused (no slot).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Lync = require(ReplicatedStorage.Packages.Lync)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local CenterTable = require(script.CenterTable)
local Slots = require(script.Slots)
local Modux = require(ServerScriptService.server.Modux)

export type PlateForm = CenterTable.Form
export type PlateState = CenterTable.Plate
export type PlatePatch = {
	Bun: boolean?,
	Dog: boolean?,
	Toppings: { string }?,
	Grade: string?,
	FlipBonus: boolean?,
	Altered: boolean?,
	Sauce: string?,
	Cut: number?,
	Place: number?,
	StartedAt: number?,
}

-- The Tool of a plate in Hand form
export type Held = { Tool: Tool, Player: Player, Links: { RBXScriptConnection } }

export type Bucket = { Tokens: number, At: number }

const TAKE = "plate_take"
const TAKE_ORDER = "take_order"
const TABLET_TAKE = "tablet_take"
const PICKUP_SERVE = "pickup_serve"
const SERVE = "serve"
const GATE = "Plates"
const TICKET_GATE = "PlateTicket"
const ANCHOR_TAG = "Interactable"
const HOT_DOG = "hot_dog"
const PLATE = "plate"
const WAITING = "Waiting"
const LEAVING = "Leaving"
const CONVEYOR = "Conveyor"
-- Tool attributes (prep-conveyor.md §6.3)
const ATTR_ID = "PlateId"
const ATTR_TICKET = "Ticket"
const ATTR_LINE = "TicketLine"
const ATTR_ORPHAN = "Orphan"
const ATTR_BUN = "Bun"
const ATTR_DOG = "Dog"
const ATTR_TOPPINGS = "Toppings"
const ATTR_FLIP = "FlipBonus"
const ATTR_ALTERED = "Altered"
-- Notices (Content.Notices)
const PLATES_FULL = "plates_full"
const PLATE_GONE = "plate_gone"
const SLOT_TAKEN = "slot_taken"
const PLATE_NOT_READY = "plate_not_ready"
const TICKET_OTHER = "ticket_other"
const TICKET_GONE = "ticket_gone"
const PLATE_SHELVED = "plate_shelved"
-- Same notice to the same player at most once per this many seconds (FEAT-005 anti-spam). PROVISIONAL constant, same
-- value as CustomerService NOTICE_GAP: no Content field holds it yet.
const NOTICE_GAP = 2
-- Dev tickets (/dev plate fill) use NpcIds from here up: no live customer has one (NpcService pool of 12)
const DEV_NPC = 65000
-- Plates wire range (Net.Restaurant Plates record id / CenterPut.Slot 1..12)
const WIRE_SLOTS = 12

local function now(): number
	return workspace:GetServerTimeNow()
end

local function tableSize(): number
	return math.clamp(math.floor(Content.Restaurant.CenterTable.Slots), 0, WIRE_SLOTS)
end

local function sameRecord(a: Slots.Record, b: Slots.Record): boolean
	if
		a.Npc ~= b.Npc
		or a.Line ~= b.Line
		or a.Bun ~= b.Bun
		or a.Sausage ~= b.Sausage
		or a.Since ~= b.Since
		or a.Orphan ~= b.Orphan
		or a.Altered ~= b.Altered
		or a.Grade ~= b.Grade
	then
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
	-- Every plate of the shift; open slots = the bound ones
	self.Table = CenterTable.new(tableSize(), {}) :: CenterTable.CenterTable
	-- Click_Slot_n of each bound slot and its Prompt_Take anchor
	self.Parts = {} :: { [number]: BasePart }
	self.TakeAnchors = {} :: { [number]: Instance }
	self.AnchorSlot = {} :: { [Instance]: number }
	-- Last record sent per slot (nil = never added)
	self.Sent = {} :: { [number]: Slots.Record }
	-- Tool of each plate in Hand form, and the plate of each Tool
	self.Held = {} :: { [number]: Held }
	self.ToolPlate = {} :: { [Tool]: number }
	-- Last time each notice went to each player (FEAT-005 anti-spam)
	self.NoticeAt = {} :: { [Player]: { [string]: number } }
	-- CenterPut rate (Content.Restaurant.CenterTable.PutRate per s)
	self.PutBuckets = {} :: { [Player]: Bucket }
	-- Next dev ticket id (DevFill)
	self.DevNext = DEV_NPC :: number
	-- A plate changed (id): form, contents or ticket (dev, QA, Metrics)
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<number>
end

-- Reads ---------------------------------------------------------------------------------------------------------------

-- Conveyor central table live in this server (Conveyor mode and at least one slot bound)
function PlateService:IsLive(): boolean
	return self.Enabled and CenterTable.openCount(self.Table) > 0
end

-- Plates alive in any form (DT-E10)
function PlateService:AliveCount(): number
	return CenterTable.alive(self.Table)
end

-- Ticket ceiling: min(ActivePlates[party], CenterTable.Slots, bound slots) (prep-conveyor.md §7.3, P20)
function PlateService:TicketCap(): number
	const rules = Content.Restaurant.Rules
	const party = math.clamp(math.floor(self.Dependencies.CustomerService.Party or 1), 1, #rules.ActivePlates)
	return math.min(rules.ActivePlates[party], tableSize(), CenterTable.openCount(self.Table))
end

-- Lines a customer orders: 2 for a pair leader (FEAT-038), else 1
function PlateService:LinesOf(npc: number?): number
	if npc == nil then
		return 1
	end
	const customer = self.Dependencies.CustomerService:Get(npc)
	if customer ~= nil and (customer.Partner ~= nil or customer.Order2 ~= nil) then
		return 2
	end
	return 1
end

-- Room for a new order of `lines` hot dogs (default 1). Always true when the central table is off (no gate).
function PlateService:HasRoom(lines: number?): boolean
	if not self:IsLive() then
		return true
	end
	return self:AliveCount() + (lines or 1) <= self:TicketCap()
end

-- Room for the order of this customer (TabletService checks it before the talk)
function PlateService:HasRoomFor(npc: number?): boolean
	return self:HasRoom(self:LinesOf(npc))
end

-- Frozen copy of a plate, nil = unknown (prep-conveyor.md §10.1)
function PlateService:Of(id: number): PlateState?
	const plate = CenterTable.get(self.Table, id)
	return if plate ~= nil then CenterTable.copy(plate) else nil
end

-- Plate on a slot (frozen copy), nil = free
function PlateService:AtSlot(index: number): PlateState?
	const plate = CenterTable.at(self.Table, index)
	return if plate ~= nil then CenterTable.copy(plate) else nil
end

-- Plates of a ticket (frozen copies, by line)
function PlateService:PlatesOf(npc: number): { PlateState }
	const out: { PlateState } = {}
	for _, plate in CenterTable.ofTicket(self.Table, npc) do
		table.insert(out, CenterTable.copy(plate))
	end
	return out
end

-- Slot index of a Prompt_Take anchor
function PlateService:SlotOf(anchor: Instance): number?
	return self.AnchorSlot[anchor]
end

-- PlateId of a Tool of this service (nil = not a plate Tool)
function PlateService:PlateOfTool(tool: Tool): number?
	return self.ToolPlate[tool]
end

-- #n over the customer's head (Customers.Number), 0 = none
function PlateService:NumberOf(npc: number): number
	const customer = if npc ~= 0 then self.Dependencies.CustomerService:Get(npc) else nil
	return if customer ~= nil and customer.Number ~= nil then customer.Number else 0
end

-- Wire ----------------------------------------------------------------------------------------------------------------

-- Record + prompt of one slot (records 1..Size always published: free = Npc 0)
function PlateService:Publish(index: number)
	const plate = CenterTable.at(self.Table, index)
	const take = self.TakeAnchors[index]
	if take ~= nil then
		self.Dependencies.InteractionService:SetPrompt(take, plate ~= nil)
	end
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	const record = Slots.record(plate, Content.Prep.GradeKeys)
	const last = self.Sent[index]
	if last ~= nil and sameRecord(last, record) then
		return
	end
	-- the wire struct is Lync's: send it untyped (the optionals cleared with Lync.none on update)
	const wire: any = table.clone(record)
	if last == nil then
		Restaurant.Plates:add(index, wire)
	else
		if wire.Orphan == nil then
			wire.Orphan = Lync.none
		end
		if wire.Altered == nil then
			wire.Altered = Lync.none
		end
		if wire.Grade == nil then
			wire.Grade = Lync.none
		end
		Restaurant.Plates:update(index, wire)
	end
	self.Sent[index] = record
end

function PlateService:Refresh()
	for index = 1, self.Table.Size do
		self:Publish(index)
	end
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

-- Plate attributes on its Tool (prep-conveyor.md §6.3). Quality / Toppings of a hot_dog come from ItemService:Give.
function PlateService:Stamp(tool: Tool, plate: CenterTable.Plate)
	tool:SetAttribute(ATTR_ID, plate.Id)
	tool:SetAttribute(ATTR_TICKET, if plate.Ticket ~= 0 then plate.Ticket else nil)
	tool:SetAttribute(ATTR_LINE, if plate.Line ~= 0 then plate.Line else nil)
	tool:SetAttribute(ATTR_ORPHAN, if plate.Orphan or plate.Ticket == 0 then true else nil)
	tool:SetAttribute(ATTR_FLIP, if plate.FlipBonus then true else nil)
	if not CenterTable.isAssembled(plate) then
		tool:SetAttribute(ATTR_BUN, plate.Bun)
		tool:SetAttribute(ATTR_DOG, plate.Dog)
		tool:SetAttribute(ATTR_TOPPINGS, table.concat(plate.Toppings, ","))
		tool:SetAttribute(ATTR_ALTERED, if plate.Altered then true else nil)
	end
end

-- Creates the Tool of a plate in the player's hand (`plate` not assembled, `hot_dog` with Quality, Sauce and FlipBonus
-- once graded) and equips it. nil = refused (hands_full notice from ItemService) or no kit Tool; nothing changes then.
function PlateService:MakeTool(player: Player, plate: CenterTable.Plate): Tool?
	const items = self.Dependencies.ItemService
	local tool: Tool? = nil
	if CenterTable.isAssembled(plate) then
		tool = items:Give(player, HOT_DOG, {
			Toppings = table.concat(plate.Toppings, ","),
			Altered = if plate.Altered then true else nil,
			Quality = Slots.wireGrade(plate.Grade, Content.Prep.GradeKeys),
		})
		if tool ~= nil and plate.Sauce ~= "" then
			items:SetSauce(tool, plate.Sauce)
		end
	else
		tool = items:Give(player, PLATE)
	end
	if tool == nil then
		return nil
	end
	self:Stamp(tool, plate)
	self:Watch(player, tool, plate.Id)
	return tool
end

-- Follows a plate Tool: lost outside this service = Lost
function PlateService:Watch(player: Player, tool: Tool, id: number)
	const links = {
		tool.Destroying:Connect(function()
			self:Lost(tool)
		end),
		tool.AncestryChanged:Connect(function()
			if tool.Parent == nil then
				self:Lost(tool)
			end
		end),
	}
	self.Held[id] = { Tool = tool, Player = player, Links = links }
	self.ToolPlate[tool] = id
end

-- Stops following the Tool of plate `id` and, with `consume`, removes it from the hotbar
function PlateService:Detach(id: number, consume: boolean)
	const held = self.Held[id]
	if held == nil then
		return
	end
	self.Held[id] = nil
	self.ToolPlate[held.Tool] = nil
	for _, link in held.Links do
		link:Disconnect()
	end
	if consume then
		self.Dependencies.ItemService:Consume(held.Player, held.Tool)
	end
end

-- A plate Tool went away without a call here (served, bin, ClearAltered, drop, death, player left).
function PlateService:Lost(tool: Tool)
	const id = self.ToolPlate[tool]
	if id == nil then
		return
	end
	const held = self.Held[id]
	self:Detach(id, false)
	const plate = CenterTable.get(self.Table, id)
	if plate == nil or plate.Form ~= "Hand" or held == nil or held.Tool ~= tool then
		return
	end
	if held.Player.Parent == nil then
		-- the player left: the plate goes back to the table with what it had (prep-conveyor.md §2.3)
		const slot = CenterTable.shelve(self.Table, id)
		if slot ~= nil then
			self:Publish(slot)
			self.Changed:Fire(id)
			return
		end
	end
	const ticket = plate.Ticket
	CenterTable.remove(self.Table, id)
	self.Changed:Fire(id)
	if ticket ~= 0 then
		self:Reconcile(ticket)
	end
end

-- The customer still waits for more lines than it has plates: an empty plate is born again per missing line (P22)
function PlateService:Reconcile(npc: number)
	const customers = self.Dependencies.CustomerService
	const customer = customers:Get(npc)
	if customer == nil or customer.State == LEAVING then
		return
	end
	const pending = #customers:PendingToppings(npc)
	const plates = CenterTable.ofTicket(self.Table, npc)
	local missing = pending - #plates
	if missing <= 0 then
		return
	end
	const used: { [number]: boolean } = {}
	for _, plate in plates do
		used[plate.Line] = true
	end
	const at = now()
	for line = 1, 2 do
		if missing <= 0 then
			break
		end
		if used[line] then
			continue
		end
		const plate = CenterTable.spawn(self.Table, npc, line, at)
		if plate == nil then
			warn(`[PlateService] no free slot to give customer {npc} line {line} a new plate`)
			break
		end
		missing -= 1
		self:Publish(plate.Slot :: number)
		self.Changed:Fire(plate.Id)
	end
end

-- Tickets -------------------------------------------------------------------------------------------------------------

-- Gives each line of the customer's order a plate (`lines` nil = from the customer): an assembled orphan with the same
-- toppings adopts the ticket, else an empty plate is born on the highest free slot. A line that already has a plate keeps
-- it. Returns the plate ids of the lines.
function PlateService:Assign(npc: number, lines: number?): { number }
	const used: { number } = {}
	if not self:IsLive() or npc == 0 then
		return used
	end
	const orders = self.Dependencies.CustomerService:PendingToppings(npc)
	const count = math.clamp(lines or self:LinesOf(npc), 1, 2)
	const at = now()
	for line = 1, count do
		local already: CenterTable.Plate? = nil
		for _, plate in CenterTable.ofTicket(self.Table, npc) do
			if plate.Line == line then
				already = plate
			end
		end
		if already ~= nil then
			table.insert(used, already.Id)
			continue
		end
		local plate: CenterTable.Plate? = nil
		if Content.Restaurant.Rules.OrphanReuse then
			plate = CenterTable.adopt(self.Table, npc, line, orders[line] or {}, at)
			if plate ~= nil then
				const held = self.Held[plate.Id]
				if held ~= nil then
					self:Stamp(held.Tool, plate)
				end
			end
		end
		if plate == nil then
			plate = CenterTable.spawn(self.Table, npc, line, at)
		end
		if plate == nil then
			warn(`[PlateService] no free slot for customer {npc} line {line} (the Plates gate should have refused)`)
			break
		end
		table.insert(used, plate.Id)
		if plate.Slot ~= nil then
			self:Publish(plate.Slot)
		end
		self.Changed:Fire(plate.Id)
	end
	return used
end

-- The customer left (served, gave up, shift end): its plates lose the ticket; empty ones go, the rest are orphans
-- (prep-conveyor.md §7.6). Returns how many plates it touched.
function PlateService:Release(npc: number): number
	const before: { [number]: number? } = {}
	for _, plate in CenterTable.ofTicket(self.Table, npc) do
		before[plate.Id] = plate.Slot
	end
	const kept, gone = CenterTable.release(self.Table, npc)
	for _, plate in gone do
		self:Detach(plate.Id, true)
		const slot = before[plate.Id]
		if slot ~= nil then
			self:Publish(slot)
		end
		self.Changed:Fire(plate.Id)
	end
	for _, plate in kept do
		const held = self.Held[plate.Id]
		if held ~= nil then
			self:Stamp(held.Tool, plate)
		end
		if plate.Slot ~= nil then
			self:Publish(plate.Slot)
		end
		self.Changed:Fire(plate.Id)
	end
	return #kept + #gone
end

-- Every plate gone (new shift, dev): plate Tools are consumed, a hot_dog in hand stays a hot dog with no ticket
function PlateService:Clear()
	const items = self.Dependencies.ItemService
	for id, held in table.clone(self.Held) do
		const isPlate = items:ItemOf(held.Tool) == PLATE
		self:Detach(id, isPlate)
		if not isPlate then
			for _, attribute in { ATTR_ID, ATTR_TICKET, ATTR_LINE, ATTR_ORPHAN, ATTR_FLIP } do
				held.Tool:SetAttribute(attribute, nil)
			end
		end
	end
	for _, plate in CenterTable.clear(self.Table) do
		self.Changed:Fire(plate.Id)
	end
	self:Refresh()
end

-- plate_take (hold E on a slot) ---------------------------------------------------------------------------------------

function PlateService:TakeSlot(player: Player, anchor: Instance): number?
	if not self:IsLive() or not self.Dependencies.RunStateService:IsActive(player) then
		return nil
	end
	return self.AnchorSlot[anchor]
end

function PlateService:ValidateTake(player: Player, anchor: Instance): boolean
	const index = self:TakeSlot(player, anchor)
	if index == nil then
		return false
	end
	const plate = CenterTable.at(self.Table, index)
	if plate == nil then
		self:NotifyThrottled(player, PLATE_GONE)
		return false
	end
	const ok, notice, value = self.Dependencies.ItemService:CanGive(
		player,
		if CenterTable.isAssembled(plate) then HOT_DOG else PLATE
	)
	if not ok then
		if notice ~= nil then
			self.Dependencies.RunStateService:Notify(player, notice, value)
		end
		return false
	end
	return true
end

-- Table -> Hand
function PlateService:Take(player: Player, anchor: Instance)
	const index = self:TakeSlot(player, anchor)
	if index == nil then
		return
	end
	const plate = CenterTable.at(self.Table, index)
	if plate == nil then
		return
	end
	-- the Tool first: a refused Give leaves the plate on its slot
	const tool = self:MakeTool(player, plate)
	if tool == nil then
		return
	end
	CenterTable.take(self.Table, index, player)
	self:Publish(index)
	self.Changed:Fire(plate.Id)
end

-- CenterPut (click on a free slot) ------------------------------------------------------------------------------------

function PlateService:AllowPut(player: Player): boolean
	const rate = math.max(1, Content.Restaurant.CenterTable.PutRate)
	const t = os.clock()
	local bucket = self.PutBuckets[player]
	if bucket == nil then
		bucket = { Tokens = rate, At = t }
		self.PutBuckets[player] = bucket
	end
	bucket.Tokens = math.min(rate, bucket.Tokens + (t - bucket.At) * rate)
	bucket.At = t
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

-- Hand -> Table: the equipped plate / hot_dog of this service on the free slot `index`
function PlateService:Put(player: Player, index: number)
	if not self:IsLive() or not self.Dependencies.RunStateService:IsActive(player) or not self:AllowPut(player) then
		return
	end
	if index ~= math.floor(index) or not CenterTable.isOpen(self.Table, index) then
		return
	end
	const part = self.Parts[index]
	const character = player.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if part == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	if (root.Position - part.Position).Magnitude > Content.Restaurant.CenterTable.Reach then
		return
	end
	const held = self.Dependencies.ItemService:GetHeld(player)
	const id = if held ~= nil then self.ToolPlate[held] else nil
	if id == nil then
		return
	end
	const entry = self.Held[id]
	const plate = CenterTable.get(self.Table, id)
	if entry == nil or entry.Player ~= player or plate == nil or plate.Form ~= "Hand" then
		return
	end
	if CenterTable.at(self.Table, index) ~= nil then
		self:NotifyThrottled(player, SLOT_TAKEN)
		return
	end
	if not CenterTable.put(self.Table, id, index) then
		return
	end
	self:Detach(id, true)
	self:Publish(index)
	self.Changed:Fire(id)
end

-- Conveyor (PrepService, prep-conveyor.md §10.1, §10.3) ---------------------------------------------------------------

-- The plate the player would put on the belt: the equipped `plate`, else the one with the oldest ticket in the hotbar.
-- Assembled plates (hot_dog) never. nil = none.
function PlateService:WorkablePlate(player: Player): PlateState?
	const items = self.Dependencies.ItemService
	const equipped = items:GetHeld(player)
	const equippedId = if equipped ~= nil then self.ToolPlate[equipped] else nil
	local best: CenterTable.Plate? = nil
	for _, plate in CenterTable.heldBy(self.Table, player) do
		const held = self.Held[plate.Id]
		if plate.Form ~= "Hand" or CenterTable.isAssembled(plate) or held == nil or held.Player ~= player then
			continue
		end
		if plate.Id == equippedId then
			return CenterTable.copy(plate)
		end
		if not items:InPlay(held.Tool, player) then
			continue
		end
		if best == nil or (plate.Since > 0 and (best.Since == 0 or plate.Since < best.Since)) then
			best = plate
		end
	end
	return if best ~= nil then CenterTable.copy(best) else nil
end

-- Hand -> Belt: the Tool leaves the hotbar (not sold). nil = not a plate of this player in the hand, or assembled.
function PlateService:Borrow(player: Player, id: number): PlateState?
	const plate = CenterTable.get(self.Table, id)
	const held = self.Held[id]
	if plate == nil or held == nil or held.Player ~= player then
		return nil
	end
	if not CenterTable.borrow(self.Table, id, player) then
		return nil
	end
	self:Detach(id, true)
	self.Changed:Fire(id)
	return CenterTable.copy(plate)
end

-- Writes a step on a plate on the belt (Belt form only). false = unknown plate or not on the belt.
function PlateService:Commit(id: number, patch: PlatePatch): boolean
	const plate = CenterTable.get(self.Table, id)
	if plate == nil or plate.Form ~= "Belt" then
		return false
	end
	if patch.Bun ~= nil then
		plate.Bun = patch.Bun
	end
	if patch.Dog ~= nil then
		plate.Dog = patch.Dog
	end
	if patch.Toppings ~= nil then
		plate.Toppings = table.clone(patch.Toppings)
	end
	if patch.Grade ~= nil then
		plate.Grade = patch.Grade
	end
	if patch.FlipBonus ~= nil then
		plate.FlipBonus = patch.FlipBonus
	end
	if patch.Altered ~= nil then
		plate.Altered = patch.Altered
	end
	if patch.Sauce ~= nil then
		plate.Sauce = patch.Sauce
	end
	if patch.Cut ~= nil then
		plate.Cut = patch.Cut
	end
	if patch.Place ~= nil then
		plate.Place = patch.Place
	end
	if patch.StartedAt ~= nil then
		plate.StartedAt = patch.StartedAt
	end
	self.Changed:Fire(id)
	return true
end

-- Bin on the belt (prep-conveyor.md §6.6, P17): the contents go, the ticket stays. Belt form only.
function PlateService:Empty(id: number): boolean
	const plate = CenterTable.get(self.Table, id)
	if plate == nil or plate.Form ~= "Belt" then
		return false
	end
	CenterTable.empty(plate)
	self.Changed:Fire(id)
	return true
end

-- Belt -> Hand: the Tool (`plate`, or `hot_dog` with Quality and FlipBonus once graded) equipped. An empty orphan ends
-- here (nil). If the Tool cannot be made the plate goes to the table instead (never lost), and nil is returned.
function PlateService:Giveback(player: Player, id: number): Tool?
	const plate = CenterTable.get(self.Table, id)
	if plate == nil or plate.Form ~= "Belt" or plate.Holder ~= player then
		return nil
	end
	if plate.Ticket == 0 and CenterTable.isEmpty(plate) then
		CenterTable.remove(self.Table, id)
		self.Changed:Fire(id)
		return nil
	end
	const tool = if player.Parent ~= nil then self:MakeTool(player, plate) else nil
	if tool == nil then
		self:Shelve(id)
		return nil
	end
	CenterTable.giveback(self.Table, id, player)
	self.Changed:Fire(id)
	return tool
end

-- Belt / Hand -> Table on the lowest free slot (disconnect, ParkMax, player left). Returns the slot; nil = refused.
function PlateService:Shelve(id: number): number?
	const plate = CenterTable.get(self.Table, id)
	if plate == nil or plate.Form == "Table" then
		return nil
	end
	const holder = plate.Holder
	if plate.Ticket == 0 and CenterTable.isEmpty(plate) then
		-- an empty orphan does not take a slot (§7.6)
		self:Detach(id, true)
		CenterTable.remove(self.Table, id)
		self.Changed:Fire(id)
		return nil
	end
	-- no free slot (only with an unbound map, DT-E10): nothing changes
	const slot = CenterTable.shelve(self.Table, id)
	if slot == nil then
		return nil
	end
	self:Detach(id, true)
	self:Publish(slot)
	self.Changed:Fire(id)
	if holder ~= nil and holder.Parent ~= nil and plate.Ticket ~= 0 then
		self:NotifyThrottled(holder, PLATE_SHELVED, self:NumberOf(plate.Ticket))
	end
	return slot
end

-- PICKUP (prep-conveyor.md §8) ----------------------------------------------------------------------------------------

-- Gate "PlateTicket": only an assembled plate, and only to the customer of its ticket waiting in the pickup line. Mirrors
-- the hot dog CustomerService:ServeAtPickup uses (the equipped one, else the first of the hotbar).
function PlateService:CheckPickup(player: Player, action: string, anchor: Instance): (boolean, string?)
	if not self:IsLive() then
		return true, nil
	end
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
	local anyPlate = false
	if tool == nil then
		for _, candidate in items:Tools(player) do
			const key = items:ItemOf(candidate)
			if key == HOT_DOG then
				tool = candidate
				break
			elseif key == PLATE then
				anyPlate = true
			end
		end
	end
	if tool == nil then
		if anyPlate then
			self:NotifyThrottled(player, PLATE_NOT_READY)
			return false, PLATE_NOT_READY
		end
		-- nothing to hand over: ServeAtPickup sends its own hint
		return true, nil
	end
	const served = tool :: Tool
	if served:GetAttribute(ATTR_ORPHAN) == true then
		self:NotifyThrottled(player, TICKET_GONE)
		return false, TICKET_GONE
	end
	const owner = customers:TicketOwner(served)
	if owner == nil then
		self:NotifyThrottled(player, TICKET_GONE)
		return false, TICKET_GONE
	end
	const customer = customers:Get(owner)
	if customer == nil or customer.State == LEAVING then
		self:NotifyThrottled(player, TICKET_GONE)
		return false, TICKET_GONE
	end
	if customer.Pickup == 0 or customer.State ~= WAITING then
		self:NotifyThrottled(player, TICKET_OTHER, self:NumberOf(owner))
		return false, TICKET_OTHER
	end
	return true, nil
end

-- Binding -------------------------------------------------------------------------------------------------------------

function PlateService:BindAnchor(index: number, anchor: Instance)
	-- Attributes before the tag: InteractionService reads them when the anchor is tagged
	anchor:SetAttribute("PromptAction", TAKE)
	anchor:SetAttribute("PromptEnabled", false)
	if not CollectionService:HasTag(anchor, ANCHOR_TAG) then
		CollectionService:AddTag(anchor, ANCHOR_TAG)
	end
	self.AnchorSlot[anchor] = index
	self.TakeAnchors[index] = anchor
end

-- The old pass PLATE-n is scenery in Conveyor mode: its prompts stay off (TASK-496 / DEC-302)
function PlateService:SilencePass()
	const binding = Content.Restaurant.Binding
	const interaction = self.Dependencies.InteractionService
	for _, part in CollectionService:GetTagged(binding.PlateTag) do
		if not part:IsDescendantOf(workspace) then
			continue
		end
		for _, name in { binding.PlatePut, binding.PlateTake } do
			const anchor = if part.Name == name then part else part:FindFirstChild(name, true)
			if anchor ~= nil then
				interaction:SetPrompt(anchor, false)
			end
		end
	end
end

function PlateService:Bind()
	const binding = Content.Restaurant.Binding
	const size = self.Table.Size
	const open: { number } = {}
	for _, part in CollectionService:GetTagged(binding.CenterTag) do
		if not part:IsDescendantOf(workspace) then
			continue
		end
		if not part:IsA("BasePart") then
			warn(`[PlateService] {part:GetFullName()}: {binding.CenterTag} must be on a BasePart (Click_Slot_n)`)
			continue
		end
		const index = part:GetAttribute(binding.CenterIndex)
		if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > size then
			warn(`[PlateService] {part:GetFullName()}: {binding.CenterIndex} must be 1..{size}`)
			continue
		end
		if self.Parts[index] ~= nil then
			warn(`[PlateService] {binding.CenterIndex} {index} bound twice ({part:GetFullName()} ignored)`)
			continue
		end
		self.Parts[index] = part
		table.insert(open, index)
		const anchor = part:FindFirstChild(binding.CenterTake)
		if anchor ~= nil then
			self:BindAnchor(index, anchor)
		else
			warn(`[PlateService] {part:GetFullName()}: no {binding.CenterTake} (the slot cannot be taken from)`)
		end
	end
	self.Table = CenterTable.new(size, open)
	if #open == 0 then
		warn(`[PlateService] conveyor on but no {binding.CenterTag} in the map: no central table`)
	end
	self:SilencePass()
end

-- Dev (PlaceService:IsDev; /dev plate) --------------------------------------------------------------------------------

function PlateService:DevCheck()
	if not self.Dependencies.PlaceService:IsDev() then
		error("[PlateService] dev mode only", 3)
	end
	if not self:IsLive() then
		error("central table off (Prep.Rules.Mode ~= Conveyor) or no CenterSlot bound", 0)
	end
end

function PlateService:DevList(): string
	self:DevCheck()
	const party = self.Dependencies.CustomerService.Party
	const open = CenterTable.openCount(self.Table)
	const lines: { string } = {
		`plates: alive {self:AliveCount()} / cap {self:TicketCap()} (party {party}), slots {open}`,
	}
	const ids: { number } = {}
	for id in self.Table.Plates do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		const plate = self.Table.Plates[id]
		const where = if plate.Form == "Table"
			then `slot {plate.Slot}`
			else `{plate.Form} {if plate.Holder then plate.Holder.Name else "?"}`
		table.insert(
			lines,
			string.format(
				"plate %d: %s ticket %d/%d (#%d) %s bun %s dog %s toppings [%s] grade %s%s%s",
				id,
				where,
				plate.Ticket,
				plate.Line,
				self:NumberOf(plate.Ticket),
				Slots.state(plate),
				tostring(plate.Bun),
				tostring(plate.Dog),
				table.concat(plate.Toppings, ","),
				plate.Grade or "-",
				if plate.FlipBonus then " flip" else "",
				if plate.Altered then " altered" else ""
			)
		)
	end
	return table.concat(lines, "\n")
end

function PlateService:DevAssign(npc: number): string
	self:DevCheck()
	const used = self:Assign(npc)
	if #used == 0 then
		return `no free slot for {npc}`
	end
	return `customer {npc} -> plate {table.concat(used, ", ")}`
end

-- Dev tickets as empty plates on the free slots (gate test: alive = cap -> tablet_take / take_order get plates_full)
function PlateService:DevFill(count: number): string
	self:DevCheck()
	local placed = 0
	for _ = 1, count do
		self.DevNext += 1
		if #self:Assign(self.DevNext, 1) == 0 then
			break
		end
		placed += 1
	end
	return `{placed} dev plates placed, alive {self:AliveCount()} / cap {self:TicketCap()}`
end

-- Bun + dog on the plate of slot `index`
function PlateService:DevPrep(index: number): string
	self:DevCheck()
	const plate = CenterTable.at(self.Table, index)
	if plate == nil then
		error(`slot {index} has no plate`, 0)
	end
	plate.Bun = true
	plate.Dog = true
	self:Publish(index)
	self.Changed:Fire(plate.Id)
	return `slot {index}: plate {plate.Id} has bun + dog`
end

function PlateService:DevClear(): string
	self:DevCheck()
	self:Clear()
	return "every plate gone"
end

PlateService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") or Content.Prep.Rules.Mode ~= CONVEYOR then
		return
	end
	self.Enabled = true

	-- Priority 566 < 730: InteractionService already built its handler table
	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction(TAKE, {
		Validate = function(player: Player, anchor: Instance): boolean
			return self:ValidateTake(player, anchor)
		end,
		Run = function(player: Player, anchor: Instance)
			self:Take(player, anchor)
		end,
	})
	-- No order without a plate (FEAT-044, DT-E10)
	interaction:AddGate(GATE, function(_player: Player, action: string, anchor: Instance): (boolean, string?)
		if (action ~= TAKE_ORDER and action ~= TABLET_TAKE) or not self:IsLive() then
			return true, nil
		end
		const customers = self.Dependencies.CustomerService
		const npc = if action == TAKE_ORDER then customers:IdOf(anchor) else customers:Front()
		return self:HasRoomFor(npc), nil
	end)
	-- Only the ticket owner gets the plate at the PICKUP (Q-383 A)
	interaction:AddGate(TICKET_GATE, function(player: Player, action: string, anchor: Instance): (boolean, string?)
		return self:CheckPickup(player, action, anchor)
	end)
	interaction.Rejected:Connect(function(player: Player, id: number, action: string, reason: string)
		if reason == GATE and (action == TAKE_ORDER or action == TABLET_TAKE) then
			self:NotifyThrottled(player, PLATES_FULL)
		elseif action == TAKE and reason == "state" then
			-- two holds on the same slot: the second finds the prompt off (the first took the plate)
			const anchor = interaction:Get(id)
			const index = if anchor ~= nil then self.AnchorSlot[anchor] else nil
			if index ~= nil and CenterTable.at(self.Table, index) == nil then
				self:NotifyThrottled(player, PLATE_GONE)
			end
		end
	end)
	Restaurant.CenterPut:onServer(function(data, player: Player)
		self:Put(player, data.Slot)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		-- plates in the hand go back to the table now, with what they had (prep-conveyor.md §2.3)
		for _, plate in CenterTable.heldBy(self.Table, player) do
			if plate.Form == "Hand" then
				self:Detach(plate.Id, false)
				const slot = CenterTable.shelve(self.Table, plate.Id)
				if slot ~= nil then
					self:Publish(slot)
				else
					CenterTable.remove(self.Table, plate.Id)
				end
				self.Changed:Fire(plate.Id)
			end
		end
		-- a plate still on the belt after PrepService handled the leave (it calls Shelve): safety net
		task.defer(function()
			for _, plate in CenterTable.heldBy(self.Table, player) do
				if plate.Form == "Belt" then
					self:Shelve(plate.Id)
				end
			end
		end)
		self.NoticeAt[player] = nil
		self.PutBuckets[player] = nil
	end)
end)

PlateService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- The map is loaded (StreamingEnabled off, T57); InteractionService (730) scanned the tagged anchors before us and
	-- watches the ones tagged here
	self:Bind()
	self:Refresh()

	const customers = self.Dependencies.CustomerService
	customers.Acted:Connect(function(id: number, action: string)
		if action == TAKE_ORDER then
			self:Assign(id)
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

return PlateService
