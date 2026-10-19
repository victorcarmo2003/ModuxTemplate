--!strict
-- Local pre-check of a prompt, for presentation only (architecture.md §18.3, network.md §3.4-§3.6 and §4.1).
-- PromptEnabled is the party-wide state written by the server; this adds what only this client knows (the Tool in
-- hand) and what the sets already show (stock, slot, customer state). The server revalidates every Interact.
-- Rule of doubt: when a record is missing, the prompt stays (the server decides); only known facts hide it.
-- Pure: no Modux, Lync or Vide. The controller passes the lookups in.
-- Wave 3 (TASK-131, DEC-221, architecture.md §19.14 v4.2): VehicleController plugs a probe over the `Shutter`
-- attribute of the current vehicle (SetShutterProbe). With the service window closed "Take Order" and "Serve"
-- show no prompt (the server gate `Shutter` refuses them anyway). Without a probe nothing changes.
-- World kitchen (kitchen-world.md §1-§3; TASK-570): PlateController plugs a probe (SetPlateProbe) over the local hands:
--   plate_take         only with no plate in the hands (one plate per hand, Provisional)
--   plate_add_bun      only with a plate equipped that has no bun yet (Requires.Held = plate)
--   plate_add_sausage  only with a plate equipped that has no sausage yet
--   pickup_serve       only with a hot dog equipped; one with a ticket only while its customer waits at the pickup (AtPickup
--                      false = no prompt, nil = not known: the server decides)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

-- Wave this build binds (content-data.md §6.8): actions with Content.Actions[a].Wave above it never show (TASK-078).
const BINDING_WAVE = Content.RunParams.BindingWave

export type Held = {
	Item: string,
	Toppings: { [string]: boolean },
}

export type StockRecord = { Amount: number, Capacity: number, Blocked: boolean }
export type SlotRecord = { State: string }
export type CustomerRecord = { State: string }
export type VitalRecord = { State: string }

export type Context = {
	Phase: string,
	IsNight: boolean,
	SelfId: number, -- UserId of the local player
	Held: Held?,
	Stock: (ingredient: string) -> StockRecord?,
	Slot: (stationId: number, slot: number) -> SlotRecord?,
	Customer: (npcId: number) -> CustomerRecord?,
	Vital: (userId: number) -> VitalRecord?, -- set Vitals (network.md §13.1)
	MemberHeld: (userId: number) -> Held?, -- Tool equipped by a crew mate (others' backpacks do not replicate)
}

-- What the rules read from the anchor (Prompt keeps these fresh from attributes).
export type Target = {
	Action: string,
	Ingredient: string?, -- anchor's Ingredient, else its Station's
	StationId: number?,
	Slot: number?,
	NpcId: number?,
	MemberId: number?, -- UserId of the character the anchor sits on (Prompt_Give, architecture.md §19.8)
}

-- Read side of the `Shutter` attribute (network.md §13.6), given by VehicleController.
export type ShutterProbe = {
	IsClosed: () -> boolean, -- service window of the vehicle in use is closed
	IsInside: (() -> boolean)?, -- local character inside the trailer (LZ-1, the volume VehicleService:IsInside reads)
}

-- The plate / hot dog Tool the local player has equipped (attributes of shared/Plate/PlateTool). AtPickup: its ticket customer
-- is Waiting in the pickup line; nil = not known (no ticket, no Customers record): the server decides.
export type HeldPlate = { Item: string, Ticket: number, Bun: boolean, Sausage: boolean, AtPickup: boolean? }
export type PlateProbe = {
	-- plates + hot dogs carried (equipped and in the backpack); nil = not known
	Hands: (() -> number)?,
	-- equipped plate / hot dog; nil = none of them equipped
	Equipped: (() -> HeldPlate?)?,
}

const ASSEMBLED_ITEM = "hot_dog"
const PLATE_ITEM = "plate"
const PICKUP_ACTION = "pickup_serve"

-- Counter actions the closed window stops (architecture.md §19.14 gate `Shutter`).
const COUNTER_ACTIONS: { [string]: boolean } = { take_order = true, serve = true }

-- Pill text of `shutter_toggle` by state (ui-text.md §2; Provisional).
const SHUTTER_TEXT_OPEN = "Close Window" -- window open: the button closes it
const SHUTTER_TEXT_CLOSED = "Open Window"

-- Package item key -> ingredient it restocks.
const packageIngredient: { [string]: string } = {}
for _, package in Content.Packages.List do
	packageIngredient[package.Item] = package.Ingredient
end

local shutterProbe: ShutterProbe? = nil
local plateProbe: PlateProbe? = nil

const Rules = {}

function Rules.SetShutterProbe(probe: ShutterProbe?)
	shutterProbe = probe
end

function Rules.SetPlateProbe(probe: PlateProbe?)
	plateProbe = probe
end

-- The plate rules above; a missing fact keeps the prompt (the server decides).
local function plateAllows(action: string, probe: PlateProbe): boolean
	if action == "plate_take" then
		const hands = if probe.Hands then probe.Hands() else nil
		return hands == nil or hands < 1
	end
	const equipped = if probe.Equipped then probe.Equipped() else nil
	if action == "plate_add_bun" or action == "plate_add_sausage" then
		if equipped == nil or equipped.Item ~= PLATE_ITEM then
			return false
		end
		return if action == "plate_add_bun" then not equipped.Bun else not equipped.Sausage
	elseif action == PICKUP_ACTION then
		if equipped == nil or equipped.Item ~= ASSEMBLED_ITEM then
			return false
		end
		return equipped.Ticket == 0 or equipped.AtPickup ~= false
	end
	return true
end

-- Text of the `shutter_toggle` pill for the `Shutter` attribute of its vehicle (true = closed).
function Rules.ShutterText(closed: boolean): string
	return if closed then SHUTTER_TEXT_CLOSED else SHUTTER_TEXT_OPEN
end

-- Requires.Held is an Items key ("hot_dog") or an ItemRules category ("Package").
function Rules.Holds(held: Held?, required: string): boolean
	if held == nil then
		return false
	elseif held.Item == required then
		return true
	end
	const item = Content.Items.ByKey[held.Item]
	return item ~= nil and item.Category == required
end

-- "ketchup,cheese" -> set
function Rules.ParseToppings(value: string?): { [string]: boolean }
	const out: { [string]: boolean } = {}
	if value then
		for _, key in string.split(value, ",") do
			if key ~= "" then
				out[key] = true
			end
		end
	end
	return out
end

-- Gate of architecture.md §19.7 ("only Active interacts"): no prompt at all while the local player is Down,
-- Reviving, Spectator or Away. No Vitals record (lobby, before the first replication) = allowed; the server decides.
function Rules.CanInteract(context: Context): boolean
	const me = context.Vital(context.SelfId)
	return me == nil or me.State == "Active"
end

function Rules.Allows(target: Target, context: Context): boolean
	const action = Content.Actions.ByKey[target.Action]
	if action == nil or action.Wave > BINDING_WAVE then
		return false
	end

	-- Anchors on the local character (its own Prompt_Give) are never a target (architecture.md §19.8).
	const memberId = target.MemberId
	if memberId and memberId == context.SelfId then
		return false
	end

	const probe = plateProbe
	if probe ~= nil and not plateAllows(target.Action, probe) then
		return false
	end

	if action.Night == "DayOnly" and context.IsNight then
		return false
	elseif action.Night == "NightOnly" and not context.IsNight then
		return false
	end

	-- ANM-020: the breaker sits on the outer wall; from inside the trailer the prompt would reach through it.
	if target.Action == "breaker_reset" and shutterProbe and shutterProbe.IsInside and shutterProbe.IsInside() then
		return false
	end
	-- Security cameras (TASK-473): no "inside the trailer" rule any more. The CCTV moved to the pantry south wall, outside
	-- LZ-1 (kitchen only), so that rule hid it everywhere; the line-of-sight check (PromptController:InSight) now keeps it
	-- from showing through the wall from the hiding spot behind it.

	-- Service window closed (DEC-221): no counter prompt; the queue waits.
	if COUNTER_ACTIONS[target.Action] and shutterProbe and shutterProbe.IsClosed() then
		return false
	end

	const requires = action.Requires
	const phases = requires.Phase
	if phases and not table.find(phases, context.Phase) then
		return false
	end

	const held = context.Held
	if requires.Held and not Rules.Holds(held, requires.Held) then
		return false
	end

	const ingredient = target.Ingredient
	if requires.NotHasTopping and held and ingredient and held.Toppings[ingredient] then
		return false
	end

	-- DEC-071: no "Add X" once the hot dog has MaxToppings.
	if target.Action == "topping_add" and held then
		local count = 0
		for _ in held.Toppings do
			count += 1
		end
		if count >= Content.OrderRules.MaxToppings then
			return false
		end
	end

	-- Restock needs the package of this station's ingredient (content-data.md §3.18).
	if target.Action == "restock" and held and ingredient then
		const restocks = packageIngredient[held.Item]
		if restocks ~= ingredient then
			return false
		end
	end

	-- network.md §3.4 (L-02): "Add X" hides with Amount = 0 or Blocked; "Restock" hides with Amount = Capacity or
	-- Blocked, never with Amount = 0 (an empty bowl is exactly when you restock).
	if ingredient and (target.Action == "topping_add" or target.Action == "restock") then
		const stock = context.Stock(ingredient)
		if stock then
			if stock.Blocked then
				return false
			elseif target.Action == "topping_add" and stock.Amount <= 0 then
				return false
			elseif target.Action == "restock" and stock.Amount >= stock.Capacity then
				return false
			end
		end
	end

	-- network.md §3.5: "Collect" only on a Ready slot.
	if target.Action == "grill_collect" and target.StationId and target.Slot then
		const slot = context.Slot(target.StationId, target.Slot)
		if slot and slot.State ~= "Ready" then
			return false
		end
	end

	-- network.md §3.6: "Take Order" only while Ordering, "Serve" only while Waiting.
	if target.NpcId and (target.Action == "take_order" or target.Action == "serve") then
		const customer = context.Customer(target.NpcId)
		if customer then
			const wanted = if target.Action == "take_order" then "Ordering" else "Waiting"
			if customer.State ~= wanted then
				return false
			end
		end
	end

	-- architecture.md §19.8 (give_coffee): the mate must be Active and not already hold a coffee
	-- (CategoryLimits.Coffee = 1). Only the equipped Tool is visible here; the server checks the backpack.
	if target.Action == "give_coffee" and memberId then
		const mate = context.Vital(memberId)
		if mate and mate.State ~= "Active" then
			return false
		end
		if Rules.Holds(context.MemberHeld(memberId), "Coffee") then
			return false
		end
	end

	return true
end

return table.freeze(Rules)
