--!strict
-- Vehicles (content-data.md §3.8; upgrades.md UPG-006; DEC-007, DEC-037, DEC-047, DEC-107, DEC-190, DEC-215).
-- The Model lives in the Workspace with tag Vehicle and attribute Vehicle = key (architecture.md §18.1, T36).
-- 2026-10-12 (user decision, Provisional): ONE vehicle. The Food Trailer is the only vehicle from Day 1; the cart left
-- the run (its models sit in ServerStorage), and so did the trailer purchase, the FOR SALE sign and the vehicle swap.
-- The table keeps the Key / Levels-per-vehicle shape (Upgrades, Stations, Required binding) with a single row.
local Table = require(script.Parent.Table)

export type Vehicle = {
	Key: string,
	Ref: string,
	Name: string,
	HasNight: boolean,
	RailSlots: number,
	BoardSlots: number, -- trailer 3 (DEC-215)
	HasCoffee: boolean,
	HasSwitch: boolean,
	HasShutter: boolean, -- service window with Prompt_Shutter / shutter_toggle (DEC-221)
}

return Table.new({
	{
		Key = "trailer",
		Ref = "UPG-006", -- model AST-027
		Name = "Open Late Trailer", -- upgrades.md UPG-006 / ui-text.md §3
		HasNight = true, -- the night shift is worked in the trailer too
		RailSlots = 8, -- FEAT-006, UPG-006
		BoardSlots = 3, -- DEC-215
		HasCoffee = true, -- UPG-007 Coffee Maker, fixed, not sold (DEC-055, DEC-125)
		HasSwitch = true, -- "Lights" switch (DEC-189)
		HasShutter = true, -- service window opens/closes from the button next to the switch (DEC-221)
	},
} :: { Vehicle })
