--!strict
-- Rejoin card command (owner request 2026-10-17, TASK-360 + resume DEC-080/Q-291, Provisional; SessionService). Lobby
-- roles only (status works anywhere).
--   rejoin            shows the top-right "Rejoin your shift" card with a dev offer (Day 3, night) to the caller
--   rejoin resume     the Resume card instead (Day 7, night, 12:40 left, counting down)
--   rejoin hide       hides it again
--   rejoin status     what the session service knows on this server (role, run id, access code known, offers)
-- A dev offer has no run behind it: "Rejoin" answers StudioNoTeleport, "Dismiss" just hides the card. The real flow
-- (drop out of a live run, land in the lobby) only works on a published game: Studio has no MemoryStore nor teleport.
local Api = require(script.Parent.Parent.Api)

const USAGE = "rejoin [resume | hide | status]"

type Role = { IsLobby: (self: Role) -> boolean }
type Session = {
	DevOffer: (self: Session, player: Player, mode: "None" | "Rejoin" | "Resume") -> (),
	RunId: string,
	Code: string,
	Claimed: boolean,
	Ended: boolean,
	Resumed: boolean,
	Offers: { [Player]: any },
}

const Rejoin: Api.Module = function(ctx: Api.Context): { Api.Command }
	return {
		{
			Name = "rejoin",
			Usage = USAGE,
			Help = "rejoin card: show (dev offer, rejoin or resume) / hide it, or print the session state",
			Run = function(args: { string }, caller: Player?): string?
				const session = ctx.Get("SessionService") :: Session
				const role = ctx.Get("RoleService") :: Role
				const sub = if args[1] then string.lower(args[1]) else "show"
				if sub == "status" then
					local offers = 0
					for _ in session.Offers do
						offers += 1
					end
					return `rejoin: lobby {role:IsLobby()}, run "{session.RunId}", code {if session.Code ~= "" then "known" else "unknown"}, `
						.. `claimed {session.Claimed}, resumed {session.Resumed}, ended {session.Ended}, {offers} offer(s)`
				end
				if caller == nil then
					error("run it from the chat (needs a player)", 0)
				end
				if not role:IsLobby() then
					error("lobby only (the card lives in the lobby)", 0)
				end
				if sub == "hide" then
					session:DevOffer(caller, "None")
					return "rejoin: card hidden"
				elseif sub == "resume" then
					session:DevOffer(caller, "Resume")
					return "rejoin: resume card shown (dev offer)"
				elseif sub == "show" then
					session:DevOffer(caller, "Rejoin")
					return "rejoin: card shown (dev offer)"
				end
				error(USAGE, 0)
			end,
		},
	}
end

return Rejoin
