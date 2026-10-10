--[[
	MAP-01 asset placement (technical prototype, Phase 0 - same status as tools/blockout).

	Replaces blockout pieces with the imported assets listed in MAP-01_placements.luau.
	Idempotent: rebuilds workspace.MAP01_Assets every run. Blockout parts listed in `replaces` are hidden
	(Transparency 1, no collision/query) and remember their original values in attributes, so `restore()` brings
	the blockout back exactly. Nothing in the blockout is destroyed.

	Assets come from the group-owned Model assets uploaded from Assets/import (ids in Assets/import/_asset_ids.json).
	They are cached once in ServerStorage.__AssetCache (PackageLink removed) and cloned per placement.
	Asset convention: pivot = base centre, front = local -Z (LookVector), 1 unit = 1 stud.

	Usage (edit mode, Command Bar or Studio MCP):
		local Place = require(<this module>)
		Place.run(placements, ids)   -- placements = require(MAP-01_placements), ids = { [name] = assetId }
		Place.restore()              -- show the blockout again and delete MAP01_Assets
]]

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local Place = {}

local ROOT_NAME = "MAP01_Assets"
local CACHE_NAME = "__AssetCache"
local HIDDEN_ATTR = "HiddenByAssets"

local function cacheFolder(): Folder
	local f = ServerStorage:FindFirstChild(CACHE_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = CACHE_NAME
		f.Parent = ServerStorage
	end
	return f :: Folder
end

-- Loads (once) the asset model for `name` and returns the cached template.
local function template(name: string, ids: { [string]: any }): (Instance?, string?)
	local cache = cacheFolder()
	local hit = cache:FindFirstChild(name)
	if hit then
		return hit, nil
	end
	local id = ids[name]
	if not id then
		return nil, "no asset id for " .. name
	end
	local ok, res = pcall(function()
		return InsertService:LoadAsset(tonumber(id) :: number)
	end)
	if not ok then
		return nil, "LoadAsset failed for " .. name .. ": " .. tostring(res)
	end
	local model = res:GetChildren()[1]
	if not model then
		res:Destroy()
		return nil, "empty asset " .. name
	end
	for _, d in model:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			-- glass pieces split out by export_import.py (flat-colour material) are translucent
			if string.sub(d.Name, 1, 5) == "Glass" then
				d.Transparency = 0.5
				d.CastShadow = false
			end
		end
	end
	model.Name = name
	model.Parent = cache
	res:Destroy()
	return model, nil
end

local function blockoutRoot(): Instance?
	return workspace:FindFirstChild("MAP01_Blockout")
end

local function findPath(root: Instance, path: string): Instance?
	local node: Instance? = root
	for seg in string.gmatch(path, "[^/]+") do
		node = node and node:FindFirstChild(seg)
	end
	return node
end

local function hide(inst: Instance)
	local list = { inst }
	for _, d in inst:GetDescendants() do
		table.insert(list, d)
	end
	for _, d in list do
		if d:IsA("BasePart") and not d:GetAttribute(HIDDEN_ATTR) then
			d:SetAttribute(HIDDEN_ATTR, true)
			d:SetAttribute("OrigTransparency", d.Transparency)
			d:SetAttribute("OrigCanCollide", d.CanCollide)
			d:SetAttribute("OrigCanQuery", d.CanQuery)
			d.Transparency = 1
			d.CanCollide = false
			d.CanQuery = false
		elseif (d:IsA("Decal") or d:IsA("Texture")) and not d:GetAttribute(HIDDEN_ATTR) then
			d:SetAttribute(HIDDEN_ATTR, true)
			d:SetAttribute("OrigTransparency", d.Transparency)
			d.Transparency = 1
		elseif (d:IsA("SurfaceGui") or d:IsA("BillboardGui")) and not d:GetAttribute(HIDDEN_ATTR) then
			d:SetAttribute(HIDDEN_ATTR, true)
			d:SetAttribute("OrigEnabled", d.Enabled)
			d.Enabled = false
		end
	end
end

function Place.restore(): number
	local n = 0
	local root = blockoutRoot()
	if root then
		for _, d in root:GetDescendants() do
			if d:GetAttribute(HIDDEN_ATTR) then
				if d:IsA("BasePart") then
					d.Transparency = d:GetAttribute("OrigTransparency") or 0
					d.CanCollide = d:GetAttribute("OrigCanCollide") ~= false
					d.CanQuery = d:GetAttribute("OrigCanQuery") ~= false
				elseif d:IsA("Decal") or d:IsA("Texture") then
					d.Transparency = d:GetAttribute("OrigTransparency") or 0
				elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
					d.Enabled = d:GetAttribute("OrigEnabled") ~= false
				end
				for _, a in { HIDDEN_ATTR, "OrigTransparency", "OrigCanCollide", "OrigCanQuery", "OrigEnabled" } do
					d:SetAttribute(a, nil)
				end
				n += 1
			end
		end
	end
	local old = workspace:FindFirstChild(ROOT_NAME)
	if old then
		old:Destroy()
	end
	return n
end

-- Swap the visible layer: "night" shows the Pad trailer set and stores the day cart set, "day" the opposite.
function Place.showLayer(layer: string): string
	local day = workspace:FindFirstChild(ROOT_NAME)
	if not day then
		return "run Place.run first"
	end
	local function move(from: Instance?, to: Instance, name: string)
		if from and from:FindFirstChild(name) then
			from[name].Parent = to
		end
	end
	local nightStore = ServerStorage:FindFirstChild(ROOT_NAME .. "_Night")
	local dayStore = ServerStorage:FindFirstChild(ROOT_NAME .. "_Day")
	if not dayStore then
		dayStore = Instance.new("Folder")
		dayStore.Name = ROOT_NAME .. "_Day"
		dayStore.Parent = ServerStorage
	end
	-- every group whose folder name starts with "Night_" belongs to the night layer; "day"-layer entries
	-- (the cart set) live in the "Cart" folder
	if layer == "night" then
		move(day, dayStore :: Instance, "Cart")
		if nightStore then
			for _, f in nightStore:GetChildren() do
				f.Parent = day
			end
		end
	else
		for _, f in day:GetChildren() do
			if string.sub(f.Name, 1, 6) == "Night_" and nightStore then
				f.Parent = nightStore
			end
		end
		move(dayStore, day, "Cart")
	end
	return "layer " .. layer
end

--[[ placements: { { asset, x, y, z, rotY, group, id, replaces = { paths } } }
	Returns a report string (placed / missing assets / missing blockout paths). ]]
function Place.run(placements: { any }, ids: { [string]: any }): string
	Place.restore()
	local oldDay = ServerStorage:FindFirstChild(ROOT_NAME .. "_Day")
	if oldDay then
		oldDay:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = ROOT_NAME
	-- layer "night" (Pad trailer) overlaps the day cart: kept in ServerStorage until Place.showLayer("night")
	local oldNight = ServerStorage:FindFirstChild(ROOT_NAME .. "_Night")
	if oldNight then
		oldNight:Destroy()
	end
	local nightRoot = Instance.new("Folder")
	nightRoot.Name = ROOT_NAME .. "_Night"
	nightRoot.Parent = ServerStorage
	local groups: { [string]: Folder } = {}
	local placed, problems = 0, {}
	local blockout = blockoutRoot()
	for i, p in placements do
		local tpl, err = template(p.asset, ids)
		if not tpl then
			table.insert(problems, err :: string)
			continue
		end
		local gkey = (p.layer == "night" and "Night_" or "") .. (p.group or "Misc")
		local g = groups[gkey]
		if not g then
			g = Instance.new("Folder")
			g.Name = (if p.layer == "night" then "Night_" else "") .. (p.group or "Misc")
			g.Parent = if p.layer == "night" then nightRoot else root
			groups[gkey] = g
		end
		local inst = tpl:Clone()
		inst.Name = if p.id then (p.id .. "_" .. p.asset) else p.asset
		-- multi-variant files: keep only the listed meshes
		if p.part then
			local keep = {}
			for _, n in p.part do
				keep[n] = true
			end
			for _, d in inst:GetDescendants() do
				if d:IsA("BasePart") and not keep[d.Name] then
					d:Destroy()
				end
			end
		end
		local cf = CFrame.new(p.x or 0, p.y or 0, p.z or 0) * CFrame.Angles(0, math.rad(p.rotY or 0), 0)
		if inst:IsA("Model") then
			inst:PivotTo(cf)
		elseif inst:IsA("BasePart") then
			inst.CFrame = cf
		end
		inst:SetAttribute("Asset", p.asset)
		if p.id then
			inst:SetAttribute("MapId", p.id)
		end
		inst.Parent = g
		placed += 1
		if blockout and p.replaces then
			for _, path in p.replaces do
				local target = findPath(blockout, path)
				if target then
					hide(target)
				else
					table.insert(problems, "blockout path not found: " .. path)
				end
			end
		end
		if i % 25 == 0 then
			task.wait()
		end
	end
	root.Parent = workspace
	local msg = string.format("placed %d / %d", placed, #placements)
	if #problems > 0 then
		msg ..= "\n" .. table.concat(problems, "\n")
	end
	return msg
end

return Place
