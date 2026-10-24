--!strict
-- Walt's notes (owner request 2026-10-22, Provisional; HintService, Content.Hints). Run place.
--   hint                      what is written, the night, the phase, whether Walt's night call still holds the tip
--   hint write [n]            writes night n's tip now (default: the current night, or the next one): pencil + "NEW!"
--   hint reset                the paper goes blank (every client sees it empty)
--   hint open                 opens the close-up of the paper for you
--   hint scare                opens the paper; the way out plays the arrival scare (on the customer at the counter /
--                             window, else at Q1)
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

type Hints = {
	DevWrite: (self: any, night: number?) -> number,
	DevReset: (self: any) -> (),
	Open: (self: any, player: Player) -> (),
	ArmScare: (self: any, player: Player) -> (),
	DevState: (self: any) -> string,
	Enabled: boolean,
}

const USAGE = "hint [state | write [n] | reset | open | scare]"

const Hint: Api.Module = function(ctx: Api.Context): { Api.Command }
	const service = ctx.Get("HintService") :: Hints

	-- the caller; from the Command Bar, the only player in the server
	local function caller(player: Player?): Player
		if player ~= nil then
			return player
		end
		const players = Players:GetPlayers()
		if #players ~= 1 then
			error("run it from the chat (needs a player; the Command Bar works with one player in the server)", 0)
		end
		return players[1]
	end

	return {
		{
			Name = "hint",
			Usage = USAGE,
			Help = "Walt's notes: state; write night n's tip now; reset the paper; open it; open it and arm the arrival scare",
			Run = function(args: { string }, player: Player?): string?
				if not service.Enabled then
					error("Walt's notes run in the Run place only", 0)
				end
				const sub = if args[1] then string.lower(args[1]) else "state"
				if sub == "state" then
					return service:DevState()
				elseif sub == "write" then
					local night: number? = nil
					if args[2] ~= nil then
						const value = tonumber(args[2])
						if value == nil or value ~= math.floor(value) or value < 0 then
							error("usage: hint write [n]", 0)
						end
						night = value
					end
					return `written up to night {service:DevWrite(night)}. {service:DevState()}`
				elseif sub == "reset" then
					service:DevReset()
					return `paper blank. {service:DevState()}`
				elseif sub == "open" then
					service:Open(caller(player))
					return "paper opened"
				elseif sub == "scare" then
					service:ArmScare(caller(player))
					return "paper opened; leave it (walk / Back) to play the arrival scare"
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Hint
