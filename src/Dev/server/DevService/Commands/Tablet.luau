--!strict
-- Restaurant order tablet (board TASK-381; tech/restaurant-flow.md rev. 2 §2.4; FEAT-043). Thin wrappers over TabletService
-- (Dev* check IsDev and Content.Restaurant.Rules.Enabled).
--   tablet [state]          TAB-1: state, customer, user, time left, order on the record, head of the queue, room
--   tablet talk             starts the talk as you with the customer of Q1 (every rule but the range: Ordering, room on
--                           the plates and in the pickup line, tablet not busy)
--   tablet finish           ends the running talk now (TakeOrderFor as at EndsAt)
--   tablet time <k> [k2]    TalkTime for k toppings (k2 = the partner's hot dog of a pair)
local Api = require(script.Parent.Parent.Api)

const USAGE = "tablet [state | talk | finish | time <k> [k2]]"

type Tablet = {
	DevState: (self: any, index: number?) -> string,
	DevTalk: (self: any, player: Player, index: number?) -> string,
	DevFinish: (self: any, index: number?) -> string,
	TalkTime: (self: any, k1: number, k2: number?) -> number,
}

local function count(text: string?): number?
	if text == nil then
		return nil
	end
	const value = tonumber(text)
	if value == nil or value ~= math.floor(value) or value < 0 then
		error(`usage: {USAGE}`, 0)
	end
	return value
end

const Tablet: Api.Module = function(ctx: Api.Context): { Api.Command }
	const tablets = ctx.Get("TabletService") :: Tablet

	return {
		{
			Name = "tablet",
			Usage = USAGE,
			Help = "Restaurant tablet: state, start / finish the talk at TAB-1, talk time for k toppings",
			Run = function(args: { string }, caller: Player?): string?
				const verb = args[1]
				if verb == nil or verb == "state" then
					return tablets:DevState()
				elseif verb == "talk" then
					if caller == nil then
						error("tablet talk needs a player (run it from the chat / console, not the Command Bar)", 0)
					end
					return tablets:DevTalk(caller)
				elseif verb == "finish" then
					return tablets:DevFinish()
				elseif verb == "time" then
					const k1 = count(args[2])
					if k1 == nil then
						error(`usage: {USAGE}`, 0)
					end
					return string.format("%.2f s", tablets:TalkTime(k1, count(args[3])))
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Tablet
