--!strict
-- Customers (2026-10-18, docs/tech/dev-commands.md) over Parts/Customer.luau, Parts/Spawns.luau and Parts/Seating.luau.
--   customer pair [a,b c,d] | group [leader+partner] | sit | quality perfect|good|messy|none   spawns / forces (FEAT-038)
--   customer on | off       resumes / pauses ORDINARY customers (anomaly customers still come; was `arrivals`)
--   customer spawns         spawn attempts this shift (spawned / skipped by full queue / by NPC cap)
--   customer tables [buy | sit]   the tables: list, the next one for free, force the next sit
-- `arrivals` stays hidden for the Admin console.
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const Customer: Api.Module = function(ctx: Api.Context): { Api.Command }
	const parts = Kit.parts(ctx, "Customer")
	const arrivals = parts.arrivals

	return {
		Kit.group(
			"customer",
			"customer pair|group|sit|quality ... | on | off | spawns | tables [buy|sit]",
			"spawn a pair / group, force sit or quality, pause ordinary arrivals, spawn stats, tables",
			{
				on = Kit.forward(arrivals, { "on" }),
				off = Kit.forward(arrivals, { "off" }),
				spawns = Kit.forward(Kit.parts(ctx, "Spawns").spawns),
				tables = Kit.forward(Kit.parts(ctx, "Seating").seating),
			},
			Kit.forward(parts.customer)
		),
		Kit.alias("arrivals", arrivals),
	}
end

return Customer
