--[[
	MAP-01 upgrade pieces binding (TASK-085, closes bug B-02). Edit-mode tool, same status as bind_map01.luau: NOT
	gameplay code. Status: Rascunho (level-designer, 2026-10-10).

	Contract: docs/tech/architecture.md §18.1 (tag UpgradePiece), §18.2 (Upgrade, Level), §18.4 "Peças de upgrade"
	(T38: toggled by visibility, never reparented; no Interactable / slot Attachment inside a piece; anchors stay on the
	station root). DEC-052 (the piece shows the level bought), DEC-184 (level per vehicle: the trailer piece is another
	instance), DEC-201 (grill slot n at the same place on every level).
	Source: ReplicatedStorage.Assets.Equipment.UpgradePieces/<cart|trailer>/<Part> (build_pieces.luau, TASK-084),
	untagged, pivot = asset origin. Runtime: src/Upgrade/server/UpgradeService/Pieces.luau shows the piece whose Level
	equals the current level of its vehicle (Vehicle ancestor) and hides the others.

	ORDER: Place.run -> Bind.run (bind_map01) -> Pieces.run (this) -> Check.run({ wave = 2 }).
	Bind.run UNDOES this script first (destroys the clones, restores the fixed parts; its clean slate would otherwise
	strip Level from the clones): run Pieces.run again after every Bind.run. Pieces.run alone is idempotent (it starts
	with Pieces.undo).

	What it does, per vehicle (tag Vehicle under workspace.MAP01_Assets) and per Content.Upgrades row with Part ~= "":
	  1. Clones the kit piece into a Folder "UpgradePieces" inside its owner, tag UpgradePiece, Upgrade/Level from the
	     kit (checked against the row), ModelStreamingMode Persistent, attribute PieceClone (tool metadata):
	       grill             station CART-G / TRL-G      aligned on the fixed mesh Grill_L1
	       cooler            station CART-S / TRL-S      aligned on the fixed mesh Body (AST-018 CoolerL1)
	       cash_drawer_lock  DRAWER / TRL-DRAWER         aligned on the fixed Lock (AST-020)
	       trailer_lights    trailer vehicle             aligned on the fixed Lights_Mast (TRL-LIGHTS, 2 models)
	       counter           vehicle                     COUNTER_POSE (no fixed counter in MAP-01_placements)
	     Alignment: pose = fixedPart.CFrame * (kit part in piece space)^-1, with the kit part of the LOWEST level that
	     has a part of that name and the same size. Every level of an upgrade uses that pose (one asset origin per
	     upgrade, build_pieces.luau). No match (part missing, or another size: e.g. the old AST-012 upload still in the
	     place) -> the fixed model pivot (= placement CFrame = asset origin, build_pieces convention), with a warning.
	     A group whose kit pieces are incomplete is skipped whole: nothing cloned, the fixed model stays visible.
	  2. Authored state = StartLevel piece visible, the other levels hidden with the UpgradeService attributes
	     (UpgHidden, UpgOrigTransparency, UpgOrigCanCollide, UpgOrigCanQuery, UpgOrigEnabled: same names as Pieces.luau,
	     otherwise the server could never show them). Drawer Lock and Trailer Lights start at 0: all hidden.
	  3. Hides the fixed equivalents placed by place_assets: the grill and cooler meshes, the DRAWER Lock (TASK-084
	     note: it was always visible), both TRL-LIGHTS models. Transparency 1, no collide/query/touch/shadow, Lights
	     off, BaseParts renamed "Fixed_<name>" (Stock.luau finds "Fill" by name: a hidden mesh must never answer);
	     originals in Piece* attributes. They stay in place as hosts of the bind_map01 anchors.
	  4. Anchors (T38, at the station root, outside the piece):
	       grill   Att_Slot1..4 (grill_collect, Slot n) moved onto the kit Anchor_Slot<n> (same at every level, no
	               Level attribute). Kit numbering is kept (slots 1-2 = the L1 rollers); a warning tells when the order
	               is not west -> east as seen from the corridor (§18.2 Slot rule).
	       cooler  Prompt_Take (grill_place) / Prompt_Restock (restock): ONE anchor per action, valid for the 3 levels
	               (see SHARED PROMPTS).
	     After the moves, the closest anchor of another owner in the same vehicle is reported (check_map01 rule 4).

	SHARED PROMPTS (Provisório, level-designer, TASK-085): only KitchenService filters slot Attachments by Level; the
	InteractionService / PromptController do not filter Interactable by Level, so one anchor per level would show three
	prompts. Each cooler prompt goes to the X/Z of the level whose kit anchor is furthest out in front (L3 fridge, so it
	is never inside the body), Y = the lowest level (2026-10-10, was the median), then each one is lifted on its own
	until it is 0.3 above the counter top (the cart cooler sits low inside the cart body). If the code ever filters Interactable by
	Level, switch to one anchor per level with Level (T38).

	COUNTER (Provisório, level-designer, TASK-085; AST-078 replaces the trailer one, TASK-088): the kit counter is a
	customer bar standing on the Pad, top 3.0 (cart) / 3.5 (trailer), front (stools, L3 return) = local -Z = north =
	queue. Origin centred on Q1 (X 52) so the two L2 stools straddle the Q1 customer; cart row Z 34.5..35.5 (in front of
	the station line Z 36..39), trailer row Z 33.9..34.9 (against the front wall Z 35). The L3 return (X 55..56, Z down
	to 33.5 on the cart / 32.9 on the trailer) grazes the Q1 -> N-Z01-02 exit line (Z 33): pieces do not collide
	(kit CanCollide false), visual only.

	Notes for other owners (not done here):
	  - frontend (Stock.luau): FindFirstChild("Fill", true) returns the first Fill of the station; with Cooler_L1 and
	    Cooler_L2 both inside CART-S it must take the Fill of the VISIBLE piece (L3 has no Fill). Same for any VFX_* /
	    Lid looked up by name inside a station (VFX_Steam<n> exists in each grill level).
	  - architect: Required.Wave2 (MapIndex) does not list UpgradePiece; check_map01 now requires it (§18.1).

	Usage (edit mode, Command Bar; repo served on 8772):
		local Pieces = require(<this module>)
		print(Pieces.run())            -- opts: { content = <Content table>? }
		print(Pieces.undo(workspace.MAP01_Assets))
	Save the place afterwards (Ctrl+S).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Pieces = {}

-- MAP-01 frame (map_frame.luau, 2026-10-10): the place is turned 180 in Y. PAD_POSE / COUNTER_POSE stay in MAP-01
-- coordinates and go through FCF; the "west -> east" order of the grill slots is read in MAP-01 X (M).
local MAP_FRAME_URL = "http://127.0.0.1:8772/tools/assetplace/map_frame.luau"
local function loadMapFrame(): any
	local sib = script and script.Parent and script.Parent:FindFirstChild("map_frame")
	if sib and sib:IsA("ModuleScript") then
		return (require :: any)(sib)
	end
	local ms = Instance.new("ModuleScript")
	ms.Name = "map_frame"
	ms.Source = game:GetService("HttpService"):GetAsync(MAP_FRAME_URL, true)
	return (require :: any)(ms)
end
local MapFrame = loadMapFrame()
local M: (Vector3) -> Vector3 = MapFrame.M
local FCF: (CFrame) -> CFrame = MapFrame.FCF

local ASSETS_ROOT = "MAP01_Assets"
local BINDING_ROOT = "MapBinding"
local TAG = "UpgradePiece"
local FOLDER = "UpgradePieces"
local CLONE = "PieceClone" -- on every clone and on the folders created here (undo destroys them)
local FIXED = "PieceFixed" -- on every fixed instance hidden here (undo restores it)
local ORIG_NAME = "PieceOrigName"
local ORIG_T = "PieceOrigTransparency"
local ORIG_COLLIDE = "PieceOrigCanCollide"
local ORIG_QUERY = "PieceOrigCanQuery"
local ORIG_TOUCH = "PieceOrigCanTouch"
local ORIG_SHADOW = "PieceOrigCastShadow"
local ORIG_ENABLED = "PieceOrigEnabled"
local FIXED_PREFIX = "Fixed_"

-- src/Upgrade/server/UpgradeService/Pieces.luau attribute names (the authored hidden state the server restores)
local UPG_HIDDEN = "UpgHidden"
local UPG_T = "UpgOrigTransparency"
local UPG_COLLIDE = "UpgOrigCanCollide"
local UPG_QUERY = "UpgOrigCanQuery"
local UPG_ENABLED = "UpgOrigEnabled"

local SIZE_TOL = 0.05
local SAME_TOL = 0.05
local MIN_GAP = 2.5 -- §18.7 item 4

-- Pad poses: the MapPoints CART / TRL (written by bind_map01 = the vehicle pivots on the Pad) win; these constants
-- are the same as bind_map01.luau CART_POSE / TRL_POSE.
local PAD_POSE = { -- world (MAP-01 numbers through the map frame)
	cart = FCF(CFrame.new(41, 0.45, 37.5)),
	trailer = FCF(CFrame.new(40, 0.45, 41)),
}
local PAD_POINT = { cart = "CART", trailer = "TRL" }
-- counter top over the vehicle pivot: cart Pad 0.45 + 3.0 (DEC-157); trailer floor +2, counter 3.5 (MAP-01 §7.2)
local COUNTER_TOP_DY = { cart = 3.0, trailer = 5.5 }
local PROMPT_ABOVE_COUNTER = 0.3

-- Counter piece origin in Pad coordinates (see COUNTER above). rotY 0: local -Z (front, stools) = north = queue.
local COUNTER_POSE = { -- world (MAP-01 numbers through the map frame)
	cart = FCF(CFrame.new(52, 0.45, 35.0)),
	trailer = FCF(CFrame.new(52, 0.45, 34.4)),
}

-- Owner of each upgrade. ids = MapId of the fixed model inside the vehicle; match = BasePart name in both the
-- fixed model and a kit piece (alignment); hide = "all" fixed BaseParts or only the ones with that name;
-- inVehicle = the piece folder goes in the vehicle (not in the fixed model); anchors = anchor rule.
type Owner = {
	ids: { [string]: string }?,
	match: string?,
	hide: string?,
	inVehicle: boolean?,
	pose: { [string]: CFrame }?,
	anchors: string?,
}
local OWNERS: { [string]: Owner } = {
	grill = { ids = { cart = "CART-G", trailer = "TRL-G" }, match = "Grill_L1", hide = "all", anchors = "grill" },
	cooler = { ids = { cart = "CART-S", trailer = "TRL-S" }, match = "Body", hide = "all", anchors = "cooler" },
	cash_drawer_lock = { ids = { cart = "DRAWER", trailer = "TRL-DRAWER" }, match = "Lock", hide = "Lock" },
	trailer_lights = { ids = { trailer = "TRL-LIGHTS" }, match = "Lights_Mast", hide = "all", inVehicle = true },
	counter = { pose = COUNTER_POSE, inVehicle = true },
}

local COOLER_PROMPTS = {
	{ name = "Prompt_Take", action = "grill_place" },
	{ name = "Prompt_Restock", action = "restock" },
}

---------------------------------------------------------------------------------------------------
-- Report
---------------------------------------------------------------------------------------------------

local report: { string } = {}
local counts = { ok = 0, new = 0, warn = 0, err = 0, note = 0 }

local function log(kind: string, msg: string)
	counts[kind] = (counts[kind] or 0) + 1
	table.insert(report, ("[%s] %s"):format(kind, msg))
end

local function fmtV(v: Vector3): string
	return ("(%.2f, %.2f, %.2f)"):format(v.X, v.Y, v.Z)
end

---------------------------------------------------------------------------------------------------
-- Rows (Content.Upgrades, else the embedded copy of src/Shared/Content/Upgrades.luau)
---------------------------------------------------------------------------------------------------

type Row = { upgrade: string, vehicle: string, level: number, part: string, start: number }

local function embeddedRows(): { Row }
	local rows: { Row } = {}
	local function add(upgrade: string, vehicle: string, level: number, part: string, start: number)
		table.insert(rows, { upgrade = upgrade, vehicle = vehicle, level = level, part = part, start = start })
	end
	for _, v in { "cart", "trailer" } do
		for level = 1, 3 do
			add("grill", v, level, "Grill_L" .. level, 1)
			add("cooler", v, level, "Cooler_L" .. level, 1)
			add("counter", v, level, "Counter_L" .. level, 1)
		end
		add("cash_drawer_lock", v, 1, "DrawerLock_L1", 0)
	end
	add("trailer_lights", "trailer", 1, "TrailerLights_L1", 0)
	return rows
end

local function rowsFrom(content: any): { Row }?
	local up = type(content) == "table" and content.Upgrades or nil
	if type(up) ~= "table" or type(up.List) ~= "table" then
		return nil
	end
	local rows: { Row } = {}
	for _, u in up.List do
		for _, vehicle in u.Vehicles or {} do
			for _, r in (u.Levels and u.Levels[vehicle]) or {} do
				if type(r.Part) == "string" and r.Part ~= "" then
					table.insert(rows, { upgrade = u.Key, vehicle = vehicle, level = r.Level, part = r.Part, start = u.StartLevel })
				end
			end
		end
	end
	return rows
end

local function loadRows(opts: { content: any? }): ({ Row }, string)
	if opts.content then
		local rows = rowsFrom(opts.content)
		if rows then
			return rows, "opts.content"
		end
	end
	local shared = ReplicatedStorage:FindFirstChild("shared")
	local mod = shared and shared:FindFirstChild("Content")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok then
			local rows = rowsFrom(res)
			if rows then
				return rows, "ReplicatedStorage.shared.Content"
			end
		end
	end
	return embeddedRows(), "embedded copy of Upgrades.luau (rojo not synced)"
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

local function near(a: Vector3, b: Vector3, tol: number): boolean
	return math.abs(a.X - b.X) <= tol and math.abs(a.Y - b.Y) <= tol and math.abs(a.Z - b.Z) <= tol
end

local function insideClone(i: Instance): boolean
	local n: Instance? = i
	while n and n ~= game do
		if n:GetAttribute(CLONE) then
			return true
		end
		n = n.Parent
	end
	return false
end

local function ancestorWithTag(i: Instance, tag: string): Instance?
	local n = i.Parent
	while n and n ~= game do
		if CollectionService:HasTag(n, tag) then
			return n
		end
		n = n.Parent
	end
	return nil
end

-- Owner of an anchor (§18.3): the Station ancestor, else the nearest Model ancestor.
local function ownerOf(i: Instance): Instance?
	local st = ancestorWithTag(i, "Station")
	if st then
		return st
	end
	local n = i.Parent
	while n and n ~= Workspace do
		if n:IsA("Model") then
			return n
		end
		n = n.Parent
	end
	return nil
end

local function anchorPos(a: Instance): Vector3
	if a:IsA("Attachment") then
		return a.WorldPosition
	elseif a:IsA("BasePart") then
		return a.Position
	elseif a:IsA("PVInstance") then
		return (a :: any):GetPivot().Position
	end
	return Vector3.zero
end

local function setAnchor(a: Instance, p: Vector3, frame: CFrame)
	if a:IsA("Attachment") then
		a.WorldCFrame = CFrame.new(p) * frame.Rotation
	elseif a:IsA("BasePart") then
		a.CFrame = CFrame.new(p) * frame.Rotation
	end
end

local function firstPart(model: Instance, partName: string): BasePart?
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == partName then
			return d
		end
	end
	return nil
end

local function anchorAttr(piece: Instance, anchorName: string): Vector3?
	local a = piece:GetAttribute("Anchor_" .. anchorName)
	return if typeof(a) == "Vector3" then a else nil
end

-- Pad pose of a vehicle (MapPoint, else the constant)
local function padPose(vkey: string): CFrame
	local root = Workspace:FindFirstChild(BINDING_ROOT)
	local pts = root and root:FindFirstChild("Points")
	local p = pts and pts:FindFirstChild(PAD_POINT[vkey] or "")
	if p and p:IsA("BasePart") then
		return p.CFrame
	end
	return PAD_POSE[vkey] or CFrame.identity
end

-- A world point of a vehicle expressed where it would be with the vehicle parked on the Pad
local function toPad(vkey: string, vehicle: Instance, p: Vector3): Vector3
	return padPose(vkey):PointToWorldSpace(((vehicle :: any):GetPivot() :: CFrame):PointToObjectSpace(p))
end

-- Interactable anchors with `action` owned by `station` (never inside a piece)
local function stationAnchors(station: Instance, action: string, slot: number?): { Instance }
	local out = {}
	for _, d in station:GetDescendants() do
		if CollectionService:HasTag(d, "Interactable") and d:GetAttribute("PromptAction") == action and ownerOf(d) == station and not insideClone(d) then
			if slot == nil or d:GetAttribute("Slot") == slot then
				table.insert(out, d)
			end
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Visibility: pieces (UpgradeService scheme) and fixed parts (this tool's scheme)
---------------------------------------------------------------------------------------------------

-- Same as Pieces.luau hide(): authored hidden state that UpgradeService:RefreshPiece can show again.
local function upgHide(item: Instance)
	if item:GetAttribute(UPG_HIDDEN) then
		return
	end
	if item:IsA("BasePart") then
		item:SetAttribute(UPG_T, item.Transparency)
		item:SetAttribute(UPG_COLLIDE, item.CanCollide)
		item:SetAttribute(UPG_QUERY, item.CanQuery)
		item.Transparency = 1
		item.CanCollide = false
		item.CanQuery = false
	elseif item:IsA("Decal") or item:IsA("Texture") then
		item:SetAttribute(UPG_T, item.Transparency)
		item.Transparency = 1
	elseif item:IsA("ParticleEmitter") or item:IsA("Light") or item:IsA("Beam") or item:IsA("Trail") then
		item:SetAttribute(UPG_ENABLED, item.Enabled)
		item.Enabled = false
	elseif item:IsA("SurfaceGui") or item:IsA("BillboardGui") then
		item:SetAttribute(UPG_ENABLED, item.Enabled)
		item.Enabled = false
	else
		return
	end
	item:SetAttribute(UPG_HIDDEN, true)
end

local function hidePiece(piece: Instance)
	upgHide(piece)
	for _, d in piece:GetDescendants() do
		upgHide(d)
	end
end

-- GHOST (2026-10-10, user request, Provisório): upgrades whose kit piece is a stand-in without its own model stay
-- INVISIBLE at every level. The pieces still exist (tag UpgradePiece, Upgrade / Level: UpgradeService and check_map01
-- find them, the upgrade keeps working) but the "original" values UpgradeService restores when it shows a level are
-- the hidden ones, so showing the bought level changes nothing on screen. Attribute NoVisual = true on the piece.
-- counter: Counter_L1..L3 (AST-019 stand-in, loose on the Pad) until the counter model exists (AST-078 / art-director).
local GHOST_UPGRADES: { [string]: boolean } = { counter = true }

local function ghostPiece(piece: Instance)
	hidePiece(piece)
	local list: { Instance } = { piece }
	for _, d in piece:GetDescendants() do
		table.insert(list, d)
	end
	for _, d in list do
		if d:GetAttribute(UPG_HIDDEN) then
			if d:IsA("BasePart") then
				d:SetAttribute(UPG_T, 1)
				d:SetAttribute(UPG_COLLIDE, false)
				d:SetAttribute(UPG_QUERY, false)
				d.CanTouch = false
				d.CastShadow = false
				d.Locked = true
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d:SetAttribute(UPG_T, 1)
			else
				d:SetAttribute(UPG_ENABLED, false)
			end
		end
	end
	piece:SetAttribute("NoVisual", true)
end

local function hideFixedOne(item: Instance)
	if item:GetAttribute(FIXED) then
		return
	end
	if item:IsA("BasePart") then
		item:SetAttribute(ORIG_NAME, item.Name)
		item:SetAttribute(ORIG_T, item.Transparency)
		item:SetAttribute(ORIG_COLLIDE, item.CanCollide)
		item:SetAttribute(ORIG_QUERY, item.CanQuery)
		item:SetAttribute(ORIG_TOUCH, item.CanTouch)
		item:SetAttribute(ORIG_SHADOW, item.CastShadow)
		item.Transparency = 1
		item.CanCollide = false
		item.CanQuery = false
		item.CanTouch = false
		item.CastShadow = false
		item.Name = FIXED_PREFIX .. item.Name
	elseif item:IsA("Decal") or item:IsA("Texture") then
		item:SetAttribute(ORIG_T, item.Transparency)
		item.Transparency = 1
	elseif item:IsA("Light") or item:IsA("SurfaceGui") or item:IsA("BillboardGui") then
		item:SetAttribute(ORIG_ENABLED, item.Enabled)
		item.Enabled = false
	else
		return
	end
	item:SetAttribute(FIXED, true)
end

-- Hides a fixed BasePart and its visuals (decals, guis, lights). Attachments (bind anchors) are left alone.
local function hideFixed(part: BasePart)
	hideFixedOne(part)
	for _, d in part:GetDescendants() do
		hideFixedOne(d)
	end
end

local function restoreFixed(item: Instance)
	if item:IsA("BasePart") then
		local n = item:GetAttribute(ORIG_NAME)
		if typeof(n) == "string" then
			item.Name = n
		end
		local t = item:GetAttribute(ORIG_T)
		item.Transparency = if typeof(t) == "number" then t else 0
		item.CanCollide = item:GetAttribute(ORIG_COLLIDE) ~= false
		item.CanQuery = item:GetAttribute(ORIG_QUERY) ~= false
		item.CanTouch = item:GetAttribute(ORIG_TOUCH) ~= false
		item.CastShadow = item:GetAttribute(ORIG_SHADOW) ~= false
	elseif item:IsA("Decal") or item:IsA("Texture") then
		local t = item:GetAttribute(ORIG_T)
		item.Transparency = if typeof(t) == "number" then t else 0
	elseif item:IsA("Light") or item:IsA("SurfaceGui") or item:IsA("BillboardGui") then
		item.Enabled = item:GetAttribute(ORIG_ENABLED) ~= false
	end
	for _, a in { FIXED, ORIG_NAME, ORIG_T, ORIG_COLLIDE, ORIG_QUERY, ORIG_TOUCH, ORIG_SHADOW, ORIG_ENABLED } do
		item:SetAttribute(a, nil)
	end
end

-- Undoes a previous run under `root`: destroys clones and the folders created here, restores the fixed parts.
-- bind_map01.luau has the same routine (unbindPieces): keep both in sync. Returns (pieces destroyed, restored).
function Pieces.undo(root: Instance): (number, number)
	local clones, fixed = {}, {}
	for _, d in root:GetDescendants() do
		if d:GetAttribute(CLONE) then
			table.insert(clones, d)
		elseif d:GetAttribute(FIXED) then
			table.insert(fixed, d)
		end
	end
	local n = 0
	for _, c in clones do
		if CollectionService:HasTag(c, TAG) then
			n += 1
		end
	end
	for _, c in clones do
		c:Destroy()
	end
	for _, f in fixed do
		restoreFixed(f)
	end
	return n, #fixed
end

---------------------------------------------------------------------------------------------------
-- Anchors
---------------------------------------------------------------------------------------------------

-- Grill: Att_Slot<n> (grill_collect, Slot n) onto the kit Anchor_Slot<n>; same place at every level (DEC-201).
local function bindGrillSlots(station: Instance, clones: { [number]: Model }, vkey: string, vehicle: Instance, label: string): { Instance }
	local moved = {}
	local ref: Model? = nil
	local refCount = 0
	for _, c in clones do
		local k = 0
		while anchorAttr(c, "Slot" .. (k + 1)) do
			k += 1
		end
		if k > refCount then
			ref, refCount = c, k
		end
	end
	if not ref then
		log("err", label .. ": no Anchor_Slot<n> attribute in the kit pieces (build_pieces.luau, T38)")
		return moved
	end
	local refPivot = ref:GetPivot()
	local padX: { number } = {}
	for n = 1, refCount do
		local world = refPivot:PointToWorldSpace(anchorAttr(ref, "Slot" .. n) :: Vector3)
		for level, c in clones do
			local p = anchorAttr(c, "Slot" .. n)
			if p and (c:GetPivot():PointToWorldSpace(p) - world).Magnitude > SAME_TOL then
				log("warn", ("%s: kit Slot%d differs between levels (L%d): DEC-201 asks the same place; the L%d one is used, no Level attribute"):format(label, n, level, ref:GetAttribute("Level") :: number))
			end
		end
		table.insert(padX, M(toPad(vkey, vehicle, world)).X) -- MAP-01 X: west -> east
		local list = stationAnchors(station, "grill_collect", n)
		if #list == 0 then
			log("err", ("%s: no grill_collect anchor with Slot %d in the station (run bind_map01 first)"):format(label, n))
		end
		for _, a in list do
			local d = (anchorPos(a) - world).Magnitude
			setAnchor(a, world, refPivot)
			table.insert(moved, a)
			log(if d > SAME_TOL then "new" else "ok", ("%s: %s (Slot %d) on the kit Anchor_Slot%d at %s (moved %.2f)"):format(label, a.Name, n, n, fmtV(world), d))
		end
		if #list > 1 then
			log("warn", ("%s: %d grill_collect anchors with Slot %d (need 1)"):format(label, #list, n))
		end
	end
	for n = 2, #padX do
		if padX[n] <= padX[n - 1] then
			log("warn", ("%s: kit slots are not west -> east as seen from the corridor (Slot%d X %.2f, Slot%d X %.2f on the Pad). Kept: slots 1..k must stay on the rollers of level k-1 (art-director / modeler-3d to confirm the §18.2 order)"):format(label, n - 1, padX[n - 1], n, padX[n]))
			break
		end
	end
	return moved
end

-- Cooler: one Prompt_Take / Prompt_Restock valid for the 3 levels (SHARED PROMPTS in the header).
local function bindCoolerPrompts(station: Instance, clones: { [number]: Model }, vkey: string, vehicle: Instance, label: string): { Instance }
	local moved = {}
	local pivot: CFrame? = nil
	for _, c in clones do
		pivot = c:GetPivot()
		break
	end
	if not pivot then
		return moved
	end
	-- 2026-10-10 (user: prompts too high): Y = the LOWEST level (L1 front face), not the median, and each prompt is
	-- clamped on its own to counter + PROMPT_ABOVE_COUNTER. The old common lift kept Take ~1.1 over Restock, so on
	-- the cart (cooler low in the body) Take ended ~1.4 over the counter, at eye height.
	local targets: { [string]: Vector3 } = {}
	for _, spec in COOLER_PROMPTS do
		local list: { Vector3 } = {}
		for _, c in clones do
			local p = anchorAttr(c, spec.name)
			if p then
				table.insert(list, p)
			end
		end
		if #list == 0 then
			log("warn", ("%s: no kit Anchor_%s: %s left where bind_map01 put it"):format(label, spec.name, spec.name))
			continue
		end
		local front = list[1]
		local ys: { number } = {}
		for _, p in list do
			if math.abs(p.Z) > math.abs(front.Z) then
				front = p
			end
			table.insert(ys, p.Y)
		end
		table.sort(ys)
		targets[spec.action] = Vector3.new(front.X, ys[1], front.Z)
	end
	local floor = ((vehicle :: any):GetPivot() :: CFrame).Y + (COUNTER_TOP_DY[vkey] or 3.0) + PROMPT_ABOVE_COUNTER
	for _, spec in COOLER_PROMPTS do
		local localPos = targets[spec.action]
		if not localPos then
			continue
		end
		local raw = (pivot :: CFrame):PointToWorldSpace(localPos)
		local lift = math.max(0, floor - raw.Y)
		local world = raw + Vector3.new(0, lift, 0)
		local list = stationAnchors(station, spec.action)
		if #list ~= 1 then
			log("err", ("%s: %d %s anchor(s) in the station (need 1; run bind_map01 first)"):format(label, #list, spec.action))
		end
		for _, a in list do
			local d = (anchorPos(a) - world).Magnitude
			setAnchor(a, world, pivot :: CFrame)
			table.insert(moved, a)
			log(if d > SAME_TOL then "new" else "ok", ("%s: %s (%s) shared by L1..L3 at %s (moved %.2f; lift %.2f over the counter rule)"):format(label, a.Name, spec.action, fmtV(world), d, lift))
		end
	end
	return moved
end

-- §18.7 item 4 after the moves: closest anchor of another owner in the same vehicle
local function reportGaps(moved: { Instance }, vehicle: Instance, label: string)
	for _, a in moved do
		local own = ownerOf(a)
		local best, who = math.huge, "-"
		for _, o in CollectionService:GetTagged("Interactable") do
			if o ~= a and o:IsDescendantOf(vehicle) and ownerOf(o) ~= own then
				local d = (anchorPos(o) - anchorPos(a)).Magnitude
				if d < best then
					best, who = d, o:GetFullName()
				end
			end
		end
		if best < MIN_GAP then
			log("warn", ("%s: %s is %.2f from %s (another owner, < %.1f: check_map01 rule 4 will fail; move one by hand)"):format(label, a.Name, best, who, MIN_GAP))
		end
	end
end

---------------------------------------------------------------------------------------------------
-- One (vehicle, upgrade) group
---------------------------------------------------------------------------------------------------

type Group = { vkey: string, upgrade: string, rows: { Row } }

local function bindGroup(vehicle: Instance, g: Group, kit: Instance): number
	local label = ("%s/%s"):format(g.vkey, g.upgrade)
	local spec = OWNERS[g.upgrade]
	if not spec then
		log("err", label .. ": no owner rule in bind_pieces.luau OWNERS (new upgrade?)")
		return 0
	end
	table.sort(g.rows, function(a, b)
		return a.level < b.level
	end)

	-- kit pieces (all or nothing)
	local dir = kit:FindFirstChild(g.vkey)
	local templates: { [number]: Model } = {}
	for _, r in g.rows do
		local t = dir and dir:FindFirstChild(r.part)
		if not (t and t:IsA("Model")) then
			log("err", ("%s: kit piece UpgradePieces/%s/%s missing (run build_pieces.luau, TASK-084): group skipped, fixed model left visible"):format(label, g.vkey, r.part))
			return 0
		end
		if t:GetAttribute("Upgrade") ~= r.upgrade or t:GetAttribute("Level") ~= r.level then
			log("err", ("%s: kit %s says %s L%s, Content says %s L%d: group skipped"):format(label, r.part, tostring(t:GetAttribute("Upgrade")), tostring(t:GetAttribute("Level")), r.upgrade, r.level))
			return 0
		end
		templates[r.level] = t
	end

	-- fixed models and the folder parent
	local fixedModels: { Instance } = {}
	local parent: Instance = vehicle
	if spec.ids then
		local id = spec.ids[g.vkey]
		if not id then
			log("err", label .. ": no fixed MapId for this vehicle in OWNERS")
			return 0
		end
		for _, d in vehicle:GetDescendants() do
			if d:GetAttribute("MapId") == id and d:IsA("PVInstance") and not insideClone(d) then
				table.insert(fixedModels, d)
			end
		end
		if #fixedModels == 0 then
			log("err", ("%s: fixed model %s not found inside the %s (run Place.run + Bind.run first)"):format(label, id, vehicle.Name))
			return 0
		end
		if not spec.inVehicle then
			parent = fixedModels[1]
			if #fixedModels > 1 then
				log("warn", ("%s: %d models with MapId %s; pieces go in the first (%s)"):format(label, #fixedModels, id, parent:GetFullName()))
			end
		end
	end

	-- pose
	local pose: CFrame? = nil
	if spec.pose then
		local pad = spec.pose[g.vkey]
		pose = ((vehicle :: any):GetPivot() :: CFrame) * padPose(g.vkey):Inverse() * pad
		log("note", ("%s: no fixed counter; piece origin at Pad %s (MAP-01), front north (Provisório, TASK-085; AST-078 for the trailer)"):format(label, fmtV(M(pad.Position))))
	elseif spec.match then
		local cands: { BasePart } = {}
		for _, m in fixedModels do
			if m:IsA("BasePart") and m.Name == spec.match then
				table.insert(cands, m)
			end
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and d.Name == spec.match then
					table.insert(cands, d)
				end
			end
		end
		for _, r in g.rows do
			local t = templates[r.level]
			local kp = firstPart(t, spec.match)
			if kp then
				for _, fp in cands do
					if near(fp.Size, kp.Size, SIZE_TOL) then
						pose = fp.CFrame * t:GetPivot():ToObjectSpace(kp.CFrame):Inverse()
						log("ok", ("%s: aligned on the fixed %s (kit %s)"):format(label, fp:GetFullName(), r.part))
						break
					end
				end
			end
			if pose then
				break
			end
		end
		local host = fixedModels[1]
		if #cands > 0 then
			host = ownerOf(cands[1]) or host
			for _, m in fixedModels do
				if cands[1]:IsDescendantOf(m) then
					host = m
				end
			end
		end
		local hostPivot = (host :: any):GetPivot() :: CFrame
		if not pose then
			pose = hostPivot
			log("warn", ("%s: no fixed %s with the kit size (%d candidate(s); old upload in the place?): placed on the %s pivot %s. Verify in Studio"):format(label, spec.match, #cands, host.Name, fmtV(hostPivot.Position)))
		else
			local d = ((pose :: CFrame).Position - hostPivot.Position).Magnitude
			if d > SIZE_TOL then
				log("note", ("%s: piece origin %.2f from the %s pivot (imported model pivot is not the asset origin; alignment by part wins)"):format(label, d, host.Name))
			end
		end
	end
	if not pose then
		log("err", label .. ": no pose rule")
		return 0
	end
	if (pose :: CFrame).UpVector.Y < 0.999 then
		log("warn", ("%s: piece pose is tilted (UpVector %s)"):format(label, fmtV((pose :: CFrame).UpVector)))
	end

	-- clones
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder:SetAttribute(CLONE, true)
	folder.Parent = parent
	local clones: { [number]: Model } = {}
	local count = 0
	for _, r in g.rows do
		local c = templates[r.level]:Clone()
		c.Name = r.part
		c:PivotTo(pose :: CFrame)
		c:SetAttribute(CLONE, true)
		local fv = c:GetAttribute("ForVehicle")
		if fv ~= nil and fv ~= g.vkey then
			log("warn", ("%s: kit %s has ForVehicle %s"):format(label, r.part, tostring(fv)))
		end
		c.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		c.Parent = folder
		CollectionService:AddTag(c, TAG)
		local ghost = GHOST_UPGRADES[g.upgrade] == true
		local shown = r.level == r.start and not ghost
		if ghost then
			ghostPiece(c)
		elseif not shown then
			hidePiece(c)
		end
		clones[r.level] = c
		count += 1
		log("new", ("%s: %s (L%d) tagged %s in %s%s"):format(label, r.part, r.level, TAG, parent.Name,
			if ghost then " - NO VISUAL (ghost until its model exists; upgrade still works)" elseif shown then " - visible (StartLevel)" else " - hidden (UpgHidden)"))
	end

	-- fixed equivalents
	local hidden = 0
	for _, m in fixedModels do
		local list: { Instance } = { m }
		for _, d in m:GetDescendants() do
			table.insert(list, d)
		end
		for _, d in list do
			if d:IsA("BasePart") and not d:GetAttribute(FIXED) and not insideClone(d) and d.Transparency < 1
				and not CollectionService:HasTag(d, "Interactable") and d:GetAttribute("Slot") == nil
				and (spec.hide == "all" or d.Name == spec.hide)
			then
				hideFixed(d)
				hidden += 1
			end
		end
	end
	if #fixedModels > 0 then
		log(if hidden > 0 then "ok" else "warn", ("%s: %d fixed part(s) hidden and renamed %s*%s"):format(label, hidden, FIXED_PREFIX, if hidden == 0 then " (nothing visible to hide?)" else ""))
	end

	-- anchors (T38)
	local moved: { Instance } = {}
	if spec.anchors == "grill" then
		moved = bindGrillSlots(parent, clones, g.vkey, vehicle, label)
	elseif spec.anchors == "cooler" then
		moved = bindCoolerPrompts(parent, clones, g.vkey, vehicle, label)
	end
	reportGaps(moved, vehicle, label)
	return count
end

---------------------------------------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------------------------------------

function Pieces.run(opts: { content: any? }?): string
	local o = opts or {}
	table.clear(report)
	for k in counts do
		counts[k] = 0
	end

	local assets = Workspace:FindFirstChild(ASSETS_ROOT)
	if not assets then
		return "[err] workspace." .. ASSETS_ROOT .. " not found: run Place.run and Bind.run first"
	end
	local a = ReplicatedStorage:FindFirstChild("Assets")
	local e = a and a:FindFirstChild("Equipment")
	local kit = e and e:FindFirstChild("UpgradePieces")
	if not kit then
		return "[err] ReplicatedStorage.Assets.Equipment.UpgradePieces not found: run build_pieces.luau (TASK-084) first"
	end
	log("ok", ("kit UpgradePieces KitVersion %s"):format(tostring(kit:GetAttribute("KitVersion"))))

	local destroyed, restored = Pieces.undo(assets)
	log("ok", ("undo: %d old piece(s) destroyed, %d fixed instance(s) restored"):format(destroyed, restored))

	local rows, src = loadRows(o)
	log("ok", ("rows: %d (Part ~= \"\") from %s"):format(#rows, src))

	local vehicles: { [string]: Instance } = {}
	for _, v in CollectionService:GetTagged("Vehicle") do
		if v:IsDescendantOf(assets) then
			local k = v:GetAttribute("Vehicle")
			if typeof(k) == "string" then
				if vehicles[k] then
					log("err", ("two Vehicle '%s' models (%s, %s)"):format(k, vehicles[k]:GetFullName(), v:GetFullName()))
				else
					vehicles[k] = v
				end
			end
		end
	end

	local groups: { [string]: Group } = {}
	local order: { string } = {}
	for _, r in rows do
		local key = r.vehicle .. "/" .. r.upgrade
		if not groups[key] then
			groups[key] = { vkey = r.vehicle, upgrade = r.upgrade, rows = {} }
			table.insert(order, key)
		end
		table.insert(groups[key].rows, r)
	end
	table.sort(order)

	local total = 0
	for _, key in order do
		local g = groups[key]
		local v = vehicles[g.vkey]
		if not v then
			log("err", ("%s: Vehicle '%s' not found under %s (run Bind.run first)"):format(key, g.vkey, ASSETS_ROOT))
			continue
		end
		total += bindGroup(v, g, kit)
	end

	local tagged = 0
	for _, i in CollectionService:GetTagged(TAG) do
		if i:IsDescendantOf(Workspace) then
			tagged += 1
		end
	end
	local head = ("bind_pieces (TASK-085): %d / %d piece(s) | ok %d | new %d | note %d | warn %d | err %d\nUpgradePiece in Workspace: %d\n"):format(
		total,
		#rows,
		counts.ok,
		counts.new,
		counts.note,
		counts.warn,
		counts.err,
		tagged
	)
	return head .. table.concat(report, "\n") .. "\nNext: Check.run({ wave = 2 }), then save the place."
end

return Pieces
