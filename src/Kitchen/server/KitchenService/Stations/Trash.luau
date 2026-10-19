--!strict
-- Trash bin BIN-C (FEAT-006 "Lixeira"; architecture.md §18.4, §18.12; content-data.md §3.6, §3.18; TASK-028).
-- Station module of KitchenService (StationApi.Module). "Throw Away" (discard, hold 0.5 s from Content.Actions) on
-- Prompt_Discard destroys the hot dog in hand; its ingredients are lost (a wrong topping can only be fixed here).
-- Wave 3 (FEAT-023, altered item) and the street bin (DEC-200, Q-166) extend what it accepts; wave 1: hot dog only.
-- No record, no snapshot. Discardable is the hand rule, shared with the street bin (KitchenService, T60; Q-166 a
-- Provisional: hot dog only): widening what may be thrown away changes only this function. World kitchen (kitchen-world.md
-- §1; TASK-569): the plate in hand goes too, empty or half made (`plate`); with bun and sausage it already is the hot dog.
-- Owner request 2026-10-19: a box in hand goes too (Items category Package: the stock room's stock_box, a Mart package),
-- its units lost. Same rule for the street bin (KitchenService reads Discardable).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local StationApi = require(script.Parent.Parent.StationApi)

const ACTION = "discard"
const HOT_DOG = "hot_dog"
const PLATE = "plate"
const PACKAGE = "Package" -- Items category of a box

export type TrashModule = StationApi.Module & {
	Discardable: (ctx: StationApi.Context, player: Player) -> Tool?,
}

-- Tool in the player's hand that may be thrown away: the hot dog, the plate or a box (ctx.Held only returns ItemService Tools).
local function heldHotDog(ctx: StationApi.Context, player: Player): Tool?
	const tool = ctx.Held(player)
	const item = if tool ~= nil then tool:GetAttribute("Item") else nil
	const row = if type(item) == "string" then Content.Items.ByKey[item] else nil
	if tool ~= nil and (item == HOT_DOG or item == PLATE or (row ~= nil and row.Category == PACKAGE)) then
		return tool
	end
	return nil
end

const Trash: TrashModule = {
	Discardable = heldHotDog,
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
