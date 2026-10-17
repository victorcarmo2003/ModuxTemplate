--!nonstrict
--[[
	gearstand_upgrades.luau (owner decision 2026-10-17: the Mart left the map, the UPGRADES stay on the Gear Stand).
	Edit-mode Studio snippet, NOT gameplay code. Idempotent and reversible.
	run("assetplace/gearstand_upgrades", "dry" | "undo" | nil)

	What it found (2026-10-17): the upgrade wall ALREADY lives on the Gear Stand (Mart v2, TASK-138, MAP-01 §18.8):
	Workspace.MAP01_Assets.GearStand holds the six AST-105 pedestals (tag GearPedestal, Slot B1..B5 / S1), each with
	Prompt_Buy_<S> (Attachment, tag Interactable, PromptAction bench_buy_upgrade / bench_buy_item, BenchSlot <S>),
	Slot_<S> and Price_Anchor_<S>; the triple shutter (GearShutter L / C / R) and Att_Opal on the OpalCounter.
	ServerStorage.Mart...GEAR_WALL is the OLD blockout (Bench / Panel / Title hidden by place_assets, B1..B5 / S1 are bare
	marker Parts with no tag or attribute): cloning it next to the stand would only add a hidden box, so this snippet
	does NOT clone it. It keeps the stand's contract whole instead:
	  1. checks every pedestal / shutter / Att_Opal against Required.luau (Bench) and MapIndex.KioskNotes, and recreates a
	     missing Prompt_Buy_<S> / Slot_<S> / Price_Anchor_<S> / Att_Opal (marker _GSU_Created; same names and attributes
	     as bind_map01, which keeps them on its next run: it never resets an anchor it finds);
	  2. moves MapPoint OP-1 (Opal's fallback point, still at the old Mart counter in the plaza lot) onto Att_Opal, facing
	     the stand's front (marker _GSU_OrigCF = the pose before the first run);
	  3. reports anything that blocks the counter (6 studs in front of the glass) and the BenchSlot count (exactly 1 each).

	Why it survives a Place.run: the Gear Stand is a placement of MAP-01_placements.luau (entry GEAR_STAND / AST-104, the
	owner's position and Structure size captured on 2026-10-12) and bind_map01 (bindGearStand) recreates its pedestal
	anchors, so Place.run + Bind.run rebuild the stand; Bind.run moves OP-1 back to the Mart spot (POINTS table), so run
	this snippet AFTER bind_map01. The model stays inside MAP01_Assets on purpose: moving it out would make bind_map01 miss
	it (byMapId in MAP01_Assets) and a Place.run would add a second stand with duplicate BenchSlots.
	Undo: removes only what this snippet created (_GSU_Created) and puts OP-1 back at _GSU_OrigCF.
]]

local CHS = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local arg = (...)
local UNDO = arg == "undo"
local DRY = arg == "dry"

local MARK_CREATED = "_GSU_Created"
local MARK_ORIG = "_GSU_OrigCF"
local BIND_CREATED = "BindCreated" -- bind_map01 marker: an anchor it made (it keeps them)
local SLOTS = {
	{ slot = "B1", action = "bench_buy_upgrade" },
	{ slot = "B2", action = "bench_buy_upgrade" },
	{ slot = "B3", action = "bench_buy_upgrade" },
	{ slot = "B4", action = "bench_buy_upgrade" },
	{ slot = "B5", action = "bench_buy_upgrade" },
	{ slot = "S1", action = "bench_buy_item" },
}
local SHUTTERS = { "L", "C", "R" }
local MINI_LIFT = 1.6 -- studs over the column top (bind_map01 MINI_LIFT)
local PROMPT_AHEAD = 0.5 -- prompt in front of the mini (bind_map01 PROMPT_AHEAD)
local PRICE_DROP, PRICE_AHEAD = 0.05, 0.55
local OPAL_BACK = 2.2 -- Att_Opal behind the OpalCounter centre (live value, 2026-10-17)
local CLEAR_DEPTH = 6 -- studs in front of the glass that must stay free

local lines = {}
local function log(kind, text)
	table.insert(lines, ("[%s] %s"):format(kind, text))
end
local function fmt(v: Vector3): string
	return ("(%.2f, %.2f, %.2f)"):format(v.X, v.Y, v.Z)
end

local function findStand(): Model?
	local assets = workspace:FindFirstChild("MAP01_Assets")
	local gs = assets and assets:FindFirstChild("GearStand")
	if gs and gs:IsA("Model") then
		return gs
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("MapId") == "GEAR_STAND" and d:GetAttribute("Asset") == "AST-104_GearStand" then
			return d
		end
	end
	return nil
end

local function findPoint(id: string): BasePart?
	for _, p in CollectionService:GetTagged("MapPoint") do
		if p:IsDescendantOf(workspace) and p:IsA("BasePart") and (p:GetAttribute("PointId") or p.Name) == id then
			return p
		end
	end
	return nil
end

local function hostPart(model: Instance): BasePart?
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		return body
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function newAttachment(host: BasePart, name: string, cf: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = host
	a.WorldCFrame = cf
	a:SetAttribute(MARK_CREATED, true)
	return a
end

local stand = findStand()
if not stand then
	return "[err] Gear Stand not found (Workspace.MAP01_Assets.GearStand / MapId GEAR_STAND): nothing done"
end
local front = stand:GetPivot().LookVector -- the stand faces its pivot LookVector (world +Z since the owner turned it)
front = Vector3.new(front.X, 0, front.Z).Unit
local floorY = stand:GetPivot().Position.Y

local recording = if DRY then nil else CHS:TryBeginRecording("gearstand_upgrades " .. (if UNDO then "undo" else "apply"))

if UNDO then
	local removed = 0
	for _, d in stand:GetDescendants() do
		if d:GetAttribute(MARK_CREATED) then
			d:Destroy()
			removed += 1
		end
	end
	local op = findPoint("OP-1")
	local orig = op and op:GetAttribute(MARK_ORIG)
	if op and typeof(orig) == "CFrame" then
		op.CFrame = orig
		op:SetAttribute(MARK_ORIG, nil)
		log("undo", "OP-1 back at " .. fmt(orig.Position))
	end
	log("undo", ("%d created anchor(s) removed"):format(removed))
	if recording then
		CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return table.concat(lines, "\n")
end

-- 1. pedestals: GearPedestal + Slot, Prompt_Buy_<S> / Slot_<S> / Price_Anchor_<S>
local pedestals = {}
for _, d in stand:GetDescendants() do
	if CollectionService:HasTag(d, "GearPedestal") then
		local slot = d:GetAttribute("Slot")
		pedestals[slot] = pedestals[slot] or {}
		table.insert(pedestals[slot], d)
	end
end
local created = 0
for _, row in SLOTS do
	local list = pedestals[row.slot] or {}
	if #list ~= 1 then
		log("err", ("pedestal %s: %d GearPedestal model(s) with Slot %s (need 1); bind_map01 pairs them by MAP-01 §18.4"):format(row.slot, #list, row.slot))
		continue
	end
	local ped = list[1]
	local host = hostPart(ped)
	local bcf, bsize = ped:GetBoundingBox()
	local c = bcf.Position
	local top = c.Y + bsize.Y / 2
	local slotAtt = ped:FindFirstChild("Slot_" .. row.slot, true)
	local miniY = if slotAtt and slotAtt:IsA("Attachment") then slotAtt.WorldPosition.Y else top + MINI_LIFT
	local want = {
		["Slot_" .. row.slot] = CFrame.lookAt(Vector3.new(c.X, miniY, c.Z), Vector3.new(c.X, miniY, c.Z) + front),
		["Price_Anchor_" .. row.slot] = CFrame.lookAt(Vector3.new(c.X, top - PRICE_DROP, c.Z) + front * PRICE_AHEAD, Vector3.new(c.X, top - PRICE_DROP, c.Z) + front * 2),
		["Prompt_Buy_" .. row.slot] = CFrame.lookAt(Vector3.new(c.X, miniY, c.Z) + front * PROMPT_AHEAD, Vector3.new(c.X, miniY, c.Z) + front * 2),
	}
	for name, cf in want do
		local a = ped:FindFirstChild(name, true)
		if a == nil then
			if not host then
				log("err", ("pedestal %s: no BasePart to host %s"):format(row.slot, name))
				continue
			end
			if DRY then
				log("plan", ("pedestal %s: would create %s at %s"):format(row.slot, name, fmt(cf.Position)))
				continue
			end
			a = newAttachment(host, name, cf)
			created += 1
			log("new", ("pedestal %s: %s created at %s"):format(row.slot, name, fmt(cf.Position)))
		end
		if name == "Prompt_Buy_" .. row.slot and not DRY then
			CollectionService:AddTag(a, "Interactable")
			if a:GetAttribute("PromptAction") ~= row.action then
				a:SetAttribute("PromptAction", row.action)
			end
			if a:GetAttribute("BenchSlot") ~= row.slot then
				a:SetAttribute("BenchSlot", row.slot)
			end
		end
	end
	local prompt = ped:FindFirstChild("Prompt_Buy_" .. row.slot, true)
	if prompt and prompt:IsA("Attachment") then
		log("ok", ("pedestal %s: %s %s at %s"):format(row.slot, tostring(prompt:GetAttribute("PromptAction")), prompt.Name, fmt(prompt.WorldPosition)))
	end
end

-- BenchSlot anchors in the Workspace: exactly one per slot (MapIndex rule 2), the stored GEAR_WALL must hold none
local count = {}
for _, i in CollectionService:GetTagged("Interactable") do
	local s = i:GetAttribute("BenchSlot")
	if s ~= nil and i:IsDescendantOf(workspace) then
		count[s] = (count[s] or 0) + 1
	end
end
for _, row in SLOTS do
	if (count[row.slot] or 0) ~= 1 then
		log("err", ("BenchSlot %s: %d anchor(s) in the Workspace (need 1)"):format(row.slot, count[row.slot] or 0))
	end
end
local mart = ServerStorage:FindFirstChild("Mart")
local wall = mart and mart:FindFirstChild("GEAR_WALL", true)
if wall then
	local tagged = 0
	for _, d in wall:GetDescendants() do
		if CollectionService:HasTag(d, "Interactable") then
			tagged += 1
		end
	end
	log(if tagged == 0 then "ok" else "warn", ("stored %s: %d Interactable inside (old blockout, not cloned)"):format(wall:GetFullName(), tagged))
end

-- shutters
local shutters = {}
for _, d in stand:GetDescendants() do
	if CollectionService:HasTag(d, "GearShutter") then
		shutters[d:GetAttribute("Slot")] = (shutters[d:GetAttribute("Slot")] or 0) + 1
	end
end
for _, key in SHUTTERS do
	log(if shutters[key] == 1 then "ok" else "warn", ("shutter %s: %d GearShutter"):format(key, shutters[key] or 0))
end

-- 2. Att_Opal + OP-1
local opal = stand:FindFirstChild("Att_Opal", true)
if not opal then
	local counter = stand:FindFirstChild("OpalCounter", true)
	if counter and counter:IsA("BasePart") then
		local at = Vector3.new(counter.Position.X, floorY, counter.Position.Z) - front * OPAL_BACK
		if DRY then
			log("plan", "would create Att_Opal at " .. fmt(at))
		else
			opal = newAttachment(counter, "Att_Opal", CFrame.lookAt(at, at + front))
			created += 1
			log("new", "Att_Opal created at " .. fmt(at))
		end
	else
		log("err", "no OpalCounter: Att_Opal not created (Opal falls back on OP-1)")
	end
end
local op = findPoint("OP-1")
if opal and opal:IsA("Attachment") then
	local cf = opal.WorldCFrame
	log("ok", ("Att_Opal at %s facing %s"):format(fmt(cf.Position), fmt(cf.LookVector)))
	if op then
		local target = CFrame.lookAt(Vector3.new(cf.X, op.Position.Y, cf.Z), Vector3.new(cf.X, op.Position.Y, cf.Z) + front)
		if (op.Position - target.Position).Magnitude < 0.05 and op.CFrame.LookVector:Dot(front) > 0.999 then
			log("ok", "OP-1 already on Att_Opal")
		elseif DRY then
			log("plan", ("OP-1 %s -> %s"):format(fmt(op.Position), fmt(target.Position)))
		else
			if op:GetAttribute(MARK_ORIG) == nil then
				op:SetAttribute(MARK_ORIG, op.CFrame)
			end
			log("move", ("OP-1 %s -> %s (Opal's fallback point on the Gear Stand)"):format(fmt(op.Position), fmt(target.Position)))
			op.CFrame = target
		end
	else
		log("warn", "MapPoint OP-1 not found (optional once the Mart is off the map)")
	end
end

-- 3. nothing colliding in front of the counter (players reach the prompts over the glass)
local cf, size = stand:GetBoundingBox()
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { stand }
local boxCf = CFrame.lookAt(cf.Position + front * (size.Z / 2 + CLEAR_DEPTH / 2), cf.Position + front * 100)
local blockers = {}
for _, p in workspace:GetPartBoundsInBox(boxCf + Vector3.new(0, floorY + 3.5 - boxCf.Position.Y, 0), Vector3.new(size.X, 6, CLEAR_DEPTH), params) do
	if p.CanCollide and p.Transparency < 1 and p.Position.Y > floorY + 0.6 then
		table.insert(blockers, p:GetFullName())
	end
end
log(if #blockers == 0 then "ok" else "warn", ("%d colliding part(s) in the %d studs in front of the stand%s"):format(#blockers, CLEAR_DEPTH, if #blockers > 0 then ": " .. table.concat(blockers, ", ") else ""))

if recording then
	CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
log("sum", ("%s; %d anchor(s) created"):format(if DRY then "dry run" else "applied", created))
return table.concat(lines, "\n")
