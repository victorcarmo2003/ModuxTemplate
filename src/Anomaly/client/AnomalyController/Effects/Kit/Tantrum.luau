--!strict
--[[
	ANM-011 the shaker's tantrum (condition Plain "JUST BREAD", owner 2026-10-22, Provisional; design/anomalies-after-
	accept-proposal.md §9.9; every number in Content.PlateThrow). Presentation only (T10): the server already threw the
	hot dog away, took the sanity and decides when he leaves (Anomaly Kit/CustomerActor); this draws it on every client.
	Lives in a Folder (Effects/Kit/), so AnomalyController:LoadEffects never takes it for an effect module.

	Throw (cue plate_throw, Entity = actor NpcId; OddCustomer forwards it): a local copy of THE hot dog served (rig
	AnomalyThrow = its toppings, HotDogVisual) on the kit dish shows in his raised right hand (WindUp: the arm snaps up, then
	forward), flies an arc (Flight, Arc) to the wall in front of him and hits it (plate_smash). The wall is a raycast along
	his flat facing from the hand (then a fan of Fan degrees), the first big standing face that is no character and not
	see-through: from the pickup counter, the inner wall of the trailer behind it. Stuck there Stick s, it slides down
	slowly (Slide, easing in), falls flat on the floor (Fall, plate_drop) and fades out (Fade). No wall within Reach = it
	lands on the floor Fallback studs ahead (smash, fade).
	Reaction, Rage.Delay after the cue (just after the hit): the TUM (anger_thud at his head, a short camera kick for who
	stands within Kick.Radius) and his line Content.PlateThrow.Text typed in a balloon over his head (TypedText in the
	order talk's Rage.Style), TextHold s after it is typed.
	Body (Mount, bound to the rig while it has the variant "shake", OddCustomer): enraged while the rig carries
	AnomalyRage (server time of his first throw) and Rage.Delay has passed: the thumbnails' monster face (RigController's
	local TicFace = Rage.Face, the rage face (CrewExpressions.Rage, owner 2026-10-22), plus the grin of teeth and tongue of tools/thumbnails T.addGrin welded to the
	head) and the bugged body: every TicEvery s the neck, both shoulders and the torso (RootJoint) jump straight to a new
	crooked pose (no tween), stay Hold s and jump back, while the torso trembles every frame (OddCustomer's own tremor
	steps aside meanwhile: Raging). Walking enraged = a stomp (Sounds.Stomp) every StompEvery s. It all goes when the rig
	loses AnomalyRage (served plain) or the variant (the pool), and on unmount.
	Reduced motion (Settings / Roblox, Interface Motion.Reduced): every angle and the tremor x Rage.Reduced, ticks twice
	as far apart, no camera kick; the plate, the face and the line stay (they are the information).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local HotDogVisual = require(ReplicatedStorage.shared.Item.HotDogVisual)
local PlateTool = require(ReplicatedStorage.shared.Plate.PlateTool)
local Effect = require(script.Parent.Parent.Parent.Effect)
local CartoonPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonPanel)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local TypedText = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TypedText)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIScale are not among them (as SpeechBalloon)
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const RULES = Content.PlateThrow
const RAGE_ATTRIBUTE = "AnomalyRage" -- Anomaly Kit/CustomerActor: server time of his first throw
const THROW_ATTRIBUTE = "AnomalyThrow" -- toppings of the plate being thrown ("mustard,onion"; "" = plain)
const FACE_ATTRIBUTE = "TicFace" -- RigController: local face of the variant (never replicated)
const GRIN_NAME = "Tantrum_Grin"
const PLATE_NAME = "Tantrum_Plate"
const HOT_DOG = "hot_dog"
const TOPPING_ANCHOR = "Att_Topping1" -- HotDogVisual: the up axis of the stack
const ARM = "Right Arm"
const RIGHT_SHOULDER = "Right Shoulder"
const HAND = CFrame.new(0, -1.1, 0) -- arm space: the palm
-- the throw on the right shoulder (R6 C0, about its Z: + = the arm forward, 180 = straight up; as SeatingController/Meal)
const WIND_POSE = CFrame.Angles(0, 0, math.rad(200)) -- raised over the head, a little back
const RELEASE_POSE = CFrame.Angles(0, 0, math.rad(70)) -- thrown forward
const RELEASE_HOLD = 0.2 -- s the arm stays thrown forward
const WALL_HITS = 12 -- faces skipped along one ray before it gives up
const WALL_GAP = 0.03 -- studs between the dish and the wall
const FLOOR_PROBE = 30 -- studs down from the wall to the floor
const TREMOR_RATE = 1 -- s between two reads of the reduced motion setting
const DEG = math.pi / 180
-- the grin of the thumbnails (tools/thumbnails/thumb_project_helpers.luau T.addGrin): colours, Neon teeth and tongue
const MOUTH_DARK = Color3.fromHex("#2A0508")
const MOUTH = Color3.fromHex("#C4142E")
const THROAT = Color3.fromHex("#5A0612")
const TONGUE = Color3.fromHex("#FF4FA3")
const TOOTH = Color3.fromHex("#FFFFFF")
-- drawn plate while the kit Tools are missing (Theme cream, bun and sausage of SeatingController/Meal)
const DISH = Color3.fromHex("#FFF8EC")
const BUN = Color3.fromHex("#E8B36B")
const SAUSAGE = Color3.fromHex("#B5482E")
-- the balloon over his head (SpeechBalloon's look, bigger letters: he shouts)
const BALLOON_WIDTH = 240
const BALLOON_HEIGHT = 96
const BALLOON_TEXT = 22
const BALLOON_PAD = 8
const BALLOON_TAIL = 12
const BALLOON_LIFT = Vector3.new(0, 3.2, 0)
const BALLOON_RANGE = 70

export type Undo = () -> ()

type Plate = { Model: Model, Radius: number, Half: number }

type Wall = { Position: Vector3, Normal: Vector3 }

type Joint = { Motor: Motor6D, Base: CFrame, Range: Vector3, Pose: CFrame }

const Tantrum = {}

-- weak keys: a forgotten rig never stays alive here
const raging: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
const throwAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local reducedAt = -math.huge
local reducedNow = false

-- Motion.Reduced, read at most once a TREMOR_RATE (it pcalls the engine setting)
local function reduced(): boolean
	const now = os.clock()
	if now - reducedAt >= TREMOR_RATE then
		reducedAt = now
		reducedNow = Motion.Reduced()
	end
	return reducedNow
end

local function limb(model: Model, name: string): BasePart?
	const found = model:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

local function joint(model: Model, part: string, name: string): Motor6D?
	const host = model:FindFirstChild(part)
	const found = if host then host:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Motor6D") then found else nil
end

local function flat(vector: Vector3): Vector3?
	const level = Vector3.new(vector.X, 0, vector.Z)
	return if level.Magnitude > 1e-3 then level.Unit else nil
end

-- Rotation of `angle` around the torso's up axis, in the frame of a joint whose Part0 is the torso/root (OddCustomer)
local function yaw(c0: CFrame, angle: number): CFrame
	return CFrame.fromAxisAngle(c0:VectorToObjectSpace(Vector3.yAxis), angle)
end

local function crooked(rng: Random, range: Vector3): CFrame
	return CFrame.Angles(
		rng:NextNumber(-range.X, range.X),
		rng:NextNumber(-range.Y, range.Y),
		rng:NextNumber(-range.Z, range.Z)
	)
end

-- He is enraged on this client (OddCustomer's tremor steps aside: the tantrum owns the RootJoint meanwhile)
function Tantrum.Raging(model: Model): boolean
	return raging[model] == true
end

-- The plate -----------------------------------------------------------------------------------------------------------

local function quiet(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
end

local function kitTool(name: string): Tool?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const tools = if items then items:FindFirstChild("Tools") else nil
	const found = if tools then tools:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Tool") then found else nil
end

-- The parts of a kit Tool (no scripts) in a Model, frames kept; primary = its Handle. nil = no kit Tool.
local function partsOf(name: string): Model?
	const tool = kitTool(name)
	if tool == nil then
		return nil
	end
	const copy = tool:Clone()
	const model = Instance.new("Model")
	model.Name = name
	for _, child in copy:GetChildren() do
		child.Parent = model
	end
	copy:Destroy()
	-- no scripts and no joints: every part is anchored and the whole model moves by PivotTo
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			quiet(descendant)
		end
	end
	const handle = model:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = handle
	return model
end

local function drawn(name: string, size: Vector3, color: Color3, frame: CFrame, shape: Enum.PartType?): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape ~= nil then
		part.Shape = shape
	end
	part.CFrame = frame
	quiet(part)
	return part
end

-- Handle frame that lays the hot dog on `top` (Y up): the stack's up axis (Att_Topping1) up (as SeatingController/Meal)
local function lay(handle: BasePart, top: CFrame): CFrame
	const anchor = handle:FindFirstChild(TOPPING_ANCHOR)
	const turn = if anchor ~= nil and anchor:IsA("Attachment") then anchor.CFrame.Rotation else CFrame.identity
	const up = turn.UpVector
	const size = handle.Size
	const half = 0.5 * (math.abs(up.X) * size.X + math.abs(up.Y) * size.Y + math.abs(up.Z) * size.Z)
	return top * CFrame.new(0, half, 0) * turn:Inverse()
end

-- The dish flat at the origin (its centre, Y up) inside `into`; returns its base part and the top of the dish.
local function dish(into: Model): (BasePart, CFrame)
	const kit = partsOf(PlateTool.Plate)
	if kit ~= nil then
		const handle = kit.PrimaryPart :: BasePart
		const origin = handle.CFrame
		for _, part in kit:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = origin:ToObjectSpace(part.CFrame)
			end
		end
		for _, child in kit:GetChildren() do
			child.Parent = into
		end
		kit:Destroy()
		return handle, CFrame.new(0, handle.Size.Y / 2, 0)
	end
	-- a cylinder runs along X: stood on its side to lie flat, its pivot turned back so the plate's Y is up
	const base = drawn("Handle", Vector3.new(0.08, 1.4, 1.4), DISH, CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
	base.PivotOffset = CFrame.Angles(0, 0, -math.pi / 2)
	base.Parent = into
	return base, CFrame.new(0, 0.04, 0)
end

-- THE hot dog (kit Tool + its toppings), or a drawn bun and sausage; anchored, not parented.
local function food(toppings: string): (Model, BasePart)
	const kit = partsOf(HOT_DOG)
	if kit ~= nil then
		const handle = kit.PrimaryPart :: BasePart
		if toppings ~= "" and handle:FindFirstChild(TOPPING_ANCHOR) ~= nil then
			const ok, problem = pcall(HotDogVisual.apply, kit, toppings, nil)
			if not ok then
				warn(`[Tantrum] HotDogVisual.apply failed: {problem}`)
			end
			for _, descendant in kit:GetDescendants() do
				if descendant:IsA("BasePart") then
					quiet(descendant)
				end
			end
		end
		return kit, handle
	end
	const model = Instance.new("Model")
	model.Name = HOT_DOG
	const bun = drawn("Handle", Vector3.new(0.4, 0.3, 1), BUN, CFrame.identity)
	bun.Parent = model
	const sausageAt = CFrame.new(0, 0.12, 0) * CFrame.Angles(0, math.pi / 2, 0)
	const sausage = drawn("Sausage", Vector3.new(1.15, 0.22, 0.22), SAUSAGE, sausageAt, Enum.PartType.Cylinder)
	sausage.Parent = model
	model.PrimaryPart = bun
	return model, bun
end

-- The plate he throws: the dish (pivot = its centre, Y = the face the food is on) with THE hot dog laid on it.
local function buildPlate(toppings: string): Plate
	const model = Instance.new("Model")
	model.Name = PLATE_NAME
	const base, top = dish(model)
	model.PrimaryPart = base
	const size = model:GetExtentsSize()
	const radius = math.max(size.X, size.Z) / 2
	const half = math.max(size.Y / 2, 0.04)
	const hotDog, handle = food(toppings)
	const at = lay(handle, top)
	hotDog:PivotTo(at * handle.CFrame:ToObjectSpace(hotDog:GetPivot()))
	hotDog.Parent = model
	return { Model = model, Radius = math.max(radius, 0.5), Half = half }
end

-- Every face of the plate fades with `alpha` (0 = as built, 1 = gone).
local function fader(model: Model): (alpha: number) -> ()
	type Faded = { Item: BasePart | Decal, From: number }
	const items: { Faded } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			table.insert(items, { Item = descendant, From = descendant.Transparency })
		end
	end
	return function(alpha: number)
		for _, entry in items do
			entry.Item.Transparency = entry.From + (1 - entry.From) * alpha
		end
	end
end

-- The wall -------------------------------------------------------------------------------------------------------------

local function isWall(part: BasePart, normal: Vector3): boolean
	if part.Transparency >= 0.9 or math.abs(normal.Y) > 0.5 then
		return false
	end
	const owner = part:FindFirstAncestorOfClass("Model")
	if owner ~= nil and owner:FindFirstChildOfClass("Humanoid") ~= nil then
		return false
	end
	const size = part.Size
	const sides = { size.X, size.Y, size.Z }
	table.sort(sides)
	return sides[2] >= RULES.Throw.Wall
end

-- The first wall along `direction` from `from`, skipping props, glass and bodies (WALL_HITS faces at most).
local function wallAlong(params: RaycastParams, from: Vector3, direction: Vector3): Wall?
	const cast = RaycastParams.new()
	cast.FilterType = params.FilterType
	cast.FilterDescendantsInstances = params.FilterDescendantsInstances
	for _ = 1, WALL_HITS do
		const hit = Workspace:Raycast(from, direction * RULES.Throw.Reach, cast)
		if hit == nil then
			return nil
		end
		const part = hit.Instance
		if part:IsA("BasePart") and isWall(part, hit.Normal) then
			const normal = flat(hit.Normal) or -direction
			return { Position = hit.Position, Normal = normal }
		end
		cast:AddToFilter(part)
	end
	return nil
end

-- The wall he throws at: straight ahead, else the nearest one in the fan (Throw.Fan degrees each side)
local function findWall(ctx: Effect.Context, model: Model, from: Vector3, facing: Vector3): Wall?
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const skip: { Instance } = { model, ctx.Folder() }
	for _, player in Players:GetPlayers() do
		const character = player.Character
		if character ~= nil then
			table.insert(skip, character)
		end
	end
	params.FilterDescendantsInstances = skip
	const straight = wallAlong(params, from, facing)
	if straight ~= nil then
		return straight
	end
	local best: Wall? = nil
	local bestDistance = math.huge
	const fan = RULES.Throw.Fan * DEG
	for _, angle in { fan / 2, -fan / 2, fan, -fan } do
		const direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(facing)
		const found = wallAlong(params, from, direction)
		if found ~= nil then
			const distance = (found.Position - from).Magnitude
			if distance < bestDistance then
				best = found
				bestDistance = distance
			end
		end
	end
	return best
end

local function floorUnder(ctx: Effect.Context, at: Vector3, plate: Model): number
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const skip: { Instance } = { plate, ctx.Folder() }
	for _, player in Players:GetPlayers() do
		const character = player.Character
		if character ~= nil then
			table.insert(skip, character)
		end
	end
	params.FilterDescendantsInstances = skip
	-- the first solid top under it (a counter against the wall counts); invisible zones and prompt parts are skipped
	for _ = 1, WALL_HITS do
		const hit = Workspace:Raycast(at, Vector3.new(0, -FLOOR_PROBE, 0), params)
		if hit == nil then
			break
		end
		const part = hit.Instance
		if part:IsA("BasePart") and part.CanCollide and part.Transparency < 0.9 then
			return hit.Position.Y
		end
		params:AddToFilter(part)
	end
	return at.Y - 3
end

-- A plate frame whose face (Y) looks along `normal`, its X along the wall
local function facingFrame(at: Vector3, normal: Vector3): CFrame
	const across = Vector3.yAxis:Cross(normal)
	const x = if across.Magnitude > 1e-3 then across.Unit else Vector3.xAxis
	return CFrame.fromMatrix(at, x, normal)
end

-- Runs `step(t)` every frame for `duration` s (t 0..1); false = the plate is gone (night over: the folder was emptied)
local function play(plate: Model, duration: number, step: (t: number) -> ()): boolean
	const started = os.clock()
	while true do
		if plate.Parent == nil then
			return false
		end
		const t = if duration > 0 then math.clamp((os.clock() - started) / duration, 0, 1) else 1
		step(t)
		if t >= 1 then
			return true
		end
		RunService.RenderStepped:Wait()
	end
end

-- The reaction ---------------------------------------------------------------------------------------------------------

-- A short camera kick for this client when it stands within Kick.Radius studs of `at` (none with reduced motion)
local function kick(at: Vector3)
	if reduced() then
		return
	end
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	const camera = Workspace.CurrentCamera
	if camera == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	if (root.Position - at).Magnitude > RULES.Kick.Radius then
		return
	end
	const angle = RULES.Kick.Angle * DEG
	const time = math.max(RULES.Kick.Time, 0.05)
	const started = os.clock()
	local last = 0
	const connection = RunService.RenderStepped:Connect(function()
		const t = (os.clock() - started) / time
		const now = if t < 1 then angle * math.sin(t * math.pi) else 0
		camera.CFrame = camera.CFrame * CFrame.Angles(now - last, 0, 0)
		last = now
	end)
	task.delay(time + 0.05, function()
		connection:Disconnect()
	end)
end

-- His line over his head: typed letter by letter in the order talk's style, then gone
local function balloon(head: BasePart)
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	const text = RULES.Text
	const rate = math.max(RULES.Rage.TypeRate, 1)
	const style = Content.OrderTalk.Styles[RULES.Rage.Style]
	const started = os.clock()
	const outline = Theme.Outline.Normal
	const inner = BALLOON_WIDTH - 2 * (BALLOON_PAD + 2)
	const destroy = Vide.root(function(destroy: () -> ()): () -> ()
		const shown = Vide.source(false)
		const scale = Vide.spring(function(): number
			return if shown() then 1 else 0.6
		end, 0.15, 0.45)
		const gui = create("BillboardGui")({
			Name = "Tantrum_Line",
			Adornee = head,
			Size = UDim2.fromOffset(BALLOON_WIDTH + 2 * outline, BALLOON_HEIGHT),
			StudsOffset = BALLOON_LIFT,
			MaxDistance = BALLOON_RANGE,
			LightInfluence = 0,
			AlwaysOnTop = false,
			ResetOnSpawn = false,

			create("Frame")({
				Name = "Balloon",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -BALLOON_TAIL / 2 - outline),
				Size = UDim2.fromOffset(BALLOON_WIDTH, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,

				createRaw("UIScale")({ Scale = scale }),

				create("Frame")({
					Name = "Tail",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 1, -2),
					Size = UDim2.fromOffset(BALLOON_TAIL, BALLOON_TAIL),
					Rotation = 45,
					BackgroundColor3 = Theme.Tone.White.Lip,
					ZIndex = 0,
					createRaw("UIStroke")({
						Color = Theme.Color.Ink,
						Thickness = outline,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				}),

				CartoonPanel({
					Name = "Body",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Tone = Theme.Tone.White,
					Outline = outline,
					Radius = Theme.Radius.Card,
					ZIndex = 1,
					Padding = { Top = BALLOON_PAD, Bottom = BALLOON_PAD, Left = BALLOON_PAD + 2, Right = BALLOON_PAD + 2 },
					Children = {
						TypedText({
							Name = "Line",
							Width = inner,
							TextSize = BALLOON_TEXT,
							Color = Theme.Color.Dark,
							Text = function(): string
								return text
							end,
							Clock = function(): TypedText.Clock
								return { Typed = math.floor((os.clock() - started) * rate), Phase = "Line" }
							end,
							Style = function(): Content.TalkStyle?
								return style
							end,
							Break = function(): number?
								return nil
							end,
							Active = shown,
						}),
					},
				}),
			}),
		})
		gui.Parent = playerGui
		shown(true)
		Vide.cleanup(function()
			gui:Destroy()
		end)
		return destroy
	end)
	task.delay(#text / rate + RULES.Rage.TextHold, destroy)
end

-- The TUM, the kick and his line
local function react(ctx: Effect.Context, model: Model)
	const head = limb(model, "Head")
	if head == nil or not model:IsDescendantOf(Workspace) then
		return
	end
	ctx.Audio:Play(RULES.Sounds.Thud, head)
	kick(head.Position)
	balloon(head)
end

-- Cue plate_throw: the plate from his hand to the wall, down to the floor, gone; the reaction after Rage.Delay.
function Tantrum.Throw(ctx: Effect.Context, npcId: number)
	const model = ctx.Npc(npcId)
	const root = if model ~= nil then limb(model, "HumanoidRootPart") or model.PrimaryPart else nil
	if model == nil or root == nil then
		return
	end
	const throw = RULES.Throw
	throwAt[model] = os.clock()
	task.delay(RULES.Rage.Delay, react, ctx, model)

	const look = model:GetAttribute(THROW_ATTRIBUTE)
	const plate = buildPlate(if type(look) == "string" then look else "")
	const body = plate.Model
	const facing = flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
	const level = CFrame.lookAt(Vector3.zero, facing) -- flat, turned his way
	local function hand(): Vector3
		const arm = limb(model, ARM)
		return if arm ~= nil then (arm.CFrame * HAND).Position else root.Position + facing + Vector3.new(0, 2.5, 0)
	end
	body:PivotTo(CFrame.new(hand()) * level)
	body.Parent = ctx.Folder()

	-- wind-up: the plate in his raised hand (the body modifier snaps the arm)
	if
		not play(body, throw.WindUp, function()
			body:PivotTo(CFrame.new(hand()) * level)
		end)
	then
		return
	end

	const from = body:GetPivot().Position
	const wall = findWall(ctx, model, from, facing)
	local to: Vector3
	local landing: CFrame
	if wall ~= nil then
		to = wall.Position + wall.Normal * (plate.Half + WALL_GAP)
		landing = facingFrame(to, wall.Normal)
	else
		const ahead = from + facing * throw.Fallback
		const floor = floorUnder(ctx, ahead, body)
		to = Vector3.new(ahead.X, floor + plate.Half, ahead.Z)
		landing = CFrame.new(to) * level
	end

	-- the arc (a quadratic curve over the straight line), spinning, turning to face where it lands
	const control = (from + to) / 2 + Vector3.new(0, 2 * throw.Arc, 0)
	const spin = throw.Spin * 2 * math.pi
	const startRotation = level
	const endRotation = landing.Rotation
	local spun = 0
	if
		not play(body, throw.Flight, function(t: number)
			const u = 1 - t
			const at = from * (u * u) + control * (2 * u * t) + to * (t * t)
			spun = spin * t * throw.Flight
			body:PivotTo(CFrame.new(at) * startRotation:Lerp(endRotation, t) * CFrame.Angles(0, spun, 0))
		end)
	then
		return
	end
	const stuck = CFrame.new(to) * endRotation * CFrame.Angles(0, spun, 0)
	body:PivotTo(stuck)
	ctx.Audio:Play(RULES.Sounds.Smash, to)

	if wall ~= nil then
		-- stuck on the wall, then it slides down slowly (easing in) until its edge meets the floor
		if not play(body, throw.Stick, function() end) then
			return
		end
		const floor = floorUnder(ctx, to + wall.Normal * 0.5, body)
		const bottom = math.min(to.Y, floor + plate.Radius)
		const drop = to.Y - bottom
		if
			not play(body, throw.Slide, function(t: number)
				body:PivotTo(stuck - Vector3.new(0, drop * t * t, 0))
			end)
		then
			return
		end
		-- off the wall, flat onto the floor
		const leaning = stuck - Vector3.new(0, drop, 0)
		const resting = Vector3.new(leaning.X, floor + plate.Half, leaning.Z) + wall.Normal * plate.Radius
		const along = flat(leaning.XVector) or flat(leaning.ZVector) or Vector3.xAxis
		const flatFrame = CFrame.fromMatrix(resting, along, Vector3.yAxis)
		if
			not play(body, throw.Fall, function(t: number)
				body:PivotTo(leaning:Lerp(flatFrame, t * t))
			end)
		then
			return
		end
		ctx.Audio:Play(RULES.Sounds.Drop, resting)
	end

	-- gone: a fade, then destroyed
	const fade = fader(body)
	play(body, throw.Fade, fade)
	body:Destroy()
end

-- The face -------------------------------------------------------------------------------------------------------------

local function grinPart(parent: Instance, name: string, frame: CFrame, size: Vector3, color: Color3, neon: boolean, sphere: boolean)
	const part = if sphere then Instance.new("Part") else Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.CFrame = frame
	part.Color = color
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	if sphere then
		const mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = parent
end

local function tooth(parent: Instance, frame: CFrame, x: number, baseY: number, h: number, w: number, down: boolean)
	const up = if down then Vector3.new(0, -1, 0) else Vector3.yAxis
	const y = if down then baseY - h / 2 else baseY + h / 2
	const size = Vector3.new(0.08, h, w / 2)
	const right = if down then Vector3.new(0, 0, -1) else Vector3.zAxis
	grinPart(parent, "Tooth", frame * CFrame.fromMatrix(Vector3.new(x + w / 4, y, -0.06), right, up), size, TOOTH, true, false)
	grinPart(parent, "Tooth", frame * CFrame.fromMatrix(Vector3.new(x - w / 4, y, -0.06), -right, up), size, TOOTH, true, false)
end

-- The thumbnails' grin (T.addGrin): a dark mouth, red inside, throat, a pink tongue and two rows of Neon teeth, scaled to
-- the head and welded to it (it follows every tick of the neck). Local parts in the rig.
local function buildGrin(model: Model): Model?
	const head = limb(model, "Head")
	if head == nil then
		return nil
	end
	const spec = RULES.Grin
	const s = head.Size.X / spec.HeadWidth
	const w, h = spec.W * s, spec.H * s
	const frame = head.CFrame * CFrame.new(0, spec.Y * s, -spec.Z * s) * CFrame.Angles(0, math.pi, 0)
	const grin = Instance.new("Model")
	grin.Name = GRIN_NAME
	grinPart(grin, "MouthDark", frame, Vector3.new(w, h, 0.1), MOUTH_DARK, false, true)
	const iw, ih = w * 0.9, h * 0.82
	grinPart(grin, "Mouth", frame * CFrame.new(0, 0, 0.03), Vector3.new(iw, ih, 0.1), MOUTH, false, true)
	grinPart(grin, "Throat", frame * CFrame.new(0, -ih * 0.05, 0.05), Vector3.new(iw * 0.45, ih * 0.4, 0.1), THROAT, false, true)
	grinPart(grin, "Tongue", frame * CFrame.new(0, -ih * 0.26, 0.07), Vector3.new(iw * 0.35, ih * 0.28, 0.1), TONGUE, true, true)
	const a, b = iw / 2, ih / 2
	const up, low = math.max(spec.Up, 2), math.max(spec.Lo, 2)
	const teeth = frame * CFrame.new(0, 0, 0.09)
	for i = 1, up do
		const x = -a * 0.86 + (i - 1) * (a * 1.72 / (up - 1))
		const edge = b * math.sqrt(math.max(0, 1 - (x / a) ^ 2))
		tooth(grin, teeth, x, edge + 0.02, 0.32 * s * (0.6 + 0.4 * edge / b) * spec.Teeth, a * 1.72 / (up - 1) * 0.85, true)
	end
	for i = 1, low do
		const x = -a * 0.78 + (i - 1) * (a * 1.56 / (low - 1))
		const edge = b * math.sqrt(math.max(0, 1 - (x / a) ^ 2))
		tooth(grin, teeth, x, -edge - 0.02, 0.28 * s * (0.6 + 0.4 * edge / b) * spec.Teeth, a * 1.56 / (low - 1) * 0.85, false)
	end
	for _, part in grin:GetChildren() do
		if part:IsA("BasePart") then
			const weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = part
			weld.Parent = part
		end
	end
	grin.Parent = model
	return grin
end

-- The body -------------------------------------------------------------------------------------------------------------

-- Bound to a "shake" rig (OddCustomer): the throw pose of the arm, and while enraged the face, the ticks, the tremor and
-- the stomps. Returns its undo.
function Tantrum.Mount(ctx: Effect.Context, model: Model): Undo
	const rage = RULES.Rage
	const joints: { Joint } = {}
	local shoulder: Joint? = nil
	local function add(name: string, range: Vector3)
		const motor = joint(model, "Torso", name)
		if motor ~= nil then
			const entry: Joint = { Motor = motor, Base = motor.C0, Range = range * DEG, Pose = CFrame.identity }
			table.insert(joints, entry)
			if name == RIGHT_SHOULDER then
				shoulder = entry
			end
		end
	end
	add("Neck", rage.Neck)
	add(RIGHT_SHOULDER, rage.Shoulder)
	add("Left Shoulder", rage.Shoulder)
	const root = joint(model, "HumanoidRootPart", "RootJoint")
	const rootBase = if root ~= nil then root.C0 else CFrame.identity
	const torsoRange = rage.Torso * DEG
	const hips = limb(model, "HumanoidRootPart")
	const rng = Random.new()
	local on = false
	local posed = false -- the throw pose is on the right shoulder
	local nextTick = 0
	local holdUntil = 0
	local rootPose = CFrame.identity
	local nextStomp = 0
	local grin: Model? = nil

	local function calm()
		for _, entry in joints do
			entry.Pose = CFrame.identity
			entry.Motor.C0 = entry.Base
		end
		rootPose = CFrame.identity
		if root ~= nil then
			root.C0 = rootBase
		end
	end

	local function enter()
		on = true
		raging[model] = true
		model:SetAttribute(FACE_ATTRIBUTE, rage.Face)
		grin = buildGrin(model)
		nextTick = 0
	end

	local function leave()
		on = false
		raging[model] = nil
		if model:GetAttribute(FACE_ATTRIBUTE) == rage.Face then
			model:SetAttribute(FACE_ATTRIBUTE, nil)
		end
		const made = grin
		grin = nil
		if made ~= nil then
			made:Destroy()
		end
		calm()
	end

	const connection = RunService.RenderStepped:Connect(function()
		const now = os.clock()
		const rageAt = model:GetAttribute(RAGE_ATTRIBUTE)
		const want = type(rageAt) == "number" and ctx.Now() >= rageAt + rage.Delay
		if want ~= on then
			if want then
				enter()
			else
				leave()
			end
		end
		-- the throw: the right arm straight up, then thrown forward (no tween)
		local throwPose: CFrame? = nil
		const thrown = throwAt[model]
		if thrown ~= nil then
			const since = now - thrown
			if since < RULES.Throw.WindUp then
				throwPose = WIND_POSE
			elseif since < RULES.Throw.WindUp + RELEASE_HOLD then
				throwPose = RELEASE_POSE
			else
				throwAt[model] = nil
			end
		end
		const arm = shoulder
		if not on then
			if arm ~= nil then
				if throwPose ~= nil then
					posed = true
					arm.Motor.C0 = arm.Base * throwPose
				elseif posed then
					posed = false
					arm.Motor.C0 = arm.Base
				end
			end
			return
		end
		-- enraged: the ticks jump to a crooked pose and back, never eased
		const slow = reduced()
		const amount = if slow then rage.Reduced else 1
		if now >= nextTick then
			for _, entry in joints do
				entry.Pose = crooked(rng, entry.Range * amount)
			end
			rootPose = crooked(rng, torsoRange * amount)
			holdUntil = now + rng:NextNumber(rage.Hold[1], rage.Hold[2])
			nextTick = now + rng:NextNumber(rage.TicEvery[1], rage.TicEvery[2]) * (if slow then 2 else 1)
		elseif now >= holdUntil then
			for _, entry in joints do
				entry.Pose = CFrame.identity
			end
			rootPose = CFrame.identity
		end
		for _, entry in joints do
			entry.Motor.C0 = if entry == arm and throwPose ~= nil then entry.Base * throwPose else entry.Base * entry.Pose
		end
		posed = throwPose ~= nil
		if root ~= nil then
			const move = rage.Tremor * amount
			const turn = rage.TremorTurn * DEG * amount
			const offset = Vector3.new(rng:NextNumber(-move, move), rng:NextNumber(-move, move), rng:NextNumber(-move, move))
			root.C0 = rootBase * CFrame.new(offset) * yaw(rootBase, rng:NextNumber(-turn, turn)) * rootPose
		end
		-- walking enraged: he stomps
		if hips ~= nil and now >= nextStomp then
			const velocity = hips.AssemblyLinearVelocity
			if Vector3.new(velocity.X, 0, velocity.Z).Magnitude >= rage.StompSpeed then
				nextStomp = now + rage.StompEvery
				ctx.Audio:Play(RULES.Sounds.Stomp, hips)
			end
		end
	end)

	return function()
		connection:Disconnect()
		throwAt[model] = nil
		if on then
			leave()
		else
			calm()
		end
	end
end

return table.freeze(Tantrum)
