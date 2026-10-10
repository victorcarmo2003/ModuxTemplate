--!strict
-- Crew classes: buy with gems, select, lock for the run, passive modifiers (FEAT-028; DEC-069, DEC-070, DEC-186).
-- Animal = class (DEC-147): the profile keeps class keys only; Content.Classes[key].Species resolves the animal.
-- Writes Gems, Classes and SelectedClass by copy, never in place (data.md §1.1, §1.2). Single ClassAction responder.
-- Wave 1 runs the Run place in dev mode (no lobby, Q-085): in the Run, Buy and Select are accepted only with
-- PlaceService:IsDev() and only before the class is locked (Provisional, TASK-017; network.md §4.6).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

export type Action = "Buy" | "Select"

-- Situation the caller knows and the class may depend on (Classes.Effect.When).
export type Context = {
	Packages: number?, -- packages in the hotbar (bear, PackagesAtLeast); default 0
	IsNight: boolean?, -- default false (wave 1 has no night)
}

const DEFAULT_CLASS = "class_dog" -- free, owned by every account (DEC-186)
const RATE_MAX = 2 -- ClassAction per player per window (network.md §4.6)
const RATE_WINDOW = 1
const GEMS_MAX = 2147483647 -- Profile.Gems wire range (network.md §4.5)

-- Value of a stat when the class has no effect on it. Stats without an entry need an explicit base.
-- GrillTime is a multiplier (the station multiplies its own time); TipWindow is an offset in seconds added to
-- Orders.TipWindowBase + TipWindowPerK x K (DEC-072). Callers that pass `base` get the effect applied to it.
const DEFAULT_BASE: { [string]: number } = {
	WalkSpeed = Content.RunParams.BaseWalkSpeed, -- 16 (DEC-069)
	GrillTime = 1,
	PackageLimit = Content.ItemRules.CategoryLimits.Package, -- 2 (DEC-049)
	TipAmount = Content.OrderRules.TipAmount, -- $1 (DEC-072)
	TipWindow = 0,
	CoffeeBrewTime = Content.Stations.ByKey.coffee_machine.Params.BrewTime, -- 6 s; Barista 3 (DEC-069)
	CoffeeRestore = Content.Sanity.Coffee, -- 25; Barista 35 (DEC-069)
}

const ClassService = Modux.Service(
	"ClassService",
	{ Require = { "ProfileService", "PlaceService", "NetService" }, Priority = 690 }
)

function ClassService:Setup()
	-- class taken for this run (DEC-069, DEC-186)
	self.Locked = {} :: { [Player]: string }
	self.RateStart = {} :: { [Player]: number }
	self.RateCount = {} :: { [Player]: number }
end

-- In the Run, writes need dev mode (wave 1). The Lobby always accepts them.
function ClassService:CanWrite(): boolean
	const place = self.Dependencies.PlaceService
	return not place:Is("Run") or place:IsDev()
end

function ClassService:Allow(player: Player): boolean
	const now = os.clock()
	const start = self.RateStart[player]
	if start == nil or now - start >= RATE_WINDOW then
		self.RateStart[player] = now
		self.RateCount[player] = 1
		return true
	end
	const count = (self.RateCount[player] or 0) + 1
	self.RateCount[player] = count
	return count <= RATE_MAX
end

-- Direct packet to the owner, not RunStateService:Notify: ClassService also runs in the Lobby (architecture.md §3.1).
function ClassService:Notify(player: Player, kind: string, value: number)
	const net = self.Dependencies.NetService
	if not net:IsRunning() or not net:IsReady(player) then
		return
	end
	self.Libs.Net.Notice:fireClient(player, {
		Kind = kind,
		Value = value,
	})
end

-- Class the player plays with. In the Run the first read locks it until the player leaves: CharacterService reads
-- it at spawn (TASK-018), so Select is refused after that. In the Lobby it is just the current selection.
function ClassService:GetClass(player: Player): string
	const locked = self.Locked[player]
	if locked then
		return locked
	end
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile then
		return DEFAULT_CLASS -- not loaded yet: not locked, the next read decides
	end
	const class = self.Dependencies.ProfileService:SelectedClass(profile)
	if self.Dependencies.PlaceService:Is("Run") then
		self.Locked[player] = class
	end
	return class
end

function ClassService:IsLocked(player: Player): boolean
	return self.Locked[player] ~= nil
end

local function applies(effect: Content.ClassEffect, context: Context?): boolean
	const when = effect.When or "Always"
	if when == "Always" then
		return true
	end
	const isNight = context ~= nil and context.IsNight == true
	if when == "Day" then
		return not isNight
	elseif when == "Night" then
		return isNight
	elseif when == "PackagesAtLeast" then
		const packages = if context and context.Packages then context.Packages else 0
		return packages >= (effect.WhenValue or math.huge)
	end
	return false
end

-- Value of `stat` for the player's class: `base` (or the stat default) with the class effects applied in table
-- order. Wave 1 consumers: WalkSpeed (CharacterService), GrillTime (Kitchen), PackageLimit (Item),
-- TipAmount and TipWindow (Economy/Customer; "own order" = the one he took, Provisional, content-data §3.10).
-- Party-scoped effects (Lion, not in the MVP) are returned for the owner only; spreading them is the reader's job.
function ClassService:GetModifier(player: Player, stat: Content.Stat, base: number?, context: Context?): number
	local value = base or DEFAULT_BASE[stat]
	if value == nil then
		error(`[ClassService] {stat} has no default base: pass one`)
	end
	const class = Content.Classes.ByKey[self:GetClass(player)]
	if not class then
		return value
	end
	for _, effect in class.Effects do
		if effect.Stat ~= stat or not applies(effect, context) then
			continue
		end
		if effect.Op == "Set" then
			value = effect.Value
		elseif effect.Op == "Mul" then
			value *= effect.Value
		elseif effect.Op == "Add" then
			value += effect.Value
		end
	end
	return value
end

function ClassService:Buy(player: Player, key: string)
	const class = Content.Classes.ByKey[key]
	if not class or not class.InMvp then
		return -- forged: only MVP classes are on sale (DEC-186)
	end
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if not profile then
		return
	end
	if profiles:OwnedClasses(profile)[key] then
		return -- already owned: never charge twice
	end
	const gems = profile.Gems()
	if gems < class.Price then
		self:Notify(player, "not_enough_gems", class.Price)
		return
	end

	const classes = table.clone(profile.Classes())
	classes[key] = true
	profiles:Update(player, {
		Gems = gems - class.Price,
		Classes = classes,
	})
	profiles:RequestSave(player)
	self:Notify(player, "class_bought", Content.Classes.IndexOf[key])
end

function ClassService:Select(player: Player, key: string)
	const class = Content.Classes.ByKey[key]
	if not class then
		return
	end
	if self.Locked[player] then
		-- the class is locked for the run (DEC-069, DEC-186); network.md §4.6 answers with class_locked
		self:Notify(player, "class_locked", Content.Classes.IndexOf[key])
		return
	end
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if not profile then
		return
	end
	if not class.InMvp or not profiles:OwnedClasses(profile)[key] then
		self:Notify(player, "class_locked", Content.Classes.IndexOf[key])
		return
	end
	if profile.SelectedClass() == key then
		return
	end

	profile.SelectedClass(key)
	profiles:RequestSave(player)
	self:Notify(player, "class_selected", Content.Classes.IndexOf[key])
end

-- Dev hook for the gems command (TASK-043, R2). Server only, never reachable from the network (T017-11).
-- `amount` may be negative; the balance stays in 0..GEMS_MAX. GemsEarned is not touched (not a real reward).
function ClassService:DevGrantGems(player: Player, amount: number): number
	if not self.Dependencies.PlaceService:IsDev() then
		error("[ClassService] DevGrantGems needs dev mode")
	end
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile then
		error(`[ClassService] {player.Name} has no loaded profile`)
	end
	const gems = math.clamp(profile.Gems() + math.floor(amount), 0, GEMS_MAX)
	profile.Gems(gems)
	self.Dependencies.ProfileService:RequestSave(player)
	return gems
end

ClassService:OnInit(function(self)
	self:Setup()

	self.Libs.Net.ClassAction:onServer(function(data, player: Player)
		if not self:Allow(player) or not self:CanWrite() then
			return
		end
		if data.Action == "Buy" then
			self:Buy(player, data.Class)
		elseif data.Action == "Select" then
			self:Select(player, data.Class)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.Locked[player] = nil
		self.RateStart[player] = nil
		self.RateCount[player] = nil
	end)
end)

return ClassService
