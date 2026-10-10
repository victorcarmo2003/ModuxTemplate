--!strict
-- Shift view (network.md §3.1, architecture.md §19.3/§19.4, FEAT-003, FEAT-018, DEC-048, DEC-127). Reads the Shift
-- set (record 1) and exposes Vide sources: Day, Night, Attempt, Phase, IsNight, Vehicle, ClockText ("8:00 AM",
-- floored to Content.Shift.ClockStepMinutes) and NightWindow ("Calm" | "Shift" | "Last" from Content.Nights.Windows,
-- nil outside the Night phase). Other Controllers read these sources, never the set.
-- The clock is interpolated locally from server time (PhaseStartedAt), so a late joiner or reconnect gets the current
-- phase and hour from onAdded without waiting for a phase change. Call has ClockFrom = ClockTo (7:00 PM stopped);
-- Night runs 8 PM -> 6 AM over the night's Duration (Nights[k].Duration when the record has no PhaseDuration).
-- ClockFrom = ClockTo = 0 (Resume, NightLost, RunEnd) holds the previous text.
-- The client never decides phase or time: it only presents what the server wrote.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const RECORD_ID = 1 -- single record (network.md §1, rule 5)
const STEP = Content.Shift.ClockStepMinutes
const MINUTES_PER_DAY = 1440
const TICK_RATE = 10 -- Hz; one clock step is >= 2 s real (night 10: 1800 s / 60 steps), 0.1 s is inside "<= 1 step"
const NIGHT_PHASE = "Night"
const WINDOW_ORDER = { "Calm", "Shift", "Last" }

-- Fallback before the first record arrives (Ready = false): start of the day prep (7:00 AM)
const DEFAULT_PHASE = "Prep"
const DEFAULT_VEHICLE = "cart" -- wave 1 always starts on the cart
const NO_MINUTE = -1 -- forces the next Refresh to write ClockText

export type Window = "Calm" | "Shift" | "Last"

export type Clock = {
	PhaseStartedAt: number,
	PhaseDuration: number,
	ClockFrom: number,
	ClockTo: number,
}

-- Fields of the Shift record this controller reads (network.md §3.1)
export type Record = {
	Day: number,
	Night: number,
	IsNight: boolean,
	Attempt: number,
	Phase: string,
	Vehicle: string,
	PhaseStartedAt: number,
	PhaseDuration: number,
	ClockFrom: number,
	ClockTo: number,
}

const RoundController = Modux.Controller("RoundController", { Priority = 800 })

-- "8:00 AM" from game minutes since 0:00 of the shift day (night runs past 24:00, e.g. 30h = 6:00 AM)
function RoundController:Format(minutes: number): string
	const total = math.floor(minutes) % MINUTES_PER_DAY
	const hour24 = total // 60
	const minute = total % 60
	local hour12 = hour24 % 12
	if hour12 == 0 then
		hour12 = 12
	end
	return string.format("%d:%02d %s", hour12, minute, if hour24 < 12 then "AM" else "PM")
end

-- network.md §3.1: ClockFrom + (ClockTo - ClockFrom) * (now - PhaseStartedAt) / PhaseDuration, floored to the step
function RoundController:MinutesAt(clock: Clock, now: number): number
	local minutes = clock.ClockFrom
	if clock.PhaseDuration > 0 then
		const alpha = math.clamp((now - clock.PhaseStartedAt) / clock.PhaseDuration, 0, 1)
		minutes = clock.ClockFrom + (clock.ClockTo - clock.ClockFrom) * alpha
	end
	return math.floor(minutes / STEP) * STEP
end

-- Content.Nights.Windows: [from, to) per window; the last one includes 6:00 AM itself
function RoundController:WindowAt(minutes: number): Window?
	const windows = Content.Nights.Windows :: any
	for index, name in WINDOW_ORDER do
		const range = windows[name] :: { number }
		if minutes >= range[1] and (minutes < range[2] or (index == #WINDOW_ORDER and minutes <= range[2])) then
			return name :: Window
		end
	end
	return nil
end

-- Real seconds of the phase: the record's cap; the Night phase falls back to Nights[k].Duration (DEC-127)
function RoundController:DurationOf(record: Record): number
	if record.PhaseDuration > 0 or record.Phase ~= NIGHT_PHASE then
		return record.PhaseDuration
	end
	const row = Content.Nights.List[record.Night]
	return if row then row.Duration else 0
end

-- Held phases (ClockFrom = ClockTo = 0) with nothing shown yet (late joiner): dawn on a night shift, 6 PM on a day
-- shift (end of the turn, Summary row). Provisional (TASK-055).
function RoundController:HeldMinutes(isNight: boolean): number
	const summary = Content.Shift.ByKey.Summary
	const night = summary.Night
	return if isNight and night then night.ClockTo else summary.ClockTo
end

function RoundController:Setup()
	self.Day = Vide.source(1) :: Vide.Source<number>
	-- Shift.Night (0 on day shifts) and Shift.Attempt (0 = first try of this night)
	self.Night = Vide.source(0) :: Vide.Source<number>
	self.Attempt = Vide.source(0) :: Vide.Source<number>
	self.Phase = Vide.source(DEFAULT_PHASE) :: Vide.Source<string>
	self.IsNight = Vide.source(false) :: Vide.Source<boolean>
	-- Shift.Vehicle (key of Content.Vehicles); MarketController reads it for "Trailer only" (FEAT-015, DEC-184)
	self.Vehicle = Vide.source(DEFAULT_VEHICLE) :: Vide.Source<string>
	self.ClockText = Vide.source(self:Format(Content.Shift.ByKey[DEFAULT_PHASE].ClockFrom)) :: Vide.Source<string>
	-- Calm / Shift / Last during the Night phase, nil otherwise (FEAT-003; not phases)
	self.NightWindow = Vide.source(nil :: Window?) :: Vide.Source<Window?>
	-- true once the first Shift record arrived
	self.Ready = Vide.source(false) :: Vide.Source<boolean>
	self.Clock = nil :: Clock?
	self.InNight = false
	-- last stepped minute written to ClockText (avoids rewriting the same text)
	self.Minutes = NO_MINUTE :: number
end

-- Rewrites ClockText / NightWindow only when the stepped minute changes (once per 10 game minutes)
function RoundController:Refresh()
	const clock = self.Clock
	if not clock then
		return
	end
	const minutes = self:MinutesAt(clock, workspace:GetServerTimeNow())
	if minutes == self.Minutes then
		return
	end
	self.Minutes = minutes
	self.ClockText(self:Format(minutes))
	self.NightWindow(if self.InNight then self:WindowAt(minutes) else nil)
end

function RoundController:Apply(record: Record)
	const held = record.ClockFrom == 0 and record.ClockTo == 0
	if held then
		-- keep the text already shown; a late joiner gets a fixed fallback
		const shown = if self.Minutes ~= NO_MINUTE then self.Minutes else self:HeldMinutes(record.IsNight)
		self.Clock = { PhaseStartedAt = record.PhaseStartedAt, PhaseDuration = 0, ClockFrom = shown, ClockTo = shown }
	else
		self.Clock = {
			PhaseStartedAt = record.PhaseStartedAt,
			PhaseDuration = self:DurationOf(record),
			ClockFrom = record.ClockFrom,
			ClockTo = record.ClockTo,
		}
	end
	self.InNight = record.Phase == NIGHT_PHASE
	self.Minutes = NO_MINUTE

	Vide.batch(function()
		self.Day(record.Day)
		self.Night(record.Night)
		self.Attempt(record.Attempt)
		self.Phase(record.Phase)
		self.IsNight(record.IsNight)
		self.Vehicle(record.Vehicle)
		self:Refresh()
		self.Ready(true)
	end)
end

RoundController:OnInit(function(self)
	self:Setup()

	const shift = self.Libs.Net.Shift

	shift:onAdded(function(id, record)
		if id == RECORD_ID then
			self:Apply(record)
		end
	end)

	shift:onChanged(function(id, record)
		if id == RECORD_ID then
			self:Apply(record)
		end
	end)

	shift:onRemoved(function(id)
		if id == RECORD_ID then
			self.Clock = nil
			self.NightWindow(nil)
			self.Ready(false)
		end
	end)
end)

RoundController:OnTick(function(self)
	self:Refresh()
end, TICK_RATE)

return RoundController
