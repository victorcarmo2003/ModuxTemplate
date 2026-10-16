--!strict
-- World/BoardView: what the 3D Board and Toppings sections DRAW on the cutting board (docs/tech/prep-3d.md §3.3, §3.4, §6A; TASK-204,
-- 205). The stage (World/Stages/Build) decides, Director3D measures; this module only presents, from the state they hand it:
--   bun        the REAL kit bun (BunClosed / BunOpen, AST-001) drawn `Rules.World.Board.Scale` times bigger on the seat's board slot.
--              Closed -> Open is a swap with a hop and crumbs (the EditableMesh morph of TASK-218 plugs in at `SwapBun`, behind
--              Rules.World.Editable; nothing here creates an EditableMesh)
--   guide      the dashed cut line over the bun (a pool of Parts) that fills as the knife goes
--   knife      a clone of the REAL knife of the board that follows the pointer (the original is hidden locally meanwhile)
--   sausage    the grilled kit sausage in the groove, a ghost where it will land, a carried one that follows the pointer
--   plate      the plate ghost carried to the bin; the toppings that are models (cheese, bacon, potato sticks)
--   (the bin is World/Bin now: one virtual bin per view, lower left of the screen)
-- The world draws its own board bun from the `Stations` record (KitchenController Board part); it is hidden LOCALLY (LocalTransparency
-- Modifier) while this view lives and given back on Destroy. Everything made here lives under the PrepWorld folder and dies with it.
-- No Modux, no Vide, no network.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Ghost = require(script.Parent.Ghost)
local Juice = require(script.Parent.Juice)
local Plane = require(script.Parent.Plane)

export type BunState = "None" | "Closed" | "Open"

export type View = {
	Plane: Plane.Plane,
	-- The pose (CFrame) of the bun base and the axes of the board: Right = screen right, Back = toward the player.
	Base: CFrame,
	Scale: number,
	Orient: CFrame,
	-- The bun and the groove, in the bun space.
	SetBun: (self: View, state: BunState, animate: boolean) -> (),
	Bun: (self: View) -> BunState,
	-- The model of the bun shown now (the highlight adornee), nil when none.
	BunModel: (self: View) -> Model?,
	-- Slides the plate to a new place (the Toppings view looks at another part of the board).
	MoveTo: (self: View, position: Vector3, time: number) -> (),
	-- The plate under the hot dog (a Cream disc with a rim): shown once the sausage is in the bun; the bun, the sausage and the
	-- toppings ride on it (the cutting board mat stays where it was). `HasPlate` = it is shown. `PlateRadius` in studs.
	SetPlate: (self: View, on: boolean) -> (),
	HasPlate: (self: View) -> boolean,
	PlateRadius: number,
	-- Where the plate can sit near `centre` (x, z): the spot closest to it that lies on the bench (the rim has bench under it) and
	-- clear of the `obstacles` (the bowl hitboxes), a little toward `toward` (flat, to the player). nil = no such spot.
	FindSpot: (self: View, centre: Vector3, obstacles: { BasePart }, toward: Vector3) -> Vector3?,
	-- A prop of the world that stands where the plate sits (the bun crate): hidden locally and let through by the bench rays, until
	-- `ShowWorld` (the plate goes back) or the view dies.
	HideWorld: (self: View, instance: Instance) -> (),
	ShowWorld: (self: View, instance: Instance) -> (),
	-- The carried sausage flies to the groove in an arc with a spring, then `done` runs (a tap on the rail sausage).
	Fly: (self: View, done: () -> ()) -> (),
	Anchor: (self: View) -> Vector3,
	SetMoved: (self: View, fn: ((delta: Vector3) -> ())?) -> (),
	-- Dashed cut line: visible, progress 0..1 of the line done.
	SetGuide: (self: View, visible: boolean, progress: number) -> (),
	-- The knife follows `point` (world, on the bun plane); nil hides it. `pressed` = cutting (lower), `lean` -1..1 = side of travel.
	SetKnife: (self: View, point: Vector3?, pressed: boolean, lean: number) -> (),
	-- The sausage in the groove ("Placed"), a ghost where it lands ("Ghost"), nothing.
	SetSausage: (self: View, mode: "None" | "Ghost" | "Placed", uv: Vector2?) -> (),
	-- Something carried by the pointer: a sausage (grilled) or the plate ghost; nil drops it. `snap` = bun-space point to slide to.
	SetCarry: (self: View, kind: "Sausage" | "Plate" | nil, point: Vector3?, snap: Vector2?) -> (),
	-- A model topping (cheese, bacon, potato sticks) landed on the bun, in the bun space; `grow` 0..1 scales the mound.
	SetTopping: (self: View, key: string, uv: Vector2?, grow: number) -> (),
	-- The bun closes over the plate (Rules.World.Board.Close), then `done` runs.
	Close: (self: View, done: () -> ()) -> (),
	-- The finished plate (plate, closed bun, sausage, toppings) leaves with the hot dog: the real pieces vanish and a copy of the whole
	-- stack flies to the hand of the camera, shrinking, then `done` runs. Nothing is left on the table.
	TakeAway: (self: View, done: (() -> ())?) -> (),
	-- Height (studs) over the plane of the bun top of whatever is under a bun-space point: the round back of the sausage when it
	-- lies in the groove, the bun beside it. The sauce and the guide track lie on this.
	SurfaceHeight: (self: View, uv: Vector2) -> number,
	-- The live progress ring around the plate: 0..1 of the gesture in progress (the cut, the sauce covered, the mound); nil hides it.
	SetProgress: (self: View, fraction: number?) -> (),
	-- The carried model, handed over (the bin swallows it); nil when nothing is carried. A lifted plate hands over a copy of the bun and
	-- the real stack vanishes (`Restore` brings it back if the server refuses the trash).
	TakeCarry: (self: View) -> Model?,
	Restore: (self: View) -> (),
	-- The grade burst of a gesture (sparks, flash, word by band) over the bun.
	Burst: (self: View, band: string) -> (),
	-- The seal of the finished plate: confetti by band and a word, over the bun.
	Celebrate: (self: View, band: string) -> (),
	Dust: (self: View) -> (),
	Step: (self: View, dt: number, time: number) -> (),
	Destroy: (self: View) -> (),
}

export type Options = {
	Folder: Folder,
	Rules: Content.PrepWorldRules,
	Seat: number,
	-- bun base position (Att_Bun<seat>) and the screen right axis (flat)
	Anchor: Vector3,
	Right: Vector3,
	-- the world's own slot objects (KitchenController:SlotView)
	SlotView: (kind: string, slot: number) -> any,
	-- the real knife of the board, nil when it is not found
	Knife: BasePart?,
	-- the rail slot whose sausage is hidden while it is on the bun / in the hand (1 = the front)
	RailFront: number,
	-- the juice of the world (World.Juice)
	Juice: () -> Juice.Juice,
	-- TASK-346: the plate's bun is the altered one (ANM-002): the open bun is the kit's BunBitten (AST-061), BunOpen if missing
	Altered: (() -> boolean)?,
}

const BoardView = {}

const BUN_LENGTH, BUN_WIDTH, BUN_HEIGHT = 1.0, 0.45, 0.35
const SAUSAGE_BASE = 0.2 -- of the bun height x scale: the groove
const SAUSAGE_THICK = 0.24
const KNIFE_SCALE = 0.5 -- of the board scale
const HIDE_EVERY = 0.25 -- s: the world re-makes its models, so the hiding is re-applied at 4 Hz
const PLATE_H = 0.08 -- studs: the thickness of the plate disc
const PLATE_REACH = 0.62 -- of the bun length x scale: the radius of the plate
const PLATE_RIM = 28 -- Parts of the rim
const FLY_TIME = 0.42 -- s: the sausage flies from the rail to the bun
const TAKEAWAY_TIME = 0.45 -- s: the finished plate leaves with the hot dog (Done)
const FLY_ARC = 0.9 -- studs: height of that arc
const GROOVE_UV = Vector2.new(Content.Prep.Build.Groove.X, Content.Prep.Build.Groove.Y)

local function easeInOut(t: number): number
	return t * t * (3 - 2 * t)
end

local function kitModel(group: string, name: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const folder = if items then items:FindFirstChild(group) else nil
	const model = if folder then folder:FindFirstChild(name) else nil
	return if model ~= nil and model:IsA("Model") then model else nil
end

-- A local, inert copy: anchored, never hit by a ray, never casting a shadow.
local function inert(model: Model, parent: Instance, transparency: number): Model
	const copy = model:Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Massless = true
			descendant.Transparency = transparency
		elseif descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end
	copy.Parent = parent
	return copy
end

local function setAlpha(model: Instance, alpha: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = alpha
		end
	end
end

local function setLocal(root: Instance, value: number)
	if root:IsA("BasePart") then
		root.LocalTransparencyModifier = value
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = value
		end
	end
end

function BoardView.new(options: Options): View
	const folder = options.Folder
	const rules = options.Rules.Board
	const scale = rules.Scale
	const up = Vector3.yAxis
	const right = options.Right.Unit
	const orient = CFrame.fromMatrix(Vector3.zero, right, up) -- local Z = toward the player

	-- the mat the plate lies on (feedback 2026-10-12, G: the bun floated over the board and, in the Toppings view, hung over the
	-- bench). The real cutting board is the parent of the knife; its clone (the mat) always lies under the plate and slides with it,
	-- its top over the bench found by a ray, and the real board is hidden locally while the mat lives. Without a board in the
	-- trailer the plate stays at the Y it was given.
	const boardInstance = if options.Knife ~= nil then options.Knife.Parent else nil
	const boardPart: BasePart? = if boardInstance ~= nil and boardInstance:IsA("BasePart") and boardInstance.Name == "Board" then boardInstance else nil
	local mat: BasePart? = nil
	local matRotation = CFrame.identity
	local matThickness = 0
	-- the bench top that the board lay on (its bottom): the Y the ray is expected to find, and the fallback
	local benchFallback = if boardPart ~= nil then boardPart.Position.Y - boardPart.Size.Y / 2 else options.Anchor.Y - 0.25
	const rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	do
		const ignore: { Instance } = { folder }
		-- the invisible hitboxes of the targets are not bench
		for _, tagged in CollectionService:GetTagged(options.Rules.Tag) do
			table.insert(ignore, tagged)
		end
		if boardPart ~= nil then
			table.insert(ignore, boardPart)
		end
		const character = Players.LocalPlayer.Character
		if character ~= nil then
			table.insert(ignore, character)
		end
		rayParams.FilterDescendantsInstances = ignore
	end
	-- the plate under the hot dog (built on first use); while it is on, the mat stays and the plate follows `seat`
	const plateRadius = BUN_LENGTH * scale * PLATE_REACH
	local plate: Model? = nil
	local plateOn = false
	local plateGrow = 1
	local bias = 0 -- studs: the plate starts on top of the mat and comes down to the bench as it slides
	local hopLift = 0
	if boardPart ~= nil then
		const clone = boardPart:Clone()
		for _, child in clone:GetChildren() do
			if not (child:IsA("SurfaceAppearance") or child:IsA("SpecialMesh") or child:IsA("Texture") or child:IsA("Decal")) then
				child:Destroy()
			end
		end
		clone.Name = "Prep_Mat"
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CastShadow = true
		clone.Massless = true
		clone.Transparency = 0
		clone.LocalTransparencyModifier = 0
		clone.Parent = folder
		mat = clone
		matRotation = boardPart.CFrame.Rotation
		matThickness = boardPart.Size.Y
	end

	-- Puts the mat under (x, z) and returns the Y of its top, where the bun base goes; `position` unchanged without a mat.
	local function seat(position: Vector3): Vector3
		const matPart = mat
		const plateModel = plate
		if matPart == nil and not (plateOn and plateModel ~= nil) then
			return position
		end
		local bench = benchFallback
		const hit = workspace:Raycast(Vector3.new(position.X, benchFallback + 1.2, position.Z), Vector3.new(0, -2.4, 0), rayParams)
		if hit ~= nil and math.abs(hit.Position.Y - benchFallback) <= 0.6 then
			bench = hit.Position.Y
		end
		if plateOn and plateModel ~= nil then
			const base = bench + bias + hopLift
			plateModel:PivotTo(CFrame.new(position.X, base + PLATE_H / 2, position.Z))
			return Vector3.new(position.X, base + PLATE_H, position.Z)
		end
		if matPart == nil then
			return position
		end
		matPart.CFrame = CFrame.new(position.X, bench + matThickness / 2, position.Z) * matRotation
		return Vector3.new(position.X, bench + matThickness, position.Z)
	end

	local anchorPos = seat(options.Anchor)
	local baseCf = CFrame.new(anchorPos + up * rules.Lift) * orient
	const closedHeight = BUN_HEIGHT * scale
	const openHeight = 0.345 * scale
	local topFrame = CFrame.new(anchorPos + up * (rules.Lift + closedHeight)) * orient
	const plane = Plane.new(topFrame, BUN_LENGTH * scale, BUN_WIDTH * scale)

	-- the plate: a Cream disc with a rim of little bars, pivot at the middle of the disc --------------------------------------
	local function makePlate(): Model
		const model = Instance.new("Model")
		model.Name = "Prep_Plate"
		local function part(name: string, size: Vector3, cf: CFrame): Part
			const made = Instance.new("Part")
			made.Name = name
			made.Anchored = true
			made.CanCollide = false
			made.CanQuery = false
			made.CanTouch = false
			made.CastShadow = true
			made.Massless = true
			made.Material = Enum.Material.SmoothPlastic
			made.Color = Theme.Color.Cream
			made.Size = size
			made.CFrame = cf
			made.Parent = model
			return made
		end
		-- the disc (a cylinder along its X): the pivot offset stands it up, as in the Serve plate
		const disc = part("Plate_Disc", Vector3.new(PLATE_H, plateRadius * 2, plateRadius * 2), CFrame.Angles(0, 0, math.pi / 2))
		disc.Shape = Enum.PartType.Cylinder
		disc.PivotOffset = CFrame.Angles(0, 0, -math.pi / 2)
		model.PrimaryPart = disc
		const segment = 2 * math.pi * plateRadius / PLATE_RIM * 1.15
		for index = 1, PLATE_RIM do
			const angle = (index - 1) / PLATE_RIM * math.pi * 2
			const at = Vector3.new(math.cos(angle) * (plateRadius - 0.05), PLATE_H / 2 + 0.035, math.sin(angle) * (plateRadius - 0.05))
			part("Plate_Rim", Vector3.new(segment, 0.07, 0.1), CFrame.new(at) * CFrame.Angles(0, -(angle + math.pi / 2), 0))
		end
		model.Parent = folder
		return model
	end

	-- the sausage in flight (a tap on the rail sausage): from where the carry is to the groove, an arc with a spring
	local flight: { T: number, From: Vector3, Done: () -> () }? = nil

	-- the bun: both kit models, one shown ------------------------------------------------------------------------------------
	local closed: Model? = nil
	local open: Model? = nil
	local state: BunState = "None"
	local swap: { T: number, Time: number }? = nil
	local closing: { T: number, Done: () -> () }? = nil
	local takeaway: { Model: Model, From: CFrame, Start: number, T: number, Done: (() -> ())? }? = nil

	local function makeBun(name: string): Model?
		const source = kitModel("Food", name)
		if source == nil then
			return nil
		end
		const copy = inert(source, folder, 1)
		copy.Name = `Prep_{name}`
		copy:ScaleTo(scale)
		copy:PivotTo(baseCf)
		return copy
	end

	-- the sausage, ghost, carried one and the toppings ----------------------------------------------------------------------
	local sausage: Model? = nil
	local sausageMode = "None"
	local sausageUv = Vector2.new(0.5, 0.5)
	local carry: Model? = nil
	local carryKind = ""
	local carryTarget: CFrame? = nil
	local carryPose: CFrame? = nil
	-- the plate dragged to the bin: the REAL stack (bun, sausage, toppings, plate) follows the pointer, no copy of the bun is made
	local lifted = false
	local liftTarget: Vector3? = nil
	local liftRest = Vector3.zero
	const toppings: { [string]: { Model: Model, Uv: Vector2, Grow: number, Scaled: number } } = {}

	local function poseTopping(key: string, item: { Model: Model, Uv: Vector2, Grow: number, Scaled: number })
		const world = Plane.ToWorld(plane, item.Uv, 0)
		const lift = (SAUSAGE_BASE + SAUSAGE_THICK) * scale + 0.03 * scale * (if key == "cheese" then 1 elseif key == "bacon" then 2 else 3)
		item.Model:PivotTo(CFrame.new(world.X, anchorPos.Y + rules.Lift + lift, world.Z) * orient)
	end

	local function sausageCf(uv: Vector2): CFrame
		const world = Plane.ToWorld(plane, uv, 0)
		return CFrame.new(world.X, anchorPos.Y + rules.Lift + SAUSAGE_BASE * scale, world.Z) * orient
	end

	local function ensureSausage(): Model?
		if sausage == nil or sausage.Parent == nil then
			const source = kitModel("Food", "SausageGrilled")
			if source == nil then
				return nil
			end
			const made = inert(source, folder, 1)
			made.Name = "Prep_PlateSausage"
			made:ScaleTo(scale)
			sausage = made
		end
		return sausage
	end

	-- guide dashes ---------------------------------------------------------------------------------------------------------------
	const dashes: { Part } = {}
	local guideOn = false
	local guideProgress = 0
	local cut = Content.Prep.Build.Cut
	for index = 1, rules.Guide.Dashes do
		const dash = Instance.new("Part")
		dash.Name = "CutDash"
		dash.Material = Enum.Material.Neon
		dash.Color = Theme.Color.Cream
		dash.Anchored = true
		dash.CanCollide = false
		dash.CanQuery = false
		dash.CanTouch = false
		dash.CastShadow = false
		dash.Transparency = 1
		const span = (cut.To - cut.From) * plane.Length
		dash.Size = Vector3.new(span / (rules.Guide.Dashes * 2), rules.Guide.Lift, rules.Guide.Width * scale)
		dash.Parent = folder
		table.insert(dashes, dash)
	end

	local function placeDashes()
		for index, dash in dashes do
			const u = cut.From + (cut.To - cut.From) * ((index - 0.5) / rules.Guide.Dashes)
			dash:PivotTo(CFrame.new(Plane.ToWorld(plane, Vector2.new(u, cut.Y), rules.Guide.Lift)) * orient)
		end
	end
	placeDashes()

	local function paintGuide()
		for index, dash in dashes do
			const u = (index - 0.5) / #dashes
			const done = u <= guideProgress
			dash.Transparency = if guideOn then 0.05 else 1
			dash.Color = if done then Theme.Color.Mustard else Theme.Color.Cream
		end
	end

	-- the live progress ring around the bun: a ring of little beads that fill (Mustard) as the gesture goes on --------------------
	const RING_BEADS = 40
	const beads: { Part } = {}
	local progress: number? = nil
	local shownBeads = -1
	for index = 1, RING_BEADS do
		const bead = Instance.new("Part")
		bead.Name = "ProgressBead"
		bead.Shape = Enum.PartType.Ball
		bead.Material = Enum.Material.Neon
		bead.Anchored = true
		bead.CanCollide = false
		bead.CanQuery = false
		bead.CanTouch = false
		bead.CastShadow = false
		bead.Transparency = 1
		bead.Size = Vector3.one * 0.045 * scale
		bead.Parent = folder
		beads[index] = bead
	end

	local function placeBeads()
		for index, bead in beads do
			const angle = (index - 1) / RING_BEADS * math.pi * 2 - math.pi / 2
			-- an ellipse a hand off the bun: wider than long
			const local_ = Vector3.new(math.cos(angle) * BUN_LENGTH * scale * 0.62, 0.06, math.sin(angle) * BUN_WIDTH * scale * 0.95)
			bead.Position = topFrame:PointToWorldSpace(local_)
		end
	end

	local function paintBeads()
		if progress == nil then
			if shownBeads ~= -2 then
				shownBeads = -2
				for _, bead in beads do
					bead.Transparency = 1
				end
			end
			return
		end
		const lit = math.floor(math.clamp(progress, 0, 1) * RING_BEADS + 0.5)
		if lit == shownBeads then
			return
		end
		shownBeads = lit
		for index, bead in beads do
			const on = index <= lit
			bead.Color = if on then Theme.Color.Mustard else Theme.Color.Cream
			bead.Transparency = if on then 0.05 else 0.72
		end
	end

	-- the knife -------------------------------------------------------------------------------------------------------------------
	local knife: BasePart? = nil
	local knifePose: CFrame? = nil
	local knifeTarget: CFrame? = nil
	if options.Knife ~= nil then
		const clone = options.Knife:Clone()
		for _, child in clone:GetChildren() do
			if not (child:IsA("SurfaceAppearance") or child:IsA("SpecialMesh") or child:IsA("Texture") or child:IsA("Decal")) then
				child:Destroy()
			end
		end
		clone.Name = "Prep_Knife"
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CastShadow = false
		clone.Massless = true
		clone.LocalTransparencyModifier = 0
		clone.Transparency = 1
		clone.Size *= scale * KNIFE_SCALE
		clone.Parent = folder
		knife = clone
	end

	-- the world's own objects, hidden locally -----------------------------------------------------------------------------------
	const hidden: { Instance } = {}
	local hideAt = 0
	local hideRail = false
	-- the rail sausage hidden while one is carried to the bun: given back as soon as it is not (a drop that missed used to leave it gone)
	const railHidden: { Instance } = {}
	local hideBar: { BillboardGui } = {}

	local function hide(instance: Instance)
		if table.find(hidden, instance) == nil then
			table.insert(hidden, instance)
		end
		setLocal(instance, 1)
	end

	-- TASK-283: the world's copy of the plate (KitchenController Board, `BunPlate_Slot<n>`) steps aside while this view draws it
	local viewStation: Instance? = nil
	local function refreshHidden()
		const entry = options.SlotView("board", options.Seat)
		if entry ~= nil and entry.Station ~= nil then
			if viewStation ~= entry.Station then
				viewStation = entry.Station
				entry.Station:SetAttribute(`PrepView{options.Seat}`, true)
			end
			for _, child in entry.Station:GetChildren() do
				if child:IsA("Model") and string.find(child.Name, `^Bun%a*_Slot{options.Seat}$`) ~= nil then
					hide(child)
				end
			end
			const bar = entry.Spot.Host:FindFirstChild(`ProgressBar_Slot{options.Seat}`)
			if bar ~= nil and bar:IsA("BillboardGui") and table.find(hideBar, bar) == nil then
				table.insert(hideBar, bar)
			end
		end
		for _, bar in hideBar do
			if bar.Parent ~= nil then
				bar.Enabled = false
			end
		end
		if options.Knife ~= nil and knife ~= nil then
			hide(options.Knife)
		end
		if boardPart ~= nil and mat ~= nil then
			hide(boardPart)
		end
		if hideRail then
			const rail = options.SlotView("rail", options.RailFront)
			if rail ~= nil and rail.Station ~= nil then
				for _, child in rail.Station:GetChildren() do
					if child:IsA("Model") and string.find(child.Name, `^Sausage%a*_Slot{options.RailFront}$`) ~= nil then
						hide(child)
						if table.find(railHidden, child) == nil then
							table.insert(railHidden, child)
						end
					end
				end
			end
		elseif #railHidden > 0 then
			for _, instance in railHidden do
				const at = table.find(hidden, instance)
				if at ~= nil then
					table.remove(hidden, at)
				end
				if instance.Parent ~= nil then
					setLocal(instance, 0)
				end
			end
			table.clear(railHidden)
		end
	end

	local function unhide()
		if viewStation ~= nil then
			if viewStation.Parent ~= nil then
				viewStation:SetAttribute(`PrepView{options.Seat}`, nil)
			end
			viewStation = nil
		end
		for _, instance in hidden do
			if instance.Parent ~= nil then
				setLocal(instance, 0)
			end
		end
		table.clear(hidden)
		-- the bar of the cut is bound to the record (it only shows while the bun is Working): its own effect turns it on again
		table.clear(hideBar)
	end

	-- public ---------------------------------------------------------------------------------------------------------------------
	-- the world's hiding must never outlive the folder (the mode can end on another tab)
	folder.Destroying:Connect(function()
		unhide()
	end)

	const self = {
		Plane = plane,
		Base = baseCf,
		Scale = scale,
		Orient = orient,
		PlateRadius = plateRadius,
	} :: any

	-- Where the plate sits: the bun, the sausage, the toppings, the guide and the bin follow (the sauce segments are moved by the
	-- listener of `SetMoved`, they are not ours).
	local moved: ((delta: Vector3) -> ())? = nil
	local slide: { From: Vector3, To: Vector3, T: number, Time: number, Bias0: number }? = nil

	local function place(requested: Vector3)
		const position = seat(requested)
		const delta = position - anchorPos
		anchorPos = position
		baseCf = CFrame.new(anchorPos + up * rules.Lift) * orient
		topFrame = CFrame.new(anchorPos + up * (rules.Lift + closedHeight)) * orient
		plane.Frame = topFrame
		placeDashes()
		placeBeads()
		if sausage ~= nil and sausageMode ~= "None" then
			sausage:PivotTo(sausageCf(sausageUv))
		end
		for key, entry in toppings do
			poseTopping(key, entry)
		end
		if moved ~= nil and delta.Magnitude > 0 then
			moved(delta)
		end
	end

	-- Slides the plate to `position` in `time` seconds (0 = at once): ease-out with a small overshoot (a spring) and a little hop.
	function self.MoveTo(_: any, position: Vector3, time: number)
		if time <= 0 then
			slide = nil
			bias = 0
			hopLift = 0
			place(position)
			return
		end
		-- the slide runs flat: the Y follows the bench under the plate (`place`)
		slide = { From = anchorPos, To = Vector3.new(position.X, anchorPos.Y, position.Z), T = 0, Time = time, Bias0 = bias }
	end

	function self.SetPlate(_: any, on: boolean)
		if on == plateOn then
			return
		end
		plateOn = on
		if on then
			if plate == nil then
				plate = makePlate()
			end
			plateGrow = 0.6
			bias = matThickness
			hopLift = 0
			;(plate :: Model):ScaleTo(plateGrow)
			place(anchorPos)
		else
			if plate ~= nil then
				plate:Destroy()
				plate = nil
			end
			slide = nil
			bias = 0
			hopLift = 0
		end
	end

	function self.HasPlate(_: any): boolean
		return plateOn
	end

	function self.FindSpot(_: any, centre: Vector3, obstacles: { BasePart }, toward: Vector3): Vector3?
		const radius = plateRadius
		const flat = Vector3.new(toward.X, 0, toward.Z)
		const dir = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero
		local best: Vector3? = nil
		local bestCost = math.huge
		local function supported(x: number, z: number): boolean
			const hit = workspace:Raycast(Vector3.new(x, benchFallback + 1.2, z), Vector3.new(0, -2.4, 0), rayParams)
			return hit ~= nil and math.abs(hit.Position.Y - benchFallback) <= 0.3
		end
		for ix = -28, 28 do
			for iz = -20, 20 do
				const dx, dz = ix * 0.25, iz * 0.25
				const cost = dx * dx + dz * dz - (dir.X * dx + dir.Z * dz) * 0.6
				if cost < bestCost then
					const x, z = centre.X + dx, centre.Z + dz
					local clear = true
					for _, obstacle in obstacles do
						const local_ = obstacle.CFrame:PointToObjectSpace(Vector3.new(x, obstacle.Position.Y, z))
						const outX = math.max(math.abs(local_.X) - obstacle.Size.X / 2, 0)
						const outZ = math.max(math.abs(local_.Z) - obstacle.Size.Z / 2, 0)
						if math.sqrt(outX * outX + outZ * outZ) < radius * 0.9 then
							clear = false
							break
						end
					end
					if clear and supported(x, z) then
						-- the whole rim has bench under it
						for step = 0, 11 do
							const angle = step / 12 * math.pi * 2
							if not supported(x + math.cos(angle) * radius * 0.97, z + math.sin(angle) * radius * 0.97) then
								clear = false
								break
							end
						end
						if clear then
							best = Vector3.new(x, anchorPos.Y, z)
							bestCost = cost
						end
					end
				end
			end
		end
		return best
	end

	function self.HideWorld(_: any, instance: Instance)
		hide(instance)
		const list = rayParams.FilterDescendantsInstances
		if table.find(list, instance) == nil then
			table.insert(list, instance)
			rayParams.FilterDescendantsInstances = list
		end
	end

	function self.ShowWorld(_: any, instance: Instance)
		const at = table.find(hidden, instance)
		if at ~= nil then
			table.remove(hidden, at)
		end
		if instance.Parent ~= nil then
			setLocal(instance, 0)
		end
		const list = rayParams.FilterDescendantsInstances
		const index = table.find(list, instance)
		if index ~= nil then
			table.remove(list, index)
			rayParams.FilterDescendantsInstances = list
		end
	end

	function self.Restore(_: any)
		const bun = if state == "Open" then open elseif state == "Closed" then closed else nil
		if bun ~= nil then
			setAlpha(bun, 0)
		end
		if sausage ~= nil and sausageMode == "Placed" then
			setAlpha(sausage, 0)
		end
		for _, entry in toppings do
			setAlpha(entry.Model, 0)
		end
		if plate ~= nil and plateOn then
			setAlpha(plate, 0)
		end
		self:MoveTo(liftRest, 0.25)
	end

	function self.Fly(_: any, done: () -> ())
		if carry == nil then
			done()
			return
		end
		const from = if carryPose ~= nil then carryPose.Position elseif carryTarget ~= nil then carryTarget.Position else topFrame.Position
		flight = { T = 0, From = from, Done = done }
	end

	function self.Anchor(_: any): Vector3
		return anchorPos
	end

	function self.SetMoved(_: any, fn: ((delta: Vector3) -> ())?)
		moved = fn
	end

	function self.Bun(_: any): BunState
		return state
	end

	-- the one place a bun swap happens: the EditableMesh morph (TASK-218, Rules.World.Editable) replaces this body
	local function swapBun(from: Model?, to: Model?, animate: boolean)
		if from ~= nil then
			setAlpha(from, 1)
		end
		if to ~= nil then
			setAlpha(to, 0)
		end
		swap = if animate and to ~= nil then { T = 0, Time = rules.Open.Time } else nil
	end

	function self.BunModel(_: any): Model?
		return if state == "Open" then open elseif state == "Closed" then closed else nil
	end

	function self.SetBun(_: any, wanted: BunState, animate: boolean)
		if wanted == state then
			return
		end
		const previous = state
		state = wanted
		if wanted ~= "None" and (closed == nil or closed.Parent == nil) then
			closed = makeBun("BunClosed")
		end
		const openName = if options.Altered ~= nil and options.Altered() and kitModel("Food", "BunBitten") ~= nil
			then "BunBitten"
			else "BunOpen"
		if wanted == "Open" and open ~= nil and open.Parent ~= nil and open.Name ~= `Prep_{openName}` then
			open:Destroy()
			open = nil
		end
		if wanted == "Open" and (open == nil or open.Parent == nil) then
			open = makeBun(openName)
		end
		if wanted == "None" then
			if closed ~= nil then
				setAlpha(closed, 1)
			end
			if open ~= nil then
				setAlpha(open, 1)
			end
			swap = nil
		elseif wanted == "Closed" then
			swapBun(open, closed, false)
		else
			swapBun(closed, open, animate and previous == "Closed")
			if animate and previous == "Closed" then
				options.Juice():Burst("Crumbs", topFrame.Position + up * 0.1, rules.Crumbs + 4)
				options.Juice():Burst("Dust", topFrame.Position, 4, Theme.Color.Cream)
			end
		end
	end

	function self.SetGuide(_: any, visible: boolean, progress: number)
		if guideOn == visible and guideProgress == progress then
			return
		end
		guideOn = visible
		guideProgress = progress
		paintGuide()
	end

	function self.SetKnife(_: any, point: Vector3?, pressed: boolean, lean: number)
		const part = knife
		if part == nil then
			return
		end
		if point == nil then
			knifeTarget = nil
			part.Transparency = 1
			return
		end
		const tilt = math.rad(rules.Knife.Tilt) * (if pressed then 0.4 else 1)
		const height = rules.Knife.Height * (if pressed then 0.45 else 1)
		-- the blade lies along the cut line, its tip at the pointer; it leans toward the side of travel
		knifeTarget = CFrame.new(point + up * height - right * (part.Size.X * 0.42)) * orient * CFrame.Angles(0, 0, -tilt * 0.4 * lean) * CFrame.Angles(tilt * 0.5, 0, 0)
		part.Transparency = 0
	end

	function self.SetSausage(_: any, mode: "None" | "Ghost" | "Placed", uv: Vector2?)
		const previousMode = sausageMode
		sausageMode = mode
		if uv ~= nil then
			sausageUv = uv
		end
		hideRail = mode == "Placed" or carryKind == "Sausage"
		if mode == "None" then
			if sausage ~= nil then
				setAlpha(sausage, 1)
			end
			hideRail = carryKind == "Sausage"
			return
		end
		const model = ensureSausage()
		if model == nil then
			return
		end
		model:PivotTo(sausageCf(sausageUv))
		setAlpha(model, if mode == "Ghost" then 0.6 else 0)
		-- it snaps into the groove: a squash and stretch (spring) and a puff, once
		if mode == "Placed" and previousMode ~= "Placed" then
			options.Juice():Pop(model, 1.4)
			options.Juice():Burst("Dust", model:GetPivot().Position, 4, Theme.Color.Cream)
		end
	end

	function self.SetCarry(_: any, kind: "Sausage" | "Plate" | nil, point: Vector3?, snap: Vector2?)
		if kind == "Plate" then
			if point ~= nil then
				if not lifted then
					lifted = true
					liftRest = anchorPos
					slide = nil
					bias = 0
				end
				liftTarget = Vector3.new(point.X, anchorPos.Y, point.Z)
				Ghost.Hold("board", "Plate", nil, liftTarget)
			end
			return
		end
		-- the live drag (DEC-259): the plate or the sausage is let go (a new sausage carry reports itself below)
		Ghost.Hold("board", "None", nil, nil)
		if kind == nil and lifted then
			-- let go: the stack goes back where it was
			lifted = false
			liftTarget = nil
			self:MoveTo(liftRest, 0.25)
		end
		if kind == nil or (point == nil and snap == nil) then
			flight = nil
			carryTarget = nil
			carryKind = ""
			const wasHidden = hideRail
			hideRail = sausageMode == "Placed"
			if wasHidden and not hideRail then
				-- a carried sausage that did not land: the one on the rail comes back at once
				refreshHidden()
			end
			if carry ~= nil then
				carry:Destroy()
				carry = nil
				carryPose = nil
			end
			return
		end
		if carry == nil or carryKind ~= kind then
			if carry ~= nil then
				carry:Destroy()
			end
			carryKind = kind
			carryPose = nil
			const source = kitModel("Food", if kind == "Sausage" then "SausageGrilled" else "BunOpen")
			if source ~= nil then
				const made = inert(source, folder, rules.Carry.Alpha)
				made.Name = "Prep_Carry"
				made:ScaleTo(scale)
				carry = made
			end
		end
		hideRail = sausageMode == "Placed" or kind == "Sausage"
		if snap ~= nil then
			carryTarget = sausageCf(snap)
		elseif point ~= nil then
			-- the aim already lifted the point over the plane (Rules.World.Lift): the thing hangs ON the pointer ray, under the cursor
			carryTarget = CFrame.new(point) * orient
		end
		Ghost.Hold("board", "Sausage", nil, if carryTarget ~= nil then carryTarget.Position else point)
	end

	function self.SetTopping(_: any, key: string, uv: Vector2?, grow: number)
		local entry = toppings[key]
		if uv == nil then
			if entry ~= nil then
				entry.Model:Destroy()
				toppings[key] = nil
			end
			return
		end
		if entry == nil then
			const source = kitModel("Toppings", key)
			if source == nil then
				return
			end
			const model = inert(source, folder, 0)
			model.Name = `Prep_Topping_{key}`
			model:ScaleTo(scale)
			entry = { Model = model, Uv = uv, Grow = grow, Scaled = scale }
			toppings[key] = entry
		end
		const item = entry :: { Model: Model, Uv: Vector2, Grow: number, Scaled: number }
		item.Uv = uv
		item.Grow = grow
		const wanted = math.max(scale * grow, 0.05)
		if math.abs(item.Scaled - wanted) > 1e-3 then
			item.Scaled = wanted
			item.Model:ScaleTo(wanted)
		end
		poseTopping(key, item)
		if grow >= 1 and (item :: any).Popped ~= true then
			-- a topping that lands: it springs
			(item :: any).Popped = true
			options.Juice():Pop(item.Model, 1.2)
			options.Juice():Burst("Sparks", item.Model:GetPivot().Position + up * 0.15, 4, Theme.Color.Cream)
		end
	end

	function self.Close(_: any, done: () -> ())
		closing = { T = 0, Done = done }
	end

	function self.TakeAway(_: any, done: (() -> ())?)
		if takeaway ~= nil then
			if done ~= nil then
				done()
			end
			return
		end
		const stack = Instance.new("Model")
		stack.Name = "Prep_TakeAway"
		const parts: { Model } = {}
		for _, model in { plate, closed, open, sausage } do
			if model ~= nil and model.Parent ~= nil and model:FindFirstChildWhichIsA("BasePart", true) ~= nil then
				table.insert(parts, model)
			end
		end
		for _, entry in toppings do
			table.insert(parts, entry.Model)
		end
		for _, model in parts do
			-- only what is drawn goes with it (a hidden bun state is fully transparent)
			const probe = model:FindFirstChildWhichIsA("BasePart", true)
			if probe ~= nil and probe.Transparency < 1 then
				inert(model, stack, 0)
				setAlpha(model, 1)
			end
		end
		if plate ~= nil then
			setAlpha(plate, 1)
		end
		stack.Parent = folder
		takeaway = { Model = stack, From = stack:GetPivot(), Start = stack:GetScale(), T = 0, Done = done }
	end

	function self.SurfaceHeight(_: any, uv: Vector2): number
		-- the sausage in the groove is a cylinder along the bun (X): its round back over the bun top, smoothly joined to the bun
		const radius = SAUSAGE_THICK * 0.5 * scale
		const axis = SAUSAGE_BASE * scale + radius - closedHeight
		const across = (uv.Y - 0.5) * plane.Width
		local sausageTop = -1
		if sausageMode ~= "None" and math.abs(across) < radius then
			sausageTop = axis + math.sqrt(radius * radius - across * across)
		end
		-- smooth max of the sausage and the bun top (0): no kink where the sauce leaves the sausage
		const k = 0.04
		return 0.5 * (sausageTop + math.sqrt(sausageTop * sausageTop + k * k))
	end

	function self.SetProgress(_: any, fraction: number?)
		progress = fraction
		if fraction == nil then
			shownBeads = -1
		end
		if fraction ~= nil and shownBeads == -2 then
			shownBeads = -1
		end
		paintBeads()
	end

	function self.TakeCarry(_: any): Model?
		flight = nil
		if lifted then
			lifted = false
			liftTarget = nil
			const source = if state == "Open" then open elseif state == "Closed" then closed else nil
			local thrown: Model? = nil
			if source ~= nil then
				thrown = inert(source, folder, 0)
				;(thrown :: Model).Name = "Prep_Carry"
				;(thrown :: Model):PivotTo(source:GetPivot())
			end
			-- the real stack is gone with it (the bin eats the copy)
			for _, model in { closed, open, sausage, plate } do
				if model ~= nil then
					setAlpha(model, 1)
				end
			end
			for _, entry in toppings do
				setAlpha(entry.Model, 1)
			end
			return thrown
		end
		const model = carry
		carry = nil
		carryTarget = nil
		carryPose = nil
		carryKind = ""
		hideRail = sausageMode == "Placed"
		return model
	end

	function self.Burst(_: any, band: string)
		const at = topFrame.Position + up * 0.4
		options.Juice():Grade(band, at, self:BunModel(), nil)
	end

	function self.Celebrate(_: any, band: string)
		const at = topFrame.Position + up * 0.5
		const confetti = Content.Prep.Rules.World.Juice.Confetti
		options.Juice():Burst("Confetti", at, (confetti :: any)[band] or 0)
		if band == "Perfect" then
			options.Juice():Burst("Coins", at, 4)
		end
	end

	function self.Dust(_: any)
		options.Juice():Burst("Dust", topFrame.Position, rules.Crumbs, Theme.Color.Cream)
	end

	function self.Step(_: any, dt: number, _time: number)
		-- the slide of the plate between sections
		if slide ~= nil then
			slide.T += dt
			const t = math.clamp(slide.T / slide.Time, 0, 1)
			const c1 = 1.2
			const u = t - 1
			const alpha = 1 + (c1 + 1) * u * u * u + c1 * u * u
			bias = slide.Bias0 * (1 - t)
			hopLift = math.sin(math.pi * t) * 0.18
			if t >= 1 then
				const target = slide.To
				slide = nil
				bias = 0
				hopLift = 0
				place(target)
			else
				place(slide.From:Lerp(slide.To, alpha))
			end
		end
		-- a plate dragged to the bin: the stack follows the pointer (a spring)
		if lifted and liftTarget ~= nil then
			slide = nil
			hopLift = 0.25
			place(anchorPos:Lerp(liftTarget, 1 - math.exp(-rules.Carry.Spring * dt)))
		end
		-- the plate grows into place when it appears
		if plate ~= nil and plateGrow < 1 then
			plateGrow = math.min(1, plateGrow + dt * 4)
			plate:ScaleTo(plateGrow)
		end
		-- the world's own objects stay hidden
		hideAt -= dt
		if hideAt <= 0 then
			hideAt = HIDE_EVERY
			refreshHidden()
		end
		-- Closed -> Open: a hop
		const bun = if state == "Open" then open else closed
		if bun ~= nil and state ~= "None" then
			local hop = 0
			if swap ~= nil then
				swap.T += dt
				const t = math.clamp(swap.T / swap.Time, 0, 1)
				hop = rules.Open.Hop * math.sin(math.pi * t)
				if t >= 1 then
					swap = nil
				end
			end
			local squash = 1
			if closing ~= nil then
				closing.T += dt
				const t = math.clamp(closing.T / rules.Close, 0, 1)
				-- the open bun wraps the plate: it dips, then the closed bun pops over it
				if t > 0.5 and state == "Open" then
					self:SetBun("Closed", false)
					if sausage ~= nil then
						setAlpha(sausage, 1)
					end
					for _, entry in toppings do
						setAlpha(entry.Model, 1)
					end
					self:Dust()
				end
				squash = 1 - 0.12 * math.sin(math.pi * t)
				if t >= 1 then
					const finished = closing
					closing = nil
					finished.Done()
				end
			end
			bun:PivotTo(baseCf * CFrame.new(0, hop, 0) * CFrame.new(0, 0, 0))
			if squash ~= 1 then
				bun:PivotTo(baseCf * CFrame.new(0, hop - (1 - squash) * closedHeight * 0.5, 0))
			end
		end
		-- the finished plate leaving with the hot dog: it rises, goes to the hand of the camera and shrinks away
		if takeaway ~= nil then
			const leaving = takeaway
			leaving.T += dt
			const t = math.clamp(leaving.T / TAKEAWAY_TIME, 0, 1)
			const camera = workspace.CurrentCamera
			if camera ~= nil then
				const frame = camera.CFrame
				const hand = frame.Position + frame.LookVector * 0.9 - frame.UpVector * 0.45 + frame.RightVector * 0.35
				const eased = t * t * (3 - 2 * t)
				const arc = math.sin(math.pi * math.min(t * 1.4, 1)) * 0.3
				leaving.Model:PivotTo(CFrame.new(leaving.From.Position:Lerp(hand, eased) + up * arc) * leaving.From.Rotation)
				leaving.Model:ScaleTo(math.max(leaving.Start * (1 - 0.85 * eased), 0.02))
			end
			if t >= 1 then
				takeaway = nil
				leaving.Model:Destroy()
				if leaving.Done ~= nil then
					leaving.Done()
				end
			end
		end
		-- the knife
		if knife ~= nil and knifeTarget ~= nil then
			if knifePose == nil then
				knifePose = knifeTarget
			else
				knifePose = knifePose:Lerp(knifeTarget, 1 - math.exp(-rules.Knife.Spring * dt))
			end
			knife.CFrame = knifePose :: CFrame
		end
		-- the carried sausage in flight to the groove
		if carry ~= nil and flight ~= nil then
			flight.T += dt
			const t = math.clamp(flight.T / FLY_TIME, 0, 1)
			const c1 = 1.2
			const u = t - 1
			const alpha = 1 + (c1 + 1) * u * u * u + c1 * u * u
			const goalCf = sausageCf(GROOVE_UV)
			const at = flight.From:Lerp(goalCf.Position, alpha) + up * (math.sin(math.pi * t) * FLY_ARC)
			carry:PivotTo(CFrame.new(at) * orient)
			if t >= 1 then
				const finished = flight.Done
				flight = nil
				finished()
			end
		elseif carry ~= nil and carryTarget ~= nil then
			if carryPose == nil then
				carryPose = carryTarget
			else
				carryPose = carryPose:Lerp(carryTarget, 1 - math.exp(-rules.Carry.Spring * dt))
			end
			carry:PivotTo(carryPose :: CFrame)
		end
		-- a sausage ghost breathes a little
		if sausage ~= nil and sausageMode == "Ghost" then
			setAlpha(sausage, 0.55 + 0.1 * math.sin(os.clock() * 5))
		end
	end

	function self.Destroy(_: any)
		Ghost.Hold("board", "None", nil, nil)
		unhide()
		flight = nil
		if plate ~= nil then
			plate:Destroy()
			plate = nil
		end
		for _, dash in dashes do
			dash:Destroy()
		end
		table.clear(dashes)
		for _, model in { closed, open, sausage, carry } do
			if model ~= nil then
				model:Destroy()
			end
		end
		for _, entry in toppings do
			entry.Model:Destroy()
		end
		table.clear(toppings)
		if knife ~= nil then
			knife:Destroy()
			knife = nil
		end
		closing = nil
		swap = nil
		if takeaway ~= nil then
			takeaway.Model:Destroy()
			takeaway = nil
		end
		for _, bead in beads do
			bead:Destroy()
		end
		table.clear(beads)
		if mat ~= nil then
			mat:Destroy()
			mat = nil
		end
	end

	placeBeads()
	return self :: View
end

return BoardView
