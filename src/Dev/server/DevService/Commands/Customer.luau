--!strict
-- Customer pair command (board TASK-146; FEAT-038). Thin wrapper over CustomerService:DevSpawnPair (checks IsDev).
--   customer group                    a pair of the current shift now (weighted draw, chance ignored)
--   customer group <leader>+<partner> that pair (CustomerTypes keys of a Flow.Groups.Pairs row, e.g. student+student)
--   customer pair [a,b c,d]           a pair with KNOWN orders: hot dog 1 = toppings a,b; hot dog 2 = toppings c,d
--                                     (ToppingKeys; default: 1st and 2nd key). Make both and serve: one interaction
--                                     takes both hot dogs when each is exact (FEAT-038).
--   customer sit                      a customer that SITS (Q-209): spawns one now and forces the next "Take Order" to
--                                     sit it at a free table (buy one first: /dev seating buy). Take its order, then
--                                     "Serve Table n" at the table with the hot dog it asked for.
--   customer quality perfect|good|messy|none
--                                     stamps the prep quality (TASK-171) on the hot dog in YOUR hand, to test the tip and
--                                     mood effects without the prep UI: Perfect = $2 tip (+4 s window), Messy = no tip and a
--                                     mood band worse, Good = as before; none = quick mode (no quality)
-- Caps and the queue still apply: the reply is the spawn outcome.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "customer group [leader+partner] | customer pair [a,b c,d] | customer sit | customer quality perfect|good|messy|none"

type SeatingDev = {
	DevForceSit: (self: any) -> (),
	DevList: (self: any, group: string?) -> string,
}

type Items = {
	GetHeld: (self: any, player: Player) -> Tool?,
	ItemOf: (self: any, tool: Tool) -> string?,
	SetQuality: (self: any, tool: Tool, quality: string?) -> boolean,
}

type Customers = {
	DevSpawn: (self: any) -> (string, number?),
	DevSpawnPair: (self: any, leader: string?, partner: string?) -> (string, number?),
}

local function pairList(): string
	const out: { string } = {}
	for _, pair in Content.Flow.Groups.Pairs do
		table.insert(out, `{pair.Leader}+{pair.Partner} ({pair.Shift})`)
	end
	return table.concat(out, ", ")
end

const Customer: Api.Module = function(ctx: Api.Context): { Api.Command }
	const customers = ctx.Get("CustomerService") :: Customers
	const seating = ctx.Get("SeatingService") :: SeatingDev
	const items = ctx.Get("ItemService") :: Items

	return {
		{
			Name = "customer",
			Usage = USAGE,
			Help = "spawns a customer pair now (FEAT-038)",
			Run = function(args: { string }, caller: Player?): string?
				if args[1] == "sit" then
					seating:DevForceSit()
					const outcome, id = customers:DevSpawn()
					return `{outcome}{if id then ` (NpcId {id})` else ""}: take its order and it sits at a free table`
						.. " (needs the Open / Night phase and a bought table: /dev seating buy)"
				end
				if args[1] == "quality" then
					const word = string.lower(args[2] or "")
					const quality = if word == "none" then nil else string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2)
					if word ~= "none" and (Content.Prep.Grades.Labels :: any)[quality] == nil then
						error(`usage: {USAGE}`, 0)
					end
					const tool = if caller then items:GetHeld(caller) else nil
					if tool == nil or items:ItemOf(tool) ~= "hot_dog" then
						error("hold a hot dog first", 0)
					end
					items:SetQuality(tool, quality)
					return `held hot dog quality = {quality or "none (quick mode)"}`
				end
				if args[1] ~= "group" then
					error(`usage: {USAGE}`, 0)
				end
				local leader: string? = nil
				local partner: string? = nil
				if args[2] ~= nil then
					leader, partner = string.match(args[2], "^([%w_]+)%+([%w_]+)$")
					if leader == nil then
						error(`usage: {USAGE} (pairs: {pairList()})`, 0)
					end
				end
				const outcome, id = customers:DevSpawnPair(leader, partner)
				return `{outcome}{if id then ` (leader NpcId {id})` else ""}`
			end,
		},
	}
end

return Customer
