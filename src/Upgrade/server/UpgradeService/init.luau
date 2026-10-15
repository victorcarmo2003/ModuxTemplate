--!strict
-- Upgrade levels per vehicle, effects and visible pieces (FEAT-015; upgrades.md; DEC-046, DEC-052, DEC-101, DEC-106,
-- DEC-184; architecture.md §3.1, §18.4 T38; network.md §3.7, §4.2; data.md §2.2, §3.3; content-data.md §3.7;
-- TASK-035). Run place only. Single writer of the Upgrades set (record id = Content.Upgrades.IndexOf[key]).
-- No prompt of its own (DEC-101): the Mart bench (MarketService, TASK-036) calls Buy. Others read:
--   GetEffect(stat, vehicle?)   absolute value of an upgrade Stat on the current vehicle (KitchenService, Customer...)
--   GetLevel(key, vehicle?)     level, nil when the upgrade does not exist on that vehicle (Trailer Lights on the cart)
--   NextLevel(key)              row that the bench sells next on the current vehicle, nil when maxed / not there
--   CanBuy(key) / Buy(key, player?)   validation and atomic purchase through EconomyService:Spend
--   Changed(key, level, vehicle) signal after every level change (purchase or restore), for slot/capacity owners
--   SetVehicle(vehicle)         VehicleService (wave 2) on the cart -> trailer swap: the set is rewritten in one batch
-- State keeps Levels[vehicle][upgrade] for every vehicle (DEC-184); the set shows only the current vehicle, with
-- Level = 0 for an upgrade that does not exist there (network.md §3.7, wave 1). Snapshot "Upg" keeps both vehicles.
-- TASK-144 (FEAT-037; Q-178 A, Q-179 a): Scope "Pad" upgrades (Patio Tables, Patio Lights) hold one level for the
-- whole Pad: SetLevel and Restore write it on every vehicle where the upgrade exists, so the swap keeps it. SoldAt
-- "InPlace" upgrades are bought by SeatingService (Buy with quiet = true: it sends its own notice); Requires = another
-- upgrade's minimum level on the current vehicle ("locked" until then).
-- Gear Stand cooldown (user feedback 2026-10-11; Q-203 Provisional): a Bench upgrade bought on the stand leaves its
-- line (vehicle + upgrade key) off sale for Content.Mart.Cooldown.Turns shifts counting the current one: bought in
-- shift T, it comes back when shift T + Turns starts, so one whole shift (T + 1) passes in between. Other lines stay
-- free. State: Turn (shift counter, +1 per new shift identity, so a repeated night does not count) and Cooldown
-- ["vehicle/key"] = Turn when the line returns. Both ride in the snapshot "UpgCd" (a lost night undoes the purchase and
-- its cooldown). The set carries the shifts left (Upgrades.Wait, 0 = on sale). InPlace upgrades (Patio) are exempt, and
-- so is a Bench line with Cooldown = false (Counter, DEC-241).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Pieces = require(script.Pieces)
local Modux = require(ServerScriptService.server.Modux)

-- Why a purchase was refused. "not_enough_cash" already sent the Notice to the buyer (EconomyService:Spend).
export type Reason = "unknown" | "not_on_vehicle" | "maxed" | "locked" | "cooldown" | "busy" | "not_enough_cash"

-- [vehicle][upgrade key] = level. Frozen: the atom holds immutable tables.
export type Levels = { [string]: { [string]: number } }

const LEVEL_MIN = 0 -- Upgrades.Level wire range (network.md §3.7)
const LEVEL_MAX = 9
const WAIT_MAX = 255 -- Upgrades.Wait wire range
const COOLDOWN_TURNS = Content.Mart.Cooldown.Turns
const BUY_ACTION = "bench_buy_upgrade"
const BOUGHT_NOTICE = "upgrade_bought"
-- Provisional (TASK-035, T035-06): after a purchase the same upgrade is refused for one bench hold. A second player
-- who started holding "Cooler 2" before the first purchase landed finishes within this window and must not buy
-- Cooler 3 by accident; any later hold already saw the new prompt. The Interact packet carries no level to compare.
const BUY_GUARD = Content.Actions.ByKey[BUY_ACTION].Hold

local function fail(message: string)
	if RunService:IsStudio() then
		error(message, 0)
	end
	warn(message)
end

-- Level row of an upgrade on a vehicle
local function rowOf(upgrade: Content.Upgrade, vehicle: string, level: number): Content.UpgradeLevel?
	const rows = upgrade.Levels[vehicle]
	if rows == nil then
		return nil
	end
	for _, row in rows do
		if row.Level == level then
			return row
		end
	end
	return nil
end

local function existsOn(upgrade: Content.Upgrade, vehicle: string): boolean
	return table.find(upgrade.Vehicles, vehicle) ~= nil and upgrade.Levels[vehicle] ~= nil
end

-- Every vehicle at StartLevel (the trailer starts over, DEC-184)
local function startLevels(): Levels
	const out: Levels = {}
	for _, vehicle in Content.Vehicles.Keys do
		const levels: { [string]: number } = {}
		for _, upgrade in Content.Upgrades.List do
			if existsOn(upgrade, vehicle) then
				levels[upgrade.Key] = upgrade.StartLevel
			end
		end
		out[vehicle] = table.freeze(levels)
	end
	return table.freeze(out)
end

const UpgradeService = Modux.Service("UpgradeService", {
	Require = { "PlaceService", "NetService", "RunStateService", "RoundService", "EconomyService" },
	Priority = 630,
})

function UpgradeService:Setup()
	self.Vehicle = self.Libs.Charm.atom(Content.RunParams.StartVehicle) :: Charm.Atom<string>
	self.Levels = self.Libs.Charm.atom(startLevels()) :: Charm.Atom<Levels>
	-- "vehicle/key" -> os.clock() of the last purchase (BUY_GUARD)
	self.BoughtAt = {} :: { [string]: number }
	-- Gear Stand cooldown: shift counter, identity of the last shift seen and "vehicle/key" -> Turn of the return
	self.Turn = self.Libs.Charm.atom(1) :: Charm.Atom<number>
	self.ShiftKey = "" :: string
	self.Cooldown = self.Libs.Charm.atom({} :: { [string]: number }) :: Charm.Atom<{ [string]: number }>
	-- Created here so lower-priority services (Vehicle 620, Market 615, Customer 590) connect in their OnInit
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<string, number, string>
end

-- Reads -----------------------------------------------------------------------------------------------------------

function UpgradeService:GetVehicle(): string
	return self.Vehicle()
end

-- Level of `key` on `vehicle` (default: current). nil when the upgrade does not exist on that vehicle.
function UpgradeService:GetLevel(key: string, vehicle: string?): number?
	const levels = self.Levels()[vehicle or self.Vehicle()]
	return if levels then levels[key] else nil
end

-- Row of the current level (Effects, Part) on `vehicle` (default: current)
function UpgradeService:CurrentRow(key: string, vehicle: string?): Content.UpgradeLevel?
	const upgrade = Content.Upgrades.ByKey[key]
	const target = vehicle or self.Vehicle()
	const level = self:GetLevel(key, target)
	if upgrade == nil or level == nil then
		return nil
	end
	return rowOf(upgrade, target, level)
end

-- What the bench sells next on `vehicle` (default: current; Price, Effects). nil = maxed or not on this vehicle.
function UpgradeService:NextLevel(key: string, vehicleKey: string?): Content.UpgradeLevel?
	const upgrade = Content.Upgrades.ByKey[key]
	const vehicle = vehicleKey or self.Vehicle()
	const level = self:GetLevel(key, vehicle)
	if upgrade == nil or level == nil then
		return nil
	end
	return rowOf(upgrade, vehicle, level + 1)
end

function UpgradeService:IsMaxed(key: string): boolean
	return self:GetLevel(key) ~= nil and self:NextLevel(key) == nil
end

-- Absolute value of an upgrade Stat (content-data.md §3.7) on `vehicle` (default: current). An upgrade that does not
-- exist on the vehicle counts with its "no upgrade" row (first row of its first vehicle: Trailer Lights on the cart
-- = LightRadius 0, DayFlowBonus 1). A Stat no upgrade touches is a programmer error (0 outside Studio).
function UpgradeService:GetEffect(stat: string, vehicle: string?): number
	if not Content.Stats.Has[stat] then
		fail(`[UpgradeService] GetEffect: {stat} is not a key of Content.Stats`)
		return 0
	end
	const key = stat :: Content.Stat
	const target = vehicle or self.Vehicle()
	const levels = self.Levels()[target] or {}
	local fallback: number? = nil
	for _, upgrade in Content.Upgrades.List do
		const level = levels[upgrade.Key]
		-- Content.Mode (owner request 2026-10-14): a day-only upgrade switched off reads its Fixed value when listed
		if level ~= nil and Content.Mode.IsOff(upgrade.Key) and Content.Mode.Fixed[key] ~= nil then
			const row = rowOf(upgrade, target, level)
			if row and row.Effects[key] ~= nil then
				return Content.Mode.Fixed[key]
			end
		end
		if level ~= nil then
			const row = rowOf(upgrade, target, level)
			const value = if row then row.Effects[key] else nil
			if value ~= nil then
				return value
			end
		elseif fallback == nil then
			const home = upgrade.Vehicles[1]
			const rows = if home then upgrade.Levels[home] else nil
			const first = if rows then rows[1] else nil
			if first and first.Effects[key] ~= nil then
				fallback = first.Effects[key]
			end
		end
	end
	if fallback ~= nil then
		return fallback
	end
	fail(`[UpgradeService] GetEffect: no upgrade has the stat {stat}`)
	return 0
end

-- Purchase ----------------------------------------------------------------------------------------------------------

function UpgradeService:GuardKey(key: string): string
	return `{self.Vehicle()}/{key}`
end

-- Shifts left before the line is on sale again on `vehicle` (default: current); 0 = on sale. Bench upgrades only.
function UpgradeService:GetWait(key: string, vehicle: string?): number
	const upgrade = Content.Upgrades.ByKey[key]
	if upgrade == nil or upgrade.SoldAt ~= "Bench" or upgrade.Cooldown == false then
		return 0
	end
	const back = self.Cooldown()[`{vehicle or self.Vehicle()}/{key}`]
	return if back == nil then 0 else math.clamp(back - self.Turn(), 0, WAIT_MAX)
end

-- Everything but the money: upgrade exists on the current vehicle, not maxed, unlocked today, not just bought.
function UpgradeService:CanBuy(key: string): (boolean, Reason?)
	const upgrade = Content.Upgrades.ByKey[key]
	if upgrade == nil then
		return false, "unknown"
	end
	if self:GetLevel(key) == nil then
		return false, "not_on_vehicle" -- "Trailer only" (B5 on the cart)
	end
	if self:NextLevel(key) == nil then
		return false, "maxed"
	end
	if self.Dependencies.RoundService:GetDay() < upgrade.UnlockDay then
		return false, "locked"
	end
	-- anomaly mode (Content.Mode, owner request 2026-10-14): tables, Drawer Lock and Wide Counter are not sold
	if Content.Mode.IsOff(key) then
		return false, "locked"
	end
	-- the Gear Stand is closed until the first shift ends (Content.Mart.FirstShiftClosed, owner request 2026-10-14)
	if upgrade.SoldAt == "Bench" and Content.Mart.FirstShiftClosed(self.Dependencies.RoundService:Info(), self.Dependencies.RoundService:GetPhase()) then
		return false, "locked"
	end
	const requires = upgrade.Requires
	if requires ~= nil and (self:GetLevel(requires.Upgrade) or 0) < requires.Level then
		return false, "locked"
	end
	if self:GetWait(key) > 0 then
		return false, "cooldown" -- sold out until the shift counter reaches the return turn
	end
	const last = self.BoughtAt[self:GuardKey(key)]
	if last ~= nil and os.clock() - last < BUY_GUARD then
		return false, "busy"
	end
	return true, nil
end

-- Atomic: validation, Spend and the level write run without yielding, so two buyers in the same frame are served one
-- after the other and the second sees the new level (T035-06). On success: effect is immediate on the current
-- vehicle, the piece swaps for everyone (server-side visibility) and the party gets "upgrade_bought" (unless `quiet`:
-- the in-place seller sends its own notice, TASK-144).
function UpgradeService:Buy(key: string, player: Player?, quiet: boolean?): (boolean, Reason?)
	const ok, reason = self:CanBuy(key)
	if not ok then
		return false, reason
	end
	const nextRow = self:NextLevel(key) :: Content.UpgradeLevel
	if not self.Dependencies.EconomyService:Spend(nextRow.Price, player) then
		return false, "not_enough_cash"
	end
	self.BoughtAt[self:GuardKey(key)] = os.clock()
	-- Cooldown = false (Counter, DEC-241): bought shift after shift, no rest
	if Content.Upgrades.ByKey[key].SoldAt == "Bench" and Content.Upgrades.ByKey[key].Cooldown ~= false then
		const cooldown = table.clone(self.Cooldown())
		cooldown[self:GuardKey(key)] = self.Turn() + COOLDOWN_TURNS
		self.Cooldown(cooldown)
	end
	self:SetLevel(self.Vehicle(), key, nextRow.Level)
	if not quiet then
		self.Dependencies.RunStateService:Notify("all", BOUGHT_NOTICE, Content.Upgrades.IndexOf[key])
	end
	return true, nil
end

-- Writes ----------------------------------------------------------------------------------------------------------

-- One level by copy; fires Changed. The Charm effect rewrites the set and the pieces. A Scope "Pad" upgrade is
-- written on every vehicle where it exists (TASK-144, Q-179 a); Changed fires for each vehicle that changed.
function UpgradeService:SetLevel(vehicle: string, key: string, level: number)
	const all = self.Levels()
	const current = all[vehicle]
	if current == nil or current[key] == nil or current[key] == level then
		return
	end
	const upgrade = Content.Upgrades.ByKey[key]
	const targets: { string } = if upgrade ~= nil and upgrade.Scope == "Pad" then upgrade.Vehicles else { vehicle }
	const nextAll = table.clone(all)
	const changed: { string } = {}
	for _, target in targets do
		const levels = nextAll[target]
		if levels == nil or levels[key] == nil or levels[key] == level then
			continue
		end
		const copy = table.clone(levels)
		copy[key] = level
		nextAll[target] = table.freeze(copy)
		table.insert(changed, target)
	end
	self.Levels(table.freeze(nextAll))
	for _, target in changed do
		self.Changed:Fire(key, level, target)
	end
end

-- Vehicle swap (VehicleService, wave 2): the set switches to the new vehicle's levels in one batch.
function UpgradeService:SetVehicle(vehicle: string)
	if Content.Vehicles.ByKey[vehicle] == nil then
		fail(`[UpgradeService] SetVehicle: {vehicle} is not a key of Content.Vehicles`)
		return
	end
	if self.Vehicle() == vehicle then
		return
	end
	self.Vehicle(vehicle)
	for key, level in self.Levels()[vehicle] or {} do
		self.Changed:Fire(key, level, vehicle)
	end
end

-- Snapshot "Upg" (data.md §3.3): both vehicles, string keys.
function UpgradeService:Capture(): { [string]: { [string]: number } }
	const out = {}
	for vehicle, levels in self.Levels() do
		out[vehicle] = table.clone(levels)
	end
	return out
end

-- Purchases of the shift are undone (FEAT-015 "Noite perdida / retomada"). Unknown keys and levels without a row are
-- ignored (start level kept), so an old snapshot never writes a level the table does not have.
function UpgradeService:Restore(data: any)
	const restored = table.clone(startLevels())
	if type(data) == "table" then
		for vehicle, levels in restored do
			const saved = data[vehicle]
			if type(saved) ~= "table" then
				continue
			end
			const copy = table.clone(levels)
			for key in levels do
				const upgrade = Content.Upgrades.ByKey[key]
				const value = saved[key]
				if type(value) == "number" and rowOf(upgrade, vehicle, value) ~= nil then
					copy[key] = value
				end
			end
			restored[vehicle] = table.freeze(copy)
		end
	end
	-- Scope "Pad" (TASK-144): one level for every vehicle, the highest one saved (an old snapshot may hold it on the
	-- cart only)
	for _, upgrade in Content.Upgrades.List do
		if upgrade.Scope ~= "Pad" then
			continue
		end
		local level = upgrade.StartLevel
		for _, vehicle in upgrade.Vehicles do
			const levels = restored[vehicle]
			if levels ~= nil and levels[upgrade.Key] ~= nil then
				level = math.max(level, levels[upgrade.Key])
			end
		end
		for _, vehicle in upgrade.Vehicles do
			const levels = restored[vehicle]
			if levels ~= nil and levels[upgrade.Key] ~= nil and levels[upgrade.Key] ~= level then
				const copy = table.clone(levels)
				copy[upgrade.Key] = level
				restored[vehicle] = table.freeze(copy)
			end
		end
	end
	const before = self.Levels()
	self.Levels(table.freeze(restored))
	table.clear(self.BoughtAt)
	for vehicle, levels in restored do
		for key, level in levels do
			if before[vehicle] == nil or before[vehicle][key] ~= level then
				self.Changed:Fire(key, level, vehicle)
			end
		end
	end
end

-- Cooldown (Gear Stand) --------------------------------------------------------------------------------------------

-- A shift starts: +1 on the counter when it is a new shift (a repeated night keeps the same identity).
function UpgradeService:OnShift(info: { Day: number, Night: number, IsNight: boolean })
	const key = `{info.Day}/{info.Night}/{if info.IsNight then 1 else 0}`
	if key == self.ShiftKey then
		return
	end
	if self.ShiftKey ~= "" then
		self.Turn(self.Turn() + 1)
	end
	self.ShiftKey = key
end

-- Dev (/dev market reset): every line on sale again
function UpgradeService:ResetCooldowns()
	self.Cooldown({})
end

-- Dev (/dev market): { vehicle/key = shifts left } of the lines still resting, and the counter
function UpgradeService:CooldownReport(): (number, { [string]: number })
	const out: { [string]: number } = {}
	const turn = self.Turn()
	for name, back in self.Cooldown() do
		if back > turn then
			out[name] = back - turn
		end
	end
	return turn, out
end

function UpgradeService:CaptureCooldown(): { [string]: any }
	return { T = self.Turn(), K = self.ShiftKey, C = table.clone(self.Cooldown()) }
end

function UpgradeService:RestoreCooldown(data: any)
	local turn = 1
	local shiftKey = ""
	const cooldown: { [string]: number } = {}
	if type(data) == "table" then
		if type(data.T) == "number" and data.T == data.T and data.T >= 1 and data.T < 1e6 then
			turn = math.floor(data.T)
		end
		if type(data.K) == "string" then
			shiftKey = data.K
		end
		if type(data.C) == "table" then
			for name, back in data.C do
				if type(name) == "string" and type(back) == "number" and back == back and back < 1e6 then
					cooldown[name] = math.floor(back)
				end
			end
		end
	end
	self.Libs.Charm.batch(function()
		self.Turn(turn)
		self.Cooldown(cooldown)
	end)
	self.ShiftKey = shiftKey
end

-- Pieces ----------------------------------------------------------------------------------------------------------

-- Shows the piece of the current level of its own vehicle, hides the others (DEC-052, T38)
function UpgradeService:RefreshPiece(instance: Instance)
	const piece, problem = Pieces.read(instance)
	if piece == nil then
		warn(`[UpgradeService] UpgradePiece {instance:GetFullName()}: {problem}`)
		return
	end
	if Content.Upgrades.ByKey[piece.Upgrade] == nil then
		warn(`[UpgradeService] UpgradePiece {instance:GetFullName()}: unknown Upgrade "{piece.Upgrade}"`)
		return
	end
	const vehicle = piece.Vehicle or self.Vehicle()
	const level = self:GetLevel(piece.Upgrade, vehicle)
	local visible = level ~= nil and level == piece.Level
	if level ~= nil and not visible then
		-- Levels that share a Part show the same piece (Counter 4 and 5 reuse Counter_L3, DEC-241)
		const upgrade = Content.Upgrades.ByKey[piece.Upgrade]
		const mine = rowOf(upgrade, vehicle, piece.Level)
		const current = rowOf(upgrade, vehicle, level)
		visible = mine ~= nil and current ~= nil and mine.Part ~= "" and mine.Part == current.Part
	end
	Pieces.setVisible(instance, visible)
end

function UpgradeService:RefreshPieces()
	for _, instance in Pieces.all() do
		self:RefreshPiece(instance)
	end
end

-- Network ----------------------------------------------------------------------------------------------------------

-- Set record of each upgrade on the current vehicle (0 where it does not exist, network.md §3.7)
function UpgradeService:Records(): { { Level: number, Wait: number } }
	const levels = self.Levels()[self.Vehicle()] or {}
	const out = {}
	for index, upgrade in Content.Upgrades.List do
		out[index] = {
			Level = math.clamp(levels[upgrade.Key] or 0, LEVEL_MIN, LEVEL_MAX),
			Wait = math.clamp(self:GetWait(upgrade.Key), 0, WAIT_MAX),
		}
	end
	return out
end

UpgradeService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	self.Dependencies.RunStateService:RegisterSnapshot("Upg", function()
		return self:Capture()
	end, function(data, _mode)
		self:Restore(data)
	end)
	self.Dependencies.RunStateService:RegisterSnapshot("UpgCd", function()
		return self:CaptureCooldown()
	end, function(data, _mode)
		self:RestoreCooldown(data)
	end)
	-- ShiftStarted fires before the shift capture, so the snapshot already holds the new counter
	self.Dependencies.RoundService.ShiftStarted:Connect(function(info)
		self:OnShift(info)
	end)
end)

UpgradeService:OnStart(function(self)
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	-- Lync.start already ran (NetService OnStart, priority 1000). Late joiners get the records from the set.
	const net = self.Libs.Net
	for index, record in self:Records() do
		net.Upgrades:add(index, record)
	end
	-- One effect for set and pieces: a purchase, a restore or a vehicle swap all land here in the same frame.
	self.Libs.Charm.effect(function()
		const records = self:Records()
		if self.Dependencies.NetService:IsRunning() then
			for index, record in records do
				net.Upgrades:update(index, record)
			end
		end
		self:RefreshPieces()
	end)

	CollectionService:GetInstanceAddedSignal(Pieces.Tag):Connect(function(instance)
		if instance:IsDescendantOf(workspace) then
			self:RefreshPiece(instance)
		end
	end)
end)

return UpgradeService
