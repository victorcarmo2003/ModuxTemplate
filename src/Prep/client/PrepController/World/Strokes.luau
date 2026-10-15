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
local Sauce = require(ReplicatedStorage.shared.Item.HotDogVisual.Sauce)
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

const LIFT = 0.42 -- share of its own width the bead sits over the surface (the rest sinks into it)
const START = 0.72 -- share of the width at the very start of a stroke
const SWELL = 2.5 -- widths over which it swells in
const TAPER_LENGTH = 3 -- widths over which the tip thins

-- The colour of a sauce (food, not a UI state): the same table the hot dog's drawn line uses (HotDogVisual.Sauce)
function Strokes.ColorOf(key: string): Color3
	return Sauce.ColorOf(key)
end

local function newPart(folder: Folder, name: string, ball: boolean): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Shape = if ball then Enum.PartType.Ball else Enum.PartType.Cylinder
	part.Material = Enum.Material.Plastic -- matte and smooth (Fabric shows a weave at this size, SmoothPlastic a specular)
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
	-- the guide: one flat chevron (">" along the path) per dot, two cream arms over two slightly bigger Ink arms (the outline)
	type Chevron = { Arms: { Part }, Outline: { Part } }
	const DASHES = 48
	const dashes: { Chevron } = {}
	const dashUv: { Vector2 } = {}
	const dashOn: { boolean } = {}
	local function flat(name: string, color: Color3): Part
		const part = newPart(folder, name, false)
		part.Shape = Enum.PartType.Block
		part.Material = Enum.Material.SmoothPlastic
		part.Color = color
		return part
	end
	for _ = 1, DASHES do
		table.insert(dashes, {
			Arms = { flat("GuideArm", Theme.Color.Cream), flat("GuideArm", Theme.Color.Cream) },
			Outline = { flat("GuideOutline", Theme.Color.Ink), flat("GuideOutline", Theme.Color.Ink) },
		})
	end
	local function setChevron(chevron: Chevron, alpha: number, color: Color3?)
		for _, part in chevron.Arms do
			part.Transparency = alpha
			if color ~= nil then
				part.Color = color
			end
		end
		for _, part in chevron.Outline do
			part.Transparency = if alpha >= 1 then 1 else math.min(alpha + 0.15, 0.9)
		end
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

	-- the paste is not one flat tone: a slow, small variation of brightness along the stroke
	local function toneAt(at: number): Color3
		const shade = 1 + 0.06 * math.sin(at * 3.1 + 0.7) + 0.04 * math.sin(at * 7.3)
		return Color3.new(math.clamp(color.R * shade, 0, 1), math.clamp(color.G * shade, 0, 1), math.clamp(color.B * shade, 0, 1))
	end

	-- width at an arc length: swells in, breathes slowly (a function of the arc, so two pieces side by side agree)
	local function widthAt(at: number): number
		const swell = smooth(at / (baseWidth * SWELL))
		const breath = 1 + look.Variance * (0.6 * math.sin(at * 4.8) + 0.4 * math.sin(at * 2.1 + 1.3))
		return baseWidth * (START + (1 - START) * swell) * breath
	end

	-- puts a piece from `from` to `to` (both ON the surface): a cylinder and the ball at its end
	local function setPiece(piece: Piece, from: Vector3, to: Vector3, width: number, at: number)
		const lift = plane.Frame.UpVector * (width * LIFT)
		const a, b = from + lift, to + lift
		piece.Width = width
		piece.Tube.Size = Vector3.new(math.max((b - a).Magnitude, 0.001), width, width)
		const tone = toneAt(at)
		piece.Tube.Color = tone
		if (b - a).Magnitude > 1e-4 then
			piece.Tube.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
			piece.Tube.Transparency = 0
		else
			piece.Tube.Transparency = 1
		end
		piece.Joint.Size = Vector3.one * width * look.Joint
		piece.Joint.Color = tone
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
		setPiece(piece, from, to, widthAt(arc + length / 2), arc + length)
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
		setPiece(piece, lastEnd, to, widthAt(arc + length / 2), arc + length)
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
				setPiece(cap, world, world, widthAt(0), 0)
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
			for _, chevron in dashes do
				setChevron(chevron, 1, nil)
			end
			self._dots = 0
			return
		end
		-- sized by the hotdog: the arm is about 0.11 bun heights long, thin and flat; the Ink outline is a hair bigger
		const arm = plane.Width * 0.10
		const thick = plane.Width * 0.015
		const height = thick * 0.5 + 0.015
		const angle = math.rad(32)
		for index, chevron in dashes do
			const uv = list[index]
			if uv == nil then
				setChevron(chevron, 1, nil)
				continue
			end
			dashUv[index] = uv
			dashOn[index] = true
			const before = list[index - 1] or uv
			const after = list[index + 1] or uv
			-- the height of the surface under the dot, its slope along the path (the chevron lies on it)
			const here = Plane.ToWorld(plane, uv, surface(uv) + height)
			const ahead = Plane.ToWorld(plane, after, surface(after) + height)
			const behind = Plane.ToWorld(plane, before, surface(before) + height)
			const tangent = ahead - behind
			const frame = if tangent.Magnitude > 1e-4 then CFrame.lookAt(here, here + tangent, plane.Frame.UpVector) else plane.Frame.Rotation + here
			for side = 1, 2 do
				const sign = if side == 1 then 1 else -1
				-- an arm of the ">" : from the back corner to the tip (the tip is ahead, -Z of the frame)
				const spin = math.atan2(-math.cos(angle), sign * math.sin(angle))
				const offset = Vector3.new(sign * math.sin(angle) * arm / 2, 0, math.cos(angle) * arm / 2 - arm * 0.3)
				chevron.Arms[side].Size = Vector3.new(arm, thick, thick)
				chevron.Arms[side].CFrame = frame * CFrame.new(offset) * CFrame.Angles(0, spin, 0)
				chevron.Outline[side].Size = Vector3.new(arm + thick * 0.8, thick * 0.6, thick * 1.7)
				chevron.Outline[side].CFrame = frame * CFrame.new(offset - Vector3.new(0, thick * 0.1, 0)) * CFrame.Angles(0, spin, 0)
			end
			setChevron(chevron, 0.15, Theme.Color.Cream)
		end
		self._dots = #list
	end

	-- the dashes the stroke points cover light up (Mustard) and go quiet; the rest keep flowing
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
					setChevron(dashes[index], 0.55, Theme.Color.Mustard)
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

	-- a discreet flow runs along the dashes still to cover, in the direction of the path
	function self.Tick(_: any, time: number)
		for index, chevron in dashes do
			if dashOn[index] then
				const alpha = 0.12 + 0.4 * (0.5 + 0.5 * math.sin(time * 3.2 - index * 0.6))
				for _, part in chevron.Arms do
					part.Transparency = alpha
				end
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
		for _, chevron in dashes do
			for _, part in chevron.Arms do
				if part.Transparency < 1 then
					part.Position += delta
				end
			end
			for _, part in chevron.Outline do
				if part.Transparency < 1 then
					part.Position += delta
				end
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
		for _, chevron in dashes do
			for _, part in chevron.Arms do
				part:Destroy()
			end
			for _, part in chevron.Outline do
				part:Destroy()
			end
		end
		table.clear(all)
		table.clear(free)
		table.clear(dashes)
	end

	return self :: Strokes
end

return Strokes
