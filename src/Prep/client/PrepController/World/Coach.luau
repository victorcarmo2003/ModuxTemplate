--!strict
-- World/Coach: the drag tutorial of the 3D prep (TASK-209; decision 3 of the owner, 2026-10-12). A ghost hand made of Parts (no new
-- mesh) loops a short version of the gesture of the section for a moment, so a new player learns that the game is played by
-- DRAGGING (the "hand" is a cartoon dog paw: Cream fur, Teal pad and toe beans, Ink outline): Grill = box -> free spot, Board = the knife along the dashes, Toppings = a bowl -> the bun, Serve = the plate -> the window.
-- With it goes ONE line of hint (`Coach.Line`, a Vide source the shell hint reads, and `Coach.Tab`).
--   * once per station, per section, per SESSION: the flag lives in this module only (no profile, no persistence)
--   * it goes away at the first correct action (the stage calls `Done`) or at the first pointer press (any), and then never returns
--     in this session for that station and section
--   * a stage calls `Show(section, points, line)` when its section opens and there is something to drag; the points are WORLD
--     points of the gesture, start to end, on the work plane (the hand lifts itself)
--   * reduced motion: the hand does not move, it shows at the start and at the end by turns
-- Numbers: Rules.World.Coach; texts: Content.Prep.Texts.Coach. Everything lives under the PrepWorld folder. No Modux, no network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Pointer = require(script.Parent.Parent.Pointer)

export type Coach = {
	-- Starts the loop of `section` (a key of Texts.Coach) over these world points (start -> end). false = not shown (seen already,
	-- fewer than two points, low quality has no effect: the hand is cheap).
	Show: (self: Coach, section: string, points: { Vector3 }) -> boolean,
	-- The player did the thing: the hand goes and does not return (this station, this section).
	Done: (self: Coach, section: string) -> (),
	-- It is showing now (any section / this one).
	Active: (self: Coach, section: string?) -> boolean,
	Step: (self: Coach, dt: number) -> (),
	Destroy: (self: Coach) -> (),
}

const CoachModule = {}

-- The hint line while the hand shows, and the tab it belongs to ("" = none). Read by the shell hint.
CoachModule.Line = Vide.source("") :: Vide.Source<string>
CoachModule.Tab = Vide.source("") :: Vide.Source<string>

-- station -> section -> true: shown (or done) already in this session
const seen: { [number]: { [string]: boolean } } = {}

const CREAM = Theme.Color.Cream
const INK = Theme.Color.Ink
const MUSTARD = Theme.Color.Mustard
const TEAL = Theme.Color.Teal

local function ball(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	const made = Instance.new("Part")
	made.Name = name
	made.Shape = Enum.PartType.Ball
	made.Size = size
	made.Color = color
	made.Material = material
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Massless = true
	return made
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

function CoachModule.new(folder: Folder, rules: Content.PrepWorldRules, pointer: Pointer.Pointer?, station: number): Coach
	const cfg = rules.Coach
	const reduced = Motion.Reduced()
	const palmSize = cfg.Hand.Palm
	-- the hand is a DOG PAW (HotDog Crew look): a Cream fur blob, a big Teal pad and four Cream toes with a Teal bean each, seen from
	-- above; the ring under the toes is the "press". Local frame: origin = the touch point (between the two middle toes), -Z = ahead.
	const pieces: { Part } = {}
	const layout: { { Piece: Part, Position: Vector3, Size: Vector3 } } = {}
	local function add(name: string, color: Color3, position: Vector3, size: Vector3)
		-- a Ball part cannot be an ellipsoid: a Block with a Sphere mesh can
		const made = ball(name, size, color, Enum.Material.SmoothPlastic)
		made.Shape = Enum.PartType.Block
		const mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = made
		table.insert(pieces, made)
		table.insert(layout, { Piece = made, Position = position, Size = size })
	end
	const unit = palmSize
	add("PawFur", CREAM, Vector3.new(0, 0.05, 0.6) * unit, Vector3.new(1.15, 0.5, 0.95) * unit)
	add("PawPad", TEAL, Vector3.new(0, 0.25, 0.64) * unit, Vector3.new(0.62, 0.18, 0.46) * unit)
	for index, spot in { Vector2.new(-0.58, 0.18), Vector2.new(-0.2, -0.1), Vector2.new(0.2, -0.1), Vector2.new(0.58, 0.18) } do
		add(`PawToe{index}`, CREAM, Vector3.new(spot.X, 0.06, spot.Y) * unit, Vector3.new(0.48, 0.36, 0.52) * unit)
		add(`PawBean{index}`, TEAL, Vector3.new(spot.X, 0.2, spot.Y) * unit, Vector3.new(0.25, 0.1, 0.26) * unit)
	end
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
	ring.Size = Vector3.new(0.02, 0.2, 0.2)
	const outline = Instance.new("Highlight")
	outline.Name = "CoachOutline"
	outline.FillTransparency = 1
	outline.OutlineColor = INK
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Enabled = false
	const hand = Instance.new("Model")
	hand.Name = "CoachHand"
	for _, piece in pieces do
		piece.Parent = hand
	end
	hand.Parent = folder
	ring.Parent = folder
	outline.Adornee = hand
	outline.Parent = folder
	const trail: { Part } = {}
	for index = 1, cfg.Dashes do
		const dot = ball("CoachDash", Vector3.one * 0.1, MUSTARD, Enum.Material.Neon)
		dot.Transparency = 1
		dot.Parent = folder
		table.insert(trail, dot)
	end

	local section = ""
	local points: { Vector3 } = {}
	local clock = 0
	local passes = 0
	local lastPhase = -1
	local alive = true
	local stopDown: any = nil

	local function hide()
		for _, piece in pieces do
			piece.Transparency = 1
		end
		ring.Transparency = 1
		for _, dot in trail do
			dot.Transparency = 1
		end
		outline.Enabled = false
	end
	hide()

	local function mark(key: string)
		local row = seen[station]
		if row == nil then
			row = {}
			seen[station] = row
		end
		row[key] = true
	end

	local function stop()
		if section ~= "" then
			mark(section)
		end
		section = ""
		table.clear(points)
		CoachModule.Line("")
		CoachModule.Tab("")
		hide()
	end

	if pointer ~= nil then
		-- the first press ends it, wherever it lands
		stopDown = pointer:OnDown(function()
			if section ~= "" then
				stop()
			end
		end)
	end

	-- the point of the path at share t (0..1), by length
	local function along(t: number): Vector3
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

	-- pose the hand at `at` (the fingertip), `down` 0..1 = how far the finger is pressed on the plane, `alpha` = Transparency
	local function pose(at: Vector3, down: number, alpha: number, direction: Vector3)
		const lift = cfg.Hand.Lift * (1 - 0.75 * down)
		const tip = at + Vector3.new(0, lift, 0)
		const flat = Vector3.new(direction.X, 0, direction.Z)
		const heading = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
		-- the paw comes from behind the touch point (against the way it travels), toes down; the press squishes it flat and wide
		const base = CFrame.lookAt(tip, tip + heading) * CFrame.Angles(math.rad(-14), 0, 0)
		const squish = Vector3.new(1 + 0.1 * down, 1 - 0.3 * down, 1 + 0.1 * down)
		for _, row in layout do
			row.Piece.Size = row.Size * squish
			row.Piece.CFrame = base * CFrame.new(row.Position * squish)
			row.Piece.Transparency = alpha
		end
		outline.Enabled = alpha < 0.9
		-- the press ring on the plane under the fingertip
		ring.CFrame = CFrame.new(at + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		const grow = 0.1 + 0.2 * down
		ring.Size = Vector3.new(0.02, grow, grow)
		ring.Transparency = if down > 0.05 then 0.2 + 0.6 * (1 - down) else 1
	end

	const self = {} :: any

	function self.Show(_: any, wanted: string, path: { Vector3 }): boolean
		if not alive or #path < 2 then
			return false
		end
		const row = seen[station]
		if row ~= nil and row[wanted] then
			return false
		end
		const text = (Content.Prep.Texts.Coach :: any)[wanted]
		if text == nil then
			return false
		end
		if section ~= "" then
			stop()
		end
		section = wanted
		points = table.clone(path)
		clock = 0
		passes = 0
		lastPhase = -1
		CoachModule.Line(text)
		CoachModule.Tab(wanted)
		-- the dots mark the way
		for index, dot in trail do
			const at = along((index - 0.5) / #trail)
			dot.Position = at + Vector3.new(0, 0.03, 0)
		end
		return true
	end

	function self.Done(_: any, key: string)
		local row = seen[station]
		if row == nil then
			row = {}
			seen[station] = row
		end
		row[key] = true
		if section == key then
			stop()
		end
	end

	function self.Active(_: any, key: string?): boolean
		return section ~= "" and (key == nil or key == section)
	end

	function self.Step(_: any, dt: number)
		if section == "" or #points < 2 then
			return
		end
		clock += dt
		const cycle = cfg.Loop + cfg.Rest
		if clock >= cycle then
			clock -= cycle
			passes += 1
			if passes >= cfg.Max then
				stop()
				return
			end
		end
		const u = math.min(clock / cfg.Loop, 1)
		-- appear (0..0.12), press (0.12..0.28), travel (0.28..0.82), release (0.82..0.94), fade (0.94..1)
		local down = 0
		local travel = 0
		local alpha = cfg.Hand.Alpha
		if u < 0.12 then
			alpha = 1 - (1 - cfg.Hand.Alpha) * ease(u / 0.12)
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
			alpha = cfg.Hand.Alpha + (1 - cfg.Hand.Alpha) * ease((u - 0.94) / 0.06)
		end
		if clock > cfg.Loop then
			-- resting between two passes: nothing on screen
			alpha = 1
			down = 0
			travel = 1
		end
		const phase = if clock > cfg.Loop then 2 else 1
		if reduced then
			-- no motion: the start, then the end, by turns
			const at = if math.floor(clock / 0.9) % 2 == 0 then points[1] else points[#points]
			pose(at, 1, cfg.Hand.Alpha, points[#points] - points[1])
			for _, dot in trail do
				dot.Transparency = 0.4
			end
			return
		end
		if phase == 2 then
			hide()
			lastPhase = phase
			return
		end
		const at = along(travel)
		const ahead = along(math.min(travel + 0.05, 1))
		const direction = if (ahead - at).Magnitude > 1e-3 then ahead - at else points[#points] - points[1]
		pose(at, down, alpha, direction)
		-- the dashes light up as the hand passes them
		for index, dot in trail do
			const share = (index - 0.5) / #trail
			dot.Transparency = if share <= travel and u >= 0.28 then 0.1 else 0.65
		end
		lastPhase = phase
	end

	function self.Destroy(_: any)
		alive = false
		if section ~= "" then
			stop()
		end
		if stopDown ~= nil then
			(stopDown :: () -> ())()
		end
		hand:Destroy()
		ring:Destroy()
		outline:Destroy()
		for _, dot in trail do
			dot:Destroy()
		end
		table.clear(trail)
	end

	return self :: Coach
end

-- A Coach that does nothing, for a stage that runs without the world (never nil to check).
function CoachModule.None(): Coach
	const none = {} :: any
	function none.Show(_: any): boolean
		return false
	end
	function none.Done(_: any) end
	function none.Active(_: any): boolean
		return false
	end
	function none.Step(_: any) end
	function none.Destroy(_: any) end
	return none :: Coach
end

-- Forgets what was shown (a new session of play, the dev command).
function CoachModule.Reset()
	table.clear(seen)
end

return CoachModule
