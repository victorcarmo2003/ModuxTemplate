--!strict
-- Grill of the cooking focus (kitchen-focus.md §1 #3). The camera is over the bars; the plate in hand sits beside the grill.
--   tap an empty place          -> Cook Place (a sausage from the box onto that place)
--   tap a cooking sausage       -> Cook Flip (once; the score is the server's: how close to the middle of the flip window)
--   drag a ready sausage        -> onto the bun of the plate: Cook Dog, scored by Gestures.Place -> Grade.Score sausage_place
-- A marker over each sausage says what it wants: Mustard = flip now (inside Restaurant.Grill.FlipFrom..FlipTo), Green = ready.
-- The sausages themselves are the world's (KitchenController draws them from the Stations set). The step ends when the plate
-- becomes the hot dog.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local Gestures = require(script.Parent.Gestures)
local Kit = require(script.Parent.Kit)
local Session = require(script.Parent.Session)

const BUILD = Content.Prep.Build
const WINDOW = Content.Restaurant.Grill
const PICK = 0.4 -- studs from a place a tap still picks it
const SLACK = 0.4 -- bun-space margin a drop still lands in
const FLIP_COLOR = Color3.fromHex("#F6C12B")
const READY_COLOR = Color3.fromHex("#5FA36A")
const HOVER_COLOR = Color3.fromHex("#FFFFFF")
const SLOT_FACTOR = 100

type Place = { Slot: number, At: Vector3 }

const Grill = {}

function Grill.Start(session: Session.Session): Session.Handler
	const folder = session.Folder
	const target = session.Target
	const up = Vector3.yAxis
	const right = session.Right

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

	-- the plate beside the grill (right side of the screen)
	const extent = (math.abs(session.Size.X * right.X) + math.abs(session.Size.Z * right.Z)) / 2
	const plateBase = CFrame.fromMatrix(Vector3.new(session.Top.X, height, session.Top.Z) + right * (extent + 0.9), right, up)
	const plateFolder = Instance.new("Folder")
	plateFolder.Name = "Plate"
	plateFolder.Parent = folder
	local bun: Kit.Bun? = nil
	local shown = ""

	local function drawPlate(hasBun: boolean)
		plateFolder:ClearAllChildren()
		const plate = Kit.Plate()
		Kit.SitOn(plate, plateBase)
		plate.Parent = plateFolder
		const _, size = plate:GetBoundingBox()
		const top = plateBase + up * size.Y
		bun = nil
		if hasBun then
			const model = Kit.Food("BunOpen")
			if model ~= nil then
				Kit.SitOn(model, top)
				model.Parent = plateFolder
				const box, bunSize = model:GetBoundingBox()
				bun = { Frame = CFrame.fromMatrix(box.Position + up * (bunSize.Y / 2), right, up), Length = bunSize.X, Width = bunSize.Z }
			end
		end
	end

	const marks = Instance.new("Folder")
	marks.Name = "Marks"
	marks.Parent = folder
	const hover = Kit.Ball(folder, Vector3.zero, HOVER_COLOR, 0.3, 1)

	local dragging: number? = nil
	local ghost: Model? = nil
	local finished = false

	local function stationId(): number?
		const value = target:GetAttribute("StationId")
		return if type(value) == "number" then value else nil
	end

	local function record(slot: number): any?
		const id = stationId()
		return if id then session.Records()[id * SLOT_FACTOR + slot] else nil
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

	local function dropGhost()
		if ghost ~= nil then
			ghost:Destroy()
			ghost = nil
		end
		dragging = nil
	end

	local function hint()
		const held = session.Held()
		const item = if held then held:GetAttribute("Item") else nil
		if item ~= "plate" then
			session.Hint("Grill: tap a spot to cook a sausage. Bring a plate with a bun to serve it")
		elseif held ~= nil and held:GetAttribute("Bun") ~= true then
			session.Hint("Cut a bun on your plate first (the cutting board)")
		else
			session.Hint("Tap to grill, tap again to flip, drag a ready one onto the bun")
		end
	end

	return {
		Pointer = function(kind: string, position: Vector2)
			if finished then
				return
			end
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
					dragging = slot
					ghost = Kit.Food("SausageGrilled")
					if ghost ~= nil then
						ghost.Parent = folder
					end
				end
				return
			end
			const slot = dragging
			if slot == nil then
				-- the place under the pointer glows
				const near = if kind == "Move" then nearest(position) else nil
				const place = if near then places[near] else nil
				hover.Transparency = if place then 0.55 else 1
				if place ~= nil then
					hover.Position = place.At + up * 0.12
				end
				return
			end
			const plane = Kit.OnPlane(position, plateBase.Position + up * 0.2, up)
			if kind == "Move" then
				const model = ghost
				if model ~= nil and plane ~= nil then
					model:PivotTo(CFrame.fromMatrix(plane + up * 0.15, right, up))
				end
				return
			end
			-- Up: the drop
			const current = bun
			dropGhost()
			if plane == nil then
				return
			end
			if current == nil then
				session.Hint("Cut a bun on your plate first (the cutting board)")
				return
			end
			const x, y = Kit.BunPoint(current, plane)
			if x < -SLACK or x > 1 + SLACK or y < -1 - SLACK or y > 2 + SLACK then
				session.Hint("Drop the sausage on the bun")
				return
			end
			const score = Grade.Score(Content.Prep, "sausage_place", Gestures.Place(x, y, BUILD.Aspect, BUILD.Groove.X, BUILD.Groove.Y))
			session.Graded(score)
			session.Send({ Act = "Dog", Slot = slot, Score = score })
		end,
		Step = function(_dt: number)
			if finished then
				return
			end
			const held = session.Held()
			const item = if held then held:GetAttribute("Item") else nil
			if item == "hot_dog" and held ~= nil and (held:GetAttribute("PlateId") or 0) ~= 0 then
				finished = true
				plateFolder:ClearAllChildren()
				marks:ClearAllChildren()
				session.Hint("Hot dog on the plate! Now the toppings")
				session.Done()
				return
			end
			const signature = if item == "plate" then (if held and held:GetAttribute("Bun") == true then "bun" else "plate") else "none"
			if signature ~= shown then
				shown = signature
				if signature == "none" then
					plateFolder:ClearAllChildren()
					bun = nil
				else
					drawPlate(signature == "bun")
				end
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
				if state.State == "Ready" and dragging ~= slot then
					Kit.Ball(marks, place.At + up * 0.45, READY_COLOR, 0.16, 0)
				elseif state.State == "Working" and (state.Flip or 0) == 0 and state.Duration > 0 then
					const fraction = (now - state.StartedAt) / state.Duration
					if fraction >= WINDOW.FlipFrom and fraction <= WINDOW.FlipTo then
						Kit.Ball(marks, place.At + up * 0.45, FLIP_COLOR, 0.2, 0)
					end
				end
			end
		end,
		Stop = function()
			dropGhost()
		end,
	}
end

return table.freeze(Grill)
