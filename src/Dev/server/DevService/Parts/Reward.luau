--!strict
-- Reward commands (board TASK-074; tests/wave-2.md §0.4 R7, L2-04). Thin wrappers over the dev hooks of
-- RewardService (DevSetEndless, DevForget, DevStatus), which check IsDev() and save; this file only parses and picks
-- the player. Player: [player] by Name/DisplayName (exact, then unique prefix, case-insensitive); without it the chat
-- caller; from the Command Bar (no caller) the only player in the server.
--   /dev reward endless <n> [player]   EndlessDays = n (T074-05: 99, then one endless day with anti-AFK)
--   /dev reward forget [player]        clears RunRewards keys and gems of this run (repeat events after ResetDev)
--   /dev reward status [player]        gems, EndlessDays, run gems and used keys
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

type Reward = {
	DevSetEndless: (self: any, player: Player, days: number) -> number,
	DevForget: (self: any, player: Player) -> number,
	DevStatus: (self: any, player: Player) -> string,
}

const USAGE = "reward endless <n> [player] | reward forget [player] | reward status [player]"

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

const Reward: Api.Module = function(ctx: Api.Context): { Api.Command }
	const reward = ctx.Get("RewardService") :: Reward

	return {
		{
			Name = "reward",
			Usage = USAGE,
			Help = "gem rewards: set EndlessDays, forget this run's reward keys, show status",
			Run = function(args: { string }, caller: Player?): string?
				const sub = string.lower(args[1] or "")
				if sub == "endless" then
					const days = tonumber(args[2] or "")
					if days == nil then
						error(`usage: {USAGE}`, 0)
					end
					const player = targetOf(args[3], caller)
					return `{player.Name} EndlessDays -> {reward:DevSetEndless(player, days)}`
				elseif sub == "forget" then
					const player = targetOf(args[2], caller)
					return `{player.Name} forgot {reward:DevForget(player)} reward key(s) of this run`
				elseif sub == "status" then
					const player = targetOf(args[2], caller)
					return `{player.Name}: {reward:DevStatus(player)}`
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Reward
