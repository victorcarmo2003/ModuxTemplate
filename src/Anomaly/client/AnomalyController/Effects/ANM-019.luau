--!strict
--[[
	ANM-019 The roof walker, client effect: "don't look up" (TASK-484; DEC-294, DEC-295 / Q-367 A;
	design/horror-cinematic.md ANM-019). Presents only: who looked up and who pays is the server's (Anomalies/ANM-019,
	Gaze pitch).

	The walk itself (steps over the head, dust, lamps, whispers "DON'T LOOK UP", heartbeat, bars, the soft nudge down)
	is the horror scene anm_019_roof_walker (Content.HorrorScenes, Scene/Kits Roof + HeadDown). Here:
	  * the record turning Signal (it lands on the roof) cuts a security-camera watcher back to the head (Kit/Watch):
	    the cameras are no place to sit the walk out;
	  * the cue `jumpscare` with Entity = this player (UserId % 65536) = this player looked up: the shape drops head
	    first from the roof in front of the window this player faces (the nearest glass part ahead; in the open, a few
	    studs ahead), hangs there with its white eyes, the camera is jolted and pulled a little towards it, then the face
	    (Kit/Jumpscare, ~0.6 s, Mild DEC-172) and it is yanked back up. ~1.4 s in all, presentation only.
	PROVISIONAL (TASK-484): the shape is made of local Parts until the art-director's sheet.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Effect)
local Kits = require(script.Parent.Parent.Scene.Kits)
local Jumpscare = require(script.Parent.Kit.Jumpscare)
local Watch = require(script.Parent.Kit.Watch)

const ENTITY_MOD = 65536 -- AnomalyCue.Entity range (server: UserId % 65536)
const MAP_NAME = "MAP01_Restaurant"
const GLASS_RANGE = 45 -- studs to the window it drops in front of
const GLASS_AHEAD = 0.45 -- cos of the widest angle off the look (flat) a window may be at
const OPEN_AHEAD = 7 -- studs ahead when there is no window
const OUTSIDE = 1.6 -- studs out of the glass, on the far side
const HANG_DROP = 0.22 -- s of the fall
const HANG_HOLD = 0.4 -- s it hangs there before the face
const PULL_UP = 0.35 -- s it is yanked back up
const FALL_FROM = 7 -- studs above the hang point it starts
const SHADOW_COLOR = Color3.fromHex("#0B0B12")
const EYE_COLOR = Color3.fromHex("#F4F1E8")
const DROP_KEY = "shadow_whoosh"
const HANG_KEY = "steps_stop"

type Shape = { Model: Model, Eyes: { BasePart } }

local busy = false

local function part(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
	const piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Shape = shape or Enum.PartType.Block
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CFrame = offset
	piece.Parent = model
	return piece
end

-- Upside-down silhouette (head at the bottom, long arms hanging past it), built at the origin facing -Z; the pivot is
-- the head, so PivotTo puts the face where it hangs
local function shape(folder: Folder): Shape
	const model = Instance.new("Model")
	model.Name = "ANM019_Drop"
	part(model, "Body", Vector3.new(1.9, 3.4, 0.7), CFrame.new(0, 1.9, 0), SHADOW_COLOR)
	part(model, "Head", Vector3.new(1.7, 1.7, 1.7), CFrame.new(0, -0.6, 0), SHADOW_COLOR, Enum.PartType.Ball)
	part(model, "ArmL", Vector3.new(0.4, 3.6, 0.4), CFrame.new(-1.25, 0.2, 0) * CFrame.Angles(0, 0, math.rad(-8)), SHADOW_COLOR)
	part(model, "ArmR", Vector3.new(0.4, 3.6, 0.4), CFrame.new(1.25, 0.2, 0) * CFrame.Angles(0, 0, math.rad(8)), SHADOW_COLOR)
	const eyes: { BasePart } = {
		part(model, "EyeL", Vector3.new(0.38, 0.22, 0.1), CFrame.new(-0.36, -0.75, -0.82), EYE_COLOR),
		part(model, "EyeR", Vector3.new(0.38, 0.22, 0.1), CFrame.new(0.36, -0.75, -0.82), EYE_COLOR),
	}
	for _, eye in eyes do
		eye.Material = Enum.Material.Neon
		eye.Transparency = 1
	end
	model.WorldPivot = CFrame.new(0, -0.6, 0)
	model.Parent = folder
	return { Model = model, Eyes = eyes }
end

-- Heading straight ahead of the view (works when looking straight up)
local function ahead(view: CFrame): Vector3
	const _, yaw = view:ToOrientation()
	return CFrame.fromOrientation(0, yaw, 0).LookVector
end

-- The glass part ahead of the view: the hang point just outside it and its top. nil = no window in front
local function windowAhead(view: CFrame, forward: Vector3): (Vector3?, number?)
	const root = Workspace:FindFirstChild(MAP_NAME) or Workspace
	const eye = view.Position
	local best: BasePart? = nil
	local bestScore = -math.huge
	for _, piece in root:GetDescendants() do
		if not piece:IsA("BasePart") or (piece.Material ~= Enum.Material.Glass and not string.find(piece.Name, "Glass") and not string.find(piece.Name, "Window")) then
			continue
		end
		const offset = piece.Position - eye
		const flat = Vector3.new(offset.X, 0, offset.Z)
		const distance = flat.Magnitude
		if distance < 1 or distance > GLASS_RANGE or piece.Size.Magnitude < 3 then
			continue
		end
		const facing = flat.Unit:Dot(forward)
		if facing < GLASS_AHEAD then
			continue
		end
		const score = facing * 2 - distance / GLASS_RANGE
		if score > bestScore then
			best, bestScore = piece, score
		end
	end
	const glass = best
	if glass == nil then
		return nil, nil
	end
	-- the thinnest axis of the glass is its normal; point it away from the eye
	const size = glass.Size
	local normal = glass.CFrame.LookVector
	if size.X <= size.Y and size.X <= size.Z then
		normal = glass.CFrame.RightVector
	elseif size.Y <= size.X and size.Y <= size.Z then
		normal = glass.CFrame.UpVector
	end
	if normal:Dot(glass.Position - eye) < 0 then
		normal = -normal
	end
	const top = glass.Position.Y + math.abs(glass.CFrame:VectorToWorldSpace(size / 2).Y)
	return glass.Position + normal * OUTSIDE, top
end

-- It drops in front of this player's window, hangs, the face, it is gone (one at a time; yields ~1.4 s)
local function drop(ctx: Effect.Context)
	if busy then
		return
	end
	busy = true
	const view = Workspace.CurrentCamera
	if view == nil then
		busy = false
		Jumpscare.Show(ctx)
		return
	end
	const eye = view.CFrame.Position
	const forward = ahead(view.CFrame)
	const window, windowTop = windowAhead(view.CFrame, forward)
	const hang = window or eye + forward * OPEN_AHEAD
	const top = windowTop or eye.Y + 2
	const at = Vector3.new(hang.X, math.min(hang.Y, eye.Y + 0.5), hang.Z)
	const facing = CFrame.lookAt(at, Vector3.new(eye.X, at.Y, eye.Z))
	const from = facing + Vector3.new(0, math.max(FALL_FROM, top - at.Y + 4), 0)
	const built = shape(ctx.Folder())
	const model = built.Model
	model:PivotTo(from)
	ctx.Play(DROP_KEY, nil, true)
	const pivot = Instance.new("CFrameValue")
	pivot.Value = from
	pivot.Changed:Connect(function(value: CFrame)
		if model.Parent ~= nil then
			model:PivotTo(value)
		end
	end)
	TweenService:Create(pivot, TweenInfo.new(HANG_DROP, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = facing }):Play()
	task.wait(HANG_DROP)
	ctx.Play(HANG_KEY, at)
	for _, piece in built.Eyes do
		piece.Transparency = 0
	end
	const camera = Kits.Camera()
	if camera ~= nil then
		camera:HorrorShake("Jolt", 1)
		camera:HorrorFov(-5, 0, 0.9)
		camera:HorrorNudge(at, 3, 0.4)
	end
	-- it hangs and sways a touch
	TweenService
		:Create(pivot, TweenInfo.new(HANG_HOLD, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Value = facing * CFrame.Angles(0, 0, math.rad(6)),
		})
		:Play()
	task.wait(HANG_HOLD)
	task.spawn(Jumpscare.Show, ctx)
	TweenService:Create(pivot, TweenInfo.new(PULL_UP, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = from }):Play()
	task.wait(PULL_UP)
	pivot:Destroy()
	model:Destroy()
	busy = false
end

const RoofWalker: Effect.Module = {
	Ref = "ANM-019",

	Mount = function(_ctx: Effect.Context, occ: Effect.Occurrence)
		local interrupted = false
		Vide.effect(function()
			const phase = occ.Record().Phase
			if not interrupted and (phase == "Signal" or phase == "Active") then
				interrupted = true
				Watch.Interrupt()
			end
		end)
	end,

	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue ~= "jumpscare" or cue.Entity ~= Players.LocalPlayer.UserId % ENTITY_MOD then
			return
		end
		drop(ctx)
	end,
}

return RoofWalker
