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
--   bin        a PLACEHOLDER bin on the bench (Provisional: the real one is on the floor behind the camera, MAP-01 §19.2)
-- The world draws its own board bun from the `Stations` record (KitchenController Board part); it is hidden LOCALLY (LocalTransparency
-- Modifier) while this view lives and given back on Destroy. Everything made here lives under the PrepWorld folder and dies with it.
-- No Modux, no Vide, no network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)
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
	-- Slides the plate to a new place (the Toppings view looks at another part of the board); the bin shows only there.
	MoveTo: (self: View, position: Vector3, time: number) -> (),
	Anchor: (self: View) -> Vector3,
	SetMoved: (self: View, fn: ((delta: Vector3) -> ())?) -> (),
	SetBinVisible: (self: View, on: boolean) -> (),
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
	-- The placeholder bin: its hitbox part and where it sits.
	BinPart: BasePart,
	BinModel: Model,
	Burst: (self: View, band: string) -> (),
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
}

const BoardView = {}

const BUN_LENGTH, BUN_WIDTH, BUN_HEIGHT = 1.0, 0.45, 0.35
const SAUSAGE_BASE = 0.2 -- of the bun height x scale: the groove
const SAUSAGE_THICK = 0.24
const KNIFE_SCALE = 0.5 -- of the board scale
const HIDE_EVERY = 0.25 -- s: the world re-makes its models, so the hiding is re-applied at 4 Hz

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
	local anchorPos = options.Anchor
	local baseCf = CFrame.new(anchorPos + up * rules.Lift) * orient
	const closedHeight = BUN_HEIGHT * scale
	const openHeight = 0.345 * scale
	local topFrame = CFrame.new(anchorPos + up * (rules.Lift + closedHeight)) * orient
	const plane = Plane.new(topFrame, BUN_LENGTH * scale, BUN_WIDTH * scale)

	-- the bun: both kit models, one shown ------------------------------------------------------------------------------------
	local closed: Model? = nil
	local open: Model? = nil
	local state: BunState = "None"
	local swap: { T: number, Time: number }? = nil
	local closing: { T: number, Done: () -> () }? = nil

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

	-- the placeholder bin ----------------------------------------------------------------------------------------------------------
	const binModel = Instance.new("Model")
	binModel.Name = "Prep_PlaceholderBin"
	const binSize = rules.Bin.Size
	local binCf = CFrame.new(anchorPos + right * rules.Bin.Right + orient.ZVector * rules.Bin.Back) * orient
	const binBody = Instance.new("Part")
	binBody.Name = "Body"
	binBody.Shape = Enum.PartType.Cylinder
	binBody.Material = Enum.Material.SmoothPlastic
	binBody.Color = Theme.Tone.Slate.Bottom
	binBody.Size = Vector3.new(binSize * 1.1, binSize * 0.9, binSize * 0.9)
	binBody.Anchored = true
	binBody.CanCollide = false
	binBody.CanQuery = true
	binBody.CanTouch = false
	binBody.CastShadow = false
	binBody.Parent = binModel
	const binLid = Instance.new("Part")
	binLid.Name = "Lid"
	binLid.Shape = Enum.PartType.Cylinder
	binLid.Material = Enum.Material.SmoothPlastic
	binLid.Color = Theme.Color.Mustard
	binLid.Size = Vector3.new(binSize * 0.1, binSize * 1.0, binSize * 1.0)
	binLid.Anchored = true
	binLid.CanCollide = false
	binLid.CanQuery = false
	binLid.CanTouch = false
	binLid.CastShadow = false
	binLid.Parent = binModel
	binModel.Parent = folder
	local binShown = false

	local function placeBin()
		binCf = CFrame.new(anchorPos + right * rules.Bin.Right + orient.ZVector * rules.Bin.Back) * orient
		binBody.CFrame = binCf * CFrame.new(0, binSize * 0.55, 0) * CFrame.Angles(0, 0, math.pi / 2)
		binLid.CFrame = binCf * CFrame.new(0, binSize * 1.15, 0) * CFrame.Angles(0, 0, math.pi / 2)
		binBody.Transparency = if binShown then 0 else 1
		binLid.Transparency = if binShown then 0 else 1
	end
	placeBin()

	-- the world's own objects, hidden locally -----------------------------------------------------------------------------------
	const hidden: { Instance } = {}
	local hideAt = 0
	local hideRail = false
	local hideBar: { BillboardGui } = {}

	local function hide(instance: Instance)
		if table.find(hidden, instance) == nil then
			table.insert(hidden, instance)
		end
		setLocal(instance, 1)
	end

	local function refreshHidden()
		const entry = options.SlotView("board", options.Seat)
		if entry ~= nil and entry.Station ~= nil then
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
		if hideRail then
			const rail = options.SlotView("rail", options.RailFront)
			if rail ~= nil and rail.Station ~= nil then
				for _, child in rail.Station:GetChildren() do
					if child:IsA("Model") and string.find(child.Name, `^Sausage%a*_Slot{options.RailFront}$`) ~= nil then
						hide(child)
					end
				end
			end
		end
	end

	local function unhide()
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
		BinPart = binBody,
		BinModel = binModel,
	} :: any

	-- Where the plate sits: the bun, the sausage, the toppings, the guide and the bin follow (the sauce segments are moved by the
	-- listener of `SetMoved`, they are not ours).
	local moved: ((delta: Vector3) -> ())? = nil
	local goal: Vector3? = nil
	local slideSpeed = 0

	local function place(position: Vector3)
		const delta = position - anchorPos
		anchorPos = position
		baseCf = CFrame.new(anchorPos + up * rules.Lift) * orient
		topFrame = CFrame.new(anchorPos + up * (rules.Lift + closedHeight)) * orient
		plane.Frame = topFrame
		placeDashes()
		placeBin()
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

	-- Slides the plate to `position` in `time` seconds (0 = at once).
	function self.MoveTo(_: any, position: Vector3, time: number)
		if time <= 0 then
			goal = nil
			place(position)
			return
		end
		goal = position
		slideSpeed = (position - anchorPos).Magnitude / time
	end

	function self.Anchor(_: any): Vector3
		return anchorPos
	end

	function self.SetMoved(_: any, fn: ((delta: Vector3) -> ())?)
		moved = fn
	end

	function self.SetBinVisible(_: any, on: boolean)
		binShown = on
		placeBin()
		binBody.CanQuery = on
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
		if wanted == "Open" and (open == nil or open.Parent == nil) then
			open = makeBun("BunOpen")
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
				Fx.Burst(topFrame.Position, "Dust", rules.Crumbs, Theme.Color.Cream)
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
	end

	function self.SetCarry(_: any, kind: "Sausage" | "Plate" | nil, point: Vector3?, snap: Vector2?)
		if kind == nil or (point == nil and snap == nil) then
			carryTarget = nil
			carryKind = ""
			hideRail = sausageMode == "Placed"
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
			carryTarget = CFrame.new(point + up * Content.Prep.Rules.World.Lift) * orient
		end
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
	end

	function self.Close(_: any, done: () -> ())
		closing = { T = 0, Done = done }
	end

	function self.Burst(_: any, band: string)
		const at = topFrame.Position + up * 0.4
		if band == "Perfect" then
			Fx.Burst(at, "Ready", 12, Theme.Color.Mustard)
		elseif band == "Good" then
			Fx.Burst(at, "Ready", 6, Theme.Color.Cream)
		else
			Fx.Burst(at, "Dust", 6)
		end
	end

	function self.Dust(_: any)
		Fx.Burst(topFrame.Position, "Dust", rules.Crumbs, Theme.Color.Cream)
	end

	function self.Step(_: any, dt: number, _time: number)
		-- the slide of the plate between sections
		if goal ~= nil then
			const toGoal = goal - anchorPos
			const step = slideSpeed * dt
			if toGoal.Magnitude <= step then
				const target = goal
				goal = nil
				place(target)
			else
				place(anchorPos + toGoal.Unit * step)
			end
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
		-- the knife
		if knife ~= nil and knifeTarget ~= nil then
			if knifePose == nil then
				knifePose = knifeTarget
			else
				knifePose = knifePose:Lerp(knifeTarget, 1 - math.exp(-rules.Knife.Spring * dt))
			end
			knife.CFrame = knifePose :: CFrame
		end
		-- the carried sausage / plate ghost
		if carry ~= nil and carryTarget ~= nil then
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
		unhide()
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
		binModel:Destroy()
		closing = nil
		swap = nil
	end

	return self :: View
end

return BoardView
