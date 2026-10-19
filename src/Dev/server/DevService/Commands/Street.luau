--!strict
-- Street (2026-10-18, docs/tech/dev-commands.md) over Parts/Traffic.luau, Parts/Pedestrian.luau and Parts/Thief.luau.
--   street cars [spawn [TR-n] | clear | hold <reason> on|off | reserve <CW-n> [npc] | release <CW-n> [npc] | hit]
--   street walkers [spawn [path] | clear | adopt]   passers-by (adopt = the next customer is a passer-by)
--   street thief [now [L1|L2|L3] | sim <day> [n]]   Quick Quentin: state, spawn now, daily chance check
-- `traffic` / `thief` stay hidden for the showcase panel.
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const Street: Api.Module = function(ctx: Api.Context): { Api.Command }
	const traffic = Kit.parts(ctx, "Traffic").traffic
	const thief = Kit.parts(ctx, "Thief").thief

	return {
		Kit.group(
			"street",
			"street cars ... | walkers [spawn|clear|adopt] | thief [now [L1..L3]|sim <day>]",
			"street cars (spawn, hold, crosswalks, hit test), passers-by, the thief",
			{
				cars = Kit.forward(traffic),
				walkers = Kit.forward(Kit.parts(ctx, "Pedestrian").walkers),
				thief = Kit.forward(thief),
			}
		),
		Kit.alias("traffic", traffic),
		Kit.alias("thief", thief),
	}
end

return Street
