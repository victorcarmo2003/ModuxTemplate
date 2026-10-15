--!strict
-- street_watcher (< 40, family D; anomalies-v2-proposal.md §3 D; DEC-254): a customer stands still far away on the
-- street, turned to the player, staring. It never walks, never comes closer, never asks anything. Local rig
-- (Actors.Customer, Night pack), no sound.
--   1. spawns on a MapPoint MIN..MAX studs away, OUTSIDE the view (the player finds it by turning);
--   2. it keeps facing the camera while it is there;
--   3. once seen (SEEN_TIME in view) and then out of view for AWAY_TIME it is gone; never seen within LIFETIME:
--      removed quietly.
local Workspace = game:GetService("Workspace")
local Actors = require(script.Parent.Parent.Actors)
local Context = require(script.Parent.Parent.Context)

const QUERY: Context.SpotQuery = {
	MinDistance = 35,
	MaxDistance = 95,
	MinAngle = 55, -- outside the view cone at spawn
	MaxAngle = 180,
	Height = 4.5,
}
const SEEN_CONE = 25 -- degrees: "looking at it"
const SEEN_TIME = 0.8 -- s in view to count as seen
const AWAY_TIME = 0.6 -- s out of view after being seen
const LIFETIME = 35 -- s
const STEP = 0.1

const StreetWatcher: Context.Effect = {
	CanRun = function(_env: Context.Env): boolean
		return #Context.FarSpots(QUERY) > 0
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const spots = Context.FarSpots(QUERY)
		if #spots == 0 then
			return
		end
		const spot = spots[env.Random:NextInteger(1, #spots)]
		const root = spot.Position + Actors.HIP
		const model = Actors.Customer(env.Random, "Hallucination_Watcher", Context.FacingCamera(root))
		if model == nil then
			return
		end
		run:Cleanup(function()
			model:Destroy()
		end)
		model.Parent = Workspace

		const started = os.clock()
		local seenFor = 0
		local seen = false
		local awayFor = 0
		local last = os.clock()
		while os.clock() - started < LIFETIME do
			if not run:Wait(STEP) or model.Parent == nil then
				return
			end
			const now = os.clock()
			const dt = now - last
			last = now
			model:PivotTo(Context.FacingCamera(root))
			const inView = Context.Sees(Actors.HeadOf(model), SEEN_CONE, QUERY.MaxDistance + 10, { model })
			if not seen then
				seenFor = if inView then seenFor + dt else 0
				seen = seenFor >= SEEN_TIME
			else
				awayFor = if inView then 0 else awayFor + dt
				if awayFor >= AWAY_TIME then
					return -- gone when the player looks back
				end
			end
		end
	end,
}

return StreetWatcher
