--!strict
--[[
	Finale: the actors of "The Second Coffee" (Content.Cutscenes second_coffee / _in / _out; owner request 2026-10-22,
	PROVISIONAL). Created by Actors.Create for the beats below; client only, never replicated. Like every actor each one is a
	pure function of its own time t (seconds since its beat): Update(t, last) poses it, so a client that arrives late shows the
	right frame (no sounds here: the scenes play them as Sound beats).

	  WaltDawn   Walt walks SCENE-STEPS-FAR -> a few studs from the own body, two coffees, a warm face (Day pack)
	  HandCup    the coffee flies from his hand to the own POV (a paw and a cup in camera space), touches, and starts to tremble
	  WaltTurn   his face goes to the Night pack, flickering the first 0.9 s (a single swap with reduced motion)
	  DoorBlast  the pantry door DOOR-B: its leaf is swapped for a copy that rattles at +0, +1.3, +2.9 s and bursts into the
	             pantry at +Value s (the beat's Value), with debris; the real leaf is hidden locally and restored on Destroy
	  WaltLoom   the doorway silhouette (the beat is the blast): scale 1.28, Night face, wrinkles, a cold light flickering on
	             him; waits LOOM_WAIT s, then strides to LOOM_GAP studs of the own body in LOOM_WALK s (the five stomps are
	             Sound / Quake beats of the scene: LOOM_WAIT + k x 0.6 + 0.3)
	  WaltGrip   his fists at the top corners of the view while he holds the own body by the collar
	  Crowd      the hands of the late crowd closing in from the edges of the view; the whisper bed loops while it lives

	Walt's rig is the same CrewRig stand-in of Actors (turtle, civil_c) until the CHR-001 sheet ships.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)

export type Actor = {
	Model: Model?,
	Update: (t: number, last: number) -> (),
	Destroy: () -> (),
}

-- What the actors need of CutsceneController's ActorContext (Actors.Context is a superset)
export type Context = {
	Point: (id: string) -> CFrame?,
	Find: (target: string) -> Actor?,
	Play: (sound: string, at: Vector3 | Instance?) -> (),
	Loop: (sound: string, at: Instance, on: boolean) -> (),
	Bind: (model: Model, set: string) -> (),
	Folder: Instance,
}

-- The builders of Actors.luau, handed in so the two files do not require each other
export type Kit = {
	Rig: (name: string, species: string, outfit: string, cap: boolean, at: CFrame, ctx: any) -> Model?,
	Part: (name: string, size: Vector3, color: Color3, parent: Instance?) -> Part,
	Cylinder: (name: string, size: Vector3, color: Color3, parent: Instance?) -> Part,
	Attach: (p: BasePart, host: BasePart, offset: CFrame) -> (),
	Limb: (model: Model, name: string) -> BasePart?,
	Flat: (v: Vector3) -> Vector3,
	WalkPose: (from: CFrame, stop: CFrame, speed: number, t: number) -> CFrame,
}

-- Where things are (MapPoint ids; "a|b@f" = fraction f of the way from a to b, facing a -> b)
const STREET_FROM = "SCENE-STEPS-FAR" -- the alley Walt comes from
const STREET_STAND = "SCENE-DOOR-OUT|SCENE-STEPS-FAR@0.2" -- ~4 studs from the own body at SCENE-DOOR-OUT
const OWN_MARK = "SCENE-DOOR-OUT"
const DOORWAY = "SCENE-DOOR-OUT|SCENE-DOOR@0.7" -- inside the frame of DOOR-B, facing into the pantry
const INSIDE = "SCENE-DOOR"
const OUTSIDE = "SCENE-DOOR-OUT"
const DOOR_ID = "DOOR-B"
const DOOR_TAG = "AutoDoor"

-- PROVISIONAL numbers (frontend-coder 2026-10-22)
const SPAWN_LIFT = Vector3.new(0, 3, 0) -- architecture.md §18.5
const WALT_SPEED = 3 -- studs/s of the dawn walk
const CUP_FLY = 0.9 -- s the cup takes to reach the own hand
const CUP_HELD = Vector3.new(0.5, -0.62, -1.6) -- camera space
const CUP_TREMBLE_FROM = 2 -- s after the beat the cup starts to shake
const CUP_TREMBLE_FULL = 8
const TURN_FLICKER = 0.9 -- s of WaltTurn's flicker
const TURN_STEP = 0.15 -- s per frame of that flicker
const RATTLES: { { number } } = { { 0, 0.5 }, { 1.3, 0.8 }, { 2.9, 1.2 } } -- { s after the beat, strength }
const BURST_SPEED = 15 -- studs/s the leaf flies in at
const BURST_DRAG = 2.6
const BURST_TIP = 0.7 -- s the leaf takes to fall flat
const DEBRIS = 14
const GRAVITY = 55
const LOOM_SCALE = 1.28
const LOOM_WAIT = 1.6 -- s in the doorway before the first stride
const LOOM_WALK = 3 -- s of the walk (five strides of 0.6 s)
const LOOM_STRIDE = 0.6
const LOOM_GAP = 2 -- studs between him and the own body
const LOOM_LIGHT = 3.2
const HANDS = 9
const GRASP_FROM = 6 -- s after the Crowd beat the hands close
const GRASP_TIME = 2
const HAND_DEPTH = 1.7 -- studs in front of the camera

const INK = Color3.fromHex("#2B2233")
const CREAM = Color3.fromHex("#FFF1D6")
const BEARD = Color3.fromHex("#F4F4F4")
const WRINKLE = Color3.fromRGB(34, 44, 38)
const SKIN_FALLBACK = Color3.fromRGB(150, 196, 112)
const HAND_COLOR = Color3.fromRGB(12, 11, 16)
const COLD = Color3.fromRGB(205, 220, 255)

const Finale = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function smooth(x: number): number
	const c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

local function ownRoot(): BasePart?
	const character = Players.LocalPlayer.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- Skin colour of the own character (the paw of the cup), else a fallback
local function ownSkin(): Color3
	const character = Players.LocalPlayer.Character
	const arm = if character ~= nil then character:FindFirstChild("Right Arm") else nil
	return if arm ~= nil and arm:IsA("BasePart") then arm.Color else SKIN_FALLBACK
end

local function dress(model: Model, pack: CrewRig.Pack, face: string)
	pcall(function()
		CrewRig.Dress(model, pack, face)
	end)
end

-- Walt dressed as the Night pack: the face of the pack (Content.Looks.PackFace)
local function darkFace(): string
	return Content.Looks.PackFace.Night
end

-- Actors ---------------------------------------------------------------------------------------------------------------

local function waltDawn(ctx: Context, kit: Kit): Actor?
	const from = ctx.Point(STREET_FROM)
	const standPoint = ctx.Point(STREET_STAND)
	const own = ctx.Point(OWN_MARK)
	if from == nil or standPoint == nil or own == nil then
		return nil
	end
	const start = CFrame.lookAt(from.Position, from.Position + kit.Flat(standPoint.Position - from.Position))
	-- ends facing the own body
	const stop = CFrame.lookAt(standPoint.Position, standPoint.Position + kit.Flat(own.Position - standPoint.Position))
	const model = kit.Rig("WaltDawn", "turtle", "civil_c", true, start, ctx)
	if model == nil then
		return nil
	end
	dress(model, "Day", "Smile")
	const beard = kit.Part("Beard", Vector3.new(0.9, 0.55, 0.35), BEARD, nil)
	beard.Shape = Enum.PartType.Ball
	const head = kit.Limb(model, "Head")
	if head ~= nil then
		kit.Attach(beard, head, CFrame.new(0, -0.45, -0.5))
	end
	-- a coffee in each hand
	for _, name in { "Left Arm", "Right Arm" } do
		const hand = kit.Limb(model, name)
		if hand ~= nil then
			const cup = kit.Cylinder("Coffee", Vector3.new(0.5, 0.35, 0.35), CREAM, nil)
			kit.Attach(cup, hand, CFrame.new(0, -1.15, -0.3) * CFrame.Angles(0, 0, math.rad(90)))
		end
	end
	ctx.Bind(model, "walt")

	local posed: CFrame? = nil
	return {
		Model = model,
		Update = function(t: number, _last: number)
			const pose = kit.WalkPose(start, stop, WALT_SPEED, t)
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

local function waltTurn(ctx: Context, _kit: Kit): Actor?
	const waltActor = ctx.Find("WaltDawn")
	const model = if waltActor ~= nil then waltActor.Model else nil
	if model == nil then
		return nil
	end
	local worn = ""
	return {
		Model = nil,
		Update = function(t: number, _last: number)
			local night: boolean
			if Motion.Reduced() then
				night = t >= 0.3
			else
				night = t >= TURN_FLICKER or math.floor(t / TURN_STEP) % 2 == 1
			end
			const key = if night then "Night" else "Day"
			if key ~= worn then
				worn = key
				if night then
					dress(model, "Night", darkFace())
				else
					dress(model, "Day", "Smile")
				end
			end
		end,
		Destroy = function() end,
	}
end

local function handCup(ctx: Context, kit: Kit): Actor?
	const waltActor = ctx.Find("WaltDawn")
	const model = if waltActor ~= nil then waltActor.Model else nil
	const hand = if model ~= nil then kit.Limb(model, "Left Arm") else nil
	if model == nil or hand == nil then
		return nil
	end
	const skin = ownSkin()
	const root = Instance.new("Model")
	root.Name = "HandCup"
	const cup = kit.Cylinder("Cup", Vector3.new(0.5, 0.35, 0.35), CREAM, root)
	const lid = kit.Cylinder("Lid", Vector3.new(0.08, 0.38, 0.38), INK, root)
	const palm = kit.Part("Palm", Vector3.new(0.4, 0.3, 0.4), skin, root)
	palm.Shape = Enum.PartType.Ball
	const fingers: { Part } = {}
	for index = 1, 4 do
		const finger = kit.Cylinder(`Finger{index}`, Vector3.new(0.3, 0.11, 0.11), skin, root)
		table.insert(fingers, finger)
	end
	const wrist = kit.Cylinder("Wrist", Vector3.new(1.2, 0.3, 0.3), skin, root)
	root.Parent = ctx.Folder

	return {
		Model = nil,
		Update = function(t: number, _last: number)
			const camera = Workspace.CurrentCamera
			if camera == nil then
				return
			end
			-- from his hand (camera space) to the held pose
			const fromHand = camera.CFrame:PointToObjectSpace(hand.CFrame:PointToWorldSpace(Vector3.new(0, -1.15, -0.3)))
			local position = fromHand:Lerp(CUP_HELD, smooth(t / CUP_FLY))
			if t >= CUP_TREMBLE_FROM and not Motion.Reduced() then
				-- a fine tremble that grows: the cup knows
				const amp = 0.03 * smooth((t - CUP_TREMBLE_FROM) / (CUP_TREMBLE_FULL - CUP_TREMBLE_FROM))
				position += Vector3.new(math.noise(t * 17, 1.3, 0), math.noise(t * 17, 8.1, 0), 0) * amp
			end
			const frame = camera.CFrame * CFrame.new(position)
			cup.CFrame = frame * CFrame.Angles(0, 0, math.rad(90))
			lid.CFrame = cup.CFrame * CFrame.new(0.21, 0, 0)
			-- the own paw under and around the cup
			palm.CFrame = frame * CFrame.new(0.04, -0.24, 0.04)
			for index, finger in fingers do
				const angle = math.rad(-60 + (index - 1) * 40)
				finger.CFrame = frame * CFrame.new(math.sin(angle) * 0.2, 0.02, math.cos(angle) * 0.2) * CFrame.Angles(0, -angle, math.rad(90))
			end
			wrist.CFrame = frame * CFrame.new(0.28, -0.62, 0.5) * CFrame.Angles(math.rad(20), math.rad(-25), math.rad(90))
		end,
		Destroy = function()
			root:Destroy()
		end,
	}
end

-- The leaf and the other parts of the pantry door DOOR-B (nil = not in the map)
local function doorOf(): (Model?, BasePart?)
	for _, instance in CollectionService:GetTagged(DOOR_TAG) do
		if instance:IsA("Model") and instance:GetAttribute("MapId") == DOOR_ID then
			local main: BasePart? = nil
			for _, descendant in instance:GetDescendants() do
				if descendant:IsA("BasePart") and (descendant.Name == "Leaf" or main == nil) then
					main = descendant
				end
			end
			return instance, main
		end
	end
	return nil, nil
end

type Chunk = { Part: Part, Start: Vector3, Velocity: Vector3, Spin: Vector3, Rest: number }

local function doorBlast(ctx: Context, kit: Kit, value: number?): Actor?
	const door, leaf = doorOf()
	const inside = ctx.Point(INSIDE)
	const outside = ctx.Point(OUTSIDE)
	if door == nil or leaf == nil or inside == nil or outside == nil then
		return nil
	end
	const blast = value or 8
	const base = leaf.CFrame
	const size = leaf.Size
	const inward = kit.Flat(inside.Position - outside.Position)
	const axis = Vector3.yAxis:Cross(inward) -- the leaf tips about this one, top first
	const halfHeight = size.Y / 2
	const halfThick = math.min(size.X, size.Z) / 2
	const floorY = base.Position.Y - halfHeight

	-- the copy first (the original is about to be hidden), then hide every part of the door locally
	const proxy = leaf:Clone()
	proxy:ClearAllChildren()
	proxy.Anchored = true
	proxy.CanCollide = false
	proxy.CanQuery = false
	proxy.CanTouch = false
	proxy.LocalTransparencyModifier = 0
	proxy.Name = "DoorBlastLeaf"
	proxy.Parent = ctx.Folder
	const hidden: { [BasePart]: number } = {}
	for _, descendant in door:GetDescendants() do
		if descendant:IsA("BasePart") then
			hidden[descendant] = descendant.LocalTransparencyModifier
			descendant.LocalTransparencyModifier = 1
		end
	end

	const random = Random.new(2210)
	const chunks: { Chunk } = {}
	for index = 1, DEBRIS do
		const edge = random:NextNumber(-2.3, 2.3)
		const high = random:NextNumber(0.4, 7.4)
		const dimension = random:NextNumber(0.15, 0.5)
		const piece = kit.Part(`Debris{index}`, Vector3.new(dimension, dimension * random:NextNumber(0.3, 1), dimension * random:NextNumber(1, 2.4)), leaf.Color, nil)
		if index % 3 == 0 then
			piece.Color = Color3.fromRGB(70, 74, 82)
		end
		piece.Material = leaf.Material
		piece.Parent = ctx.Folder
		const lateral = base.RightVector * random:NextNumber(-4, 4)
		table.insert(chunks, {
			Part = piece,
			Start = base.Position + base.RightVector * edge + Vector3.new(0, high - halfHeight, 0),
			Velocity = inward * random:NextNumber(6, 20) + lateral + Vector3.new(0, random:NextNumber(2, 9), 0),
			Spin = Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-8, 8), random:NextNumber(-8, 8)),
			Rest = floorY + piece.Size.Y / 2,
		})
	end

	return {
		Model = nil,
		Update = function(t: number, _last: number)
			if t < blast then
				-- the handle shakes the door in its frame
				local shake = 0
				for _, row in RATTLES do
					const dt = t - row[1]
					if dt >= 0 and dt < 0.6 then
						shake += row[2] * math.exp(-dt * 7) * math.sin(dt * 70)
					end
				end
				proxy.CFrame = base * CFrame.new(shake * 0.05, 0, 0) * CFrame.Angles(0, shake * 0.012, 0)
				for _, chunk in chunks do
					chunk.Part.Transparency = 1
				end
				return
			end
			const tt = t - blast
			const distance = BURST_SPEED / BURST_DRAG * (1 - math.exp(-BURST_DRAG * tt))
			const tip = math.rad(90) * smooth(tt / BURST_TIP)
			const hop = 1.2 * math.sin(math.pi * math.clamp(tt / 0.35, 0, 1)) * (1 - tip / math.rad(90))
			const y = floorY + halfHeight * math.cos(tip) + halfThick * math.sin(tip) + hop
			const position = Vector3.new(base.Position.X, y, base.Position.Z) + inward * distance
			proxy.CFrame = CFrame.fromAxisAngle(axis, tip) * (base - base.Position) + position
			for _, chunk in chunks do
				const p = chunk.Start + chunk.Velocity * tt + Vector3.new(0, -0.5 * GRAVITY * tt * tt, 0)
				const landed = p.Y <= chunk.Rest
				const rest = Vector3.new(p.X, chunk.Rest, p.Z)
				const spin = math.min(tt, 0.9) -- they tumble for a moment and lie still
				chunk.Part.Transparency = 0
				chunk.Part.CFrame = CFrame.new(if landed then rest else p)
					* CFrame.Angles(chunk.Spin.X * spin, chunk.Spin.Y * spin, chunk.Spin.Z * spin)
			end
		end,
		Destroy = function()
			proxy:Destroy()
			for _, chunk in chunks do
				chunk.Part:Destroy()
			end
			for part, before in hidden do
				if part.Parent ~= nil then
					part.LocalTransparencyModifier = before
				end
			end
		end,
	}
end

-- Dark thin lines on the front of Walt's head: forehead, around the eyes, from the nose to the mouth
local function wrinkles(kit: Kit, head: BasePart)
	const size = head.Size
	-- { x, y, width, roll } as fractions of the head width / height
	const lines = {
		{ 0, 0.3, 0.55, 0 },
		{ 0, 0.38, 0.4, 0 },
		{ 0, 0.22, 0.35, 0 },
		{ -0.32, 0.08, 0.2, 25 },
		{ 0.32, 0.08, 0.2, -25 },
		{ -0.24, -0.16, 0.3, -62 },
		{ 0.24, -0.16, 0.3, 62 },
		{ -0.12, -0.3, 0.22, -20 },
		{ 0.12, -0.3, 0.22, 20 },
	}
	for index, line in lines do
		const y = line[2] * size.Y
		-- the front of a round head curves away from the middle: pull the line onto it
		const curve = math.sqrt(math.max(0.2, 1 - (2 * y / size.Y) ^ 2 - (2 * line[1]) ^ 2 * 0.5))
		const stroke = kit.Part(`Wrinkle{index}`, Vector3.new(line[3] * size.X, 0.05, 0.04), WRINKLE, nil)
		kit.Attach(stroke, head, CFrame.new(line[1] * size.X, y, -size.Z / 2 * curve - 0.02) * CFrame.Angles(0, 0, math.rad(line[4])))
	end
end

local function waltLoom(ctx: Context, kit: Kit): Actor?
	const doorway = ctx.Point(DOORWAY)
	const inside = ctx.Point(INSIDE)
	if doorway == nil or inside == nil then
		return nil
	end
	const toward = kit.Flat(inside.Position - doorway.Position)
	const start = CFrame.lookAt(doorway.Position, doorway.Position + toward)
	const model = kit.Rig("WaltLoom", "turtle", "civil_c", true, start, ctx)
	if model == nil then
		return nil
	end
	dress(model, "Night", darkFace())
	const head = kit.Limb(model, "Head")
	if head ~= nil then
		const beard = kit.Part("Beard", Vector3.new(0.9, 0.55, 0.35), BEARD, nil)
		beard.Shape = Enum.PartType.Ball
		kit.Attach(beard, head, CFrame.new(0, -0.45, -0.5))
		wrinkles(kit, head)
	end
	-- a cold light on his face from the side the player stands
	local light: PointLight? = nil
	if head ~= nil then
		const made = Instance.new("PointLight")
		made.Name = "LoomLight"
		made.Color = COLD
		made.Range = 16
		made.Brightness = LOOM_LIGHT
		made.Shadows = false
		made.Parent = head
		light = made
	end
	model:ScaleTo(LOOM_SCALE)

	local posed: CFrame? = nil
	return {
		Model = model,
		Update = function(t: number, _last: number)
			-- where he stops: LOOM_GAP studs short of the own body, on the line from the doorway
			const root = ownRoot()
			local goal = doorway.Position + toward * 6
			if root ~= nil then
				const line = kit.Flat(root.Position - doorway.Position)
				const away = (Vector3.new(root.Position.X, doorway.Position.Y, root.Position.Z) - doorway.Position).Magnitude
				goal = doorway.Position + line * math.max(away - LOOM_GAP, 0)
			end
			const walked = math.clamp((t - LOOM_WAIT) / LOOM_WALK, 0, 1)
			const position = doorway.Position:Lerp(goal, walked)
			const facing = kit.Flat(goal - doorway.Position)
			const bob = if walked > 0 and walked < 1 then 0.12 * math.abs(math.sin(math.pi * (t - LOOM_WAIT) / LOOM_STRIDE)) else 0
			const pose = CFrame.lookAt(position, position + facing) + Vector3.new(0, SPAWN_LIFT.Y * LOOM_SCALE + bob, 0)
			if posed == nil or posed ~= pose then
				posed = pose
				model:PivotTo(pose)
			end
			if light ~= nil then
				-- flickers like a failing tube; a slow pulse with reduced motion
				const pulse = if Motion.Reduced()
					then 0.8 + 0.2 * math.sin(t * 2)
					else 0.55 + 0.45 * math.clamp(math.noise(t * 9, 4.4, 0) * 2 + 0.6, 0, 1)
				light.Brightness = LOOM_LIGHT * pulse
			end
		end,
		Destroy = function()
			model:Destroy()
		end,
	}
end

local function waltGrip(ctx: Context, kit: Kit): Actor?
	const loom = ctx.Find("WaltLoom")
	const arm = if loom ~= nil and loom.Model ~= nil then kit.Limb(loom.Model, "Right Arm") else nil
	const skin = if arm ~= nil then arm.Color else SKIN_FALLBACK
	const root = Instance.new("Model")
	root.Name = "WaltGrip"
	const fists: { { Fist: Part, Cuff: Part, Side: number } } = {}
	for _, side in { -1, 1 } do
		const fist = kit.Part("Fist", Vector3.new(0.55, 0.5, 0.55), skin, root)
		fist.Shape = Enum.PartType.Ball
		const cuff = kit.Cylinder("Cuff", Vector3.new(1.4, 0.4, 0.4), INK, root)
		table.insert(fists, { Fist = fist, Cuff = cuff, Side = side })
	end
	root.Parent = ctx.Folder
	return {
		Model = nil,
		Update = function(t: number, _last: number)
			const camera = Workspace.CurrentCamera
			if camera == nil then
				return
			end
			-- they rise into the corners as he lifts, and hold on, trembling
			const rise = smooth(t / 0.25)
			for _, row in fists do
				const jitter = if Motion.Reduced() then Vector3.zero else Vector3.new(math.noise(t * 11, row.Side, 0), math.noise(t * 11, 7.7 + row.Side, 0), 0) * 0.025
				const place = Vector3.new(row.Side * 0.78, lerp(-0.9, 0.5, rise), -1.25) + jitter
				row.Fist.CFrame = camera.CFrame * CFrame.new(place)
				row.Cuff.CFrame = camera.CFrame * CFrame.new(place + Vector3.new(row.Side * 0.1, 0.75, -0.1)) * CFrame.Angles(0, 0, math.rad(90 - row.Side * 12))
			end
		end,
		Destroy = function()
			root:Destroy()
		end,
	}
end

type Hand = {
	Angle: number, -- direction of the edge it comes from
	Delay: number,
	Rest: number, -- radius (fraction of the view's half-height) it waits at before the grasp
	Arm: Part,
	Palm: Part,
	Fingers: { Part },
}

local function crowd(ctx: Context, kit: Kit): Actor?
	const root = Instance.new("Model")
	root.Name = "Crowd"
	const random = Random.new(77)
	const hands: { Hand } = {}
	for index = 1, HANDS do
		const arm = kit.Part("Arm", Vector3.new(0.3, 0.3, 2.4), HAND_COLOR, root)
		const palm = kit.Part("Palm", Vector3.new(0.48, 0.2, 0.5), HAND_COLOR, root)
		palm.Shape = Enum.PartType.Ball
		const fingers: { Part } = {}
		for finger = 1, 4 do
			table.insert(fingers, kit.Part(`Finger{finger}`, Vector3.new(0.09, 0.09, 0.38), HAND_COLOR, root))
		end
		table.insert(hands, {
			Angle = (index - 1) / HANDS * math.pi * 2 + random:NextNumber(-0.2, 0.2),
			Delay = 0.2 + (index - 1) * 0.28,
			Rest = random:NextNumber(0.72, 1),
			Arm = arm,
			Palm = palm,
			Fingers = fingers,
		})
	end
	root.Parent = ctx.Folder
	ctx.Loop("whispers_bed", ctx.Folder, true)

	return {
		Model = nil,
		Update = function(t: number, _last: number)
			const camera = Workspace.CurrentCamera
			if camera == nil then
				return
			end
			const half = HAND_DEPTH * math.tan(math.rad(camera.FieldOfView) / 2)
			const aspect = camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1)
			const grasp = smooth((t - GRASP_FROM) / GRASP_TIME)
			for _, hand in hands do
				const reach = smooth((t - hand.Delay) / 5.5)
				const radius = lerp(1.5, hand.Rest, reach) * (1 - grasp) + 0.15 * grasp
				-- a little creep: they never stop quite still
				const creep = if Motion.Reduced() then 0 else math.sin(t * 1.7 + hand.Angle * 3) * 0.02
				const x = math.cos(hand.Angle) * (radius + creep) * half * aspect
				const y = math.sin(hand.Angle) * (radius + creep) * half
				const spot = Vector3.new(x, y, -HAND_DEPTH)
				const heading = Vector3.new(-x, -y, 0)
				const frame = camera.CFrame * CFrame.lookAt(spot, spot + (if heading.Magnitude > 1e-3 then heading.Unit else Vector3.new(0, 1, 0)))
				hand.Arm.CFrame = frame * CFrame.new(0, 0, 1.3)
				hand.Palm.CFrame = frame
				for index, finger in hand.Fingers do
					-- open and splayed, closing into a fist at the grasp
					const splay = (index - 2.5) * 0.14
					finger.CFrame = frame
						* CFrame.Angles(0, splay * (1 - grasp * 0.8), 0)
						* CFrame.new((index - 2.5) * 0.11, 0, -0.33)
						* CFrame.Angles(grasp * 1.1, 0, 0)
				end
			end
		end,
		Destroy = function()
			ctx.Loop("whispers_bed", ctx.Folder, false)
			root:Destroy()
		end,
	}
end

-- Builds the actor of an `Actor` beat of The Second Coffee; nil = not one of ours, or the map point / rig is missing
function Finale.Create(target: string, ctx: Context, kit: Kit, value: number?): Actor?
	if target == "WaltDawn" then
		return waltDawn(ctx, kit)
	elseif target == "HandCup" then
		return handCup(ctx, kit)
	elseif target == "WaltTurn" then
		return waltTurn(ctx, kit)
	elseif target == "DoorBlast" then
		return doorBlast(ctx, kit, value)
	elseif target == "WaltLoom" then
		return waltLoom(ctx, kit)
	elseif target == "WaltGrip" then
		return waltGrip(ctx, kit)
	elseif target == "Crowd" then
		return crowd(ctx, kit)
	end
	return nil
end

return table.freeze(Finale)
