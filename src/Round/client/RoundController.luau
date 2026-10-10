--!strict
-- Shift view (network.md §3.1, FEAT-003, DEC-048). Reads the Shift set (record 1) and exposes Vide sources:
-- Day, Phase, IsNight, Vehicle and ClockText ("8:00 AM", floored to Content.Shift.ClockStepMinutes). Other
-- Controllers read these sources, never the set. The clock is interpolated locally from server time
-- (PhaseStartedAt) so a late joiner or reconnect gets the current phase and hour from onAdded without waiting for a
-- phase change.
-- The client never decides phase or time: it only presents what the server wrote.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const RECORD_ID = 1 -- single record (network.md §1, rule 5)
const STEP = Content.Shift.ClockStepMinutes
const MINUTES_PER_DAY = 1440
const TICK_RATE = 10 -- Hz; one clock step is 6 s real on day, so 0.1 s is far inside the "<= 1 step" budget

-- Fallback before the first record arrives (Ready = false): start of the day prep (7:00 AM)
const DEFAULT_PHASE = "Prep"
const DEFAULT_VEHICLE = "cart" -- wave 1 always starts on the cart
const NO_MINUTE = -1 -- forces the next Refresh to write ClockText

export type Clock = {
	PhaseStartedAt: number,
	PhaseDuration: number,
	ClockFrom: number,
	ClockTo: number,
}

-- Fields of the Shift record this controller reads (network.md §3.1)
export type Record = {
	Day: number,
	IsNight: boolean,
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

function RoundController:Setup()
	self.Day = Vide.source(1) :: Vide.Source<number>
	self.Phase = Vide.source(DEFAULT_PHASE) :: Vide.Source<string>
	self.IsNight = Vide.source(false) :: Vide.Source<boolean>
	-- Shift.Vehicle (key of Content.Vehicles); MarketController reads it for "Trailer only" (FEAT-015, DEC-184)
	self.Vehicle = Vide.source(DEFAULT_VEHICLE) :: Vide.Source<string>
	self.ClockText = Vide.source(self:Format(Content.Shift.ByKey[DEFAULT_PHASE].ClockFrom)) :: Vide.Source<string>
	-- true once the first Shift record arrived
	self.Ready = Vide.source(false) :: Vide.Source<boolean>
	self.Clock = nil :: Clock?
	-- last stepped minute written to ClockText (avoids rewriting the same text)
	self.Minutes = NO_MINUTE :: number
end

-- Rewrites ClockText only when the stepped minute changes, so dependents update once per 10 game minutes
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
end

function RoundController:Apply(record: Record)
	const clock: Clock = {
		PhaseStartedAt = record.PhaseStartedAt,
		PhaseDuration = record.PhaseDuration,
		ClockFrom = record.ClockFrom,
		ClockTo = record.ClockTo,
	}
	self.Clock = clock
	self.Minutes = NO_MINUTE

	Vide.batch(function()
		self.Day(record.Day)
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
			self.Ready(false)
		end
	end)
end)

RoundController:OnTick(function(self)
	self:Refresh()
end, TICK_RATE)

return RoundController
