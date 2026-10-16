--!strict
-- World/Director3D: which gesture the 3D Board and Toppings sections listen to now, and what each one does (docs/tech/prep-3d.md §2.3,
-- §3.3, §3.4; TASK-204, 205). The same job as Stages/Build/Director in 2D, with the same measures and the same Grade, but the region
-- the gestures read is the TOP OF THE BUN seen through the camera (World/Plane, a PlaneRegion in the bun space 0..1), so
-- slice, place, trace, slide, taps, hold and Score never learn that the board became 3D. One MODE at a time (a string, so the arms
-- are rebuilt only when it changes, never in the middle of a gesture):
--   slice / slice_hold       the knife along the dashed line (hold: the knife runs by itself, the pointer only chooses the height)
--   trace:K / trace_hold:K   a sauce bottle over the zig-zag (hold: pour along the path, let go at the mark). trace:K is SELECT, THEN DRAG:
--                            Selected (the bottle floats over the bun following the pointer, nothing flows) -> press over the plane
--                            of the bun and move past Stroke.Threshold = Pouring (the points go to Strokes) -> release stops the flow
--                            and KEEPS the selection for new strokes -> the topping lands when the guide is covered / the meter is
--                            full on release, or when it is deselected with enough sauce (tap the bowl again, Esc, press on empty
--                            space, Next). `IsPrecisionActive` tells the camera the player is in a precision gesture.
--   slide:K / slide_hold:K   the cheese slice onto the groove
--   taps:K                   the bacon rings, one tap each as they close
--   hold:K                   the potato sticks mound, let go at the ring
-- The sausage is not here: it is dragged from the rail by the World aim (Stages/Build) and measured with `MeasurePlace`.
-- It tells the stage what happened through the callbacks of `Options` and draws only through BoardView, ToolView and Strokes.
-- No Modux, no Vide, no network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Gestures = require(script.Parent.Parent.Gestures)
local Geometry = require(script.Parent.Parent.Gestures.Geometry)
local Score = require(script.Parent.Parent.Gestures.Score)
local hold = require(script.Parent.Parent.Gestures.hold)
local place = require(script.Parent.Parent.Gestures.place)
local slice = require(script.Parent.Parent.Gestures.slice)
local slide = require(script.Parent.Parent.Gestures.slide)
local taps = require(script.Parent.Parent.Gestures.taps)
local trace = require(script.Parent.Parent.Gestures.trace)
local Pointer = require(script.Parent.Parent.Pointer)
local BoardView = require(script.Parent.BoardView)
local Ghost = require(script.Parent.Ghost)
local Plane = require(script.Parent.Plane)
local Ray = require(script.Parent.Ray)
local Strokes = require(script.Parent.Strokes)
local ToolView = require(script.Parent.ToolView)
local Types = require(script.Parent.Types)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)
local Haptics = require(StarterPlayer.StarterPlayerScripts.client.Input.Haptics)

type Event = Gestures.Event

export type Options = {
	Folder: Folder,
	Gestures: Gestures.Recogniser,
	Pointer: Pointer.Pointer,
	View: BoardView.View,
	Tool: ToolView.Tool,
	Strokes: Strokes.Strokes,
	Assist: () -> boolean,
	-- plays a SFX of Content.Sounds at a point (nil = silent)
	Sfx: (key: string, at: Vector3?) -> (),
	-- the results
	OnCut: (score: number) -> (),
	-- path = the sauce strokes as drawn, in bun space (trace only; the hot dog keeps the line, owner request 2026-10-14)
	OnTopping: (key: string, score: number, amount: number, path: { { Vector2 } }?) -> (),
	-- The selected sauce asks to be put down (Esc, a press on empty space): the stage clears the active tool.
	Deselect: () -> (),
	-- The pointer went down on a world target (a bowl, the board...): not an empty press.
	OverTarget: () -> boolean,
	-- The plate can still take the topping (open, placed, no Finish on its way): a selection left behind lands only then.
	CanLand: () -> boolean,
	-- A gesture that did not land, said to the player (toast + error sound; owner report 2026-10-14: no silent refusal)
	Refuse: (text: string) -> (),
}

export type Director = {
	-- Re-arms the gestures for a mode ("none" disarms). `held` = the press that picked the tool is still down: the gesture goes on.
	SetMode: (self: Director, mode: string, held: boolean) -> (),
	Mode: (self: Director) -> string,
	-- A gesture is in progress (the stage keeps the tool in the hand).
	Busy: (self: Director) -> boolean,
	-- The player is in a precision gesture (a sauce selected or pouring, the knife armed or cutting, a drag in progress): the pan and
	-- the edge scroll of the camera must stand still.
	IsPrecisionActive: (self: Director) -> boolean,
	-- "Idle" | "Selected" | "Pouring" | "Cutting" (the sauce flow state machine, for the HUD and the tests).
	State: (self: Director) -> string,
	-- Lands the selected sauce now if it has enough on the plate (true when it landed). Next calls it before PrepFinish.
	Commit: (self: Director) -> boolean,
	-- The measure of a sausage drop (bun-space samples): the score 0..100 and whether it is inside the magnet, nil = not a drop.
	MeasurePlace: (self: Director, points: { Vector2 }) -> (number?, boolean),
	-- Is a screen point (px) over the mat (the bun and a margin)? Where a gesture may begin.
	Inside: (self: Director, px: Vector2) -> boolean,
	-- The pointer in the bun space and in the world, nil when the ray misses the plane.
	Aim: (self: Director) -> (Vector2?, Vector3?),
	-- Per frame: the knife and the tool follow the pointer.
	Frame: (self: Director, dt: number) -> (),
	Destroy: (self: Director) -> (),
}

const cfg = Content.Prep
const build = cfg.Build
const rows = cfg.Gestures.ByKey
const SAMPLE_GAP = 1 / 30 -- s between the samples of a hold-mode knife
const SETTLE = 3 -- samples a slide settles over
const BACON_RESULT_DELAY = 0.35 -- s the last ring stays on screen before the topping lands
const SQUIRT_EVERY = 0.45 -- s between the squirt sounds of a pour
const GROOVE = Vector2.new(build.Groove.X, build.Groove.Y)

-- `/dev prep ray` (player attribute PrepRay) narrates the gestures in the client output.
local function note(text: string)
	if game:GetService("Players").LocalPlayer:GetAttribute("PrepRay") == true then
		print(`[prep gesture] {text}`)
	end
end

const Director3D = {}

-- Every live director (one per Build session): the camera pan (PrepController/Pan.luau) asks the module, not a session.
const live: { [any]: boolean } = {}

-- A precision gesture is on in any live director (the pan and the edge scroll stand still).
function Director3D.IsPrecisionActive(): boolean
	for director in live do
		if (director :: Director):IsPrecisionActive() then
			return true
		end
	end
	return false
end

-- A tool is armed in any live director (a mode other than "none"): a press on empty space must not start a pan.
function Director3D.IsArmed(): boolean
	for director in live do
		if (director :: Director):Mode() ~= "none" or (director :: Director):IsPrecisionActive() then
			return true
		end
	end
	return false
end

function Director3D.new(options: Options): Director
	const gestures = options.Gestures
	const pointer = options.Pointer
	const view = options.View
	const tool = options.Tool
	const strokes = options.Strokes
	const plane = view.Plane
	const aspect = Plane.Aspect(plane)
	const rules = cfg.Rules.World
	const ringRules = rules.Toppings.Ring

	local mode = "none"
	local arms: { Gestures.Arm } = {}
	local undo: { () -> () } = {}
	local pressed = false -- a gesture is in progress
	local pouring = false
	local rumbling = false -- the pour haptic is on (follows `pouring` in Frame)
	-- the selected sauce (trace:K, drag mode): what to do with it when the mode ends
	local selection: { Commit: () -> boolean, Leave: (canLand: boolean) -> (), Active: () -> boolean }? = nil
	local lastX = 0
	local lean = 0
	local lastSquirt = 0

	-- rings (bacon, potato target) on an invisible anchor lying on the bun top
	const anchor = Instance.new("Part")
	anchor.Name = "PlateAnchor"
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.CFrame = plane.Frame
	anchor.Parent = options.Folder
	const rings: { CylinderHandleAdornment } = {}
	for _ = 1, build.Bacon.Count + 1 do
		const ring = Instance.new("CylinderHandleAdornment")
		ring.Name = "PrepRing"
		ring.Adornee = anchor
		ring.Height = 0.03
		ring.Transparency = 1
		ring.Color3 = Theme.Color.Mustard
		ring.AlwaysOnTop = false
		ring.ZIndex = 2
		ring.Parent = options.Folder
		table.insert(rings, ring)
	end

	local function setRing(index: number, uv: Vector2?, radius: number, color: Color3, alpha: number)
		const ring = rings[index]
		if uv == nil then
			ring.Transparency = 1
			return
		end
		const local_ = Vector3.new((uv.X - 0.5) * plane.Length, 0.12, (uv.Y - 0.5) * plane.Width)
		ring.Radius = radius
		ring.InnerRadius = math.max(radius - ringRules.Thick * view.Scale * 0.5, 0.02)
		ring.Color3 = color
		ring.Transparency = alpha
		ring.CFrame = CFrame.new(local_) * CFrame.Angles(math.pi / 2, 0, 0)
	end

	local function clearRings()
		for index in rings do
			setRing(index, nil, 0, Theme.Color.Mustard, 1)
		end
	end

	-- regions ---------------------------------------------------------------------------------------------------------------------
	local function rayOf(px: Vector2): (Vector3?, Vector3?)
		const camera = workspace.CurrentCamera
		if camera == nil then
			return nil, nil
		end
		return Ray.Of(camera, px, pointer.Device)
	end
	const bunRegion: Types.PlaneRegion = Plane.Region(plane, rayOf)
	-- the mat: the bun and a margin all round (a stroke may begin off the bun); the points stay in the bun space
	const matRegion: Types.PlaneRegion = {
		Inside = function(px: Vector2): boolean
			const uv = bunRegion.Normalise(px)
			const origin = rayOf(px)
			return origin ~= nil and uv.X >= -0.6 and uv.X <= 1.6 and uv.Y >= -1.2 and uv.Y <= 2.2 and (uv.X ~= 0 or uv.Y ~= 0)
		end,
		Normalise = bunRegion.Normalise,
		Aspect = bunRegion.Aspect,
	}

	-- where the sauce records: the plane of the bun and a thin margin (never the tray or the menu)
	const margin = rules.Toppings.Stroke.Margin
	local function inRecord(uv: Vector2): boolean
		return (uv.X ~= 0 or uv.Y ~= 0) and uv.X >= -margin.X and uv.X <= 1 + margin.X and uv.Y >= -margin.Y and uv.Y <= 1 + margin.Y
	end
	const recordRegion: Types.PlaneRegion = {
		Inside = function(px: Vector2): boolean
			return rayOf(px) ~= nil and inRecord(bunRegion.Normalise(px))
		end,
		Normalise = bunRegion.Normalise,
		Aspect = bunRegion.Aspect,
	}

	local function disarm()
		for _, arm in arms do
			arm:Cancel()
		end
		table.clear(arms)
		for _, fn in undo do
			fn()
		end
		table.clear(undo)
		pressed = false
		pouring = false
		selection = nil
		strokes:Drop()
		strokes:SetDots(nil)
		clearRings()
		view:SetGuide(false, 0)
		view:SetProgress(nil)
		view:SetKnife(nil, false, 0)
		tool:Move(nil, false, 0)
	end

	local function add(arm: Gestures.Arm)
		table.insert(arms, arm)
	end

	-- slice -------------------------------------------------------------------------------------------------------------------------
	local function sliceParams(): slice.Params
		return { Aspect = aspect, Y = build.Cut.Y, From = build.Cut.From, To = build.Cut.To, MinPoints = rows.slice.MinPoints }
	end

	local function armSlice(holdMode: boolean)
		const cut = build.Cut
		local done = false
		local reached = 0
		local samples: { { X: number, Y: number } } = {}
		local lastSample = 0

		local function reset()
			pressed = false
			view:SetGuide(true, 0)
			view:SetProgress(nil)
		end
		local function complete(points: { any })
			done = true
			pressed = false
			const score = Score.Value(cfg, "bun_cut", slice.Measure(points, sliceParams()), nil, options.Assist())
			view:SetGuide(false, 1)
			view:SetProgress(1)
			options.Sfx("bun_slice", plane.Frame.Position)
			options.OnCut(score)
		end
		local function begin()
			reached = 0
			table.clear(samples)
			lastSample = 0
			pressed = true
			view:SetGuide(true, 0)
		end
		view:SetGuide(true, 0)

		if not holdMode then
			add(gestures:Arm("Drag", bunRegion, { Row = "slice", Start = bunRegion }, function(event: Event)
				note(`slice {event.Phase} x {string.format("%.3f", event.Position.X)} y {string.format("%.3f", event.Position.Y)}`)
				if done then
					return
				end
				if event.Phase == "Begin" then
					begin()
				elseif event.Phase == "Move" then
					const progress = math.clamp((event.Position.X - cut.From) / (cut.To - cut.From), 0, 1)
					if progress > reached then
						reached = progress
						view:SetGuide(true, progress)
						view:SetProgress(progress)
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
		add(gestures:Arm("Hold", bunRegion, { Hold = cut.Hold, Start = bunRegion }, function(event: Event)
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
					view:SetGuide(true, event.Progress)
					view:SetProgress(event.Progress)
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

	-- place (the sausage; the stage feeds the samples) ---------------------------------------------------------------------------
	const placeParams: place.Params = { Aspect = aspect, X = build.Groove.X, Y = build.Groove.Y, MinPoints = rows.place.MinPoints }

	-- toppings --------------------------------------------------------------------------------------------------------------------
	local function traceParams(): trace.Params
		return { Aspect = aspect, Path = build.Sauce.Path, Reach = build.Sauce.Reach, Spill = build.Sauce.Spill }
	end

	-- the guide dots of the zig-zag in the bun space, a dot every Rules.World.Toppings.Dot.Step bun heights
	local function guideDots(): { Vector2 }
		const path = Geometry.Samples(Geometry.Space(build.Sauce.Path :: any, aspect), rules.Toppings.Dot.Step)
		const dots: { Vector2 } = {}
		for index = 1, #path.xs do
			table.insert(dots, Vector2.new(path.xs[index] / aspect, path.ys[index]))
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

	local function squirt()
		const now = os.clock()
		if now - lastSquirt >= SQUIRT_EVERY then
			lastSquirt = now
			options.Sfx("topping_squirt", tool:Tip())
		end
	end

	-- select, then drag (owner decision 2026-10-12) ----------------------------------------------------------------------------------
	local function armPour(key: string)
		const stroke = rules.Toppings.Stroke
		const meter = build.Sauce.Meter
		const params = traceParams()
		const minStep = 0.012 -- bun heights between two recorded points
		strokes:SetDots(guideDots())
		tool:SetFill(1)
		const segments: { { Vector2 } } = {} -- the strokes already lifted
		local points: { Vector2 }? = nil -- the stroke being poured
		local down = false
		local flowing = false -- the threshold was passed in this press
		local ended = false
		local alive = true
		local pressUv = Vector2.zero
		local pressWorld = Vector3.zero

		local function amount(): number
			local total = trace.AmountAll(segments :: { { any } }, params)
			if points ~= nil and #points >= 2 then
				total += trace.Amount(points, params)
			end
			return total
		end
		local function closeSegment()
			if points ~= nil then
				strokes:Keep()
				if #points >= 2 then
					table.insert(segments, points)
				end
				points = nil
			end
			pouring = false
		end
		local function land()
			ended = true
			alive = false
			pressed = false
			pouring = false
			down = false
			const coverage, excess = trace.MeasureAll(segments :: { { any } }, params)
			strokes:SetDots(nil)
			tool:SetFill(0)
			options.OnTopping(
				key,
				Score.Value(cfg, key, coverage, excess, options.Assist()),
				math.clamp(coverage / 100, 0.25, 1),
				table.clone(segments)
			)
		end
		local function commit(): boolean
			if ended then
				return false
			end
			closeSegment()
			if #segments > 0 and amount() >= stroke.MinAmount then
				land()
				return true
			end
			-- too little to count: the stroke is taken back, the tool goes
			strokes:Remove(key)
			strokes:SetDots(nil)
			ended = true
			alive = false
			return false
		end
		selection = {
			Commit = commit,
			Active = function(): boolean
				return not ended
			end,
			Leave = function(canLand: boolean)
				if ended then
					return
				end
				if canLand then
					commit()
				else
					closeSegment()
					strokes:Remove(key)
					ended = true
					alive = false
				end
			end,
		}

		-- one more point of the stroke: the points between it and the last are fed so a fast hand covers the guide and shapes the curve
		local function extend(uv: Vector2)
			const list = points :: { Vector2 }
			const last = list[#list]
			const dx, dy = (uv.X - last.X) * aspect, uv.Y - last.Y
			const distance = math.sqrt(dx * dx + dy * dy)
			if distance < minStep then
				return
			end
			const pieces = math.max(1, math.ceil(distance / 0.02))
			for piece = 1, pieces do
				const point = last:Lerp(uv, piece / pieces)
				strokes:Add(point)
				strokes:Cover({ point }, build.Sauce.Reach, aspect)
			end
			table.insert(list, uv)
		end
		local function openSegment(from: Vector2)
			strokes:Begin(Strokes.ColorOf(key), key)
			points = { from }
			strokes:Add(from)
			pouring = true
			squirt()
		end
		local function refresh()
			tool:SetFill(1 - math.clamp(amount() / meter.Max, 0, 1))
		end

		add(gestures:Arm("Drag", bunRegion, { Start = recordRegion }, function(event: Event)
			if ended then
				return
			end
			const uv = event.Position
			if event.Phase == "Begin" then
				down = true
				flowing = false
				pressed = true
				pressUv = uv
				pressWorld = Plane.ToWorld(plane, uv, 0)
				note(`pour press x {string.format("%.3f", uv.X)} y {string.format("%.3f", uv.Y)}`)
			elseif event.Phase == "Move" then
				if not down then
					return
				end
				const inside = inRecord(uv)
				const room = amount() < meter.Max
				if not flowing then
					if inside and room and (Plane.ToWorld(plane, uv, 0) - pressWorld).Magnitude >= stroke.Threshold then
						flowing = true
						openSegment(pressUv)
						note("pouring")
					else
						return
					end
				end
				if inside and room then
					if points == nil then
						-- came back over the bun in the same press: a new stroke from here
						openSegment(uv)
					end
					extend(uv)
					squirt()
					refresh()
				elseif points ~= nil then
					closeSegment()
					refresh()
				end
			else
				-- End / Cancel: the flow stops, the selection stays
				const was = flowing
				down = false
				flowing = false
				pressed = false
				closeSegment()
				if event.Phase == "End" and was then
					refresh()
					note(`pour end amount {string.format("%.2f", amount())} progress {string.format("%.2f", strokes:Progress())}`)
					if amount() >= meter.Max - 0.01 or strokes:Progress() >= stroke.Done then
						land()
					end
				end
			end
		end))

		-- put the sauce down: a press on empty space (not on a bowl or the bun plane) or Escape
		table.insert(undo, pointer:OnDown(function(px: Vector2)
			task.defer(function()
				if not alive or ended then
					return
				end
				if recordRegion.Inside(px) or options.OverTarget() then
					return
				end
				note("deselect: empty press")
				options.Deselect()
			end)
		end))
		const keys = UserInputService.InputBegan:Connect(function(input: InputObject)
			if input.KeyCode == Enum.KeyCode.Escape and alive and not ended then
				note("deselect: escape")
				options.Deselect()
			end
		end)
		table.insert(undo, function()
			alive = false
			keys:Disconnect()
		end)
	end

	local function armTrace(key: string, holdMode: boolean, held: boolean)
		strokes:SetDots(guideDots())
		const meter = build.Sauce.Meter
		local ended = false
		local drawn = 0 -- points already drawn of the stroke
		local function land(coverage: number, excess: number, amount: number)
			ended = true
			pressed = false
			pouring = false
			strokes:Keep()
			strokes:SetDots(nil)
			view:SetProgress(1)
			tool:SetFill(0)
			-- hold mode pours along the guide: the line is the path up to where it stopped
			options.OnTopping(
				key,
				Score.Value(cfg, key, coverage, excess, options.Assist()),
				math.clamp(coverage / 100, 0.25, 1),
				{ pathUpTo(amount) }
			)
		end
		local function clear()
			pressed = false
			pouring = false
			strokes:Drop()
			strokes:SetDots(guideDots())
			view:SetProgress(nil)
			tool:SetFill(1)
			drawn = 0
		end
		if not holdMode then
			armPour(key)
			return
		end
		-- hold: the sauce pours along the path (amount = progress x Meter.Max); let go at the mark
		add(gestures:Arm("Hold", bunRegion, { Hold = build.Sauce.Fill, Start = matRegion, Held = held }, function(event: Event)
			if ended then
				return
			end
			if event.Phase == "Begin" or event.Phase == "Move" then
				pressed = true
				pouring = true
				const amount = event.Progress * meter.Max
				strokes:Drop()
				strokes:Begin(Strokes.ColorOf(key))
				for _, point in pathUpTo(amount) do
					strokes:Add(point)
				end
				strokes:Cover(pathUpTo(amount), build.Sauce.Reach, aspect)
				view:SetProgress(strokes:Progress())
				tool:SetFill(1 - math.clamp(amount / meter.Max, 0, 1))
				squirt()
				if event.Done then
					const coverage, excess = trace.Poured(meter.Max)
					land(coverage, excess, meter.Max)
				end
			elseif event.Phase == "End" and event.Duration >= build.MinHold then
				const coverage, excess = trace.Poured(event.Progress * meter.Max)
				land(coverage, excess, event.Progress * meter.Max)
			else
				clear()
			end
		end))
	end

	local function slideParams(): slide.Params
		return { Aspect = aspect, X = build.Groove.X, Y = build.Groove.Y, MinPoints = rows.slide.MinPoints, Settle = SETTLE }
	end

	-- The point of a model topping's release is on the bun (a little slack round the edge): it lands there, graded by distance
	local function onBun(uv: Vector2): boolean
		const slack = build.DropSlack
		return uv.X >= -slack and uv.X <= 1 + slack and uv.Y >= -slack and uv.Y <= 1 + slack
	end

	local function armSlide(key: string, holdMode: boolean, held: boolean)
		local ended = false
		local function land(points: { any })
			const error = slide.Measure(points, slideParams())
			pressed = false
			-- owner report 2026-10-14 (the cheese "does not go"): a drop anywhere on the bun lands, snapped to the groove; inside the
			-- Magnet it is the precise one, farther out the distance only lowers the grade
			ended = true
			const score = Score.Value(cfg, key, error, nil, options.Assist())
			note(`slide land error {string.format("%.1f", error)} magnet {build.Magnet} score {score}`)
			tool:Set("None", "")
			view:SetTopping(key, GROOVE, 1)
			options.Sfx("hotdog_assemble", plane.Frame.Position)
			options.OnTopping(key, score, 1)
		end
		if not holdMode then
			add(gestures:Arm("Drag", bunRegion, { Row = "slide", Start = matRegion, Held = held }, function(event: Event)
				if ended then
					return
				end
				if event.Phase == "Begin" then
					pressed = true
				elseif event.Phase == "End" then
					pressed = false
					const points = table.clone((event.Points or {}) :: { any })
					if onBun(event.Position) then
						-- a click without drag (too few samples for the slide row) lands at the click: tap-to-add
						while #points < rows.slide.MinPoints do
							table.insert(points, event.Position)
						end
						land(points)
					elseif event.Length > build.DragMin then
						-- dragged and let go off the bun: say so (a plain click on a bowl only selects, silently)
						options.Refuse(build.Texts.DropOnBun)
					end
				elseif event.Phase ~= "Move" then
					pressed = false
				end
			end))
			return
		end
		local settled = false
		add(gestures:Arm("Hold", bunRegion, { Hold = build.HoldPlace, Start = matRegion, Held = held }, function(event: Event)
			if event.Phase == "End" or event.Phase == "Cancel" then
				if event.Phase == "End" and not ended and not settled and event.Inside then
					-- let go before the slice settled: say how (no silent miss)
					options.Refuse(build.Texts.HoldLonger)
				end
				settled = false
				pressed = false
				return
			end
			if ended or settled then
				return
			end
			pressed = true
			if event.Done then
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
		const radius = ringRules.Radius * view.Scale
		local function land()
			if landed then
				return
			end
			landed = true
			task.delay(BACON_RESULT_DELAY, function()
				if alive then
					clearRings()
					tool:Set("None", "")
					view:SetTopping(key, GROOVE, 1)
					options.Sfx("hotdog_assemble", plane.Frame.Position)
					options.OnTopping(key, Score.Value(cfg, key, taps.Measure(ideal, tapped, params), nil, options.Assist()), 1)
				end
			end)
		end
		local connection: RBXScriptConnection? = nil
		connection = RunService.Heartbeat:Connect(function()
			if anchor.Parent == nil then
				alive = false
				if connection ~= nil then
					connection:Disconnect()
				end
				return
			end
			const now = os.clock()
			if index <= bacon.Count and now > ideal[index] + bacon.Late then
				-- nobody tapped it: a miss (nil), on to the next ring
				index += 1
			end
			for ring = 1, bacon.Count do
				const uv = Vector2.new(bacon.X[ring] or 0.5, bacon.Y)
				if ring < index then
					const got = tapped[ring] ~= nil
					setRing(ring, uv, radius, if got then Theme.Color.Green else Theme.Color.Cream, if got then 0.3 else 0.7)
				elseif now >= starts[ring] then
					const phase = math.clamp((now - starts[ring]) / bacon.Shrink, 0, 1)
					setRing(ring, uv, radius * (1 + 1.4 * (1 - phase)), Theme.Color.Mustard, 0.15)
				else
					setRing(ring, nil, 0, Theme.Color.Mustard, 1)
				end
			end
			if index > bacon.Count then
				land()
			end
		end)
		table.insert(undo, function()
			alive = false
			if connection ~= nil then
				connection:Disconnect()
			end
		end)
		add(gestures:Arm("Tap", bunRegion, { Start = matRegion }, function(event: Event)
			if event.Phase ~= "End" or index > bacon.Count then
				return
			end
			const pressedAt = os.clock() - event.Duration
			-- before the first ring shows nothing counts (a stray tap on the way in)
			if pressedAt < starts[index] - 0.15 then
				return
			end
			tapped[index] = pressedAt
			Fx.Burst(Plane.ToWorld(plane, Vector2.new(bacon.X[index] or 0.5, bacon.Y), 0.3), "Ready", 3, Theme.Color.Cream)
			index += 1
			view:SetProgress(math.clamp((index - 1) / bacon.Count, 0, 1))
		end))
	end

	local function armHold(key: string, held: boolean)
		const potato = build.Potato
		const radius = 0.94 * view.Scale * potato.Target * 0.5
		local ended = false
		local function show(progress: number)
			const grow = rules.Toppings.Potato.From + (1 - rules.Toppings.Potato.From) * progress
			view:SetTopping(key, GROOVE, grow)
			view:SetProgress(progress)
		end
		local function land(progress: number)
			ended = true
			pressed = false
			clearRings()
			tool:Set("None", "")
			options.OnTopping(key, Score.Value(cfg, key, hold.Measure(progress, { Target = potato.Target }), nil, options.Assist()), 1)
		end
		-- the target ring: the mound grows until it touches it
		setRing(#rings, GROOVE, radius, Theme.Color.Mustard, 0.2)
		add(gestures:Arm("Hold", bunRegion, { Hold = potato.Fill, Start = matRegion, Held = held }, function(event: Event)
			if ended then
				return
			end
			if event.Phase == "Begin" or event.Phase == "Move" then
				pressed = true
				show(event.Progress)
				if event.Done then
					land(1)
				end
			elseif event.Phase == "End" and event.Duration >= build.MinHold then
				land(event.Progress)
			else
				pressed = false
				view:SetTopping(key, nil, 0)
				if event.Phase == "End" and event.Inside then
					-- a click on the bun: the potato sticks need a hold (no silent miss)
					options.Refuse(build.Texts.HoldLonger)
				end
			end
		end))
	end

	-- mode ------------------------------------------------------------------------------------------------------------------------
	const self = {} :: any

	function self.SetMode(_: any, wanted: string, held: boolean)
		if wanted == mode then
			return
		end
		-- a sauce selected and left behind lands (or is taken back) before the arms go
		if selection ~= nil then
			const leaving = selection
			selection = nil
			leaving.Leave(options.CanLand())
		end
		disarm()
		mode = wanted
		note(`mode {wanted} held {tostring(held)}`)
		const name, found = string.match(wanted, "^([%w_]+):?(.*)$")
		const key = found or ""
		if name == "slice" or name == "slice_hold" then
			armSlice(name == "slice_hold")
		elseif name == "trace" or name == "trace_hold" then
			armTrace(key, name == "trace_hold", held)
		elseif name == "slide" or name == "slide_hold" then
			armSlide(key, name == "slide_hold", held)
		elseif name == "taps" then
			armTaps(key)
		elseif name == "hold" then
			armHold(key, held)
		end
	end

	function self.Mode(_: any): string
		return mode
	end

	function self.Busy(_: any): boolean
		return pressed
	end

	function self.IsPrecisionActive(_: any): boolean
		return pressed or (selection ~= nil and selection.Active()) or string.sub(mode, 1, 5) == "slice"
	end

	function self.State(_: any): string
		if string.sub(mode, 1, 5) == "slice" then
			return "Cutting"
		elseif selection ~= nil and selection.Active() then
			return if pouring then "Pouring" else "Selected"
		end
		return "Idle"
	end

	function self.Commit(_: any): boolean
		if selection ~= nil then
			return selection.Commit()
		end
		return false
	end

	function self.MeasurePlace(_: any, points: { Vector2 }): (number?, boolean)
		const error = place.Measure(points :: { any }, placeParams)
		if error == math.huge then
			return nil, false
		end
		return Score.Value(cfg, "sausage_place", error, nil, options.Assist()), error <= build.Magnet
	end

	function self.Inside(_: any, px: Vector2): boolean
		return matRegion.Inside(px)
	end

	function self.Aim(_: any): (Vector2?, Vector3?)
		const camera = workspace.CurrentCamera
		if camera == nil then
			return nil, nil
		end
		const origin, direction = Ray.Of(camera, pointer.Position, pointer.Device)
		const uv, world = Plane.FromRay(plane, origin, direction)
		return uv, world
	end

	function self.Frame(_: any, _dt: number)
		anchor.CFrame = plane.Frame
		strokes:Tick(os.clock())
		const uv, world = self:Aim()
		-- touch has no hover: with the finger up the tool waits over the middle of the bun
		const visible = world ~= nil and (pointer.Device ~= "Touch" or pointer.Down)
		local point = if visible then world else nil
		if point == nil and pointer.Device == "Touch" and tool:Kind() ~= "None" then
			point = Plane.ToWorld(plane, GROOVE, 0)
		end
		if uv ~= nil then
			lean = math.clamp((uv.X - lastX) * 18, -1, 1) * 0.5 + lean * 0.5
			lastX = uv.X
		end
		const slicing = string.sub(mode, 1, 5) == "slice"
		view:SetKnife(if slicing then point else nil, pressed, lean)
		if tool:Kind() ~= "None" then
			tool:Move(point, pouring and uv ~= nil, lean)
		end
		-- the live drag (DEC-259): the knife and the topping tool in the hand, as the colleagues see them
		Ghost.Hold("knife", if slicing then "Knife" else "None", nil, point)
		Ghost.Hold("tool", tool:Kind(), tool:Key(), point)
		-- a light continuous rumble while a sauce pours (TASK-268; same on PS and Xbox, Settings Vibration)
		const rumble = pouring and tool:Kind() ~= "None"
		if rumble ~= rumbling then
			rumbling = rumble
			Haptics.Hold("Pour", rumble)
		end
	end

	function self.Destroy(_: any)
		disarm()
		mode = "none"
		Ghost.Hold("knife", "None", nil, nil)
		Ghost.Hold("tool", "None", nil, nil)
		if rumbling then
			rumbling = false
			Haptics.Hold("Pour", false)
		end
		for _, ring in rings do
			ring:Destroy()
		end
		table.clear(rings)
		anchor:Destroy()
		live[self] = nil
	end

	live[self] = true
	return self :: Director
end

return Director3D
