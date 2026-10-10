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
	right after a vehicle swap, which rewrites the levels) plays SFX-064 `buy` on its GEAR WALL card and SFX-065
	`upgrade_done` + 14 confetti on the vehicle in use (heard at the Pad, FEAT-015). Decided SETTLE s after the record,
	so a swap whose Shift.Vehicle lands after the Upgrades records stays silent. Package buys have no event here
	(the Tool arrives through ItemController): SFX-061 is not played by this controller.
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
local Labels = require(script.Labels)
-- shared VFX budget (AST-092 ceiling counts the whole screen)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)

const TAG = "Interactable"
const ECONOMY_ID = 1 -- single record (network.md §1 rule 5)
const SPECIAL_SLOT = "S1"
-- Shelf tag sits under the prompt pill, which is drawn at the anchor itself (Provisional, MAP-01 §7.4).
const SHELF_OFFSET = Vector3.new(0, -1.3, 0)
const SHELF_DISTANCE = 30
-- Card bottom 0.6 stud above its anchor so it never covers the prompt pill (Provisional until the AST-049 fittings
-- are checked in the place).
const CARD_OFFSET = Vector3.new(0, 3.4 / 2 + 0.6, 0)
-- Readable from the Mart door (~36 studs to S1, AST-049 "Leitura").
const BENCH_DISTANCE = 45
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle"
const SETTLE = 0.5 -- s before an upgrade sound is decided (swap guard)
const SWAP_GUARD = 2 -- s: level changes this close to a vehicle swap are the swap, not a purchase
const CONFETTI = 14 -- AST-092 upgrade Emit(14)
const NEVER = -1e9 -- SwappedAt before any swap

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

-- Upgrade level change: +1 on the same vehicle, away from a swap = a purchase (presentation only).
function MarketController:OnLevel(upgrade: Content.Upgrade, level: number)
	const previous = self.LastLevel[upgrade.Key] or UNKNOWN_LEVEL
	self.LastLevel[upgrade.Key] = level
	if previous == UNKNOWN_LEVEL or level ~= previous + 1 then
		return
	end
	const round = self.Dependencies.RoundController
	const vehicle = Vide.untrack(round.Vehicle)
	const at = os.clock()
	task.delay(SETTLE, function()
		if Vide.untrack(round.Vehicle) ~= vehicle or at - self.SwappedAt < SWAP_GUARD then
			return
		end
		const bench = self:BenchAnchor(upgrade.BenchSpot)
		if bench then
			self:Cue("buy", bench)
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

-- `Price_Anchor_<Slot>` inside the anchor's owner (nearest Model ancestor, architecture.md §18.3/§18.4); the prompt
-- anchor itself when the fitting is missing (bind_map01 logs it as a warning).
function MarketController:CardAdornee(anchor: Instance, slot: string): Instance
	const owner = anchor:FindFirstAncestorWhichIsA("Model")
	const fitting = if owner then owner:FindFirstChild("Price_Anchor_" .. slot, true) else nil
	if fitting and (fitting:IsA("Attachment") or fitting:IsA("BasePart")) then
		return fitting
	end
	return anchor
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
	const adornee = self:CardAdornee(anchor, slot)

	if slot == SPECIAL_SLOT then
		-- Wave 1: no Bench set, the special slot is always empty (FEAT-015, Q-120; draw in wave 4, FEAT-035).
		const unmount, gui = Vide.root(function()
			return BenchCard({
				Name = "BenchCard_" .. slot,
				Adornee = adornee,
				Visible = function()
					return true
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
				StudsOffset = CARD_OFFSET,
				MaxDistance = BENCH_DISTANCE,
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
			Adornee = adornee,
			Visible = function()
				return view().Visible
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
			StudsOffset = CARD_OFFSET,
			MaxDistance = BENCH_DISTANCE,
		})
	end)
	return { Gui = gui, Unmount = unmount }
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
			self.Levels[upgrade.Key](record.Level)
			self:OnLevel(upgrade, record.Level)
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
	end)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return MarketController
