--!strict
-- Director: which gesture the Build board listens to now, and what each one does (docs/tech/prep-mode.md §2 b / c, §5;
-- docs/art/prep-ui-spec.md §5.3; TASK-176 / TASK-178). One MODE at a time, derived from the state of the plate:
--   slice      bun step, plate open     drag the knife along the dashed line (hold mode: hold, the knife runs by itself)
--   place      build step, no sausage   drag the sausage chip into the groove of the bun (magnet Build.Magnet %)
--   trace:K    a sauce picked           trace the zig-zag (hold mode: hold to pour, release in the green)
--   slide:K    cheese picked            slide the slice onto the bun (hold mode: hold where it goes)
--   taps:K     bacon picked             tap each ring as it closes
--   hold:K     potato sticks picked     hold, release in the green band
-- The mode is a string so the arms are rebuilt only when it changes, never in the middle of a gesture. Every gesture is
-- measured in the space of the bun (Gestures/*.luau), turned into 0..100 by Gestures/Score (the Grade of the server) and written
-- to the Session; the view-model (PlateView, StrokeCanvas, pips) shows it at once. Assist (x1.3) is read at the moment of scoring.
-- Built inside the Vide scope of the board (the effect and the cleanup die with it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Gestures = require(script.Parent.Parent.Parent.Gestures)
local Geometry = require(script.Parent.Parent.Parent.Gestures.Geometry)
local Score = require(script.Parent.Parent.Parent.Gestures.Score)
local hold = require(script.Parent.Parent.Parent.Gestures.hold)
local place = require(script.Parent.Parent.Parent.Gestures.place)
local slice = require(script.Parent.Parent.Parent.Gestures.slice)
local slide = require(script.Parent.Parent.Parent.Gestures.slide)
local taps = require(script.Parent.Parent.Parent.Gestures.taps)
local trace = require(script.Parent.Parent.Parent.Gestures.trace)
local Overlay = require(script.Parent.Overlay)
local Rail = require(script.Parent.Rail)
local Session = require(script.Parent.Session)

const untrack = Vide.untrack

type Event = Gestures.Event

const cfg = Content.Prep
const build = cfg.Build
const rows = cfg.Gestures.ByKey
const MAX = Content.OrderRules.MaxToppings
const DEFAULT_ASPECT = 3.1
const SAMPLE_GAP = 1 / 30 -- s between the samples of a hold-mode knife
const SETTLE = 3 -- samples a slice settles over
const BACON_RESULT_DELAY = 0.35 -- s the last ring stays on screen before the topping lands

export type Director = {
	-- A box was tapped (held = false) or grabbed (held = true: the press is still down, the gesture goes on from it).
	Pick: (key: string, held: boolean) -> (),
}

const Director = {}

-- The Director of the board on screen (the stage routes Pick / Grab to it).
Director.Current = nil :: Director?

function Director.Pick(key: string, held: boolean)
	const current = Director.Current
	if current ~= nil then
		current.Pick(key, held)
	end
end

local function boundsX(value: number): number
	return math.clamp(value, -0.3, 1.3)
end

local function boundsY(value: number): number
	return math.clamp(value, -1, 2)
end

function Director.Mount(ctx: Overlay.Ctx)
	const controller = ctx.Controller
	const view = controller.View
	const gestures = controller.Gestures
	const bun = ctx.Bun :: Frame
	const mat = ctx.Mat :: Frame
	local arms: { Gestures.Arm } = {}
	-- what the arm in force must undo / stop when the mode changes
	local undo: { () -> () } = {}
	local pickHeld = false
	local refusals = 0

	local function aspect(): number
		const size = bun.AbsoluteSize
		return if size.X > 0 and size.Y > 0 then size.X / size.Y else DEFAULT_ASPECT
	end

	local function assist(): boolean
		return Session.Peek(controller.Assist) == true
	end

	local function add(arm: Gestures.Arm)
		table.insert(arms, arm)
	end

	local function clearStroke()
		Vide.batch(function()
			view.Stroke({})
			view.StrokeGuide({})
			view.Meter(false)
		end)
	end

	local function disarm()
		for _, arm in arms do
			arm:Cancel()
		end
		table.clear(arms)
		for _, fn in undo do
			fn()
		end
		table.clear(undo)
		ctx.Dragging(false)
		ctx.Carry(false)
		ctx.Rings(Overlay.HiddenRings())
		clearStroke()
	end

	-- Slice (the bun step) -------------------------------------------------------------------------------------------------

	local function sliceParams(): slice.Params
		return { Aspect = aspect(), Y = build.Cut.Y, From = build.Cut.From, To = build.Cut.To, MinPoints = rows.slice.MinPoints }
	end

	local function armSlice(holdMode: boolean)
		const cut = build.Cut
		local done = false
		local reached = 0
		local samples: { { X: number, Y: number } } = {}
		local lastSample = 0

		local function reset()
			Vide.batch(function()
				view.Bun("Closed")
				view.Cut(0)
				view.Guide(true)
			end)
		end
		local function complete(points: { any })
			done = true
			const score = Score.Value(cfg, "bun_cut", slice.Measure(points, sliceParams()), nil, assist())
			Vide.batch(function()
				view.Cut(1)
				view.Bun("Open")
				view.Guide(false)
			end)
			Session.SetCut(controller, score)
		end
		local function begin()
			reached = 0
			table.clear(samples)
			lastSample = 0
			Vide.batch(function()
				view.Bun("Cut")
				view.Cut(0)
				view.Guide(true)
			end)
		end

		if not holdMode then
			add(gestures:Arm("Drag", bun, { Row = "slice", Start = bun }, function(event: Event)
				if done then
					return
				end
				if event.Phase == "Begin" then
					begin()
				elseif event.Phase == "Move" then
					const progress = math.clamp((event.Position.X - cut.From) / (cut.To - cut.From), 0, 1)
					if progress > reached then
						reached = progress
						view.Cut(progress)
					end
					if event.Position.X >= cut.Done and event.Points ~= nil then
						const points = table.clone(event.Points) :: { any }
						table.insert(points, event.Position)
						complete(points)
					end
				else
					reset()
				end
			end))
			return
		end
		-- hold: the knife runs along the line by itself in Build.Cut.Hold s; the pointer only chooses how high
		add(gestures:Arm("Hold", bun, { Hold = cut.Hold, Start = bun }, function(event: Event)
			if done then
				return
			end
			if event.Phase == "Begin" then
				begin()
			elseif event.Phase == "Move" then
				const now = os.clock()
				const x = cut.From + (cut.To - cut.From) * event.Progress
				if reached < event.Progress then
					reached = event.Progress
					view.Cut(event.Progress)
				end
				if now - lastSample >= SAMPLE_GAP then
					lastSample = now
					table.insert(samples, { X = x, Y = event.Position.Y })
				end
				if event.Done then
					table.insert(samples, { X = cut.To, Y = event.Position.Y })
					complete(samples)
				end
			else
				reset()
			end
		end))
	end

	-- Place (the sausage) --------------------------------------------------------------------------------------------------

	local function placeParams(): place.Params
		return { Aspect = aspect(), X = build.Groove.X, Y = build.Groove.Y, MinPoints = rows.place.MinPoints }
	end

	local function sausageAt(position: Vector2)
		view.Sausage({ X = boundsX(position.X), Y = boundsY(position.Y), State = "Ready" })
	end

	-- the sausage lands in the groove when the error is inside the magnet, else it goes back to the chip
	local function settleSausage(points: { any }): boolean
		const params = placeParams()
		const error = place.Measure(points, params)
		if error <= build.Magnet then
			const score = Score.Value(cfg, "sausage_place", error, nil, assist())
			view.Sausage({ X = build.Groove.X, Y = build.Groove.Y, State = "Ready" })
			Session.SetPlace(controller, score)
			return true
		end
		view.Sausage(false)
		return false
	end

	local function armPlace(holdMode: boolean)
		local done = false
		if not holdMode then
			add(gestures:Arm("Drag", bun, { Row = "place", Start = ctx.Chip }, function(event: Event)
				if done then
					return
				end
				if event.Phase == "Begin" then
					ctx.Dragging(true)
					sausageAt(event.Position)
				elseif event.Phase == "Move" then
					sausageAt(event.Position)
				elseif event.Phase == "End" then
					ctx.Dragging(false)
					if event.Valid and event.Points ~= nil then
						done = true
						settleSausage(table.clone(event.Points) :: { any })
					else
						view.Sausage(false)
					end
				else
					ctx.Dragging(false)
					view.Sausage(false)
				end
			end))
			return
		end
		-- hold: the sausage follows the finger and lands where it is after Build.HoldPlace s
		local settled = false
		add(gestures:Arm("Hold", bun, { Hold = build.HoldPlace, Start = bun }, function(event: Event)
			if event.Phase == "End" or event.Phase == "Cancel" then
				-- a miss goes back to the chip; a landed sausage stays (the mode is about to change)
				if not Session.Peek(Session.Placed) then
					view.Sausage(false)
				end
				ctx.Dragging(false)
				settled = false
				return
			end
			if settled then
				return
			end
			ctx.Dragging(true)
			sausageAt(event.Position)
			if event.Done then
				settled = true
				const points: { any } = {}
				for _ = 1, rows.place.MinPoints do
					table.insert(points, event.Position)
				end
				if not settleSausage(points) then
					ctx.Dragging(false)
				end
			end
		end))
	end

	-- Toppings -------------------------------------------------------------------------------------------------------------

	local function traceParams(): trace.Params
		return { Aspect = aspect(), Path = build.Sauce.Path, Reach = build.Sauce.Reach, Spill = build.Sauce.Spill }
	end

	-- the dotted guide of the zig-zag (bun space), a dot every ~0.06 bun heights
	local function guideDots(): { Vector2 }
		const ratio = aspect()
		const path = Geometry.Samples(Geometry.Space(build.Sauce.Path :: any, ratio), 0.08)
		const dots: { Vector2 } = {}
		for index = 1, #path.xs do
			table.insert(dots, Vector2.new(path.xs[index] / ratio, path.ys[index]))
		end
		return dots
	end

	-- the first `fraction` (0..1) of the path as points (the pour of the hold mode)
	local function pathUpTo(fraction: number): { Vector2 }
		const path = build.Sauce.Path
		const legs = #path - 1
		const position = math.clamp(fraction, 0, 1) * legs
		const points: { Vector2 } = {}
		for index = 1, #path do
			if index - 1 <= position then
				table.insert(points, Vector2.new(path[index].X, path[index].Y))
			end
		end
		const leg = math.floor(position)
		if leg < legs and position > leg then
			const alpha = position - leg
			const from, to = path[leg + 1], path[leg + 2]
			table.insert(points, Vector2.new(from.X + (to.X - from.X) * alpha, from.Y + (to.Y - from.Y) * alpha))
		end
		return points
	end

	local function showSauce(amount: number)
		const meter = build.Sauce.Meter
		view.Meter({ Fill = math.clamp(amount / meter.Max, 0, 1), Target = meter.Target, Window = meter.Window })
	end

	local function primeSauce(key: string)
		Vide.batch(function()
			view.StrokeColor(Overlay.FoodColor(key))
			view.StrokeGuide(guideDots())
			view.Stroke({})
			view.Meter(false)
		end)
	end

	local function armTrace(key: string, holdMode: boolean)
		primeSauce(key)
		local ended = false
		local function land(coverage: number, excess: number)
			ended = true
			const score = Score.Value(cfg, key, coverage, excess, assist())
			Session.AddTopping(controller, key, score, math.clamp(coverage / 100, 0.25, 1))
		end
		local function clear()
			Vide.batch(function()
				view.Stroke({})
				view.Meter(false)
			end)
		end
		if not holdMode then
			add(gestures:Arm("Trace", bun, { Start = mat, Held = pickHeld }, function(event: Event)
				if ended then
					return
				end
				if event.Phase == "Begin" then
					Vide.batch(function()
						view.Stroke({})
						showSauce(0)
					end)
				elseif event.Phase == "Move" and event.Points ~= nil then
					const points = table.clone(event.Points)
					Vide.batch(function()
						view.Stroke(points)
						showSauce(trace.Amount(points, traceParams()))
					end)
				elseif event.Phase == "End" and event.Valid and event.Points ~= nil then
					const coverage, excess = trace.Measure(event.Points, traceParams())
					land(coverage, excess)
				else
					clear()
				end
			end))
			return
		end
		-- hold: the sauce pours along the path (amount = progress x Meter.Max); release in the green window
		add(gestures:Arm("Hold", bun, { Hold = build.Sauce.Fill, Start = mat, Held = pickHeld }, function(event: Event)
			if ended then
				return
			end
			if event.Phase == "Begin" or event.Phase == "Move" then
				Vide.batch(function()
					view.Stroke(pathUpTo(event.Progress * build.Sauce.Meter.Max / 1))
					showSauce(event.Progress * build.Sauce.Meter.Max)
				end)
				if event.Done then
					const coverage, excess = trace.Poured(build.Sauce.Meter.Max)
					land(coverage, excess)
				end
			elseif event.Phase == "End" and event.Duration >= build.MinHold then
				const coverage, excess = trace.Poured(event.Progress * build.Sauce.Meter.Max)
				land(coverage, excess)
			else
				clear()
			end
		end))
	end

	local function slideParams(): slide.Params
		return { Aspect = aspect(), X = build.Groove.X, Y = build.Groove.Y, MinPoints = rows.slide.MinPoints, Settle = SETTLE }
	end

	local function armSlide(key: string, holdMode: boolean)
		local ended = false
		local function carry(position: Vector2)
			ctx.Carry({ Key = key, X = boundsX(position.X), Y = boundsY(position.Y) })
		end
		local function land(points: { any })
			const error = slide.Measure(points, slideParams())
			if error <= build.Magnet then
				ended = true
				ctx.Carry(false)
				Session.AddTopping(controller, key, Score.Value(cfg, key, error, nil, assist()), 1)
			else
				ctx.Carry(false)
			end
		end
		if not holdMode then
			add(gestures:Arm("Drag", bun, { Row = "slide", Start = mat, Held = pickHeld }, function(event: Event)
				if ended then
					return
				end
				if event.Phase == "Begin" or event.Phase == "Move" then
					carry(event.Position)
				elseif event.Phase == "End" and event.Valid and event.Points ~= nil then
					land(table.clone(event.Points) :: { any })
				else
					ctx.Carry(false)
				end
			end))
			return
		end
		local settled = false
		add(gestures:Arm("Hold", bun, { Hold = build.HoldPlace, Start = mat, Held = pickHeld }, function(event: Event)
			if event.Phase == "End" or event.Phase == "Cancel" then
				settled = false
				ctx.Carry(false)
				return
			end
			if ended or settled then
				return
			end
			carry(event.Position)
			if event.Done then
				-- a miss: the slice goes back and the next press tries again
				settled = true
				const points: { any } = {}
				for _ = 1, rows.slide.MinPoints do
					table.insert(points, event.Position)
				end
				land(points)
			end
		end))
	end

	local function armTaps(key: string)
		const bacon = build.Bacon
		const params: taps.Params = { Count = bacon.Count, Miss = bacon.Miss }
		const opened = os.clock()
		const starts: { number } = {}
		const ideal: { number } = {}
		for index = 1, bacon.Count do
			starts[index] = opened + bacon.Lead + (index - 1) * bacon.Gap
			ideal[index] = starts[index] + bacon.Shrink
		end
		const tapped: { number? } = {}
		local index = 1
		local alive = true
		local landed = false
		local function land()
			if landed then
				return
			end
			landed = true
			task.delay(BACON_RESULT_DELAY, function()
				if alive then
					Session.AddTopping(controller, key, Score.Value(cfg, key, taps.Measure(ideal, tapped, params), nil, assist()), 1)
				end
			end)
		end
		const connection = RunService.Heartbeat:Connect(function()
			const now = os.clock()
			if index <= bacon.Count and now > ideal[index] + bacon.Late then
				-- nobody tapped it: a miss (nil), on to the next ring
				index += 1
			end
			const rings = Overlay.HiddenRings()
			for ring = 1, bacon.Count do
				if ring < index then
					const state: Overlay.RingState = if tapped[ring] ~= nil then "Tapped" else "Missed"
					rings[ring] = { Scale = 1, State = state }
				elseif now >= starts[ring] then
					const phase = math.clamp((now - starts[ring]) / bacon.Shrink, 0, 1)
					rings[ring] = { Scale = 1 + 1.4 * (1 - phase), State = "Closing" }
				end
			end
			ctx.Rings(rings)
			if index > bacon.Count then
				land()
			end
		end)
		table.insert(undo, function()
			alive = false
			connection:Disconnect()
		end)
		add(gestures:Arm("Tap", bun, { Start = mat }, function(event: Event)
			if event.Phase ~= "End" or index > bacon.Count then
				return
			end
			const pressedAt = os.clock() - event.Duration
			-- before the first ring shows nothing counts (a stray tap on the way in)
			if pressedAt < starts[index] - 0.15 then
				return
			end
			tapped[index] = pressedAt
			index += 1
		end))
	end

	local function armHold(key: string)
		const potato = build.Potato
		const params: hold.Params = { Target = potato.Target }
		local ended = false
		local function show(progress: number)
			view.Meter({ Fill = progress, Target = potato.Target, Window = potato.Window })
		end
		local function land(progress: number)
			ended = true
			Session.AddTopping(controller, key, Score.Value(cfg, key, hold.Measure(progress, params), nil, assist()), 1)
		end
		Vide.batch(function()
			view.StrokeGuide({})
			view.Stroke({})
			show(0)
		end)
		add(gestures:Arm("Hold", bun, { Hold = potato.Fill, Start = mat, Held = pickHeld }, function(event: Event)
			if ended then
				return
			end
			if event.Phase == "Begin" or event.Phase == "Move" then
				show(event.Progress)
				if event.Done then
					land(1)
				end
			elseif event.Phase == "End" and event.Duration >= build.MinHold then
				land(event.Progress)
			else
				show(0)
			end
		end))
	end

	-- Mode -----------------------------------------------------------------------------------------------------------------

	const mode = Vide.derive(function(): string
		if view.Seal() ~= false or not Session.Open() or Session.Pending() == "Finish" then
			return "none"
		end
		const holdMode = Session.Hold()
		const bunState = view.Bun()
		const step = controller.Step()
		if step == "bun" then
			if bunState == "Closed" or bunState == "Cut" then
				return if holdMode then "slice_hold" else "slice"
			end
			return "none"
		end
		if step ~= "build" or bunState ~= "Open" then
			return "none"
		end
		if not Session.Placed() then
			return if Rail.Count(controller) > 0 then (if holdMode then "place_hold" else "place") else "none"
		end
		const key = Session.Active()
		if key == "" then
			return "none"
		end
		const tolerance = cfg.Tolerances.ByKey[key]
		if tolerance == nil then
			return "none"
		end
		const gesture = tolerance.Gesture
		return if holdMode and (gesture == "trace" or gesture == "slide") then `{gesture}_hold:{key}` else `{gesture}:{key}`
	end)

	local function arm(current: string)
		const name, found = string.match(current, "^([%w_]+):?(.*)$")
		const key = found or ""
		if name == "slice" or name == "slice_hold" then
			armSlice(name == "slice_hold")
		elseif name == "place" or name == "place_hold" then
			armPlace(name == "place_hold")
		elseif name == "trace" or name == "trace_hold" then
			armTrace(key, name == "trace_hold")
		elseif name == "slide" or name == "slide_hold" then
			armSlide(key, name == "slide_hold")
		elseif name == "taps" then
			armTaps(key)
		elseif name == "hold" then
			armHold(key)
		end
	end

	Vide.effect(function()
		const current = mode()
		untrack(function()
			disarm()
			arm(current)
			return nil
		end)
	end)

	-- A box of the panel: tap = the gesture waits for a press on the board, grab = it goes on from the press that is down.
	local function pick(key: string, isHeld: boolean)
		if Session.Peek(controller.Step) ~= "build" or not Session.Peek(Session.Open) or Session.Peek(view.Seal) ~= false then
			return
		end
		local function refuse(text: string)
			refusals += 1
			view.Refused({ Key = key, Id = refusals })
			controller:Toast(text, "Alert")
		end
		if not Session.Peek(Session.Placed) then
			refuse(build.Texts.PlaceFirst)
			return
		end
		if Session.Peek(view.Used)[key] == true or #Session.Toppings() >= MAX or Session.Peek(Session.Active) == key then
			return
		end
		pickHeld = isHeld and cfg.Tolerances.ByKey[key] ~= nil and cfg.Tolerances.ByKey[key].Gesture ~= "taps"
		view.Focus(key)
		Session.Active(key)
		pickHeld = false
	end

	Director.Current = { Pick = pick }

	Vide.cleanup(function()
		Director.Current = nil
		disarm()
	end)
end

return Director
