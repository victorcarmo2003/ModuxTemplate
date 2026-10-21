--!strict
-- Breaker trips by itself (Q-435; AnomalyService/Trip.luau, Content.Breaker). Night phase only.
--   trip        tonight's trips, the limit and the next one
--   trip now    the next trip is due now (it still waits for a calm moment: no anomaly running, power on, bulb fine)
local Api = require(script.Parent.Parent.Api)

type Anomalies = { DevTrip: (self: any, nowToo: boolean) -> string }

const Trip: Api.Module = function(ctx: Api.Context): { Api.Command }
	const service = ctx.Get("AnomalyService") :: Anomalies

	return {
		{
			Name = "trip",
			Usage = "trip [now]",
			Help = "breaker trips by itself: count tonight, next one; now = trip as soon as calm (Q-435)",
			Run = function(args: { string }, _caller: Player?): string?
				return service:DevTrip(args[1] == "now")
			end,
		},
	}
end

return Trip
