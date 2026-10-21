--!strict
-- behind_creak (owner 2026-10-21, Provisional; Content.Nights.Behind): the floor gives right behind the player who
-- cooks with the back to the window, as if someone shifted their weight; a pause, a softer one. Audio only.
local Behind = require(script.Parent.Parent.Behind)
local Context = require(script.Parent.Parent.Context)

const KEY = "behind_creak" -- sound, volume and pitch tuned in Studio (Assets.SFX.Behind["Behind Creak"])
const NEAR = 2.5 -- studs behind the player
const PAUSE = 1.7 -- s before the second, softer creak
const VOLUME = 1 -- x the Studio Sound volume

const BehindCreak: Context.Effect = {
	CanRun = function(_env: Context.Env): boolean
		return Behind.Spot() ~= nil
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const spot = Behind.Spot()
		if spot == nil then
			return
		end
		env.Sound(KEY, Behind.At(spot, NEAR, 0), { Volume = VOLUME, Speed = 1, Vary = 0.05 })
		if not run:Wait(PAUSE + env.Random:NextNumber(0, 0.6)) then
			return
		end
		env.Sound(KEY, Behind.At(spot, NEAR - 0.6, 0), { Volume = VOLUME * 0.55, Speed = 0.9, Vary = 0.05 })
		run:Wait(1)
	end,
}

return BehindCreak
