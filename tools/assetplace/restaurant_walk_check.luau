--!nonstrict
--[[
	restaurant_walk_check.luau (TASK-382, 2026-10-17). Read-only Edit snippet: sweeps an R6-sized box (2 wide x 4.6 tall x 1
	deep, feet 0.15 over the floor) along the walking routes of the expanded trailer and reports every collidable part in the
	way (RespectCanCollide). Routes in MAP-01 coordinates (+X east, +Z south). run("assetplace/restaurant_walk_check").
]]
local K = 67.887287
local FLOOR = 0.45
local function F(x, y, z)
	return Vector3.new(-x, y, K - z)
end
local ROUTES = {
	{ "spawn PS-1 -> west passage -> DOOR-P -> pantry -> DOOR-B -> outside", { { 33, 58.5 }, { 29.5, 58.5 }, { 29.5, 66.5 }, { 28.0, 70.5 }, { 28.0, 73.8 }, { 29.5, 76.0 }, { 29.5, 78.0 }, { 29.5, 81.4 }, { 20.0, 81.4 } } },
	{ "outside -> DOOR-B -> pantry -> DOOR-P -> kitchen", { { 20.0, 81.4 }, { 29.5, 81.4 }, { 29.5, 76.0 }, { 28.0, 73.8 }, { 28.0, 70.5 }, { 29.5, 66.5 } } },
	{ "front corridor (tablet / pickup / tip jar poses)", { { 27.8, 57.6 }, { 57.8, 57.6 } } },
	{ "east passage front -> back", { { 56.8, 57.6 }, { 56.8, 66.6 } } },
	{ "back corridor along the stations", { { 28.5, 66.6 }, { 57.8, 66.6 } } },
	{ "pantry aisle (DROP-R, shelves)", { { 29.5, 74.8 }, { 47.0, 74.8 } } },
	{ "patio: gate -> Q5 -> pickup lane", { { 36, 30 }, { 36, 48 }, { 46.5, 50.1 } } },
}
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = {}
rp.RespectCanCollide = true
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Exclude
op.RespectCanCollide = true
local SIZE = Vector3.new(2, 4.6, 1)
local Y = FLOOR + 0.15 + SIZE.Y / 2
local out = {}
local blocked = 0
for _, r in ROUTES do
	local name, pts = r[1], r[2]
	local hits = {}
	for i = 1, #pts - 1 do
		local a, b = F(pts[i][1], Y, pts[i][2]), F(pts[i + 1][1], Y, pts[i + 1][2])
		local dir = b - a
		local cf = CFrame.lookAt(a, b)
		for _, p in workspace:GetPartBoundsInBox(cf, SIZE, op) do
			hits[p:GetFullName()] = string.format("start of leg %d", i)
		end
		local res = workspace:Blockcast(cf, SIZE, dir, rp)
		if res then
			local m = res.Position
			hits[res.Instance:GetFullName()] = string.format("leg %d at MAP (%.1f, %.1f)", i, -m.X, K - m.Z)
		end
	end
	local n = 0
	for inst, where in hits do
		n += 1
		table.insert(out, "   BLOCK " .. inst:gsub("^Workspace%.", "") .. " (" .. where .. ")")
	end
	blocked += n
	table.insert(out, (if n == 0 then "OK   " else "FAIL ") .. name)
end
return string.format("R6 sweep: %d blocking hit(s)\n", blocked) .. table.concat(out, "\n")
