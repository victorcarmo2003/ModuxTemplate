--!strict
-- Restaurant supply (board TASK-388; FEAT-050). Thin wrappers over SupplyService (Dev* check IsDev and the flags
-- Content.Restaurant.Supply.Enabled + Rules.Enabled).
--   supply [state]                    calls on the way, boxes per bay, hatch spots, outside, packages on sale
--   supply order <pkg> <n> [...]      a call with these boxes (pays Σ prices + Fee; "dogs 2 buns 1"); no pairs = quick order
--   supply arrive                     every call on the way lands now
--   supply take [<pkg>]               the caller takes a box from the first bay of <pkg> (no word = the hatch)
--   supply seed                       the Night 1 start boxes land again
--   supply clear                      every box and call gone
--   supply test                       table tests of Order.luau (pure)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)
local Order = require(ServerScriptService.server.Supply.SupplyService.Order)

const USAGE = "supply [state | order [<pkg> <n> ...] | arrive | take [<pkg>] | seed | clear | test]"

type Supply = {
	DevState: (self: any) -> string,
	DevOrder: (self: any, player: Player?, boxes: Order.Boxes?) -> string,
	DevArrive: (self: any) -> string,
	DevTake: (self: any, player: Player, package: string?) -> string,
	DevSeed: (self: any) -> string,
	DevClear: (self: any) -> string,
}

local function package(word: string): string
	const key = Order.resolve(word, Content.Packages.List)
	if key == nil then
		error(`unknown package "{word}" (keys: {table.concat(Content.Packages.Keys, ", ")})`, 0)
	end
	return key
end

-- "dogs 2 buns 1" -> { pack_sausages = 2, pack_buns = 1 }; nothing after "order" = nil (quick order)
local function boxesOf(args: { string }): Order.Boxes?
	if #args < 2 then
		return nil
	end
	const out: Order.Boxes = {}
	local index = 2
	while index <= #args do
		const key = package(args[index])
		const count = tonumber(args[index + 1])
		if count == nil or count ~= math.floor(count) or count < 1 then
			error(`usage: {USAGE}`, 0)
		end
		out[key] = (out[key] or 0) + count
		index += 2
	end
	return out
end

const Supply: Api.Module = function(ctx: Api.Context): { Api.Command }
	const supply = ctx.Get("SupplyService") :: Supply

	return {
		{
			Name = "supply",
			Usage = USAGE,
			Help = "Restaurant boxes: state, phone order, arrive now, take a box, start boxes, clear, table tests",
			Run = function(args: { string }, caller: Player?): string?
				const verb = args[1]
				if verb == nil or verb == "state" then
					return supply:DevState()
				elseif verb == "order" then
					return supply:DevOrder(caller, boxesOf(args))
				elseif verb == "arrive" then
					return supply:DevArrive()
				elseif verb == "take" then
					if caller == nil then
						error("take needs a player (run it from the chat)", 0)
					end
					return supply:DevTake(caller, if args[2] then package(args[2]) else nil)
				elseif verb == "seed" then
					return supply:DevSeed()
				elseif verb == "clear" then
					return supply:DevClear()
				elseif verb == "test" then
					const passed, total, failures = Order.selfTest()
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

return Supply
