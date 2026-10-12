--!nonstrict
--[[
	stations_prep.luau (TASK-172, P4 of docs/tech/prep-mode.md §6 "Mapa"; DEC-223; Provisional). Edit-mode Studio snippet, NOT
	gameplay code. Idempotent, NO Place.run, nothing is deleted (what leaves goes to ServerStorage.Trailer_Backup_20261012).
	Run: run("stations_prep", "dry") report only | run("stations_prep") apply | run("stations_prep", "undo").

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
local UNDO = MODE == "undo"

local SPACING = 3.5
local STAND = { y = 2.0, z = 0.85 }
local FOCUS = { y = 5.12, z = 3.25 }
local PITCH = math.rad(55)
local DIST = 2.5 -- Content.Prep.Rules.Camera.Distance
local PROMPT = { y = 3.72, z = 0.20 } -- world Y 2.2 (hip of a player on the floor), Z 11.9
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
if UNDO then
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

local report = {}
for n = 1, 4 do
	local dx = SPACING * (2.5 - n)
	local standCF = CFrame.lookAt(at(dx, STAND.y, STAND.z).Position, at(dx, STAND.y, STAND.z + 1).Position)
	local focusPos = at(dx, FOCUS.y, FOCUS.z).Position
	local camPos = at(dx, FOCUS.y + DIST * math.sin(PITCH), FOCUS.z - DIST * math.cos(PITCH)).Position
	local camCF = CFrame.lookAt(camPos, focusPos)
	local promptPos = at(dx, PROMPT.y, PROMPT.z).Position
	local bunPos = slotPos[n] or focusPos

	-- checks (read only)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local existing = trl:FindFirstChild("Station_" .. n)
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
	local view = workspace:Raycast(camPos, focusPos - camPos, rp)
	local viewClear = view == nil or (view.Position - focusPos).Magnitude < 1.2
	local minGap, minWith = math.huge, ""
	for _, i in CS:GetTagged("Interactable") do
		if i:IsDescendantOf(trl) and not (existing and i:IsDescendantOf(existing)) then
			local ip = i:IsA("Attachment") and i.WorldPosition or (i:IsA("BasePart") and i.Position)
			if ip and (ip - promptPos).Magnitude < minGap then
				minGap, minWith = (ip - promptPos).Magnitude, i.Name
			end
		end
	end
	table.insert(
		report,
		string.format(
			"[%s] Station_%d stand %s floor=%s blockers=%s | cam %s -> focus %s clear=%s | Prompt_Work %s gap %.2f (%s)%s",
			(floorOk and #blockers == 0 and viewClear and minGap >= MIN_GAP) and "ok" or "WARN",
			n,
			fv(standCF.Position),
			tostring(floorOk),
			#blockers == 0 and "none" or table.concat(blockers, ","),
			fv(camPos),
			fv(focusPos),
			tostring(viewClear),
			fv(promptPos),
			minGap,
			minWith,
			view and not viewClear and (" view blocked by " .. view.Instance.Name) or ""
		)
	)

	if not DRY then
		local st, created = ensure(trl, "Model", "Station_" .. n)
		local mount = ensure(st, "Part", "Mount")
		mount.Size = Vector3.new(0.4, 0.2, 0.4)
		mount.Transparency = 1
		mount.Anchored, mount.CanCollide, mount.CanQuery, mount.CanTouch, mount.CastShadow = true, false, false, false, false
		mount.CFrame = standCF
		st.PrimaryPart = mount
		st.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		st:SetAttribute("StationKind", "prep")
		st:SetAttribute("Seat", n)
		st:SetAttribute("MapId", "TRL-PREP-" .. n)
		st:SetAttribute("PrepStationsV1", true)
		CS:AddTag(st, "Station")
		local function att(name, cf)
			local a = ensure(mount, "Attachment", name)
			a.WorldCFrame = cf
			return a
		end
		att("Att_Stand", standCF)
		att("CamAnchor", camCF)
		att("Focus", CFrame.new(focusPos))
		local pw = att("Prompt_Work", CFrame.new(promptPos))
		pw:SetAttribute("PromptAction", "prep_work")
		CS:AddTag(pw, "Interactable")
		local ab = att("Att_Bun", CFrame.new(bunPos))
		ab:SetAttribute("Slot", n)
		log(string.format("[%s] Station_%d (%s)", created and "new" or "ok", n, fv(standCF.Position)))
	end
end
for _, r in report do
	log(r)
end
CHS:SetWaypoint("stations_prep: after")
return table.concat(out, "\n")
