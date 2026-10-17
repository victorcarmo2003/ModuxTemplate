--!strict
-- Plate slots of the restaurant assembly table (tech/restaurant-flow.md rev. 2 §2.2, §2.5; design FEAT-044; DEC-271;
-- TASK-379, wave R1-B). Run place only, and only with Content.Restaurant.Rules.Enabled: with the flag off nothing is
-- bound, no action is registered and no gate is added (the published trailer flow is untouched). Single writer of the
-- Net.Restaurant Plates set and of the hot_dog Tool attribute Ticket.
--
-- Binding (Content.Restaurant.Binding): every Instance tagged PlateTag with a number attribute PlateIndex
-- (1..Rules.PlateSlotsMax), anchors PlatePut / PlateTake found under it by name (attributes PromptAction set and the
-- Interactable tag added here when the map did not). Active slots = the bound ones with index <= ActivePlates[party]
-- (FEAT-044: 1p 4, 2p 6, 3-4p 8; party = CustomerService.Party, locked at Open); a slot past that count stays active
-- while it holds a ticket or contents. The Plates set has one record per active slot (no record = inactive).
--
-- Tickets: CustomerService.Acted(id, "take_order") -> Assign (one slot per line of a pair, Slots.pick: a prepped plate
-- first with Rules.PreppedFirst, else the lowest free); CustomerService.Left / Removed -> Release (Npc 0, contents kept,
-- Orphan when something was on it). Gate "Plates" on take_order / tablet_take: refused while the active free slots are
-- fewer than the lines of the customer at the counter, with the Notice plates_full (via InteractionService.Rejected).
--
-- Actions: plate_put (Prompt_Put): the held bun_sliced / sausage_grilled / hot_dog, or (empty hand) the stack the slot
-- needs next from the hotbar; a stack loses 1 (ItemService:SetCount), a hot_dog is consumed and its bun, sausage,
-- toppings, Altered and Ticket go back to the slot. plate_take (Prompt_Take): bun AND sausage on it and room in the
-- hotbar -> ItemService:Give(hot_dog, Toppings, Altered) + attribute Ticket = Npc; the slot empties and frees its
-- ticket. Ticket is a guide for ServeAtPickup, never a lock, and never enters the run snapshot (Stash ignores it).
-- No tick: everything runs on events. A new shift starts with every slot empty (data.md §2.2).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Lync = require(ReplicatedStorage.Packages.Lync)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local Slots = require(script.Slots)
local Modux = require(ServerScriptService.server.Modux)

-- Line and landing time of a ticket that left its slot on a taken plate (restored if it is put back)
export type Carry = { Line: number, Since: number }

const PUT = "plate_put"
const TAKE = "plate_take"
const TAKE_ORDER = "take_order"
const TABLET_TAKE = "tablet_take"
const GATE = "Plates"
const ANCHOR_TAG = "Interactable"
const HOT_DOG = "hot_dog"
const BUN = "bun_sliced"
const SAUSAGE = "sausage_grilled"
const TICKET = "Ticket"
const PLATES_FULL = "plates_full"
-- Same notice to the same player at most once per this many seconds (FEAT-005 anti-spam). PROVISIONAL constant, same
-- value as CustomerService NOTICE_GAP: no Content field holds it yet.
const NOTICE_GAP = 2
-- Dev tickets (/dev plate fill) use NpcIds from here up: no live customer has one (NpcService pool of 12)
const DEV_NPC = 65000

const KIND_OF_ITEM: { [string]: Slots.PutKind } = { [BUN] = "bun", [SAUSAGE] = "sausage", [HOT_DOG] = "plate" }
const ITEM_OF_KIND: { [Slots.PutKind]: string } = { bun = BUN, sausage = SAUSAGE, plate = HOT_DOG }

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Topping list of a Customers bitfield, in ToppingKeys order
local function toppingList(set: { [string]: boolean }?): { string }
	const out: { string } = {}
	if set == nil then
		return out
	end
	for _, key in Content.Ingredients.ToppingKeys do
		if set[key] then
			table.insert(out, key)
		end
	end
	return out
end

local function toppingSet(list: { string }): { [string]: boolean }
	const out: { [string]: boolean } = {}
	for _, key in list do
		out[key] = true
	end
	return out
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
	-- Slot state by PlateIndex (bound slots only)
	self.Slots = {} :: { [number]: Slots.Slot }
	-- Map Instance of each bound slot, and the slot of each of its anchors
	self.Parts = {} :: { [number]: Instance }
	self.PutAnchors = {} :: { [number]: Instance }
	self.TakeAnchors = {} :: { [number]: Instance }
	self.AnchorSlot = {} :: { [Instance]: number }
	-- Indices with a record on the Plates set
	self.Published = {} :: { [number]: boolean }
	-- Ticket line of the plates in hand (weak: the Tool goes away when served or thrown out)
	self.Carried = setmetatable({}, { __mode = "k" }) :: { [Tool]: Carry }
	-- Last time each notice went to each player (FEAT-005 anti-spam)
	self.NoticeAt = {} :: { [Player]: { [string]: number } }
	-- Next dev ticket id (DevFill)
	self.DevNext = DEV_NPC :: number
end

-- Reads ---------------------------------------------------------------------------------------------------------------

-- Restaurant flow live in this server (flag on and at least one slot bound)
function PlateService:IsLive(): boolean
	return self.Enabled and next(self.Slots) ~= nil
end

-- Active slot count for the party locked at Open (FEAT-044 ActivePlates), never above PlateSlotsMax
function PlateService:ActiveCount(): number
	const rules = Content.Restaurant.Rules
	const party = math.clamp(math.floor(self.Dependencies.CustomerService.Party or 1), 1, #rules.ActivePlates)
	return math.min(rules.ActivePlates[party], rules.PlateSlotsMax)
end

function PlateService:IsActive(index: number): boolean
	const slot = self.Slots[index]
	if slot == nil then
		return false
	end
	return index <= self:ActiveCount() or Slots.isOccupied(slot)
end

-- Active slots, by index
function PlateService:Active(): { Slots.Slot }
	const out: { Slots.Slot } = {}
	for index, slot in self.Slots do
		if self:IsActive(index) then
			table.insert(out, slot)
		end
	end
	table.sort(out, function(a: Slots.Slot, b: Slots.Slot): boolean
		return a.Index < b.Index
	end)
	return out
end

-- Free active slots (no ticket)
function PlateService:FreeCount(): number
	return Slots.countFree(self:Active())
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

-- Room for a new order of `lines` hot dogs (default 1). Always true when the restaurant flow is off (no gate).
function PlateService:HasRoom(lines: number?): boolean
	if not self:IsLive() then
		return true
	end
	return self:FreeCount() >= (lines or 1)
end

-- Room for the order of this customer (TabletService checks it before the talk)
function PlateService:HasRoomFor(npc: number?): boolean
	return self:HasRoom(self:LinesOf(npc))
end

-- Slot index of an anchor (Prompt_Put / Prompt_Take)
function PlateService:SlotOf(anchor: Instance): Slots.Slot?
	const index = self.AnchorSlot[anchor]
	return if index ~= nil then self.Slots[index] else nil
end

-- Slots holding a ticket of this customer
function PlateService:SlotsOf(npc: number): { Slots.Slot }
	const out: { Slots.Slot } = {}
	for _, slot in self.Slots do
		if npc ~= 0 and slot.Npc == npc then
			table.insert(out, slot)
		end
	end
	return out
end

-- Wire ----------------------------------------------------------------------------------------------------------------

function PlateService:Record(slot: Slots.Slot): any
	return {
		Npc = math.clamp(slot.Npc, 0, 65535),
		Line = math.clamp(slot.Line, 0, 2),
		Bun = slot.Bun,
		Sausage = slot.Sausage,
		Toppings = toppingSet(slot.Toppings),
		Since = slot.Since,
		-- A nil field is skipped by Lync's update: clearing an optional needs Lync.none
		Orphan = if slot.Orphan then true else Lync.none,
		Altered = if slot.Altered then true else Lync.none,
	}
end

-- Record + prompts of one slot
function PlateService:Publish(index: number)
	const slot = self.Slots[index]
	if slot == nil then
		return
	end
	const active = self:IsActive(index)
	const interaction = self.Dependencies.InteractionService
	const put = self.PutAnchors[index]
	if put ~= nil then
		interaction:SetPrompt(put, active)
	end
	const take = self.TakeAnchors[index]
	if take ~= nil then
		interaction:SetPrompt(take, active and Slots.isReady(slot))
	end
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	if active then
		const record = self:Record(slot)
		if self.Published[index] then
			Restaurant.Plates:update(index, record)
		else
			-- add: the optionals left as Lync.none would not be a value; nil = absent
			if record.Orphan == Lync.none then
				record.Orphan = nil
			end
			if record.Altered == Lync.none then
				record.Altered = nil
			end
			Restaurant.Plates:add(index, record)
			self.Published[index] = true
		end
	elseif self.Published[index] then
		Restaurant.Plates:remove(index)
		self.Published[index] = nil
	end
end

function PlateService:Refresh()
	for index in self.Slots do
		self:Publish(index)
	end
end

-- Sends `key` to `player` unless the same key went to them less than NOTICE_GAP s ago.
function PlateService:NotifyThrottled(player: Player, key: string)
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
	self.Dependencies.RunStateService:Notify(player, key)
end

-- Tickets -------------------------------------------------------------------------------------------------------------

-- Puts the ticket(s) of a customer on free active slots: one per line (`lines` nil = from the customer). Returns the
-- slot indices used; a line already on a slot is kept there.
function PlateService:Assign(npc: number, lines: number?): { number }
	const used: { number } = {}
	if not self:IsLive() or npc == 0 then
		return used
	end
	const customer = self.Dependencies.CustomerService:Get(npc)
	const orders = {
		toppingList(if customer then customer.Order else nil),
		toppingList(if customer then customer.Order2 else nil),
	}
	const count = math.clamp(lines or self:LinesOf(npc), 1, 2)
	const at = now()
	for line = 1, count do
		local already: Slots.Slot? = nil
		for _, slot in self:SlotsOf(npc) do
			if slot.Line == line then
				already = slot
			end
		end
		if already ~= nil then
			table.insert(used, already.Index)
			continue
		end
		const slot = Slots.pick(self:Active(), orders[line], Content.Restaurant.Rules.PreppedFirst)
		if slot == nil then
			warn(`[PlateService] no free plate for customer {npc} line {line} (the Plates gate should have refused)`)
			break
		end
		Slots.assign(slot, npc, line, at)
		table.insert(used, slot.Index)
		self:Publish(slot.Index)
	end
	return used
end

-- The customer left (served, gave up, shift end): its tickets go, the contents stay. Returns the slots released.
function PlateService:Release(npc: number): number
	local count = 0
	for _, slot in self:SlotsOf(npc) do
		Slots.release(slot)
		count += 1
		self:Publish(slot.Index)
	end
	-- a slot past the active count that is now empty stops being active: Refresh drops its record
	if count > 0 then
		self:Refresh()
	end
	return count
end

-- Every slot empty, no ticket (new shift, dev)
function PlateService:Clear()
	for _, slot in self.Slots do
		Slots.clear(slot)
	end
	self:Refresh()
end

-- plate_put -----------------------------------------------------------------------------------------------------------

-- Tool and kind a put would use on this slot, or the refusal notice. The held stack / plate says what to put; an
-- empty (or unrelated) hand puts what the slot needs next from the hotbar.
function PlateService:PickPut(player: Player, slot: Slots.Slot): (Tool?, Slots.PutKind?, string?)
	const items = self.Dependencies.ItemService
	const held = items:GetHeld(player)
	const heldKey = if held then items:ItemOf(held) else nil
	const heldKind = if heldKey then KIND_OF_ITEM[heldKey] else nil
	if held ~= nil and heldKind ~= nil then
		const ticket = held:GetAttribute(TICKET)
		const ok, refusal = Slots.canPut(slot, heldKind, if type(ticket) == "number" then ticket else nil)
		if not ok then
			return nil, nil, refusal
		end
		return held, heldKind, nil
	end
	const kind = Slots.needs(slot)
	if kind == nil then
		return nil, nil, "plate_full"
	end
	const ok, refusal = Slots.canPut(slot, kind, nil)
	if not ok then
		return nil, nil, refusal
	end
	const wanted = ITEM_OF_KIND[kind]
	for _, tool in items:Tools(player) do
		if items:ItemOf(tool) == wanted then
			return tool, kind, nil
		end
	end
	return nil, nil, nil
end

function PlateService:CanUse(player: Player, anchor: Instance): Slots.Slot?
	if not self:IsLive() or not self.Dependencies.RunStateService:IsActive(player) then
		return nil
	end
	const slot = self:SlotOf(anchor)
	if slot == nil or not self:IsActive(slot.Index) then
		return nil
	end
	return slot
end

function PlateService:ValidatePut(player: Player, anchor: Instance): boolean
	const slot = self:CanUse(player, anchor)
	if slot == nil then
		return false
	end
	const tool, _, notice = self:PickPut(player, slot)
	if tool == nil then
		if notice ~= nil then
			self:NotifyThrottled(player, notice)
		end
		return false
	end
	return true
end

function PlateService:Put(player: Player, anchor: Instance)
	const slot = self:CanUse(player, anchor)
	if slot == nil then
		return
	end
	const tool, kind = self:PickPut(player, slot)
	if tool == nil or kind == nil then
		return
	end
	const items = self.Dependencies.ItemService
	if kind == "plate" then
		const ticket = tool:GetAttribute(TICKET)
		const carry = self.Carried[tool]
		slot.Toppings = items:Toppings(tool)
		slot.Altered = items:IsAltered(tool)
		items:Consume(player, tool)
		slot.Bun = true
		slot.Sausage = true
		slot.Orphan = false
		-- the plate's own ticket comes back with it while its customer is still around and has no other slot for that line
		const line = if carry then carry.Line else 1
		if slot.Npc == 0 and type(ticket) == "number" and self.Dependencies.CustomerService:Get(ticket) ~= nil then
			local taken = false
			for _, other in self:SlotsOf(ticket) do
				if other.Line == line then
					taken = true
				end
			end
			if not taken then
				Slots.assign(slot, ticket, line, if carry and carry.Since > 0 then carry.Since else now())
			end
		end
	else
		items:SetCount(tool, items:Count(tool) - 1)
		if kind == "bun" then
			slot.Bun = true
		else
			slot.Sausage = true
		end
	end
	self:Publish(slot.Index)
end

-- plate_take ----------------------------------------------------------------------------------------------------------

function PlateService:ValidateTake(player: Player, anchor: Instance): boolean
	const slot = self:CanUse(player, anchor)
	if slot == nil then
		return false
	end
	if not Slots.isReady(slot) then
		self:NotifyThrottled(player, "plate_not_ready")
		return false
	end
	const ok, notice, value = self.Dependencies.ItemService:CanGive(player, HOT_DOG)
	if not ok then
		if notice ~= nil then
			self.Dependencies.RunStateService:Notify(player, notice, value)
		end
		return false
	end
	return true
end

function PlateService:Take(player: Player, anchor: Instance)
	const slot = self:CanUse(player, anchor)
	if slot == nil or not Slots.isReady(slot) then
		return
	end
	const tool = self.Dependencies.ItemService:Give(player, HOT_DOG, {
		Toppings = table.concat(slot.Toppings, ","),
		Altered = if slot.Altered then true else nil,
	})
	if tool == nil then
		return
	end
	if slot.Npc ~= 0 then
		tool:SetAttribute(TICKET, slot.Npc)
		self.Carried[tool] = { Line = slot.Line, Since = slot.Since }
	end
	Slots.clear(slot)
	self:Refresh()
end

-- Binding -------------------------------------------------------------------------------------------------------------

function PlateService:BindAnchor(index: number, root: Instance, name: string, action: string): Instance?
	const anchor = if root.Name == name then root else root:FindFirstChild(name, true)
	if anchor == nil then
		return nil
	end
	-- Attributes before the tag: InteractionService reads them when the anchor is tagged
	anchor:SetAttribute("PromptAction", action)
	anchor:SetAttribute("PromptEnabled", false)
	if not CollectionService:HasTag(anchor, ANCHOR_TAG) then
		CollectionService:AddTag(anchor, ANCHOR_TAG)
	end
	self.AnchorSlot[anchor] = index
	return anchor
end

function PlateService:Bind()
	const binding = Content.Restaurant.Binding
	const max = Content.Restaurant.Rules.PlateSlotsMax
	for _, part in CollectionService:GetTagged(binding.PlateTag) do
		if not part:IsDescendantOf(workspace) then
			continue
		end
		const index = part:GetAttribute(binding.PlateIndex)
		if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > max then
			warn(`[PlateService] {part:GetFullName()}: {binding.PlateIndex} must be 1..{max}`)
			continue
		end
		if self.Slots[index] ~= nil then
			warn(`[PlateService] {binding.PlateIndex} {index} bound twice ({part:GetFullName()} ignored)`)
			continue
		end
		self.Slots[index] = Slots.new(index)
		self.Parts[index] = part
		self.PutAnchors[index] = self:BindAnchor(index, part, binding.PlatePut, PUT)
		self.TakeAnchors[index] = self:BindAnchor(index, part, binding.PlateTake, TAKE)
		if self.PutAnchors[index] == nil or self.TakeAnchors[index] == nil then
			warn(`[PlateService] PLATE-{index}: missing {binding.PlatePut} or {binding.PlateTake}`)
		end
	end
	if next(self.Slots) == nil then
		warn(`[PlateService] restaurant on but no {binding.PlateTag} in the map: no plate slots`)
	end
end

-- Dev (PlaceService:IsDev; /dev plate) --------------------------------------------------------------------------------

function PlateService:DevCheck()
	if not self.Dependencies.PlaceService:IsDev() then
		error("[PlateService] dev mode only", 3)
	end
	if not self:IsLive() then
		error("restaurant off (Content.Restaurant.Rules.Enabled) or no PlateSlot bound", 0)
	end
end

function PlateService:DevList(): string
	self:DevCheck()
	const lines: { string } = { `plates: active {self:ActiveCount()} (party {self.Dependencies.CustomerService.Party}), free {self:FreeCount()}` }
	const indices: { number } = {}
	for index in self.Slots do
		table.insert(indices, index)
	end
	table.sort(indices)
	for _, index in indices do
		const slot = self.Slots[index]
		table.insert(
			lines,
			string.format(
				"PLATE-%d%s ticket %d/%d bun %s sausage %s toppings [%s]%s%s",
				index,
				if self:IsActive(index) then "" else " (inactive)",
				slot.Npc,
				slot.Line,
				tostring(slot.Bun),
				tostring(slot.Sausage),
				table.concat(slot.Toppings, ","),
				if slot.Orphan then " orphan" else "",
				if slot.Altered then " altered" else ""
			)
		)
	end
	return table.concat(lines, "\n")
end

function PlateService:DevAssign(npc: number): string
	self:DevCheck()
	const used = self:Assign(npc)
	if #used == 0 then
		return `no free plate for {npc}`
	end
	return `customer {npc} -> PLATE-{table.concat(used, ", PLATE-")}`
end

-- Dev tickets on the first `count` free active slots (gate test: all taken = plates_full on tablet_take)
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
	return `{placed} dev tickets placed, {self:FreeCount()} free`
end

-- Bun + sausage on slot `index` (pre-prep)
function PlateService:DevPrep(index: number): string
	self:DevCheck()
	const slot = self.Slots[index]
	if slot == nil then
		error(`PLATE-{index} not bound`, 0)
	end
	slot.Bun = true
	slot.Sausage = true
	self:Publish(index)
	return `PLATE-{index} has bun + sausage`
end

function PlateService:DevClear(): string
	self:DevCheck()
	self:Clear()
	return "every plate empty"
end

PlateService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") or not Content.Restaurant.Rules.Enabled then
		return
	end
	self.Enabled = true

	-- Priority 566 < 730: InteractionService already built its handler table
	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction(PUT, {
		Validate = function(player: Player, anchor: Instance): boolean
			return self:ValidatePut(player, anchor)
		end,
		Run = function(player: Player, anchor: Instance)
			self:Put(player, anchor)
		end,
	})
	interaction:RegisterAction(TAKE, {
		Validate = function(player: Player, anchor: Instance): boolean
			return self:ValidateTake(player, anchor)
		end,
		Run = function(player: Player, anchor: Instance)
			self:Take(player, anchor)
		end,
	})
	-- No order without a plate (FEAT-044): the customer at the counter needs one free active slot per line
	interaction:AddGate(GATE, function(_player: Player, action: string, anchor: Instance): (boolean, string?)
		if (action ~= TAKE_ORDER and action ~= TABLET_TAKE) or not self:IsLive() then
			return true, nil
		end
		const customers = self.Dependencies.CustomerService
		const npc = if action == TAKE_ORDER then customers:IdOf(anchor) else customers:Front()
		return self:HasRoomFor(npc), nil
	end)
	interaction.Rejected:Connect(function(player: Player, _id: number, action: string, reason: string)
		if reason == GATE and (action == TAKE_ORDER or action == TABLET_TAKE) then
			self:NotifyThrottled(player, PLATES_FULL)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		self.NoticeAt[player] = nil
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
	const round = self.Dependencies.RoundService
	round.ShiftStarted:Connect(function()
		self:Clear()
	end)
	-- the party is locked at Open: the active slot count follows it
	round.PhaseChanged:Connect(function()
		self:Refresh()
	end)
end)

return PlateService
