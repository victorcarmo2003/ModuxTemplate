--!strict
-- Gear Stand business hours (owner request 2026-10-17; Content.Mart.Hours). Thin wrapper over GearStandService.
--   gear / gear state   open or closed, phase, seconds to the scheduled close
--   gear open           opens now (toast + shutters + SFX); in a selling phase the close is scheduled from now
--   gear close          closes now
local Api = require(script.Parent.Parent.Api)

const USAGE = "gear [open|close|state]"

type GearStand = {
	Force: (self: any, open: boolean) -> (),
	Report: (self: any) -> string,
}

const Gear: Api.Module = function(ctx: Api.Context): { Api.Command }
	const gear = ctx.Get("GearStandService") :: GearStand

	return {
		{
			Name = "gear",
			Usage = USAGE,
			Help = "Gear Stand hours: open / close it now, or show its state",
			Run = function(args: { string }, _caller: Player?): string?
				const verb = args[1]
				if verb == nil or verb == "state" then
					return gear:Report()
				elseif verb == "open" or verb == "close" then
					gear:Force(verb == "open")
					return gear:Report()
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Gear
