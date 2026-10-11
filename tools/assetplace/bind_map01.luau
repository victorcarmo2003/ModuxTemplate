--[[
	MAP-01 binding, waves 1 + 2 + 3 (TASK-005, TASK-083, TASK-098, TASK-132). Edit-mode tool, same status as place_assets.luau:
	NOT gameplay code. Status: Rascunho (level-designer, 2026-10-10).

	Wave 3 (TASK-098, TASK-132; architecture.md §19.22, §8, §19.13-§19.17; MAP-01 §5.4-§5.6, §7.2, §9.3, §9.5, §10.3,
	§11, §16.5):
	  W1. Service window (DEC-221, TASK-132; replaces the hide spots H1..H4, which are destroyed here):
	      - button TRL-SHUTTER: bind-created Model (MapId TRL-SHUTTER) inside the trailer with a placeholder plate
	        "Button" (0.5 x 0.7 x 0.15, Mustard) on the south wall at X 43.4 (Pad frame), same wall face and height
	        as the TRL-SWITCH plate; Attachment Prompt_Shutter (Interactable, PromptAction "shutter_toggle") 0.3 in
	        front of it. The plate slides west, then up, until the prompt is >= 2.6 from every anchor of another
	        owner (Prompt_Switch is 2.6 away by construction). Kept on re-runs unless opts.resetCreated.
	      - flap: Attachment Shutter_Hinge (X axis = hinge axis along the window, authored pose = OPEN) with
	        attribute ClosedAngle (degrees around the hinge X axis that bring the piece from open to closed). On the
	        AST-027 MeshPart "Awning" when, measured, it spans the window (22.5) and, hung from its wall-side edge,
	        covers sill 3.5 .. top 8 above the floor; otherwise on a placeholder Part "Shutter_Panel" (22.5 x 4.6 x
	        0.2, Metal / Aluminum, no collision) hinged on the window top outside the wall, authored open
	        (horizontal, outwards; ClosedAngle -90), and the Awning stays fixed (MAP-01 P51). The client poses the
	        piece: closed = H * CFrame.Angles(rad(ClosedAngle), 0, 0) * H:Inverse() * openCFrame, H = the hinge's
	        authored WorldCFrame (cache it: the hinge moves with the piece).
	  W2. Apartment windows WV-1..3 (ANM-006): tag AnomalyAnchor + AnchorId on Window_Up_<n> of the AST-045 (Z-11);
	      without it, an invisible Part WV-<n> in MapBinding/Anomaly at the MAP-01 position (warning).
	  W3. MapPoints: SS, AN-04/05/11/12, AS-1..4, WALKER-10, traffic entries/exits W/E/JN/JS-IN/OUT, cutscene points
	      (CutsceneMark1..4, CS-1..5, CS-P1..4, SS-1..4, WALT-1, MKT-DOOR, RL-1, RL-END; + CS-5W / CS-5E proposal).
	  W4. Sidewalk nodes of Content.WalkPaths (17 new NpcNodes, crosswalk pairs CW-1, CW-2, CW-3; CW-4 is wave 1).
	  W5. Traffic in MapBinding/Traffic: Paths/TR-n (Folder, tag TrafficPath, PathId; child Parts "01".."nn" with
	      Index 1..n, each facing the next node, on the road top), Lines/SL-* (Part across the lane, tag TrafficLine,
	      LineId; LookVector = travel direction of the lane that stops there), Boxes/X-T + CW-1..4 (volume, tag
	      TrafficBox, BoxId). All invisible, no collision, no query (Provisional, TASK-097 note d).

	2026-10-10 additions (level-designer, all Provisório; MAP-01 §9.8, §5.6, §16.8):
	  W6. Spawn / despawn points (MAP-01 §9.8): every point where an NPC appears or vanishes carries Spawn (comma list of
	      roles: customer, thief, pedestrian, actor), Despawn (bool) and SpawnKind ("door" = a building door, rule a;
	      "edge" = a street end beyond the player limits, out of sight of the Pad and the Mart, rule b); door points
	      also Door = the door id. New: DR-APT (bank / apartments door), SP-S (Juniper South beyond BAR-S), SP-B (laundry
	      door), DR-B3 (B3b door); moved: EX-E into the alley behind B1, ST-R past the curve, SP-A into the shadow of the
	      bank rear; MKT-DOOR becomes a node. Content.Flow.Spawns (customers) and Content.WalkPaths (pedestrians) use them.
	  W7. Helpers locked: every invisible helper (MapBinding parts, created anchors / lamp holders / placeholders, the
	      blockout Markers, Limits, hidden and ghost parts) gets Locked = true (no click-select in Studio) and CanTouch
	      false; CanQuery false unless it still collides (player limits keep their collision).
	  W8. AutoDoor (DoorController contract): the LEAF of the Mart door (MapId MKT-DOOR; placeholder glass Door_Leaf
	      when the mesh has none), D1 and SP-B gets tag AutoDoor + DoorId, DoorLeaf, DoorHinge (Left/Right), DoorAngle
	      (signed: opens inward), DoorRadius 8 and CanCollide false on the server (only the client animates).
	  W9. (2026-10-10, ambience pass, user request) the stray default Workspace.SpawnLocation (Roblox template, star
	      decal, 12 x 1 x 12 in the middle of the crossing / X-T) moves to ServerStorage.DevScenes. Players are placed
	      by CharacterService on PS-* / PS-N*; the blockout SpawnLocation_PS on the Pad stays the engine spawn.
	  Walker posts (2026-10-10, user: the Juniper posts were not visible from the trailer window): 4 posts NL-01..04 on
	      the Ninth north curb (bank / parking side) every 20 studs, X 118 -> 58, + P-01 (Order 1..5: NL-01 = 1 ...
	      NL-04 = 4, P-01 = 5); Walker steps 0..3 = Order 1..4, step 4 = WALKER-10 (48, 14) across the Ninth from the
	      window; Hush = 5 posts x 3 s (Content.LightGroups). The blockout lights of JL-01..09 and of the decorative
	      Post_NinthN_E1 (it stood between NL-01 and NL-02) are disabled.
	  Awning: ClosedAngle from the measured slant of the Awning (bbox diagonal + raycast profile), hanging 3 degrees
	      outwards; a degenerate angle (< 5 degrees) falls back to the Shutter_Panel.

	Map frame (2026-10-10, decision of the user): the place is turned 180 degrees in Y (map_frame.luau). Every number in
this file stays in MAP-01 coordinates (docs, +X east, +Z south) and so does the logic (north = -Z, "west first" = smaller
X, boxes, raycast probes). Conversion happens ONLY at the Workspace boundary: reads of world positions go through
M / MCF (partsBox, mapPos, mapPivot, bowl / part positions) and writes through F / FCF (Attachment.WorldCFrame,
Part.CFrame, PivotTo, raycast origins); world directions compared with MAP-01 directions go through FD.

Contract: docs/tech/architecture.md §18 (tags §18.1, attributes §18.2, anchors §18.3-§18.4, points §18.5, NpcNode
	graph §18.6) and §19.22 (wave 2: trailer, phone, purchase, tarp, light, points, street bins; T36, T38, T60).
	Layout: docs/levels/MAP-01.md §5, §7, §9, §10.2 and §16 (binding notes). DEC-157 (cart counter y 3.45), DEC-190 /
	DEC-215 (board 2 slots on the cart, 3 on the trailer), DEC-201 (grill 4 slots), DEC-086 (trailer on the Pad),
	DEC-124 (phone in both vehicles), DEC-196 (no light volume on the Pad <-> Mart route), DEC-199 (tarp on the cart
	at the sale spot), DEC-200 (street bin is interactive).

	What it does, over workspace.MAP01_Assets (built by place_assets.luau) and workspace.MapBinding:
	  0. Both layers in the Workspace (T36: "both vehicles live in the Workspace"): the Night_* folders kept in
	     ServerStorage.MAP01_Assets_Night and the Cart folder kept in MAP01_Assets_Day move into MAP01_Assets.
	     After this, do NOT use Place.showLayer any more (it would store the cart again).
	  1. Clean slate: first undoes bind_pieces.luau (TASK-085: destroys the UpgradePiece clones, restores the fixed
     grill / cooler / Lock / TRL-LIGHTS parts; otherwise the clones would lose their Level attribute below), then
     removes the tags it owns and the authored attributes from every descendant of MAP01_Assets.
     Run bind_pieces.luau (Pieces.run) after every Bind.run.
	  2. Cart (wave 1, unchanged): Vehicle "cart"; CART-*, DRAWER and BIN-C inside it; stations S G R B T K + BIN-C;
	     DRAWER fittings; Zone_Center. Wave 2: CART-PHONE.Prompt_Answer (answer_phone) and the tarp placeholder
	     (Model "VehicleCover" inside the cart, tag VehicleCover, authored HIDDEN, see step 8).
	  3. Trailer (wave 2): the AST-027 placed on the Pad (MapId TRL) becomes Vehicle "trailer"; every TRL-* model
	     (except the TRL-SALE shell) goes inside it; the old hide cabinets H1..H4 (AST-041) are destroyed (DEC-221). Stations as the cart, plus Rail_8 (8 slots), board with
	     3 slots and coffee_machine (Prompt_Brew -> brew_coffee, Prompt_Restock -> restock, Ingredient coffee).
	     TRL-PHONE.Prompt_Answer, TRL-SWITCH.Prompt_Switch (switch_light), Prompt_Buy on the shell (buy_trailer),
	     Zone_Center, DRAWER fittings. The empty sale shell (MapId TRL-SALE) is removed: the real trailer parks there.
	  4. Map anchors (wave 1): OPEN sign, Mart shelves (MKT-SHELVES), GEAR WALL. Wave 2: street bins AST-034_TrashCan
	     -> tag StreetBin + Prompt_Discard (discard; T60, Q-166 b: all three, Provisório).
	  5. Street lights (2026-10-10: Walker posts moved to the Ninth): NL-01..04 + P-01 -> one Model per post (pole +
	     head) with tag StreetLight, PostId, Group = "juniper_posts", Order 1..5 in Hush order (NL-01 = 1 ... NL-04 = 4,
	     P-01 = 5). A blockout SpotLight of the same id (P-01) is copied into LampHead/Light_Lamp and the blockout one is
	     disabled (no double light); posts with no blockout twin (NL-*) get a default SpotLight.
	  6. workspace.MapBinding: MapPoint parts (wave 1 + PS-N1..4, REV-1..4, TRL, TRL-SALE, CART, SPEC-P, SPEC-M,
	     DROP-T, L1..L3, ST-R, SIGN-T) and the NpcNode graph (wave 1 + thief nodes up to the lurks). Floor Y by
	     raycast; vehicle poses are the model pivots (no raycast); SPEC-* are camera points at absolute height.
	  7. MapBinding/LightZones: LZ-1..5 volume parts (tag LightZone, ZoneId, Group; Block or Ball). Static on the Pad
	     (only active with the trailer as current vehicle: LightGroups condition), never on the Pad <-> Mart route.
	  8. Tarp (VehicleCover): authored hidden (Transparency 1, CanCollide/CanQuery false) with OrigTransparency /
	     OrigCanCollide / OrigCanQuery = the visible values (same attribute names as place_assets.hide). The
	     VehicleService shows it while the cart is at TRL-SALE (T38). Provisório until AST-043 is modelled.
	  9. ModelStreamingMode = Persistent on every Model that is, or contains, a tagged instance (§18.0 item 6).
	 10. Last: the trailer is pivoted to TRL-SALE (start of a run: cart on the Pad, trailer for sale, DEC-047).
	     Every anchor is bound with the trailer on the Pad, so the fallbacks are in MAP-01 coordinates.

	Anchor lookup (§18.3):
	  - Attachment with the expected name            -> used as is ("ok").
	  - BasePart with that name                       -> used as anchor, forced invisible / no collide ("ok part").
	  - other class with that name (Model, Folder...) -> renamed <name>_Src, Attachment created at its pivot ("conv").
	  - nothing                                       -> Attachment created at a fallback position ("new"), with
	                                                     attribute BindCreated = true. Kept on re-runs (hand-tuning
	                                                     survives) unless opts.resetCreated = true.
	  Trailer fallbacks = the cart fallback + (trailer station pivot - cart station pivot): same asset, same layout.
	  Phone prompts are pushed up until they are >= 2.6 from every anchor of another owner in the same vehicle.

	IMPORTANT: place_assets.luau Place.run() destroys and rebuilds MAP01_Assets (and the night store). After every
	Place.run, run Bind.run() again. MapBinding lives outside MAP01_Assets and is rebuilt here every run.

	Usage (edit mode, Command Bar; repo served on 8772, see docs/levels/MAP-01.md §16):
		local Bind = require(<this module>)
		print(Bind.run())                       -- opts: { resetCreated = false }
	Then bind_pieces.luau (Pieces.run(), TASK-085) and check_map01.luau (Check.run({ wave = 3 })).
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Bind = {}

-- MAP-01 frame (map_frame.luau): MAP-01 coordinates <-> world. See the header.
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
local F: (Vector3) -> Vector3 = MapFrame.F -- MAP-01 point -> world
local M: (Vector3) -> Vector3 = MapFrame.M -- world point -> MAP-01
local FD: (Vector3) -> Vector3 = MapFrame.FD -- MAP-01 direction -> world
local FCF: (CFrame) -> CFrame = MapFrame.FCF -- MAP-01 CFrame -> world
local MCF: (CFrame) -> CFrame = MapFrame.MCF -- world CFrame -> MAP-01

local ASSETS_ROOT = "MAP01_Assets"
local BINDING_ROOT = "MapBinding"
local CREATED = "BindCreated"
local SRC_NAME = "SrcName"

local COUNTER_Y = 3.45 -- cart counter top (DEC-157; Provisório until Q-153)
local TRAILER_COUNTER_DY = 5.5 -- trailer counter top over the trailer pivot: floor +2, counter 3.5 (MAP-01 §2, §7.2)

-- Vehicle poses = model pivots (T36: VehicleService does vehicle:PivotTo(MapIndex.Point(id))). Same numbers as the
-- CART / TRL / TRL-SALE entries of MAP-01_placements.luau: change both together. MAP-01 frame (world = FCF(pose)).
local CART_POSE = CFrame.new(41, 0.45, 37.5) -- MAP-01 CART centre is (41, 40); the pivot of AST-026 is (41, 37.5)
local TRL_POSE = CFrame.new(40, 0.45, 41) -- facing north (window to the queue)
local SALE_POSE = CFrame.new(78, 0.02, -58) * CFrame.Angles(0, math.pi, 0) -- facing south (window to the Pad)

local OWN_TAGS = {
	"MapBinding",
	"MapPoint",
	"NpcNode",
	"Vehicle",
	"Station",
	"Interactable",
	"VehicleCover",
	"LightZone",
	"StreetLight",
	"StreetBin",
	-- wave 3
	"AnomalyAnchor",
	"TrafficPath",
	"TrafficLine",
	"TrafficBox",
	-- 2026-10-10 (W8)
	"AutoDoor",
}
local AUTHORED_ATTRS = {
	"DoorId",
	"DoorAngle",
	"AnchorId",
	"PointId",
	"NodeId",
	"Links",
	"Crosswalk",
	"Vehicle",
	"StationKind",
	"Ingredient",
	"PromptAction",
	"Slot",
	"Level",
	"Package",
	"BenchSlot",
	"ZoneId",
	"Group",
	"PostId",
	"Order",
}

local NORTH = Vector3.new(0, 0, -1)
local SOUTH = Vector3.new(0, 0, 1)
local EAST = Vector3.new(1, 0, 0)
local WEST = Vector3.new(-1, 0, 0)
local DRAWER_XZ = { 52, 37 } -- the thief looks at the drawer from the lurks (MAP-01 §9.2)

---------------------------------------------------------------------------------------------------
-- DATA (MAP-01). x, z = world studs; floor = expected floor top (Pad 0.45, Ninth sidewalk / Mart 0.4,
-- Juniper sidewalk tiles 0.24, trailer floor 2.45, parking lot 0.02); the raycast result is used when it is
-- within 0.6 of it.
---------------------------------------------------------------------------------------------------

-- MapPoint (§18.5). node = true -> the same Part is also an NpcNode (NodeId omitted, PointId is the id).
-- onTrailer = the floor is the trailer's (raycast ignores the cart); the others ignore the trailer.
-- y = absolute height (camera points, no raycast). pose = vehicle pose (pivot of the model, no raycast).
-- faceTo = { x, z } the point faces (horizontal).
local POINTS = {
	{ id = "PS-1", x = 32, z = 42, floor = 0.45, face = NORTH },
	{ id = "PS-2", x = 38, z = 42, floor = 0.45, face = NORTH },
	{ id = "PS-3", x = 44, z = 42, floor = 0.45, face = NORTH },
	{ id = "PS-4", x = 50, z = 42, floor = 0.45, face = NORTH },
	{ id = "Q1", x = 52, z = 33, floor = 0.45, face = SOUTH, node = true },
	{ id = "Q2", x = 46, z = 29, floor = 0.4, face = EAST, node = true },
	{ id = "Q3", x = 41, z = 29, floor = 0.4, face = EAST, node = true },
	{ id = "Q4", x = 36, z = 29, floor = 0.4, face = EAST, node = true },
	{ id = "Q5", x = 31, z = 29, floor = 0.4, face = EAST, node = true },
	-- D1: MAP-01 gives (64, 48) = the door plane on B1's west wall (X 64). Point 1 stud out, on the Pad, so an
	-- NPC never spawns inside the wall. Faces west (out of the door).
	{ id = "D1", x = 63, z = 48, floor = 0.45, face = WEST, node = true, spawn = "customer,actor", despawn = true, door = "D1" },
	-- SP-A (MAP-01 §9.8): moved from (30, -104) to the strip north of the bank-rear fill, in its shadow as seen from
	-- the Pad AND from the Mart door / SS (at -104 the Mart door saw it down the Juniper). Beyond BAR-N.
	{ id = "SP-A", x = 29, z = -92, floor = 0.24, face = WEST, node = true, spawn = "customer,pedestrian,actor", despawn = true },
	-- EX-E (MAP-01 §9.8): moved from the sidewalk (116, 24), seen from Q1..Q5 down the sidewalk, into the alley
	-- X 113..120 behind B1 (beyond BAR-E): B1 hides it from the Pad, the queue and the Mart door.
	{ id = "EX-E", x = 116.5, z = 40, floor = 0, face = SOUTH, node = true, spawn = "pedestrian", despawn = true },
	-- Opal behind the checkout, back to the north glass, facing into the store (south).
	{ id = "OP-1", x = -75, z = 33.5, floor = 0.4, face = SOUTH },

	-- wave 2 (§19.22) -------------------------------------------------------------------------
	-- night spawn inside the trailer (MAP-01 §5.1), facing the window
	{ id = "PS-N1", x = 32, z = 41, floor = 2.45, face = NORTH, onTrailer = true },
	{ id = "PS-N2", x = 38, z = 41, floor = 2.45, face = NORTH, onTrailer = true },
	{ id = "PS-N3", x = 44, z = 41, floor = 2.45, face = NORTH, onTrailer = true },
	{ id = "PS-N4", x = 50, z = 41, floor = 2.45, face = NORTH, onTrailer = true },
	-- revived / lost night: standing on the south sidewalk, facing the Pad (MAP-01 §5.5, DEC-122)
	{ id = "REV-1", x = 38, z = 20, floor = 0.4, face = SOUTH },
	{ id = "REV-2", x = 42, z = 20, floor = 0.4, face = SOUTH },
	{ id = "REV-3", x = 46, z = 20, floor = 0.4, face = SOUTH },
	{ id = "REV-4", x = 50, z = 20, floor = 0.4, face = SOUTH },
	-- spectator's items (FEAT-025): trailer floor, back-right corner beside the back door, inside LZ-1 (MAP-01 §5.1)
	{ id = "DROP-T", x = 51.5, z = 44.5, floor = 2.45, face = NORTH, onTrailer = true },
	-- vehicle poses (T36)
	{ id = "CART", pose = "cart" },
	{ id = "TRL", pose = "trl" },
	{ id = "TRL-SALE", pose = "sale" },
	-- sale sign (VehicleController draws "Available on Day 5" here; proposal, see MAP-01 §16)
	{ id = "SIGN-T", x = 78, y = 0.02, z = -40, face = SOUTH }, -- y fixed: a raycast would start inside the sign
	-- fixed spectator cameras (MAP-01 §5.5): absolute height, horizontal facing; the camera pitches down itself
	{ id = "SPEC-P", x = 66, y = 20, z = 28, faceTo = { 44, 30 } },
	{ id = "SPEC-M", x = -48, y = 14, z = 40, faceTo = { -50, 13 } },
	-- thief (MAP-01 §5.3, §9.2). L1 is 2 studs NE of the P-01 pole foot (20, 20), not inside the pole; L3 stands
	-- in front of the Pad bench (58, 58). All face the drawer.
	{ id = "L1", x = 21.5, z = 22, floor = 0.4, faceTo = DRAWER_XZ, node = true },
	{ id = "L2", x = 84, z = 22, floor = 0.4, faceTo = DRAWER_XZ, node = true },
	{ id = "L3", x = 58, z = 56.5, floor = 0.45, faceTo = DRAWER_XZ, node = true }, -- 20.4 from the drawer (>= 20, MAP-01 §14)
	-- ST-R (MAP-01 §9.8): moved from (18, 92), seen from Q5 past the B1 rear corner, to (21, 108) past the curve,
	-- close to the building line X 24 (B1 rear hides it from every Pad / queue point; B5 from the Mart door)
	{ id = "ST-R", x = 21, z = 108, floor = 0.24, face = NORTH, node = true, spawn = "thief", despawn = true },

	-- wave 3 (TASK-098) ----------------------------------------------------------------------
	-- safe spot under the "OPEN 24 HOURS" marquee (MAP-01 §5.2; AnomalyService InZone(p, "SS", 6)); faces the Pad
	{ id = "SS", x = -58, z = 30, floor = 0.4, face = EAST },
	-- anomaly anchors (MAP-01 §10.3). AN-04 / AN-11 / AN-05 at the height of the thing (window, clock, door pane)
	{ id = "AN-04", x = 38, y = 26.3, z = -31, face = SOUTH }, -- WV-2 centre (glass 24.6..28, AST-045)
	{ id = "AN-05", x = 49, y = 7.45, z = 46.5, face = NORTH }, -- back door pane, inside, trailer on the Pad (night pose)
	{ id = "AN-11", x = 39, y = 14, z = -31, face = SOUTH }, -- C-01 clock face (AST-044)
	{ id = "AN-12", x = 70, z = -22, floor = 0.4, face = SOUTH }, -- long car pose: parking entrance mouth, nose south
	-- hidden actor spawns (out of sight of the Pad, the window and the Mart)
	{ id = "AS-1", x = 92, z = -80, floor = 0.02, faceTo = { 41, 40 }, spawn = "actor", despawn = true }, -- behind the van (AST-035 van at AS-1)
	{ id = "AS-2", x = 100, z = 18, floor = 0.4, faceTo = { 41, 40 }, spawn = "actor", despawn = true }, -- behind the TRUCK
	{ id = "AS-3", x = -30, z = -104, floor = 0.4, faceTo = { 41, 40 }, spawn = "actor", despawn = true }, -- beyond BAR-N, west side alley
	{ id = "AS-4", x = -40, z = -36, floor = 0.4, faceTo = { -40, 0 }, spawn = "actor", despawn = true, door = "SP-B" }, -- behind the laundry door
	-- Walker last step (MAP-01 §5.6, fixed, 2026-10-10): south gutter of the Ninth right across from the trailer window,
	-- outside LZ-3 (28 from the trailer centre) and CW-3, off the EB lane (Z 5); steps 0..3 are the posts NL-01..04
	{ id = "WALKER-10", x = 48, z = 14, floor = 0, faceTo = { 41, 35 } },
	-- traffic entries / exits (MAP-01 §5.4), on the road top, facing the travel direction
	{ id = "W-IN", x = -136, z = 5, floor = 0, face = EAST },
	{ id = "W-OUT", x = -136, z = -5, floor = 0, face = WEST },
	{ id = "E-IN", x = 136, z = -5, floor = 0, face = WEST },
	{ id = "E-OUT", x = 136, z = 5, floor = 0, face = EAST },
	{ id = "JN-IN", x = -6, z = -140, floor = 0, face = SOUTH },
	{ id = "JN-OUT", x = 6, z = -140, floor = 0, face = NORTH },
	{ id = "JS-IN", x = 6, z = 116, floor = 0, face = NORTH },
	{ id = "JS-OUT", x = -6, z = 116, floor = 0, face = SOUTH },
	-- opening cutscene (MAP-01 §11.1). Marks = 2 x 2 around CS-1 (columns +-2 of the axis, rows 3 apart), facing east
	{ id = "CutsceneMark1", x = -100, z = -26, floor = 0.4, face = EAST },
	{ id = "CutsceneMark2", x = -100, z = -22, floor = 0.4, face = EAST },
	{ id = "CutsceneMark3", x = -103, z = -26, floor = 0.4, face = EAST },
	{ id = "CutsceneMark4", x = -103, z = -22, floor = 0.4, face = EAST },
	{ id = "CS-1", x = -100, z = -24, floor = 0.4, face = EAST },
	{ id = "CS-2", x = -60, z = -24, floor = 0.4, face = EAST },
	{ id = "CS-3", x = -18, z = -22, floor = 0.4, face = SOUTH }, -- NW corner; CS-3 -> CS-4 runs inside CW-2
	{ id = "CS-4", x = -18, z = 22, floor = 0.4, face = SOUTH }, -- SW corner after CW-2
	{ id = "CS-5", x = 0, z = 38, floor = 0, face = EAST }, -- middle of CW-1
	-- proposal (MAP-01 P46): curb marks so every MoveTo segment stays on the sidewalk or inside the stripes
	{ id = "CS-5W", x = -14, z = 38, floor = 0.24, face = EAST },
	{ id = "CS-5E", x = 14, z = 38, floor = 0.24, face = EAST },
	{ id = "CS-P1", x = 16, z = 25, floor = 0.4, faceTo = { 20, 20 } },
	{ id = "CS-P2", x = 19, z = 27, floor = 0.4, faceTo = { 20, 20 } },
	{ id = "CS-P3", x = 23, z = 26, floor = 0.4, faceTo = { 20, 20 } },
	{ id = "CS-P4", x = 13, z = 22, floor = 0.4, faceTo = { 20, 20 } },
	-- finale (MAP-01 §11.3): party under the marquee facing Walt, Walt from the Mart door, Raincoat Lady on Ninth W
	{ id = "SS-1", x = -54, z = 26, floor = 0.4, face = WEST },
	{ id = "SS-2", x = -52, z = 30, floor = 0.4, face = WEST },
	{ id = "SS-3", x = -54, z = 34, floor = 0.4, face = WEST },
	{ id = "SS-4", x = -56, z = 23, floor = 0.4, face = WEST },
	-- also a pedestrian door (MAP-01 §9.8): shoppers come out of / go into the Mart (24 h)
	{ id = "MKT-DOOR", x = -62, z = 34, floor = 0.4, faceTo = { -60, 30 }, node = true, spawn = "pedestrian", despawn = true, door = "MKT-DOOR" },
	{ id = "WALT-1", x = -60, z = 30, floor = 0.4, face = EAST },
	{ id = "RL-1", x = -100, z = -22, floor = 0.4, face = EAST },
	{ id = "RL-END", x = -76, z = -22, floor = 0.4, face = EAST },

	-- spawn / despawn (MAP-01 §9.8, 2026-10-10, Provisório) ------------------------------------------------------
	-- doors (rule a): the NPC appears / vanishes on the threshold, 0.8 in front of the leaf (resolve = measured on the
	-- placed door model when found; x / z = fallback). The AutoDoor leaf opens for it (W8, client).
	{ id = "DR-APT", x = 32, z = -31, floor = 0.4, face = SOUTH, node = true, spawn = "customer,pedestrian", despawn = true, door = "DR-APT",
		resolve = { mapId = "Z-11", asset = "AST-044_BellmoorSavings", part = "[Dd]oor", out = SOUTH } }, -- bank / apartments door
	{ id = "SP-B", x = -40, z = -31, floor = 0.4, face = SOUTH, node = true, spawn = "pedestrian", despawn = true, door = "SP-B",
		resolve = { mapId = "SP-B", asset = "AST-046_DoorSPB", out = SOUTH } }, -- laundry door (day; MAP-01 §5.3)
	{ id = "DR-B3", x = -93.3, z = -31.2, floor = 0.4, face = SOUTH, node = true, spawn = "pedestrian", despawn = true, door = "DR-B3" }, -- B3b door (NO HELP WANTED glass)
	-- street end (rule b): Juniper South east sidewalk beyond BAR-S, past the curve, against the building line X 24
	{ id = "SP-S", x = 21, z = 100, floor = 0.24, face = NORTH, node = true, spawn = "customer,actor", despawn = true },
}

-- NpcNode-only parts (NodeId = N-<zone>-<nn>, §18.6). crosswalk = the two curb nodes of a crosswalk.
local NODES = {
	-- ROUTE-SP-A: Juniper North east sidewalk (X 18), CW-4, Ninth south sidewalk (LANE-E, Z 23)
	{ id = "N-Z13-01", x = 18, z = -104, floor = 0.24 },
	{ id = "N-Z13-02", x = 18, z = -84, floor = 0.24 },
	{ id = "N-Z07-01", x = 18, z = -62, floor = 0.24 },
	{ id = "N-Z07-02", x = 18, z = -40, floor = 0.24 },
	{ id = "N-Z06-01", x = 18, z = -17, floor = 0.4, crosswalk = "CW-4" },
	{ id = "N-Z02-01", x = 18, z = 17, floor = 0.4, crosswalk = "CW-4" },
	{ id = "N-Z02-02", x = 18, z = 23, floor = 0.4 },
	{ id = "N-Z02-03", x = 26, z = 23, floor = 0.4 }, -- shared by ROUTE-SP-A and ROUTE-D1-IN, last node before Q5
	-- ROUTE-D1-IN: D1 -> Pad east side -> LANE-W (Z 18) -> west -> up to Q5
	{ id = "N-Z01-01", x = 62, z = 33, floor = 0.45 },
	{ id = "N-Z02-06", x = 62, z = 18, floor = 0.4 },
	{ id = "N-Z02-05", x = 44, z = 18, floor = 0.4 },
	{ id = "N-Z02-04", x = 26, z = 18, floor = 0.4 },
	-- ROUTE-EXIT-E: Q1 -> LANE-E -> EX-E
	{ id = "N-Z02-07", x = 55, z = 23, floor = 0.4 },
	{ id = "N-Z02-08", x = 84, z = 23, floor = 0.4 },
	{ id = "N-Z02-09", x = 112, z = 23, floor = 0.4 },
	-- ROUTE-EXIT-D1: Q1 -> east of the cart -> D1
	{ id = "N-Z01-02", x = 58, z = 33, floor = 0.45 },
	{ id = "N-Z01-03", x = 58, z = 47, floor = 0.45 },
	-- wave 2, thief (ROUTE-THIEF): ST-R -> Juniper South east sidewalk (X 18, never crosses a road) -> lurks
	{ id = "N-Z08-01", x = 18, z = 70, floor = 0.24 }, -- passes BAR-S (Z 78): player-only wall (collision group)
	{ id = "N-Z08-02", x = 18, z = 56, floor = 0.24 },
	{ id = "N-Z08-03", x = 18, z = 38, floor = 0.24 },
	{ id = "N-Z01-04", x = 38, z = 56, floor = 0.45 }, -- south strip of the Pad, behind the cart / trailer, to L3
	-- wave 3, sidewalk nodes of Content.WalkPaths (MAP-01 §9.3). Curb nodes 1 stud off the carriageway.
	-- east: north sidewalk of the Ninth in front of the bank, CW-3
	{ id = "N-Z06-02", x = 57, z = -17, floor = 0.4, crosswalk = "CW-3" },
	{ id = "N-Z02-10", x = 57, z = 17, floor = 0.4, crosswalk = "CW-3" },
	{ id = "N-Z06-03", x = 38, z = -22, floor = 0.4 },
	{ id = "N-Z06-04", x = 84, z = -22, floor = 0.4 }, -- passes the parking entrance (AN-12 is night only)
	{ id = "N-Z06-05", x = 110, z = -22, floor = 0.4 }, -- east end (BAR-E), walkers despawn here
	-- CW-1 (the Mart crossing) curb nodes
	{ id = "N-Z08-04", x = 13, z = 38, floor = 0.24, crosswalk = "CW-1" },
	{ id = "N-Z08-05", x = -13, z = 38, floor = 0.24, crosswalk = "CW-1" },
	-- west: plaza, south sidewalk of the Ninth (west), CW-2, north sidewalk (west)
	{ id = "N-Z12-01", x = -34, z = 40, floor = 0.4 },
	{ id = "N-Z12-02", x = -54, z = 30, floor = 0.4 }, -- inside SS (day only for these paths)
	{ id = "N-Z02-11", x = -72, z = 24, floor = 0.4 },
	{ id = "N-Z02-12", x = -108, z = 24, floor = 0.4 }, -- west end (BAR-W)
	{ id = "N-Z02-13", x = -40, z = 22, floor = 0.4 },
	{ id = "N-Z02-14", x = -18, z = 17, floor = 0.4, crosswalk = "CW-2" },
	{ id = "N-Z06-06", x = -18, z = -17, floor = 0.4, crosswalk = "CW-2" },
	{ id = "N-Z06-07", x = -40, z = -22, floor = 0.4 },
	{ id = "N-Z06-08", x = -76, z = -22, floor = 0.4 },
	{ id = "N-Z06-09", x = -108, z = -22, floor = 0.4 }, -- west end (BAR-W); no walk path ends here any more (§9.8)
	-- MAP-01 §9.8: north sidewalk in front of the bank / apartments door (DR-APT)
	{ id = "N-Z06-10", x = 32, z = -22, floor = 0.4 },
}

local EDGES = {
	-- ROUTE-SP-A (SP-A moved to (29, -92), MAP-01 §9.8: straight to N-Z13-02; N-Z13-01 stays as a spare node)
	{ "SP-A", "N-Z13-02" },
	{ "N-Z13-01", "N-Z13-02" },
	{ "N-Z13-02", "N-Z07-01" },
	{ "N-Z07-01", "N-Z07-02" },
	{ "N-Z07-02", "N-Z06-01" },
	{ "N-Z06-01", "N-Z02-01" }, -- CW-4 crosswalk edge (reservation in wave 3; free before)
	{ "N-Z02-01", "N-Z02-02" },
	{ "N-Z02-02", "N-Z02-03" },
	{ "N-Z02-03", "Q5" }, -- arrivals link only to Q5 (§18.6)
	-- ROUTE-D1-IN
	{ "D1", "N-Z01-01" },
	{ "N-Z01-01", "N-Z02-06" },
	{ "N-Z02-06", "N-Z02-05" },
	{ "N-Z02-05", "N-Z02-04" },
	{ "N-Z02-04", "N-Z02-03" },
	-- ROUTE-QUEUE
	{ "Q5", "Q4" },
	{ "Q4", "Q3" },
	{ "Q3", "Q2" },
	{ "Q2", "Q1" },
	-- ROUTE-EXIT-E
	{ "Q1", "N-Z02-07" },
	{ "N-Z02-07", "N-Z02-08" },
	{ "N-Z02-08", "N-Z02-09" },
	{ "N-Z02-09", "EX-E" },
	-- ROUTE-EXIT-D1
	{ "Q1", "N-Z01-02" },
	{ "N-Z01-02", "N-Z01-03" },
	{ "N-Z01-03", "D1" },
	-- wave 2: ROUTE-THIEF (MAP-01 §9.2). L1 by the corner, L2 by LANE-W -> LANE-E, L3 by the Pad's south strip.
	{ "ST-R", "N-Z08-01" },
	{ "N-Z08-01", "N-Z08-02" },
	{ "N-Z08-02", "N-Z08-03" },
	{ "N-Z08-03", "N-Z02-02" },
	{ "N-Z02-02", "L1" },
	{ "N-Z02-06", "N-Z02-08" }, -- LANE-W east end -> L2's post (also L2's flight to EX-E)
	{ "N-Z02-08", "L2" },
	{ "N-Z08-02", "N-Z01-04" },
	{ "N-Z01-04", "L3" },
	-- wave 3: sidewalk network of the pedestrians (Content.WalkPaths). No edge touches a queue slot; the customer
	-- and thief routes of waves 1-2 keep their A* paths (every new way is longer).
	{ "N-Z06-01", "N-Z06-03" },
	{ "N-Z06-03", "N-Z06-02" },
	{ "N-Z06-02", "N-Z02-10" }, -- CW-3 crosswalk edge
	{ "N-Z02-10", "N-Z02-05" },
	{ "N-Z06-02", "N-Z06-04" },
	{ "N-Z06-04", "N-Z06-05" },
	{ "N-Z08-03", "N-Z08-04" },
	{ "N-Z08-04", "N-Z08-05" }, -- CW-1 crosswalk edge
	{ "N-Z08-05", "N-Z12-01" },
	{ "N-Z12-01", "N-Z12-02" },
	{ "N-Z12-02", "N-Z02-11" },
	{ "N-Z02-11", "N-Z02-12" },
	{ "N-Z02-11", "N-Z02-13" },
	{ "N-Z02-13", "N-Z02-14" },
	{ "N-Z02-14", "N-Z08-05" }, -- Juniper South west sidewalk (future SP-B route, MAP-01 §5.3)
	{ "N-Z02-14", "N-Z06-06" }, -- CW-2 crosswalk edge
	{ "N-Z06-06", "N-Z06-07" },
	{ "N-Z06-07", "N-Z06-08" },
	{ "N-Z06-08", "N-Z06-09" },
	-- MAP-01 §9.8 spawn / despawn points
	{ "DR-APT", "N-Z06-10" }, -- ROUTE-DR-APT: door -> sidewalk -> CW-4 curb (N-Z06-01) -> CW-4 -> ... -> Q5
	{ "N-Z06-10", "N-Z06-01" },
	{ "N-Z06-10", "N-Z06-03" },
	{ "SP-S", "N-Z08-01" }, -- ROUTE-SP-S: Juniper South east sidewalk (same as the thief's, never crosses a road)
	{ "N-Z02-10", "N-Z02-06" }, -- CW-3 south curb -> LANE-W east end (walkers to the EX-E alley)
	{ "SP-B", "N-Z06-07" }, -- laundry door
	{ "DR-B3", "N-Z06-08" }, -- B3b door
	{ "MKT-DOOR", "N-Z12-02" }, -- Mart door -> SS rim -> plaza / south sidewalk
}

-- Ingredient key -> .fbx suffix (PascalCase rule of §18.4) and MAP-01 §7.1 grid cell (fallback XZ, cart coords).
-- x, z are used ONLY when the real bowl Bin_<Suf> is missing (see bindToppings: anchors live on the bowls).
local TOPPINGS = {
	{ key = "ketchup", suf = "Ketchup", x = 45, z = 36.5 },
	{ key = "mustard", suf = "Mustard", x = 47, z = 36.5 },
	{ key = "cheese", suf = "Cheese", x = 49, z = 36.5 },
	{ key = "bacon", suf = "Bacon", x = 45, z = 38.5 },
	{ key = "potato_sticks", suf = "PotatoSticks", x = 47, z = 38.5 },
	{ key = "cream_cheese", suf = "CreamCheese", x = 49, z = 38.5 },
}

-- Mart shelf purchase points (MAP-01 §7.4), anchor ~4.5 above the floor (0.4).
local SHELVES = {
	{ name = "Sausages", package = "pack_sausages", x = -69, z = 40 },
	{ name = "Buns", package = "pack_buns", x = -69, z = 44 },
	{ name = "Ketchup", package = "pack_ketchup", x = -75, z = 40 },
	{ name = "Mustard", package = "pack_mustard", x = -75, z = 44 },
	{ name = "Cheese", package = "pack_cheese", x = -81, z = 40 },
	{ name = "Bacon", package = "pack_bacon", x = -81, z = 44 },
	{ name = "PotatoSticks", package = "pack_potato_sticks", x = -75, z = 48 },
	{ name = "CreamCheese", package = "pack_cream_cheese", x = -81, z = 48 },
	{ name = "Coffee", package = "pack_coffee", x = -68, z = 35 },
}
local MART_FLOOR = 0.4
local SHELF_ANCHOR_H = 4.5

-- GEAR WALL (AST-049) prompts (MAP-01 §7.4): bench X -100..-98, top 3.5 above the Mart floor.
local BENCH = {
	{ slot = "B1", action = "bench_buy_upgrade", z = 40.5 },
	{ slot = "B2", action = "bench_buy_upgrade", z = 43.5 },
	{ slot = "S1", action = "bench_buy_item", z = 46.5 },
	{ slot = "B3", action = "bench_buy_upgrade", z = 49.5 },
	{ slot = "B4", action = "bench_buy_upgrade", z = 52.5 },
	{ slot = "B5", action = "bench_buy_upgrade", z = 55.5 },
}

-- Street lights of the Hush / Walker chain (MAP-01 §5.6, 2026-10-10: 4 posts on the Ninth north curb, seen from the
-- trailer window, user's request). Order = Hush order (NL-01 farthest first, P-01 last). Walker: step = Order - 1 for
-- Order 1..4 (NL-01..NL-04), step 4 = WALKER-10; P-01 (Order 5) is only the Hush's corner post.
local POSTS = {
	{ id = "NL-01", order = 1 },
	{ id = "NL-02", order = 2 },
	{ id = "NL-03", order = 3 },
	{ id = "NL-04", order = 4 },
	{ id = "P-01", order = 5 },
}
-- blockout posts that no longer carry the chain: their SpotLight is switched off (W: Walker posts). The Juniper keeps
-- two decorative posts (no light, no tag); Post_NinthN_E1 left the Ninth north curb (it stood among the NL posts).
local RETIRED_POSTS = { "JL-01", "JL-02", "JL-03", "JL-04", "JL-05", "JL-06", "JL-07", "JL-08", "JL-09", "Post_NinthN_E1" }
local POST_GROUP = "juniper_posts" -- Content.LightGroups (content-data.md §6.4); visual only, no volume (DEC-196)

-- Light volumes (MAP-01 §10.2). Trailer zones are given in the trailer's Pad frame (offset from TRL_POSE), the
-- others in world coords. Block: centre + size; Ball: centre + radius (centre at standing-HRP height).
local ZONES = {
	{ id = "LZ-1", group = "trailer_interior", shape = "Block", local_ = Vector3.new(0, 6.25, 0), size = Vector3.new(26, 8.5, 10) }, -- X 27..53, Z 36..46, floor 2.45 .. ceiling 10.95
	{ id = "LZ-2", group = "trailer_interior", shape = "Block", local_ = Vector3.new(10, 4.75, -8.5), size = Vector3.new(12, 9.5, 5) }, -- porch X 44..56, Z 30..35 (Q1)
	{ id = "LZ-3", group = "trailer_lights", shape = "Ball", local_ = Vector3.new(0, 3, 0), radius = 18 }, -- Trailer Lights (40, 41) r 18 (LightRadius)
	{ id = "LZ-4", group = "mart", shape = "Block", world = Vector3.new(-82, 6.4, 48), size = Vector3.new(36, 12, 32) }, -- Mart X -100..-64, Z 32..64
	{ id = "LZ-5", group = "mart", shape = "Ball", world = Vector3.new(-58, 3.4, 30), radius = 6 }, -- SS under the marquee
}

-- Wave 3 -----------------------------------------------------------------------------------------

-- Service window (DEC-221, TASK-132; MAP-01 §7.2, P51). Offsets in the trailer's Pad frame (from TRL_POSE, facing
-- north: local -Z = out of the window). Floor at +2 over the pivot; window X 30..53 (22.5 wide, AST-027), sill 3.5
-- and top 8 over the floor; north wall outer face at local Z -6 (hull Z 35..47).
local SHUTTER_ID = "TRL-SHUTTER"
local SHUTTER_BUTTON_X = 43.4 -- world X with the trailer on the Pad: 2.6 west of TRL-SWITCH (X 46)
local SHUTTER_BUTTON_FALLBACK = Vector3.new(3.4, 6.4, 5.1) -- Pad frame, used when TRL-SWITCH is missing
local SHUTTER_BUTTON_SIZE = Vector3.new(0.5, 0.7, 0.15) -- placeholder plate until the art sheet exists (P51)
local SHUTTER_BUTTON_COLOR = Color3.fromRGB(246, 193, 43) -- Mustard #F6C12B (style guide: interactive accent)
local SHUTTER_PROMPT_OUT = 0.3 -- Prompt_Shutter in front of the plate (corridor side), like Prompt_Switch
local SHUTTER_GAP = 2.6 -- >= this from anchors of other owners in the trailer (§18.7 item 4 + margin, like the phone)
local WINDOW_LOCAL = { x0 = -9.75, x1 = 12.75, sill = 5.5, top = 10.0, wallZ = -6 } -- X 30.25..52.75 on the Pad
local AWNING_TOL = 0.3 -- slack when deciding whether the Awning covers the window
local SHUTTER_PANEL_SIZE = Vector3.new(22.5, 4.6, 0.2)
local SHUTTER_PANEL_COLOR = Color3.fromRGB(198, 204, 210) -- Aluminum mid (#E3E7EB -> #A9B1B9)

-- Apartment windows (AST-045 Window_Up_<n>, MAP-01 §5.2 / §10.3). Fallback Part when the asset lacks them.
local WINDOWS = {
	{ id = "WV-1", n = 1, x = 31 },
	{ id = "WV-2", n = 2, x = 38 },
	{ id = "WV-3", n = 3, x = 45 },
}
local WINDOW_Y, WINDOW_Z = 26.3, -32.2 -- glass 24.6..28 (AST-045, Em revisão); facade at Z -32 (MAP-01)

-- Traffic (MAP-01 §5.4, §9.5; architecture.md §8.1; Content.Traffic). Lanes: Ninth EB Z 5, WB Z -5; Juniper SB
-- X -6, NB X 6. Turns are 2-3 corner nodes inside the X-T box. Path = Content.Traffic.Routes[].Path (= Key).
local TRAFFIC_ROUTES = {
	{ id = "TR-1", pts = { { -136, 5 }, { -12, 5 }, { 12, 5 }, { 136, 5 } } }, -- W-IN -> E-OUT
	{ id = "TR-2", pts = { { 136, -5 }, { 12, -5 }, { -12, -5 }, { -136, -5 } } }, -- E-IN -> W-OUT
	{ id = "TR-3", pts = { { -6, -140 }, { -6, -16 }, { -4, -6 }, { 2, 2 }, { 12, 5 }, { 136, 5 } } }, -- JN-IN -> left -> E-OUT
	{ id = "TR-4", pts = { { -6, -140 }, { -6, -16 }, { -7.5, -9 }, { -12, -5 }, { -136, -5 } } }, -- JN-IN -> right -> W-OUT
	{ id = "TR-5", pts = { { -136, 5 }, { -12, 5 }, { -2, 2 }, { 4, -6 }, { 6, -16 }, { 6, -140 } } }, -- W-IN -> left -> JN-OUT
	{ id = "TR-6", pts = { { 136, -5 }, { 12, -5 }, { 8, -9 }, { 6, -16 }, { 6, -140 } } }, -- E-IN -> right -> JN-OUT
	{ id = "TR-7", pts = { { 6, 116 }, { 6, 16 }, { 6, -16 }, { 6, -140 } } }, -- JS-IN -> straight -> JN-OUT
	{ id = "TR-8", pts = { { -6, -140 }, { -6, -16 }, { -6, 16 }, { -6, 116 } } }, -- JN-IN -> straight -> JS-OUT
	{ id = "TR-9", pts = { { -136, 5 }, { -12, 5 }, { -8, 9 }, { -6, 16 }, { -6, 116 } } }, -- W-IN -> right -> JS-OUT
	{ id = "TR-10", pts = { { 6, 116 }, { 6, 16 }, { 8, 9 }, { 12, 5 }, { 136, 5 } } }, -- JS-IN -> right -> E-OUT
}
-- Stop lines: centre (x, z), width across the lane(s), dir = travel direction of the lane that stops there.
local TRAFFIC_LINES = {
	{ id = "SL-N", x = -6, z = -20, width = 12, dir = SOUTH }, -- PARE, Juniper SB
	{ id = "SL-S", x = 6, z = 20, width = 12, dir = NORTH }, -- PARE, Juniper NB
	{ id = "SL-W", x = -28, z = 8, width = 16, dir = EAST }, -- CW-2 / CW-4, Ninth EB
	{ id = "SL-E", x = 28, z = -8, width = 16, dir = WEST }, -- CW-2 / CW-4, Ninth WB
	{ id = "SL-1N", x = -6, z = 30, width = 12, dir = SOUTH }, -- CW-1, Juniper South SB
	{ id = "SL-1S", x = 6, z = 46, width = 12, dir = NORTH }, -- CW-1, Juniper South NB
	{ id = "SL-3W", x = 50, z = 8, width = 16, dir = EAST }, -- CW-3, Ninth EB
	{ id = "SL-3E", x = 64, z = -8, width = 16, dir = WEST }, -- CW-3, Ninth WB
}
-- Boxes: X0..X1, Z0..Z1 (MAP-01 §5.2 crosswalk stripes; X-T = the carriageway square of the crossing).
local TRAFFIC_BOXES = {
	{ id = "X-T", x0 = -12, x1 = 12, z0 = -16, z1 = 16 },
	{ id = "CW-1", x0 = -12, x1 = 12, z0 = 34, z1 = 42 },
	{ id = "CW-2", x0 = -24, x1 = -12, z0 = -16, z1 = 16 },
	{ id = "CW-3", x0 = 54, x1 = 60, z0 = -16, z1 = 16 },
	{ id = "CW-4", x0 = 12, x1 = 24, z0 = -16, z1 = 16 },
}
local TRAFFIC_BOX_H = 10
local ROAD_Y = 0 -- carriageway top (blockout Y_ROAD); the raycast result wins when within 0.6

-- Grill (AST-012): the .fbx has 6 slot empties; DEC-201 uses 4 (L1 1-2, L2 1-3, L3 1-4). Pick = the 4 central
-- ones after sorting left -> right as seen from the corridor (+X). Same positions at every level (no Level attr).
local GRILL_SLOTS = 4
local GRILL_FALLBACK_DX = { -1.35, -0.45, 0.45, 1.35 } -- 0.9 between centres (asset-list AST-012)
local BUN_SLOT_STEP = 1.1 -- board slots along Att_Bun local X (cart 2: -/+0.55; trailer 3: -1.1, 0, +1.1)
local PHONE_GAP = 2.6 -- phone prompt >= this from anchors of other owners in the same vehicle (§18.7 item 4 + margin)

-- Tarp placeholder (AST-043: 26 x 4 x 4, Mint-gray #B7CFC6; DEC-199). Replaced when the model exists (TASK-088).
local COVER_COLOR = Color3.fromRGB(183, 207, 198)

---------------------------------------------------------------------------------------------------
-- Report
---------------------------------------------------------------------------------------------------

local report: { string } = {}
local counts = { ok = 0, new = 0, conv = 0, warn = 0, err = 0 }

local function log(kind: string, msg: string)
	counts[kind] = (counts[kind] or 0) + 1
	table.insert(report, ("[%s] %s"):format(kind, msg))
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

local function fmtV(v: Vector3): string
	return ("(%.2f, %.2f, %.2f)"):format(v.X, v.Y, v.Z)
end

-- WORLD position of an anchor (distances only; use mapPos for anything that reads an axis)
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

-- MAP-01 position of an anchor
local function mapPos(a: Instance): Vector3
	return M(anchorPos(a))
end

-- MAP-01 pivot of a model / part
local function mapPivot(m: Instance): CFrame
	return MCF((m :: any):GetPivot() :: CFrame)
end

local function setPersistent(m: Instance)
	if m:IsA("Model") and m.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
end

local function makeInvisible(p: BasePart)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Anchored = true
end

-- First model under `root` with MapId = id (and Asset = asset, if given).
local function byMapId(root: Instance, id: string, asset: string?): Instance?
	for _, d in root:GetDescendants() do
		if d:GetAttribute("MapId") == id and (asset == nil or d:GetAttribute("Asset") == asset) then
			return d
		end
	end
	return nil
end

-- Descendant by name; prefers an Attachment when several share the name.
local function findNamed(model: Instance, name: string): Instance?
	local first: Instance? = nil
	for _, d in model:GetDescendants() do
		if d.Name == name then
			if d:IsA("Attachment") then
				return d
			end
			first = first or d
		end
	end
	return first
end

-- BasePart that hosts created Attachments: PrimaryPart, else the largest BasePart (name breaks ties).
local function hostPart(model: Instance): BasePart?
	if model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart
	end
	if model:IsA("BasePart") then
		return model
	end
	local best: BasePart? = nil
	local bestV = -1
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestV or (v == bestV and best and d.Name < best.Name) then
				best, bestV = d, v
			end
		end
	end
	return best
end

-- Bounding box (MAP-01 axes) of the visible BaseParts of `model` that pass `keep` (all when nil): min, max.
local function partsBox(model: Instance, keep: ((BasePart) -> boolean)?): (Vector3?, Vector3?)
	local mn, mx = nil, nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and (keep == nil or keep(d)) then
			local cf, s = d.CFrame, d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = M(cf:PointToWorldSpace(Vector3.new(s.X * sx, s.Y * sy, s.Z * sz)))
						mn = if mn then mn:Min(p) else p
						mx = if mx then mx:Max(p) else p
					end
				end
			end
		end
	end
	return mn, mx
end

local function topY(model: Instance, default: number?): number
	local _, mx = partsBox(model)
	return if mx then mx.Y else (default or COUNTER_Y)
end

-- `pos` in MAP-01 coordinates
local function newAttachment(host: BasePart, name: string, pos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = host
	a.WorldCFrame = FCF(CFrame.new(pos))
	a:SetAttribute(CREATED, true)
	return a
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

type AnchorOpts = { resetCreated: boolean? }

-- Finds or creates the anchor `name` inside `model`. fallback() = MAP-01 position used when it must be created.
local function ensureAnchor(model: Instance, name: string, fallback: () -> Vector3, opts: AnchorOpts, label: string): Instance?
	local found = findNamed(model, name)
	if found then
		if found:IsA("Attachment") then
			if found:GetAttribute(CREATED) then
				if opts.resetCreated then
					found.WorldCFrame = FCF(CFrame.new(fallback()))
				end
				log("new", ("%s: %s kept (created by binding) at %s"):format(label, name, fmtV(found.WorldPosition)))
			else
				log("ok", ("%s: %s (Attachment from .fbx) at %s"):format(label, name, fmtV(found.WorldPosition)))
			end
			return found
		elseif found:IsA("BasePart") then
			makeInvisible(found)
			log("ok", ("%s: %s is a BasePart, used as anchor (made invisible) at %s"):format(label, name, fmtV(found.Position)))
			return found
		else
			local host = hostPart(model)
			if not host then
				log("err", ("%s: %s exists as %s and the model has no BasePart to host an Attachment"):format(label, name, found.ClassName))
				return nil
			end
			local pos = if found:IsA("PVInstance") then mapPivot(found).Position else fallback()
			found.Name = name .. "_Src"
			local a = newAttachment(host, name, pos)
			log("conv", ("%s: %s came as %s -> Attachment created at its pivot %s (original renamed %s_Src)"):format(label, name, found.ClassName, fmtV(pos), name))
			return a
		end
	end
	local host = hostPart(model)
	if not host then
		log("err", ("%s: %s missing and the model has no BasePart to host it"):format(label, name))
		return nil
	end
	local a = newAttachment(host, name, fallback())
	log("new", ("%s: %s not in the .fbx -> created at %s (fallback, verify in Studio)"):format(label, name, fmtV(a.WorldPosition)))
	return a
end

local function interactable(anchor: Instance?, action: string, attrs: { [string]: any }?)
	if not anchor then
		return
	end
	CollectionService:AddTag(anchor, "Interactable")
	anchor:SetAttribute("PromptAction", action)
	if attrs then
		for k, v in attrs do
			anchor:SetAttribute(k, v)
		end
	end
end

-- Floor height under MAP-01 (x, z) by raycast; returns expected when the hit is missing or too far from it.
local function floorY(x: number, z: number, expected: number, exclude: { Instance }): (number, string?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = table.clone(exclude)
	for _ = 1, 16 do
		params.FilterDescendantsInstances = ex
		local hit = Workspace:Raycast(F(Vector3.new(x, expected + 3, z)), Vector3.new(0, -6, 0), params)
		if not hit then
			return expected, "no floor hit, used expected Y"
		end
		local p = hit.Instance
		if p:IsA("BasePart") and p.CanCollide then
			if math.abs(hit.Position.Y - expected) <= 0.6 then
				return hit.Position.Y, nil
			end
			return expected, ("hit %s at Y %.2f (expected %.2f), used expected Y"):format(p:GetFullName(), hit.Position.Y, expected)
		end
		table.insert(ex, p)
	end
	return expected, "too many non-colliding hits, used expected Y"
end

-- Pushes an Attachment anchor up until it is >= gap from every anchor of another owner inside `vehicle`.
local function clearUp(anchor: Instance?, vehicle: Instance, gap: number, label: string)
	if not (anchor and anchor:IsA("Attachment")) then
		if anchor then
			log("warn", ("%s: %s is not an Attachment, clearance not applied"):format(label, anchor.Name))
		end
		return
	end
	local own = ownerOf(anchor)
	local function closest(): (number, string)
		local best, who = math.huge, "-"
		for _, o in CollectionService:GetTagged("Interactable") do
			if o ~= anchor and o:IsDescendantOf(vehicle) and ownerOf(o) ~= own then
				local d = (anchorPos(o) - anchor.WorldPosition).Magnitude
				if d < best then
					best, who = d, o.Name
				end
			end
		end
		return best, who
	end
	local steps = 0
	local d, who = closest()
	while d < gap and steps < 40 do
		anchor.WorldCFrame = anchor.WorldCFrame + Vector3.new(0, 0.1, 0)
		steps += 1
		d, who = closest()
	end
	if d < gap then
		log("warn", ("%s: %s still %.2f from %s after +4.0 (move it by hand)"):format(label, anchor.Name, d, who))
	elseif steps > 0 then
		log("new", ("%s: %s raised %.1f to clear the counter prompts (closest %s at %.2f)"):format(label, anchor.Name, steps * 0.1, who, d))
	else
		log("ok", ("%s: %s clear of other prompts (closest %s at %.2f)"):format(label, anchor.Name, who, d))
	end
end

-- Closest Interactable of another owner inside `vehicle` (distance, name).
local function closestOther(anchor: Instance, vehicle: Instance): (number, string)
	local own = ownerOf(anchor)
	local best, who = math.huge, "-"
	for _, o in CollectionService:GetTagged("Interactable") do
		if o ~= anchor and o:IsDescendantOf(vehicle) and ownerOf(o) ~= own then
			local d = (anchorPos(o) - anchorPos(anchor)).Magnitude
			if d < best then
				best, who = d, o.Name
			end
		end
	end
	return best, who
end

---------------------------------------------------------------------------------------------------
-- Steps
---------------------------------------------------------------------------------------------------

-- Both layers in the Workspace (T36). Returns how many folders were moved.
local function mergeLayers(assets: Instance): number
	local moved = 0
	local function bring(f: Instance)
		local same = assets:FindFirstChild(f.Name)
		if same and same ~= f then
			for _, c in f:GetChildren() do
				c.Parent = same
			end
			f:Destroy()
		else
			f.Parent = assets
		end
		moved += 1
	end
	local night = ServerStorage:FindFirstChild(ASSETS_ROOT .. "_Night")
	if night then
		for _, f in night:GetChildren() do
			bring(f)
		end
	end
	local day = ServerStorage:FindFirstChild(ASSETS_ROOT .. "_Day")
	if day then
		for _, f in day:GetChildren() do
			bring(f)
		end
	end
	return moved
end

-- Undo of bind_pieces.luau (TASK-085), same attributes as its Pieces.undo: keep both in sync.
-- Clones (PieceClone) are destroyed; fixed parts hidden there (PieceFixed) get name and visuals back.
local PIECE_ORIG = { "PieceFixed", "PieceOrigName", "PieceOrigTransparency", "PieceOrigCanCollide", "PieceOrigCanQuery", "PieceOrigCanTouch", "PieceOrigCastShadow", "PieceOrigEnabled" }
local function unbindPieces(root: Instance)
	local clones, fixed = {}, {}
	for _, d in root:GetDescendants() do
		if d:GetAttribute("PieceClone") then
			table.insert(clones, d)
		elseif d:GetAttribute("PieceFixed") then
			table.insert(fixed, d)
		end
	end
	local n = 0
	for _, c in clones do
		if CollectionService:HasTag(c, "UpgradePiece") then
			n += 1
		end
	end
	for _, c in clones do
		c:Destroy()
	end
	for _, f in fixed do
		if f:IsA("BasePart") then
			local name = f:GetAttribute("PieceOrigName")
			if typeof(name) == "string" then
				f.Name = name
			end
			local t = f:GetAttribute("PieceOrigTransparency")
			f.Transparency = if typeof(t) == "number" then t else 0
			f.CanCollide = f:GetAttribute("PieceOrigCanCollide") ~= false
			f.CanQuery = f:GetAttribute("PieceOrigCanQuery") ~= false
			f.CanTouch = f:GetAttribute("PieceOrigCanTouch") ~= false
			f.CastShadow = f:GetAttribute("PieceOrigCastShadow") ~= false
		elseif f:IsA("Decal") or f:IsA("Texture") then
			local t = f:GetAttribute("PieceOrigTransparency")
			f.Transparency = if typeof(t) == "number" then t else 0
		elseif f:IsA("Light") or f:IsA("SurfaceGui") or f:IsA("BillboardGui") then
			f.Enabled = f:GetAttribute("PieceOrigEnabled") ~= false
		end
		for _, a in PIECE_ORIG do
			f:SetAttribute(a, nil)
		end
	end
	log("ok", ("upgrade pieces undone: %d UpgradePiece clone(s) destroyed, %d fixed instance(s) restored (run bind_pieces.luau after this bind)"):format(n, #fixed))
end

local function cleanSlate(root: Instance)
	local n = 0
	for _, d in root:GetDescendants() do
		for _, t in OWN_TAGS do
			if CollectionService:HasTag(d, t) then
				CollectionService:RemoveTag(d, t)
				n += 1
			end
		end
		for _, a in AUTHORED_ATTRS do
			if d:GetAttribute(a) ~= nil then
				d:SetAttribute(a, nil)
			end
		end
	end
	log("ok", ("clean slate: %d old tag(s) removed under %s"):format(n, root.Name))
end

-- Grill: pick 4 of the slot empties (Att_SlotN / SlotN), or create fallbacks.
local function bindGrill(model: Instance, opts: AnchorOpts, label: string)
	local src, created = {}, {}
	for _, d in model:GetDescendants() do
		local n = d:GetAttribute(SRC_NAME) or d.Name
		if typeof(n) == "string" and (string.match(n, "^Att_Slot%d+$") or string.match(n, "^Slot%d+$")) then
			if d:GetAttribute(CREATED) then
				table.insert(created, d)
			elseif d:IsA("Attachment") or d:IsA("BasePart") then
				table.insert(src, d)
			end
		end
	end
	if #src >= GRILL_SLOTS then
		for _, c in created do
			c:Destroy()
		end
		local minP, maxP = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, d in src do
			local p = mapPos(d)
			minP, maxP = minP:Min(p), maxP:Max(p)
		end
		local alongX = (maxP.X - minP.X) >= (maxP.Z - minP.Z)
		table.sort(src, function(a, b)
			local pa, pb = mapPos(a), mapPos(b)
			if alongX then
				if math.abs(pa.X - pb.X) > 1e-3 then
					return pa.X < pb.X
				end
				return pa.Z < pb.Z
			end
			if math.abs(pa.Z - pb.Z) > 1e-3 then
				return pa.Z < pb.Z
			end
			return pa.X < pb.X
		end)
		local first = math.floor((#src - GRILL_SLOTS) / 2) + 1
		local spare = 0
		for i, d in src do
			if d:GetAttribute(SRC_NAME) == nil then
				d:SetAttribute(SRC_NAME, d.Name)
			end
			if d:IsA("BasePart") then
				makeInvisible(d)
			end
			local slot = i - first + 1
			if slot >= 1 and slot <= GRILL_SLOTS then
				d.Name = "Att_Slot" .. slot
				interactable(d, "grill_collect", { Slot = slot })
				log("ok", ("%s: %s (.fbx %s) -> Slot %d at %s"):format(label, d.Name, tostring(d:GetAttribute(SRC_NAME)), slot, fmtV(anchorPos(d))))
			else
				spare += 1
				d.Name = "Att_SlotSpare" .. spare
			end
		end
		if not alongX then
			log("warn", label .. ": slot empties spread along Z, not X; ordered north -> south. Check the slot order")
		end
		log("ok", ("%s: %d slot empties found, central %d used (DEC-201), %d spare left untagged"):format(label, #src, GRILL_SLOTS, spare))
		return
	end
	if #src > 0 then
		log("warn", ("%s: only %d slot empties found (need %d); using fallback slots"):format(label, #src, GRILL_SLOTS))
	end
	local host = hostPart(model)
	if not host then
		log("err", label .. ": no BasePart to host slot Attachments")
		return
	end
	local mn, mx = partsBox(model)
	local centre = if mn and mx then (mn + mx) / 2 else mapPivot(model).Position
	local top = if mx then mx.Y else COUNTER_Y
	for slot = 1, GRILL_SLOTS do
		local name = "Att_Slot" .. slot
		local existing: Instance? = nil
		for _, c in created do
			if c.Name == name then
				existing = c
			end
		end
		local pos = Vector3.new(centre.X + GRILL_FALLBACK_DX[slot], top + 0.2, centre.Z)
		local a: Instance
		if existing then
			a = existing
			if opts.resetCreated and a:IsA("Attachment") then
				a.WorldCFrame = FCF(CFrame.new(pos))
			end
		else
			a = newAttachment(host, name, pos)
		end
		interactable(a, "grill_collect", { Slot = slot })
		log("new", ("%s: %s fallback -> Slot %d at %s (verify on the rollers)"):format(label, name, slot, fmtV(anchorPos(a))))
	end
end

--[[ Rail: Slot1..n (or Att_Slot1..n) get Slot = k; missing numbers are created along the rail.
	mode "first" (cart, wave 1, unchanged): when a number has duplicates (Rail_6 and Rail_8 empties), the first one.
	mode "ideal" (trailer, Rail_8): the duplicate closest to the evenly spaced position along the visible rail. ]]
local function bindRail(model: Instance, opts: AnchorOpts, n: number, label: string, mode: string)
	local byNum: { [number]: { Instance } } = {}
	for _, d in model:GetDescendants() do
		local num = string.match(d.Name, "^Slot(%d+)$") or string.match(d.Name, "^Att_Slot(%d+)$")
		if num and (d:IsA("Attachment") or d:IsA("BasePart")) then
			local k = tonumber(num) :: number
			byNum[k] = byNum[k] or {}
			table.insert(byNum[k], d)
		end
	end
	local mn, mx = partsBox(model)
	local centre = if mn and mx then (mn + mx) / 2 else mapPivot(model).Position
	local top = if mx then mx.Y else COUNTER_Y + 0.5
	local alongX = if mn and mx then (mx.X - mn.X) >= (mx.Z - mn.Z) else true
	local function ideal(slot: number): Vector3
		if mode == "first" or not (mn and mx) then
			return Vector3.new(centre.X - 1 + 0.4 * (slot - 1), top, centre.Z)
		end
		local len = if alongX then mx.X - mn.X else mx.Z - mn.Z
		local step = len * 0.8 / math.max(n - 1, 1)
		local off = -len * 0.4 + step * (slot - 1)
		return if alongX then Vector3.new(centre.X + off, top, centre.Z) else Vector3.new(centre.X, top, centre.Z + off)
	end
	local host = hostPart(model)
	for slot = 1, n do
		local list = byNum[slot]
		local a: Instance? = nil
		if list and #list > 0 then
			a = list[1]
			if #list > 1 then
				if mode == "ideal" then
					local want = ideal(slot)
					local best = math.huge
					for _, c in list do
						local d = (mapPos(c) - want).Magnitude
						if d < best then
							a, best = c, d
						end
					end
				end
				log("warn", ("%s: %d instances named Slot%d (Rail_6 and Rail_8 empties?); used %s"):format(label, #list, slot, (a :: Instance):GetFullName()))
			end
			if a and a:IsA("BasePart") then
				makeInvisible(a)
			end
			if a and a:GetAttribute(CREATED) and opts.resetCreated and a:IsA("Attachment") then
				a.WorldCFrame = FCF(CFrame.new(ideal(slot)))
			end
		elseif host then
			a = newAttachment(host, "Slot" .. slot, ideal(slot))
		end
		if a then
			a:SetAttribute("Slot", slot)
			log(if a:GetAttribute(CREATED) then "new" else "ok", ("%s: %s -> Slot %d at %s"):format(label, a.Name, slot, fmtV(anchorPos(a))))
		else
			log("err", ("%s: cannot create Slot%d (no BasePart)"):format(label, slot))
		end
	end
	if findNamed(model, "Prompt_Rail") then
		log("ok", label .. ": Prompt_Rail left WITHOUT tag (Add Sausage is on the board, §18.4)")
	end
end

-- Board: Att_Bun -> Att_Bun1..n (Slot 1 = the one more to the west; DEC-190 cart 2, DEC-215 trailer 3).
local function bindBoard(model: Instance, opts: AnchorOpts, n: number, label: string)
	local mn, mx = partsBox(model)
	local centre = if mn and mx then (mn + mx) / 2 else mapPivot(model).Position
	local top = if mx then mx.Y else COUNTER_Y + 0.2
	local base = ensureAnchor(model, "Att_Bun", function()
		return Vector3.new(centre.X, top + 0.05, centre.Z)
	end, opts, label)
	if not base then
		return
	end
	local baseCF = MCF(if base:IsA("Attachment") then base.WorldCFrame else (base :: BasePart).CFrame) -- MAP-01
	local host = if base:IsA("Attachment") then base.Parent :: BasePart else hostPart(model)
	local list: { Vector3 } = {}
	for i = 1, n do
		local off = (i - (n + 1) / 2) * BUN_SLOT_STEP
		table.insert(list, (baseCF * CFrame.new(off, 0, 0)).Position)
	end
	table.sort(list, function(a, b)
		return a.X < b.X
	end)
	for slot, pos in list do
		local name = "Att_Bun" .. slot
		local a = findNamed(model, name)
		if a and a:IsA("Attachment") then
			if a:GetAttribute(CREATED) and opts.resetCreated then
				a.WorldCFrame = FCF(CFrame.new(pos) * baseCF.Rotation)
			end
		elseif host then
			a = newAttachment(host :: BasePart, name, pos)
			;(a :: Attachment).WorldCFrame = FCF(CFrame.new(pos) * baseCF.Rotation)
		end
		if a then
			a:SetAttribute("Slot", slot)
			log(if a:GetAttribute(CREATED) then "new" else "ok", ("%s: %s -> Slot %d at %s (shared slot)"):format(label, name, slot, fmtV(anchorPos(a))))
		end
	end
end

--[[ Toppings grid (AST-017, bowls of DEC-156). Anchors sit on the REAL bowl of each ingredient (MeshPart
	Bin_<Suf>), parented to it, and are always re-derived from it on every run.
	The two real rows are 1.5 apart in Z (operator row low, back row 0.3 higher), under the 2.0 of §18.7 item 4.
	Fix without changing any game rule: the anchors of each row are pushed OUT of the grid so the billboards are
	>= 2.0 apart: operator row -> towards the corridor (+Z) and slightly up; back row -> straight up.
	Use and Restock of the same bowl share the position (one action visible at a time). ]]
local TOPPING_OPERATOR_OFFSET = Vector3.new(0, 0.35, 0.4)
local TOPPING_BACK_OFFSET = Vector3.new(0, 1.25, 0)
local TOPPING_MIN_GAP = 2.05 -- back row is raised further if the measured rows still end up closer than this

local function bindToppings(model: Instance, opts: AnchorOpts, label: string, delta: Vector3)
	local bins: { [string]: BasePart } = {}
	local zs: { number } = {}
	for _, t in TOPPINGS do
		local b = findNamed(model, "Bin_" .. t.suf)
		if b and b:IsA("BasePart") then
			bins[t.key] = b
			table.insert(zs, M(b.Position).Z)
		else
			log("err", ("%s: bowl Bin_%s not found (MeshPart of AST-017): anchor falls back to MAP-01 §7.1"):format(label, t.suf))
		end
	end
	-- operator row = the bowls nearest the corridor (largest Z, operator faces north)
	local maxZ, minZ = -math.huge, math.huge
	for _, z in zs do
		maxZ, minZ = math.max(maxZ, z), math.min(minZ, z)
	end
	local splitZ = (maxZ + minZ) / 2

	local wanted: { [string]: Vector3 } = {}
	for _, t in TOPPINGS do
		local b = bins[t.key]
		if b then
			local bm = M(b.Position)
			local isOperator = bm.Z >= splitZ
			wanted[t.key] = bm + (if isOperator then TOPPING_OPERATOR_OFFSET else TOPPING_BACK_OFFSET)
		else
			wanted[t.key] = Vector3.new(t.x + delta.X, topY(model) + 0.3, t.z + delta.Z)
		end
	end
	-- safety: raise the back row until every pair of different bowls is >= TOPPING_MIN_GAP apart
	for _ = 1, 20 do
		local worst = math.huge
		for _, a in TOPPINGS do
			for _, c in TOPPINGS do
				local ba, bc = bins[a.key], bins[c.key]
				-- only pairs across the two rows (same-row spacing is the model's, 2.0 between bowls)
				if ba and bc and (M(ba.Position).Z >= splitZ) ~= (M(bc.Position).Z >= splitZ) then
					worst = math.min(worst, (wanted[a.key] - wanted[c.key]).Magnitude)
				end
			end
		end
		if worst >= TOPPING_MIN_GAP then
			break
		end
		for _, t in TOPPINGS do
			local b = bins[t.key]
			if b and M(b.Position).Z < splitZ then
				wanted[t.key] += Vector3.new(0, 0.1, 0)
			end
		end
	end

	for _, t in TOPPINGS do
		local p = wanted[t.key]
		local host: BasePart? = bins[t.key] or hostPart(model)
		for _, spec in { { "Prompt_Use_" .. t.suf, "topping_add" }, { "Prompt_Restock_" .. t.suf, "restock" } } do
			local a = findNamed(model, spec[1])
			if a and a:IsA("Attachment") and not a:GetAttribute(CREATED) then
				log("ok", ("%s: %s (Attachment from .fbx) kept at %s"):format(label, spec[1], fmtV(a.WorldPosition)))
			else
				if a and not a:IsA("Attachment") then
					a.Name = spec[1] .. "_Src"
					a = nil
				end
				if not a and host then
					a = newAttachment(host, spec[1], p)
				end
				if a and host then
					a.Parent = host
					;(a :: Attachment).WorldCFrame = FCF(CFrame.new(p))
				end
				log("new", ("%s: %s on %s at %s"):format(label, spec[1], if bins[t.key] then "Bin_" .. t.suf else "MAP-01 cell", fmtV(p)))
			end
			interactable(a, spec[2], { Ingredient = t.key })
		end
	end
	-- layout note: MAP-01 §7.1 documents the real grid (Cheese / Mustard / Ketchup on the operator row)
	local k, c = bins.ketchup, bins.cheese
	local km = if k then M(k.Position) else Vector3.zero
	local cm = if c then M(c.Position) else Vector3.zero
	if k and c and (km.X < cm.X or km.Z < splitZ) then
		log("warn", ("%s: grid differs from MAP-01 §7.1 (Ketchup X %.1f Z %.1f, Cheese X %.1f): update the doc"):format(label, km.X, km.Z, cm.X))
	end
end

local function bindStation(vehicle: Instance, mapId: string, kind: string, ingredient: string?): Instance?
	local m = byMapId(vehicle, mapId)
	if not m then
		log("err", ("%s not found inside the %s model (run place_assets first)"):format(mapId, vehicle.Name))
		return nil
	end
	CollectionService:AddTag(m, "Station")
	m:SetAttribute("StationKind", kind)
	if ingredient then
		m:SetAttribute("Ingredient", ingredient)
	end
	setPersistent(m)
	log("ok", ("%s: Station %s%s"):format(mapId, kind, if ingredient then " / " .. ingredient else ""))
	return m
end

-- Kitchen of one vehicle. The cart is the reference: trailer fallbacks = cart fallbacks + station pivot delta.
type Kit = {
	label: string, -- "CART" / "TRL"
	ids: { [string]: string }, -- role -> MapId: S G R B T K BIN DRAWER PHONE
	rail: number,
	board: number,
	railMode: string,
	counterY: number,
	cart: Instance?, -- the cart vehicle (reference for the deltas); nil when binding the cart itself
	fallbackDelta: Vector3, -- vehicle pivot delta, used when a station has no counterpart
}

local CART_IDS = { S = "CART-S", G = "CART-G", R = "CART-R", B = "CART-B", T = "CART-T", K = "CART-K", BIN = "BIN-C", DRAWER = "DRAWER", PHONE = "CART-PHONE" }
local TRL_IDS = { S = "TRL-S", G = "TRL-G", R = "TRL-R", B = "TRL-B", T = "TRL-T", K = "TRL-K", BIN = "TRL-BIN", DRAWER = "TRL-DRAWER", PHONE = "TRL-PHONE" }

local function bindKitchen(vehicle: Instance, kit: Kit, opts: AnchorOpts): Instance?
	local function delta(role: string): Vector3
		if not kit.cart then
			return Vector3.zero
		end
		local a = byMapId(vehicle, kit.ids[role])
		local b = byMapId(kit.cart :: Instance, CART_IDS[role])
		if a and b and a:IsA("PVInstance") and b:IsA("PVInstance") then
			return mapPivot(a).Position - mapPivot(b).Position
		end
		return kit.fallbackDelta
	end
	local L = kit.label

	-- S: sausage stock
	local s = bindStation(vehicle, kit.ids.S, "sausage_stock", "sausage")
	if s then
		local d = delta("S")
		local y = math.max(topY(s), kit.counterY) + 0.3
		interactable(ensureAnchor(s, "Prompt_Take", function()
			return Vector3.new(28.9 + d.X, y, 38.4 + d.Z)
		end, opts, kit.ids.S), "grill_place")
		interactable(ensureAnchor(s, "Prompt_Restock", function()
			return Vector3.new(29.6 + d.X, y, 37.0 + d.Z)
		end, opts, kit.ids.S), "restock")
	end
	-- G: grill
	local g = bindStation(vehicle, kit.ids.G, "grill")
	if g then
		bindGrill(g, opts, kit.ids.G)
		if findNamed(g, "Prompt_Grill") then
			log("ok", kit.ids.G .. ": Prompt_Grill left WITHOUT tag (placing is on the cooler, Prompt_Take -> grill_place)")
		end
	end
	-- R: rest rail
	local r = bindStation(vehicle, kit.ids.R, "rail")
	if r then
		bindRail(r, opts, kit.rail, kit.ids.R, kit.railMode)
	end
	-- B: bun crate (the .fbx has no empties)
	local b = bindStation(vehicle, kit.ids.B, "bun_crate", "bun")
	if b then
		local d = delta("B")
		local y = topY(b) + 0.3
		interactable(ensureAnchor(b, "Prompt_Take", function()
			return Vector3.new(39.7 + d.X, y, 38.4 + d.Z)
		end, opts, kit.ids.B), "bun_cut")
		interactable(ensureAnchor(b, "Prompt_Restock", function()
			return Vector3.new(39.7 + d.X, y, 36.9 + d.Z)
		end, opts, kit.ids.B), "restock")
	end
	-- T: cutting board, one prompt + shared slots
	local t = bindStation(vehicle, kit.ids.T, "board")
	if t then
		local d = delta("T")
		local y = topY(t) + 0.3
		interactable(ensureAnchor(t, "Prompt_Board", function()
			return Vector3.new(42.3 + d.X, y, 38.4 + d.Z)
		end, opts, kit.ids.T), "board_add_sausage")
		bindBoard(t, opts, kit.board, kit.ids.T)
	end
	-- K: toppings grid
	local k = bindStation(vehicle, kit.ids.K, "toppings")
	if k then
		bindToppings(k, opts, kit.ids.K, delta("K"))
	end
	-- BIN: trash (cart: BIN-C on the Pad; trailer: inside, back wall)
	local bin = bindStation(vehicle, kit.ids.BIN, "trash")
	if bin then
		local y = topY(bin) + 0.3
		interactable(ensureAnchor(bin, "Prompt_Discard", function()
			if not kit.cart then
				return Vector3.new(56, y, 42)
			end
			local mn, mx = partsBox(bin)
			if mn and mx then
				local c = (mn + mx) / 2
				return Vector3.new(c.X, y, mn.Z - 0.2) -- corridor side (north) of the back-wall bin
			end
			return mapPivot(bin).Position + Vector3.new(0, 2.3, -0.6)
		end, opts, kit.ids.BIN), "discard")
	end
	-- DRAWER: not a Station; Value_Anchor on top of the POS (drawer half, X >= 52.2 on the cart)
	local drawer = byMapId(vehicle, kit.ids.DRAWER)
	if drawer then
		setPersistent(drawer)
		local d = delta("DRAWER")
		ensureAnchor(drawer, "Value_Anchor", function()
			local mn, mx = partsBox(drawer, function(p)
				return M(p.Position).X >= 52.2 + d.X
			end)
			if not (mn and mx) then
				mn, mx = partsBox(drawer)
			end
			if mn and mx then
				local c = (mn + mx) / 2
				return Vector3.new(c.X, mx.Y + 0.4, c.Z)
			end
			return Vector3.new(53.2 + d.X, kit.counterY + 1.6, 37 + d.Z)
		end, opts, kit.ids.DRAWER)
		for _, n in { "Prompt_Serve", "Prompt_Drawer", "Prompt_TakeOrder", "Prompt_Refuse" } do
			if findNamed(drawer, n) then
				log("ok", ("%s: %s left WITHOUT tag (Serve is on the customer, DEC-190)"):format(kit.ids.DRAWER, n))
			end
		end
		for _, n in { "Bar_Thief", "VFX_Coins" } do
			if not findNamed(drawer, n) then
				log("warn", ("%s: fitting %s missing (read by TASK-024 / ThiefController)"):format(kit.ids.DRAWER, n))
			end
		end
	else
		log("err", ("%s (AST-020) not found inside the %s model"):format(kit.ids.DRAWER, L))
	end
	return vehicle
end

-- Phone (AST-042, DEC-124): Prompt_Answer -> answer_phone, pushed clear of the counter prompts.
local function bindPhone(vehicle: Instance, mapId: string, opts: AnchorOpts)
	local ph = byMapId(vehicle, mapId)
	if not ph then
		log("err", ("%s (AST-042) not found inside the %s model"):format(mapId, vehicle.Name))
		return
	end
	setPersistent(ph)
	local a = ensureAnchor(ph, "Prompt_Answer", function()
		local mn, mx = partsBox(ph)
		if mn and mx then
			local c = (mn + mx) / 2
			return Vector3.new(c.X, mx.Y + 0.3, c.Z)
		end
		return mapPivot(ph).Position + Vector3.new(0, 1.6, 0)
	end, opts, mapId)
	interactable(a, "answer_phone")
	for _, n in { "Light_Ring", "VFX_Ring" } do
		if not findNamed(ph, n) then
			log("warn", ("%s: fitting %s missing (BossController ring light, TASK-071)"):format(mapId, n))
		end
	end
end

-- Tarp placeholder inside the cart (VehicleCover, DEC-199, T38). Authored hidden; Orig* = visible values.
local function bindCover(cart: Instance)
	local cover = cart:FindFirstChild("VehicleCover")
	if not (cover and cover:IsA("Model")) then
		if cover then
			cover:Destroy()
		end
		local m = Instance.new("Model")
		m.Name = "VehicleCover"
		m:SetAttribute(CREATED, true)
		m.Parent = cart
		cover = m
	end
	local bin = byMapId(cart, "BIN-C")
	local pivot = mapPivot(cart) -- MAP-01
	-- footprint of the cart body + counter items, without the parasol canopies and the loose bin
	local mn, mx = partsBox(cart, function(p)
		local inCover = p:IsDescendantOf(cover :: Instance)
		local inBin = bin ~= nil and p:IsDescendantOf(bin :: Instance)
		return not inCover and not inBin and p.Position.Y < pivot.Y + 5.5
	end)
	local size = Vector3.new(26.6, 4.2, 4.6)
	local centre = pivot.Position + Vector3.new(0, 2.1, 0)
	if mn and mx then
		-- height fixed at 4.2 (AST-043: 26 x 4 x 4 over body + counter); parasol poles poke through
		size = Vector3.new(mx.X - mn.X + 0.4, 4.2, mx.Z - mn.Z + 0.4)
		centre = Vector3.new((mn.X + mx.X) / 2, pivot.Y + size.Y / 2, (mn.Z + mx.Z) / 2)
	end
	local part = (cover :: Instance):FindFirstChild("Cover")
	if not (part and part:IsA("BasePart")) then
		local p = Instance.new("Part")
		p.Name = "Cover"
		p.Parent = cover
		part = p
	end
	local bp = part :: BasePart
	bp.Anchored = true
	bp.Size = size
	bp.CFrame = FCF(CFrame.new(centre) * pivot.Rotation)
	bp.Material = Enum.Material.Fabric
	bp.Color = COVER_COLOR
	bp.CastShadow = true
	-- authored state = hidden; the VehicleService restores Orig* while the cart is at TRL-SALE (T38)
	bp.Transparency = 1
	bp.CanCollide = false
	bp.CanQuery = false
	bp.CanTouch = false
	bp:SetAttribute("OrigTransparency", 0)
	bp:SetAttribute("OrigCanCollide", true)
	bp:SetAttribute("OrigCanQuery", true)
	;(cover :: Model).PrimaryPart = bp
	CollectionService:AddTag(cover :: Instance, "VehicleCover")
	setPersistent(cover :: Instance)
	log("new", ("CART: VehicleCover placeholder %s at %s (hidden; AST-043 replaces it, TASK-088)"):format(fmtV(size), fmtV(centre)))
end

local function bindCart(assets: Instance, opts: AnchorOpts): Instance?
	local cart = byMapId(assets, "CART", "AST-026_CornerCart")
	if not cart then
		log("err", "CART (AST-026_CornerCart) not found in MAP01_Assets. Run Place.run first")
		return nil
	end
	CollectionService:AddTag(cart, "Vehicle")
	cart:SetAttribute("Vehicle", "cart")
	setPersistent(cart)
	log("ok", ("CART: Vehicle 'cart' (%s)"):format(cart:GetFullName()))

	-- re-parent every cart piece into the vehicle (T36: one PivotTo moves the set)
	local moved = 0
	for _, d in assets:GetDescendants() do
		local id = d:GetAttribute("MapId")
		if d ~= cart and typeof(id) == "string" and not d:IsDescendantOf(cart) then
			if string.sub(id, 1, 5) == "CART-" or id == "DRAWER" or id == "BIN-C" then
				d.Parent = cart
				moved += 1
			end
		end
	end
	log("ok", ("CART: %d model(s) moved inside the vehicle (CART-*, DRAWER, BIN-C)"):format(moved))

	bindKitchen(cart, {
		label = "CART",
		ids = CART_IDS,
		rail = 6,
		board = 2,
		railMode = "first",
		counterY = COUNTER_Y,
		cart = nil,
		fallbackDelta = Vector3.zero,
	}, opts)
	-- Zone_Center (thief radius 14, DEC-050): from the .fbx or created at the cart centre (41, 40)
	ensureAnchor(cart, "Zone_Center", function()
		return Vector3.new(41, 0.55, 40)
	end, opts, "CART")
	bindCover(cart)
	return cart
end

-- Trailer (wave 2). Returns the model and its Pad pose; leaves it ON THE PAD (moved to TRL-SALE at the end).
local function bindTrailer(assets: Instance, cart: Instance?, opts: AnchorOpts): (Instance?, CFrame, CFrame)
	local salePose = SALE_POSE
	local shell = byMapId(assets, "TRL-SALE", "AST-027_OpenLateTrailer")
	if shell and shell:IsA("PVInstance") then
		local p = mapPivot(shell)
		if (p.Position - SALE_POSE.Position).Magnitude > 0.05 or p.LookVector:Dot(SALE_POSE.LookVector) < 0.999 then
			log("warn", ("TRL-SALE shell pivot %s differs from the binding constant; the shell's pivot is used"):format(fmtV(p.Position)))
		end
		salePose = p
		shell:Destroy()
		log("ok", "TRL-SALE: empty sale shell removed (the real trailer parks here, T36)")
	end

	local trl = byMapId(assets, "TRL", "AST-027_OpenLateTrailer")
	if not trl then
		log("err", "TRL (AST-027_OpenLateTrailer, layer night) not found. Run Place.run first")
		return nil, TRL_POSE, salePose
	end
	-- DEC-221 (TASK-132): the hide cabinets H1..H4 leave the game. Destroy them wherever they are (inside the trailer
	-- after an older bind, or loose after an older Place.run); MAP-01_placements.luau no longer lists them.
	local hides: { Instance } = {}
	for _, d in assets:GetDescendants() do
		local id = d:GetAttribute("MapId")
		if typeof(id) == "string" and string.match(id, "^H[1-4]$") and d:GetAttribute("Asset") == "AST-041_HideCabinet" then
			table.insert(hides, d)
		end
	end
	for _, d in hides do
		if d.Parent then
			d:Destroy()
		end
	end
	if #hides > 0 then
		log("ok", ("TRL: %d hide cabinet model(s) H1..H4 removed (DEC-221)"):format(#hides))
	end

	local members: { Instance } = {}
	for _, d in assets:GetDescendants() do
		local id = d:GetAttribute("MapId")
		if d ~= trl and typeof(id) == "string" and not d:IsDescendantOf(trl) then
			if string.sub(id, 1, 4) == "TRL-" and id ~= "TRL-SALE" then
				table.insert(members, d)
			end
		end
	end
	local padPose = TRL_POSE
	if #members > 0 then
		-- first bind after Place.run: the trailer and its interior are where place_assets put them (Pad)
		padPose = mapPivot(trl)
		if (padPose.Position - TRL_POSE.Position).Magnitude > 0.05 or padPose.LookVector:Dot(TRL_POSE.LookVector) < 0.999 then
			log("warn", ("TRL pivot %s differs from the binding constant %s; the actual pivot is used as TRL"):format(fmtV(padPose.Position), fmtV(TRL_POSE.Position)))
		end
		for _, d in members do
			d.Parent = trl
		end
	else
		-- re-run: the set is already inside the trailer (parked at TRL-SALE); bring it back to the Pad to bind
		(trl :: any):PivotTo(FCF(TRL_POSE))
	end
	log("ok", ("TRL: %d model(s) moved inside the trailer (TRL-*); bound on the Pad"):format(#members))
	CollectionService:AddTag(trl, "Vehicle")
	trl:SetAttribute("Vehicle", "trailer")
	setPersistent(trl)

	local cartPivot = if cart then mapPivot(cart).Position else CART_POSE.Position
	bindKitchen(trl, {
		label = "TRL",
		ids = TRL_IDS,
		rail = 8, -- Vehicles.trailer.RailSlots (Rail_8, §19.22)
		board = 3, -- Vehicles.trailer.BoardSlots (DEC-215)
		railMode = "ideal",
		counterY = padPose.Y + TRAILER_COUNTER_DY,
		cart = cart,
		fallbackDelta = padPose.Position - cartPivot,
	}, opts)

	-- coffee machine (AST-022, DEC-125): Prompt_Brew -> brew_coffee, Prompt_Restock -> restock (stock coffee)
	local cm = bindStation(trl, "TRL-COFFEE", "coffee_machine", "coffee")
	if cm then
		local mn, mx = partsBox(cm)
		local c = if mn and mx then (mn + mx) / 2 else mapPivot(cm).Position
		local top = if mx then mx.Y else padPose.Y + TRAILER_COUNTER_DY + 2
		local front = if mn then mn.Z - 0.2 else c.Z - 1.6 -- corridor side (north) at the Pad pose
		interactable(ensureAnchor(cm, "Prompt_Brew", function()
			return Vector3.new(c.X - 0.6, top + 0.3, front)
		end, opts, "TRL-COFFEE"), "brew_coffee")
		interactable(ensureAnchor(cm, "Prompt_Restock", function()
			return Vector3.new(c.X + 0.6, top + 0.3, front)
		end, opts, "TRL-COFFEE"), "restock")
		for _, n in { "Bar_Brew", "Att_Cup", "VFX_Steam" } do
			if not findNamed(cm, n) then
				log("warn", ("TRL-COFFEE: fitting %s missing (KitchenController/Coffee.luau, TASK-069)"):format(n))
			end
		end
	end

	-- light switch (AST-039): Prompt_Switch -> switch_light (LightService, §19.6)
	local sw = byMapId(trl, "TRL-SWITCH")
	if sw then
		setPersistent(sw)
		interactable(ensureAnchor(sw, "Prompt_Switch", function()
			local mn, mx = partsBox(sw)
			if mn and mx then
				local c = (mn + mx) / 2
				return Vector3.new(c.X, c.Y, mn.Z - 0.3) -- in front of the plate, corridor side (north)
			end
			return mapPivot(sw).Position + Vector3.new(0, 0.5, -0.4)
		end, opts, "TRL-SWITCH"), "switch_light")
	else
		log("err", "TRL-SWITCH (AST-039) not found inside the trailer")
	end

	-- purchase (FEAT-016, DEC-047, DEC-107): Prompt_Buy on the shell, outside the service window; it travels with
	-- the trailer (at TRL-SALE the window faces the Pad). The VehicleService disables it once bought.
	interactable(ensureAnchor(trl, "Prompt_Buy", function()
		return padPose:PointToWorldSpace(Vector3.new(1, 4.5, -7.5))
	end, opts, "TRL"), "buy_trailer")

	-- thief zone of the trailer (DEC-050): centre of the trailer, Pad level
	ensureAnchor(trl, "Zone_Center", function()
		return padPose.Position + Vector3.new(0, 0.1, 0)
	end, opts, "TRL")
	for _, n in { "Light_Interior" } do
		if not findNamed(trl, n) then
			log("warn", ("TRL: fitting %s missing (LightController, TASK-060; AST-079 pending)"):format(n))
		end
	end
	return trl, padPose, salePose
end

local function bindOpenSign(assets: Instance, opts: AnchorOpts)
	local m = byMapId(assets, "OPEN", "AST-024_SignStand")
	if not m then
		log("err", "OPEN sign (AST-024_SignStand, MapId OPEN) not found")
		return
	end
	setPersistent(m)
	local a = ensureAnchor(m, "Prompt_Open", function()
		local mn, mx = partsBox(m)
		if mn and mx then
			return (mn + mx) / 2
		end
		return Vector3.new(25, 2, 35)
	end, opts, "OPEN")
	interactable(a, "open_sign")
	-- the sale sign SIGN-T uses the same asset: its Prompt_Open must stay untagged (clean slate does it)
end

local function bindMart(assets: Instance, opts: AnchorOpts)
	-- Shelves: invisible anchor Parts in a Model MKT-SHELVES (gondolas/fridges have no empties)
	local parent = assets:FindFirstChild("MartInterior") or assets
	local shelves = assets:FindFirstChild("MKT-SHELVES", true)
	if not (shelves and shelves:IsA("Model")) then
		shelves = Instance.new("Model")
		shelves.Name = "MKT-SHELVES"
		shelves:SetAttribute(CREATED, true)
		shelves.Parent = parent
	end
	setPersistent(shelves :: Instance)
	for _, sh in SHELVES do
		local name = "BUY-" .. sh.name
		local p = (shelves :: Instance):FindFirstChild(name)
		local pos = Vector3.new(sh.x, MART_FLOOR + SHELF_ANCHOR_H, sh.z)
		if not (p and p:IsA("BasePart")) then
			local part = Instance.new("Part")
			part.Name = name
			part.Size = Vector3.one
			part.CFrame = FCF(CFrame.new(pos))
			part:SetAttribute(CREATED, true)
			part.Parent = shelves
			p = part
		elseif opts.resetCreated then
			(p :: BasePart).CFrame = FCF(CFrame.new(pos))
		end
		makeInvisible(p :: BasePart)
		interactable(p, "buy_package", { Package = sh.package })
		log("ok", ("MKT-SHELVES: %s -> buy_package %s at %s"):format(name, sh.package, fmtV(M((p :: BasePart).Position))))
	end

	-- GEAR WALL (AST-049): Prompt_Buy_<slot>
	local gw = byMapId(assets, "GEAR_WALL", "AST-049_GearWall")
	if not gw then
		log("err", "GEAR_WALL (AST-049_GearWall) not found")
		return
	end
	setPersistent(gw)
	for _, b in BENCH do
		local a = ensureAnchor(gw, "Prompt_Buy_" .. b.slot, function()
			return Vector3.new(-97.8, MART_FLOOR + 3.5 + 1.0, b.z)
		end, opts, "GEAR_WALL")
		interactable(a, b.action, { BenchSlot = b.slot })
		for _, n in { "Price_Anchor_" .. b.slot, "PriceTag_" .. b.slot, "Slot_" .. b.slot } do
			if not findNamed(gw, n) then
				log("warn", ("GEAR_WALL: fitting %s missing (read by MarketController, TASK-037)"):format(n))
			end
		end
	end
end

-- Street bins (DEC-200, T60): every AST-034_TrashCan on the map. Q-166 b (how many): all, Provisório.
local function bindStreetBins(assets: Instance, opts: AnchorOpts)
	local n = 0
	for _, d in assets:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Asset") == "AST-034_TrashCan" then
			if ancestorWithTag(d, "Vehicle") then
				log("err", ("StreetBin %s is inside a Vehicle (T60: never)"):format(d:GetFullName()))
				continue
			end
			n += 1
			CollectionService:AddTag(d, "StreetBin")
			setPersistent(d)
			local p = mapPivot(d).Position
			local label = ("StreetBin %s (%.0f, %.0f)"):format(tostring(d:GetAttribute("MapId")), p.X, p.Z)
			interactable(ensureAnchor(d, "Prompt_Discard", function()
				local mn, mx = partsBox(d)
				if mn and mx then
					local c = (mn + mx) / 2
					return Vector3.new(c.X, mx.Y + 0.3, c.Z)
				end
				return p + Vector3.new(0, 3.3, 0)
			end, opts, label), "discard")
		end
	end
	log(if n > 0 then "ok" else "warn", ("StreetBin: %d street bin(s) interactive (DEC-200; Q-166 b Provisório: all)"):format(n))
end

-- Copies the blockout SpotLight of a post into LampHead/Light_Lamp (pointing down) and disables the blockout one.
local function ensureLampLight(post: Instance, head: Instance?, id: string)
	for _, d in post:GetDescendants() do
		if d:IsA("SpotLight") or d:IsA("PointLight") or d:IsA("SurfaceLight") then
			log("ok", ("%s: light %s already in the post"):format(id, d:GetFullName()))
			return
		end
	end
	if not head then
		log("warn", ("%s: no LampHead model, light not bound"):format(id))
		return
	end
	local src: Light? = nil
	local blockout = Workspace:FindFirstChild("MAP01_Blockout")
	local folder = blockout and blockout:FindFirstChild("StreetLights")
	local bp = folder and folder:FindFirstChild(id)
	if bp then
		for _, d in bp:GetDescendants() do
			if d:IsA("Light") then
				src = d
				break
			end
		end
	end
	local mn, mx = partsBox(head)
	local pivot = mapPivot(head) -- MAP-01
	local pos = if mn and mx then Vector3.new((mn.X + mx.X) / 2, mn.Y - 0.05, (mn.Z + mx.Z) / 2) else pivot.Position + Vector3.new(0, 13, 0)
	local holder = Instance.new("Part")
	holder.Name = "Light_Lamp"
	holder.Size = Vector3.new(0.4, 0.1, 0.4)
	holder.CFrame = FCF(CFrame.new(pos) * pivot.Rotation)
	makeInvisible(holder)
	holder:SetAttribute(CREATED, true)
	holder.Parent = head
	local light: Light
	if src then
		light = src:Clone()
		light.Enabled = true -- the source may be disabled by an earlier bind (Place.run rebuilt the head)
		light:SetAttribute("DisabledByBind", nil)
		src.Enabled = false
		src:SetAttribute("DisabledByBind", true)
	else
		local sl = Instance.new("SpotLight")
		sl.Range = 18
		sl.Angle = 60
		sl.Brightness = 2
		sl.Color = Color3.fromRGB(255, 214, 150)
		light = sl
		log("new", ("%s: no blockout twin; default SpotLight created (style guide §5.1: Range 16-20, no shadow)"):format(id))
	end
	if light:IsA("SpotLight") then
		light.Face = Enum.NormalId.Bottom
	end
	light.Shadows = false
	light.Parent = holder
	log("new", ("%s: %s moved to LampHead/Light_Lamp at %s%s"):format(id, light.ClassName, fmtV(pos), if src then " (blockout light disabled)" else ""))
end

-- Street lights: one Model per post with tag StreetLight (§19.6).
local function bindStreetLights(assets: Instance)
	for _, spec in POSTS do
		local parts: { Instance } = {}
		local group: Model? = nil
		for _, d in assets:GetDescendants() do
			if d:GetAttribute("MapId") == spec.id and d:IsA("PVInstance") then
				table.insert(parts, d)
				local par = d.Parent
				if par and par:IsA("Model") and par.Name == spec.id then
					group = par
				end
			end
		end
		if #parts == 0 then
			log("err", ("StreetLight %s: no placed model with MapId %s"):format(spec.id, spec.id))
			continue
		end
		local head: Instance? = nil
		for _, d in parts do
			if d:GetAttribute("Asset") == "AST-036_LampHead" then
				head = d
			end
		end
		if not group then
			local g = Instance.new("Model")
			g.Name = spec.id
			g.Parent = parts[1].Parent
			group = g
		end
		for _, d in parts do
			d.Parent = group
		end
		local post = group :: Model
		post.WorldPivot = if head then (head :: any):GetPivot() else (parts[1] :: any):GetPivot()
		CollectionService:AddTag(post, "StreetLight")
		post:SetAttribute("PostId", spec.id)
		post:SetAttribute("Group", POST_GROUP)
		post:SetAttribute("Order", spec.order)
		setPersistent(post)
		ensureLampLight(post, head, spec.id)
		log("ok", ("StreetLight %s: Order %d, Group %s (%d model(s))"):format(spec.id, spec.order, POST_GROUP, #parts))
	end
	-- retired posts (Walker posts on the Ninth, 2026-10-10): their blockout light would still shine (hidden parts keep lights)
	local blockout = Workspace:FindFirstChild("MAP01_Blockout")
	local folder = blockout and blockout:FindFirstChild("StreetLights")
	local off = 0
	for _, id in RETIRED_POSTS do
		local bp = folder and folder:FindFirstChild(id)
		if bp then
			for _, d in bp:GetDescendants() do
				if d:IsA("Light") and d.Enabled then
					d.Enabled = false
					d:SetAttribute("DisabledByBind", true)
					off += 1
				end
			end
		end
		for _, d in assets:GetDescendants() do
			if d:GetAttribute("MapId") == id then
				log("warn", ("StreetLight %s: a placed model %s still has the retired MapId (run Place.run with the new placements)"):format(id, d:GetFullName()))
				break
			end
		end
	end
	log("ok", ("StreetLight: %d blockout light(s) of the retired posts %s switched off"):format(off, table.concat(RETIRED_POSTS, ", ")))
end

type Ctx = { cart: Instance?, trailer: Instance?, poses: { [string]: CFrame }, assets: Instance? }

-- Door spawn point measured on the placed door (MAP-01 §9.8): XZ of the door part / model centre, pushed `out` to
-- 0.8 in front of its outer face. nil when the model (or the named part) is not in the place.
local function resolveDoor(assets: Instance?, r: any): (number?, number?, string)
	if not assets then
		return nil, nil, "no MAP01_Assets"
	end
	local model = byMapId(assets, r.mapId, r.asset)
	if not model then
		return nil, nil, ("%s (%s) not placed"):format(r.mapId, r.asset)
	end
	local target: Instance = model
	if r.part then
		local best: BasePart? = nil
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, r.part) and d.Transparency < 1 then
				if not best or d.Size.Magnitude > best.Size.Magnitude then
					best = d
				end
			end
		end
		if not best then
			return nil, nil, ("no part matching '%s' in %s"):format(r.part, model:GetFullName())
		end
		target = best :: BasePart
	end
	local mn, mx = partsBox(target)
	if not (mn and mx) then
		return nil, nil, "empty box"
	end
	local c = (mn + mx) / 2
	local out: Vector3 = r.out
	local half = math.abs(out.X) * (mx.X - mn.X) / 2 + math.abs(out.Z) * (mx.Z - mn.Z) / 2
	local p = c + out * (half + 0.8)
	return p.X, p.Z, ("measured on %s"):format(target:GetFullName())
end

local function bindPoints(ctx: Ctx): Instance
	local root = Workspace:FindFirstChild(BINDING_ROOT)
	if not (root and root:IsA("Model")) then
		if root then
			log("warn", ("workspace.%s was a %s; replaced by a Model"):format(BINDING_ROOT, root.ClassName))
			root:Destroy()
		end
		root = Instance.new("Model")
		root.Name = BINDING_ROOT
		root.Parent = Workspace
	end
	CollectionService:AddTag(root, "MapBinding")
	setPersistent(root)
	for _, child in (root :: Instance):GetChildren() do
		child:Destroy()
	end
	local pts = Instance.new("Folder")
	pts.Name = "Points"
	pts.Parent = root
	local nodes = Instance.new("Folder")
	nodes.Name = "Nodes"
	nodes.Parent = root

	local exclude: { Instance } = { root :: Instance }
	local blockout = Workspace:FindFirstChild("MAP01_Blockout")
	if blockout and blockout:FindFirstChild("Markers") then
		table.insert(exclude, blockout.Markers)
	end
	-- review / demo scenes are not part of the map
	for _, c in Workspace:GetChildren() do
		if c.Name == "CrewDemo" or c.Name == "AssetReview" or c.Name == "KitDemo" or c.Name == "ItemsDemo" or string.sub(c.Name, 1, 10) == "__Preview_" then
			table.insert(exclude, c)
		end
	end
	local function without(v: Instance?): { Instance }
		local ex = table.clone(exclude)
		if v then
			table.insert(ex, v)
		end
		return ex
	end

	local links: { [string]: { string } } = {}
	for _, e in EDGES do
		links[e[1]] = links[e[1]] or {}
		links[e[2]] = links[e[2]] or {}
		table.insert(links[e[1]], e[2])
		table.insert(links[e[2]], e[1])
	end

	-- cf in MAP-01 coordinates
	local function newPart(name: string, cf: CFrame, parent: Instance): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.one
		p.CFrame = FCF(cf)
		makeInvisible(p)
		p.Parent = parent
		return p
	end

	for _, pt in POINTS do
		local cf: CFrame
		if pt.pose then
			cf = ctx.poses[pt.pose]
		else
			local px, pz = pt.x, pt.z
			if pt.resolve then
				local rx, rz, how = resolveDoor(ctx.assets, pt.resolve)
				if rx and rz and math.abs(rx - pt.x) + math.abs(rz - pt.z) <= 12 then
					px, pz = rx, rz
					log("ok", ("%s: door point %s"):format(pt.id, how))
				elseif rx and rz then
					log("warn", ("%s: measured door at (%.1f, %.1f) is > 12 from the MAP-01 fallback; fallback used (%s)"):format(pt.id, rx, rz, how))
				else
					log("warn", ("%s: door not measured (%s); MAP-01 fallback (%.1f, %.1f) used"):format(pt.id, how, pt.x, pt.z))
				end
			end
			local y: number
			if pt.y then
				y = pt.y
			else
				local why
				y, why = floorY(px, pz, pt.floor, without(if pt.onTrailer then ctx.cart else ctx.trailer))
				if why then
					log("warn", ("%s: %s"):format(pt.id, why))
				end
			end
			local pos = Vector3.new(px, y, pz)
			local face: Vector3? = pt.face
			if pt.faceTo then
				local d = Vector3.new(pt.faceTo[1] - px, 0, pt.faceTo[2] - pz)
				face = if d.Magnitude > 1e-3 then d.Unit else nil
			end
			cf = if face then CFrame.lookAt(pos, pos + face) else CFrame.new(pos)
		end
		local p = newPart(pt.id, cf, pts)
		CollectionService:AddTag(p, "MapPoint")
		p:SetAttribute("PointId", pt.id)
		if pt.node then
			CollectionService:AddTag(p, "NpcNode")
			p:SetAttribute("Links", table.concat(links[pt.id] or {}, ","))
		end
		-- spawn / despawn contract (MAP-01 §9.8, Provisório)
		if pt.spawn or pt.despawn then
			p:SetAttribute("Spawn", pt.spawn or "")
			p:SetAttribute("Despawn", pt.despawn == true)
			p:SetAttribute("SpawnKind", if pt.door then "door" else "edge")
			if pt.door then
				p:SetAttribute("Door", pt.door)
			end
		end
		log("ok", ("MapPoint %s at %s%s%s"):format(pt.id, fmtV(p.Position), if pt.node then " (+ NpcNode)" else "", if pt.spawn then (" spawn {%s}"):format(pt.spawn) else ""))
	end
	for _, nd in NODES do
		local y, why = floorY(nd.x, nd.z, nd.floor, without(ctx.trailer))
		if why then
			log("warn", ("%s: %s"):format(nd.id, why))
		end
		local p = newPart(nd.id, CFrame.new(nd.x, y, nd.z), nodes)
		CollectionService:AddTag(p, "NpcNode")
		p:SetAttribute("NodeId", nd.id)
		p:SetAttribute("Links", table.concat(links[nd.id] or {}, ","))
		if nd.crosswalk then
			p:SetAttribute("Crosswalk", nd.crosswalk)
		end
	end
	local pointNodes = 0
	for _, pt in POINTS do
		if pt.node then
			pointNodes += 1
		end
	end
	log("ok", ("NpcNode graph: %d node-only parts + %d point nodes, %d edges"):format(#NODES, pointNodes, #EDGES))
	return root :: Instance
end

-- Light volumes LZ-1..5 in MapBinding/LightZones (static; trailer zones on the Pad pose).
local function bindLightZones(root: Instance, padPose: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "LightZones"
	folder.Parent = root
	for _, z in ZONES do
		local p = Instance.new("Part")
		p.Name = z.id
		local centre: CFrame = if z.local_ then padPose * CFrame.new(z.local_) else CFrame.new(z.world :: Vector3)
		if z.shape == "Ball" then
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.one * (z.radius :: number) * 2
		else
			p.Shape = Enum.PartType.Block
			p.Size = z.size :: Vector3
		end
		p.CFrame = FCF(centre)
		makeInvisible(p)
		p.Parent = folder
		CollectionService:AddTag(p, "LightZone")
		p:SetAttribute("ZoneId", z.id)
		p:SetAttribute("Group", z.group)
		log("ok", ("LightZone %s (%s, %s) at %s size %s"):format(z.id, z.group, z.shape, fmtV(p.Position), fmtV(p.Size)))
	end
end

-- Wave 3 (W1a): service window button TRL-SHUTTER (DEC-221, TASK-132; MAP-01 §7.2). Bound with the trailer on the Pad.
local function bindShutterButton(trl: Instance, padPose: CFrame, opts: AnchorOpts)
	-- where the plate goes: X 43.4, same wall face and height as the TRL-SWITCH plate (fallback: Pad-frame constant)
	local function wanted(): CFrame
		local sw = byMapId(trl, "TRL-SWITCH")
		local mn, mx = nil, nil
		if sw then
			mn, mx = partsBox(sw)
		end
		if mn and mx then
			local local_ = padPose:PointToObjectSpace(Vector3.new(SHUTTER_BUTTON_X, (mn.Y + mx.Y) / 2, mx.Z - SHUTTER_BUTTON_SIZE.Z / 2))
			return padPose * CFrame.new(local_)
		end
		log("warn", "TRL-SHUTTER: TRL-SWITCH plate not found, button placed at the Pad-frame fallback")
		return padPose * CFrame.new(SHUTTER_BUTTON_FALLBACK)
	end

	local model = byMapId(trl, SHUTTER_ID)
	if model and not model:IsA("Model") then
		model:Destroy()
		model = nil
	end
	if not model then
		local m = Instance.new("Model")
		m.Name = SHUTTER_ID
		m:SetAttribute("MapId", SHUTTER_ID)
		m:SetAttribute(CREATED, true)
		m.Parent = trl
		model = m
	end
	local m = model :: Model
	setPersistent(m)

	local plate = m:FindFirstChild("Button")
	local fresh = false
	if not (plate and plate:IsA("BasePart")) then
		if plate then
			plate:Destroy()
		end
		local p = Instance.new("Part")
		p.Name = "Button"
		p:SetAttribute(CREATED, true)
		p.Parent = m
		plate = p
		fresh = true
	end
	local bp = plate :: BasePart
	bp.Anchored = true
	if bp:GetAttribute(CREATED) then
		-- placeholder look (P51); a hand-made / art plate without BindCreated is left as it is
		bp.Size = SHUTTER_BUTTON_SIZE
		bp.Material = Enum.Material.SmoothPlastic
		bp.Color = SHUTTER_BUTTON_COLOR
		bp.CanCollide = false
		bp.CanTouch = false
		bp.CastShadow = false
		if fresh or opts.resetCreated then
			bp.CFrame = FCF(wanted())
		end
	end
	m.PrimaryPart = bp

	-- Prompt_Shutter: Attachment on the plate, corridor side (local -Z = north with the trailer on the Pad)
	local prompt = bp:FindFirstChild("Prompt_Shutter")
	if not (prompt and prompt:IsA("Attachment")) then
		if prompt then
			prompt:Destroy()
		end
		local a = Instance.new("Attachment")
		a.Name = "Prompt_Shutter"
		a:SetAttribute(CREATED, true)
		a.Parent = bp
		prompt = a
	end
	local a = prompt :: Attachment
	if a:GetAttribute(CREATED) then
		a.CFrame = CFrame.new(0, 0, -(bp.Size.Z / 2 + SHUTTER_PROMPT_OUT))
	end
	interactable(a, "shutter_toggle")

	-- clearance: slide the plate west (up to 1.0), then up (up to 1.0), until >= SHUTTER_GAP from other owners
	local d, who = closestOther(a, trl)
	local moved = Vector3.zero
	for _, step in { padPose.RightVector * -0.1, padPose.UpVector * 0.1 } do
		local n = 0
		while d < SHUTTER_GAP and n < 10 do
			bp.CFrame = bp.CFrame + FD(step)
			moved += step
			n += 1
			d, who = closestOther(a, trl)
		end
	end
	local label = ("%s: Prompt_Shutter (shutter_toggle) at %s"):format(SHUTTER_ID, fmtV(a.WorldPosition))
	if d < SHUTTER_GAP then
		log("warn", ("%s still %.2f from %s after moving the plate %s (move it by hand)"):format(label, d, who, fmtV(moved)))
	elseif moved.Magnitude > 0 then
		log("new", ("%s, plate moved %s to clear %s (%.2f)"):format(label, fmtV(moved), who, d))
	else
		log(if bp:GetAttribute(CREATED) then "new" else "ok", ("%s, closest other owner %s at %.2f"):format(label, who, d))
	end
	local sw = byMapId(trl, "TRL-SWITCH")
	local swPrompt = sw and findNamed(sw, "Prompt_Switch")
	if swPrompt then
		local ds = (anchorPos(swPrompt) - a.WorldPosition).Magnitude
		if ds > 4 then
			log("warn", ("%s: %.2f from Prompt_Switch (MAP-01 §7.2 wants it next to the switch, ~2.6)"):format(SHUTTER_ID, ds))
		end
	end
end

-- Wave 3 (W1b): the piece that closes the window + Shutter_Hinge (DEC-221, TASK-132; MAP-01 §7.2, P51).
-- The Awning is used when, measured in the Pad frame, it spans the window and, hung from its wall-side edge,
-- covers sill..top; otherwise a placeholder Shutter_Panel. ClosedAngle = degrees around the hinge X axis.
local function bindShutterPiece(trl: Instance, padPose: CFrame)
	local existing = findNamed(trl, "Shutter_Hinge")
	if existing and existing:IsA("Attachment") and not existing:GetAttribute(CREATED) then
		local host = if existing.Parent then existing.Parent:GetFullName() else "?"
		log("ok", ("TRL: Shutter_Hinge authored by hand on %s, left as is (ClosedAngle %s)"):format(host, tostring(existing:GetAttribute("ClosedAngle"))))
		return
	end
	-- old created hinges / panels are rebuilt below
	for _, d in trl:GetDescendants() do
		if d.Name == "Shutter_Hinge" and d:GetAttribute(CREATED) then
			d:Destroy()
		end
	end
	local W = WINDOW_LOCAL
	local rot = padPose.Rotation

	local function newHinge(host: BasePart, hingeWorld: Vector3, angle: number)
		local h = Instance.new("Attachment")
		h.Name = "Shutter_Hinge"
		h:SetAttribute(CREATED, true)
		h.Parent = host
		h.WorldCFrame = FCF(CFrame.new(hingeWorld) * rot) -- X axis = along the window (hinge axis); hingeWorld in MAP-01
		h:SetAttribute("ClosedAngle", angle)
		return h
	end

	-- the AST-027 Awning of the shell (not a piece of another MapId model inside the trailer)
	local awning: BasePart? = nil
	for _, d in trl:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Awning" then
			local q = d.Parent
			local nested = false
			while q and q ~= trl do
				if q:GetAttribute("MapId") ~= nil then
					nested = true
				end
				q = q.Parent
			end
			if not nested then
				awning = d
				break
			end
		end
	end

	local why = "no BasePart named Awning in the trailer shell"
	if awning then
		--[[ 2026-10-10 fix (ClosedAngle came out 0, the flap never closed): the MeshPart is axis-aligned and its Size is
			the BOUNDING BOX of a slanted plate, so "the longer axis" was the box height and the plate looked vertical
			(already closed). Now the slant is the box DIAGONAL in the Pad YZ plane: hinge = the wall-side edge (largest
			local Z: the window faces -Z), far = the outer edge; which of the two diagonals is the plate comes from a
			raycast profile (top surface higher at the wall = canopy sloping down-outwards, the usual raised awning).
			Closed = hanging from the hinge, 3 degrees outwards so it never sinks into the wall. ]]
		local box = padPose:ToObjectSpace(MCF(awning.CFrame))
		local half = awning.Size / 2
		local mnL, mxL = nil :: Vector3?, nil :: Vector3?
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = box:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
					mnL = if mnL then mnL:Min(p) else p
					mxL = if mxL then mxL:Max(p) else p
				end
			end
		end
		local mn, mx = mnL :: Vector3, mxL :: Vector3
		local width = mx.X - mn.X
		local cx = (mn.X + mx.X) / 2
		-- profile: top surface height near the wall side and near the outer side (pad frame), raycast on the mesh only
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { awning }
		local query = awning.CanQuery
		awning.CanQuery = true
		local function topAt(z: number): number?
			local o = F(padPose:PointToWorldSpace(Vector3.new(cx, mx.Y + 2, z)))
			local hit = Workspace:Raycast(o, FD(padPose:VectorToWorldSpace(Vector3.new(0, -(mx.Y - mn.Y) - 4, 0))), params)
			return if hit then padPose:PointToObjectSpace(M(hit.Position)).Y else nil
		end
		local depth = mx.Z - mn.Z
		local yWall = topAt(mx.Z - depth * 0.15)
		local yOut = topAt(mn.Z + depth * 0.15)
		awning.CanQuery = query
		local downOut = not (yWall and yOut and yOut > yWall + 0.05) -- unknown profile = the usual down-outwards canopy
		local hinge = Vector3.new(cx, if downOut then mx.Y else mn.Y, mx.Z)
		local far = Vector3.new(cx, if downOut then mn.Y else mx.Y, mn.Z)
		local v = far - hinge
		local length = math.sqrt(v.Y * v.Y + v.Z * v.Z)
		local covers = width >= (W.x1 - W.x0) - 2 * AWNING_TOL
			and mn.X <= W.x0 + AWNING_TOL
			and mx.X >= W.x1 - AWNING_TOL
			and hinge.Y >= W.top - AWNING_TOL
			and hinge.Y - length <= W.sill + AWNING_TOL
			and math.abs(hinge.Z - W.wallZ) <= 1.5
		local info = ("Awning box %.2f x %.2f x %.2f (X %.2f..%.2f), profile wall %s / out %s (%s), slant %.2f, hinge y %.2f z %.2f over the pivot; window X %.2f..%.2f, sill %.2f, top %.2f, wall z %.2f"):format(
			width, mx.Y - mn.Y, depth, mn.X, mx.X, if yWall then ("%.2f"):format(yWall) else "-", if yOut then ("%.2f"):format(yOut) else "-",
			if downOut then "down-outwards" else "up-outwards", length, hinge.Y, hinge.Z, W.x0, W.x1, W.sill, W.top, W.wallZ)
		-- angle of v in the (Y, Z) plane = atan2(Z, Y); CFrame.Angles(t, 0, 0) adds t to it. Target: hanging down,
		-- tilted 3 degrees outwards (-Z): atan2(-sin 3, -cos 3) = -(180 - 3) degrees.
		local theta = -(math.pi - math.rad(3)) - math.atan2(v.Z, v.Y)
		while theta > math.pi do
			theta -= 2 * math.pi
		end
		while theta <= -math.pi do
			theta += 2 * math.pi
		end
		local deg = math.floor(math.deg(theta) * 10 + 0.5) / 10
		if covers and math.abs(deg) < 5 then
			covers = false
			why = ("measured ClosedAngle %.1f is degenerate (the awning already hangs over the window?): %s"):format(deg, info)
		elseif not covers then
			why = "it does not cover the window: " .. info
		end
		if covers then
			for _, d in trl:GetDescendants() do
				if d.Name == "Shutter_Panel" and d:GetAttribute(CREATED) then
					d:Destroy()
				end
			end
			if awning:GetAttribute("AwningHiddenByBind") then
				awning.Transparency = awning:GetAttribute("OrigAwningTransparency") or 0
				awning.CanQuery = true
				awning.CanCollide = awning:GetAttribute("OrigAwningCanCollide") ~= false
				awning:SetAttribute("AwningHiddenByBind", nil)
			end
			newHinge(awning, padPose:PointToWorldSpace(hinge), deg)
			log("ok", ("TRL: Shutter_Hinge on the AST-027 Awning, ClosedAngle %.1f (%s)"):format(deg, info))
			return
		end
	end

	-- placeholder panel (P51): hinge on the window top, outside the wall; authored OPEN = horizontal, outwards
	local hingeLocal = Vector3.new((W.x0 + W.x1) / 2, W.top + 0.1, W.wallZ - SHUTTER_PANEL_SIZE.Z / 2 - 0.05)
	local hingeCF = padPose * CFrame.new(hingeLocal)
	local closedCF = hingeCF * CFrame.new(0, -SHUTTER_PANEL_SIZE.Y / 2, 0)
	local openCF = hingeCF * CFrame.Angles(math.rad(90), 0, 0) * hingeCF:Inverse() * closedCF
	local panel = trl:FindFirstChild("Shutter_Panel")
	if not (panel and panel:IsA("BasePart")) then
		if panel then
			panel:Destroy()
		end
		local p = Instance.new("Part")
		p.Name = "Shutter_Panel"
		p:SetAttribute(CREATED, true)
		p.Parent = trl
		panel = p
	end
	local pp = panel :: BasePart
	if pp:GetAttribute(CREATED) then
		-- always re-derived from the window (a hand-made panel without BindCreated is left where it is)
		pp.Anchored = true
		pp.Size = SHUTTER_PANEL_SIZE
		pp.Material = Enum.Material.Metal
		pp.Color = SHUTTER_PANEL_COLOR
		pp.CanCollide = false
		pp.CanQuery = false
		pp.CanTouch = false
		pp.CastShadow = true
		pp.CFrame = FCF(openCF)
	end
	newHinge(pp, hingeCF.Position, -90)
	-- 2026-10-10 (Walker sight, MAP-01 §5.6): the AST-027 Awning of the current FBX is a vertical plate hanging over the
	-- whole window (Y 5.9..10.7 at the wall face), i.e. the flap already CLOSED. Left fixed it blocked every ray out of
	-- the window (raycast from PS-N1..4 and the window centre). With the placeholder panel as the flap, the fixed
	-- Awning is hidden (reversible: Orig* attributes; restored when an Awning that works as a flap comes back).
	local hid = ""
	if awning and not awning:GetAttribute("AwningHiddenByBind") then
		awning:SetAttribute("OrigAwningTransparency", awning.Transparency)
		awning:SetAttribute("OrigAwningCanCollide", awning.CanCollide)
		awning:SetAttribute("AwningHiddenByBind", true)
		awning.Transparency = 1
		awning.CanCollide = false
		awning.CanQuery = false
		hid = "; fixed Awning hidden (it hung over the window)"
	elseif awning then
		hid = "; fixed Awning already hidden"
	end
	log("new", ("TRL: Shutter_Panel placeholder %s, open at %s, Shutter_Hinge ClosedAngle -90%s (P51: %s)"):format(
		fmtV(SHUTTER_PANEL_SIZE), fmtV(M(pp.Position)), hid, why))
end

-- Leftovers of the hide spots inside the trailer (DEC-221): bind-created Prompt_Hide / Hide_Pose outside the
-- cabinets (the cabinets themselves are destroyed in bindTrailer). The shell's own Hide_1..4 mounts stay untagged.
local function removeHideLeftovers(trl: Instance)
	local n = 0
	for _, d in trl:GetDescendants() do
		if (d.Name == "Prompt_Hide" or d.Name == "Hide_Pose") and d.Parent then
			d:Destroy()
			n += 1
		end
	end
	if n > 0 then
		log("ok", ("TRL: %d leftover Prompt_Hide / Hide_Pose removed (DEC-221)"):format(n))
	end
end

-- Wave 3 (W2): AnomalyAnchor WV-1..3 on the apartment windows (ANM-006).
local function bindWindows(assets: Instance, root: Instance)
	local bldg = byMapId(assets, "Z-11", "AST-045_ApartmentBlock")
	if not bldg then
		log("warn", "Z-11 (AST-045_ApartmentBlock) not found: WV-1..3 use fallback Parts in MapBinding/Anomaly")
	end
	local folder: Instance? = nil
	for _, w in WINDOWS do
		local want = "Window_Up_" .. w.n
		local found: Instance? = nil
		if bldg then
			for _, d in bldg:GetDescendants() do
				if d.Name == want and (d:IsA("Model") or d:IsA("BasePart")) then
					found = d
					if d:IsA("Model") then
						break -- a Model groups glass, Lit, curtain and the waver empty: preferred
					end
				end
			end
		end
		if found then
			CollectionService:AddTag(found, "AnomalyAnchor")
			found:SetAttribute("AnchorId", w.id)
			log("ok", ("%s: AnomalyAnchor on %s at %s"):format(w.id, found:GetFullName(), fmtV(anchorPos(found))))
		else
			if not folder then
				local f = Instance.new("Folder")
				f.Name = "Anomaly"
				f.Parent = root
				folder = f
			end
			local p = Instance.new("Part")
			p.Name = w.id
			p.Size = Vector3.new(3, 3.4, 0.2)
			local c = Vector3.new(w.x, WINDOW_Y, WINDOW_Z)
			p.CFrame = FCF(CFrame.lookAt(c, c + SOUTH))
			makeInvisible(p)
			p.Parent = folder
			CollectionService:AddTag(p, "AnomalyAnchor")
			p:SetAttribute("AnchorId", w.id)
			log("warn", ("%s: %s not in the AST-045 (re-upload pending): fallback Part at %s"):format(w.id, want, fmtV(c)))
		end
	end
end

-- Wave 3 (W5): traffic routes, stop lines and boxes in MapBinding/Traffic (static; never move).
local function bindTraffic(root: Instance)
	local exclude: { Instance } = { root }
	local blockout = Workspace:FindFirstChild("MAP01_Blockout")
	if blockout and blockout:FindFirstChild("Markers") then
		table.insert(exclude, blockout.Markers)
	end
	local misses = 0
	local function roadY(x: number, z: number): number
		local y, why = floorY(x, z, ROAD_Y, exclude)
		if why then
			misses += 1
		end
		return y
	end
	local function folder(name: string, parent: Instance): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end
	local tf = folder("Traffic", root)
	local paths, lines, boxes = folder("Paths", tf), folder("Lines", tf), folder("Boxes", tf)

	for _, r in TRAFFIC_ROUTES do
		local f = folder(r.id, paths)
		CollectionService:AddTag(f, "TrafficPath")
		f:SetAttribute("PathId", r.id)
		local pos: { Vector3 } = {}
		for i, p in r.pts do
			pos[i] = Vector3.new(p[1], roadY(p[1], p[2]), p[2])
		end
		local len = 0
		for i, p in pos do
			local d = if i < #pos then pos[i + 1] - p else p - pos[i - 1]
			d = Vector3.new(d.X, 0, d.Z)
			local part = Instance.new("Part")
			part.Name = ("%02d"):format(i)
			part.Size = Vector3.one * 0.6
			part.CFrame = FCF(CFrame.lookAt(p, p + d.Unit))
			makeInvisible(part)
			part:SetAttribute("Index", i)
			part.Parent = f
			if i > 1 then
				len += (p - pos[i - 1]).Magnitude
			end
		end
		log("ok", ("TrafficPath %s: %d nodes, %.0f studs"):format(r.id, #pos, len))
	end
	for _, l in TRAFFIC_LINES do
		local p = Instance.new("Part")
		p.Name = l.id
		p.Size = Vector3.new(l.width, 0.2, 0.4)
		local c = Vector3.new(l.x, roadY(l.x, l.z) + 0.1, l.z)
		p.CFrame = FCF(CFrame.lookAt(c, c + l.dir))
		makeInvisible(p)
		p.Parent = lines
		CollectionService:AddTag(p, "TrafficLine")
		p:SetAttribute("LineId", l.id)
	end
	for _, b in TRAFFIC_BOXES do
		local p = Instance.new("Part")
		p.Name = b.id
		p.Size = Vector3.new(b.x1 - b.x0, TRAFFIC_BOX_H, b.z1 - b.z0)
		p.CFrame = FCF(CFrame.new((b.x0 + b.x1) / 2, ROAD_Y + TRAFFIC_BOX_H / 2, (b.z0 + b.z1) / 2))
		makeInvisible(p)
		p.Parent = boxes
		CollectionService:AddTag(p, "TrafficBox")
		p:SetAttribute("BoxId", b.id)
	end
	log("ok", ("Traffic: %d paths, %d stop lines, %d boxes in MapBinding/Traffic"):format(#TRAFFIC_ROUTES, #TRAFFIC_LINES, #TRAFFIC_BOXES))
	if misses > 0 then
		log("warn", ("Traffic: %d road raycast(s) missed or off by > 0.6; used Y %.2f there (road ends at X +-136 are expected)"):format(misses, ROAD_Y))
	end
end

-- W8: AutoDoor leaves (2026-10-10, Provisório; the client controller opens them by proximity, another agent).
-- Leaf = a visible BasePart of the door model whose name contains "door"/"leaf"/"glass"/"panel" (or DoorLeaf = true)
-- and not "frame" / "wall" / "jamb" / "header"; none in the Mart door -> placeholder glass Door_Leaf (contract of the
-- DoorController). Per leaf: tag AutoDoor, DoorId, DoorLeaf, DoorHinge, DoorAngle, DoorRadius (see below) and an
-- informative Attachment Door_Hinge on the hinge edge (double door: each leaf its outer edge; a hand-made one is kept).
-- CanCollide false on the server (DoorOrigCanCollide keeps the old value).
local DOORS = {
	{ id = "MKT-DOOR", mapId = "MKT-DOOR", asset = "AST-028_MartWallDoor", inward = Vector3.new(-1, 0, 1).Unit, placeholder = Vector3.new(4, 7.5, 0.2) }, -- into the Mart (chamfer at its NE corner: inside is west + south)
	{ id = "D1", mapId = "D1", asset = "AST-033_DoorD1", inward = EAST }, -- into B1
	{ id = "SP-B", mapId = "SP-B", asset = "AST-046_DoorSPB", inward = NORTH }, -- into the laundry
}
local DOOR_OPEN = 90

local function isLeafName(n: string): boolean
	local l = string.lower(n)
	if string.find(l, "frame") or string.find(l, "wall") or string.find(l, "jamb") or string.find(l, "header") or string.find(l, "sign") then
		return false
	end
	return string.find(l, "door") ~= nil or string.find(l, "leaf") ~= nil or string.find(l, "glass") ~= nil or string.find(l, "panel") ~= nil
end

local function bindAutoDoors(assets: Instance)
	for _, spec in DOORS do
		local model = byMapId(assets, spec.mapId, spec.asset)
		if not model then
			log("warn", ("AutoDoor %s: %s (%s) not placed"):format(spec.id, spec.mapId, spec.asset))
			continue
		end
		local leaves: { BasePart } = {}
		local names: { string } = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				table.insert(names, d.Name)
				if isLeafName(d.Name) or d:GetAttribute("DoorLeaf") == true then
					table.insert(leaves, d)
				end
			end
		end
		if #leaves == 0 and spec.placeholder then
			-- DoorController contract: no separate leaf in the mesh -> a placeholder glass leaf in the doorway (the
			-- mesh is one piece: its painted door cannot be hidden alone; the art-director splits it later)
			local old = model:FindFirstChild("Door_Leaf")
			if old then
				old:Destroy()
			end
			local pivot = (model :: any):GetPivot() :: CFrame
			local leaf = Instance.new("Part")
			leaf.Name = "Door_Leaf"
			leaf.Size = spec.placeholder
			leaf.CFrame = pivot * CFrame.new(0, spec.placeholder.Y / 2, 0)
			leaf.Anchored = true
			leaf.Material = Enum.Material.Glass
			leaf.Color = Color3.fromRGB(200, 230, 235)
			leaf.Transparency = 0.45
			leaf.CastShadow = false
			leaf:SetAttribute(CREATED, true)
			leaf.Parent = model
			table.insert(leaves, leaf)
			log("new", ("AutoDoor %s: no leaf in %s (parts: %s): placeholder Door_Leaf %s at %s (art-director: split the leaf in the mesh)"):format(spec.id, model:GetFullName(), table.concat(names, ", "), fmtV(spec.placeholder), fmtV(leaf.Position)))
		end
		if #leaves == 0 then
			log("warn", ("AutoDoor %s: no leaf part in %s (parts: %s). Tag the leaf by hand: tag AutoDoor, DoorLeaf, DoorHinge"):format(spec.id, model:GetFullName(), table.concat(names, ", ")))
			continue
		end
		-- doorway centre = centre of all the leaves
		local sum = Vector3.zero
		for _, p in leaves do
			sum += p.Position
		end
		local centre = sum / #leaves
		for _, p in leaves do
			-- width axis = the longer horizontal axis of the part
			local right = p.CFrame.RightVector
			local look = p.CFrame.LookVector
			local axis, w = right, p.Size.X
			if math.abs(look.Y) < 0.9 and p.Size.Z > p.Size.X then
				axis, w = look, p.Size.Z
			end
			axis = Vector3.new(axis.X, 0, axis.Z)
			axis = if axis.Magnitude > 1e-3 then axis.Unit else FD(EAST)
			local e1 = p.Position + axis * (w / 2)
			local e2 = p.Position - axis * (w / 2)
			local edge = if #leaves == 1 then e1 elseif (e1 - centre).Magnitude >= (e2 - centre).Magnitude then e1 else e2
			-- an empty "Hinge*" of the .fbx (AST-033 Door_D1 has Hinge_D1) wins for a single leaf
			local fbxHinge: Attachment? = nil
			for _, d in model:GetDescendants() do
				if d:IsA("Attachment") and string.sub(d.Name, 1, 5) == "Hinge" then
					fbxHinge = d
					break
				end
			end
			if #leaves == 1 and fbxHinge then
				edge = fbxHinge.WorldPosition
			elseif #leaves == 1 then
				log("warn", ("AutoDoor %s: single leaf %s, hinge put on its +width edge %s: check the side in Studio (move Door_Hinge by hand if wrong)"):format(spec.id, p:GetFullName(), fmtV(e1)))
			end
			local hinge = p:FindFirstChild("Door_Hinge")
			if hinge and not hinge:GetAttribute(CREATED) then
				log("ok", ("AutoDoor %s: Door_Hinge on %s authored by hand, kept"):format(spec.id, p.Name))
			else
				if hinge then
					hinge:Destroy()
				end
				local a = Instance.new("Attachment")
				a.Name = "Door_Hinge"
				a:SetAttribute(CREATED, true)
				a.Parent = p
				a.WorldCFrame = CFrame.new(Vector3.new(edge.X, p.Position.Y - p.Size.Y / 2, edge.Z)) -- Y axis = world up
				hinge = a
			end
			-- sign: the leaf centre turned +90 about the hinge must move towards the inside
			local h = (hinge :: Attachment).WorldPosition
			local r = p.Position - h
			local turned = CFrame.Angles(0, math.rad(DOOR_OPEN), 0):VectorToWorldSpace(Vector3.new(r.X, 0, r.Z))
			local sign = if (turned - Vector3.new(r.X, 0, r.Z)):Dot(FD(spec.inward)) >= 0 then 1 else -1 -- leaf geometry is world, inward MAP-01
			if p:GetAttribute("DoorOrigCanCollide") == nil then
				p:SetAttribute("DoorOrigCanCollide", p.CanCollide)
			end
			-- DoorController contract (commit of the frontend): tag on the LEAF (<= 10 wide, Anchored), DoorLeaf,
			-- DoorHinge Left/Right (turns 90; Right = hinge on the leaf's +RightVector edge, Provisório), DoorAngle
			-- (signed so the leaf swings INTO the building), DoorRadius 8. Only the client animates: the leaf has
			-- no collision on the server so NPCs walk through the doorway.
			if w > 10 then
				log("warn", ("AutoDoor %s: leaf %s is %.1f wide (> 10, DoorController limit)"):format(spec.id, p:GetFullName(), w))
			end
			local side = if (h - p.Position):Dot(p.CFrame.RightVector) >= 0 then "Right" else "Left"
			p.Anchored = true
			p.CanCollide = false
			CollectionService:AddTag(p, "AutoDoor")
			p:SetAttribute("DoorId", spec.id)
			p:SetAttribute("DoorLeaf", true)
			p:SetAttribute("DoorHinge", side)
			p:SetAttribute("DoorAngle", sign * DOOR_OPEN)
			p:SetAttribute("DoorRadius", 8)
			log("new", ("AutoDoor %s: leaf %s, DoorHinge %s (Door_Hinge %s), DoorAngle %d (inward), CanCollide off"):format(spec.id, p:GetFullName(), side, fmtV(h), sign * DOOR_OPEN))
		end
		setPersistent(model)
	end
end

-- W7: helpers locked (Studio click-select off) and out of touch / query when nothing reads them that way.
local function lockOne(p: BasePart): boolean
	local changed = not p.Locked or p.CanTouch
	p.Locked = true
	p.CanTouch = false
	if not p.CanCollide and p.CanQuery and p.Transparency >= 0.75 then
		p.CanQuery = false
		changed = true
	end
	return changed
end

local function lockHelpers(assets: Instance, root: Instance): number
	local n = 0
	-- the whole binding (points, nodes, zones, traffic, anomaly fallbacks): invisible data parts
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and lockOne(d) then
			n += 1
		end
	end
	-- bind-created helpers inside the assets (lamp holders, shelf anchors, tarp, placeholders) and hidden parts
	for _, d in assets:GetDescendants() do
		-- visible created placeholders (shutter button plate, Shutter_Panel) stay selectable: the user tunes them by hand
		if d:IsA("BasePart") and d.Transparency >= 0.99 and not CollectionService:HasTag(d, "AutoDoor") then
			-- hidden upgrade pieces / fixed parts keep CanQuery as their owners left it (they restore it themselves)
			if d:GetAttribute("UpgHidden") or d:GetAttribute("PieceFixed") or d.Name == "Cover" then
				if not d.Locked then
					d.Locked = true
					n += 1
				end
			elseif lockOne(d) then
				n += 1
			end
		end
	end
	-- blockout: markers, limits (keep collision), hidden pieces (place_assets.hide) and translucent zones / ghosts
	local blockout = Workspace:FindFirstChild("MAP01_Blockout")
	if blockout then
		for _, d in blockout:GetDescendants() do
			if d:IsA("BasePart") then
				local inHelper = (blockout:FindFirstChild("Markers") and d:IsDescendantOf(blockout.Markers))
					or (blockout:FindFirstChild("Limits") and d:IsDescendantOf(blockout.Limits))
				if inHelper or d.Transparency >= 0.75 then
					if lockOne(d) then
						n += 1
					end
				end
			end
		end
	end
	return n
end

-- W9: the default SpawnLocation template (star decal) left in the crossing goes to ServerStorage.DevScenes (reversible).
local function parkStraySpawn(): number
	local n = 0
	for _, d in Workspace:GetChildren() do
		if d:IsA("SpawnLocation") and d.Name == "SpawnLocation" then
			local dev = ServerStorage:FindFirstChild("DevScenes")
			if not dev then
				dev = Instance.new("Folder")
				dev.Name = "DevScenes"
				dev.Parent = ServerStorage
			end
			d.Parent = dev
			n += 1
		end
	end
	return n
end

-- Persistent on every Model that is, or contains, a tagged instance (§18.0 item 6).
local function persistAll(): number
	local n = 0
	for _, tag in OWN_TAGS do
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsDescendantOf(Workspace) then
				local node: Instance? = inst
				while node and node ~= Workspace do
					if node:IsA("Model") and node.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
						node.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
						n += 1
					end
					node = node.Parent
				end
			end
		end
	end
	return n
end

---------------------------------------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------------------------------------

function Bind.run(opts: AnchorOpts?): string
	local o: AnchorOpts = opts or {}
	table.clear(report)
	for k in counts do
		counts[k] = 0
	end

	local assets = Workspace:FindFirstChild(ASSETS_ROOT)
	if not assets then
		return "[err] workspace." .. ASSETS_ROOT .. " not found: run place_assets.luau Place.run first"
	end
	local merged = mergeLayers(assets)
	log("ok", ("layers: %d folder(s) brought from ServerStorage (both vehicles in the Workspace, T36). Do not use Place.showLayer after this"):format(merged))
	if not byMapId(assets, "CART") then
		return "[err] the cart set (MapId CART) is not in MAP01_Assets nor in ServerStorage.MAP01_Assets_Day. Run Place.run first"
	end

	unbindPieces(assets)
	cleanSlate(assets)
	local cart = bindCart(assets, o)
	local trl, padPose, salePose = bindTrailer(assets, cart, o)
	-- phones last: the clearance looks at every other prompt of the vehicle
	if cart then
		bindPhone(cart, "CART-PHONE", o)
		clearUp(findNamed(cart, "Prompt_Answer"), cart, PHONE_GAP, "CART-PHONE")
	end
	if trl then
		bindPhone(trl, "TRL-PHONE", o)
		clearUp(findNamed(trl, "Prompt_Answer"), trl, PHONE_GAP, "TRL-PHONE")
		-- wave 3 (DEC-221): service window last, the button clears every other prompt of the trailer (phone included)
		removeHideLeftovers(trl)
		bindShutterButton(trl, padPose, o)
		bindShutterPiece(trl, padPose)
	end
	bindOpenSign(assets, o)
	bindMart(assets, o)
	bindStreetBins(assets, o)
	bindStreetLights(assets)
	bindAutoDoors(assets)

	local cartPose = if cart then mapPivot(cart) else CART_POSE
	if (cartPose.Position - CART_POSE.Position).Magnitude > 0.05 then
		log("warn", ("CART pivot %s differs from the binding constant %s; the actual pivot is used as CART"):format(fmtV(cartPose.Position), fmtV(CART_POSE.Position)))
	end
	local root = bindPoints({ cart = cart, trailer = trl, poses = { cart = cartPose, trl = padPose, sale = salePose }, assets = assets })
	bindLightZones(root, padPose)
	bindWindows(assets, root)
	bindTraffic(root)
	local parked = parkStraySpawn()
	if parked > 0 then
		log("conv", ("W9: %d stray Workspace.SpawnLocation (star decal in the crossing) moved to ServerStorage.DevScenes"):format(parked))
	end
	local locked = lockHelpers(assets, root)
	log("ok", ("helpers: %d invisible / helper part(s) Locked (no click-select), CanTouch off, CanQuery off where they do not collide (W7)"):format(locked))
	local p = persistAll()
	log("ok", ("ModelStreamingMode = Persistent set on %d more model(s)"):format(p))

	-- start of a run: trailer for sale (T36, DEC-047)
	if trl then
		(trl :: any):PivotTo(FCF(salePose))
		log("ok", ("TRL: trailer parked at TRL-SALE %s (VehicleService moves it to TRL on the swap)"):format(fmtV(salePose.Position)))
	end

	local tagCounts = {}
	for _, tag in OWN_TAGS do
		local c = 0
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsDescendantOf(Workspace) then
				c += 1
			end
		end
		table.insert(tagCounts, ("%s=%d"):format(tag, c))
	end

	local head = ("bind_map01 (waves 1+2+3): ok %d | new %d | conv %d | warn %d | err %d\ntags in Workspace: %s\n"):format(
		counts.ok,
		counts.new,
		counts.conv,
		counts.warn,
		counts.err,
		table.concat(tagCounts, ", ")
	)
	local body = table.concat(report, "\n")
	return head .. body .. "\nNext: run bind_pieces.luau (Pieces.run(), TASK-085), then check_map01.luau (Check.run({ wave = 3 }))."
end

return Bind
