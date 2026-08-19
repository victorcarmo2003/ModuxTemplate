local Modux = require(game.ReplicatedStorage.Shared.Modux)

local SpawnService = Modux.Service("SpawnService")
type Self = typeof(SpawnService)

-- Troque por sua própria lógica de seleção de spawn (times, zonas, etc.)
-- quando o jogo precisar de algo além de "primeiro SpawnLocation achado".
local function findSpawnLocation(): BasePart?
	local direct = workspace:FindFirstChildOfClass("SpawnLocation")
	if direct then
		return direct
	end

	for _, instance in workspace:GetDescendants() do
		if instance:IsA("SpawnLocation") then
			return instance
		end
	end

	return nil
end

-- Chamado pelo VitalService após a morte, ou por qualquer fluxo (lobby -> partida)
-- que precise (re)colocar o player no mapa.
SpawnService.RequestSpawn = function(self: Self, Player: Player)
	if not Player:IsDescendantOf(game:GetService("Players")) then
		return
	end

	Player:LoadCharacterAsync()

	local character = Player.Character
	local spawnLocation = findSpawnLocation()
	if character and spawnLocation then
		character:PivotTo(spawnLocation:GetPivot() + Vector3.new(0, 2, 0))
	end
end

return SpawnService
