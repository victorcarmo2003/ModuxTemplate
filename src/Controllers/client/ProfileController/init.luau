--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const ProfileController = Modux.Controller("ProfileController", { Priority = 800 })

function ProfileController:Setup()
	self.Coins = Vide.source(0) :: Vide.Source<number>
	self.Level = Vide.source(1) :: Vide.Source<number>
	self.Playtime = Vide.source(0) :: Vide.Source<number>
	self.Ready = Vide.source(false) :: Vide.Source<boolean>
end

ProfileController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Profile:onAdded(function(_, record)
		self.Coins(record.Coins)
		self.Level(record.Level)
		self.Playtime(record.Playtime)
		self.Ready(true)
	end)

	self.Libs.Net.Profile:onChanged(function(_, record)
		self.Coins(record.Coins)
		self.Level(record.Level)
		self.Playtime(record.Playtime)
	end)

	self.Libs.Net.Profile:onRemoved(function()
		self.Ready(false)
	end)
end)

return ProfileController
