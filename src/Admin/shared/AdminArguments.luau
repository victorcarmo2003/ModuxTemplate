--!strict
-- Typed Conch arguments backed by the Content tables (never hardcoded keys). Required by both sides so the
-- type ids exist on the server and on the client that parses the command line.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local conch = require(ReplicatedStorage.Packages.Conch)

const MAX_MONEY = 1_000_000_000

return {
	-- Content keys (ITM/UPG/CLS rows)
	ItemKey = conch.args.enum_from_array("item_key", Content.Items.Keys),
	IngredientKey = conch.args.enum_from_array("ingredient_key", Content.Ingredients.Keys),
	ClassKey = conch.args.enum_from_array("class_key", Content.Classes.Keys),
	UpgradeKey = conch.args.enum_from_array("upgrade_key", Content.Upgrades.Keys),
	-- Numbers (validated again in the callback: the server never trusts the parsed value)
	Day = conch.args.number,
	Money = conch.args.number,
	Player = conch.args.player,
	MaxMoney = MAX_MONEY,
}
