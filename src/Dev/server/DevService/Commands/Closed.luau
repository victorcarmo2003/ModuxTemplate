--!strict
-- Shop switch state (owner request 2026-10-12, Provisional): the "Closed" pause of the Open phase, through the
-- RoundService API (no cooldown, no range check: dev only).
--   closed                  state: phase, paused, selling
--   closed on | off         pause / resume the arrival of new customers (Open phase only)
local Api = require(script.Parent.Parent.Api)

const USAGE = "closed [on|off]"

type Round = {
	GetPhase: (self: any) -> string,
	IsPaused: (self: any) -> boolean,
	SetPaused: (self: any, paused: boolean) -> boolean,
}

const Closed: Api.Module = function(ctx: Api.Context): { Api.Command }
	const round = ctx.Get("RoundService") :: Round

	local function status(): string
		return `phase {round:GetPhase()}, shop {if round:IsPaused() then "CLOSED (no new customers)" else "open"}`
	end

	return {
		{
			Name = "closed",
			Usage = USAGE,
			Help = "trailer shop switch: pause / resume new customers during the Open phase",
			Run = function(args: { string }, _caller: Player?): string?
				const sub = args[1]
				if sub == nil then
					return status()
				elseif sub == "on" or sub == "off" then
					if not round:SetPaused(sub == "on") then
						error("only during the Open phase", 0)
					end
					return status()
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Closed
