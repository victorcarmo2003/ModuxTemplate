--!strict
-- Redeem codes (TASK-161; user request 2026-10-11, Provisional; data.md §1.7, network.md §15.2; Q-191).
-- SERVER ONLY on purpose: this file lives in ServerScriptService, not in ReplicatedStorage.shared.Content, because
-- everything in ReplicatedStorage is readable by every client, and a code that ships to the client is a public code.
-- Key = the normalized code: upper case, letters/digits/underscore only, 3..20 characters (CodesService checks it on
-- boot). Persisted in profile.RedeemedCodes by Key: never rename a live code, add a new one.
-- Reward: Gems and/or Class (a Content.Classes key, InMvp). A class the player already owns turns into its gem price.
-- Expires: ISO 8601 UTC ("2026-12-31T23:59:59Z"); nil = never. Active = false switches a code off without deleting it
-- (deleting is fine too: unknown code = "Invalid").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Table = require(ReplicatedStorage.shared.Content.Table)

export type Reward = {
	Gems: number?,
	Class: string?,
}

export type Code = {
	Key: string,
	Reward: Reward,
	Expires: string?,
	Active: boolean?, -- nil = true
	Note: string?, -- who / why (not shown to players)
}

return Table.new({
	{
		Key = "BETA",
		Reward = { Gems = 500 },
		Expires = "2026-11-10T23:59:59Z",
		Note = "Beta tester code",
	},
} :: { Code })
