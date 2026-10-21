--!strict
-- Private profile view (network.md §4.5): Gems, unlocked Classes, Selected class and TutorialDone as Vide sources.
-- Ready stays false until the first Profile packet; the defaults mirror a new account (Template v1).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const DEFAULT_CLASS = "class_dog"

const ProfileController = Modux.Controller("ProfileController", { Priority = 800 })

function ProfileController:Setup()
	self.Gems = Vide.source(0) :: Vide.Source<number>
	self.Classes = Vide.source({ [DEFAULT_CLASS] = true }) :: Vide.Source<{ [string]: boolean }>
	self.Selected = Vide.source(DEFAULT_CLASS) :: Vide.Source<string>
	self.Ready = Vide.source(false) :: Vide.Source<boolean>
	-- first-hot-dog tutorial done or skipped (TutorialController reads it once Ready)
	self.TutorialDone = Vide.source(false) :: Vide.Source<boolean>
	-- lobby floor guides already shown (Content.Lobby.Guide.Keys; LobbyController reads it)
	self.Guides = Vide.source({}) :: Vide.Source<{ [string]: boolean }>
end

function ProfileController:Owns(class: string): boolean
	return self.Classes()[class] == true
end

ProfileController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Profile:onClient(function(data)
		self.Gems(data.Gems)
		self.Classes(table.freeze(data.Classes))
		self.Selected(data.Selected)
		self.TutorialDone(data.TutorialDone)
		self.Guides(table.freeze(data.Guides))
		self.Ready(true)
	end)
end)

return ProfileController
