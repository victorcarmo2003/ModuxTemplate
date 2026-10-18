--!strict
--[[
	PlateController (TASK-383, R1-F; design FEAT-044, DEC-271; tech/restaurant-flow.md rev. 2 §2.2 / §3.3)
	Conveyor (TASK-522; DEC-304, Q-383 A; tech/prep-conveyor.md §6.3 / §6.4 / §7; network.md §19; MAP-01-r4 §16.5 d)

	Presents the plates; decides nothing (PlateService assigns tickets, fills and empties the plates, the Tools `plate` and
	`hot_dog` carry the plate in the hand).

	  - Plates set (Net.Restaurant) -> one Vide source per slot. Conveyor: record = central table slot
	    1..CenterTable.Slots (every slot published, free = Npc 0 and no Orphan; Grade = band of an assembled plate).
	    Pass of TASK-383 (no conveyor): record = plate index 1..Rules.PlateSlotsMax.
	  - Binding. Conveyor: tag Binding.CenterTag + attribute Binding.CenterIndex on each Click_Slot_n of the CENTER model;
	    the plate sits on Mount_Plate_n (Binding.CenterMount: Attachment, or a part's top; none = the bottom of the box).
	    Pass: tag Binding.PlateTag + Binding.PlateIndex on PLATE-n. A late tag or attribute still binds.
	  - Look (local only). Conveyor: a free slot draws nothing (the table has its marks); a slot with a ticket or an
	    orphan draws the plate (kit Tool `plate`, else a drawn dish) with its content on it. Pass: an empty plate is a
	    ghost (GHOST_TRANSPARENCY), the content drawn on PLATE-n. Content = kit Tools bun_sliced, sausage_grilled, or
	    hot_dog with the toppings stacked by HotDogVisual (drawn parts when the kit is missing).
	  - Ticket (Interface/Components/PlateTicket, BillboardGui, MaxDistance 40) on Att_Ticket while the slot has a ticket
	    or an orphan: #n (Customers.Number), the order of its line, faded icons for what is still missing, the patience
	    ring, "!" under Rules.UrgentAt, the oldest open ticket pulsing. Conveyor: the grade of an assembled plate rides
	    over it (TicketHud.Tag). The last order seen is kept, so an orphan still shows what it was.
	  - Conveyor hands and HUD (TicketHud): while the local player holds a plate its ticket (#n, the order's items and
	    toppings, the grade) is on the HUD and swaps with the equipped plate; inside the belt focus it comes from the
	    own PrepSeats record (Ticket / Line / Plate mask). A crewmate's plate in hand carries a "#n" tag.
	  - Conveyor put (CenterTable): click / tap a free slot, or "Set down" (touch button, gamepad Y) for the nearest
	    free slot -> packet CenterPut. A slot shown as taken sends nothing.
	  - Prompts: plugs the Plates probe into PromptController/Rules (pass: plate_put / plate_take by hand and by plate;
	    conveyor: plate_take on the nearest plate with room in the hands, pickup_serve only with an assembled plate of
	    a customer waiting at the pickup).

	Content.Restaurant.Rules.Enabled = false: inert (no listener, no tag watch, no probe); the published game is unchanged.
	Listeners in OnInit (before Lync.start); tags are scanned in OnStart.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local HotDogVisual = require(ReplicatedStorage.shared.Item.HotDogVisual)
local PlateMask = require(ReplicatedStorage.shared.Prep.PlateMask)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local PlateTicket = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PlateTicket)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Rules = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Rules)
local CenterTable = require(script.CenterTable)
local TicketHud = require(script.TicketHud)

const RESTAURANT = Content.Restaurant
const BINDING = RESTAURANT.Binding
const MAX_TOPPINGS = Content.OrderRules.MaxToppings
-- the central table replaces the pass (prep-conveyor.md §7.4): Prep.Rules.Mode is the only selector
const CONVEYOR = RESTAURANT.Rules.Enabled and Content.Prep.Rules.Mode == "Conveyor"
const SLOT_TAG = if CONVEYOR then BINDING.CenterTag else BINDING.PlateTag
const SLOT_INDEX = if CONVEYOR then BINDING.CenterIndex else BINDING.PlateIndex
const TICKET_ANCHOR = if CONVEYOR then BINDING.CenterTicket else BINDING.PlateTicket
const GHOST_TRANSPARENCY = 0.5 -- tech §3.3: empty plate translucent (pass only)
const TICKET_DISTANCE = 40
const TICKET_LIFT = 1.6 -- studs over the plate when the map has no Att_Ticket
const GRADE_OFFSET = Vector2.new(0, 1.1) -- the grade tag rides just over the slot ticket (fraction of its own size)
const FOOD_ANCHOR = "Att_Food" -- optional Attachment on PLATE-n
const TICK = 0.1 -- s, patience ring clock (only while a ticket is shown)
const BLANK = "blank" -- ANM-001 rig Variant: the ticket has no icon
const FOOD_FOLDER = "PlateFood"
const BUN_COLOR = Color3.fromHex("#E8B36B")
const DOG_COLOR = Color3.fromHex("#C8553D")
const DISH_COLOR = Color3.fromHex("#F4F1EA")
const RIM_COLOR = Color3.fromHex("#D9D2C3")
const DISH_SIZE = Vector3.new(1.8, 0.1, 1.0) -- AST-162 placeholder until the kit Tool `plate` exists
const PLATE_KIT = "plate"
const PUT_BIND = "CenterPut"
const PUT_PRIORITY = 5 -- over ClassController's Crew toggle (ButtonY, priority 0); only bound near a free slot
const STEP_RATE = 10 -- Hz: central table pick, nearest plate for the prompts, HUD place
const HUD_GAP = 8 -- px under the order card
const HUD_FALLBACK = UDim2.fromOffset(8, 96)
const NO_GRADE = "None"

export type Record = {
	Npc: number,
	Line: number,
	Bun: boolean,
	Sausage: boolean,
	Toppings: { [string]: boolean },
	Since: number,
	Orphan: boolean?,
	Altered: boolean?,
	Grade: string?, -- conveyor: band of an assembled plate, nil = not assembled
}

-- What the ticket and the HUD read from the Customers set
type Customer = {
	State: string,
	Number: number?,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
	PatienceEndsAt: number,
	PatienceSpan: number,
	Phase: string,
	Pickup: number?,
	Drive: number?,
}

-- Last order seen on a plate (an orphan keeps showing it)
type Memo = { Npc: number, Line: number, Number: number?, Toppings: { string } }

-- Last order seen for a ticket (the HUD of an orphan plate in hand)
type TicketMemo = { Number: number?, Order: { string }, Order2: { string }?, Drive: boolean }

-- Own belt seat (PrepSeats): the plate on the belt while the focus is open
type Seat = { Ticket: number, Line: number, Plate: number }

-- The ticket the HUD shows, from the equipped plate or the own belt seat
type Current = {
	Ticket: number,
	Line: number,
	Orphan: boolean,
	Bun: boolean,
	Dog: boolean,
	Toppings: { [string]: boolean },
	Grade: string?,
	Flip: boolean,
	InHand: boolean,
}

type Slot = {
	Index: number,
	Record: Vide.Source<Record | false>,
	Blank: Vide.Source<boolean>,
	Part: BasePart?,
	Mount: Instance?, -- conveyor: Mount_Plate_n
	Saved: { [BasePart]: number }, -- authored Transparency of the visible parts of PLATE-n
	Food: Model?,
	FoodKey: string,
	Memo: Memo?,
	Unmount: (() -> ())?,
	Gui: Instance?,
	GradeUnmount: (() -> ())?,
	GradeGui: Instance?,
}

const PlateController = Modux.Controller("PlateController", { Require = { "InputController" }, Priority = 660 })

function PlateController:Setup()
	self.Slots = {} :: { [number]: Slot }
	-- plate Part -> its watcher connections
	self.Tracked = {} :: { [Instance]: { RBXScriptConnection } }
	-- NpcId -> Customers record (copy); one source for the whole map (<= 12 customers, few writes)
	self.Customers = Vide.source({}) :: Vide.Source<{ [number]: Customer }>
	self.Tickets = {} :: { [number]: TicketMemo }
	self.Now = Vide.source(Workspace:GetServerTimeNow()) :: Vide.Source<number>
	self.Gui = nil :: Instance?
	self.Folder = nil :: Folder?
	self.Clock = nil :: thread?
	self.Warned = false :: boolean
	-- conveyor: own belt seat, local hands, the put input, the HUD layer
	self.SeatId = 0 :: number
	self.Seat = Vide.source(false :: Seat | false) :: Vide.Source<Seat | false>
	self.Hand = nil :: TicketHud.Tracker?
	self.Center = nil :: CenterTable.State?
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.HudPosition = Vide.source(HUD_FALLBACK) :: Vide.Source<UDim2>
	self.HudGui = nil :: ScreenGui?
end

function PlateController:Enabled(): boolean
	return RESTAURANT.Rules.Enabled
end

-- Reactive read of a plate record (nil = no such plate). For other controllers and debugging.
function PlateController:RecordOf(index: number): Record?
	const slot = self.Slots[index]
	if slot == nil then
		return nil
	end
	const record = slot.Record()
	return if record == false then nil else record
end

-- Reactive: index of the plate holding the ticket of `npc` (nil = none)
function PlateController:PlateOf(npc: number): number?
	for index, slot in self.Slots do
		const record = slot.Record()
		if record ~= false and record.Npc == npc and npc ~= 0 then
			return index
		end
	end
	return nil
end

function PlateController:SlotOf(index: number): Slot
	const existing = self.Slots[index]
	if existing ~= nil then
		return existing
	end
	const slot: Slot = {
		Index = index,
		Record = Vide.source(false :: Record | false) :: Vide.Source<Record | false>,
		Blank = Vide.source(false) :: Vide.Source<boolean>,
		Part = nil,
		Mount = nil,
		Saved = {},
		Food = nil,
		FoodKey = "",
		Memo = nil,
		Unmount = nil,
		Gui = nil,
		GradeUnmount = nil,
		GradeGui = nil,
	}
	self.Slots[index] = slot
	return slot
end

-- Topping keys of an order bitfield, ToppingKeys order, max MaxToppings (DEC-071)
local function toppingList(order: { [string]: boolean }?): { string }
	const list: { string } = {}
	if order == nil then
		return list
	end
	for _, key in Content.Ingredients.ToppingKeys do
		if order[key] then
			table.insert(list, key)
			if #list >= MAX_TOPPINGS then
				break
			end
		end
	end
	return list
end

-- Rig of a customer (CrewRig tag + NpcId attribute); nil = none (drive-thru customer, rig not streamed yet)
local function rigOf(npc: number): Model?
	for _, instance in CollectionService:GetTagged(CrewRig.Tag) do
		if instance:IsA("Model") and instance:GetAttribute("NpcId") == npc then
			return instance
		end
	end
	return nil
end

-- A plate is on the slot: a ticket on it, or an orphan
local function ticketUp(record: Record | false): boolean
	return record ~= false and (record.Npc ~= 0 or record.Orphan == true)
end

-- The grade of a record ("None" and nil = not assembled)
local function gradeOf(record: Record | false): string?
	if record == false or record.Grade == nil or record.Grade == NO_GRADE then
		return nil
	end
	return record.Grade
end

-- Copies: the set may reuse its record table between frames, and Vide needs a new value to notice a change.
function PlateController:WriteRecord(index: number, record: Record?)
	const slot = self:SlotOf(index)
	if record == nil then
		slot.Record(false)
		slot.Memo = nil
		self:Refresh(slot)
		return
	end
	const copy: Record = {
		Npc = record.Npc,
		Line = record.Line,
		Bun = record.Bun,
		Sausage = record.Sausage,
		Toppings = table.clone(record.Toppings),
		Since = record.Since,
		Orphan = record.Orphan,
		Altered = record.Altered,
		Grade = record.Grade,
	}
	if copy.Npc == 0 and not copy.Orphan then
		slot.Memo = nil
	end
	if copy.Npc ~= 0 then
		const rig = rigOf(copy.Npc)
		slot.Blank(rig ~= nil and rig:GetAttribute("Variant") == BLANK)
	else
		slot.Blank(false)
	end
	slot.Record(copy)
	self:Remember(slot)
	self:Refresh(slot)
end

function PlateController:WriteCustomer(id: number, record: any?)
	const map = table.clone(Vide.untrack(self.Customers))
	if record == nil then
		map[id] = nil
	else
		map[id] = {
			State = record.State,
			Number = record.Number,
			Order = table.clone(record.Order),
			Order2 = if record.Order2 then table.clone(record.Order2) else nil,
			PatienceEndsAt = record.PatienceEndsAt,
			PatienceSpan = record.PatienceSpan,
			Phase = record.Phase,
			Pickup = record.Pickup,
			Drive = record.Drive,
		}
		-- the HUD of an orphan plate keeps the last order seen for its ticket
		if record.Number ~= nil then
			self.Tickets[id] = {
				Number = record.Number,
				Order = toppingList(record.Order),
				Order2 = if record.Order2 then toppingList(record.Order2) else nil,
				Drive = record.Drive ~= nil,
			}
		end
	end
	self.Customers(map)
	for _, slot in self.Slots do
		self:Remember(slot)
	end
end

-- Own belt seat (conveyor): the plate on the belt while the focus is open; parked (Away) or no plate = none
function PlateController:WriteSeat(id: number, record: any?)
	const me = Players.LocalPlayer.UserId
	if record ~= nil and record.User == me then
		self.SeatId = id
		const stop = record.Stop or 0
		const ticket = record.Ticket or 0
		if stop > 0 and ticket ~= 0 and record.Away ~= true then
			self.Seat({ Ticket = ticket, Line = if record.Line == 2 then 2 else 1, Plate = record.Plate or 0 })
		else
			self.Seat(false)
		end
	elseif self.SeatId == id then
		self.SeatId = 0
		self.Seat(false)
	end
end

-- Keeps the last order seen for the ticket of a plate (an orphan keeps showing it)
function PlateController:Remember(slot: Slot)
	const record = Vide.untrack(slot.Record)
	if record == false or record.Npc == 0 then
		return
	end
	const customer = Vide.untrack(self.Customers)[record.Npc]
	if customer == nil then
		return
	end
	const order = if record.Line == 2 then customer.Order2 else customer.Order
	if order == nil then
		return
	end
	slot.Memo = { Npc = record.Npc, Line = record.Line, Number = customer.Number, Toppings = toppingList(order) }
end

-- Reactive: the ticket is up (a ticket on it, or an orphan)
function PlateController:HasTicket(slot: Slot): boolean
	return ticketUp(slot.Record())
end

-- Non-reactive: any ticket up on the table
function PlateController:AnyTicket(): boolean
	for _, slot in self.Slots do
		if ticketUp(Vide.untrack(slot.Record)) then
			return true
		end
	end
	return false
end

function PlateController:CustomerOf(slot: Slot): Customer?
	const record = slot.Record()
	if record == false or record.Npc == 0 then
		return nil
	end
	return self.Customers()[record.Npc]
end

function PlateController:NumberOf(slot: Slot): number?
	const customer = self:CustomerOf(slot)
	if customer ~= nil and customer.Number ~= nil then
		return customer.Number
	end
	const memo = slot.Memo
	return if memo then memo.Number else nil
end

-- Reactive #n of a ticket (Customers, else the last seen)
function PlateController:TicketNumber(npc: number): number?
	const customer = self.Customers()[npc]
	if customer ~= nil and customer.Number ~= nil then
		return customer.Number
	end
	const memo = self.Tickets[npc]
	return if memo then memo.Number else nil
end

function PlateController:ToppingsOf(slot: Slot): { string }
	const record = slot.Record()
	const customer = self:CustomerOf(slot)
	if record ~= false and customer ~= nil then
		const order = if record.Line == 2 then customer.Order2 else customer.Order
		if order ~= nil then
			return toppingList(order)
		end
	end
	const memo = slot.Memo
	return if memo then table.clone(memo.Toppings) else {}
end

function PlateController:PatienceOf(slot: Slot): number
	const customer = self:CustomerOf(slot)
	if customer == nil or customer.Phase == "None" or customer.PatienceEndsAt <= 0 or customer.PatienceSpan <= 0 then
		return -1
	end
	return math.clamp((customer.PatienceEndsAt - self.Now()) / customer.PatienceSpan, 0, 1)
end

-- Reactive: this plate holds the oldest open ticket of the table (only with 2+ open: one alone does not pulse)
function PlateController:IsOldest(slot: Slot): boolean
	local open, oldest, since = 0, 0, math.huge
	for index, other in self.Slots do
		const record = other.Record()
		if record ~= false and record.Npc ~= 0 and not record.Orphan then
			open += 1
			if record.Since < since or (record.Since == since and index < oldest) then
				oldest, since = index, record.Since
			end
		end
	end
	return open >= 2 and oldest == slot.Index
end

-- Look + food + ticket of one plate, after a record or a binding change
function PlateController:Refresh(slot: Slot)
	self:ApplyLook(slot)
	self:BuildFood(slot)
	self:MountTicket(slot)
	self:RunClock()
end

-- Ghost (no bun, no dog) = translucent; else the authored look (pass only: the central table has no authored plate)
function PlateController:ApplyLook(slot: Slot)
	const record = Vide.untrack(slot.Record)
	const ghost = not CONVEYOR and (record == false or not (record.Bun or record.Sausage))
	for part, authored in slot.Saved do
		if part.Parent ~= nil then
			part.Transparency = if ghost then math.max(authored, GHOST_TRANSPARENCY) else authored
		end
	end
end

-- Parts of the plate model the look may touch: visible ones, not the prompt / ticket anchors
local function lookParts(root: BasePart): { BasePart }
	const parts: { BasePart } = {}
	local function consider(part: BasePart)
		const name = part.Name
		if part.Transparency >= 1 or string.sub(name, 1, 7) == "Prompt_" or string.sub(name, 1, 4) == "Att_" then
			return
		end
		table.insert(parts, part)
	end
	consider(root)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			consider(descendant)
		end
	end
	return parts
end

-- Top of a part's box, its yaw kept
local function topOf(part: BasePart): CFrame
	const cf = part.CFrame
	-- world height of the part's box
	const size = part.Size
	const height = math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z
	const _, yaw = cf:ToOrientation()
	return CFrame.new(cf.Position + Vector3.new(0, height / 2, 0)) * CFrame.fromOrientation(0, yaw, 0)
end

-- World CFrame the food sits on (pass): Att_Food, else the top of the plate part
local function foodBase(part: BasePart): CFrame
	const anchor = part:FindFirstChild(FOOD_ANCHOR)
	if anchor ~= nil and anchor:IsA("Attachment") then
		return anchor.WorldCFrame
	end
	return topOf(part)
end

-- Mount_Plate_n of a central table slot: inside the CENTER model holding the box, else next to the box
local function findMount(box: BasePart, index: number): Instance?
	const name = string.format(BINDING.CenterMount, index)
	const model = box:FindFirstAncestor(BINDING.CenterModel) or box.Parent
	if model == nil then
		return nil
	end
	return model:FindFirstChild(name, true)
end

-- World CFrame a central table plate sits on: the mount (Attachment, or the top of a part); nil = the box decides
local function mountCFrame(mount: Instance?): CFrame?
	if mount == nil or mount.Parent == nil then
		return nil
	elseif mount:IsA("Attachment") then
		const cf = mount.WorldCFrame
		const _, yaw = cf:ToOrientation()
		return CFrame.new(cf.Position) * CFrame.fromOrientation(0, yaw, 0)
	elseif mount:IsA("BasePart") then
		return topOf(mount)
	end
	return nil
end

local function quiet(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		elseif descendant:IsA("LuaSourceContainer") or descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end
end

-- Kit Tool `key` as an anchored Model (primary = Handle); nil when the kit has no such Tool
function PlateController:KitModel(key: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const tools = if items then items:FindFirstChild("Tools") else nil
	const tool = if tools then tools:FindFirstChild(key) else nil
	if tool == nil or not tool:IsA("Tool") then
		if not self.Warned then
			self.Warned = true
			warn(`[PlateController] Assets.Items.Tools.{key} missing: plates draw a placeholder`)
		end
		return nil
	end
	const copy = tool:Clone()
	const model = Instance.new("Model")
	model.Name = key
	for _, child in copy:GetChildren() do
		if not child:IsA("LuaSourceContainer") then
			child.Parent = model
		end
	end
	copy:Destroy()
	const handle = model:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = handle
	return model
end

-- Placeholder bun and / or dog (kit missing)
local function drawnFood(bun: boolean, dog: boolean): Model
	const model = Instance.new("Model")
	model.Name = "PlateFood"
	local primary: BasePart? = nil
	if bun then
		const part = Instance.new("Part")
		part.Name = "Handle"
		part.Size = Vector3.new(0.45, 0.3, 1.1)
		part.Color = BUN_COLOR
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = model
		primary = part
	end
	if dog then
		const part = Instance.new("Part")
		part.Name = if primary then "Sausage" else "Handle"
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(1.2, 0.22, 0.22)
		part.Color = DOG_COLOR
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = CFrame.new(0, if primary then 0.14 else 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
		part.Parent = model
		primary = primary or part
	end
	model.PrimaryPart = primary
	return model
end

-- Placeholder dish (AST-162 until the kit Tool `plate`). Like the kit plate it has a `Rim` part (World/BeltMates paints
-- that one with the owner's colour on the belt; here it stays plain)
local function drawnDish(): Model
	const model = Instance.new("Model")
	model.Name = PLATE_KIT
	const part = Instance.new("Part")
	part.Name = "Handle"
	part.Size = DISH_SIZE
	part.Color = DISH_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model
	const rim = Instance.new("Part")
	rim.Name = "Rim"
	rim.Size = DISH_SIZE + Vector3.new(0.12, -0.04, 0.12)
	rim.CFrame = CFrame.new(0, -0.02, 0)
	rim.Color = RIM_COLOR
	rim.Material = Enum.Material.SmoothPlastic
	rim.Parent = model
	model.PrimaryPart = part
	return model
end

-- Bun / dog / hot dog model for a record (kit, else drawn); nil = nothing on the plate
function PlateController:ContentModel(record: Record): Model?
	if not (record.Bun or record.Sausage) then
		return nil
	end
	local model: Model? = nil
	if record.Bun and record.Sausage then
		model = self:KitModel("hot_dog")
		if model ~= nil then
			quiet(model)
			HotDogVisual.apply(model, toppingList(record.Toppings))
		end
	elseif record.Bun then
		model = self:KitModel("bun_sliced")
	else
		model = self:KitModel("sausage_grilled")
	end
	const food = model or drawnFood(record.Bun, record.Sausage)
	quiet(food)
	return food
end

-- Places `model` with its bottom on `base` (no-op without a primary part)
local function sitOn(model: Model, base: CFrame): number
	if model.PrimaryPart == nil then
		return 0
	end
	const _, extents = model:GetBoundingBox()
	model:PivotTo(base * CFrame.new(0, extents.Y / 2, 0))
	return extents.Y
end

-- Conveyor: where the plate of a slot sits
function PlateController:BaseOf(slot: Slot): CFrame?
	const mounted = mountCFrame(slot.Mount)
	if mounted ~= nil then
		return mounted
	end
	const part = slot.Part
	if part == nil then
		return nil
	end
	return CenterTable.Base({ Index = slot.Index, Box = part, Mount = nil, Free = true, Plate = false })
end

-- Bun / dog / toppings drawn on the plate (local copy, rebuilt only when the content changes)
function PlateController:BuildFood(slot: Slot)
	const record = Vide.untrack(slot.Record)
	const part = slot.Part
	local key = ""
	if record ~= false and part ~= nil then
		const content = `{if record.Bun then "b" else ""}{if record.Sausage then "s" else ""}:{table.concat(toppingList(record.Toppings), ",")}`
		if CONVEYOR and ticketUp(record) then
			key = `p{content}`
		elseif not CONVEYOR and (record.Bun or record.Sausage) then
			key = content
		end
	end
	if key == slot.FoodKey and (key == "" or (slot.Food ~= nil and slot.Food.Parent ~= nil)) then
		return
	end
	slot.FoodKey = key
	if slot.Food ~= nil then
		slot.Food:Destroy()
		slot.Food = nil
	end
	const folder = self.Folder
	if key == "" or record == false or part == nil or folder == nil then
		return
	end

	if not CONVEYOR then
		const food = self:ContentModel(record)
		if food == nil then
			return
		end
		food.Name = `Plate_{slot.Index}`
		sitOn(food, foodBase(part))
		food.Parent = folder
		slot.Food = food
		return
	end

	-- Conveyor: the plate itself, then what is on it
	const base = self:BaseOf(slot)
	if base == nil then
		return
	end
	const holder = Instance.new("Model")
	holder.Name = `Plate_{slot.Index}`
	const dish = self:KitModel(PLATE_KIT) or drawnDish()
	quiet(dish)
	const height = sitOn(dish, base)
	dish.Parent = holder
	const food = self:ContentModel(record)
	if food ~= nil then
		sitOn(food, base * CFrame.new(0, height, 0))
		food.Parent = holder
	end
	holder.Parent = folder
	slot.Food = holder
end

-- Ticket anchor of a slot: Att_Ticket under the box (conveyor: also under Mount_Plate_n), else the box with a lift
function PlateController:TicketAnchor(slot: Slot): Instance?
	const part = slot.Part
	if part == nil then
		return nil
	end
	const found = part:FindFirstChild(TICKET_ANCHOR, true)
	if found ~= nil then
		return found
	end
	const mount = slot.Mount
	return if CONVEYOR and mount ~= nil then mount:FindFirstChild(TICKET_ANCHOR, true) else nil
end

function PlateController:MountTicket(slot: Slot)
	-- one ticket per bound plate (Release unmounts it when the part goes); it shows and hides by itself
	if slot.Unmount ~= nil or self.Gui == nil or slot.Part == nil then
		return
	end
	const part = slot.Part :: BasePart
	const anchor = self:TicketAnchor(slot)
	const offset = if anchor then Vector3.zero else Vector3.new(0, TICKET_LIFT, 0)
	const unmount, gui = Vide.root(function()
		return PlateTicket({
			Name = `PlateTicket_{slot.Index}`,
			Adornee = anchor or part,
			StudsOffset = offset,
			MaxDistance = TICKET_DISTANCE,
			UrgentAt = RESTAURANT.Rules.UrgentAt,
			WarnAt = 0.5,
			Visible = function()
				return self:HasTicket(slot)
			end,
			Number = function(): number?
				return self:NumberOf(slot)
			end,
			Toppings = function(): { string }
				return self:ToppingsOf(slot)
			end,
			Done = function(): { [string]: boolean }
				const record = slot.Record()
				const done: { [string]: boolean } = {}
				if record ~= false then
					done.bun = record.Bun
					done.sausage = record.Sausage
					for key, on in record.Toppings do
						done[key] = on
					end
				end
				return done
			end,
			Patience = function(): number
				return self:PatienceOf(slot)
			end,
			Orphan = function(): boolean
				const record = slot.Record()
				return record ~= false and record.Orphan == true
			end,
			Oldest = function(): boolean
				return self:IsOldest(slot)
			end,
			Empty = function(): boolean
				return slot.Blank()
			end,
		})
	end)
	slot.Unmount = unmount
	slot.Gui = gui
	gui.Parent = self.Gui

	if not CONVEYOR then
		return
	end
	-- the grade of an assembled plate, just over the ticket
	const gradeUnmount, gradeGui = Vide.root(function()
		return TicketHud.Tag({
			Name = `PlateGrade_{slot.Index}`,
			Adornee = anchor or part,
			StudsOffset = offset,
			SizeOffset = GRADE_OFFSET,
			MaxDistance = TICKET_DISTANCE,
			Visible = function()
				return self:HasTicket(slot)
			end,
			Grade = function(): string?
				return gradeOf(slot.Record())
			end,
		})
	end)
	slot.GradeUnmount = gradeUnmount
	slot.GradeGui = gradeGui
	gradeGui.Parent = self.Gui
end

function PlateController:UnmountTicket(slot: Slot)
	if slot.Unmount ~= nil then
		slot.Unmount()
		slot.Unmount = nil
	end
	if slot.Gui ~= nil then
		slot.Gui:Destroy()
		slot.Gui = nil
	end
	if slot.GradeUnmount ~= nil then
		slot.GradeUnmount()
		slot.GradeUnmount = nil
	end
	if slot.GradeGui ~= nil then
		slot.GradeGui:Destroy()
		slot.GradeGui = nil
	end
end

-- Patience clock at 1 / TICK while any ticket is up; stops by itself
function PlateController:RunClock()
	if self.Clock ~= nil or not self:AnyTicket() then
		return
	end
	self.Clock = task.spawn(function()
		repeat
			self.Now(Workspace:GetServerTimeNow())
			task.wait(TICK)
		until not self:AnyTicket()
		self.Clock = nil
	end)
end

-- Plate part bound by tag + index attribute (PLATE-n / Click_Slot_n)
function PlateController:Bind(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	const value = instance:GetAttribute(SLOT_INDEX)
	const index = if typeof(value) == "number" and instance:IsDescendantOf(Workspace) then value else nil
	-- unbind wherever this part was before
	for _, slot in self.Slots do
		if slot.Part == instance and slot.Index ~= index then
			self:Release(slot)
		end
	end
	if index == nil then
		return
	end
	const slot = self:SlotOf(index)
	if slot.Part == instance then
		return
	end
	if slot.Part ~= nil then
		self:Release(slot)
	end
	slot.Part = instance
	slot.Saved = {}
	if CONVEYOR then
		slot.Mount = findMount(instance, index)
		-- the Take prompt names its slot, so the prompt rules know which plate it is (local attribute; a value the server
		-- writes wins)
		const take = instance:FindFirstChild(BINDING.CenterTake, true)
		if take ~= nil and take:GetAttribute("Slot") == nil then
			take:SetAttribute("Slot", index)
		end
	else
		for _, part in lookParts(instance) do
			slot.Saved[part] = part.Transparency
		end
	end
	self:Refresh(slot)
end

-- Restores the authored look and drops the food and the ticket of a plate whose part went away
function PlateController:Release(slot: Slot)
	for part, authored in slot.Saved do
		if part.Parent ~= nil then
			part.Transparency = authored
		end
	end
	slot.Saved = {}
	slot.Part = nil
	slot.Mount = nil
	slot.FoodKey = ""
	if slot.Food ~= nil then
		slot.Food:Destroy()
		slot.Food = nil
	end
	self:UnmountTicket(slot)
end

function PlateController:Track(instance: Instance)
	if self.Tracked[instance] ~= nil then
		return
	end
	local function bind()
		self:Bind(instance)
	end
	self.Tracked[instance] = {
		instance:GetAttributeChangedSignal(SLOT_INDEX):Connect(bind),
		instance.AncestryChanged:Connect(bind),
	}
	bind()
end

function PlateController:Untrack(instance: Instance)
	const connections = self.Tracked[instance]
	if connections == nil then
		return
	end
	self.Tracked[instance] = nil
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, slot in self.Slots do
		if slot.Part == instance then
			self:Release(slot)
		end
	end
end

-- Conveyor -----------------------------------------------------------------------------------------------------------

-- Bound central table slots now (CenterTable reads, not reactive)
function PlateController:Views(): { CenterTable.View }
	const views: { CenterTable.View } = {}
	for index, slot in self.Slots do
		const part = slot.Part
		if part ~= nil and part.Parent ~= nil then
			const record = Vide.untrack(slot.Record)
			table.insert(views, {
				Index = index,
				Box = part,
				Mount = mountCFrame(slot.Mount),
				Free = not ticketUp(record),
				Plate = ticketUp(record),
			})
		end
	end
	return views
end

-- The ticket the HUD shows: the equipped plate (with a ticket or an orphan), else the plate of the own belt seat
function PlateController:Current(): Current?
	const hand = self.Hand
	const held = if hand then hand.Held() else false
	if held ~= false and (held.Ticket ~= 0 or held.Orphan) then
		return {
			Ticket = held.Ticket,
			Line = held.Line,
			Orphan = held.Orphan,
			Bun = held.Bun,
			Dog = held.Dog,
			Toppings = held.Toppings,
			Grade = held.Quality,
			Flip = held.FlipBonus,
			InHand = true,
		}
	end
	const seat = self.Seat()
	if seat == false then
		return nil
	end
	const mask = PlateMask.Unpack(seat.Plate)
	const toppings: { [string]: boolean } = {}
	for _, key in mask.Toppings do
		toppings[key] = true
	end
	return {
		Ticket = seat.Ticket,
		Line = seat.Line,
		Orphan = false,
		Bun = mask.Cut,
		Dog = mask.Sausage,
		Toppings = toppings,
		Grade = nil,
		Flip = false,
		InHand = false,
	}
end

-- Reactive: topping keys of the order of a ticket line (Customers, else the last seen); nil = order not known
function PlateController:OrderOf(ticket: number, line: number): { string }?
	if ticket == 0 then
		return nil
	end
	const customer = self.Customers()[ticket]
	if customer ~= nil then
		const order = if line == 2 then customer.Order2 else customer.Order
		return if order ~= nil then toppingList(order) else nil
	end
	const memo = self.Tickets[ticket]
	if memo == nil then
		return nil
	end
	return if line == 2 then memo.Order2 else memo.Order
end

function PlateController:HudCard(): TicketHud.CardProps
	return {
		Shown = function()
			return self:Current() ~= nil
		end,
		Number = function(): number?
			const current = self:Current()
			return if current and current.Ticket ~= 0 then self:TicketNumber(current.Ticket) else nil
		end,
		Drive = function()
			const current = self:Current()
			if current == nil or current.Ticket == 0 then
				return false
			end
			const customer = self.Customers()[current.Ticket]
			if customer ~= nil then
				return customer.Drive ~= nil
			end
			const memo = self.Tickets[current.Ticket]
			return memo ~= nil and memo.Drive
		end,
		Cells = function(): { TicketHud.Cell }
			const current = self:Current()
			if current == nil then
				return {}
			end
			const assembled = current.Grade ~= nil
			const cells: { TicketHud.Cell } = {
				{ Key = "bun", Done = current.Bun },
				{ Key = "sausage", Done = current.Dog },
			}
			for _, key in self:OrderOf(current.Ticket, current.Line) or {} do
				table.insert(cells, { Key = key, Done = assembled or current.Toppings[key] == true })
			end
			return cells
		end,
		NoToppings = function()
			const current = self:Current()
			const order = if current then self:OrderOf(current.Ticket, current.Line) else nil
			return order ~= nil and #order == 0
		end,
		Grade = function(): string?
			const current = self:Current()
			return if current then current.Grade else nil
		end,
		Flip = function()
			const current = self:Current()
			return current ~= nil and current.Flip
		end,
		Orphan = function()
			const current = self:Current()
			return current ~= nil and current.Orphan
		end,
		More = function()
			const hand = self.Hand
			const current = self:Current()
			if hand == nil or current == nil then
				return 0
			end
			return math.max(hand.Hands() - (if current.InHand then 1 else 0), 0)
		end,
		Position = function()
			return self.HudPosition()
		end,
	}
end

-- The HUD card sits where the order card (Hud > Order > HudOrder) is, under it while that one shows
function PlateController:PlaceHud()
	const screen = self.HudGui
	if screen == nil then
		return
	end
	const camera = Workspace.CurrentCamera
	if camera ~= nil then
		const scale = Theme.ScaleOf(camera.ViewportSize)
		if math.abs(scale - Vide.untrack(self.Scale)) > 0.01 then
			self.Scale(scale)
		end
	end
	const layer = screen:FindFirstChild("Layer")
	const hud = screen.Parent and screen.Parent:FindFirstChild("Hud")
	const orderLayer = if hud then hud:FindFirstChild("Order") else nil
	const card = if orderLayer then orderLayer:FindFirstChild("HudOrder") else nil
	local position = HUD_FALLBACK
	if layer ~= nil and layer:IsA("GuiObject") and card ~= nil and card:IsA("GuiObject") and hud ~= nil and hud:IsA("ScreenGui") then
		const scale = Vide.untrack(self.Scale)
		const x = (card.AbsolutePosition.X - layer.AbsolutePosition.X) / scale
		local y = (card.AbsolutePosition.Y - layer.AbsolutePosition.Y) / scale
		if card.Visible and hud.Enabled then
			y += card.AbsoluteSize.Y / scale + HUD_GAP
		end
		position = UDim2.fromOffset(math.floor(x), math.floor(y))
	end
	if Vide.untrack(self.HudPosition) ~= position then
		self.HudPosition(position)
	end
end

-- The equipped plate the put / pickup rules read (not reactive)
function PlateController:EquippedPlate(): TicketHud.HeldPlate?
	const hand = self.Hand
	if hand == nil then
		return nil
	end
	const held = Vide.untrack(hand.Held)
	return if held == false then nil else held
end

-- Ticket customer waiting in the pickup line; nil = not known (no record): the server decides
function PlateController:AtPickup(ticket: number): boolean?
	const customer = Vide.untrack(self.Customers)[ticket]
	if customer == nil then
		return nil
	end
	return customer.State == "Waiting" and customer.Pickup ~= nil
end

function PlateController:StartConveyor(gui: Instance)
	const input = self.Dependencies.InputController
	const hand = TicketHud.Track(Players.LocalPlayer)
	self.Hand = hand

	local center: CenterTable.State
	center = CenterTable.new({
		Views = function()
			return self:Views()
		end,
		Equipped = function(): { Number: number? }?
			const held = self:EquippedPlate()
			if held == nil or (held.PlateId == 0 and held.Ticket == 0) then
				return nil
			end
			return { Number = if held.Ticket ~= 0 then Vide.untrack(function(): number?
				return self:TicketNumber(held.Ticket)
			end) else nil }
		end,
		Device = function(): string
			return input.Device()
		end,
		Gameplay = function()
			return input.Context == "Gameplay"
		end,
		Root = function(): BasePart?
			const character = Players.LocalPlayer.Character
			const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			return if root ~= nil and root:IsA("BasePart") then root else nil
		end,
		SetBound = function(on: boolean)
			if not on then
				input:Unbind(PUT_BIND)
				return
			end
			input
				:Bind({
					Name = PUT_BIND,
					Key = Enum.UserInputType.MouseButton1,
					Keys = { Enum.KeyCode.ButtonY },
					Priority = PUT_PRIORITY,
					Context = "Gameplay",
				})
				.OnPress(function()
					CenterTable.Press(center)
				end)
		end,
		Send = function(slot: number)
			Restaurant.CenterPut:fireServer({ Slot = slot })
		end,
	})
	self.Center = center

	-- a tap on a slot in the world (taps on GUI never reach here)
	UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processed: boolean)
		if not processed then
			CenterTable.Tap(center, position)
		end
	end)

	-- the HUD layer: ticket card + put hint / "Set down" button
	const _, screen = Vide.root(function()
		const root = TicketHud.Screen({
			Card = self:HudCard(),
			Scale = function()
				return self.Scale()
			end,
		})
		const layer = root:FindFirstChild("Layer")
		if layer ~= nil then
			CenterTable.Ui(center).Parent = layer
		end
		return root
	end)
	self.HudGui = screen
	screen.Parent = gui

	-- "#n" over the plate a crewmate holds
	const tags = Instance.new("Folder")
	tags.Name = "PlateHandTags"
	tags.Parent = gui
	TicketHud.TagHands(tags, function(npc: number): number?
		return self:TicketNumber(npc)
	end)
end

function PlateController:Watch(gui: Instance)
	const folder = Instance.new("Folder")
	folder.Name = FOOD_FOLDER
	folder.Parent = Workspace
	self.Folder = folder
	const holder = Instance.new("Folder")
	holder.Name = "PlateTickets"
	holder.Parent = gui
	self.Gui = holder

	if CONVEYOR then
		self:StartConveyor(gui)
	end

	CollectionService:GetInstanceAddedSignal(SLOT_TAG):Connect(function(instance)
		self:Track(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(SLOT_TAG):Connect(function(instance)
		self:Untrack(instance)
	end)
	for _, instance in CollectionService:GetTagged(SLOT_TAG) do
		self:Track(instance)
	end
	for _, slot in self.Slots do
		self:Refresh(slot)
	end
end

PlateController:OnInit(function(self)
	self:Setup()
	if not self:Enabled() then
		return -- trailer flow: inert
	end

	const plates = Restaurant.Plates
	plates:onAdded(function(index, record)
		self:WriteRecord(index, record)
	end)
	plates:onChanged(function(index, record)
		self:WriteRecord(index, record)
	end)
	plates:onRemoved(function(index)
		self:WriteRecord(index, nil)
	end)

	const customers = self.Libs.Net.Customers
	customers:onAdded(function(id, record)
		self:WriteCustomer(id, record)
	end)
	customers:onChanged(function(id, record)
		self:WriteCustomer(id, record)
	end)
	customers:onRemoved(function(id)
		self:WriteCustomer(id, nil)
	end)

	if CONVEYOR then
		const seats = self.Libs.Net.PrepSeats
		seats:onAdded(function(id, record)
			self:WriteSeat(id, record)
		end)
		seats:onChanged(function(id, record)
			self:WriteSeat(id, record)
		end)
		seats:onRemoved(function(id)
			self:WriteSeat(id, nil)
		end)
	end

	Rules.SetPlateProbe({
		Plate = function(index: number): Rules.PlateRecord?
			const slot = self.Slots[index]
			if slot == nil then
				return nil
			end
			const record = Vide.untrack(slot.Record)
			if record == false then
				return nil
			end
			const known: Record = record
			return {
				Npc = known.Npc,
				Bun = known.Bun,
				Sausage = known.Sausage,
				Orphan = known.Orphan,
				Grade = gradeOf(known),
			}
		end,
		Conveyor = CONVEYOR,
		Hands = function(): number
			const hand = self.Hand
			return if hand then Vide.untrack(hand.Hands) else 0
		end,
		NearestTake = function(): number?
			const center = self.Center
			return if center then CenterTable.NearestTake(center) else nil
		end,
		Equipped = function(): Rules.HeldPlate?
			const held = self:EquippedPlate()
			if held == nil then
				return nil
			end
			return {
				Item = held.Item,
				Ticket = held.Ticket,
				Orphan = held.Orphan,
				AtPickup = if held.Ticket ~= 0 then self:AtPickup(held.Ticket) else nil,
			}
		end,
	})
end)

PlateController:OnStart(function(self)
	if not self:Enabled() then
		return
	end
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

-- Conveyor: the central table pick, the nearest plate for the prompts and the HUD place (10 Hz, after Watch)
PlateController:OnTick(function(self)
	const center = self.Center
	if center == nil then
		return
	end
	CenterTable.Step(center)
	self:PlaceHud()
end, STEP_RATE)

return PlateController
