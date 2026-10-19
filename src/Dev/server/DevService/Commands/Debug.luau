--!strict
-- Debug readouts (2026-10-18, docs/tech/dev-commands.md) over Parts/Audio, Interact, Movement, Item and Light.
--   debug audio                  the client prints its audio counts and LoadQueue (client Output)
--   debug interact [on|off]      log discarded Interact packets with their reason (was `interactlog`)
--   debug movement [debug on|off]   NPC walking numbers; draw the rounded path of each walk
--   debug drop                   drops the held item on the ground
--   debug light [on|off | hush [s] | end | here]   light groups, switch, Hush, IsLit at your character
-- `light` stays hidden for the showcase panel.
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const Debug: Api.Module = function(ctx: Api.Context): { Api.Command }
	const light = Kit.parts(ctx, "Light").light

	return {
		Kit.group(
			"debug",
			"debug audio | interact [on|off] | movement [debug on|off] | drop | light ...",
			"audio counts, Interact rejections, NPC walking, drop the held item, lights",
			{
				audio = Kit.forward(Kit.parts(ctx, "Audio").audio),
				interact = Kit.forward(Kit.parts(ctx, "Interact").interactlog),
				movement = Kit.forward(Kit.parts(ctx, "Movement").movement),
				drop = Kit.forward(Kit.parts(ctx, "Item").drop),
				light = Kit.forward(light),
			}
		),
		Kit.alias("light", light),
	}
end

return Debug
