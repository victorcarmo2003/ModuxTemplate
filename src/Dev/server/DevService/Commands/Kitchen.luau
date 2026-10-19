--!strict
-- Kitchen (2026-10-18, docs/tech/dev-commands.md): stock and stations outside the focused prep (that one is `prep`),
-- over Parts/RailFeed.luau, Parts/Gift.luau and Parts/Supply.luau.
--   kitchen rail [n]                    n grilled sausages on the rail (default 8), stops when it is full
--   kitchen gift [<topping> | all]      gift bowls: list, or unlock + close one (or all) so "Open" can be tested
--   kitchen stock [state | take <pkg> | test]   the stock room: state, take a box, table tests
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const Kitchen: Api.Module = function(ctx: Api.Context): { Api.Command }
	return {
		Kit.group(
			"kitchen",
			"kitchen rail [n] | gift [topping|all] | stock [state|take <pkg>|test]",
			"sausages on the rail, gift bowls, stock room boxes",
			{
				rail = Kit.forward(Kit.parts(ctx, "RailFeed").railfeed),
				gift = Kit.forward(Kit.parts(ctx, "Gift").gift),
				stock = Kit.forward(Kit.parts(ctx, "Supply").supply),
			}
		),
	}
end

return Kitchen
