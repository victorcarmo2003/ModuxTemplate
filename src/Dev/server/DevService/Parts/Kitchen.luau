--!strict
-- Coffee doses (part of `coffee`, Commands/Coffee.luau). The ANM-002 "alter" command left with the restaurant cut
-- (2026-10-18, docs/tech/dev-commands.md).
--   coffee [n]              coffee doses of the machine (user request 2026-10-11): shows them, or sets n (0..capacity;
--                           capacity is 0 with the cart in use, coffee only opens with the trailer)
local Api = require(script.Parent.Parent.Api)

type Kitchen = {
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
	}
end

return Kitchen
