--!strict
--[[
	SeatingController (TASK-147; FEAT-037; UPG-008; network.md §14; architecture.md §19.28)

	Presents the tables from the server; decides nothing (SeatingService buys, seats, cleans and pays).

	  - Tables set (record id = table index 1..Content.Seating.Tables) -> one Vide source per table.
	  - The table Model is found by the tag Seating.Binding.Tag + attribute TableIndex (bound place, TASK-149, or
	    written at runtime by the server fallback); the attribute is watched, so a late tag/attribute still binds.
	  - Look (Look.luau, local only): Locked = hidden (nothing before the Day 2); Ghost = Seating.GhostTransparency, no
	    shadow (the server writes CanCollide off, which replicates); Free / Occupied / Dirty = authored look.
	  - Price plate (Interface/Components/TableSign, studs-sized, MaxDistance 45) over the next table for sale only
	    (Ghost with Price > 0): "Patio Table" + "$30", the tag red while the party cash (Economy set) cannot pay it.
	    The prompt pill ("Buy Table — $30") is the PromptController's, from the server's anchor attributes.
	  - Bought (Ghost -> Free): confetti (Kitchen Fx budget) + `upgrade_done` (SFX-065) on the table. The toast
	    "Table added!" is HudController's (Notice table_added).
	  - Dirty: tray + wrapper + cup + tip coins (Tray.luau; `Table_Tray` model under ReplicatedStorage.Assets
	    replaces the drawn one) on Tray_Anchor, else the centre of the table top. Rebuilt when the tip changes.
	  - Cleaned (Dirty -> Free with the previous Tip > 0, while the drawer is open): "+$N" rising over the table
	    (DrawerValue Pop, same look as the drawer one), a Tip coin burst and SFX `coin`. The "+$N" on the drawer is
	    EconomyController's (the drawer value goes up). The Summary reset writes the same Dirty -> Free with Tip -> 0:
	    it is told apart by the phase, read one defer later (the Round record of the same flush has landed by then).
	  - Diners (Meal.luau): rigs with the `Seated` attribute hold a hot dog that shrinks in 3 bites; npc_sit /
	    npc_eat_seated play through AnimController when they have an Id.
	  - Carried plate (TASK-387, restaurant): rigs with `Carrying` walk with a plate + their hot dog (Meal.luau,
	    Tray.Plate); seated, the plate goes on the table and the hot dog to the hand. Toppings: the last non-empty order
	    of the Customers set (the served record is already empty), cached here; table top = the spot's TrayAt.

	Order at the table (Q-209, Provisional): a customer sits right after "Take Order" and waits (rig attribute `Seated`,
	empty hands); the server table anchor carries "Serve Table n: <order>" (PromptController / interaction menu). Over an
	Occupied table whose customer is Waiting this controller mounts the order label: a plate "TABLE n" with the topping
	names in the tag and an OrderBubble with the topping icons (a pair: one row per hot dog), read from the Customers
	set through CustomerController. It goes when the food is served (the customer is Leaving and eats; `Eating`
	on the rig, Meal.luau) or the customer leaves.

	Groups (Q-209): one group since 2026-10-12, the tables TBL-1..4; the next one for sale is a Ghost with a plate
	"Table $N"; a ghost the party cannot pay is drawn fainter (GhostDimTransparency).

	Not here yet (TASK-147 rest): Patio Lights string (UPG-009) and Back Bar (UPG-010): no model nor binding yet
	(TASK-149 / TASK-153). Listeners in OnInit (before Lync.start); tags and rigs are scanned in OnStart.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local TableSign = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TableSign)
local OrderBubble = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.OrderBubble)
local Pop = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.DrawerValue.Pop)
local WorldScale = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.WorldScale)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)
local Look = require(script.Look)
local Tray = require(script.Tray)
local Meal = require(script.Meal)

const SEATING = Content.Seating
const BINDING = SEATING.Binding
const ECONOMY_ID = 1 -- single record (network.md §1 rule 5)
const SIGN_TITLE = "Table" -- ui-text.md (TASK-150), Provisional (fallback; every group uses Group.Label)
const SIGN_LIFT = 2.8 -- studs over the table top: clears the prompt pill (anchor at +0.6)
const SIGN_DISTANCE = 45
const ORDER_LIFT = 4.2 -- studs over the table top: the order bubble sits over the "TABLE n" plate (Q-209)
const ORDER_DISTANCE = 60
const POP_LIFT = 1.2 -- studs over the table top where the "+$N" starts
const POP_WIDTH = 180
const POP_HEIGHT = 130
const POP_DISTANCE = 80
const CONFETTI = 14
const TIP_COINS = 3
-- Phases with the drawer open (EconomyService:IsDrawerOpen): a Dirty -> Free there is a cleaning
const OPEN_PHASES: { [string]: boolean } = { Closing = true }
for _, phase in SEATING.SitPhases do
	OPEN_PHASES[phase] = true
end

export type State = "Locked" | "Ghost" | "Free" | "Occupied" | "Dirty"

export type Record = { State: string, Price: number, Npc1: number, Npc2: number, Tip: number }

type Spot = {
	Index: number,
	Record: Vide.Source<Record | false>,
	Model: Model?,
	Saved: Look.Saved?, -- authored look of Model
	Top: Attachment?, -- table top centre (Terrain), adornee of the plate and the pops
	TrayAt: CFrame?, -- where the tray goes
	Tray: Model?,
	TrayTip: number, -- tip the tray was built with
	Dim: boolean, -- ghost drawn fainter: for sale but the party cannot pay it yet (like the bench)
	Unmount: (() -> ())?,
	Gui: Instance?,
	OrderUnmounts: { () -> () }, -- order label (plate + bubble) of a customer waiting at the table (Q-209)
	OrderGuis: { Instance },
}

-- Order of a customer as last seen with something in it (TASK-387).
type Orders = { Order: { [string]: boolean }, Order2: { [string]: boolean }? }

-- Topping keys of an order bitfield, in ToppingKeys order.
local function keysOf(order: { [string]: boolean }): { string }
	const keys: { string } = {}
	for _, key in Content.Ingredients.ToppingKeys do
		if order[key] then
			table.insert(keys, key)
		end
	end
	return keys
end

const SeatingController = Modux.Controller(
	"SeatingController",
	{ Require = { "RoundController", "AudioController", "AnimController", "CustomerController" }, Priority = 680 }
)

function SeatingController:Setup()
	self.Spots = {} :: { [number]: Spot }
	-- table Model -> its watcher connections
	self.Tracked = {} :: { [Model]: { RBXScriptConnection } }
	self.Gui = nil :: Instance?
	self.Folder = nil :: Folder?
	-- party cash (Economy.Cash); until the first record arrives the plate is never red
	self.Cash = Vide.source(0) :: Vide.Source<number>
	self.CashReady = Vide.source(false) :: Vide.Source<boolean>
	self.Meal = (Meal.new({
		Play = function(model: Model, key: string, looped: boolean)
			self.Dependencies.AnimController:Play(model, key, { Looped = looped })
		end,
		Stop = function(model: Model, key: string)
			self.Dependencies.AnimController:Stop(model, key)
		end,
	}, {
		Toppings = function(rig: Model): { string }
			return self:CarriedToppings(rig)
		end,
		TableTop = function(index: number): CFrame?
			const spot = self.Spots[index]
			return if spot then spot.TrayAt else nil
		end,
	})) :: Meal.Meal
	-- NpcId -> last non-empty order seen (the served record has an empty Order: the plate keeps what was ordered)
	self.Orders = {} :: { [number]: Orders }
end

-- Topping keys of the plate a served rig carries (TASK-387): its own order, a partner the leader's 2nd hot dog.
function SeatingController:CarriedToppings(rig: Model): { string }
	const id = rig:GetAttribute("NpcId")
	if typeof(id) ~= "number" then
		return {}
	end
	const order = self.Orders[id]
	if order ~= nil then
		return keysOf(order.Order)
	end
	const record = Vide.untrack(function()
		return self.Dependencies.CustomerController:RecordOf(id)
	end)
	const leader = if record then self.Orders[record.Leader or 0] else nil
	if leader ~= nil and leader.Order2 ~= nil then
		return keysOf(leader.Order2)
	end
	return {}
end

function SeatingController:RememberOrder(id: number, record: { Order: { [string]: boolean }, Order2: { [string]: boolean }? })
	const known = self.Orders[id]
	if known ~= nil and known.Order2 ~= nil and record.Order2 == nil then
		return -- a pair being served line by line: keep both hot dogs as ordered
	end
	if next(keysOf(record.Order)) ~= nil then
		self.Orders[id] = {
			Order = table.clone(record.Order),
			Order2 = if record.Order2 then table.clone(record.Order2) else nil,
		}
	end
end

-- Reactive read of a table record (nil = unknown). For other controllers and debugging.
function SeatingController:RecordOf(index: number): Record?
	const spot = self.Spots[index]
	if spot == nil then
		return nil
	end
	const record = spot.Record()
	if record == false then
		return nil
	end
	return record
end

function SeatingController:SpotOf(index: number): Spot
	const existing = self.Spots[index]
	if existing ~= nil then
		return existing
	end
	const spot: Spot = {
		Index = index,
		Record = Vide.source(false :: Record | false) :: Vide.Source<Record | false>,
		Model = nil,
		Saved = nil,
		Top = nil,
		TrayAt = nil,
		Tray = nil,
		TrayTip = 0,
		Dim = false,
		Unmount = nil,
		Gui = nil,
		OrderUnmounts = {},
		OrderGuis = {},
	}
	self.Spots[index] = spot
	return spot
end

-- Client folder for the trays (never inside the server's table models).
function SeatingController:FolderOf(): Folder
	local folder = self.Folder
	if folder == nil or folder.Parent == nil then
		const created = Instance.new("Folder")
		created.Name = "Seating_Client"
		created.Parent = workspace
		folder = created
		self.Folder = created
	end
	return folder :: Folder
end

function SeatingController:Cue(key: string, at: Instance)
	if Content.Sounds.ByKey[key] then
		self.Dependencies.AudioController:Play(key, at)
	end
end

-- Records ---------------------------------------------------------------------------------------------------------

-- Copies: the set may reuse its record table, and Vide needs a new value to notice a change.
function SeatingController:WriteRecord(index: number, record: Record?)
	const spot = self:SpotOf(index)
	const old = Vide.untrack(spot.Record)
	if record == nil then
		spot.Record(false)
		self:Apply(spot)
		return
	end
	const copy: Record = {
		State = record.State,
		Price = record.Price,
		Npc1 = record.Npc1,
		Npc2 = record.Npc2,
		Tip = record.Tip,
	}
	-- a leftover tray (nothing makes a table Dirty since DEC-307) is just removed
	if old ~= false and old.State == "Dirty" and copy.State == "Free" and spot.Tray ~= nil then
		spot.Tray:Destroy()
		spot.Tray = nil
		spot.TrayTip = 0
	end
	spot.Record(copy)
	self:Apply(spot)
	if old == false then
		return -- first sight (late join, run start): no celebration
	end
	if old.State == "Ghost" and copy.State ~= "Ghost" and copy.State ~= "Locked" then
		self:Bought(spot)
	elseif old.State == "Dirty" and copy.State == "Free" and old.Tip > 0 then
		const tip = old.Tip
		-- the Summary reset writes the same thing; the phase of the same flush is read one defer later
		task.defer(function()
			if OPEN_PHASES[Vide.untrack(self.Dependencies.RoundController.Phase)] then
				self:Cleaned(spot, tip)
			end
		end)
	end
end

-- Binding ---------------------------------------------------------------------------------------------------------

local function topOf(model: Model): (Vector3, CFrame)
	const frame, size = model:GetBoundingBox()
	const top = frame.Position + Vector3.new(0, size.Y / 2, 0)
	-- yaw of the table, Y up
	const look = frame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	return top, CFrame.lookAt(top, top + flat.Unit)
end

-- Tray frame: Tray_Anchor of the table (Attachment or Part, Y up), else the centre of the table top.
local function trayFrame(model: Model, fallback: CFrame): CFrame
	const anchor = model:FindFirstChild(BINDING.TrayAnchor, true)
	if anchor ~= nil and anchor:IsA("Attachment") then
		return anchor.WorldCFrame
	elseif anchor ~= nil and anchor:IsA("BasePart") then
		return anchor.CFrame
	end
	return fallback
end

function SeatingController:Bind(spot: Spot, model: Model)
	if spot.Model == model then
		return
	end
	self:Unbind(spot)
	spot.Model = model
	spot.Saved = Look.Capture(model)
	const top, frame = topOf(model)
	spot.TrayAt = trayFrame(model, frame)
	const attachment = Instance.new("Attachment")
	attachment.Name = `Seating_Top_{spot.Index}`
	attachment.WorldPosition = top
	attachment.Parent = workspace.Terrain
	spot.Top = attachment
	self:MountSign(spot)
	self:MountOrder(spot)
	self:Apply(spot)
end

-- Back to the authored look, tray, plate and anchor gone.
function SeatingController:Unbind(spot: Spot)
	if spot.Saved ~= nil then
		Look.Apply(spot.Saved, "Solid", 0)
	end
	self:ClearTray(spot)
	const unmount = spot.Unmount
	if unmount then
		spot.Unmount = nil
		unmount()
	end
	if spot.Gui then
		spot.Gui:Destroy()
		spot.Gui = nil
	end
	self:UnmountOrder(spot)
	if spot.Top then
		spot.Top:Destroy()
		spot.Top = nil
	end
	spot.Model = nil
	spot.Saved = nil
	spot.TrayAt = nil
end

-- Re-reads the TableIndex of a tagged model.
function SeatingController:Rebind(model: Model)
	for _, spot in self.Spots do
		if spot.Model == model then
			self:Unbind(spot)
		end
	end
	const value = model:GetAttribute(BINDING.IndexAttribute)
	if not CollectionService:HasTag(model, BINDING.Tag) or not model:IsDescendantOf(workspace) then
		return
	end
	if typeof(value) ~= "number" or value < 1 or value > SEATING.Tables or value % 1 ~= 0 then
		return
	end
	const spot = self:SpotOf(value)
	if spot.Model == nil then
		self:Bind(spot, model)
	end
end

function SeatingController:Track(instance: Instance)
	if not instance:IsA("Model") or self.Tracked[instance] ~= nil then
		return
	end
	const model = instance
	self.Tracked[model] = {
		model:GetAttributeChangedSignal(BINDING.IndexAttribute):Connect(function()
			self:Rebind(model)
		end),
		model.Destroying:Connect(function()
			self:Untrack(model)
		end),
	}
	self:Rebind(model)
end

function SeatingController:Untrack(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	const connections = self.Tracked[instance]
	if connections == nil then
		return
	end
	self.Tracked[instance] = nil
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, spot in self.Spots do
		if spot.Model == instance then
			self:Unbind(spot)
		end
	end
end

-- Presentation ----------------------------------------------------------------------------------------------------

function SeatingController:Apply(spot: Spot)
	const saved = spot.Saved
	if saved == nil then
		return
	end
	const record = Vide.untrack(spot.Record)
	if record == false then
		Look.Apply(saved, "Solid", 0) -- no record (lobby, before the first replication): as authored
		self:ClearTray(spot)
		return
	end
	const mode: Look.Mode = if record.State == "Locked"
		then "Hidden"
		elseif record.State == "Ghost" then "Ghost"
		else "Solid"
	const dim = record.State == "Ghost" and record.Price > 0 and not self:CanPayNow(record.Price)
	spot.Dim = dim
	Look.Apply(saved, mode, if dim then SEATING.GhostDimTransparency else SEATING.GhostTransparency)
	if record.State == "Dirty" then
		self:ShowTray(spot, record.Tip)
	else
		self:ClearTray(spot)
	end
end

function SeatingController:ShowTray(spot: Spot, tip: number)
	const at = spot.TrayAt
	if at == nil or (spot.Tray ~= nil and spot.Tray.Parent ~= nil and spot.TrayTip == tip) then
		return
	end
	self:ClearTray(spot)
	const tray = Tray.Build(at, tip, SEATING.TableTip)
	tray.Name = `Seating_Tray_{spot.Index}`
	tray.Parent = self:FolderOf()
	spot.Tray = tray
	spot.TrayTip = tip
end

function SeatingController:ClearTray(spot: Spot)
	if spot.Tray ~= nil then
		spot.Tray:Destroy()
		spot.Tray = nil
	end
	spot.TrayTip = 0
end

function SeatingController:CanPay(price: number): boolean
	return not self.CashReady() or self.Cash() >= price
end

-- Same, readable outside a reactive scope (Apply).
function SeatingController:CanPayNow(price: number): boolean
	return Vide.untrack(function(): boolean
		return self:CanPay(price)
	end)
end

-- The party cash changed: a ghost for sale turns faint / solid-ghost when the price crosses it.
function SeatingController:RefreshDim()
	for _, spot in self.Spots do
		const record = Vide.untrack(spot.Record)
		if record ~= false and record.State == "Ghost" and record.Price > 0 then
			if spot.Dim == self:CanPayNow(record.Price) then
				self:Apply(spot)
			end
		end
	end
end

-- Plate title of a table: its group's label.
local function titleOf(index: number): string
	for _, group in SEATING.Groups do
		if index >= group.First and index < group.First + group.Count then
			return group.Label
		end
	end
	return SIGN_TITLE
end

-- Price plate of the table (mounted once per bound table; shown only on the next one for sale).
function SeatingController:MountSign(spot: Spot)
	const gui = self.Gui
	const top = spot.Top
	if gui == nil or top == nil or spot.Unmount ~= nil then
		return
	end
	const unmount, billboard = Vide.root(function()
		local function price(): number
			const record = spot.Record()
			return if record ~= false and record.State == "Ghost" then record.Price else 0
		end
		return TableSign({
			Name = `TableSign_{spot.Index}`,
			Adornee = top,
			Visible = function()
				return price() > 0
			end,
			Mode = function(): TableSign.Mode
				return if self:CanPay(price()) then "Buy" else "NoCash"
			end,
			Title = function()
				return titleOf(spot.Index)
			end,
			Price = function()
				return `${price()}`
			end,
			Offset = Vector3.new(0, SIGN_LIFT, 0),
			MaxDistance = SIGN_DISTANCE,
		})
	end)
	billboard.Parent = gui
	spot.Unmount = unmount
	spot.Gui = billboard
end

-- NpcId of the customer waiting at the table (reactive), or nil: the table is Occupied and its first diner (the leader
-- of the order) is Waiting for its food (Q-209).
function SeatingController:WaitingAt(spot: Spot): number?
	const record = spot.Record()
	if record == false or record.State ~= "Occupied" or record.Npc1 == 0 then
		return nil
	end
	const customer = self.Dependencies.CustomerController:RecordOf(record.Npc1)
	if customer == nil or customer.State ~= "Waiting" then
		return nil
	end
	return record.Npc1
end

-- "Ketchup + Cheese" (a pair: "Ketchup + Cheese | Mustard"): names of the pending hot dogs of the order.
local function orderNames(rows: { { OrderBubble.Topping } }): string
	const parts: { string } = {}
	for _, row in rows do
		const names: { string } = {}
		for _, topping in row do
			const ingredient = Content.Ingredients.ByKey[topping.Key]
			table.insert(names, if ingredient then ingredient.Name else topping.Key)
		end
		table.insert(parts, if #names > 0 then table.concat(names, " + ") else "Plain")
	end
	return table.concat(parts, " | ")
end

-- Pending rows of the customer at the table: 1st hot dog, and the pair's 2nd one.
function SeatingController:OrderRows(spot: Spot): { { OrderBubble.Topping } }
	const id = self:WaitingAt(spot)
	const rows: { { OrderBubble.Topping } } = {}
	const controller = self.Dependencies.CustomerController
	const customer = if id then controller:RecordOf(id) else nil
	if customer == nil then
		return rows
	end
	table.insert(rows, controller:ToppingsOf(customer))
	if customer.Order2 ~= nil then
		table.insert(rows, controller:ToppingsOfOrder(customer.Order2))
	end
	return rows
end

-- Order label over a table: plate "TABLE n" (tag = topping names) + bubble with the icons. Visible only while the
-- customer of the table waits for its food (Q-209). Mounted with the table, once the gui exists.
function SeatingController:MountOrder(spot: Spot)
	const gui = self.Gui
	const top = spot.Top
	if gui == nil or top == nil or #spot.OrderUnmounts > 0 then
		return
	end
	local function waiting(): boolean
		return self:WaitingAt(spot) ~= nil
	end
	const unmountPlate, plate = Vide.root(function()
		return TableSign({
			Name = `TableOrder_{spot.Index}`,
			Adornee = top,
			Visible = waiting,
			Mode = function(): TableSign.Mode
				return "Buy"
			end,
			Title = function()
				return `TABLE {spot.Index}`
			end,
			Price = function()
				return orderNames(self:OrderRows(spot))
			end,
			Offset = Vector3.new(0, SIGN_LIFT, 0),
			MaxDistance = SIGN_DISTANCE,
		})
	end)
	plate.Parent = gui
	table.insert(spot.OrderUnmounts, unmountPlate)
	table.insert(spot.OrderGuis, plate)
	const unmountBubble, bubble = Vide.root(function()
		return OrderBubble({
			Name = `TableOrderBubble_{spot.Index}`,
			Adornee = top,
			Visible = waiting,
			Toppings = function()
				return self:OrderRows(spot)[1] or {}
			end,
			Toppings2 = function()
				return self:OrderRows(spot)[2]
			end,
			Patience = function()
				return -1 -- the patience bar over the customer carries the clock
			end,
			Offset = Vector3.new(0, ORDER_LIFT, 0),
			MaxDistance = ORDER_DISTANCE,
			AlwaysOnTop = true,
		})
	end)
	bubble.Parent = gui
	table.insert(spot.OrderUnmounts, unmountBubble)
	table.insert(spot.OrderGuis, bubble)
end

function SeatingController:UnmountOrder(spot: Spot)
	for _, unmount in spot.OrderUnmounts do
		unmount()
	end
	table.clear(spot.OrderUnmounts)
	for _, gui in spot.OrderGuis do
		gui:Destroy()
	end
	table.clear(spot.OrderGuis)
end

-- Ghost -> bought: confetti + SFX-065 on the table.
function SeatingController:Bought(spot: Spot)
	const top = spot.Top
	if top == nil then
		return
	end
	Fx.Burst(top.WorldPosition, "Confetti", CONFETTI)
	self:Cue("upgrade_done", top)
end

-- Clean Table done: "+$N" rising over the table, coin burst and sound.
function SeatingController:Cleaned(spot: Spot, tip: number)
	const top = spot.Top
	const gui = self.Gui
	if top == nil or gui == nil then
		return
	end
	Fx.Burst(top.WorldPosition, "Tip", TIP_COINS)
	self:Cue("coin", top)
	local billboard: BillboardGui? = nil
	local unmount: (() -> ())? = nil
	local function finish()
		task.defer(function()
			if unmount then
				unmount()
				unmount = nil
			end
			if billboard then
				billboard:Destroy()
				billboard = nil
			end
		end)
	end
	unmount, billboard = Vide.root(function()
		const pop = Vide.create("BillboardGui")({
			Name = `TablePop_{spot.Index}`,
			Adornee = top,
			Size = UDim2.fromOffset(POP_WIDTH, POP_HEIGHT),
			SizeOffset = Vector2.new(0, 0.5),
			StudsOffsetWorldSpace = Vector3.new(0, POP_LIFT, 0),
			AlwaysOnTop = true,
			MaxDistance = POP_DISTANCE,
			LightInfluence = 0,
			ResetOnSpawn = false,
			Pop.Render({ Amount = tip }, { Bottom = POP_HEIGHT, OnDone = finish }),
		})
		-- shrinks with distance like the table under it (a pixel pop grew next to it from far away, owner 2026-10-20)
		WorldScale.Track(pop, POP_WIDTH, POP_HEIGHT)
		return pop
	end)
	if billboard then
		billboard.Parent = gui
	end
end

function SeatingController:Watch(gui: Instance)
	self.Gui = gui
	CollectionService:GetInstanceAddedSignal(BINDING.Tag):Connect(function(instance)
		self:Track(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(BINDING.Tag):Connect(function(instance)
		self:Untrack(instance)
	end)
	for _, instance in CollectionService:GetTagged(BINDING.Tag) do
		self:Track(instance)
	end
	-- signs of tables bound before the gui existed
	for _, spot in self.Spots do
		self:MountSign(spot)
		self:MountOrder(spot)
	end

	CollectionService:GetInstanceAddedSignal(CrewRig.Tag):Connect(function(instance)
		self.Meal:Track(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(CrewRig.Tag):Connect(function(instance)
		self.Meal:Untrack(instance)
	end)
	for _, instance in CollectionService:GetTagged(CrewRig.Tag) do
		self.Meal:Track(instance)
	end
end

SeatingController:OnInit(function(self)
	self:Setup()

	const net = self.Libs.Net
	net.Tables:onAdded(function(index, record)
		self:WriteRecord(index, record)
	end)
	net.Tables:onChanged(function(index, record)
		self:WriteRecord(index, record)
	end)
	net.Tables:onRemoved(function(index)
		self:WriteRecord(index, nil)
	end)

	-- toppings of the plate a served customer carries (TASK-387); presentation only
	net.Customers:onAdded(function(id, record)
		self:RememberOrder(id, record)
	end)
	net.Customers:onChanged(function(id, record)
		self:RememberOrder(id, record)
	end)
	net.Customers:onRemoved(function(id)
		self.Orders[id] = nil
	end)

	const applyCash = function(id: number, record: { Cash: number, Drawer: number })
		if id == ECONOMY_ID then
			Vide.batch(function()
				self.Cash(record.Cash)
				self.CashReady(true)
			end)
			self:RefreshDim()
		end
	end
	net.Economy:onAdded(applyCash)
	net.Economy:onChanged(applyCash)
	net.Economy:onRemoved(function(id)
		if id == ECONOMY_ID then
			self.CashReady(false)
			self:RefreshDim()
		end
	end)
end)

SeatingController:OnStart(function(self)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return SeatingController
