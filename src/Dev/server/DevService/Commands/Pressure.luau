--!strict
-- Sanity pressure (DEC-352; AnomalyService/Pressure.luau). Force each tier with `sanity <n>` first.
--   pressure        each Active player's tier and next personal scare, the crew tier, extra anomalies tonight
--   pressure now    the next extra roll and every personal scare become due now (the tier's chance still holds)
local Api = require(script.Parent.Parent.Api)

type Anomalies = { DevPressure: (self: any, nowToo: boolean) -> string }

const Pressure: Api.Module = function(ctx: Api.Context): { Api.Command }
	const service = ctx.Get("AnomalyService") :: Anomalies

	return {
		{
			Name = "pressure",
			Usage = "pressure [now]",
			Help = "sanity tiers: per-player tier, next personal scare, extra anomalies tonight (DEC-352)",
			Run = function(args: { string }, _caller: Player?): string?
				return service:DevPressure(args[1] == "now")
			end,
		},
	}
end

return Pressure
