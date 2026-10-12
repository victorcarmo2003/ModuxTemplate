--!strict
-- Gestures: the recogniser of the focused prep mode (docs/tech/prep-mode.md §6 Gestures; FEAT-039). It turns the events of
-- Pointer.luau into four NORMALISED gestures, the only input the stages ever see (they never read UserInputService):
--   Drag   press (inside `Start`, default the region) and move; Begin, Move, End / Cancel. The knife, the sausage, a cheese
--          slice, a grabbed topping box.
--   Trace  a Drag that also keeps the path: sampled at Content.Prep.Gestures.trace.Hz (30), at most MaxPoints (64) kept (the
--          list is thinned in place, so a long stroke never grows past it). The sauce zig-zag.
--          Any Drag / Hold can keep its path too with `Options.Row` = a key of Content.Prep.Gestures (slice, place, slide...):
--          Hz, MinPoints and MaxPoints of that row. `Options.Held` starts the gesture at once when the pointer is already
--          down (a drag that began on an ingredient box and goes on over the board).
--   Tap    press and release in place (< TAP_TIME s, < TAP_SLOP px). Bacon rings, a button of the board.
--   Hold   press and keep; Progress 0..1 of `Hold` seconds, `Done` once. Potato sticks, the bin, the "hold instead of drag"
--          accessibility mode.
-- The score of a gesture lives in the modules next to this file (slice, place, trace, slide, taps, hold, Score): they take
-- the points of an Event and answer a raw error that Prep/shared/Grade turns into 0..100.
-- Every point is normalised to the `Region` GuiObject: (0, 0) its top left, (1, 1) its bottom right (it can leave 0..1 while
-- dragging past the edge; `Inside` says whether it is in). In the 3D mode (prep-3d.md §2.3, TASK-197) the region can also be a
-- PlaneRegion, the top of the bun seen through the camera (World/Plane): the same 0..1 bun space, the same events, so the
-- measures, Score and Grade do not change. The score of a gesture is NOT computed here: a stage reads the
-- event, measures its error and asks Prep/shared/Grade (TASK-176). The mode (`Assist`, hold) is the controller's business.
-- No Modux, no Vide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Content = require(ReplicatedStorage.shared.Content)
local Pointer = require(script.Parent.Pointer)
local Types = require(script.Parent.World.Types)

export type PlaneRegion = Types.PlaneRegion

-- What a gesture is armed on: a GuiObject (2D) or a plane of the 3D world.
export type Region = GuiObject | PlaneRegion

export type Kind = "Drag" | "Trace" | "Tap" | "Hold"

export type Phase = "Begin" | "Move" | "End" | "Cancel"

export type Event = {
	Kind: Kind,
	Phase: Phase,
	-- Now and at the press, normalised to the region.
	Position: Vector2,
	Origin: Vector2,
	-- Trace / a gesture with a Row: the path so far (a reused list; copy it to keep it). Other kinds: nil.
	Points: { Vector2 }?,
	-- Path length in region widths.
	Length: number,
	-- Seconds since the press.
	Duration: number,
	-- Hold: 0..1 and whether the time was reached.
	Progress: number,
	Done: boolean,
	-- Trace / a gesture with a Row: enough samples (the MinPoints of its row) to count.
	Valid: boolean,
	Inside: boolean,
}

export type Options = {
	-- Where the press must land (default: the region itself).
	Start: Region?,
	-- Hold: seconds to reach Done.
	Hold: number?,
	-- Press only counts when this returns true for the pressed point (normalised); nil = always.
	Accept: ((Vector2) -> boolean)?,
	-- Key of Content.Prep.Gestures whose Hz / MinPoints / MaxPoints sample the path (Trace defaults to "trace").
	Row: string?,
	-- Start pressed at once (at the pointer) when the pointer is down already.
	Held: boolean?,
}

export type Arm = { Cancel: (self: Arm) -> () }

export type Recogniser = {
	-- Starts listening; the handler runs on the main thread of the pointer events. One arm = one gesture at a time.
	Arm: (self: Recogniser, kind: Kind, region: Region, options: Options?, handler: (Event) -> ()) -> Arm,
	-- Cancels everything in progress (a tab change, leaving the mode).
	CancelAll: (self: Recogniser) -> (),
	Destroy: (self: Recogniser) -> (),
}

const TAP_TIME = 0.35
const TAP_SLOP = 14

const Gestures = {}

local function isPlane(region: Region): boolean
	return typeof(region) ~= "Instance"
end

-- Is the screen point (px) inside the region? A plane answers by its own ray.
local function inside(region: Region, position: Vector2): boolean
	if isPlane(region) then
		return (region :: PlaneRegion).Inside(position)
	end
	const object = region :: GuiObject
	const origin, size = object.AbsolutePosition, object.AbsoluteSize
	return position.X >= origin.X and position.X <= origin.X + size.X and position.Y >= origin.Y and position.Y <= origin.Y + size.Y
end

-- The screen point (px) in the 0..1 space of the region.
local function normalise(region: Region, position: Vector2): Vector2
	if isPlane(region) then
		return (region :: PlaneRegion).Normalise(position)
	end
	const size = (region :: GuiObject).AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return Vector2.zero
	end
	return (position - (region :: GuiObject).AbsolutePosition) / size
end

-- Region heights per region width: the factor that turns a step in normalised units into region widths (Event.Length).
local function heightPerWidth(region: Region): number
	if isPlane(region) then
		const aspect = (region :: PlaneRegion).Aspect
		return if aspect > 0 then 1 / aspect else 0
	end
	const size = (region :: GuiObject).AbsoluteSize
	return if size.X > 0 then size.Y / size.X else 0
end

-- Halves the list in place (keeps every second point and the last one): the cap of a trace.
local function thin(points: { Vector2 })
	const kept: { Vector2 } = {}
	for index = 1, #points, 2 do
		table.insert(kept, points[index])
	end
	const last = points[#points]
	if kept[#kept] ~= last then
		table.insert(kept, last)
	end
	table.clear(points)
	for _, point in kept do
		table.insert(points, point)
	end
end

function Gestures.new(pointer: Pointer.Pointer): Recogniser
	type Active = {
		Kind: Kind,
		Region: Region,
		Options: Options,
		Config: Content.PrepGesture?,
		Handler: (Event) -> (),
		Pressed: boolean,
		Origin: Vector2,
		OriginPx: Vector2,
		StartedAt: number,
		LastSample: number,
		Points: { Vector2 },
		Length: number,
		Last: Vector2,
		Done: boolean,
	}
	const arms: { Active } = {}
	const connections: { () -> () } = {}

	const rows = Content.Prep.Gestures.ByKey

	local function emit(active: Active, phase: Phase, position: Vector2, extra: { Progress: number?, Done: boolean?, Valid: boolean? }?)
		const config = active.Config
		const minimum = if config ~= nil then config.MinPoints else 0
		const keeps = active.Config ~= nil and active.Kind ~= "Tap"
		const event: Event = {
			Kind = active.Kind,
			Phase = phase,
			Position = position,
			Origin = active.Origin,
			Points = if keeps then active.Points else nil,
			Length = active.Length,
			Duration = os.clock() - active.StartedAt,
			Progress = if extra ~= nil and extra.Progress ~= nil then extra.Progress elseif active.Kind == "Hold" then math.clamp((os.clock() - active.StartedAt) / math.max(active.Options.Hold or 0.5, 0.05), 0, 1) else 0,
			Done = if extra ~= nil and extra.Done ~= nil then extra.Done else active.Done,
			Valid = if keeps then #active.Points >= minimum else true,
			Inside = inside(active.Region, active.OriginPx) and (position.X >= 0 and position.X <= 1 and position.Y >= 0 and position.Y <= 1),
		}
		active.Handler(event)
	end

	local function finish(active: Active, phase: Phase, position: Vector2)
		if not active.Pressed then
			return
		end
		active.Pressed = false
		emit(active, phase, position, nil)
	end

	local function sample(active: Active, position: Vector2, force: boolean)
		const config = active.Config
		const maxPoints = if config ~= nil then config.MaxPoints else 64
		const hz = if config ~= nil and config.Hz > 0 then config.Hz else 30
		const now = os.clock()
		if not force and now - active.LastSample < 1 / hz then
			return
		end
		active.LastSample = now
		table.insert(active.Points, position)
		if #active.Points > maxPoints then
			thin(active.Points)
		end
	end

	-- The press of an arm at `px` (screen px): called by a real press or by `Held` at arm time.
	local function press(active: Active, px: Vector2)
		const origin = normalise(active.Region, px)
		active.Pressed = true
		active.Origin = origin
		active.OriginPx = px
		active.Last = origin
		active.StartedAt = os.clock()
		active.LastSample = 0
		active.Length = 0
		active.Done = false
		table.clear(active.Points)
		if active.Config ~= nil and active.Kind ~= "Tap" then
			sample(active, origin, true)
		end
		if active.Kind ~= "Tap" then
			emit(active, "Begin", origin, nil)
		end
	end

	local function down(px: Vector2)
		for _, active in table.clone(arms) do
			if active.Pressed or table.find(arms, active) == nil then
				continue
			end
			const start = active.Options.Start or active.Region
			if not inside(start, px) then
				continue
			end
			if active.Options.Accept ~= nil and not active.Options.Accept(normalise(active.Region, px)) then
				continue
			end
			press(active, px)
		end
	end

	local function move(px: Vector2)
		for _, active in table.clone(arms) do
			if not active.Pressed then
				continue
			end
			const position = normalise(active.Region, px)
			active.Length += (position - active.Last).Magnitude * heightPerWidth(active.Region)
			active.Last = position
			if active.Config ~= nil and active.Kind ~= "Tap" then
				sample(active, position, false)
			end
			if active.Kind == "Drag" or active.Kind == "Trace" then
				emit(active, "Move", position, nil)
			end
		end
	end

	local function up(px: Vector2)
		for _, active in table.clone(arms) do
			if not active.Pressed then
				continue
			end
			const position = normalise(active.Region, px)
			if active.Kind == "Tap" then
				const moved = (px - active.OriginPx).Magnitude
				const quick = os.clock() - active.StartedAt <= TAP_TIME
				active.Pressed = false
				if moved <= TAP_SLOP and quick then
					emit(active, "End", position, nil)
				end
			else
				if active.Config ~= nil then
					sample(active, position, true)
				end
				finish(active, "End", position)
			end
		end
	end

	table.insert(connections, pointer:OnDown(down))
	table.insert(connections, pointer:OnMove(move))
	table.insert(connections, pointer:OnUp(up))

	-- Hold clock: only runs the loop body while some hold is pressed
	const heartbeat = RunService.Heartbeat:Connect(function()
		for _, active in table.clone(arms) do
			if active.Pressed and active.Kind == "Hold" then
				const wanted = math.max(active.Options.Hold or 0.5, 0.05)
				const progress = math.clamp((os.clock() - active.StartedAt) / wanted, 0, 1)
				const reached = progress >= 1 and not active.Done
				if reached then
					active.Done = true
				end
				emit(active, "Move", active.Last, { Progress = progress, Done = active.Done })
			end
		end
	end)

	const self = {} :: any
	function self.Arm(_: any, kind: Kind, region: Region, options: Options?, handler: (Event) -> ()): Arm
		const opts: Options = options or {}
		const row = if opts.Row ~= nil then opts.Row elseif kind == "Trace" then "trace" else nil
		const active: Active = {
			Kind = kind,
			Region = region,
			Options = opts,
			Config = if row ~= nil then rows[row] else nil,
			Handler = handler,
			Pressed = false,
			Origin = Vector2.zero,
			OriginPx = Vector2.zero,
			StartedAt = 0,
			LastSample = 0,
			Points = {},
			Length = 0,
			Last = Vector2.zero,
			Done = false,
		}
		table.insert(arms, active)
		-- a drag that began on an ingredient box goes on over the board: the press is the one already down
		if opts.Held == true and pointer.Down then
			press(active, pointer.Position)
		end
		const handle = {} :: any
		function handle.Cancel(_: any)
			finish(active, "Cancel", active.Last)
			const index = table.find(arms, active)
			if index ~= nil then
				table.remove(arms, index)
			end
		end
		return handle :: Arm
	end
	function self.CancelAll(_: any)
		for _, active in table.clone(arms) do
			finish(active, "Cancel", active.Last)
		end
	end
	function self.Destroy(_: any)
		self:CancelAll()
		table.clear(arms)
		heartbeat:Disconnect()
		for _, disconnect in connections do
			disconnect()
		end
		table.clear(connections)
	end
	return self :: Recogniser
end

return Gestures
