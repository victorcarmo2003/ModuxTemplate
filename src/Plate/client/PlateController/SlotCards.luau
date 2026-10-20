--!strict
-- SlotCards (DEC-311; owner 2026-10-19): the plates of the front counter. PlateService ties each free ticket line to a slot part
-- (PlateIndex + MapId PLATE-n) through its attributes Ticket / TicketLine; here, for every slot:
--   - no Ticket: the plate (every part of its Mark model) is hidden locally (LocalTransparencyModifier 1), no card
--   - a Ticket: the plate shows and a BillboardGui over it carries the PlateOrderCard of that order (#n, the layered hot dog,
--     the customer's patience), so the cook sees which plate is which order and picks one
-- Presents only (the prompt is the server's). Sized in studs (owner 2026-10-20: the px card stayed huge from far away), like
-- TableSign / PadTag: it shrinks with distance like a real sign. The card keeps its px layout and a UIScale fits it to the
-- billboard's AbsoluteSize. MaxDistance 40, never AlwaysOnTop, never Active.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local PlateOrderCard = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PlateOrderCard)

const SLOT_INDEX = "PlateIndex"
const SLOT_TICKET = "Ticket"
const SLOT_LINE = "TicketLine"
const LIFT = 0.6 -- studs over the plate to the card's bottom
const MAX_DISTANCE = 40
const STUDS_PER_PX = 2 / PlateOrderCard.Width -- the card is as wide as the plate (2 studs; slots 2.6 apart, so no overlap)

-- What SlotCards reads from PlateController
export type Source = {
	Number: (npc: number) -> number?, -- reactive
	Order: (npc: number, line: number) -> { string }?, -- reactive
	Drive: (npc: number) -> boolean, -- reactive
	Patience: (npc: number) -> number?, -- reactive (ticks with the clock)
}

const SlotCards = {}

local function isSlot(instance: Instance): boolean
	-- the name first: this runs for every instance added to the Workspace
	if string.sub(instance.Name, 1, 6) ~= "PLATE-" or not instance:IsA("BasePart") then
		return false
	end
	const mapId = instance:GetAttribute("MapId")
	return type(instance:GetAttribute(SLOT_INDEX)) == "number"
		and type(mapId) == "string"
		and string.sub(mapId, 1, 6) == "PLATE-"
end

-- The parts that draw a slot's plate: its Mark model when it has one, else the slot part
local function visualsOf(part: BasePart): { BasePart }
	const model = part:FindFirstAncestorOfClass("Model")
	const root: Instance = if model ~= nil then model else part
	const list: { BasePart } = {}
	if root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(list, descendant)
		end
	end
	return list
end

local function watchSlot(part: BasePart, source: Source, folder: Instance): () -> ()
	const ticket = Vide.source(0)
	const line = Vide.source(1)
	local function read()
		const npc = part:GetAttribute(SLOT_TICKET)
		const index = part:GetAttribute(SLOT_LINE)
		ticket(if type(npc) == "number" then npc else 0)
		line(if type(index) == "number" then index else 1)
		const hidden = if type(npc) == "number" and npc ~= 0 then 0 else 1
		for _, visual in visualsOf(part) do
			visual.LocalTransparencyModifier = hidden
		end
	end
	read()
	const connections = {
		part:GetAttributeChangedSignal(SLOT_TICKET):Connect(read),
		part:GetAttributeChangedSignal(SLOT_LINE):Connect(read),
	}
	const toppings = function(): { string }
		return source.Order(ticket(), line()) or {}
	end
	-- the card hangs on a local attachment LIFT studs over the plate (world up: the slot part is a turned cylinder, so an offset in
	-- its own space would push the card sideways)
	const anchor = Instance.new("Attachment")
	anchor.Name = "PlateCardAnchor"
	anchor.Parent = part
	anchor.WorldPosition = part.Position + Vector3.new(0, LIFT, 0)
	const unmount = Vide.mount(function()
		const scale = Vide.source(1)
		return Vide.create("BillboardGui")({
			Name = `PlateCard_{part.Name}`,
			Adornee = anchor,
			Size = function(): UDim2
				return UDim2.fromScale(
					PlateOrderCard.Width * STUDS_PER_PX,
					PlateOrderCard.Height(#toppings()) * STUDS_PER_PX
				)
			end,
			-- the card's bottom on the anchor
			SizeOffset = Vector2.new(0, 0.5),
			LightInfluence = 0,
			MaxDistance = MAX_DISTANCE,
			AlwaysOnTop = false,
			Active = false,
			ResetOnSpawn = false,
			Enabled = function(): boolean
				return ticket() ~= 0
			end,
			Vide.changed("AbsoluteSize", function(size: Vector2)
				scale(size.X / PlateOrderCard.Width)
			end),
			-- the px card at its design size, scaled to the studs billboard
			Vide.create("Frame")({
				Name = "Fit",
				Size = function(): UDim2
					return UDim2.fromOffset(PlateOrderCard.Width, PlateOrderCard.Height(#toppings()))
				end,
				BackgroundTransparency = 1,
				(Vide.create :: any)("UIScale")({ Scale = scale }),
				PlateOrderCard.Card({
					Number = function(): number?
						return source.Number(ticket())
					end,
					Toppings = toppings,
					Drive = function(): boolean
						return source.Drive(ticket())
					end,
					Patience = function(): number?
						return source.Patience(ticket())
					end,
				}),
			}),
		})
	end, folder)
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		unmount()
		anchor:Destroy()
		for _, visual in visualsOf(part) do
			visual.LocalTransparencyModifier = 0
		end
	end
end

-- Watches every slot of the map, now and later (streaming). Returns the stop.
function SlotCards.Watch(source: Source): () -> ()
	const folder = Instance.new("Folder")
	folder.Name = "PlateSlotCards"
	folder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	const stops: { [Instance]: () -> () } = {}
	local function add(instance: Instance)
		if stops[instance] == nil and isSlot(instance) then
			stops[instance] = watchSlot(instance :: BasePart, source, folder)
		end
	end
	for _, instance in Workspace:GetDescendants() do
		add(instance)
	end
	const added = Workspace.DescendantAdded:Connect(add)
	const removing = Workspace.DescendantRemoving:Connect(function(instance: Instance)
		const stop = stops[instance]
		if stop ~= nil then
			stops[instance] = nil
			stop()
		end
	end)
	return function()
		added:Disconnect()
		removing:Disconnect()
		for _, stop in stops do
			stop()
		end
		table.clear(stops)
		folder:Destroy()
	end
end

return table.freeze(SlotCards)
