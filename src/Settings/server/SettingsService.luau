--!strict
-- Player settings (TASK-279; owner request 2026-10-14, Provisional). Lobby and Run.
-- Keeps profile.Settings (Template) and talks to the owner only:
--   Settings      s -> owner, once the profile is loaded AND the client is ready (whichever comes last)
--   SettingsSave  c -> s, the whole record; sanitized by SettingsRules (the client is never trusted for a range), saved with
--                 ProfileService:RequestSave (grouped). Cosmetic only: nothing of money, items or stats rides on it.
-- Rate limit: one save per MIN_GAP s; the client debounces, so a save inside the gap is dropped and the next one carries
-- the last values anyway.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SettingsRules = require(ReplicatedStorage.shared.Settings.SettingsRules)
local Modux = require(ServerScriptService.server.Modux)

const MIN_GAP = 0.25 -- s between two saves of the same player

const SettingsService = Modux.Service(
	"SettingsService",
	{ Require = { "ProfileService", "NetService" }, Priority = 660 }
)

function SettingsService:Setup()
	self.LastAt = {} :: { [Player]: number }
end

-- Sanitized settings of a loaded profile; nil while the profile is not loaded.
function SettingsService:Get(player: Player): SettingsRules.Settings?
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile then
		return nil
	end
	return SettingsRules.Sanitize(profile.Settings())
end

function SettingsService:Send(player: Player)
	const net = self.Dependencies.NetService
	if not net:IsRunning() or not net:IsReady(player) then
		return
	end
	const settings = self:Get(player)
	if settings == nil then
		return
	end
	self.Libs.Net.Settings:fireClient(player, settings)
end

-- Server API too (Command Bar tests): SettingsService:Save(player, { Music = 40 }).
function SettingsService:Save(player: Player, raw: any)
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if not profile then
		return
	end
	const current = SettingsRules.Sanitize(profile.Settings())
	const merged = table.clone(current) :: { [string]: any }
	if type(raw) == "table" then
		for key, value in raw :: { [string]: any } do
			merged[key] = value
		end
	end
	const settings = SettingsRules.Sanitize(merged)
	if SettingsRules.Same(settings, current) then
		return
	end
	profiles:Update(player, { Settings = settings })
	profiles:RequestSave(player)
end

SettingsService:OnInit(function(self)
	self:Setup()

	self.Dependencies.ProfileService.Loaded:Connect(function(player)
		self:Send(player)
	end)
	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:Send(player)
	end)

	self.Libs.Net.SettingsSave:onServer(function(data, player: Player)
		const now = os.clock()
		const last = self.LastAt[player]
		if last ~= nil and now - last < MIN_GAP then
			return
		end
		self.LastAt[player] = now
		self:Save(player, data)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.LastAt[player] = nil
	end)
end)

return SettingsService
