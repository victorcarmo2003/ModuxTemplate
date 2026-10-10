--!strict
-- Run parameters, single record (content-data.md §3.1). Owner: game-designer (+ architect on technical times).
-- STUB (TASK-003): values from content-data.md v4; reviewed in TASK-008.
local Table = require(script.Parent.Table)

export type RunParams = {
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
	EndlessFromDay: number,
	EndlessRequiresNoTrailer: boolean,
	AntiAfkMinCompleted: number,
	AntiAfkAppliesToGradeA: boolean,
}

const params: RunParams = {
	TrailerDay = 5, -- DEC-037
	TrailerBasePrice = 300, -- DEC-047
	PartyPriceMult = { 1.0, 1.5, 1.9, 2.2 },
	PricePartyFrom = "JoinedByDay1End",
	Nights = 10, -- DEC-060
	Chances = 1,
	StartCash = 30, -- DEC-045
	StartStockFull = true, -- DEC-049
	BaseWalkSpeed = 16, -- DEC-069
	StartVehicle = "cart", -- DEC-007
	JoinWindow = 60, -- DEC-098
	ResumeWindow = 900, -- DEC-080
	ResumeWait = 15,
	EndlessFromDay = 6, -- DEC-084
	EndlessRequiresNoTrailer = true,
	AntiAfkMinCompleted = 3, -- DEC-083
	AntiAfkAppliesToGradeA = true,
}

return Table.record(params)
