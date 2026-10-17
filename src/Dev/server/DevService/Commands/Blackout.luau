--!strict
-- Blackout (TASK-444, owner request 2026-10-17): shortcut for `anomaly ANM-020`, the real module through the
-- AnomalyService API (Night phase only). With Content.Restaurant.Rules.Enabled: omen flicker -> "lights off" -> dark +
-- "POWER OUT" caption + violins -> the choir and -35 for whoever is not hidden in the pantry, until the breaker is held.
--   blackout        starts ANM-020 now
--   blackout stop   stops every running ANM-020 (the power comes back)
local Api = require(script.Parent.Parent.Api)

const REF = "ANM-020"
const USAGE = "blackout [stop]"

type Anomalies = {
	DevForce: (self: any, anomaly: string, example: boolean) -> string,
	DevStopKey: (self: any, anomaly: string) -> number,
}

const Blackout: Api.Module = function(ctx: Api.Context): { Api.Command }
	const anomalies = ctx.Get("AnomalyService") :: Anomalies

	return {
		{
			Name = "blackout",
			Usage = USAGE,
			Help = "starts the ANM-020 blackout now (Night phase), or stops it",
			Run = function(args: { string }, _caller: Player?): string?
				const sub = args[1]
				if sub == nil then
					return anomalies:DevForce(REF, false)
				elseif sub == "stop" then
					return `{REF}: {anomalies:DevStopKey(REF)} occurrence(s) stopped`
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Blackout
