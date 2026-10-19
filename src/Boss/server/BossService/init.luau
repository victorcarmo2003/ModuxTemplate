--!strict
-- Boss (Walt) phone calls (FEAT-018, FEAT-024; DEC-025, 077, 124, 194; architecture.md §19.9; network.md §13.3;
-- data.md §3.3 "Bs"; ui-text.md §11; TASK-070). Run place only. Single writer of the Call set (record 1).
--
-- Triggers (§19.9): PhaseChanged("Prep") of a day -> call_day_after_<k> / call_day_<N> (quentin variant) / endless
-- pool; PhaseChanged("Call") -> call_night_<N> (first attempt) or the night's ShortCall (Attempt > 0), after the
-- pending lost-night calls; NightResolved("Lost") ->
-- call_lost_critical (reason critical) + call_lost_last_chance when a chance is left (none left = call_run_over,
-- which never rings: the run end screen quotes it); InteractionService.Performed -> hint_<action> (first time).
-- Which row a trigger picks lives in Calls.luau (Content.BossCalls, Content.Nights).
--
-- Queue: one call at a time, highest Priority first, then arrival order. Idle + queue -> Ringing (both phones of the
-- current vehicle, prompt "Answer") -> answer_phone or AutoAnswer (15 s) -> Talking for #LinesOf x LineTime ->
-- next queued call goes straight to Talking (Walt stays on the line; this is what keeps the sequences of one Call
-- phase inside its 60 s cap, Validate L2-12) or Idle. The server only writes StartedAt: the line is
-- floor((now - StartedAt) / LineTime), the same for everyone, and whoever joins mid-call gets the rest (T44).
-- No call starts in Finale, NightLost, RunEnd or Resume; entering one hangs up the current call, and
-- NightLost/RunEnd/Resume also empty the queue. Probe "Call" = queue empty and the phone Idle.
-- Once rows are marked played when they start Talking (heard), so a shift capture taken at the shift start does
-- not hold the call of that shift: a Resume plays it again. Snapshot "Bs" = sorted played keys, restored as is.
--
-- Tutorial call (user request 2026-10-11, Provisional; BossCalls Trigger Tutorial): while a player in the server has
-- the first-hot-dog tutorial ahead (TutorialService:AnyPending), the tutorial call is queued in a day Prep/Open
-- (Priority 4, ahead of the day call; on Day 1 it replaces the DayPrep call, marked heard). It never answers itself
-- (answering is the tutorial's first step), and once answered it is held Talking (the rookie's client voices the
-- step lines) until nobody has the tutorial pending; then it stays Rules.Tutorial.Goodbye s for Walt's goodbye and
-- hangs up. Nobody pending while it rings = the ring stops. Leaving the day Prep/Open hangs it up. Queuing it marks the
-- Hint rows of Rules.Tutorial.Covers as heard (the tutorial teaches those), so no second phone talks over it.
-- One ring per tutorial (user request 2026-10-11, Provisional): the phone rings once at the start; once answered, Walt
-- stays on the line for the whole tutorial (Mart trip included: no proximity rule). If the held call is cut anyway
-- (another call forced through dev, a phase hiccup) it comes back straight to Talking when it leaves the queue, never
-- ringing again (TutorialAnswered), until nobody has the tutorial pending.
--
-- Trailer (user decision 2026-10-12): the Food Trailer is the only vehicle from Day 1, so there is no trailer offer, no
-- purchase call, no money top-up and no FOR SALE sign focus any more (the rows and cues left BossCalls).
--
-- PROVISIONAL (TASK-070): chaining without a new ring; Resume blocks calls like NightLost.
-- Require follows architecture.md §19.2: VehicleService (phones of the current vehicle) and ThiefService (owner of the
-- quentin_caught_day counter read through RunStateService); neither requires Boss, no cycle.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local Calls = require(script.Calls)
local TutorialRules = require(ReplicatedStorage.shared.Tutorial.Rules)
local Modux = require(ServerScriptService.server.Modux)

export type State = "Idle" | "Ringing" | "Talking"

-- Call set record (network.md §13.3)
export type Record = { Call: string, State: State, StartedAt: number }

export type Entry = { Key: string, Priority: number, Order: number }

const RECORD = 1 -- single record (network.md §13.3)
const NONE = "none"
const TICK_RATE = 10 -- Hz: ring and line ends at most 0.1 s late
const TAG = "Interactable"
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle"
const PHONE_ACTION = "answer_phone"
const CAUGHT_COUNTER = "quentin_caught_day" -- written by ThiefService (TASK-072)
const SNAPSHOT = "Bs"
const AUTO_ANSWER = Content.BossCallRules.AutoAnswer
const MAX_QUEUE = 32 -- far above any real sequence; guards a runaway trigger
const TUTORIAL = Content.BossCallRules.Tutorial
-- Day 1 upgrade lesson call (owner request 2026-10-14, Provisional; Trigger UpgradeLesson, Once)
const LESSON_CALL = TutorialRules.Upgrade.Call
-- day phases where the tutorial call may ring and talk
const TUTORIAL_PHASES: { [string]: boolean } = { Prep = true, Open = true }
-- No call starts here; entering one hangs up (architecture.md §19.9 "Fila")
const BLOCKED: { [string]: boolean } = { Finale = true, NightLost = true, RunEnd = true, Resume = true }
-- Entering one of these also empties the queue
const CLEARS: { [string]: boolean } = { NightLost = true, RunEnd = true, Resume = true }

local function now(): number
	return workspace:GetServerTimeNow()
end

const BossService = Modux.Service("BossService", {
	Require = {
		"PlaceService",
		"NetService",
		"RoundService",
		"RunStateService",
		"InteractionService",
		"ThiefService",
		"TutorialService",
		"EconomyService",
		"VitalService",
	},
	Priority = 560,
})

function BossService:Setup()
	self.Enabled = false :: boolean
	self.Record = self.Libs.Charm.atom({ Call = NONE, State = "Idle", StartedAt = 0 } :: Record) :: Charm.Atom<Record>
	-- Server time the current Talking ends (0 when not talking)
	self.EndsAt = 0 :: number
	self.Queue = {} :: { Entry }
	self.Order = 0 :: number
	-- Once rows already heard this run (snapshot Bs)
	self.Played = {} :: { [string]: boolean }
	-- Lost-night calls for the Call phase of the repeated night (survive the RepeatNight restore)
	self.Pending = {} :: { string }
	self.LastInfinite = "" :: string
	self.Random = Random.new() :: Random
	-- the tutorial call was answered once while a tutorial is pending: it never rings again, it resumes Talking
	self.TutorialAnswered = false :: boolean
	-- cues already run for the call that is talking (id = key # index @ StartedAt)
	self.Cued = {} :: { [string]: boolean }
end

-- Reads -----------------------------------------------------------------------------------------------------------

function BossService:GetState(): State
	return self.Record().State
end

function BossService:GetCall(): string
	return self.Record().Call
end

-- Something rings, talks or waits in the queue
function BossService:IsBusy(): boolean
	return self.Record().State ~= "Idle" or #self.Queue > 0
end

function BossService:HasPlayed(key: string): boolean
	return self.Played[key] == true
end

-- Lines spoken for a key on the current shift (a repeated night appends that night's Short lines)
function BossService:LinesOf(key: string): { Content.BossCallLine }
	return Content.BossCalls.LinesOf(key, self.Dependencies.RoundService:GetNight())
end

function BossService:CanStart(): boolean
	const round = self.Dependencies.RoundService
	return self.Enabled and round:IsStarted() and not BLOCKED[round:GetPhase()]
end

-- Queue -----------------------------------------------------------------------------------------------------------

function BossService:IsQueued(key: string): boolean
	for _, entry in self.Queue do
		if entry.Key == key then
			return true
		end
	end
	return false
end

-- Adds a call to the queue. False when the key cannot ring, a Once row was heard (unless forced), it is already
-- queued or on the phone, or the queue is full. front = ahead of everything (dev).
function BossService:Enqueue(key: string, forced: boolean?, front: boolean?): boolean
	const row = Calls.row(key)
	if row == nil or not Calls.isRingable(key) then
		return false
	end
	if row.Once and self.Played[key] and not forced then
		return false
	end
	if self:IsQueued(key) or (self.Record().Call == key and self.Record().State ~= "Idle") then
		return false
	end
	if #self.Queue >= MAX_QUEUE then
		warn(`[BossService] queue full, {key} dropped`)
		return false
	end
	self.Order += 1
	const entry: Entry = { Key = key, Priority = if front then math.huge else row.Priority, Order = self.Order }
	table.insert(self.Queue, entry)
	table.sort(self.Queue, function(a: Entry, b: Entry): boolean
		if a.Priority ~= b.Priority then
			return a.Priority > b.Priority
		end
		return a.Order < b.Order
	end)
	return true
end

function BossService:Unqueue(key: string)
	for index, entry in self.Queue do
		if entry.Key == key then
			table.remove(self.Queue, index)
			return
		end
	end
end

function BossService:Pop(): string?
	const entry = table.remove(self.Queue, 1)
	return if entry then entry.Key else nil
end

-- Phone ------------------------------------------------------------------------------------------------------------

function BossService:IsPhone(anchor: Instance): boolean
	return anchor:GetAttribute("PromptAction") == PHONE_ACTION
end

-- Phone of the current vehicle (Shift.Vehicle). An anchor outside any Vehicle model counts (unbound map).
function BossService:IsCurrentPhone(anchor: Instance): boolean
	local current = anchor.Parent
	while current ~= nil and current ~= workspace do
		if CollectionService:HasTag(current, VEHICLE_TAG) then
			return current:GetAttribute(VEHICLE_ATTRIBUTE) == self.Dependencies.RoundService:CurrentVehicle()
		end
		current = current.Parent
	end
	return true
end

-- "Answer" only on the ringing phone of the current vehicle
function BossService:RefreshPhone(anchor: Instance)
	const ringing = self.Enabled and self.Record().State == "Ringing"
	self.Dependencies.InteractionService:SetPrompt(anchor, ringing and self:IsCurrentPhone(anchor))
end

function BossService:RefreshPhones()
	for _, anchor in CollectionService:GetTagged(TAG) do
		if self:IsPhone(anchor) then
			self:RefreshPhone(anchor)
		end
	end
end

-- Call flow --------------------------------------------------------------------------------------------------------

function BossService:Write(key: string, state: State, startedAt: number)
	self.Record({ Call = key, State = state, StartedAt = startedAt })
	self:RefreshPhones()
end

function BossService:Ring(key: string)
	self.EndsAt = 0
	self:Write(key, "Ringing", now())
end

-- Walt starts talking at `at`; a Once row counts as heard from here
function BossService:Talk(key: string, at: number)
	const row = Calls.row(key)
	if row and row.Once then
		self.Played[key] = true
	end
	table.clear(self.Cued)
	-- the tutorial call is held open until no tutorial is pending (StepTutorial)
	-- each line lasts its voice (Content.BossCalls.LengthOf, owner 2026-10-18), not a fixed LineTime
	self.EndsAt = if key == TUTORIAL.Call then math.huge else at + Content.BossCalls.LengthOf(self:LinesOf(key))
	self:Write(key, "Talking", at)
end

-- Hangs up now (no line is lost from the queue unless clear)
function BossService:Stop(clear: boolean)
	if clear then
		table.clear(self.Queue)
	end
	self.EndsAt = 0
	if self.Record().State ~= "Idle" then
		self:Write(NONE, "Idle", 0)
	end
end

-- End of the last line: the next queued call follows without ringing again
function BossService:Finish(at: number)
	const nextKey = if self:CanStart() then self:Pop() else nil
	if nextKey then
		self:Talk(nextKey, at)
	else
		self:Stop(false)
	end
end

-- answer_phone, or AutoAnswer
function BossService:Answer()
	const record = self.Record()
	if record.State == "Ringing" then
		if record.Call == TUTORIAL.Call then
			self.TutorialAnswered = true
		end
		self:Talk(record.Call, now())
	end
end

function BossService:Step()
	const record = self.Record()
	const t = now()
	self:StepTutorial(t)
	self:StepLesson()
	if record ~= self.Record() then
		return
	end
	if record.State == "Ringing" then
		-- the tutorial call never answers itself: answering is the tutorial's first step
		if t >= record.StartedAt + AUTO_ANSWER and record.Call ~= TUTORIAL.Call then
			self:Answer()
		end
	elseif record.State == "Talking" then
		self:RunCues(record, t)
		if t >= self.EndsAt then
			self:Finish(t)
		end
	elseif #self.Queue > 0 and self:CanStart() then
		const key = self:Pop()
		if key ~= nil then
			if key == TUTORIAL.Call and self.TutorialAnswered then
				-- the rookie already picked up: Walt is back on the line without a second ring
				self:Talk(key, t)
			else
				self:Ring(key)
			end
		end
	end
end

-- Cues ----------------------------------------------------------------------------------------------

-- Runs the cues of the talking call whose line has started (once each)
function BossService:RunCues(record: Record, t: number)
	const row = Calls.row(record.Call)
	const cues = if row then row.Cues else nil
	if cues == nil then
		return
	end
	const line = Content.BossCalls.LineAt(self:LinesOf(record.Call), t - record.StartedAt)
	for index, cue in cues do
		const id = `{record.Call}#{index}@{record.StartedAt}`
		if line >= cue.Line and not self.Cued[id] then
			self.Cued[id] = true
			if cue.Kind == "CoffeeHint" then
				-- seconds of this call still to run: the emphasis lasts that long plus Sanity.CoffeeHint
				const callLeft = math.max(0, self.EndsAt - t)
				self.Dependencies.VitalService:StartCoffeeHint(callLeft)
			end
		end
	end
end

-- Tutorial call ----------------------------------------------------------------------------------------------------

function BossService:TutorialAllowed(): boolean
	const round = self.Dependencies.RoundService
	return self.Enabled and round:IsStarted() and not round:IsNight() and TUTORIAL_PHASES[round:GetPhase()] == true
end

-- Queues the tutorial call; the Hint rows it teaches count as heard (and leave the queue)
function BossService:QueueTutorial()
	if not self:Enqueue(TUTORIAL.Call) then
		return
	end
	for _, action in TUTORIAL.Covers do
		const hint = Calls.hint(action)
		if hint then
			self.Played[hint] = true
			self:Unqueue(hint)
		end
	end
end

-- Rings, holds and hangs up the tutorial call from TutorialService:AnyPending (polled: a rookie finishing, skipping or
-- leaving all end the same way)
function BossService:StepTutorial(t: number)
	const key = TUTORIAL.Call
	const record = self.Record()
	const allowed = self:TutorialAllowed()
	const pending = allowed and self.Dependencies.TutorialService:AnyPending()
	if not pending and not (record.Call == key and record.State ~= "Idle") then
		-- tutorial over (or off for now): a later tutorial starts with a ring again
		self.TutorialAnswered = false
	end
	if record.Call == key and record.State ~= "Idle" then
		if not allowed or (not pending and record.State == "Ringing") then
			self:Stop(false)
		elseif not pending and self.EndsAt == math.huge then
			-- the last rookie is done: Walt's goodbye, then the hang up (Step -> Finish)
			self.EndsAt = t + TUTORIAL.Goodbye
		end
		return
	end
	if self:IsQueued(key) then
		if not pending then
			self:Unqueue(key)
		end
		return
	end
	if pending then
		self:QueueTutorial()
	end
end

-- Day 1 upgrade lesson: queued once the first shift is over and the last-call line is empty (TutorialService decides)
function BossService:StepLesson()
	if self.Played[LESSON_CALL] or self:IsQueued(LESSON_CALL) or self.Record().Call == LESSON_CALL then
		return
	end
	if self:CanStart() and self.Dependencies.TutorialService:LessonCallDue() then
		self:Enqueue(LESSON_CALL)
	end
end

-- Triggers ---------------------------------------------------------------------------------------------------------

function BossService:OnDayPrep(day: number, night: number)
	const runState = self.Dependencies.RunStateService
	const key = Calls.day({
		Day = day,
		Night = night,
		CaughtDay = runState.Counters()[CAUGHT_COUNTER] or 0,
		Endless = runState.Endless(),
		LastInfinite = self.LastInfinite,
		Played = self.Played,
	}, self.Random)
	if key == nil then
		return
	end
	const row = Calls.row(key)
	if row and row.Trigger.Kind == "DayPrep" and row.Trigger.Day == 1 and self.Dependencies.TutorialService:AnyPending() then
		-- Day 1 call = the old tutorial opener: the tutorial call replaces it (heard, so a Resume does not ring it)
		self.Played[key] = true
		self:QueueTutorial()
		return
	end
	if row and row.Trigger.Kind == "DayInfinite" then
		self.LastInfinite = key
	end
	self:Enqueue(key)
end

-- Call phase of a night: lost-night calls first by Priority, then the night's own call
function BossService:OnNightCall(night: number, attempt: number)
	for _, key in self.Pending do
		self:Enqueue(key, true)
	end
	table.clear(self.Pending)
	const call, short = Calls.night(night)
	const key = if attempt > 0 then short else call
	if key then
		self:Enqueue(key)
	end
	-- Night 1 teaches the coffee: after the rules call (lower Priority), on a repeat too (the night starts at 50 again)
	const coffee = Calls.nightCoffee(night)
	if coffee then
		self:Enqueue(coffee)
	end
end

function BossService:OnPhase(phase: string, day: number, night: number)
	if CLEARS[phase] then
		self:Stop(true)
		if phase ~= "NightLost" then
			table.clear(self.Pending)
		end
	elseif BLOCKED[phase] then
		self:Stop(false)
	end
	const round = self.Dependencies.RoundService
	if phase == "Prep" and not round:IsNight() then
		self:OnDayPrep(day, night)
	elseif phase == "Call" then
		self:OnNightCall(night, round:Info().Attempt)
	end
	self:RefreshPhones()
end

-- NightResolved fires before PhaseChanged("NightLost"): the calls wait in Pending for the repeated night's Call.
-- No chance left = the run ends; call_run_over never rings.
function BossService:OnNightResolved(result: string, reason: string?)
	if result ~= "Lost" then
		return
	end
	table.clear(self.Pending)
	if self.Dependencies.RunStateService.Chances() <= 0 then
		return
	end
	if reason == "critical" then
		const critical = Calls.ofKind("LostCritical")
		if critical then
			table.insert(self.Pending, critical)
		end
	end
	const lastChance = Calls.ofKind("LostLastChance")
	if lastChance then
		table.insert(self.Pending, lastChance)
	end
end

function BossService:OnPerformed(action: string)
	const key = Calls.hint(action)
	if key then
		self:Enqueue(key)
	end
end

-- Snapshot "Bs" (data.md §3.3) -------------------------------------------------------------------------------------

function BossService:CaptureBoss(): { string }
	const keys: { string } = {}
	for key in self.Played do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

function BossService:RestoreBoss(data: any)
	const played: { [string]: boolean } = {}
	if type(data) == "table" then
		for _, key in data do
			if type(key) == "string" and Calls.row(key) ~= nil then
				played[key] = true
			end
		end
	end
	self.Played = played
end

-- Dev hooks (commands in DevService/Commands/Boss.luau) -----------------------------------------------------------

function BossService:DevCheck(name: string)
	if not self.Dependencies.PlaceService:IsDev() then
		error(`[BossService] {name} is dev mode only`, 3)
	end
	if not self.Enabled then
		error(`[BossService] {name}: not the Run place`, 3)
	end
end

-- Rings `key` now, ahead of the queue, ignoring Once. Refused in the blocked phases.
function BossService:DevCall(key: string)
	self:DevCheck("DevCall")
	if not Calls.isRingable(key) then
		error(`[BossService] DevCall: {key} is not a call that rings`, 2)
	end
	if not self:CanStart() then
		error(`[BossService] DevCall: no call in {self.Dependencies.RoundService:GetPhase()} (or run not started)`, 2)
	end
	self:Stop(false)
	for index, entry in self.Queue do
		if entry.Key == key then
			table.remove(self.Queue, index)
			break
		end
	end
	self:Enqueue(key, true, true)
	self:Step()
end

function BossService:DevAnswer()
	self:DevCheck("DevAnswer")
	if self.Record().State ~= "Ringing" then
		error("[BossService] DevAnswer: the phone is not ringing", 2)
	end
	self:Answer()
end

function BossService:DevStop()
	self:DevCheck("DevStop")
	self:Stop(true)
end

-- Tutorial restarted (/dev tutorial reset): its call off the phone and the queue, the next one rings again
function BossService:DevResetTutorial()
	self:DevCheck("DevResetTutorial")
	const record = self.Record()
	if record.Call == TUTORIAL.Call and record.State ~= "Idle" then
		self:Stop(false)
	end
	self:Unqueue(TUTORIAL.Call)
	self.TutorialAnswered = false
end

-- One line: state, call, current line and queue
function BossService:DevStatus(): string
	const record = self.Record()
	local text = `Call {record.State}`
	if record.State ~= "Idle" then
		text ..= ` {record.Call}`
	end
	if record.State == "Talking" then
		const lines = #self:LinesOf(record.Call)
		const line = Content.BossCalls.LineAt(self:LinesOf(record.Call), now() - record.StartedAt)
		text ..= ` line {math.clamp(line, 1, math.max(lines, 1))}/{lines}`
	elseif record.State == "Ringing" then
		text ..= ` (auto-answer in {math.max(0, math.ceil(record.StartedAt + AUTO_ANSWER - now()))} s)`
	end
	const queued: { string } = {}
	for _, entry in self.Queue do
		table.insert(queued, entry.Key)
	end
	text ..= `; queue [{table.concat(queued, ", ")}]; played {#self:CaptureBoss()}; tutorial answered {self.TutorialAnswered}`
	if #self.Pending > 0 then
		text ..= `; pending [{table.concat(self.Pending, ", ")}]`
	end
	return text
end

-- Lifecycle ----------------------------------------------------------------------------------------------------------

BossService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	const round = self.Dependencies.RoundService
	const runState = self.Dependencies.RunStateService
	const interaction = self.Dependencies.InteractionService

	-- In OnInit: RoundService (750) starts the run in its own OnStart, before ours; the probe and the signals must
	-- already be there for the first PhaseChanged.
	round:SetPhaseProbe("Call", function(): boolean
		return not self:IsBusy()
	end)
	round.PhaseChanged:Connect(function(phase, day, night)
		self:OnPhase(phase, day, night)
	end)
	round.NightResolved:Connect(function(_info, result, reason)
		self:OnNightResolved(result, reason)
	end)

	runState:RegisterSnapshot(SNAPSHOT, function()
		return self:CaptureBoss()
	end, function(data, _mode)
		self:RestoreBoss(data)
	end)

	interaction:RegisterAction(PHONE_ACTION, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			return self.Record().State == "Ringing" and runState:IsActive(player) and self:IsCurrentPhone(anchor)
		end,
		Run = function(_player: Player, _anchor: Instance, _id: number)
			self:Answer()
		end,
	})
	-- Listeners run inside the per-target queue: no yield here
	interaction.Performed:Connect(function(_player, action)
		self:OnPerformed(action)
	end)
end)

BossService:OnStart(function(self)
	if not self.Enabled then
		return
	end

	-- Lync.start already ran (NetService OnStart, priority 1000). Late joiners get the record from the set.
	self.Libs.Net.Call:add(RECORD, self.Record())
	self.Libs.Charm.effect(function()
		const record = self.Record()
		if self.Dependencies.NetService:IsRunning() then
			self.Libs.Net.Call:update(RECORD, record)
		end
	end)

	-- InteractionService (730) already scanned the anchors with the default PromptEnabled: phones start silent
	self:RefreshPhones()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(anchor)
		if self:IsPhone(anchor) then
			self:RefreshPhone(anchor)
		end
	end)
end)

BossService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return BossService
