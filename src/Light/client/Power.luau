--!strict
-- Power state of the party (Power set record 1, network.md §13.2a; owner requests 2026-10-21, Provisional), as Vide
-- sources any client module can read: PowerController is the only writer (from the set callbacks, never inside an
-- effect). Out = the ANM-020 blackout is on (it outlives its occurrence until the breaker); Burnt = the kitchen bulb.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

const out = Vide.source(false)
const burnt = Vide.source(false)

return table.freeze({
	Out = function(): boolean
		return out()
	end,
	Burnt = function(): boolean
		return burnt()
	end,
	-- PowerController only
	Set = function(isOut: boolean, isBurnt: boolean)
		Vide.batch(function()
			out(isOut)
			burnt(isBurnt)
		end)
	end,
})
