--!strict
-- Vital commands (board TASK-062; architecture.md §19.7). Thin wrappers over the dev hooks of VitalService. Player:
-- [player] by Name/DisplayName (exact, then unique prefix, case-insensitive); without it the chat caller; from the
-- Command Bar (no caller) the only player in the server.
--   /dev sanity [player]              value, max, state, band, revives tonight, coffee cooldown, last cause
--   /dev sanity <n> [player]          sets the sanity of an Active member at night (0 = falls)
--   /dev sanity dark on|off|auto      forces every position dark / lit, or back to LightService (TASK-059)
--   /dev down [player]                falls now as Down (sanity 0, faint, stash, StateEndsAt = 6:00 AM)
--   /dev spectate [player]            falls now as Spectator (DEC-129 path: faint, DropStash)
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

type Entry = {
	Sanity: number,
	Max: number,
	Band: string,
	RevivesTonight: number,
	CoffeeReadyAt: number,
	StateEndsAt: number,
	LastCause: string,
}

type Vital = {
	Ensure: (self: any, player: Player) -> Entry,
	GetState: (self: any, userId: number) -> string?,
	DevSetSanity: (self: any, player: Player, value: number) -> number,
	DevFall: (self: any, player: Player, state: string?) -> (),
	DevDark: (self: any, mode: boolean?) -> (),
	WipeEndsAt: number,
}

const USAGE_SANITY = "sanity [<n> | dark on|off|auto] [player]"

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

const Vital: Api.Module = function(ctx: Api.Context): { Api.Command }
	const vital = ctx.Get("VitalService") :: Vital

	local function status(player: Player): string
		const entry = vital:Ensure(player)
		const t = workspace:GetServerTimeNow()
		const coffee = math.max(0, math.ceil(entry.CoffeeReadyAt - t))
		const ends = if entry.StateEndsAt > 0 then `, ends in {math.ceil(entry.StateEndsAt - t)}s` else ""
		const wipe = if vital.WipeEndsAt > 0 then `; wipe in {math.ceil(vital.WipeEndsAt - t)}s` else ""
		return `{player.Name}: sanity {entry.Sanity}/{entry.Max}, {vital:GetState(player.UserId) or "not a member"}`
			.. `{ends}, band {entry.Band}, revives tonight {entry.RevivesTonight}, coffee in {coffee}s, `
			.. `last cause "{entry.LastCause}"{wipe}`
	end

	return {
		{
			Name = "sanity",
			Usage = USAGE_SANITY,
			Help = "sanity status; set a value (0 = falls); force the dark on/off for the dark rule",
			Run = function(args: { string }, caller: Player?): string?
				const first = args[1]
				if first ~= nil and string.lower(first) == "dark" then
					const mode = string.lower(args[2] or "")
					if mode == "on" then
						vital:DevDark(true)
					elseif mode == "off" then
						vital:DevDark(false)
					elseif mode == "auto" then
						vital:DevDark(nil)
					else
						error(`usage: {USAGE_SANITY}`, 0)
					end
					return `dark forced: {mode}`
				end
				const value = if first ~= nil then tonumber(first) else nil
				if value == nil then
					return status(targetOf(first, caller))
				end
				const player = targetOf(args[2], caller)
				vital:DevSetSanity(player, value)
				return status(player)
			end,
		},
		{
			Name = "down",
			Usage = "down [player]",
			Help = "the player falls now as Down (sanity 0)",
			Run = function(args: { string }, caller: Player?): string?
				const player = targetOf(args[1], caller)
				vital:DevFall(player, "Down")
				return status(player)
			end,
		},
		{
			Name = "spectate",
			Usage = "spectate [player]",
			Help = "the player falls now as Spectator",
			Run = function(args: { string }, caller: Player?): string?
				const player = targetOf(args[1], caller)
				vital:DevFall(player, "Spectator")
				return status(player)
			end,
		},
	}
end

return Vital
