--!strict
-- Visible upgrade pieces (DEC-052; architecture.md §18.1, §18.2, §18.4 T38). Plain module, no Modux and no network.
-- A piece is any instance tagged UpgradePiece with attributes Upgrade (key of Content.Upgrades) and Level (int).
-- It belongs to the vehicle of its nearest ancestor tagged Vehicle (attribute Vehicle); the trailer piece is another
-- instance (DEC-184). Pieces are toggled by visibility, never reparented: the original Transparency / CanCollide /
-- CanQuery (and Enabled of effects/guis) are kept in attributes while hidden. Prefix "Upg" so the blockout tool's
-- own Orig* attributes (tools/assetplace/place_assets.luau) never collide with these.
local CollectionService = game:GetService("CollectionService")

export type Piece = {
	Instance: Instance,
	Upgrade: string,
	Level: number,
	Vehicle: string?, -- nil = no Vehicle ancestor (the current vehicle is used)
}

const TAG = "UpgradePiece"
const VEHICLE_TAG = "Vehicle"
const HIDDEN = "UpgHidden"
const TRANSPARENCY = "UpgOrigTransparency"
const COLLIDE = "UpgOrigCanCollide"
const QUERY = "UpgOrigCanQuery"
const ENABLED = "UpgOrigEnabled"

const Pieces = {}

Pieces.Tag = TAG

-- Vehicle key of the nearest ancestor tagged Vehicle
function Pieces.vehicleOf(instance: Instance): string?
	local node = instance.Parent
	while node ~= nil and node ~= game do
		if CollectionService:HasTag(node, VEHICLE_TAG) then
			const key = node:GetAttribute("Vehicle")
			return if typeof(key) == "string" and key ~= "" then key else nil
		end
		node = node.Parent
	end
	return nil
end

-- Reads the authored attributes; nil (with the reason) when the piece is malformed
function Pieces.read(instance: Instance): (Piece?, string?)
	const upgrade = instance:GetAttribute("Upgrade")
	const level = instance:GetAttribute("Level")
	if typeof(upgrade) ~= "string" or upgrade == "" then
		return nil, "missing string attribute Upgrade"
	end
	if typeof(level) ~= "number" or level ~= math.floor(level) or level < 0 then
		return nil, "missing integer attribute Level"
	end
	return {
		Instance = instance,
		Upgrade = upgrade,
		Level = level,
		Vehicle = Pieces.vehicleOf(instance),
	},
		nil
end

local function hide(item: Instance)
	if item:GetAttribute(HIDDEN) then
		return
	end
	if item:IsA("BasePart") then
		item:SetAttribute(TRANSPARENCY, item.Transparency)
		item:SetAttribute(COLLIDE, item.CanCollide)
		item:SetAttribute(QUERY, item.CanQuery)
		item.Transparency = 1
		item.CanCollide = false
		item.CanQuery = false
	elseif item:IsA("Decal") or item:IsA("Texture") then
		item:SetAttribute(TRANSPARENCY, item.Transparency)
		item.Transparency = 1
	elseif item:IsA("ParticleEmitter") or item:IsA("Light") or item:IsA("Beam") or item:IsA("Trail") then
		item:SetAttribute(ENABLED, item.Enabled)
		item.Enabled = false
	elseif item:IsA("SurfaceGui") or item:IsA("BillboardGui") then
		item:SetAttribute(ENABLED, item.Enabled)
		item.Enabled = false
	else
		return
	end
	item:SetAttribute(HIDDEN, true)
end

local function show(item: Instance)
	if not item:GetAttribute(HIDDEN) then
		return
	end
	if item:IsA("BasePart") then
		const transparency = item:GetAttribute(TRANSPARENCY)
		item.Transparency = if typeof(transparency) == "number" then transparency else 0
		item.CanCollide = item:GetAttribute(COLLIDE) ~= false
		item.CanQuery = item:GetAttribute(QUERY) ~= false
	elseif item:IsA("Decal") or item:IsA("Texture") then
		const transparency = item:GetAttribute(TRANSPARENCY)
		item.Transparency = if typeof(transparency) == "number" then transparency else 0
	elseif item:IsA("ParticleEmitter") or item:IsA("Light") or item:IsA("Beam") or item:IsA("Trail") then
		item.Enabled = item:GetAttribute(ENABLED) ~= false
	elseif item:IsA("SurfaceGui") or item:IsA("BillboardGui") then
		item.Enabled = item:GetAttribute(ENABLED) ~= false
	end
	for _, name in { HIDDEN, TRANSPARENCY, COLLIDE, QUERY, ENABLED } do
		item:SetAttribute(name, nil)
	end
end

-- Shows or hides the piece and everything under it. Idempotent: hiding twice keeps the first originals.
function Pieces.setVisible(instance: Instance, visible: boolean)
	const apply = if visible then show else hide
	apply(instance)
	for _, item in instance:GetDescendants() do
		apply(item)
	end
end

-- Pieces in the Workspace (the tag may also sit on templates in storage: those are left alone)
function Pieces.all(): { Instance }
	const out = {}
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsDescendantOf(workspace) then
			table.insert(out, instance)
		end
	end
	return out
end

return table.freeze(Pieces)
