--!strict
-- Refusal toasts of the station modules (FEAT-005 "Recusas do servidor e avisos"; wave-1-report.md D-04; TASK-080).
-- Plain module (no Modux, Lync or atoms), used by Stations/*.luau from their Validate:
--   * only to the player who acted (ctx.Notify to that player, Audience "Player");
--   * the same key at most once every GAP seconds per player (anti-spam: holding a refused action never stacks toasts);
--   * only for a refusal a legitimate player can reach (the game state changed). Forged requests and life-state gates
--     never get here: InteractionService and KitchenService:Evaluate refuse them before the module's Validate.
-- Provisional (TASK-080): the modules notify here instead of returning the key from Validate, because the key needs a
-- Value ({item}) that Validate cannot return (StationApi, TASK-057) and KitchenService:Notify has no throttle. Proposal
-- to the architect: throttle inside RunStateService:Notify for player targets, so every emitter shares it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local StationApi = require(script.Parent.StationApi)

const GAP = 2 -- seconds (FEAT-005 anti-spam, Provisional constant: no Content field yet)

-- os.clock() of the last toast sent, by player and key. Players that left are pruned on the next send.
const sent: { [Player]: { [string]: number } } = {}

local function prune()
	for player in sent do
		if player.Parent == nil then
			sent[player] = nil
		end
	end
end

const Refusal = {}

-- Sends `key` (a Content.Notices key) to `player` unless the same key went out less than GAP seconds ago.
function Refusal.notify(ctx: StationApi.Context, player: Player, key: string, value: number?)
	if Content.Notices.ByKey[key] == nil then
		return
	end
	const now = os.clock()
	local keys = sent[player]
	if keys == nil then
		prune()
		keys = {}
		sent[player] = keys
	end
	const last = keys[key]
	if last ~= nil and now - last < GAP then
		return
	end
	keys[key] = now
	ctx.Notify(player, key, value)
end

-- Notice.Value of an {item} that comes from Content.Ingredients (ValueFrom = "Ingredients").
function Refusal.ingredient(key: string): number?
	return Content.Ingredients.IndexOf[key]
end

return table.freeze(Refusal)
