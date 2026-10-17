--!strict
--[[
	PlateController (TASK-383, R1-F; design FEAT-044, DEC-271; tech/restaurant-flow.md rev. 2 §2.2 / §3.3)

	Presents the plate slots of the assembly table; decides nothing (PlateService assigns tickets, fills and empties the
	plates, the Tool `hot_dog` carries the plate in the hand).

	  - Plates set (Net.Restaurant, record id = plate index 1..Rules.PlateSlotsMax) -> one Vide source per plate.
	  - The plate Part is found by tag Binding.PlateTag + attribute Binding.PlateIndex (PLATE-n of the map); a late tag or
	    attribute still binds.
	  - Look (local only): with no bun and no dog the plate is a ghost (every visible part of PLATE-n at least
	    GHOST_TRANSPARENCY, the authored value saved and restored); with bun or dog it is solid. The content is drawn on
	    the plate from the kit Tools (ReplicatedStorage.Assets.Items.Tools): bun_sliced, sausage_grilled, or hot_dog with
	    the toppings stacked by HotDogVisual (drawn parts when the kit is missing). Optional Attachment `Att_Food` on
	    PLATE-n = where the food sits, else the top of the part.
	  - Ticket (Interface/Components/PlateTicket, BillboardGui, MaxDistance 40) on Binding.PlateTicket (Att_Ticket) while
	    the plate has a ticket (Npc > 0) or is an orphan: #n (Customers.Number), the order of its line (Line 2 = Order2),
	    faded icons for what is still missing, the patience ring of the customer (Customers PatienceEndsAt / PatienceSpan),
	    "!" under Rules.UrgentAt, the oldest open ticket pulsing (2+ open). The last order seen for a plate is kept, so an
	    orphan still shows what it was.
	  - Prompts: plugs the Plates probe into PromptController/Rules (plate_put / plate_take by hand and by plate).

	Content.Restaurant.Rules.Enabled = false: inert (no listener, no tag watch, no probe); the published game is unchanged.
	Listeners in OnInit (before Lync.start); tags are scanned in OnStart.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local HotDogVisual = require(ReplicatedStorage.shared.Item.HotDogVisual)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local PlateTicket = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PlateTicket)
local Rules = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Rules)

const RESTAURANT = Content.Restaurant
const BINDING = RESTAURANT.Binding
const MAX_TOPPINGS = Content.OrderRules.MaxToppings
const GHOST_TRANSPARENCY = 0.5 -- tech §3.3: empty plate translucent
const TICKET_DISTANCE = 40
const TICKET_LIFT = 1.6 -- studs over the plate when the map has no Att_Ticket
const FOOD_ANCHOR = "Att_Food" -- optional Attachment on PLATE-n
const TICK = 0.1 -- s, patience ring clock (only while a ticket is shown)
const BLANK = "blank" -- ANM-001 rig Variant: the ticket has no icon
const FOOD_FOLDER = "PlateFood"
const BUN_COLOR = Color3.fromHex("#E8B36B")
const DOG_COLOR = Color3.fromHex("#C8553D")

export type Record = {
	Npc: number,
	Line: number,
	Bun: boolean,
	Sausage: boolean,
	Toppings: { [string]: boolean },
	Since: number,
	Orphan: boolean?,
	Altered: boolean?,
}

-- What the ticket reads from the Customers set
type Customer = {
	State: string,
	Number: number?,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
	PatienceEndsAt: number,
	PatienceSpan: number,
	Phase: string,
}

-- Last order seen on a plate (an orphan keeps showing it)
type Memo = { Npc: number, Line: number, Number: number?, Toppings: { string } }

type Slot = {
	Index: number,
	Record: Vide.Source<Record | false>,
	Blank: Vide.Source<boolean>,
	Part: BasePart?,
	Saved: { [BasePart]: number }, -- authored Transparency of the visible parts of PLATE-n
	Food: Model?,
	FoodKey: string,
	Memo: Memo?,
	Unmount: (() -> ())?,
	Gui: Instance?,
}

const PlateController = Modux.Controller("PlateController", { Require = {}, Priority = 660 })

function PlateController:Setup()
	self.Slots = {} :: { [number]: Slot }
	-- plate Part -> its watcher connections
	self.Tracked = {} :: { [Instance]: { RBXScriptConnection } }
	-- NpcId -> Customers record (copy); one source for the whole map (<= 12 customers, few writes)
	self.Customers = Vide.source({}) :: Vide.Source<{ [number]: Customer }>
	self.Now = Vide.source(Workspace:GetServerTimeNow()) :: Vide.Source<number>
	self.Gui = nil :: Instance?
	self.Folder = nil :: Folder?
	self.Clock = nil :: thread?
	self.Warned = false :: boolean
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
		Saved = {},
		Food = nil,
		FoodKey = "",
		Memo = nil,
		Unmount = nil,
		Gui = nil,
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
		}
	end
	self.Customers(map)
	for _, slot in self.Slots do
		self:Remember(slot)
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

local function ticketUp(record: Record | false): boolean
	return record ~= false and (record.Npc ~= 0 or record.Orphan == true)
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

-- Ghost (no bun, no dog) = translucent; else the authored look
function PlateController:ApplyLook(slot: Slot)
	const record = Vide.untrack(slot.Record)
	const ghost = record == false or not (record.Bun or record.Sausage)
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

-- World CFrame the food sits on: Att_Food, else the top of the plate part (its yaw kept)
local function foodBase(part: BasePart): CFrame
	const anchor = part:FindFirstChild(FOOD_ANCHOR)
	if anchor ~= nil and anchor:IsA("Attachment") then
		return anchor.WorldCFrame
	end
	const cf = part.CFrame
	-- world height of the part's box
	const size = part.Size
	const height = math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z
	const _, yaw = cf:ToOrientation()
	return CFrame.new(cf.Position + Vector3.new(0, height / 2, 0)) * CFrame.fromOrientation(0, yaw, 0)
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

-- Bun / dog / toppings drawn on the plate (local copy, rebuilt only when the content changes)
function PlateController:BuildFood(slot: Slot)
	const record = Vide.untrack(slot.Record)
	const part = slot.Part
	local key = ""
	if record ~= false and part ~= nil and (record.Bun or record.Sausage) then
		key = `{if record.Bun then "b" else ""}{if record.Sausage then "s" else ""}:{table.concat(toppingList(record.Toppings), ",")}`
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
	food.Name = `Plate_{slot.Index}`
	const primary = food.PrimaryPart
	if primary ~= nil then
		const _, extents = food:GetBoundingBox()
		food:PivotTo(foodBase(part) * CFrame.new(0, extents.Y / 2, 0))
	end
	food.Parent = folder
	slot.Food = food
end

function PlateController:MountTicket(slot: Slot)
	-- one ticket per bound plate (Release unmounts it when the part goes); it shows and hides by itself
	if slot.Unmount ~= nil or self.Gui == nil or slot.Part == nil then
		return
	end
	const part = slot.Part :: BasePart
	const anchor = part:FindFirstChild(BINDING.PlateTicket)
	const unmount, gui = Vide.root(function()
		return PlateTicket({
			Name = `PlateTicket_{slot.Index}`,
			Adornee = anchor or part,
			StudsOffset = if anchor then Vector3.zero else Vector3.new(0, TICKET_LIFT, 0),
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

-- Plate part bound by tag + PlateIndex
function PlateController:Bind(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	const value = instance:GetAttribute(BINDING.PlateIndex)
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
	for _, part in lookParts(instance) do
		slot.Saved[part] = part.Transparency
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
		instance:GetAttributeChangedSignal(BINDING.PlateIndex):Connect(bind),
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

function PlateController:Watch(gui: Instance)
	const folder = Instance.new("Folder")
	folder.Name = FOOD_FOLDER
	folder.Parent = Workspace
	self.Folder = folder
	const holder = Instance.new("Folder")
	holder.Name = "PlateTickets"
	holder.Parent = gui
	self.Gui = holder

	CollectionService:GetInstanceAddedSignal(BINDING.PlateTag):Connect(function(instance)
		self:Track(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(BINDING.PlateTag):Connect(function(instance)
		self:Untrack(instance)
	end)
	for _, instance in CollectionService:GetTagged(BINDING.PlateTag) do
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
			return { Npc = known.Npc, Bun = known.Bun, Sausage = known.Sausage }
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

return PlateController
