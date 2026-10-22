--!strict
-- Mandatory night event (owner 2026-10-22, Provisional, Q-475; AnomalyService StepNightEvent, Content.Nights.Beats Night*).
-- Night phase.
--   nightevent        the drawn key, its game clock, the state (pending / running / done), the lock and the pool
--   nightevent now    it is due now (still waits NightMaxWait s for an anomaly that is running)
local Api = require(script.Parent.Parent.Api)

type Anomalies = { DevNightEvent: (self: any, nowToo: boolean) -> string }

const NightEvent: Api.Module = function(ctx: Api.Context): { Api.Command }
	const service = ctx.Get("AnomalyService") :: Anomalies

	return {
		{
			Name = "nightevent",
			Usage = "nightevent [now]",
			Help = "mandatory night event: key, time, state, lock and pool; now = due at once (Q-475)",
			Run = function(args: { string }, _caller: Player?): string?
				return service:DevNightEvent(args[1] == "now")
			end,
		},
	}
end

return NightEvent
