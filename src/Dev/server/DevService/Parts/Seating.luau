--!strict
-- Table commands (board TASK-145; FEAT-037), part of `customer tables` (Commands/Customer.luau). Thin wrappers over
-- SeatingService (Dev* check IsDev). The trailer / dirty / clean forms left with the restaurant (no dirty tables).
--   seating                 tables (group, state, price, tip, party), diners and tension
--   seating buy             next table for free (the one group, TBL-1..4; UpgradeService level, no Spend, no notice)
--   seating sit             the next customer/pair that takes its order sits at a free table (Q-209)
local Api = require(script.Parent.Parent.Api)

const USAGE = "customer tables [buy | sit]"

type Seating = {
	DevList: (self: any, group: string?) -> string,
	DevBuy: (self: any, group: string?) -> number,
	DevForceSit: (self: any) -> (),
}

const Seating: Api.Module = function(ctx: Api.Context): { Api.Command }
	const seating = ctx.Get("SeatingService") :: Seating

	return {
		{
			Name = "seating",
			Usage = USAGE,
			Help = "tables: list, the next one for free, force the next sit",
			Run = function(args: { string }, _caller: Player?): string?
				const verb = args[1]
				if verb == nil then
					return seating:DevList()
				elseif verb == "buy" then
					return `tables bought: {seating:DevBuy(args[2])}`
				elseif verb == "sit" then
					seating:DevForceSit()
					return "the next customer or pair that takes its order sits (if a table is free and the phase is Open / Night)"
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Seating
