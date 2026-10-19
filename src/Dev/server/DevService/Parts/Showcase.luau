--!strict
-- Showcase command (docs/tech/showcase.md). Opens the dev showcase panel on the caller's client; the panel itself is
-- ShowcaseController (F9 toggles it too). ShowcaseService re-checks dev mode and the admin whitelist.
--   showcase    opens the panel (anomalies, scares, mechanics)
local Api = require(script.Parent.Parent.Api)

type Showcase = {
	Open: (self: any, player: Player) -> (boolean, string),
}

const Showcase: Api.Module = function(ctx: Api.Context): { Api.Command }
	const showcase = ctx.Get("ShowcaseService") :: Showcase

	return {
		{
			Name = "showcase",
			Usage = "showcase",
			Help = "opens the dev showcase panel: trigger every anomaly, scare and mechanic (F9 toggles it)",
			Run = function(_args: { string }, caller: Player?): string?
				if caller == nil then
					error("showcase needs a caller (use the chat or the Conch console)", 0)
				end
				const ok, text = showcase:Open(caller)
				if not ok then
					error(text, 0)
				end
				return text
			end,
		},
	}
end

return Showcase
