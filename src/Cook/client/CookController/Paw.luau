--!strict
-- Paw: the gesture coach of the cooking focus (DEC-311; brought back from the old prep's World/Coach, owner 2026-10-19). A cartoon
-- paw made of Parts (Cream fur, Pink pad and four toe beans, an Ink outline) loops the gesture the player has to make: it comes in,
-- presses, travels the path (a drag) or presses twice (a tap), lets go, fades, rests, and again. A trail of Mustard arrows (owner
-- 2026-10-19: arrows, not dots: they say which way to go) marks
-- the way. The station says what to show (Show) and when the player did it (Learned): a learned gesture never shows again in this
-- session. Settings "Prep helper" off (Prefs.PrepAssist) = no paw. Reduced motion: the paw does not travel, it shows at the
-- start and at the end by turns. Local Parts only, under the focus folder.
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Prefs = require(StarterPlayer.StarterPlayerScripts.client.Settings.Prefs)

export type Paw = {
	-- loops `gesture` over these world points (start -> end; one point = a tap there). The same key again keeps the loop going.
	Show: (self: Paw, gesture: string, points: { Vector3 }) -> (),
	Hide: (self: Paw) -> (),
	-- the player made `gesture`: it goes and never shows again this session
	Learned: (self: Paw, gesture: string) -> (),
	Step: (self: Paw, dt: number) -> (),
	Destroy: (self: Paw) -> (),
}

const LOOP = 1.6 -- s: one pass of the gesture
const REST = 0.5 -- s between two passes
const PALM = 0.42 -- studs: the paw's size
const LIFT = 0.35 -- studs over the work plane before the press
const ALPHA = 0.08 -- Transparency of the paw while it shows
const DASHES = 10
const ARROW_ARM = 0.14 -- studs of a trail arrow's arm

const CREAM = Theme.Color.Cream
const INK = Theme.Color.Ink
const MUSTARD = Theme.Color.Mustard
const PINK = Theme.Color.Pink

-- gestures learned in this session (any focus)
const learned: { [string]: boolean } = {}

local function blob(name: string, size: Vector3, color: Color3, parent: Instance): Part
	-- a Ball part cannot be an ellipsoid: a Block with a Sphere mesh can
	const part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	const mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = parent
	return part
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

const PawModule = {}

function PawModule.new(folder: Instance): Paw
	const reduced = Motion.Reduced()
	const hand = Instance.new("Model")
	hand.Name = "CoachPaw"
	hand.Parent = folder
	-- local frame: origin = the touch point (between the two middle toes), -Z = ahead
	const layout: { { Piece: Part, Position: Vector3, Size: Vector3 } } = {}
	local function add(name: string, color: Color3, position: Vector3, size: Vector3)
		table.insert(layout, { Piece = blob(name, size * PALM, color, hand), Position = position * PALM, Size = size * PALM })
	end
	add("PawFur", CREAM, Vector3.new(0, 0.05, 0.6), Vector3.new(1.15, 0.5, 0.95))
	add("PawPad", PINK, Vector3.new(0, 0.25, 0.64), Vector3.new(0.62, 0.18, 0.46))
	for index, spot in { Vector2.new(-0.58, 0.18), Vector2.new(-0.2, -0.1), Vector2.new(0.2, -0.1), Vector2.new(0.58, 0.18) } do
		add(`PawToe{index}`, CREAM, Vector3.new(spot.X, 0.06, spot.Y), Vector3.new(0.48, 0.36, 0.52))
		add(`PawBean{index}`, PINK, Vector3.new(spot.X, 0.2, spot.Y), Vector3.new(0.25, 0.1, 0.26))
	end
	const outline = Instance.new("Highlight")
	outline.Name = "CoachOutline"
	outline.FillTransparency = 1
	outline.OutlineColor = INK
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Enabled = false
	outline.Adornee = hand
	outline.Parent = folder
	const ring = Instance.new("Part")
	ring.Name = "CoachTap"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = MUSTARD
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 1
	ring.Size = Vector3.new(0.02, 0.2, 0.2)
	ring.Parent = folder
	-- the trail: one Mustard chevron per dash, pointing the way
	type Arrow = { A: Part, B: Part }
	local function arm(name: string): Part
		const part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = MUSTARD
		part.Transparency = 1
		part.Size = Vector3.new(ARROW_ARM, 0.035, 0.035)
		part.Parent = folder
		return part
	end
	const trail: { Arrow } = {}
	for index = 1, DASHES do
		table.insert(trail, { A = arm(`CoachArrow{index}A`), B = arm(`CoachArrow{index}B`) })
	end
	local function shade(arrow: Arrow, transparency: number)
		arrow.A.Transparency = transparency
		arrow.B.Transparency = transparency
	end
	-- a ">" with its point on `at`, aimed along `direction` (flat)
	local function aim(arrow: Arrow, at: Vector3, direction: Vector3)
		const flat = Vector3.new(direction.X, 0, direction.Z)
		const forward = if flat.Magnitude > 1e-4 then flat.Unit else Vector3.zAxis
		const side = forward:Cross(Vector3.yAxis).Unit
		for index, part in { arrow.A, arrow.B } do
			const sign = if index == 1 then 1 else -1
			const tail = at - forward * ARROW_ARM * 0.7 + side * sign * ARROW_ARM * 0.6
			part.CFrame = CFrame.lookAt((tail + at) / 2, at) * CFrame.Angles(0, math.pi / 2, 0)
		end
	end

	local gesture = ""
	local points: { Vector3 } = {}
	local clock = 0

	local function hideAll()
		for _, row in layout do
			row.Piece.Transparency = 1
		end
		ring.Transparency = 1
		for _, arrow in trail do
			shade(arrow, 1)
		end
		outline.Enabled = false
	end

	-- the point of the path at share t (0..1), by length
	local function along(t: number): Vector3
		if #points == 1 then
			return points[1]
		end
		local total = 0
		for index = 2, #points do
			total += (points[index] - points[index - 1]).Magnitude
		end
		local want = total * math.clamp(t, 0, 1)
		for index = 2, #points do
			const leg = (points[index] - points[index - 1]).Magnitude
			if want <= leg or index == #points then
				return points[index - 1]:Lerp(points[index], if leg > 0 then math.clamp(want / leg, 0, 1) else 0)
			end
			want -= leg
		end
		return points[1]
	end

	-- the paw with its touch point on `at`, `down` 0..1 = pressed, `alpha` = Transparency, heading along `direction`
	local function pose(at: Vector3, down: number, alpha: number, direction: Vector3)
		const tip = at + Vector3.new(0, LIFT * (1 - 0.75 * down), 0)
		const flat = Vector3.new(direction.X, 0, direction.Z)
		const heading = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
		const base = CFrame.lookAt(tip, tip + heading) * CFrame.Angles(math.rad(-14), 0, 0)
		const squish = Vector3.new(1 + 0.1 * down, 1 - 0.3 * down, 1 + 0.1 * down)
		for _, row in layout do
			row.Piece.Size = row.Size * squish
			row.Piece.CFrame = base * CFrame.new(row.Position * squish)
			row.Piece.Transparency = alpha
		end
		outline.Enabled = alpha < 0.9
		ring.CFrame = CFrame.new(at + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		const grow = 0.1 + 0.2 * down
		ring.Size = Vector3.new(0.02, grow, grow)
		ring.Transparency = if down > 0.05 then 0.2 + 0.6 * (1 - down) else 1
	end

	const self = {} :: any

	function self.Show(_: any, key: string, path: { Vector3 })
		if learned[key] or #path == 0 or not Vide.untrack(Prefs.PrepAssist) then
			if gesture == key then
				gesture = ""
				hideAll()
			end
			return
		end
		if key ~= gesture then
			clock = 0
		end
		gesture = key
		points = table.clone(path)
		for index, arrow in trail do
			const share = (index - 0.5) / #trail
			const at = along(share) + Vector3.new(0, 0.04, 0)
			aim(arrow, at, along(math.min(share + 0.03, 1)) - along(math.max(share - 0.03, 0)))
		end
	end

	function self.Hide(_: any)
		gesture = ""
		hideAll()
	end

	function self.Learned(_: any, key: string)
		learned[key] = true
		if gesture == key then
			gesture = ""
			hideAll()
		end
	end

	function self.Step(_: any, dt: number)
		if gesture == "" or #points == 0 then
			return
		end
		clock = (clock + dt) % (LOOP + REST)
		const tap = #points == 1
		if reduced then
			const at = if tap or math.floor(clock / 0.9) % 2 == 0 then points[1] else points[#points]
			pose(at, 1, ALPHA, points[#points] - points[1])
			for _, arrow in trail do
				shade(arrow, if tap then 1 else 0.4)
			end
			return
		end
		if clock > LOOP then
			hideAll()
			return
		end
		const u = clock / LOOP
		local down, travel, alpha = 0, 0, ALPHA
		if tap then
			-- two presses in place
			down = math.max(0, math.sin(u * math.pi * 4))
			alpha = if u < 0.1 then 1 - (1 - ALPHA) * ease(u / 0.1) else ALPHA
		elseif u < 0.12 then
			alpha = 1 - (1 - ALPHA) * ease(u / 0.12)
		elseif u < 0.28 then
			down = ease((u - 0.12) / 0.16)
		elseif u < 0.82 then
			down = 1
			travel = ease((u - 0.28) / 0.54)
		elseif u < 0.94 then
			down = 1 - ease((u - 0.82) / 0.12)
			travel = 1
		else
			travel = 1
			alpha = ALPHA + (1 - ALPHA) * ease((u - 0.94) / 0.06)
		end
		const at = along(travel)
		const ahead = along(math.min(travel + 0.05, 1))
		const direction = if (ahead - at).Magnitude > 1e-3 then ahead - at else points[#points] - points[1]
		pose(at, down, alpha, direction)
		for index, arrow in trail do
			const share = (index - 0.5) / #trail
			shade(arrow, if tap then 1 elseif share <= travel and u >= 0.28 then 0.05 else 0.55)
		end
	end

	function self.Destroy(_: any)
		gesture = ""
		hand:Destroy()
		ring:Destroy()
		outline:Destroy()
		for _, arrow in trail do
			arrow.A:Destroy()
			arrow.B:Destroy()
		end
	end

	return self :: Paw
end

-- Forgets what was learned (a new session of play, the dev command, the tutorial reset)
function PawModule.Reset()
	table.clear(learned)
end

return PawModule
