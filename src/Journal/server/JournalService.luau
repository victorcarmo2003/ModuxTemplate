--!strict
--[[
	JournalService (TASK-335, TASK-345; owner request 2026-10-15, Provisional)

	Server half of the Anomaly Tablet (the tablet in the trailer). Owns profile.Journal (Content.Journal key -> os.time() of
	the unlock) and talks to the owner only:
	  Unlock   AnomalyService.Ended(key, players): an occurrence of an anomaly with a page ended and these players took
	           part (Active at its start, or failed it: they died to it or got past it). A page the profile does not
	           have yet is written (copy, never in place) and saved with ProfileService:RequestSave. Kept across runs.
	  Journal  s -> owner, once the profile is loaded AND the client is ready (whichever comes last), and again with
	           New = the key on every new page (the client toasts and makes the tablet glow), and with Gained = the key on
	           every claim.
	  Claim    (owner request 2026-10-17, Provisional) JournalClaim from the client when the player opens a page on the
	           tablet: the first time, Rules.Reward gems are paid and the page is flagged in profile.JournalClaimed
	           (saved, so the gems never pay twice, on any server). An unlocked page without the flag is "new": the
	           tablet shows "!" and glows until it is opened. GemsEarned is not touched (RewardService owns it).
	  Prompt   read_journal (the tablet, tools/assetplace/anomaly_tablet.luau; Run place only): JournalOpen to that player.
	           Reading the tablet changes nothing on the server: no freeze, no gate.
	No money, items or stats ride on it, only the page gems.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)
local MetricsLog = require(ServerScriptService.server.Metrics.MetricsService.Log)

const rules = Content.Journal.Rules
const GEMS_MAX = 2147483647 -- Profile.Gems wire range (network.md §4.5)

const JournalService = Modux.Service("JournalService", {
	Require = { "PlaceService", "ProfileService", "NetService", "AnomalyService", "InteractionService" },
	Priority = 540,
})

function JournalService:Setup()
	self.Active = false :: boolean
end

-- Unlocked pages of a loaded profile, as the packet bitfield (keys Content.Journal knows); nil while not loaded.
function JournalService:Pages(player: Player): { [string]: boolean }?
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile then
		return nil
	end
	const pages: { [string]: boolean } = {}
	const saved = profile.Journal()
	if type(saved) == "table" then
		for key in saved do
			if Content.Journal.ByKey[key] ~= nil then
				pages[key] = true
			end
		end
	end
	return pages
end

-- Pages whose gems were paid (profile.JournalClaimed), as the packet bitfield; {} while not loaded.
function JournalService:Claimed(player: Player): { [string]: boolean }
	const profile = self.Dependencies.ProfileService:Get(player)
	const claimed: { [string]: boolean } = {}
	const saved = if profile then profile.JournalClaimed() else nil
	if type(saved) == "table" then
		for key in saved do
			if Content.Journal.ByKey[key] ~= nil then
				claimed[key] = true
			end
		end
	end
	return claimed
end

function JournalService:Send(player: Player, new: string?, gained: string?)
	const net = self.Dependencies.NetService
	if not net:IsRunning() or not net:IsReady(player) then
		return
	end
	const pages = self:Pages(player)
	if pages == nil then
		return
	end
	self.Libs.Net.Journal:fireClient(player, { Pages = pages, Claimed = self:Claimed(player), New = new, Gained = gained })
end

-- Server API too (Command Bar tests): pays Rules.Reward gems for an unlocked page the first time. true = paid.
-- No yield between the checks and the Update (two packets in a row never pay twice).
function JournalService:Claim(player: Player, key: string): boolean
	if Content.Journal.ByKey[key] == nil then
		return false
	end
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if not profile then
		return false
	end
	const pages = profile.Journal()
	if type(pages) ~= "table" or pages[key] == nil then
		return false
	end
	const saved = profile.JournalClaimed()
	if type(saved) == "table" and saved[key] ~= nil then
		return false
	end
	const claimed = if type(saved) == "table" then table.clone(saved) else {}
	claimed[key] = os.time()
	const gems = rules.Reward
	profiles:Update(player, {
		Gems = math.clamp(profile.Gems() + gems, 0, GEMS_MAX),
		JournalClaimed = claimed,
	})
	profiles:RequestSave(player)
	MetricsLog.gems(player, "Source", gems, profile.Gems(), "Journal", key)
	self:Send(player, nil, key)
	return true
end

-- Server API too (Command Bar tests): JournalService:Unlock(player, "anm_001_blank_folks"). true = a new page.
function JournalService:Unlock(player: Player, key: string): boolean
	if Content.Journal.ByKey[key] == nil then
		return false
	end
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if not profile then
		return false
	end
	const saved = profile.Journal()
	if type(saved) == "table" and saved[key] ~= nil then
		return false
	end
	const pages = if type(saved) == "table" then table.clone(saved) else {}
	pages[key] = os.time()
	profiles:Update(player, { Journal = pages })
	profiles:RequestSave(player)
	self:Send(player, key)
	return true
end

-- Dev / Command Bar: forget every page and claim of this player (the tablet starts empty again; gems already paid stay).
function JournalService:Reset(player: Player)
	const profiles = self.Dependencies.ProfileService
	if profiles:Get(player) == nil then
		return
	end
	profiles:Update(player, { Journal = {}, JournalClaimed = {} })
	profiles:RequestSave(player)
	self:Send(player, nil)
end

-- Opens the tablet on this player's screen (the prompt, and /dev journal open).
function JournalService:Open(player: Player)
	self.Libs.Net.JournalOpen:fireClient(player, nil)
end

function JournalService:Register()
	self.Dependencies.InteractionService:RegisterAction(rules.Action, {
		Validate = function(player: Player, _anchor: Instance, _id: number): boolean
			return self.Dependencies.ProfileService:Get(player) ~= nil
		end,
		Run = function(player: Player, _anchor: Instance, _id: number)
			self:Open(player)
		end,
	})
end

JournalService:OnInit(function(self)
	self:Setup()

	self.Dependencies.ProfileService.Loaded:Connect(function(player)
		self:Send(player, nil)
	end)
	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:Send(player, nil)
	end)
	self.Libs.Net.JournalClaim:onServer(function(key, player: Player)
		if type(key) == "string" then
			self:Claim(player, key)
		end
	end)

	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Active = true
	self:Register()

	self.Dependencies.AnomalyService.Ended:Connect(function(key: string, players: { Player })
		if Content.Journal.ByKey[key] == nil then
			return
		end
		for _, player in players do
			if player.Parent == Players then
				self:Unlock(player, key)
			end
		end
	end)
end)

return JournalService
