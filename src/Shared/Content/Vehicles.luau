--!strict
-- Vehicles (content-data.md §3.8; DEC-007, DEC-037, DEC-047, DEC-107, DEC-190, DEC-215).
-- The Model lives in the Workspace with tag Vehicle and attribute Vehicle = key (architecture.md §18.1, T36).
-- STUB (TASK-003): rows from content-data.md v4; reviewed in TASK-008.
local Table = require(script.Parent.Table)

export type Vehicle = {
	Key: string,
	Ref: string,
	Name: string,
	HasNight: boolean,
	RailSlots: number,
	BoardSlots: number, -- cart 2 (DEC-190), trailer 3 (DEC-215)
	HasCoffee: boolean,
	HasSwitch: boolean,
	HidePoints: number,
	BuyFromDay: number, -- 0 = not bought (starting vehicle)
	CoveredAfter: string?, -- tarp asset over the parked vehicle after the swap (DEC-199)
}

return Table.new({
	{
		Key = "cart",
		Ref = "AST-026",
		Name = "Corner Cart",
		HasNight = false,
		RailSlots = 6,
		BoardSlots = 2,
		HasCoffee = false,
		HasSwitch = false,
		HidePoints = 0,
		BuyFromDay = 0,
		CoveredAfter = "AST-043",
	},
	{
		Key = "trailer",
		Ref = "UPG-006",
		Name = "Open Late Trailer",
		HasNight = true,
		RailSlots = 8,
		BoardSlots = 3,
		HasCoffee = true,
		HasSwitch = true,
		HidePoints = 4,
		BuyFromDay = 5, -- DEC-037; buy spot = the trailer itself in the lot (DEC-107)
	},
} :: { Vehicle })
