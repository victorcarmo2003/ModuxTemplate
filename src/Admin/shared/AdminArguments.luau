--!strict
-- Typed Conch arguments backed by the Content tables (never hardcoded keys). Required by both sides so the
-- type ids exist on the server and on the client that parses the command line.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local conch = require(ReplicatedStorage.Packages.Conch)

const MAX_MONEY = 1_000_000_000

-- Anomalies in play order (owner 2026-10-18: numbers in order): by debut night, then by Ref.
local function playable(): { any }
	const out: { any } = {}
	for _, row in Content.Anomalies.List do
		table.insert(out, row)
	end
	table.sort(out, function(a: any, b: any): boolean
		if a.Night ~= b.Night then
			return a.Night < b.Night
		end
		return a.Ref < b.Ref
	end)
	return out
end

const PLAYABLE = playable()
const PLAYABLE_KEYS: { string } = {}
for _, row in PLAYABLE do
	table.insert(PLAYABLE_KEYS, row.Key)
end

return {
	-- anomalies the console offers, in play order (see playable)
	PlayableAnomalies = PLAYABLE,
	-- Content keys (ITM/UPG/CLS rows)
	ItemKey = conch.args.enum_from_array("item_key", Content.Items.Keys),
	IngredientKey = conch.args.enum_from_array("ingredient_key", Content.Ingredients.Keys),
	ClassKey = conch.args.enum_from_array("class_key", Content.Classes.Keys),
	UpgradeKey = conch.args.enum_from_array("upgrade_key", Content.Upgrades.Keys),
	-- anomalies (owner 2026-10-16): every Content.Anomalies key, autocompleted in the console
	AnomalyKey = conch.args.enum_from_array("anomaly_key", PLAYABLE_KEYS),
	AnomalyAction = conch.args.enum_from_array("anomaly_action", { "trigger", "resolve", "wrong", "stop" }),
	ArrivalsState = conch.args.enum_from_array("arrivals_state", { "on", "off" }),
	-- Numbers (validated again in the callback: the server never trusts the parsed value)
	Day = conch.args.number,
	Night = conch.args.number,
	Money = conch.args.number,
	Player = conch.args.player,
	-- gift recipient (TASK-352): a player name (in this server, or any Roblox username) or a UserId (offline too)
	Recipient = conch.args.string,
	MaxMoney = MAX_MONEY,
	MaxGiftGems = 1_000_000,
}
