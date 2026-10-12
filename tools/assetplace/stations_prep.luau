--!nonstrict
--[[
	stations_prep.luau (TASK-172, P4 of docs/tech/prep-mode.md §6 "Mapa"; DEC-223; Provisional). Edit-mode Studio snippet, NOT
	gameplay code. Idempotent, NO Place.run, nothing is deleted (what leaves goes to ServerStorage.Trailer_Backup_20261012).
	Run: run("stations_prep", "dry") report only | run("stations_prep") apply (V2) | run("stations_prep", "undo") back to the V1
	layout (4 prompts, one per station; the two extra prompts come back from the backup) | run("stations_prep", "remove") the old
	undo: Stations and the 4th board slot go to the backup.

	V2 (DEC-224, Provisional, 2026-10-12; the owner hated four separate spots): the seats stay 4 and logical (co-op), but only two
	natural prompts exist: Prompt_Work of Station_1 on the GRILL (PromptStep = Grill) and Prompt_Work of Station_3 on the CUTTING
	BOARD (PromptStep = Build). Whoever uses either gets the next free seat (PrepService). The Prompt_Work of Station_2 and
	Station_4 are MOVED (never deleted) to ServerStorage.Trailer_Backup_20261012 (attribute StashedBy = "stations_prep: v2 extra
	prompt"). Every station keeps its Att_Stand / CamAnchor / Focus for the GRILL view and gains Att_Stand_Build / CamAnchor_Build /
	Focus_Build for the BOARD view (the PrepController picks the view of the tab: Order and Grill look at the grill, Build and Serve
	at the board). The seats are staggered 1.0 stud apart around the view centre (seat 1 east) so the rigs do not stack.

	Builds Station_1..4 inside the trailer Model (so they follow the trailer: PivotTo, trailer_ground, TRL-SALE parking):
	  Model Station_n   tag Station, StationKind = "prep", Seat = n, MapId = TRL-PREP-n, Persistent, PrepStationsV1
	    Mount           invisible anchored Part at the stand (host of the Attachments; PrimaryPart)
	    Att_Stand       floor point where the rig stands, looking at the bench (+Z world, the window side)
	    CamAnchor       camera CFrame: 2.5 studs from Focus, pitch -55 (Content.Prep.Rules.Camera), looking at Focus
	    Focus           centre of the bench in front of the stand (DOF target)
	    Prompt_Work     Attachment, tag Interactable, PromptAction = prep_work (Content.Actions.prep_work), behind the rig
	    Att_Bun         the board slot n of the real board (TRL-T Att_Bun<n>), attribute Slot = n
	and sets BoardSlots = 4 on the board: Att_Bun1..4 respaced 0.8 apart around Att_Bun (was 3 at 1.1; the original X of each is
	kept in PrepOrigX so "undo" restores them; Att_Bun4 is created, undo moves it to the backup).

	Offsets are relative to the trailer pivot in WORLD axes at the default pose (look +Z), in studs:
	  station n at dx = 3.5 * (2.5 - n)  (n = 1 east ... 4 west, the order of the board slots: slot 1 is the east one)
	  Att_Stand  y +2.00 (interior floor 0.48 with the pivot at -1.52), dz +0.85 (world Z 12.55; the counter edge is Z 14.0)
	  Focus      y +5.12 (counter top 3.08 + a bit), dz +3.25 (Z 14.95, the middle of the counters)
	  CamAnchor  Focus + (0, 2.5 sin 55, -2.5 cos 55) = Focus + (0, 2.05, -1.43)
	  Prompt_Work y +4.52, dz -0.20 (Z 11.5): >= 2.5 from every prompt of another owner (checked on every run)
	bind_map01.luau (bindPrepStations) and check_map01.luau (rule 17) mirror these numbers in MAP-01 axes.
	Checks on every run (printed): floor under Att_Stand by raycast, no collider in the rig's box, CamAnchor -> Focus clear,
	Prompt_Work distances.
]]

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local MODE = (...) or "apply"
local DRY = MODE == "dry"
local REMOVE = MODE == "remove"
local V1 = MODE == "undo" -- the layout before DEC-224: station n owns its place and its prompt
local EXTRA_PROMPT_WHY = "stations_prep: v2 extra prompt"
local V2_EXTRA = { [2] = true, [4] = true } -- stations whose Prompt_Work leaves in V2

local SPACING = 3.5
local STAND = { y = 2.0, z = 0.85 }
local FOCUS = { y = 5.12, z = 3.25 }
local PITCH = math.rad(55)
local DIST = 2.5 -- Content.Prep.Rules.Camera.Distance
local PROMPT = { y = 5.82, z = 0.20 } -- V2: world Y 4.3 (eye height 5.5 minus a bit: a prompt at the hip, Y 2.2, fell out of the view; V1 was y 3.72)
local STAGGER = 1.0 -- V2: seats 1.0 apart around the view centre
local GRILL_N, BOARD_N = 1, 3 -- V2: the station whose old place is the grill / the cutting board (prompts live there)
local BUN_STEP = 0.8
local MIN_GAP = 2.5
local FLOOR_Y = 0.48 -- interior floor with the trailer on the ground (trailer_ground)
local BACKUP = "Trailer_Backup_20261012"

local out = {}
local function log(s)
	table.insert(out, s)
end
local function fv(v)
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

local assets = workspace:FindFirstChild("MAP01_Assets")
local trl
for _, d in (assets or workspace):GetDescendants() do
	if d:IsA("Model") and d:GetAttribute("MapId") == "TRL" then
		trl = d
		break
	end
end
if not trl then
	return "[err] trailer (MapId TRL) not found"
end
local pivot = trl:GetPivot()
-- world-axes frame at the trailer pivot (the trailer looks +Z: rotate the 180 degrees away); it follows a rotated trailer
local base = pivot * CFrame.Angles(0, math.pi, 0)
local function at(dx, y, dz)
	return base * CFrame.new(dx, y, dz)
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

local function stash(inst, why)
	for _, d in inst:GetDescendants() do
		for _, t in { "Station", "Interactable" } do
			CS:RemoveTag(d, t)
		end
	end
	for _, t in { "Station", "Interactable" } do
		CS:RemoveTag(inst, t)
	end
	inst:SetAttribute("OrigPath", inst:GetFullName())
	inst:SetAttribute("StashedBy", "stations_prep: " .. why)
	inst.Parent = backupFolder()
end

local board = trl:FindFirstChild("TRL-T_AST-014_CuttingBoard", true)
local function slotAttachment(i)
	if not board then
		return nil
	end
	for _, d in board:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "Att_Bun" .. i then
			return d
		end
	end
	return nil
end

CHS:SetWaypoint("stations_prep: before")

-- UNDO ------------------------------------------------------------------------------------------------------------
if REMOVE then
	for _, d in trl:GetChildren() do
		if d:IsA("Model") and d:GetAttribute("PrepStationsV1") then
			stash(d, "undo")
			log("[undo] " .. d.Name .. " -> ServerStorage." .. BACKUP)
		end
	end
	if board then
		for i = 1, 4 do
			local a = slotAttachment(i)
			if a and a:GetAttribute("PrepOrigX") then
				if i > 3 and a:GetAttribute("PrepCreated") then
					a:SetAttribute("OrigPath", a:GetFullName())
					a.Parent = backupFolder()
					log("[undo] Att_Bun4 -> backup")
				else
					local w = a.WorldCFrame
					a.WorldCFrame = CFrame.new(a:GetAttribute("PrepOrigX"), w.Y, w.Z) * w.Rotation
					a:SetAttribute("PrepOrigX", nil)
					log("[undo] " .. a.Name .. " restored")
				end
			end
		end
	end
	CHS:SetWaypoint("stations_prep: after")
	return table.concat(out, "\n")
end

-- BOARD SLOTS (4) -------------------------------------------------------------------------------------------------
local slotPos = {} -- slot -> world position
if board then
	local a1, a2, a3 = slotAttachment(1), slotAttachment(2), slotAttachment(3)
	local baseAtt
	for _, d in board:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "Att_Bun" then
			baseAtt = d
		end
	end
	if not (a1 and a2 and a3 and baseAtt) then
		log("[err] board Att_Bun / Att_Bun1..3 missing (run bind_map01)")
	else
		local a4 = slotAttachment(4)
		if not a4 and not DRY then
			a4 = Instance.new("Attachment")
			a4.Name = "Att_Bun4"
			a4.Parent = a3.Parent
			a4.WorldCFrame = a3.WorldCFrame
			a4:SetAttribute("BindCreated", true)
			a4:SetAttribute("PrepCreated", true)
			a4:SetAttribute("Slot", 4)
			a4:SetAttribute("PrepOrigX", a3.WorldPosition.X)
			log("[new] Att_Bun4 on " .. a3.Parent.Name)
		end
		local centre = baseAtt.WorldPosition
		for i = 1, 4 do
			local a = slotAttachment(i)
			-- world X descends with the slot: slot 1 is the east one (MAP-01 X ascends)
			local x = centre.X + (2.5 - i) * BUN_STEP
			slotPos[i] = Vector3.new(x, centre.Y, centre.Z)
			if a and not DRY then
				if a:GetAttribute("PrepOrigX") == nil then
					a:SetAttribute("PrepOrigX", a.WorldPosition.X)
				end
				a.WorldCFrame = CFrame.new(slotPos[i]) * a.WorldCFrame.Rotation
				a:SetAttribute("Slot", i)
			end
			log(string.format("[ok] board slot %d at %s", i, fv(slotPos[i])))
		end
	end
else
	log("[err] TRL-T board not found")
end

-- STATIONS --------------------------------------------------------------------------------------------------------
local function ensure(parent, cls, name)
	local x = parent:FindFirstChild(name)
	if x and x.ClassName == cls then
		return x, false
	end
	if x then
		stash(x, "wrong class")
	end
	x = Instance.new(cls)
	x.Name = name
	x.Parent = parent
	return x, true
end

-- a Prompt_Work that V2 moved out comes back (undo) from the backup, found by its OrigPath
local function restoreExtraPrompt(n, mount)
	local folder = ServerStorage:FindFirstChild(BACKUP)
	if not folder then
		return nil
	end
	for _, d in folder:GetChildren() do
		if d.Name == "Prompt_Work" and d:GetAttribute("StashedBy") == EXTRA_PROMPT_WHY and d:GetAttribute("Seat") == n then
			d.Parent = mount
			d:SetAttribute("StashedBy", nil)
			d:SetAttribute("OrigPath", nil)
			CS:AddTag(d, "Interactable")
			return d
		end
	end
	return nil
end

-- view centre dx (world axes from the trailer pivot): V1 = the station's own place; V2 = grill (station 1) / board (station 3)
local function viewDx(n, view)
	if V1 then
		return SPACING * (2.5 - n)
	end
	return SPACING * (2.5 - (view == "Build" and BOARD_N or GRILL_N))
end
local function seatShift(n)
	return V1 and 0 or (2.5 - n) * STAGGER
end

local function checkView(n, view, existing)
	local dx = viewDx(n, view)
	local standCF = CFrame.lookAt(at(dx + seatShift(n), STAND.y, STAND.z).Position, at(dx + seatShift(n), STAND.y, STAND.z + 1).Position)
	local focusPos = at(dx, FOCUS.y, FOCUS.z).Position
	local camPos = at(dx, FOCUS.y + DIST * math.sin(PITCH), FOCUS.z - DIST * math.cos(PITCH)).Position
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = existing and { existing } or {}
	local down = workspace:Raycast(standCF.Position + Vector3.new(0, 3, 0), Vector3.new(0, -6, 0), rp)
	local floorOk = down ~= nil and down.Instance:IsDescendantOf(trl) and math.abs(down.Position.Y - standCF.Position.Y) < 0.06
	-- no collider within the rig's radius (1.0): 8 horizontal rays at 3 heights (part bounds would hit the mesh boxes of the shell)
	local blockers = {}
	for _, h in { 1.2, 2.6, 4.0 } do
		for k = 0, 7 do
			local ang = k * math.pi / 4
			local o = standCF.Position + Vector3.new(0, h, 0)
			local hit = workspace:Raycast(o, Vector3.new(math.cos(ang), 0, math.sin(ang)) * 1.0, rp)
			if hit and hit.Instance.CanCollide then
				table.insert(blockers, (hit.Instance:GetFullName():gsub(".*OpenLateTrailer%.", "")) .. "@" .. h)
			end
		end
	end
	local look = workspace:Raycast(camPos, focusPos - camPos, rp)
	local viewClear = look == nil or (look.Position - focusPos).Magnitude < 1.2
	return {
		standCF = standCF,
		focusPos = focusPos,
		camPos = camPos,
		camCF = CFrame.lookAt(camPos, focusPos),
		ok = floorOk and #blockers == 0 and viewClear,
		text = string.format(
			"%s stand %s floor=%s blockers=%s | cam %s -> focus %s clear=%s%s",
			view,
			fv(standCF.Position),
			tostring(floorOk),
			#blockers == 0 and "none" or table.concat(blockers, ","),
			fv(camPos),
			fv(focusPos),
			tostring(viewClear),
			look and not viewClear and (" blocked by " .. look.Instance.Name) or ""
		),
	}
end

local report = {}
for n = 1, 4 do
	local existing = trl:FindFirstChild("Station_" .. n)
	local g = checkView(n, "Grill", existing)
	local b = checkView(n, "Build", existing)
	local promptDx = SPACING * (2.5 - n) -- V1: own place
	local promptStep = nil
	local hasPrompt = true
	if not V1 then
		hasPrompt = n == GRILL_N or n == BOARD_N
		promptDx = viewDx(n, n == BOARD_N and "Build" or "Grill")
		promptStep = n == BOARD_N and "Build" or "Grill"
	end
	local promptPos = at(promptDx, PROMPT.y, PROMPT.z).Position
	local bunPos = slotPos[n] or g.focusPos

	local minGap, minWith = math.huge, ""
	if hasPrompt then
		for _, i in CS:GetTagged("Interactable") do
			if i:IsDescendantOf(trl) and not (existing and i:IsDescendantOf(existing)) then
				local ip = i:IsA("Attachment") and i.WorldPosition or (i:IsA("BasePart") and i.Position)
				if ip and (ip - promptPos).Magnitude < minGap then
					minGap, minWith = (ip - promptPos).Magnitude, i.Name
				end
			end
		end
	end
	table.insert(
		report,
		string.format(
			"[%s] Station_%d %s | %s | Prompt_Work %s%s",
			(g.ok and b.ok and (not hasPrompt or minGap >= MIN_GAP)) and "ok" or "WARN",
			n,
			g.text,
			b.text,
			hasPrompt and (fv(promptPos) .. string.format(" step %s gap %.2f (%s)", tostring(promptStep or "-"), minGap, minWith)) or "none (V2: moves to the backup)",
			""
		)
	)

	if not DRY then
		local st, created = ensure(trl, "Model", "Station_" .. n)
		local mount = ensure(st, "Part", "Mount")
		mount.Size = Vector3.new(0.4, 0.2, 0.4)
		mount.Transparency = 1
		mount.Anchored, mount.CanCollide, mount.CanQuery, mount.CanTouch, mount.CastShadow = true, false, false, false, false
		mount.CFrame = g.standCF
		st.PrimaryPart = mount
		st.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		st:SetAttribute("StationKind", "prep")
		st:SetAttribute("Seat", n)
		st:SetAttribute("MapId", "TRL-PREP-" .. n)
		st:SetAttribute("PrepStationsV1", true)
		st:SetAttribute("PrepStationsV2", (not V1) or nil)
		CS:AddTag(st, "Station")
		local function att(name, cf)
			local a = ensure(mount, "Attachment", name)
			a.WorldCFrame = cf
			return a
		end
		att("Att_Stand", g.standCF)
		att("CamAnchor", g.camCF)
		att("Focus", CFrame.new(g.focusPos))
		if V1 then
			-- back to the V1 layout: the board-view attachments go to the backup
			for _, name in { "Att_Stand_Build", "CamAnchor_Build", "Focus_Build" } do
				local a = mount:FindFirstChild(name)
				if a then
					a:SetAttribute("OrigPath", a:GetFullName())
					a:SetAttribute("StashedBy", "stations_prep: undo v2")
					a.Parent = backupFolder()
				end
			end
		else
			att("Att_Stand_Build", b.standCF)
			att("CamAnchor_Build", b.camCF)
			att("Focus_Build", CFrame.new(b.focusPos))
		end
		-- Prompt_Work
		local pw = mount:FindFirstChild("Prompt_Work")
		if hasPrompt then
			if not pw and V1 then
				pw = restoreExtraPrompt(n, mount)
			end
			pw = pw or ensure(mount, "Attachment", "Prompt_Work")
			pw.WorldCFrame = CFrame.new(promptPos)
			pw:SetAttribute("PromptAction", "prep_work")
			pw:SetAttribute("PromptStep", promptStep)
			CS:AddTag(pw, "Interactable")
		elseif pw then
			pw:SetAttribute("Seat", n)
			stash(pw, EXTRA_PROMPT_WHY)
			pw:SetAttribute("StashedBy", EXTRA_PROMPT_WHY) -- stash() writes its own prefix; the restore finds this exact text
			log("[v2] Station_" .. n .. " Prompt_Work -> ServerStorage." .. BACKUP)
		end
		local ab = att("Att_Bun", CFrame.new(bunPos))
		ab:SetAttribute("Slot", n)
		log(string.format("[%s] Station_%d (%s)", created and "new" or "ok", n, fv(g.standCF.Position)))
	end
end
for _, r in report do
	log(r)
end
CHS:SetWaypoint("stations_prep: after")
return table.concat(out, "\n")
