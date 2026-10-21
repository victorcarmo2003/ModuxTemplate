--!strict
--[[
	Guide: the lobby floor guide (owner request 2026-10-20, Provisional). A line of Mustard chevrons ("^") painted on the
	floor from the player's feet to a target zone, sliding toward it, closed by one big flat arrow head at the zone edge
	(the look of the owner's reference shot). One Ink-outlined Highlight on the whole guide (same colours as the
	tutorial Trail and Arrow3D), occluded by props so it reads as paint on the floor.

	  - The owner (LobbyController) says where (Point(center, radius) = the zone floor top centre and its radius) or
	    Clear(); Step() every frame redraws it from the current feet. A straight line: the lobby floor is open.
	  - Reduced motion (Motion.Reduced): still chevrons.
	  - Under a cinematic (Cinematic.Active) it is taken out of the world and comes back when it ends.
	Local only (client parts in Workspace.LobbyGuide, no collision, no query, no touch, no shadow).
]]
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)

export type Guide = {
	-- Target: zone floor top centre and radius (the head stops at the edge). Same target again = nothing to do.
	Point: (center: Vector3, radius: number) -> (),
	Clear: () -> (),
	Step: () -> (),
	Destroy: () -> (),
}

-- PROVISIONAL sizes and timings (tune in play)
const ARM_LENGTH = 1.1 -- studs, one arm of a chevron
const ARM_WIDTH = 0.32
const THICKNESS = 0.08
const GAP = 2.4 -- studs between two chevron tips
const SPEED = 3 -- studs/s toward the target
const HEAD_LENGTH = 2.6
const HEAD_WIDTH = 3.2
const LIFT = 0.06 -- studs over the floor
const FILL = 0.35 -- Highlight fill (Arrow3D ARROW_FILL)
const START = 2.5 -- studs between the feet and the first chevron
const HEAD_GAP = 1.2 -- studs kept free between the last chevron and the head
const EDGE = 0.5 -- studs: the head tip stops this far outside the zone edge
const COUNT = 40 -- chevrons built (enough for ~96 studs; the far ones park)
const FOOT_PROBE = 8 -- studs under the root the floor ray looks
const PARK = CFrame.new(0, -1e4, 0)
const DIAGONAL = math.sqrt(0.5)

local function flat(className: string, name: string, size: Vector3, parent: Instance): BasePart
	const created = Instance.new(className) :: BasePart
	created.Name = name
	created.Size = size
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.CastShadow = false
	created.Massless = true
	created.Material = Enum.Material.SmoothPlastic
	created.Color = Theme.Color.Mustard
	created.CFrame = PARK
	created.Parent = parent
	return created
end

-- Point on the floor under the local character, nil without a character
local function feet(skip: Instance): Vector3?
	const character = Players.LocalPlayer.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if character == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance, skip }
	const hit = workspace:Raycast(root.Position, -Vector3.yAxis * FOOT_PROBE, params)
	return if hit then hit.Position else root.Position - Vector3.yAxis * 3
end

return function(): Guide
	local target: Vector3? = nil
	local radius = 0
	const startClock = os.clock()

	const model = Instance.new("Model")
	model.Name = "LobbyGuide"
	const outline = Instance.new("Highlight")
	outline.Name = "Outline"
	outline.FillColor = Theme.Color.Mustard
	outline.FillTransparency = FILL
	outline.OutlineColor = Theme.Color.Ink
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Adornee = model
	outline.Parent = model

	const armSize = Vector3.new(ARM_WIDTH, THICKNESS, ARM_LENGTH)
	const arms: { BasePart } = {}
	for i = 1, COUNT do
		table.insert(arms, flat("Part", `Left{i}`, armSize, model))
		table.insert(arms, flat("Part", `Right{i}`, armSize, model))
	end
	-- head: two flat wedges back to back, the right angle of each at the base centre, the slopes meeting at the tip
	const headSize = Vector3.new(THICKNESS, HEAD_WIDTH / 2, HEAD_LENGTH)
	const headLeft = flat("WedgePart", "HeadLeft", headSize, model)
	const headRight = flat("WedgePart", "HeadRight", headSize, model)

	local function park()
		const parts: { BasePart } = { headLeft, headRight }
		const frames: { CFrame } = { PARK, PARK }
		for _, arm in arms do
			table.insert(parts, arm)
			table.insert(frames, PARK)
		end
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	return {
		Point = function(center: Vector3, size: number)
			target = center
			radius = size
		end,
		Clear = function()
			target = nil
			model.Parent = nil
		end,
		Step = function()
			const goal = target
			if goal == nil then
				return
			end
			if Cinematic.Active() then
				model.Parent = nil
				return
			end
			const from = feet(model)
			if from == nil then
				model.Parent = nil
				return
			end
			const offset = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
			const span = offset.Magnitude - radius - EDGE -- feet to the head tip
			if span < START + HEAD_LENGTH then
				model.Parent = nil -- already at the zone
				return
			end
			if model.Parent == nil then
				park()
				model.Parent = workspace
			end
			const forward = offset.Unit
			const right = forward:Cross(Vector3.yAxis)
			const up = Vector3.yAxis
			-- floor height along the line: from the feet to the zone floor top
			local function at(s: number): Vector3
				const t = math.clamp(s / span, 0, 1)
				const y = from.Y + (goal.Y - from.Y) * t + LIFT + THICKNESS / 2
				return Vector3.new(from.X + forward.X * s, y, from.Z + forward.Z * s)
			end

			const parts: { BasePart } = {}
			const frames: { CFrame } = {}

			const tip = at(span)
			const base = tip - forward * HEAD_LENGTH
			-- right half: local Y = right (half width), local Z = backward (length), local X = down
			table.insert(parts, headRight)
			table.insert(frames, CFrame.fromMatrix(base + right * (HEAD_WIDTH / 4) + forward * (HEAD_LENGTH / 2), -up, right))
			table.insert(parts, headLeft)
			table.insert(frames, CFrame.fromMatrix(base - right * (HEAD_WIDTH / 4) + forward * (HEAD_LENGTH / 2), up, -right))

			const phase = if Motion.Reduced() then 0 else ((os.clock() - startClock) * SPEED) % GAP
			const last = span - HEAD_LENGTH - HEAD_GAP
			const backRight = (right - forward) * DIAGONAL
			const backLeft = (-right - forward) * DIAGONAL
			for i = 1, COUNT do
				const s = START + ARM_LENGTH * DIAGONAL + (i - 1) * GAP + phase
				local leftFrame, rightFrame = PARK, PARK
				if s <= last then
					const point = at(s)
					const leftCenter = point + backLeft * (ARM_LENGTH / 2)
					const rightCenter = point + backRight * (ARM_LENGTH / 2)
					leftFrame = CFrame.lookAt(leftCenter, leftCenter + backLeft)
					rightFrame = CFrame.lookAt(rightCenter, rightCenter + backRight)
				end
				table.insert(parts, arms[2 * i - 1])
				table.insert(frames, leftFrame)
				table.insert(parts, arms[2 * i])
				table.insert(frames, rightFrame)
			end
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end,
		Destroy = function()
			target = nil
			model:Destroy()
		end,
	}
end
