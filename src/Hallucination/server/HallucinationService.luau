--!strict
--[[
	HallucinationService (TASK-274; anomalies-v2-proposal.md §3 D; DEC-254, DEC-256)

	Server door to the family D scares ("sustos sem verbo"): events that ask nothing of the player, never hurt, never
	count as an anomaly and never jumpscare (the jumpscare is the error's, DEC-256). The effects are client-only
	(HallucinationController); this service only tells the client "play one now" through the packet
	HallucinationScare. Each client picks, among the allowed keys, one FamilyD row it can show right now (its own
	view, its own vehicle, its own cooldowns), so two players may get different scares from the same call.

	API (for the night scheduler, TASK-271):
	  :Scare(target, keys?) -> number   target = Player | { Player } | nil (nil = every player in the run);
	                                     keys = allowed Content.Hallucinations keys (FamilyD only; nil / {} = any).
	                                     Unknown or non-FamilyD keys are dropped with one warning. Returns how many
	                                     players were sent the scare (0 = nothing sent).
	  :Keys() -> { string }              every FamilyD key, in table order (to build a night's list).
	  :IsScare(key) -> boolean           key is a FamilyD row.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

const MAX_KEYS = 32 -- packet limit (HallucinationScare.Keys)

const HallucinationService = Modux.Service("HallucinationService", {
	Require = { "NetService" },
})

function HallucinationService:Setup()
	self.Warned = {} :: { [string]: boolean }
end

function HallucinationService:IsScare(key: string): boolean
	const row = Content.Hallucinations.ByKey[key]
	return row ~= nil and row.FamilyD
end

function HallucinationService:Keys(): { string }
	const out: { string } = {}
	for _, row in Content.Hallucinations.List do
		if row.FamilyD then
			table.insert(out, row.Key)
		end
	end
	return out
end

-- Allowed keys after validation; nil = the caller's list had keys but none was valid (send nothing).
function HallucinationService:Filter(keys: { string }?): { string }?
	if keys == nil or #keys == 0 then
		return {}
	end
	const out: { string } = {}
	for _, key in keys do
		if self:IsScare(key) then
			if #out < MAX_KEYS and not table.find(out, key) then
				table.insert(out, key)
			end
		elseif not self.Warned[key] then
			self.Warned[key] = true
			warn(`[HallucinationService] '{key}' is not a family D scare (Content.Hallucinations FamilyD): dropped`)
		end
	end
	return if #out > 0 then out else nil
end

function HallucinationService:Scare(target: (Player | { Player })?, keys: { string }?): number
	const allowed = self:Filter(keys)
	if allowed == nil then
		return 0
	end
	const net = self.Dependencies.NetService
	if not net:IsRunning() then
		return 0
	end
	const payload = { Keys = allowed }
	if target == nil then
		self.Libs.Net.HallucinationScare:fireClient(net.Audience, payload)
		return #Players:GetPlayers()
	end
	const list: { Player } = if typeof(target) == "Instance" then { target :: Player } else target :: { Player }
	local sent = 0
	for _, player in list do
		if player.Parent == Players then
			self.Libs.Net.HallucinationScare:fireClient(player, payload)
			sent += 1
		end
	end
	return sent
end

HallucinationService:OnInit(function(self)
	self:Setup()
end)

return HallucinationService
