--!strict
-- Traffic commands (board TASK-104; architecture.md §8, §19.17). Thin wrappers over TrafficService.
--   traffic                         cars (route, distance/length, speed, stop), holds, reservations, density now
--   traffic spawn [TR-n]            a car now on that route (or a random one): ignores timers, density and holds
--   traffic clear                   removes every car
--   traffic hold <reason> on|off    TrafficService:Hold (anm_008, anm_010, cutscene, ambulance)
--   traffic reserve <CW-n> [npc]    ReserveCrossing with a fake NpcId (default 0); expires after Crossing.MaxWait
--   traffic release <CW-n> [npc]    ReleaseCrossing
--   traffic hit                     knocks the caller as a valid car hit (Knock, SetKnocked, DropHeld, immunity)
local Api = require(script.Parent.Parent.Api)

type Traffic = {
	Status: (self: any) -> string,
	DevSpawn: (self: any, route: string?) -> string,
	DevClear: (self: any) -> number,
	DevHit: (self: any, player: Player) -> boolean,
	Hold: (self: any, reason: string, on: boolean) -> (),
	ReserveCrossing: (self: any, cw: string, npcId: number) -> boolean,
	ReleaseCrossing: (self: any, cw: string, npcId: number) -> (),
}

const USAGE = "traffic [spawn [TR-n] | clear | hold <reason> on|off | reserve <CW-n> [npc] | release <CW-n> [npc] | hit]"

local function npcOf(text: string?): number
	const value = if text then tonumber(text) else 0
	if value == nil or value ~= math.floor(value) then
		error(`usage: {USAGE}`, 0)
	end
	return value
end

const Traffic: Api.Module = function(ctx: Api.Context): { Api.Command }
	const traffic = ctx.Get("TrafficService") :: Traffic

	return {
		{
			Name = "traffic",
			Usage = USAGE,
			Help = "street cars: state, spawn, clear, hold, crosswalk reservation, hit test",
			Run = function(args: { string }, caller: Player?): string?
				const sub = if args[1] then string.lower(args[1]) else nil
				if sub == nil then
					return traffic:Status()
				elseif sub == "spawn" then
					return traffic:DevSpawn(if args[2] then string.upper(args[2]) else nil)
				elseif sub == "clear" then
					return `{traffic:DevClear()} car(s) removed`
				elseif sub == "hold" then
					const reason = args[2]
					const mode = if args[3] then string.lower(args[3]) else nil
					if reason == nil or (mode ~= "on" and mode ~= "off") then
						error(`usage: {USAGE}`, 0)
					end
					traffic:Hold(reason, mode == "on")
					return `hold {reason} {mode}`
				elseif sub == "reserve" or sub == "release" then
					const cw = if args[2] then string.upper(args[2]) else nil
					if cw == nil then
						error(`usage: {USAGE}`, 0)
					end
					const npc = npcOf(args[3])
					if sub == "reserve" then
						return `{cw}: {if traffic:ReserveCrossing(cw, npc) then "granted" else "refused"}`
					end
					traffic:ReleaseCrossing(cw, npc)
					return `{cw}: released`
				elseif sub == "hit" then
					if caller == nil then
						error("traffic hit needs a caller (use the chat)", 0)
					end
					return if traffic:DevHit(caller) then "hit" else "not knocked (no body, fainted, frozen or down)"
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Traffic
