--!strict
-- Calls of PrepService into the services of other agents (TASK-170): the only file that knows their method shapes.
--   KitchenService (TASK-169, Kitchen/Plate.luau)
--     BeginPlate(player, slot?)            -> Ticket?, reason?     reserves 1 bun and the board slot; Ticket.PreCut = altered bun
--     FinishPlate(player, {Toppings, Quality}) -> Result?, reason? all or nothing; Result.Tool, Result.SausageScore
--     RefundPlate(player)                  -> boolean              the reserved bun goes back
--     TrashPlate(player, {Sausage?, Hand?}) -> {Bun, Sausage, Hand} the bin
--     GrillAct(player, act, slot?)         -> GrillResult?, reason? Place / Flip / Collect
--   CustomerService (TASK-171): TakeOrderFor(player, id?) -> boolean, ServeFor(player, tool?, id) -> SaleResult?
--   ItemService: SetQuality(tool, band), QualityOf(tool)
-- Conveyor (TASK-514; tech/prep-conveyor.md §10.2, §10.3), only while Content.Prep.Rules.Mode = "Conveyor":
--   KitchenService plate api (Kitchen/Plate.luau, reached through KitchenService.Plates: the KitchenService wrappers of
--   TASK-169 do not forward the Belt options)
--     Begin(player, nil, {Belt = true}) -> Ticket?, reason?   the bun of a belt plate (stock or the altered bun); no board slot
--     BeltToppings(player, keys)       -> boolean, reason?    one use of every topping, all or nothing; no Give, no rail
--     TakeRest(player, slot)           -> RestEntry?, reason? the sausage at that rest table position (Rail.PopAt)
--   PlateService (TASK-516): Of, WorkablePlate, Borrow, Commit, Empty, Giveback, Shelve (prep-conveyor.md §10.1)
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

-- Conveyor: kitchen (TASK-514) -------------------------------------------------------------------------------------------

-- The plate api of the kitchen, nil = the kitchen is off (not the Run place, or not started)
local function plateApi(kitchen: any): any
	if kitchen == nil or kitchen.Active ~= true then
		return nil
	end
	return kitchen.Plates
end

-- The bun of a belt plate (PrepStage Cut). (ok, reason, preCut): preCut = the altered bun of the board was adopted (ANM-002)
function Bridge.Cut(kitchen: any, player: Player): (boolean, string, boolean)
	const api = plateApi(kitchen)
	if api == nil then
		return false, "NoStation", false
	end
	const ticket, reason = api.Begin(player, nil, { Belt = true })
	if ticket == nil then
		return false, Bridge.Reason(reason), false
	end
	return true, "None", ticket.PreCut == true
end

export type RestEntry = { Score: number?, Flip: boolean, Altered: boolean }

-- The sausage at rest table position `slot` (PrepStage Dog). (ok, reason, entry)
function Bridge.Dog(kitchen: any, player: Player, slot: number): (boolean, string, RestEntry?)
	const api = plateApi(kitchen)
	if api == nil then
		return false, "NoStation", nil
	end
	-- KitchenService:TakeRest when the kitchen exposes it (TASK-515), else the plate api of Plate.luau (same Rail.PopAt)
	local entry: any, reason: any = nil, nil
	if type(kitchen.TakeRest) == "function" then
		entry, reason = kitchen:TakeRest(player, slot)
	else
		entry, reason = api.TakeRest(player, slot)
	end
	if reason == "Empty" then
		reason = "NoSausage"
	end
	if type(entry) ~= "table" then
		return false, Bridge.Reason(reason or "NoSausage"), nil
	end
	return true, "None", {
		Score = if type(entry.Score) == "number" then entry.Score else nil,
		Flip = entry.Flip == true,
		Altered = entry.Altered == true,
	}
end

-- One use of every topping of the plate (PrepFinish), all or nothing. (ok, reason)
function Bridge.Toppings(kitchen: any, player: Player, keys: { string }): (boolean, string)
	const api = plateApi(kitchen)
	if api == nil then
		return false, "NoSession"
	end
	const ok, reason = api.BeltToppings(player, keys)
	if ok ~= true then
		return false, Bridge.Reason(reason)
	end
	return true, "None"
end

-- Conveyor: plates (PlateService, TASK-516) ------------------------------------------------------------------------------

-- prep-conveyor.md §10.1 PlateState (the fields PrepService reads; a frozen copy)
export type PlateState = {
	Id: number,
	Ticket: number,
	Line: number,
	Bun: boolean,
	Dog: boolean,
	Toppings: { string },
	Grade: string?,
	FlipBonus: boolean,
	Altered: boolean,
	Cut: number?,
	Place: number?,
	StartedAt: number?,
	Form: string,
	Holder: Player?,
}

-- prep-conveyor.md §10.1 PlatePatch
export type PlatePatch = {
	Bun: boolean?,
	Dog: boolean?,
	Toppings: { string }?,
	Grade: string?,
	FlipBonus: boolean?,
	Altered: boolean?,
	Sauce: string?,
	Cut: number?,
	Place: number?,
	StartedAt: number?,
}

const warned: { [string]: boolean } = {}

-- The PlateService method `name`, nil (one warning) while TASK-516 has not landed it
local function plateMethod(plates: any, name: string): any
	const method = if plates ~= nil then plates[name] else nil
	if type(method) ~= "function" then
		if not warned[name] then
			warned[name] = true
			warn(`[PrepService] PlateService:{name} is missing (prep-conveyor.md §10.1, TASK-516): the conveyor refuses plates`)
		end
		return nil
	end
	return method
end

local function state(value: any): PlateState?
	if type(value) ~= "table" or type(value.Id) ~= "number" then
		return nil
	end
	return value :: PlateState
end

function Bridge.PlateOf(plates: any, id: number): PlateState?
	const method = plateMethod(plates, "Of")
	return if method ~= nil then state(method(plates, id)) else nil
end

-- The plate of the hand that goes on the belt (prep-conveyor.md §2.2: equipped, else the oldest ticket), nil = none
function Bridge.Workable(plates: any, player: Player): PlateState?
	const method = plateMethod(plates, "WorkablePlate")
	return if method ~= nil then state(method(plates, player)) else nil
end

-- Hand -> Belt: the Tool leaves the hand (not sold). nil = not this player's plate
function Bridge.Borrow(plates: any, player: Player, id: number): PlateState?
	const method = plateMethod(plates, "Borrow")
	return if method ~= nil then state(method(plates, player, id)) else nil
end

-- A stage written into the plate on the belt
function Bridge.Commit(plates: any, id: number, patch: PlatePatch): boolean
	const method = plateMethod(plates, "Commit")
	return method ~= nil and method(plates, id, patch) == true
end

-- The bin (prep-conveyor.md §6.6): the content is lost, the ticket stays
function Bridge.Empty(plates: any, id: number): boolean
	const method = plateMethod(plates, "Empty")
	return method ~= nil and method(plates, id) == true
end

-- Belt -> Hand (plate, or hot_dog once graded), equipped. nil = it did not reach the hand
function Bridge.Giveback(plates: any, player: Player, id: number): Tool?
	const method = plateMethod(plates, "Giveback")
	if method == nil then
		return nil
	end
	const tool = method(plates, player, id)
	return if typeof(tool) == "Instance" and tool:IsA("Tool") then tool else nil
end

-- Belt / Hand -> a free slot of the central table. false = no slot (cannot happen while tickets <= slots, DT-E10)
function Bridge.Shelve(plates: any, id: number): boolean
	const method = plateMethod(plates, "Shelve")
	return method ~= nil and method(plates, id) ~= nil
end

-- Customer ---------------------------------------------------------------------------------------------------------------

-- act = Content.Prep.OrderActs value (Take, Serve; no Refuse since TASK-354: refusing is closing the window). NoTicket = the customer is not there / not in that state.
-- made = the hot dog this seat just made (Serve judges that one: the plate dropped on the customer, owner request 2026-10-14);
-- nil = CustomerService picks the exact one of the hotbar.
function Bridge.Order(customer: any, player: Player, act: string, npc: number, made: Tool?): Outcome
	if act == "Take" then
		const ok = customer:TakeOrderFor(player, npc)
		return { Ok = ok == true, Reason = if ok == true then "None" else "NoTicket", Grade = "None", Value = 0 }
	end
	const sale = customer:ServeFor(player, made, npc)
	if sale == nil then
		return { Ok = false, Reason = "NoTicket", Grade = "None", Value = 0 }
	end
	return { Ok = true, Reason = "None", Grade = "None", Value = 0 }
end

return table.freeze(Bridge)
