--!strict
-- Cutting board of the cooking focus (kitchen-focus.md §1 #2): the plate in hand sits on the board with a whole bun on it and a
-- dashed cut line along the bun. The knife is the pointer: press on the bun and drag across the line (left to right on screen;
-- a gamepad holds R2 and pushes the stick). Release = the cut, scored by Gestures.Slice -> Grade.Score bun_cut, sent as Cook Cut.
-- When the server puts the bun on the plate (attribute Bun) the bun opens and the focus ends by itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local Gestures = require(script.Parent.Gestures)
local Kit = require(script.Parent.Kit)
local Session = require(script.Parent.Session)

const BUILD = Content.Prep.Build
const LINE_COLOR = Color3.fromHex("#F6C12B")
const KNIFE_COLOR = Color3.fromHex("#FFFFFF")
const LIFT = 0.04 -- studs over the bun top for the line and the trail
const SLACK = 0.35 -- bun-space margin a press may start in
const RETRY = 2.5 -- s: no answer from the server after a cut = try again

const Board = {}

function Board.Start(session: Session.Session): Session.Handler
	const folder = session.Folder
	const up = Vector3.yAxis
	const right = session.Right
	const base = CFrame.fromMatrix(session.Top, right, up)

	-- the plate and the whole bun on it
	const plate = Kit.Plate()
	Kit.SitOn(plate, base)
	plate.Parent = folder
	const _, plateSize = plate:GetBoundingBox()
	const plateTop = base + up * plateSize.Y
	local bunModel = Kit.Food("BunClosed")
	if bunModel ~= nil then
		Kit.SitOn(bunModel, plateTop)
		bunModel.Parent = folder
	end
	local bun: Kit.Bun
	do
		local box, size = plateTop, Vector3.new(1, 0.3, 0.4)
		if bunModel ~= nil then
			box, size = bunModel:GetBoundingBox()
		end
		bun = {
			Frame = CFrame.fromMatrix(box.Position + up * (size.Y / 2), right, up),
			Length = size.X,
			Width = size.Z,
		}
	end

	-- the dashed line
	const line = Instance.new("Folder")
	line.Name = "CutLine"
	line.Parent = folder
	const dashes = 14
	for index = 0, dashes do
		const x = BUILD.Cut.From + (BUILD.Cut.To - BUILD.Cut.From) * index / dashes
		Kit.Ball(line, Kit.BunWorld(bun, x, BUILD.Cut.Y, LIFT), LINE_COLOR, 0.06, 0.15)
	end

	const trail = Instance.new("Folder")
	trail.Name = "Knife"
	trail.Parent = folder
	local points: { Gestures.Point } = {}
	local last: Vector3? = nil
	local cutting = false
	local sentAt: number? = nil
	local finished = false

	session.Hint("Swipe across the bun along the line")

	local function bunPoint(position: Vector2): (number?, number?, Vector3?)
		const world = Kit.OnPlane(position, bun.Frame.Position, up)
		if world == nil then
			return nil, nil, nil
		end
		const x, y = Kit.BunPoint(bun, world)
		return x, y, world
	end

	local function reset()
		trail:ClearAllChildren()
		table.clear(points)
		last = nil
	end

	local function finish()
		if finished then
			return
		end
		finished = true
		if bunModel ~= nil then
			bunModel:Destroy()
		end
		bunModel = Kit.Food("BunOpen")
		if bunModel ~= nil then
			Kit.SitOn(bunModel, plateTop)
			bunModel.Parent = folder
		end
		line:ClearAllChildren()
		trail:ClearAllChildren()
		session.Hint("Bun on the plate!")
		session.Done()
	end

	return {
		Pointer = function(kind: string, position: Vector2)
			if finished or sentAt ~= nil then
				return
			end
			const x, y, world = bunPoint(position)
			if kind == "Down" then
				if x == nil or y == nil or x < -SLACK or x > 1 + SLACK or y < -1 or y > 2 then
					return
				end
				reset()
				cutting = true
			end
			if not cutting or x == nil or y == nil or world == nil then
				return
			end
			if kind == "Down" or kind == "Move" then
				const at = world + up * LIFT
				if last == nil or (at - last).Magnitude > 0.02 then
					if last ~= nil then
						Kit.Segment(trail, last, at, KNIFE_COLOR, 0.035)
					end
					last = at
					table.insert(points, { X = x, Y = y })
				end
				return
			end
			-- Up: the cut
			cutting = false
			const raw = Gestures.Slice(points, BUILD.Aspect, BUILD.Cut.Y, BUILD.Cut.From, BUILD.Cut.To, BUILD.Cut.MinPoints)
			if raw == math.huge then
				reset()
				session.Hint("Drag across the whole bun, along the line")
				return
			end
			const score = Grade.Score(Content.Prep, "bun_cut", raw)
			session.Graded(score)
			session.Send({ Act = "Cut", Slot = 0, Score = score })
			sentAt = os.clock()
			session.Hint("Cutting...")
		end,
		Step = function(_dt: number)
			if finished then
				return
			end
			const held = session.Held()
			if held ~= nil and held:GetAttribute("Bun") == true then
				finish()
				return
			end
			if held == nil or held:GetAttribute("Item") ~= "plate" then
				session.Hint("Hold your plate to cut a bun on it")
			end
			if sentAt ~= nil and os.clock() - sentAt > RETRY then
				sentAt = nil
				reset()
				session.Hint("Try again: swipe across the bun")
			end
		end,
		Stop = function() end,
	}
end

return table.freeze(Board)
