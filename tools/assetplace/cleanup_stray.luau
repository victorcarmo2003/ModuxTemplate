--!nonstrict
--[[
	cleanup_stray.luau - Studio snippet (Edit mode, command bar / Studio MCP execute_luau), IDEMPOTENT, DRY BY DEFAULT.
	Companion of tools/assetplace/cleanup_report.md (read that first: path, type, position, reason, recommendation).
	It NEVER deletes anything on its own: deletion happens only for the full paths the owner writes in ALLOW_DELETE
	(empty on purpose) and only with DRY = false.

	What it does:
	  1  MOVE_TABLES (trivial and safe): the 4 trailer picnic tables that sit loose in the Workspace root (model named
	     AST-100_PicnicTable, tag SeatTable, TableGroup "Trailer") get Parent = workspace.MAP01_Assets.TrailerTables (Folder,
	     created when missing). Parent only: the CFrame, tag, TableIndex, Seat1..4 are untouched. Two attributes are added
	     (MapId = "TTBL-<TableIndex>", Asset = "AST-100_PicnicTable") so Place.diff pairs them with the entries TTBL-6..9 of
	     MAP-01_placements.luau. NOTE: Place.run rebuilds MAP01_Assets (it recreates these tables from the placements; then run
	     tools/assetplace/trailer_tables.luau, see STUDIO_LAYER.md).
	  2  MOVE_OPTIONAL (off): listed in the report as suggestions, nothing happens until you set `on = true`.
	  3  SCAN (always, read-only): root children that are not the known folders, empty Folders / Models, Attachments whose
	     parent is not a BasePart, Beam / Highlight / SelectionBox / Trail outside the known toolbox fountain, generic names.
	  4  ALLOW_DELETE: exact paths under Workspace or ServerStorage (instance:GetFullName()). An entry that matches 0 or more than 1 instance is refused. With
	     DRY = true it only prints what would be destroyed (and how many descendants it carries).

	Undo: Ctrl+Z (waypoints "cleanup_stray: before / after").
]]
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local DRY = true
-- Full paths (GetFullName) the owner decided to destroy after reading cleanup_report.md. EMPTY ON PURPOSE.
local ALLOW_DELETE: { string } = {}

local MOVE_TABLES = true
-- Suggestions, nothing happens while `on` is false. from = full path, to = full path of the new parent (Folder created when missing).
local MOVE_OPTIONAL = {
	{
		on = false,
		from = "Workspace.Model",
		to = "Workspace.LOBBY_Assets.LobbyFountain",
		rename = "Fountain_Toolbox",
		why = "toolbox fountain (Water + Beams, rbxassetid 70456xxxxx) loose in the Workspace root at the lobby fountain; check its licence in docs/art/credits.md first",
	},
}

assert(RunService:IsEdit(), "run in Edit mode")
local lines: { string } = {}
local function say(...)
	table.insert(lines, string.format(...))
end
local function fv(v: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end

local function ensureFolder(path: string): Instance?
	local node: Instance = game
	local first = true
	for seg in string.gmatch(path, "[^%.]+") do
		if first then
			first = false
			node = game:GetService("Workspace")
			if seg ~= "Workspace" then
				return nil
			end
			continue
		end
		local nxt = node:FindFirstChild(seg)
		if not nxt then
			if DRY then
				say("[dry] would create Folder %s under %s", seg, node:GetFullName())
				return nil
			end
			nxt = Instance.new("Folder")
			nxt.Name = seg
			nxt.Parent = node
			say("created Folder %s", nxt:GetFullName())
		end
		node = nxt
	end
	return node
end

local function resolveAll(path: string): { Instance }
	local current: { Instance } = {}
	local first = true
	for seg in string.gmatch(path, "[^%.]+") do
		if first then
			first = false
			if seg ~= "Workspace" and seg ~= "ServerStorage" then
				return {}
			end
			current = { game:GetService(seg) }
			continue
		end
		local nextList = {}
		for _, node in current do
			for _, c in node:GetChildren() do
				if c.Name == seg then
					table.insert(nextList, c)
				end
			end
		end
		current = nextList
	end
	return current
end

if not DRY then
	ChangeHistoryService:SetWaypoint("cleanup_stray: before")
end

-- 1 ---------------------------------------------------------------- loose trailer tables
if MOVE_TABLES then
	local tables = {}
	for _, c in workspace:GetChildren() do
		if c:IsA("Model") and c.Name == "AST-100_PicnicTable" and CollectionService:HasTag(c, "SeatTable") and c:GetAttribute("TableGroup") == "Trailer" then
			table.insert(tables, c)
		end
	end
	table.sort(tables, function(a, b)
		return (a:GetAttribute("TableIndex") or 0) < (b:GetAttribute("TableIndex") or 0)
	end)
	if #tables == 0 then
		say("tables: none loose in the Workspace root (already moved?)")
	else
		local dest = ensureFolder("Workspace.MAP01_Assets.TrailerTables")
		for _, t in tables do
			local idx = t:GetAttribute("TableIndex")
			local before = t:GetPivot()
			if DRY or not dest then
				say("[dry] table TableIndex %s at %s -> MAP01_Assets.TrailerTables (MapId TTBL-%s)", tostring(idx), fv(before.Position), tostring(idx))
			else
				t.Parent = dest
				if t:GetAttribute("MapId") == nil then
					t:SetAttribute("MapId", "TTBL-" .. tostring(idx))
				end
				if t:GetAttribute("Asset") == nil then
					t:SetAttribute("Asset", "AST-100_PicnicTable")
				end
				local moved = (t:GetPivot().Position - before.Position).Magnitude
				say("table TableIndex %s moved to %s (pivot shift %.4f)", tostring(idx), t:GetFullName(), moved)
				assert(moved < 1e-3, "pivot changed while reparenting")
			end
		end
	end
end

-- 2 ---------------------------------------------------------------- optional moves
for _, m in MOVE_OPTIONAL do
	local found = resolveAll(m.from)
	if #found ~= 1 then
		say("optional move %s: %d match(es), skipped", m.from, #found)
	elseif not m.on then
		say("optional move OFF: %s -> %s (%s)", m.from, m.to, m.why)
	elseif DRY then
		say("[dry] optional move %s -> %s", m.from, m.to)
	else
		local dest = ensureFolder(m.to)
		if dest then
			local inst = found[1]
			inst.Parent = dest
			if m.rename then
				inst.Name = m.rename
			end
			say("optional move done: %s", inst:GetFullName())
		end
	end
end

-- 3 ---------------------------------------------------------------- read-only scan
local KNOWN = { Terrain = true, Camera = true, MAP01_Blockout = true, MAP01_Assets = true, LOBBY_Assets = true, MapBinding = true }
for _, c in workspace:GetChildren() do
	if not KNOWN[c.Name] then
		say("scan root: %s [%s] %s", c.Name, c.ClassName, if c:IsA("PVInstance") then fv(c:GetPivot().Position) else "-")
	end
end
local nEmpty, nOrphan, nOdd = 0, 0, 0
for _, d in workspace:GetDescendants() do
	if (d:IsA("Folder") or d:IsA("Model")) and #d:GetChildren() == 0 then
		nEmpty += 1
		say("scan empty %s: %s", d.ClassName, d:GetFullName())
	elseif d:IsA("Attachment") and not d.Parent:IsA("BasePart") then
		nOrphan += 1
	elseif (d:IsA("Highlight") or d:IsA("SelectionBox") or d:IsA("SelectionSphere") or d:IsA("Trail")) then
		nOdd += 1
		say("scan odd %s: %s", d.ClassName, d:GetFullName())
	end
end
say("scan: %d empty container(s), %d Attachment(s) whose parent is not a BasePart (the toolbox fountain Beams / Water groups), %d Highlight/SelectionBox/Trail", nEmpty, nOrphan, nOdd)

-- 4 ---------------------------------------------------------------- explicit deletions
if #ALLOW_DELETE == 0 then
	say("ALLOW_DELETE is empty: nothing will be destroyed")
end
for _, path in ALLOW_DELETE do
	local found = resolveAll(path)
	if #found ~= 1 then
		say("delete REFUSED %s: %d match(es) (need exactly 1)", path, #found)
	else
		local inst = found[1]
		if inst == workspace or inst.Parent == game or (KNOWN[inst.Name] and inst.Parent == workspace) or inst.Name:sub(1, 2) == "__" then
			say("delete REFUSED %s: protected root", path)
		elseif DRY then
			say("[dry] would destroy %s (%d descendants)", path, #inst:GetDescendants())
		else
			inst:Destroy()
			say("destroyed %s", path)
		end
	end
end

if not DRY then
	ChangeHistoryService:SetWaypoint("cleanup_stray: after")
end
say("DRY = %s", tostring(DRY))
return table.concat(lines, "\n")
