--!strict
-- Day shift cycle (FEAT-002, FEAT-003; DEC-048, DEC-085; network.md §3.1; architecture.md §3.1, §4.1, §7; TASK-012).
-- Run place only. Single writer of the Shift set (record 1). Wave 1 runs days only: Prep -> Open -> Closing -> Summary,
-- then Day N + 1 (no night). Phase lengths and clock ranges come from Content.Shift; nothing here is a design number.
-- The clock never pauses (DEC-085 a): a phase ends at PhaseStartedAt + Duration whoever is connected. Early ends:
-- "Open Shop" on the sign (Prep), counter empty (Closing), DevSkipPhase (dev mode). All of them go through EndPhase,
-- the same path as the timer.
-- Order at the shift boundary (architecture.md §7, DEC-121): Summary starts -> ShiftEnded (Economy deposits) ->
-- FixPriceParty on Day 1; Summary ends -> Day + 1 -> Prep written -> ShiftStarted -> PhaseChanged -> Capture.
-- The OPEN/CLOSED sign has no field: clients derive it from Phase (network.md §3.1). The server only keeps the
-- "Open Shop" prompt enabled during Prep.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

export type Phase = "Prep" | "Open" | "Closing" | "Summary"

-- Identifies a shift (data.md §3.3 "Sh"). Wave 1: Night = 0, IsNight = false, Attempt = 0.
export type ShiftInfo = { Day: number, Night: number, IsNight: boolean, Attempt: number }

-- Shift set record (network.md §3.1)
export type Record = {
	Day: number,
	Night: number,
	IsNight: boolean,
	Attempt: number,
	Phase: string,
	PhaseStartedAt: number,
	PhaseDuration: number,
	ClockFrom: number,
	ClockTo: number,
	Vehicle: string,
	Chances: number,
	WipeEndsAt: number,
	WipeFrozen: boolean,
}

const RECORD = 1 -- single record (network.md §1, rule 5)
const TAG = "Interactable" -- anchor tag (architecture.md §18.2)
const OPEN_ACTION = "open_sign"
const MAX_DAY = 10000 -- Shift.Day wire range
const TICK_RATE = 10 -- Hz; phase ends at most 0.1 s late, the next phase starts at the exact deadline
-- Next phase after each wave 1 day phase; Summary rolls over to the Prep of the next day
const NEXT: { [Phase]: Phase } = { Prep = "Open", Open = "Closing", Closing = "Summary", Summary = "Prep" }

const RoundService = Modux.Service("RoundService", {
	Require = { "PlaceService", "NetService", "RunStateService", "InteractionService" },
	Priority = 750,
})

function RoundService:Setup()
	self.Started = false :: boolean
	self.Day = self.Libs.Charm.atom(1) :: Charm.Atom<number>
	self.Phase = self.Libs.Charm.atom("Prep" :: Phase) :: Charm.Atom<Phase>
	self.PhaseStartedAt = self.Libs.Charm.atom(0) :: Charm.Atom<number>
	-- Counter probe for Closing, set by CustomerService (TASK-032). nil = no customer system = counter always empty.
	self.CounterEmpty = nil :: (() -> boolean)?
	-- Signals are created here so lower-priority services connect in their OnInit (architecture.md §3.1)
	self.PhaseChanged = self.Libs.Signal.new() :: SignalLib.Signal<Phase, number, number>
	self.ShiftStarted = self.Libs.Signal.new() :: SignalLib.Signal<ShiftInfo>
	self.ShiftEnded = self.Libs.Signal.new() :: SignalLib.Signal<ShiftInfo>
end

-- Reads -----------------------------------------------------------------------------------------------------------

function RoundService:GetPhase(): Phase
	return self.Phase()
end

function RoundService:GetDay(): number
	return self.Day()
end

function RoundService:IsNight(): boolean
	return false -- wave 1 has no night
end

function RoundService:IsStarted(): boolean
	return self.Started
end

function RoundService:Info(): ShiftInfo
	return { Day = self.Day(), Night = 0, IsNight = false, Attempt = 0 }
end

-- Content.Shift row of a phase (Duration, ClockFrom, ClockTo)
function RoundService:Row(phase: Phase): Content.Phase
	return Content.Shift.ByKey[phase]
end

-- Server time at which the current phase reaches its cap
function RoundService:Deadline(): number
	return self.PhaseStartedAt() + self:Row(self.Phase()).Duration
end

-- Game minutes now, same formula as the client (network.md §3.1), without the 10 min floor
function RoundService:Minutes(): number
	const row = self:Row(self.Phase())
	if row.Duration <= 0 then
		return row.ClockFrom
	end
	const alpha = math.clamp((workspace:GetServerTimeNow() - self.PhaseStartedAt()) / row.Duration, 0, 1)
	return row.ClockFrom + (row.ClockTo - row.ClockFrom) * alpha
end

function RoundService:Record(): Record
	const phase = self.Phase()
	const row = self:Row(phase)
	return {
		Day = self.Day(),
		Night = 0,
		IsNight = false,
		Attempt = 0,
		Phase = phase,
		PhaseStartedAt = self.PhaseStartedAt(),
		PhaseDuration = row.Duration,
		ClockFrom = row.ClockFrom,
		ClockTo = row.ClockTo,
		Vehicle = Content.RunParams.StartVehicle, -- VehicleService owns the swap in wave 2
		Chances = self.Dependencies.RunStateService.Chances(),
		WipeEndsAt = 0,
		WipeFrozen = false,
	}
end

-- Hooks -----------------------------------------------------------------------------------------------------------

-- CustomerService (TASK-032) tells whether the counter queue is empty. Closing ends on the first tick it says true.
function RoundService:SetCounterProbe(probe: () -> boolean)
	self.CounterEmpty = probe
end

-- Sign ------------------------------------------------------------------------------------------------------------

function RoundService:IsSign(anchor: Instance): boolean
	return anchor:GetAttribute("PromptAction") == OPEN_ACTION
end

-- "Open Shop" exists for the party only during Prep (Content.Actions.open_sign.Requires.Phase)
function RoundService:RefreshSign(anchor: Instance)
	const phases = Content.Actions.ByKey[OPEN_ACTION].Requires.Phase
	const enabled = self.Started and phases ~= nil and table.find(phases, self.Phase()) ~= nil
	self.Dependencies.InteractionService:SetPrompt(anchor, enabled)
end

function RoundService:RefreshSigns()
	for _, anchor in CollectionService:GetTagged(TAG) do
		if self:IsSign(anchor) then
			self:RefreshSign(anchor)
		end
	end
end

-- Phases ----------------------------------------------------------------------------------------------------------

-- One batch: the Shift effect sends a single update per phase change
function RoundService:Enter(phase: Phase, startedAt: number, day: number?)
	self.Libs.Charm.batch(function()
		if day ~= nil then
			self.Day(day)
		end
		self.Phase(phase)
		self.PhaseStartedAt(startedAt)
	end)
	self:RefreshSigns()
end

-- New shift: Day written, Prep from startedAt. capture = false only when a snapshot was just restored.
function RoundService:StartShift(day: number, startedAt: number, capture: boolean)
	self:Enter("Prep", startedAt, day)
	const info = self:Info()
	self.ShiftStarted:Fire(info)
	self.PhaseChanged:Fire("Prep", info.Day, info.Night)
	if capture then
		self.Dependencies.RunStateService:Capture()
	end
end

-- Ends the current phase. startedAt = when the next phase starts (deadline on timeout, now on an early end).
-- Single path for timer, sign, empty counter and DevSkipPhase.
function RoundService:EndPhase(startedAt: number)
	if not self.Started then
		return
	end
	const current = self.Phase()
	const nextPhase = NEXT[current]

	if current == "Summary" then
		self:StartShift(math.min(self.Day() + 1, MAX_DAY), startedAt, true)
		return
	end

	self:Enter(nextPhase, startedAt)
	const info = self:Info()
	if nextPhase == "Summary" then
		-- Shift is over: Economy deposits and sends ShiftReport, then PriceParty is fixed on Day 1 (DEC-121)
		self.ShiftEnded:Fire(info)
		if info.Day == 1 and not info.IsNight then
			self.Dependencies.RunStateService:FixPriceParty()
		end
	end
	self.PhaseChanged:Fire(nextPhase, info.Day, info.Night)
end

function RoundService:Step()
	if not self.Started then
		return
	end
	const deadline = self:Deadline()
	const now = workspace:GetServerTimeNow()
	if now >= deadline then
		self:EndPhase(deadline)
		return
	end
	if self.Phase() == "Closing" and now > self.PhaseStartedAt() then
		const probe = self.CounterEmpty
		local empty = true
		if probe then
			const ok, result = pcall(probe)
			if not ok then
				warn(`[RoundService] counter probe errored: {result}`)
			end
			empty = ok and result == true
		end
		if empty then
			self:EndPhase(now)
		end
	end
end

-- Run start: Day 1 Prep when the first member is in (Provisional, TASK-012: the clock does not run on an empty
-- dev server). Network writes start here; Lync.start already ran (NetService OnStart, priority 1000).
function RoundService:StartRun()
	if self.Started then
		return
	end
	self.Started = true
	self.Libs.Net.Shift:add(RECORD, self:Record())
	self.Libs.Charm.effect(function()
		const record = self:Record()
		if self.Dependencies.NetService:IsRunning() then
			self.Libs.Net.Shift:update(RECORD, record)
		end
	end)
	self:StartShift(self.Day(), workspace:GetServerTimeNow(), true)
end

-- Snapshot "Sh" (data.md §3.3). Restore goes back to the start of the captured shift without a new capture.
function RoundService:CaptureShift(): { [string]: any }
	const info = self:Info()
	return { D = info.Day, N = info.Night, Ni = info.IsNight, A = info.Attempt }
end

function RoundService:RestoreShift(data: { [string]: any })
	const day = if type(data.D) == "number" then math.clamp(math.floor(data.D), 1, MAX_DAY) else self.Day()
	-- Deferred: the other services restore after this one, and ShiftStarted listeners must see their state
	task.defer(function()
		if self.Started then
			self:StartShift(day, workspace:GetServerTimeNow(), false)
		else
			self.Day(day)
		end
	end)
end

-- Dev hooks (board TASK-012 v1.1, R1; commands live in TASK-042) -----------------------------------------------

function RoundService:DevSkipPhase()
	if not self.Dependencies.PlaceService:IsDev() then
		error("[RoundService] DevSkipPhase is dev mode only", 2)
	end
	if not self.Started then
		error("[RoundService] DevSkipPhase: run not started (no member yet)", 2)
	end
	self:EndPhase(workspace:GetServerTimeNow())
end

function RoundService:DevSetDay(day: number)
	if not self.Dependencies.PlaceService:IsDev() then
		error("[RoundService] DevSetDay is dev mode only", 2)
	end
	if type(day) ~= "number" or day ~= math.floor(day) or day < 1 or day > MAX_DAY then
		error(`[RoundService] DevSetDay: day must be an integer in 1..{MAX_DAY}`, 2)
	end
	if not self.Started then
		error("[RoundService] DevSetDay: run not started (no member yet)", 2)
	end
	-- Jumping past Day 1 skips its end: fix PriceParty as the natural path would have (DEC-121)
	if day > 1 then
		self.Dependencies.RunStateService:FixPriceParty()
	end
	self:StartShift(day, workspace:GetServerTimeNow(), true)
end

RoundService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	self.Dependencies.RunStateService:RegisterSnapshot("Sh", function()
		return self:CaptureShift()
	end, function(data, _mode)
		self:RestoreShift(data)
	end)
end)

RoundService:OnStart(function(self)
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	-- Registered here, not in OnInit: InteractionService (730) builds its handler table in its own OnInit, after ours.
	-- Its OnStart (scan of anchors) still runs after this one, so the default PromptEnabled sees the handler.
	const runState = self.Dependencies.RunStateService
	self.Dependencies.InteractionService:RegisterAction(OPEN_ACTION, {
		Validate = function(player: Player, _anchor: Instance, _id: number): boolean
			return self.Started and self.Phase() == "Prep" and runState:IsActive(player)
		end,
		Run = function(_player: Player, _anchor: Instance, _id: number)
			if self.Phase() == "Prep" then
				self:EndPhase(workspace:GetServerTimeNow())
			end
		end,
	})

	self:RefreshSigns()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(anchor)
		if self:IsSign(anchor) then
			self:RefreshSign(anchor)
		end
	end)

	runState.MemberJoined:Connect(function()
		self:StartRun()
	end)
	for _ in runState.Members() do
		self:StartRun()
		break
	end
end)

RoundService:OnTick(function(self)
	self:Step()
end, TICK_RATE)

return RoundService
