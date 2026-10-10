--!strict
-- Kitchen altered-item commands (TASK-113, tests/wave-3.md R22; architecture.md §19.13; ITM-020). Go through the
-- KitchenService API, so the Stations set, the "assembled" hot dog and Discarded behave as in play. They place the
-- item only: no ANM-002 occurrence runs (use "anomaly anm_002_wrong_food" for the whole anomaly).
--   alter                   whether the current vehicle has an altered item (rail, board)
--   alter rail|board [slot] KitchenService:Alter (Night phase only; false = no room, one already there, or locked)
--   alter clear             KitchenService:ClearAltered (every station)
local Api = require(script.Parent.Parent.Api)

const USAGE = "alter [rail|board [slot]|clear]"

type Kitchen = {
	Alter: (self: any, kind: "rail" | "board", slot: number?) -> boolean,
	ClearAltered: (self: any) -> number,
	HasAltered: (self: any, kind: ("rail" | "board")?) -> boolean,
}

const Kitchen: Api.Module = function(ctx: Api.Context): { Api.Command }
	const kitchen = ctx.Get("KitchenService") :: Kitchen

	return {
		{
			Name = "alter",
			Usage = USAGE,
			Help = "puts an altered item (ANM-002) on the rail or a board, clears them, or shows where they are",
			Run = function(args: { string }, _caller: Player?): string?
				const sub = args[1]
				if sub == nil then
					return `altered: rail {if kitchen:HasAltered("rail") then "yes" else "no"}, board {if kitchen:HasAltered(
						"board"
					)
						then "yes"
						else "no"}`
				elseif sub == "clear" then
					return `cleared {kitchen:ClearAltered()} station(s)`
				elseif sub ~= "rail" and sub ~= "board" then
					error(`usage: {USAGE}`, 0)
				end
				local slot: number? = nil
				if args[2] ~= nil then
					slot = tonumber(args[2])
					if slot == nil then
						error(`usage: {USAGE}`, 0)
					end
				end
				const kind: "rail" | "board" = if sub == "rail" then "rail" else "board"
				if not kitchen:Alter(kind, slot) then
					error(`Alter("{kind}") refused (Night phase only; no room, one already there, or station busy)`, 0)
				end
				return `altered item placed on the {kind}`
			end,
		},
	}
end

return Kitchen
