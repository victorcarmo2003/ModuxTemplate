--!strict
-- `railfeed [n]`: puts n (default: fills it) grilled sausages on the RestRail through KitchenService:DevFeedRail, so the
-- client shows them on the Rail_<N>/Part poses (Kitchen/shared/RailSlot; owner request 2026-10-12). Needs a running shift.
local Api = require(script.Parent.Parent.Api)

type Kitchen = {
	DevFeedRail: (self: any, score: number?) -> boolean,
	RailCount: (self: any) -> number,
}

const Module: Api.Module = function(ctx: Api.Context): { Api.Command }
	const kitchen = ctx.Get("KitchenService") :: Kitchen
	return {
		{
			Name = "railfeed",
			Usage = "railfeed [n]",
			Help = "puts n grilled sausages on the rail (default 8), stops when the rail is full",
			Run = function(args: { string }, _caller: Player?): string?
				const wanted = if args[1] ~= nil then tonumber(args[1]) else 8
				if wanted == nil then
					error("usage: railfeed [n]", 0)
				end
				for _ = 1, wanted do
					if not kitchen:DevFeedRail(nil) then
						break
					end
				end
				return `rail has {kitchen:RailCount()}`
			end,
		},
	}
end

return Module
