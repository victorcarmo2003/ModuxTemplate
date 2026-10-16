--!strict
-- TutorialService (user request 2026-10-11, Provisional; Q-### "tutorial always on Day 1, never saved"): single
-- responder of `TutorialComplete` (network.md). The tutorial is NOT saved and NOT mandatory: it is pending for every
-- player on Day 1 of the run (normal and infinite mode alike) until that player finishes or skips it (client packet
-- TutorialComplete, idempotent) or the run goes past Day 1 (latched: coming back to Day 1 does not reopen it). State
-- is in memory of this server (one run per server), per UserId; a player who leaves and comes back starts over.
-- The profile field TutorialDone stays in the schema for compatibility with saved data, but nothing reads or writes
-- it any more. Run place only.
-- AnyPending (Provisional, user request 2026-10-11): BossService rings and holds the tutorial call (BossCalls Trigger
-- Tutorial) while a player in the server still has the tutorial ahead.
-- Tutorial customer (Provisional, user request 2026-10-11): `TutorialBegin` from a player with the tutorial pending asks
-- CustomerService for the tutorial customer (one at a time, shared.Tutorial.Rules). Once nobody has the tutorial
-- pending any more (finished, skipped, left), an unserved tutorial customer is sent away (CustomerService:EndTutorial).
-- Shopping lesson (Provisional, user request 2026-10-11; shared.Tutorial.Rules Buns / Package): on the first
-- TutorialBegin while EVERY player in the server is a rookie (a veteran's run is never touched) the bun stock is capped
-- at Rules.Buns (one), so the first sale empties the crate and Walt sends the rookie to the Mart. While the tutorial
-- customer still waits, a hot dog thrown away gives the bun back (never stuck without a bun for the first sale). When
-- the buns run out with a rookie pending, Cash is topped up to the package price (EconomyService:TopUp) so the
-- purchase never stalls on money. Server decides: the client only reads the Stock set.
-- Day 1 stands still for the tutorial (user decision 2026-10-12, Provisional): ShouldHold is the single answer to "the
-- tutorial holds Day 1" and feeds two hooks registered in OnInit: RoundService:SetClockHold (the clock of Prep and Open
-- freezes, so the 30 s Prep cap and the 216 s Open cap cannot run out under the lesson) and
-- CustomerService:SetSpawnHold (no regular customer, adoption or guarantee until it ends). It ends when nobody has the
-- tutorial pending any more (finished, skipped, left) or after Content.Shift.TutorialHoldMax seconds of holding (safety:
-- an AFK rookie never freezes the server for good; latched until DevReset). Co-op: held for everyone while any rookie is
-- still in the tutorial (default; a veteran waits for the rookie).
-- Dev tools (Provisional, user request 2026-10-11; DevService/Commands/Tutorial.luau): DevReset reopens the tutorial for
-- the player in this run, at any day, without touching the profile (the client restarts the tutorial without the intro), DevSend forwards a client-side dev command (voice
-- test, debug panel, step jump) to one player through the dev-only `DevClient` packet. Both refuse outside dev mode.
-- Day 1 upgrade lesson (owner request 2026-10-14, Provisional; shared.Tutorial.Rules.Upgrade): a player who answered
-- the tutorial call on Day 1 is a rookie of this run (Rookies, memory only). When the first shift ends (the day Closing
-- at 6 PM) with a rookie in the server and no Gear Stand line bought yet, ShouldHold also holds the Closing (clock frozen
-- at 6 PM, no probe end), and once the last-call line is empty (the Closing probe) the lesson is "due": Cash is topped up
-- to Rules.Upgrade.Cash (at least the Storage price) and BossService rings Rules.Upgrade.Call once (LessonCallDue). It
-- ends for good (LessonOver, latched) when any Gear Stand line is bought, the run leaves Day 1 / the day shift, no rookie
-- is left, or after Content.Shift.TutorialHoldMax s of holding the Closing (AFK rookie). TutorialController shows the
-- steps and MarketController the arrow (client side reads the Upgrades set and the Boss call).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local TutorialRules = require(ReplicatedStorage.shared.Tutorial.Rules)
local Modux = require(ServerScriptService.server.Modux)
local MetricsLog = require(ServerScriptService.server.Metrics.MetricsService.Log)

const TICK_RATE = 2 -- Hz: the pending check of the tutorial customer
const HOT_DOG = "hot_dog"
const PACKAGE = Content.Packages.ByKey[TutorialRules.Package]
const BUN = if PACKAGE then PACKAGE.Ingredient else "bun"

const TutorialService = Modux.Service(
	"TutorialService",
	{
		Require = {
			"PlaceService",
			"CustomerService",
			"KitchenService",
			"EconomyService",
			"RoundService",
			"UpgradeService",
		},
		Priority = 500,
	}
)

function TutorialService:Setup()
	self.Enabled = false :: boolean
	-- a tutorial customer was asked and the tutorial may still be running for someone
	self.Asked = false :: boolean
	-- the tutorial stock (Rules.Buns) was applied in this server
	self.Seeded = false :: boolean
	-- UserId -> finished or skipped in this run (memory only, never saved)
	self.Closed = {} :: { [number]: boolean }
	-- UserId -> reopened by /dev tutorial reset: ignores the day gate until it ends again
	self.Revived = {} :: { [number]: boolean }
	-- the run went past Day 1 (latched)
	self.Past = false :: boolean
	-- os.clock() when the current hold began (0 = not holding); HoldExpired = the safety timeout ran out (latched)
	self.HoldSince = 0 :: number
	self.HoldExpired = false :: boolean
	-- Day 1 upgrade lesson: UserId -> answered the tutorial call this run; lesson over (latched); the call / cash went
	-- out; os.clock() the Closing hold began (0 = not holding)
	self.Rookies = {} :: { [number]: boolean }
	self.LessonOver = false :: boolean
	self.LessonRung = false :: boolean
	self.LessonSince = 0 :: number
end

-- The player finished or skipped the tutorial: over for this run (idempotent, not saved)
function TutorialService:Complete(player: Player)
	if not self.Closed[player.UserId] then
		-- onboarding funnel, last step (analytics; the steps in between come from MetricTutorial)
		MetricsLog.onboarding(player, #Content.Metrics.TutorialSteps + 2, "complete")
	end
	self.Closed[player.UserId] = true
	self.Revived[player.UserId] = nil
end

-- Day 1 of the run still on (latches off once the day moves on or a night shift starts)
function TutorialService:OnDayOne(): boolean
	if not self.Past then
		const round = self.Dependencies.RoundService
		if round:GetDay() > 1 or round:IsNight() then
			self.Past = true
		end
	end
	return not self.Past
end

-- A player in the server still has the tutorial ahead: Day 1 of the run and not finished / skipped (or reopened by dev)
function TutorialService:IsPending(player: Player): boolean
	if player.Parent == nil or self.Closed[player.UserId] then
		return false
	end
	return self.Revived[player.UserId] == true or self:OnDayOne()
end

-- Why the tutorial is not pending for the player (dev messages), nil = pending
function TutorialService:Reason(player: Player): string?
	if self:IsPending(player) then
		return nil
	end
	if self.Closed[player.UserId] then
		return "done or skipped this run"
	end
	return `day {self.Dependencies.RoundService:GetDay()} is past day 1`
end

function TutorialService:AnyPending(): boolean
	for _, player in Players:GetPlayers() do
		if self:IsPending(player) then
			return true
		end
	end
	return false
end

-- Every player in the server has a loaded profile with the tutorial ahead (a tutorial run)
function TutorialService:AllPending(): boolean
	const players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		if not self:IsPending(player) then
			return false
		end
	end
	return true
end

-- Cash up to the package price while a rookie has the shopping lesson ahead
function TutorialService:EnsureCash()
	if PACKAGE ~= nil and self.Seeded and self:AnyPending() then
		self.Dependencies.EconomyService:TopUp(PACKAGE.Price)
	end
end

-- Tutorial stock: the bun stock capped at Rules.Buns, once per server, only in a run of rookies
function TutorialService:Seed()
	if self.Seeded or not self:AllPending() then
		return
	end
	self.Seeded = true
	const kitchen = self.Dependencies.KitchenService
	const amount = kitchen:GetStock(BUN)
	if amount > TutorialRules.Buns then
		kitchen:SetAmount(BUN, TutorialRules.Buns)
	end
	self:EnsureCash()
end

-- A hot dog thrown away while the tutorial customer still waits: the bun comes back (the first sale never stalls)
function TutorialService:OnDiscarded(item: string)
	if not self.Seeded or item ~= HOT_DOG or not self:AnyPending() then
		return
	end
	if not self.Dependencies.CustomerService:HasTutorial() then
		return
	end
	const kitchen = self.Dependencies.KitchenService
	if kitchen:GetStock(BUN) < TutorialRules.Buns then
		kitchen:SetAmount(BUN, TutorialRules.Buns)
	end
end

-- A rookie started the tutorial (answered the call): the tutorial customer comes
function TutorialService:Begin(player: Player)
	if not self:IsPending(player) then
		return
	end
	if not self.Rookies[player.UserId] then
		MetricsLog.onboarding(player, 1, "begin") -- onboarding funnel, step 1 (analytics)
	end
	self.Rookies[player.UserId] = true
	self:Seed()
	if self.Dependencies.CustomerService:RequestTutorial() then
		self.Asked = true
	end
end

-- Upgrade lesson ------------------------------------------------------------------------------------------------

-- Any Gear Stand line above its start level on the current vehicle (the first upgrade was bought)
function TutorialService:BoughtGear(): boolean
	const upgrades = self.Dependencies.UpgradeService
	for _, upgrade in Content.Upgrades.List do
		const level = if upgrade.SoldAt == "Bench" then upgrades:GetLevel(upgrade.Key) else nil
		if level ~= nil and level > upgrade.StartLevel then
			return true
		end
	end
	return false
end

-- A rookie of this run is in the server
function TutorialService:AnyRookie(): boolean
	for _, player in Players:GetPlayers() do
		if self.Rookies[player.UserId] then
			return true
		end
	end
	return false
end

-- The upgrade lesson runs now: the day Closing of Day 1, a rookie around, nothing bought yet (latches off for good)
function TutorialService:LessonActive(): boolean
	if not self.Enabled or self.LessonOver then
		return false
	end
	const round = self.Dependencies.RoundService
	if round:GetDay() > 1 or round:IsNight() then
		self.LessonOver = true
		return false
	end
	if round:GetPhase() ~= "Closing" or not self:AnyRookie() then
		return false
	end
	if self:BoughtGear() then
		self.LessonOver = true
		return false
	end
	return true
end

-- The last-call line is empty: Walt may call (BossService polls this; the call is Once)
function TutorialService:LessonCallDue(): boolean
	return self:LessonActive() and self.Dependencies.RoundService:ProbeSaysEnd("Closing")
end

-- Cash up to Rules.Upgrade.Cash (never below the price of the lesson's level) once the call goes out
function TutorialService:LessonCash()
	const row = self.Dependencies.UpgradeService:NextLevel(TutorialRules.Upgrade.Key)
	if row == nil then
		return
	end
	if self.Dependencies.EconomyService:GetCash() < row.Price then
		self.Dependencies.EconomyService:TopUp(math.max(TutorialRules.Upgrade.Cash, row.Price))
	end
end

function TutorialService:StepLesson()
	if self.LessonRung or not self:LessonCallDue() then
		return
	end
	self.LessonRung = true
	self:LessonCash()
end

-- The Closing of Day 1 stands still for the lesson (own safety timer: an AFK rookie never freezes the server)
function TutorialService:LessonHold(): boolean
	if not self:LessonActive() then
		self.LessonSince = 0
		return false
	end
	const t = os.clock()
	if self.LessonSince <= 0 then
		self.LessonSince = t
	elseif t - self.LessonSince > Content.Shift.TutorialHoldMax then
		self.LessonOver = true
		self.LessonSince = 0
		warn(`[TutorialService] Day 1 upgrade lesson held {Content.Shift.TutorialHoldMax} s: released (safety timeout)`)
		return false
	end
	return true
end

-- Day 1 stands still for the tutorial: a day shift in Prep or Open with someone still in the tutorial, or the day
-- Closing of the upgrade lesson
function TutorialService:ShouldHold(): boolean
	if not self.Enabled then
		return false
	end
	if self:LessonHold() then
		return true
	end
	if self.HoldExpired then
		return false
	end
	const round = self.Dependencies.RoundService
	const phase = round:GetPhase()
	if round:IsNight() or (phase ~= "Prep" and phase ~= "Open") or not self:AnyPending() then
		self.HoldSince = 0
		return false
	end
	const t = os.clock()
	if self.HoldSince <= 0 then
		self.HoldSince = t
	elseif t - self.HoldSince > Content.Shift.TutorialHoldMax then
		self.HoldExpired = true
		self.HoldSince = 0
		warn(`[TutorialService] Day 1 held {Content.Shift.TutorialHoldMax} s: released (safety timeout)`)
		return false
	end
	return true
end

-- Dev hooks ---------------------------------------------------------------------------------------------------------

function TutorialService:DevCheck(name: string)
	if not self.Dependencies.PlaceService:IsDev() then
		error(`[TutorialService] {name} is dev mode only`, 3)
	end
	if not self.Enabled then
		error(`[TutorialService] {name}: not the Run place`, 3)
	end
end

-- A client-side dev command for `player` (TutorialController runs it)
function TutorialService:DevSend(player: Player, command: string, text: string?)
	self:DevCheck("DevSend")
	self.Libs.Net.DevClient:fireClient(player, {
		Command = string.sub(command, 1, 32),
		Text = string.sub(text or "", 1, 200),
	})
end

-- Tutorial reopened for `player` in this run (memory only), the tutorial customer and the tutorial stock start over; the client is
-- told to restart its tutorial state (DevClient "tutorial_reset")
function TutorialService:DevReset(player: Player)
	self:DevCheck("DevReset")
	self.Closed[player.UserId] = nil
	self.Revived[player.UserId] = true
	self.Asked = false
	self.Seeded = false
	self.HoldSince = 0
	self.HoldExpired = false
	self.Rookies[player.UserId] = true
	self.LessonOver = false
	self.LessonRung = false
	self.LessonSince = 0
	self.Dependencies.CustomerService:EndTutorial()
	self:DevSend(player, "tutorial_reset", "")
end

-- One line: who has the tutorial pending, customer, stock seed
function TutorialService:DevStatus(): string
	const pending: { string } = {}
	for _, player in Players:GetPlayers() do
		const state = self:Reason(player) or "pending"
		table.insert(pending, `{player.Name}={state}`)
	end
	return `tutorial [{table.concat(pending, ", ")}]; held {self.Dependencies.RoundService:IsClockHeld()}{if self.HoldExpired then " (timeout)" else ""}; customer asked {self.Asked}, around {self.Dependencies.CustomerService:HasTutorial()}; seeded {self.Seeded}; buns {self.Dependencies.KitchenService:GetStock(BUN)}; upgrade lesson active {self:LessonActive()}, rung {self.LessonRung}, over {self.LessonOver}`
end

function TutorialService:Step()
	self:StepLesson()
	if self.Asked and not self:AnyPending() then
		self.Asked = false
		self.Dependencies.CustomerService:EndTutorial()
	end
end

TutorialService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true
	self.Dependencies.RoundService:SetClockHold(function(): boolean
		return self:ShouldHold()
	end)
	self.Dependencies.CustomerService:SetSpawnHold(function(): boolean
		return self:ShouldHold()
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		-- a player who comes back starts over (the client lost its session state too)
		self.Closed[player.UserId] = nil
		self.Revived[player.UserId] = nil
		self.Rookies[player.UserId] = nil
	end)
	self.Libs.Net.TutorialComplete:onServer(function(_, player: Player)
		self:Complete(player)
	end)
	self.Libs.Net.TutorialBegin:onServer(function(_, player: Player)
		self:Begin(player)
	end)
	self.Libs.Net.TutorialLessonSkip:onServer(function(_, player: Player)
		self.Rookies[player.UserId] = nil
	end)
	-- KitchenService (650) created its signals in its own OnInit, before this one (500)
	const kitchen = self.Dependencies.KitchenService
	kitchen.Discarded:Connect(function(_player: Player, item: string, _altered: boolean, _where: string)
		self:OnDiscarded(item)
	end)
	kitchen.StockChanged:Connect(function(ingredient: string, amount: number)
		if ingredient == BUN and amount <= 0 then
			self:EnsureCash()
		end
	end)
end)

TutorialService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return TutorialService
