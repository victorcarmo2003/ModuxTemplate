--!strict
-- Lobby set-dressing NPCs (TASK-452; DEC-289 L5, Q-353 A: always on; rows in Content.Lobby.Extras, TASK-451).
-- Client only: CrewRig rigs built here (root anchored, limbs on their Motor6D), no Humanoid, every part CanCollide /
-- CanQuery / CanTouch off, no shadow, never replicated (Workspace.LobbyExtras). The loops are procedural
-- (Motor6D.Transform written every frame): the R6 animation ids of Content.Animations are not uploaded yet, and a
-- Transform loop needs no Animator. A rig farther than Extras.Range from the camera leaves the world and is not
-- animated. SetHidden (class panel open: the HQ crew stands behind the class stage) takes every rig out.
-- Presentation only; nothing here touches a zone, a panel or the network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)

export type Extras = {
	Step: (t: number, camera: Vector3?) -> (),
	SetHidden: (on: boolean) -> (),
	Destroy: () -> (),
}

type Rig = {
	Row: Content.LobbyExtra,
	Model: Model,
	Root: BasePart,
	Neck: Motor6D?,
	Right: Motor6D?,
	Left: Motor6D?,
	Shown: boolean,
	Seed: number,
}

const LOBBY = Content.Lobby
const FOLDER = "LobbyExtras"
const SPAWN_LIFT = Vector3.new(0, 3, 0) -- CrewRig pivot above the feet (Cutscene Ambience / Actors)
const TOOLS = "Tools" -- ReplicatedStorage.Assets.Items.Tools

local function rad(deg: number): number
	return math.rad(deg)
end

-- R6 joints, Animate convention: + lift = arm forward / up (Left Shoulder turns the other way)
local function arm(lift: number, swing: number?): CFrame
	return CFrame.Angles(0, 0, rad(lift)) * CFrame.Angles(rad(swing or 0), 0, 0)
end

local function leftArm(lift: number): CFrame
	return CFrame.Angles(0, 0, -rad(lift))
end

-- Neck Transform: yaw turns the head, pitch nods (R6 Neck C0 turns X/Y; Angles(pitch, 0, yaw) in its frame)
local function head(yaw: number, pitch: number): CFrame
	return CFrame.Angles(rad(pitch), 0, rad(yaw))
end

type Pose = { Neck: CFrame, Right: CFrame, Left: CFrame }

-- One frame of a loop at time t (seconds, offset by the rig's seed).
local function pose(loop: Content.LobbyExtraLoop, t: number): Pose
	const breathe = math.sin(t * 1.3) * 2
	if loop == "Grill" then
		return { Neck = head(math.sin(t * 0.4) * 8, -12 + breathe), Right = arm(55 + math.sin(t * 2.2) * 18, math.sin(t * 2.2) * 10), Left = leftArm(30) }
	elseif loop == "Serve" then
		return { Neck = head(0, breathe), Right = arm(80 + math.sin(t * 1.6) * 6), Left = leftArm(0) }
	elseif loop == "Wave" then
		const waving = (t % 7) < 3 -- waves for 3 s every 7 s
		return {
			Neck = head(math.sin(t * 0.5) * 12, breathe),
			Right = if waving then arm(160, math.sin(t * 9) * 22) else arm(5),
			Left = leftArm(0),
		}
	elseif loop == "Wipe" then
		return { Neck = head(0, -15 + breathe), Right = arm(60, math.sin(t * 2.4) * 28), Left = leftArm(0) }
	elseif loop == "Eat" then
		const bite = math.max(0, math.sin(t * 1.4))
		return { Neck = head(0, -bite * 6 + breathe), Right = arm(70 + bite * 55), Left = leftArm(10) }
	elseif loop == "Chat" then
		const laugh = (t % 6) > 4.5
		return {
			Neck = head(math.sin(t * 0.7) * 30, if laugh then math.sin(t * 22) * 5 else breathe),
			Right = arm(15 + (if laugh then math.sin(t * 11) * 10 else 0)),
			Left = leftArm(10),
		}
	end
	-- Drive
	return { Neck = head(math.sin(t * 0.45) * 35, breathe), Right = arm(60), Left = leftArm(60) }
end

-- Clones the tool's parts into the right hand (welded, massless, no collision), like a held item.
local function hold(model: Model, toolName: string)
	const items = ReplicatedStorage:FindFirstChild("Assets")
	const tools = items and items:FindFirstChild("Items") and (items :: any).Items:FindFirstChild(TOOLS)
	const tool = tools and tools:FindFirstChild(toolName)
	const handArm = model:FindFirstChild("Right Arm")
	if tool == nil or not tool:IsA("Tool") or handArm == nil or not handArm:IsA("BasePart") then
		return
	end
	const handle = tool:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		return
	end
	const grip = handArm:FindFirstChild("RightGripAttachment")
	const gripCF = if grip and grip:IsA("Attachment")
		then grip.WorldCFrame
		else handArm.CFrame * CFrame.new(0, -handArm.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
	const base = gripCF * tool.Grip:Inverse()
	const held = Instance.new("Model")
	held.Name = `Held_{toolName}`
	for _, part in tool:GetChildren() do
		if part:IsA("BasePart") then
			const copy = part:Clone()
			for _, joint in copy:GetChildren() do
				if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
					joint:Destroy()
				end
			end
			copy.CFrame = base * handle.CFrame:ToObjectSpace(part.CFrame)
			copy.Anchored = false
			copy.Massless = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.CastShadow = false
			const weld = Instance.new("WeldConstraint")
			weld.Part0 = handArm
			weld.Part1 = copy
			weld.Parent = copy
			copy.Parent = held
		end
	end
	held.Parent = model
end

local function build(row: Content.LobbyExtra, parent: Instance, seed: number): Rig?
	const feet = row.Position
	const ok, result = pcall(function(): Model
		return CrewRig.Build(row.Species, row.Outfit, {
			Name = `Extra_{row.Key}`,
			CFrame = CFrame.new(feet + SPAWN_LIFT) * CFrame.Angles(0, math.pi + rad(row.Yaw), 0),
			Anchored = true,
			Tag = false,
			LookPack = "Day",
		})
	end)
	if not ok then
		warn(`[LobbyController] could not build the lobby extra {row.Key}: {result}`)
		return nil
	end
	const model = result :: Model
	const humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Destroy()
	end
	CrewRig.Dress(model, "Day", row.Expression)
	if row.Hold then
		hold(model, row.Hold)
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	const torso = model:FindFirstChild("Torso")
	local function joint(name: string): Motor6D?
		const j = torso and torso:FindFirstChild(name)
		return if j and j:IsA("Motor6D") then j else nil
	end
	const root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	model.Parent = parent
	return {
		Row = row,
		Model = model,
		Root = root,
		Neck = joint("Neck"),
		Right = joint("Right Shoulder"),
		Left = joint("Left Shoulder"),
		Shown = true,
		Seed = seed,
	}
end

return function(): Extras
	const folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = workspace
	const range = LOBBY.Extras.Range
	const rigs: { Rig } = {}
	for index, row in LOBBY.Extras.Rows do
		const rig = build(row, folder, index * 1.7)
		if rig then
			table.insert(rigs, rig)
		end
	end
	local hidden = false

	local function step(t: number, camera: Vector3?)
		if hidden then
			return
		end
		for _, rig in rigs do
			const near = camera == nil or (camera - rig.Root.Position).Magnitude <= range
			if near ~= rig.Shown then
				rig.Shown = near
				rig.Model.Parent = if near then folder else nil
			end
			if near then
				const p = pose(rig.Row.Loop, t + rig.Seed)
				if rig.Neck then
					rig.Neck.Transform = p.Neck
				end
				if rig.Right then
					rig.Right.Transform = p.Right
				end
				if rig.Left then
					rig.Left.Transform = p.Left
				end
			end
		end
	end

	local function setHidden(on: boolean)
		hidden = on
		folder.Parent = if on then nil else workspace
	end

	local function destroy()
		folder:Destroy()
		table.clear(rigs)
	end

	return {
		Step = step,
		SetHidden = setHidden,
		Destroy = destroy,
	}
end
