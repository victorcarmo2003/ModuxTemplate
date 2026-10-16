--!strict
--[[
	JournalService (TASK-335, TASK-345; owner request 2026-10-15, Provisional)

	Server half of the Anomaly Tablet (the tablet in the trailer). Owns profile.Journal (Content.Journal key -> os.time() of
	the unlock) and talks to the owner only:
	  Unlock   AnomalyService.Ended(key, players): an occurrence of an anomaly with a page ended and these players took
	           part (Active at its start, or failed it: they died to it or got past it). A page the profile does not
	           have yet is written (copy, never in place) and saved with ProfileService:RequestSave. Kept across runs.
	  Journal  s -> owner, once the profile is loaded AND the client is ready (whichever comes last), and again with
	           New = the key on every new page (the client toasts and makes the tablet glow).
	  Prompt   read_journal (the tablet, tools/assetplace/anomaly_tablet.luau; Run place only): JournalOpen to that player.
	           Reading the tablet changes nothing on the server: no freeze, no gate.
	Nothing of money, items or stats rides on it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

const rules = Content.Journal.Rules

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

function JournalService:Send(player: Player, new: string?)
	const net = self.Dependencies.NetService
	if not net:IsRunning() or not net:IsReady(player) then
		return
	end
	const pages = self:Pages(player)
	if pages == nil then
		return
	end
	self.Libs.Net.Journal:fireClient(player, { Pages = pages, New = new })
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

-- Dev / Command Bar: forget every page of this player (the tablet starts empty again).
function JournalService:Reset(player: Player)
	const profiles = self.Dependencies.ProfileService
	if profiles:Get(player) == nil then
		return
	end
	profiles:Update(player, { Journal = {} })
	profiles:RequestSave(player)
	self:Send(player, nil)
end

function JournalService:Register()
	self.Dependencies.InteractionService:RegisterAction(rules.Action, {
		Validate = function(player: Player, _anchor: Instance, _id: number): boolean
			return self.Dependencies.ProfileService:Get(player) ~= nil
		end,
		Run = function(player: Player, _anchor: Instance, _id: number)
			self.Libs.Net.JournalOpen:fireClient(player, nil)
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
