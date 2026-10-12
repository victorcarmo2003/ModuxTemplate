--!strict
-- Pad table commands (board TASK-145; FEAT-037). Thin wrappers over SeatingService (Dev* check IsDev).
--   seating                 tables (group, state, price, tip, party), diners and tension
--   seating buy [pad|trailer]  next table of the group for free (default: the group that seats now; UpgradeService
--                           level, no Spend, no notice)
--   seating trailer [buy]   the Trailer tables (TBL-6..9, UPG-011); "buy" = next one for free (hidden until the trailer
--                           is the vehicle: /dev vehicle trailer)
--   seating sit             the next customer/pair that takes its order sits at a free table (Q-209; /dev customer sit
--                           also spawns one)
--   seating dirty <n> [tip] table n dirty with a tip (default Seating.TableTip)
--   seating clean <n>       cleans table n (tip into the drawer, drawer must be open)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "seating [buy [pad|trailer] | trailer [buy] | sit | dirty <n> [tip] | clean <n>]"

type Seating = {
	DevList: (self: any, group: string?) -> string,
	DevBuy: (self: any, group: string?) -> number,
	DevForceSit: (self: any) -> (),
	DevDirty: (self: any, index: number, tip: number?) -> (),
	DevClean: (self: any, index: number) -> (),
}

local function tableIndex(text: string?): number
	const value = if text then tonumber(text) else nil
	if value == nil or value ~= math.floor(value) or value < 1 or value > Content.Seating.Tables then
		error(`usage: {USAGE} (n = 1..{Content.Seating.Tables})`, 0)
	end
	return value
end

const Seating: Api.Module = function(ctx: Api.Context): { Api.Command }
	const seating = ctx.Get("SeatingService") :: Seating

	return {
		{
			Name = "seating",
			Usage = USAGE,
			Help = "Pad / Trailer tables: list, free purchase, force the next sit, dirty / clean a table",
			Run = function(args: { string }, _caller: Player?): string?
				const verb = args[1]
				if verb == nil then
					return seating:DevList()
				elseif verb == "buy" then
					return `tables bought: {seating:DevBuy(args[2])}`
				elseif verb == "trailer" then
					if args[2] == "buy" then
						seating:DevBuy("trailer")
					elseif args[2] ~= nil then
						error(`usage: {USAGE}`, 0)
					end
					return seating:DevList("trailer")
				elseif verb == "sit" then
					seating:DevForceSit()
					return "the next customer or pair that takes its order sits (if a table is free and the phase is Open / Night)"
				elseif verb == "dirty" then
					const index = tableIndex(args[2])
					const tip = if args[3] then tonumber(args[3]) else nil
					seating:DevDirty(index, tip)
					return `TBL-{index} dirty`
				elseif verb == "clean" then
					const index = tableIndex(args[2])
					seating:DevClean(index)
					return `TBL-{index} clean`
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Seating
