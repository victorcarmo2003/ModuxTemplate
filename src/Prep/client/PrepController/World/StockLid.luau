--!strict
-- World/StockLid: the lid of the sausage container (target SausageStock) opens when the pointer is over it (polish of 2026-10-12): a hinge
-- tween with a spring (0.2 s, a little overshoot) and a sausage peeking from the inside while it is open; it closes when the pointer
-- leaves. The cooler of the trailer (TRL-S_AST-018_CoolerL1) is the model: its visible lids (MeshPart "Lid*" that is not transparent:
-- `Lid` of the level 1, `Lid_L` of the level 2) are moved LOCALLY (the server never sees it) around the edge farthest from the camera, and
-- given back exactly on Destroy. A level whose lid is part of the body (no "Lid*" MeshPart) is left alone: the peeking sausage still shows.
-- The cooler is found by the hitbox of the target (the nearest model with a `UpgradePieces` or a `Fixed_Lid` inside); nothing is
-- authored in the map. No Modux, no Vide, no network.

export type StockLid = {
	-- The pointer is over the container (true) or left it (false).
	SetOpen: (self: StockLid, open: boolean) -> (),
	Step: (self: StockLid, dt: number) -> (),
	Destroy: (self: StockLid) -> (),
}

type Lid = { Part: BasePart, Home: CFrame }

const OPEN_ANGLE = math.rad(100)
-- Spring of the hinge: period ~0.2 s, damped so that it overshoots a little (about 8 %).
const STIFFNESS = 900
const DAMPING = 32
const SEARCH = 4 -- studs around the hitbox

const StockLid = {}

-- The model of the cooler that holds the hitbox: the closest model around it that has lids.
local function coolerOf(hitbox: BasePart): Model?
	local best: Model? = nil
	local bestDistance = math.huge
	for _, part in workspace:GetPartBoundsInRadius(hitbox.Position, SEARCH) do
		const model = part:FindFirstAncestorOfClass("Model")
		if model ~= nil and model ~= best and (model:FindFirstChild("UpgradePieces") ~= nil or model:FindFirstChild("Fixed_Lid", true) ~= nil) then
			const distance = (model:GetPivot().Position - hitbox.Position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = model
			end
		end
	end
	return best
end

local function visibleLids(cooler: Model): { Lid }
	const found: { Lid } = {}
	for _, descendant in cooler:GetDescendants() do
		if
			descendant:IsA("MeshPart")
			and string.sub(descendant.Name, 1, 3) == "Lid"
			and descendant.Transparency < 0.95
			and descendant.LocalTransparencyModifier < 0.95
			and descendant.Anchored
		then
			table.insert(found, { Part = descendant, Home = descendant.CFrame })
		end
	end
	return found
end

function StockLid.new(folder: Folder, hitbox: BasePart): StockLid
	const cooler = coolerOf(hitbox)
	local lids: { Lid } = {}
	local wantOpen = false
	local angle = 0
	local velocity = 0
	local scanned = false

	-- the sausage that peeks: a cartoon sausage standing in the box, rising with the lid
	const peek = Instance.new("Part")
	peek.Name = "Prep_StockPeek"
	peek.Shape = Enum.PartType.Cylinder
	peek.Material = Enum.Material.SmoothPlastic
	peek.Color = Color3.fromHex("#E39A82")
	peek.Size = Vector3.new(1.1, 0.34, 0.34)
	peek.Anchored = true
	peek.CanCollide = false
	peek.CanQuery = false
	peek.CanTouch = false
	peek.CastShadow = false
	peek.Transparency = 1
	peek.Parent = folder
	const tipCap = peek:Clone()
	tipCap.Name = "Prep_StockPeekTip"
	tipCap.Shape = Enum.PartType.Ball
	tipCap.Size = Vector3.one * 0.34
	tipCap.Parent = folder

	local function place(openness: number)
		const base = hitbox.Position
		-- from inside the box (hidden by the lid) to standing out of it, a little tilted, bobbing a hair with the opening
		const lift = -0.35 + 0.95 * openness
		const root = CFrame.new(base.X + 0.1, base.Y + 0.15 + lift, base.Z) * CFrame.Angles(0, 0, math.rad(15)) * CFrame.Angles(0, 0, math.pi / 2)
		peek.CFrame = root
		tipCap.CFrame = root * CFrame.new(0.55, 0, 0)
		const alpha = if openness < 0.08 then 1 else 0
		peek.Transparency = alpha
		tipCap.Transparency = alpha
	end

	local function poseLids()
		const camera = workspace.CurrentCamera
		for _, lid in lids do
			if lid.Part.Parent == nil then
				continue
			end
			const home = lid.Home
			const size = lid.Part.Size
			-- the hinge: the horizontal edge of the lid farthest from the camera
			const toCamera = if camera ~= nil then camera.CFrame.Position - home.Position else Vector3.zAxis
			const flat = Vector3.new(toCamera.X, 0, toCamera.Z)
			const away = if flat.Magnitude > 1e-3 then -flat.Unit else -Vector3.zAxis
			local axis = home.RightVector
			local half = size.X / 2
			if math.abs(away:Dot(home.LookVector)) > math.abs(away:Dot(home.RightVector)) then
				axis = home.LookVector
				half = size.Z / 2
			end
			const sign = if away:Dot(axis) >= 0 then 1 else -1
			const hinge = home.Position + axis * (half * sign) - home.UpVector * (size.Y / 2)
			-- the turn axis lies along the hinge edge; the sign lifts the near edge
			const spin = axis:Cross(home.UpVector)
			const turn = angle
			local rotated = CFrame.fromAxisAngle(spin, turn * sign)
			const probe = home.Position - axis * (half * sign)
			const lifted = (CFrame.new(hinge) * rotated * CFrame.new(-hinge)):PointToWorldSpace(probe)
			if lifted.Y < probe.Y then
				rotated = CFrame.fromAxisAngle(spin, -turn * sign)
			end
			lid.Part.CFrame = CFrame.new(hinge) * rotated * CFrame.new(-hinge) * home
		end
	end

	const self = {} :: any

	function self.SetOpen(_: any, open: boolean)
		wantOpen = open
		if open and not scanned then
			scanned = true
			if cooler ~= nil then
				lids = visibleLids(cooler)
			end
		end
	end

	function self.Step(_: any, dt: number)
		const goal = if wantOpen then OPEN_ANGLE else 0
		if math.abs(angle - goal) < 0.002 and math.abs(velocity) < 0.01 then
			return
		end
		-- a spring integrated in small steps (stable at any frame time)
		local left = math.min(dt, 0.1)
		while left > 0 do
			const h = math.min(left, 1 / 120)
			velocity += ((goal - angle) * STIFFNESS - velocity * DAMPING) * h
			angle += velocity * h
			left -= h
		end
		angle = math.max(angle, 0)
		if angle < 0.002 and not wantOpen then
			angle = 0
			velocity = 0
		end
		const openness = math.clamp(angle / OPEN_ANGLE, 0, 1.2)
		poseLids()
		place(math.clamp(openness, 0, 1))
	end

	function self.Destroy(_: any)
		for _, lid in lids do
			if lid.Part.Parent ~= nil then
				lid.Part.CFrame = lid.Home
			end
		end
		table.clear(lids)
		peek:Destroy()
		tipCap:Destroy()
	end

	return self :: StockLid
end

return StockLid
