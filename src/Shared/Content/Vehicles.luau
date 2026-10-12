--!strict
-- Vehicles (content-data.md §3.8; upgrades.md UPG-006; DEC-007, DEC-037, DEC-047, DEC-107, DEC-190, DEC-215).
-- The Model lives in the Workspace with tag Vehicle and attribute Vehicle = key (architecture.md §18.1, T36).
-- Trailer price = RunParams.TrailerBasePrice x RunParams.PartyPriceMult (DEC-047, DEC-121); buy spot = the trailer
-- itself in the lot, prompt buy_trailer, outside the bench rotation (DEC-107).
local Table = require(script.Parent.Table)
local Trailer = require(script.Parent.Trailer)

export type Vehicle = {
	Key: string,
	Ref: string,
	Name: string,
	HasNight: boolean,
	RailSlots: number,
	BoardSlots: number, -- cart 2 (DEC-190), trailer 3 (DEC-215)
	HasCoffee: boolean,
	HasSwitch: boolean,
	HasShutter: boolean, -- service window with Prompt_Shutter / shutter_toggle (DEC-221)
	OfferAfterNight: number, -- on sale from the day after this night (Content.Trailer); 0 = not for sale (starting vehicle)
	CoveredAfter: string?, -- tarp asset over the parked vehicle after the swap (DEC-199)
	Reminder: Reminder?, -- "for sale" notices while not bought (FEAT-017)
}

-- Notice trailer_available at the end of the day shift with FirstNight nights played, without a purchase;
-- trailer_waiting every Every nights after.
export type Reminder = {
	FirstNight: number, -- nights played at the end of the day shift that gets the first notice
	Every: number, -- nights between the next ones
}

return Table.new({
	{
		Key = "cart",
		Ref = "AST-026",
		Name = "Corner Cart", -- upgrades.md UPG-006 / ui-text.md §3
		HasNight = true, -- the night shift starts in the cart from Day 2 (user request 2026-10-12, Provisional; was day only, DEC-007)
		RailSlots = 6, -- FEAT-006
		BoardSlots = 2, -- DEC-190, DEC-215
		HasCoffee = false, -- coffee maker comes with the trailer (DEC-055, DEC-125)
		HasSwitch = false, -- light switch comes with the trailer (DEC-189)
		HasShutter = false, -- DEC-221
		OfferAfterNight = 0, -- starting vehicle (RunParams.StartVehicle, DEC-007)
		CoveredAfter = "AST-043", -- tarp over the cart after the swap (DEC-199)
	},
	{
		Key = "trailer",
		Ref = "UPG-006", -- model AST-027
		Name = "Open Late Trailer", -- upgrades.md UPG-006 / ui-text.md §3
		HasNight = true, -- both vehicles work nights now; the trailer is the optional aid (window, lights, coffee; Content.Trailer)
		RailSlots = 8, -- FEAT-006, UPG-006
		BoardSlots = 3, -- DEC-215
		HasCoffee = true, -- UPG-007 Coffee Maker, fixed, not sold (DEC-055, DEC-125)
		HasSwitch = true, -- "Lights" switch (DEC-189)
		HasShutter = true, -- service window opens/closes from the button next to the switch (DEC-221)
		OfferAfterNight = Trailer.OfferAfterNight, -- user request 2026-10-12 (was Day 5, DEC-037)
		Reminder = { FirstNight = Trailer.OfferAfterNight, Every = 3 }, -- FEAT-017, counted in nights now
	},
} :: { Vehicle })
