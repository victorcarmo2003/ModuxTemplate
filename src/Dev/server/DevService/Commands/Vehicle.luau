--!strict
-- Trailer commands (board TASK-056; FEAT-016, FEAT-017). Thin wrappers over VehicleService (dev checks inside).
--   trailer        current vehicle, purchase state, pending swap and price
--   trailer buy    free purchase on any day and phase (no cash); the swap waits for the end of the shift
--   trailer swap   swap now (buys for free first if needed): fade, PivotTo, SetVehicle, Swapped
local Api = require(script.Parent.Parent.Api)

type Vehicles = {
	Current: (self: any) -> string,
	IsBought: (self: any) -> boolean,
	IsPending: (self: any) -> boolean,
	Price: (self: any) -> number,
	DevBuy: (self: any) -> boolean,
	DevSwap: (self: any) -> boolean,
}

const USAGE = "trailer [buy | swap]"

const Vehicle: Api.Module = function(ctx: Api.Context): { Api.Command }
	const vehicles = ctx.Get("VehicleService") :: Vehicles

	local function state(): string
		return `vehicle {vehicles:Current()}; bought {vehicles:IsBought()}; pending {vehicles:IsPending()}; price ${vehicles:Price()}`
	end

	return {
		{
			Name = "trailer",
			Usage = USAGE,
			Help = "trailer state; 'buy' buys it for free (swap at the end of the shift); 'swap' swaps now",
			Run = function(args: { string }, _caller: Player?): string?
				const sub = if args[1] then string.lower(args[1]) else nil
				if sub == nil then
					return state()
				elseif sub == "buy" then
					if not vehicles:DevBuy() then
						error(`already bought ({state()})`, 0)
					end
					return `bought; swap at the end of the shift ({state()})`
				elseif sub == "swap" then
					if not vehicles:DevSwap() then
						error(`already swapped ({state()})`, 0)
					end
					return `swapped ({state()})`
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Vehicle
