--!strict
-- World/Strokes: the sauce on the bun and the guide track of the zig-zag (docs/tech/prep-3d.md §3.4, §8, R8; TASK-205; reworked
-- 2026-10-12: the owner found the sauce "de Lego" (a chain of beads tied by bigger balls) and wanted ONE continuous, natural line).
-- A stroke is ONE smooth bead:
--   * the pointer samples (spaced so the whole zig-zag fits the per-stroke budget) go through a Catmull-Rom curve; the piece between
--     two samples is finished as soon as the next one arrives, and a HEAD piece (a chord from the end of the finished curve to the
--     pointer) shows the sauce at once, so there is no lag. Every cut of the curve is cut again into Smooth short cylinders
--   * a cylinder meets the next at a ball of the SAME diameter (Stroke.Joint = 1), so a bend is round and there is no bulge; a ball
--     also rounds the start (a cap, a little thinner) and the tip
--   * the width is almost constant: it swells in over the first stretch, breathes a little with the arc length (Stroke.Variance,
--     slow sines, never per piece) and thins smoothly at the tip when the stroke is kept (Stroke.Taper)
--   * the bead lies ON the surface: every cut of the curve is projected again on `surface(uv)` (the round back of the sausage in the
--     groove, the bun beside it) and lifted by the share of its own width that sits over it, so it does not float or sink
--   * SmoothPlastic with a slight Reflectance (Stroke.Shine): the wet shine
-- Strokes of one topping share a GROUP (its key): `Remove(group)` takes them back. The guide track is a row of thin dashes along the
-- path, oriented along it and following the surface; a soft wave of light runs along them (`Tick`) and a dash goes out when a stroke
-- covers it. `Progress` is the share of the track covered: the stage shows it live. Pools are made once (Rules.World.Budget.SaucePool
-- pieces; at most SauceSegmentsPerStroke per stroke and SauceSegmentsPerPlate per plate); nothing is created per frame.
-- No Modux, no Vide, no network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Plane = require(script.Parent.Plane)
local Theme = require(game:GetService("StarterPlayer").StarterPlayerScripts.client.Interface.Components.Theme)

export type Strokes = {
	-- Starts a stroke of this colour (a stroke already running is kept as it is); `group` names what it belongs to (a topping key).
	Begin: (self: Strokes, color: Color3, group: string?) -> (),
	-- Extends it to a bun-space point; true when a sample was taken (the budget and the step decide).
	Add: (self: Strokes, uv: Vector2) -> boolean,
	-- The stroke ends and stays on the plate (its tip thins).
	Keep: (self: Strokes) -> (),
	-- The running stroke is thrown away (a cancelled or invalid gesture).
	Drop: (self: Strokes) -> (),
	-- Takes back every KEPT stroke of a group (a deselect that did not land).
	Remove: (self: Strokes, group: string) -> (),
	-- The guide track on (list of bun-space points along the path) or off (nil).
	SetDots: (self: Strokes, dots: { Vector2 }?) -> (),
	-- The dashes the stroke points cover go out.
	Cover: (self: Strokes, points: { Vector2 }, reach: number, aspect: number) -> (),
	-- Share of the track covered, 0..1 (1 when there is no track).
	Progress: (self: Strokes) -> number,
	-- Runs the wave of light of the track (call every frame while the track shows).
	Tick: (self: Strokes, time: number) -> (),
	Count: (self: Strokes) -> number,
	-- The plate slid by `delta` (studs): every laid piece and dash goes with it.
	Shift: (self: Strokes, delta: Vector3) -> (),
	-- Everything off (the plate is gone).
	Clear: (self: Strokes) -> (),
	Destroy: (self: Strokes) -> (),
}

const Strokes = {}

const COLORS: { [string]: Color3 } = {
	ketchup = Color3.fromHex("#E2402E"),
	mustard = Color3.fromHex("#F6C12B"),
	cream_cheese = Color3.fromHex("#FFF8EA"),
}

const LIFT = 0.42 -- share of its own width the bead sits over the surface (the rest sinks into it)
const START = 0.72 -- share of the width at the very start of a stroke
const SWELL = 2.5 -- widths over which it swells in
const TAPER_LENGTH = 3 -- widths over which the tip thins

-- The colour of a sauce (food, not a UI state).
function Strokes.ColorOf(key: string): Color3
	return COLORS[key] or Color3.fromHex("#FFF8EA")
end

local function newPart(folder: Folder, name: string, ball: boolean): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Shape = if ball then Enum.PartType.Ball else Enum.PartType.Cylinder
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.1
	part.Parent = folder
	return part
end

-- Catmull-Rom between p1 and p2 (p0, p3 the neighbours) at t in 0..1
local function spline(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	const t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

local function smooth(x: number): number
	const t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

type Piece = { Tube: Part, Joint: Part, Width: number, Arc: number, Used: boolean, Group: string? }

function Strokes.new(
	folder: Folder,
	rules: Content.PrepWorldRules,
	plane: Plane.Plane,
	surface: (uv: Vector2) -> number
): Strokes
	const budget = rules.Budget
	const look = rules.Toppings.Stroke
	const dotRules = rules.Toppings.Dot
	const scale = rules.Board.Scale
	const baseWidth = look.Width * scale
	const free: { Piece } = {}
	const all: { Piece } = {}
	for _ = 1, budget.SaucePool do
		const tube = newPart(folder, "SauceTube", false)
		const joint = newPart(folder, "SauceJoint", true)
		tube.Reflectance = look.Shine
		joint.Reflectance = look.Shine
		const piece: Piece = { Tube = tube, Joint = joint, Width = baseWidth, Arc = 0, Used = false, Group = nil }
		table.insert(all, piece)
		table.insert(free, piece)
	end
	const dashes: { Part } = {}
	const dashUv: { Vector2 } = {}
	const dashOn: { boolean } = {}
	for _ = 1, 48 do
		const dash = newPart(folder, "GuideDash", false)
		dash.Material = Enum.Material.Neon
		table.insert(dashes, dash)
	end

	-- the guide path in the world, to pick a step that lets the longest stroke (Meter.Max path lengths) fit the per-stroke budget
	local pathLength = 0
	do
		const path = Content.Prep.Build.Sauce.Path
		for index = 2, #path do
			pathLength += math.sqrt(((path[index].X - path[index - 1].X) * plane.Length) ^ 2 + ((path[index].Y - path[index - 1].Y) * plane.Width) ^ 2)
		end
	end
	const pieces = math.max(look.Smooth, 1) -- cylinders per Catmull-Rom piece
	const longest = pathLength * Content.Prep.Build.Sauce.Meter.Max * 1.05
	const step = math.max(budget.SauceMinStep, longest * pieces / budget.SauceSegmentsPerStroke)

	local color = Color3.new(1, 1, 1)
	local group: string? = nil
	local running = false
	local raw: { Vector3 } = {} -- the samples of the running stroke (world, ON the surface)
	local laid = 0 -- spline pieces already finished (up to raw[laid + 1])
	local arc = 0 -- length of the finished part of the stroke
	local lastEnd = Vector3.zero -- where the finished part ends
	local pointer: Vector3? = nil -- the latest pointer point (on the surface)
	local current: { Piece } = {} -- the pieces of the running stroke (the cap first)
	local head: Piece? = nil -- the chord from the end of the finished curve to the pointer
	local plate = 0
	local covered = 0

	const self = {} :: any

	local function take(): Piece?
		const piece = table.remove(free)
		if piece ~= nil then
			piece.Used = true
			piece.Group = group
			plate += 1
		end
		return piece
	end

	local function release(piece: Piece)
		piece.Tube.Transparency = 1
		piece.Joint.Transparency = 1
		piece.Used = false
		piece.Group = nil
		plate -= 1
		table.insert(free, piece)
	end

	-- the point of the surface under (or over) a world point: the bead is projected on it again at every cut
	local function snap(point: Vector3): Vector3
		const uv = Plane.ToUV(plane, point)
		const clamped = Vector2.new(math.clamp(uv.X, -0.2, 1.2), math.clamp(uv.Y, -0.35, 1.35))
		return Plane.ToWorld(plane, clamped, surface(clamped))
	end

	-- width at an arc length: swells in, breathes slowly (a function of the arc, so two pieces side by side agree)
	local function widthAt(at: number): number
		const swell = smooth(at / (baseWidth * SWELL))
		const breath = 1 + look.Variance * (0.6 * math.sin(at * 4.8) + 0.4 * math.sin(at * 2.1 + 1.3))
		return baseWidth * (START + (1 - START) * swell) * breath
	end

	-- puts a piece from `from` to `to` (both ON the surface): a cylinder and the ball at its end
	local function setPiece(piece: Piece, from: Vector3, to: Vector3, width: number)
		const lift = plane.Frame.UpVector * (width * LIFT)
		const a, b = from + lift, to + lift
		piece.Width = width
		piece.Tube.Size = Vector3.new(math.max((b - a).Magnitude, 0.001), width, width)
		piece.Tube.Color = color
		if (b - a).Magnitude > 1e-4 then
			piece.Tube.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
			piece.Tube.Transparency = 0
		else
			piece.Tube.Transparency = 1
		end
		piece.Joint.Size = Vector3.one * width * look.Joint
		piece.Joint.Color = color
		piece.Joint.Position = b
		piece.Joint.Transparency = 0
	end

	local function lay(from: Vector3, to: Vector3): boolean
		if #current >= budget.SauceSegmentsPerStroke or plate >= budget.SauceSegmentsPerPlate then
			return false
		end
		const length = (to - from).Magnitude
		if length < 1e-4 then
			return false
		end
		const piece = take()
		if piece == nil then
			return false
		end
		setPiece(piece, from, to, widthAt(arc + length / 2))
		arc += length
		piece.Arc = arc
		table.insert(current, piece)
		return true
	end

	-- finishes the spline piece between raw[n] and raw[n + 1] (neighbours raw[n - 1] and raw[n + 2], doubled at the ends)
	local function finishPiece(n: number, last: boolean)
		const p1, p2 = raw[n], raw[n + 1]
		if p1 == nil or p2 == nil then
			return
		end
		const p0 = raw[n - 1] or p1
		const p3 = raw[n + 2] or (if last then p2 + (p2 - p1) * 0.3 else p2)
		for cut = 1, pieces do
			const point = if cut == pieces then snap(p2) else snap(spline(p0, p1, p2, p3, cut / pieces))
			if not lay(lastEnd, point) then
				return
			end
			lastEnd = point
		end
	end

	-- the head follows the pointer: a chord from the end of the finished curve (no lag, short)
	local function placeHead(to: Vector3)
		if head == nil then
			head = take()
		end
		const piece = head
		if piece == nil then
			return
		end
		const length = (to - lastEnd).Magnitude
		if length < 1e-4 then
			piece.Tube.Transparency = 1
			piece.Joint.Transparency = 1
			return
		end
		setPiece(piece, lastEnd, to, widthAt(arc + length / 2))
		piece.Arc = arc + length
	end

	local function dropHead()
		if head ~= nil then
			release(head)
			head = nil
		end
	end

	function self.Begin(_: any, wanted: Color3, name: string?)
		if running then
			self:Keep()
		end
		color = wanted
		group = name
		running = true
		table.clear(raw)
		table.clear(current)
		laid = 0
		arc = 0
		pointer = nil
		head = nil
	end

	function self.Add(_: any, uv: Vector2): boolean
		if not running then
			return false
		end
		const clamped = Vector2.new(math.clamp(uv.X, -0.2, 1.2), math.clamp(uv.Y, -0.35, 1.35))
		const world = Plane.ToWorld(plane, clamped, surface(clamped))
		pointer = world
		const count = #raw
		if count == 0 then
			table.insert(raw, world)
			lastEnd = world
			-- the rounded start: a ball (the tube of this piece stays hidden)
			const cap = take()
			if cap ~= nil then
				setPiece(cap, world, world, widthAt(0))
				cap.Tube.Transparency = 1
				cap.Arc = 0
				table.insert(current, cap)
			end
			return true
		end
		const taken = (world - raw[count]).Magnitude >= step
		if taken then
			table.insert(raw, world)
			const total = count + 1
			-- a light average of the sample before (the hand is not a machine)
			if total >= 3 then
				raw[total - 1] = raw[total - 2] * 0.25 + raw[total - 1] * 0.5 + raw[total] * 0.25
			end
			-- the piece two samples back is finished now that its far neighbour is known
			const n = total - 2
			if n >= 1 then
				finishPiece(n, false)
				laid = n
			end
		end
		placeHead(world)
		return taken
	end

	-- the tip thins smoothly over the last stretch of the stroke
	local function taper()
		const total = arc
		const length = baseWidth * TAPER_LENGTH
		for _, piece in current do
			if piece.Arc <= 0 then
				continue
			end
			const share = 1 - look.Taper * (1 - smooth((total - piece.Arc) / length))
			if share < 0.999 then
				const old = piece.Width
				const width = old * share
				piece.Width = width
				piece.Tube.Size = Vector3.new(piece.Tube.Size.X, width, width)
				piece.Joint.Size = Vector3.one * width * look.Joint
				const drop = plane.Frame.UpVector * ((old - width) * LIFT)
				piece.Tube.Position -= drop
				piece.Joint.Position -= drop
			end
		end
	end

	function self.Keep(_: any)
		if not running then
			return
		end
		dropHead()
		-- the last sample is where the pointer ended (it may be a step short of the last taken one)
		if pointer ~= nil and #raw >= 1 and (pointer :: Vector3 - raw[#raw]).Magnitude > 0.01 then
			table.insert(raw, pointer :: Vector3)
		end
		for n = laid + 1, #raw - 1 do
			finishPiece(n, n == #raw - 1)
		end
		taper()
		running = false
		table.clear(raw)
		table.clear(current)
		laid = 0
		pointer = nil
	end

	function self.Drop(_: any)
		dropHead()
		for _, piece in current do
			release(piece)
		end
		table.clear(current)
		table.clear(raw)
		laid = 0
		running = false
		pointer = nil
	end

	function self.Remove(_: any, name: string)
		for _, piece in all do
			if piece.Used and piece.Group == name and table.find(current, piece) == nil and piece ~= head then
				release(piece)
			end
		end
	end

	-- The guide track ----------------------------------------------------------------------------------------------------------------
	function self.SetDots(_: any, list: { Vector2 }?)
		table.clear(dashUv)
		table.clear(dashOn)
		covered = 0
		if list == nil then
			for _, dash in dashes do
				dash.Transparency = 1
			end
			self._dots = 0
			return
		end
		const thick = dotRules.Size * scale * 0.5
		const height = thick * 0.5
		for index, dash in dashes do
			const uv = list[index]
			if uv == nil then
				dash.Transparency = 1
				continue
			end
			dashUv[index] = uv
			dashOn[index] = true
			-- along the path (from the previous to the next point): a thin dash of half the gap, Cream, a hair over the surface
			const before = list[index - 1] or uv
			const after = list[index + 1] or uv
			const here = Plane.ToWorld(plane, uv, surface(uv) + height)
			const ahead = Plane.ToWorld(plane, after, surface(after) + height)
			const behind = Plane.ToWorld(plane, before, surface(before) + height)
			const tangent = ahead - behind
			const gap = if list[index + 1] ~= nil then (ahead - here).Magnitude else (here - behind).Magnitude
			dash.Color = Theme.Color.Cream
			dash.Size = Vector3.new(math.max(gap * 0.5, thick), thick, thick)
			dash.CFrame = (if tangent.Magnitude > 1e-4 then CFrame.lookAt(here, here + tangent) else CFrame.new(here)) * CFrame.Angles(0, math.pi / 2, 0)
			dash.Transparency = 0.45
		end
		self._dots = #list
	end

	function self.Cover(_: any, points: { Vector2 }, reach: number, aspect: number)
		for index, uv in dashUv do
			if not dashOn[index] then
				continue
			end
			for _, p in points do
				const dx = (p.X - uv.X) * aspect
				const dy = p.Y - uv.Y
				if dx * dx + dy * dy <= reach * reach then
					dashOn[index] = false
					dashes[index].Transparency = 1
					covered += 1
					break
				end
			end
		end
	end

	function self.Progress(_: any): number
		const total: number = self._dots or 0
		if total == 0 then
			return 1
		end
		return math.clamp(covered / math.min(total, #dashes), 0, 1)
	end

	-- a soft wave of light runs along the dashes (a hair of Transparency, never loud)
	function self.Tick(_: any, time: number)
		for index, dash in dashes do
			if dashOn[index] then
				dash.Transparency = 0.4 + 0.3 * (0.5 + 0.5 * math.sin(time * 3.6 - index * 0.5))
			end
		end
	end

	function self.Shift(_: any, delta: Vector3)
		for _, piece in all do
			if piece.Used then
				piece.Tube.Position += delta
				piece.Joint.Position += delta
			end
		end
		for _, dash in dashes do
			if dash.Transparency < 1 then
				dash.Position += delta
			end
		end
		for index, point in raw do
			raw[index] = point + delta
		end
		lastEnd += delta
		if pointer ~= nil then
			pointer = (pointer :: Vector3) + delta
		end
	end

	function self.Count(_: any): number
		return plate
	end

	function self.Clear(_: any)
		for _, piece in all do
			piece.Tube.Transparency = 1
			piece.Joint.Transparency = 1
			piece.Used = false
			piece.Group = nil
		end
		table.clear(free)
		for _, piece in all do
			table.insert(free, piece)
		end
		table.clear(current)
		table.clear(raw)
		head = nil
		laid = 0
		plate = 0
		running = false
		pointer = nil
		self:SetDots(nil)
	end

	function self.Destroy(_: any)
		for _, piece in all do
			piece.Tube:Destroy()
			piece.Joint:Destroy()
		end
		for _, dash in dashes do
			dash:Destroy()
		end
		table.clear(all)
		table.clear(free)
		table.clear(dashes)
	end

	return self :: Strokes
end

return Strokes
