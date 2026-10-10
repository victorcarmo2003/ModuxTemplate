--!strict
--[[
	CustomerController (TASK-034; FEAT-010, FEAT-011; DEC-071, DEC-152, DEC-162, DEC-187; network.md §3.6, §4.3, §5.3)

	Presents the customers from the server; decides nothing (CustomerService validates, pays and moves the mood).

	  - Customers set (record id = NpcId) -> one Vide source per customer.
	  - The rig is found by the `NpcId` attribute of the `AnimalRig`-tagged models (a pooled rig gets a new id on
	    every spawn, so the attribute is watched, not read once).
	  - Order bubble (Interface/Components/OrderBubble) over the head, seen by the whole party (DEC-071), only while
	    the customer is `Waiting` (that is, after "Take Order": Order is empty before it, FEAT-011). Base icon + the
	    ordered toppings (ToppingKeys order, max 3). At most MAX_BUBBLES on screen.
	  - Patience ring only with PatienceEndsAt > 0 (T41: 0 until "Take Order", K stays hidden). The span of the
	    ring is max(PatienceBase + PatiencePerK x K, time left when first seen): the Counter bonus is not on the wire
	    for this controller, so the ring starts full at "Take Order" and drains to 0 at PatienceEndsAt. Provisional.
	  - Face: Moods[Mood].Expression through RigController:SetExpression (local only; the low-band Normal_Night of
	    RigController still wins). The face follows the server's Mood in every state; the client never derives a
	    mood from the patience (Annoyed is written by the server, network.md §3.6). Cleared when the record goes.
	  - Sale packet -> ReactionBubble over the rig for REACTION_TIME s (Reactions.luau); the order bubble of that
	    customer hides meanwhile. The "+$N" on the drawer is EconomyController's.
	  - Sound and one-shot animation (TASK-079; sound-list §5.4; architecture.md §19.20): "Take Order" (record goes
	    to Waiting) plays SFX-041 `order_take` on the rig; a Sale plays SFX-042 `serve` (when something was handed
	    over) and the reaction sound + clip of Reactions.Feedback through AudioController / AnimController. The coin
	    (SFX-043/044) is EconomyController's, on the drawer. Keys still missing from Content.Sounds are skipped
	    quietly (the row comes with the Content owner); clips with an empty id do not play (AnimController).

	Wave 3 (TASK-110; anomalies.md N1/N4/N5, architecture.md §19.3): the rig attribute `Variant` (NpcService,
	TASK-108: blank / mirror / raincoat; nil = ordinary customer) is read per customer into a Vide source
	(`self:VariantOf(id)`, reactive), re-read when the attribute changes (a pooled rig loses it). Applied locally:
	  - the face is RigController's (it reads the same attribute; the variant face beats the mood);
	  - blank: the order bubble shows no topping icon (the order is still on the wire, the server judges it). The
	    bubble's base icon stays until OrderBubble has an "empty" prop (Interface owner; ANM-001 `Coin_Blank` and the
	    missing breath are the TASK-112 effect's).
	Nothing here decides an anomaly: the verb, the payment and the result stay on the server.

	Listeners in OnInit (before Lync.start, README "Rede"); the late joiner gets the current records through onAdded.
	Rigs are scanned in OnStart. No input: nothing here is clickable (FEAT-032).
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local OrderBubble = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.OrderBubble)
local ReactionBubble = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ReactionBubble)
local Reactions = require(script.Reactions)

const MAX_BUBBLES = 8 -- TASK-034 acceptance; <= 8 customers by day (network.md §3.6)
const REACTION_TIME = 3 -- s
const TICK_RATE = 10 -- Hz, patience ring clock (only while a bubble is mounted)
const HEAD_GAP = 0.6 -- studs between the top of the head and the tip of the bubble
const MAX_DISTANCE = 60
const ORDER_RULES = Content.OrderRules
const WARN_AT = Content.Moods.Rules.AnnoyedAt
const VARIANT_ATTRIBUTE = "Variant" -- rig attribute (NpcService, TASK-108)
const BLANK = "blank" -- ANM-001: no icons in the bubble

export type Record = {
	State: string,
	Slot: number,
	Order: { [string]: boolean },
	PatienceEndsAt: number,
	Mood: string,
}

type Entry = {
	Id: number,
	Record: Vide.Source<Record | false>,
	Reacting: Vide.Source<boolean>,
	EndsAt: number, -- last PatienceEndsAt seen (> 0)
	Total: number, -- span of the patience ring (s); 0 = unknown
	Model: Model?, -- rig the bubble and the face are on
	Unmount: (() -> ())?,
	Gui: Instance?,
	Face: string?,
	Variant: Vide.Source<string | false>, -- rig attribute Variant (TASK-110); false = ordinary customer
}

type Reaction = {
	Id: number,
	Unmount: () -> (),
	Gui: Instance,
	Timer: thread,
}

type Tracked = {
	Id: number?,
	Connections: { RBXScriptConnection },
}

const CustomerController = Modux.Controller(
	"CustomerController",
	{ Require = { "RigController", "AudioController", "AnimController" }, Priority = 670 }
)

function CustomerController:Setup()
	self.Entries = {} :: { [number]: Entry }
	-- NpcId -> rig
	self.Models = {} :: { [number]: Model }
	self.Tracked = {} :: { [Model]: Tracked }
	self.Reactions = {} :: { [Model]: Reaction }
	self.Mounted = 0 :: number
	self.Now = Vide.source(workspace:GetServerTimeNow()) :: Vide.Source<number>
	self.Gui = nil :: Instance?
	self.Random = Random.new() :: Random
end

-- Reactive read of a customer record (nil = no such customer). For other controllers and debugging.
function CustomerController:RecordOf(id: number): Record?
	const entry = self.Entries[id]
	return if entry then entry.Record() or nil else nil
end

-- Reactive customer-anomaly variant (nil = ordinary, or no such customer / rig yet). TASK-110.
function CustomerController:VariantOf(id: number): string?
	const entry = self.Entries[id]
	const value = if entry then entry.Variant() else false
	return if typeof(value) == "string" then value else nil
end

-- Topping keys of an order, in display order (ToppingKeys order), max 3 (DEC-071).
function CustomerController:ToppingsOf(record: Record): { OrderBubble.Topping }
	const list: { OrderBubble.Topping } = {}
	for _, key in Content.Ingredients.ToppingKeys do
		if record.Order[key] then
			table.insert(list, { Key = key, Icon = Content.Ingredients.ByKey[key].Icon })
			if #list >= ORDER_RULES.MaxToppings then
				break
			end
		end
	end
	return list
end

-- Patience left (0..1) for the ring; -1 = no ring.
function CustomerController:PatienceOf(entry: Entry): number
	const record = entry.Record()
	if record == false or record.PatienceEndsAt <= 0 or entry.Total <= 0 then
		return -1
	end
	return math.clamp((record.PatienceEndsAt - self.Now()) / entry.Total, 0, 1)
end

function CustomerController:NewEntry(id: number): Entry
	const entry: Entry = {
		Id = id,
		Record = Vide.source(false :: Record | false) :: Vide.Source<Record | false>,
		Reacting = Vide.source(false) :: Vide.Source<boolean>,
		EndsAt = 0,
		Total = 0,
		Model = nil,
		Unmount = nil,
		Gui = nil,
		Face = nil,
		Variant = Vide.source(false :: string | false) :: Vide.Source<string | false>,
	}
	self.Entries[id] = entry
	return entry
end

-- Copies: the set may reuse its record table between frames, and Vide needs a new value to notice a change.
function CustomerController:WriteRecord(id: number, record: Record?)
	if record == nil then
		self:Drop(id)
		return
	end
	const entry = self.Entries[id] or self:NewEntry(id)
	const copy: Record = {
		State = record.State,
		Slot = record.Slot,
		Order = table.clone(record.Order),
		PatienceEndsAt = record.PatienceEndsAt,
		Mood = record.Mood,
	}
	const old = Vide.untrack(entry.Record)
	if old ~= false and old.State ~= "Waiting" and copy.State == "Waiting" then
		self:Cue(id, "order_take")
	end
	const now = workspace:GetServerTimeNow()
	if copy.PatienceEndsAt <= 0 then
		entry.EndsAt = 0
		entry.Total = 0
	elseif copy.PatienceEndsAt ~= entry.EndsAt then
		entry.EndsAt = copy.PatienceEndsAt
		const k = #self:ToppingsOf(copy)
		const formula = ORDER_RULES.PatienceBase + ORDER_RULES.PatiencePerK * k
		entry.Total = math.max(formula, copy.PatienceEndsAt - now)
	end
	self.Now(now)
	const source: Vide.Source<Record | false> = entry.Record
	source(copy)
	self:Sync(id)
end

-- The customer left the set: bubble and face go with it.
function CustomerController:Drop(id: number)
	const entry = self.Entries[id]
	if entry == nil then
		return
	end
	self.Entries[id] = nil
	self:Detach(entry)
	self:Fill()
end

-- Unmount the bubble and give the rig its neutral face back.
function CustomerController:Detach(entry: Entry)
	self:Unmount(entry)
	const model = entry.Model
	if model ~= nil and entry.Face ~= nil then
		self.Dependencies.RigController:SetExpression(model, nil)
	end
	entry.Model = nil
	entry.Face = nil
	entry.Variant(false)
end

function CustomerController:Unmount(entry: Entry)
	const unmount = entry.Unmount
	if unmount then
		entry.Unmount = nil
		self.Mounted -= 1
		unmount()
	end
	const gui = entry.Gui
	if gui then
		entry.Gui = nil
		gui:Destroy()
	end
end

-- Mount bubbles that were skipped by the MAX_BUBBLES cap or by a missing gui.
function CustomerController:Fill()
	for id, entry in self.Entries do
		if entry.Unmount == nil and self.Models[id] ~= nil then
			self:Sync(id)
		end
	end
end

local function headOf(model: Model): BasePart?
	const head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	return model.PrimaryPart
end

-- Bring one customer's bubble and face in line with its record and rig.
function CustomerController:Sync(id: number)
	const entry = self.Entries[id]
	if entry == nil then
		return
	end
	const model = self.Models[id]
	if entry.Model ~= nil and entry.Model ~= model then
		self:Detach(entry)
	end
	const record = Vide.untrack(entry.Record)
	if model == nil or record == false then
		return
	end
	entry.Model = model

	const value = model:GetAttribute(VARIANT_ATTRIBUTE)
	const variant: string | false = if typeof(value) == "string" and value ~= "" then value else false
	if Vide.untrack(entry.Variant) ~= variant then
		entry.Variant(variant)
	end

	const mood = Content.Moods.ByKey[record.Mood]
	const face = if mood then mood.Expression else nil
	if face ~= entry.Face then
		entry.Face = face
		self.Dependencies.RigController:SetExpression(model, face)
	end

	if entry.Unmount == nil then
		self:Mount(entry, model)
	end
end

function CustomerController:Mount(entry: Entry, model: Model)
	const gui = self.Gui
	const head = headOf(model)
	if gui == nil or head == nil or self.Mounted >= MAX_BUBBLES then
		return
	end
	const unmount, billboard = Vide.root(function()
		return OrderBubble({
			Name = `OrderBubble_{entry.Id}`,
			Adornee = head,
			Empty = function()
				return entry.Variant() == BLANK
			end,
			Visible = function()
				const record = entry.Record()
				return record ~= false and record.State == "Waiting" and not entry.Reacting()
			end,
			Toppings = function()
				const record = entry.Record()
				if record == false or entry.Variant() == BLANK then
					return {}
				end
				return self:ToppingsOf(record)
			end,
			Patience = function()
				return self:PatienceOf(entry)
			end,
			WarnAt = WARN_AT,
			Offset = Vector3.new(0, head.Size.Y / 2 + HEAD_GAP, 0),
			MaxDistance = MAX_DISTANCE,
		})
	end)
	billboard.Parent = gui
	entry.Unmount = unmount
	entry.Gui = billboard
	self.Mounted += 1
end

-- Sale packet: reaction bubble over the rig (presentation only; the drawer comes from the Economy set).
function CustomerController:React(id: number, result: string)
	const model = self.Models[id]
	const gui = self.Gui
	if model == nil or gui == nil then
		return
	end
	const head = headOf(model)
	if head == nil then
		return
	end
	self:ClearReaction(model)

	const kind, line = Reactions.For(result, self.Random)
	const unmount, billboard = Vide.root(function()
		return ReactionBubble({
			Name = `ReactionBubble_{id}`,
			Adornee = head,
			Kind = function()
				return kind
			end,
			Text = function()
				return line
			end,
			Offset = Vector3.new(0, head.Size.Y / 2 + HEAD_GAP, 0),
			MaxDistance = MAX_DISTANCE,
		})
	end)
	billboard.Parent = gui

	const entry = self.Entries[id]
	if entry then
		entry.Reacting(true)
	end
	self.Reactions[model] = {
		Id = id,
		Unmount = unmount,
		Gui = billboard,
		Timer = task.delay(REACTION_TIME, function()
			self:ClearReaction(model)
		end),
	}
end

function CustomerController:ClearReaction(model: Model)
	const reaction = self.Reactions[model]
	if reaction == nil then
		return
	end
	self.Reactions[model] = nil
	if coroutine.running() ~= reaction.Timer and coroutine.status(reaction.Timer) == "suspended" then
		task.cancel(reaction.Timer)
	end
	reaction.Unmount()
	reaction.Gui:Destroy()
	const entry = self.Entries[reaction.Id]
	if entry then
		entry.Reacting(false)
	end
end

-- One-shot sound on the customer's head (nothing without a rig). Missing key = silent (row not in Content yet).
function CustomerController:Cue(id: number, key: string)
	const model = self.Models[id]
	if model == nil or Content.Sounds.ByKey[key] == nil then
		return
	end
	self.Dependencies.AudioController:Play(key, headOf(model) or model)
end

-- Sale packet: serve + reaction sound on the rig, reaction clip (npc_happy / npc_complain / npc_refuse_leave).
function CustomerController:Feedback(id: number, result: string)
	const feedback = Reactions.Feedback(result)
	if feedback.Served then
		self:Cue(id, "serve")
	end
	if feedback.Sound ~= "" then
		self:Cue(id, feedback.Sound)
	end
	const model = self.Models[id]
	if model ~= nil and feedback.Clip ~= "" then
		self.Dependencies.AnimController:Play(model, feedback.Clip)
	end
end

-- Rig tracking: NpcId attribute -> model, re-read on change (pool reuse = new id).
function CustomerController:Bind(model: Model)
	const tracked = self.Tracked[model]
	if tracked == nil then
		return
	end
	const value = model:GetAttribute("NpcId")
	const id = if typeof(value) == "number" and model:IsDescendantOf(workspace) then value else nil
	const old = tracked.Id
	if old == id then
		return
	end
	tracked.Id = id
	if old ~= nil then
		self:ClearReaction(model)
		if self.Models[old] == model then
			self.Models[old] = nil
			self:Sync(old)
		end
	end
	if id ~= nil then
		self.Models[id] = model
		self:Sync(id)
	end
end

function CustomerController:Track(instance: Instance)
	if not instance:IsA("Model") or self.Tracked[instance] ~= nil then
		return
	end
	const model = instance
	const tracked: Tracked = { Id = nil, Connections = {} }
	self.Tracked[model] = tracked
	local function bind()
		self:Bind(model)
	end
	table.insert(tracked.Connections, model:GetAttributeChangedSignal("NpcId"):Connect(bind))
	table.insert(
		tracked.Connections,
		model:GetAttributeChangedSignal(VARIANT_ATTRIBUTE):Connect(function()
			const id = tracked.Id
			if id ~= nil and self.Models[id] == model then
				self:Sync(id)
			end
		end)
	)
	table.insert(tracked.Connections, model.AncestryChanged:Connect(bind))
	table.insert(
		tracked.Connections,
		model.Destroying:Connect(function()
			self:Untrack(model)
		end)
	)
	bind()
end

function CustomerController:Untrack(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	const tracked = self.Tracked[instance]
	if tracked == nil then
		return
	end
	self.Tracked[instance] = nil
	for _, connection in tracked.Connections do
		connection:Disconnect()
	end
	self:ClearReaction(instance)
	const id = tracked.Id
	if id ~= nil and self.Models[id] == instance then
		self.Models[id] = nil
		self:Sync(id)
		self:Fill()
	end
end

function CustomerController:Watch(gui: Instance)
	self.Gui = gui
	CollectionService:GetInstanceAddedSignal(CrewRig.Tag):Connect(function(instance)
		self:Track(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(CrewRig.Tag):Connect(function(instance)
		self:Untrack(instance)
	end)
	for _, instance in CollectionService:GetTagged(CrewRig.Tag) do
		self:Track(instance)
	end
	self:Fill()
end

CustomerController:OnInit(function(self)
	self:Setup()

	const net = self.Libs.Net
	net.Customers:onAdded(function(id, record)
		self:WriteRecord(id, record)
	end)
	net.Customers:onChanged(function(id, record)
		self:WriteRecord(id, record)
	end)
	net.Customers:onRemoved(function(id)
		self:WriteRecord(id, nil)
	end)

	net.Sale:onClient(function(sale)
		self:React(sale.Npc, sale.Result)
		self:Feedback(sale.Npc, sale.Result)
	end)
end)

CustomerController:OnStart(function(self)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

CustomerController:OnTick(function(self)
	if self.Mounted > 0 then
		self.Now(workspace:GetServerTimeNow())
	end
end, TICK_RATE)

return CustomerController
