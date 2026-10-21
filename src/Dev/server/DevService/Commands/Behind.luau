--!strict
-- "Behind you" sounds (owner 2026-10-21; AnomalyService/Behind.luau, Content.Nights.Behind). Night phase.
--   behind              tonight's count, the next try, why it is busy, each player's distance and angle to the window
--   behind now          the next one is due now (still waits for a calm moment and a player with the back to the window)
--   behind steps|creak|tap   plays that one on you right now (no calm check; turn your back to the window to hear it)
local Api = require(script.Parent.Parent.Api)

type Anomalies = { DevBehind: (self: any, arg: string?, caller: Player?) -> string }

const Behind: Api.Module = function(ctx: Api.Context): { Api.Command }
	const service = ctx.Get("AnomalyService") :: Anomalies

	return {
		{
			Name = "behind",
			Usage = "behind [now | steps | creak | tap]",
			Help = "sound behind a player cooking with the back to the window: status and why busy; now = as soon as calm; steps/creak/tap = play on you now",
			Run = function(args: { string }, caller: Player?): string?
				return service:DevBehind(args[1], caller)
			end,
		},
	}
end

return Behind
