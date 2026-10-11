--[[
	MAP-01 asset placement (technical prototype, Phase 0 - same status as tools/blockout).

	Replaces blockout pieces with the imported assets listed in MAP-01_placements.luau.
	Idempotent: rebuilds workspace.MAP01_Assets every run. Blockout parts listed in `replaces` are hidden
	(Transparency 1, no collision/query) and remember their original values in attributes, so `restore()` brings
	the blockout back exactly. Nothing in the blockout is destroyed.

	Assets come from the group-owned Model assets uploaded from Assets/import (ids in Assets/import/_asset_ids.json).
	They are cached once in ServerStorage.__AssetCache (PackageLink removed) and cloned per placement.
	Asset convention: pivot = base centre, front = local -Z (LookVector), 1 unit = 1 stud.
	Map frame (2026-10-10): placement x/y/z/rotY (and pivot) are MAP-01 coordinates; the world pose is
	MAP_FRAME * placementCFrame (map_frame.luau: the place is turned 180 in Y around (0, 33.94)). parts / copies are
	relative to the entry, so they need no transform.

	Usage (edit mode, Command Bar or Studio MCP):
		local Place = require(<this module>)
		Place.run(placements, ids)   -- placements = require(MAP-01_placements), ids = { [name] = assetId }
		Place.restore()              -- show the blockout again and delete MAP01_Assets
		Place.diff(placements, ids)  -- READ-ONLY: what Place.run (+ bind_map01's trailer move) would put vs the Workspace
]]

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

-- MAP-01 frame (map_frame.luau, 2026-10-10): placements stay in MAP-01 coordinates; the place is turned 180 in Y,
-- so every placement pose is MAP_FRAME * placementCFrame (one transform, at the Workspace boundary).
local MAP_FRAME_URL = "http://127.0.0.1:8772/tools/assetplace/map_frame.luau"
local function loadMapFrame(): any
	local sib = script and script.Parent and script.Parent:FindFirstChild("map_frame")
	if sib and sib:IsA("ModuleScript") then
		return (require :: any)(sib)
	end
	local ms = Instance.new("ModuleScript")
	ms.Name = "map_frame"
	ms.Source = game:GetService("HttpService"):GetAsync(MAP_FRAME_URL, true)
	return (require :: any)(ms)
end
local MapFrame = loadMapFrame()
local MAP_FRAME: CFrame = MapFrame.FRAME

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

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- y-rotation frame in placement coordinates: { x, y, z, rotY } (rotY in degrees, optional) -> WORLD CFrame
-- (MAP_FRAME applied: placements are MAP-01 coordinates, the place is turned 180 in Y)
local function frameOf(x: number?, y: number?, z: number?, rotY: number?): CFrame
	return MAP_FRAME * CFrame.new(x or 0, y or 0, z or 0) * CFrame.Angles(0, math.rad(rotY or 0), 0)
end

-- Part pose in the asset frame: centre o = { x, y, z, rotY = extra yaw, rotX / rotZ = extra pitch / roll over the
-- template orientation }, in the asset frame, composed Y * X * Z (CFrame.fromEulerAnglesYXZ).
local function partPose(origin: CFrame, rel: CFrame, o: { [any]: any }): CFrame
	local extra = CFrame.fromEulerAnglesYXZ(math.rad(o.rotX or 0), math.rad(o.rotY or 0), math.rad(o.rotZ or 0))
	return origin * CFrame.new(o[1] or 0, o[2] or 0, o[3] or 0) * extra * rel.Rotation
end

local function findPart(inst: Instance, name: string): BasePart?
	if inst:IsA("BasePart") and inst.Name == name then
		return inst
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name then
			return d
		end
	end
	return nil
end

--[[ Builds one placement from its cached template (not parented). Optional hand-edit fields (2026-10-10,
	recorded from edits made in Studio; all coordinates in the placement frame / asset frame):
	  part   = { names }   keep only these BaseParts (multi-variant FBX)
	  drop   = { names }   destroy these BaseParts (meshes removed by hand)
	  parts  = { [name] = { x, y, z, rotY = deg?, rotX = deg?, rotZ = deg?, size = { sx, sy, sz }? } }
	           part centre in the ASSET frame (relative to x/y/z/rotY of the entry), extra rotation over the template
	           orientation (asset frame, Y * X * Z), new size (MeshPart scaled)
	  copies = { { part = name, x, y, z, rotY = deg?, size = {..}? } }   extra clones of a part, same pose rule
	  pivot  = { x, y, z, rotY }   Model.WorldPivot in the PLACEMENT frame (same coordinates as x/y/z), when the
	           pivot was moved off the asset origin by hand
	  collide = false      every BasePart CanCollide false (small props, facade details) ]]
local function build(p: { [string]: any }, tpl: Instance): Instance
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
	if p.drop then
		local gone = {}
		for _, n in p.drop do
			gone[n] = true
		end
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") and gone[d.Name] then
				d:Destroy()
			end
		end
	end
	local cf = frameOf(p.x, p.y, p.z, p.rotY)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	elseif inst:IsA("BasePart") then
		inst.CFrame = cf
	end
	-- copies first (they clone the part with its template pose and size)
	if p.copies then
		for _, c in p.copies do
			local src = findPart(inst, c.part)
			if src then
				local rel = cf:ToObjectSpace(src.CFrame)
				local cp = src:Clone()
				cp.CFrame = partPose(cf, rel, c)
				if c.size then
					cp.Size = v3(c.size)
				end
				cp.Parent = src.Parent
			end
		end
	end
	if p.parts then
		for name, o in p.parts do
			local bp = findPart(inst, name)
			if bp then
				local rel = cf:ToObjectSpace(bp.CFrame)
				if o.size then
					bp.Size = v3(o.size)
				end
				bp.CFrame = partPose(cf, rel, o)
			end
		end
	end
	if p.pivot and inst:IsA("Model") then
		inst.WorldPivot = frameOf(p.pivot[1], p.pivot[2], p.pivot[3], p.pivot[4])
	end
	-- collide = false (2026-10-10, ambience pass): small props next to walking lines / out of reach (AC units,
	-- clotheslines) do not block characters; CanQuery stays (raycasts and the line-of-sight checks still see them)
	if p.collide == false then
		for _, d in (if inst:IsA("BasePart") then { inst } else inst:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	end
	return inst
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
		local inst = build(p, tpl)
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

--[[ Place.diff(placements, ids, opts?) -> (report, nDiff)
	Read-only. Pairing is by stable key, never by list position: entry <-> live model with the same MapId|Asset
	(attributes set by Place.run; the live name is "<id>_<asset>"), closest pivots first over the whole key group
	(parts: same rule by name). Builds every placement in memory (same build() as Place.run, never parented) and compares it with what
	is in workspace.MAP01_Assets now: model pivot, every BasePart (name, CFrame, Size), parts missing / extra, and the
	template Attachments (counted apart: bind_map01 / bind_pieces move some anchors on purpose).
	Default frame rule = MAP-01 after bind_map01: the entries bind_map01 puts inside the trailer (id TRL, TRL-*, H1..H4)
	are compared after the trailer's move from its placement pose to its CURRENT pivot (TRL-SALE or the Pad); the
	TRL-SALE shell is skipped (bind_map01 destroys it). opts:
	  tolPos (0.05 stud), tolDeg (1), ids = { [MapId] = true } (only these), verbose (matching entries + attachments),
	  moved = function(p) -> CFrame | false | nil (custom frame rule; false = skip, nil = as placed).
	Ignored in the Workspace: UpgradePieces / VehicleCover subtrees, nested MapId models, parts with BindCreated,
	"Light_Lamp" (bind_map01 step 5); the "Fixed_" prefix of bind_pieces is stripped before matching. ]]
function Place.diff(placements: { any }, ids: { [string]: any }?, opts: { [string]: any }?): (string, number)
	local o = opts or {}
	local tolPos: number = o.tolPos or 0.05
	local tolDeg: number = o.tolDeg or 1
	local root = workspace:FindFirstChild(ROOT_NAME)
	if not root then
		return "no workspace." .. ROOT_NAME, 1
	end
	local function angle(a: CFrame, b: CFrame): number
		local _, t = a:ToObjectSpace(b):ToAxisAngle()
		return math.deg(math.abs(t))
	end
	local function fmt(v: Vector3): string
		return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
	end
	-- live instances by MapId|Asset
	local live: { [string]: { Instance } } = {}
	for _, d in root:GetDescendants() do
		local id, a = d:GetAttribute("MapId"), d:GetAttribute("Asset")
		if typeof(id) == "string" and typeof(a) == "string" and d:IsA("PVInstance") then
			local k = id .. "|" .. a
			live[k] = live[k] or {}
			table.insert(live[k], d)
		end
	end
	-- default rule: the trailer set follows the trailer
	local moved = o.moved
	if not moved then
		local trlEntry
		for _, p in placements do
			if p.id == "TRL" then
				trlEntry = p
			end
		end
		local liveTrl = live["TRL|AST-027_OpenLateTrailer"]
		local trlMove = CFrame.identity
		if trlEntry and liveTrl and liveTrl[1] then
			trlMove = (liveTrl[1] :: any):GetPivot() * frameOf(trlEntry.x, trlEntry.y, trlEntry.z, trlEntry.rotY):Inverse()
		end
		moved = function(p: { [string]: any }): any
			local id = p.id or ""
			if id == "TRL-SALE" then
				return false
			end
			if id == "TRL" or string.sub(id, 1, 4) == "TRL-" or string.match(id, "^H[1-4]$") then
				return trlMove
			end
			return nil
		end
	end
	local function ownParts(m: Instance): { BasePart }
		local list = {}
		local all: { Instance } = if m:IsA("BasePart") then { m } else {}
		for _, d in m:GetDescendants() do
			table.insert(all, d)
		end
		for _, d in all do
			if d:IsA("BasePart") and not d:GetAttribute("BindCreated") and d.Name ~= "Light_Lamp" then
				local skip = d ~= m and d:GetAttribute("MapId") ~= nil
				local q = d.Parent
				while not skip and q and q ~= m and q ~= root do
					if q.Name == "UpgradePieces" or q.Name == "VehicleCover" or q:GetAttribute("MapId") ~= nil then
						skip = true
					end
					q = q.Parent
				end
				if not skip then
					table.insert(list, d)
				end
			end
		end
		return list
	end
	local function bare(n: string): string
		return (string.gsub(n, "^Fixed_", ""))
	end
	-- Pass 1: build every expected model (never parented) and group the entries by their stable key MapId|Asset.
	type Entry = { i: number, p: { [string]: any }, key: string, move: CFrame?, exp: Instance?, err: string?, live: Instance?, dist: number }
	local entries: { Entry } = {}
	local byKey: { [string]: { Entry } } = {}
	for i, p in placements do
		if o.ids and not o.ids[p.id or ""] then
			continue
		end
		local move = moved(p)
		if move == false then
			continue
		end
		local key = (p.id or "") .. "|" .. p.asset
		local e: Entry = { i = i, p = p, key = key, move = move, dist = math.huge }
		local tpl, err = template(p.asset, ids or {})
		if not tpl then
			e.err = err
		else
			local exp = build(p, tpl)
			if move then
				if exp:IsA("Model") then
					-- a hand-set WorldPivot travels with the parts
					local piv = exp.WorldPivot
					exp:PivotTo(move * exp:GetPivot())
					exp.WorldPivot = move * piv
				elseif exp:IsA("BasePart") then
					exp.CFrame = move * exp.CFrame
				end
			end
			e.exp = exp
			byKey[key] = byKey[key] or {}
			table.insert(byKey[key], e)
		end
		table.insert(entries, e)
		if i % 25 == 0 then
			task.wait()
		end
	end
	-- Pass 2: pair entries and live models of the same key by GLOBAL nearest pivot (closest pairs first), so the
	-- result does not depend on the order of the placement list or of the Workspace children (a moved copy, a removed
	-- or renumbered entry never shifts the pairing of the others).
	local used: { [Instance]: boolean } = {}
	for key, list in byKey do
		local pairs_: { { e: Entry, a: Instance, d: number } } = {}
		for _, e in list do
			local ep = ((e.exp :: any):GetPivot() :: CFrame).Position
			for _, a in live[key] or {} do
				table.insert(pairs_, { e = e, a = a, d = ((a :: any):GetPivot().Position - ep).Magnitude })
			end
		end
		table.sort(pairs_, function(x, y)
			if x.d ~= y.d then
				return x.d < y.d
			end
			return x.e.i < y.e.i
		end)
		for _, pr in pairs_ do
			if not pr.e.live and not used[pr.a] then
				pr.e.live = pr.a
				pr.e.dist = pr.d
				used[pr.a] = true
			end
		end
	end
	local lines: { string } = {}
	local nDiff, nOk, nAtt = 0, 0, 0
	for n, e in entries do
		local i, key, move = e.i, e.key, e.move
		if not e.exp then
			table.insert(lines, string.format("#%d %s: %s", i, key, tostring(e.err)))
			nDiff += 1
			continue
		end
		local exp = e.exp :: Instance
		local expPivot = (exp :: any):GetPivot() :: CFrame
		local best, bd = e.live, e.dist
		local msgs: { string } = {}
		local real = 0
		if not best then
			table.insert(msgs, "MISSING in the Workspace")
			real += 1
		else
			local livePivot = (best :: any):GetPivot() :: CFrame
			if bd > tolPos or angle(expPivot, livePivot) > tolDeg then
				table.insert(msgs, string.format("pivot d=%.3f a=%.1f live %s", bd, angle(expPivot, livePivot), fmt(livePivot.Position)))
				real += 1
			end
			local liveParts = ownParts(best)
			local expParts = ownParts(exp)
			-- same global nearest rule for parts of the same name (duplicated meshes, copies)
			local pp: { { ep: BasePart, lp: BasePart, d: number } } = {}
			for _, ep in expParts do
				for _, lp in liveParts do
					if bare(lp.Name) == ep.Name then
						table.insert(pp, { ep = ep, lp = lp, d = (lp.Position - ep.Position).Magnitude })
					end
				end
			end
			table.sort(pp, function(x, y)
				return x.d < y.d
			end)
			local taken: { [Instance]: boolean } = {}
			local match: { [BasePart]: BasePart } = {}
			for _, pr in pp do
				if not match[pr.ep] and not taken[pr.lp] then
					match[pr.ep] = pr.lp
					taken[pr.lp] = true
				end
			end
			for _, ep in expParts do
				local cand = match[ep]
				if not cand then
					table.insert(msgs, "part missing live: " .. ep.Name)
					real += 1
					continue
				end
				local cd = (cand.Position - ep.Position).Magnitude
				local a = angle(ep.CFrame, cand.CFrame)
				local ds = (ep.Size - cand.Size).Magnitude
				if cd > tolPos or a > tolDeg or ds > tolPos then
					table.insert(msgs, string.format("part %s d=%.3f a=%.1f size %s live %s", ep.Name, cd, a, fmt(ep.Size), fmt(cand.Size)))
					real += 1
				end
				-- template attachments (informational: bind_map01 / bind_pieces move some)
				for _, at in ep:GetChildren() do
					if at:IsA("Attachment") then
						local la = cand:FindFirstChild(at.Name)
						local off = if la and la:IsA("Attachment") then (la.WorldPosition - at.WorldPosition).Magnitude else math.huge
						if off > tolPos then
							nAtt += 1
							if o.verbose then
								table.insert(msgs, string.format("(att %s/%s %s)", ep.Name, at.Name, if off == math.huge then "missing" else string.format("d=%.3f", off)))
							end
						end
					end
				end
			end
			for _, lp in liveParts do
				if not taken[lp] then
					table.insert(msgs, "part extra live: " .. lp:GetFullName())
					real += 1
				end
			end
		end
		exp:Destroy()
		local where = if best then " <-> " .. best:GetFullName() else ""
		if real > 0 then
			nDiff += 1
			table.insert(lines, string.format("#%d %s%s%s: %s", i, key, if move then " [moved]" else "", where, table.concat(msgs, " | ")))
		else
			nOk += 1
			if o.verbose then
				table.insert(lines, string.format("#%d %s ok%s %s", i, key, where, table.concat(msgs, " ")))
			end
		end
		if n % 25 == 0 then
			task.wait()
		end
	end
	if not o.ids then
		for k, list in live do
			for _, a in list do
				if not used[a] and string.sub(k, 1, 9) ~= "TRL-SALE|" then
					nDiff += 1
					table.insert(lines, "live model not in the placements: " .. a:GetFullName())
				end
			end
		end
	end
	table.insert(
		lines,
		1,
		string.format(
			"diff: %d differ, %d match (tol %.2f stud / %.0f deg); template attachments off or missing: %d (bind moves some on purpose)",
			nDiff,
			nOk,
			tolPos,
			tolDeg,
			nAtt
		)
	)
	return table.concat(lines, "\n"), nDiff
end

return Place
