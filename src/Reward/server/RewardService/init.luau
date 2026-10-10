--!strict
-- Gems per event, endless days and Day 100 (FEAT-017, FEAT-029, FEAT-031; DEC-058, DEC-070, DEC-083, DEC-084,
-- DEC-104; architecture.md §19.11, T48, T59; data.md §1.2, §1.3; TASK-074). Run place; the badge retry also runs on
-- any place when a profile loads (lobby in wave 4).
-- Single writer of Gems (credits), GemsEarned, EndlessDays, Achievements, BadgesAwarded, RunRewards and the run
-- Stats it counts. Every credit is keyed in profile.RunRewards (D{d}:day, D{d}:gradeA, D{d}:endless, N{n}:night,
-- finale, achievement:<key>), scoped by RunStateService.RunId: a repeated night, ResetDev, a reconnection or a resume
-- on another server never pays the same key twice (data.md §1.3; ResetDev keeps the RunId, L2-04: dev uses
-- "/dev reward forget").
-- Hooks, no Require cycle (T42):
--   EconomyService:AddReportStep        day credits at the start of Summary; fills ShiftReport.Gems / AfkLocked
--   RoundService.NightResolved("Won")   night credit and, on the last night, the finale (before the Finale phase)
--   RoundService:AddRunReportStep       RunReport.Gems = RunRewards.Gems of this run (T59)
-- NightResolved and AddRunReportStep come with TASK-054: until then they are looked up at runtime (warn once) and
-- the run ends with Gems = 0 (§19.0 rule 4). PENDING when TASK-054 lands: drop the RoundHooks cast.
-- Who gets paid: connected members with a loaded profile, in any life state (DEC-104). A connected player whose
-- profile is still loading waits up to LOAD_WAIT seconds (data.md §1.3), then misses that event.
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Atomic = require(ReplicatedStorage.shared.Types.Atomic)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Ledger = require(ServerScriptService.server.Economy.EconomyService.Ledger)
local Template = require(ServerScriptService.server.Profile.ProfileService.Template)
local Modux = require(ServerScriptService.server.Modux)

-- Same type as ProfileService.Profile (one atom per Template field)
type Profile = Atomic.Table<Template.Data>
type ShiftInfo = { Day: number, Night: number, IsNight: boolean, Attempt: number }
-- ShiftReport packet (network.md §4.4), as EconomyService builds it
type ShiftReport = Ledger.Report
-- RunReport packet (network.md §13.1): the Round fills the rest, this service only Gems
type RunReport = { Gems: number }
type RunRewards = { RunId: string, Keys: { string }, Gems: number }

-- Profile writes that ride in the credit batch (EndlessDays, Stats...). Runs inside Charm.batch: no yield.
export type Extra = (profile: Profile) -> ()

-- Wave 2 API of RoundService (architecture.md §19.4) that TASK-054 is adding; optional until it lands.
type RoundHooks = {
	NightResolved: SignalLib.Signal<ShiftInfo, string, string?>?,
	RunEnded: SignalLib.Signal<string>?,
	AddRunReportStep: ((self: any, name: string, step: (player: Player, report: RunReport) -> ()) -> ())?,
}

type Pending = { Until: number, Run: (player: Player, profile: Profile) -> () }

const STEP = "Reward"
const GEMS_MAX = 2147483647 -- Profile.Gems wire range (network.md §4.5)
const LOAD_WAIT = 10 -- s a loading profile still gets the event (data.md §1.3)
const BADGE_TRIES = 4
const BADGE_BACKOFF = 5 -- s, doubled per try
const NO_BADGE = 0 -- Achievements.BadgeId not created yet (Creator Hub)

local function fail(message: string)
	if RunService:IsStudio() then
		error(message, 0)
	end
	warn(message)
end

local function withKey(rr: RunRewards, key: string, gems: number): RunRewards
	const keys = table.clone(rr.Keys)
	table.insert(keys, key)
	return { RunId = rr.RunId, Keys = keys, Gems = rr.Gems + gems }
end

-- Default badge award (yields). Swappable from the Command Bar to mock a failure (T074-12).
local function awardBadge(userId: number, badgeId: number): boolean
	const okHas, has = pcall(function(): boolean
		return BadgeService:UserHasBadgeAsync(userId, badgeId)
	end)
	if okHas and has then
		return true
	end
	const ok, awarded = pcall(function(): boolean
		return BadgeService:AwardBadge(userId, badgeId)
	end)
	return ok and awarded == true
end

const RewardService = Modux.Service("RewardService", {
	Require = { "PlaceService", "ProfileService", "RoundService", "RunStateService", "EconomyService" },
	Priority = 550,
})

function RewardService:Setup()
	-- Gems credited to each player in the current shift (UserId), for ShiftReport.Gems; zeroed at ShiftStarted
	self.ShiftGems = {} :: { [number]: number }
	-- Events waiting for a profile that is still loading (data.md §1.3)
	self.Pending = {} :: { [Player]: { Pending } }
	-- Badges with a retry loop running (UserId:key)
	self.Awarding = {} :: { [string]: boolean }
	self.AwardBadge = awardBadge :: (userId: number, badgeId: number) -> boolean
	self.Warned = {} :: { [string]: boolean }
end

-- Reads -----------------------------------------------------------------------------------------------------------

function RewardService:RunId(): string
	return self.Dependencies.RunStateService.RunId
end

-- RunRewards of this run (a fresh record when the profile holds another run's)
function RewardService:RunRewardsOf(profile: Profile): RunRewards
	const rr = profile.RunRewards() :: RunRewards
	const runId = self:RunId()
	if rr.RunId ~= runId then
		return { RunId = runId, Keys = {}, Gems = 0 }
	end
	return { RunId = rr.RunId, Keys = rr.Keys or {}, Gems = rr.Gems or 0 }
end

function RewardService:HasKey(profile: Profile, key: string): boolean
	return table.find(self:RunRewardsOf(profile).Keys, key) ~= nil
end

-- Gems of this run (RunReport.Gems): 0 without a loaded profile or when RunRewards belongs to another run
function RewardService:RunGems(player: Player): number
	const profile = self.Dependencies.ProfileService:Get(player)
	if profile == nil then
		return 0
	end
	return self:RunRewardsOf(profile).Gems
end

-- Connected member, not Away (DEC-104: any life state counts)
function RewardService:IsPresent(player: Player): boolean
	if player.Parent ~= Players then
		return false
	end
	const member = self.Dependencies.RunStateService:GetMember(player)
	return member ~= nil and member.State ~= "Away"
end

-- Credit ----------------------------------------------------------------------------------------------------------

-- data.md §1.3. Pays `gems` once per key and run, with `extra` in the same batch, and asks for a save. Returns the
-- gems credited (0 when the key was already used). No toast here: the caller sums an event and sends one.
function RewardService:Credit(player: Player, profile: Profile, key: string, gems: number, extra: Extra?): number
	if type(gems) ~= "number" or gems < 0 or gems ~= math.floor(gems) then
		fail(`[RewardService] Credit {key}: gems must be a non-negative integer, got {gems}`)
		return 0
	end
	const rr = self:RunRewardsOf(profile)
	if table.find(rr.Keys, key) then
		return 0
	end
	self.Libs.Charm.batch(function()
		profile.Gems(math.min(profile.Gems() + gems, GEMS_MAX))
		profile.GemsEarned(math.min(profile.GemsEarned() + gems, GEMS_MAX))
		profile.RunRewards(withKey(rr, key, gems))
		if extra then
			extra(profile)
		end
	end)
	self.Dependencies.ProfileService:RequestSave(player)
	const userId = player.UserId
	self.ShiftGems[userId] = (self.ShiftGems[userId] or 0) + gems
	return gems
end

-- Runs `pay` for every connected member with a loaded profile; one still loading gets it on Loaded (LOAD_WAIT).
function RewardService:ForPresent(pay: (player: Player, profile: Profile) -> ())
	const profiles = self.Dependencies.ProfileService
	for _, player in Players:GetPlayers() do
		const profile = profiles:Get(player)
		if profile ~= nil then
			if self:IsPresent(player) then
				pay(player, profile)
			end
			continue
		end
		const queue = self.Pending[player] or {}
		table.insert(queue, { Until = os.clock() + LOAD_WAIT, Run = pay })
		self.Pending[player] = queue
	end
end

function RewardService:FlushPending(player: Player, profile: Profile)
	const queue = self.Pending[player]
	self.Pending[player] = nil
	if queue == nil or not self:IsPresent(player) then
		return
	end
	const now = os.clock()
	for _, pending in queue do
		if now <= pending.Until then
			pending.Run(player, profile)
		else
			warn(`[RewardService] {player.Name} profile loaded after {LOAD_WAIT} s: missed a reward event`)
		end
	end
end

function RewardService:Toast(player: Player, gems: number)
	if gems > 0 then
		self.Dependencies.RunStateService:Notify(player, "gems_gained", gems)
	end
end

-- Achievements ----------------------------------------------------------------------------------------------------

-- Every achievement whose profile counter reached its Target and is not unlocked yet (once per account, DEC-058).
-- Returns the gems credited. The badge goes out after the batch, with retry.
function RewardService:CheckAchievements(player: Player, profile: Profile): number
	local gained = 0
	for _, achievement in Content.Achievements.List do
		const counter = (profile :: any)[achievement.Counter] :: (() -> any)?
		if counter == nil then
			fail(`[RewardService] achievement {achievement.Key}: {achievement.Counter} is not a profile field`)
			continue
		end
		const value = counter()
		if type(value) ~= "number" or value < achievement.Target or profile.Achievements()[achievement.Key] ~= nil then
			continue
		end
		gained += self:Credit(player, profile, `achievement:{achievement.Key}`, achievement.Gems, function(p: Profile)
			const unlocked = table.clone(p.Achievements())
			unlocked[achievement.Key] = os.time()
			p.Achievements(unlocked)
		end)
		if profile.Achievements()[achievement.Key] ~= nil then
			self.Dependencies.RunStateService:Notify(player, "achievement", Content.Achievements.IndexOf[achievement.Key])
		end
	end
	self:AwardPending(player, profile)
	return gained
end

-- Unlocked achievements whose badge is not confirmed yet (BadgesAwarded). Each runs in its own thread with backoff;
-- whatever still fails is tried again the next time the profile loads.
function RewardService:AwardPending(player: Player, profile: Profile)
	for key in profile.Achievements() do
		const achievement = Content.Achievements.ByKey[key]
		if achievement == nil or achievement.BadgeId == NO_BADGE or profile.BadgesAwarded()[key] == true then
			continue
		end
		const id = `{player.UserId}:{key}`
		if self.Awarding[id] then
			continue
		end
		self.Awarding[id] = true
		task.spawn(function()
			for try = 1, BADGE_TRIES do
				const ok = self.AwardBadge(player.UserId, achievement.BadgeId)
				const live = self.Dependencies.ProfileService:Get(player)
				if ok then
					if live ~= nil then
						const awarded = table.clone(live.BadgesAwarded())
						awarded[key] = true
						live.BadgesAwarded(awarded)
						self.Dependencies.ProfileService:RequestSave(player)
					end
					break
				end
				if live == nil or try == BADGE_TRIES then
					warn(`[RewardService] badge {key} for {player.Name} not awarded (try {try}); retry on next load`)
					break
				end
				task.wait(BADGE_BACKOFF * 2 ^ (try - 1))
			end
			self.Awarding[id] = nil
		end)
	end
end

-- Events ----------------------------------------------------------------------------------------------------------

-- Day summary (EconomyService report step, start of Summary): DayShift and DayGradeA with the anti-AFK minimum
-- (DEC-083), endless day + Day 100 (DEC-084). Night summaries only report the gems of the night (credited at 6:00).
function RewardService:ReportStep(info: ShiftInfo, report: ShiftReport)
	if not info.IsNight then
		const params = Content.RunParams
		const rewards = Content.GemRewards
		const day = info.Day
		const afkOk = report.Completed >= params.AntiAfkMinCompleted
		const gradeA = report.Grade == "A" and (afkOk or not params.AntiAfkAppliesToGradeA)
		const endless = afkOk and self.Dependencies.RunStateService.Endless()
		report.AfkLocked = not afkOk

		self:ForPresent(function(player: Player, profile: Profile)
			local gained = 0
			if afkOk then
				gained += self:Credit(player, profile, `D{day}:day`, rewards.DayShift)
			end
			if gradeA then
				gained += self:Credit(player, profile, `D{day}:gradeA`, rewards.DayGradeA)
			end
			if endless then
				gained += self:Credit(player, profile, `D{day}:endless`, 0, function(p: Profile)
					p.EndlessDays(p.EndlessDays() + 1)
					const stats = table.clone(p.Stats())
					stats.BestDay = math.max(stats.BestDay, day)
					p.Stats(stats)
				end)
				gained += self:CheckAchievements(player, profile)
			end
			self:Toast(player, gained)
		end)
		if not afkOk then
			self.Dependencies.RunStateService:Notify("all", "afk_no_gems")
		end
	end

	local best = 0
	for _, gems in self.ShiftGems do
		best = math.max(best, gems)
	end
	report.Gems = best
end

-- Night won at 6:00 (NightResolved "Won"): NightBase + NightPerIndex x (N - 1); the last night also pays the finale,
-- before the Finale phase (FEAT-027). A lost night pays nothing.
function RewardService:NightWon(info: ShiftInfo)
	const rewards = Content.GemRewards
	const night = info.Night
	if type(night) ~= "number" or night < 1 then
		fail(`[RewardService] NightResolved("Won") with Night = {night}`)
		return
	end
	const last = night >= Content.RunParams.Nights
	self:ForPresent(function(player: Player, profile: Profile)
		local gained = self:Credit(
			player,
			profile,
			`N{night}:night`,
			rewards.NightBase + rewards.NightPerIndex * (night - 1),
			function(p: Profile)
				const stats = table.clone(p.Stats())
				stats.NightsWon += 1
				stats.BestNight = math.max(stats.BestNight, night)
				p.Stats(stats)
			end
		)
		if last then
			gained += self:Credit(player, profile, "finale", rewards.Finale, function(p: Profile)
				const stats = table.clone(p.Stats())
				stats.RunsFinished += 1
				p.Stats(stats)
			end)
		end
		self:Toast(player, gained)
	end)
end

-- Failed run: RunFailedExtra (0 today; nothing is credited while it stays 0)
function RewardService:RunFailed()
	const extra = Content.GemRewards.RunFailedExtra
	if extra <= 0 then
		return
	end
	self:ForPresent(function(player: Player, profile: Profile)
		self:Toast(player, self:Credit(player, profile, "failed", extra))
	end)
end

function RewardService:WarnOnce(key: string, message: string)
	if self.Warned[key] then
		return
	end
	self.Warned[key] = true
	warn(message)
end

-- Dev (Commands/Reward.luau; tests/wave-2.md §0.4 R7) ------------------------------------------------------------

function RewardService:DevProfile(player: Player): Profile
	if not self.Dependencies.PlaceService:IsDev() then
		error("[RewardService] dev mode only", 2)
	end
	const profile = self.Dependencies.ProfileService:Get(player)
	if profile == nil then
		error(`{player.Name} has no loaded profile`, 0)
	end
	return profile
end

-- Writes EndlessDays (never below 0). The next endless day with anti-AFK adds 1 and checks Day 100.
function RewardService:DevSetEndless(player: Player, days: number): number
	const profile = self:DevProfile(player)
	if type(days) ~= "number" or days ~= days or math.abs(days) == math.huge then
		error("days must be a finite number", 0)
	end
	profile.EndlessDays(math.max(0, math.floor(days)))
	self.Dependencies.ProfileService:RequestSave(player)
	return profile.EndlessDays()
end

-- Clears the RunRewards keys and gems of this run, so the same events pay again after ResetDev (L2-04).
function RewardService:DevForget(player: Player): number
	const profile = self:DevProfile(player)
	const count = #self:RunRewardsOf(profile).Keys
	profile.RunRewards({ RunId = self:RunId(), Keys = {}, Gems = 0 })
	self.Dependencies.ProfileService:RequestSave(player)
	return count
end

function RewardService:DevStatus(player: Player): string
	const profile = self:DevProfile(player)
	const rr = self:RunRewardsOf(profile)
	return `Gems {profile.Gems()} (earned {profile.GemsEarned()}), EndlessDays {profile.EndlessDays()}, run gems {rr.Gems}, keys [{table.concat(
		rr.Keys,
		" "
	)}]`
end

RewardService:OnInit(function(self)
	self:Setup()

	const profiles = self.Dependencies.ProfileService
	-- Badge retry on every place (lobby in wave 4); pending events only matter in the run
	profiles.Loaded:Connect(function(player, profile)
		self:FlushPending(player, profile)
		self:AwardPending(player, profile)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Pending[player] = nil
	end)

	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	-- Higher-priority services: their Setup already ran, so steps register and signals connect here
	self.Dependencies.EconomyService:AddReportStep(STEP, function(info, report)
		self:ReportStep(info, report)
	end)

	const round = self.Dependencies.RoundService
	round.ShiftStarted:Connect(function()
		self.ShiftGems = {}
	end)

	const hooks = (round :: any) :: RoundHooks
	if hooks.NightResolved ~= nil then
		hooks.NightResolved:Connect(function(info, result)
			if result == "Won" then
				self:NightWon(info)
			end
		end)
	else
		self:WarnOnce("night", "[RewardService] RoundService.NightResolved missing (TASK-054): no night gems")
	end
	if hooks.RunEnded ~= nil then
		hooks.RunEnded:Connect(function(result)
			if result == "Failed" then
				self:RunFailed()
			end
		end)
	end
	if hooks.AddRunReportStep ~= nil then
		hooks.AddRunReportStep(round, STEP, function(player, report)
			report.Gems = self:RunGems(player)
		end)
	else
		self:WarnOnce("run", "[RewardService] RoundService:AddRunReportStep missing (TASK-054): RunReport.Gems = 0")
	end
end)

return RewardService
