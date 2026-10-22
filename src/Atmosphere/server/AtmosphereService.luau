--!strict
--[[
	AtmosphereService (TASK-275; DEC-257; design/anomalies-v2-proposal.md §4)

	Picks the night's atmosphere (ATM-#) and publishes it; AtmosphereController draws it. Ambience only: no rule reads
	this. Run servers only.

	State (replicated): Workspace attribute Content.Atmospheres.Rules.Attribute ("Atmosphere") = "ATM-<n>" while an
	atmosphere is on, nil during the day. One string, so a Workspace attribute instead of a Lync set (late joiners
	read it on join; no packet needed).

	Which key:
	  * a Night phase starts: Content.Nights row of that night, field `Atmosphere` (TASK-271's table); while the rows
	    have no such field, Content.Atmospheres.Rules.Fallback[night]; unknown key = Rules.Default
	  * any other phase: nil (the client blends back to the day)
	  * Force(key) (dev, `/dev atmosphere`): wins over the night until Force(nil); "" forces "no atmosphere"

	Forced lightning (Strike(near), dev `/dev bolt`, or a scripted scare): Workspace attribute Rules.StrikeAttribute =
	"<server time>:<0|1 near>", a hair in the future so every client flashes together. Clients play it over any
	atmosphere (Rules.Strike when the row has no Lightning); with no atmosphere on (day) nothing shows.

	Forced shower (Shower(length), dev `/dev shower`): Workspace attribute Rules.ShowerAttribute =
	"<server time start>:<length s>" (length 0 = stop).

	API: Get() -> key?, KeyFor(night) -> key, Force(key?), IsForced(), Strike(near), Shower(length). The Scheduler does not need to call anything
	when the key lives in Content.Nights; Set(key?) exists for a scheduler that wants to drive it itself.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

const ATMOSPHERES = Content.Atmospheres
const RULES = ATMOSPHERES.Rules
const STRIKE_LEAD = 0.15 -- s ahead of now a forced strike is stamped (replication time)

const AtmosphereService = Modux.Service(
	"AtmosphereService",
	{ Require = { "PlaceService", "RoundService" }, Priority = 600 }
)

function AtmosphereService:Setup()
	self.Enabled = false :: boolean
	self.Natural = nil :: string? -- key the round asks for
	self.Forced = nil :: string? -- dev override; "" = forced off
	self.Dark = false :: boolean -- RoundService:IsDark() at the last Refresh (the morning's dusk comes by the clock)
end

-- Key of the night (Content.Nights field, else the provisional fallback, else Default).
function AtmosphereService:KeyFor(night: number): string
	const row = Content.Nights.List[night]
	const fromRow: unknown = if row then (row :: any).Atmosphere else nil
	local key = if type(fromRow) == "string" then fromRow else RULES.Fallback[night]
	if key == nil or ATMOSPHERES.ByKey[key] == nil then
		key = RULES.Default
	end
	return key :: string
end

function AtmosphereService:Get(): string?
	const value = Workspace:GetAttribute(RULES.Attribute)
	return if type(value) == "string" and value ~= "" then value else nil
end

function AtmosphereService:IsForced(): boolean
	return self.Forced ~= nil
end

function AtmosphereService:Publish()
	if not self.Enabled then
		return
	end
	local key = self.Natural
	if self.Forced ~= nil then
		key = if self.Forced == "" then nil else self.Forced
	end
	if key ~= self:Get() then
		Workspace:SetAttribute(RULES.Attribute, key)
	end
end

-- Natural key (what the round wants); nil = day. For a scheduler that drives the atmosphere itself.
function AtmosphereService:Set(key: string?)
	if key ~= nil and ATMOSPHERES.ByKey[key] == nil then
		warn(`[AtmosphereService] unknown atmosphere "{key}", using {RULES.Default}`)
		key = RULES.Default
	end
	self.Natural = key
	self:Publish()
end

-- Dev override: a key, "" (forced off) or nil (back to the round's key).
function AtmosphereService:Force(key: string?)
	if key ~= nil and key ~= "" and ATMOSPHERES.ByKey[key] == nil then
		error(`unknown atmosphere "{key}"`, 0)
	end
	self.Forced = key
	self:Publish()
end

-- One forced lightning strike on every client; `near` = the scare (bright, thunder at once, camera jolt).
function AtmosphereService:Strike(near: boolean)
	const at = Workspace:GetServerTimeNow() + STRIKE_LEAD
	Workspace:SetAttribute(RULES.StrikeAttribute, `{string.format("%.3f", at)}:{if near then 1 else 0}`)
end

-- A forced shower on every client from now, `length` s (0 = stop it); it opens with its strike like a natural one.
-- Only rows with Showers rain (all of them today).
function AtmosphereService:Shower(length: number)
	const now = Workspace:GetServerTimeNow()
	Workspace:SetAttribute(RULES.ShowerAttribute, `{string.format("%.3f", now + STRIKE_LEAD)}:{math.max(0, length)}`)
end

function AtmosphereService:Refresh()
	const round = self.Dependencies.RoundService
	-- owner 2026-10-21: the morning of a night shift is clear; the night's atmosphere (fog, rain) comes back at its dusk
	const night = round:IsDark()
	self.Dark = night
	self:Set(if night then self:KeyFor(round:GetNight()) else nil)
end

AtmosphereService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true
	self.Dependencies.RoundService.PhaseChanged:Connect(function()
		self:Refresh()
	end)
end)

-- the dusk of the morning comes inside the Prep phase, by the clock: catch it
AtmosphereService:OnTick(function(self)
	if self.Enabled and self.Dependencies.RoundService:IsDark() ~= self.Dark then
		self:Refresh()
	end
end, 2)

AtmosphereService:OnStart(function(self)
	if self.Enabled then
		self:Refresh()
	end
end)

return AtmosphereService
