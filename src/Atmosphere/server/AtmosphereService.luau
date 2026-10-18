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
	  * any other phase: nil (the client blends back to the day); also the Intro of a run that starts at night (DEC-300)
	  * Force(key) (dev, `/dev atmosphere`): wins over the night until Force(nil); "" forces "no atmosphere"

	API: Get() -> key?, KeyFor(night) -> key, Force(key?), IsForced(). The Scheduler does not need to call anything
	when the key lives in Content.Nights; Set(key?) exists for a scheduler that wants to drive it itself.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

const ATMOSPHERES = Content.Atmospheres
const RULES = ATMOSPHERES.Rules

const AtmosphereService = Modux.Service(
	"AtmosphereService",
	{ Require = { "PlaceService", "RoundService" }, Priority = 600 }
)

function AtmosphereService:Setup()
	self.Enabled = false :: boolean
	self.Natural = nil :: string? -- key the round asks for
	self.Forced = nil :: string? -- dev override; "" = forced off
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

function AtmosphereService:Refresh()
	const round = self.Dependencies.RoundService
	-- the run's intro is played on Night 1 (DEC-300) but stays clear: the atmosphere comes in after its nightfall
	const night = round:IsNight() and round:GetPhase() ~= "Intro"
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

AtmosphereService:OnStart(function(self)
	if self.Enabled then
		self:Refresh()
	end
end)

return AtmosphereService
