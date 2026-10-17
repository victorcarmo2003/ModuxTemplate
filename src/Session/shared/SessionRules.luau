--!strict
-- Rejoin a run in progress (owner request 2026-10-17; DEC-063, DEC-067; architecture.md §5.3, §5.4; data.md §3.1,
-- §3.2; TASK-360, Provisional). ReplicatedStorage.shared.Session.SessionRules. Pure: no Modux, Lync, Vide nor self.Libs.
-- Shared by SessionService (lobby + game roles), the lobby SessionController and the Net contract (Reconnect enums).
-- Numbers are Provisional (Q-290): one line here changes them, no code.

-- Reconnect.Mode (s -> c, lobby). Rejoin = the run is live on its server; Resume = nobody is in it (everyone left or the
-- server fell) and it can be resumed from the start of its shift for a while (DEC-080, DEC-119; Q-291).
const MODES = table.freeze({ "None", "Rejoin", "Resume" })

-- Reconnect.Reason (s -> c, lobby): why the offer went away. None = nothing to say (dismissed, accepted, no offer).
const REASONS = table.freeze({
	"None",
	"Ended", -- the run is over (or its server is gone): nothing to rejoin
	"Failed", -- every teleport attempt failed: the offer comes back
	"StudioNoTeleport", -- Studio cannot teleport (dev offer)
	"TooFast", -- reply rate limit
})

const RULES = table.freeze({
	-- MemoryStore HashMaps (shared by every server of the universe; data.md §3.1, §3.2). `_v1` = format version.
	RunsMap = "Runs_v1", -- key = RunId (PrivateServerId of the run server)
	PlayerRunMap = "PlayerRun_v1", -- key = tostring(UserId)
	-- Runs record written by the lobby before the teleport: the run server claims it on boot (State Starting)
	StartingTtl = 300, -- s
	-- Runs record of a live run: rewritten every Heartbeat s, gone Ttl s after the last beat (crashed server)
	Heartbeat = 30, -- s
	RunTtl = 960, -- s
	-- a run whose last beat is older than this is not offered (server gone without BindToClose)
	Stale = 90, -- s
	-- PlayerRun pointer written when a roster member leaves a live run; the run server removes it on return / run end.
	-- Long on purpose: a live run is checked through Runs (Stale), so an old pointer never shows a dead run
	PointerTtl = 6 * 3600, -- s
	-- lobby: how long the server waits for the client's Lync handshake before giving up on the offer
	ReadyWait = 30, -- s
	-- c -> s ReconnectReply: one per player per this many seconds
	ReplyRate = 1, -- s
	-- Snap HashMap (data.md §3.3): the start-of-shift snapshot of a run, key = RunId. Written by the run server at every
	-- capture (SnapTtl) and when it suspends (SuspendTtl); read by the server that resumes the run
	SnapMap = "Snap_v1",
	SnapTtl = 2700, -- s alive: longer than the longest night (30 min) + the resume window (data.md §3.3)
	-- run server: how often it looks for a new capture to write (a table identity check, no request)
	SnapWatch = 2, -- s
	-- Runs, Snap and PlayerRun of a suspended run (architecture.md §5.5): the resume window (Content.RunParams.ResumeWindow,
	-- 900 s) plus a margin, so nothing is gone before the window closes
	SuspendTtl = 960, -- s
	-- Resume phase (architecture.md §5.5 step 5): ends early when the whole roster is back, but never before this
	ResumeMinWait = 5, -- s
	-- teleport retries of a rejoin (the same 2/5/10 s of the squad launch, architecture.md §5.2)
	TeleportRetries = table.freeze({ 2, 5, 10 }),
	-- a rejoin teleport accepted by Roblox that neither leaves nor fails frees the player's replies after this (the
	-- client's "Joining..." waits a little longer: SessionController ANSWER_TIMEOUT 45 s)
	JoinTimeout = 40, -- s
	-- TeleportData of a rejoin teleport: a server that boots from it (its run is gone) sends the player back
	RejoinFlag = "Rejoin",
	-- run server: s before a player who arrived at a dead run is sent back (the client finishes loading first)
	DeadRunDelay = 2,
})

return table.freeze({
	Modes = MODES,
	Reasons = REASONS,
	Rules = RULES,
})
