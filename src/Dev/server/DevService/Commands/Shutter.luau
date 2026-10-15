--!strict
-- Service window commands (TASK-130; architecture.md §19.14; DEC-221). Thin wrappers over VehicleService: SetShutter
-- keeps the night rule (closing by day is refused) but skips the prompt, range, hold and cooldown (dev only).
--   shutter          state of the window, current vehicle
--   shutter open     opens it (ShutterChanged without a player: not an "action" for N8)
--   shutter close    closes it (night shift only, vehicle with a window)
--   shutter in       IsInside / IsProtected of the caller
local Api = require(script.Parent.Parent.Api)

type Vehicles = {
	Current: (self: any) -> string,
	IsShutterClosed: (self: any) -> boolean,
	IsInside: (self: any, player: Player) -> boolean,
	IsProtected: (self: any, player: Player) -> boolean,
	SetShutter: (self: any, closed: boolean, player: Player?, force: boolean?) -> boolean,
}

const USAGE = "shutter [open | close | in]"

const Shutter: Api.Module = function(ctx: Api.Context): { Api.Command }
	const vehicles = ctx.Get("VehicleService") :: Vehicles

	local function state(): string
		return `window {if vehicles:IsShutterClosed() then "closed" else "open"} ({vehicles:Current()})`
	end

	return {
		{
			Name = "shutter",
			Usage = USAGE,
			Help = "trailer service window: state; 'open'/'close' (close in Prep/Open/Closing/Night; dev open in Prep does not start the shop); 'in' = inside/protected check",
			Run = function(args: { string }, caller: Player?): string?
				const sub = if args[1] then string.lower(args[1]) else nil
				if sub == nil then
					return state()
				elseif sub == "open" then
					vehicles:SetShutter(false, nil)
					return state()
				elseif sub == "close" then
					if not vehicles:SetShutter(true, nil) then
						error(`refused: closes only on a night shift with a window ({state()})`, 0)
					end
					return state()
				elseif sub == "in" then
					if caller == nil then
						error("needs a caller (run from the chat)", 0)
					end
					return `inside {vehicles:IsInside(caller)}; protected {vehicles:IsProtected(caller)}; {state()}`
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Shutter
