--!strict
-- Restaurant pickup line commands (board TASK-380, R1-C; tech/restaurant-flow.md rev. 2 §3.1). Thin wrappers over
-- CustomerService (its Dev* check IsDev). Needs Content.Restaurant.Rules.Enabled = true and PU-1 in the map for the
-- pickup mode; "test" runs anywhere.
--   pickup                  state: modes, PU points, size, who stands on each PU-k (#n, order, patience left)
--   pickup test             table tests of CustomerService/Pickup.luau (join / leave / the line moves / full / choose)
--   pickup take             takes the order of the customer on Q1 as you (the TabletService path: TakeOrderFor)
--   pickup serve [npc]      hands over the hot dog in your hand at the pickup (ServeAtPickup; npc = as if served on
--                           that rig)
--   pickup ticket <npc>     stamps the plate Ticket = npc on the hot dog in your hand (PlateService does it in play)
--   pickup pause <npc> on|off   freezes / resumes that customer's patience clock (PausePatience, the tablet talk)
local Api = require(script.Parent.Parent.Api)

const USAGE = "pickup [test | take | serve [npc] | ticket <npc> | pause <npc> on|off]"
const HOT_DOG = "hot_dog"

type Customers = {
	DevPickupState: (self: any) -> string,
	DevPickupTest: (self: any) -> { string },
	TakeOrderFor: (self: any, player: Player, id: number?) -> boolean,
	ServeAtPickup: (self: any, player: Player, target: number?) -> (string?, number?),
	PausePatience: (self: any, id: number, on: boolean) -> boolean,
	Front: (self: any) -> number?,
}

type Items = {
	GetHeld: (self: any, player: Player) -> Tool?,
	ItemOf: (self: any, tool: Tool) -> string?,
}

local function npcId(text: string?): number
	const value = if text then tonumber(text) else nil
	if value == nil or value ~= math.floor(value) or value < 1 then
		error(`usage: {USAGE} (npc = NpcId, see /dev pickup)`, 0)
	end
	return value
end

local function needCaller(caller: Player?): Player
	if caller == nil then
		error("run it from the chat (needs a player)", 0)
	end
	return caller
end

const Pickup: Api.Module = function(ctx: Api.Context): { Api.Command }
	const customers = ctx.Get("CustomerService") :: Customers
	const items = ctx.Get("ItemService") :: Items

	return {
		{
			Name = "pickup",
			Usage = USAGE,
			Help = "Restaurant pickup line: state, table tests, take / serve as the tablet would, ticket, pause",
			Run = function(args: { string }, caller: Player?): string?
				const verb = args[1]
				if verb == nil then
					return customers:DevPickupState()
				elseif verb == "test" then
					const failures = customers:DevPickupTest()
					if #failures == 0 then
						return "Pickup.luau: all table tests passed"
					end
					return `Pickup.luau: {#failures} failed\n{table.concat(failures, "\n")}`
				elseif verb == "take" then
					const player = needCaller(caller)
					const front = customers:Front()
					if front == nil then
						return "nobody on Q1"
					end
					const ok = customers:TakeOrderFor(player, front)
					return `take order npc {front}: {if ok then "taken" else "refused (state, drawer, pickup_full)"}\n{customers:DevPickupState()}`
				elseif verb == "serve" then
					const player = needCaller(caller)
					const target = if args[2] then npcId(args[2]) else nil
					const result, id = customers:ServeAtPickup(player, target)
					if result == nil then
						return "nothing served (pickup mode off, drawer closed, nobody waiting or no hot dog)"
					end
					return `served npc {id}: {result}\n{customers:DevPickupState()}`
				elseif verb == "ticket" then
					const player = needCaller(caller)
					const id = npcId(args[2])
					const tool = items:GetHeld(player)
					if tool == nil or items:ItemOf(tool) ~= HOT_DOG then
						error("hold a hot dog first", 0)
					end
					tool:SetAttribute("Ticket", id)
					return `hot dog in hand: Ticket = {id}`
				elseif verb == "pause" then
					const id = npcId(args[2])
					const mode = args[3]
					if mode ~= "on" and mode ~= "off" then
						error(`usage: {USAGE}`, 0)
					end
					const ok = customers:PausePatience(id, mode == "on")
					return `pause npc {id} {mode}: {if ok then "ok" else "no change (no clock, unknown, already)"}`
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Pickup
