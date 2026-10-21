--!strict
-- ANM-016 The starer, client effect (V2 family A; DEC-254; TASK-292). Modifier "stare" and the jumpscare cue:
-- Kit/OddCustomer. Presentation only (T10).
-- TASK-591 (owner 2026-10-19, Provisional): cue stare_front (it reached the window, Entity = actor NpcId): EVERY
-- player's view is dragged to its head, slowly - a chain of eased pulls (CameraController:HorrorPull, each at most
-- Rules.MaxPull degrees over PULL_TIME s, never locking the input) until the look is on it - then the lights die for a
-- blink with a heavy thud and a jolt (the flash blackout), and come back. Reduced motion: the pulls shrink with the
-- camera's own horror scale; the flash stays (it is the sign).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Effect)
local OddCustomer = require(script.Parent.Kit.OddCustomer)
local Kits = require(script.Parent.Parent.Scene.Kits)
local Lights = require(script.Parent.Parent.Scene.Lights)

const FRONT_CUE = "stare_front"
const PULL_TIME = 1.6 -- s per pull: slow
const PULLS = 6 -- at most (6 x 30 = all the way round)
const ON_IT = 6 -- degrees: the look is on it, the pulls stop
const FLASH_AFTER = 0.35 -- s after the last pull lands
const FLASH_FOR = 0.16 -- s the lights are out
const THUD = "door_force" -- stands in for a heavy thud (sound-list.md, TASK-591)
const MAX_PULL = Content.HorrorScenes.Rules.MaxPull

const base = OddCustomer.Effect("ANM-016", "stare")

-- Degrees between the look and the direction to `at`
local function offAngle(at: Vector3): number?
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	const offset = at - camera.CFrame.Position
	if offset.Magnitude < 0.01 then
		return 0
	end
	return math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(offset.Unit), -1, 1)))
end

local function headOf(ctx: Effect.Context, npc: number): BasePart?
	const model = ctx.Npc(npc)
	const head = if model ~= nil then model:FindFirstChild("Head") else nil
	return if head ~= nil and head:IsA("BasePart") then head else nil
end

local function flash(ctx: Effect.Context, at: Vector3)
	const camera = Kits.Camera()
	ctx.Play(THUD, at)
	if not Lights.IsOff() then
		Lights.Off()
		task.delay(FLASH_FOR, function()
			Lights.On()
		end)
	end
	if camera ~= nil then
		camera:HorrorShake("Jolt", 1)
		camera:HorrorFov(-4, 0, 0.5)
	end
end

local function front(ctx: Effect.Context, npc: number)
	const camera = Kits.Camera()
	task.spawn(function()
		for _ = 1, PULLS do
			const head = headOf(ctx, npc)
			if head == nil then
				return -- gone
			end
			const off = offAngle(head.Position)
			const pull = camera
			if off == nil or off <= ON_IT or pull == nil then
				break
			end
			pull:HorrorPull(head.Position, math.min(off, MAX_PULL), PULL_TIME)
			task.wait(PULL_TIME)
		end
		task.wait(FLASH_AFTER)
		const head = headOf(ctx, npc)
		if head ~= nil then
			flash(ctx, head.Position)
		end
	end)
end

return {
	Ref = base.Ref,
	Mount = base.Mount,
	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == FRONT_CUE then
			front(ctx, cue.Entity)
			return
		end
		const handler = base.Cue
		if handler ~= nil then
			handler(ctx, cue)
		end
	end,
} :: Effect.Module
