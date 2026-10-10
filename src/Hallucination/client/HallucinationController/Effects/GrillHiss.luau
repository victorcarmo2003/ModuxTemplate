--!strict
-- grill_hiss (< 60; script.md §8, sound-list.md §5.12): the sausage sizzle (the real SFX-021) on an empty grill.
-- Audio only (AST-085). Only on a grill near the player with every slot Empty; a sausage put down cancels it.
local Context = require(script.Parent.Parent.Context)

const STATION_TAG = "Station"
const KIND = "grill"
const KEY = "grill_sizzle"
const MAX_SLOTS = 8 -- above any GrillSlots (Upgrades.grill: 2/3/4)
const RANGE = 30 -- studs
const TIME = 2.6 -- s (sound-list: 2-3 s)
const STEP = 0.2
const LIFT = Vector3.new(0, 0.3, 0) -- own Loop anchor: never the one KitchenController uses for a real sizzle

local function empty(env: Context.Env, station: Instance): boolean
	const id = station:GetAttribute("StationId")
	if typeof(id) ~= "number" then
		return false
	end
	for slot = 1, MAX_SLOTS do
		const state = env.SlotState(id * 100 + slot)
		if state ~= nil and state ~= "Empty" then
			return false
		end
	end
	return true
end

local function nearestGrill(): (Instance?, Vector3?)
	const root = Context.Root()
	if root == nil then
		return nil, nil
	end
	local best: Instance? = nil
	local bestAt: Vector3? = nil
	local bestDistance = RANGE
	for _, station in Context.Tagged(STATION_TAG) do
		if station:GetAttribute("StationKind") == KIND then
			const at = Context.PositionOf(station)
			if at then
				const distance = (at - root.Position).Magnitude
				if distance <= bestDistance then
					best, bestAt, bestDistance = station, at, distance
				end
			end
		end
	end
	return best, bestAt
end

const GrillHiss: Context.Effect = {
	CanRun = function(env: Context.Env): boolean
		const station = nearestGrill()
		return station ~= nil and empty(env, station)
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const station, at = nearestGrill()
		if station == nil or at == nil then
			return
		end
		const point = at + LIFT
		run:Cleanup(function()
			env.Loop(KEY, point, false)
		end)
		env.Loop(KEY, point, true)
		const started = os.clock()
		while os.clock() - started < TIME do
			if not empty(env, station) or not run:Wait(STEP) then
				return
			end
		end
	end,
}

return GrillHiss
