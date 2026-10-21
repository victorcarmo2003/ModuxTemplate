--!strict
-- behind_tap (owner 2026-10-21, Provisional; Content.Nights.Behind): light taps on the window glass behind the player
-- who cooks with the back to it - three, a pause, one more. Nobody at the window when they turn. Audio only
-- (`door_knock` played higher and softer, a knuckle on glass; a dedicated glass tap has no key yet).
local Behind = require(script.Parent.Parent.Behind)
local Context = require(script.Parent.Parent.Context)

const KEY = "door_knock"
const TAPS = { 0, 0.32, 0.64, 2.2 } -- s from the start
const BEFORE_WINDOW = 1.5 -- studs on the player's side of the window spot (the glass, not the street)
const LIFT = 1.5 -- studs above the root: the height of the glass
const VOLUME = 0.4
const SPEED = 1.7

const BehindTap: Context.Effect = {
	CanRun = function(_env: Context.Env): boolean
		return Behind.Spot() ~= nil
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const spot = Behind.Spot()
		if spot == nil then
			return
		end
		const at = Behind.At(spot, math.max(spot.Distance - BEFORE_WINDOW, 1), LIFT)
		local elapsed = 0
		for _, time in TAPS do
			if time > elapsed and not run:Wait(time - elapsed) then
				return
			end
			elapsed = time
			env.Sound(KEY, at, { Volume = VOLUME, Speed = SPEED, Vary = 0.06 })
		end
		run:Wait(0.8)
	end,
}

return BehindTap
