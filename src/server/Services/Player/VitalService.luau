local CollectionService = game:GetService("CollectionService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local VitalService = Modux.Service("VitalService"):Import("PlayerService"):Import("SpawnService")
type Self = typeof(VitalService)

local RESPAWN_DELAY = 3

VitalService.OnStaminaDepleted = VitalService.Signal.new() :: Modux.Signal<Player>

VitalService.OnPlayerDie = function(self: Self, Player: Player)
	local character = Player.Character
	if not character then
		return
	end

	local HRP = character:FindFirstChild("HumanoidRootPart", true)
	if HRP then
		self.Tools.BreakJoints(HRP)
	end

	task.delay(RESPAWN_DELAY, function()
		print(`[VitalService] Respawnando {Player.Name} depois do delay de ragdoll`)
		self.SpawnService:RequestSpawn(Player)
	end)
end

VitalService:OnInit(function(self)
	self.Network.Packages.GetVitals:handle(function(_, Player: Player?)
		if not Player then
			return nil
		end

		local playerVital = self:GetComponent(Player, "VitalComponent")
		if not playerVital then
			return nil
		end

		return {
			Armor = playerVital.Armor,
			Health = playerVital.Health,
			Stamina = playerVital.Stamina,
		}
	end)

	self.PlayerService:OnPlayerAdded(function(Player: Player)
		CollectionService:AddTag(Player, "VitalComponent")
	end)
end)

return VitalService
