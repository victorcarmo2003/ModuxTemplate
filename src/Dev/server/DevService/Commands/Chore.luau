--!strict
-- Night chores (Q-436; ChoreService, Content.Chores). Night phase only for the draw; a key starts it at once.
--   chore                         tonight's count, the next draw and the state of each chore
--   chore <key>                   start it now (grill_fire, back_door, rats, camera_static)
--   chore now                     draw one now
--   chore end [<key>|all]         end one (or all)
local Api = require(script.Parent.Parent.Api)

type Chores = { DevRun: (self: any, args: { string }) -> string }

const Chore: Api.Module = function(ctx: Api.Context): { Api.Command }
	const service = ctx.Get("ChoreService") :: Chores

	return {
		{
			Name = "chore",
			Usage = "chore [<key>|now|end [<key>|all]]",
			Help = "night chores: grill fire, back door, rats, camera static (Q-436)",
			Run = function(args: { string }, _caller: Player?): string?
				return service:DevRun(args)
			end,
		},
	}
end

return Chore
