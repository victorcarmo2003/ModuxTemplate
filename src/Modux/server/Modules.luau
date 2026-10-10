--!strict

local ServerScriptService = game:GetService("ServerScriptService")

return {
	ServerScriptService.server.Character.CharacterService,
	ServerScriptService.server.Class.ClassService,
	ServerScriptService.server.Customer.CustomerService,
	ServerScriptService.server.Dev.DevService,
	ServerScriptService.server.Economy.EconomyService,
	ServerScriptService.server.Interaction.InteractionService,
	ServerScriptService.server.Item.ItemService,
	ServerScriptService.server.Kitchen.KitchenService,
	ServerScriptService.server.Market.MarketService,
	ServerScriptService.server.Net.NetService,
	ServerScriptService.server.Npc.NpcService,
	ServerScriptService.server.Place.PlaceService,
	ServerScriptService.server.Player.PlayerService,
	ServerScriptService.server.Profile.ProfileService,
	ServerScriptService.server.Round.RoundService,
	ServerScriptService.server.Run.RunStateService,
	ServerScriptService.server.Upgrade.UpgradeService,
	ServerScriptService.server.Vital.VitalService,
} :: { ModuleScript }
