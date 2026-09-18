--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Struct = require(ReplicatedStorage.shared.Types.Struct)
local Template = require(script.Template)
local Modux = require(ServerScriptService.server.Modux)

export type Data = typeof(Template)

const STORE_NAME = "Player"

const ProfileService = Modux.Service("ProfileService", { Require = { "PlayerService" }, Priority = 800 })

function ProfileService:Setup()
	self.Store = ProfileStore.New(STORE_NAME, Template) :: any
	self.Profiles = {} :: { [Player]: any }
	self.Loaded = self.Libs.Signal.new() :: SignalLib.Signal<Player, Data>
end

function ProfileService:Get(player: Player): Data?
	const profile = self.Profiles[player]
	if not profile then
		return nil
	end
	return profile.Data
end

function ProfileService:Update(player: Player, patch: Struct.Partial<Data>)
	const profile = self.Profiles[player]
	if not profile then
		warn(`[ProfileService] {player.Name} has no loaded profile`)
		return
	end
	for key, value in patch :: any do
		profile.Data[key] = value
	end
	self.Libs.Net.Profile:update(player.UserId, patch)
end

function ProfileService:Load(player: Player)
	const profile = self.Store:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		self.Profiles[player] = nil
		player:Kick("Your data session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	self.Profiles[player] = profile

	const owner = tostring(player.UserId)
	const data = profile.Data
	self.Libs.Net.Profile:add(player.UserId, {
		Owner = owner,
		Coins = data.Coins,
		Level = data.Level,
		Playtime = data.Playtime,
	})
	self.Libs.Net.Profile:audience(owner, player)

	self.Loaded:Fire(player, data)
end

function ProfileService:Unload(player: Player)
	if self.Libs.Net.Profile:get(player.UserId) then
		self.Libs.Net.Profile:remove(player.UserId)
	end

	const profile = self.Profiles[player]
	if not profile then
		return
	end
	self.Profiles[player] = nil
	profile:EndSession()
end

ProfileService:OnInit(function(self)
	self:Setup()

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:Load(player)
		end)
	end)
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Unload(player)
	end)
end)

return ProfileService
