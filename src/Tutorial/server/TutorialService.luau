--!strict
-- TutorialService (user request 2026-10-11, Provisional): single responder of `TutorialComplete` (network.md, Profile
-- packet field TutorialDone; data.md §1.1). Sets the profile flag TutorialDone = true when the client says the
-- first-hot-dog tutorial ended (finished or skipped) and asks a save. Idempotent: a second packet changes nothing.
-- Cosmetic flag (nothing else reads it on the server): the client is trusted to say it. Run place only.
-- AnyPending (Provisional, user request 2026-10-11): BossService rings and holds the tutorial call (BossCalls Trigger
-- Tutorial) while a player in the server still has the tutorial ahead.
-- Tutorial customer (Provisional, user request 2026-10-11): `TutorialBegin` from a rookie (TutorialDone = false) asks
-- CustomerService for the tutorial customer (one at a time, shared.Tutorial.Rules). Once nobody has the tutorial
-- pending any more (finished, skipped, left), an unserved tutorial customer is sent away (CustomerService:EndTutorial).
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const TICK_RATE = 2 -- Hz: the pending check of the tutorial customer

const TutorialService = Modux.Service(
	"TutorialService",
	{ Require = { "ProfileService", "PlaceService", "CustomerService" }, Priority = 500 }
)

function TutorialService:Setup()
	self.Enabled = false :: boolean
	-- a tutorial customer was asked and the tutorial may still be running for someone
	self.Asked = false :: boolean
end

function TutorialService:Complete(player: Player)
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if profile == nil or profile.TutorialDone() == true then
		return
	end
	profiles:Update(player, { TutorialDone = true })
	profiles:RequestSave(player)
end

-- A player in the server with a loaded profile still has the tutorial ahead (TutorialDone = false)
function TutorialService:IsPending(player: Player): boolean
	const profile = self.Dependencies.ProfileService:Get(player)
	return profile ~= nil and profile.TutorialDone() == false
end

function TutorialService:AnyPending(): boolean
	for _, player in Players:GetPlayers() do
		if self:IsPending(player) then
			return true
		end
	end
	return false
end

-- A rookie started the tutorial (answered the call): the tutorial customer comes
function TutorialService:Begin(player: Player)
	if not self:IsPending(player) then
		return
	end
	if self.Dependencies.CustomerService:RequestTutorial() then
		self.Asked = true
	end
end

function TutorialService:Step()
	if self.Asked and not self:AnyPending() then
		self.Asked = false
		self.Dependencies.CustomerService:EndTutorial()
	end
end

TutorialService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true
	self.Libs.Net.TutorialComplete:onServer(function(_, player: Player)
		self:Complete(player)
	end)
	self.Libs.Net.TutorialBegin:onServer(function(_, player: Player)
		self:Begin(player)
	end)
end)

TutorialService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return TutorialService
