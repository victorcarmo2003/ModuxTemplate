--!strict
-- Service window (owner 2026-10-21; VehicleService, Content.ShopWindow). Shut from the report to the night; it opens by
-- itself ShopWindow.AutoOpenAfter s after the night starts (0 = with it); this forces it now.
--   window              window, phase and whether the shop is paused
--   window open|close   opens / shuts it now (open in a selling phase also opens the shop)
local Api = require(script.Parent.Parent.Api)

type Vehicles = { DevWindow: (self: any, arg: string?) -> string }

const Window: Api.Module = function(ctx: Api.Context): { Api.Command }
	const service = ctx.Get("VehicleService") :: Vehicles

	return {
		{
			Name = "window",
			Usage = "window [open | close | status]",
			Help = "service window: status, or force it open / shut now (the night opens it by itself when it starts)",
			Run = function(args: { string }, _caller: Player?): string?
				return service:DevWindow(args[1])
			end,
		},
	}
end

return Window
