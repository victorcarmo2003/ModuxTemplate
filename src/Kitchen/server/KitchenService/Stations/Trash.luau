--!strict
-- Trash bin BIN-C (FEAT-006 "Lixeira"; architecture.md §18.4, §18.12; content-data.md §3.6, §3.18; TASK-028).
-- Station module of KitchenService (StationApi.Module). "Throw Away" (discard, hold 0.5 s from Content.Actions) on
-- Prompt_Discard destroys the hot dog in hand; its ingredients are lost (a wrong topping can only be fixed here).
-- Wave 3 (FEAT-023, altered item) and the street bin (DEC-200, Q-166) extend what it accepts; wave 1: hot dog only.
-- No record, no snapshot.
local StationApi = require(script.Parent.Parent.StationApi)

const ACTION = "discard"
const HOT_DOG = "hot_dog"

-- Hot dog in the player's hand (ctx.Held only returns Tools created by ItemService).
local function heldHotDog(ctx: StationApi.Context, player: Player): Tool?
	const tool = ctx.Held(player)
	if tool ~= nil and tool:GetAttribute("Item") == HOT_DOG then
		return tool
	end
	return nil
end

const Trash: StationApi.Module = {
	Kinds = { "trash" },
	Actions = {
		[ACTION] = {
			Validate = function(ctx: StationApi.Context, _station: StationApi.Station, player: Player, _anchor: Instance)
				return heldHotDog(ctx, player) ~= nil, nil
			end,
			Run = function(ctx: StationApi.Context, _station: StationApi.Station, player: Player, _anchor: Instance)
				const tool = heldHotDog(ctx, player)
				if tool ~= nil then
					ctx.Consume(player, tool)
				end
			end,
		},
	},
	Bind = function(_ctx: StationApi.Context, _station: StationApi.Station) end,
	Capture = function(_ctx: StationApi.Context, _station: StationApi.Station): any
		return nil
	end,
	Restore = function(_ctx: StationApi.Context, _station: StationApi.Station, _data: any) end,
}

return Trash
