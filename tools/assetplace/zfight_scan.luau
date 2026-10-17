--!nonstrict
--[[
	zfight_scan.luau (TASK-382, 2026-10-17). Read-only Edit snippet: finds coplanar overlapping faces (z-fighting) among the
	visible BaseParts under a root (default workspace.MAP01_Restaurant), plus parts of the map that touch it.
	run("assetplace/zfight_scan", rootName?, tol?) -> report. Faces compared: the 6 box faces of every part whose rotation is a
	multiple of 90 degrees (MeshParts use their bounding box: a hit there is a "maybe"; the plane must match within tol and the
	overlap area must be > 0.01 stud²). Only same-facing faces fight; opposite faces are hidden.
]]
local rootName, TOL = ...
TOL = TOL or 0.004
local root = workspace:FindFirstChild(rootName or "MAP01_Restaurant")
if not root then
	return "[err] no root"
end
local K = 67.887287
local function mapOf(v)
	return string.format("(%.2f, %.2f, %.2f)", -v.X, v.Y, K - v.Z)
end

local parts = {}
local function consider(p)
	if p:IsA("BasePart") and p.Transparency < 0.95 and not p:IsA("Terrain") then
		if p:IsA("Part") and p.Shape ~= Enum.PartType.Block then
			return
		end
		table.insert(parts, p)
	end
end
for _, d in root:GetDescendants() do
	consider(d)
end
-- neighbours: everything in the lot box that is not under the root (sidewalk, signs, tables...)
local lotMin, lotMax = Vector3.new(-80, -2, -16), Vector3.new(-20, 30, 40)
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Exclude
op.FilterDescendantsInstances = { root }
for _, p in workspace:GetPartBoundsInBox(CFrame.new((lotMin + lotMax) / 2), lotMax - lotMin, op) do
	if not p:IsDescendantOf(workspace.CurrentCamera) then
		consider(p)
	end
end

-- faces of an axis-aligned part: { n = axis index 1..3, s = +1/-1, d = plane coord, a0,a1,b0,b1 = rect on the other axes }
local function axisAligned(cf)
	for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
		local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
		if math.max(ax, ay, az) < 0.9999 then
			return false
		end
	end
	return true
end
local faces = {}
for _, p in parts do
	if axisAligned(p.CFrame) then
		-- world-aligned extents
		local cf, s = p.CFrame, p.Size
		local half = Vector3.new(
			math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
			math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
			math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
		) / 2
		local lo, hi = cf.Position - half, cf.Position + half
		local L = { lo.X, lo.Y, lo.Z }
		local H = { hi.X, hi.Y, hi.Z }
		for n = 1, 3 do
			local o1, o2 = (n % 3) + 1, ((n + 1) % 3) + 1
			for _, sgn in { -1, 1 } do
				table.insert(faces, {
					p = p,
					n = n,
					s = sgn,
					d = if sgn < 0 then L[n] else H[n],
					a0 = L[o1],
					a1 = H[o1],
					b0 = L[o2],
					b1 = H[o2],
					mesh = p:IsA("MeshPart"),
				})
			end
		end
	end
end
-- bucket by (n, s, rounded d)
local buckets = {}
for _, f in faces do
	local key = f.n .. ":" .. f.s .. ":" .. math.floor(f.d / 0.05 + 0.5)
	buckets[key] = buckets[key] or {}
	table.insert(buckets[key], f)
end
local hits, seen = {}, {}
for _, list in buckets do
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if a.p ~= b.p and math.abs(a.d - b.d) <= TOL then
				local w = math.min(a.a1, b.a1) - math.max(a.a0, b.a0)
				local h = math.min(a.b1, b.b1) - math.max(a.b0, b.b0)
				if w > 0.02 and h > 0.02 and w * h > 0.01 then
					local k = if a.p:GetFullName() < b.p:GetFullName() then a.p:GetFullName() .. "|" .. b.p:GetFullName() else b.p:GetFullName() .. "|" .. a.p:GetFullName()
					k ..= "|" .. a.n .. a.s
					if not seen[k] then
						seen[k] = true
						local axis = ({ "X", "Y", "Z" })[a.n]
						table.insert(hits, string.format("%s%s%s | %s | %s | %.2f stud2%s", if a.s > 0 then "+" else "-", axis, "", a.p:GetFullName():gsub("^Workspace%.", ""), b.p:GetFullName():gsub("^Workspace%.", ""), w * h, if a.mesh or b.mesh then " (mesh bbox)" else ""))
					end
				end
			end
		end
	end
end
table.sort(hits)
return string.format("parts %d, faces %d, coplanar overlaps %d\n", #parts, #faces, #hits) .. table.concat(hits, "\n")
