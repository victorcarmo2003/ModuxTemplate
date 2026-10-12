--!strict
-- Poses: the camera pose of each prep station (docs/art/prep-ui-spec.md §13.2; docs/tech/prep-mode.md §6 "Mapa").
-- With the map done (TASK-172) every `Station_n` Model (tag `Station`, StationKind "prep") carries `CamAnchor` (the camera
-- CFrame, about 2.5 studs from the bench, pitch about -55 degrees) and `Focus` (the point the camera looks at: the centre of
-- the plate, also the focus of the depth of field). Until then the FALLBACK builds the same pose from the trailer MapPoint
-- `TRL` (Provisional numbers, the level-designer replaces them with the anchors):
--   F  = TRL * (Spacing * (n - 2.5), Height, 0)                    bench point of station n, stations side by side
--   cam = F + (0, D sin(pitch), D cos(pitch)) in the TRL frame      "+Z local" = the player's side of the bench
--   CFrame.lookAt(cam, F)
-- where D = Rules.Camera.Distance and pitch = |Rules.Camera.Pitch|. `Mock` is the pose of the dev UI preview when there is
-- no trailer at all: a few studs in front of the own head, looking down at a point on the floor.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)

export type Pose = {
	Frame: CFrame,
	-- Centre of the plate (the DOF focus and the end of the NPC cut segment).
	Focus: Vector3,
	Source: "Anchor" | "Fallback" | "Mock",
}

const cfg = Content.Prep.Rules.Camera
-- Provisional (spec §13.2): stations 3.5 studs apart (the plate of the neighbour stays out of the frame), bench 1.5 studs
-- over the TRL pivot (floor +2, bench 3.5 above the ground)
const SPACING = 3.5
const HEIGHT = 1.5

const Poses = {}

local function frameOf(instance: Instance?): CFrame?
	if instance == nil then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance.CFrame
	elseif instance:IsA("Attachment") then
		return instance.WorldCFrame
	elseif instance:IsA("Model") then
		return instance:GetPivot()
	end
	return nil
end

local function stationModel(station: number): Instance?
	const name = `Station_{station}`
	for _, instance in CollectionService:GetTagged("Station") do
		if instance.Name == name then
			return instance
		end
	end
	return workspace:FindFirstChild(name, true)
end

-- The pose of station `station`, nil when neither the anchors nor the trailer exist (not streamed in yet).
function Poses.Of(station: number): Pose?
	const model = stationModel(station)
	if model ~= nil then
		const anchor = frameOf(model:FindFirstChild("CamAnchor", true))
		if anchor ~= nil then
			const focusFrame = frameOf(model:FindFirstChild("Focus", true))
			const focus = if focusFrame ~= nil then focusFrame.Position else anchor.Position + anchor.LookVector * cfg.Distance
			return { Frame = anchor, Focus = focus, Source = "Anchor" }
		end
	end
	local trailer = MapIndex.FindPoint("TRL")
	if trailer == nil then
		MapIndex.Refresh()
		trailer = MapIndex.FindPoint("TRL")
	end
	if trailer == nil then
		return nil
	end
	const bench: CFrame = trailer * CFrame.new(SPACING * (station - 2.5), HEIGHT, 0)
	const pitch = math.rad(math.abs(cfg.Pitch))
	const eye: CFrame = bench * CFrame.new(0, cfg.Distance * math.sin(pitch), cfg.Distance * math.cos(pitch))
	return { Frame = CFrame.lookAt(eye.Position, bench.Position), Focus = bench.Position, Source = "Fallback" }
end

-- Dev preview pose: in front of the own head, looking at the ground a little ahead.
function Poses.Mock(): Pose?
	const character = Players.LocalPlayer.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	const focus = root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, -1.5, 0)
	const pitch = math.rad(math.abs(cfg.Pitch))
	const eye = focus + Vector3.new(0, cfg.Distance * math.sin(pitch), 0) - root.CFrame.LookVector * cfg.Distance * math.cos(pitch)
	return { Frame = CFrame.lookAt(eye, focus), Focus = focus, Source = "Mock" }
end

return Poses
