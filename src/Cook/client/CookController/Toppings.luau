--!strict
-- Condiment table of the cooking focus (kitchen-focus.md §1 #4). The hot dog in hand (on its dish) sits in the middle of the table,
-- turned so the bun runs left to right on screen; the pans of the order are lit by PlateController.
--   tap a pan                  selects that condiment (a white outline)
--   sauce (ketchup, mustard, cream cheese): draw on the bun; the zig-zag dots are the target. Release = Cook Topping with the
--                              drawn line (it stays on the hot dog: HotDogVisual.Sauce) and Gestures.Trace -> Grade.Score
--   cheese, bacon, potato sticks: the piece follows the pointer; press / release on the bun = Cook Topping, scored by how close to
--                              the middle of the bun it landed (Gestures.Place)
-- The step ends when every topping of the order is on (an order not known = never by itself).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local Sauce = require(ReplicatedStorage.shared.Item.HotDogVisual.Sauce)
local Gestures = require(script.Parent.Gestures)
local Kit = require(script.Parent.Kit)
local Session = require(script.Parent.Session)

const BUILD = Content.Prep.Build
const BUN_LENGTH = 0.85 -- HotDogVisual: share of the Handle's long side the bun space covers
const BUN_WIDTH = 0.7
const PATH_COLOR = Color3.fromHex("#FFF1D6")
const PICK_COLOR = Color3.fromHex("#FFFFFF")
const SLACK = 0.25
const TRACE: { [string]: boolean } = {}
for _, row in Content.Prep.Tolerances.List do
	if row.Gesture == "trace" then
		TRACE[row.Key] = true
	end
end

type Space = { Origin: Vector3, Along: Vector3, Across: Vector3, Length: number, Width: number }

const Toppings = {}

local function toppingModel(key: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const kit = if items then items:FindFirstChild("Toppings") else nil
	const template = if kit then kit:FindFirstChild(key) else nil
	if template == nil or not template:IsA("Model") then
		return nil
	end
	const copy = template:Clone()
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	return copy
end

function Toppings.Start(session: Session.Session): Session.Handler
	const folder = session.Folder
	const up = Vector3.yAxis
	const right = session.Right

	-- the pans of the table
	const pans: { Instance } = {}
	for _, child in session.Target:GetDescendants() do
		if child:IsA("Model") and type(child:GetAttribute("Topping")) == "string" then
			table.insert(pans, child)
		end
	end
	if #pans == 0 and type(session.Target:GetAttribute("Topping")) == "string" then
		table.insert(pans, session.Target)
	end

	const propFolder = Instance.new("Folder")
	propFolder.Name = "HotDog"
	propFolder.Parent = folder
	const ink = Instance.new("Folder")
	ink.Name = "Ink"
	ink.Parent = folder
	const guide = Instance.new("Folder")
	guide.Name = "Guide"
	guide.Parent = folder
	local space: Space? = nil
	local shown = ""
	local selected: string? = nil
	local pick: Highlight? = nil
	local ghost: Model? = nil
	local stroke: { Gestures.Point } = {}
	local last: Vector3? = nil
	local drawing = false
	local finished = false

	-- the hot dog in hand as a local model in the middle of the table, the bun running along the screen's right
	local function drawProp(tool: Tool)
		propFolder:ClearAllChildren()
		space = nil
		const model = Kit.FromTool(tool)
		if model == nil then
			return
		end
		const handle = model.PrimaryPart :: BasePart
		const alongLocal = if handle.Size.X >= handle.Size.Z then Vector3.xAxis else Vector3.zAxis
		const handleFrame = if alongLocal == Vector3.xAxis
			then CFrame.fromMatrix(session.Top, right, up)
			else CFrame.fromMatrix(session.Top, up:Cross(right), up)
		model:PivotTo(handleFrame * handle.CFrame:ToObjectSpace(model:GetPivot()))
		const box, size = model:GetBoundingBox()
		model:PivotTo(model:GetPivot() + Vector3.new(session.Top.X - box.Position.X, session.Top.Y - (box.Position.Y - size.Y / 2), session.Top.Z - box.Position.Z))
		model.Parent = propFolder
		const acrossLocal = if alongLocal == Vector3.xAxis then Vector3.zAxis else Vector3.xAxis
		const anchor = handle:FindFirstChild("Att_Topping1")
		const origin = if anchor ~= nil and anchor:IsA("Attachment") then anchor.WorldPosition else handle.Position + up * (handle.Size.Y / 2)
		space = {
			Origin = origin,
			Along = handle.CFrame:VectorToWorldSpace(alongLocal),
			Across = handle.CFrame:VectorToWorldSpace(acrossLocal),
			Length = math.abs(handle.Size:Dot(alongLocal)) * BUN_LENGTH,
			Width = math.abs(handle.Size:Dot(acrossLocal)) * BUN_WIDTH,
		}
	end

	local function bunPoint(position: Vector2): (number?, number?, Vector3?)
		const current = space
		if current == nil then
			return nil, nil, nil
		end
		const world = Kit.OnPlane(position, current.Origin, up)
		if world == nil then
			return nil, nil, nil
		end
		const offset = world - current.Origin
		return offset:Dot(current.Along) / current.Length + 0.5, offset:Dot(current.Across) / current.Width + 0.5, world
	end

	local function worldOf(x: number, y: number, lift: number): Vector3?
		const current = space
		if current == nil then
			return nil
		end
		return current.Origin + current.Along * ((x - 0.5) * current.Length) + current.Across * ((y - 0.5) * current.Width) + up * lift
	end

	local function clearPick()
		if pick ~= nil then
			pick:Destroy()
			pick = nil
		end
		if ghost ~= nil then
			ghost:Destroy()
			ghost = nil
		end
		guide:ClearAllChildren()
		selected = nil
	end

	local function onHotDog(key: string): boolean
		const held = session.Held()
		const raw = if held then held:GetAttribute("Toppings") else nil
		return type(raw) == "string" and table.find(string.split(raw, ","), key) ~= nil
	end

	local function select(pan: Instance)
		const key = pan:GetAttribute("Topping") :: string
		clearPick()
		if onHotDog(key) then
			const row = Content.Ingredients.ByKey[key]
			session.Hint(`{if row then row.Name else key} is already on it`)
			return
		end
		selected = key
		const light = Instance.new("Highlight")
		light.Name = "CookPick"
		light.Adornee = pan
		light.FillTransparency = 1
		light.OutlineColor = PICK_COLOR
		light.DepthMode = Enum.HighlightDepthMode.Occluded
		light.Parent = folder
		pick = light
		const row = Content.Ingredients.ByKey[key]
		const name = if row then row.Name else key
		if TRACE[key] then
			-- the target: the zig-zag over the bun
			for index, point in BUILD.Sauce.Path do
				const at = worldOf(point.X, point.Y, 0.06)
				if at ~= nil then
					Kit.Ball(guide, at, PATH_COLOR, 0.07, 0.2)
				end
				const nextPoint = BUILD.Sauce.Path[index + 1]
				if nextPoint ~= nil then
					for step = 1, 3 do
						const alpha = step / 4
						const mid = worldOf(point.X + (nextPoint.X - point.X) * alpha, point.Y + (nextPoint.Y - point.Y) * alpha, 0.06)
						if mid ~= nil then
							Kit.Ball(guide, mid, PATH_COLOR, 0.045, 0.45)
						end
					end
				end
			end
			session.Hint(`Draw the {name} over the dots`)
		else
			ghost = toppingModel(key)
			if ghost ~= nil then
				ghost.Parent = folder
			end
			session.Hint(`Drop the {name} on the bun`)
		end
	end

	local function commitSauce(key: string)
		const coverage, excess = Gestures.Trace({ stroke }, BUILD.Sauce.Path, BUILD.Aspect, BUILD.Sauce.Reach, BUILD.Sauce.Spill)
		const score = Grade.Score(Content.Prep, key, coverage, excess)
		const segment: { Vector2 } = {}
		for _, point in stroke do
			table.insert(segment, Vector2.new(math.clamp(point.X, 0, 1), math.clamp(point.Y, 0, 1)))
		end
		session.Graded(score)
		session.Send({ Act = "Topping", Slot = 0, Score = score, Key = key, Points = Sauce.Pack({ segment }) })
		clearPick()
	end

	local function remaining(): (number, number)
		const order = session.Order()
		if order == nil then
			return -1, 0
		end
		local left = 0
		for _, key in order do
			if not onHotDog(key) then
				left += 1
			end
		end
		return left, #order
	end

	return {
		Pointer = function(kind: string, position: Vector2)
			if finished then
				return
			end
			const key = selected
			const x, y, world = bunPoint(position)
			if kind == "Down" then
				-- a pan first: it (re)selects
				const hit = Kit.Hit(position, pans)
				if hit ~= nil then
					for _, pan in pans do
						if hit:IsDescendantOf(pan) then
							select(pan)
							return
						end
					end
				end
				if key == nil then
					session.Hint("Tap a condiment first")
					return
				end
				if TRACE[key] and x ~= nil and y ~= nil and x > -SLACK and x < 1 + SLACK and y > -SLACK and y < 1 + SLACK then
					drawing = true
					table.clear(stroke)
					ink:ClearAllChildren()
					last = nil
				end
			end
			if key == nil or x == nil or y == nil or world == nil then
				return
			end
			if TRACE[key] then
				if not drawing then
					return
				end
				if kind ~= "Up" then
					const at = world + up * 0.05
					if last == nil or (at - last).Magnitude > 0.03 then
						if last ~= nil then
							Kit.Segment(ink, last, at, Sauce.ColorOf(key), 0.06)
						end
						last = at
						if #stroke < BUILD.Sauce.MaxPoints then
							table.insert(stroke, { X = x, Y = y })
						end
					end
					return
				end
				drawing = false
				if #stroke < BUILD.Sauce.MinPoints then
					ink:ClearAllChildren()
					session.Hint("Draw a longer line over the dots")
					return
				end
				commitSauce(key)
				return
			end
			-- a piece: it follows the pointer, the release on the bun drops it
			const model = ghost
			if model ~= nil then
				model:PivotTo(CFrame.fromMatrix(world + up * 0.08, right, up))
			end
			if kind == "Up" then
				if x < -BUILD.DropSlack or x > 1 + BUILD.DropSlack or y < -1 or y > 2 then
					return
				end
				const score = Grade.Score(Content.Prep, key, Gestures.Place(x, y, BUILD.Aspect, BUILD.Groove.X, BUILD.Groove.Y))
				session.Graded(score)
				session.Send({ Act = "Topping", Slot = 0, Score = score, Key = key })
				clearPick()
			end
		end,
		Step = function(_dt: number)
			if finished then
				return
			end
			const held = session.Held()
			if held == nil or held:GetAttribute("Item") ~= "hot_dog" then
				if shown ~= "" then
					shown = ""
					propFolder:ClearAllChildren()
					space = nil
				end
				session.Hint("Bring the hot dog on its plate")
				return
			end
			const signature = `{held:GetAttribute("Toppings") or ""}|{held:GetAttribute("Sauce") or ""}`
			if signature ~= shown then
				shown = signature
				drawProp(held)
				ink:ClearAllChildren()
				const left, total = remaining()
				if left == 0 then
					finished = true
					clearPick()
					session.Hint(if total == 0 then "No toppings for this one. Hand it over!" else "All done! Hand it over at the pickup")
					session.Done()
					return
				end
				if selected == nil then
					session.Hint("Tap a lit condiment, then put it on the bun")
				end
			end
		end,
		Stop = function()
			clearPick()
		end,
	}
end

return table.freeze(Toppings)
