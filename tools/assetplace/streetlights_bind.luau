--!nonstrict
--[[
	streetlights_bind.luau (playtest 2026-10-12: PlaceService "map binding (wave 3) has 83 problem(s)"). Edit-mode Studio
	snippet, NOT gameplay code. Idempotent; never deletes. run("assetplace/streetlights_bind", "dry" | "undo" | nil).

	Rule of PlaceService / MapIndex.Validate (Required.Tagged + check 5):
	  * every instance with tag StreetLight carries a unique string attribute PostId;
	  * every Model that is, or contains, a tagged instance (up to Workspace) is ModelStreamingMode Persistent.
	The 5 gameplay posts (NL-01..NL-04, P-01) are Models bound by bind_map01 (PostId, Group, Order). Root cause of the 83
	problems: every AST-036_LampHead.Bulb MeshPart of the DECORATIVE posts (Post_*, POST-OUT*, Post_L2; 34 of them, and the
	Bulbs of NL-01..04) carries the tag StreetLight (it came after the last bind run: the AST-036 template is clean), without
	PostId, and the Models around them (LampHead, the owner's grouping Model, ...) are ModelStreamingMode Default.

	What it does (nothing is deleted or moved):
	  1. A tagged instance that is not a Model (a Bulb) loses the tag. If it sits inside a real post Model (NL-xx / P-01) that
	     is all. Otherwise its owner Model (nearest ancestor Asset = AST-036_LampHead, else nearest Model) becomes the post:
	     tag StreetLight, PostId = "DECOR-<MapId>-<x>_<z>" (MapId or name before "_AST-", pivot XZ rounded; "-2", "-3" when
	     two heads share it; an existing unique PostId is kept), Decor = true. No Group / Order: LightController reads them as
	     Order 0 of juniper_posts, like the bare Bulb was, but now with the Bulb as its lamp part (night neon, day Cream).
	  2. ModelStreamingMode = Persistent on every Model that is or contains a tagged instance (the owner's "Model" groups too).
	  3. Reports suspected duplicates (same MapId, pivot within 0.5 stud): it only lists them.
	Undo: stripped Bulbs get the tag back (attribute _SLB_Stripped), made posts lose tag / PostId / Decor (_SLB_Made),
	Persistent Models go back to their old mode (_SLB_Mode); the markers are removed.
	Called by bind_map01.luau (bindDecorLamps) after every Bind.run; this file is the stand-alone version for a place that
	was edited by hand without a bind.
]]

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local arg = (...)
local UNDO = arg == "undo"
local DRY = arg == "dry"

local TAG = "StreetLight"
local REAL = { ["NL-01"] = true, ["NL-02"] = true, ["NL-03"] = true, ["NL-04"] = true, ["P-01"] = true }
local MARK_STRIPPED, MARK_MADE, MARK_MODE = "_SLB_Stripped", "_SLB_Made", "_SLB_Mode"

local lines = {}
local function log(kind, text)
	table.insert(lines, ("[%s] %s"):format(kind, text))
end

local function isReal(m)
	return m:IsA("Model") and REAL[m:GetAttribute("PostId")] == true
end

local function modelOf(inst)
	local c = inst.Parent
	local head, firstModel = nil, nil
	while c and c ~= workspace do
		if c:IsA("Model") then
			if isReal(c) then
				return c, true
			end
			if head == nil and c:GetAttribute("Asset") == "AST-036_LampHead" then
				head = c
			end
			firstModel = firstModel or c
		end
		c = c.Parent
	end
	return head or firstModel, false
end

local function mapIdOf(m)
	local id = m:GetAttribute("MapId")
	if typeof(id) == "string" and id ~= "" then
		return id
	end
	return (string.match(m.Name, "^(.-)_AST%-") or m.Name)
end

local recording = nil
if not DRY then
	recording = CHS:TryBeginRecording("streetlights_bind")
end

local changed = 0

if UNDO then
	for _, d in workspace:GetDescendants() do
		if d:GetAttribute(MARK_STRIPPED) then
			CS:AddTag(d, TAG)
			d:SetAttribute(MARK_STRIPPED, nil)
			changed += 1
		end
		if d:GetAttribute(MARK_MADE) then
			CS:RemoveTag(d, TAG)
			d:SetAttribute("PostId", nil)
			d:SetAttribute("Decor", nil)
			d:SetAttribute(MARK_MADE, nil)
			changed += 1
		end
		local mode = d:GetAttribute(MARK_MODE)
		if mode and d:IsA("Model") then
			d.ModelStreamingMode = Enum.ModelStreamingMode[mode]
			d:SetAttribute(MARK_MODE, nil)
			changed += 1
		end
	end
	if recording then
		CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return ("streetlights_bind undo: %d change(s)"):format(changed)
end

-- 1: strays and untagged-id Models
local used = {}
for _, inst in CS:GetTagged(TAG) do
	local id = inst:GetAttribute("PostId")
	if inst:IsA("Model") and typeof(id) == "string" then
		used[id] = (used[id] or 0) + 1
	end
end

local owners = {} -- Model -> true (becomes / is a decorative post)
local stripped = 0
for _, inst in CS:GetTagged(TAG) do
	if not inst:IsDescendantOf(workspace) then
		continue
	end
	if not inst:IsA("Model") then
		local owner, inReal = modelOf(inst)
		if not DRY then
			CS:RemoveTag(inst, TAG)
			inst:SetAttribute(MARK_STRIPPED, true)
		end
		stripped += 1
		if owner and not inReal then
			owners[owner] = true
		elseif owner == nil then
			log("warn", ("stray tag on %s without a Model owner: tag removed only"):format(inst:GetFullName()))
		end
	elseif not isReal(inst) then
		owners[inst] = true
	end
end
log("ok", ("%d stray %s tag(s) on non-Model parts %s"):format(stripped, TAG, if DRY then "(dry: would be removed)" else "removed"))

local list = {}
for m in owners do
	table.insert(list, m)
end
table.sort(list, function(a, b)
	return a:GetFullName() < b:GetFullName()
end)

local made = 0
for _, m in list do
	local id = m:GetAttribute("PostId")
	local ok = typeof(id) == "string" and id ~= "" and (used[id] or 0) <= 1 and CS:HasTag(m, TAG)
	if not (typeof(id) == "string" and id ~= "" and (used[id] or 0) <= 1) then
		local p = m:GetPivot().Position
		local base = ("DECOR-%s-%d_%d"):format(mapIdOf(m), math.round(p.X), math.round(p.Z))
		local candidate, n = base, 1
		while used[candidate] do
			n += 1
			candidate = base .. "-" .. n
		end
		id = candidate
		used[id] = 1
		ok = false
		if not DRY then
			m:SetAttribute("PostId", id)
		end
	end
	if not CS:HasTag(m, TAG) or not ok then
		if not DRY then
			CS:AddTag(m, TAG)
			if not m:GetAttribute(MARK_MADE) then
				m:SetAttribute(MARK_MADE, true)
			end
			if m:GetAttribute("Decor") ~= true then
				m:SetAttribute("Decor", true)
			end
		end
		made += 1
	end
end
log("ok", ("%d decorative post Model(s) tagged with a PostId"):format(made))

-- 2: Persistent on every Model that is or contains a tagged instance
local persisted = 0
local seen = {}
local function persist(m)
	if seen[m] then
		return
	end
	seen[m] = true
	if m.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
		if not DRY then
			if m:GetAttribute(MARK_MODE) == nil then
				m:SetAttribute(MARK_MODE, m.ModelStreamingMode.Name)
			end
			m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end
		persisted += 1
	end
end
local function tagged()
	if DRY then
		-- dry: what the tagged set would be after step 1
		local out = {}
		for _, i in CS:GetTagged(TAG) do
			if i:IsA("Model") then
				table.insert(out, i)
			end
		end
		for _, m in list do
			table.insert(out, m)
		end
		return out
	end
	return CS:GetTagged(TAG)
end
for _, inst in tagged() do
	local c = inst
	while c and c ~= workspace do
		if c:IsA("Model") then
			persist(c)
		end
		c = c.Parent
	end
end
log("ok", ("%d Model(s) set to ModelStreamingMode Persistent"):format(persisted))

-- 3: suspected duplicates (report only)
local byKey = {}
for _, m in list do
	local k = mapIdOf(m)
	byKey[k] = byKey[k] or {}
	table.insert(byKey[k], m)
end
local dupes = 0
for k, ms in byKey do
	for i = 1, #ms do
		for j = i + 1, #ms do
			if (ms[i]:GetPivot().Position - ms[j]:GetPivot().Position).Magnitude < 0.5 then
				dupes += 1
				log("warn", ("duplicate? %s and %s are < 0.5 stud apart (MapId %s): nothing removed"):format(ms[i]:GetFullName(), ms[j]:GetFullName(), k))
			end
		end
	end
end
if dupes == 0 then
	log("ok", "no overlapping duplicate heads")
end

-- check: the PlaceService rule
local problems = 0
if not DRY then
	local ids = {}
	for _, inst in CS:GetTagged(TAG) do
		local id = inst:GetAttribute("PostId")
		if typeof(id) ~= "string" or id == "" then
			problems += 1
			log("err", ("still without PostId: %s"):format(inst:GetFullName()))
		else
			ids[id] = (ids[id] or 0) + 1
		end
		local c = inst
		while c and c ~= workspace do
			if c:IsA("Model") and c.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
				problems += 1
				log("err", ("not Persistent: %s"):format(c:GetFullName()))
			end
			c = c.Parent
		end
	end
	for id, n in ids do
		if n > 1 then
			problems += 1
			log("err", ("PostId %s used %d times"):format(id, n))
		end
	end
	for id in REAL do
		if ids[id] ~= 1 then
			problems += 1
			log("err", ("real post %s found %d time(s)"):format(id, ids[id] or 0))
		end
	end
end
log(if problems == 0 then "ok" else "err", ("rule check: %d problem(s)"):format(problems))

if recording then
	CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return "streetlights_bind" .. (if DRY then " (dry)" else "") .. ":\n" .. table.concat(lines, "\n")
