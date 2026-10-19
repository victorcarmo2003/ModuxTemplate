--!strict
-- Grill of the cooking focus (kitchen-focus.md §1 #3; DEC-310 pre-prep). The camera is over the bars; no plate here.
--   tap an empty place          -> Cook Place (a sausage from the box onto that place)
--   tap a cooking sausage       -> Cook Flip (once; the score is the server's: how close to the middle of the flip window)
--   tap a ready sausage         -> Cook Collect (it goes to the rest rail with its flip score; "Add Sausage" there puts it
--                                  on a plate)
-- A marker over each sausage says what it wants: Mustard = flip now (inside Restaurant.Grill.FlipFrom..FlipTo), Green = ready.
-- The sausages themselves are the world's (KitchenController draws them from the Stations set). The focus stays until the
-- player leaves (Back, walking): the grill is a batch station.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Kit = require(script.Parent.Kit)
local Session = require(script.Parent.Session)

const WINDOW = Content.Restaurant.Grill
const PICK = 0.4 -- studs from a place a tap still picks it
const RAIL_KIND = "rail" -- StationKind of the rest rail
const FLIP_COLOR = Color3.fromHex("#F6C12B")
const READY_COLOR = Color3.fromHex("#5FA36A")
const HOVER_COLOR = Color3.fromHex("#FFFFFF")
const SLOT_FACTOR = 100

type Place = { Slot: number, At: Vector3 }

const Grill = {}
-- StationId of the rest rail of the world (nil when none bound)
local function railId(): number?
	for _, station in CollectionService:GetTagged("Station") do
		const id = station:GetAttribute("StationId")
		if station:GetAttribute("StationKind") == RAIL_KIND and type(id) == "number" then
			return id
		end
	end
	return nil
end

function Grill.Start(session: Session.Session): Session.Handler
	const folder = session.Folder
	const target = session.Target
	const up = Vector3.yAxis
	const rail = railId()

	-- the places: Attachments with a Slot inside the grill (the level's one wins over an unlevelled one, as the server does)
	const places: { [number]: Place } = {}
	for _, child in target:GetDescendants() do
		if child:IsA("Attachment") then
			const slot = child:GetAttribute("Slot")
			if type(slot) == "number" and slot >= 1 and slot <= 8 then
				places[slot] = { Slot = slot, At = child.WorldPosition }
			end
		end
	end
	local height = session.Top.Y
	for _, place in places do
		height = place.At.Y
		break
	end

	const marks = Instance.new("Folder")
	marks.Name = "Marks"
	marks.Parent = folder
	const hover = Kit.Ball(folder, Vector3.zero, HOVER_COLOR, 0.3, 1)
	local shown = ""

	local function stationId(): number?
		const value = target:GetAttribute("StationId")
		return if type(value) == "number" then value else nil
	end

	local function record(slot: number): any?
		const id = stationId()
		return if id then session.Records()[id * SLOT_FACTOR + slot] else nil
	end

	-- sausages waiting on the rest rail
	local function railCount(): number?
		if rail == nil then
			return nil
		end
		const value = session.Records()[rail * SLOT_FACTOR]
		return if value ~= nil then value.Count or 0 else 0
	end

	local function nearest(position: Vector2): number?
		const world = Kit.OnPlane(position, Vector3.new(0, height, 0), up)
		if world == nil then
			return nil
		end
		local best: number? = nil
		local bestDistance = PICK
		for slot, place in places do
			if record(slot) == nil then
				continue -- not an active place at this grill level
			end
			const flat = Vector3.new(place.At.X - world.X, 0, place.At.Z - world.Z).Magnitude
			if flat < bestDistance then
				best = slot
				bestDistance = flat
			end
		end
		return best
	end

	local function hint()
		const count = railCount()
		const tail = if count ~= nil then ` On the rest rail: {count}` else ""
		session.Hint(`Tap a spot to grill, tap again to flip, tap a ready one to send it to the rest rail.{tail}`)
	end

	return {
		Pointer = function(kind: string, position: Vector2)
			if kind == "Down" then
				const slot = nearest(position)
				if slot == nil then
					return
				end
				const state = record(slot)
				if state == nil or state.State == "Empty" then
					session.Send({ Act = "Place", Slot = slot, Score = 0 })
				elseif state.State == "Working" and (state.Flip or 0) == 0 then
					session.Send({ Act = "Flip", Slot = slot, Score = 0 })
				elseif state.State == "Ready" then
					session.Send({ Act = "Collect", Slot = slot, Score = 0 })
				end
				return
			end
			-- the place under the pointer glows
			const near = if kind == "Move" then nearest(position) else nil
			const place = if near then places[near] else nil
			hover.Transparency = if place then 0.55 else 1
			if place ~= nil then
				hover.Position = place.At + up * 0.12
			end
		end,
		Step = function(_dt: number)
			const signature = tostring(railCount())
			if signature ~= shown then
				shown = signature
				hint()
			end
			-- what each sausage wants
			marks:ClearAllChildren()
			const now = Workspace:GetServerTimeNow()
			for slot, place in places do
				const state = record(slot)
				if state == nil then
					continue
				end
				if state.State == "Ready" then
					Kit.Ball(marks, place.At + up * 0.45, READY_COLOR, 0.16, 0)
				elseif state.State == "Working" and (state.Flip or 0) == 0 and state.Duration > 0 then
					const fraction = (now - state.StartedAt) / state.Duration
					if fraction >= WINDOW.FlipFrom and fraction <= WINDOW.FlipTo then
						Kit.Ball(marks, place.At + up * 0.45, FLIP_COLOR, 0.2, 0)
					end
				end
			end
		end,
		Stop = function() end,
	}
end

return table.freeze(Grill)
