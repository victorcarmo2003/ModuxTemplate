--!strict
-- Player life (2026-10-18, docs/tech/dev-commands.md): one verb per need over Parts/Vital.luau, Parts/Revive.luau and
-- Parts/Tester.luau (VitalService dev hooks). Player = Name/DisplayName (exact, then unique prefix); without it the
-- caller, from the Command Bar the only player.
--   sanity [<n>|hint|dark on|off|auto] [player]   status, set (0 = falls), Night 1 coffee hint, force the dark
--   god [on|off]                     nobody faints (sanity stops at 1; VitalService:DevGod); no argument toggles
--   god me [on|off] [player]         infinite sanity for one player (never drops; was `infsanity`)
--   revive [player|all]              a Down or Spectator player (or every one) back Active
--   revive auto [on|off] [player]    stands up 2 s after any faint (was `autorevive`)
--   faint [spectator] [player]       falls now as Down (or Spectator)
-- Old names kept hidden for their callers: down / spectate (showcase), autorevive (Admin), infsanity (DevTool).
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

type Vital = {
	DevGod: (self: any, on: boolean) -> (),
	IsDevGod: (self: any) -> boolean,
}

const Life: Api.Module = function(ctx: Api.Context): { Api.Command }
	const vital = ctx.Get("VitalService") :: Vital
	const parts = Kit.parts(ctx, "Vital")
	const revive = Kit.parts(ctx, "Revive").revive
	const tester = Kit.parts(ctx, "Tester")
	const sanity = parts.sanity

	local function god(args: { string }, _caller: Player?): string?
		const word = if args[1] then string.lower(args[1]) else nil
		if word ~= nil and word ~= "on" and word ~= "off" then
			error("usage: god [on|off] | god me [on|off] [player]", 0)
		end
		const on = if word == "on" then true elseif word == "off" then false else not vital:IsDevGod()
		vital:DevGod(on)
		return `god {if on then "ON (nobody faints, sanity stops at 1)" else "OFF"}`
	end

	local function faint(args: { string }, caller: Player?): string?
		if args[1] ~= nil and string.lower(args[1]) == "spectator" then
			return Kit.forward(parts.spectate)({ table.unpack(args, 2) }, caller)
		end
		return Kit.forward(parts.down)(args, caller)
	end

	const commands: { Api.Command } = {
		Kit.group(
			"god",
			"god [on|off] | god me [on|off] [player]",
			"nobody faints (party); god me = infinite sanity for one player",
			{ me = Kit.forward(tester.infsanity) },
			god
		),
		Kit.group(
			"revive",
			"revive [player|all] | revive auto [on|off] [player]",
			"brings a Down or Spectator player (or all) back; auto = stand up 2 s after any faint",
			{ auto = Kit.forward(parts.autorevive) },
			Kit.forward(revive)
		),
		{
			Name = "faint",
			Usage = "faint [spectator] [player]",
			Help = "the player falls now as Down (sanity 0), or as Spectator",
			Run = faint,
		},
		Kit.alias("down", parts.down),
		Kit.alias("spectate", parts.spectate),
		Kit.alias("autorevive", parts.autorevive),
		Kit.alias("infsanity", tester.infsanity),
	}
	if sanity ~= nil then
		table.insert(commands, sanity)
	end
	return commands
end

return Life
