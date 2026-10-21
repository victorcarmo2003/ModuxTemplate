--!strict
-- "Behind you" sounds (owner 2026-10-21; AnomalyService/Behind.luau, Content.Nights.Behind). Night phase.
--   behind      tonight's count, the next try, calm or busy, who faces away from the window now
--   behind now  the next one is due now (still waits for a calm moment and a player with the back to the window)
local Api = require(script.Parent.Parent.Api)

type Anomalies = { DevBehind: (self: any, nowToo: boolean) -> string }

const Behind: Api.Module = function(ctx: Api.Context): { Api.Command }
	const service = ctx.Get("AnomalyService") :: Anomalies

	return {
		{
			Name = "behind",
			Usage = "behind [now]",
			Help = "sound behind a player cooking with the back to the window: count, next try, who faces away; now = as soon as calm",
			Run = function(args: { string }, _caller: Player?): string?
				return service:DevBehind(args[1] == "now")
			end,
		},
	}
end

return Behind
