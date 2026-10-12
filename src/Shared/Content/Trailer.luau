--!strict
-- Trailer offer (user request 2026-10-11/12, Provisional; replaces "the trailer is bought on Day 5", DEC-037/DEC-047):
-- the night shift starts in the cart, and the old trailer is offered later because it helps against the anomalies (the
-- service window, the trailer light, the safe spot). One number says when.
--   OfferAfterNight  the trailer goes on sale from the day after this night (nights played >= it). That morning Walt
--                    rings (BossCalls "TrailerOffer"): the camera looks at the FOR SALE sign, his till tops the
--                    party's cash up to the price (the missing part only, once per run) and he sends the rookie to
--                    the sign. The price stays RunParams.TrailerBasePrice x PartyPriceMult (DEC-047, DEC-121).
local Table = require(script.Parent.Table)

export type Trailer = {
	OfferAfterNight: number,
}

const trailer: Trailer = {
	OfferAfterNight = 2, -- user request 2026-10-12: the morning after Night 2
}

return Table.record(trailer)
