--!strict
-- Calls of PrepService into the services of other agents (TASK-170): the only file that knows their method shapes.
--   KitchenService (TASK-169, Kitchen/Plate.luau)
--     BeginPlate(player, slot?)            -> Ticket?, reason?     reserves 1 bun and the board slot; Ticket.PreCut = altered bun
--     FinishPlate(player, {Toppings, Quality}) -> Result?, reason? all or nothing; Result.Tool, Result.SausageScore
--     RefundPlate(player)                  -> boolean              the reserved bun goes back
--     TrashPlate(player, {Sausage?, Hand?}) -> {Bun, Sausage, Hand} the bin
--     GrillAct(player, act, slot?)         -> GrillResult?, reason? Place / Flip / Collect
--   CustomerService (TASK-171): TakeOrderFor(player, id?) -> boolean, ServeFor(player, tool?, id) -> SaleResult?,
--     RefuseFor(player, id?) -> boolean
--   ItemService: SetQuality(tool, band), QualityOf(tool)
-- Services come in as `any` so a signature change of another task shows up here and nowhere else. Reasons that cross the wire
-- are always keys of Content.Prep.Reasons (Bridge.Reason).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Outcome = { Ok: boolean, Reason: string, Grade: string, Value: number }

const HOT_DOG = "hot_dog"

const Bridge = {}

-- Only keys of Content.Prep.Reasons cross the wire
function Bridge.Reason(reason: any): string
	if type(reason) == "string" and Content.Prep.Reasons.ByKey[reason] ~= nil then
		return reason
	end
	return "Invalid"
end

local function gradeKey(grade: any): string
	if type(grade) == "string" and table.find(Content.Prep.GradeKeys, grade) ~= nil then
		return grade
	end
	return "None"
end

local function wholeByte(value: any): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, 255)
end

-- Kitchen ---------------------------------------------------------------------------------------------------------------

-- Reserves a bun and the board slot of the seat. (ok, reason, preCut): preCut = the bun is an altered, already sliced one.
function Bridge.Begin(kitchen: any, player: Player, seat: number): (boolean, string, boolean)
	const ticket, reason = kitchen:BeginPlate(player, seat)
	if ticket == nil then
		return false, Bridge.Reason(reason), false
	end
	return true, "None", ticket.PreCut == true
end

export type Made = { Tool: Tool, SausageScore: number? }

-- The atomic transaction of PrepFinish (stock, rail, hotbar, board slot): (made, reason, value). A refusal changed nothing.
-- value = ingredient index for NoStock when the kitchen says which (it does not yet: 0).
function Bridge.Finish(kitchen: any, player: Player, keys: { string }, band: string): (Made?, string, number)
	const result, reason = kitchen:FinishPlate(player, { Toppings = keys, Quality = band })
	if result == nil then
		return nil, Bridge.Reason(reason), 0
	end
	return { Tool = result.Tool, SausageScore = result.SausageScore }, "None", 0
end

-- Leave without a Finish: the reserved bun comes back
function Bridge.Refund(kitchen: any, player: Player)
	kitchen:RefundPlate(player)
end

-- The bin with an open plate: its bun and the front sausage are lost. Without a plate, a hot dog in hand is thrown away
-- through the BIN-C path (Discarded signal of ANM-002). Returns false when there was nothing to throw.
function Bridge.Trash(kitchen: any, items: any, player: Player, plateOpen: boolean): boolean
	if plateOpen then
		const result = kitchen:TrashPlate(player, { Sausage = true })
		return result.Bun or result.Sausage
	end
	if items:Holding(player, HOT_DOG) == nil then
		return false
	end
	const result = kitchen:TrashPlate(player, { Hand = true })
	return result.Hand
end

-- The bin by drag: a sausage of the grill slot / rail position. (ok, reason)
function Bridge.TrashSausage(kitchen: any, player: Player, from: string, slot: number): (boolean, string)
	const ok, reason = kitchen:TrashSausage(player, from, slot)
	if ok == true then
		return true, "None"
	end
	return false, Bridge.Reason(reason)
end

-- slot 0 = the server picks (Place)
function Bridge.Grill(kitchen: any, player: Player, act: string, slot: number): Outcome
	const result, reason = kitchen:GrillAct(player, act, if slot > 0 then slot else nil)
	if result == nil then
		return { Ok = false, Reason = Bridge.Reason(reason), Grade = "None", Value = 0 }
	end
	return { Ok = true, Reason = "None", Grade = gradeKey(result.Band), Value = wholeByte(result.Slot) }
end

-- Customer ---------------------------------------------------------------------------------------------------------------

-- act = Content.Prep.OrderActs value (Take, Serve, Refuse). NoTicket = the customer is not there / not in that state.
function Bridge.Order(customer: any, player: Player, act: string, npc: number): Outcome
	if act == "Take" then
		const ok = customer:TakeOrderFor(player, npc)
		return { Ok = ok == true, Reason = if ok == true then "None" else "NoTicket", Grade = "None", Value = 0 }
	elseif act == "Refuse" then
		const ok = customer:RefuseFor(player, npc)
		return { Ok = ok == true, Reason = if ok == true then "None" else "NoTicket", Grade = "None", Value = 0 }
	end
	const sale = customer:ServeFor(player, nil, npc)
	if sale == nil then
		return { Ok = false, Reason = "NoTicket", Grade = "None", Value = 0 }
	end
	return { Ok = true, Reason = "None", Grade = "None", Value = 0 }
end

return table.freeze(Bridge)
