--!strict
-- Gear Stand business hours (owner request 2026-10-17, Provisional; FEAT-015 v2; Content.Mart.Hours). Run place only.
-- Single owner of "is the Gear Stand open": MarketService asks IsOpen() for the bench prompts and every bench purchase.
-- Rule (Content.Mart.Hours, numbers PROVISIONAL):
--   * OPENS on RoundService.ShiftEnded (the start of Summary, the end of every shift) and stays open through the break
--     (Summary, boss Call, Prep);
--   * the next shift's first selling phase (Content.Shift Selling: Open on a day, Night on a night) schedules the close
--     at now + StayOpenIntoShift (45 s) so the crew can finish shopping; CloseWarning (20 s) before it a toast
--     "Gear Stand closing in 20s" goes out; then it CLOSES;
--   * always CLOSED in Content.Mart.KioskClosedPhases (NightLost, Resume, Intro, Finale, RunEnd): a lost night, a
--     resume and a repeated night start with the stand down until the next shift end;
--   * a new run starts closed (the Intro is a closed phase): Day 1 opens at the end of the first shift;
--   * OpenAtShiftEnd = false = no hours, the old rule (open in every phase outside KioskClosedPhases).
-- Toasts (Content.Notices, party): gear_open, gear_closing {value}, gear_shut. The refusal gear_closed is MarketService's.
-- Replication: two Workspace attributes (Hours.Attributes: GearStandOpen boolean, GearStandClosesAt server time, 0 = no
-- close scheduled), like AtmosphereService: one small state, late joiners read it on join, no Lync entry. The client
-- (MarketController) moves the shutters and plays the metal door SFX at the stand on every change.
-- Dev (`/dev gear open|close|state`): Force(open) wins until the next natural change (shift end / selling start /
-- closed phase); open during a selling phase also schedules the close (now + StayOpenIntoShift) to test the warning.
-- No snapshot: the state is derived again from the phase on every transition.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

const HOURS = Content.Mart.Hours
const ALWAYS_CLOSED: { [string]: boolean } = {}
for _, phase in Content.Mart.KioskClosedPhases do
	ALWAYS_CLOSED[phase] = true
end

const GearStandService = Modux.Service("GearStandService", {
	Require = { "PlaceService", "RoundService", "RunStateService" },
	-- above MarketService (615), which reads IsOpen in its prompt effect
	Priority = 617,
})

function GearStandService:Setup()
	self.Enabled = false :: boolean
	-- reactive: MarketService's prompt effect re-reads IsOpen
	self.Open = self.Libs.Charm.atom(false) :: Charm.Atom<boolean>
	self.ClosesAt = 0 :: number -- server time of the scheduled close, 0 = none
	self.Warned = false :: boolean -- the "closing in" toast of the current window went out
	-- the shift that opened the stand already scheduled its close (one window per shift end)
	self.Scheduled = false :: boolean
end

function GearStandService:IsOpen(): boolean
	return self.Open()
end

function GearStandService:Publish()
	Workspace:SetAttribute(HOURS.Attributes.Open, self.Open())
	Workspace:SetAttribute(HOURS.Attributes.ClosesAt, self.ClosesAt)
end

-- open / close; notify = party toast on a real change
function GearStandService:Set(open: boolean, notify: boolean)
	const changed = self.Open() ~= open
	self.Open(open)
	if not open then
		self.ClosesAt = 0
		self.Warned = false
	end
	self:Publish()
	if changed and notify then
		self.Dependencies.RunStateService:Notify("all", if open then "gear_open" else "gear_shut", 0)
	end
end

-- close at now + StayOpenIntoShift (warning CloseWarning before)
function GearStandService:Schedule(now: number)
	self.Scheduled = true
	self.ClosesAt = now + HOURS.StayOpenIntoShift
	self.Warned = HOURS.CloseWarning <= 0
	self:Publish()
end

function GearStandService:OnPhase(phase: string)
	const now = Workspace:GetServerTimeNow()
	if ALWAYS_CLOSED[phase] then
		self.Scheduled = false
		self:Set(false, true)
		return
	end
	if not HOURS.OpenAtShiftEnd then
		self:Set(true, true)
		return
	end
	if phase == "Summary" then
		-- = RoundService.ShiftEnded (fired just before this PhaseChanged): a new window
		self.Scheduled = false
		self.ClosesAt = 0
		self.Warned = false
		self:Set(true, true)
		return
	end
	const row = Content.Shift.ByKey[phase]
	if row and row.Selling and self.Open() and not self.Scheduled then
		self:Schedule(now)
	end
end

function GearStandService:Step()
	if not self.Enabled or self.ClosesAt <= 0 or not self.Open() then
		return
	end
	const left = self.ClosesAt - Workspace:GetServerTimeNow()
	if left <= 0 then
		self:Set(false, true)
		return
	end
	if not self.Warned and left <= HOURS.CloseWarning then
		self.Warned = true
		self.Dependencies.RunStateService:Notify("all", "gear_closing", math.ceil(left))
	end
end

-- Dev override (`/dev gear`): open = open now (and, in a selling phase, the close scheduled from now); close = now
function GearStandService:Force(open: boolean)
	if not self.Enabled then
		error("Gear Stand hours run only in the Run place", 0)
	end
	if not open then
		self:Set(false, true)
		return
	end
	self.Scheduled = false
	self.ClosesAt = 0
	self.Warned = false
	self:Set(true, true)
	const row = Content.Shift.ByKey[self.Dependencies.RoundService:GetPhase()]
	if HOURS.OpenAtShiftEnd and row and row.Selling then
		self:Schedule(Workspace:GetServerTimeNow())
	end
end

-- One line for `/dev gear state`
function GearStandService:Report(): string
	const phase = self.Dependencies.RoundService:GetPhase()
	local closes = "no close scheduled"
	if self.ClosesAt > 0 then
		closes = `closes in {math.max(0, math.ceil(self.ClosesAt - Workspace:GetServerTimeNow()))}s`
			.. (if self.Warned then " (warned)" else "")
	end
	return `Gear Stand {if self.Open() then "OPEN" else "CLOSED"} - phase {phase}, {closes}`
		.. ` - hours {if HOURS.OpenAtShiftEnd then "on" else "off"} (stay {HOURS.StayOpenIntoShift}s, warn {HOURS.CloseWarning}s)`
end

GearStandService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true
	self.Dependencies.RoundService.PhaseChanged:Connect(function(phase, _day, _night)
		self:OnPhase(phase)
	end)
end)

GearStandService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- initial state (before the run starts): closed with hours, open without
	self.Open(not HOURS.OpenAtShiftEnd)
	self:Publish()
end)

GearStandService:OnTick(function(self)
	self:Step()
end, HOURS.Tick)

return GearStandService
