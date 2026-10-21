--!strict
-- Cutting board of the cooking focus (kitchen-focus.md §1 #2; DEC-310 pre-prep): a whole bun lies on the board with a dashed
-- cut line along it. The knife is the pointer: press on the bun and drag across the line (left to right on screen; a gamepad
-- holds R2 and pushes the stick). While cutting, the dashes the knife went over turn Mustard and the focus bar fills with the
-- share of the line crossed (owner 2026-10-19, like the old prep's guide). Release = the cut, scored by Gestures.Slice -> Grade.Score bun_cut, sent as Cook Cut. No plate:
-- the server puts the cut bun on the cut-bun pile (the crate on the right, TLR_BUN_CUT); when the pile grows the bun opens and a
-- new whole bun comes, so the player cuts a batch. The focus stays until the player leaves (Back, walking).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local Gestures = require(script.Parent.Gestures)
local Kit = require(script.Parent.Kit)
local Session = require(script.Parent.Session)

const BUILD = Content.Prep.Build
const LINE_COLOR = Color3.fromHex("#FFF1D6") -- the dashes still to cut (Cream)
const DONE_COLOR = Color3.fromHex("#F6C12B") -- the dashes the knife went over (Mustard; owner 2026-10-19: show the progress)
const KNIFE_COLOR = Color3.fromHex("#FFFFFF")
const LIFT = 0.04 -- studs over the bun top for the line and the trail
const SLACK = 0.35 -- bun-space margin a press may start in
const RETRY = 2.5 -- s: no answer from the server after a cut = try again
const OPEN_SHOW = 0.45 -- s the opened bun stays before the next whole one comes
const PILE_KIND = "board" -- StationKind of the cut-bun pile
const BUN_SCALE = 2 -- the bun on the board is drawn twice the kit size (owner 2026-10-19: easier to see what you cut)
const POP_TIME = 0.32 -- s of the cartoon pop a bun comes in with (squash, overshoot, settle)
const TUTORIAL_ATTRIBUTE = "TutorialRunning" -- TutorialController: one bun only while it runs
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
	-- the dashes of the cut line and their x along the bun
	const dashes: { { Part: Part, X: number } } = {}
	local low, high = math.huge, -math.huge -- x range the knife went over in this swipe
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

	-- the dashes inside the swiped range turn Mustard, the bar shows the share of the line crossed
	local function paintCut()
		const span = BUILD.Cut.To - BUILD.Cut.From
		const crossed = if high >= low then math.clamp((math.min(high, BUILD.Cut.To) - math.max(low, BUILD.Cut.From)) / span, 0, 1) else 0
		for _, dash in dashes do
			dash.Part.Color = if dash.X >= low and dash.X <= high then DONE_COLOR else LINE_COLOR
		end
		session.Progress(if cutting then crossed else nil)
	end

	local function reset()
		trail:ClearAllChildren()
		table.clear(points)
		last = nil
		low, high = math.huge, -math.huge
		paintCut()
	end

	-- the tutorial (owner 2026-10-19): one bun only
	local function oneEnough(): boolean
		return Players.LocalPlayer:GetAttribute(TUTORIAL_ATTRIBUTE) == true and pileCount() >= 1
	end

	-- a bun model at BUN_SCALE, sitting on the board, popping in like a cartoon (a quick overshoot and settle)
	local function placeBun(name: string): Model?
		const model = Kit.Food(name)
		if model == nil then
			return nil
		end
		model:ScaleTo(BUN_SCALE)
		Kit.SitOn(model, base)
		model.Parent = folder
		task.spawn(function()
			local t = 0
			while t < POP_TIME and model.Parent ~= nil do
				t += RunService.Heartbeat:Wait()
				const u = math.clamp(t / POP_TIME, 0, 1)
				-- 0.55 -> 1.18 -> 1 (ease out with an overshoot)
				const s = if u < 0.6 then 0.55 + (1.18 - 0.55) * (u / 0.6) else 1.18 - 0.18 * ((u - 0.6) / 0.4)
				model:ScaleTo(BUN_SCALE * s)
				Kit.SitOn(model, base)
			end
			if model.Parent ~= nil then
				model:ScaleTo(BUN_SCALE)
				Kit.SitOn(model, base)
			end
		end)
		return model
	end

	-- a whole bun on the board with its dashed line
	local function newBun()
		if bunModel ~= nil then
			bunModel:Destroy()
		end
		-- the size at rest (the pop scales it a moment after)
		local box, size = base, Vector3.new(1, 0.3, 0.4) * BUN_SCALE
		const probe = Kit.Food("BunClosed")
		if probe ~= nil then
			probe:ScaleTo(BUN_SCALE)
			Kit.SitOn(probe, base)
			box, size = probe:GetBoundingBox()
			probe:Destroy()
		end
		bunModel = placeBun("BunClosed")
		bun = { Frame = CFrame.fromMatrix(box.Position + up * (size.Y / 2), right, up), Length = size.X, Width = size.Z }
		line:ClearAllChildren()
		table.clear(dashes)
		const count = 14
		for index = 0, count do
			const x = BUILD.Cut.From + (BUILD.Cut.To - BUILD.Cut.From) * index / count
			table.insert(dashes, { Part = Kit.Ball(line, Kit.BunWorld(bun, x, BUILD.Cut.Y, LIFT), LINE_COLOR, 0.06, 0.15), X = x })
		end
		reset()
		hint()
	end

	-- the server took the cut: the bun opens, then a new one comes
	local function opened()
		if bunModel ~= nil then
			bunModel:Destroy()
		end
		bunModel = placeBun("BunOpen")
		line:ClearAllChildren()
		table.clear(dashes)
		trail:ClearAllChildren()
		session.Progress(nil)
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
			if kind == "Down" and oneEnough() then
				session.Hint("One bun is enough for now. Press Back")
				return
			end
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
					low, high = math.min(low, x), math.max(high, x)
					paintCut()
				end
				return
			end
			-- Up: the cut
			cutting = false
			session.Progress(nil)
			const raw = Gestures.Slice(points, BUILD.Aspect, BUILD.Cut.Y, BUILD.Cut.From, BUILD.Cut.To, BUILD.Cut.MinPoints)
			if raw == math.huge then
				reset()
				session.Hint("Drag across the whole bun, along the line")
				return
			end
			const score = Grade.Score(Content.Prep, "bun_cut", raw)
			const middle = Kit.BunWorld(bun, 0.5, 0.5, LIFT)
			session.Graded(score, middle)
			session.Juice:Sound("bun_slice", middle)
			session.Juice:Burst(middle, "Dust", 10, Color3.fromHex("#E8B36B"))
			session.Paw:Learned("bun_cut")
			sentCount = pileCount()
			session.Send({ Act = "Cut", Slot = 0, Score = score })
			sentAt = os.clock()
			session.Hint("Cutting...")
		end,
		Step = function(_dt: number)
			-- the paw drags the knife along the line while a whole bun waits
			if openedAt == nil and sentAt == nil then
				session.Paw:Show("bun_cut", {
					Kit.BunWorld(bun, BUILD.Cut.From, BUILD.Cut.Y, LIFT),
					Kit.BunWorld(bun, BUILD.Cut.To, BUILD.Cut.Y, LIFT),
				})
			else
				session.Paw:Hide()
			end
			if openedAt ~= nil then
				if os.clock() - openedAt >= OPEN_SHOW then
					if oneEnough() then
						-- the tutorial: the cut bun stays, the next step is to step back (TutorialController spots Back)
						session.Hint("Bun cut! Press Back")
						return
					end
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
		Stop = function()
			session.Progress(nil)
		end,
	}
end

return table.freeze(Board)
