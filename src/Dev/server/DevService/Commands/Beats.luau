--!strict
-- Beat director (owner 2026-10-21; AnomalyService/Director.luau, Content.Nights.Beats). Night phase.
--   beats       last beat, what counts as active now (anomalies, chores, a trip) and the next regular anomaly
local Api = require(script.Parent.Parent.Api)

type Anomalies = { DevBeats: (self: any) -> string }

const Beats: Api.Module = function(ctx: Api.Context): { Api.Command }
	const service = ctx.Get("AnomalyService") :: Anomalies

	return {
		{
			Name = "beats",
			Usage = "beats",
			Help = "beat director: last beat, active beats, gap and the next anomaly (one budget for anomalies, chores, trips, suspense)",
			Run = function(_args: { string }, _caller: Player?): string?
				return service:DevBeats()
			end,
		},
	}
end

return Beats
