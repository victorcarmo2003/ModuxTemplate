--!strict
-- Discarded Interact log (board TASK-044, R4; tests/wave-1.md §0.4 R4, §3). Listens to InteractionService.Rejected
-- (TASK-011 v1.1) and prints "[Interact] <player> <entityId> <action> -> <reason>" in the server Output.
-- Aggregation: rejections are buffered by (player, entityId, action, reason) and flushed once per WINDOW, one line
-- per distinct key with " xN" when N > 1. A forged burst of 30 packets in one frame prints at most 2 lines
-- (e.g. "state x8" for the processed ones + "rate x22"). Only loaded in dev mode (DevService), on by default.
local Api = require(script.Parent.Parent.Api)

type Connection = { Disconnect: (self: Connection) -> () }

type Interaction = {
	Rejected: {
		Connect: (self: any, callback: (player: Player, id: number, action: string, reason: string) -> ()) -> Connection,
	},
}

type Entry = { Text: string, Count: number }

const PREFIX = "[Interact]"
const WINDOW = 1 -- seconds

const Interact: Api.Module = function(ctx: Api.Context): { Api.Command }
	const interaction = ctx.Get("InteractionService") :: Interaction

	local enabled = true
	local entries: { [string]: Entry } = {}
	local order: { string } = {}
	local scheduled = false

	local function flush()
		scheduled = false
		const keys = order
		const pending = entries
		order = {}
		entries = {}
		if not enabled then
			return
		end
		for _, key in keys do
			const entry = pending[key]
			print(if entry.Count > 1 then `{entry.Text} x{entry.Count}` else entry.Text)
		end
	end

	interaction.Rejected:Connect(function(player: Player, id: number, action: string, reason: string)
		if not enabled then
			return
		end
		-- Name captured now: the player may leave before the flush.
		const text = `{PREFIX} {player.Name} {id} {action} -> {reason}`
		const entry = entries[text]
		if entry ~= nil then
			entry.Count += 1
		else
			entries[text] = { Text = text, Count = 1 }
			table.insert(order, text)
		end
		if not scheduled then
			scheduled = true
			task.delay(WINDOW, flush)
		end
	end)

	return {
		{
			Name = "interactlog",
			Usage = "interactlog [on|off]",
			Help = "log discarded Interact packets with reason (rate, range, target, state, or gate as <gate>:<detail>), aggregated per second",
			Run = function(args: { string }, _caller: Player?): string?
				const arg = if args[1] then string.lower(args[1]) else nil
				if arg == "on" then
					enabled = true
				elseif arg == "off" then
					enabled = false
				elseif arg ~= nil then
					error("usage: interactlog [on|off]", 0)
				end
				return `interact log {if enabled then "on" else "off"}`
			end,
		},
	}
end

return Interact
