--!strict
-- Restaurant supply (board TASK-388; FEAT-050; infinite stock room, owner 2026-10-17). Thin wrappers over SupplyService
-- (Dev* check IsDev and the flags Content.Restaurant.Supply.Enabled + Rules.Enabled).
--   supply [state]                    bays of the stock room and the packages on sale
--   supply take <pkg>                 the caller takes a box from the first bay of <pkg> ("dogs", "buns", a key)
--   supply test                       table tests of Words.luau (pure)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)
local Words = require(ServerScriptService.server.Supply.SupplyService.Words)

const USAGE = "supply [state | take <pkg> | test]"

type Supply = {
	DevState: (self: any) -> string,
	DevTake: (self: any, player: Player, package: string) -> string,
}

local function package(word: string): string
	const key = Words.resolve(word, Content.Packages.List)
	if key == nil then
		error(`unknown package "{word}" (keys: {table.concat(Content.Packages.Keys, ", ")})`, 0)
	end
	return key
end

const Supply: Api.Module = function(ctx: Api.Context): { Api.Command }
	const supply = ctx.Get("SupplyService") :: Supply

	return {
		{
			Name = "supply",
			Usage = USAGE,
			Help = "Restaurant stock room: state, take a box, table tests",
			Run = function(args: { string }, caller: Player?): string?
				const verb = args[1]
				if verb == nil or verb == "state" then
					return supply:DevState()
				elseif verb == "take" then
					if caller == nil then
						error("take needs a player (run it from the chat)", 0)
					end
					if args[2] == nil then
						error(`usage: {USAGE}`, 0)
					end
					return supply:DevTake(caller, package(args[2]))
				elseif verb == "test" then
					const passed, total, failures = Words.selfTest()
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
