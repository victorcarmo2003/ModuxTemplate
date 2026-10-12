--!strict
--[[
	Content.CoffeeCup: numbers and names of the coffee cup on the trailer counter (owner request 2026-10-12;
	CoffeeCupController; PROVISIONAL, no DEC). The cup (Workspace.ManFaceMug, hand-made by the owner) has an inner
	Part (the coffee surface) that rises while the machine brews and sinks when someone takes the coffee.

	Flow (nothing new on the network): KitchenController/Coffee.luau already reads the coffee_machine record
	(Empty | Working | Ready) and mirrors it, client side only, on the station Model as two attributes:
	  Station.CoffeeCupState    "Empty" | "Working" | "Ready"
	  Station.CoffeeCupSeconds  seconds left of the brew when it was written (0 outside Working)
	The cup finds its station by the attribute `CupStation` (= the station MapId, "TRL-COFFEE").
	  Working -> the surface rises from the bottom over the brew time (or Fill.Seconds when FollowBrew is false)
	  Ready   -> full
	  Empty   -> (coffee taken / drunk) the surface sinks and fades over Drain.Seconds
	/dev coffeecup fill|empty|auto sets `CupDev` on the cup (server attribute, replicated) to force a state.

	Attributes on the cup Model (written by tools/assetplace/coffee_cup.luau from what the owner built):
	  CupStation        station MapId the cup follows
	  CupFillSurface    name of the inner Part (the coffee)
	  CupBody           name of the Part the surface is measured from (the cup body)
	  CupFullCFrame     CFrame of the surface relative to the body when FULL (what the owner left in Studio)
	  CupFullY          informational: that same height in studs above the body centre
	  CupEmptyOffset    studs the surface sinks when empty
]]

local CoffeeCup = {
	Tag = "CoffeeCup",

	-- station side (written by KitchenController/Coffee.luau)
	StationKind = "coffee_machine",
	StationStateAttribute = "CoffeeCupState",
	StationSecondsAttribute = "CoffeeCupSeconds",

	-- cup side (Model attributes)
	StationAttribute = "CupStation",
	SurfaceAttribute = "CupFillSurface",
	BodyAttribute = "CupBody",
	FullCFrameAttribute = "CupFullCFrame",
	FullYAttribute = "CupFullY",
	EmptyOffsetAttribute = "CupEmptyOffset",
	DevAttribute = "CupDev", -- "fill" | "empty" | absent = follow the machine

	-- the surface sinks by this many studs when EmptyOffsetAttribute is missing
	DefaultEmptyOffset = 0.3,

	Fill = {
		FollowBrew = true, -- true: the rise lasts the brew time left; false (and Ready / late join): Seconds
		Seconds = 1.0,
		MinSeconds = 0.6, -- a brew that has less left than this still rises over this long
		Easing = "Sine", -- Enum.EasingStyle name
		Direction = "Out", -- Enum.EasingDirection name
	},

	Drain = {
		Seconds = 1.0,
		Easing = "Quad",
		Direction = "In",
	},

	-- never shorter than this fraction of the base time when the surface is already part of the way (re-trigger)
	MinFraction = 0.2,
	EmptyTransparency = 1, -- the surface is invisible when empty
}

return table.freeze(CoffeeCup)
