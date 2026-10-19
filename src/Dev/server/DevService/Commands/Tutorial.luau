--!strict
-- Tutorial (2026-10-18, docs/tech/dev-commands.md) over Parts/Tutorial.luau (TutorialService, client through DevSend).
--   tutorial                 server status + the client's status
--   tutorial reset           reopens the tutorial in this run (memory only), intro skipped, call and customer restart
--   tutorial step <key>      the client jumps to a step ("auto" = back to the live flow)
--   tutorial intro           ends the intro cutscene and its phase now (was `intro skip`)
--   tutorial voice <text> | tutorial | stop   Walt's voice test on the client (was `voice`)
--   tutorial debug           toggles the client's tutorial debug panel (F8; was `tutdebug`)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const Tutorial: Api.Module = function(ctx: Api.Context): { Api.Command }
	const parts = Kit.parts(ctx, "Tutorial")

	return {
		Kit.group(
			"tutorial",
			"tutorial [reset | step <key> | intro | voice <text>|tutorial|stop | debug]",
			"tutorial status, reset, jump to a step, skip the intro, voice test, debug panel",
			{
				intro = Kit.forward(parts.intro, { "skip" }),
				voice = Kit.forward(parts.voice),
				debug = Kit.forward(parts.tutdebug),
			},
			Kit.forward(parts.tutorial)
		),
	}
end

return Tutorial
