--!strict
-- Family D scares (TASK-274; DEC-254): the same call the night scheduler makes, HallucinationService:Scare.
--   scare               one random family D scare on the caller's client (what the client can show right now)
--   scare <key> [key]   only among these keys (Content.Hallucinations rows with FamilyD)
--   scare all           one random scare on every player's client
--   scare list          the family D keys
-- To force one effect regardless of where the player stands, use the showcase (HallucinationController:DevPlay).
local Api = require(script.Parent.Parent.Api)

type Hallucination = {
	Scare: (self: any, target: (Player | { Player })?, keys: { string }?) -> number,
	Keys: (self: any) -> { string },
	IsScare: (self: any, key: string) -> boolean,
}

const Scare: Api.Module = function(ctx: Api.Context): { Api.Command }
	const service = ctx.Get("HallucinationService") :: Hallucination

	return {
		{
			Name = "scare",
			Usage = "scare [list | all | <key> ...]",
			Help = "family D scare (no verb, no damage) on your client: random, or among the given keys",
			Run = function(args: { string }, caller: Player?): string?
				const first = args[1]
				if first == "list" then
					return table.concat(service:Keys(), ", ")
				end
				if first == "all" then
					return `scare sent to {service:Scare(nil, nil)} player(s)`
				end
				if caller == nil then
					return "scare needs a player (or 'scare all')"
				end
				for _, key in args do
					if not service:IsScare(key) then
						return `'{key}' is not a family D scare (scare list)`
					end
				end
				const sent = service:Scare(caller, if #args > 0 then args else nil)
				return if sent > 0 then "scare sent (the client picks what it can show now)" else "not sent"
			end,
		},
	}
end

return Scare
