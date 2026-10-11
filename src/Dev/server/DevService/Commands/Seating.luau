--!strict
-- Pad table commands (board TASK-145; FEAT-037). Thin wrappers over SeatingService (Dev* check IsDev).
--   seating                 tables (state, price, tip, party), diners and tension
--   seating buy             next table for free (UpgradeService level, no Spend, no notice)
--   seating sit             the next customer/pair that ends its order well sits whatever the chance
--   seating dirty <n> [tip] table n dirty with a tip (default Seating.TableTip)
--   seating clean <n>       cleans table n (tip into the drawer, drawer must be open)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "seating [buy | sit | dirty <n> [tip] | clean <n>]"

type Seating = {
	DevList: (self: any) -> string,
	DevBuy: (self: any) -> number,
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
			Help = "Pad tables: list, free purchase, force the next sit, dirty / clean a table",
			Run = function(args: { string }, _caller: Player?): string?
				const verb = args[1]
				if verb == nil then
					return seating:DevList()
				elseif verb == "buy" then
					return `tables bought: {seating:DevBuy()}`
				elseif verb == "sit" then
					seating:DevForceSit()
					return "the next customer or pair that ends its order well sits (if a table is free)"
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
