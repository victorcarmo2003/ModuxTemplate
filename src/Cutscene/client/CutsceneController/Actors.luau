--!strict
-- Actors: client-only actors and props of the cutscenes (architecture.md §19.16 "Atores"; Content.Cutscenes beat
-- `Actor`; script.md §1; ending.md §2.2, §2.4; MAP-01 §11). Never replicated, never touched by the server.
--
-- Every actor is a pure function of its own time t (seconds since its beat): Update(t, last) poses it for t and
-- plays a sound only when an instant falls in (last, t], so an actor created late (join in the middle of the scene)
-- shows the right pose without replaying the sounds that already happened.
--
--   ToyCarNinth    toy car along the Ninth, across the CS-3 -> CS-4 crossing, without stopping (DEC-130, DEC-133)
--   ToyCarJuniper  toy car between the flyer post (P-01) and the cart (CS-7, "beep-beep!")
--   FlipPhone      the open flip (AST-038, no opening animation) of the avatar on CS-P1 (slot 1, Q-106 c):
--                  low in the own view when that avatar is this client, in the right hand of a mate otherwise
--   MartDoor       Mart door bell at MKT-DOOR (sound only; the door is map geometry)
--   Walt           Walt Bramble (CHR-001, turtle, DEC-202): MKT-DOOR -> WALT-1 at a slow walk, cane, beard, coffee
--   WaltCoffee     Walt's offer: a coffee flies from his hand to the front of THIS client's camera (ending.md §2.2)
--   RaincoatLady   frog (DEC-203) in a raincoat with an umbrella: RL-1 -> RL-END, nods at Walt, sinks into a puddle
--   Flyer          "NIGHT SHIFT — NOW HIRING" flyer flapping on the P-01 post (ending.md §2.4, AN-03)
--
-- PROVISIONAL (TASK-121): Walt and the Raincoat Lady are CrewRig placeholders (civil outfit + Part props) until the
-- sheets AST-059 / CHR-001 ship (TASK-125); toy cars, the flip, the coffee, the puddle and the flyer are Part
-- placeholders; every speed and time below.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)

export type Actor = {
	Model: Model?,
	Update: (t: number, last: number) -> (),
	Destroy: () -> (),
}

export type Context = {
	-- MapPoint by id (ground level, facing)
	Point: (id: string) -> CFrame?,
	-- ground point under a StreetLight by PostId
	Post: (id: string) -> Vector3?,
	-- another actor of the running segment
	Find: (target: string) -> Actor?,
	Play: (sound: string, at: Vector3 | Instance?) -> (),
	-- AnimController
	Bind: (model: Model, set: string) -> (),
	Action: (model: Model, key: string) -> (),
	Folder: Instance,
}

const SPAWN_LIFT = Vector3.new(0, 3, 0) -- architecture.md §18.5
const FLYER_HEIGHT = 4.5 -- studs above the post base (eye height, style guide)
const CAR_LIFT = 0.9
const CAR_REACH = 45 -- studs each side of the crossing point
const CAR_TIME = 2.6 -- s to cross the whole reach
const CAR_HONK = 0.4 -- fraction of the pass
const FLIP_TIME = 16 -- s on screen: shot 7 (25 s) to the turn to the cart (41 s)
const FLIP_OFFSET = CFrame.new(0.55, -0.8, -1.7) * CFrame.Angles(math.rad(20), math.rad(-15), 0)
const WALT_SPEED = 3 -- studs/s, hunched with a cane
const COFFEE_FLY = 1.2
const COFFEE_HOLD = 6
const COFFEE_BACK = 1
const COFFEE_OFFSET = CFrame.new(0, -0.55, -2.2)
const LADY_WALK = 8 -- s from RL-1 to RL-END (arrives before "Morning, Marigold" at 46 s)
const LADY_NOD = 1
const LADY_SINK = 0.6
const LADY_DEPTH = 4.5
const PUDDLE_TIME = 3
const FLAP_SPEED = 5
const FLAP_ANGLE = math.rad(10)

const INK = Color3.fromHex("#2B2233")
const CREAM = Color3.fromHex("#FFF1D6")
const MUSTARD = Color3.fromHex("#F6C12B")
const KETCHUP = Color3.fromHex("#E2402E")
const TEAL = Color3.fromHex("#3FA7B5")
const PUDDLE = Color3.fromHex("#4C6A8A")
const CANE = Color3.fromHex("#7A5230")
const BEARD = Color3.fromHex("#F4F4F4")

const Actors = {}

-- Geometry -----------------------------------------------------------------------------------------------------

local function part(name: string, size: Vector3, color: Color3, parent: Instance?): Part
	const p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function cylinder(name: string, size: Vector3, color: Color3, parent: Instance?): Part
	const p = part(name, size, color, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Welds `p` to `host` where it stands now (the rig is anchored and moved by PivotTo)
local function attach(p: BasePart, host: BasePart, offset: CFrame)
	p.CFrame = host.CFrame * offset
	p.Anchored = false
	p.Massless = true
	const weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = p
	weld.Parent = p
	p.Parent = host.Parent
end

local function limb(model: Model, name: string): BasePart?
	const found = model:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

local function flat(v: Vector3): Vector3
	const f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

local function crossed(at: number, t: number, last: number): boolean
	return last < at and at <= t
end

-- Local rig from the crew kit (Opal pattern: untagged, anchored, no Humanoid; AnimController animates it)
local function rig(name: string, species: string, outfit: string, cap: boolean, at: CFrame, ctx: Context): Model?
	const options: CrewRig.BuildOptions = {
		Name = name,
		CFrame = at + SPAWN_LIFT,
		Anchored = true,
		Tag = false,
		LookPack = "Day",
		Cap = cap,
	}
	const ok, result = pcall(function(): Model
		return CrewRig.Build(species, outfit, options)
	end)
	if not ok then
		warn(`[CutsceneController] could not build {name}: {result}`)
		return nil
	end
	const model = result :: Model
	const humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid:Destroy()
	end
	model.Parent = ctx.Folder
	CrewRig.Dress(model, "Day", "Normal")
	return model
end

-- Walk along a straight segment at `speed`, then face `stop` (rig pivot = HumanoidRootPart = ground + 3)
local function walkPose(from: CFrame, stop: CFrame, speed: number, t: number): CFrame
	const a = from.Position
	const b = stop.Position
	const distance = (b - a).Magnitude
	const time = distance / math.max(speed, 1e-3)
	if t >= time or distance < 1e-3 then
		return stop + SPAWN_LIFT
	end
	const position = a:Lerp(b, math.max(t, 0) / time)
	return CFrame.lookAt(position, position + flat(b - a)) + SPAWN_LIFT
end

-- Actors --------------------------------------------------------------------------------------------------------

local function toyCar(name: string, a: Vector3, b: Vector3, paint: Color3, horn: string, ctx: Context): Actor
	const model = Instance.new("Model")
	model.Name = name
	const body = part("Body", Vector3.new(2.4, 1.1, 4.4), paint, model)
	const cabin = part("Cabin", Vector3.new(2, 0.9, 2.2), CREAM, model)
	cabin.CFrame = body.CFrame * CFrame.new(0, 0.95, 0.3)
	for _, offset in { Vector3.new(1.2, -0.45, -1.4), Vector3.new(-1.2, -0.45, -1.4), Vector3.new(1.2, -0.45, 1.4), Vector3.new(-1.2, -0.45, 1.4) } do
		const wheel = cylinder("Wheel", Vector3.new(0.5, 1, 1), INK, model)
		wheel.CFrame = body.CFrame * CFrame.new(offset)
	end
	model.PrimaryPart = body
	model.Parent = ctx.Folder

	-- across the crossing: perpendicular to a -> b in the ground plane
	const across = flat(b - a)
	const lane = Vector3.new(across.Z, 0, -across.X)
	const middle = (a + b) / 2 + Vector3.new(0, CAR_LIFT, 0)
	const from = middle - lane * CAR_REACH
	const to = middle + lane * CAR_REACH

	return {
		Model = model,
		Update = function(t: number, last: number)
			if t >= CAR_TIME then
				model.Parent = nil
				return
			end
			model.Parent = ctx.Folder
			const position = from:Lerp(to, math.clamp(t / CAR_TIME, 0, 1))
			model:PivotTo(CFrame.lookAt(position, position + lane))
			if crossed(CAR_TIME * CAR_HONK, t, last) then
				ctx.Play(horn, body)
			end
		end,
		Destroy = function()
			model:Destroy()
		end,
	}
end

-- Character standing nearest to a point (the avatar the server walked to CS-P1)
local function nearestCharacter(point: Vector3): Model?
	local best: Model? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		const character = player.Character
		const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if character ~= nil and root ~= nil and root:IsA("BasePart") then
			const distance = (root.Position - point).Magnitude
			if distance < bestDistance then
				best = character
				bestDistance = distance
			end
		end
	end
	return best
end

local function flipModel(parent: Instance?): (Model, BasePart)
	const model = Instance.new("Model")
	model.Name = "FlipPhone"
	const base = part("Base", Vector3.new(0.32, 0.5, 0.08), KETCHUP, model)
	const lid = part("Lid", Vector3.new(0.32, 0.5, 0.08), KETCHUP, model)
	lid.CFrame = base.CFrame * CFrame.new(0, 0.48, -0.06) * CFrame.Angles(math.rad(-20), 0, 0)
	const screen = part("Screen", Vector3.new(0.24, 0.32, 0.02), TEAL, model)
	screen.Material = Enum.Material.Neon
	screen.CFrame = lid.CFrame * CFrame.new(0, 0.02, -0.045)
	for _, p in { lid, screen } do
		const weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = p
		weld.Parent = p
		p.Anchored = false
		p.Massless = true
	end
	model.PrimaryPart = base
	model.Parent = parent
	return model, base
end

local function flipPhone(ctx: Context): Actor?
	const mark = ctx.Point("CS-P1")
	if mark == nil then
		return nil
	end
	const holder = nearestCharacter(mark.Position)
	if holder == nil then
		return nil
	end
	const own = holder == Players.LocalPlayer.Character
	const model, base = flipModel(nil)
	if own then
		-- low in the own view (no hand, script.md §1 shot 7)
		model.Parent = Workspace.CurrentCamera
	else
		const hand = limb(holder, "Right Arm")
		if hand == nil then
			model:Destroy()
			return nil
		end
		base.CFrame = hand.CFrame * CFrame.new(0, -1.15, -0.25)
		base.Anchored = false
		base.Massless = true
		const weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = base
		weld.Parent = base
		model.Parent = holder
	end

	return {
		Model = model,
		Update = function(t: number, last: number)
			if t >= FLIP_TIME then
				model.Parent = nil
				return
			end
			if own then
				const camera = Workspace.CurrentCamera
				if camera ~= nil then
					model.Parent = camera
					model:PivotTo(camera.CFrame * FLIP_OFFSET)
				end
			end
			if crossed(0.05, t, last) then
				ctx.Play("phone_pickup", if own then nil else base)
			end
		end,
		Destroy = function()
			model:Destroy()
		end,
	}
end

local function martDoor(ctx: Context): Actor?
	const door = ctx.Point("MKT-DOOR")
	if door == nil then
		return nil
	end
	return {
		Model = nil,
		Update = function(t: number, last: number)
			if crossed(0, t, last) then
				ctx.Play("door_creak", door.Position)
			end
		end,
		Destroy = function() end,
	}
end

local function walt(ctx: Context): Actor?
	const door = ctx.Point("MKT-DOOR")
	const stop = ctx.Point("WALT-1")
	if door == nil or stop == nil then
		return nil
	end
	const start = CFrame.lookAt(door.Position, door.Position + flat(stop.Position - door.Position))
	-- PROVISIONAL (CHR-001 sheet): civil outfit, crew cap standing in for his red cap
	const model = rig("Walt", "turtle", "civil_c", true, start, ctx)
	if model == nil then
		return nil
	end
	const right = limb(model, "Right Arm")
	const left = limb(model, "Left Arm")
	const head = limb(model, "Head")
	if right ~= nil then
		const cane = cylinder("Cane", Vector3.new(3.2, 0.22, 0.22), CANE, nil)
		attach(cane, right, CFrame.new(0, -1.9, -0.35) * CFrame.Angles(0, 0, math.rad(90)))
	end
	if head ~= nil then
		const beard = part("Beard", Vector3.new(0.9, 0.55, 0.35), BEARD, nil)
		beard.Shape = Enum.PartType.Ball
		attach(beard, head, CFrame.new(0, -0.45, -0.5))
	end
	if left ~= nil then
		const cup = cylinder("Coffee", Vector3.new(0.5, 0.35, 0.35), CREAM, nil)
		attach(cup, left, CFrame.new(0, -1.15, -0.3) * CFrame.Angles(0, 0, math.rad(90)))
	end
	ctx.Bind(model, "walt")

	local posed: CFrame? = nil
	return {
		Model = model,
		Update = function(t: number, _last: number)
			const pose = walkPose(start, stop, WALT_SPEED, t)
			if posed == nil or posed ~= pose then
				posed = pose
				model:PivotTo(pose)
			end
		end,
		Destroy = function()
			model:Destroy()
		end,
	}
end

local function waltCoffee(ctx: Context): Actor?
	const waltActor = ctx.Find("Walt")
	const model = if waltActor ~= nil then waltActor.Model else nil
	const hand = if model ~= nil then limb(model, "Left Arm") else nil
	if model == nil or hand == nil then
		return nil
	end
	const cup = cylinder("OfferedCoffee", Vector3.new(0.5, 0.35, 0.35), CREAM, ctx.Folder)
	const lid = cylinder("Lid", Vector3.new(0.08, 0.38, 0.38), INK, cup)

	local function handFrame(): CFrame
		return hand.CFrame * CFrame.new(0, -1.15, -0.3)
	end

	return {
		Model = nil,
		Update = function(t: number, last: number)
			const camera = Workspace.CurrentCamera
			if camera == nil or t >= COFFEE_FLY + COFFEE_HOLD + COFFEE_BACK then
				cup.Parent = nil
				return
			end
			cup.Parent = ctx.Folder
			const front = camera.CFrame * COFFEE_OFFSET
			local position: Vector3
			if t < COFFEE_FLY then
				position = handFrame().Position:Lerp(front.Position, math.clamp(t / COFFEE_FLY, 0, 1))
			elseif t < COFFEE_FLY + COFFEE_HOLD then
				position = front.Position
			else
				const back = (t - COFFEE_FLY - COFFEE_HOLD) / COFFEE_BACK
				position = front.Position:Lerp(handFrame().Position, math.clamp(back, 0, 1))
			end
			-- upright cup (cylinder axis is X)
			cup.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
			lid.CFrame = cup.CFrame * CFrame.new(0.21, 0, 0)
			if crossed(0, t, last) then
				ctx.Action(model, "walt_offer_coffee")
			end
		end,
		Destroy = function()
			cup:Destroy()
		end,
	}
end

local function raincoatLady(ctx: Context): Actor?
	const from = ctx.Point("RL-1")
	const stop = ctx.Point("RL-END")
	if from == nil or stop == nil then
		return nil
	end
	const start = CFrame.lookAt(from.Position, from.Position + flat(stop.Position - from.Position))
	-- PROVISIONAL (AST-059, TASK-125): civil frog with a Part raincoat and umbrella
	const model = rig("RaincoatLady", "frog", "civil_d", false, start, ctx)
	if model == nil then
		return nil
	end
	const torso = limb(model, "Torso")
	const right = limb(model, "Right Arm")
	if torso ~= nil then
		const coat = part("Raincoat", torso.Size * Vector3.new(1.15, 1.25, 1.2), MUSTARD, nil)
		attach(coat, torso, CFrame.new(0, -0.2, 0))
	end
	if right ~= nil then
		const stick = cylinder("UmbrellaStick", Vector3.new(3.2, 0.12, 0.12), INK, nil)
		attach(stick, right, CFrame.new(0, 0.6, -0.2) * CFrame.Angles(0, 0, math.rad(90)))
		const canopy = cylinder("Umbrella", Vector3.new(0.35, 4.2, 4.2), TEAL, nil)
		attach(canopy, right, CFrame.new(0, 2.2, -0.2) * CFrame.Angles(0, 0, math.rad(90)))
	end
	ctx.Bind(model, "npc")

	-- nods towards Walt's mark when she arrives (ending.md §2.2)
	const waltMark = ctx.Point("WALT-1")
	const facing = if waltMark ~= nil
		then CFrame.lookAt(stop.Position, stop.Position + flat(waltMark.Position - stop.Position))
		else stop
	const puddle = cylinder("Puddle", Vector3.new(0.05, 4, 4), PUDDLE, nil)
	puddle.CFrame = CFrame.new(stop.Position + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
	puddle.Material = Enum.Material.Glass
	puddle.Transparency = 0.25

	local posed: CFrame? = nil
	return {
		Model = model,
		Update = function(t: number, last: number)
			const gone = LADY_WALK + LADY_NOD + LADY_SINK
			local pose: CFrame
			if t < LADY_WALK then
				pose = walkPose(start, stop, (stop.Position - start.Position).Magnitude / LADY_WALK, t)
			elseif t < LADY_WALK + LADY_NOD then
				pose = facing + SPAWN_LIFT
			else
				const sink = math.clamp((t - LADY_WALK - LADY_NOD) / LADY_SINK, 0, 1)
				pose = facing + SPAWN_LIFT - Vector3.new(0, LADY_DEPTH * sink, 0)
			end
			if posed == nil or posed ~= pose then
				posed = pose
				model:PivotTo(pose)
			end
			model.Parent = if t < gone then ctx.Folder else nil

			-- the puddle shows from the sink and dries out
			const wet = t - LADY_WALK - LADY_NOD
			if wet >= 0 and wet < LADY_SINK + PUDDLE_TIME then
				puddle.Parent = ctx.Folder
				puddle.LocalTransparencyModifier = math.clamp((wet - LADY_SINK) / PUDDLE_TIME, 0, 1)
			else
				puddle.Parent = nil
			end
			if crossed(LADY_WALK + LADY_NOD, t, last) then
				ctx.Play("splash", stop.Position)
			end
		end,
		Destroy = function()
			model:Destroy()
			puddle:Destroy()
		end,
	}
end

local function flyerPart(): Part
	const flyer = part("Flyer", Vector3.new(1.4, 1.9, 0.05), CREAM, nil)
	const gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 0
	gui.Parent = flyer
	const lines = {
		{ Text = "NIGHT SHIFT —\nNOW HIRING", Size = 24, Y = 0.08, H = 0.34 },
		{ Text = "Must notice things.", Size = 16, Y = 0.5, H = 0.18 },
		{ Text = "Call 555-0179", Size = 18, Y = 0.72, H = 0.18 },
	}
	for index, line in lines do
		const label = Instance.new("TextLabel")
		label.Name = `Line{index}`
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.06, line.Y)
		label.Size = UDim2.fromScale(0.88, line.H)
		label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		label.TextSize = line.Size
		label.TextWrapped = true
		label.TextColor3 = INK
		label.Text = line.Text
		label.Parent = gui
	end
	return flyer
end

local function flyer(ctx: Context): Actor?
	const ground = ctx.Post("P-01")
	const camera = Workspace.CurrentCamera
	if ground == nil or camera == nil then
		return nil
	end
	const center = ground + Vector3.new(0, FLYER_HEIGHT, 0)
	const toward = flat(camera.CFrame.Position - center)
	const hang = CFrame.lookAt(center + toward * 0.45, center + toward * 2)
	const sheet = flyerPart()
	sheet.Parent = ctx.Folder
	const half = sheet.Size.Y / 2

	return {
		Model = nil,
		Update = function(t: number, _last: number)
			const angle = math.sin(t * FLAP_SPEED) * FLAP_ANGLE
			sheet.CFrame = hang * CFrame.new(0, half, 0) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -half, 0)
		end,
		Destroy = function()
			sheet:Destroy()
		end,
	}
end

-- Builds the actor of an `Actor` beat; nil = unknown target or missing map points (warned once by the caller)
function Actors.Create(target: string, ctx: Context): Actor?
	if target == "ToyCarNinth" then
		const a = ctx.Point("CS-3")
		const b = ctx.Point("CS-4")
		return if a ~= nil and b ~= nil then toyCar(target, a.Position, b.Position, TEAL, "car_honk_soft", ctx) else nil
	elseif target == "ToyCarJuniper" then
		const a = ctx.Post("P-01")
		const b = ctx.Point("CART")
		return if a ~= nil and b ~= nil then toyCar(target, a, b.Position, MUSTARD, "car_honk_soft", ctx) else nil
	elseif target == "FlipPhone" then
		return flipPhone(ctx)
	elseif target == "MartDoor" then
		return martDoor(ctx)
	elseif target == "Walt" then
		return walt(ctx)
	elseif target == "WaltCoffee" then
		return waltCoffee(ctx)
	elseif target == "RaincoatLady" then
		return raincoatLady(ctx)
	elseif target == "Flyer" then
		return flyer(ctx)
	end
	return nil
end

return table.freeze(Actors)
