--!strict
--[[
	PlateController (TASK-570; kitchen-world.md §1-§2; DEC-306, DEC-308)

	Presents the plate in hand of the world kitchen; decides nothing (PlateService ties the ticket, KitchenService fills the
	plate, the Tools `plate` and `hot_dog` carry it, shared/Plate/PlateTool names the attributes). The central table, the
	conveyor and the PLATE-n pass are gone (TASK-581).

	  - HUD (TicketHud): while the local player holds a plate or the hot dog it became, its ticket (#n, the order's bun,
	    sausage and toppings, faded while missing; "No ticket yet" for a plate with none) sits under the order card.
	  - In hand (HandFood): the bun and the sausage on a plate are drawn on it, for every player's plate.
	  - Condiment pans: only the pans of the held plate's order that are not on it yet light up (a Highlight on the Pan_* Model
	    whose attribute Topping is that key; kitchen-world.md §1 #9).
	  - "#n" tag over the plate a crewmate holds (TicketHud.TagHands).
	  - Plate slots of the front counter (SlotCards, DEC-311): a slot with no ticket line hides its plate; one with a line
	    shows it under the order card (PlateOrderCard: #n, the layered hot dog, the patience).
	  - Prompts: plugs the plate probe into PromptController/Rules (Take Plate with free hands, Add Bun / Add Sausage only
	    for what the plate lacks, Hand Over only with a hot dog, its ticket customer at the pickup).
	Listeners in OnInit (before Lync.start); the HUD is built in OnStart.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Rules = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Rules)
local HandFood = require(script.HandFood)
local SlotCards = require(script.SlotCards)
local TicketHud = require(script.TicketHud)

const MAX_TOPPINGS = Content.OrderRules.MaxToppings
const STEP_RATE = 10 -- Hz: HUD place, pan lights
const HUD_GAP = 8 -- px under the order card
const HUD_FALLBACK = UDim2.fromOffset(8, 96)
const PAN_ATTRIBUTE = "Topping" -- PRODUCTION/Pan_* (kitchen-world.md §5)
const PAN_LIGHT = "PlateOrderLight"
const PAN_COLOR = Theme.Color.Mustard
const TICKET_CARD_ATTRIBUTE = "TicketCard" -- LocalPlayer: the plate card is on the HUD (HudController hides HudOrder)

-- What the HUD and the prompts read of the Customers set
type Customer = {
	State: string,
	PatienceEndsAt: number,
	PatienceSpan: number,
	Number: number?,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
	Pickup: number?,
	Drive: number?,
	Bread: boolean, -- the order is a bun alone (Content.OrderRules.BreadOnly, ANM-011)
}

-- Last order seen for a ticket (a plate whose customer left still shows it)
type TicketMemo = { Number: number?, Order: { string }, Order2: { string }?, Drive: boolean, Bread: boolean }

const PlateController = Modux.Controller("PlateController", { Require = { "InputController" }, Priority = 660 })

function PlateController:Setup()
	-- NpcId -> Customers record (copy); one source for the whole map (<= 12 customers, few writes)
	self.Customers = Vide.source({}) :: Vide.Source<{ [number]: Customer }>
	self.Tickets = {} :: { [number]: TicketMemo }
	self.Hand = nil :: TicketHud.Tracker?
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.HudPosition = Vide.source(HUD_FALLBACK) :: Vide.Source<UDim2>
	-- server time, ticked with OnTick (the slot cards' patience bars)
	self.Clock = Vide.source(0) :: Vide.Source<number>
	self.HudGui = nil :: ScreenGui?
	-- Pan_* Models by topping key (rescanned when one goes away) and the lit ones
	self.Pans = {} :: { [string]: Instance }
	self.Lit = {} :: { [string]: Highlight }
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

function PlateController:WriteCustomer(id: number, record: any?)
	const map = table.clone(Vide.untrack(self.Customers))
	if record == nil then
		map[id] = nil
	else
		map[id] = {
			State = record.State,
			PatienceEndsAt = record.PatienceEndsAt,
			PatienceSpan = record.PatienceSpan,
			Number = record.Number,
			Order = table.clone(record.Order),
			Order2 = if record.Order2 then table.clone(record.Order2) else nil,
			Pickup = record.Pickup,
			Drive = record.Drive,
			Bread = record.Bread == true,
		}
		if record.Number ~= nil then
			self.Tickets[id] = {
				Number = record.Number,
				Order = toppingList(record.Order),
				Order2 = if record.Order2 then toppingList(record.Order2) else nil,
				Drive = record.Drive ~= nil,
				Bread = record.Bread == true,
			}
		end
	end
	self.Customers(map)
end

-- Reactive: #n of a ticket (Customers, else the last seen)
function PlateController:TicketNumber(npc: number): number?
	const customer = self.Customers()[npc]
	if customer ~= nil and customer.Number ~= nil then
		return customer.Number
	end
	const memo = self.Tickets[npc]
	return if memo then memo.Number else nil
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

-- Reactive: the order of a ticket is a bun alone (Customers, else the last seen)
function PlateController:BreadOf(ticket: number): boolean
	if ticket == 0 then
		return false
	end
	const customer = self.Customers()[ticket]
	if customer ~= nil then
		return customer.Bread
	end
	const memo = self.Tickets[ticket]
	return memo ~= nil and memo.Bread
end

-- The equipped plate carries the bun alone and a bread-only order waits for it in the pickup line (its ticket's, or any
-- one for a plate with no ticket); not reactive. The server decides again (PlateService gate, CustomerService:BreadTarget)
function PlateController:BreadReady(held: TicketHud.HeldPlate): boolean
	if held.Item ~= "plate" or not held.Bun or held.Dog or next(held.Toppings) ~= nil then
		return false
	end
	const customers = Vide.untrack(self.Customers)
	local function waits(customer: Customer?): boolean
		return customer ~= nil and customer.Bread and customer.State == "Waiting" and customer.Pickup ~= nil
	end
	if held.Ticket ~= 0 and waits(customers[held.Ticket]) then
		return true
	end
	for _, customer in customers do
		if waits(customer) then
			return true
		end
	end
	return false
end

-- Reactive: the plate the HUD shows (the equipped plate / hot dog of the world kitchen), nil = none
function PlateController:Current(): TicketHud.HeldPlate?
	const hand = self.Hand
	const held: TicketHud.HeldPlate | false = if hand then hand.Held() else false
	if held == false or (held.PlateId == 0 and held.Ticket == 0) then
		return nil
	end
	return held
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
			-- a bread-only order (ANM-011): the bun alone
			if self:BreadOf(current.Ticket) then
				return { { Key = "bun", Done = current.Bun } }
			end
			const cells: { TicketHud.Cell } = {
				{ Key = "bun", Done = current.Bun },
				{ Key = "sausage", Done = current.Dog },
			}
			for _, key in self:OrderOf(current.Ticket, current.Line) or {} do
				table.insert(cells, { Key = key, Done = current.Toppings[key] == true })
			end
			return cells
		end,
		NoToppings = function()
			const current = self:Current()
			const order = if current then self:OrderOf(current.Ticket, current.Line) else nil
			return order ~= nil and #(order :: { string }) == 0
		end,
		Grade = function(): string?
			const current = self:Current()
			return if current then current.Quality else nil
		end,
		Flip = function()
			const current = self:Current()
			return current ~= nil and current.FlipBonus
		end,
		Orphan = function()
			const current = self:Current()
			return current ~= nil and current.Orphan
		end,
		More = function()
			const hand = self.Hand
			if hand == nil or self:Current() == nil then
				return 0
			end
			return math.max(hand.Hands() - 1, 0)
		end,
		Patience = function(): number
			const current = self:Current()
			if current == nil or current.Ticket == 0 then
				return -1
			end
			const customer = self.Customers()[current.Ticket]
			if customer == nil or customer.PatienceSpan <= 0 or customer.PatienceEndsAt <= 0 then
				return -1
			end
			return math.clamp((customer.PatienceEndsAt - self.Clock()) / customer.PatienceSpan, 0, 1)
		end,
		WarnAt = Content.Moods.Rules.AnnoyedAt,
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

-- The equipped plate the prompt rules read (not reactive)
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

-- Condiment pans ----------------------------------------------------------------------------------------------------

-- Pan_* Models of the map by topping key (attribute Topping); rescanned only when a known one went away or none is known
function PlateController:PanOf(key: string): Instance?
	const known = self.Pans[key]
	if known ~= nil and known.Parent ~= nil then
		return known
	end
	table.clear(self.Pans)
	for _, instance in Workspace:GetDescendants() do
		if instance:IsA("Model") then
			const topping = instance:GetAttribute(PAN_ATTRIBUTE)
			if type(topping) == "string" then
				self.Pans[topping] = instance
			end
		end
	end
	return self.Pans[key]
end

-- The pans of the held plate's order that are not on it yet light up; everything else goes dark
function PlateController:LightPans()
	const held = self:EquippedPlate()
	const wanted: { [string]: boolean } = {}
	if held ~= nil and held.Ticket ~= 0 then
		const order = Vide.untrack(function(): { string }?
			return self:OrderOf(held.Ticket, held.Line)
		end)
		for _, key in order or {} do
			if not held.Toppings[key] then
				wanted[key] = true
			end
		end
	end
	for key, light in self.Lit do
		if not wanted[key] or light.Parent == nil then
			light:Destroy()
			self.Lit[key] = nil
		end
	end
	for key in wanted do
		if self.Lit[key] ~= nil then
			continue
		end
		const pan = self:PanOf(key)
		if pan == nil then
			continue
		end
		const light = Instance.new("Highlight")
		light.Name = PAN_LIGHT
		light.Adornee = pan
		light.FillColor = PAN_COLOR
		light.FillTransparency = 0.75
		light.OutlineColor = PAN_COLOR
		light.OutlineTransparency = 0
		light.DepthMode = Enum.HighlightDepthMode.Occluded
		light.Parent = pan
		self.Lit[key] = light
	end
end

function PlateController:Watch(gui: Instance)
	self.Hand = TicketHud.Track(Players.LocalPlayer)

	const _, screen = Vide.root(function()
		return TicketHud.Screen({
			Card = self:HudCard(),
			Scale = function()
				return self.Scale()
			end,
		})
	end)
	self.HudGui = screen
	screen.Parent = gui
	-- one order card on the HUD (owner 2026-10-19): while the plate card shows, HudController hides its HudOrder
	Vide.root(function()
		Vide.effect(function()
			Players.LocalPlayer:SetAttribute(TICKET_CARD_ATTRIBUTE, self:Current() ~= nil)
		end)
	end)

	-- "#n" over the plate a crewmate holds
	const tags = Instance.new("Folder")
	tags.Name = "PlateHandTags"
	tags.Parent = gui
	TicketHud.TagHands(tags, function(npc: number): number?
		return Vide.untrack(function(): number?
			return self:TicketNumber(npc)
		end)
	end)
	HandFood.Watch()
	SlotCards.Watch({
		Number = function(npc: number): number?
			return self:TicketNumber(npc)
		end,
		Order = function(npc: number, line: number): { string }?
			return self:OrderOf(npc, line)
		end,
		Drive = function(npc: number): boolean
			const customer = self.Customers()[npc]
			return customer ~= nil and customer.Drive ~= nil
		end,
		Bread = function(npc: number): boolean
			return self:BreadOf(npc)
		end,
		Patience = function(npc: number): number?
			const customer = self.Customers()[npc]
			if customer == nil or customer.PatienceSpan <= 0 or customer.PatienceEndsAt <= 0 then
				return nil
			end
			return math.clamp((customer.PatienceEndsAt - self.Clock()) / customer.PatienceSpan, 0, 1)
		end,
	})
end

PlateController:OnInit(function(self)
	self:Setup()

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
		Hands = function(): number
			const hand = self.Hand
			return if hand then Vide.untrack(hand.Hands) else 0
		end,
		Equipped = function(): Rules.HeldPlate?
			const held = self:EquippedPlate()
			if held == nil then
				return nil
			end
			return {
				Item = held.Item,
				Ticket = held.Ticket,
				Bun = held.Bun,
				Sausage = held.Dog,
				AtPickup = if held.Ticket ~= 0 then self:AtPickup(held.Ticket) else nil,
				Bread = self:BreadReady(held),
			}
		end,
	})
end)

PlateController:OnStart(function(self)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

-- HUD place and pan lights (10 Hz, after Watch)
PlateController:OnTick(function(self)
	if self.HudGui == nil then
		return
	end
	self:PlaceHud()
	self:LightPans()
	self.Clock(Workspace:GetServerTimeNow())
end, STEP_RATE)

return PlateController
