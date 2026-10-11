--!strict
-- TutorialService (user request 2026-10-11, Provisional): single responder of `TutorialComplete` (network.md, Profile
-- packet field TutorialDone; data.md §1.1). Sets the profile flag TutorialDone = true when the client says the
-- first-hot-dog tutorial ended (finished or skipped) and asks a save. Idempotent: a second packet changes nothing.
-- Cosmetic flag (nothing else reads it on the server): the client is trusted to say it. Run place only.
-- AnyPending (Provisional, user request 2026-10-11): BossService rings and holds the tutorial call (BossCalls Trigger
-- Tutorial) while a player in the server still has the tutorial ahead.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const TutorialService = Modux.Service(
	"TutorialService",
	{ Require = { "ProfileService", "PlaceService" }, Priority = 500 }
)

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

TutorialService:OnInit(function(self)
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Libs.Net.TutorialComplete:onServer(function(_, player: Player)
		self:Complete(player)
	end)
end)

return TutorialService
