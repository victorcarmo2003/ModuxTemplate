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
-- Service window (architecture.md §19.14 v4.2, network.md §13.6, T61; FEAT-023; DEC-204, DEC-221; TASK-130): state of
-- the current vehicle when Content.Vehicles[v].HasShutter (the trailer). Single writer of the attribute Shutter on the
-- vehicle Models (true = closed; the vehicle for sale / parked is always closed, AST-027 ForSale). Action
-- shutter_toggle (Prompt_Shutter, hold 0.5, night only, party cooldown 1 s, Active member, anchor of the current
-- vehicle, caller inside the trailer = LightZone LZ-1); opens by itself on ShiftStarted, NightLost, Resume, restore and swap; not in the snapshot. Gate "Shutter":
-- take_order/serve/refuse refused while closed (reason Shutter:Closed) + Notice shutter_closed to who acted (one per
-- NOTICE_EVERY s). API IsShutterClosed, IsInside, IsInsidePoint, IsProtected, SetShutter; signal ShutterChanged.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(ServerScriptService.server.Modux)
local Shutter = require(script.Shutter)

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
-- Service window (§19.14)
const SHUTTER_ACTION = "shutter_toggle"
const SHUTTER_ATTRIBUTE = "Shutter"
const SHUTTER_GATE = "Shutter"
const SHUTTER_NOTICE = "shutter_closed"
const SHUTTER_COOLDOWN = 1 -- s between two toggles, party-wide (Q-173; not a Content.Actions field)
const NOTICE_EVERY = 2 -- s between two shutter_closed notices to the same player
-- Counter actions refused while the window is closed (the queue waits, patience keeps running)
const COUNTER_ACTIONS: { [string]: boolean } = { take_order = true, serve = true, refuse = true }
-- PromptText when closed. Content.Actions.shutter_toggle.Text ("Close Window") is the open state; the table has one
-- Text per action. PLACEHOLDER until ui-text.md (content-data.md §6 row shutter_toggle).
const OPEN_TEXT = "Open Window"
-- Phases where the window opens by itself (NightLost; Resume = restore waiting for the roster)
const OPEN_PHASES = { "NightLost", "Resume" }

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
	-- Service window of the current vehicle (only meaningful with HasShutter)
	self.ShutterClosed = false :: boolean
	self.ShutterAt = 0 :: number -- os.clock() of the last shutter_toggle (party cooldown; 0 = none yet)
	self.ShutterAnchors = {} :: { [Instance]: boolean }
	self.InteriorPart = nil :: BasePart?
	self.NoticeAt = setmetatable({}, { __mode = "k" }) :: { [Player]: number }
	-- (closed, player?) player = who toggled; nil = automatic opening or dev. AnomalyService (570) connects in OnInit
	self.ShutterChanged = self.Libs.Signal.new() :: SignalLib.Signal<boolean, Player?>
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

-- Service window (§19.14) -----------------------------------------------------------------------------------------

local function hasShutter(key: string?): boolean
	const row = if key ~= nil then Content.Vehicles.ByKey[key] else nil
	return row ~= nil and row.HasShutter
end

function VehicleService:IsShutterClosed(): boolean
	return self.ShutterClosed and hasShutter(self.Vehicle())
end

-- Interior volume (Shutter.luau: LightZone LZ-1; L3-20). Cached part, scanned again when it leaves the Workspace.
function VehicleService:Interior(): BasePart?
	const cached = self.InteriorPart
	if cached ~= nil and cached:IsDescendantOf(workspace) then
		return cached
	end
	self.InteriorPart = Shutter.findInterior()
	return self.InteriorPart
end

-- Point inside the trailer interior while the current vehicle has a window (the cart has no interior to protect)
function VehicleService:IsInsidePoint(position: Vector3): boolean
	if typeof(position) ~= "Vector3" or not hasShutter(self.Vehicle()) then
		return false
	end
	const part = self:Interior()
	return part ~= nil and Shutter.contains(part, position)
end

-- Root of the player's character inside the current vehicle
function VehicleService:IsInside(player: Player): boolean
	const character = player.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	return self:IsInsidePoint(root.Position)
end

-- N8/N9 protected state (DEC-221): window closed and inside the trailer
function VehicleService:IsProtected(player: Player): boolean
	return self:IsShutterClosed() and self:IsInside(player)
end

function VehicleService:IsShutterAnchor(anchor: Instance): boolean
	return anchor:GetAttribute("PromptAction") == SHUTTER_ACTION
end

-- Attribute Shutter of every Model with a window (current = its state, parked/for sale = closed) and the prompts
function VehicleService:ApplyShutter()
	const current = self.Vehicle()
	for _, model in self:Models() do
		const key = model:GetAttribute("Vehicle") :: string
		if hasShutter(key) then
			model:SetAttribute(SHUTTER_ATTRIBUTE, if key == current then self.ShutterClosed else true)
		end
	end
	const interaction = self.Dependencies.InteractionService
	const enabled = interaction:IsActive(SHUTTER_ACTION)
	const text = if self.ShutterClosed then OPEN_TEXT else nil
	for anchor in self.ShutterAnchors do
		if anchor.Parent == nil then
			self.ShutterAnchors[anchor] = nil
			continue
		end
		const _, key = vehicleOf(anchor)
		const live = enabled and key == current and hasShutter(key)
		interaction:SetPrompt(anchor, live, if live then text else nil)
	end
end

function VehicleService:AddShutterAnchor(anchor: Instance)
	if not self:IsShutterAnchor(anchor) or self.ShutterAnchors[anchor] then
		return
	end
	self.ShutterAnchors[anchor] = true
	self:ApplyShutter()
end

-- Party window state. Closing needs a night shift outside the closed phases and a vehicle with a window (dev goes
-- through here too: "shutter close" by day does nothing); force = automatic opening paths. Opening always works.
-- Returns the state now matches `closed`.
function VehicleService:SetShutter(closed: boolean, player: Player?, force: boolean?): boolean
	if type(closed) ~= "boolean" then
		error("[VehicleService] SetShutter needs a boolean", 2)
	end
	if closed and force ~= true then
		if not hasShutter(self.Vehicle()) or not self:ShutterPhase() then
			return false
		end
	end
	if self.ShutterClosed == closed then
		return true
	end
	self.ShutterClosed = closed
	self:ApplyShutter()
	self.ShutterChanged:Fire(closed, player)
	return true
end

-- Night shift, outside Resume/Intro/RunEnd/NightLost. Follows Actions.shutter_toggle.Night = NightOnly, i.e. the
-- night shift as a whole (its Prep included, same as KitchenService/ItemService read Night; L3-18, PROVISIONAL)
function VehicleService:ShutterPhase(): boolean
	const round = self.Dependencies.RoundService
	return round:IsStarted() and round:IsNight() and table.find(CLOSED_PHASES, round:GetPhase()) == nil
end

-- shutter_toggle Validate: Active member, anchor of the current vehicle with a window, caller inside it, phase,
-- party cooldown
function VehicleService:CanToggleShutter(player: Player, anchor: Instance): boolean
	if not self.Dependencies.RunStateService:IsActive(player) or not self:ShutterPhase() then
		return false
	end
	const _, key = vehicleOf(anchor)
	if key ~= self.Vehicle() or not hasShutter(key) or not self:IsInside(player) then
		return false -- L3-17: the button works only from inside the trailer
	end
	-- cooldown: silent refusal (L3-19)
	return os.clock() - self.ShutterAt >= SHUTTER_COOLDOWN
end

-- Gate refusal notice, at most one per NOTICE_EVERY s per player (FEAT-005)
function VehicleService:NotifyClosed(player: Player)
	const at = os.clock()
	const last = self.NoticeAt[player]
	if last ~= nil and at - last < NOTICE_EVERY then
		return
	end
	self.NoticeAt[player] = at
	self.Dependencies.RunStateService:Notify(player, SHUTTER_NOTICE)
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
	self:SetShutter(false, nil, true) -- the new current opens, the parked one closes (ApplyShutter below)
	self:ApplyShutter()
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
	-- the window is not in the snapshot: every restore opens it (§19.14)
	self:SetShutter(false, nil, true)
	self:ApplyShutter()
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

	-- Service window (§19.14)
	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction(SHUTTER_ACTION, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			return self:CanToggleShutter(player, anchor)
		end,
		Run = function(player: Player, _anchor: Instance, _id: number)
			self.ShutterAt = os.clock()
			self:SetShutter(not self.ShutterClosed, player, true)
		end,
	})
	interaction:AddGate(SHUTTER_GATE, function(player: Player, action: string, _anchor: Instance): (boolean, string?)
		if COUNTER_ACTIONS[action] and self:IsShutterClosed() then
			-- the prompt is already hidden on clients with the window closed: this is the race (a mate closed it
			-- during the hold)
			self:NotifyClosed(player)
			return false, "Closed"
		end
		return true, nil
	end)
	round.ShiftStarted:Connect(function(_info)
		self:SetShutter(false, nil, true)
	end)
	round.PhaseChanged:Connect(function(phase)
		if table.find(OPEN_PHASES, phase) ~= nil then
			self:SetShutter(false, nil, true)
		end
	end)
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
		self:AddShutterAnchor(anchor)
	end)

	-- Service window: anchors, attribute of every vehicle and the interior volume
	for _, anchor in CollectionService:GetTagged(ANCHOR_TAG) do
		if self:IsShutterAnchor(anchor) then
			self.ShutterAnchors[anchor] = true
		end
	end
	if SALE ~= nil and SALE.HasShutter and self:Interior() == nil then
		warn(`[VehicleService] LightZone {Shutter.InteriorZone} not bound (MAP-01 §16); IsInside is always false`)
	end
	if SALE ~= nil and SALE.HasShutter and next(self.ShutterAnchors) == nil then
		warn("[VehicleService] no Prompt_Shutter (PromptAction shutter_toggle) in the Workspace (MAP-01 §16.5)")
	end
	self:ApplyShutter()
	CollectionService:GetInstanceAddedSignal(COVER_TAG):Connect(function(cover)
		if cover:IsDescendantOf(workspace) then
			self:RefreshCover(cover)
		end
	end)
end)

return VehicleService
