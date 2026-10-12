--!nocheck
--[[
	fix_trailer_height.luau - SURGICAL and IDEMPOTENT Studio patch (2026-10-11). NOT a Place.run: it touches only the
	trailer shells (AST-027), the trailer counter stations and the three AST-040 benches. Paste it in the Studio command bar
	/ execute_luau (Edit mode, not Play). Safe to run twice: every touched instance gets an attribute and is skipped.

	Why (first person, night): the counter (3.47 over the floor) + the window sill (5.5 over the pivot) hid the customers in
	the window and the toppings. New geometry (Assets/blender/vehicle/AST-027_OpenLateTrailer.blend, tools/blender/
	lower_trailer_counter.py):
	  Counters   top  pivot + 5.5  -> pivot + 4.6      (2.6 over the floor, floor stays at +2.0)
	  Body       skirt squashed, window sill 5.5 -> 4.6, head stays 10.0 (opening 0.9 taller; bbox unchanged)
	  Awning     (service shutter plate) bottom 5.45 -> 4.55; Shelf_Fold (outside fold shelf) -0.9
	Bench AST-040: the orange U handles that read as "feet sunk in the floor" (Z 0.25..0.38) now sit at the door top.

	What it does, in order (asserts first, nothing changes if a LoadAsset fails):
	  1  LoadAsset old + new AST-027 and AST-040 (ids below) to read MeshId / TextureID / Size and the part pose deltas
	  2  per AST-027 shell found in Workspace (and ServerStorage, where the layers park night folders): swap MeshId/TextureID
	     of Body, Counters, Awning, Shelf_Fold, set Size from the new mesh and move the part by the mesh-centre delta
	     (local frame, so a hand-nudged part keeps its nudge); re-bake WeldConstraints of the touched parts
	  3  every counter station (TRL-G, -R, -B, -T, -K, -DRAWER, -S, -COFFEE) PivotTo -0.9 (children, prompts, attachments,
	     UpgradePieces folders and Detail_* children go with the model); Detail_* parts that sit loose on the counter too
	  4  Shutter_Panel created by the bind (BindCreated, Size.Y 4.6) -> 5.4, hinge kept
	  5  the 3 benches: MeshId/TextureID swap (bbox identical: no pose change)
	DOES NOT MOVE (wall mounts, not on the counter): TRL-PHONE (shelf on the wall), TRL-SWITCH, TRL-SHUTTER button,
	TRL-LIGHTS (roof), TRL-BIN / benches (floor), Counter_L* upgrade piece (outside bar). Flip DROP[...] to change.
	AFTER: run bind_map01 + bind_pieces + check_map01 (constants already lowered to 4.6) and look at the printout.
	Undo: Ctrl+Z (waypoints "fix_trailer_height: before/after") or set the OLD_* ids back (the Blender source is in git).
]]

local InsertService = game:GetService("InsertService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local DROP_Y = 0.9
local OLD_TRAILER, NEW_TRAILER = 78288102155940, 81401517660968
local OLD_BENCH, NEW_BENCH = 75406033923116, 116016315058616
local DONE = "TrailerLoweredV1" -- attribute on every touched instance (idempotency)
local SHELL_ASSET = "AST-027_OpenLateTrailer"
local BENCH_ASSET = "AST-040_TrailerBench"
local SHELL_PARTS = { "Body", "Counters", "Awning", "Shelf_Fold" }

-- MapId -> true: lowered with the counter; false: stays (reason on top of the file)
local DROP = {
	["TRL-G"] = true, ["TRL-R"] = true, ["TRL-B"] = true, ["TRL-T"] = true, ["TRL-K"] = true,
	["TRL-DRAWER"] = true, ["TRL-S"] = true, ["TRL-COFFEE"] = true, ["TRL-K-SAUCE"] = true,
	["TRL-PHONE"] = false, ["TRL-SWITCH"] = false, ["TRL-SHUTTER"] = false, ["TRL-LIGHTS"] = false,
}

local report: { string } = {}
local function say(...)
	local s = string.format(...)
	table.insert(report, s)
	print(s)
end
local function fv(v: Vector3): string
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

-- ---------------------------------------------------------------- 1. load the reference meshes
local function load(id: number): Instance
	local ok, res = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	assert(ok and res, "LoadAsset " .. id .. " failed: " .. tostring(res) .. " (HttpEnabled / asset permission?)")
	return res
end

local function partNamed(root: Instance, name: string): BasePart
	for _, d in root:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == name then
			return d
		end
	end
	error(("part %s missing in loaded asset %s"):format(name, root.Name))
end

local oldT, newT = load(OLD_TRAILER), load(NEW_TRAILER)
local oldB, newB = load(OLD_BENCH), load(NEW_BENCH)

type Ref = { oldPart: MeshPart, newPart: MeshPart, delta: CFrame }
local refs: { [string]: Ref } = {}
local oldBody, newBody = partNamed(oldT, "Body") :: MeshPart, partNamed(newT, "Body") :: MeshPart
for _, n in SHELL_PARTS do
	local o, w = partNamed(oldT, n) :: MeshPart, partNamed(newT, n) :: MeshPart
	-- pose of the part in the frame of Body (Body does not change), then the delta in the part's OWN old frame
	local relOld = oldBody.CFrame:ToObjectSpace(o.CFrame)
	local relNew = newBody.CFrame:ToObjectSpace(w.CFrame)
	refs[n] = { oldPart = o, newPart = w, delta = relOld:Inverse() * relNew }
	say("ref %-10s old size %s -> new size %s, centre delta (local) %s", n, fv(o.Size), fv(w.Size), fv(refs[n].delta.Position))
end
assert((newBody.Size - oldBody.Size).Magnitude < 0.05 and refs.Body.delta.Position.Magnitude < 0.02,
	"Body bbox changed: the pose logic assumes it does not")
local benchOld, benchNew = partNamed(oldB, "AST-040_TrailerBench") :: MeshPart, partNamed(newB, "AST-040_TrailerBench") :: MeshPart
assert((benchNew.Size - benchOld.Size).Magnitude < 0.05, "bench bbox changed")

-- ---------------------------------------------------------------- helpers
local function nestedInOtherMapId(inst: Instance, root: Instance): boolean
	local q = inst.Parent
	while q and q ~= root do
		if q:GetAttribute("MapId") ~= nil then
			return true
		end
		q = q.Parent
	end
	return false
end

local function shellPart(shell: Instance, name: string): MeshPart?
	for _, d in shell:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == name and not nestedInOtherMapId(d, shell) then
			return d
		end
	end
	return nil
end

local roots: { Instance } = { workspace, ServerStorage }
local function findAll(pred: (Instance) -> boolean): { Instance }
	local out = {}
	for _, r in roots do
		for _, d in r:GetDescendants() do
			if pred(d) then
				table.insert(out, d)
			end
		end
	end
	return out
end

ChangeHistoryService:SetWaypoint("fix_trailer_height: before")

-- ---------------------------------------------------------------- 2. shells
local shells = findAll(function(d)
	return (d:IsA("Model") or d:IsA("BasePart"))
		and (d:GetAttribute("Asset") == SHELL_ASSET or string.find(d.Name, SHELL_ASSET, 1, true) ~= nil)
		and d:FindFirstChild("Body") ~= nil
end)
assert(#shells > 0, "no AST-027 shell found (expected workspace.MAP01_Assets.Night_Trailer.TRL_AST-027_OpenLateTrailer)")

local shellInfo: { { shell: Instance, y: number } } = {}
for _, shell in shells do
	if shell:GetAttribute(DONE) then
		say("shell %s: already lowered, skipped", shell:GetFullName())
		continue
	end
	local pivotY = (shell :: PVInstance):GetPivot().Position.Y
	local touched: { [Instance]: boolean } = {}
	local live: { [string]: MeshPart } = {}
	local ok = true
	for _, n in SHELL_PARTS do
		local p = shellPart(shell, n)
		if not p then
			if n == "Awning" or n == "Shelf_Fold" then
				say("shell %s: no %s (optional), skipped", shell.Name, n)
				continue
			end
			ok = false
			say("ERROR shell %s: part %s missing, shell NOT changed", shell:GetFullName(), n)
			break
		end
		if (p.Size - refs[n].oldPart.Size).Magnitude > 0.1 then
			ok = false
			say("ERROR shell %s: %s size %s differs from the old asset %s (hand-edited?), shell NOT changed",
				shell:GetFullName(), n, fv(p.Size), fv(refs[n].oldPart.Size))
			break
		end
		live[n] = p
	end
	if not ok then
		continue
	end
	for n, p in live do
		local r = refs[n]
		if p.MeshId ~= r.oldPart.MeshId then
			say("note %s/%s: MeshId was %s (the old asset has %s) - replaced anyway", shell.Name, n, p.MeshId, r.oldPart.MeshId)
		end
		local cf = p.CFrame * r.delta
		p.MeshId = r.newPart.MeshId
		p.TextureID = r.newPart.TextureID
		p.Size = r.newPart.Size
		p.CFrame = cf
		if r.newPart:FindFirstChildOfClass("SurfaceAppearance") then
			say("warn %s/%s: the new asset has a SurfaceAppearance (not copied)", shell.Name, n)
		end
		touched[p] = true
		say("shell %s: %s -> new mesh, size %s, centre %s", shell.Name, n, fv(p.Size), fv(p.Position))
	end
	for _, d in shell:GetDescendants() do -- WeldConstraint offsets are baked: re-bake after moving a part
		if d:IsA("WeldConstraint") and (touched[d.Part0 :: any] or touched[d.Part1 :: any]) then
			d.Enabled = false
			d.Enabled = true
		elseif (d:IsA("Weld") or d:IsA("ManualWeld")) and (touched[d.Part0 :: any] or touched[d.Part1 :: any]) then
			say("warn %s: classic %s %s references a moved part (check its C0/C1)", shell.Name, d.ClassName, d:GetFullName())
		end
	end
	local c = live.Counters
	local top = c.Position.Y + c.Size.Y / 2
	assert(math.abs(top - (pivotY + 4.6)) < 0.08, ("Counters top %.3f, expected %.3f"):format(top, pivotY + 4.6))
	shell:SetAttribute(DONE, true)
	table.insert(shellInfo, { shell = shell, y = pivotY })
	say("shell %s: Counters top y %.3f = pivot %.3f + 4.6 OK", shell:GetFullName(), top, pivotY)
end

-- ---------------------------------------------------------------- 3. stations and loose details
local movedRoots: { [Instance]: boolean } = {}
local function underMoved(i: Instance): boolean
	local q: Instance? = i
	while q do
		if movedRoots[q] then
			return true
		end
		q = q.Parent
	end
	return false
end

local stations = findAll(function(d)
	local id = d:GetAttribute("MapId")
	return type(id) == "string" and DROP[id] == true and (d:IsA("Model") or d:IsA("BasePart"))
end)
local movedN = 0
for _, st in stations do
	if st:GetAttribute(DONE) then
		say("station %s: already lowered", st.Name)
	elseif not underMoved(st) then
		local pv = st :: PVInstance
		local before = pv:GetPivot()
		pv:PivotTo(before - Vector3.new(0, DROP_Y, 0))
		st:SetAttribute(DONE, true)
		movedRoots[st] = true
		movedN += 1
		say("station %s (%s): pivot y %.3f -> %.3f", st.Name, tostring(st:GetAttribute("MapId")), before.Y, before.Y - DROP_Y)
	end
end
say("%d station(s) lowered by %.2f", movedN, DROP_Y)

-- Detail_* loose on the counter (inside a shell footprint, base on/above the old counter top, below the roof)
for _, info in shellInfo do
	local shell = info.shell :: PVInstance
	local cf, size = shell:GetBoundingBox()
	local oldTop = info.y + 5.5
	for _, d in shell:GetDescendants() do
		if string.sub(d.Name, 1, 7) == "Detail_" and (d:IsA("BasePart") or d:IsA("Model")) and not d:GetAttribute(DONE) and not underMoved(d) then
			local pv = d :: PVInstance
			local dcf, dsz = pv:GetBoundingBox()
			local base = dcf.Position.Y - dsz.Y / 2
			local inside = (cf:PointToObjectSpace(dcf.Position)).Magnitude < size.Magnitude
			if inside and base >= oldTop - 0.2 and base <= oldTop + 3 then
				pv:PivotTo(pv:GetPivot() - Vector3.new(0, DROP_Y, 0))
				d:SetAttribute(DONE, true)
				movedRoots[d] = true
				say("loose %s lowered (base was %.2f over the old counter top)", d:GetFullName(), base - oldTop)
			end
		end
	end
	-- report only: tagged anchors / prompts outside any moved station that float at counter height
	for _, d in shell:GetDescendants() do
		if (d:IsA("Attachment") or d:IsA("BasePart")) and not underMoved(d) and not d:GetAttribute(DONE) then
			local n = d.Name
			if string.sub(n, 1, 7) == "Prompt_" or string.sub(n, 1, 4) == "Att_" or string.sub(n, 1, 5) == "Slot_" or string.sub(n, 1, 7) == "Anchor_" then
				local y = if d:IsA("Attachment") then d.WorldPosition.Y else (d :: BasePart).Position.Y
				if y > oldTop - 0.1 and y < oldTop + 4 and not nestedInOtherMapId(d, shell) then
					say("CHECK (not moved, stays with its owner): %s at y %.2f", d:GetFullName(), y)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- 4. Shutter_Panel (bind placeholder)
for _, info in shellInfo do
	for _, d in (info.shell :: Instance):GetDescendants() do
		if d.Name == "Shutter_Panel" and d:IsA("BasePart") and d:GetAttribute("BindCreated") and not d:GetAttribute(DONE)
			and math.abs(d.Size.Y - 4.6) < 0.05 then
			local hinge = d:FindFirstChild("Shutter_Hinge") :: Attachment?
			local hingeWorld = if hinge then hinge.WorldPosition else nil
			local hy = if hinge then hinge.Position.Y else d.Size.Y / 2
			local newY = 5.4
			local hy2 = (if hy >= 0 then 1 else -1) * newY / 2
			d.CFrame = d.CFrame * CFrame.new(0, hy - hy2, 0) -- the hinge edge keeps its world place
			d.Size = Vector3.new(d.Size.X, newY, d.Size.Z)
			if hinge then
				hinge.Position = Vector3.new(hinge.Position.X, hy2, hinge.Position.Z)
				assert((hinge.WorldPosition - hingeWorld).Magnitude < 0.01, "hinge moved")
			end
			d:SetAttribute(DONE, true)
			say("Shutter_Panel %s: Size.Y 4.6 -> 5.4, hinge fixed", d:GetFullName())
		end
	end
end

-- ---------------------------------------------------------------- 5. benches
local benches = findAll(function(d)
	return d:IsA("MeshPart") and (d.Name == BENCH_ASSET or d:GetAttribute("Asset") == BENCH_ASSET
		or (d.Parent and d.Parent:GetAttribute("Asset") == BENCH_ASSET) or d.MeshId == benchOld.MeshId)
end)
for _, b in benches do
	local mp = b :: MeshPart
	if mp:GetAttribute(DONE) then
		say("bench %s: already new", mp:GetFullName())
	elseif (mp.Size - benchOld.Size).Magnitude < 0.1 then
		mp.MeshId = benchNew.MeshId
		mp.TextureID = benchNew.TextureID
		mp:SetAttribute(DONE, true)
		say("bench %s: mesh swapped (handles up), base y %.3f", mp:GetFullName(), mp.Position.Y - mp.Size.Y / 2)
	else
		say("bench %s: size %s not the bench, skipped", mp:GetFullName(), fv(mp.Size))
	end
end

oldT:Destroy(); newT:Destroy(); oldB:Destroy(); newB:Destroy()
ChangeHistoryService:SetWaypoint("fix_trailer_height: after")
say("done: %d shell(s), %d station(s), %d bench part(s). Now run bind_map01 + bind_pieces + check_map01.", #shellInfo, movedN, #benches)
return table.concat(report, "\n")
