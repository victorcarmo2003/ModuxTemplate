--!strict
-- ShowcaseService/Resolve: "do what the player would do" for each anomaly (docs/tech/showcase.md). Dev only, called by
-- ShowcaseService after its IsDev + AdminSettings gate. Every function goes through the real service API of the action
-- (CustomerService:Refuse, LightService:SetSwitch, VehicleService:SetShutter, a teleport) so the anomaly module judges it
-- exactly as in play. Two cases cannot be done for real from a panel and inject the event instead (AnomalyService:
-- DevEmit): ANM-002 discard (a bin trip) and ANM-005 serve (a made hot dog). The helper says so in its reply.
--
-- Correct(ref, env) -> reply line; Wrong(ref, env) -> reply line. Both error(msg, 0) when impossible right now.
-- A ref absent from both tables has no automatic verb (ANM-006 / ANM-007: the right answer is NOT to look).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Env = {
	Player: Player,
	Anomaly: any,
	Customers: any,
	Npcs: any,
	Lights: any,
	Vehicles: any,
	Kitchen: any,
	-- MapPoint id -> true when the player was moved there
	Teleport: (player: Player, point: string) -> boolean,
	Rule: (ref: string) -> { [string]: any }?,
}

const Resolve = {}

local function running(env: Env, ref: string): any
	const occ = env.Anomaly:DevOccurrence(ref)
	if occ == nil then
		error(`{ref} is not running: press Trigger first`, 0)
	end
	return occ
end

-- The customer anomaly's actor and its anchor (the rig). Needs a ticket: the actor must have joined the queue.
local function actor(env: Env, ref: string): (number, Model)
	const occ = running(env, ref)
	const state = occ.State
	const id = if type(state) == "table" then state.Actor else nil
	if type(id) ~= "number" or id == 0 then
		error(`{ref} has no actor yet`, 0)
	end
	const model = env.Npcs:GetModel(id)
	if model == nil then
		error(`{ref}: the actor is gone`, 0)
	end
	if env.Customers:GetTicket(id) == nil then
		error(`{ref}: the customer is still walking to the counter, try again in a few seconds`, 0)
	end
	return id, model
end

local function paramNumber(env: Env, ref: string, name: string, fallback: number): number
	const rule = env.Rule(ref)
	const params: any = if rule ~= nil then rule.Params else nil
	const value: any = if type(params) == "table" then params[name] else nil
	return if type(value) == "number" then value else fallback
end

local function hasWindow(env: Env): boolean
	const key: string = env.Vehicles:Current()
	const vehicle = Content.Vehicles.ByKey[key]
	return vehicle ~= nil and vehicle.HasShutter == true
end

-- Correct ---------------------------------------------------------------------------------------------------------------

const correct: { [string]: (env: Env) -> string } = {}

correct["ANM-001"] = function(env: Env): string
	const _id, model = actor(env, "ANM-001")
	env.Customers:Refuse(env.Player, model)
	return "refused the blank customer"
end

correct["ANM-004"] = function(env: Env): string
	const _id, model = actor(env, "ANM-004")
	env.Customers:Refuse(env.Player, model)
	return "refused the copy"
end

correct["ANM-005"] = function(env: Env): string
	const id, _model = actor(env, "ANM-005")
	-- simulated serve: the real one needs a made hot dog in hand
	env.Anomaly:DevEmit({ Kind = "Customer", Npc = id, Action = "serve", Player = env.Player, Result = "Complete" })
	return "serve event injected (Complete)"
end

local function shutterOrLeave(env: Env, ref: string): string
	running(env, ref)
	if hasWindow(env) and env.Vehicles:SetShutter(true, env.Player) then
		return "service window closed"
	end
	if not env.Teleport(env.Player, "SS") then
		error("no window in this vehicle and no SS point to leave the zone", 0)
	end
	return "no window to close: left the trailer zone for the Mart (SS)"
end

correct["ANM-008"] = function(env: Env): string
	return shutterOrLeave(env, "ANM-008")
end

correct["ANM-009"] = function(env: Env): string
	return shutterOrLeave(env, "ANM-009")
end

correct["ANM-010"] = function(env: Env): string
	running(env, "ANM-010")
	if not env.Teleport(env.Player, "SS") then
		error("MapPoint SS (safe spot) not found", 0)
	end
	return "moved to the Mart sign (safe spot)"
end

-- Wrong -----------------------------------------------------------------------------------------------------------------

const wrong: { [string]: (env: Env) -> string } = {}

local function takeOrder(env: Env, ref: string): string
	const _id, model = actor(env, ref)
	env.Customers:TakeOrder(env.Player, model)
	return "took the order of the wrong customer"
end

wrong["ANM-001"] = function(env: Env): string
	return takeOrder(env, "ANM-001")
end

wrong["ANM-004"] = function(env: Env): string
	return takeOrder(env, "ANM-004")
end

wrong["ANM-005"] = function(env: Env): string
	const _id, model = actor(env, "ANM-005")
	env.Customers:Refuse(env.Player, model)
	return "refused the Raincoat Lady"
end

local function exposed(env: Env, ref: string): string
	running(env, ref)
	env.Vehicles:SetShutter(false, nil)
	if not env.Teleport(env.Player, "TRL") then
		error("MapPoint TRL (trailer pad) not found", 0)
	end
	return "window open and standing at the trailer"
end

wrong["ANM-008"] = function(env: Env): string
	return exposed(env, "ANM-008")
end

wrong["ANM-009"] = function(env: Env): string
	return exposed(env, "ANM-009")
end

wrong["ANM-010"] = function(env: Env): string
	running(env, "ANM-010")
	if not env.Teleport(env.Player, "TRL") then
		error("MapPoint TRL (trailer pad) not found", 0)
	end
	return "stayed at the trailer (not at the safe spot)"
end

function Resolve.HasCorrect(ref: string): boolean
	return correct[ref] ~= nil
end

function Resolve.HasWrong(ref: string): boolean
	return wrong[ref] ~= nil
end

function Resolve.Correct(ref: string, env: Env): string
	const run = correct[ref]
	if run == nil then
		error(`{ref} has no automatic correct verb (the answer is not to look)`, 0)
	end
	return run(env)
end

function Resolve.Wrong(ref: string, env: Env): string
	const run = wrong[ref]
	if run == nil then
		error(`{ref} has no automatic wrong verb`, 0)
	end
	return run(env)
end

return table.freeze(Resolve)
