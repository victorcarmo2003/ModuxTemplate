--!strict
-- ANM-022 The head banger, client effect (V2 family A; TASK-591; owner 2026-10-19, Provisional Q-399). Modifier
-- "banger" (head hanging forward) and the jumpscare cue: Kit/OddCustomer. Presentation only (T10).
-- Cue head_bang (Entity = actor NpcId): one blow of its head on the shut window - a heavy thud at the shutter, the
-- shutter panel jumping in and shivering back, the camera shaken (harder the closer the
-- player stands). The rhythm is the server's (Rules/ANM-022 BangEvery / BangFaster).
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Effect = require(script.Parent.Parent.Effect)
local OddCustomer = require(script.Parent.Kit.OddCustomer)
local Kits = require(script.Parent.Parent.Scene.Kits)

const BANG_CUE = "head_bang"
const THUD = "door_force" -- stands in for a head on a shutter (sound-list.md, TASK-591)
const SHUTTER_NAME = "Shutter_Panel" -- MAP01 Trailer.Front (the service window's shutter)
const SHUTTER_SEARCH = 14 -- studs from the actor's head
const JUMP = 0.12 -- studs the panel is pushed in
const SHIVER = 0.35 -- s it shivers back
const NEAR = 18 -- studs: full camera shake inside this, fading to nothing at 2x

const base = OddCustomer.Effect("ANM-022", "banger")

-- panel -> its resting CFrame while a shiver runs (never stacked: a new blow restarts from the rest)
const resting: { [BasePart]: CFrame } = {}
const shivers: { [BasePart]: RBXScriptConnection } = {}

local function shutterNear(at: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = SHUTTER_SEARCH
	const map = Workspace:FindFirstChild("MAP01_Restaurant")
	if map == nil then
		return nil
	end
	for _, d in map:GetDescendants() do
		if d.Name == SHUTTER_NAME and d:IsA("BasePart") then
			const distance = (d.Position - at).Magnitude
			if distance < bestDistance then
				best, bestDistance = d, distance
			end
		end
	end
	return best
end

local function jump(panel: BasePart, from: Vector3)
	const rest = resting[panel] or panel.CFrame
	resting[panel] = rest
	const old = shivers[panel]
	if old ~= nil then
		old:Disconnect()
	end
	-- pushed away from the head, along the panel's thin axis
	const away = (rest.Position - from)
	const push = if away.Magnitude > 0.01 then away.Unit * JUMP else Vector3.zero
	local t = 0
	shivers[panel] = RunService.RenderStepped:Connect(function(dt)
		t += dt
		const k = math.clamp(t / SHIVER, 0, 1)
		const wobble = math.cos(k * math.pi * 5) * (1 - k)
		panel.CFrame = rest + push * wobble
		if k >= 1 then
			panel.CFrame = rest
			resting[panel] = nil
			shivers[panel]:Disconnect()
			shivers[panel] = nil
		end
	end)
end

local function bang(ctx: Effect.Context, npc: number)
	const model = ctx.Npc(npc)
	const head = if model ~= nil then model:FindFirstChild("Head") else nil
	if head == nil or not head:IsA("BasePart") then
		return
	end
	const panel = shutterNear(head.Position)
	const at = if panel ~= nil then panel.Position else head.Position
	ctx.Play(THUD, at)
	if panel ~= nil then
		jump(panel, head.Position)
	end
	const camera = Kits.Camera()
	const view = Workspace.CurrentCamera
	if camera ~= nil and view ~= nil then
		const distance = (view.CFrame.Position - at).Magnitude
		const scale = math.clamp(1 - (distance - NEAR) / NEAR, 0, 1)
		if scale > 0 then
			camera:HorrorShake("Door", scale)
		end
	end
end

return {
	Ref = base.Ref,
	Mount = base.Mount,
	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == BANG_CUE then
			bang(ctx, cue.Entity)
			return
		end
		const handler = base.Cue
		if handler ~= nil then
			handler(ctx, cue)
		end
	end,
} :: Effect.Module
