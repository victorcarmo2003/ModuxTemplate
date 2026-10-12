--!strict
-- Trailer (user decision 2026-10-12, Provisional; replaces the 2026-10-11/12 "offer after Night 2" and DEC-037/DEC-047):
-- the Food Trailer is the only vehicle and the party owns it from Day 1. There is no purchase, no FOR SALE sign, no
-- offer call and no vehicle swap any more; the cart left the run. The record only states that, for the code that
-- still wants to ask (Validate, dev status).
local Table = require(script.Parent.Table)

export type Trailer = {
	OwnedFromStart: boolean,
}

const trailer: Trailer = {
	OwnedFromStart = true,
}

return Table.record(trailer)
