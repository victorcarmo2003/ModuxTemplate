--!strict
-- The plate in hand (ITM-025; docs/tech/kitchen-world.md §2; TASK-569). ReplicatedStorage.shared.Plate.PlateTool. Pure: the
-- Tool attribute names and the few reads both sides share. Writers: PlateService (Id, Ticket, Line, Since at Take Plate /
-- the hand-over) and KitchenService (Bun, Sausage, Flipped, Altered through Context.FillPlate).
--   plate    Item "plate": Bun / Sausage say what is on it (bools). With both on it KitchenService turns it into the
--   hot_dog  Tool (same hand): Id, Ticket, Line, Since and Flipped are carried over, Altered is ItemService's own attribute,
--            and the condiments go on it as Toppings (ItemService:AddTopping)
-- Ticket = NpcId of the order (0 / nil = none yet: it takes the oldest ticket at the hand-over), Line = which hot dog of a
-- pair (1 leader, 2 partner), Since = server time the ticket landed (oldest first).

const PlateTool = {}

PlateTool.Plate = "plate"
PlateTool.HotDog = "hot_dog"

PlateTool.Attr = table.freeze({
	Id = "PlateId",
	Ticket = "Ticket",
	Line = "TicketLine",
	Since = "Since",
	Bun = "Bun",
	Sausage = "Sausage",
	Flipped = "Flipped",
	Altered = "Altered",
	Item = "Item",
	Toppings = "Toppings",
})

-- What the hot dog keeps of the plate it was (the rest is ItemService's: Toppings, Altered, Quality)
PlateTool.Carried = table.freeze({ "PlateId", "Ticket", "TicketLine", "Since", "Flipped" })

local function number(tool: Instance, name: string): number
	const value = tool:GetAttribute(name)
	return if type(value) == "number" and value == value then value else 0
end

-- PlateId of a plate / hot_dog Tool of the world kitchen, 0 = none (a hot dog from elsewhere)
function PlateTool.Id(tool: Instance): number
	return number(tool, PlateTool.Attr.Id)
end

-- NpcId of the ticket, 0 = none
function PlateTool.Ticket(tool: Instance): number
	return number(tool, PlateTool.Attr.Ticket)
end

function PlateTool.Line(tool: Instance): number
	return number(tool, PlateTool.Attr.Line)
end

function PlateTool.Since(tool: Instance): number
	return number(tool, PlateTool.Attr.Since)
end

-- The Tool is a plate (empty or half made) or the hot dog a plate became
function PlateTool.IsPlate(tool: Instance): boolean
	const item = tool:GetAttribute(PlateTool.Attr.Item)
	return item == PlateTool.Plate or (item == PlateTool.HotDog and PlateTool.Id(tool) > 0)
end

-- What is on it: (bun, sausage). A hot dog has both.
function PlateTool.Parts(tool: Instance): (boolean, boolean)
	if tool:GetAttribute(PlateTool.Attr.Item) == PlateTool.HotDog then
		return true, true
	end
	return tool:GetAttribute(PlateTool.Attr.Bun) == true, tool:GetAttribute(PlateTool.Attr.Sausage) == true
end

-- Toppings on it, in the order added ("" = none)
function PlateTool.Toppings(tool: Instance): { string }
	const out: { string } = {}
	const raw = tool:GetAttribute(PlateTool.Attr.Toppings)
	if type(raw) ~= "string" then
		return out
	end
	for key in string.gmatch(raw, "[^,]+") do
		table.insert(out, key)
	end
	return out
end

return table.freeze(PlateTool)
