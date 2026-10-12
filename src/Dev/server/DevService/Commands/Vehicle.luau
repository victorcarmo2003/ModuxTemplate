--!strict
-- Trailer commands (board TASK-056; FEAT-016, FEAT-017). Thin wrappers over VehicleService (dev checks inside).
--   trailer          trailer offer test (user request 2026-10-12): back to the cart and not bought, go to the Prep of the
--                    day after night Content.Trailer.OfferAfterNight and ring call_trailer_offer at once, answered:
--                    camera focus on the FOR SALE sign, Walt's till tops the cash up to the price, then buy at the
--                    sign; the purchase rings call_trailer_bought
--   trailer broke    the same with the party's cash at 0 (shows the full grant)
--   trailer reset    undo it: cart, not bought, offer / bought calls and the money flag forgotten, phone silent
--   trailer status   current vehicle, purchase state, pending swap and price
--   trailer buy      free purchase on any day and phase (no cash); the swap waits for the end of the shift
--   trailer swap     swap now (buys for free first if needed): fade, PivotTo, SetVehicle, Swapped
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

type Vehicles = {
	Current: (self: any) -> string,
	IsBought: (self: any) -> boolean,
	IsPending: (self: any) -> boolean,
	Price: (self: any) -> number,
	DevBuy: (self: any) -> boolean,
	DevSwap: (self: any) -> boolean,
	DevReset: (self: any) -> (),
}

type Boss = {
	DevResetTrailer: (self: any) -> (),
	DevCall: (self: any, key: string) -> (),
	DevAnswer: (self: any) -> (),
	DevStatus: (self: any) -> string,
}

type Round = {
	DevSetDay: (self: any, day: number) -> (),
	DevSetNight: (self: any, night: number) -> (),
	GetDay: (self: any) -> number,
}

type Economy = {
	GetCash: (self: any) -> number,
	DevAddCash: (self: any, amount: number) -> number,
}

const USAGE = "trailer [broke | reset | status | buy | swap]"

const Vehicle: Api.Module = function(ctx: Api.Context): { Api.Command }
	const vehicles = ctx.Get("VehicleService") :: Vehicles
	const boss = ctx.Get("BossService") :: Boss
	const round = ctx.Get("RoundService") :: Round
	const economy = ctx.Get("EconomyService") :: Economy

	local function state(): string
		return `vehicle {vehicles:Current()}; bought {vehicles:IsBought()}; pending {vehicles:IsPending()}; price ${vehicles:Price()}`
	end

	return {
		{
			Name = "trailer",
			Usage = USAGE,
			Help = "trailer reveal test (day 5 call, focus, money, sign prompt); 'reset' undoes it; 'status', 'buy', 'swap'",
			Run = function(args: { string }, _caller: Player?): string?
				const sub = if args[1] then string.lower(args[1]) else nil
				if sub == nil or sub == "broke" then
					vehicles:DevReset()
					boss:DevResetTrailer()
					if sub == "broke" then
						economy:DevAddCash(-economy:GetCash())
					end
					-- nights played = OfferAfterNight: that night first (Night k is on Day k + 1), then the Prep of the day
					-- after it (Day k + 2; DevSetDay derives the nights played from the day, run flow of 2026-10-12)
					round:DevSetNight(Content.Trailer.OfferAfterNight)
					round:DevSetDay(round:GetDay() + 1)
					boss:DevCall("call_trailer_offer")
					boss:DevAnswer()
					return `after night {Content.Trailer.OfferAfterNight}, call_trailer_offer answered ({boss:DevStatus()}); cash ${economy:GetCash()}; {state()}`
				elseif sub == "reset" then
					vehicles:DevReset()
					boss:DevResetTrailer()
					return `trailer reset ({state()})`
				elseif sub == "status" then
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
