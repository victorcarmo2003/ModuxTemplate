--!strict
-- Suspense events (TASK-481; DEC-294; tech/suspense.md): forces one now through SuspenseService, any phase or night.
--   suspense                    a random event on a spot nobody is looking at
--   suspense <spot>             a random event that uses this spot, there (even if someone is looking)
--   suspense <event> [spot]     this event (Content.Suspense key), on a free spot of it or on `spot`
--   suspense list               events and spots
--   suspense status             tonight's agenda, the live event, whether an anomaly holds them
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "suspense [list | status | <spot> | <event> [spot]]"

type Suspense = {
	DevForce: (self: any, event: string?, spot: string?) -> string,
	DevList: (self: any) -> string,
	DevStatus: (self: any) -> string,
}

const Suspense: Api.Module = function(ctx: Api.Context): { Api.Command }
	const service = ctx.Get("SuspenseService") :: Suspense

	return {
		{
			Name = "suspense",
			Usage = USAGE,
			Help = "forces a suspense event now (creature where nobody looks; the glance pulls the camera, -sanity)",
			Run = function(args: { string }, _caller: Player?): string?
				const first = args[1]
				if first == nil then
					return service:DevForce(nil, nil)
				elseif first == "list" then
					return service:DevList()
				elseif first == "status" then
					return service:DevStatus()
				elseif Content.Suspense.Spots.ByKey[first] ~= nil then
					return service:DevForce(nil, first)
				elseif Content.Suspense.ByKey[first] ~= nil then
					return service:DevForce(first, args[2])
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Suspense
