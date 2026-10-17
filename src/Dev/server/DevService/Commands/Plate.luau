--!strict
-- Restaurant plate slots (board TASK-379; tech/restaurant-flow.md rev. 2 §2.2; FEAT-044). Thin wrappers over PlateService
-- (Dev* check IsDev and Content.Restaurant.Rules.Enabled).
--   plate [list]          every bound slot: ticket (Npc/Line), bun, sausage, toppings, orphan; active count and free
--   plate assign <npc>    puts the ticket(s) of customer <npc> on free plates (as after its "Take Order")
--   plate fill <n>        n dev tickets on the free plates (all taken = tablet_take / take_order get plates_full)
--   plate prep <n>        bun + sausage on PLATE-n (pre-prep: the next ticket prefers it with Rules.PreppedFirst)
--   plate clear           every plate empty, no ticket
--   plate test            table tests of Slots.luau (pure)
local ServerScriptService = game:GetService("ServerScriptService")
local Api = require(script.Parent.Parent.Api)
local Slots = require(ServerScriptService.server.Plate.PlateService.Slots)

const USAGE = "plate [list | assign <npc> | fill <n> | prep <n> | clear | test]"

type Plate = {
	DevList: (self: any) -> string,
	DevAssign: (self: any, npc: number) -> string,
	DevFill: (self: any, count: number) -> string,
	DevPrep: (self: any, index: number) -> string,
	DevClear: (self: any) -> string,
}

local function whole(text: string?, min: number): number
	const value = if text then tonumber(text) else nil
	if value == nil or value ~= math.floor(value) or value < min then
		error(`usage: {USAGE}`, 0)
	end
	return value
end

const Plate: Api.Module = function(ctx: Api.Context): { Api.Command }
	const plates = ctx.Get("PlateService") :: Plate

	return {
		{
			Name = "plate",
			Usage = USAGE,
			Help = "Restaurant plate slots: list, assign a ticket, fill with dev tickets, pre-prep, clear, table tests",
			Run = function(args: { string }, _caller: Player?): string?
				const verb = args[1]
				if verb == nil or verb == "list" then
					return plates:DevList()
				elseif verb == "assign" then
					return plates:DevAssign(whole(args[2], 1))
				elseif verb == "fill" then
					return plates:DevFill(whole(args[2], 1))
				elseif verb == "prep" then
					return plates:DevPrep(whole(args[2], 1))
				elseif verb == "clear" then
					return plates:DevClear()
				elseif verb == "test" then
					const passed, total, failures = Slots.selfTest()
					if #failures > 0 then
						return `{passed}/{total} ok; failed: {table.concat(failures, ", ")}`
					end
					return `{passed}/{total} ok`
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Plate
