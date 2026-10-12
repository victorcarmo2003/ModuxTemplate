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
	-- Field of view of the view (an anchor attribute `Fov`, the Views row, or Rules.Camera.Fov).
	Fov: number,
	Source: "Anchor" | "Fallback" | "Mock",
}

const prep = Content.Prep
const cfg = prep.Rules.Camera
-- hops of a view Fallback chain (Content.Prep Validate refuses a cycle; this is the belt)
const MAX_HOPS = 6
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

-- Camera view of a tab. 2D mode (Rules.ThreeD = false): Order and Grill look at the grill, Build and Serve at the cutting board
-- (DEC-224: the seats are logical, the two views are the two natural places; the Station_n model carries CamAnchor / Focus for
-- the grill and CamAnchor_Build / Focus_Build for the board). 3D mode: one view per section (Content.Prep.Views: Grill, Board,
-- Toppings, Window = the Serve tab); a tab key of the other mode resolves through Content.Prep.TabAlias.
function Poses.ViewOf(tab: string): string
	if not prep.Rules.ThreeD then
		return if tab == "Build" or tab == "Serve" then "Build" else "Grill"
	end
	const key = if prep.Tabs.ByKey[tab] ~= nil then tab else (prep.TabAlias[tab] or tab)
	for _, row in prep.Views.List do
		if row.Tab == key then
			return row.Key
		end
	end
	return "Grill"
end

type Row = { Anchor: string, Focus: string, Fallback: string, Fov: number }

-- Anchor names of a view: a Content.Prep.Views row, or "Build" = the legacy pair of the 2D mode.
local function rowOf(view: string): Row?
	if view == "Build" then
		const legacy = prep.LegacyView
		return { Anchor = legacy.Anchor, Focus = legacy.Focus, Fallback = "", Fov = 0 }
	end
	return prep.Views.ByKey[view]
end

-- The Fov of a view: the attribute `Fov` of the anchor wins, then the Views row, then Rules.Camera.Fov.
local function fovOf(anchor: Instance, row: Row): number
	const attribute = anchor:GetAttribute(prep.Rules.World.Attr.Fov)
	if type(attribute) == "number" and attribute > 0 then
		return attribute
	end
	return if row.Fov > 0 then row.Fov else cfg.Fov
end

-- The pose of station `station` for a view ("Grill" default), nil when neither the anchors nor the trailer exist (not streamed
-- in yet). A view with no anchor in the Station_n model walks its Fallback chain (Views row, "Build" = the legacy pair, "" = end);
-- then the Grill anchor; then the TRL fallback below. A cycle in the data ends after a few hops (Validate also refuses it).
function Poses.Of(station: number, view: string?): Pose?
	const wanted = view or "Grill"
	const model = stationModel(station)
	if model ~= nil then
		local key = wanted
		for _ = 1, MAX_HOPS do
			const row = rowOf(key)
			if row == nil then
				break
			end
			const anchorInstance = model:FindFirstChild(row.Anchor, true)
			const anchor = frameOf(anchorInstance)
			if anchor ~= nil and anchorInstance ~= nil then
				const focusFrame = frameOf(model:FindFirstChild(row.Focus, true))
				const focus = if focusFrame ~= nil then focusFrame.Position else anchor.Position + anchor.LookVector * cfg.Distance
				return { Frame = anchor, Focus = focus, Fov = fovOf(anchorInstance, row), Source = "Anchor" }
			end
			if row.Fallback == "" then
				break
			end
			key = row.Fallback
		end
		-- the last link of every chain: the Grill view
		const grill = rowOf("Grill")
		const grillInstance = if grill ~= nil then model:FindFirstChild(grill.Anchor, true) else nil
		const grillAnchor = frameOf(grillInstance)
		if grill ~= nil and grillInstance ~= nil and grillAnchor ~= nil then
			const focusFrame = frameOf(model:FindFirstChild(grill.Focus, true))
			const focus = if focusFrame ~= nil then focusFrame.Position else grillAnchor.Position + grillAnchor.LookVector * cfg.Distance
			const row = rowOf(wanted)
			return { Frame = grillAnchor, Focus = focus, Fov = if row ~= nil and row.Fov > 0 then row.Fov else cfg.Fov, Source = "Anchor" }
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
	const fallbackRow = rowOf(wanted)
	const fov = if fallbackRow ~= nil and fallbackRow.Fov > 0 then fallbackRow.Fov else cfg.Fov
	return { Frame = CFrame.lookAt(eye.Position, bench.Position), Focus = bench.Position, Fov = fov, Source = "Fallback" }
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
	return { Frame = CFrame.lookAt(eye, focus), Focus = focus, Fov = cfg.Fov, Source = "Mock" }
end

return Poses
