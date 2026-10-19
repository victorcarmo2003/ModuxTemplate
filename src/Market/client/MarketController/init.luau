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
	  * shutters (Kiosk.luau): follow the business hours (owner request 2026-10-17, Content.Mart.Hours): the server's
	    GearStandService publishes the Workspace attribute Hours.Attributes.Open; up while it is true (and outside the
	    Day 1 FirstShiftClosedPhases). Each change plays the metal door SFX (Hours.Sfx) at the middle of the shutters:
	    the Content.Sounds row through AudioController, or the owner's Studio Sound ReplicatedStorage.Assets.SFX
	    [Hours.Assets] while the row has no Id yet. Animated with Mart.Door times and the L -> C -> R stagger; the first record (late
	    joiner) snaps to the final state. Without GearShutter models a test shutter is generated (1 warning);
	  * miniatures (Minis.luau) over the pedestals: the piece of the NEXT level on the current vehicle ("Sale", bob +
	    spin), the current level when maxed (still), the first trailer level at 50% for "Trailer only" (still), none
	    on the empty S1. Frozen with the camera beyond Mart.Mini.ActiveRadius or the shutter down;
	  * plate = GearTag (name, effect, price pill; fixed pixels, AlwaysOnTop, Cream card with Ink outline) FLOATING ABOVE
	    the miniature (user feedback 2026-10-11: the old BenchCard under the glass was unreadable). Adornee = a local
	    invisible part at the miniature centre + Mart.Plate.Lift; without a pedestal it hangs over the prompt anchor.
	    Hidden while the shutter is down. "Sold out" (grey) while the line rests after a purchase;
	  * cooldown (Q-203 Provisional, server-authoritative): Upgrades[].Wait = shifts left; > 0 and a next level exists
	    -> the miniature is gone (Empty), the plate says "Sold out - Back next shift", the prompt is off (server). Back
	    on sale the miniature rises out of the pedestal again;
	  * closing-time hint (Hint.luau): Closing -> Prep with money for a line (or never bought): arrow over the stand,
	    edge pointer when it is off screen; gone on reaching the stand or when Open starts. The toast is the server's
	    Notice "mart_hint" (MarketService);
	  * purchase: the old miniature spins and pops, 14 confetti + SFX-064 `buy` at the pedestal, the next one rises.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local GearTag = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.GearTag)
local Hint = require(script.Hint)
local Kiosk = require(script.Kiosk)
local Labels = require(script.Labels)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local VehicleRoot = require(ReplicatedStorage.shared.Vehicle.VehicleRoot)
local Minis = require(script.Minis)
-- shared VFX budget (AST-092 ceiling counts the whole screen)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)

const TAG = "Interactable"
const ECONOMY_ID = 1 -- single record (network.md §1 rule 5)
const SPECIAL_SLOT = "S1"
const BUN_BAY_TAG = "StockShelf" -- pantry bays (Supply/Shelves.luau)
const BUN_PACKAGE = "pack_buns"
const SETTLE = 0.5 -- s before an upgrade sound is decided (swap guard)
const SWAP_GUARD = 2 -- s: level changes this close to a vehicle swap are the swap, not a purchase
const CONFETTI = 14 -- AST-092 upgrade Emit(14)
const NEVER = -1e9 -- SwappedAt before any swap
const MART = Content.Mart
const TICK_RATE = 60 -- Hz: shutters and miniatures move every frame while visible
const RELOCATE_EVERY = 2 -- s between two re-reads of the pedestal positions (streaming)
const MAP_WAIT = 60 -- s MapIndex.WaitReady may wait before the fallback shutters are generated
-- Plate over the prompt anchor when the slot has no miniature position (the prompt pill sits at the anchor itself)
const PLATE_OVER_PROMPT = Vector3.new(0, 1.6, 0)
const HOURS = MART.Hours
const SFX_HOLD = 6 -- s a Studio fallback door Sound lives before it is cleaned up

export type View = {
	Visible: boolean,
	Mode: GearTag.Mode,
	Title: string,
	Detail: string,
	Tag: string,
}

type Mounted = {
	Gui: BillboardGui,
	Unmount: () -> (),
	Slot: string?, -- bench slot whose plate this is (adornee follows the miniature)
}

const HIDDEN: View = { Visible = false, Mode = "Empty", Title = "", Detail = "", Tag = "" }
const PLATE_PARTS = "GearPlates" -- local Folder in Workspace with the plate adornee parts
const HINT_PHASES: { [string]: boolean } = {}
for _, phase in MART.Hint.Phases do
	HINT_PHASES[phase] = true
end
const BUN_PHASES: { [string]: boolean } = {}
for _, phase in MART.BunHint.Phases do
	BUN_PHASES[phase] = true
end
-- Upgrades record not received yet. A source of an optional type cannot be read with `()` (ambiguous overload).
const UNKNOWN_LEVEL = -1

-- Stock[ingredient].Blocked as seen by the client; Unknown = record not received yet.
type Availability = "Unknown" | "Open" | "Blocked"
-- Gear Stand business hours as published by the server; Unknown = attribute not there yet.
type GearState = "Unknown" | "Open" | "Closed"

const MarketController =
	Modux.Controller(
	"MarketController",
	{ Require = { "RoundController", "AudioController", "TutorialController", "HudController" }, Priority = 680 }
)

function MarketController:Setup()
	-- Party cash (Economy.Cash). Until the first record arrives nothing is drawn red.
	self.Cash = Vide.source(0) :: Vide.Source<number>
	self.CashReady = Vide.source(false) :: Vide.Source<boolean>
	-- Upgrades set: level of the current vehicle per upgrade key; UNKNOWN_LEVEL until the record arrives.
	self.Levels = {} :: { [string]: Vide.Source<number> }
	for _, upgrade in Content.Upgrades.List do
		self.Levels[upgrade.Key] = Vide.source(UNKNOWN_LEVEL)
	end
	-- Upgrades[].Wait per upgrade key: shifts left before the line is on sale again (0 = on sale)
	self.Waits = {} :: { [string]: Vide.Source<number> }
	for _, upgrade in Content.Upgrades.List do
		self.Waits[upgrade.Key] = Vide.source(0)
	end
	-- Economy.Drawer (the closing hint counts cash + drawer)
	self.Drawer = Vide.source(0) :: Vide.Source<number>
	-- bench slot -> local part the plate hangs on
	self.Plates = {} :: { [string]: Part }
	self.Hint = nil :: Hint.Hint?
	self.HintDismissed = false :: boolean
	-- Low-bun Mart hint (Content.Mart.BunHint, 2026-10-17): its own beacon; showing now; reached the door this low spell
	self.BunHint = nil :: Hint.Hint?
	self.BunShown = false :: boolean
	self.BunDismissed = false :: boolean
	self.BunToasted = false :: boolean
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
	-- server business hours (Workspace attribute Hours.Attributes.Open); Unknown = not published yet
	self.GearOpen = Vide.source("Unknown" :: GearState) :: Vide.Source<GearState>
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

function MarketController:CurrentVehicle(): Instance?
	return VehicleRoot.Find(Vide.untrack(self.Dependencies.RoundController.Vehicle))
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
			const frame, size = VehicleRoot.Box(model)
			Fx.Burst(frame.Position + Vector3.new(0, size.Y / 2, 0), "Confetti", CONFETTI)
		end
	end)
end

-- True when the party can pay `price` (or cash is not known yet: no false red on join).
function MarketController:CanPay(price: number): boolean
	return not self.CashReady() or self.Cash() >= price
end

-- A pedestal shared by a day-only and an anomaly-only line (Content.Mode, TASK-324) shows the one on in this mode.
function MarketController:UpgradeAt(slot: string): Content.Upgrade?
	for _, upgrade in Content.Upgrades.List do
		if upgrade.BenchSpot == slot and not Content.Mode.IsOff(upgrade.Key) then
			return upgrade
		end
	end
	return nil
end

-- Pure view of one fixed position (B1..B5) from the current vehicle, its level and the cash.
function MarketController:BenchView(upgrade: Content.Upgrade, vehicle: string, level: number, wait: number): View
	-- anomaly mode (Content.Mode, owner request 2026-10-14): Wide Counter and Drawer Lock are not on the stand
	if Content.Mode.IsOff(upgrade.Key) then
		return HIDDEN
	end
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

	if wait > 0 then
		-- resting after a purchase (Gear Stand cooldown): same card, grey, no price
		return {
			Visible = true,
			Mode = "SoldOut",
			Title = Labels.LevelName(upgrade, nextRow.Level),
			Detail = Labels.SoldOut,
			Tag = Labels.Back(wait),
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
function MarketController:MiniTarget(upgrade: Content.Upgrade, vehicle: string, level: number, wait: number): Minis.Target
	const badge = Labels.Badge(upgrade)
	if Content.Mode.IsOff(upgrade.Key) then
		return { State = "Empty", Part = "", Vehicle = vehicle, Badge = badge } -- anomaly mode: empty pedestal
	end
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
	if nextRow and wait > 0 then
		return { State = "Empty", Part = "", Vehicle = vehicle, Badge = badge } -- sold out: the pedestal is empty
	end
	if nextRow then
		return { State = "Sale", Part = nextRow.Part, Vehicle = vehicle, Badge = badge }
	end
	return { State = "Maxed", Part = if current then current.Part else "", Vehicle = vehicle, Badge = badge }
end

-- Local invisible part of a slot's plate: over the miniature centre (Mart.Plate.Lift), nil while the miniature has no
-- position yet (pedestal not streamed in). Created on demand, moved by SyncPlates.
function MarketController:PlatePart(slot: string): Part?
	const centre = self.Minis:Where(slot)
	if centre == nil then
		return nil
	end
	local part = self.Plates[slot]
	if part == nil or part.Parent == nil then
		const folder = workspace:FindFirstChild(PLATE_PARTS) or Instance.new("Folder")
		folder.Name = PLATE_PARTS
		folder.Parent = workspace
		part = Instance.new("Part")
		const made = part :: Part
		made.Name = "Plate_" .. slot
		made.Anchored = true
		made.CanCollide = false
		made.CanQuery = false
		made.CanTouch = false
		made.CastShadow = false
		made.Transparency = 1
		made.Size = Vector3.one * 0.2
		made.Parent = folder
		self.Plates[slot] = made
	end
	const plate = part :: Part
	plate.Position = centre + Vector3.new(0, MART.Plate.Lift, 0)
	return plate
end

-- Plates follow their miniature (pedestals stream in and out): re-point every mounted bench plate.
function MarketController:SyncPlates()
	for anchor, mounted in self.Mounted do
		const slot = mounted.Slot
		if slot == nil then
			continue
		end
		const part = self:PlatePart(slot)
		mounted.Gui.Adornee = part or anchor
		mounted.Gui.StudsOffsetWorldSpace = if part then Vector3.zero else PLATE_OVER_PROMPT
	end
end

function MarketController:MountBench(anchor: Instance, slot: string): Mounted?
	const open = self.KioskOpen
	const part = self:PlatePart(slot)
	const adornee: Instance = part or anchor

	if slot == SPECIAL_SLOT then
		-- Wave 1: no Bench set, the special slot is always empty (FEAT-015, Q-120; draw in wave 4, FEAT-035).
		const unmount, gui = Vide.root(function()
			return GearTag({
				Name = "GearTag_" .. slot,
				Adornee = adornee,
				Visible = function()
					return open()
				end,
				Mode = function(): GearTag.Mode
					return "Empty"
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
				Width = MART.Plate.Width,
				Offset = if part then Vector3.zero else PLATE_OVER_PROMPT,
				MaxDistance = MART.Plate.Distance,
			})
		end)
		return { Gui = gui, Unmount = unmount, Slot = slot }
	end

	const upgrade = self:UpgradeAt(slot)
	if upgrade == nil then
		warn(`[MarketController] bench {anchor:GetFullName()}: no upgrade on BenchSlot "{slot}"`)
		return nil
	end
	const level = self.Levels[upgrade.Key]
	const wait = self.Waits[upgrade.Key]
	const round = self.Dependencies.RoundController

	const unmount, gui = Vide.root(function()
		const view = Vide.derive(function(): View
			return self:BenchView(upgrade, round.Vehicle(), level(), wait())
		end)
		return GearTag({
			Name = "GearTag_" .. slot,
			Adornee = adornee,
			Visible = function()
				return view().Visible and open()
			end,
			Mode = function()
				return view().Mode
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
			Width = MART.Plate.Width,
			Offset = if part then Vector3.zero else PLATE_OVER_PROMPT,
			MaxDistance = MART.Plate.Distance,
		})
	end)
	return { Gui = gui, Unmount = unmount, Slot = slot }
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

-- Where the stand's door SFX plays: the middle of the shutters, else the first pedestal
function MarketController:StandPoint(): Vector3?
	const center = self.Kiosk:Center()
	if center then
		return center
	end
	const at = self.Minis:Where(MART.Pedestals[1].Slot)
	return at
end

-- Metal door SFX at the stand (Content.Mart.Hours.Sfx). While the Content.Sounds row has no Id, the owner's Studio
-- Sound ReplicatedStorage.Assets.SFX[Hours.Assets] is cloned on a local holder (Sfx SoundGroup when it exists).
function MarketController:DoorCue(open: boolean)
	const at = self:StandPoint()
	if at == nil then
		return
	end
	const key = if open then HOURS.Sfx.Open else HOURS.Sfx.Close
	const row = Content.Sounds.ByKey[key]
	if row and row.Id ~= "" then
		self.Dependencies.AudioController:Play(key, at)
		return
	end
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const folder = if assets then assets:FindFirstChild("SFX") else nil
	const source = if folder then folder:FindFirstChild(if open then HOURS.Assets.Open else HOURS.Assets.Close) else nil
	if source == nil or not source:IsA("Sound") then
		return
	end
	const holder = Instance.new("Part")
	holder.Name = "GearStandSfx"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.CFrame = CFrame.new(at)
	const sound = source:Clone()
	sound.Looped = false
	if row then
		sound.RollOffMaxDistance = row.MaxDistance
	end
	sound.SoundGroup = self.Dependencies.AudioController.Groups.Sfx
	sound.Parent = holder
	holder.Parent = workspace
	sound:Play()
	task.delay(math.max(SFX_HOLD, sound.TimeLength + 0.5), function()
		holder:Destroy()
	end)
end

-- Shutter state from the server's business hours (Workspace attribute) and the Day 1 rule; the first value snaps,
-- later changes animate with the metal door SFX.
function MarketController:ApplyPhase(phase: string, ready: boolean)
	const round = self.Dependencies.RoundController
	-- Day 1: also down in FirstShiftClosedPhases (Content.Mart.FirstShiftClosed, owner request 2026-10-14)
	const info = { Day = Vide.untrack(round.Day), IsNight = Vide.untrack(round.IsNight) }
	const gear = Vide.untrack(self.GearOpen)
	const open = gear == "Open" and not MART.FirstShiftClosed(info, phase)
	const animate = self.KioskSynced
	const changed = Vide.untrack(self.KioskOpen) ~= open
	self.KioskSynced = ready and gear ~= "Unknown"
	self.KioskOpen(open)
	self.Kiosk:Set(open, animate)
	if animate and changed then
		self:DoorCue(open)
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
		const wait = self.Waits[upgrade.Key]
		Vide.effect(function()
			const target = self:MiniTarget(upgrade, round.Vehicle(), level(), wait())
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

-- Closing-time hint ---------------------------------------------------------------------------------------------------

-- A line the party could buy now (level known, next level exists, not resting, unlocked, on this vehicle): its price,
-- the cheapest one. nil = nothing sells. Same rule as MarketService:CheapestOnSale.
function MarketController:CheapestOnSale(): number?
	const round = self.Dependencies.RoundController
	const vehicle = Vide.untrack(round.Vehicle)
	const day = Vide.untrack(round.Day)
	local cheapest: number? = nil
	for _, upgrade in Content.Upgrades.List do
		if
			upgrade.SoldAt ~= "Bench"
			or Content.Mode.IsOff(upgrade.Key)
			or not table.find(upgrade.Vehicles, vehicle)
			or day < upgrade.UnlockDay
		then
			continue
		end
		const level = Vide.untrack(self.Levels[upgrade.Key])
		if level == UNKNOWN_LEVEL or Vide.untrack(self.Waits[upgrade.Key]) > 0 then
			continue
		end
		for _, row in upgrade.Levels[vehicle] or {} do
			if row.Level == level + 1 and (cheapest == nil or row.Price < cheapest) then
				cheapest = row.Price
			end
		end
	end
	return cheapest
end

function MarketController:NeverBought(): boolean
	for _, upgrade in Content.Upgrades.List do
		const level = Vide.untrack(self.Levels[upgrade.Key])
		if upgrade.SoldAt == "Bench" and level ~= UNKNOWN_LEVEL and level > upgrade.StartLevel then
			return false
		end
	end
	return true
end

-- Instance the arrow points at: the first pedestal found, else the first bench prompt anchor.
function MarketController:HintTarget(): Instance?
	for _, row in MART.Pedestals do
		const pedestal = self.Pedestals[row.Slot]
		if pedestal and pedestal.Parent then
			return pedestal
		end
	end
	for _, row in MART.Pedestals do
		const anchor = self:SlotAnchor(row.Slot)
		if anchor then
			return anchor
		end
	end
	return nil
end

-- The pantry bay of the buns (StockShelf, Package pack_buns): the part the low-bun arrow points at (nil = not streamed)
local function bunBay(): BasePart?
	for _, bay in CollectionService:GetTagged(BUN_BAY_TAG) do
		if bay:GetAttribute("Package") == BUN_PACKAGE and bay:IsDescendantOf(workspace) then
			if bay:IsA("BasePart") then
				return bay
			end
			const part = if bay:IsA("Model") then bay.PrimaryPart or bay:FindFirstChildWhichIsA("BasePart", true) else nil
			if part ~= nil then
				return part
			end
		end
	end
	return nil
end

-- Low buns (Content.Mart.BunHint, owner decision 2026-10-17): an arrow to the buns bay of the pantry (DEC-307: the Mart
-- left the map) and one toast per low spell, any day, while the tutorial is not running. Owns the screen over the
-- gear-stand hint.
function MarketController:StepBunHint()
	const hint = self.BunHint
	if hint == nil then
		return
	end
	const rule = MART.BunHint
	const tutorial = self.Dependencies.TutorialController
	const phase = Vide.untrack(self.Dependencies.RoundController.Phase)
	const stock = Vide.untrack(function(): number?
		return tutorial:StockAmount("bun")
	end)
	const low = stock ~= nil and stock <= rule.LowBuns
	if not low then
		self.BunDismissed = false
		self.BunToasted = false
	end
	const tutorialOn = Vide.untrack(function(): boolean
		return tutorial:FirstRun()
	end)
	if not low or tutorialOn or self.BunDismissed or not BUN_PHASES[phase] then
		self.BunShown = false
		hint:Set(false)
		return
	end
	const door = bunBay()
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if door and door:IsA("BasePart") and root and root:IsA("BasePart") then
		if (root.Position - door.Position).Magnitude <= rule.Reach then
			self.BunDismissed = true -- at the pantry: done until the stock goes back up
			self.BunShown = false
			hint:Set(false)
			return
		end
	end
	hint:SetTarget(door)
	hint:Set(door ~= nil)
	self.BunShown = door ~= nil
	if door ~= nil and not self.BunToasted then
		self.BunToasted = true
		self.Dependencies.HudController:PushText("Buns running low! Grab a box in the pantry.", "Info")
	end
end

function MarketController:StepHint()
	const hint = self.Hint
	if hint == nil then
		return
	end
	if self.BunShown then
		hint:Set(false) -- one arrow at a time: the buns first
	end
	const round = self.Dependencies.RoundController
	const phase = Vide.untrack(round.Phase)
	const tutorial = self.Dependencies.TutorialController
	-- Day 1 upgrade lesson (owner request 2026-10-14): the tutorial guides to the Storage pedestal (one arrow at a time)
	const lesson = Vide.untrack(function(): string?
		return tutorial:UpgradeLesson()
	end)
	if lesson ~= nil then
		hint:Set(false)
		return
	end
	if not HINT_PHASES[phase] then
		self.HintDismissed = false -- a new window (next closing) may raise the hint again
		hint:Set(false)
		return
	end
	-- the tutorial owns the guidance on Day 1 (one arrow at a time): no gear-stand hint until it ends or is skipped;
	-- and none while the stand is closed (business hours, Content.Mart.Hours; Day 1 FirstShiftClosed)
	const tutorialOn = Vide.untrack(function(): boolean
		return tutorial:FirstRun()
	end)
	const info = { Day = Vide.untrack(round.Day), IsNight = Vide.untrack(round.IsNight) }
	if tutorialOn or MART.FirstShiftClosed(info, phase) or not Vide.untrack(self.KioskOpen) then
		hint:Set(false)
		return
	end
	if self.HintDismissed or not Vide.untrack(self.CashReady) then
		hint:Set(false)
		return
	end
	const cheapest = self:CheapestOnSale()
	const afford = cheapest ~= nil
		and (Vide.untrack(self.Cash) + Vide.untrack(self.Drawer) >= cheapest or self:NeverBought())
	if not afford then
		hint:Set(false)
		return
	end
	const target = self:HintTarget()
	hint:SetTarget(target)
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local at: Vector3? = nil
	if target and target:IsA("BasePart") then
		at = target.Position
	elseif target and target:IsA("Model") then
		at = target:GetPivot().Position
	end
	if root and root:IsA("BasePart") and at and (root.Position - at).Magnitude <= MART.Hint.Reach then
		self.HintDismissed = true -- reached the stand: done until the next closing
		hint:Set(false)
		return
	end
	hint:Set(target ~= nil) -- the hint moves its own Beacon every frame (Hint.luau)
end

function MarketController:Step()
	const now = os.clock()
	const dt = math.min(now - self.LastStep, 0.25)
	self.LastStep = now
	if now - self.LastRelocate >= RELOCATE_EVERY then
		self.LastRelocate = now
		self.Minis:Relocate()
		self:SyncPlates()
	end
	self:StepBunHint()
	self:StepHint()
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
	const slot = anchor:GetAttribute("BenchSlot")
	local mounted: Mounted? = nil
	if typeof(slot) == "string" and slot ~= "" then
		-- the miniature falls back to the prompt anchor when the slot has no pedestal; bound first so the plate
		-- finds its position
		self.Minis:Bind(slot, self.Pedestals[slot], anchor)
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
				self.Drawer(record.Drawer)
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

	const applyLevel = function(id: number, record: { Level: number, Wait: number })
		const upgrade = Content.Upgrades.List[id]
		if upgrade then
			-- OnLevel first: a purchase must be marked before the miniature target changes
			self:OnLevel(upgrade, record.Level)
			-- one batch: the new level and its cooldown land together (pop, then an empty pedestal)
			Vide.batch(function()
				self.Levels[upgrade.Key](record.Level)
				self.Waits[upgrade.Key](record.Wait)
			end)
		end
	end
	net.Upgrades:onAdded(applyLevel)
	net.Upgrades:onChanged(applyLevel)
	net.Upgrades:onRemoved(function(id)
		const upgrade = Content.Upgrades.List[id]
		if upgrade then
			self.Levels[upgrade.Key](UNKNOWN_LEVEL)
			self.Waits[upgrade.Key](0)
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
	-- business hours published by GearStandService (Workspace attribute; late joiners read it here)
	const readGear = function()
		const value = workspace:GetAttribute(HOURS.Attributes.Open)
		self.GearOpen(if value == true then "Open" elseif value == false then "Closed" else "Unknown")
	end
	readGear()
	workspace:GetAttributeChangedSignal(HOURS.Attributes.Open):Connect(readGear)
	self.Unmount = Vide.root(function()
		Vide.effect(function()
			round.Vehicle()
			if first then
				first = false
				return
			end
			self.SwappedAt = os.clock()
		end)
		-- Gear Stand shutter follows the business hours (snap until the first record, animate afterwards)
		Vide.effect(function()
			const phase = round.Phase()
			const ready = round.Ready()
			round.Day()
			round.IsNight()
			self.GearOpen()
			Vide.untrack(function()
				self:ApplyPhase(phase, ready)
				return nil
			end)
		end)
		self:WatchMinis()
	end)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		self.Hint = Hint.new(playerGui)
		self.BunHint = Hint.new(playerGui)
		self:Watch(playerGui)
		self:WatchKiosk()
	end)
end)

MarketController:OnTick(function(self)
	self:Step()
end, TICK_RATE)

return MarketController
