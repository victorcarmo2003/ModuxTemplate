--!strict
-- Redeem codes (TASK-161; user request 2026-10-11, Provisional; data.md §1.7, network.md §15.2). Lobby and Run.
-- Single CodeRedeem responder; every request gets one CodeRedeemResult (Ok / Invalid / Expired / Already / Busy).
-- The code table is server only (Codes.luau, never in ReplicatedStorage: a code on the client is a public code).
-- Normalization: spaces removed, upper case ("  hot dog " = "HOTDOG"). One redeem per code per account
-- (profile.RedeemedCodes). The grant (gems, class, RedeemedCodes) is one Update with no yield after the checks, so two
-- requests in the same frame cannot both pass "Already". Rate limit: one attempt per MIN_GAP s, and after FAIL_MAX
-- wrong codes in FAIL_WINDOW s every attempt is "Busy" until the window ends (guessing codes is slow).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Codes = require(script.Codes)
local Modux = require(ServerScriptService.server.Modux)
local MetricsLog = require(ServerScriptService.server.Metrics.MetricsService.Log)

export type Reason = "Ok" | "Invalid" | "Expired" | "Already" | "Busy"
export type Reward = { Gems: number, Class: string? }

const MIN_GAP = 1 -- s between two attempts of the same player
const FAIL_MAX = 5 -- Invalid/Expired answers allowed per window
const FAIL_WINDOW = 60 -- s
const GEMS_MAX = 2147483647 -- Profile.Gems wire range (network.md §4.5)
const REWARD_GEMS_MAX = 1000000 -- CodeRedeemResult.Reward.Gems wire range

-- Upper case, no whitespace. Anything else (punctuation) stays and simply matches no code.
local function normalize(raw: string): string
	return string.upper((string.gsub(raw, "%s", "")))
end

local function parseExpiry(iso: string): number?
	const ok, date = pcall(DateTime.fromIsoDate, iso)
	if not ok or date == nil then
		return nil
	end
	return date.UnixTimestamp
end

const CodesService = Modux.Service(
	"CodesService",
	{ Require = { "ProfileService", "NetService" }, Priority = 670 }
)

function CodesService:Setup()
	self.LastAt = {} :: { [Player]: number }
	self.FailStart = {} :: { [Player]: number }
	self.FailCount = {} :: { [Player]: number }
	-- Key -> expiry (unix s); codes without Expires are absent
	self.ExpiresAt = {} :: { [string]: number }
	-- Codes that failed the boot check are never redeemable
	self.Broken = {} :: { [string]: boolean }
	self:Check()
end

-- Boot check of Codes.luau: a bad row is switched off and reported (error in Studio would stop the whole server).
function CodesService:Check()
	for _, code in Codes.List do
		local problem: string? = nil
		if code.Key ~= normalize(code.Key) or not string.match(code.Key, "^[A-Z0-9_]+$") then
			problem = "Key must be upper case letters, digits or _"
		elseif #code.Key < 3 or #code.Key > 20 then
			problem = "Key must have 3..20 characters"
		elseif code.Reward.Class ~= nil then
			const class = Content.Classes.ByKey[code.Reward.Class]
			if not class or not class.InMvp then
				problem = `Reward.Class {code.Reward.Class} is not an MVP class`
			end
		end
		const gems = code.Reward.Gems or 0
		if problem == nil and (gems < 0 or gems > REWARD_GEMS_MAX or gems ~= math.floor(gems)) then
			problem = `Reward.Gems must be an integer in 0..{REWARD_GEMS_MAX}`
		end
		if problem == nil and gems == 0 and code.Reward.Class == nil then
			problem = "Reward is empty"
		end
		if problem == nil and code.Expires ~= nil then
			const at = parseExpiry(code.Expires)
			if at == nil then
				problem = `Expires {code.Expires} is not ISO 8601 (2026-12-31T23:59:59Z)`
			else
				self.ExpiresAt[code.Key] = at
			end
		end
		if problem then
			self.Broken[code.Key] = true
			warn(`[CodesService] code {code.Key} switched off: {problem}`)
		end
	end
end

-- Gap between attempts and the wrong-code budget. Returns false = answer "Busy".
function CodesService:Allow(player: Player): boolean
	const now = os.clock()
	const last = self.LastAt[player]
	if last ~= nil and now - last < MIN_GAP then
		return false
	end
	self.LastAt[player] = now
	const start = self.FailStart[player]
	if start ~= nil and now - start >= FAIL_WINDOW then
		self.FailStart[player] = nil
		self.FailCount[player] = nil
	end
	return (self.FailCount[player] or 0) < FAIL_MAX
end

function CodesService:CountFail(player: Player)
	if self.FailStart[player] == nil then
		self.FailStart[player] = os.clock()
	end
	self.FailCount[player] = (self.FailCount[player] or 0) + 1
end

-- Checks and grants. Server API too (Command Bar tests): CodesService:Redeem(player, "hotdog").
function CodesService:Redeem(player: Player, raw: string): (Reason, Reward)
	const none: Reward = { Gems = 0 }
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if not profile then
		return "Busy", none
	end

	const key = normalize(raw)
	MetricsLog.panel(player, "codes", 2, "try")
	const code = Codes.ByKey[key]
	if code == nil or code.Active == false or self.Broken[key] then
		self:CountFail(player)
		return "Invalid", none
	end
	const expiresAt = self.ExpiresAt[key]
	if expiresAt ~= nil and os.time() >= expiresAt then
		self:CountFail(player)
		return "Expired", none
	end
	const redeemed = profile.RedeemedCodes()
	if redeemed[key] ~= nil then
		return "Already", none
	end

	-- grant: no yield from the checks above to the Update
	local gems = code.Reward.Gems or 0
	const classKey = code.Reward.Class
	local classes: { [string]: boolean }? = nil
	local grantedClass: string? = nil
	if classKey ~= nil then
		if profiles:OwnedClasses(profile)[classKey] then
			gems += Content.Classes.ByKey[classKey].Price -- already owned: its gem price instead (data.md §1.7)
		else
			classes = profiles:WithClass(profile, classKey)
			grantedClass = classKey
		end
	end
	const codes = table.clone(redeemed)
	codes[key] = os.time()

	profiles:Update(player, {
		Gems = math.clamp(profile.Gems() + gems, 0, GEMS_MAX),
		Classes = classes,
		RedeemedCodes = codes,
	})
	profiles:RequestSave(player)
	MetricsLog.gems(player, "Source", gems, profile.Gems(), "Code", key)
	MetricsLog.player(player, "code_redeemed", gems, { code = key, class = grantedClass or "" })
	MetricsLog.panel(player, "codes", 3, "redeemed", { code = key })
	return "Ok", { Gems = math.min(gems, REWARD_GEMS_MAX), Class = grantedClass }
end

function CodesService:Reply(player: Player, reason: Reason, reward: Reward)
	const net = self.Dependencies.NetService
	if not net:IsRunning() or not net:IsReady(player) then
		return
	end
	self.Libs.Net.CodeRedeemResult:fireClient(player, {
		Ok = reason == "Ok",
		Reason = reason,
		Reward = reward,
	})
end

CodesService:OnInit(function(self)
	self:Setup()

	self.Libs.Net.CodeRedeem:onServer(function(data, player: Player)
		if not self:Allow(player) then
			self:Reply(player, "Busy", { Gems = 0 })
			return
		end
		const reason, reward = self:Redeem(player, data.Code)
		self:Reply(player, reason, reward)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.LastAt[player] = nil
		self.FailStart[player] = nil
		self.FailCount[player] = nil
	end)
end)

return CodesService
