--!strict
-- Full run cycle (architecture.md §19.4, T42, T56, T58, T59; network.md §3.1, §13.1; FEAT-002, 003, 017, 026, 027;
-- DEC-053, 084, 127; TASK-012, TASK-054). Run place only. Single writer of the Shift set (record 1).
-- Phases, durations and clock ranges come from Content.Shift (night override per row, Night length from
-- Content.Nights); the decisions that are pure (next phase, next shift, skip, window) live in Flow.luau.
-- The clock never pauses (DEC-085 a): a phase ends at PhaseStartedAt + Duration whoever is connected. Early ends:
-- the service window opened in Prep (OpenShop, VehicleService; TASK-284), a phase probe (Call, Closing, Finale, Resume), LoseNight, dev commands. Every end goes
-- through Advance, the same path as the timer.
-- Shift boundary (end of Summary), fixed order: BeforeShift(prev) -> Flow.Next -> RunStateService:SetEndless(false) ->
-- StartShift (atoms in one batch -> ShiftStarted -> PhaseChanged(first) -> Capture).
-- Run flow (user decision 2026-10-12): D1 (tutorial + the rest of a real day shift), then ONLY nights, forever:
-- N1 (Day 2), N2 (Day 3) ... N10 (Day 11), Finale. Day still counts one per shift. Every night is played in the vehicle
-- in use (the trailer, the only vehicle since 2026-10-12); endless days are gone (Flow.Next).
-- Lost night: NightLost (6 s) -> SpendChance -> Restore("RepeatNight") (Sh comes back with Attempt + 1 and a new
-- capture) or RunEnd + RunEnded("Failed"). Night 10 won: NightEnd -> Finale -> RunEnd + RunEnded("Success").
-- End of RunEnd: waves 2-3 go back to the first capture (RunStateService:ResetDev, T56) through the Resume phase;
-- wave 4 hands over to SessionService:EndRun instead.
-- Clock hold (user decision 2026-10-12, Provisional): while TutorialService's hook (SetClockHold) says so, Prep and Open
-- of Day 1 do not run out: HoldAt (server time the hold began) freezes the clock (Record publishes ClockFrom = ClockTo =
-- the clock at HoldAt), the deadline never comes and the tutorial customer is the only one around; on release
-- PhaseStartedAt moves forward by the time held, so the phase continues exactly where it stopped.
-- No Require on peripheral services (T42): they plug in with SetPhaseProbe, SetVehicleProbe, SetVerdict, SetWipe,
-- LoseNight and AddRunReportStep. The OPEN/CLOSED sign has no field: clients derive it from Phase + Paused.
-- TASK-284 (owner request 2026-10-14, Provisional): the red "Open Shop" switch (open_sign) is gone. The service window is
-- the shop: VehicleService calls OpenShop when it opens in Prep and SetPaused(closed) in the selling phases.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Flow = require(script.Flow)
local Modux = require(ServerScriptService.server.Modux)

export type Phase =
	"Resume"
	| "Prep"
	| "Open"
	| "Closing"
	| "Summary"
	| "Call"
	| "Night"
	| "NightEnd"
	| "NightLost"
	| "Finale"
	| "RunEnd"

-- Identifies a shift (data.md §3.3 "Sh"). Same shape as wave 1.
export type ShiftInfo = Flow.Info

export type NightWindow = Flow.Window
export type LoseReason = "wipe" | "critical"
export type NightResult = "Won" | "Lost"
export type RunResult = "Success" | "Failed"

-- RunReport packet (network.md §13.1), one per connected member on RunEnded
export type RunReport = { Result: RunResult, Day: number, Night: number, Gems: number }
export type RunReportStep = (player: Player, report: RunReport) -> ()
type Step = { Name: string, Run: RunReportStep }

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
	Paused: boolean,
}

-- EconomyService seen through a runtime lookup (no Require: Economy requires Round, T42)
type EconomyHook = {
	AddReportStep: (self: any, name: string, fn: (info: ShiftInfo, report: any) -> ()) -> (),
}

const RECORD = 1 -- single record (network.md §1, rule 5)
const MAX_DAY = 10000 -- Shift.Day wire range
const MAX_ATTEMPT = 9 -- Shift.Attempt wire range
const MAX_DURATION = 3600 -- Shift.PhaseDuration wire range
const MAX_CLOCK = 2880 -- Shift.ClockFrom/To wire range
const MAX_CHANCES = 9 -- Shift.Chances wire range
const MAX_GEMS = 100000 -- RunReport.Gems wire range
const LAST_NIGHT = math.min(Content.RunParams.Nights, #Content.Nights.List)
const TICK_RATE = 10 -- Hz; phase ends at most 0.1 s late, the next phase starts at the exact deadline
const LAST_CHANCE_STEP = "LastChanceUsed"

local function wireInt(value: number, low: number, high: number): number
	if value ~= value then
		return low
	end
	return math.clamp(math.floor(value), low, high)
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

const RoundService = Modux.Service("RoundService", {
	Require = { "PlaceService", "NetService", "RunStateService", "InteractionService" },
	Priority = 750,
})

function RoundService:Setup()
	self.Started = false :: boolean
	-- True between a snapshot restore and the deferred StartShift/Resume: no phase may end meanwhile
	self.Busy = false :: boolean
	self.Day = self.Libs.Charm.atom(1) :: Charm.Atom<number>
	self.Night = self.Libs.Charm.atom(0) :: Charm.Atom<number>
	self.NightShift = self.Libs.Charm.atom(false) :: Charm.Atom<boolean>
	self.Attempt = self.Libs.Charm.atom(0) :: Charm.Atom<number>
	self.Phase = self.Libs.Charm.atom("Prep" :: Phase) :: Charm.Atom<Phase>
	self.PhaseStartedAt = self.Libs.Charm.atom(0) :: Charm.Atom<number>
	-- Clock shown by phases that hold it (ClockFrom = ClockTo = 0: Resume, NightLost, RunEnd)
	self.Held = self.Libs.Charm.atom(0) :: Charm.Atom<number>
	self.WipeEndsAt = self.Libs.Charm.atom(0) :: Charm.Atom<number>
	self.WipeFrozen = self.Libs.Charm.atom(false) :: Charm.Atom<boolean>
	-- Shop closed during a selling phase (Open, Night): the service window is shut (VehicleService, TASK-284), no new
	-- customer arrives; any phase change reopens it (VehicleService then applies the window again)
	self.Paused = self.Libs.Charm.atom(false) :: Charm.Atom<boolean>
	-- Clock hold (SetClockHold): server time the current hold began, 0 = running. An atom: the Shift record reads it.
	self.HoldAt = self.Libs.Charm.atom(0) :: Charm.Atom<number>
	self.ClockHold = nil :: (() -> boolean)?
	-- Server time the Night phase of this shift ended (0 = not yet)
	self.NightEndedAt = 0 :: number
	self.LostReason = "wipe" :: LoseReason
	self.Result = "Failed" :: RunResult
	-- Hooks (T42): "can end now" per phase, current vehicle key, "someone is standing" at 6 AM
	self.Probes = {} :: { [string]: () -> boolean }
	self.VehicleProbe = nil :: (() -> string)?
	self.VerdictProbe = nil :: (() -> boolean)?
	self.RunSteps = {} :: { Step }
	-- Run start gate (architecture.md §20.3, TASK-156): nil = start on the first member (dev / solo); set by
	-- PartyRunService on a squad server so the run waits for the squad (or Content.RunParams.JoinWindow, DEC-098)
	self.StartGate = nil :: (() -> boolean)?
	-- Resume boot (SessionService, DEC-080): no run start while the session reads its Runs record
	self.ResumeHold = false :: boolean
	-- Signals are created here so lower-priority services connect in their OnInit (architecture.md §3.1)
	self.PhaseChanged = self.Libs.Signal.new() :: SignalLib.Signal<Phase, number, number>
	self.ShiftStarted = self.Libs.Signal.new() :: SignalLib.Signal<ShiftInfo>
	self.ShiftEnded = self.Libs.Signal.new() :: SignalLib.Signal<ShiftInfo>
	self.BeforeShift = self.Libs.Signal.new() :: SignalLib.Signal<ShiftInfo>
	self.NightResolved = self.Libs.Signal.new() :: SignalLib.Signal<ShiftInfo, NightResult, LoseReason?>
	self.RunEnded = self.Libs.Signal.new() :: SignalLib.Signal<RunResult>
end

-- Reads -----------------------------------------------------------------------------------------------------------

function RoundService:GetPhase(): Phase
	return self.Phase()
end

function RoundService:GetDay(): number
	return self.Day()
end

function RoundService:GetNight(): number
	return self.Night()
end

function RoundService:IsNight(): boolean
	return self.NightShift()
end

function RoundService:IsStarted(): boolean
	return self.Started
end

function RoundService:Info(): ShiftInfo
	return { Day = self.Day(), Night = self.Night(), IsNight = self.NightShift(), Attempt = self.Attempt() }
end

-- Customers spawn and the drawer counts (Content.Shift.Selling: Open, Night)
function RoundService:IsSelling(): boolean
	return Content.Shift.ByKey[self.Phase()].Selling
end

-- Last call (DEC-240): the DAY Closing (Content.Shift Closing.LastCall). Nobody new arrives but the trailer is still open:
-- the crew, the prep mode, the tables and the sign keep working until the line and the tables are empty.
function RoundService:IsLastCall(): boolean
	if not self.Started or self.NightShift() then
		return false
	end
	return Content.Shift.ByKey[self.Phase()].LastCall == true
end

-- The crew works the shop now: a selling phase or the day Last call (PrepService, SeatingService read this)
function RoundService:IsServing(): boolean
	return self.Started and (self:IsSelling() or self:IsLastCall())
end

-- The shop is closed (service window shut) in a selling phase: no new customer arrives while true
function RoundService:IsPaused(): boolean
	return self.Paused()
end

-- Shop Open <-> Closed during a selling phase (Open, Night): VehicleService mirrors the service window here (TASK-284).
-- false = not toggled (not a selling phase, not started).
function RoundService:SetPaused(paused: boolean): boolean
	if not self.Started or self.Busy or not self:IsSelling() then
		return false
	end
	if self.Paused() ~= paused then
		self.Paused(paused)
	end
	return true
end

-- The service window opened in Prep (VehicleService, TASK-284): the selling phase starts at once, like the old "Open
-- Shop" switch. false = not in Prep / not started (nothing changes).
function RoundService:OpenShop(): boolean
	if not self.Started or self.Busy then
		return false
	end
	const phase = self.Phase()
	if phase == "Call" and self.NightShift() then
		-- the night call no longer blocks (owner decision 2026-10-17, Provisional): Call -> Prep -> Night at once, the call
		-- keeps talking (BossService does not hang up on Prep / Night)
		const now = workspace:GetServerTimeNow()
		self:Advance(now)
		if self.Phase() == "Prep" and not self.Busy then
			self:Advance(now)
		end
		return true
	end
	if phase ~= "Prep" then
		return false
	end
	self:Advance(workspace:GetServerTimeNow())
	return true
end

-- Length of the Night phase of night k (DEC-127)
function RoundService:NightDuration(night: number): number
	const list = Content.Nights.List
	return list[math.clamp(night, 1, #list)].Duration
end

-- Duration and clock of a phase on the current shift (holding phases show Held)
function RoundService:Timing(phase: Phase): Flow.Timing
	const timing =
		Flow.Timing(phase, Content.Shift.ByKey[phase], self.NightShift(), self:NightDuration(self.Night()))
	if Flow.HoldsClock(timing) then
		const held = self.Held()
		return { Duration = timing.Duration, ClockFrom = held, ClockTo = held }
	end
	return timing
end

-- Server time at which the current phase reaches its cap (math.huge while the clock is held)
function RoundService:Deadline(): number
	if self.HoldAt() > 0 then
		return math.huge
	end
	return self.PhaseStartedAt() + self:Timing(self.Phase()).Duration
end

-- The clock is frozen by the tutorial (SetClockHold)
function RoundService:IsClockHeld(): boolean
	return self.HoldAt() > 0
end

-- Game minutes of the current phase at server time t (a held clock never reads past the moment it stopped)
function RoundService:ClockAt(t: number): number
	const holdAt = self.HoldAt()
	const at = if holdAt > 0 then math.min(t, holdAt) else t
	return Flow.Clock(self:Timing(self.Phase()), at - self.PhaseStartedAt())
end

-- Game minutes now, same formula as the client (network.md §3.1), without the 10 min floor
function RoundService:Minutes(): number
	return self:ClockAt(workspace:GetServerTimeNow())
end

-- Calm / Shift / Last from the clock, only during the Night phase (FEAT-003; not phases)
function RoundService:NightWindow(): NightWindow?
	if self.Phase() ~= "Night" then
		return nil
	end
	return Flow.Window(self:Minutes(), Content.Nights.Windows)
end

-- Server time of 6:00 AM of this night (deadline of Down, DEC-115). Before the Night phase it is an estimate from
-- the caps (Call/Prep may end early); after it, the moment the Night phase ended. 0 on a day shift.
function RoundService:NightEndsAt(): number
	if not self.NightShift() then
		return 0
	end
	const phase = self.Phase()
	if phase == "Night" then
		return self:Deadline()
	end
	const night = self:NightDuration(self.Night())
	if phase == "Prep" then
		return self:Deadline() + night
	elseif phase == "Call" then
		const prep = Flow.Timing("Prep", Content.Shift.ByKey.Prep, true, night)
		return self:Deadline() + prep.Duration + night
	end
	return self.NightEndedAt
end

-- Vehicle key from the VehicleService probe (RunParams.StartVehicle without one, A6)
function RoundService:CurrentVehicle(): string
	const probe = self.VehicleProbe
	if probe then
		const ok, result = pcall(probe)
		if ok and type(result) == "string" and Content.Vehicles.ByKey[result] ~= nil then
			return result
		end
		warn(`[RoundService] vehicle probe gave {if ok then tostring(result) else "an error: " .. tostring(result)}`)
	end
	return Content.RunParams.StartVehicle
end

-- Kept for the type surface: every vehicle works nights now (the flow no longer reads it)
function RoundService:VehicleHasNight(): boolean
	return Content.Vehicles.ByKey[self:CurrentVehicle()].HasNight
end

function RoundService:Record(): Record
	const phase = self.Phase()
	const timing = self:Timing(phase)
	const holdAt = self.HoldAt()
	-- held: from = to = the minutes at the moment it stopped (the client interpolates nothing)
	const clockFrom = if holdAt > 0 then self:ClockAt(holdAt) else timing.ClockFrom
	const clockTo = if holdAt > 0 then clockFrom else timing.ClockTo
	return {
		Day = wireInt(self.Day(), 1, MAX_DAY),
		Night = wireInt(self.Night(), 0, LAST_NIGHT),
		IsNight = self.NightShift(),
		Attempt = wireInt(self.Attempt(), 0, MAX_ATTEMPT),
		Phase = phase,
		PhaseStartedAt = self.PhaseStartedAt(),
		PhaseDuration = wireInt(timing.Duration, 0, MAX_DURATION),
		ClockFrom = wireInt(clockFrom, 0, MAX_CLOCK),
		ClockTo = wireInt(clockTo, 0, MAX_CLOCK),
		Vehicle = self:CurrentVehicle(),
		Chances = wireInt(self.Dependencies.RunStateService.Chances(), 0, MAX_CHANCES),
		WipeEndsAt = self.WipeEndsAt(),
		WipeFrozen = self.WipeFrozen(),
		Paused = self.Paused(),
	}
end

-- Hooks (T42; registered in the owner's OnInit/OnStart) -------------------------------------------------------

-- "Can end now" for Call, Closing, Finale or Resume. Last registration wins.
function RoundService:SetPhaseProbe(phase: Phase, probe: () -> boolean)
	if not Flow.CanProbe(phase) or type(probe) ~= "function" then
		error(`[RoundService] SetPhaseProbe: {phase} cannot end by probe (or probe is not a function)`, 2)
	end
	self.Probes[phase] = probe
end

-- TutorialService: "the clock stands still now". Asked every tick; the service only honours it on the day shift in Prep,
-- Open (the first-hot-dog tutorial) and Closing (the Day 1 upgrade lesson, 2026-10-14). Last registration wins.
function RoundService:SetClockHold(hold: () -> boolean)
	if type(hold) ~= "function" then
		error("[RoundService] SetClockHold needs a function", 2)
	end
	self.ClockHold = hold
end

-- Wave 1 name (CustomerService, TASK-032): the counter is empty
function RoundService:SetCounterProbe(probe: () -> boolean)
	self:SetPhaseProbe("Closing", probe)
end

-- VehicleService: key of the current vehicle (Shift.Vehicle, night or not at the boundary)
function RoundService:SetVehicleProbe(probe: () -> string)
	if type(probe) ~= "function" then
		error("[RoundService] SetVehicleProbe needs a function", 2)
	end
	self.VehicleProbe = probe
end

-- VitalService: someone present is Active/Reviving (FEAT-026: the night is won with at least one standing)
function RoundService:SetVerdict(probe: () -> boolean)
	if type(probe) ~= "function" then
		error("[RoundService] SetVerdict needs a function", 2)
	end
	self.VerdictProbe = probe
end

-- VitalService: 10 s wipe window (DEC-094, DEC-118). endsAt = 0 closes it.
function RoundService:SetWipe(endsAt: number, frozen: boolean)
	if not finite(endsAt) or endsAt < 0 or type(frozen) ~= "boolean" then
		error("[RoundService] SetWipe: endsAt must be a finite number >= 0 and frozen a boolean", 2)
	end
	self.Libs.Charm.batch(function()
		self.WipeEndsAt(endsAt)
		self.WipeFrozen(frozen)
	end)
end

-- RewardService (T59): fills RunReport fields per player. Runs in registration order, in pcall, no yield.
-- Run start gate (TASK-156): StartRun waits until gate() is true; Step polls it while a member is in.
function RoundService:SetStartGate(gate: () -> boolean)
	self.StartGate = gate
end

-- SessionService (DEC-080; architecture.md §5.5): true holds the run start while a fresh server reached by a rejoin
-- teleport finds out whether it resumes a run; false lets the run start as usual (now, when a member is in).
function RoundService:SetResumeHold(on: boolean)
	self.ResumeHold = on == true
	if not self.ResumeHold and next(self.Dependencies.RunStateService.Members()) ~= nil then
		self:StartRun()
	end
end

function RoundService:AddRunReportStep(name: string, step: RunReportStep)
	if type(name) ~= "string" or name == "" or type(step) ~= "function" then
		error("[RoundService] AddRunReportStep needs a name and a function", 2)
	end
	for _, entry in self.RunSteps do
		if entry.Name == name then
			error(`[RoundService] AddRunReportStep: duplicate step {name}`, 2)
		end
	end
	table.insert(self.RunSteps, { Name = name, Run = step })
end

-- Probes in pcall: an error is a warn and the default value
local function ask(probe: () -> boolean, label: string, default: boolean): boolean
	const ok, result = pcall(probe)
	if not ok then
		warn(`[RoundService] {label} probe errored: {result}`)
		return default
	end
	return result == true
end

function RoundService:HasProbe(phase: string): boolean
	return self.Probes[phase] ~= nil
end

-- Closing without a probe = no customer system = counter always empty (wave 1 behavior)
function RoundService:ProbeSaysEnd(phase: Phase): boolean
	const probe = self.Probes[phase]
	if probe == nil then
		return phase == "Closing"
	end
	return ask(probe, phase, phase == "Closing")
end

-- No VitalService = everyone counts as standing
function RoundService:Verdict(): boolean
	const probe = self.VerdictProbe
	if probe == nil then
		return true
	end
	return ask(probe, "verdict", true)
end

-- Skips SkipWithoutProbe phases nobody owns (§19.0 rule 4)
function RoundService:Resolve(phase: string, info: ShiftInfo): Phase
	return Flow.Resolve(phase, info, LAST_NIGHT, function(key: string): Flow.Row?
		return Content.Shift.ByKey[key]
	end, function(key: string): boolean
		return self:HasProbe(key)
	end) :: Phase
end

-- Phases ----------------------------------------------------------------------------------------------------------

-- The clock should stand still now: Prep, Open or Closing of a day, or Prep / Night of a night (owner 2026-10-19: the tutorial is
-- Night 1's, the clock does not run under it), and the hook says yes (errors are a warn and "no")
function RoundService:HoldWanted(): boolean
	const hold = self.ClockHold
	if hold == nil then
		return false
	end
	const phase = self.Phase()
	if self.NightShift() then
		-- Summary: the upgrade lesson at the end of Night 1 (owner bug 2026-10-20: the break waits for the first purchase)
		if phase ~= "Prep" and phase ~= "Night" and phase ~= "Summary" then
			return false
		end
	-- Closing (day = Last call, 6 PM): the Day 1 upgrade lesson (owner request 2026-10-14, Provisional)
	elseif phase ~= "Prep" and phase ~= "Open" and phase ~= "Closing" then
		return false
	end
	return ask(hold, "clock hold", false)
end

-- Starts or ends the hold at server time `now`. Release moves the phase start forward by the time held.
function RoundService:UpdateHold(now: number)
	const holdAt = self.HoldAt()
	const wanted = self.Started and not self.Busy and self:HoldWanted()
	if wanted and holdAt <= 0 then
		self.HoldAt(math.max(now, self.PhaseStartedAt()))
	elseif not wanted and holdAt > 0 then
		self.Libs.Charm.batch(function()
			self.PhaseStartedAt(self.PhaseStartedAt() + math.max(0, now - holdAt))
			self.HoldAt(0)
		end)
	end
end

-- One batch: the Shift effect sends a single update per phase change. info = new shift; held = clock to hold
-- (default: the clock of the phase being left, at startedAt).
function RoundService:Enter(phase: Phase, startedAt: number, info: ShiftInfo?, held: number?)
	const clock = if held ~= nil then held else self:ClockAt(startedAt)
	self.Libs.Charm.batch(function()
		if info then
			self.Day(info.Day)
			self.Night(info.Night)
			self.NightShift(info.IsNight)
			self.Attempt(info.Attempt)
			self.WipeEndsAt(0)
			self.WipeFrozen(false)
		end
		self.Paused(false)
		self.Held(clock)
		self.HoldAt(0)
		self.Phase(phase)
		self.PhaseStartedAt(startedAt)
	end)
end

-- Enters a phase of the current shift and fires what that phase means
function RoundService:Go(phase: Phase, startedAt: number)
	self:Enter(phase, startedAt, nil, nil)
	const info = self:Info()
	if phase == "Summary" then
		-- Shift is over: Economy deposits and sends ShiftReport, then PriceParty is fixed on Day 1 (DEC-121)
		self.ShiftEnded:Fire(info)
		if Flow.IsFirst(info, Content.Shift.RunStartsAtNight) then
			self.Dependencies.RunStateService:FixPriceParty()
		end
	elseif phase == "NightEnd" then
		self.NightResolved:Fire(info, "Won", nil)
	elseif phase == "NightLost" then
		self.NightResolved:Fire(info, "Lost", self.LostReason)
	elseif phase == "RunEnd" then
		self.RunEnded:Fire(self.Result)
		self:SendRunReports(self.Result)
	end
	self.PhaseChanged:Fire(phase, info.Day, info.Night)
end

-- New shift from startedAt. capture = false never happens on the natural path (kept for symmetry with wave 1).
-- newRun is no longer read (the intro phase is gone, DEC-309); the parameter stays until ModuxTypes is regenerated.
function RoundService:StartShift(info: ShiftInfo, startedAt: number, capture: boolean, newRun: boolean)
	const first = self:Resolve(Flow.First(info), info)
	self.NightEndedAt = 0
	self:Enter(first, startedAt, info, nil)
	const current = self:Info()
	self.ShiftStarted:Fire(current)
	self.PhaseChanged:Fire(first, current.Day, current.Night)
	if capture then
		self.Dependencies.RunStateService:Capture()
	end
end

-- Resume restore: wait phase on the restored shift; the shift (ShiftStarted + capture) starts when it ends.
-- The clock shows the start of the shift's first phase.
function RoundService:EnterResume(info: ShiftInfo, startedAt: number)
	const first = self:Resolve(Flow.First(info), info)
	const timing =
		Flow.Timing(first, Content.Shift.ByKey[first], info.IsNight, self:NightDuration(info.Night))
	self.NightEndedAt = 0
	self:Enter("Resume", startedAt, info, timing.ClockFrom)
	self.PhaseChanged:Fire("Resume", info.Day, info.Night)
end

function RoundService:Lose(reason: LoseReason, startedAt: number)
	self.LostReason = reason
	self:Go("NightLost", startedAt)
end

function RoundService:WinNight(startedAt: number)
	self.NightEndedAt = startedAt
	self:Go(self:Resolve("NightEnd", self:Info()), startedAt)
end

-- End of Summary (architecture.md §19.4, fixed order)
function RoundService:Boundary(startedAt: number)
	const prev = self:Info()
	self.BeforeShift:Fire(prev)
	const nextShift = Flow.Next(prev, LAST_NIGHT, MAX_DAY)
	self.Dependencies.RunStateService:SetEndless(false)
	self:StartShift(nextShift, startedAt, true, false)
end

-- End of NightLost: a chance repeats the night from its capture, none left ends the run
function RoundService:EndLost(startedAt: number)
	const runState = self.Dependencies.RunStateService
	if runState:SpendChance() then
		self.Busy = true
		if not runState:Restore("RepeatNight") then
			-- Nothing captured (should not happen: every shift start captures): repeat from the current shift
			self.Busy = false
			const info = self:Info()
			info.Attempt = math.min(info.Attempt + 1, MAX_ATTEMPT)
			self:StartShift(info, startedAt, true, false)
		end
		return
	end
	self.Result = "Failed"
	self:Go("RunEnd", startedAt)
end

-- End of RunEnd. Waves 2-3: back to the first capture of the run (T56); wave 4: SessionService:EndRun.
function RoundService:EndRun(startedAt: number)
	self.Busy = true
	if not self.Dependencies.RunStateService:ResetDev() then
		self.Busy = false
		warn("[RoundService] RunEnd: no first capture to go back to; starting a new run again")
		self:StartShift(Flow.Start(Content.Shift.RunStartsAtNight), startedAt, true, true)
	end
end

-- Ends the current phase. startedAt = when the next one starts (deadline on timeout, now on an early end).
-- Single path for timer, sign, probes and dev skip.
function RoundService:Advance(startedAt: number)
	if not self.Started or self.Busy then
		return
	end
	const current = self.Phase()
	const info = self:Info()
	if current == "Night" then
		if self:Verdict() then
			self:WinNight(startedAt)
		else
			self.NightEndedAt = startedAt
			self:Lose("wipe", startedAt)
		end
	elseif current == "Summary" then
		self:Boundary(startedAt)
	elseif current == "NightLost" then
		self:EndLost(startedAt)
	elseif current == "RunEnd" then
		self:EndRun(startedAt)
	elseif current == "Resume" then
		self:StartShift(info, startedAt, true, false)
	else
		const nextPhase = Flow.After(current, info, LAST_NIGHT)
		if nextPhase == nil then
			warn(`[RoundService] no phase after {current}`)
			return
		end
		const resolved = self:Resolve(nextPhase, info)
		if resolved == "RunEnd" then
			self.Result = "Success"
		end
		self:Go(resolved, startedAt)
	end
end

function RoundService:Step()
	if not self.Started then
		-- squad server: the gate opens when the squad is in or the join window ran out (TASK-156)
		if self.StartGate ~= nil and next(self.Dependencies.RunStateService.Members()) ~= nil then
			self:StartRun()
		end
		return
	end
	if self.Busy then
		return
	end
	const now = workspace:GetServerTimeNow()
	self:UpdateHold(now)
	const deadline = self:Deadline()
	if now >= deadline then
		self:Advance(deadline)
		return
	end
	const phase = self.Phase()
	-- a night override's Min: the probe cannot end it before (owner 2026-10-21: upgrade time after the night)
	const override = if self.NightShift() then Content.Shift.ByKey[phase].Night else nil
	const minimum = if override ~= nil and override.Min ~= nil then override.Min else 0
	-- a held phase never ends by its probe either (the day Closing of the Day 1 upgrade lesson)
	if
		Flow.CanProbe(phase)
		and self.HoldAt() <= 0
		and now > self.PhaseStartedAt() + minimum
		and self:ProbeSaysEnd(phase)
	then
		self:Advance(now)
	end
end

-- VitalService (wipe), AnomalyService (critical). Accepted in Call, Prep and Night of a night shift; false
-- otherwise (also when the night is already lost: idempotent).
function RoundService:LoseNight(reason: LoseReason): boolean
	if reason ~= "wipe" and reason ~= "critical" then
		error(`[RoundService] LoseNight: reason must be "wipe" or "critical", got {tostring(reason)}`, 2)
	end
	if not self.Started or self.Busy or not Flow.CanLose(self.Phase(), self:Info()) then
		return false
	end
	const now = workspace:GetServerTimeNow()
	if self.Phase() == "Night" then
		self.NightEndedAt = now
	end
	self:Lose(reason, now)
	return true
end

-- Run start: first shift of a new run when the first member is in (Provisional, TASK-012: the clock does not run on
-- an empty dev server). Network writes start here; Lync.start already ran (NetService OnStart, priority 1000).
function RoundService:StartRun()
	if self.Started or self.ResumeHold then
		return
	end
	const gate = self.StartGate
	if gate ~= nil and not gate() then
		return
	end
	self:Publish()
	self:StartShift(Flow.Start(Content.Shift.RunStartsAtNight), workspace:GetServerTimeNow(), true, true)
end

-- Started + the Shift set (network writes start here; Lync.start already ran: NetService OnStart, priority 1000)
function RoundService:Publish()
	self.Started = true
	self.Libs.Net.Shift:add(RECORD, self:Record())
	self.Libs.Charm.effect(function()
		const record = self:Record()
		if self.Dependencies.NetService:IsRunning() then
			self.Libs.Net.Shift:update(RECORD, record)
		end
	end)
end

-- Resume boot (SessionService, DEC-080; architecture.md §5.5 steps 4-5): the run starts from the snapshot the session
-- loaded (RunStateService:Load) in the Resume phase of its shift, instead of a new Day 1; the shift starts again (and
-- captures) when Resume ends. False when the run already started or nothing could be restored (then Day 1 starts).
function RoundService:ResumeRun(): boolean
	if self.Started then
		return false
	end
	self.ResumeHold = false
	self:Publish()
	-- RestoreShift sees Started: it holds the phases (Busy) and enters Resume once every service restored
	if self.Dependencies.RunStateService:Restore("Resume") then
		return true
	end
	warn("[RoundService] ResumeRun: no snapshot to restore; starting a new run")
	self:StartShift(Flow.Start(Content.Shift.RunStartsAtNight), workspace:GetServerTimeNow(), true, true)
	return false
end

-- Run report (T59) -------------------------------------------------------------------------------------------------

-- One packet per connected member with Ready; steps fill the per-player fields (Gems)
function RoundService:SendRunReports(result: RunResult)
	const net = self.Dependencies.NetService
	if not net:IsRunning() then
		return
	end
	const info = self:Info()
	for userId, member in self.Dependencies.RunStateService.Members() do
		if member.State == "Away" then
			continue
		end
		const player = Players:GetPlayerByUserId(userId)
		if player == nil or not net:IsReady(player) then
			continue
		end
		const report: RunReport = {
			Result = result,
			Day = wireInt(info.Day, 1, MAX_DAY),
			Night = wireInt(info.Night, 0, LAST_NIGHT),
			Gems = 0,
		}
		for _, step in self.RunSteps do
			const ok, err = pcall(step.Run, player, report)
			if not ok then
				warn(`[RoundService] run report step {step.Name} failed: {err}`)
			end
		end
		const gems = report.Gems
		self.Libs.Net.RunReport:fireClient(player, {
			Result = result,
			Day = wireInt(info.Day, 1, MAX_DAY),
			Night = wireInt(info.Night, 0, LAST_NIGHT),
			Gems = if finite(gems) then wireInt(gems, 0, MAX_GEMS) else 0,
		})
	end
end

-- ShiftReport.LastChanceUsed (DEC-053, DEC-110): night summary after the chance was spent. EconomyService requires
-- this service, so the step is registered through a runtime lookup instead of a Require (Provisional, TASK-054).
function RoundService:HookEconomy()
	const feature = ServerScriptService.server:FindFirstChild("Economy")
	const module = if feature then feature:FindFirstChild("EconomyService") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return
	end
	const economy = (require :: any)(module) :: EconomyHook
	const runState = self.Dependencies.RunStateService
	economy:AddReportStep(LAST_CHANCE_STEP, function(info: ShiftInfo, report: any)
		report.LastChanceUsed = info.IsNight and runState.Chances() <= 0
	end)
end

-- Snapshot "Sh" (data.md §3.3) -------------------------------------------------------------------------------------

function RoundService:CaptureShift(): { [string]: any }
	const info = self:Info()
	return { D = info.Day, N = info.Night, Ni = info.IsNight, A = info.Attempt }
end

local function intOr(value: any, low: number, high: number, default: number): number
	if finite(value) then
		return math.clamp(math.floor(value), low, high)
	end
	return default
end

-- RepeatNight: Attempt + 1 and a new capture; Resume: Resume phase, the shift starts (and captures) at its end.
-- Deferred: the other services restore after this one, and ShiftStarted listeners must see their state.
function RoundService:RestoreShift(data: { [string]: any }, mode: string)
	const info: ShiftInfo = {
		Day = intOr(data.D, 1, MAX_DAY, self.Day()),
		Night = intOr(data.N, 0, LAST_NIGHT, self.Night()),
		IsNight = data.Ni == true,
		Attempt = intOr(data.A, 0, MAX_ATTEMPT, 0),
	}
	if mode == "RepeatNight" then
		info.Attempt = math.min(info.Attempt + 1, MAX_ATTEMPT)
	end
	self.Busy = true
	task.defer(function()
		self.Busy = false
		if not self.Started then
			self.Libs.Charm.batch(function()
				self.Day(info.Day)
				self.Night(info.Night)
				self.NightShift(info.IsNight)
				self.Attempt(info.Attempt)
			end)
			return
		end
		const now = workspace:GetServerTimeNow()
		if mode == "Resume" then
			self:EnterResume(info, now)
		else
			self:StartShift(info, now, true, false)
		end
	end)
end

-- Dev hooks (TASK-012 v1.1, TASK-054; commands in DevService/Commands/Round.luau) --------------------------------

function RoundService:DevCheck(name: string)
	if not self.Dependencies.PlaceService:IsDev() then
		error(`[RoundService] {name} is dev mode only`, 3)
	end
	if not self.Started then
		error(`[RoundService] {name}: run not started (no member yet)`, 3)
	end
	if self.Busy then
		error(`[RoundService] {name}: a restore is in progress, try again`, 3)
	end
end

function RoundService:DevSkipPhase()
	self:DevCheck("DevSkipPhase")
	self:Advance(workspace:GetServerTimeNow())
end

-- Shift of Day n in the natural sequence (Flow.OfDay): Day 1 is the day shift, Day n >= 2 is Night n - 1 (/dev day 4 is
-- Night 3, from its first phase).
function RoundService:DevSetDay(day: number)
	self:DevCheck("DevSetDay")
	if type(day) ~= "number" or day ~= math.floor(day) or day < 1 or day > MAX_DAY then
		error(`[RoundService] DevSetDay: day must be an integer in 1..{MAX_DAY}`, 2)
	end
	const runState = self.Dependencies.RunStateService
	-- Jumping past Day 1 skips its end: fix PriceParty as the natural path would have (DEC-121)
	if day > 1 then
		runState:FixPriceParty()
	end
	const info = Flow.OfDay(day, LAST_NIGHT)
	runState:SetEndless(false)
	self:StartShift(info, workspace:GetServerTimeNow(), true, false)
end

-- Night k on its own day (Day = k + 1: the evening of the day shift before it), from its first phase (Call, skipped
-- without BossService)
function RoundService:DevSetNight(night: number)
	self:DevCheck("DevSetNight")
	if type(night) ~= "number" or night ~= math.floor(night) or night < 1 or night > LAST_NIGHT then
		error(`[RoundService] DevSetNight: night must be an integer in 1..{LAST_NIGHT}`, 2)
	end
	const runState = self.Dependencies.RunStateService
	runState:FixPriceParty()
	runState:SetEndless(false)
	const info: ShiftInfo =
		{ Day = Flow.DayOfNight(night), Night = night, IsNight = true, Attempt = 0 }
	self:StartShift(info, workspace:GetServerTimeNow(), true, false)
end

-- Wins the current night now (NightEnd + NightResolved "Won"), from Call, Prep or Night
function RoundService:DevWinNight()
	self:DevCheck("DevWinNight")
	if not Flow.CanLose(self.Phase(), self:Info()) then
		error("[RoundService] DevWinNight: only in Call, Prep or Night of a night shift", 2)
	end
	self:WinNight(workspace:GetServerTimeNow())
end

-- Showcase clock (ShowcaseService; docs/tech/showcase.md): seconds the current phase has run, and a rewrite of its start
-- so the clock reads another time (or stays frozen when called every tick). Moves only PhaseStartedAt: the deadline
-- follows it, nothing else is touched.
function RoundService:DevPhaseElapsed(): number
	return workspace:GetServerTimeNow() - self.PhaseStartedAt()
end

function RoundService:DevSetPhaseElapsed(seconds: number)
	self:DevCheck("DevSetPhaseElapsed")
	if not finite(seconds) then
		error("[RoundService] DevSetPhaseElapsed: seconds must be a finite number", 2)
	end
	self.PhaseStartedAt(workspace:GetServerTimeNow() - math.max(0, seconds))
end

RoundService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	self.Dependencies.RunStateService:RegisterSnapshot("Sh", function()
		return self:CaptureShift()
	end, function(data, mode)
		self:RestoreShift(data, mode)
	end)
end)

RoundService:OnStart(function(self)
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	-- EconomyService (740) built its step list in its OnInit, before every OnStart
	self:HookEconomy()

	const runState = self.Dependencies.RunStateService
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
