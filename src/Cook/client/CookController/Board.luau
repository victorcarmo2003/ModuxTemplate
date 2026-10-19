--!strict
-- Cutting board of the cooking focus (kitchen-focus.md §1 #2; DEC-310 pre-prep): a whole bun lies on the board with a dashed
-- cut line along it. The knife is the pointer: press on the bun and drag across the line (left to right on screen; a gamepad
-- holds R2 and pushes the stick). Release = the cut, scored by Gestures.Slice -> Grade.Score bun_cut, sent as Cook Cut. No plate:
-- the server puts the cut bun on the cut-bun pile (the crate on the right, TLR_BUN_CUT); when the pile grows the bun opens and a
-- new whole bun comes, so the player cuts a batch. The focus stays until the player leaves (Back, walking).
local CollectionService = game:GetService("CollectionService")
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
const OPEN_SHOW = 0.45 -- s the opened bun stays before the next whole one comes
const PILE_KIND = "board" -- StationKind of the cut-bun pile
const SLOT_FACTOR = 100 -- Stations record id = StationId * 100 + slot

const Board = {}

-- StationIds of the cut-bun piles in the world
local function pileIds(): { [number]: boolean }
	const ids: { [number]: boolean } = {}
	for _, station in CollectionService:GetTagged("Station") do
		const id = station:GetAttribute("StationId")
		if station:GetAttribute("StationKind") == PILE_KIND and type(id) == "number" then
			ids[id] = true
		end
	end
	return ids
end

function Board.Start(session: Session.Session): Session.Handler
	const folder = session.Folder
	const up = Vector3.yAxis
	const right = session.Right
	const base = CFrame.fromMatrix(session.Top, right, up)
	const piles = pileIds()

	-- buns on the pile (cut or being cut), read from the Stations set
	local function pileCount(): (number, number)
		local count, places = 0, 0
		for id, record in session.Records() do
			if piles[id // SLOT_FACTOR] then
				places += 1
				if record.State ~= "Empty" then
					count += 1
				end
			end
		end
		return count, places
	end

	const line = Instance.new("Folder")
	line.Name = "CutLine"
	line.Parent = folder
	const trail = Instance.new("Folder")
	trail.Name = "Knife"
	trail.Parent = folder
	local bunModel: Model? = nil
	local bun: Kit.Bun = { Frame = base, Length = 1, Width = 0.4 }
	local points: { Gestures.Point } = {}
	local last: Vector3? = nil
	local cutting = false
	local sentAt: number? = nil
	local sentCount = 0
	local openedAt: number? = nil

	local function hint()
		const count, places = pileCount()
		if places > 0 then
			session.Hint(`Swipe across the bun along the line. Cut buns: {count}/{places}`)
		else
			session.Hint("Swipe across the bun along the line")
		end
	end

	local function reset()
		trail:ClearAllChildren()
		table.clear(points)
		last = nil
	end

	-- a whole bun on the board with its dashed line
	local function newBun()
		if bunModel ~= nil then
			bunModel:Destroy()
		end
		bunModel = Kit.Food("BunClosed")
		local box, size = base, Vector3.new(1, 0.3, 0.4)
		if bunModel ~= nil then
			Kit.SitOn(bunModel, base)
			bunModel.Parent = folder
			box, size = bunModel:GetBoundingBox()
		end
		bun = { Frame = CFrame.fromMatrix(box.Position + up * (size.Y / 2), right, up), Length = size.X, Width = size.Z }
		line:ClearAllChildren()
		const dashes = 14
		for index = 0, dashes do
			const x = BUILD.Cut.From + (BUILD.Cut.To - BUILD.Cut.From) * index / dashes
			Kit.Ball(line, Kit.BunWorld(bun, x, BUILD.Cut.Y, LIFT), LINE_COLOR, 0.06, 0.15)
		end
		reset()
		hint()
	end

	-- the server took the cut: the bun opens, then a new one comes
	local function opened()
		if bunModel ~= nil then
			bunModel:Destroy()
		end
		bunModel = Kit.Food("BunOpen")
		if bunModel ~= nil then
			Kit.SitOn(bunModel, base)
			bunModel.Parent = folder
		end
		line:ClearAllChildren()
		trail:ClearAllChildren()
		openedAt = os.clock()
	end

	local function bunPoint(position: Vector2): (number?, number?, Vector3?)
		const world = Kit.OnPlane(position, bun.Frame.Position, up)
		if world == nil then
			return nil, nil, nil
		end
		const x, y = Kit.BunPoint(bun, world)
		return x, y, world
	end

	newBun()

	return {
		Pointer = function(kind: string, position: Vector2)
			if sentAt ~= nil or openedAt ~= nil then
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
			sentCount = pileCount()
			session.Send({ Act = "Cut", Slot = 0, Score = score })
			sentAt = os.clock()
			session.Hint("Cutting...")
		end,
		Step = function(_dt: number)
			if openedAt ~= nil then
				if os.clock() - openedAt >= OPEN_SHOW then
					openedAt = nil
					newBun()
				end
				return
			end
			if sentAt ~= nil then
				if pileCount() > sentCount then
					sentAt = nil
					opened()
				elseif os.clock() - sentAt > RETRY then
					-- refused (no bun in stock, pile full: the toast says why) or lost: the same bun again
					sentAt = nil
					reset()
					hint()
				end
			end
		end,
		Stop = function() end,
	}
end

return table.freeze(Board)
