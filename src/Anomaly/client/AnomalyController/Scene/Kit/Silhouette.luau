--!strict
--[[
	Silhouette step (TASK-589; design/horror-cinematic.md §3.13, §11.3): a big dark shape that crosses outside the
	windows (the Hush passing by, the roof walker against the sky for whoever is outside). Local only, undone when the
	run ends. Made of Parts until the art-director's sheet (PROVISIONAL).
	Red neon eyes (owner 2026-10-19): the shapes of the scenes in EYES (the Hush) carry two glowing red eyes on the head.
	TASK-593 (ANM-021 "many ghosts"): several per run, one per name in the step's Text (nil = the run's single shape,
	as anm_010 / 019 / 020 use it). A Leave with Text "*" sends every shape of the run away.
	  Target "Pass"    (default) from Point to To over Duration, then gone
	  Target "Arrive"  from Point to To over Duration, then it stays there and slowly turns to the local player
	  Target "Leave"   the one standing goes from where it is to To over Duration, fading out
	  Text             name of the shape (TASK-593); the same name moves the same shape, "*" on a Leave = all of them
	  Point / To       MapPoint ids, or "ID@dx,dy,dz" (world offset in studs from that point)
	  Value            scale (default 1 = SHAPE_HEIGHT studs tall); Sound = Content.Sounds key played on its feet at each
	                   stride; Seen = which eyes see it (Scene/Seen: "Cameras" = only on the security feed)
	Held (Scene/init): a late joiner gets it where it should be on its way.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Parent.Effect)
local Steps = require(script.Parent.Parent.Steps)
local Seen = require(script.Parent.Parent.Seen)

type Step = Content.HorrorStep
type State = Steps.State
type Handler = Steps.Handler

const SHAPE_NAME = "SceneSilhouette"
const SHAPE_HEIGHT = 13 -- studs at Value 1: taller than the shop windows
const SHAPE_COLOR = Color3.fromHex("#07060B")
const SHAPE_TRANSPARENCY = 0.06
const STRIDE = 1.1 -- s between two steps of its Sound
const TURN_TIME = 0.8 -- s to face the player once it arrived
const FADE_TIME = 0.6 -- s to vanish at the end of a Pass / Leave
const BOB = 0.12 -- studs of up-and-down per stride
const SINGLE = "" -- the name of the shape a step without Text moves
const EVERY = "*" -- Leave Text: every shape of the run
-- scenes whose shape has red neon eyes (owner 2026-10-19: the Hush)
const EYES: { [string]: boolean } = { anm_010_hush = true }
const EYE_COLOR = Color3.fromHex("#FF1A1A")

type Shape = {
	Model: Model,
	Parts: { BasePart },
	Visible: boolean,
	Fade: number, -- 0..1 extra transparency (the vanish)
	Stop: () -> (), -- the Seen binding
	Move: RBXScriptConnection?,
	Token: number,
}

-- run -> shape name (step Text) -> shape
const shapes: { [State]: { [string]: Shape } } = {}

local function part(name: string, kind: Enum.PartType, size: Vector3, at: CFrame, parent: Instance): Part
	const p = Instance.new("Part")
	p.Name = name
	p.Shape = kind
	p.Size = size
	p.CFrame = at
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = SHAPE_COLOR
	p.Transparency = 1
	p.Parent = parent
	return p
end

-- Tall, thin, long arms, small head: pivot at the feet, facing -Z; `eyes` = two red neon eyes on the head's front
local function build(scale: number, eyes: boolean): (Model, { BasePart })
	const model = Instance.new("Model")
	model.Name = SHAPE_NAME
	const h = SHAPE_HEIGHT * scale
	const parts: { BasePart } = {}
	table.insert(
		parts,
		part("Body", Enum.PartType.Block, Vector3.new(0.22 * h, 0.5 * h, 0.08 * h), CFrame.new(0, 0.62 * h, 0), model)
	)
	table.insert(parts, part("Head", Enum.PartType.Ball, Vector3.one * 0.16 * h, CFrame.new(0, 0.94 * h, 0), model))
	if eyes then
		for side = -1, 1, 2 do
			const eye = part("Eye", Enum.PartType.Ball, Vector3.new(0.035, 0.03, 0.02) * h, CFrame.new(side * 0.032 * h, 0.95 * h, -0.072 * h), model)
			eye.Material = Enum.Material.Neon
			eye.Color = EYE_COLOR
			table.insert(parts, eye)
		end
	end
	for side = -1, 1, 2 do
		table.insert(
			parts,
			part("Leg", Enum.PartType.Block, Vector3.new(0.06 * h, 0.4 * h, 0.06 * h), CFrame.new(side * 0.06 * h, 0.2 * h, 0), model)
		)
		-- the arms hang past the knees
		table.insert(
			parts,
			part(
				"Arm",
				Enum.PartType.Block,
				Vector3.new(0.04 * h, 0.55 * h, 0.04 * h),
				CFrame.new(side * 0.14 * h, 0.55 * h, 0) * CFrame.Angles(0, 0, side * math.rad(4)),
				model
			)
		)
	end
	-- no PrimaryPart: the pivot is the feet (WorldPivot at the origin the parts were built around)
	model.WorldPivot = CFrame.new()
	return model, parts
end

local function paint(shape: Shape)
	const transparency = if shape.Visible then SHAPE_TRANSPARENCY + (1 - SHAPE_TRANSPARENCY) * shape.Fade else 1
	for _, p in shape.Parts do
		p.Transparency = transparency
	end
end

local function drop(state: State, name: string)
	const named = shapes[state]
	const shape = if named ~= nil then named[name] else nil
	if named == nil or shape == nil then
		return
	end
	named[name] = nil
	if next(named) == nil then
		shapes[state] = nil
	end
	shape.Token += 1
	if shape.Move ~= nil then
		shape.Move:Disconnect()
	end
	shape.Stop()
	shape.Model:Destroy()
end

local function dropAll(state: State)
	const named = shapes[state]
	if named == nil then
		return
	end
	for name in table.clone(named) do
		drop(state, name)
	end
end

local function spawn(ctx: Effect.Context, state: State, step: Step, name: string, at: CFrame): Shape
	const model, parts = build(step.Value or 1, EYES[state.Key] == true)
	model:PivotTo(at)
	model.Parent = ctx.Folder()
	const shape: Shape = {
		Model = model,
		Parts = parts,
		Visible = false,
		Fade = 0,
		Stop = function() end,
		Move = nil,
		Token = 0,
	}
	shape.Stop = Seen.Bind(step.Seen, function(visible)
		shape.Visible = visible
		paint(shape)
	end)
	local named = shapes[state]
	if named == nil then
		named = {}
		shapes[state] = named
	end
	(named :: { [string]: Shape })[name] = shape
	state.Undo["silhouette"] = function()
		dropAll(state)
	end
	return shape
end

local function facing(from: Vector3, to: Vector3): CFrame
	const flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 0.01 then
		return CFrame.new(from)
	end
	return CFrame.lookAt(from, from + flat)
end

local function playerFlat(y: number): Vector3?
	const character = Players.LocalPlayer.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return Vector3.new(root.Position.X, y, root.Position.Z)
end

local function travel(
	ctx: Effect.Context,
	state: State,
	name: string,
	shape: Shape,
	step: Step,
	from: Vector3,
	to: Vector3,
	late: number
)
	const target = step.Target or "Pass"
	const duration = math.max(step.Duration or 4, 0.05)
	if shape.Move ~= nil then
		shape.Move:Disconnect()
	end
	shape.Token += 1
	const token = shape.Token
	local elapsed = math.min(late, duration)
	local nextStride = 0
	shape.Move = RunService.Heartbeat:Connect(function(dt)
		if shape.Token ~= token then
			return
		end
		elapsed += dt
		const k = math.clamp(elapsed / duration, 0, 1)
		const flat = from:Lerp(to, k)
		const bob = math.abs(math.sin(elapsed * math.pi / STRIDE)) * BOB
		shape.Model:PivotTo(facing(flat, to) + Vector3.new(0, bob, 0))
		if step.Sound ~= nil and k < 1 and elapsed >= nextStride then
			nextStride = elapsed + STRIDE
			ctx.Play(step.Sound, flat)
		end
		if target ~= "Arrive" then
			-- Pass / Leave: it melts into the night over the last FADE_TIME
			shape.Fade = math.clamp(1 - (duration - elapsed) / FADE_TIME, 0, 1)
			paint(shape)
		end
		if k >= 1 then
			if shape.Move ~= nil then
				shape.Move:Disconnect()
				shape.Move = nil
			end
			if target == "Arrive" then
				-- stands and slowly turns to whoever looks
				const towards = playerFlat(to.Y)
				if towards ~= nil then
					const start = shape.Model:GetPivot()
					const goal = facing(to, towards)
					local t = 0
					shape.Move = RunService.Heartbeat:Connect(function(step2)
						if shape.Token ~= token then
							return
						end
						t += step2
						shape.Model:PivotTo(start:Lerp(goal, math.clamp(t / TURN_TIME, 0, 1)))
						if t >= TURN_TIME and shape.Move ~= nil then
							shape.Move:Disconnect()
							shape.Move = nil
						end
					end)
				end
			else
				drop(state, name)
			end
		end
	end)
end

-- A MapPoint id, or "ID@dx,dy,dz" = that point moved by a world offset in studs (the shop has few scene points: the
-- street front and the roof are read off TRL, e.g. "TRL@0,17,0" = over the middle of the roof)
local function pointAt(ctx: Effect.Context, id: string?): CFrame?
	if id == nil then
		return nil
	end
	const base, offset = string.match(id, "^([^@]+)@(.+)$")
	if base == nil or offset == nil then
		return ctx.Point(id)
	end
	const at = ctx.Point(base)
	const x, y, z = string.match(offset, "^(-?[%d%.]+),(-?[%d%.]+),(-?[%d%.]+)$")
	if at == nil or x == nil or y == nil or z == nil then
		return at
	end
	return at + Vector3.new(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
end

const silhouette: Handler = function(ctx, state, step, late)
	const target = step.Target or "Pass"
	const goalId = if type(step.To) == "string" then step.To else nil
	const goal = pointAt(ctx, goalId)
	const name = step.Text or SINGLE
	if target == "Leave" and name == EVERY then
		-- TASK-593: all of them go, each from where it stands
		const named = shapes[state]
		if named == nil then
			return -- nobody standing there
		end
		for each, shape in table.clone(named) do
			if goal == nil then
				drop(state, each)
			else
				travel(ctx, state, each, shape, step, shape.Model:GetPivot().Position, goal.Position, late)
			end
		end
		return
	end
	if goal == nil then
		if target == "Leave" then
			drop(state, name)
		end
		return
	end
	const named = shapes[state]
	local shape = if named ~= nil then named[name] else nil
	local from: Vector3
	if target == "Leave" then
		if shape == nil then
			return -- nobody standing there
		end
		from = shape.Model:GetPivot().Position
	else
		const start = pointAt(ctx, step.Point)
		if start == nil then
			return
		end
		from = start.Position
		if shape == nil then
			shape = spawn(ctx, state, step, name, facing(from, goal.Position))
		end
	end
	travel(ctx, state, name, shape :: Shape, step, from, goal.Position, late)
end

return table.freeze({
	Register = function(handle: (kind: Content.HorrorStepKind, handler: Handler) -> (), _camera: any)
		handle("Silhouette", silhouette)
	end,
})
