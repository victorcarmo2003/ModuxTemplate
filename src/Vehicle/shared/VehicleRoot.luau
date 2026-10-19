--!strict
-- The vehicle root: the Instance tagged `Vehicle` (attribute Vehicle = key). The trailer is a Model; the restaurant is a
-- Folder ("Trailer", owner 2026-10-18: a Folder keeps the shell, kitchen and pantry easy to pick in Studio). A Folder
-- has no pivot or bounding box, so both come from here:
--   Pivot  Model:GetPivot(); a Folder reads its `Pivot` attribute (CFrame, written by restaurant_bind from MapPoint
--          TRL), else the centre of its parts (axis aligned)
--   Box    Model:GetBoundingBox(); a Folder: the axis-aligned box of its BaseParts (cached per Folder)
-- Pure: no Modux, Lync or Vide.
local CollectionService = game:GetService("CollectionService")

const TAG = "Vehicle"
const ATTRIBUTE = "Vehicle"
const PIVOT_ATTRIBUTE = "Pivot"

const VehicleRoot = {}

VehicleRoot.Tag = TAG
VehicleRoot.Attribute = ATTRIBUTE

const boxes: { [Instance]: { CFrame: CFrame, Size: Vector3 } } = setmetatable({}, { __mode = "k" }) :: any

-- A vehicle root holds the tag and is a Model or a Folder
function VehicleRoot.Is(instance: Instance): boolean
	return (instance:IsA("Model") or instance:IsA("Folder")) and CollectionService:HasTag(instance, TAG)
end

-- The root of `key` in the Workspace (nil when it is not streamed in or not bound)
function VehicleRoot.Find(key: string?): Instance?
	for _, instance in CollectionService:GetTagged(TAG) do
		if
			(instance:IsA("Model") or instance:IsA("Folder"))
			and (key == nil or instance:GetAttribute(ATTRIBUTE) == key)
			and instance:IsDescendantOf(workspace)
		then
			return instance
		end
	end
	return nil
end

-- Nearest vehicle root at or above `instance` (nil if none)
function VehicleRoot.Above(instance: Instance): Instance?
	local current: Instance? = instance
	while current ~= nil do
		if CollectionService:HasTag(current, TAG) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function folderBox(root: Instance): (CFrame, Vector3)
	const cached = boxes[root]
	if cached ~= nil then
		return cached.CFrame, cached.Size
	end
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			const cf = part.CFrame
			const half = part.Size / 2
			-- world half extents of the oriented box
			const ex = math.abs(cf.XVector.X) * half.X + math.abs(cf.YVector.X) * half.Y + math.abs(cf.ZVector.X) * half.Z
			const ey = math.abs(cf.XVector.Y) * half.X + math.abs(cf.YVector.Y) * half.Y + math.abs(cf.ZVector.Y) * half.Z
			const ez = math.abs(cf.XVector.Z) * half.X + math.abs(cf.YVector.Z) * half.Y + math.abs(cf.ZVector.Z) * half.Z
			const extent = Vector3.new(ex, ey, ez)
			low = low:Min(cf.Position - extent)
			high = high:Max(cf.Position + extent)
		end
	end
	if low.X > high.X then
		return CFrame.identity, Vector3.zero
	end
	const frame = CFrame.new((low + high) / 2)
	const size = high - low
	boxes[root] = { CFrame = frame, Size = size }
	return frame, size
end

-- Bounding box of the root (CFrame at its centre, size)
function VehicleRoot.Box(root: Instance): (CFrame, Vector3)
	if root:IsA("Model") then
		return root:GetBoundingBox()
	end
	return folderBox(root)
end

-- Pivot of the root
function VehicleRoot.Pivot(root: Instance): CFrame
	if root:IsA("PVInstance") then
		return root:GetPivot()
	end
	const pivot = root:GetAttribute(PIVOT_ATTRIBUTE)
	if typeof(pivot) == "CFrame" then
		return pivot
	end
	return (folderBox(root))
end

return table.freeze(VehicleRoot)
