local Modux = require(game.ReplicatedStorage.Shared.Modux)
local PlayerService = Modux.Service("PlayerService")
type Self = typeof(PlayerService)

-- Modelo mínimo de um character válido; troque por um tipo mais específico
-- (com Motor6Ds, attachments, etc.) se o seu rig customizado precisar.
export type CharacterModel = Model & {
	Humanoid: Humanoid,
	HumanoidRootPart: BasePart,
}

PlayerService._playerAddedCallbacks = {}
PlayerService._playerRemovedCallbacks = {}
PlayerService._characterAddedCallbacks = {}
PlayerService._characterRemovedCallbacks = {}
PlayerService.allPlayers = {} :: { [number]: Player }
PlayerService.allCharacters = {} :: { [number]: CharacterModel }

-- [[ API ]] --
-- Registers a callback to be called whenever a player joins
PlayerService.OnPlayerAdded = function(self: Self, callback: (Player: Player) -> ())
	table.insert(PlayerService._playerAddedCallbacks, callback)
end

-- Registers a callback to be called whenever a player left
PlayerService.OnPlayerRemoved = function(self: Self, callback: (Player: Player) -> ())
	table.insert(PlayerService._playerRemovedCallbacks, callback)
end

-- Registers a callback to be called whenever a character is added to any player
PlayerService.OnCharacterAdded = function(self: Self, callback: (Character: CharacterModel, Player: Player) -> ())
	table.insert(PlayerService._characterAddedCallbacks, callback)
end

-- Registers a callback to be called whenever a character is removed to any player
PlayerService.OnCharacterRemoved = function(self: Self, callback: (Character: CharacterModel, Player: Player) -> ())
	table.insert(PlayerService._characterRemovedCallbacks, callback)
end

PlayerService.GetAllPlayers = function(self: Self): { Player }
	return table.clone(self.allPlayers)
end

PlayerService.GetAllCharacters = function(self: Self): { CharacterModel }
	return table.clone(self.allCharacters)
end

-- [[ INTERNAL ]] --
local function triggerCharacterAdded(character: CharacterModel, player: Player)
	for _, cb in PlayerService._characterAddedCallbacks do
		task.spawn(cb, character, player)
	end
end

local function triggerCharacterRemoved(character: CharacterModel, player: Player)
	for _, cb in PlayerService._characterRemovedCallbacks do
		task.spawn(cb, character, player)
	end
end

local function triggerPlayerAdded(player: Player)
	for _, cb in PlayerService._playerAddedCallbacks do
		task.spawn(cb, player)
	end

	table.insert(PlayerService.allPlayers, player)
	-- Setup character listener for this player
	PlayerService:Cleanup(player.CharacterAdded:Connect(function(character)
		table.insert(PlayerService.allCharacters, character)
		triggerCharacterAdded(character, player)
	end))

	-- If character already exists, trigger immediately
	if player.Character then
		table.insert(PlayerService.allCharacters, player.Character)
		triggerCharacterAdded(player.Character :: CharacterModel, player)
	end

	PlayerService:Cleanup(player.CharacterRemoving:Connect(function(character)
		triggerCharacterRemoved(character, player)
		local position = table.find(PlayerService.allCharacters, character)
		if position then
			table.remove(PlayerService.allCharacters, position)
		end
	end))
end

local function triggerPlayerRemoved(player: Player)
	for _, cb in PlayerService._playerRemovedCallbacks do
		task.spawn(cb, player)
	end
	local position = table.find(PlayerService.allPlayers, player)
	if position then
		table.remove(PlayerService.allPlayers, position)
	end
end

-- [[ LIFECYCLE ]] --

PlayerService:OnInit(function(self)
	local Players = game:GetService("Players")

	-- Connect to future players
	self:Cleanup(Players.PlayerAdded:Connect(triggerPlayerAdded))
	self:Cleanup(Players.PlayerRemoving:Connect(triggerPlayerRemoved))
	-- Handle existing players
	for _, player in Players:GetPlayers() do
		task.spawn(triggerPlayerAdded, player)
	end
end)

PlayerService:OnDestroy(function(self)
	table.clear(self._playerAddedCallbacks)
	table.clear(self._playerRemovedCallbacks)
	table.clear(self._characterAddedCallbacks)
	table.clear(self._characterRemovedCallbacks)
end)

return PlayerService
