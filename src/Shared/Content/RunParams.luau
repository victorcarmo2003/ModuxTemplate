--!strict
-- Run parameters, single record (content-data.md §3.1). Owner: game-designer (+ architect on technical times).
-- Values reviewed in TASK-008; every number cites its origin.
local Table = require(script.Parent.Table)

export type RunParams = {
	NightsFromDay: number,
	TrailerDay: number,
	TrailerBasePrice: number,
	PartyPriceMult: { number }, -- by party size 1..4 (trailer and Revive Kit; DEC-047, DEC-121, DEC-129)
	PricePartyFrom: "JoinedByDay1End", -- rule (DEC-121); changing it needs a DEC
	Nights: number,
	Chances: number, -- per whole run (DEC-110, DEC-112)
	StartCash: number,
	StartStockFull: boolean,
	BaseWalkSpeed: number,
	StartVehicle: string, -- key of Vehicles
	JoinWindow: number,
	ResumeWindow: number,
	ResumeWait: number,
	EndlessFromDay: number, -- UNUSED since 2026-10-12 (endless days were "no trailer"; nights no longer depend on it)
	EndlessRequiresNoTrailer: boolean, -- UNUSED, same reason
	AntiAfkMinCompleted: number,
	AntiAfkAppliesToGradeA: boolean,
	BindingWave: number, -- which MapIndex Required.Wave<n> PlaceService validates; also gates Actions[a].Wave
}

const params: RunParams = {
	-- Run flow (user request 2026-10-12, PROVISIONAL Q-207): Day 1 is the tutorial day shift only; from this day on
	-- every day shift is followed by a night shift in the cart: D1, D2, N1, D3, N2 ... D11, N10 (night k is played on
	-- day k + NightsFromDay - 1). The trailer is an optional later unlock (Content.Trailer.OfferAfterNight).
	NightsFromDay = 2,
	TrailerDay = 5, -- OBSOLETE (user request 2026-10-12): the offer is Content.Trailer.OfferAfterNight now; nobody reads this
	TrailerBasePrice = 300, -- $300 x party (DEC-047)
	PartyPriceMult = { 1.0, 1.5, 1.9, 2.2 }, -- 1p..4p: $300/$450/$570/$660 (DEC-047); also Revive Kit (DEC-129)
	PricePartyFrom = "JoinedByDay1End", -- party size fixed at the end of Day 1 (DEC-121)
	Nights = 10, -- DEC-060
	Chances = 1, -- per whole run: the 2nd lost night ends the run (DEC-110, DEC-112)
	StartCash = 30, -- boss advance (DEC-045)
	StartStockFull = true, -- run starts with full stock at Cooler level 1 (DEC-049)
	BaseWalkSpeed = 16, -- class without speed effect (DEC-069)
	StartVehicle = "cart", -- DEC-007
	JoinWindow = 60, -- DEC-098
	ResumeWindow = 900, -- 15 min (DEC-080)
	ResumeWait = 15, -- Resume phase (architect, content-data.md §3.1)
	EndlessFromDay = 6, -- UNUSED: endless days are gone with the new flow (Q-207), RunState.Endless stays false
	EndlessRequiresNoTrailer = true, -- UNUSED
	AntiAfkMinCompleted = 3, -- DEC-083
	AntiAfkAppliesToGradeA = true, -- DEC-083 (secretary reading, to confirm)
	BindingWave = 3, -- 1 -> 2 -> 3 per wave (content-data.md §6.8; architecture.md §19.22)
}

return Table.record(params)
