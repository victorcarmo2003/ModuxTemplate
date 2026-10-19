--!strict
-- Item commands (user request 2026-10-11, Provisional; FEAT-036). Thin wrapper over ItemService:DropHeld.
--   drop      the item in the caller's hand falls as a car hit would drop it (toss, pick-up prompt, 90 s with blink,
--             returns to the owner on a phase change); no knock-down. For the full hit use `traffic hit`.
local Api = require(script.Parent.Parent.Api)

type Items = {
	DropHeld: (self: any, player: Player, reason: string) -> boolean,
}

const Item: Api.Module = function(ctx: Api.Context): { Api.Command }
	const items = ctx.Get("ItemService") :: Items

	return {
		{
			Name = "drop",
			Usage = "drop",
			Help = "drops the held item on the ground (recoverable with Take); `traffic hit` also knocks you down",
			Run = function(_args: { string }, caller: Player?): string?
				if caller == nil then
					error("drop needs a caller (use the chat)", 0)
				end
				return if items:DropHeld(caller, "Dev") then "dropped" else "nothing in hand"
			end,
		},
	}
end

return Item
