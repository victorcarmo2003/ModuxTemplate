--!strict
-- SeatingService/Diner: puts a server NPC rig on a seat and back (FEAT-037; TASK-145). No Service, no network.
--
-- Sit: the HumanoidRootPart (R6: same frame as the Torso) is anchored on the seat Part's position, facing the seat's
-- LookVector flattened (the table). While Content.Animations.npc_sit has no Id, the hips (and shoulders, hands on the
-- table) are bent through Motor6D.C0, which replicates: every client sees the R6 sitting pose with no client code.
-- With an Id the server only anchors and the client plays the clip on rigs with the `Seated` attribute (TASK-147).
-- The rest C0 of every posed motor is kept in the attribute RestC0 (NpcService/Pool.luau restores it on release, so
-- a pooled rig never comes out sitting).
-- Stand: rest C0 back, root unanchored, put upright on `standAt` (the approach point).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Rig = { Model: Model, Root: BasePart, Humanoid: Humanoid }

const REST_ATTRIBUTE = "RestC0"
const SEATED_ATTRIBUTE = "Seated" -- table index on the rig while seated (client contract, network.md §14.3)
const SIT_CLIP = "npc_sit"
const HALF_PI = math.pi / 2
-- Motor -> angle around its Z axis (the R6 Animate sit pose: hips +-90, shoulders +-90)
const POSE: { [string]: number } = {
	["Right Hip"] = HALF_PI,
	["Left Hip"] = -HALF_PI,
	["Right Shoulder"] = HALF_PI,
	["Left Shoulder"] = -HALF_PI,
}

const Diner = {}

-- The server bends the joints itself (no sitting clip uploaded yet).
function Diner.ServerPose(): boolean
	const row = Content.Animations.ByKey[SIT_CLIP]
	return row == nil or row.Id == ""
end

local function motors(rig: Rig): { Motor6D }
	const out: { Motor6D } = {}
	for _, motor in rig.Model:GetDescendants() do
		if motor:IsA("Motor6D") and POSE[motor.Name] ~= nil then
			table.insert(out, motor)
		end
	end
	return out
end

-- Seat frame for the root: seat position, facing the seat's LookVector on the XZ plane.
function Diner.SeatFrame(seat: BasePart): CFrame
	const look = seat.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	const position = seat.Position
	return CFrame.lookAt(position, position + flat.Unit)
end

-- Where a diner stands before sitting / after standing: Approach studs behind the seat, at `height` (root Y).
function Diner.ApproachPoint(seat: BasePart, height: number): Vector3
	const frame = Diner.SeatFrame(seat)
	const point = frame.Position - frame.LookVector * Content.Seating.Approach
	return Vector3.new(point.X, height, point.Z)
end

function Diner.Sit(rig: Rig, seat: BasePart, tableIndex: number)
	rig.Humanoid:MoveTo(rig.Root.Position)
	rig.Root.Anchored = true
	rig.Model:PivotTo(Diner.SeatFrame(seat))
	if Diner.ServerPose() then
		for _, motor in motors(rig) do
			local rest = motor:GetAttribute(REST_ATTRIBUTE)
			if typeof(rest) ~= "CFrame" then
				rest = motor.C0
				motor:SetAttribute(REST_ATTRIBUTE, rest)
			end
			motor.C0 = (rest :: CFrame) * CFrame.Angles(0, 0, POSE[motor.Name])
		end
	end
	rig.Model:SetAttribute(SEATED_ATTRIBUTE, tableIndex)
end

-- Joints back to rest and the seated mark gone. Safe on a rig that never sat or that went back to the pool.
function Diner.Unpose(rig: Rig)
	for _, motor in motors(rig) do
		const rest = motor:GetAttribute(REST_ATTRIBUTE)
		if typeof(rest) == "CFrame" then
			motor.C0 = rest
		end
	end
	rig.Model:SetAttribute(SEATED_ATTRIBUTE, nil)
end

-- Up from the seat, standing on `standAt` (root position), facing away from the table.
function Diner.Stand(rig: Rig, standAt: Vector3?)
	Diner.Unpose(rig)
	if standAt ~= nil and rig.Root:IsDescendantOf(workspace) then
		const look = rig.Root.CFrame.LookVector
		const flat = Vector3.new(look.X, 0, look.Z)
		const away = if flat.Magnitude > 1e-3 then -flat.Unit else Vector3.new(0, 0, 1)
		rig.Model:PivotTo(CFrame.lookAt(standAt, standAt + away))
	end
	rig.Root.Anchored = false
end

return table.freeze(Diner)
