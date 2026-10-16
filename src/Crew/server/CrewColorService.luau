--!strict
-- CrewColorService (owner request 2026-10-16, Provisional): gives every player of the server one palette colour
-- (Crew/shared/CrewColor), written on the Player attribute `CrewColor`: the lowest index nobody holds, freed when he
-- leaves. Read by the name tag over the head, the character outline and the co-op prep (DEC-259). No network packet:
-- Player attributes replicate to every client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)
local CrewColor = require(ReplicatedStorage.shared.Crew.CrewColor)

const CrewColorService = Modux.Service("CrewColorService", { Priority = 600 })

function CrewColorService:Setup()
	self.Taken = {} :: { [number]: Player }
end

function CrewColorService:Assign(player: Player)
	for index = 1, CrewColor.Count do
		if self.Taken[index] == nil then
			self.Taken[index] = player
			player:SetAttribute(CrewColor.Attribute, index)
			return
		end
	end
	-- more players than colours: share, by join order
	player:SetAttribute(CrewColor.Attribute, (#Players:GetPlayers() - 1) % CrewColor.Count + 1)
end

function CrewColorService:Release(player: Player)
	for index, holder in self.Taken do
		if holder == player then
			self.Taken[index] = nil
		end
	end
end

CrewColorService:OnInit(function(self)
	self:Setup()
	Players.PlayerAdded:Connect(function(player)
		self:Assign(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Release(player)
	end)
	for _, player in Players:GetPlayers() do
		self:Assign(player)
	end
end)

return CrewColorService
