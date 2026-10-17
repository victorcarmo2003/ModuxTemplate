--!strict
-- Rejoin a run in progress (owner request 2026-10-17: "reconectar na partida caso o usuário caia ... prompt em cima na
-- direita"; DEC-063, DEC-067; architecture.md §5.2-§5.4; data.md §3.1, §3.2; network.md §13.8; TASK-360, Provisional)
-- and resume it for 15 min after everyone left or its server fell (DEC-080, DEC-119; architecture.md §5.5; data.md
-- §3.3, §3.4; Q-291, Provisional). Every role; the single owner of the run records in MemoryStore (SessionRules.Rules).
--
--   Runs[RunId]          RunId = PrivateServerId of the run server. { V, Code, Roster, State, JobId, Day, IsNight,
--                        ExpiresAt, CreatedAt, UpdatedAt }. Lobby (PartyService -> Register): State "Starting",
--                        StartingTtl. Run server: claims it on boot (Starting -> "Live", JobId), rewrites it every
--                        Heartbeat s (RunTtl), removes it when the run ends; on BindToClose with the run going it
--                        writes "Suspended" (ExpiresAt = now + ResumeWindow, SuspendTtl). A fresh server that resumes
--                        it claims it as "Resuming" (its JobId), then "Live".
--   Snap[RunId]          the start-of-shift snapshot (RunStateService:LastSnapshot, JSON, <= 8 KB). Run server: written
--                        after every capture (SnapTtl) and on suspend (SuspendTtl); removed when the run ends.
--   PlayerRun[UserId]    { V, RunId, Code, At }. Run server: written for every roster member when the run is claimed and
--                        when a member joins or leaves (PointerTtl; SuspendTtl on suspend), so a crash still leaves
--                        everyone a way back; removed when the run ends. Lobby: removed when the player dismisses the
--                        offer or it is dead.
--
-- Lobby: a joining player with a PlayerRun whose Runs record has them in the Roster gets
--   - Reconnect { Mode = "Rejoin" } when it is Live (or Resuming) and beat less than Stale s ago;
--   - Reconnect { Mode = "Resume", Left } when it is Suspended before ExpiresAt, or Live/Resuming with no beat for Stale
--     s (crashed server) before UpdatedAt + ResumeWindow (Left = seconds of the window still open).
-- Both on the top-right card (SessionController). ReconnectReply Accept = read again, then TeleportAsync to the same
-- reserved server (access code) with TeleportData { Rejoin = true } and the squad retries (2/5/10 s); false = forget
-- the pointer. Every failure answers Reconnect { Mode = "None", Reason }.
-- Run (Rejoin): the returning member is put back by the services that already keep a member who is Away
-- (RunStateService seat, class and life state; ItemService stash; VitalService sanity and revives; CharacterService
-- spawn at work).
-- Run (Resume): the access code of a closed reserved server boots a fresh one with the same PrivateServerId
-- (architecture.md §5.1 b). Its first player came from a rejoin, so OnInit holds the run start (RoundService
-- SetResumeHold) until the Runs record is read: resumable = claim it atomically (Resuming, this JobId), read Snap,
-- RunStateService:Load + RoundService:ResumeRun (Restore("Resume"), Resume phase, then the shift starts over), Live.
-- Another server holding it with a fresh beat = everyone here goes back to the lobby (pointers kept); ended, expired or
-- no readable snapshot ("That shift can't be resumed.") = dead run: everyone here goes back to the lobby.
-- The shift in progress when everyone left is lost (DEC-080); gems already paid stay (DEC-104).
-- Studio (no MemoryStore for unpublished places, no teleport): nothing is read or written; `/dev rejoin [resume]`
-- shows the card with a dev offer.
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")
local Content = require(ReplicatedStorage.shared.Content)
local SessionRules = require(ReplicatedStorage.shared.Session.SessionRules)
local Teleport = require(ServerScriptService.server.Party.PartyService.Teleport)
local Modux = require(ServerScriptService.server.Modux)

const RULES = SessionRules.Rules
const VERSION = 1
const WINDOW = Content.RunParams.ResumeWindow -- 900 s (DEC-080)
const LEFT_MAX = 3600 -- Reconnect.Left wire range

export type RunState = "Starting" | "Live" | "Suspended" | "Resuming" | "Ended"

export type RunRecord = {
	V: number,
	Code: string,
	Roster: { number },
	State: RunState,
	JobId: string,
	Day: number,
	IsNight: boolean,
	-- Suspended / Resuming: os.time() the resume window closes; 0 otherwise
	ExpiresAt: number,
	CreatedAt: number,
	UpdatedAt: number,
}

-- What a Runs record allows now (architecture.md §5.5 step 1): join its live server, resume it, or nothing.
export type Standing = "Live" | "Resumable" | "Gone"

export type Pointer = { V: number, RunId: string, Code: string, At: number }

export type Mode = "None" | "Rejoin" | "Resume"

-- What the lobby offered to one player (kept until they answer or leave).
export type Offer = { RunId: string, Code: string, Dev: boolean, Mode: Mode }

type Reason = "None" | "Ended" | "Failed" | "StudioNoTeleport" | "TooFast"

-- Boot verdict of a run server (Claim)
type Verdict = "Claimed" | "Resume" | "Taken" | "Dead" | "None"

local function isUserId(value: any): boolean
	return type(value) == "number" and value == value and value >= 1 and value % 1 == 0 and value < 2 ^ 53
end

local function isState(value: any): boolean
	return value == "Starting" or value == "Live" or value == "Suspended" or value == "Resuming" or value == "Ended"
end

-- Checks a Runs value read from MemoryStore; nil when the shape is wrong or the version is unknown.
local function readRun(value: any): RunRecord?
	if type(value) ~= "table" or value.V ~= VERSION or type(value.Code) ~= "string" or not isState(value.State) then
		return nil
	end
	const roster: { number } = {}
	if type(value.Roster) == "table" then
		for _, userId in value.Roster do
			if isUserId(userId) then
				table.insert(roster, userId)
			end
		end
	end
	return {
		V = VERSION,
		Code = value.Code,
		Roster = roster,
		State = value.State,
		JobId = if type(value.JobId) == "string" then value.JobId else "",
		Day = if type(value.Day) == "number" then value.Day else 0,
		IsNight = value.IsNight == true,
		ExpiresAt = if type(value.ExpiresAt) == "number" then value.ExpiresAt else 0,
		CreatedAt = if type(value.CreatedAt) == "number" then value.CreatedAt else 0,
		UpdatedAt = if type(value.UpdatedAt) == "number" then value.UpdatedAt else 0,
	}
end

-- When the resume window of a record closes: its ExpiresAt (Suspended, Resuming) or the last beat + the window (a Live
-- record whose server fell without BindToClose).
local function resumeDeadline(run: RunRecord): number
	return if run.ExpiresAt > 0 then run.ExpiresAt else run.UpdatedAt + WINDOW
end

local function standing(run: RunRecord, now: number): Standing
	if run.State == "Live" or run.State == "Resuming" then
		-- a fresh beat: its server is up (joining a Resuming one is a rejoin of the server that is restoring it)
		if now - run.UpdatedAt < RULES.Stale then
			return "Live"
		end
		return if now < resumeDeadline(run) then "Resumable" else "Gone"
	elseif run.State == "Suspended" then
		return if now < run.ExpiresAt then "Resumable" else "Gone"
	end
	return "Gone"
end

local function readPointer(value: any): Pointer?
	if type(value) ~= "table" or value.V ~= VERSION or type(value.RunId) ~= "string" or type(value.Code) ~= "string" then
		return nil
	end
	return { V = VERSION, RunId = value.RunId, Code = value.Code, At = if type(value.At) == "number" then value.At else 0 }
end

local function joinData(player: Player): any
	const ok, data = pcall(function()
		return player:GetJoinData()
	end)
	return if ok and type(data) == "table" then data.TeleportData else nil
end

-- Day / IsNight of a snapshot's shift ("Sh", data.md §3.3); nil when it has none
local function snapShift(snapshot: { [string]: any }): (number?, boolean)
	const sh = snapshot.Sh
	if type(sh) ~= "table" or type(sh.D) ~= "number" then
		return nil, false
	end
	return sh.D, sh.Ni == true
end

const SessionService = Modux.Service("SessionService", {
	Require = {
		"RoleService",
		"PlayerService",
		"NetService",
		"RunStateService",
		"RoundService",
		"PartyRunService",
	},
	Priority = 700,
})

function SessionService:Setup()
	self.Runs = nil :: MemoryStoreHashMap?
	self.Snaps = nil :: MemoryStoreHashMap?
	self.Pointers = nil :: MemoryStoreHashMap?
	self.Warned = {} :: { [string]: boolean }
	-- lobby
	self.Offers = {} :: { [Player]: Offer }
	-- players whose pointer was already looked up (PlayerAdded and the OnStart scan may both see one)
	self.Checked = {} :: { [Player]: boolean }
	-- rejoin teleports in flight: player -> tries so far
	self.Joining = {} :: { [Player]: number }
	self.LastReply = {} :: { [Player]: number }
	-- run server
	-- RunId of this run server; "" = no session (not a reserved Game server, Studio, MemoryStore off)
	self.RunId = "" :: string
	-- access code of this server, read from the lobby's Runs record; "" = unknown (nobody can be offered a rejoin)
	self.Code = "" :: string
	-- true while this server owns its Runs record (claimed on boot)
	self.Claimed = false :: boolean
	self.Ended = false :: boolean
	self.CreatedAt = 0 :: number
	-- state the heartbeat writes (Claim already wrote "Resuming"; the first beat comes after the restore: "Live")
	self.State = "Live" :: RunState
	-- the first player came from a rejoin teleport: this fresh server may resume a run (RoundService start held)
	self.FromRejoin = false :: boolean
	-- true on a server that resumed its run from Snap (dev status)
	self.Resumed = false :: boolean
	-- roster of the Runs record read on boot (the RunStateService roster may still be empty then)
	self.BootRoster = {} :: { number }
	-- last snapshot written to Snap (identity)
	self.Written = nil :: { [string]: any }?
end

function SessionService:Warn(what: string, err: any)
	if not self.Warned[what] then
		self.Warned[what] = true
		warn(`[SessionService] MemoryStore {what} failed ({err}); rejoin offers are off for it`)
	end
end

-- MemoryStore ---------------------------------------------------------------------------------------------------------

function SessionService:Open(): boolean
	if RunService:IsStudio() then
		return false
	end
	const ok, problem = pcall(function()
		self.Runs = MemoryStoreService:GetHashMap(RULES.RunsMap)
		self.Snaps = MemoryStoreService:GetHashMap(RULES.SnapMap)
		self.Pointers = MemoryStoreService:GetHashMap(RULES.PlayerRunMap)
	end)
	if not ok then
		self.Runs = nil
		self.Snaps = nil
		self.Pointers = nil
		self:Warn("open", problem)
	end
	return ok
end

function SessionService:GetRun(runId: string): RunRecord?
	const map = self.Runs
	if map == nil or runId == "" then
		return nil
	end
	const ok, value = pcall(function()
		return map:GetAsync(runId)
	end)
	if not ok then
		self:Warn("read run", value)
		return nil
	end
	return readRun(value)
end

function SessionService:GetPointer(userId: number): Pointer?
	const map = self.Pointers
	if map == nil then
		return nil
	end
	const ok, value = pcall(function()
		return map:GetAsync(tostring(userId))
	end)
	if not ok then
		self:Warn("read pointer", value)
		return nil
	end
	return readPointer(value)
end

function SessionService:SetPointer(userId: number, pointer: Pointer, ttl: number?)
	const map = self.Pointers
	if map == nil then
		return
	end
	const ok, problem = pcall(function()
		map:SetAsync(tostring(userId), pointer, ttl or RULES.PointerTtl)
	end)
	if not ok then
		self:Warn("write pointer", problem)
	end
end

-- Removes the pointer of a player; with `runId`, only when it still points at that run (a newer run is left alone).
function SessionService:ClearPointer(userId: number, runId: string?)
	const map = self.Pointers
	if map == nil then
		return
	end
	if runId ~= nil then
		const pointer = self:GetPointer(userId)
		if pointer == nil or pointer.RunId ~= runId then
			return
		end
	end
	const ok, problem = pcall(function()
		map:RemoveAsync(tostring(userId))
	end)
	if not ok then
		self:Warn("remove pointer", problem)
	end
end

function SessionService:GetSnap(runId: string): { [string]: any }?
	const map = self.Snaps
	if map == nil or runId == "" then
		return nil
	end
	const ok, value = pcall(function()
		return map:GetAsync(runId)
	end)
	if not ok then
		self:Warn("read snapshot", value)
		return nil
	end
	return if type(value) == "table" then value else nil
end

function SessionService:SetSnap(snapshot: { [string]: any }, ttl: number): boolean
	const map = self.Snaps
	if map == nil or self.RunId == "" then
		return false
	end
	const ok, problem = pcall(function()
		map:SetAsync(self.RunId, snapshot, ttl)
	end)
	if not ok then
		self:Warn("write snapshot", problem)
	end
	return ok
end

-- Lobby: launch --------------------------------------------------------------------------------------------------------

-- Called by PartyService right after ReserveServer, before the teleport: the record the run server claims on boot.
-- Never throws (a MemoryStore failure only means no rejoin for that run).
function SessionService:Register(runId: string, code: string, roster: { number })
	const map = self.Runs
	if map == nil or runId == "" or code == "" then
		return
	end
	const now = os.time()
	const record: RunRecord = {
		V = VERSION,
		Code = code,
		Roster = table.clone(roster),
		State = "Starting",
		JobId = "",
		Day = 0,
		IsNight = false,
		ExpiresAt = 0,
		CreatedAt = now,
		UpdatedAt = now,
	}
	const ok, problem = pcall(function()
		map:SetAsync(runId, record, RULES.StartingTtl)
	end)
	if not ok then
		self:Warn("register run", problem)
	end
end

-- Lobby: offer ---------------------------------------------------------------------------------------------------------

-- `left` = seconds of the resume window still open (Resume only)
function SessionService:Send(player: Player, mode: Mode, reason: Reason, run: RunRecord?, left: number?)
	const net = self.Dependencies.NetService
	if player.Parent == nil or not net:IsRunning() or not net:IsReady(player) then
		return
	end
	self.Libs.Net.Reconnect:fireClient(player, {
		Mode = mode,
		Day = if run ~= nil then math.clamp(math.floor(run.Day), 0, 10000) else 0,
		IsNight = run ~= nil and run.IsNight,
		Reason = reason,
		Left = if mode == "Resume" and left ~= nil then math.clamp(math.floor(left), 0, LEFT_MAX) else 0,
	})
end

-- The run a pointer leads to and what this user can do with it now (nil = nothing: gone, or not in its roster).
function SessionService:OpenRun(userId: number, runId: string): (RunRecord?, Mode, number)
	const run = self:GetRun(runId)
	if run == nil or table.find(run.Roster, userId) == nil then
		return nil, "None", 0
	end
	const now = os.time()
	const stand = standing(run, now)
	if stand == "Live" then
		return run, "Rejoin", 0
	elseif stand == "Resumable" then
		return run, "Resume", resumeDeadline(run) - now
	end
	return nil, "None", 0
end

-- Shows the card for one open run
function SessionService:Offer(player: Player, runId: string, run: RunRecord, mode: Mode, left: number)
	self.Offers[player] = { RunId = runId, Code = run.Code, Dev = false, Mode = mode }
	self:Send(player, mode, "None", run, left)
end

-- Waits for the client's Lync handshake (packets sent before it are dropped). False = gave up.
function SessionService:WaitReady(player: Player): boolean
	const net = self.Dependencies.NetService
	const deadline = os.clock() + RULES.ReadyWait
	while not net:IsReady(player) do
		if player.Parent == nil or os.clock() >= deadline then
			return false
		end
		task.wait(0.25)
	end
	return true
end

function SessionService:Check(player: Player)
	if self.Checked[player] then
		return
	end
	self.Checked[player] = true
	const pointer = self:GetPointer(player.UserId)
	if pointer == nil then
		return
	end
	if self:OpenRun(player.UserId, pointer.RunId) == nil then
		-- dead pointer (run over, resume window closed): forget it
		self:ClearPointer(player.UserId, pointer.RunId)
		return
	end
	if player.Parent == nil or not self:WaitReady(player) then
		return
	end
	-- read again after the wait: the Left of a Resume counts from now
	const run, mode, left = self:OpenRun(player.UserId, pointer.RunId)
	if run ~= nil then
		self:Offer(player, pointer.RunId, run, mode, left)
	end
end

-- `/dev rejoin [resume]`: the card without a run behind it (Studio and live tests of the UI). Accept answers
-- StudioNoTeleport. Mode None hides it.
function SessionService:DevOffer(player: Player, mode: Mode)
	if mode == "None" then
		self.Offers[player] = nil
		self:Send(player, "None", "None", nil)
		return
	end
	self.Offers[player] = { RunId = "", Code = "", Dev = true, Mode = mode }
	const now = os.time()
	const resume = mode == "Resume"
	self:Send(player, mode, "None", {
		V = VERSION,
		Code = "",
		Roster = { player.UserId },
		State = if resume then "Suspended" else "Live",
		JobId = "",
		Day = if resume then 7 else 3,
		IsNight = true,
		ExpiresAt = 0,
		CreatedAt = now,
		UpdatedAt = now,
	}, 760)
end

-- Lobby: answer --------------------------------------------------------------------------------------------------------

function SessionService:HandleReply(player: Player, accept: boolean)
	const now = os.clock()
	const last = self.LastReply[player]
	if last ~= nil and now - last < RULES.ReplyRate then
		return
	end
	self.LastReply[player] = now
	const offer = self.Offers[player]
	if offer == nil or self.Joining[player] ~= nil then
		return
	end
	if not accept then
		self.Offers[player] = nil
		if not offer.Dev then
			task.spawn(function()
				self:ClearPointer(player.UserId, offer.RunId)
			end)
		end
		return
	end
	if offer.Dev or RunService:IsStudio() then
		self.Offers[player] = nil
		self:Send(player, "None", "StudioNoTeleport", nil)
		return
	end
	task.spawn(function()
		self:Rejoin(player, offer)
	end)
end

-- Rejoin and Resume teleport the same way: the access code reaches the live server, or boots a fresh one that resumes.
function SessionService:Rejoin(player: Player, offer: Offer)
	self.Joining[player] = 0
	-- read again: the run may have ended (or its window closed) while the card was up; a Resume that became Live
	-- (somebody else resumed it first) is a plain rejoin of the same server
	const run, mode, left = self:OpenRun(player.UserId, offer.RunId)
	if run == nil then
		self.Joining[player] = nil
		self.Offers[player] = nil
		self:ClearPointer(player.UserId, offer.RunId)
		self:Send(player, "None", "Ended", nil)
		return
	end
	const options = Teleport.Options(run.Code, { [RULES.RejoinFlag] = true })
	const retries = RULES.TeleportRetries
	for attempt = 1, #retries + 1 do
		if player.Parent == nil then
			self.Joining[player] = nil
			return
		end
		const ok, problem = Teleport.Send({ player }, options)
		if ok then
			-- TeleportInitFailed may still come back for this player (OnTeleportFailed)
			task.delay(RULES.JoinTimeout, function()
				if player.Parent ~= nil and self.Joining[player] == 0 then
					self.Joining[player] = nil
				end
			end)
			return
		end
		warn(`[SessionService] rejoin teleport of {player.Name} failed (try {attempt}): {problem}`)
		if attempt <= #retries then
			task.wait(retries[attempt])
		end
	end
	self.Joining[player] = nil
	self:Send(player, "None", "Failed", nil)
	-- the offer stays: the card comes back so they can try again (the Left of a Resume counts from the first read)
	self:Offer(player, offer.RunId, run, mode, left)
end

function SessionService:OnTeleportFailed(player: Player, result: Enum.TeleportResult, message: string)
	const tries = self.Joining[player]
	const offer = self.Offers[player]
	if tries == nil or offer == nil or result == Enum.TeleportResult.IsTeleporting then
		return
	end
	const retries = RULES.TeleportRetries
	warn(`[SessionService] rejoin of {player.Name} failed ({result.Name}: {message}); try {tries + 1}`)
	if tries >= #retries then
		self.Joining[player] = nil
		self:Send(player, "None", "Failed", nil)
		task.spawn(function()
			const run, mode, left = self:OpenRun(player.UserId, offer.RunId)
			if run ~= nil then
				self:Offer(player, offer.RunId, run, mode, left)
			else
				self.Offers[player] = nil
			end
		end)
		return
	end
	self.Joining[player] = tries + 1
	task.delay(retries[tries + 1], function()
		if player.Parent == nil or self.Joining[player] == nil then
			return
		end
		const ok, problem =
			Teleport.Send({ player }, Teleport.Options(offer.Code, { [RULES.RejoinFlag] = true }))
		if not ok then
			self:OnTeleportFailed(player, Enum.TeleportResult.Failure, problem or "TeleportAsync failed")
		end
	end)
end

-- Run server -----------------------------------------------------------------------------------------------------------

function SessionService:Record(state: RunState): RunRecord
	const round = self.Dependencies.RoundService
	const started = round:IsStarted()
	return {
		V = VERSION,
		Code = self.Code,
		Roster = table.clone(self.Dependencies.RunStateService.Roster()),
		State = state,
		JobId = game.JobId,
		Day = if started then round:GetDay() else 0,
		IsNight = started and round:IsNight(),
		ExpiresAt = 0,
		CreatedAt = self.CreatedAt,
		UpdatedAt = os.time(),
	}
end

-- Every roster member this server knows of (the RunStateService roster, else the one read on boot)
function SessionService:RosterIds(): { number }
	const roster = table.clone(self.Dependencies.RunStateService.Roster())
	for _, userId in self.BootRoster do
		if table.find(roster, userId) == nil then
			table.insert(roster, userId)
		end
	end
	return roster
end

function SessionService:PointerHere(): Pointer
	return { V = VERSION, RunId = self.RunId, Code = self.Code, At = os.time() }
end

-- Boot (architecture.md §5.5 step 1-2): reads the Runs record and takes it over in one UpdateAsync.
--   Claimed  the lobby's "Starting" record (or our own): Live, a normal run
--   Resume   Suspended in its window, or Live/Resuming with a stopped beat in its window: Resuming, this JobId
--   Taken    another server holds it with a fresh beat
--   Dead     ended, expired or gone, and the first player came from a rejoin
--   None     no session (no record on a launch boot, MemoryStore off): a run without rejoin
function SessionService:Claim(rejoin: boolean): Verdict
	const map = self.Runs
	if map == nil then
		return "None"
	end
	local verdict: Verdict = "None"
	const ok, problem = pcall(function()
		map:UpdateAsync(self.RunId, function(value: any): any
			const current = readRun(value)
			if current == nil then
				verdict = if rejoin then "Dead" else "None"
				return nil
			end
			self.BootRoster = current.Roster
			if current.State == "Starting" or current.JobId == game.JobId then
				verdict = "Claimed"
				self.Code = current.Code
				self.CreatedAt = current.CreatedAt
				const claimed = self:Record("Live")
				-- the roster seated by PartyRunService may still be empty on a slow boot: keep the lobby's
				if #claimed.Roster == 0 then
					claimed.Roster = current.Roster
				end
				return claimed
			end
			const stand = standing(current, os.time())
			if stand == "Live" then
				verdict = "Taken"
				return nil
			elseif stand == "Gone" then
				verdict = "Dead"
				return nil
			end
			verdict = "Resume"
			self.Code = current.Code
			self.CreatedAt = current.CreatedAt
			const resuming = table.clone(current)
			resuming.State = "Resuming"
			resuming.JobId = game.JobId
			resuming.ExpiresAt = resumeDeadline(current)
			resuming.UpdatedAt = os.time()
			return resuming
		end, RULES.RunTtl)
	end)
	if not ok then
		self:Warn("claim run", problem)
		-- a rejoin teleport only boots a server for a run that existed: without the record it cannot be resumed
		return if rejoin then "Dead" else "None"
	end
	return verdict
end

function SessionService:Beat()
	const map = self.Runs
	if map == nil or not self.Claimed or self.Ended then
		return
	end
	const record = self:Record(self.State)
	const ok, problem = pcall(function()
		map:SetAsync(self.RunId, record, RULES.RunTtl)
	end)
	if not ok then
		self:Warn("heartbeat", problem)
	end
end

-- Snap after every capture (start of each shift, repeated night): a server that falls without BindToClose leaves the
-- start of its shift behind (data.md §3.3, TTL SnapTtl). A table identity check every SnapWatch s, no request otherwise.
function SessionService:WatchSnapshots()
	const runState = self.Dependencies.RunStateService
	while not self.Ended do
		task.wait(RULES.SnapWatch)
		const snapshot = runState:LastSnapshot()
		if snapshot ~= nil and snapshot ~= self.Written and not self.Ended then
			self.Written = snapshot
			self:SetSnap(snapshot, RULES.SnapTtl)
		end
	end
end

-- Run over (RunEnded) or a run that cannot go on: nothing can be rejoined or resumed any more.
function SessionService:EndRun()
	if self.Ended or self.RunId == "" then
		return
	end
	self.Ended = true
	if self.Claimed then
		const runs = self.Runs
		if runs ~= nil then
			pcall(function()
				runs:RemoveAsync(self.RunId)
			end)
		end
		const snaps = self.Snaps
		if snaps ~= nil then
			pcall(function()
				snaps:RemoveAsync(self.RunId)
			end)
		end
	end
	for _, userId in self:RosterIds() do
		self:ClearPointer(userId, self.RunId)
	end
end

-- BindToClose with the run going (data.md §3.4): everyone left, or Roblox shuts the server down. The run waits
-- ResumeWindow s for its first member to come back (DEC-080). 3-6 requests, well inside the 30 s of BindToClose.
function SessionService:Suspend()
	if self.Ended or not self.Claimed or self.RunId == "" then
		return
	end
	const snapshot = self.Dependencies.RunStateService:LastSnapshot()
	if snapshot == nil or not self.Dependencies.RoundService:IsStarted() then
		-- nothing to resume from (closed before the first shift started)
		self:EndRun()
		return
	end
	self.Ended = true
	const now = os.time()
	-- 1. Snap: the start of the current shift (the shift in progress is lost, DEC-080)
	self:SetSnap(snapshot, RULES.SuspendTtl)
	-- 2. Runs: Suspended, the window, the day the card shows (the snapshot's: that is where it resumes)
	const record = self:Record("Suspended")
	record.ExpiresAt = now + WINDOW
	const day, isNight = snapShift(snapshot)
	if day ~= nil then
		record.Day = day
		record.IsNight = isNight
	end
	if #record.Roster == 0 then
		record.Roster = table.clone(self.BootRoster)
	end
	const map = self.Runs
	if map ~= nil then
		const ok, problem = pcall(function()
			map:UpdateAsync(self.RunId, function(value: any): any
				const current = readRun(value)
				-- another server took it over meanwhile: leave its record alone
				if current ~= nil and current.JobId ~= game.JobId and current.State ~= "Starting" then
					return nil
				end
				return record
			end, RULES.SuspendTtl)
		end)
		if not ok then
			self:Warn("suspend run", problem)
		end
	end
	-- 3. PlayerRun of every roster member, gone with the window
	const pointer = self:PointerHere()
	for _, userId in self:RosterIds() do
		self:SetPointer(userId, pointer, RULES.SuspendTtl)
	end
	print(`[SessionService] run {self.RunId} suspended for {WINDOW} s (Day {record.Day})`)
end

function SessionService:OnMemberLeft(player: Player)
	if self.Ended or not self.Claimed or self.Code == "" then
		return
	end
	if self.Dependencies.RunStateService.Members()[player.UserId] == nil then
		return
	end
	-- refreshes the pointer written on join (the last one out also gets it from Suspend, with the window's TTL)
	const userId = player.UserId
	const pointer = self:PointerHere()
	task.spawn(function()
		self:SetPointer(userId, pointer)
	end)
end

-- A member joins (first time or back): their pointer, so a crash of this server still leads them back (Resume).
function SessionService:OnMemberJoined(player: Player)
	if self.Ended or not self.Claimed or self.Code == "" then
		return
	end
	const userId = player.UserId
	const pointer = self:PointerHere()
	task.spawn(function()
		self:SetPointer(userId, pointer)
	end)
end

-- A rejoin landed on a server that cannot hold the run: send everyone here back to the lobby (the run client shows no
-- squad notices, so the trip back is the message). `forget` = the run is over: clear their pointers too (the lobby
-- then shows no card); false = another server holds it, the lobby offers it again.
function SessionService:DeadRun(forget: boolean)
	warn(
		if forget
			then "[SessionService] this run is gone (ended, window closed or no snapshot); sending its players back to the lobby"
			else "[SessionService] another server holds this run; sending its players back to the lobby"
	)
	self.Ended = true
	const partyRun = self.Dependencies.PartyRunService
	local function sendBack(player: Player)
		task.delay(RULES.DeadRunDelay, function()
			if player.Parent ~= nil then
				partyRun:SendToLobby({ player })
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		if forget then
			self:ClearPointer(player.UserId, nil)
		end
		sendBack(player)
	end
	Players.PlayerAdded:Connect(sendBack)
end

-- Resume (architecture.md §5.5 steps 3-6): Snap -> RunStateService:Load -> RoundService:ResumeRun -> Live.
-- False = "That shift can't be resumed." (no snapshot, unknown format): the run is over.
function SessionService:Resume(): boolean
	const snapshot = self:GetSnap(self.RunId)
	const runState = self.Dependencies.RunStateService
	if snapshot == nil or not runState:Load(snapshot) then
		warn(`[SessionService] run {self.RunId}: that shift can't be resumed (snapshot missing or unknown format)`)
		return false
	end
	self.Written = snapshot
	self.Resumed = true
	const round = self.Dependencies.RoundService
	-- Resume phase (15 s): ends early once the whole roster is back, never before ResumeMinWait
	round:SetPhaseProbe("Resume", function(): boolean
		if workspace:GetServerTimeNow() - round.PhaseStartedAt() < RULES.ResumeMinWait then
			return false
		end
		const members = runState.Members()
		for _, userId in runState.Roster() do
			const member = members[userId]
			if member == nil or member.State == "Away" or Players:GetPlayerByUserId(userId) == nil then
				return false
			end
		end
		return true
	end)
	round:ResumeRun()
	const day, isNight = snapShift(snapshot)
	print(`[SessionService] run {self.RunId} resumed (Day {day or "?"}, {if isNight then "night" else "day"})`)
	return true
end

function SessionService:StartRun()
	const role = self.Dependencies.RoleService
	const round = self.Dependencies.RoundService
	if not role:IsGame() or not role:IsReserved() or self.Runs == nil then
		round:SetResumeHold(false)
		return
	end
	self.RunId = game.PrivateServerId
	const verdict = self:Claim(self.FromRejoin)
	if verdict == "Dead" or verdict == "Taken" then
		-- the start stays held: this server never runs a shift
		self:DeadRun(verdict == "Dead")
		return
	end
	if verdict == "None" then
		self.RunId = ""
		round:SetResumeHold(false)
		return
	end
	self.Claimed = true
	if verdict == "Resume" then
		if not self:Resume() then
			self:EndRun()
			self:DeadRun(true)
			return
		end
	else
		round:SetResumeHold(false)
	end
	print(`[SessionService] run {self.RunId} live; rejoin {if self.Code ~= "" then "on" else "off (no access code)"}`)

	if self.Code ~= "" then
		const pointer = self:PointerHere()
		for _, userId in self:RosterIds() do
			task.spawn(function()
				self:SetPointer(userId, pointer)
			end)
		end
	end
	const players = self.Dependencies.PlayerService
	players.PlayerRemoving:Connect(function(player)
		self:OnMemberLeft(player)
	end)
	self.Dependencies.RunStateService.MemberJoined:Connect(function(player)
		self:OnMemberJoined(player)
	end)
	round.RunEnded:Connect(function()
		task.spawn(function()
			self:EndRun()
		end)
	end)
	game:BindToClose(function()
		-- the run goes on later (DEC-080): everyone left or the server is shutting down
		self:Suspend()
	end)
	task.spawn(function()
		self:Beat()
		while not self.Ended do
			task.wait(RULES.Heartbeat)
			self:Beat()
		end
	end)
	task.spawn(function()
		self:WatchSnapshots()
	end)
end

SessionService:OnInit(function(self)
	self:Setup()
	self:Open()
	const role = self.Dependencies.RoleService

	-- A fresh reserved server whose first player came from a rejoin teleport may be resuming a run: hold the run start
	-- (no Day 1) until StartRun read the Runs record. RoleService:OnInit already waited for that player.
	if role:IsGame() and role:IsReserved() and self.Runs ~= nil then
		const first = Players:GetPlayers()[1]
		const data = if first ~= nil then joinData(first) else nil
		self.FromRejoin = type(data) == "table" and data[RULES.RejoinFlag] == true
		if self.FromRejoin then
			self.Dependencies.RoundService:SetResumeHold(true)
		end
	end

	-- Responder on every role (Lync locks definitions at start); only lobby roles act on it
	self.Libs.Net.ReconnectReply:onServer(function(data, player: Player)
		if role:IsLobby() and type(data) == "table" then
			self:HandleReply(player, data.Accept == true)
		end
	end)
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.Offers[player] = nil
		self.Checked[player] = nil
		self.Joining[player] = nil
		self.LastReply[player] = nil
	end)
end)

SessionService:OnStart(function(self)
	const role = self.Dependencies.RoleService
	if role:IsLobby() then
		if self.Pointers == nil then
			return
		end
		local function check(player: Player)
			task.spawn(function()
				self:Check(player)
			end)
		end
		self.Dependencies.PlayerService.PlayerAdded:Connect(check)
		for _, player in Players:GetPlayers() do
			check(player)
		end
		TeleportService.TeleportInitFailed:Connect(function(player, result, message)
			self:OnTeleportFailed(player, result, message)
		end)
		return
	end
	task.spawn(function()
		self:StartRun()
	end)
end)

return SessionService
