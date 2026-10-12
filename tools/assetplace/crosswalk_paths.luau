--!nocheck
--[[
	crosswalk_paths.luau: keeps the NPC paths on the crosswalk stripes the OWNER moved (2026-10-12). Studio snippet, Edit mode.
	NEVER moves a stripe: the stripes under workspace.MAP01_Blockout.Crosswalks are the reference; it moves NpcNodes /
	TrafficBox / TrafficLine of workspace.MapBinding to them.

	Call (tools/studio/README.md, run_snippet):
		run("crosswalk_paths")           -- report only (DRY_RUN): stripes, nodes, errors, raycast verdicts
		run("crosswalk_paths", "apply")  -- applies the fixes below (idempotent: marks `CwPathsV1` on what it touched)
		run("crosswalk_paths", "undo")   -- restores nodes / links / box / lines from the `CwOrig*` attributes

	What it does (world coordinates; MAP-01 coordinates are world = (-x, y, 67.887287 - z)):
	  1. Reads every stripe cluster (stripes of the same line of a Crosswalks model) -> rect, crossing axis, lanes.
	  2. Pairs each cluster with the 2 NpcNodes carrying `Crosswalk = CW-n` (nearest pair). The curb nodes are put on the
	     centre line of the stripes (cross coordinate), keeping their along-the-road X and their floor Y.
	  3. Re-links the Juniper South corner (FIXES.links): N-Z08-04 <-> N-Z02-02 instead of N-Z08-03 (the crossing now sits
	     at the mouth of the Ninth, 14 studs north of where it was).
	  4. Moves TrafficBox CW-n (centre + length) to the stripes and the stop lines of that crossing (FIXES.lines).
	  5. Verifies by Spherecast along each crossing edge (lanes 0, +-0.9, +-2.5; heights 1.6 / 3.0 / 4.6) and by overlap at
	     every node; lists crosswalks without nodes, nodes without stripes, orphan stripes, nodes on asphalt outside a crosswalk.
]]

local CollectionService = game:GetService("CollectionService")
local MODE = (...) or "report"
local APPLY = MODE == "apply"
local UNDO = MODE == "undo"
local MARK = "CwPathsV1"
local Z0 = 67.887287 -- world z = Z0 - MAP z

local out = {}
local function say(...)
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	table.insert(out, table.concat(parts, " "))
end
local function f(n)
	return string.format("%.2f", n)
end

-- Fixes that are not derivable from the stripes ------------------------------------------------------------------------
local FIXES = {
	-- node -> { remove = { ids }, add = { ids } } (both directions are kept in sync)
	links = {
		["N-Z08-04"] = { remove = { "N-Z08-03" }, add = { "N-Z02-02" } },
	},
	-- crossing centre line vs the stripes centre (studs, along the road). CW-1: the corner sign pole of the Ninth
	-- (SW: x 12.2.., z 47.0..47.5, measured by raycast) touches the +2.5 lane of a line on z 43.89 (clearance 0.2 < radius 0.8),
	-- and check_map01 rule 6 (waypoint sphere r 1.2 vs the sign boxes, Z >= 43.75) flags a node there. 1.4 studs south the
	-- nodes pass rule 6 (>= 1.26 from the boxes), the centre line stays inside the stripes (Z 39.89..47.89) and the lanes
	-- (0.9 / 2.5) keep 1.9 from the pole; the -2.5 lane reaches the paint edge. Provisional.
	shift = { ["CW-1"] = -1.4 },
	-- stop lines of a crosswalk: distance (studs) from the stripe edge, side = "hi" (high world Z) or "lo"
	lines = {
		["CW-1"] = {
			["SL-1N"] = { side = "hi", gap = 2 }, -- SB: coming from the Ninth, stops before the stripes (still outside X-T by 2)
			["SL-1S"] = { side = "lo", gap = 4 }, -- NB: same 4 studs the old design had
		},
	},
}

-- 1. stripes -> clusters ------------------------------------------------------------------------------------------------
local folder = workspace.MAP01_Blockout.Crosswalks
local clusters = {}
for _, model in folder:GetChildren() do
	local groups = {}
	for _, s in model:GetChildren() do
		if s:IsA("BasePart") then
			local alongX = s.Size.X > s.Size.Z -- long in X: stacked in Z, crossing axis = Z
			local key = (alongX and "X" or "Z") .. (alongX and math.floor(s.Position.X / 8 + 0.5) or math.floor(s.Position.Z / 8 + 0.5))
			groups[key] = groups[key] or { stripes = {}, alongX = alongX }
			table.insert(groups[key].stripes, s)
		end
	end
	for _, g in groups do
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, s in g.stripes do
			x0 = math.min(x0, s.Position.X - s.Size.X / 2)
			x1 = math.max(x1, s.Position.X + s.Size.X / 2)
			z0 = math.min(z0, s.Position.Z - s.Size.Z / 2)
			z1 = math.max(z1, s.Position.Z + s.Size.Z / 2)
		end
		table.insert(clusters, {
			model = model.Name,
			n = #g.stripes,
			alongX = g.alongX, -- true: stripes long in X (a crossing along Z, over the Ninth)
			x0 = x0, x1 = x1, z0 = z0, z1 = z1,
			cx = (x0 + x1) / 2, cz = (z0 + z1) / 2,
			stripes = g.stripes,
		})
	end
end
table.sort(clusters, function(a, b)
	return a.model .. f(a.cz) .. f(a.cx) < b.model .. f(b.cz) .. f(b.cx)
end)

-- nodes ------------------------------------------------------------------------------------------------------------------
local nodesFolder = workspace.MapBinding.Nodes
local nodeById = {}
for _, n in nodesFolder:GetChildren() do
	if n:IsA("BasePart") then
		nodeById[n:GetAttribute("NodeId") or n.Name] = n
	end
end
-- door / spawn points are MapPoints, not NpcNodes of this folder: NpcNode ids used by the paths may be in Points too
local pointsFolder = workspace.MapBinding:FindFirstChild("Points")
local function nodePart(id)
	if nodeById[id] then
		return nodeById[id]
	end
	return pointsFolder and pointsFolder:FindFirstChild(id) or nil
end

local function linksOf(n)
	local raw = n:GetAttribute("Links")
	local list = {}
	if type(raw) == "string" and raw ~= "" then
		for id in raw:gmatch("[^,]+") do
			table.insert(list, id)
		end
	end
	return list
end
local function setLinks(n, list)
	n:SetAttribute("Links", table.concat(list, ","))
end
local function hasId(list, id)
	return table.find(list, id) ~= nil
end

-- curb pairs by crosswalk key
local pairs_ = {}
for id, n in nodeById do
	local cw = n:GetAttribute("Crosswalk")
	if cw then
		pairs_[cw] = pairs_[cw] or {}
		table.insert(pairs_[cw], n)
	end
end
for _, list in pairs_ do
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
end

-- match cluster <-> pair (nearest centre; one cluster per key)
local used = {}
local assigned = {}
local keys = {}
for k in pairs_ do
	table.insert(keys, k)
end
table.sort(keys)
-- greedy by distance: a pair only matches a cluster of its own axis within MATCH_MAX studs (the owner moved CW-1 by 14)
local MATCH_MAX = 20
local candidates = {}
for _, key in keys do
	local list = pairs_[key]
	if #list == 2 then
		local mid = (list[1].Position + list[2].Position) / 2
		local delta = list[2].Position - list[1].Position
		local crossAlongZ = math.abs(delta.Z) > math.abs(delta.X) -- Ninth crossings walk along Z (stripes along X)
		for _, c in clusters do
			if c.n >= 3 and c.alongX == crossAlongZ then
				local d = (Vector3.new(c.cx, 0, c.cz) - Vector3.new(mid.X, 0, mid.Z)).Magnitude
				if d <= MATCH_MAX then
					table.insert(candidates, { key = key, c = c, d = d })
				end
			end
		end
	end
end
table.sort(candidates, function(a, b)
	return a.d < b.d
end)
for _, cand in candidates do
	if assigned[cand.key] == nil and not used[cand.c] then
		assigned[cand.key] = cand.c
		used[cand.c] = true
	end
end

-- 2. report: crosswalks -------------------------------------------------------------------------------------------------
say(("== stripes (%d clusters) and curb pairs =="):format(#clusters))
for _, c in clusters do
	local key
	for k, v in assigned do
		if v == c then
			key = k
		end
	end
	say(("%-6s n=%2d %s  X %s..%s  Z %s..%s  centre (%s, %s)  w=%s l=%s  -> %s"):format(
		c.model, c.n, c.alongX and "stripes along X (crossing along Z)" or "stripes along Z (crossing along X)",
		f(c.x0), f(c.x1), f(c.z0), f(c.z1), f(c.cx), f(c.cz), f(c.x1 - c.x0), f(c.z1 - c.z0),
		key or (c.n < 3 and "ORPHAN stripe(s) (no cluster)" or "NO NpcNode PAIR (crosswalk without path)")
	))
end
for _, key in keys do
	if not assigned[key] then
		say("PATH WITHOUT STRIPES:", key, "has curb nodes but no stripe cluster")
	end
end

-- 3. plan -----------------------------------------------------------------------------------------------------------------
local plan = {}
for _, key in keys do
	local c = assigned[key]
	if c then
		for _, n in pairs_[key] do
			local p = n.Position
			local dev = if c.alongX then math.abs(p.X - c.cx) else math.abs(p.Z - (c.cz + (FIXES.shift[key] or 0)))
			table.insert(plan, { key = key, node = n, cluster = c, dev = dev })
		end
	end
end

-- Ninth crossings run along Z: lateral error = |x - centre| and must stay inside the stripe width (x0..x1);
-- Juniper crossings run along X: lateral error = |z - centre|, target z = centre (stripes are 8 long, lanes 2.5 + 1).
local TOL_MOVE = 0.05
say("== curb node vs centre line of the stripes ==")
for _, e in plan do
	local c = e.cluster
	local p = e.node.Position
	local inside = if c.alongX then (p.X >= c.x0 and p.X <= c.x1) else (p.Z >= c.z0 and p.Z <= c.z1)
	local mark = ""
	if not c.alongX and e.dev > TOL_MOVE then
		mark = "  -> MOVE to z " .. f(c.cz + (FIXES.shift[e.key] or 0))
	end
	say(("%s %-9s (%s, %s) lateral %s from the centre line (%s)%s%s"):format(
		e.key, e.node.Name, f(p.X), f(p.Z), f(e.dev), inside and "inside the stripes" or "OUTSIDE the stripes", mark,
		e.node:GetAttribute(MARK) and "  [done]" or ""
	))
end

-- backups / undo ---------------------------------------------------------------------------------------------------------
local function backup(inst, name, value)
	if inst:GetAttribute(name) == nil then
		inst:SetAttribute(name, value)
	end
end

local touched = {}
if APPLY then
	for _, e in plan do
		local c = e.cluster
		if not c.alongX and e.dev > TOL_MOVE then
			local n = e.node
			backup(n, "CwOrigPos", n.Position)
			backup(n, "CwOrigLinks", n:GetAttribute("Links") or "")
			local p = n.Position
			n.Position = Vector3.new(p.X, p.Y, c.cz + (FIXES.shift[e.key] or 0))
			n:SetAttribute(MARK, true)
			table.insert(touched, n.Name)
		end
	end
	for id, change in FIXES.links do
		local n = nodeById[id]
		if n and (assigned["CW-1"] ~= nil) then
			backup(n, "CwOrigLinks", n:GetAttribute("Links") or "")
			local list = linksOf(n)
			for _, r in change.remove do
				local i = table.find(list, r)
				if i then
					table.remove(list, i)
					local other = nodeById[r]
					if other then
						backup(other, "CwOrigLinks", other:GetAttribute("Links") or "")
						local ol = linksOf(other)
						local j = table.find(ol, id)
						if j then
							table.remove(ol, j)
							setLinks(other, ol)
						end
						other:SetAttribute(MARK, true)
					end
				end
			end
			for _, a in change.add do
				if not hasId(list, a) then
					table.insert(list, a)
				end
				local other = nodeById[a]
				if other then
					backup(other, "CwOrigLinks", other:GetAttribute("Links") or "")
					local ol = linksOf(other)
					if not hasId(ol, id) then
						table.insert(ol, id)
						setLinks(other, ol)
					end
					other:SetAttribute(MARK, true)
				end
			end
			setLinks(n, list)
			n:SetAttribute(MARK, true)
		end
	end
	-- traffic boxes and lines
	local boxes = workspace.MapBinding.Traffic.Boxes
	local lines = workspace.MapBinding.Traffic.Lines
	for key, c in assigned do
		local box = boxes:FindFirstChild(key)
		if box and not c.alongX then
			backup(box, "CwOrigCFrame", box.CFrame)
			backup(box, "CwOrigSize", box.Size)
			box.Size = Vector3.new(box.Size.X, box.Size.Y, c.z1 - c.z0)
			box.CFrame = CFrame.new(box.Position.X, box.Position.Y, c.cz) * (box.CFrame - box.CFrame.Position)
			box:SetAttribute(MARK, true)
		end
		for lineId, rule in (FIXES.lines[key] or {}) do
			local ln = lines:FindFirstChild(lineId)
			if ln and not c.alongX then
				backup(ln, "CwOrigCFrame", ln.CFrame)
				local z = if rule.side == "hi" then c.z1 + rule.gap else c.z0 - rule.gap
				ln.CFrame = CFrame.new(ln.Position.X, ln.Position.Y, z) * (ln.CFrame - ln.CFrame.Position)
				ln:SetAttribute(MARK, true)
			end
		end
	end
	say("APPLIED, nodes moved:", table.concat(touched, ", "))
elseif UNDO then
	for _, inst in workspace.MapBinding:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute(MARK) then
			local pos = inst:GetAttribute("CwOrigPos")
			if pos then
				inst.Position = pos
			end
			local cf = inst:GetAttribute("CwOrigCFrame")
			if cf then
				inst.CFrame = cf
			end
			local sz = inst:GetAttribute("CwOrigSize")
			if sz then
				inst.Size = sz
			end
			local lk = inst:GetAttribute("CwOrigLinks")
			if lk ~= nil then
				inst:SetAttribute("Links", lk)
			end
			for _, a in { MARK, "CwOrigPos", "CwOrigCFrame", "CwOrigSize", "CwOrigLinks" } do
				inst:SetAttribute(a, nil)
			end
		end
	end
	say("UNDONE")
end

-- 4. verification (spherecast along each crossing edge) -----------------------------------------------------------------
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
local skip = { workspace.MapBinding, folder }
for _, d in workspace:GetChildren() do
	if d:IsA("Model") and game:GetService("Players"):GetPlayerFromCharacter(d) then
		table.insert(skip, d)
	end
end
params.FilterDescendantsInstances = skip
local RADIUS, HEIGHTS, LANES = 0.8, { 1.6, 3.0, 4.6 }, { 0, 0.9, -0.9, 2.5, -2.5 }

local function blockers(a, b, label)
	local dir = b - a
	local len = dir.Magnitude
	local unit = dir / len
	local side = Vector3.new(-unit.Z, 0, unit.X)
	local hits = {}
	for _, lane in LANES do
		for _, h in HEIGHTS do
			local origin = Vector3.new(a.X, h, a.Z) + side * lane
			local r = workspace:Spherecast(origin, RADIUS, unit * len, params)
			if r then
				local name = r.Instance:GetFullName():gsub("^Workspace%.", "")
				hits[name] = hits[name] or ("lane " .. lane .. " h " .. h .. " at " .. f(r.Position.X) .. "," .. f(r.Position.Z))
			end
		end
	end
	local any = false
	for name, where in hits do
		any = true
		say("   BLOCKED", label, name, where)
	end
	if not any then
		say("   clear", label)
	end
	return not any
end

local function overlapAt(pos)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = skip
	op.RespectCanCollide = true
	local found = {}
	for _, h in HEIGHTS do
		for _, part in workspace:GetPartBoundsInRadius(Vector3.new(pos.X, h, pos.Z), 1.0, op) do
			found[part:GetFullName():gsub("^Workspace%.", "")] = true
		end
	end
	local list = {}
	for k in found do
		table.insert(list, k)
	end
	return list
end

say("== verification (Spherecast r " .. RADIUS .. ", lanes, heights) ==")
for _, key in keys do
	local c = assigned[key]
	local list = pairs_[key]
	if not c and #list == 2 then
		say(key .. ": NO STRIPES under the curb pair " .. list[1].Name .. " -> " .. list[2].Name .. " (edge walked without paint)")
		blockers(list[1].Position, list[2].Position, key .. " edge")
	end
	if c and #list == 2 then
		local a, b = list[1].Position, list[2].Position
		local dev = 0
		for t = 0, 1, 0.1 do
			local p = a:Lerp(b, t)
			-- lateral distance of the walked line from the stripe centre line
			local d = if c.alongX then math.abs(p.X - c.cx) else math.abs(p.Z - c.cz)
			dev = math.max(dev, d)
		end
		local lateralHalf = if c.alongX then (c.x1 - c.x0) / 2 else (c.z1 - c.z0) / 2
		say(("%s: %s -> %s  length %s  max drift from the centre line %s (stripes half-width %s, lanes use up to 2.5)"):format(
			key, list[1].Name, list[2].Name, f((b - a).Magnitude), f(dev), f(lateralHalf)
		))
		blockers(a, b, key .. " edge")
		for _, n in list do
			local over = overlapAt(n.Position)
			if #over > 0 then
				say("   NODE " .. n.Name .. " overlaps: " .. table.concat(over, "; "))
			end
		end
	end
end

-- 5. nodes on asphalt outside any crosswalk -----------------------------------------------------------------------------
local ROADS = {
	{ "Ninth", -200, 200, 51.887, 83.887 },
	{ "Juniper South", -12, 12, -52, 51.887 },
	{ "Juniper North", -12, 12, 83.887, 190 },
}
say("== nodes on asphalt outside a stripe rect ==")
local anyRoad = false
for id, n in nodeById do
	local p = n.Position
	for _, r in ROADS do
		if p.X > r[2] and p.X < r[3] and p.Z > r[4] and p.Z < r[5] then
			local inStripe = false
			for _, c in clusters do
				if p.X >= c.x0 - 0.5 and p.X <= c.x1 + 0.5 and p.Z >= c.z0 - 0.5 and p.Z <= c.z1 + 0.5 then
					inStripe = true
				end
			end
			if not inStripe then
				anyRoad = true
				say("   ", id, f(p.X), f(p.Z), "on", r[1])
			end
		end
	end
end
if not anyRoad then
	say("   none")
end

-- floor of the curb nodes against their neighbours (ramp) ----------------------------------------------------------------
say("== floor Y of crossing curbs vs neighbours ==")
for _, key in keys do
	for _, n in pairs_[key] do
		for _, id in linksOf(n) do
			local o = nodePart(id)
			if o and o:GetAttribute("Crosswalk") ~= key then
				local dy = math.abs(o.Position.Y - n.Position.Y)
				if dy > 0.2 then
					say(("   %s (y %s) -> %s (y %s): step %s"):format(n.Name, f(n.Position.Y), id, f(o.Position.Y), f(dy)))
				end
			end
		end
	end
end

-- node ground: raycast down, how far each crossing curb floats / sinks --------------------------------------------------
say("== ground under curb nodes ==")
for _, key in keys do
	for _, n in pairs_[key] do
		local p = n.Position
		local r = workspace:Raycast(Vector3.new(p.X, p.Y + 3, p.Z), Vector3.new(0, -8, 0), params)
		say(("   %s node y %s ground %s (%s)"):format(n.Name, f(p.Y), r and f(r.Position.Y) or "none", r and r.Instance.Name or "-"))
	end
end

return table.concat(out, "\n")
