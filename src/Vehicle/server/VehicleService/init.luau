--!strict
-- Vehicle in use, trailer purchase and the end-of-shift swap (architecture.md §19.5, T36, T38, T58; network.md §13.1
-- `Transition`; data.md §3.3 "Veh"; FEAT-016, FEAT-017; DEC-047, DEC-086, DEC-107, DEC-121, DEC-184, DEC-199;
-- TASK-056). Run place only.
-- State: Vehicle (atom, key of Content.Vehicles), Purchased (the sale vehicle was bought this run) and Pending (swap at the
-- next shift boundary). The two vehicles live in the Workspace (tag Vehicle, attribute Vehicle = key) and only move
-- by PivotTo (T36): before the swap the start vehicle sits at its Pad point and the sale vehicle at the lot
-- (TRL-SALE); after it the sale vehicle takes its Pad point and the start vehicle goes to the lot under its tarp
-- (VehicleCover, shown by visibility with the Orig* attributes of the binding, T38).
-- Purchase: anchor Prompt_Buy (buy_trailer) on the sale vehicle; price = TrailerBasePrice x PartyPriceMult[PriceParty]
-- (DEC-047, DEC-121). Swap: RoundService.BeforeShift with Pending -> Transition packet -> state + SetVehicle ->
-- Swapped -> PivotTo under the fade. Reminders (FEAT-017) from Vehicles[sale].Reminder at the end of a day shift.
-- Others read: Current() (RoundService probe, ItemService, KitchenService), IsBought(), Price(); signals
-- Bought(player) and Swapped(from, to). The sale vehicle Model carries attribute Bought for clients that join between
-- the purchase and the swap (VehicleController, TASK-058).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(ServerScriptService.server.Modux)

const VEHICLE_TAG = "Vehicle"
const COVER_TAG = "VehicleCover"
const ANCHOR_TAG = "Interactable"
const BUY_ACTION = "buy_trailer"
const BOUGHT_NOTICE = "trailer_bought"
const AVAILABLE_NOTICE = "trailer_available"
const WAITING_NOTICE = "trailer_waiting"
const BOUGHT_ATTRIBUTE = "Bought"
const SNAPSHOT = "Veh"
const START_VEHICLE = Content.RunParams.StartVehicle
-- Binding points (MAP-01 §16.3: point = model pivot). Pad point of each vehicle when in use; the lot otherwise.
const START_POINT = "CART"
const SALE_POINT = "TRL"
const LOT_POINT = "TRL-SALE"
-- Phases where nobody buys even by day: waiting for the roster / opening cutscene (RoundService Busy-like phases)
const CLOSED_PHASES = { "Resume", "Intro", "RunEnd", "NightLost" }
-- Seconds between the Transition packet and the PivotTo: fade-in (0.2) + half the black hold (0.5) of the
-- VehicleController fade (T58, 1.5 s total), so the pivot lands under the cover on every client. Provisional.
const PIVOT_DELAY = 0.45

local function fail(message: string)
	if RunService:IsStudio() then
		error(message, 0)
	end
	warn(message)
end

-- Vehicle sold in the lot: the first row with BuyFromDay > 0 (the trailer; content-data.md §3.8)
local function saleVehicle(): Content.Vehicle?
	for _, vehicle in Content.Vehicles.List do
		if vehicle.BuyFromDay > 0 then
			return vehicle
		end
	end
	return nil
end

const SALE = saleVehicle()

-- Model tagged Vehicle that contains `instance` (or is it), with its key
local function vehicleOf(instance: Instance): (Instance?, string?)
	local current: Instance? = instance
	while current ~= nil and current ~= workspace do
		if CollectionService:HasTag(current, VEHICLE_TAG) then
			const key = current:GetAttribute("Vehicle")
			return current, if type(key) == "string" then key else nil
		end
		current = current.Parent
	end
	return nil, nil
end

-- Visible = Orig* values of the binding (default visible), hidden = transparent and without collision (T38)
local function setVisible(instance: Instance, visible: boolean)
	if instance:IsA("BasePart") then
		if visible then
			const transparency = instance:GetAttribute("OrigTransparency")
			instance.Transparency = if type(transparency) == "number" then transparency else 0
			instance.CanCollide = instance:GetAttribute("OrigCanCollide") ~= false
			instance.CanQuery = instance:GetAttribute("OrigCanQuery") ~= false
			instance.CanTouch = instance:GetAttribute("OrigCanTouch") ~= false
		else
			instance.Transparency = 1
			instance.CanCollide = false
			instance.CanQuery = false
			instance.CanTouch = false
		end
	elseif instance:IsA("Decal") then
		const transparency = instance:GetAttribute("OrigTransparency")
		instance.Transparency = if not visible then 1 elseif type(transparency) == "number" then transparency else 0
	end
end

const VehicleService = Modux.Service("VehicleService", {
	Require = {
		"PlaceService",
		"NetService",
		"RunStateService",
		"RoundService",
		"InteractionService",
		"EconomyService",
		"UpgradeService",
	},
	Priority = 620,
})

function VehicleService:Setup()
	self.Vehicle = self.Libs.Charm.atom(START_VEHICLE) :: Charm.Atom<string>
	self.Purchased = self.Libs.Charm.atom(false) :: Charm.Atom<boolean>
	self.Pending = self.Libs.Charm.atom(false) :: Charm.Atom<boolean>
	-- Bumped on every placement request: a delayed PivotTo only runs if nothing newer came after it
	self.PlaceToken = 0 :: number
	self.MissingPoints = {} :: { [string]: boolean }
	-- Created here so lower-priority services connect in their OnInit; higher ones (Item, Kitchen) in OnStart
	self.Bought = self.Libs.Signal.new() :: SignalLib.Signal<Player>
	self.Swapped = self.Libs.Signal.new() :: SignalLib.Signal<string, string>
end

-- Reads -----------------------------------------------------------------------------------------------------------

function VehicleService:Current(): string
	return self.Vehicle()
end

function VehicleService:IsBought(): boolean
	return self.Purchased()
end

function VehicleService:IsPending(): boolean
	return self.Pending()
end

-- TrailerBasePrice x PartyPriceMult[PriceParty] (DEC-047, DEC-121). PriceParty is 0 until the end of Day 1: the
-- solo multiplier until then (the trailer is never on sale before BuyFromDay anyway).
function VehicleService:Price(): number
	const params = Content.RunParams
	const mults = params.PartyPriceMult
	const party = math.clamp(self.Dependencies.RunStateService.PriceParty(), 1, #mults)
	return math.floor(params.TrailerBasePrice * mults[party] + 0.5)
end

-- Shift and phase allow the purchase (Actions.buy_trailer Night / Requires.Phase, Vehicles[sale].BuyFromDay)
function VehicleService:IsOnSale(): boolean
	if SALE == nil or self.Purchased() or self.Pending() or self.Vehicle() ~= START_VEHICLE then
		return false
	end
	const round = self.Dependencies.RoundService
	if not round:IsStarted() or round:GetDay() < SALE.BuyFromDay then
		return false
	end
	const phase = round:GetPhase()
	if table.find(CLOSED_PHASES, phase) ~= nil then
		return false
	end
	const row = Content.Actions.ByKey[BUY_ACTION]
	const night = round:IsNight()
	if (row.Night == "DayOnly" and night) or (row.Night == "NightOnly" and not night) then
		return false
	end
	const phases = row.Requires.Phase
	return phases == nil or table.find(phases, phase) ~= nil
end

function VehicleService:PromptText(): string
	return (string.gsub(Content.Actions.ByKey[BUY_ACTION].Text, "{price}", tostring(self:Price())))
end

-- World -----------------------------------------------------------------------------------------------------------

function VehicleService:Models(): { Instance }
	const out = {}
	for _, model in CollectionService:GetTagged(VEHICLE_TAG) do
		if model:IsDescendantOf(workspace) and type(model:GetAttribute("Vehicle")) == "string" then
			table.insert(out, model)
		end
	end
	return out
end

-- Pad point when in use, the lot otherwise (MAP-01 §16.3)
function VehicleService:PointFor(key: string): string
	if key ~= self.Vehicle() then
		return LOT_POINT
	end
	return if key == START_VEHICLE then START_POINT else SALE_POINT
end

function VehicleService:IsBuyAnchor(anchor: Instance): boolean
	if anchor:GetAttribute("PromptAction") ~= BUY_ACTION then
		return false
	end
	const _, key = vehicleOf(anchor)
	return SALE ~= nil and key == SALE.Key
end

-- Tarp shown on a vehicle that is not in use and has CoveredAfter (the cart after the swap, DEC-199)
function VehicleService:RefreshCover(cover: Instance)
	const _, key = vehicleOf(cover)
	const row = if key then Content.Vehicles.ByKey[key] else nil
	const visible = row ~= nil and row.CoveredAfter ~= nil and key ~= self.Vehicle()
	setVisible(cover, visible)
	for _, descendant in cover:GetDescendants() do
		setVisible(descendant, visible)
	end
end

function VehicleService:RefreshCovers()
	for _, cover in CollectionService:GetTagged(COVER_TAG) do
		if cover:IsDescendantOf(workspace) then
			self:RefreshCover(cover)
		end
	end
end

-- PivotTo of every vehicle to the point of the current state, then the tarps. Idempotent.
function VehicleService:PlaceNow()
	if not MapIndex.HasBinding() then
		return
	end
	for _, model in self:Models() do
		const key = model:GetAttribute("Vehicle") :: string
		const pointId = self:PointFor(key)
		const point = MapIndex.FindPoint(pointId)
		if point == nil then
			if not self.MissingPoints[pointId] then
				self.MissingPoints[pointId] = true
				warn(`[VehicleService] MapPoint {pointId} not found (binding wave 2, MAP-01 §16); {key} not moved`)
			end
			continue
		end
		if model:IsA("PVInstance") and not model:GetPivot():FuzzyEq(point, 1e-3) then
			model:PivotTo(point)
		end
	end
	self:RefreshCovers()
end

-- delay > 0: under the fade of the swap. A newer request cancels an older delayed one.
function VehicleService:Place(delay: number)
	self.PlaceToken += 1
	const token = self.PlaceToken
	if delay <= 0 then
		self:PlaceNow()
		return
	end
	task.delay(delay, function()
		if self.PlaceToken == token then
			self:PlaceNow()
		end
	end)
end

-- Prompt_Buy state and the Bought attribute of the sale vehicle (one effect, see OnStart)
function VehicleService:RefreshSale()
	const sale = SALE
	if sale == nil then
		return
	end
	const interaction = self.Dependencies.InteractionService
	const enabled = self:IsOnSale()
	const text = self:PromptText()
	const bought = self.Purchased()
	for _, model in self:Models() do
		if model:GetAttribute("Vehicle") ~= sale.Key then
			continue
		end
		model:SetAttribute(BOUGHT_ATTRIBUTE, bought)
		for _, descendant in model:GetDescendants() do
			if self:IsBuyAnchor(descendant) then
				interaction:SetPrompt(descendant, enabled, text)
			end
		end
	end
end

-- Writes ----------------------------------------------------------------------------------------------------------

-- buy_trailer Run: atomic Spend, then Purchased + Pending (swap at the next boundary) and the party notice
function VehicleService:Buy(player: Player): boolean
	if not self:IsOnSale() then
		return false
	end
	if not self.Dependencies.EconomyService:Spend(self:Price(), player) then
		return false
	end
	self:MarkBought(player)
	return true
end

function VehicleService:MarkBought(player: Player?)
	self.Libs.Charm.batch(function()
		self.Purchased(true)
		self.Pending(true)
	end)
	self.Dependencies.RunStateService:Notify("all", BOUGHT_NOTICE)
	if player then
		self.Bought:Fire(player)
	end
end

-- Applies the pending swap (RoundService.BeforeShift, before Flow.Next reads the probe): fade packet, state,
-- UpgradeService levels of the new vehicle, Swapped; the pivots follow under the fade.
function VehicleService:Swap()
	if SALE == nil then
		return
	end
	const from = self.Vehicle()
	const to = SALE.Key
	self.Pending(false)
	if from == to then
		return
	end
	const net = self.Dependencies.NetService
	const covered = net:IsRunning()
	if covered then
		self.Libs.Net.Transition:fireClient(net.Audience, {
			Kind = "VehicleSwap",
			StartedAt = workspace:GetServerTimeNow(),
		})
	end
	self.Vehicle(to)
	self.Dependencies.UpgradeService:SetVehicle(to)
	self.Swapped:Fire(from, to)
	self:Place(if covered then PIVOT_DELAY else 0)
end

-- End of a day shift without the purchase: trailer_available on Reminder.FirstDay, trailer_waiting every
-- Reminder.Every days after (FEAT-017)
function VehicleService:Remind(info: { Day: number, IsNight: boolean })
	if SALE == nil or info.IsNight or self.Purchased() or self.Vehicle() ~= START_VEHICLE then
		return
	end
	const reminder = SALE.Reminder
	if reminder == nil then
		return
	end
	const day = info.Day
	if day == reminder.FirstDay then
		self.Dependencies.RunStateService:Notify("all", AVAILABLE_NOTICE)
	elseif day > reminder.FirstDay and reminder.Every > 0 and (day - reminder.FirstDay) % reminder.Every == 0 then
		self.Dependencies.RunStateService:Notify("all", WAITING_NOTICE)
	end
end

-- Snapshot "Veh" (data.md §3.3): the key of the current vehicle. Restore = positions + SetVehicle + Bought =
-- (Veh ~= StartVehicle); a pending swap is dropped (the capture is taken after the boundary applied it). A change of
-- vehicle on restore (ResetDev back to the cart, Resume on a fresh server) fires Swapped too, so the stations follow.
function VehicleService:Restore(data: any)
	local key = START_VEHICLE
	if type(data) == "string" and Content.Vehicles.ByKey[data] ~= nil then
		key = data
	elseif data ~= nil then
		fail(`[VehicleService] snapshot Veh: unknown vehicle {tostring(data)}, using {START_VEHICLE}`)
	end
	const from = self.Vehicle()
	self.Libs.Charm.batch(function()
		self.Vehicle(key)
		self.Purchased(key ~= START_VEHICLE)
		self.Pending(false)
	end)
	self.Dependencies.UpgradeService:SetVehicle(key)
	self:Place(0)
	if from ~= key then
		self.Swapped:Fire(from, key)
	end
end

-- Dev hooks (Commands/Vehicle.luau) ------------------------------------------------------------------------------

function VehicleService:DevCheck(name: string)
	if not self.Dependencies.PlaceService:IsDev() then
		error(`[VehicleService] {name} is dev mode only`, 3)
	end
	if SALE == nil then
		error(`[VehicleService] {name}: no vehicle for sale in Content.Vehicles`, 3)
	end
end

-- Free purchase on any day and phase (no Spend); the swap still waits for the boundary
function VehicleService:DevBuy(): boolean
	self:DevCheck("DevBuy")
	if self.Purchased() or self.Vehicle() ~= START_VEHICLE then
		return false
	end
	self:MarkBought(nil)
	return true
end

-- Swap now, buying for free first if needed (the shift keeps going; nights start at the next boundary)
function VehicleService:DevSwap(): boolean
	self:DevCheck("DevSwap")
	if SALE ~= nil and self.Vehicle() == SALE.Key then
		return false
	end
	if not self.Purchased() then
		self:MarkBought(nil)
	end
	self:Swap()
	return true
end

VehicleService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	if SALE == nil then
		warn("[VehicleService] no vehicle with BuyFromDay > 0 in Content.Vehicles; nothing for sale")
	end

	const round = self.Dependencies.RoundService
	round:SetVehicleProbe(function(): string
		return self.Vehicle()
	end)
	round.BeforeShift:Connect(function(_prev)
		if self.Pending() then
			self:Swap()
		end
	end)
	round.ShiftEnded:Connect(function(info)
		self:Remind(info)
	end)

	self.Dependencies.RunStateService:RegisterSnapshot(SNAPSHOT, function()
		return self.Vehicle()
	end, function(data, _mode)
		self:Restore(data)
	end)

	-- InteractionService (730) built its handler table in its OnInit, before this one
	self.Dependencies.InteractionService:RegisterAction(BUY_ACTION, {
		Validate = function(_player: Player, anchor: Instance, _id: number): boolean
			return self:IsBuyAnchor(anchor) and self:IsOnSale()
		end,
		Run = function(player: Player, _anchor: Instance, _id: number)
			self:Buy(player)
		end,
	})
end)

VehicleService:OnStart(function(self)
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	-- Binding state = start of a run (MAP-01 §16.3); a restore before this point already placed them
	self:Place(0)

	-- Day, phase, PriceParty, purchase: every input of the prompt is an atom read inside RefreshSale
	self.Libs.Charm.effect(function()
		self:RefreshSale()
	end)

	CollectionService:GetInstanceAddedSignal(ANCHOR_TAG):Connect(function(anchor)
		if self:IsBuyAnchor(anchor) then
			self:RefreshSale()
		end
	end)
	CollectionService:GetInstanceAddedSignal(COVER_TAG):Connect(function(cover)
		if cover:IsDescendantOf(workspace) then
			self:RefreshCover(cover)
		end
	end)
end)

return VehicleService
