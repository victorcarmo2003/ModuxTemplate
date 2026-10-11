--!strict
--[[
	MarketController (TASK-037; FEAT-008, FEAT-015; DEC-015, DEC-106, DEC-180, DEC-184)

	Draws the Mart in the world, never on screen (DEC-015):
	  * a ShelfTag on each of the 9 shelf anchors (`Interactable` + `Package`): price from Content.Packages, red when
	    the party cash is short (FEAT-008), "Out of stock" (+ "Day N", Provisional) while Stock[ingredient].Blocked
	    (DEC-180). The tag leaves the moment the server clears Blocked on the unlock day;
	  * a BenchCard on each GEAR WALL position (`Interactable` + `BenchSlot`): B1..B5 read the Upgrades set (levels of
	    the current vehicle, DEC-184) and Content.Upgrades -> next level name, effect, price (red when short),
	    "Maxed" at the last level, "Trailer only" when the upgrade does not exist on the current vehicle (B5 on the
	    cart, DEC-055). S1 is "Nothing special today" in wave 1 (no Bench set yet, FEAT-035 is wave 4).

	Presentation only: it never buys, never changes cash, stock or levels. Prompts (text, enabled, hold) belong to
	MarketService/PromptController; the server refuses a buy without cash whatever this shows.
	Network: listeners on the Economy, Stock and Upgrades sets are registered in OnInit (README, network.md rule 7).

	Sound and VFX (TASK-079; sound-list §5.5; AST-092): an upgrade level going up by one on the same vehicle (and not
	right after a vehicle swap, which rewrites the levels) is a purchase: the pedestal celebrates at once (see Gear
	Stand) and, SETTLE s after the record, SFX-065 `upgrade_done` + 14 confetti play on the vehicle in use (heard at
	the Pad, FEAT-015), so a swap whose Shift.Vehicle lands after the Upgrades records stays silent. Package buys have
	no event here (the Tool arrives through ItemController): SFX-061 is not played by this controller.

	Gear Stand (Mart v2, TASK-140; FEAT-015 v2; MAP-01 §18.4; Q-176 A Provisional), zero network of its own:
	  * shutters (Kiosk.luau): down in Content.Mart.KioskClosedPhases, up in every other phase of the Shift set
	    (RoundController.Phase). Animated with Mart.Door times and the L -> C -> R stagger; the first record (late
	    joiner) snaps to the final state. Without GearShutter models a test shutter is generated (1 warning);
	  * miniatures (Minis.luau) over the pedestals: the piece of the NEXT level on the current vehicle ("Sale", bob +
	    spin), the current level when maxed (still), the first trailer level at 50% for "Trailer only" (still), none
	    on the empty S1. Frozen with the camera beyond Mart.Mini.ActiveRadius or the shutter down;
	  * price plate = BenchCard in Plate mode hung under `Price_Anchor_<Slot>` (pedestal first, then the prompt owner,
	    then the prompt anchor), hidden while the shutter is down;
	  * purchase: the old miniature spins and pops, 14 confetti + SFX-064 `buy` at the pedestal, the next one rises.
	    Shutter SFX keys `kiosk_shutter_down` / `kiosk_shutter_up` play once they exist in Content.Sounds.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local BenchCard = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.BenchCard)
local ShelfTag = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ShelfTag)
local Kiosk = require(script.Kiosk)
local Labels = require(script.Labels)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Minis = require(script.Minis)
-- shared VFX budget (AST-092 ceiling counts the whole screen)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)

const TAG = "Interactable"
const ECONOMY_ID = 1 -- single record (network.md §1 rule 5)
const SPECIAL_SLOT = "S1"
-- Shelf tag sits under the prompt pill, which is drawn at the anchor itself (Provisional, MAP-01 §7.4).
const SHELF_OFFSET = Vector3.new(0, -1.3, 0)
const SHELF_DISTANCE = 30
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle"
const SETTLE = 0.5 -- s before an upgrade sound is decided (swap guard)
const SWAP_GUARD = 2 -- s: level changes this close to a vehicle swap are the swap, not a purchase
const CONFETTI = 14 -- AST-092 upgrade Emit(14)
const NEVER = -1e9 -- SwappedAt before any swap
const MART = Content.Mart
const TICK_RATE = 60 -- Hz: shutters and miniatures move every frame while visible
const RELOCATE_EVERY = 2 -- s between two re-reads of the pedestal positions (streaming)
const MAP_WAIT = 60 -- s MapIndex.WaitReady may wait before the fallback shutters are generated
-- Plate (BenchCard Plate mode, 1.9 high) hangs under its anchor; without Price_Anchor it goes under the prompt pill.
const PLATE_UNDER_FITTING = Vector3.new(0, -1.9 / 2, 0)
const PLATE_UNDER_PROMPT = Vector3.new(0, -(1.9 / 2 + 0.9), 0)
const DOOR_DOWN_SFX = "kiosk_shutter_down"
const DOOR_UP_SFX = "kiosk_shutter_up"
const KIOSK_CLOSED: { [string]: boolean } = {}
for _, phase in MART.KioskClosedPhases do
	KIOSK_CLOSED[phase] = true
end

export type View = {
	Visible: boolean,
	Mode: BenchCard.Mode,
	Title: string,
	Detail: string,
	Tag: string,
}

type Mounted = {
	Gui: BillboardGui,
	Unmount: () -> (),
}

const HIDDEN: View = { Visible = false, Mode = "Empty", Title = "", Detail = "", Tag = "" }
-- Upgrades record not received yet. A source of an optional type cannot be read with `()` (ambiguous overload).
const UNKNOWN_LEVEL = -1

-- Stock[ingredient].Blocked as seen by the client; Unknown = record not received yet.
type Availability = "Unknown" | "Open" | "Blocked"

const MarketController =
	Modux.Controller("MarketController", { Require = { "RoundController", "AudioController" }, Priority = 680 })

function MarketController:Setup()
	-- Party cash (Economy.Cash). Until the first record arrives nothing is drawn red.
	self.Cash = Vide.source(0) :: Vide.Source<number>
	self.CashReady = Vide.source(false) :: Vide.Source<boolean>
	-- Upgrades set: level of the current vehicle per upgrade key; UNKNOWN_LEVEL until the record arrives.
	self.Levels = {} :: { [string]: Vide.Source<number> }
	for _, upgrade in Content.Upgrades.List do
		self.Levels[upgrade.Key] = Vide.source(UNKNOWN_LEVEL)
	end
	-- Stock set: Blocked per ingredient key.
	self.Stock = {} :: { [string]: Vide.Source<Availability> }
	for _, ingredient in Content.Ingredients.List do
		self.Stock[ingredient.Key] = Vide.source("Unknown" :: Availability)
	end
	self.Mounted = {} :: { [Instance]: Mounted }
	self.Gui = nil :: Instance?
	-- last level seen per upgrade key (UNKNOWN_LEVEL = none) and when Shift.Vehicle last changed (os.clock)
	self.LastLevel = {} :: { [string]: number }
	self.SwappedAt = NEVER :: number
	self.Unmount = nil :: (() -> ())?
	-- Gear Stand
	self.KioskOpen = Vide.source(true) :: Vide.Source<boolean>
	self.KioskSynced = false :: boolean -- first Shift record applied (later changes animate)
	self.Kiosk = Kiosk.new() :: Kiosk.Kiosk
	self.Minis = Minis.new() :: Minis.Minis
	self.Pedestals = {} :: { [string]: Instance }
	self.LastStep = os.clock() :: number
	self.LastRelocate = 0 :: number
end

-- Bench anchor of a GEAR WALL position (B1..B5), nil when not mounted (streamed out)
function MarketController:BenchAnchor(slot: string): Instance?
	for anchor in self.Mounted do
		if anchor:GetAttribute("BenchSlot") == slot and anchor.Parent then
			return anchor
		end
	end
	return nil
end

function MarketController:CurrentVehicle(): Model?
	const key = Vide.untrack(self.Dependencies.RoundController.Vehicle)
	for _, vehicle in CollectionService:GetTagged(VEHICLE_TAG) do
		if vehicle:IsA("Model") and vehicle:GetAttribute(VEHICLE_ATTRIBUTE) == key and vehicle:IsDescendantOf(workspace) then
			return vehicle
		end
	end
	return nil
end

-- One-shot; a key still missing from Content.Sounds is skipped quietly
function MarketController:Cue(key: string, at: Instance)
	if Content.Sounds.ByKey[key] then
		self.Dependencies.AudioController:Play(key, at)
	end
end

-- Pedestal celebration of a purchase (FEAT-015 v2 "Feedback da compra" 2): pop on the next miniature change,
-- SFX-064 `buy` and confetti at the miniature.
function MarketController:Celebrate(slot: string)
	self.Minis:Celebrate(slot)
	const at, host = self.Minis:Where(slot)
	if at then
		Fx.Burst(at, "Confetti", MART.Purchase.Confetti)
	end
	const where = host or self:BenchAnchor(slot)
	if where then
		self:Cue("buy", where)
	end
end

-- Upgrade level change: +1 on the same vehicle, away from a swap = a purchase (presentation only). Called BEFORE the
-- level source is written, so the pedestal knows the miniature change is a purchase.
function MarketController:OnLevel(upgrade: Content.Upgrade, level: number)
	const previous = self.LastLevel[upgrade.Key] or UNKNOWN_LEVEL
	self.LastLevel[upgrade.Key] = level
	-- In-place upgrades (Pad tables, TASK-144) are not Gear Stand purchases: SeatingController presents them
	if upgrade.SoldAt ~= "Bench" then
		return
	end
	if previous == UNKNOWN_LEVEL or level ~= previous + 1 then
		return
	end
	const round = self.Dependencies.RoundController
	const vehicle = Vide.untrack(round.Vehicle)
	const at = os.clock()
	if at - self.SwappedAt >= SWAP_GUARD then
		self:Celebrate(upgrade.BenchSpot)
	end
	task.delay(SETTLE, function()
		if Vide.untrack(round.Vehicle) ~= vehicle or at - self.SwappedAt < SWAP_GUARD then
			return
		end
		const model = self:CurrentVehicle()
		if model then
			self:Cue("upgrade_done", model)
			const frame, size = model:GetBoundingBox()
			Fx.Burst(frame.Position + Vector3.new(0, size.Y / 2, 0), "Confetti", CONFETTI)
		end
	end)
end

-- True when the party can pay `price` (or cash is not known yet: no false red on join).
function MarketController:CanPay(price: number): boolean
	return not self.CashReady() or self.Cash() >= price
end

function MarketController:UpgradeAt(slot: string): Content.Upgrade?
	for _, upgrade in Content.Upgrades.List do
		if upgrade.BenchSpot == slot then
			return upgrade
		end
	end
	return nil
end

-- Pure view of one fixed position (B1..B5) from the current vehicle, its level and the cash.
function MarketController:BenchView(upgrade: Content.Upgrade, vehicle: string, level: number): View
	if not table.find(upgrade.Vehicles, vehicle) then
		-- "Trailer only" (B5 on the cart): show what it would be on the first vehicle that has it.
		const home = upgrade.Vehicles[1]
		const rows = if home then upgrade.Levels[home] else nil
		local first: Content.UpgradeLevel? = nil
		if rows then
			for _, row in rows do
				if row.Level > upgrade.StartLevel then
					first = row
					break
				end
			end
		end
		return {
			Visible = true,
			Mode = "Locked",
			Title = Labels.LevelName(upgrade, if first then first.Level else upgrade.StartLevel + 1),
			Detail = if first then Labels.Effect(upgrade, first) else "",
			Tag = Labels.TrailerOnly,
		}
	end

	if level == UNKNOWN_LEVEL then
		return HIDDEN
	end

	const rows = upgrade.Levels[vehicle]
	if rows == nil then
		return HIDDEN
	end
	local current: Content.UpgradeLevel? = nil
	local nextRow: Content.UpgradeLevel? = nil
	for _, row in rows do
		if row.Level == level then
			current = row
		elseif row.Level == level + 1 then
			nextRow = row
		end
	end

	if nextRow == nil then
		return {
			Visible = true,
			Mode = "Maxed",
			Title = Labels.LevelName(upgrade, level),
			Detail = if current then Labels.Effect(upgrade, current) else "",
			Tag = Labels.Maxed,
		}
	end

	return {
		Visible = true,
		Mode = if self:CanPay(nextRow.Price) then "Buy" else "NoCash",
		Title = Labels.LevelName(upgrade, nextRow.Level),
		Detail = Labels.Effect(upgrade, nextRow),
		Tag = Labels.Price(nextRow.Price),
	}
end

-- Miniature target of a fixed position (B1..B5): next level on sale, current level when maxed, first level of the
-- home vehicle for "Trailer only", nothing until the level is known (FEAT-015 v2 table).
function MarketController:MiniTarget(upgrade: Content.Upgrade, vehicle: string, level: number): Minis.Target
	const badge = Labels.Badge(upgrade)
	if not table.find(upgrade.Vehicles, vehicle) then
		const home = upgrade.Vehicles[1]
		const rows = (if home then upgrade.Levels[home] else nil) or {}
		for _, row in rows do
			if row.Level > upgrade.StartLevel then
				return { State = "Locked", Part = row.Part, Vehicle = home, Badge = badge }
			end
		end
		return { State = "Locked", Part = "", Vehicle = vehicle, Badge = badge }
	end
	if level == UNKNOWN_LEVEL then
		return { State = "Hidden", Part = "", Vehicle = vehicle, Badge = badge }
	end
	local current: Content.UpgradeLevel? = nil
	local nextRow: Content.UpgradeLevel? = nil
	for _, row in upgrade.Levels[vehicle] or {} do
		if row.Level == level then
			current = row
		elseif row.Level == level + 1 then
			nextRow = row
		end
	end
	if nextRow then
		return { State = "Sale", Part = nextRow.Part, Vehicle = vehicle, Badge = badge }
	end
	return { State = "Maxed", Part = if current then current.Part else "", Vehicle = vehicle, Badge = badge }
end

-- Plate fitting of a slot: `Price_Anchor_<Slot>` (or `Price_Anchor`) inside the GearPedestal, else
-- `Price_Anchor_<Slot>` inside the anchor's owner (nearest Model ancestor, architecture.md §18.3/§18.4). nil = none
-- (the plate hangs under the prompt anchor).
function MarketController:PlateFitting(anchor: Instance, slot: string): Instance?
	const pedestal = self.Pedestals[slot]
	local fitting: Instance? = nil
	if pedestal then
		fitting = pedestal:FindFirstChild("Price_Anchor_" .. slot, true) or pedestal:FindFirstChild("Price_Anchor", true)
	end
	if fitting == nil then
		const owner = anchor:FindFirstAncestorWhichIsA("Model")
		fitting = if owner then owner:FindFirstChild("Price_Anchor_" .. slot, true) else nil
	end
	if fitting and (fitting:IsA("Attachment") or fitting:IsA("BasePart")) then
		return fitting
	end
	return nil
end

function MarketController:MountShelf(anchor: Instance, packageKey: string): Mounted?
	const package = Content.Packages.ByKey[packageKey]
	const ingredient = if package then Content.Ingredients.ByKey[package.Ingredient] else nil
	if package == nil or ingredient == nil then
		warn(`[MarketController] shelf {anchor:GetFullName()}: unknown Package "{packageKey}"`)
		return nil
	end
	const availability = self.Stock[ingredient.Key]
	const price = package.Price

	local function mode(): ShelfTag.Mode
		if availability() == "Blocked" then
			return "OutOfStock"
		end
		return if self:CanPay(price) then "Price" else "NoCash"
	end

	const unmount, gui = Vide.root(function()
		return ShelfTag({
			Name = "ShelfTag_" .. packageKey,
			Adornee = anchor,
			Visible = function()
				return availability() ~= "Unknown"
			end,
			Mode = mode,
			Text = function()
				return if mode() == "OutOfStock" then Labels.OutOfStock else Labels.Price(price)
			end,
			SubText = function()
				return Labels.UnlockDay(ingredient)
			end,
			StudsOffset = SHELF_OFFSET,
			MaxDistance = SHELF_DISTANCE,
		})
	end)
	return { Gui = gui, Unmount = unmount }
end

function MarketController:MountBench(anchor: Instance, slot: string): Mounted?
	const fitting = self:PlateFitting(anchor, slot)
	const adornee = fitting or anchor
	const offset = if fitting then PLATE_UNDER_FITTING else PLATE_UNDER_PROMPT
	const open = self.KioskOpen

	if slot == SPECIAL_SLOT then
		-- Wave 1: no Bench set, the special slot is always empty (FEAT-015, Q-120; draw in wave 4, FEAT-035).
		const unmount, gui = Vide.root(function()
			return BenchCard({
				Name = "BenchCard_" .. slot,
				Plate = true,
				Adornee = adornee,
				Visible = function()
					return open()
				end,
				Mode = function(): BenchCard.Mode
					return "Empty"
				end,
				Icon = function()
					return ""
				end,
				Badge = function()
					return ""
				end,
				Title = function()
					return ""
				end,
				Detail = function()
					return ""
				end,
				Tag = function()
					return Labels.NothingSpecial
				end,
				Special = function()
					return true
				end,
				StudsOffset = offset,
				MaxDistance = MART.Plate.Distance,
			})
		end)
		return { Gui = gui, Unmount = unmount }
	end

	const upgrade = self:UpgradeAt(slot)
	if upgrade == nil then
		warn(`[MarketController] bench {anchor:GetFullName()}: no upgrade on BenchSlot "{slot}"`)
		return nil
	end
	const level = self.Levels[upgrade.Key]
	const round = self.Dependencies.RoundController
	const badge = Labels.Badge(upgrade)

	const unmount, gui = Vide.root(function()
		const view = Vide.derive(function(): View
			return self:BenchView(upgrade, round.Vehicle(), level())
		end)
		return BenchCard({
			Name = "BenchCard_" .. slot,
			Plate = true,
			Adornee = adornee,
			Visible = function()
				return view().Visible and open()
			end,
			Mode = function()
				return view().Mode
			end,
			-- AST-071 renders do not exist yet (Q-152): placeholder tile with the upgrade initial.
			Icon = function()
				return ""
			end,
			Badge = function()
				return badge
			end,
			Title = function()
				return view().Title
			end,
			Detail = function()
				return view().Detail
			end,
			Tag = function()
				return view().Tag
			end,
			StudsOffset = offset,
			MaxDistance = MART.Plate.Distance,
		})
	end)
	return { Gui = gui, Unmount = unmount }
end

-- Gear Stand ------------------------------------------------------------------------------------------------------

-- Prompt anchor of a slot, mounted or not (Interactable + BenchSlot in the Workspace).
function MarketController:SlotAnchor(slot: string): Instance?
	const mounted = self:BenchAnchor(slot)
	if mounted then
		return mounted
	end
	for _, anchor in CollectionService:GetTagged(TAG) do
		if anchor:GetAttribute("BenchSlot") == slot and anchor:IsDescendantOf(workspace) then
			return anchor
		end
	end
	return nil
end

-- Re-binds the miniature of a slot to its pedestal / prompt anchor and re-hangs the plate (the pedestal may carry
-- the Price_Anchor that the plate was missing).
function MarketController:Rebind(slot: string)
	const anchor = self:SlotAnchor(slot)
	self.Minis:Bind(slot, self.Pedestals[slot], anchor)
	if anchor and self.Mounted[anchor] then
		self:Remove(anchor)
		self:Add(anchor)
	end
end

function MarketController:AddPedestal(pedestal: Instance)
	const slot = pedestal:GetAttribute(MART.Tags.Slot)
	if typeof(slot) ~= "string" or self.Minis.Slots[slot] == nil then
		warn(`[MarketController] GearPedestal {pedestal:GetFullName()}: Slot "{tostring(slot)}" is not a Content.Mart pedestal`)
		return
	end
	if not pedestal:IsDescendantOf(workspace) or self.Pedestals[slot] == pedestal then
		return
	end
	self.Pedestals[slot] = pedestal
	self:Rebind(slot)
end

function MarketController:RemovePedestal(pedestal: Instance)
	for slot, current in self.Pedestals do
		if current == pedestal then
			self.Pedestals[slot] = nil
			self:Rebind(slot)
		end
	end
end

-- Shutter state from the Shift phase; the first record snaps, later changes animate (with the shutter SFX).
function MarketController:ApplyPhase(phase: string, ready: boolean)
	const open = not KIOSK_CLOSED[phase]
	const animate = self.KioskSynced
	const changed = Vide.untrack(self.KioskOpen) ~= open
	self.KioskSynced = ready
	self.KioskOpen(open)
	self.Kiosk:Set(open, animate)
	if animate and changed then
		const _, host = self.Minis:Where(MART.Pedestals[1].Slot)
		if host then
			self:Cue(if open then DOOR_UP_SFX else DOOR_DOWN_SFX, host)
		end
	end
end

-- One Vide effect per pedestal (inside the OnStart root): its miniature target follows the vehicle and the level.
-- S1 is always empty until the FEAT-035 special set exists (wave 4).
function MarketController:WatchMinis()
	const round = self.Dependencies.RoundController
	for _, row in MART.Pedestals do
		const slot = row.Slot
		const upgrade = if row.Offer == "Upgrade" then self:UpgradeAt(slot) else nil
		if upgrade == nil then
			self.Minis:Set(slot, { State = "Empty", Part = "", Vehicle = "", Badge = "" })
			continue
		end
		const level = self.Levels[upgrade.Key]
		Vide.effect(function()
			const target = self:MiniTarget(upgrade, round.Vehicle(), level())
			Vide.untrack(function()
				self.Minis:Set(slot, target)
				return nil
			end)
		end)
	end
end

function MarketController:WatchKiosk()
	const pedestalTag = MART.Tags.Pedestal
	CollectionService:GetInstanceAddedSignal(pedestalTag):Connect(function(pedestal)
		self:AddPedestal(pedestal)
	end)
	CollectionService:GetInstanceRemovedSignal(pedestalTag):Connect(function(pedestal)
		self:RemovePedestal(pedestal)
	end)
	for _, pedestal in CollectionService:GetTagged(pedestalTag) do
		self:AddPedestal(pedestal)
	end

	const shutterTag = MART.Tags.Shutter
	CollectionService:GetInstanceAddedSignal(shutterTag):Connect(function(model)
		self.Kiosk:Add(model)
	end)
	CollectionService:GetInstanceRemovedSignal(shutterTag):Connect(function(model)
		self.Kiosk:Remove(model)
	end)
	for _, model in Kiosk.Tagged() do
		self.Kiosk:Add(model)
	end

	for _, row in MART.Pedestals do
		self:Rebind(row.Slot)
	end

	-- The map streams in after boot: fallback shutters only once the binding is ready.
	if MapIndex.WaitReady(MAP_WAIT) then
		const anchors: { [string]: Instance } = {}
		for _, row in MART.Pedestals do
			const anchor = self:SlotAnchor(row.Slot)
			if anchor then
				anchors[row.Slot] = anchor
			end
			self:Rebind(row.Slot)
		end
		self.Kiosk:Fallback(anchors)
	end
end

function MarketController:Step()
	const now = os.clock()
	const dt = math.min(now - self.LastStep, 0.25)
	self.LastStep = now
	if now - self.LastRelocate >= RELOCATE_EVERY then
		self.LastRelocate = now
		self.Minis:Relocate()
	end
	self.Kiosk:Step(now)
	const camera = workspace.CurrentCamera
	if camera then
		self.Minis:Step(now, dt, camera.CFrame.Position, Vide.untrack(self.KioskOpen))
	end
end

function MarketController:Add(anchor: Instance)
	const gui = self.Gui
	if gui == nil or self.Mounted[anchor] or not anchor:IsDescendantOf(workspace) then
		return
	end
	const package = anchor:GetAttribute("Package")
	const slot = anchor:GetAttribute("BenchSlot")
	local mounted: Mounted? = nil
	if typeof(package) == "string" and package ~= "" then
		mounted = self:MountShelf(anchor, package)
	elseif typeof(slot) == "string" and slot ~= "" then
		mounted = self:MountBench(anchor, slot)
		-- the miniature falls back to the prompt anchor when the slot has no pedestal
		self.Minis:Bind(slot, self.Pedestals[slot], anchor)
	end
	if mounted then
		mounted.Gui.Parent = gui
		self.Mounted[anchor] = mounted
	end
end

function MarketController:Remove(anchor: Instance)
	const mounted = self.Mounted[anchor]
	if mounted == nil then
		return
	end
	self.Mounted[anchor] = nil
	mounted.Unmount()
	mounted.Gui:Destroy()
end

function MarketController:Watch(gui: Instance)
	self.Gui = gui
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(anchor)
		self:Add(anchor)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(anchor)
		self:Remove(anchor)
	end)
	for _, anchor in CollectionService:GetTagged(TAG) do
		self:Add(anchor)
	end
end

MarketController:OnInit(function(self)
	self:Setup()

	const net = self.Libs.Net

	const applyCash = function(id: number, record: { Cash: number, Drawer: number })
		if id == ECONOMY_ID then
			Vide.batch(function()
				self.Cash(record.Cash)
				self.CashReady(true)
			end)
		end
	end
	net.Economy:onAdded(applyCash)
	net.Economy:onChanged(applyCash)
	net.Economy:onRemoved(function(id)
		if id == ECONOMY_ID then
			self.CashReady(false)
		end
	end)

	const applyLevel = function(id: number, record: { Level: number })
		const upgrade = Content.Upgrades.List[id]
		if upgrade then
			-- OnLevel first: a purchase must be marked before the miniature target changes
			self:OnLevel(upgrade, record.Level)
			self.Levels[upgrade.Key](record.Level)
		end
	end
	net.Upgrades:onAdded(applyLevel)
	net.Upgrades:onChanged(applyLevel)
	net.Upgrades:onRemoved(function(id)
		const upgrade = Content.Upgrades.List[id]
		if upgrade then
			self.Levels[upgrade.Key](UNKNOWN_LEVEL)
			self.LastLevel[upgrade.Key] = UNKNOWN_LEVEL
		end
	end)

	const applyStock = function(id: number, record: { Amount: number, Capacity: number, Blocked: boolean })
		const ingredient = Content.Ingredients.List[id]
		if ingredient then
			self.Stock[ingredient.Key](if record.Blocked then "Blocked" else "Open")
		end
	end
	net.Stock:onAdded(applyStock)
	net.Stock:onChanged(applyStock)
	net.Stock:onRemoved(function(id)
		const ingredient = Content.Ingredients.List[id]
		if ingredient then
			self.Stock[ingredient.Key]("Unknown")
		end
	end)
end)

MarketController:OnStart(function(self)
	-- swap guard: remember when Shift.Vehicle changes (the first run is the initial value, not a swap)
	const round = self.Dependencies.RoundController
	local first = true
	self.Unmount = Vide.root(function()
		Vide.effect(function()
			round.Vehicle()
			if first then
				first = false
				return
			end
			self.SwappedAt = os.clock()
		end)
		-- Gear Stand shutter follows the Shift phase (snap until the first record, animate afterwards)
		Vide.effect(function()
			const phase = round.Phase()
			const ready = round.Ready()
			Vide.untrack(function()
				self:ApplyPhase(phase, ready)
				return nil
			end)
		end)
		self:WatchMinis()
	end)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
		self:WatchKiosk()
	end)
end)

MarketController:OnTick(function(self)
	self:Step()
end, TICK_RATE)

return MarketController
