--!strict
-- Schema dos dados persistentes do jogador (ProfileService/ProfileStore).
-- Adicione campos aqui, e sincronize com:
--   - src/shared/Modux/CoreTypes.luau (DataTemplate / DataTemplateKey / DataKeyPayload)
--   - src/shared/Modux/src/Network/init.luau (Network.Packages.Data / DataKey)
local Template = {
	-- Economy
	Gems = 0,

	-- Onboarding
	FirstLogin = true,

	-- Settings
	MusicVolume = 100,
	SoundVolume = 100,
	MusicEnabled = true,
	SoundEnabled = true,
}

return { Template = Template }
