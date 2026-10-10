--!strict
-- Vehicles (content-data.md §3.8; upgrades.md UPG-006; DEC-007, DEC-037, DEC-047, DEC-107, DEC-190, DEC-215).
-- The Model lives in the Workspace with tag Vehicle and attribute Vehicle = key (architecture.md §18.1, T36).
-- Trailer price = RunParams.TrailerBasePrice x RunParams.PartyPriceMult (DEC-047, DEC-121); buy spot = the trailer
-- itself in the lot, prompt buy_trailer, outside the bench rotation (DEC-107).
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
	HasShutter: boolean, -- service window with Prompt_Shutter / shutter_toggle (DEC-221)
	BuyFromDay: number, -- 0 = not bought (starting vehicle)
	CoveredAfter: string?, -- tarp asset over the parked vehicle after the swap (DEC-199)
	Reminder: Reminder?, -- "for sale" notices while not bought (FEAT-017)
}

-- Notice trailer_available at the end of Day FirstDay without a purchase; trailer_waiting every Every days after.
export type Reminder = {
	FirstDay: number,
	Every: number,
}

return Table.new({
	{
		Key = "cart",
		Ref = "AST-026",
		Name = "Corner Cart", -- upgrades.md UPG-006 / ui-text.md §3
		HasNight = false, -- day only (DEC-007)
		RailSlots = 6, -- FEAT-006
		BoardSlots = 2, -- DEC-190, DEC-215
		HasCoffee = false, -- coffee maker comes with the trailer (DEC-055, DEC-125)
		HasSwitch = false, -- light switch comes with the trailer (DEC-189)
		HidePoints = 0, -- DEC-176
		HasShutter = false, -- DEC-221
		BuyFromDay = 0, -- starting vehicle (RunParams.StartVehicle, DEC-007)
		CoveredAfter = "AST-043", -- tarp over the cart after the swap (DEC-199)
	},
	{
		Key = "trailer",
		Ref = "UPG-006", -- model AST-027
		Name = "Open Late Trailer", -- upgrades.md UPG-006 / ui-text.md §3
		HasNight = true, -- opens the night shift (DEC-007)
		RailSlots = 8, -- FEAT-006, UPG-006
		BoardSlots = 3, -- DEC-215
		HasCoffee = true, -- UPG-007 Coffee Maker, fixed, not sold (DEC-055, DEC-125)
		HasSwitch = true, -- "Lights" switch (DEC-189)
		HidePoints = 4, -- 4 hide points, hiding is per player (DEC-176)
		HasShutter = true, -- service window opens/closes from the button next to the switch (DEC-221)
		BuyFromDay = 5, -- = RunParams.TrailerDay (DEC-037)
		Reminder = { FirstDay = 5, Every = 3 }, -- FEAT-017
	},
} :: { Vehicle })
