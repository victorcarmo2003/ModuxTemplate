--!strict
-- Anomaly commands (TASK-106; architecture.md §19.13). Go through the AnomalyService API, so the Anomalies set, the
-- AnomalyCue packet, events and Stop behave as in play. Forcing skips the agenda and Scheduler.Admit (dev only).
--   anomaly                        modules, rules, tension and the occurrences running
--   anomaly agenda                 tonight's agenda (clock, Ref, scripted/done/no module)
--   anomaly <key|ANM-###|n>        starts that anomaly now with its module (Night phase only)
--   anomaly <key|ANM-###|n> example starts it with Anomalies/_Example (tests the core without the real module)
--   anomaly stop                   stops every occurrence ("Restore") and empties the set
local Api = require(script.Parent.Parent.Api)

const USAGE = "anomaly [agenda|stop|<key|ANM-###|n> [example]]"

type Anomalies = {
	DevForce: (self: any, anomaly: string, example: boolean) -> string,
	DevStop: (self: any) -> string,
	DevStatus: (self: any) -> string,
	DevAgenda: (self: any) -> string,
}

const Anomaly: Api.Module = function(ctx: Api.Context): { Api.Command }
	const anomalies = ctx.Get("AnomalyService") :: Anomalies

	return {
		{
			Name = "anomaly",
			Usage = USAGE,
			Help = "forces an anomaly now (or the example module on it), shows the agenda and what is running, stops all",
			Run = function(args: { string }, _caller: Player?): string?
				const sub = args[1]
				if sub == nil then
					return anomalies:DevStatus()
				elseif sub == "agenda" then
					return anomalies:DevAgenda()
				elseif sub == "stop" then
					return anomalies:DevStop()
				end
				const mode = args[2]
				if mode ~= nil and mode ~= "example" then
					error(`usage: {USAGE}`, 0)
				end
				return anomalies:DevForce(sub, mode == "example")
			end,
		},
	}
end

return Anomaly
