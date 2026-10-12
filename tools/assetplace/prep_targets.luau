--!nonstrict
--[[
	prep_targets.luau (TASK-200, 3D-6; docs/tech/prep-3d.md §2.2, §4.1, §4.3, §15; MAP-01 §19.2; Provisional). Edit-mode Studio
	snippet, NOT gameplay code. Idempotent, NO Place.run, nothing is deleted (what leaves goes to ServerStorage.PrepTargets_Backup_20261012).
	Run (tools/studio/README.md, run_snippet):
	  run("prep_targets", "dry")    plan + checks only, writes nothing
	  run("prep_targets")           apply (hitboxes + view anchors), then the same checks on the live result
	  run("prep_targets", "undo")   hitboxes and new anchors go to the backup, CamAnchor / Focus back to their saved CFrame

	What it makes (all derived from the LIVE objects of the trailer, never from a coordinate; the owner's layout is not moved):
	  * HITBOXES: invisible Parts (Transparency 1, CanCollide false, CanQuery true, CanTouch false, Anchored), tag PrepTarget, named
	    PT_<Kind>_<n>, all in the Model trailer.PrepTargets (NOT inside the objects: MapIndex and KitchenController count every
	    `Slot` attribute under a Station model, a hitbox there would be a second slot anchor; attribute Object = MapId of the real
	    object, the Hatch has none). Attributes read by the
	    client (Content.Prep.Rules.World.Attr): TargetKind, Slot (GrillSlot / Rail / Board, else 0), Key (Topping = Ingredients key);
	    Id (documentation only: GrillSlot:3, Topping:ketchup, Bin) and PrepTargetsV1.
	      GrillSlot 1..4   Att_Slot1..4 of the roller grill (0.86 x 0.5 x 1.9; the 4 slots of Upgrades.grill, only 2 are live at L1)
	      SausageStock     the cooler TRL-S (the half that faces the grill)
	      Rail             the rest rail TRL-R, ONE hitbox over the 8 slots (Slot = 1, the front one: 8 slivers of 0.34 stud cannot be 44 px)
	      BunCrate         TRL-B
	      Board 1..4       Att_Bun1..4 of the cutting board TRL-T (0.76 wide = the 0.8 spacing, no overlap)
	      Knife            the knife of the board
	      Topping x6       the 6 bins of TRL-K (ketchup mustard cheese bacon potato_sticks cream_cheese): the real "bowls" are bins
	                       with lids in a 3 x 2 grid on ONE side of the bun (not bowls on both sides: see the report)
	      Bin              the trash can TRL-BIN (floor, behind the cook: out of every bench view, attribute ViewGap)
	      Hatch            the service sill in front of the counter edge at the Q1 line (no object there: hitbox + mark only)
	  * VIEWS (Content.Prep.Views): per Station_n the Attachments CamAnchor_<View> / Focus_<View> / Att_Stand_<View> for Board,
	    Toppings and Window; CamAnchor / Focus (Grill) are re-aimed (their old CFrame is kept in PTOrigCF for the undo; stations_prep
	    rewrites them: run this snippet AFTER it). Every CamAnchor has Fov and View attributes. The distance is the smallest that fits
	    every target of the view in a 667x375 frame with a 5% margin (printed); the focus is the middle of those targets.
	  * Prompt_Work (grill, board), Att_Bun, Att_Stand, CamAnchor_Build / Focus_Build are untouched.
	Checks (printed, same numbers as check_map01 rule 18): min size, overlap <= 25% of the smaller box, per view: every target
	on screen, >= 44 px in both axes in 667x375 and 844x390, and visible by raycast from the camera (>= 3 of 5 points).
]]

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local MODE = (...) or "apply"
local DRY = MODE == "dry"
local UNDO = MODE == "undo"
local BACKUP = "PrepTargets_Backup_20261012"

-- Content.Prep.Rules.World (Provisional)
local TAG = "PrepTarget"
local MIN_STUDS, MIN_PX = 0.31, 44
local MAX_OVERLAP = 0.25
local RESOLUTIONS = { { 667, 375 }, { 844, 390 } }
local MARGIN = 0.05
local PITCH = 55
local STAGGER = 1.0 -- seats 1.0 apart around the view centre (stations_prep)

-- per view: Fov (vertical, deg), pitch, shift of the focus (L axes), targets that frame it (filled below)
local VIEWS = {
	{ Key = "Grill", Fov = 70, Pitch = PITCH, Anchor = "CamAnchor", Focus = "Focus", Stand = nil },
	{ Key = "Board", Fov = 62, Pitch = PITCH, Anchor = "CamAnchor_Board", Focus = "Focus_Board", Stand = "Att_Stand_Board" },
	{ Key = "Toppings", Fov = 62, Pitch = PITCH, Anchor = "CamAnchor_Toppings", Focus = "Focus_Toppings", Stand = "Att_Stand_Toppings" },
	{ Key = "Window", Fov = 62, Pitch = 40, Anchor = "CamAnchor_Window", Focus = "Focus_Window", Stand = "Att_Stand_Window" },
}
-- which views a Kind has to be seen in (the "stage targets" of prep-3d.md §2.2; Frame = it also decides the framing)
local KIND_VIEWS = {
	GrillSlot = { Grill = true },
	SausageStock = { Grill = true },
	Rail = { Grill = true, Board = true },
	BunCrate = { Board = true },
	Board = { Board = true, Toppings = true },
	Knife = { Board = true },
	Topping = { Toppings = true },
	Bin = { Board = true, Toppings = true },
	Hatch = { Window = true },
}
local NO_FRAME = { Bin = true } -- a target that cannot be framed does not drive the view (reported as a gap)

local out = {}
local function log(s)
	table.insert(out, s)
end
local function fv(v)
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

-- the trailer ---------------------------------------------------------------------------------------------------------
local trl
for _, d in workspace:GetDescendants() do
	if d:IsA("Model") and d:GetAttribute("MapId") == "TRL" then
		trl = d
		break
	end
end
if not trl then
	return "[err] trailer (MapId TRL) not found"
end
local L = trl:GetPivot() * CFrame.Angles(0, math.pi, 0) -- L axes = world axes of the default pose (the trailer looks +Z)
local function toL(v)
	return L:PointToObjectSpace(v)
end
local function fromL(v)
	return L:PointToWorldSpace(v)
end
local function child(mapId)
	for _, c in trl:GetChildren() do
		if c:GetAttribute("MapId") == mapId then
			return c
		end
	end
	return nil
end

local function backupFolder()
	local f = ServerStorage:FindFirstChild(BACKUP)
	if not f then
		f = Instance.new("Folder")
		f.Name = BACKUP
		f.Parent = ServerStorage
	end
	return f
end

-- UNDO ----------------------------------------------------------------------------------------------------------------
if UNDO then
	CHS:SetWaypoint("prep_targets: before undo")
	local n = 0
	for _, d in trl:GetDescendants() do
		if d:GetAttribute("PrepTargetsV1") and (d:IsA("BasePart") or d:IsA("Attachment")) and not d:GetAttribute("PTOrigCF") then
			CS:RemoveTag(d, TAG)
			d:SetAttribute("OrigPath", d:GetFullName())
			d:SetAttribute("StashedBy", "prep_targets: undo")
			d.Parent = backupFolder()
			n += 1
		end
	end
	local holder = trl:FindFirstChild("PrepTargets")
	if holder and #holder:GetChildren() == 0 then
		holder:SetAttribute("OrigPath", holder:GetFullName())
		holder.Parent = backupFolder()
	end
	local back = 0
	for _, d in trl:GetDescendants() do
		local cf = d:IsA("Attachment") and d:GetAttribute("PTOrigCF")
		if cf then
			d.WorldCFrame = cf
			d:SetAttribute("PTOrigCF", nil)
			d:SetAttribute("PrepTargetsV1", nil)
			d:SetAttribute("View", nil)
			d:SetAttribute("Fov", nil)
			back += 1
		end
	end
	CHS:SetWaypoint("prep_targets: after undo")
	return string.format("[undo] %d piece(s) -> ServerStorage.%s, %d anchor(s) back to the saved CFrame", n, BACKUP, back)
end

-- geometry helpers (L space) ------------------------------------------------------------------------------------------
local function corners(cf, size)
	local h = size / 2
	local t = {}
	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz = -1, 1, 2 do
				table.insert(t, cf:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)))
			end
		end
	end
	return t
end
-- AABB (L space) of the visible parts of an instance
local function boundsL(inst, accept)
	local mn, mx = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, p in list do
		if p:IsA("BasePart") and p.Transparency < 1 and (not accept or accept(p)) then
			for _, w in corners(p.CFrame, p.Size) do
				local v = toL(w)
				mn = Vector3.new(math.min(mn.X, v.X), math.min(mn.Y, v.Y), math.min(mn.Z, v.Z))
				mx = Vector3.new(math.max(mx.X, v.X), math.max(mx.Y, v.Y), math.max(mx.Z, v.Z))
			end
		end
	end
	return mn, mx
end
local function findAtt(inst, name)
	for _, d in inst:GetDescendants() do
		if d:IsA("Attachment") and d.Name == name then
			return d
		end
	end
	return nil
end

-- the plan: one entry per hitbox ---------------------------------------------------------------------------------------
local plan = {}
local FRAME_ONLY = {} -- boxes that only drive the framing of a view (Views = { <ViewKey> = true })
local problems = {}
local function target(kind, id, slot, key, owner, c, s, extra)
	local t = { Kind = kind, Id = id, Slot = slot, Key = key, Owner = owner, C = c, S = s }
	for k, v in extra or {} do
		t[k] = v
	end
	table.insert(plan, t)
	return t
end

local grill, cooler, rail, crate, boardM, grid, bin = child("TRL-G"), child("TRL-S"), child("TRL-R"), child("TRL-B"), child("TRL-T"), child("TRL-K"), child("TRL-BIN")
for nm, o in { ["TRL-G"] = grill, ["TRL-S"] = cooler, ["TRL-R"] = rail, ["TRL-B"] = crate, ["TRL-T"] = boardM, ["TRL-K"] = grid, ["TRL-BIN"] = bin } do
	if not o then
		table.insert(problems, "object " .. nm .. " not found in the trailer")
	end
end
if #problems > 0 then
	return "[err] " .. table.concat(problems, "; ")
end

-- GrillSlot 1..4
local slotX = {}
for i = 1, 4 do
	local a = findAtt(grill, "Att_Slot" .. i)
	if a then
		local p = toL(a.WorldPosition)
		slotX[i] = p.X
		target("GrillSlot", "GrillSlot:" .. i, i, "", grill, Vector3.new(p.X, p.Y + 0.25, p.Z), Vector3.new(0.86, 0.5, 1.9))
	else
		table.insert(problems, "Att_Slot" .. i .. " missing on the grill")
	end
end
-- SausageStock: the half of the cooler that faces the grill
do
	local mn, mx = boundsL(cooler)
	local gx = slotX[1] or (mn.X + mx.X) / 2
	local cx = (mn.X + mx.X) / 2
	local w = 1.4
	local x0, x1 = if gx < cx then mn.X else mx.X - w, if gx < cx then mn.X + w else mx.X
	target("SausageStock", "SausageStock", 0, "", cooler, Vector3.new((x0 + x1) / 2, (mn.Y + mx.Y) / 2, (mn.Z + mx.Z) / 2), Vector3.new(x1 - x0, mx.Y - mn.Y, mx.Z - mn.Z))
end
-- Rail: one box over the 8 slots (Slot 1 = the front one)
do
	local x0, x1, y, z = 1e9, -1e9, 0, 0
	local n = 0
	for i = 1, 8 do
		local a = findAtt(rail, "Slot" .. i)
		if a then
			local p = toL(a.WorldPosition)
			x0, x1, y, z = math.min(x0, p.X), math.max(x1, p.X), y + p.Y, z + p.Z
			n += 1
		end
	end
	if n == 0 then
		table.insert(problems, "rail Slot1..8 attachments missing")
	else
		target("Rail", "Rail:1", 1, "", rail, Vector3.new((x0 + x1) / 2, y / n + 0.09, z / n), Vector3.new(x1 - x0 + 0.5, 0.65, 2.3), { RailSlots = n })
	end
end
-- BunCrate
do
	local mn, mx = boundsL(crate)
	local y0, y1 = mn.Y + 0.2, mx.Y + 0.2
	target("BunCrate", "BunCrate", 0, "", crate, Vector3.new((mn.X + mx.X) / 2, (y0 + y1) / 2, (mn.Z + mx.Z) / 2), Vector3.new(mx.X - mn.X, y1 - y0, mx.Z - mn.Z))
end
-- Board 1..4 and Knife
for i = 1, 4 do
	local a = findAtt(boardM, "Att_Bun" .. i)
	if a then
		local p = toL(a.WorldPosition)
		target("Board", "Board:" .. i, i, "", boardM, Vector3.new(p.X, p.Y + 0.25, p.Z - 0.2), Vector3.new(0.76, 0.5, 0.9))
	else
		table.insert(problems, "Att_Bun" .. i .. " missing on the board")
	end
end
do
	local knife
	for _, d in boardM:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Knife" then
			knife = d
			break
		end
	end
	if knife then
		local mn, mx = boundsL(knife)
		target("Knife", "Knife", 0, "", boardM, Vector3.new((mn.X + mx.X) / 2, (mn.Y + mx.Y) / 2 + 0.05, (mn.Z + mx.Z) / 2), Vector3.new(mx.X - mn.X + 0.15, 0.5, math.max(mx.Z - mn.Z, 0.75)))
	else
		table.insert(problems, "Knife missing on the board")
	end
end
-- Topping x6 (the bins of the topping grid)
for _, row in {
	{ "Bin_Ketchup", "ketchup" },
	{ "Bin_Mustard", "mustard" },
	{ "Bin_Cheese", "cheese" },
	{ "Bin_Bacon", "bacon" },
	{ "Bin_PotatoSticks", "potato_sticks" },
	{ "Bin_CreamCheese", "cream_cheese" },
} do
	local b = grid:FindFirstChild(row[1])
	local lid = b and b:FindFirstChild("Lid_" .. string.sub(row[1], 5))
	if b and b:IsA("BasePart") then
		local p = toL(b.Position)
		local ly = lid and toL(lid.Position).Y or p.Y + 0.4
		target("Topping", "Topping:" .. row[2], 0, row[2], grid, Vector3.new(p.X, ly - 0.3, p.Z), Vector3.new(b.Size.X, 0.95, b.Size.Z + 0.06))
	else
		table.insert(problems, row[1] .. " missing in the topping grid")
	end
end
-- Bin (floor, behind the cook)
do
	local mn, mx = boundsL(bin)
	target("Bin", "Bin", 0, "", bin, Vector3.new((mn.X + mx.X) / 2, (mn.Y + mx.Y) / 2, (mn.Z + mx.Z) / 2), Vector3.new(mx.X - mn.X + 0.1, mx.Y - mn.Y + 0.1, mx.Z - mn.Z + 0.1), {
		ViewGap = "on the floor behind the cook: no bench view can see it; needs a bench bin (AST-120+)",
	})
end
-- Hatch: the sill in front of the counter edge, on the Q1 line
do
	local x
	local mb = workspace:FindFirstChild("MapBinding", true)
	local pts = mb and mb:FindFirstChild("Points")
	local q1 = pts and pts:FindFirstChild("Q1")
	if q1 then
		x = toL(q1:IsA("Attachment") and q1.WorldPosition or q1.Position).X
	end
	local cmn, cmx = boundsL(trl.Body.Counters)
	if not x then
		x = (cmn.X + cmx.X) / 2
		log("[warn] Q1 not found: the hatch uses the middle of the counter")
	end
	local topY = cmx.Y
	target("Hatch", "Hatch", 0, "", trl, Vector3.new(x, topY + 0.67, cmx.Z + 0.65), Vector3.new(3.0, 1.0, 1.3), { NoHardObject = true })
	-- frame only (no hitbox): the upper body of the customer in Q1 (Kind Customer is a rig, found at runtime) must be in the Window view
	if q1 then
		local qp = toL(q1:IsA("Attachment") and q1.WorldPosition or q1.Position)
		table.insert(FRAME_ONLY, { Views = { Window = true }, Id = "Customer@Q1", C = Vector3.new(qp.X, qp.Y + 4.0, qp.Z), S = Vector3.new(1.2, 2.5, 0.8) })
	end
end
if #problems > 0 then
	return "[err] " .. table.concat(problems, "; ")
end

-- views: framing -------------------------------------------------------------------------------------------------------
local stations = {}
for n = 1, 4 do
	local st = trl:FindFirstChild("Station_" .. n)
	local mount = st and st:FindFirstChild("Mount")
	if not mount then
		return "[err] Station_" .. n .. " / Mount missing (run stations_prep first)"
	end
	stations[n] = mount
end
local fwd = Vector3.new(0, 0, 1) -- toward the window, in L axes

local function corners8(t)
	local out8 = {}
	local h = t.S / 2
	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz = -1, 1, 2 do
				table.insert(out8, t.C + Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
			end
		end
	end
	return out8
end
-- camera-space projection: ndc x / y (-1..1) and depth
local function project(cam, fov, aspect, p)
	local rel = cam:PointToObjectSpace(p)
	local depth = -rel.Z
	if depth < 0.05 then
		return nil
	end
	local t = math.tan(math.rad(fov) / 2)
	return rel.X / (depth * t * aspect), rel.Y / (depth * t), depth
end
local function inView(v, kind)
	return KIND_VIEWS[kind] and KIND_VIEWS[kind][v.Key]
end

local function camFor(v, focus, D)
	local p = math.rad(v.Pitch)
	local pos = focus + Vector3.new(0, D * math.sin(p), 0) - fwd * (D * math.cos(p))
	return CFrame.lookAt(pos, focus)
end

for _, v in VIEWS do
	local mn, mx = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	local count = 0
	local framed = {}
	for _, t in plan do
		if inView(v, t.Kind) and not NO_FRAME[t.Kind] then
			table.insert(framed, t)
		end
	end
	for _, t in FRAME_ONLY do
		if t.Views[v.Key] then
			table.insert(framed, t)
		end
	end
	for _, t in framed do
		count += 1
		for _, c in corners8(t) do
			mn = Vector3.new(math.min(mn.X, c.X), math.min(mn.Y, c.Y), math.min(mn.Z, c.Z))
			mx = Vector3.new(math.max(mx.X, c.X), math.max(mx.Y, c.Y), math.max(mx.Z, c.Z))
		end
	end
	v.Focus3 = (mn + mx) / 2
	local aspect = RESOLUTIONS[1][1] / RESOLUTIONS[1][2]
	local D = 2.5
	while D < 14 do
		local cam = camFor(v, v.Focus3, D)
		local ok = true
		for _, t in framed do
			for _, c in corners8(t) do
				local x, y = project(cam, v.Fov, aspect, c)
				if not x or math.abs(x) > 1 - MARGIN or math.abs(y) > 1 - MARGIN then
					ok = false
					break
				end
			end
			if not ok then
				break
			end
		end
		if ok then
			break
		end
		D += 0.1
	end
	v.D = D
	v.Cam = camFor(v, v.Focus3, D)
	log(string.format("[view] %s: %d targets frame it, focus %s, distance %.1f, fov %d, pitch %d, camera %s", v.Key, count, fv(v.Focus3), D, v.Fov, v.Pitch, fv(v.Cam.Position)))
end

-- checks ---------------------------------------------------------------------------------------------------------------
local existing = {}
for _, i in CS:GetTagged(TAG) do
	table.insert(existing, i)
end
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = existing
local bad = 0

-- min size + overlap
for _, t in plan do
	local d = { t.S.X, t.S.Y, t.S.Z }
	table.sort(d, function(a, b)
		return a > b
	end)
	if d[2] < MIN_STUDS then
		bad += 1
		log(string.format("[WARN] %s too small: %s (second dimension < %.2f)", t.Id, fv(t.S), MIN_STUDS))
	end
end
for i = 1, #plan do
	for j = i + 1, #plan do
		local a, b = plan[i], plan[j]
		local ox = math.min(a.C.X + a.S.X / 2, b.C.X + b.S.X / 2) - math.max(a.C.X - a.S.X / 2, b.C.X - b.S.X / 2)
		local oy = math.min(a.C.Y + a.S.Y / 2, b.C.Y + b.S.Y / 2) - math.max(a.C.Y - a.S.Y / 2, b.C.Y - b.S.Y / 2)
		local oz = math.min(a.C.Z + a.S.Z / 2, b.C.Z + b.S.Z / 2) - math.max(a.C.Z - a.S.Z / 2, b.C.Z - b.S.Z / 2)
		if ox > 0 and oy > 0 and oz > 0 then
			local va, vb = a.S.X * a.S.Y * a.S.Z, b.S.X * b.S.Y * b.S.Z
			local ratio = ox * oy * oz / math.min(va, vb)
			if ratio > MAX_OVERLAP then
				bad += 1
				log(string.format("[WARN] overlap %.0f%% of the smaller: %s x %s", ratio * 100, a.Id, b.Id))
			end
		end
	end
end

-- per view: on screen, px, raycast
local function camSamples(t)
	local top = t.C.Y + t.S.Y / 2 - 0.02
	local ix, iz = t.S.X * 0.3, t.S.Z * 0.3
	return {
		Vector3.new(t.C.X, top, t.C.Z),
		Vector3.new(t.C.X - ix, top, t.C.Z - iz),
		Vector3.new(t.C.X + ix, top, t.C.Z - iz),
		Vector3.new(t.C.X - ix, top, t.C.Z + iz),
		Vector3.new(t.C.X + ix, top, t.C.Z + iz),
	}
end
local function isOwner(hit, t)
	if t.Owner == trl then
		return false
	end
	return hit:IsDescendantOf(t.Owner)
end
for _, v in VIEWS do
	local camW = v.Cam.Position
	local lines = {}
	local gaps = {}
	for _, t in plan do
		if not inView(v, t.Kind) then
			continue
		end
		-- raycast (in world space)
		local seen = 0
		local blockedBy
		for _, s in camSamples(t) do
			local pw = fromL(s)
			local origin = fromL(v.Cam.Position)
			local hit = workspace:Raycast(origin, pw - origin, rp)
			if not hit or (hit.Position - pw).Magnitude < 0.15 or isOwner(hit.Instance, t) then
				seen += 1
			else
				blockedBy = blockedBy or hit.Instance.Name
			end
		end
		-- px
		local worst = math.huge
		local onScreen = true
		local camCF = CFrame.lookAt(v.Cam.Position, v.Focus3)
		local pxs = {}
		for _, r in RESOLUTIONS do
			local W, H = r[1], r[2]
			local x0, x1, y0, y1 = 1e9, -1e9, 1e9, -1e9
			local behind = false
			for _, c in corners8(t) do
				local nx, ny = project(camCF, v.Fov, W / H, c)
				if not nx then
					behind = true
					break
				end
				local px, py = (nx * 0.5 + 0.5) * W, (0.5 - ny * 0.5) * H
				x0, x1, y0, y1 = math.min(x0, px), math.max(x1, px), math.min(y0, py), math.max(y1, py)
			end
			if behind then
				onScreen = false
				table.insert(pxs, "behind the camera")
				worst = 0
			else
				local w, h = x1 - x0, y1 - y0
				if x0 < 0 or y0 < 0 or x1 > W or y1 > H then
					onScreen = false
				end
				worst = math.min(worst, w, h)
				table.insert(pxs, string.format("%dx%d:%dx%d", W, H, w + 0.5, h + 0.5))
			end
		end
		local okPx = worst >= MIN_PX
		local okSeen = seen >= 3
		local gap = t.ViewGap ~= nil
		local flag = (okPx and okSeen and onScreen) and "ok" or (gap and "GAP" or "WARN")
		if flag == "WARN" then
			bad += 1
		end
		table.insert(lines, string.format("  [%s] %s  %s  ray %d/5%s%s", flag, t.Id, table.concat(pxs, " "), seen, blockedBy and (" blocked by " .. blockedBy) or "", onScreen and "" or " OFF-SCREEN"))
	end
	log(string.format("[%s view] camera %s -> %s (Fov %d)", v.Key, fv(fromL(v.Cam.Position)), fv(fromL(v.Focus3)), v.Fov))
	for _, l in lines do
		log(l)
	end
end
-- the customer in Q1 must be in the Window frame (info)
do
	local mb = workspace:FindFirstChild("MapBinding", true)
	local q1 = mb and mb:FindFirstChild("Points") and mb.Points:FindFirstChild("Q1")
	if q1 then
		local p = toL(q1:IsA("Attachment") and q1.WorldPosition or q1.Position) + Vector3.new(0, 4.6, 0)
		for _, v in VIEWS do
			if v.Key == "Window" then
				local nx, ny = project(CFrame.lookAt(v.Cam.Position, v.Focus3), v.Fov, 667 / 375, p)
				log(string.format("[info] Q1 customer head (%s) in the Window frame: %s", fv(p), (nx and math.abs(nx) <= 1 and math.abs(ny) <= 1) and "yes" or "NO (outside the frame)"))
			end
		end
	end
end

-- rig stand floor / blockers per view ------------------------------------------------------------------------------------
local standChecks = {}
-- the 4 stands are 1.0 apart around the view centre, the group pulled inside the floor: the body shell has a wheel-arch bulge
-- along the end walls (measured 2026-10-12: floor 0.48 up to 3.1 studs from the end, then the bulge), hence WALL_GAP
local WALL_GAP = 3.1
local floorMn, floorMx = boundsL(trl.Body.Floor)
local function standAt(n, v)
	local a = stations[n]:FindFirstChild("Att_Stand")
	local s0 = toL(a.WorldPosition)
	local half = 1.5 * STAGGER
	local cx = math.clamp(v.Focus3.X, floorMn.X + WALL_GAP + half, floorMx.X - WALL_GAP - half)
	return Vector3.new(cx + (2.5 - n) * STAGGER, s0.Y, s0.Z)
end
for _, v in VIEWS do
	if v.Stand then
		local blocked, nofloor = 0, 0
		for n = 1, 4 do
			local p = fromL(standAt(n, v))
			local prm = RaycastParams.new()
			prm.FilterType = Enum.RaycastFilterType.Exclude
			prm.FilterDescendantsInstances = { trl:FindFirstChild("Station_" .. n) }
			local down = workspace:Raycast(p + Vector3.new(0, 3, 0), Vector3.new(0, -6, 0), prm)
			if not (down and math.abs(down.Position.Y - p.Y) < 0.15) then
				nofloor += 1
			end
			for _, h in { 1.2, 2.6, 4.0 } do
				for k = 0, 7 do
					local ang = k * math.pi / 4
					local hit = workspace:Raycast(p + Vector3.new(0, h, 0), Vector3.new(math.cos(ang), 0, math.sin(ang)) * 1.0, prm)
					if hit and hit.Instance.CanCollide then
						blocked += 1
					end
				end
			end
		end
		if nofloor > 0 or blocked > 0 then
			bad += 1
		end
		log(string.format("[%s] %s stands of the 4 seats: no floor %d, collider hits %d", (nofloor == 0 and blocked == 0) and "ok" or "WARN", v.Stand, nofloor, blocked))
	end
end

log(string.format("plan: %d hitboxes, %d check problem(s)%s", #plan, bad, DRY and " (dry: nothing written)" or ""))
if DRY then
	return table.concat(out, "\n")
end

-- APPLY ------------------------------------------------------------------------------------------------------------------
CHS:SetWaypoint("prep_targets: before")
-- The hitboxes live in ONE Model beside the objects (trailer.PrepTargets), not inside TRL-G / TRL-R / TRL-T: the attribute `Slot`
-- of the PrepTarget contract is also what MapIndex (server boot validation) and KitchenController Slots count under a Station
-- model, and a hitbox there would count as a second slot anchor. Attribute `Object` = MapId of the real object.
local container = trl:FindFirstChild("PrepTargets")
if container and not container:IsA("Model") then
	container.Name = "PrepTargets_old"
	container.Parent = backupFolder()
	container = nil
end
if not container then
	container = Instance.new("Model")
	container.Name = "PrepTargets"
	container.Parent = trl
end
container:SetAttribute("PrepTargetsV1", true)
container.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
local made, kept = 0, 0
for _, t in plan do
	local name = "PT_" .. string.gsub(t.Id, ":", "_")
	local p = container:FindFirstChild(name)
	if not p then
		-- an earlier run (V1 of this snippet) parented it under the object: move it, never delete
		for _, d in t.Owner:GetChildren() do
			if d.Name == name and d:IsA("BasePart") then
				p = d
				p.Parent = container
				break
			end
		end
	end
	if p and not p:IsA("BasePart") then
		p.Name = name .. "_old"
		p:SetAttribute("OrigPath", p:GetFullName())
		p.Parent = backupFolder()
		p = nil
	end
	if not p then
		p = Instance.new("Part")
		p.Name = name
		p.Parent = container
		made += 1
	else
		kept += 1
	end
	p:SetAttribute("Object", if t.Owner ~= trl then t.Owner:GetAttribute("MapId") else nil)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, true, false, false, true
	p.Transparency = 1
	p.Size = t.S
	p.CFrame = CFrame.new(fromL(t.C)) * L.Rotation
	p:SetAttribute("TargetKind", t.Kind)
	p:SetAttribute("Slot", t.Slot)
	p:SetAttribute("Key", if t.Key ~= "" then t.Key else nil)
	p:SetAttribute("Id", t.Id)
	p:SetAttribute("RailSlots", t.RailSlots)
	p:SetAttribute("ViewGap", t.ViewGap)
	p:SetAttribute("PrepTargetsV1", true)
	CS:AddTag(p, TAG)
end
log(string.format("[apply] hitboxes: %d new, %d updated (tag %s)", made, kept, TAG))

for n = 1, 4 do
	local mount = stations[n]
	for _, v in VIEWS do
		local function att(name, cf, keepOrig)
			local a = mount:FindFirstChild(name)
			if not (a and a:IsA("Attachment")) then
				a = Instance.new("Attachment")
				a.Name = name
				a.Parent = mount
			elseif keepOrig and not a:GetAttribute("PTOrigCF") then
				a:SetAttribute("PTOrigCF", a.WorldCFrame)
			end
			a.WorldCFrame = cf
			a:SetAttribute("PrepTargetsV1", true)
			return a
		end
		local isGrill = v.Key == "Grill"
		local cam = att(v.Anchor, CFrame.lookAt(fromL(v.Cam.Position), fromL(v.Focus3)), isGrill)
		cam:SetAttribute("View", v.Key)
		cam:SetAttribute("Fov", v.Fov)
		att(v.Focus, CFrame.new(fromL(v.Focus3)), isGrill)
		if v.Stand then
			local sp = fromL(standAt(n, v))
			att(v.Stand, CFrame.lookAt(sp, sp + L:VectorToWorldSpace(fwd)), false)
		end
	end
end
log("[apply] anchors written for Station_1..4 (Grill re-aimed, Board / Toppings / Window new)")
CHS:SetWaypoint("prep_targets: after")
return table.concat(out, "\n")
