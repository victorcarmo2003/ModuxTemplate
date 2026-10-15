--!strict
-- Tester shortcuts (TASK-332; owner request 2026-10-15, Provisional). Also run by the dev row of the settings panel
-- (packet DevTool -> DevService). Player: [player] by Name/DisplayName (exact, then unique prefix); without it the chat
-- caller; from the Command Bar the only player in the server.
--   /dev mycoffee [player]                a full coffee in the hand (same Tool as the machine's; click it to drink, night only)
--   /dev infsanity [on|off] [player]      infinite sanity: never drops, no faint (only /dev down still works); no
--                                         argument toggles. On fills the bar (Active at night)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Api = require(script.Parent.Parent.Api)
local Content = require(ReplicatedStorage.shared.Content)

type Vital = {
	DevInfiniteSanity: (self: any, player: Player, on: boolean) -> boolean,
	IsDevInfinite: (self: any, player: Player) -> boolean,
	GetSanity: (self: any, player: Player) -> (number, number),
}

type Items = {
	Give: (self: any, player: Player, key: string, options: any) -> Tool?,
}

const USAGE_INFINITE = "infsanity [on|off] [player]"

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
	error(`{#players} players in the server: name one`, 0)
end

const Tester: Api.Module = function(ctx: Api.Context): { Api.Command }
	const vital = ctx.Get("VitalService") :: Vital
	const items = ctx.Get("ItemService") :: Items

	return {
		{
			Name = "mycoffee",
			Usage = "mycoffee [player]",
			Help = "a full coffee in the hand (click it to drink; night only)",
			Run = function(args: { string }, caller: Player?): string?
				const player = targetOf(args[1], caller)
				const tool = items:Give(player, "coffee", { Restore = Content.Sanity.Coffee })
				return if tool
					then `coffee given to {player.Name}`
					else `{player.Name}: Give refused (hands full / already holds one)`
			end,
		},
		{
			Name = "infsanity",
			Usage = USAGE_INFINITE,
			Help = "infinite sanity on/off (no argument toggles): never drops, no faint",
			Run = function(args: { string }, caller: Player?): string?
				const first = if args[1] then string.lower(args[1]) else nil
				local on: boolean? = nil
				local query = args[1]
				if first == "on" then
					on = true
					query = args[2]
				elseif first == "off" then
					on = false
					query = args[2]
				end
				const player = targetOf(query, caller)
				const value = if on == nil then not vital:IsDevInfinite(player) else on
				vital:DevInfiniteSanity(player, value)
				const sanity, max = vital:GetSanity(player)
				return `{player.Name}: infinite sanity {if value then "on" else "off"} ({sanity}/{max})`
			end,
		},
	}
end

return Tester
