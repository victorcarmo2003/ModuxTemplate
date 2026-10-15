--!strict
-- Players online in the whole game (TASK-312; owner request 2026-10-15, Provisional): every server of the experience
-- (lobbies, private lobbies and runs) counts, shown by the lobby HUD as a social pill ("200 players online").
-- MemoryStore HashMap MAP (shared by every place of the universe):
--   key = game.JobId     this server's player count, rewritten every PUBLISH_EVERY s with expiration ENTRY_TTL s (a
--                        crashed server drops out by itself). Every role publishes
--   key = TOTAL_KEY      { Count, At }: the last global sum, rewritten by ONE lobby server per SUM_EVERY s
--   key = LEASE_KEY      who sums: claimed with UpdateAsync (expires LEASE_TTL s). Only the holder lists the map, so
--                        the cost of listing grows with the number of servers once a minute, not per lobby server
-- Lobby servers read TOTAL_KEY every READ_EVERY s and replicate it through the `Online` set (record 1); the shown
-- number is never below the local count (a stale or missing total). Requests per minute (quota 1000 + 100 x users):
-- 2 per server + 2 per lobby server + about servers / 200 pages + 2 for the summer, far under the quota.
-- Studio (no MemoryStore for unpublished places) and any MemoryStore error: the local count only.
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const MAP = "Online_v1"
const TOTAL_KEY = "_total"
const LEASE_KEY = "_lease"
const PUBLISH_EVERY = 30 -- s between two writes of this server's count
const ENTRY_TTL = 90 -- s: a server that stopped writing drops out of the sum after this
const READ_EVERY = 30 -- s between two reads of the total (lobby servers)
const SUM_EVERY = 60 -- s: a total older than this is summed again by whoever gets the lease
const LEASE_TTL = 50 -- s
const TOTAL_TTL = 300 -- s: the total disappears when no lobby server sums anymore
const PAGE_SIZE = 200 -- ListItemsAsync maximum
const MAX_PAGES = 50 -- 10 000 servers
const RECORD = 1
const MAX_COUNT = 16777215 -- Online.Count wire range

type Total = { Count: number, At: number }

const PresenceService = Modux.Service(
	"PresenceService",
	{ Require = { "PlaceService", "NetService" }, Priority = 640 }
)

function PresenceService:Setup()
	self.Map = nil :: MemoryStoreHashMap?
	-- last global total read from the map; nil = none yet (Studio, error, first read pending)
	self.Total = nil :: number?
	-- last count replicated through `Online`; nil = record not added yet
	self.Sent = nil :: number?
	self.Warned = false :: boolean
end

function PresenceService:Warn(what: string, err: any)
	if not self.Warned then
		self.Warned = true
		warn(`[PresenceService] MemoryStore {what} failed ({err}); showing the local count`)
	end
end

function PresenceService:LocalCount(): number
	return #Players:GetPlayers()
end

-- Shown number: the global total, never under this server's own players.
function PresenceService:Count(): number
	return math.clamp(math.max(self.Total or 0, self:LocalCount()), 0, MAX_COUNT)
end

function PresenceService:Publish()
	const map = self.Map
	if map == nil then
		return
	end
	const ok, err = pcall(function()
		map:SetAsync(game.JobId, self:LocalCount(), ENTRY_TTL)
	end)
	if not ok then
		self:Warn("publish", err)
	end
end

-- Claims the summing lease for this server; true = this server sums now.
function PresenceService:Claim(map: MemoryStoreHashMap): boolean
	const ok, holder = pcall(function()
		return map:UpdateAsync(LEASE_KEY, function(current: any)
			if current ~= nil and current ~= game.JobId then
				return nil -- somebody else holds it
			end
			return game.JobId
		end, LEASE_TTL)
	end)
	return ok and holder == game.JobId
end

-- Lists every server entry and writes the sum to TOTAL_KEY.
function PresenceService:Sum(map: MemoryStoreHashMap): number?
	const ok, result = pcall(function(): number
		local sum = 0
		const pages = map:ListItemsAsync(PAGE_SIZE)
		for _ = 1, MAX_PAGES do
			for _, item in pages:GetCurrentPage() do
				const entry = item :: { key: string, value: any }
				if string.sub(entry.key, 1, 1) ~= "_" and type(entry.value) == "number" then
					sum += entry.value
				end
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
		map:SetAsync(TOTAL_KEY, { Count = sum, At = os.time() }, TOTAL_TTL)
		return sum
	end)
	if not ok then
		self:Warn("sum", result)
		return nil
	end
	return result
end

function PresenceService:Read()
	const map = self.Map
	if map == nil then
		return
	end
	const ok, value = pcall(function()
		return map:GetAsync(TOTAL_KEY)
	end)
	if not ok then
		self:Warn("read", value)
		return
	end
	const total = if type(value) == "table" then value :: Total else nil
	if total ~= nil and type(total.Count) == "number" then
		self.Total = total.Count
	end
	const stale = total == nil or type(total.At) ~= "number" or os.time() - total.At >= SUM_EVERY
	if stale and self:Claim(map) then
		const sum = self:Sum(map)
		if sum ~= nil then
			self.Total = sum
		end
	end
end

function PresenceService:Send()
	const net = self.Dependencies.NetService
	const count = self:Count()
	if count == self.Sent or not net:IsRunning() then
		return
	end
	if self.Sent == nil then
		self.Libs.Net.Online:add(RECORD, { Count = count })
	else
		self.Libs.Net.Online:update(RECORD, { Count = count })
	end
	self.Sent = count
end

PresenceService:OnInit(function(self)
	self:Setup()
	if RunService:IsStudio() then
		return
	end
	const ok, result = pcall(function()
		return MemoryStoreService:GetHashMap(MAP)
	end)
	if ok then
		self.Map = result
	else
		self:Warn("open", result)
	end
end)

PresenceService:OnStart(function(self)
	const lobby = self.Dependencies.PlaceService:Is("Lobby")
	-- this server's count: on a timer and on leave (a closing server drops its entry right away)
	task.spawn(function()
		while true do
			self:Publish()
			task.wait(PUBLISH_EVERY)
		end
	end)
	game:BindToClose(function()
		const map = self.Map
		if map ~= nil then
			pcall(function()
				map:RemoveAsync(game.JobId)
			end)
		end
	end)
	if not lobby then
		return
	end

	-- Lync.start already ran (NetService OnStart, priority 1000)
	self:Send()
	Players.PlayerAdded:Connect(function()
		self:Send()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			self:Send()
		end)
	end)
	task.spawn(function()
		while true do
			self:Read()
			self:Send()
			task.wait(READ_EVERY)
		end
	end)
end)

return PresenceService
