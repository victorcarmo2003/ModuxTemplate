--!strict
-- Trailer commands (board TASK-056; FEAT-016). Thin wrappers over VehicleService (dev checks inside).
-- 2026-10-12 (user decision, Provisional): the Food Trailer is the only vehicle, owned from Day 1. The old offer / buy /
-- broke / swap tests are gone with the purchase.
--   trailer          the same as status
--   trailer status   vehicle, service window and the distance of the model to MapPoint TRL
--   trailer reset    window open again (the vehicle never changes)
local Api = require(script.Parent.Parent.Api)

type Vehicles = {
	Current: (self: any) -> string,
	DevStatus: (self: any) -> string,
	DevReset: (self: any) -> (),
}

const USAGE = "trailer [status | reset]"

const Vehicle: Api.Module = function(ctx: Api.Context): { Api.Command }
	const vehicles = ctx.Get("VehicleService") :: Vehicles

	return {
		{
			Name = "trailer",
			Usage = USAGE,
			Help = "the trailer is the only vehicle: 'status' shows the window and the pose, 'reset' opens the window",
			Run = function(args: { string }, _caller: Player?): string?
				const sub = if args[1] then string.lower(args[1]) else "status"
				if sub == "status" then
					return vehicles:DevStatus()
				elseif sub == "reset" then
					vehicles:DevReset()
					return `trailer reset ({vehicles:DevStatus()})`
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Vehicle
