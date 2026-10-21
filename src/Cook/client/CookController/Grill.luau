--!strict
-- Grill of the cooking focus (kitchen-focus.md §1 #3; DEC-310 pre-prep, DEC-311 owner 2026-10-19). The camera centres the grill,
-- the sausage box on its left and the rest rail on its right. No plate here.
--   the box                 hover: its lid opens (local) and shows the sausages; drag one onto a free place of the grill = Cook
--                           Place on that place; a click on the box = Cook Place on the lowest free place
--   half cooked             an unflipped sausage stops at Restaurant.Grill.HoldAt (the server holds it); the flip mini-game is a
--                           cooking bar of that sausage turning into the flip bar (FlipMeter.State; TASK-594, owner
--                           2026-10-19: the screen card took too much room), the sausage icon running left and right on it. One
--                           bar at a time (they would overlap): the held sausage under the pointer, else the oldest. A press
--                           anywhere stops it = Cook Flip for that sausage with FlipMeter.Score (Perfect in the middle, Nice
--                           around it), the grade pops, it cooks on
--   ready                   drag it onto the rest rail = Cook Collect; a click on it = Cook Collect too
-- A marker over each sausage says what it wants: Mustard = flip (held), Green = ready. The sausages are the world's
-- (KitchenController draws them from the Stations set); the box's stock counter is the world's billboard. The focus stays until
-- the player leaves (Back, walking): the grill is a batch station.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local FlipMeter = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.FlipMeter)
local Kit = require(script.Parent.Kit)
local Session = require(script.Parent.Session)

const WINDOW = Content.Restaurant.Grill
const DROP = 0.8 -- studs from a place a dropped sausage still lands on it
const CLICK_TIME = 0.3 -- s: a press released sooner than this ...
const CLICK_MOVE = 14 -- ... and closer than this (px) is a click, not a drag
const RAIL_SLACK = 0.5 -- studs around the rest rail a drop still lands on it
const NEAR = 9 -- studs: the box and the rail of this grill
const SWEEP = 1.1 -- s for the capsule to cross the bar once
const RETRY = 2.5 -- s: no answer from the server = the gesture can be done again
const LID_ANGLE = math.rad(-75) -- the front edge of the lid rises
const LID_TIME = 0.18
const GHOST_SCALE = 2 -- the sausage being dragged is drawn this much bigger (owner 2026-10-19: easier to see)
const TUTORIAL_ATTRIBUTE = "TutorialRunning" -- TutorialController: one sausage at a time while it runs
const FLIP_COLOR = Color3.fromHex("#F6C12B")
const READY_COLOR = Color3.fromHex("#5FA36A")
const HOVER_COLOR = Color3.fromHex("#FFFFFF")
const SLOT_FACTOR = 100

type Place = { Slot: number, At: Vector3 }
type Lid = { Part: BasePart, Closed: CFrame, Open: CFrame }
type Drag = { Kind: "Raw" | "Ready", Slot: number, From: Vector2, At: number, Ghost: Model?, Moved: boolean }

const Grill = {}

-- The station of `kind` nearest to `at` within NEAR studs
local function nearestStation(kind: string, at: Vector3): Instance?
	local best: Instance? = nil
	local bestDistance = NEAR
	for _, station in CollectionService:GetTagged("Station") do
		if station:GetAttribute("StationKind") ~= kind or not station:IsDescendantOf(Workspace) then
			continue
		end
		const centre = Kit.Bounds(station)
		const distance = (centre - at).Magnitude
		if distance < bestDistance then
			best, bestDistance = station, distance
		end
	end
	return best
end

-- The visible lids of the box and the hinge that opens each one (its back edge, away from the camera)
local function lidsOf(box: Instance, toward: Vector3, right: Vector3): { Lid }
	const lids: { Lid } = {}
	for _, part in box:GetDescendants() do
		if part:IsA("BasePart") and string.find(part.Name, "Lid") ~= nil and part.Transparency < 0.95 then
			const direction = part.CFrame:VectorToObjectSpace(toward)
			const depth = math.abs(direction.X) * part.Size.X + math.abs(direction.Y) * part.Size.Y + math.abs(direction.Z) * part.Size.Z
			const hinge = part.Position - toward * (depth / 2)
			const turn = CFrame.fromAxisAngle(right, LID_ANGLE)
			const open = CFrame.new(hinge) * turn * CFrame.new(-hinge) * part.CFrame
			table.insert(lids, { Part = part, Closed = part.CFrame, Open = open })
		end
	end
	return lids
end

function Grill.Start(session: Session.Session): Session.Handler
	const folder = session.Folder
	const target = session.Target
	const up = Vector3.yAxis
	const box = nearestStation("sausage_stock", session.Top)
	const rail = nearestStation("rail", session.Top)

	-- the places: Attachments with a Slot inside the grill
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
	const lids = if box ~= nil then lidsOf(box, session.Toward, session.Right) else {}
	local lidOpen = false
	local drag: Drag? = nil
	local sentFlip: number? = nil
	local flipSlot: number? = nil
	local hoverFlip: number? = nil -- the held sausage under the pointer
	local shown = ""

	-- the flip bar is the cooking bar of the sausage being flipped: FlipMeter.State says which and where the icon is, the world bar
	-- (KitchenController/Slots) turns into it
	const meterOn = Vide.source(false)
	const marker = Vide.source(0)
	local sweep = 0

	local function stationId(): number?
		const value = target:GetAttribute("StationId")
		return if type(value) == "number" then value else nil
	end

	local function record(slot: number): any?
		const id = stationId()
		return if id then session.Records()[id * SLOT_FACTOR + slot] else nil
	end

	local function railCount(): number?
		const id = if rail ~= nil then rail:GetAttribute("StationId") else nil
		if type(id) ~= "number" then
			return nil
		end
		const value = session.Records()[id * SLOT_FACTOR]
		return if value ~= nil then value.Count or 0 else 0
	end

	-- a sausage waiting for its flip: Working, not flipped, past HoldAt of its cook time
	local function held(state: any?, now: number): boolean
		if state == nil or state.State ~= "Working" or (state.Flip or 0) ~= 0 or state.Duration <= 0 then
			return false
		end
		return (now - state.StartedAt) / state.Duration >= WINDOW.HoldAt
	end

	-- the active place nearest to a world point (nil = none within DROP)
	local function placeAt(world: Vector3, wanted: string): number?
		local best: number? = nil
		local bestDistance = DROP
		for slot, place in places do
			const state = record(slot)
			if state == nil or state.State ~= wanted then
				continue
			end
			const flat = Vector3.new(place.At.X - world.X, 0, place.At.Z - world.Z).Magnitude
			if flat < bestDistance then
				best, bestDistance = slot, flat
			end
		end
		return best
	end

	local function freePlace(): number?
		const slots: { number } = {}
		for slot in places do
			table.insert(slots, slot)
		end
		table.sort(slots)
		for _, slot in slots do
			const state = record(slot)
			if state ~= nil and state.State == "Empty" then
				return slot
			end
		end
		return nil
	end

	-- the tutorial (owner 2026-10-19): one sausage only, grilled or on the rail
	local function oneEnough(): boolean
		if Players.LocalPlayer:GetAttribute(TUTORIAL_ATTRIBUTE) ~= true then
			return false
		end
		for slot in places do
			const state = record(slot)
			if state ~= nil and state.State ~= "Empty" then
				return true
			end
		end
		return (railCount() or 0) > 0
	end

	local function onGrill(position: Vector2): Vector3?
		return Kit.OnPlane(position, Vector3.new(0, height, 0), up)
	end

	local function overRail(world: Vector3): boolean
		if rail == nil then
			return false
		end
		const centre, size = Kit.Bounds(rail)
		return math.abs(world.X - centre.X) <= size.X / 2 + RAIL_SLACK and math.abs(world.Z - centre.Z) <= size.Z / 2 + RAIL_SLACK
	end

	-- the box glows while the pointer is on it (the lid opens with it)
	const boxLight = Instance.new("Highlight")
	boxLight.Name = "BoxHover"
	boxLight.FillTransparency = 0.85
	boxLight.FillColor = Color3.fromHex("#F6C12B")
	boxLight.OutlineColor = Color3.fromHex("#F6C12B")
	boxLight.DepthMode = Enum.HighlightDepthMode.Occluded
	boxLight.Enabled = false
	boxLight.Adornee = box
	boxLight.Parent = folder

	local function setLid(open: boolean)
		if open == lidOpen then
			return
		end
		lidOpen = open
		boxLight.Enabled = open
		for _, lid in lids do
			TweenService:Create(lid.Part, TweenInfo.new(LID_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = if open then lid.Open else lid.Closed,
			}):Play()
		end
	end

	local function dropGhost()
		const current = drag
		if current ~= nil and current.Ghost ~= nil then
			current.Ghost:Destroy()
		end
		drag = nil
	end

	local function hint()
		const count = railCount()
		const tail = if count ~= nil then ` Rest rail: {count}` else ""
		session.Hint(`Drag a sausage from the box onto the grill (or tap the box). Flip it at half. Ready? Send it to the rest rail.{tail}`)
	end

	-- the press on the meter: the score is where the capsule is now
	local function flip()
		const slot = flipSlot
		if slot == nil then
			return
		end
		const score = FlipMeter.Score(Vide.untrack(marker))
		const place = places[slot]
		session.Graded(score, if place then place.At else nil)
		if place ~= nil then
			session.Juice:Sound("grill_drop", place.At)
			session.Juice:Burst(place.At, "Dust", 6, nil)
		end
		session.Send({ Act = "Flip", Slot = slot, Score = score })
		session.Paw:Learned("grill_flip")
		sentFlip = os.clock()
		meterOn(false)
		FlipMeter.State.Clear()
	end

	local function readySlotUnder(position: Vector2): number?
		const world = onGrill(position)
		return if world ~= nil then placeAt(world, "Ready") else nil
	end

	-- the pointer over the box: inside its footprint on the plane of its top (its parts take no raycast: CanQuery is off)
	local boxTop, boxSize = Vector3.zero, Vector3.zero
	if box ~= nil then
		boxTop, boxSize = Kit.Bounds(box)
	end
	-- the sausages inside the box (its visible Fill), else the middle of its top: the paw starts there, not on the lid
	local boxFood = boxTop
	if box ~= nil then
		for _, part in box:GetDescendants() do
			if part:IsA("BasePart") and string.find(part.Name, "Fill") ~= nil and part.Transparency < 0.95 then
				boxFood = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
				break
			end
		end
	end
	local function overBox(position: Vector2): boolean
		if box == nil then
			return false
		end
		const world = Kit.OnPlane(position, boxTop, up)
		return world ~= nil
			and math.abs(world.X - boxTop.X) <= boxSize.X / 2 + RAIL_SLACK
			and math.abs(world.Z - boxTop.Z) <= boxSize.Z / 2 + RAIL_SLACK
	end

	return {
		Pointer = function(kind: string, position: Vector2)
			if kind == "Down" then
				-- the meter takes the press while it shows
				if Vide.untrack(meterOn) then
					flip()
					return
				end
				if overBox(position) then
					drag = { Kind = "Raw", Slot = 0, From = position, At = os.clock(), Ghost = nil, Moved = false }
					return
				end
				const ready = readySlotUnder(position)
				if ready ~= nil then
					drag = { Kind = "Ready", Slot = ready, From = position, At = os.clock(), Ghost = nil, Moved = false }
				end
				return
			end
			const current = drag
			if kind == "Move" then
				-- the box opens under the pointer (or while a sausage is taken from it)
				setLid(overBox(position) or (current ~= nil and current.Kind == "Raw"))
				if current == nil then
					const world = onGrill(position)
					-- the held sausage under the pointer gets the flip bar
					const working = if world ~= nil then placeAt(world, "Working") else nil
					hoverFlip = if working ~= nil and held(record(working), Workspace:GetServerTimeNow()) then working else nil
					const ready = if world ~= nil then placeAt(world, "Ready") else nil
					const place = if ready ~= nil then places[ready] else nil
					hover.Transparency = if place then 0.55 else 1
					if place ~= nil then
						hover.Position = place.At + up * 0.12
					end
					return
				end
				if not current.Moved and (position - current.From).Magnitude >= CLICK_MOVE then
					current.Moved = true
					const ghost = Kit.Food(if current.Kind == "Raw" then "SausageRaw" else "SausageGrilled")
					if ghost ~= nil then
						ghost:ScaleTo(GHOST_SCALE)
						ghost.Parent = folder
					end
					current.Ghost = ghost
				end
				-- over the box the sausage rides its top (else it would hide inside it), elsewhere the grill
				const inBox = overBox(position)
				const world = if inBox then Kit.OnPlane(position, boxTop, up) else onGrill(position)
				if current.Ghost ~= nil and world ~= nil then
					current.Ghost:PivotTo(CFrame.fromMatrix(world + up * (if inBox then 0.45 else 0.3), session.Right, up))
				end
				return
			end
			-- Up
			if current == nil then
				return
			end
			const click = not current.Moved and os.clock() - current.At <= CLICK_TIME
			const world = onGrill(position)
			dropGhost()
			if current.Kind == "Raw" and oneEnough() then
				session.Hint("One is enough for now")
			elseif current.Kind == "Raw" then
				const slot = if click then freePlace() elseif world ~= nil then placeAt(world, "Empty") else nil
				if slot ~= nil then
					session.Send({ Act = "Place", Slot = slot, Score = 0 })
					session.Paw:Learned("grill_place")
					-- the sizzle and a puff where it lands
					session.Juice:Sound("grill_drop", places[slot].At)
					session.Juice:Burst(places[slot].At, "Dust", 8, nil)
				elseif not click then
					session.Hint("Drop it on a free spot of the grill")
				end
			elseif click or (world ~= nil and overRail(world)) then
				session.Send({ Act = "Collect", Slot = current.Slot, Score = 0 })
				session.Paw:Learned("grill_collect")
				-- off the grill with a pop on the rail
				if rail ~= nil then
					const railTop = Kit.Bounds(rail)
					session.Juice:Sound("grill_collect", railTop)
					session.Juice:Burst(railTop, "Ready", 8, Color3.fromHex("#5FA36A"))
				end
			else
				session.Hint("Drop it on the rest rail")
			end
		end,
		Step = function(dt: number)
			const signature = tostring(railCount())
			if signature ~= shown then
				shown = signature
				hint()
			end
			const now = Workspace:GetServerTimeNow()
			-- the held sausage the flip bar is for: the one under the pointer, else the oldest
			local wanted: number? = nil
			local oldest = math.huge
			for slot in places do
				const state = record(slot)
				if held(state, now) and state.StartedAt < oldest then
					wanted, oldest = slot, state.StartedAt
				end
			end
			const pointed = hoverFlip
			if pointed ~= nil and held(record(pointed), now) then
				wanted = pointed
			end
			if sentFlip ~= nil and (wanted ~= flipSlot or os.clock() - sentFlip > RETRY) then
				sentFlip = nil
			end
			flipSlot = wanted
			meterOn(wanted ~= nil and sentFlip == nil)
			const id = stationId()
			if Vide.untrack(meterOn) and wanted ~= nil and id ~= nil then
				FlipMeter.State.Set(id * SLOT_FACTOR + wanted)
				sweep = (sweep + dt / SWEEP) % 2
				const at = if sweep <= 1 then sweep else 2 - sweep
				marker(at)
				FlipMeter.State.SetMarker(at)
			else
				FlipMeter.State.Clear()
			end
			-- the paw shows the next gesture: flip a held one, send a ready one to the rail, take one from the box
			local readyAt: Vector3? = nil
			local busy = false
			for slot, place in places do
				const state = record(slot)
				if state ~= nil and state.State ~= "Empty" then
					busy = true
				end
				if state ~= nil and state.State == "Ready" and readyAt == nil then
					readyAt = place.At
				end
			end
			const free = freePlace()
			if wanted ~= nil then
				session.Paw:Show("grill_flip", { places[wanted].At })
			elseif readyAt ~= nil and rail ~= nil then
				session.Paw:Show("grill_collect", { readyAt, (Kit.Bounds(rail)) })
			elseif not busy and free ~= nil and box ~= nil then
				session.Paw:Show("grill_place", { boxFood, places[free].At })
			else
				session.Paw:Hide()
			end
			-- what each sausage wants
			marks:ClearAllChildren()
			for slot, place in places do
				const state = record(slot)
				if state == nil then
					continue
				end
				const moving = drag
				const dragged = moving ~= nil and moving.Kind == "Ready" and moving.Slot == slot and moving.Moved
				if state.State == "Ready" and not dragged then
					Kit.Ball(marks, place.At + up * 0.45, READY_COLOR, 0.16, 0)
				elseif held(state, now) then
					Kit.Ball(marks, place.At + up * 0.45, FLIP_COLOR, 0.2, 0)
				end
			end
		end,
		Stop = function()
			dropGhost()
			for _, lid in lids do
				lid.Part.CFrame = lid.Closed
			end
			FlipMeter.State.Clear()
		end,
	}
end

return table.freeze(Grill)
