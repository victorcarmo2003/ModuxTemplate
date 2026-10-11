--!strict
-- Customer pair command (board TASK-146; FEAT-038). Thin wrapper over CustomerService:DevSpawnPair (checks IsDev).
--   customer group                    a pair of the current shift now (weighted draw, chance ignored)
--   customer group <leader>+<partner> that pair (CustomerTypes keys of a Flow.Groups.Pairs row, e.g. student+student)
-- Caps and the queue still apply: the reply is the spawn outcome.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "customer group [leader+partner]"

type Customers = {
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

	return {
		{
			Name = "customer",
			Usage = USAGE,
			Help = "spawns a customer pair now (FEAT-038)",
			Run = function(args: { string }, _caller: Player?): string?
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
