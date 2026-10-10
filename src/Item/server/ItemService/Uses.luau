--!strict
-- Active items (architecture.md §19.12 T51, §19.8; TASK-066). Plain module, no Modux and no network.
-- The owner of a use registers it in its OnInit (VitalService "coffee", ReviveService "revive_kit" in wave 4):
-- ItemService:RegisterUse(item, { Validate, Run }). Only items with Content.Items[k].Use = true accept a handler.
-- ItemService connects Tool.Activated only on the Tools it created; the client never says what was used.
-- Server checks before Validate: the Tool is still the one in the owner's hand, the player is an active member, no
-- other use of the same player is running (Run may yield: drink animation 1.5 s) and the activations are spaced.
-- Validate returning (false, key) with a key of Content.Notices sends that toast to the player (coffee_full, ...).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Handler = {
	Validate: (player: Player, tool: Tool) -> (boolean, string?),
	Run: (player: Player, tool: Tool) -> (),
}

export type Deps = {
	IsHeld: (player: Player, tool: Tool) -> boolean,
	IsActive: (player: Player) -> boolean,
	Notify: (player: Player, key: string) -> (),
}

export type Uses = {
	Deps: Deps,
	Handlers: { [string]: Handler },
	Busy: { [Player]: boolean },
	LastAt: { [Player]: number },
}

-- Anti-spam between two activations of the same player (technical, not a design number: cooldowns are the owner's).
const MIN_GAP = 0.2

const Uses = {}

function Uses.new(deps: Deps): Uses
	return { Deps = deps, Handlers = {}, Busy = {}, LastAt = {} }
end

-- One handler per item, items marked Use in Content.Items only.
function Uses.register(uses: Uses, item: string, handler: Handler)
	const row = Content.Items.ByKey[item]
	if row == nil or not row.Use then
		error(`[ItemService] RegisterUse: "{item}" is not an active item (Content.Items[k].Use)`, 3)
	end
	if uses.Handlers[item] ~= nil then
		error(`[ItemService] RegisterUse: "{item}" already has a handler`, 3)
	end
	uses.Handlers[item] = handler
end

function Uses.has(uses: Uses, item: string): boolean
	return uses.Handlers[item] ~= nil
end

-- Tool.Activated of a server Tool of `player` holding `item`.
function Uses.activate(uses: Uses, player: Player, tool: Tool, item: string)
	const handler = uses.Handlers[item]
	if handler == nil or uses.Busy[player] then
		return
	end
	const now = os.clock()
	if now - (uses.LastAt[player] or -math.huge) < MIN_GAP then
		return
	end
	uses.LastAt[player] = now
	if not uses.Deps.IsActive(player) or not uses.Deps.IsHeld(player, tool) then
		return
	end

	const ok, allowed, reason = pcall(handler.Validate, player, tool)
	if not ok then
		warn(`[ItemService] use Validate of "{item}" errored: {allowed}`)
		return
	end
	if allowed ~= true then
		if type(reason) == "string" and Content.Notices.ByKey[reason] ~= nil then
			uses.Deps.Notify(player, reason)
		end
		return
	end

	uses.Busy[player] = true
	task.spawn(function()
		const ran, err = pcall(handler.Run, player, tool)
		uses.Busy[player] = nil
		if not ran then
			warn(`[ItemService] use Run of "{item}" errored: {err}`)
		end
	end)
end

function Uses.forget(uses: Uses, player: Player)
	uses.Busy[player] = nil
	uses.LastAt[player] = nil
end

return table.freeze(Uses)
