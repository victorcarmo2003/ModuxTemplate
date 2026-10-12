--!strict
-- Kitchen altered-item commands (TASK-113, tests/wave-3.md R22; architecture.md §19.13; ITM-020). Go through the
-- KitchenService API, so the Stations set, the "assembled" hot dog and Discarded behave as in play. They place the
-- item only: no ANM-002 occurrence runs (use "anomaly anm_002_wrong_food" for the whole anomaly).
--   alter                   whether the current vehicle has an altered item (rail, board)
--   alter rail|board [slot] KitchenService:Alter (Night phase only; false = no room, one already there, or locked)
--   alter clear             KitchenService:ClearAltered (every station)
--   coffee [n]              coffee doses of the machine (user request 2026-10-11): shows them, or sets n (0..capacity;
--                           capacity is 0 with the cart in use, coffee only opens with the trailer)
local Api = require(script.Parent.Parent.Api)

const USAGE = "alter [rail|board [slot]|clear]"

type Kitchen = {
	Alter: (self: any, kind: "rail" | "board", slot: number?) -> boolean,
	ClearAltered: (self: any) -> number,
	HasAltered: (self: any, kind: ("rail" | "board")?) -> boolean,
	DevSetCoffee: (self: any, amount: number) -> number,
	GetStock: (self: any, ingredient: string) -> (number, number),
}

const Kitchen: Api.Module = function(ctx: Api.Context): { Api.Command }
	const kitchen = ctx.Get("KitchenService") :: Kitchen

	return {
		{
			Name = "coffee",
			Usage = "coffee [n]",
			Help = "coffee doses in the machine: no argument shows them, n sets them (clamped to the capacity)",
			Run = function(args: { string }, _caller: Player?): string?
				if args[1] ~= nil then
					const value = tonumber(args[1])
					if value == nil then
						error("usage: coffee [n]", 0)
					end
					kitchen:DevSetCoffee(value)
				end
				const amount, capacity = kitchen:GetStock("coffee")
				return `coffee {amount}/{capacity}`
			end,
		},
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
