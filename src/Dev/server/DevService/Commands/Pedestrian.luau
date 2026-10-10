--!strict
-- Pedestrian commands (board TASK-122; architecture.md §19.17). Thin wrappers over PedestrianService.
--   walkers                   walkers (path, distance/length, speed, next stop), target, held crosswalks
--   walkers spawn [path_key]  a walker now at the start of that WalkPaths row (or a random one of the shift)
--   walkers clear             removes every walker
local Api = require(script.Parent.Parent.Api)

type Pedestrian = {
	Status: (self: any) -> string,
	DevSpawn: (self: any, path: string?) -> string,
	DevClear: (self: any) -> number,
}

const USAGE = "walkers [spawn [path_key] | clear]"

const Pedestrian: Api.Module = function(ctx: Api.Context): { Api.Command }
	const pedestrian = ctx.Get("PedestrianService") :: Pedestrian

	return {
		{
			Name = "walkers",
			Usage = USAGE,
			Help = "passers-by: state, spawn, clear",
			Run = function(args: { string }, _caller: Player?): string?
				const sub = if args[1] then string.lower(args[1]) else nil
				if sub == nil then
					return pedestrian:Status()
				elseif sub == "spawn" then
					return pedestrian:DevSpawn(if args[2] then string.lower(args[2]) else nil)
				elseif sub == "clear" then
					return `{pedestrian:DevClear()} walker(s) removed`
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Pedestrian
