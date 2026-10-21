--!strict
-- Revive command (docs/tech/showcase.md). Stand-in for the wave 4 ReviveService: VitalService:DevRevive brings a Down
-- or Spectator member back Active (half sanity, new character, stash returned).
--   revive [player]    by Name/DisplayName (exact, then unique prefix); without it the caller, or the only player
--   revive all         every Down or Spectator player (owner 2026-10-21)
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

type Vital = {
	DevRevive: (self: any, player: Player) -> string,
}

local function targetOf(query: string?, caller: Player?): Player
	if query ~= nil then
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
		error(if #matches == 0 then `no player matches "{query}"` else `"{query}" matches {#matches} players`, 0)
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

const Revive: Api.Module = function(ctx: Api.Context): { Api.Command }
	const vital = ctx.Get("VitalService") :: Vital

	return {
		{
			Name = "revive",
			Usage = "revive [player|all]",
			Help = "brings a Down or Spectator player (or all of them) back Active (dev stand-in for a revive)",
			Run = function(args: { string }, caller: Player?): string?
				if args[1] ~= nil and string.lower(args[1]) == "all" then
					const lines: { string } = {}
					for _, player in Players:GetPlayers() do
						const ok, reply = pcall(vital.DevRevive, vital, player)
						if ok then
							table.insert(lines, reply)
						end
					end
					return if #lines > 0 then table.concat(lines, "; ") else "nobody is Down or Spectator"
				end
				return vital:DevRevive(targetOf(args[1], caller))
			end,
		},
	}
end

return Revive
