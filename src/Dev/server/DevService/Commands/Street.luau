--!strict
-- Street (2026-10-18, docs/tech/dev-commands.md) over Parts/Traffic.luau and Parts/Pedestrian.luau.
--   street cars [spawn [TR-n] | clear | hold <reason> on|off | reserve <CW-n> [npc] | release <CW-n> [npc] | hit]
--   street walkers [spawn [path] | clear | adopt]   passers-by (adopt = the next customer is a passer-by)
-- `traffic` stays hidden for the showcase panel.
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const Street: Api.Module = function(ctx: Api.Context): { Api.Command }
	const traffic = Kit.parts(ctx, "Traffic").traffic

	return {
		Kit.group(
			"street",
			"street cars ... | walkers [spawn|clear|adopt]",
			"street cars (spawn, hold, crosswalks, hit test), passers-by",
			{
				cars = Kit.forward(traffic),
				walkers = Kit.forward(Kit.parts(ctx, "Pedestrian").walkers),
			}
		),
		Kit.alias("traffic", traffic),
	}
end

return Street
