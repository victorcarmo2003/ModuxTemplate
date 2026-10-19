--!strict
-- Gems and party cash commands (board TASK-043, R2; tests/wave-1.md §0.4 R2, T017-03). Thin wrappers over the dev
-- hooks of ClassService (TASK-017 v1.1: DevGrantGems) and EconomyService (TASK-021 v1.1: DevAddCash). The owners
-- check IsDev(), clamp the totals (never below 0) and replicate/save; this file only parses and picks the player.
-- Player for "gems": [player] by Name/DisplayName (exact, then unique prefix, case-insensitive); without it the
-- chat caller; from the Command Bar (no caller) the only player in the server (Provisional, TASK-043).
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

type Class = {
	DevGrantGems: (self: any, player: Player, amount: number) -> number,
}

type Economy = {
	DevAddCash: (self: any, amount: number) -> number,
	GetCash: (self: any) -> number,
}

local function amountOf(text: string?, usage: string): number
	const value = if text then tonumber(text) else nil
	if value == nil or value ~= value or math.abs(value) == math.huge then
		error(`usage: {usage}`, 0)
	end
	return math.floor(value)
end

local function findPlayer(query: string): Player
	const needle = string.lower(query)
	const matches = {}
	for _, player in Players:GetPlayers() do
		const name = string.lower(player.Name)
		const display = string.lower(player.DisplayName)
		if name == needle or display == needle then
			return player
		end
		if string.sub(name, 1, #needle) == needle or string.sub(display, 1, #needle) == needle then
			table.insert(matches, player)
		end
	end
	if #matches == 1 then
		return matches[1]
	end
	if #matches == 0 then
		error(`no player matches "{query}"`, 0)
	end
	error(`"{query}" matches {#matches} players, be more specific`, 0)
end

local function targetOf(query: string?, caller: Player?): Player
	if query ~= nil then
		return findPlayer(query)
	end
	if caller ~= nil then
		return caller
	end
	const players = Players:GetPlayers()
	if #players == 1 then
		return players[1]
	end
	error(`{#players} players in the server: name one (gems <n> <player>)`, 0)
end

const Economy: Api.Module = function(ctx: Api.Context): { Api.Command }
	const class = ctx.Get("ClassService") :: Class
	const economy = ctx.Get("EconomyService") :: Economy

	return {
		{
			Name = "gems",
			Usage = "gems <n> [player]",
			Help = "add n gems to a player's profile (negative removes, never below 0); default: you / the only player",
			Run = function(args: { string }, caller: Player?): string?
				const amount = amountOf(args[1], "gems <n> [player]")
				const player = targetOf(args[2], caller)
				const total = class:DevGrantGems(player, amount)
				return `{player.Name} gems {if amount >= 0 then "+" else ""}{amount} -> {total}`
			end,
		},
		{
			Name = "cash",
			Usage = "cash <n>",
			Help = "add n to the party Cash (negative removes, never below 0)",
			Run = function(args: { string }, _caller: Player?): string?
				const amount = amountOf(args[1], "cash <n>")
				const before = economy:GetCash()
				const total = economy:DevAddCash(amount)
				return `Cash {before} -> {total}`
			end,
		},
	}
end

return Economy
