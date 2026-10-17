--[[
	MAP-01 "Ninth & Juniper" - placement table of the real assets (technical prototype, Phase 0).
	DATA ONLY. Status: Draft (level-designer, 2026-10-10). Not gameplay code.

	Sources: docs/levels/MAP-01.md (rev. 3, final adjustment), tools/blockout/MAP-01_blockout.luau,
	Assets/import/_export_log.json + Assets/import/<cat>/*.fbx, docs/art/asset-sourcing.md,
	DEC-137..DEC-147. Every FBX was re-measured (import into a temp Blender scene, converted to
	Roblox axes, 1 unit = 1 stud): bbox, pivot, empties (Mount_*, Att_*, Prompt_*).

	ORIENTATION FIX (2026-10-10, main session): Roblox raycast on the placed grill showed the knob
	panel of our modelled FBX faces local -Z (LookVector), not +Z as measured above. rotY of every
	modelled asset (Assets/blender sources) except the cart/trailer shells and the lamp head was
	turned +180. Pack pieces unchanged. Lamp heads re-aligned to the measured arm tip of each pole
	(raycast in Studio; the head FBX is also turned 180, so the old foot-based offset put the dome behind the pole).
	Cart/trailer shells: +180 as well (service window/queue side is local -Z in the imported FBX, verified in
	Studio: window was facing south). Station positions unchanged (they come from the mounts).

	==============================================================================================
	CONVENTIONS
	==============================================================================================
	- MAP FRAME (2026-10-10, user's decision): the place is turned 180 in Y around (0, 33.94). The numbers here stay
	  MAP-01 coordinates; place_assets.luau puts every entry at MAP_FRAME * CFrame(x, y, z, rotY) (map_frame.luau).
	- x, z: MAP-01 coords (origin = Juniper centre on the Ninth axis, +X east, +Z south).
	  y: ABSOLUTE world height of the asset pivot (pivot = bottom centre of the bbox).
	- rotY: degrees, CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotY), 0).
	  With this, local +Z points to world (sin rotY, cos rotY): 0 = +Z faces south, 90 = east,
	  180 = north, 270 = west. LookVector (local -Z) is the opposite.
	- replaces: paths inside workspace.MAP01_Blockout that become invisible when the asset is in
	  (exact names created by the blockout script). Markers, routes, zones, limits and tags are
	  never listed. A path may repeat on several entries (hiding is idempotent).
	- Optional fields:
	    part  = mesh names to KEEP from a multi-variant FBX (hide the other MeshParts of the model).
	    layer = "day" (cart, visible by default) | "night" (Pad trailer; starts hidden, same state
	            as the TRL ghost of the blockout). Entries without layer are always visible.
	    paint = colour variant of AST-035 (Paint mesh / _Paints).
	    note  = short warning for the person doing the swap.
	    Hand edits made in Studio (2026-10-10, applied by place_assets.luau build(); Place.diff checks them):
	    drop   = { mesh names } removed from the model.
	    parts  = { [mesh] = { x, y, z, rotY = deg?, rotX = deg?, rotZ = deg?, size = { sx, sy, sz }? } } mesh centre
	             in the ASSET frame (relative to the entry's x/y/z/rotY), extra rotation over the template (Y * X * Z), new size.
	    copies = { { part = mesh, x, y, z, rotY = deg? } } extra clones of a mesh, same rule.
	    pivot  = { x, y, z, rotY } Model.WorldPivot in the placement frame (same coordinates as x/y/z).

	==============================================================================================
	MEASURED FACTS THAT DRIVE THE ROTATIONS (read before swapping)
	==============================================================================================
	1. "Front = -Z" does NOT hold for our modelled FBX. In Roblox axes the user-facing side is +Z
	   for every modelled asset: prompts of AST-012..025/039/042/049, headlights + Hit_Front of
	   AST-035/052, seats of AST-034_ParkBench, storefront of the Kenney CC buildings.
	   Pack pieces (MM walls/fridge/checkout, KP cabinets) have their detailed face at -Z.
	   The rotY of every entry already accounts for the real side of that asset.
	2. Cart AST-026 and trailer AST-027 (current FBX, rotated 180 vs the _atts.json): the QUEUE
	   side (Mount_Sign, Mount_Counter, awning, Decal_SignFront) is local +Z; operator side,
	   Zone_Center, Mount_Trash and back door are local -Z. rotY = 180 puts everything on MAP-01:
	   grill at X 33.5, Parasol_E to the east, back door X 47..51 / Z 47, hitch to X 21.5,
	   Mount_Trash exactly on BIN-C (56, 42), Hide_1..4 exactly on the old H1..H4 (removed, DEC-221). So the asset LookVector
	   ends up facing SOUTH (operator), not the queue. If the modeler meant "front = queue", the
	   FBX is still flipped; the table does not care (positions are verified by the mounts).
	3. Station positions = vehicle pivot + mount offset. Because the FBX turned 180 and the vehicle
	   turns 180 again, world = pivot + (x, y, z) of the *_atts.json files (old axes).
	   Cart pivot (41, 0.45, 37.5) on the Pad top (Y_PAD 0.45); trailer pivot (40, 0.45, 41).
	4. Equipment rotY does NOT copy the mount rotY_deg blindly:
	   - Grid AST-017 + holder AST-016 + register AST-020: rotY 180. Only this matches MAP-01 §7.1
	     (front row Ketchup/Mustard/Cheese west -> east facing the queue; delivery stand X 50..52,
	     drawer X 52..54). Their Prompt_Serve / Prompt_Drawer end up on the queue side (north).
	   - Cooler, grill, rail, bun crate, board, phone: rotY 0 (prompts, knife edge, low end of the
	     rail face the operator in the corridor).
	   - Cart trash: rotY 270 (pedal faces the corridor, west). Mount_Trash says 90 = pedal east.
	   - Trailer back-row items (coffee, trash, switch): rotY 180 (face the corridor, north).
	     Trailer bench is a KP pack piece (front -Z): bench 0 (the Hide cabinets left with DEC-221).
	5. Street light: AST-036_StreetLightCurved pivot is the bbox centre; the pole foot is at local
	   (0, 0, -1.815) and the arm points to local +Z (bbox z -2.33..2.33, foot centre z -1.815).
	   AST-036_LampHead pivot = pole foot of the pack (dome at local z 2.63..4.63, y 13.0..14.45 ->
	   arm 3.6, total 14.45, same as DEC-140). Hence, for a foot F and arm direction d:
	       pole.pivot = F + 1.815 * d,  head.pivot = F,  same rotY (local +Z = d).
	   ASSUMED OFFSET: 1.815 studs (measured). The blockout SpotLight lives in <post>/Lamp (hidden,
	   still lit) ~0.6 above and 0.6 short of the new head; move it to LampHead.Light_Lamp later.
	6. Road tiles AST-032 (24 x 24): levels 0 / 0.24 (asphalt) / 0.48 (curb strip). The strip is
	   2.4 wide on each side INSIDE the tile, so asphalt is 19.2 wide (MAP-01 Juniper: 24). Lanes
	   at X -6 / +6 still fit (car 7 wide -> 2.5..9.5). Road tiles at y -0.24 keep asphalt at Y 0
	   (flush with the Ninth, CW-1 stripes, SL lines and the yellow centre lines, which stay).
	   SidewalkTile is a 0.48 slab: at y -0.24 its top (0.24) matches the curb strip.
	   Result: Juniper sidewalks at 0.24, Ninth sidewalks / plaza at 0.4 (blockout) -> 0.16 step at
	   the Z -32 / Z 32 seams. Props on Juniper sidewalks use y 0.24.
	   Juniper sidewalk tiles are 24 wide over 12-wide sidewalks: the outer 12 lies inside the Pad,
	   the plaza, buildings or the alleys (hidden or paving the alleys AS-3 / SP-A).
	7. Mart walls AST-028 are SOLID blocks 8 x 12 x 4.8 (interior green stripe on local -Z,
	   exterior on +Z). Placed with the inner face on the MAP-01 interior line (X -100..-64,
	   Z 32..64), so the shop keeps 36 x 32; the north facade grows 4.8 into the sidewalk
	   (exterior face at Z 27.2) and the east facade 4.8 into the plaza (X -59.2). West and south
	   modules sit inside Fill_SW_West / Fill_SW_MartRear (only the interior face shows).
	   The chamfered NE corner is approximated by one MartWallDoor turned 135 degrees, inner face
	   ~on the chamfer: it overlaps the west rim of the SS marking by ~2.3 (SS-1..4 stay clear).
	8. Kenney buildings: storefront on local +Z (renders). BuildingA 16.4 x 24 x 17.45,
	   BuildingH 16.4 x 24 x 18.71; facades sit on the MAP lot line, lots are filled with whole
	   buildings in a row (16.4 modules), small gaps noted below. ApartmentBlock is symmetric
	   front/back. Laundry door estimated at local x ~ -3 on the +Z face (from render, +-1) ->
	   centre X -37 puts it on SP-B (X -40).

	==============================================================================================
	LEFT OUT (blockout stays) AND WHY
	==============================================================================================
	- (2026-10-10, user's print: Kenney tile next to blockout asphalt at the corner) Ninth Avenue, the intersection,
	  BackStreet and the Ninth sidewalks now use AST-032 tiles scaled with `parts.size` (see section 1). Only the
	  Juniper sidewalk strip Z -136..-128 (8) stays a gap at ground level (Z-13, beyond BAR-N, in the fog).
	- Kenney crossing tile not used for CW-1: its stripes are centred on the tile (~7.6 wide) and
	  CW-1 (Z 34..42) would need a tile at Z 26..50, leaving a 10-stud hole at Z 16..26. CW-1..4,
	  SL lines and the yellow centre lines stay as blockout paint (the tiles also carry a thin
	  white centre line; recolour is the art-director's call).
	- Pad floor, plaza, parking lot, red curb, stall lines, parking fence, plaza tables: no asset.
	- Fill_* boxes (background masses): replaced by Kenney A/H + BG cards in section 8 (2026-10-10, ambience pass).
	- TRUCK (AST-048, no new model). Ambulance + stretcher (AST-052) and long car (AST-065):
	  dynamic actors, not static scenery.
	- PARE-N / PARE-S (CR stop sign is excluded in asset-sourcing), CoffeeRack, ProduceSign,
	  Opal OP-1: no asset yet or they are ID anchors. (2026-10-10, modeler-3d: Marquee, SS marking,
	  C-01 + hands, WV-1..3, BankSign, BankDoor, Door_D1, Door_SP-B and the three "NO HELP WANTED"
	  windows now have assets - AST-028 / AST-033 / AST-044 / AST-045 / AST-046 entries below.)
	- P-01 flyer (AST-037): not in this pass. The blockout flyer sits 0.36 from the pole axis, the
	  new pole has radius 0.52 -> the flyer ends up INSIDE the pole (move to ~0.56 when swapped).
	- Mount_Counter (cart and trailer): no asset fits (AST-019 counter is 3.5 tall, the mount is at
	  counter-top height). Cart Mount_Sign is the skirt decal (AST-072), not the OPEN sign.
	- Bottles AST-004/005 on the holder (Att_Bottle_*): editing in progress, runtime.
	- Upgrade states (CoolerL2/L3, Lock, grill levels): runtime (TASK-084 kit, TASK-085 binding). The CART-S / TRL-S,
	  CART-G / TRL-G, DRAWER Lock and TRL-LIGHTS entries below stay: bind_pieces.luau aligns the kit pieces on them,
	  then hides them (Fixed_*) and keeps them as hosts of the bind anchors. Counter has no entry (piece pose in
	  bind_pieces.luau COUNTER_POSE). AST-043 tarp: not
  modelled; bind_map01 puts a hidden grey placeholder (tag VehicleCover) inside the cart (TASK-083).
- 2026-10-10 (TASK-083): after Place.run, bind_map01 brings the night layer into the Workspace for good (both
  vehicles live there, T36) and parks the trailer at TRL-SALE. Place.showLayer is no longer used after a bind.
	- AST-050_BunDisplay: MAP-01 §7.4 has no slot for it (buns are bought at the gondola, Q-135).
	- Not used: AST-034_Cone (same role as AST-047_ConstructionCone), AST-036_StreetLightSquare,
	  AST-047_WorkLight.

	==============================================================================================
	CONFLICTS / OPEN POINTS FOUND (for the user and the art-director)
	==============================================================================================
	- (solved 2026-10-10, modeler-3d) Bellmoor Savings split into AST-044 (ground 0..18, full lot
	  X 24..52 / Z -64..-32, closes the void behind the bank) + AST-045 (floors 2-3, 18..30, WV-1..3).
	- Void inside the B1 block (X 81..113, Z 50..88) visible from the EX-E alley; 6.6 gap between
	  B3a and B2b (X -72..-65.4, tree T-03 in front of it).
	- AST-024 OPEN sign is 4 tall; DEC-048 / MAP-01 §5.1 ask <= 3. SIGN-T needs 4 x 5 (asset 2 x 4).
	- AST-030 fridge is 7 tall and one-sided; MAP-01 asks low fridges, and Bacon (-81, 44) is bought
	  at the back of the north fridge.
	- Cart phone (on the Parasol_E pole, Mount_Phone): new AST-042 model (2026-10-10) sits on its own shelf at 4.85,
	  above the topping grid (top 4.75); not verified in Studio yet (raycast the dial side: must face south).
	- AST-028_MartAwning still has its legs (edition pending in AST-028); side not confirmed.
	- AST-031 checkout side not confirmed (detail side -Z put towards Opal).
	- Rail: the FBX has Rail_6 and Rail_8 on top of each other; cart Rail_6, trailer Rail_8 (TASK-083).
	- Barriers moved 0.8 towards the play area (Z -74.0 / 78.0) so they do not cut the cones.
]]

return {
	---------------------------------------------------------------------------------------------
	-- 1. ROADS (Juniper only; road tiles rotY 90 = carriageway along Z) and SIDEWALKS
	---------------------------------------------------------------------------------------------
	-- 2026-10-10 (user, print of the corner): the Ninth, the crossing and the BackStreet get AST-032 tiles too (no more
	-- blockout asphalt next to the Kenney tiles). First / last Juniper tiles trimmed to 20 / 22 long so the crossroads
	-- (Z -20..20 and Z -154..-134) do not overlap them.
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -30, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 20, 0.48, 24 } } }, group = "Roads", id = "Z-07", replaces = { "Roads/Juniper_North" }, note = "Z -40..-20 (trimmed 24 -> 20 for the crossroad)" },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -52, rotY = 90, group = "Roads", id = "Z-07", replaces = { "Roads/Juniper_North" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -76, rotY = 90, group = "Roads", id = "Z-07", replaces = { "Roads/Juniper_North" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -100, rotY = 90, group = "Roads", id = "Z-13", replaces = { "Roads/Juniper_North" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -123, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 22, 0.48, 24 } } }, group = "Roads", id = "Z-13", replaces = { "Roads/Juniper_North" }, note = "Z -134..-112 (trimmed 24 -> 22 for the BackStreet crossroad)" },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 30, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 20, 0.48, 24 } } }, group = "Roads", id = "Z-08", replaces = { "Roads/Juniper_South" }, note = "Z 20..40 (trimmed 24 -> 20 for the crossroad)" },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 52, rotY = 90, group = "Roads", id = "Z-08", replaces = { "Roads/Juniper_South" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 76, rotY = 90, group = "Roads", id = "Z-08", replaces = { "Roads/Juniper_South" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 100, rotY = 90, group = "Roads", id = "Z-08", replaces = { "Roads/Juniper_South" } },
	{ asset = "AST-032_RoadStraightHalf", x = 0, y = -0.24, z = 118, rotY = 90, group = "Roads", id = "Z-08", replaces = { "Roads/Juniper_South" }, note = "covers Z 112..124 (blockout road ended at 120; out of view after the curve)" },
	-- Ninth Avenue (Z-03, X -136..136, Z -16..16) along X: 5 + 5 tiles 24.8 long, scaled across to 40 so the asphalt
	-- (19.2 of 24) is exactly the 32 of the Ninth and the curb strips (|Z| 16..20, top 0.24) end up inside the Ninth
	-- sidewalk tiles (top 0.4); lanes, lines, SL-* and CW-2/3/4 stripes of the blockout stay on top (asphalt Y 0).
	{ asset = "AST-032_RoadStraight", x = -24.4, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 40 } } }, group = "Roads", id = "Z-03", replaces = { "Roads/NinthAvenue" } },
	{ asset = "AST-032_RoadStraight", x = -49.2, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 40 } } }, group = "Roads", id = "Z-03", replaces = { "Roads/NinthAvenue" } },
	{ asset = "AST-032_RoadStraight", x = -74, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 40 } } }, group = "Roads", id = "Z-03", replaces = { "Roads/NinthAvenue" } },
	{ asset = "AST-032_RoadStraight", x = -98.8, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 40 } } }, group = "Roads", id = "Z-03", replaces = { "Roads/NinthAvenue" } },
	{ asset = "AST-032_RoadStraight", x = -123.6, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 40 } } }, group = "Roads", id = "Z-03", replaces = { "Roads/NinthAvenue" } },
	{ asset = "AST-032_RoadStraight", x = 24.4, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 40 } } }, group = "Roads", id = "Z-03", replaces = { "Roads/NinthAvenue" } },
	{ asset = "AST-032_RoadStraight", x = 49.2, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 40 } } }, group = "Roads", id = "Z-03", replaces = { "Roads/NinthAvenue" } },
	{ asset = "AST-032_RoadStraight", x = 74, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 40 } } }, group = "Roads", id = "Z-03", replaces = { "Roads/NinthAvenue" } },
	{ asset = "AST-032_RoadStraight", x = 98.8, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 40 } } }, group = "Roads", id = "Z-03", replaces = { "Roads/NinthAvenue" } },
	{ asset = "AST-032_RoadStraight", x = 123.6, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 40 } } }, group = "Roads", id = "Z-03", replaces = { "Roads/NinthAvenue" } },
	{ asset = "AST-032_RoadCrossroad", x = 0, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadCrossroad"] = { 0, 0.24, 0, size = { 24, 0.48, 40 } } }, group = "Roads", id = "Z-03", replaces = { "Roads/NinthAvenue" }, note = "2026-10-10: X -12..12, Z -20..20; corner curbs (X +-9.6..12, Z +-16..20) continue the Juniper curbs; Ninth arms open" },
	{ asset = "AST-032_RoadStraight", x = -24.4, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 20 } } }, group = "Roads", id = "Z-13", replaces = { "Roads/BackStreet" } },
	{ asset = "AST-032_RoadStraight", x = -49.2, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 20 } } }, group = "Roads", id = "Z-13", replaces = { "Roads/BackStreet" } },
	{ asset = "AST-032_RoadStraight", x = -74, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 20 } } }, group = "Roads", id = "Z-13", replaces = { "Roads/BackStreet" } },
	{ asset = "AST-032_RoadStraight", x = -98.8, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 20 } } }, group = "Roads", id = "Z-13", replaces = { "Roads/BackStreet" } },
	{ asset = "AST-032_RoadStraight", x = -123.6, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 20 } } }, group = "Roads", id = "Z-13", replaces = { "Roads/BackStreet" } },
	{ asset = "AST-032_RoadStraight", x = 24.4, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 20 } } }, group = "Roads", id = "Z-13", replaces = { "Roads/BackStreet" } },
	{ asset = "AST-032_RoadStraight", x = 49.2, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 20 } } }, group = "Roads", id = "Z-13", replaces = { "Roads/BackStreet" } },
	{ asset = "AST-032_RoadStraight", x = 74, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 20 } } }, group = "Roads", id = "Z-13", replaces = { "Roads/BackStreet" } },
	{ asset = "AST-032_RoadStraight", x = 98.8, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 20 } } }, group = "Roads", id = "Z-13", replaces = { "Roads/BackStreet" } },
	{ asset = "AST-032_RoadStraight", x = 123.6, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24.8, 0.48, 20 } } }, group = "Roads", id = "Z-13", replaces = { "Roads/BackStreet" } },
	{ asset = "AST-032_RoadCrossroad", x = 0, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadCrossroad"] = { 0, 0.24, 0, size = { 24, 0.48, 20 } } }, group = "Roads", id = "Z-13", replaces = { "Roads/BackStreet" }, note = "2026-10-10: Juniper North meets the BackStreet (Z -154..-134)" },
	{ asset = "AST-032_SidewalkTile", x = -24.4, y = -0.08, z = -24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, -1.999, size = { 24.8, 0.48, 12.001 } } }, group = "Sidewalks", id = "Z-06", replaces = { "Sidewalks/Z-06_NinthNorth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -49.2, y = -0.08, z = -24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, -2, size = { 24.8, 0.48, 12 } } }, group = "Sidewalks", id = "Z-06", replaces = { "Sidewalks/Z-06_NinthNorth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -74, y = -0.08, z = -24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, -2.001, size = { 24.8, 0.48, 11.998 } } }, group = "Sidewalks", id = "Z-06", replaces = { "Sidewalks/Z-06_NinthNorth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -98.8, y = -0.08, z = -24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, -2.002, size = { 24.8, 0.48, 11.997 } } }, group = "Sidewalks", id = "Z-06", replaces = { "Sidewalks/Z-06_NinthNorth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -123.6, y = -0.08, z = -24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, -2.003, size = { 24.8, 0.48, 11.995 } } }, group = "Sidewalks", id = "Z-06", replaces = { "Sidewalks/Z-06_NinthNorth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 24.4, y = -0.08, z = -24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, -1.997, size = { 24.8, 0.48, 12.005 } } }, group = "Sidewalks", id = "Z-06", replaces = { "Sidewalks/Z-06_NinthNorth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 49.2, y = -0.08, z = -24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, -1.997, size = { 24.8, 0.48, 12.006 } } }, group = "Sidewalks", id = "Z-06", replaces = { "Sidewalks/Z-06_NinthNorth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 74, y = -0.08, z = -24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, -1.997, size = { 24.8, 0.48, 12.006 } } }, group = "Sidewalks", id = "Z-06", replaces = { "Sidewalks/Z-06_NinthNorth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 98.8, y = -0.08, z = -24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, -1.997, size = { 24.8, 0.48, 12.007 } } }, group = "Sidewalks", id = "Z-06", replaces = { "Sidewalks/Z-06_NinthNorth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 123.6, y = -0.08, z = -24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, -1.996, size = { 24.8, 0.48, 12.007 } } }, group = "Sidewalks", id = "Z-06", replaces = { "Sidewalks/Z-06_NinthNorth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -24.4, y = -0.08, z = 24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 1.997, size = { 24.8, 0.48, 12.005 } } }, group = "Sidewalks", id = "Z-02", replaces = { "Sidewalks/Z-02_NinthSouth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -49.2, y = -0.08, z = 24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 1.99, size = { 24.8, 0.48, 12.02 } } }, group = "Sidewalks", id = "Z-02", replaces = { "Sidewalks/Z-02_NinthSouth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -74, y = -0.08, z = 24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 2.002, size = { 24.8, 0.48, 11.996 } } }, group = "Sidewalks", id = "Z-02", replaces = { "Sidewalks/Z-02_NinthSouth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -98.8, y = -0.08, z = 24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 1.992, size = { 24.8, 0.48, 12.016 } } }, group = "Sidewalks", id = "Z-02", replaces = { "Sidewalks/Z-02_NinthSouth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -123.6, y = -0.08, z = 24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 2.016, size = { 24.8, 0.48, 11.969 } } }, group = "Sidewalks", id = "Z-02", replaces = { "Sidewalks/Z-02_NinthSouth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 24.4, y = -0.08, z = 24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 1.998, size = { 24.8, 0.48, 12.005 } } }, group = "Sidewalks", id = "Z-02", replaces = { "Sidewalks/Z-02_NinthSouth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 49.2, y = -0.08, z = 24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 2.002, size = { 24.8, 0.48, 11.996 } } }, group = "Sidewalks", id = "Z-02", replaces = { "Sidewalks/Z-02_NinthSouth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 74, y = -0.08, z = 24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 2.003, size = { 24.8, 0.48, 11.994 } } }, group = "Sidewalks", id = "Z-02", replaces = { "Sidewalks/Z-02_NinthSouth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 98.8, y = -0.08, z = 24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 2.004, size = { 24.8, 0.48, 11.993 } } }, group = "Sidewalks", id = "Z-02", replaces = { "Sidewalks/Z-02_NinthSouth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 123.6, y = -0.08, z = 24, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 2.005, size = { 24.8, 0.48, 11.991 } } }, group = "Sidewalks", id = "Z-02", replaces = { "Sidewalks/Z-02_NinthSouth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },

	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = -44, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.4, 0 } }, group = "Sidewalks", id = "Z-07", replaces = { "Sidewalks/JuniperNorth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = -68, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.4, 0 } }, group = "Sidewalks", id = "Z-07", replaces = { "Sidewalks/JuniperNorth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = -92, rotY = 0, group = "Sidewalks", id = "Z-13", replaces = { "Sidewalks/JuniperNorth_W" } },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = -116, rotY = 0, group = "Sidewalks", id = "Z-13", replaces = { "Sidewalks/JuniperNorth_W" }, note = "Z -136..-128 left as a gap" },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = -44, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.4, 0 } }, group = "Sidewalks", id = "Z-07", replaces = { "Sidewalks/JuniperNorth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = -68, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.4, 0 } }, group = "Sidewalks", id = "Z-07", replaces = { "Sidewalks/JuniperNorth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = -92, rotY = 0, group = "Sidewalks", id = "Z-13", replaces = { "Sidewalks/JuniperNorth_E" } },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = -116, rotY = 0, group = "Sidewalks", id = "Z-13", replaces = { "Sidewalks/JuniperNorth_E" }, note = "Z -136..-128 left as a gap" },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = 44, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 6, 0.397, 0, size = { 12, 0.48, 24 } } }, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_W" }, note = "west half hidden inside the plaza slab" },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = 68, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.397, 0 } }, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = 92, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.397, 0 } }, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = 116, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.397, -2, size = { 24, 0.48, 19.999 } } }, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = 44, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.4, 0 } }, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_E" }, note = "east half hidden inside the Pad slab" },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = 68, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.4, 0 } }, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = 92, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.4, 0 } }, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = 116, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.4, -1.999, size = { 24, 0.48, 20.002 } } }, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_E" }, note = "user 2026-10-11: edited in Studio (captured)" },

	---------------------------------------------------------------------------------------------
	-- 2a. CORNER CART (tier 1, day) + stations on its mounts. Pivot (41, 0.45, 37.5), rotY 180.
-- 2026-10-10: user lowered the cart body 3.5 -> 3.0 tall in Studio; counter mounts now at y 3.45 (Pad 0.45 + 3.0).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-026_CornerCart", x = 41, y = 0.45, z = 37.5, rotY = 0, parts = { ["Parasol_W"] = { -6.5, 5.926, -1.624, rotX = -6.3, size = { 12.9, 6.372, 10.014 } }, ["Parasol_E"] = { 6.5, 5.901, -1.77, rotX = -9 } }, group = "Cart", id = "CART", layer = "day", replaces = { "Pad/CART/Base", "Pad/CART/UmbrellaPole_1", "Pad/CART/UmbrellaPole_2", "Pad/CART/Umbrella_1", "Pad/CART/Umbrella_2" }, note = "queue side is local +Z; LookVector faces the operator (south). 2026-10-10 hand edit (user, Studio): parasols tilted 9 / 6.3 deg" },
	{ asset = "AST-018_CoolerL1", x = 29.5, y = 0.95, z = 37.66, rotY = 180, group = "Cart", id = "CART-S", layer = "day", replaces = { "Pad/CART/1_S_Stock" }, note = "Mount_StockSausage (low, inside the cart body)" },
	{ asset = "AST-012_RollerGrill", part = { "Grill_L1" }, x = 33.5, y = 3.45, z = 37.5, rotY = 180, group = "Cart", id = "CART-G", layer = "day", replaces = { "Pad/CART/2_G_Grill", "Pad/CART/GrillPlate" } },
	{ asset = "AST-013_RestRail", part = { "Rail_6" }, x = 37.5, y = 3.45, z = 37.5, rotY = 180, group = "Cart", id = "CART-R", layer = "day", replaces = { "Pad/CART/3_R_Rest" }, note = "low end + Prompt_Rail towards the operator" },
	{ asset = "AST-015_BunCrate", x = 40, y = 3.45, z = 37.5, rotY = 180, group = "Cart", id = "CART-B", layer = "day", replaces = { "Pad/CART/4_B_Bun" } },
	{ asset = "AST-014_CuttingBoard", x = 42.5, y = 3.45, z = 37.5, rotY = 0, parts = { ["Knife"] = { 0, 0.163, -0.1, size = { 1.246, 0.083, 0.276 } }, ["Board"] = { 0, 0.06, 0.1, size = { 2.6, 0.12, 1.7 } } }, group = "Cart", id = "CART-T", layer = "day", replaces = { "Pad/CART/5_T_Board" }, note = "2026-10-10 matched to the trailer board (user)" },
	{ asset = "AST-017_ToppingGrid", x = 47, y = 3.45, z = 37.352, rotY = 180, group = "Cart", id = "CART-K", layer = "day", replaces = { "Pad/CART/6_K_Toppings", "Pad/CART/Lid_Ketchup", "Pad/CART/Lid_Mustard", "Pad/CART/Lid_Cheese", "Pad/CART/Lid_Bacon", "Pad/CART/Lid_PotatoSticks", "Pad/CART/Lid_CreamCheese" }, note = "2026-10-10 hand edit (mirror of TRL-K): rotY 180, front row F (Ketchup / Mustard / Cheese, labels) faces the operator (south)" },
	-- 2026-10-10: sauce holder removed; Ketchup/Mustard are steel bowls in the grid (user request)
	-- { asset = "AST-016_SauceHolder", x = 46, y = 3.60, z = 36.75, rotY = 0, group = "Cart", id = "CART-K-SAUCE", layer = "day", replaces = {}, note = "sits on grid cells F1 (Ketchup, X45) + F2 (Mustard, X47); bottles go on Att_Bottle_* at runtime" },
	{ asset = "AST-020_CashRegister", x = 53.143, y = 3.45, z = 37.661, rotY = 180, drop = { "DeliveryStand" }, pivot = { 51.743, 3.45, 37.661, 180 }, group = "Cart", id = "DRAWER", layer = "day", replaces = { "Pad/CART/7_H_Delivery", "Pad/CART/DRAWER" }, note = "2026-10-10 hand edit: delivery stand removed, register turned to the operator, pivot moved by hand" },
	{ asset = "AST-042_VehiclePhone", part = { "Phone_Cart", "Cart_Body", "Cart_Handset", "Cart_Lamp" }, x = 31.9, y = 3.45, z = 37.84, rotY = -174.3, group = "Cart", id = "CART-PHONE", layer = "day", replaces = {}, note = "2026-10-10 new model (rotary desk phone on a wood shelf, Poly Pizza CC-BY): Att_Mount (local z 0.6) on Mount_Phone (47.5, 5.45, 36.49, Parasol_E pole); shelf base 4.85 clears the topping grid top (4.75); phone faces the operator (south)" },
	{ asset = "AST-025_Trashcan", x = 56, y = 0.45, z = 42, rotY = 90, group = "Cart", id = "BIN-C", layer = "day", replaces = { "Pad/BIN-C" }, note = "Mount_Trash rotY 90 would point the pedal east; 270 = pedal to the corridor" },

	---------------------------------------------------------------------------------------------
	-- 2b. OPEN LATE TRAILER on the Pad (night) + interior. Pivot (40, 0.45, 41), rotY 180.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-027_OpenLateTrailer", x = 40, y = 0.45, z = 41, rotY = 0, group = "Trailer", id = "TRL", layer = "night", replaces = { "Pad/TRL", "Pad/TRL_Hitch" }, note = "window/awning north (queue), back door X 47..51 south, hitch to X 21.5; floor at Y 2.45" },
	{ asset = "AST-018_CoolerL1", x = 28.5, y = 5.05, z = 37.5, rotY = 180, group = "Trailer", id = "TRL-S", layer = "night", replaces = {}, note = "2026-10-11 y 5.95 -> 5.05 (counter lowered 0.9); cooler level carries over from the cart (Q-075)" },
	{ asset = "AST-012_RollerGrill", part = { "Grill_L1" }, x = 33, y = 5.05, z = 37.5, rotY = 180, group = "Trailer", id = "TRL-G", layer = "night", replaces = {} },
	{ asset = "AST-013_RestRail", part = { "Rail_8" }, x = 37.5, y = 5.05, z = 37.5, rotY = 180, group = "Trailer", id = "TRL-R", layer = "night", replaces = {}, note = "TASK-083: Rail_8 (Vehicles.trailer.RailSlots 8, §19.22); bind_map01 picks the 8 slot empties" },
	{ asset = "AST-015_BunCrate", x = 40, y = 5.05, z = 37.5, rotY = 180, copies = { { part = "Buns", 0, 0.512, 0 }, { part = "Buns", 0, 0.78, 0 } }, group = "Trailer", id = "TRL-B", layer = "night", replaces = {}, note = "2026-10-10 hand edit: two more bun layers stacked" },
	{ asset = "AST-014_CuttingBoard", x = 42.5, y = 5.05, z = 37.5, rotY = 0, parts = { Board = { 0, 0.06, 0.25, size = { 2.6, 0.12, 1.4 } }, Knife = { 0, 0.161, 0.012, size = { 1.246, 0.083, 0.276 } } }, group = "Trailer", id = "TRL-T", layer = "night", replaces = {}, note = "2026-10-10 hand edit: turned 180, board 2.6 x 1.4 (3 slots), knife scaled" },
	{ asset = "AST-017_ToppingGrid", x = 47, y = 5.05, z = 37.352, rotY = 180, group = "Trailer", id = "TRL-K", layer = "night", replaces = {}, note = "2026-10-10 hand edit: front row (labels) faces the operator" },
	-- 2026-10-10: sauce holder removed; Ketchup/Mustard are steel bowls in the grid (user request)
	-- { asset = "AST-016_SauceHolder", x = 46, y = 6.10, z = 36.75, rotY = 0, group = "Trailer", id = "TRL-K-SAUCE", layer = "night", replaces = {} },
	-- 2026-10-13: the trailer register TRL-DRAWER left (DEC-239); the TIPS jar TRL-TIPJAR (AST-121) is built by trailer_tipjar.luau, not placed here
	-- { asset = "AST-020_CashRegister", x = 52.351, y = 5.05, z = 36.861, rotY = 180, drop = { "DeliveryStand" }, pivot = { 51.18, 5.05, 36.861, 180 }, group = "Trailer", id = "TRL-DRAWER", layer = "night", replaces = {}, note = "2026-10-10 hand edit: delivery stand removed, register turned to the operator, pivot moved by hand" },
	{ asset = "AST-042_VehiclePhone", part = { "Phone_Trailer", "Trailer_Body", "Trailer_Handset", "Trailer_Lamp" }, x = 30.7, y = 7.85, z = 36.35, rotY = 180, group = "Trailer", id = "TRL-PHONE", layer = "night", replaces = {}, note = "2026-10-10 new model: trailer variant sits 2.2 off the FBX origin; Att_Mount (back of the shelf, local z 0.6) lands on Mount_Phone (28.5, 8.45, 36), front wall; shelf base 7.85 clears the TRL-S cooler top (7.55)" },
	{ asset = "AST-022_CoffeeMachine", x = 40, y = 5.05, z = 44.8, rotY = 0, group = "Trailer", id = "TRL-COFFEE", layer = "night", replaces = {}, note = "2026-10-17 hand edit: moved 0.8 back on the counter (was z 44) to free the front strip where the ready cup stands (KitchenController/Coffee.luau)" },
	{ asset = "AST-025_Trashcan", x = 43.5, y = 2.45, z = 44, rotY = 0, group = "Trailer", id = "TRL-BIN", layer = "night", replaces = {} },
	{ asset = "AST-039_LightSwitch", x = 46, y = 6.45, z = 46, rotY = 0, group = "Trailer", id = "TRL-SWITCH", layer = "night", replaces = {}, note = "back plate on the south wall (Z 46), lever to the north" },
	{ asset = "AST-040_TrailerBench", x = 34.5, y = 2.45, z = 44.5, rotY = 180, pivot = { 28.5, 2.45, 44.5, 0 }, group = "Trailer", id = "TRL-BENCH-1", layer = "night", replaces = {} },
	{ asset = "AST-040_TrailerBench", x = 31.5, y = 2.45, z = 44.5, rotY = 180, pivot = { 31.5, 2.45, 44.5, 0 }, group = "Trailer", id = "TRL-BENCH-2", layer = "night", replaces = {} },
	{ asset = "AST-040_TrailerBench", x = 28.5, y = 2.45, z = 44.5, rotY = 180, pivot = { 34.5, 2.45, 44.5, 0 }, group = "Trailer", id = "TRL-BENCH-3", layer = "night", replaces = {} },
	-- 2026-10-10 DEC-221 (TASK-132): hide cabinets H1..H4 (AST-041) removed; their mesh was already dropped by hand.
	-- bind_map01 destroys the empty H1..H4 models left in the place and creates the window button TRL-SHUTTER
	-- (placeholder plate, no asset entry) next to TRL-SWITCH.
	{ asset = "AST-023_TrailerLights", part = { "Lights_Mast", "Lights_Mast_Lamps" }, x = 40, y = 11.45, z = 41, rotY = 0, group = "Trailer", id = "TRL-LIGHTS", layer = "night", replaces = {}, note = "UPG-005: only after purchase; Mount_Lights on the roof" },
	{ asset = "AST-023_TrailerLights", part = { "Lights_String", "Lights_String_Bulbs" }, x = 41.25, y = 11.05, z = 34.9, rotY = 0, group = "Trailer", id = "TRL-LIGHTS", layer = "night", replaces = {}, note = "UPG-005; Mount_LightsString over the window. Same FBX placed twice (mast / string share the origin)" },

	---------------------------------------------------------------------------------------------
	-- 2c. SALE TRAILER, signs, queue marks
	---------------------------------------------------------------------------------------------
	{ asset = "AST-027_OpenLateTrailer", x = 78, y = 0.02, z = -58, rotY = 180, group = "Trailer", id = "TRL-SALE", replaces = { "Trailer/TRL-SALE" }, note = "window faces south (Pad); hitch east, like the blockout. TASK-083: empty shell = pose reference only; bind_map01 reads its pivot, destroys it and parks the real trailer (TRL) here (T36)" },
	{ asset = "AST-024_SignStand", x = 78, y = 0.02, z = -40, rotY = 180, group = "Pad", id = "SIGN-T", replaces = { "Trailer/SIGN-T" }, note = "MAP asks 4 x 5; asset is 2 x 4 (scale or variant)" },
	{ asset = "AST-024_SignStand", x = 25.7, y = 0.56, z = 33.2, rotY = 0, parts = { ["AST-024_SignStand"] = { -0.1, 1.89, 0 } }, group = "Pad", id = "OPEN", replaces = { "Pad/OPEN" }, note = "4 tall vs <= 3 (DEC-048 sight band). Trailer has Mount_Sign at (27.5, 0.45, 33) as alternative" },
	{ asset = "AST-019_QueueMark", x = 52, y = 0.45, z = 33, rotY = 180, group = "Pad", id = "Q1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 46, y = 0.4, z = 29, rotY = 180, group = "Pad", id = "Q2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 41, y = 0.4, z = 29, rotY = 180, group = "Pad", id = "Q3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 36, y = 0.4, z = 29, rotY = 180, group = "Pad", id = "Q4", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 31, y = 0.4, z = 29, rotY = 180, group = "Pad", id = "Q5", replaces = {} },

	---------------------------------------------------------------------------------------------
	-- 3. STREET LIGHTS: pole pivot = foot + 1.815 * armDir; LampHead pivot = foot; same rotY.
	--    JL arms point east (rotY 90). Juniper sidewalk tiles -> y 0.24 (JL-01 sits on the Ninth
	--    sidewalk, 0.4; JL-02 straddles the seam at Z -32 and uses the lower 0.24).
	---------------------------------------------------------------------------------------------
	-- 2026-10-10 (user: the Juniper posts were NOT visible from the trailer window): the Walker chain moved to the Ninth north
	-- curb, bank / parking side, 4 posts every 20 studs coming towards the trailer: NL-01 (X 118, beyond BAR-E, step 0)
	-- -> NL-04 (X 58, step 3); WALKER-10 = (48, 14) across the Ninth (bind_map01). Arm over the road (rotY 0 = +Z),
	-- pole on the curb like the other Ninth posts. X 62..78 (parking mouth, long car AN-12) stays clear; PARK-N cars 5 / 6
	-- moved west so nothing parks between the window and the posts. Sight checked by check_map01 rule 14.
	-- The blockout JL-01..09 and Post_NinthN_E1 parts stay hidden through these entries (their lights: bind RETIRED_POSTS).
	{ asset = "AST-036_StreetLightCurved", x = 118, y = 0.4, z = -19.085, rotY = 0, group = "StreetLights", id = "NL-01", replaces = { "StreetLights/Post_NinthN_E1/Pole", "StreetLights/Post_NinthN_E1/Arm" }, note = "Walker step 0, beyond BAR-E" },
	{ asset = "AST-036_LampHead", x = 118, y = 0.4, z = -17.305, rotY = 0, group = "StreetLights", id = "NL-01", replaces = { "StreetLights/Post_NinthN_E1/Lamp" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 98, y = 0.4, z = -19.085, rotY = 0, group = "StreetLights", id = "NL-02", replaces = {}, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = 98, y = 0.4, z = -17.305, rotY = 0, group = "StreetLights", id = "NL-02", replaces = {}, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 78, y = 0.4, z = -19.085, rotY = 0, group = "StreetLights", id = "NL-03", replaces = {}, note = "east edge of the parking mouth (X 64..76)" },
	{ asset = "AST-036_LampHead", x = 78, y = 0.4, z = -17.305, rotY = 0, group = "StreetLights", id = "NL-03", replaces = {}, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 58, y = 0.4, z = -19.085, rotY = 0, group = "StreetLights", id = "NL-04", replaces = {}, note = "Walker step 3, in front of the bank / fence" },
	{ asset = "AST-036_LampHead", x = 58, y = 0.4, z = -17.305, rotY = 0, group = "StreetLights", id = "NL-04", replaces = {}, note = "user 2026-10-11: edited in Studio (captured)" },
	-- Juniper North: two decorative posts (no tag, no light) where JL-02 / JL-04 stood; they hide all the blockout JL posts
	{ asset = "AST-036_StreetLightCurved", x = -14.335, y = 0.4, z = -40.019, rotY = 89.994, group = "StreetLights", id = "Post_JuniperN_1", replaces = { "StreetLights/JL-01/Pole", "StreetLights/JL-01/Arm", "StreetLights/JL-02/Pole", "StreetLights/JL-02/Arm", "StreetLights/JL-03/Pole", "StreetLights/JL-03/Arm", "StreetLights/JL-04/Pole", "StreetLights/JL-04/Arm", "StreetLights/JL-05/Pole", "StreetLights/JL-05/Arm" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = -12.405, y = 0.24, z = -40, rotY = 90, group = "StreetLights", id = "Post_JuniperN_1", replaces = { "StreetLights/JL-01/Lamp", "StreetLights/JL-02/Lamp", "StreetLights/JL-03/Lamp", "StreetLights/JL-04/Lamp", "StreetLights/JL-05/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -14.334, y = 0.4, z = -71.816, rotY = 89.994, group = "StreetLights", id = "Post_JuniperN_2", replaces = { "StreetLights/JL-06/Pole", "StreetLights/JL-06/Arm", "StreetLights/JL-07/Pole", "StreetLights/JL-07/Arm", "StreetLights/JL-08/Pole", "StreetLights/JL-08/Arm", "StreetLights/JL-09/Pole", "StreetLights/JL-09/Arm" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = -12.405, y = 0.24, z = -72, rotY = 90, group = "StreetLights", id = "Post_JuniperN_2", replaces = { "StreetLights/JL-06/Lamp", "StreetLights/JL-07/Lamp", "StreetLights/JL-08/Lamp", "StreetLights/JL-09/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = 18.717, y = 0.4, z = 18.717, rotY = 225, group = "StreetLights", id = "P-01", replaces = { "StreetLights/P-01/Pole", "StreetLights/P-01/Arm" }, note = "foot (20, 20), arm to the NW over the intersection; flyer must move out to r ~0.56" },
	{ asset = "AST-036_LampHead", x = 17.459, y = 0.4, z = 17.459, rotY = 225, group = "StreetLights", id = "P-01", replaces = { "StreetLights/P-01/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -40, y = 0.4, z = 19.085, rotY = 180, group = "StreetLights", id = "Post_NinthS_W1", replaces = { "StreetLights/Post_NinthS_W1/Pole", "StreetLights/Post_NinthS_W1/Arm" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = -40, y = 0.4, z = 17.305, rotY = 180, group = "StreetLights", id = "Post_NinthS_W1", replaces = { "StreetLights/Post_NinthS_W1/Lamp" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = -90, y = 0.4, z = 18.985, rotY = 180, group = "StreetLights", id = "Post_NinthS_W2", replaces = { "StreetLights/Post_NinthS_W2/Pole", "StreetLights/Post_NinthS_W2/Arm" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = -90, y = 0.4, z = 17.405, rotY = 180, group = "StreetLights", id = "Post_NinthS_W2", replaces = { "StreetLights/Post_NinthS_W2/Lamp" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = -76, y = 0.4, z = -19.685, rotY = 0, group = "StreetLights", id = "Post_NinthN_W1", replaces = { "StreetLights/Post_NinthN_W1/Pole", "StreetLights/Post_NinthN_W1/Arm" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = -76, y = 0.4, z = -17.905, rotY = 0, group = "StreetLights", id = "Post_NinthN_W1", replaces = { "StreetLights/Post_NinthN_W1/Lamp" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 84, y = 0.4, z = 19.785, rotY = 180, group = "StreetLights", id = "Post_L2", replaces = { "StreetLights/Post_L2/Pole", "StreetLights/Post_L2/Arm" }, note = "L2 lurk post" },
	{ asset = "AST-036_LampHead", x = 84, y = 0.4, z = 18.105, rotY = 180, group = "StreetLights", id = "Post_L2", replaces = { "StreetLights/Post_L2/Lamp" }, note = "user 2026-10-11: edited in Studio (captured)" },

	---------------------------------------------------------------------------------------------
	-- 4. BUILDINGS (pivot y 0). Front (+Z) on the lot line: rotY 0 = faces south, 180 = north,
	--    90 = east, 270 = west. A = BuildingA (16.4 x 17.45 deep), H = BuildingH (16.4 x 18.71).
	---------------------------------------------------------------------------------------------
	-- North of the Ninth, facades on Z -32
	{ asset = "AST-033_BuildingA", x = -80.2, y = 0, z = -40.725, rotY = 0, group = "Buildings", id = "B3", replaces = { "Buildings/B3" }, note = "B3a, X -88.4..-72" },
	{ asset = "AST-033_BuildingH", x = -96.6, y = 0, z = -41.355, rotY = 0, group = "Buildings", id = "B3", replaces = { "Buildings/B3" }, note = "B3b, behind the NO HELP WANTED window X -92" },
	{ asset = "AST-033_BuildingA", x = -113.0, y = 0, z = -40.725, rotY = 0, group = "Buildings", id = "B3", replaces = { "Buildings/B3" }, note = "B3c" },
	{ asset = "AST-033_BuildingH", x = -129.4, y = 0, z = -41.355, rotY = 0, group = "Buildings", id = "B3", replaces = { "Buildings/B3" }, note = "B3d, ends at X -137.6" },
	{ asset = "AST-033_BuildingH", x = -57.2, y = 0, z = -41.355, rotY = 0, parts = { ["AST-033_BuildingH"] = { 0, 12, 0, rotY = 180 } }, group = "Buildings", id = "B2", replaces = { "Buildings/B2/Block" }, note = "B2b annex west of the laundry, behind window X -56; gap X -72..-65.4 to B3a" },
	{ asset = "AST-046_Laundry", x = -37.0, y = 0, z = -39.34, rotY = 0, group = "Buildings", id = "B2", replaces = { "Buildings/B2/Block", "Buildings/B2/Awning" }, note = "Z-10; mesh door ~X -40 = SP-B; Door_SP-B and window X -32 stay" },
	{ asset = "AST-046_DoorSPB", x = -39.91, y = 0.4, z = -33.64, rotY = 180, group = "Buildings", id = "SP-B", replaces = { "Buildings/B2/Door_SP-B" }, note = "modeler-3d 2026-10-10: between the laundry pillars, under the awning (4.74): opening 3.2 x 4.1 only (see AST-046)" },
	{ asset = "AST-033_NoHelpSign", x = -93.29, y = 2.2, z = -35.079, rotY = 180, group = "Buildings", id = "CS-2", replaces = { "Buildings/Window_NoHelpWanted_X-92" }, note = "card on the B3b door glass; text = SurfaceGui (AST-072)" },
	{ asset = "AST-033_NoHelpSign", x = -53.89, y = 2.2, z = -35.079, rotY = -180, parts = { ["NoHelpSign"] = { 0, 1.415, 0 } }, group = "Buildings", id = "CS-2", replaces = { "Buildings/B2/Window_NoHelpWanted_X-56" }, note = "card on the B2b door glass" },
	{ asset = "AST-033_NoHelpSign", x = -34.86, y = 2.4, z = -34.414, rotY = 180, group = "Buildings", id = "CS-2", replaces = { "Buildings/B2/Window_NoHelpWanted_X-32" }, note = "card on the left pane of the laundry window" },
	{ asset = "AST-033_NoHelpSign", x = -62, y = 4.2, z = -31.85, rotY = 180, parts = { ["NoHelpSign"] = { 0, 0.515, 0, size = { 3.96, 3.09, 0.216 } } }, group = "Buildings", id = "CS-2", replaces = {  }, note = "user 2026-10-11: big card on the B2b facade at the first intro stop (CS-2), 3x the door cards; bind letters it" },
	{ asset = "AST-033_BuildingA", x = -32.725, y = 0, z = -55.8, rotY = 90, group = "Buildings", id = "B2", replaces = { "Buildings/B2/Block" }, note = "B2c faces the Juniper (east), Z -64..-47.6: closes the lot seen from the trailer window" },
	{ asset = "AST-044_BellmoorSavings", x = 38, y = 0, z = -46.97, rotY = 180, parts = { BankDoor = { -1, 4.65, -15.18, size = { 3.92, 6.85, 0.34 } } }, group = "Buildings", id = "Z-11", replaces = { "Buildings/BellmoorSavings/Bank_GroundFloor", "Buildings/BellmoorSavings/Cornice", "Buildings/BellmoorSavings/BankDoor", "Buildings/BellmoorSavings/BankSign", "Buildings/BellmoorSavings/C-01", "Buildings/BellmoorSavings/C-01_MinuteHand", "Buildings/BellmoorSavings/C-01_HourHand" }, note = "modeler-3d 2026-10-10: ground floor 0..18, lot X 24..52 / Z -64..-32, portico + C-01 (39, 14, face at Z ~-30.3); columns now inside this mesh; BankSign text = SurfaceGui on +Z face; hands pivot = Clock_Center (_atts.json). 2026-10-10 hand edit (user, Studio): BankDoor 7.45 -> 6.85 tall, bottom raised 0.6 (doors overlapped)" },
	{ asset = "AST-045_ApartmentBlock", x = 38.05, y = 17.6, z = -40.762, rotY = 180, group = "Buildings", id = "Z-11", replaces = { "Buildings/BellmoorSavings/Apartments", "Buildings/BellmoorSavings/WV-1", "Buildings/BellmoorSavings/WV-2", "Buildings/BellmoorSavings/WV-3" }, note = "modeler-3d 2026-10-10: floors 2-3 on the bank (18..30, roof hut to 32.2); Window_Up_1..3 = WV-1..3 at X 31/38/45, glass 24.6..28" },
	{ asset = "AST-033_BuildingH", x = 112.2, y = 0, z = -41.355, rotY = 0, group = "Buildings", id = "B4", replaces = { "Buildings/B4" }, note = "Ninth front" },
	{ asset = "AST-033_BuildingA", x = 128.6, y = 0, z = -40.725, rotY = 0, group = "Buildings", id = "B4", replaces = { "Buildings/B4" } },
	{ asset = "AST-033_BuildingA", x = 112.725, y = 0, z = -58.91, rotY = 270, group = "Buildings", id = "B4", replaces = { "Buildings/B4" }, note = "faces the parking lot (west)" },
	{ asset = "AST-033_BuildingH", x = 113.355, y = 0, z = -75.31, rotY = 270, group = "Buildings", id = "B4", replaces = { "Buildings/B4" } },
	{ asset = "AST-033_BuildingA", x = 112.725, y = 0, z = -91.71, rotY = 270, group = "Buildings", id = "B4", replaces = { "Buildings/B4" } },
	{ asset = "AST-033_BuildingH", x = 113.355, y = 0, z = -108.11, rotY = 270, group = "Buildings", id = "B4", replaces = { "Buildings/B4" } },
	{ asset = "AST-033_BuildingA", x = 112.725, y = 0, z = -124.51, rotY = 270, group = "Buildings", id = "B4", replaces = { "Buildings/B4" } },
	-- South of the Ninth: B1 behind the Pad (Door_D1 moved 2026-10-11 to the Ninth front of the middle block, X 88.6)
	{ asset = "AST-033_BuildingA", x = 72.2, y = 0, z = 40.725, rotY = 180, group = "Buildings", id = "B1", replaces = { "Buildings/B1/Block_East" }, note = "corner, Ninth front" },
	{ asset = "AST-033_BuildingH", x = 88.6, y = 0, z = 40.655, rotY = 180, group = "Buildings", id = "B1", replaces = { "Buildings/B1/Block_East" }, note = "user 2026-10-11: pulled 0.7 toward the Ninth (carries D1)" },
	{ asset = "AST-033_BuildingA", x = 105.0, y = 0, z = 40.725, rotY = 180, group = "Buildings", id = "B1", replaces = { "Buildings/B1/Block_East" }, note = "ends X 113.2: EX-E alley 6.8 wide" },
	{ asset = "AST-033_BuildingA", x = 72.725, y = 0, z = 57.65, rotY = 270, group = "Buildings", id = "B1", replaces = { "Buildings/B1/Block_East" }, note = "faces the Pad (west), Z 49.45..65.85" },
	{ asset = "AST-033_DoorD1", x = 88.6, y = 0.45, z = 32.048, rotY = 0, parts = { ["DoorFrame_D1"] = { 0, 3.475, 0.11, size = { 4.7, 6.95, 0.6 } } }, group = "Buildings", id = "D1", replaces = { "Buildings/B1/Door_D1" }, note = "user 2026-10-11: moved off the Pad side wall (next to the cart) to the plain ground floor of the middle B1 block on the Ninth front (wall Z 32); leaf Door_D1, hinge Hinge_D1" },
	{ asset = "AST-033_BuildingH", x = 32.2, y = 0, z = 73.355, rotY = 180, group = "Buildings", id = "B1", replaces = { "Buildings/B1/Block_Rear" }, note = "faces the Pad; hides ST-R (18, 92) from the Pad" },
	{ asset = "AST-033_BuildingA", x = 48.6, y = 0, z = 72.725, rotY = 180, group = "Buildings", id = "B1", replaces = { "Buildings/B1/Block_Rear" } },
	{ asset = "AST-033_BuildingH", x = 65.0, y = 0, z = 73.355, rotY = 180, group = "Buildings", id = "B1", replaces = { "Buildings/B1/Block_Rear" }, note = "overlaps the west-facing B1 block by ~1.9 at the back (hidden)" },
	-- B5 behind the plaza
	{ asset = "AST-033_BuildingA", x = -51.0, y = 0, z = 64.725, rotY = 180, group = "Buildings", id = "B5", replaces = { "Buildings/B5" }, note = "plaza front Z 56, X -59.2..-42.8 (touches the Mart east wall)" },
	{ asset = "AST-033_BuildingH", x = -34.6, y = 0, z = 65.355, rotY = 180, group = "Buildings", id = "B5", replaces = { "Buildings/B5" } },
	{ asset = "AST-033_BuildingH", x = -33.355, y = 0, z = 82.91, rotY = 90, group = "Buildings", id = "B5", replaces = { "Buildings/B5" }, note = "faces the Juniper Sul (east)" },
	{ asset = "AST-033_BuildingA", x = -32.725, y = 0, z = 99.31, rotY = 90, group = "Buildings", id = "B5", replaces = { "Buildings/B5" } },
	{ asset = "AST-033_BuildingH", x = -33.355, y = 0, z = 115.71, rotY = 90, group = "Buildings", id = "B5", replaces = { "Buildings/B5" } },

	---------------------------------------------------------------------------------------------
	-- 5. NINTH STREET MART (Z-04). Walls: exterior = local +Z, inner face on the MAP-01 line.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-028_MartWall", x = -104, y = 0.4, z = 29.6, rotY = 180, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Base", "Mart/MKT_Shell/North_Header" }, note = "closes the NW corner (X -108..-100)" },
	{ asset = "AST-028_MartWallWindow", x = -96, y = 0.4, z = 29.6, rotY = 180, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Base", "Mart/MKT_Shell/North_Glass", "Mart/MKT_Shell/North_Header" } },
	{ asset = "AST-028_MartWallWindow", x = -88, y = 0.4, z = 29.6, rotY = 180, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Base", "Mart/MKT_Shell/North_Glass", "Mart/MKT_Shell/North_Header" } },
	{ asset = "AST-028_MartWallWindow", x = -80, y = 0.4, z = 29.6, rotY = 180, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Base", "Mart/MKT_Shell/North_Glass", "Mart/MKT_Shell/North_Header" } },
	{ asset = "AST-028_MartWallWindow", x = -72, y = 0.4, z = 29.6, rotY = 180, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Base", "Mart/MKT_Shell/North_Glass", "Mart/MKT_Shell/North_Header" } },
	{ asset = "AST-028_MartWallDoor", x = -64.3, y = 0.4, z = 32.3, rotY = 135, group = "Mart", id = "MKT-DOOR", replaces = { "Mart/MKT_Shell/Corner_JambN", "Mart/MKT_Shell/Corner_JambE", "Mart/MKT_Shell/Corner_Header", "Mart/MKT_Shell/Door" }, note = "chamfer (-68,32)->(-64,36) approximated; overlaps the SS rim ~2.3" },
	{ asset = "AST-028_MartWallWindow", x = -61.6, y = 0.4, z = 40, rotY = 90, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/East_Base", "Mart/MKT_Shell/East_Glass", "Mart/MKT_Shell/East_Header" } },
	{ asset = "AST-028_MartWallWindow", x = -61.6, y = 0.4, z = 48, rotY = 90, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/East_Base", "Mart/MKT_Shell/East_Glass", "Mart/MKT_Shell/East_Header" } },
	{ asset = "AST-028_MartWallWindow", x = -61.6, y = 0.4, z = 56, rotY = 90, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/East_Base", "Mart/MKT_Shell/East_Glass", "Mart/MKT_Shell/East_Header", "Mart/MKT_Shell/East_Solid" }, note = "glass Z 52..60; its south half faces the side of B5a" },
	{ asset = "AST-028_MartWall", x = -61.6, y = 0.4, z = 64, rotY = 90, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/East_Solid" } },
	{ asset = "AST-028_MartWall", x = -96, y = 0.4, z = 66.4, rotY = 0, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_S" }, note = "inside Fill_SW_MartRear" },
	{ asset = "AST-028_MartWall", x = -88, y = 0.4, z = 66.4, rotY = 0, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_S" } },
	{ asset = "AST-028_MartWall", x = -80, y = 0.4, z = 66.4, rotY = 0, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_S" } },
	{ asset = "AST-028_MartWall", x = -72, y = 0.4, z = 66.4, rotY = 0, parts = { ["AST-028_MartWall"] = { 4.2, 6, 0, size = { 16.4, 12, 4.8 } } }, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_S" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-028_MartWall", x = -102.4, y = 0.4, z = 36, rotY = 270, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_W" }, note = "inside Fill_SW_West; GEAR WALL leans on it" },
	{ asset = "AST-028_MartWall", x = -102.4, y = 0.4, z = 44, rotY = 270, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_W" } },
	{ asset = "AST-028_MartWall", x = -102.4, y = 0.4, z = 52, rotY = 270, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_W" } },
	{ asset = "AST-028_MartWall", x = -102.4, y = 0.4, z = 60, rotY = 270, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_W" } },
	{ asset = "AST-028_MartAwning", x = -72, y = 6.065, z = 27.822, rotY = 0, parts = { ["AST-028_MartAwning"] = { 0, 1.913, -0.585, rotX = -17 } }, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Awning" }, note = "plate top at 9.9; pack legs still on the mesh (edit pending); side to confirm" },
	{ asset = "AST-028_MartAwning", x = -88, y = 6.065, z = 27.822, rotY = 0, parts = { ["AST-028_MartAwning"] = { 0, 1.913, -0.585, rotX = -17 } }, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Awning" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-028_MartAwning", x = -80, y = 6.065, z = 27.822, rotY = 0, parts = { ["AST-028_MartAwning"] = { 0, 1.913, -0.585, rotX = -17 } }, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Awning" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-028_MartAwning", x = -72, y = 5.9, z = 26.46, rotY = -180, parts = { ["AST-028_MartAwning"] = { 24, 2.078, -0.777, rotY = -180, rotX = -17 } }, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Awning" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-028_Marquee", x = -57.7, y = 2.1, z = 26.8, rotY = 0, parts = { ["Marquee"] = { -0.3, 5.5, 0, size = { 17.2, 14.8, 16.6 } } }, group = "Mart", id = "SS", replaces = { "Mart/Marquee_OPEN24/Canopy", "Mart/Marquee_OPEN24/Post_N", "Mart/Marquee_OPEN24/Post_S", "Mart/Marquee_OPEN24/Sign_North", "Mart/Marquee_OPEN24/Sign_East" }, note = "modeler-3d 2026-10-10: canopy X -66..-50 / Z 22..38 at 10.8; Sign_Open24 = coral Neon tubes (set Material Neon); text OPEN 24 HOURS = SurfaceGui at Text_Open24_N / _E; blockout SignLight kept" },
	{ asset = "AST-028_SafeZoneMarking", x = -58, y = 0.4, z = 30, rotY = 0, parts = { ["SafeZone_Marking"] = { -1.1, 0.02, -2.7 } }, group = "Mart", id = "SS", replaces = { "Mart/SS" }, note = "disc r 6, 0.04 thick; CanCollide/CanQuery off" },
	{ asset = "AST-028_SignName", x = -84, y = 9.925, z = 27.025, rotY = 0, group = "Mart", id = "MKT", replaces = {}, note = "plate 14 x 2 on the north header (wall face Z 27.2); text NINTH STREET MART = SurfaceGui at Text_Name" },

	-- Interior (Mart floor top 0.4)
	{ asset = "AST-049_GearWall", x = -99, y = 0.4, z = 48, rotY = 270, part = { "__none" }, group = "MartInterior", id = "GEAR_WALL", replaces = { "Mart/Interior/GEAR_WALL/Bench", "Mart/Interior/GEAR_WALL/BenchTopTrim", "Mart/Interior/GEAR_WALL/Panel", "Mart/Interior/GEAR_WALL/Title", "Mart/Interior/GEAR_WALL/S1_Vitrine" }, note = "Slot_B1 lands on Z 40.5, S1 on 46.5, B5 on 55.5 (= MAP-01 7.4); Title SurfaceGui still renders when hidden", note2 = "user/Mart v2 2026-10-11: removed (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-031_MartCheckout", x = -77.1, y = 0.4, z = 35.5, rotY = 0, parts = { ["AST-031_MartCheckout"] = { 0, 1.75, 0.7, size = { 6, 3.5, 3.9 } } }, drop = { "AST-031_MartCheckout" }, group = "MartInterior", id = "OP-1", replaces = { "Mart/Interior/CheckoutCounter" }, note = "6 wide (blockout 10); detail side (-Z) towards Opal, confirm", note2 = "user/Mart v2 2026-10-11: removed (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-029_GondolaBoxes", x = -83.813, y = 0.4, z = 33.086, rotY = 0, drop = { "AST-029_GondolaBoxes" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaN_Shelf" }, note = "user 2026-10-11: edited in Studio (captured)", note2 = "user/Mart v2 2026-10-11: removed (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-029_GondolaBags", x = -88.3, y = 0.4, z = 33.081, rotY = 0, drop = { "AST-029_GondolaBags" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaN_Shelf" }, note = "user 2026-10-11: edited in Studio (captured)", note2 = "user/Mart v2 2026-10-11: removed (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-029_GondolaEnd", x = -92.8, y = 0.4, z = 33.15, rotY = 0, drop = { "AST-029_GondolaEnd" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaN_Shelf" }, note = "user 2026-10-11: edited in Studio (captured)", note2 = "user/Mart v2 2026-10-11: removed (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-029_GondolaBoxes", x = -77.75, y = 0.4, z = 51.237, rotY = 0, drop = { "AST-029_GondolaBoxes" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaS_Shelf" }, note = "user 2026-10-11: removed in Studio (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-029_GondolaBags", x = -73.25, y = 0.4, z = 53.737, rotY = 180, drop = { "AST-029_GondolaBags" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaS_Shelf" }, note = "user 2026-10-11: removed in Studio (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-029_GondolaEnd", x = -97.312, y = 0.4, z = 33.162, rotY = 0, drop = { "AST-029_GondolaEnd" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaS_Shelf" }, note = "user 2026-10-11: edited in Studio (captured)", note2 = "user/Mart v2 2026-10-11: removed (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-030_FridgeDisplayShelves", x = -71.7, y = 0.4, z = 62.737, rotY = 180, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaN_Fridge" }, note = "2026-10-12 (owner moved the fridges: world 67.7 / 71.7, 5.15): open interior (AST-030_FridgeDisplayShelves: glass doors + 3 levels per bay); run fix_mart_fridge.luau after Place.run for the packs. glass north (Cheese -81,40); Bacon (-81,44) is at its back; 7 tall vs low fridge" },
	{ asset = "AST-030_FridgeDisplayShelves", x = -67.7, y = 0.4, z = 62.737, rotY = 180, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaS_Fridge" }, note = "glass north (Cream Cheese -81,48)" },
	{ asset = "AST-029_GondolaBoxes", x = -97.75, y = 0.4, z = 62.75, rotY = 0, drop = { "AST-029_GondolaBoxes" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" }, note = "user 2026-10-11: removed in Studio (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-029_GondolaBoxes", x = -93.25, y = 0.4, z = 62.75, rotY = 0, drop = { "AST-029_GondolaBoxes" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" }, note = "user 2026-10-11: removed in Studio (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-029_GondolaBoxes", x = -88.75, y = 0.4, z = 62.75, rotY = 0, drop = { "AST-029_GondolaBoxes" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" }, note = "Mart v2 2026-10-11: removed (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-029_GondolaBoxes", x = -84.25, y = 0.4, z = 62.75, rotY = 0, drop = { "AST-029_GondolaBoxes" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" }, note = "Mart v2 2026-10-11: removed (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-029_GondolaBoxesBare", x = -76.55, y = 0.4, z = 62.837, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" }, note = "user 2026-10-11: edited in Studio (captured); 2026-10-12 Bare = shelf-boxes WITHOUT the baked Kenney stock (milk-like cartons); AST-011 packs go on top with tools/assetplace/fix_mart_shelf_packs.luau (run after every Place.run + bind_map01)" },
	{ asset = "AST-029_GondolaBoxes", x = -73.25, y = 0.4, z = 51.237, rotY = 0, drop = { "AST-029_GondolaBoxes" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" }, note = "user 2026-10-11: removed in Studio (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-029_GondolaBoxes", x = -70.75, y = 0.4, z = 62.75, rotY = 0, drop = { "AST-029_GondolaBoxes" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" }, note = "user 2026-10-11: removed in Studio (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-029_GondolaBoxes", x = -66.25, y = 0.4, z = 62.75, rotY = 0, drop = { "AST-029_GondolaBoxes" }, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" }, note = "user 2026-10-11: removed in Studio (mesh dropped, blockout stays hidden)" },
	{ asset = "AST-050_FruitDisplay", x = -88.1, y = 0.4, z = 33.587, rotY = 180, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/ProduceDisplay", "Mart/Interior/Fruit1", "Mart/Interior/Fruit2", "Mart/Interior/Fruit3", "Mart/Interior/Fruit4" }, note = "scenery, no prompt (DEC-109)" },
	-- 2026-10-10: wooden market table (AST-098, Quaternius CC0 via Poly Pizza) under the two lettuce crates, FRESH PRODUCE corner.
	-- Table 4.6 x 2.65 x 3.33 (top of the planks 2.5); X -91.95..-87.35 (FruitDisplay ends at -92), Z 34.14..37.47 (sign at Z 33.2..33.4, Y 4.9..6.4).
	-- Crates sit on Slot_1 / Slot_2 (local x -/+1.05, z 0.307 in Roblox axes): world (-90.70 / -88.60, 2.91, 35.5).
	{ asset = "AST-098_ProduceStand", x = -83.6, y = 0.4, z = 33.687, rotY = 180, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/ProduceDisplay" }, note = "scenery, no prompt (DEC-109); front (planks edge) faces the store (south)" },
	{ asset = "AST-050_LettuceCrate", x = -82.55, y = 2.91, z = 33.38, rotY = 180, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/ProduceDisplay" }, note = "on AST-098 Slot (was on the floor at -91)" },
	{ asset = "AST-050_LettuceCrate", x = -84.65, y = 2.91, z = 33.38, rotY = 180, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/ProduceDisplay" }, note = "on AST-098 Slot (was on the floor at -89)" },

	---------------------------------------------------------------------------------------------
	-- 6. STREET FURNITURE (proposed spots, Provisional; nothing > 3 tall in the Z 30..47 band)
	---------------------------------------------------------------------------------------------
	{ asset = "AST-034_ParkBench", x = 57.2, y = 0.45, z = 62.12, rotY = 0, group = "StreetFurniture", id = "L3", replaces = { "Pad/PadBench_L3" }, note = "faces north (drawer)" },
	{ asset = "AST-034_ParkBench", x = -39, y = 0.4, z = 54.5, rotY = 0, group = "StreetFurniture", id = "Z-12", replaces = {} },
	{ asset = "AST-034_Planter", x = -54, y = 0.4, z = 54.5, rotY = 0, group = "StreetFurniture", id = "Z-12", replaces = {} },
	{ asset = "AST-034_Planter", x = -28, y = 0.4, z = 54.5, rotY = 0, group = "StreetFurniture", id = "Z-12", replaces = {} },
	{ asset = "AST-034_TreeLarge", x = -108, y = 0.4, z = 19.5, rotY = 0, group = "StreetFurniture", id = "T-01", replaces = {} },
	{ asset = "AST-034_TreeSmall", x = -84, y = 0.4, z = 19.5, rotY = 0, group = "StreetFurniture", id = "T-02", replaces = {} },
	{ asset = "AST-034_TreeLarge", x = -68, y = 0.4, z = -32.918, rotY = 0, group = "StreetFurniture", id = "T-03", replaces = {}, note = "in front of the B3a / B2b gap" },
	{ asset = "AST-034_TreeSmall", x = -108, y = 0.4, z = -27.5, rotY = 0, group = "StreetFurniture", id = "T-04", replaces = {} },
	{ asset = "AST-034_TreeSmall", x = 104, y = 0.4, z = 19.5, rotY = 0, group = "StreetFurniture", id = "T-05", replaces = {} },
	{ asset = "AST-034_TreeLarge", x = 92, y = 0.4, z = -27.5, rotY = 0, group = "StreetFurniture", id = "T-06", replaces = {} },
	{ asset = "AST-034_TrashCan", x = -46, y = 0.4, z = 17.5, rotY = 180, group = "StreetFurniture", id = "Z-02", replaces = {} },
	{ asset = "AST-034_TrashCan", x = 66, y = 0.4, z = 17.5, rotY = 180, group = "StreetFurniture", id = "Z-02", replaces = {} },
	{ asset = "AST-034_TrashCan", x = -30, y = 0.4, z = -17.5, rotY = 180, group = "StreetFurniture", id = "Z-06", replaces = {} },
	{ asset = "AST-034_Hydrant", x = 32, y = 0.4, z = -17.5, rotY = 180, group = "StreetFurniture", id = "Z-06", replaces = {}, note = "red-curb stretch" },
	{ asset = "AST-034_Mailbox", x = -46, y = 0.4, z = -18.5, rotY = 180, group = "StreetFurniture", id = "Z-06", replaces = {} },
	{ asset = "AST-034_StreetSign", x = 15.042, y = 0.4, z = -19.8, rotY = 180, group = "StreetFurniture", id = "NE-corner", replaces = {}, note = "NINTH AVE / JUNIPER ST decal (AST-072)" },
	{ asset = "AST-034_StreetSign", x = -13, y = 0.4, z = 17.5, rotY = 0, group = "StreetFurniture", id = "SW-corner", replaces = {} },

	-- Barriers BAR-N / BAR-S (AST-047): fence along X on each Juniper sidewalk, on tiles (y 0.24)
	{ asset = "AST-047_Barrier", x = -18.001, y = 0.4, z = -73.386, rotY = 89.994, group = "Barriers", id = "BAR-N", replaces = { "Signs/SidewalkClosed_BAR-N_W" }, note = "0.8 south of the sawhorse so it clears the cones" },
	{ asset = "AST-047_Barrier", x = 17.902, y = 0.4, z = -73.885, rotY = 89.994, group = "Barriers", id = "BAR-N", replaces = { "Signs/SidewalkClosed_BAR-N_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-047_Barrier", x = -18.329, y = 0.4, z = 77.842, rotY = 90, group = "Barriers", id = "BAR-S", replaces = { "Signs/SidewalkClosed_BAR-S_W" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-047_Barrier", x = 17.886, y = 0.4, z = 77.885, rotY = 90, group = "Barriers", id = "BAR-S", replaces = { "Signs/SidewalkClosed_BAR-S_E" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-047_ConstructionCone", x = -22.601, y = 0.4, z = -74.599, rotY = -0.006, group = "Barriers", id = "BAR-N", replaces = { "Signs/Cones_AST-047/Cone_-22_-75" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-047_ConstructionCone", x = -13.801, y = 0.4, z = -74.609, rotY = -0.006, group = "Barriers", id = "BAR-N", replaces = { "Signs/Cones_AST-047/Cone_-14_-75" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-047_ConstructionCone", x = 13.465, y = 0.3, z = -74.132, rotY = -42.972, group = "Barriers", id = "BAR-N", replaces = { "Signs/Cones_AST-047/Cone_14_-75" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-047_ConstructionCone", x = 21.962, y = 0.4, z = -74.999, rotY = -0.006, group = "Barriers", id = "BAR-N", replaces = { "Signs/Cones_AST-047/Cone_22_-75" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-047_ConstructionCone", x = -22.8, y = 0.4, z = 79.14, rotY = 19.6, group = "Barriers", id = "BAR-S", replaces = { "Signs/Cones_AST-047/Cone_-22_79" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-047_ConstructionCone", x = -13.54, y = 0.4, z = 78.5, rotY = -23.1, group = "Barriers", id = "BAR-S", replaces = { "Signs/Cones_AST-047/Cone_-14_79" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-047_ConstructionCone", x = 13.475, y = 0.4, z = 78.807, rotY = 23.1, group = "Barriers", id = "BAR-S", replaces = { "Signs/Cones_AST-047/Cone_14_79" }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-047_ConstructionCone", x = 22.34, y = 0.4, z = 78.91, rotY = 0, group = "Barriers", id = "BAR-S", replaces = { "Signs/Cones_AST-047/Cone_22_79" }, note = "user 2026-10-11: edited in Studio (captured)" },

	---------------------------------------------------------------------------------------------
	-- 7. PARKED VEHICLES (AST-035; headlights = local +Z). PARK-N faces west (rotY 270) on the
	--    WB parking lane, Z -12.6 (up to 0.6 over the lane line). Lot cars nose-in to the north.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-035_CarSedan", x = -104, y = 0, z = -12.6, rotY = 90, group = "Vehicles", id = "PARK-N", paint = "Butter", replaces = { "Parking/PARK-N/ParkN_Car_1" } },
	{ asset = "AST-035_CarHatch", x = -90, y = 0, z = -12.6, rotY = 90, group = "Vehicles", id = "PARK-N", paint = "Peach", replaces = { "Parking/PARK-N/ParkN_Car_2" } },
	{ asset = "AST-035_CarVan", x = -62, y = 0, z = -12.6, rotY = 90, group = "Vehicles", id = "PARK-N", paint = "TealLight", replaces = { "Parking/PARK-N/ParkN_Car_3" } },
	{ asset = "AST-035_CarPickup", x = -44, y = 0, z = -12.6, rotY = 90, group = "Vehicles", id = "PARK-N", paint = "Lilac", replaces = { "Parking/PARK-N/ParkN_Car_4" }, note = "ends at X -37, clear of the red curb (-32)" },
	{ asset = "AST-035_CarSedan", x = -133, y = 0, z = -12.6, rotY = 90, group = "Vehicles", id = "PARK-N", paint = "MintGray", replaces = { "Parking/PARK-N/ParkN_Car_5" }, note = "2026-10-10: moved from X 84 (between the trailer window and the Walker posts NL-02/03), beyond BAR-W" },
	{ asset = "AST-035_CarHatch", x = -118, y = 0, z = -12.6, rotY = 90, group = "Vehicles", id = "PARK-N", paint = "Butter", replaces = { "Parking/PARK-N/ParkN_Car_6" }, note = "2026-10-10: moved from X 98 (Walker sight), beyond BAR-W" },
	{ asset = "AST-035_CarHatch", x = 60, y = 0.02, z = -81, rotY = 0, group = "Vehicles", id = "Z-05", paint = "Peach", replaces = { "Parking/LotCar_1" } },
	{ asset = "AST-035_CarSedan", x = 68, y = 0.02, z = -81, rotY = 0, group = "Vehicles", id = "Z-05", paint = "Lilac", replaces = { "Parking/LotCar_2" } },
	{ asset = "AST-035_CarPickup", x = 100, y = 0.02, z = -48, rotY = 0, group = "Vehicles", id = "Z-05", paint = "TealLight", replaces = { "Parking/LotCar_3" } },
	{ asset = "AST-035_CarVan", x = 92, y = 0.02, z = -72.5, rotY = 0, group = "Vehicles", id = "AS-1", paint = "MintGray", replaces = { "Parking/Van_AS-1_Cover" }, note = "6.35 tall, Z -79..-66: still hides AS-1 (92, -80) from the Pad" },

	---------------------------------------------------------------------------------------------
	-- 8. AMBIENCE (2026-10-10, level-designer, Provisional; MAP-01 §17). Numbers generated by a one-off script from the
	--    MAP-01 §17 rules (checked against the NpcNode graph, TR-* paths, boxes, points and sight lines); edit by hand from here.
	---------------------------------------------------------------------------------------------
	-- 8a. BACKGROUND MASSES (2026-10-10, ambience pass, user: 'mapa muito pequeno, precisa de mais ambiente'). The grey
	--     Fill_* boxes of the blockout become real buildings (Kenney A/H on the faces seen from the play area, BG cards
	--     behind and above them). Overlapping Kenney pieces get distinct y (0 / -0.3 / -0.6 / -0.9) so roofs never z-fight.
	{ asset = "AST-033_BuildingH", x = 33.355, y = 0, z = -72.8, rotY = 270, group = "CityFill", id = "FILL-NBR", replaces = { "Buildings/Fill_N_BankRear" }, note = "faces the Juniper North (Z -64.6..-81); 0.6 clear of the bank back (Z -64.47); keeps SP-A in the shadow like the fill" },
	{ asset = "AST-033_BuildingA", x = 32.725, y = -0.6, z = -79.8, rotY = 270, group = "CityFill", id = "FILL-NBR", replaces = {  }, note = "Z -71.6..-88" },
	{ asset = "AST-033_BuildingA", x = 43.275, y = -0.3, z = -72.8, rotY = 90, group = "CityFill", id = "FILL-NBR", replaces = {  }, note = "faces the parking lot" },
	{ asset = "AST-033_BuildingH", x = 42.645, y = -0.9, z = -79.8, rotY = 90, group = "CityFill", id = "FILL-NBR", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = 40.2, y = 0, z = -96.725, rotY = 0, group = "CityFill", id = "FILL-NPR", replaces = { "Buildings/Fill_N_ParkingRear" }, note = "SP-A alley X 24..32 stays open" },
	{ asset = "AST-033_BuildingH", x = 56.6, y = 0, z = -97.355, rotY = 0, group = "CityFill", id = "FILL-NPR", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = 73, y = 0, z = -96.725, rotY = 0, group = "CityFill", id = "FILL-NPR", replaces = {  } },
	{ asset = "AST-033_BuildingH", x = 89.4, y = 0, z = -97.355, rotY = 0, group = "CityFill", id = "FILL-NPR", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = 95.8, y = -0.4, z = -96.725, rotY = 0, group = "CityFill", id = "FILL-NPR", replaces = {  }, note = "last piece overlaps the 4th (X 87.6..104), sunk 0.4" },
	{ asset = "AST-033_BGCard_A", x = 44.3, y = 0, z = -131.9, rotY = 0, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityFill", id = "FILL-NPR", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 66.145, y = 0, z = -131.9, rotY = 0, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityFill", id = "FILL-NPR", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 88.565, y = 0, z = -131.9, rotY = 0, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityFill", id = "FILL-NPR", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 48.45, y = 0, z = -115.15, rotY = 180, parts = { ["BG_Card_B"] = { 0, 23.7, 0, size = { 24.9, 47.4, 6.3 } } }, group = "CityFill", id = "FILL-NPR", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = -44.725, y = 0, z = -72.2, rotY = 90, group = "CityFill", id = "FILL-NW", replaces = { "Buildings/Fill_NW" }, note = "AS-3 strip X -36..-24 stays open" },
	{ asset = "AST-033_BuildingH", x = -45.355, y = 0, z = -88.6, rotY = 90, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = -44.725, y = 0, z = -105, rotY = 90, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BuildingH", x = -45.355, y = 0, z = -121.4, rotY = 90, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = -44.725, y = -0.4, z = -126, rotY = 90, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -128.115, y = 0, z = -131.9, rotY = 0, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -106.7, y = 0, z = -131.9, rotY = 0, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -79.78, y = 0, z = -131.9, rotY = 0, parts = { ["BG_Card_C"] = { 0, 12.09, 0, size = { 26.78, 24.18, 4.2 } } }, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -60.195, y = 0, z = -131.9, rotY = 0, parts = { ["BG_Card_B"] = { 0, 11.793, 0, size = { 12.39, 23.586, 4.2 } } }, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -121.55, y = 0, z = -71.15, rotY = 180, parts = { ["BG_Card_B"] = { 0, 23.7, 0, size = { 24.9, 47.4, 6.3 } } }, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -82.73, y = 0, z = -74.15, rotY = 180, parts = { ["BG_Card_A"] = { 0, 23.37, 0, size = { 46.74, 46.74, 6.3 } } }, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -111.74, y = 0, z = -103.15, rotY = 180, parts = { ["BG_Card_B"] = { 0, 34.76, 0, size = { 36.52, 69.52, 6.3 } } }, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = -112.9, y = 0, z = 40.725, rotY = 180, group = "CityFill", id = "FILL-SWW", replaces = { "Buildings/Fill_SW_West" }, note = "X -121.1..-104.7, closes the Mart NW corner" },
	{ asset = "AST-033_BuildingH", x = -129.3, y = 0, z = 41.355, rotY = 180, group = "CityFill", id = "FILL-SWW", replaces = {  }, note = "X -137.5..-121.1" },
	{ asset = "AST-033_BGCard_A", x = -133.9, y = 0, z = 63.07, rotY = 90, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityFill", id = "FILL-SWW", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -133.9, y = 0, z = 86.5, rotY = 90, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityFill", id = "FILL-SWW", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -133.9, y = 0, z = 109.16, rotY = 90, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityFill", id = "FILL-SWW", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -109.15, y = 0, z = 67.28, rotY = 270, parts = { ["BG_Card_B"] = { 0, 25.28, 0, size = { 26.56, 50.56, 6.3 } } }, group = "CityFill", id = "FILL-SWW", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -86.513, y = 0, z = 74.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 25.675, 0, size = { 26.975, 51.35, 4.2 } } }, group = "CityFill", id = "FILL-SWM", replaces = { "Buildings/Fill_SW_MartRear" } },
	{ asset = "AST-033_BGCard_A", x = -87.7, y = 0, z = 117.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityFill", id = "FILL-SWM", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -69.7, y = 0, z = 117.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 10.851, 0, size = { 11.4, 21.701, 4.2 } } }, group = "CityFill", id = "FILL-SWM", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = 32.725, y = 0, z = 92.2, rotY = 270, group = "CityFill", id = "FILL-SE", replaces = { "Buildings/Fill_SE_B1Rear" }, note = "Z 84..100.4; hides SP-S / ST-R like the fill" },
	{ asset = "AST-033_BuildingH", x = 33.355, y = 0, z = 108.6, rotY = 270, group = "CityFill", id = "FILL-SE", replaces = {  }, note = "Z 100.4..116.8" },
	{ asset = "AST-033_BGCard_B", x = 55.62, y = 0, z = 95.15, rotY = 0, parts = { ["BG_Card_B"] = { 0, 22.12, 0, size = { 23.24, 44.24, 6.3 } } }, group = "CityFill", id = "FILL-SE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 92.38, y = 0, z = 98.15, rotY = 0, parts = { ["BG_Card_A"] = { 0, 22.14, 0, size = { 44.28, 44.28, 6.3 } } }, group = "CityFill", id = "FILL-SE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 56.875, y = 0, z = 117.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityFill", id = "FILL-SE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 77.635, y = 0, z = 117.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityFill", id = "FILL-SE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 99.05, y = 0, z = 117.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityFill", id = "FILL-SE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 124.29, y = 0, z = 117.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 10.573, 0, size = { 23.42, 21.146, 4.2 } } }, group = "CityFill", id = "FILL-SE", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = 128.2, y = 0, z = 40.725, rotY = 180, group = "CityFill", id = "FILL-E", replaces = { "Buildings/Fill_E" }, note = "X 120..136.4 on the Ninth" },
	{ asset = "AST-033_BuildingA", x = 128.725, y = -0.3, z = 57.65, rotY = 270, group = "CityFill", id = "FILL-E", replaces = {  }, note = "EX-E alley face, Z 49.45..65.85" },
	{ asset = "AST-033_BuildingH", x = 129.355, y = 0, z = 74.05, rotY = 270, group = "CityFill", id = "FILL-E", replaces = {  }, note = "Z 65.85..82.25" },
	{ asset = "AST-033_BGCard_B", x = 135.4, y = 0, z = 92.715, rotY = 270, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityFill", id = "FILL-E", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 135.4, y = 0, z = 112.5, rotY = 270, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityFill", id = "FILL-E", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 135.4, y = 0, z = -119.64, rotY = 270, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityFill", id = "FILL-E", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 135.4, y = 0, z = -96.98, rotY = 270, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityFill", id = "FILL-E", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 135.4, y = 0, z = -76.305, rotY = 270, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityFill", id = "FILL-E", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 135.4, y = 0, z = -57.965, rotY = 270, parts = { ["BG_Card_A"] = { 0, 7.965, 0, size = { 15.93, 15.93, 4.2 } } }, group = "CityFill", id = "FILL-E", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -135.4, y = 0, z = -119.7, rotY = 90, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -135.4, y = 0, z = -97.855, rotY = 90, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -135.4, y = 0, z = -75.435, rotY = 90, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityFill", id = "FILL-NW", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -135.4, y = 0, z = -57.28, rotY = 90, parts = { ["BG_Card_B"] = { 0, 10.051, 0, size = { 10.56, 20.102, 4.2 } } }, group = "CityFill", id = "FILL-NW", replaces = {  } },
	-- 8b. OUTER STREETS beyond the limits (visual only; no traffic route, no NPC node): east / west avenues X +-154,
	--     the Ninth, the BackStreet and a new South Street (Z 124..144) continue to X +-250 / Z -250..250. Ground slab
	--     (top -0.3) under everything; sidewalk slabs (top 0.24) fill the outer blocks.
	{ asset = "AST-032_SidewalkTile", x = 0, y = -0.78, z = 0, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 900, 0.48, 900 } } }, group = "CityOuter", id = "GROUND", replaces = {  }, note = "ground under the whole city, top -0.3" },
	{ asset = "AST-032_RoadStraight", x = 139, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 6, 0.48, 40 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-032_RoadCrossroad", x = 154, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadCrossroad"] = { 0, 0.24, 0, size = { 24, 0.48, 40 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 176.5, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 40 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 197.5, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 40 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 218.5, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 40 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 239.5, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 40 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 139, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 6, 0.48, 20 } } }, group = "CityOuter", id = "BACK-X", replaces = {  } },
	{ asset = "AST-032_RoadCrossroad", x = 154, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadCrossroad"] = { 0, 0.24, 0, size = { 24, 0.48, 20 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 176.5, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "BACK-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 197.5, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "BACK-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 218.5, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "BACK-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 239.5, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "BACK-X", replaces = {  } },
	{ asset = "AST-032_RoadCrossroad", x = 154, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadCrossroad"] = { 0, 0.24, 0, size = { 24, 0.48, 20 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 22.833, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.667, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 44.5, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.667, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 66.167, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.667, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 87.833, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.667, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 109.5, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.667, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 131.167, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.667, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 176.5, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 197.5, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 218.5, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 239.5, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = -238, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = -214, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = -190, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = -166, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = -122.6, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 22.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = -99.8, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 22.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = -77, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 22.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = -54.2, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 22.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = -31.4, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 22.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = 30.4, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 20.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = 51.2, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 20.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = 72, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 20.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = 92.8, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 20.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = 113.6, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 20.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = 154.6, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = 175.8, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = 197, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = 218.2, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 154, y = -0.24, z = 239.4, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -139, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 6, 0.48, 40 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-032_RoadCrossroad", x = -154, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadCrossroad"] = { 0, 0.24, 0, size = { 24, 0.48, 40 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -239.5, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 40 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -218.5, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 40 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -197.5, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 40 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -176.5, y = -0.24, z = 0, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 40 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -139, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 6, 0.48, 20 } } }, group = "CityOuter", id = "BACK-X", replaces = {  } },
	{ asset = "AST-032_RoadCrossroad", x = -154, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadCrossroad"] = { 0, 0.24, 0, size = { 24, 0.48, 20 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -239.5, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "BACK-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -218.5, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "BACK-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -197.5, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "BACK-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -176.5, y = -0.24, z = -144, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "BACK-X", replaces = {  } },
	{ asset = "AST-032_RoadCrossroad", x = -154, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadCrossroad"] = { 0, 0.24, 0, size = { 24, 0.48, 20 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -131.167, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.667, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -109.5, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.667, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -87.833, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.667, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -66.167, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.667, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -44.5, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.667, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -22.833, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.667, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -239.5, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -218.5, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -197.5, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -176.5, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = -238, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = -214, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = -190, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = -166, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = -122.6, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 22.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = -99.8, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 22.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = -77, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 22.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = -54.2, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 22.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = -31.4, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 22.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = 30.4, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 20.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = 51.2, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 20.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = 72, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 20.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = 92.8, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 20.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = 113.6, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 20.8, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = 154.6, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = 175.8, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = 197, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = 218.2, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = -154, y = -0.24, z = 239.4, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-032_RoadCrossroad", x = 0, y = -0.24, z = 134, rotY = 0, parts = { ["AST-032_RoadCrossroad"] = { 0, 0.24, 0, size = { 24, 0.48, 20 } } }, group = "CityOuter", id = "SOUTH-ST", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -238, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24, 0.48, 24 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -214, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24, 0.48, 24 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -190, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24, 0.48, 24 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -166, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 24, 0.48, 24 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 154.6, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 175.8, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 197, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 218.2, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 239.4, rotY = 90, parts = { ["AST-032_RoadStraight"] = { 0, 0.24, 0, size = { 21.2, 0.48, 24 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = -208, y = -0.24, z = -202, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 84, 0.48, 96 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = -208, y = -0.24, z = 197, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 84, 0.48, 106 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = -77, y = -0.24, z = -202, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 130, 0.48, 96 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = -77, y = -0.24, z = 197, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 130, 0.48, 106 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = 77, y = -0.24, z = -202, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 130, 0.48, 96 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = 77, y = -0.24, z = 197, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 130, 0.48, 106 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = 208, y = -0.24, z = -202, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 84, 0.48, 96 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = 208, y = -0.24, z = 197, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 84, 0.48, 106 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = -208, y = -0.24, z = -77, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 84, 0.48, 114 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = -208, y = -0.24, z = 72, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 84, 0.48, 104 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = 208, y = -0.24, z = -77, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 84, 0.48, 114 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = 208, y = -0.24, z = 72, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 84, 0.48, 104 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = -139, y = -0.24, z = -77, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 6, 0.48, 114 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = -139, y = -0.24, z = 72, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 6, 0.48, 104 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = 139, y = -0.24, z = -77, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 6, 0.48, 114 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	{ asset = "AST-032_SidewalkTile", x = 139, y = -0.24, z = 72, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 6, 0.48, 104 } } }, group = "CityOuter", id = "BLOCK", replaces = {  } },
	-- 8c. OUTER BUILDINGS: Kenney A/H where a street vista from the play area ends on them (Ninth E/W past the avenues,
	--     Juniper N/S past the cross streets), BG cards elsewhere (90-118 tris each); tall cards (x1.8-2.6) behind as skyline.
	{ asset = "AST-033_BuildingA", x = 180.2, y = 0, z = -34.725, rotY = 0, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BuildingH", x = 196.6, y = 0, z = -35.355, rotY = 0, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 218.33, y = 0, z = -28.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 240.93, y = 0, z = -28.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 8.189, 0, size = { 18.14, 16.379, 4.2 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BuildingH", x = 180.2, y = 0, z = 35.355, rotY = 180, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = 196.6, y = 0, z = 34.725, rotY = 180, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 213.515, y = 0, z = 28.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 233.3, y = 0, z = 28.1, rotY = 0, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 174.1, y = 0, z = -117.7, rotY = 90, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 174.1, y = 0, z = -97.025, rotY = 90, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 174.1, y = 0, z = -73.12, rotY = 90, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 174.1, y = 0, z = -52.795, rotY = 90, parts = { ["BG_Card_A"] = { 0, 6.795, 0, size = { 13.59, 13.59, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 174.1, y = 0, z = 55.545, rotY = 90, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 174.1, y = 0, z = 77.965, rotY = 90, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 174.1, y = 0, z = 98.725, rotY = 90, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 174.1, y = 0, z = 163.39, rotY = 90, parts = { ["BG_Card_C"] = { 0, 12.09, 0, size = { 26.78, 24.18, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 174.1, y = 0, z = 185.495, rotY = 90, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 174.1, y = 0, z = 205.28, rotY = 90, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 174.1, y = 0, z = 228.71, rotY = 90, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 174.1, y = 0, z = -239.625, rotY = 90, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 174.1, y = 0, z = -215.72, rotY = 90, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 174.1, y = 0, z = -189.89, rotY = 90, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 174.1, y = 0, z = -168.795, rotY = 90, parts = { ["BG_Card_B"] = { 0, 16.742, 0, size = { 17.59, 33.485, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 133.9, y = 0, z = -237.125, rotY = 270, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 133.9, y = 0, z = -216.365, rotY = 270, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 133.9, y = 0, z = -194.95, rotY = 270, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 133.9, y = 0, z = -173.71, rotY = 270, parts = { ["BG_Card_C"] = { 0, 6.961, 0, size = { 15.42, 13.923, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 133.9, y = 0, z = 158.715, rotY = 270, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 133.9, y = 0, z = 178.5, rotY = 270, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 133.9, y = 0, z = 201.93, rotY = 270, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 133.9, y = 0, z = 224.59, rotY = 270, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 133.9, y = 0, z = 242.445, rotY = 270, parts = { ["BG_Card_B"] = { 0, 14.382, 0, size = { 15.11, 28.764, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 265.15, y = 0, z = -247.06, rotY = 90, parts = { ["BG_Card_B"] = { 0, 28.44, 0, size = { 29.88, 56.88, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 268.15, y = 0, z = -197.83, rotY = 90, parts = { ["BG_Card_A"] = { 0, 28.29, 0, size = { 56.58, 56.58, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 265.15, y = 0, z = -146.94, rotY = 90, parts = { ["BG_Card_B"] = { 0, 31.6, 0, size = { 33.2, 63.2, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 268.15, y = 0, z = -97.56, rotY = 90, parts = { ["BG_Card_C"] = { 0, 24.18, 0, size = { 53.56, 48.36, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 265.15, y = 0, z = -41.41, rotY = 90, parts = { ["BG_Card_A"] = { 0, 23.37, 0, size = { 46.74, 46.74, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 268.15, y = 0, z = 2.9, rotY = 90, parts = { ["BG_Card_B"] = { 0, 28.44, 0, size = { 29.88, 56.88, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 265.15, y = 0, z = 52.13, rotY = 90, parts = { ["BG_Card_A"] = { 0, 28.29, 0, size = { 56.58, 56.58, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 268.15, y = 0, z = 103.02, rotY = 90, parts = { ["BG_Card_B"] = { 0, 31.6, 0, size = { 33.2, 63.2, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 265.15, y = 0, z = 152.4, rotY = 90, parts = { ["BG_Card_C"] = { 0, 24.18, 0, size = { 53.56, 48.36, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 268.15, y = 0, z = 208.55, rotY = 90, parts = { ["BG_Card_A"] = { 0, 23.37, 0, size = { 46.74, 46.74, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = -180.2, y = 0, z = -34.725, rotY = 0, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BuildingH", x = -196.6, y = 0, z = -35.355, rotY = 0, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -236.47, y = 0, z = -28.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -213.87, y = 0, z = -28.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 9.07, 0, size = { 18.14, 18.14, 4.2 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BuildingH", x = -180.2, y = 0, z = 35.355, rotY = 180, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = -196.6, y = 0, z = 34.725, rotY = 180, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -240.455, y = 0, z = 28.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -218.035, y = 0, z = 28.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "NINTH-X", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -174.1, y = 0, z = -120.115, rotY = 270, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -174.1, y = 0, z = -98.7, rotY = 270, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -174.1, y = 0, z = -71.78, rotY = 270, parts = { ["BG_Card_C"] = { 0, 12.09, 0, size = { 26.78, 24.18, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -174.1, y = 0, z = -52.195, rotY = 270, parts = { ["BG_Card_B"] = { 0, 11.793, 0, size = { 12.39, 23.586, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -174.1, y = 0, z = 57.07, rotY = 270, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -174.1, y = 0, z = 80.5, rotY = 270, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -174.1, y = 0, z = 103.16, rotY = 270, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -174.1, y = 0, z = 163.53, rotY = 270, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -174.1, y = 0, z = 189.36, rotY = 270, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -174.1, y = 0, z = 211.205, rotY = 270, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -174.1, y = 0, z = 233.625, rotY = 270, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -174.1, y = 0, z = -242.115, rotY = 270, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -174.1, y = 0, z = -220.7, rotY = 270, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -174.1, y = 0, z = -193.78, rotY = 270, parts = { ["BG_Card_C"] = { 0, 12.09, 0, size = { 26.78, 24.18, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -174.1, y = 0, z = -171.675, rotY = 270, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -133.9, y = 0, z = -238.93, rotY = 90, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -133.9, y = 0, z = -215.5, rotY = 90, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -133.9, y = 0, z = -192.84, rotY = 90, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -133.9, y = 0, z = -174.27, rotY = 90, parts = { ["BG_Card_B"] = { 0, 15.743, 0, size = { 16.54, 31.486, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -133.9, y = 0, z = 163.53, rotY = 90, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -133.9, y = 0, z = 189.36, rotY = 90, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -133.9, y = 0, z = 211.205, rotY = 90, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -133.9, y = 0, z = 233.625, rotY = 90, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "AVE", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -265.15, y = 0, z = -247.06, rotY = 270, parts = { ["BG_Card_B"] = { 0, 28.44, 0, size = { 29.88, 56.88, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -268.15, y = 0, z = -197.83, rotY = 270, parts = { ["BG_Card_A"] = { 0, 28.29, 0, size = { 56.58, 56.58, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -265.15, y = 0, z = -146.94, rotY = 270, parts = { ["BG_Card_B"] = { 0, 31.6, 0, size = { 33.2, 63.2, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -268.15, y = 0, z = -97.56, rotY = 270, parts = { ["BG_Card_C"] = { 0, 24.18, 0, size = { 53.56, 48.36, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -265.15, y = 0, z = -41.41, rotY = 270, parts = { ["BG_Card_A"] = { 0, 23.37, 0, size = { 46.74, 46.74, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -268.15, y = 0, z = 2.9, rotY = 270, parts = { ["BG_Card_B"] = { 0, 28.44, 0, size = { 29.88, 56.88, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -265.15, y = 0, z = 52.13, rotY = 270, parts = { ["BG_Card_A"] = { 0, 28.29, 0, size = { 56.58, 56.58, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -268.15, y = 0, z = 103.02, rotY = 270, parts = { ["BG_Card_B"] = { 0, 31.6, 0, size = { 33.2, 63.2, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -265.15, y = 0, z = 152.4, rotY = 270, parts = { ["BG_Card_C"] = { 0, 24.18, 0, size = { 53.56, 48.36, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -268.15, y = 0, z = 208.55, rotY = 270, parts = { ["BG_Card_A"] = { 0, 23.37, 0, size = { 46.74, 46.74, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BuildingH", x = 26.2, y = 0, z = -169.355, rotY = 0, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = 42.6, y = 0, z = -168.725, rotY = 0, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 58.685, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 80.1, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 107.02, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 12.09, 0, size = { 26.78, 24.18, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 128.205, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 14.839, 0, size = { 15.59, 29.677, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 183.07, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 206.5, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 229.16, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 244.73, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 10.032, 0, size = { 10.54, 20.064, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 20.1, y = 0, z = -236.47, rotY = 90, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 20.1, y = 0, z = -210.64, rotY = 90, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 20.1, y = 0, z = -189.17, rotY = 90, parts = { ["BG_Card_B"] = { 0, 17.456, 0, size = { 18.34, 34.912, 4.2 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = 26.2, y = 0, z = 158.725, rotY = 180, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BuildingH", x = 42.6, y = 0, z = 159.355, rotY = 180, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 63.675, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 84.435, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 105.85, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 127.69, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 7.503, 0, size = { 16.62, 15.006, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 180.715, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 200.5, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 223.93, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 243.145, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 6.189, 0, size = { 13.71, 12.379, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 20.1, y = 0, z = 180.375, rotY = 90, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 20.1, y = 0, z = 204.28, rotY = 90, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 20.1, y = 0, z = 230.11, rotY = 90, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-033_BuildingH", x = -26.2, y = 0, z = -169.355, rotY = 0, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = -42.6, y = 0, z = -168.725, rotY = 0, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -123.125, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -102.365, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -80.95, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -59.11, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 7.503, 0, size = { 16.62, 15.006, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -241.285, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -221.5, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -198.07, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -178.855, y = 0, z = -162.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 6.189, 0, size = { 13.71, 12.379, 4.2 } } }, group = "CityOuter", id = "NORTH", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -20.1, y = 0, z = -239.625, rotY = 270, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -20.1, y = 0, z = -215.72, rotY = 270, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -20.1, y = 0, z = -191.095, rotY = 270, parts = { ["BG_Card_A"] = { 0, 11.095, 0, size = { 22.19, 22.19, 4.2 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-033_BuildingA", x = -26.2, y = 0, z = 158.725, rotY = 180, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BuildingH", x = -42.6, y = 0, z = 159.355, rotY = 180, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -126.455, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -104.035, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -83.275, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -63.095, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_A"] = { 0, 12.295, 0, size = { 24.59, 24.59, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -236.61, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 12.09, 0, size = { 26.78, 24.18, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -214.505, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -194.72, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -177.825, y = 0, z = 152.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 5.259, 0, size = { 11.65, 10.519, 4.2 } } }, group = "CityOuter", id = "SOUTH", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -20.1, y = 0, z = 180.3, rotY = 270, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -20.1, y = 0, z = 200.975, rotY = 270, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -20.1, y = 0, z = 224.88, rotY = 270, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "JUNIPER-X", replaces = {  } },
	--     block interiors: card rows every 26 (only seen from above or through gaps)
	{ asset = "AST-033_BGCard_B", x = -228.455, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -204.035, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -183.58, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 10.622, 0, size = { 11.16, 21.244, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -224.47, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -195.55, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_C"] = { 0, 12.09, 0, size = { 26.78, 24.18, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -229.285, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -207.5, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -186.215, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 7.417, 0, size = { 16.43, 14.835, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -227.7, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -205.025, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -185.325, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_A"] = { 0, 7.325, 0, size = { 14.65, 14.65, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -225.7, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -201.855, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -184.155, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 5.557, 0, size = { 12.31, 11.115, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -122.115, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -98.7, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -69.78, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 12.09, 0, size = { 26.78, 24.18, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -45.675, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -117.64, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -92.98, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -70.305, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -44.4, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -120.455, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -96.035, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -73.275, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -49.86, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -121.285, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -99.5, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -74.07, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -49.41, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -30.555, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 12.478, 0, size = { 13.11, 24.956, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -116.47, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -88.64, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -64.795, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -40.375, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 31.885, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 55.3, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 84.22, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 12.09, 0, size = { 26.78, 24.18, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 108.325, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 36.36, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 61.02, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 83.695, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 109.6, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 33.545, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 57.965, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 80.725, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 104.14, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 32.715, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 54.5, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 79.93, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 11.16, 0, size = { 24.72, 22.32, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 104.59, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 123.445, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 12.478, 0, size = { 13.11, 24.956, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 37.53, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 65.36, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 89.205, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 113.625, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 11.625, 0, size = { 25.75, 23.25, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 185.885, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 209.3, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 231.415, y = 0, z = -228.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 5.946, 0, size = { 13.17, 11.891, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 186.715, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 208.5, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 229.785, y = 0, z = -197.9, rotY = 0, parts = { ["BG_Card_C"] = { 0, 7.417, 0, size = { 16.43, 14.835, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 188.3, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 210.975, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 230.675, y = 0, z = 165.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 7.325, 0, size = { 14.65, 14.65, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 190.3, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 214.145, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 231.845, y = 0, z = 196.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 5.557, 0, size = { 12.31, 11.115, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 185.885, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 209.3, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 231.415, y = 0, z = 217.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 5.946, 0, size = { 13.17, 11.891, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -229.285, y = 0, z = -112.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -207.5, y = 0, z = -112.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -186.215, y = 0, z = -112.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 7.417, 0, size = { 16.43, 14.835, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -227.7, y = 0, z = -81.9, rotY = 0, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -205.025, y = 0, z = -81.9, rotY = 0, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -185.325, y = 0, z = -81.9, rotY = 0, parts = { ["BG_Card_A"] = { 0, 7.325, 0, size = { 14.65, 14.65, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -225.7, y = 0, z = -60.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -201.855, y = 0, z = -60.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -184.155, y = 0, z = -60.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 5.557, 0, size = { 12.31, 11.115, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -230.115, y = 0, z = 41.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -206.7, y = 0, z = 41.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -184.585, y = 0, z = 41.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 5.946, 0, size = { 13.17, 11.891, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -229.285, y = 0, z = 72.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -207.5, y = 0, z = 72.1, rotY = 0, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -186.215, y = 0, z = 72.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 7.417, 0, size = { 16.43, 14.835, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -227.7, y = 0, z = 93.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -205.025, y = 0, z = 93.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -185.325, y = 0, z = 93.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 7.325, 0, size = { 14.65, 14.65, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 190.3, y = 0, z = -112.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 214.145, y = 0, z = -112.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 231.845, y = 0, z = -112.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 5.557, 0, size = { 12.31, 11.115, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 185.885, y = 0, z = -81.9, rotY = 0, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 209.3, y = 0, z = -81.9, rotY = 0, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 231.415, y = 0, z = -81.9, rotY = 0, parts = { ["BG_Card_C"] = { 0, 5.946, 0, size = { 13.17, 11.891, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 186.715, y = 0, z = -60.1, rotY = 180, parts = { ["BG_Card_B"] = { 0, 16.59, 0, size = { 17.43, 33.18, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 208.5, y = 0, z = -60.1, rotY = 180, parts = { ["BG_Card_A"] = { 0, 11.07, 0, size = { 22.14, 22.14, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 229.785, y = 0, z = -60.1, rotY = 180, parts = { ["BG_Card_C"] = { 0, 7.417, 0, size = { 16.43, 14.835, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 188.3, y = 0, z = 41.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 9.3, 0, size = { 20.6, 18.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 210.975, y = 0, z = 41.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 19.75, 0, size = { 20.75, 39.5, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 230.675, y = 0, z = 41.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 7.325, 0, size = { 14.65, 14.65, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 190.3, y = 0, z = 72.1, rotY = 0, parts = { ["BG_Card_A"] = { 0, 12.3, 0, size = { 24.6, 24.6, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 214.145, y = 0, z = 72.1, rotY = 0, parts = { ["BG_Card_B"] = { 0, 18.17, 0, size = { 19.09, 36.34, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 231.845, y = 0, z = 72.1, rotY = 0, parts = { ["BG_Card_C"] = { 0, 5.557, 0, size = { 12.31, 11.115, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 185.885, y = 0, z = 93.9, rotY = 180, parts = { ["BG_Card_B"] = { 0, 15.01, 0, size = { 15.77, 30.02, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 209.3, y = 0, z = 93.9, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13.53, 0, size = { 27.06, 27.06, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 231.415, y = 0, z = 93.9, rotY = 180, parts = { ["BG_Card_C"] = { 0, 5.946, 0, size = { 13.17, 11.891, 4.2 } } }, group = "CityOuter", id = "BLOCK-IN", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -241.06, y = 0, z = -265.15, rotY = 180, parts = { ["BG_Card_B"] = { 0, 28.44, 0, size = { 29.88, 56.88, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -191.83, y = 0, z = -268.15, rotY = 180, parts = { ["BG_Card_A"] = { 0, 28.29, 0, size = { 56.58, 56.58, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -140.94, y = 0, z = -265.15, rotY = 180, parts = { ["BG_Card_B"] = { 0, 31.6, 0, size = { 33.2, 63.2, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -91.56, y = 0, z = -268.15, rotY = 180, parts = { ["BG_Card_C"] = { 0, 24.18, 0, size = { 53.56, 48.36, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -35.41, y = 0, z = -265.15, rotY = 180, parts = { ["BG_Card_A"] = { 0, 23.37, 0, size = { 46.74, 46.74, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 8.9, y = 0, z = -268.15, rotY = 180, parts = { ["BG_Card_B"] = { 0, 28.44, 0, size = { 29.88, 56.88, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 58.13, y = 0, z = -265.15, rotY = 180, parts = { ["BG_Card_A"] = { 0, 28.29, 0, size = { 56.58, 56.58, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 109.02, y = 0, z = -268.15, rotY = 180, parts = { ["BG_Card_B"] = { 0, 31.6, 0, size = { 33.2, 63.2, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 158.4, y = 0, z = -265.15, rotY = 180, parts = { ["BG_Card_C"] = { 0, 24.18, 0, size = { 53.56, 48.36, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 214.55, y = 0, z = -268.15, rotY = 180, parts = { ["BG_Card_A"] = { 0, 23.37, 0, size = { 46.74, 46.74, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -241.06, y = 0, z = 265.15, rotY = 0, parts = { ["BG_Card_B"] = { 0, 28.44, 0, size = { 29.88, 56.88, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -191.83, y = 0, z = 268.15, rotY = 0, parts = { ["BG_Card_A"] = { 0, 28.29, 0, size = { 56.58, 56.58, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = -140.94, y = 0, z = 265.15, rotY = 0, parts = { ["BG_Card_B"] = { 0, 31.6, 0, size = { 33.2, 63.2, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = -91.56, y = 0, z = 268.15, rotY = 0, parts = { ["BG_Card_C"] = { 0, 24.18, 0, size = { 53.56, 48.36, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = -35.41, y = 0, z = 265.15, rotY = 0, parts = { ["BG_Card_A"] = { 0, 23.37, 0, size = { 46.74, 46.74, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 8.9, y = 0, z = 268.15, rotY = 0, parts = { ["BG_Card_B"] = { 0, 28.44, 0, size = { 29.88, 56.88, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 58.13, y = 0, z = 265.15, rotY = 0, parts = { ["BG_Card_A"] = { 0, 28.29, 0, size = { 56.58, 56.58, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_B", x = 109.02, y = 0, z = 268.15, rotY = 0, parts = { ["BG_Card_B"] = { 0, 31.6, 0, size = { 33.2, 63.2, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_C", x = 158.4, y = 0, z = 265.15, rotY = 0, parts = { ["BG_Card_C"] = { 0, 24.18, 0, size = { 53.56, 48.36, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	{ asset = "AST-033_BGCard_A", x = 214.55, y = 0, z = 268.15, rotY = 0, parts = { ["BG_Card_A"] = { 0, 23.37, 0, size = { 46.74, 46.74, 6.3 } } }, group = "CityOuter", id = "SKY", replaces = {  } },
	--     parked cars on the outer curbs (static; no traffic route goes there) and posts along the Ninth continuation
	{ asset = "AST-035_CarSedan", x = 44, y = 0, z = -148, rotY = 90, paint = "Peach", group = "CityOuter", id = "PARK-OUT", replaces = {  } },
	{ asset = "AST-035_CarVan", x = -52, y = 0, z = -148, rotY = 270, paint = "TealLight", group = "CityOuter", id = "PARK-OUT", replaces = {  } },
	{ asset = "AST-035_CarHatch", x = -96, y = 0, z = -148, rotY = 270, paint = "Lilac", group = "CityOuter", id = "PARK-OUT", replaces = {  } },
	{ asset = "AST-035_CarPickup", x = 190, y = 0, z = 12.6, rotY = 90, paint = "Butter", group = "CityOuter", id = "PARK-OUT", replaces = {  } },
	{ asset = "AST-035_CarSedan", x = -196, y = 0, z = -12.6, rotY = 270, paint = "MintGray", group = "CityOuter", id = "PARK-OUT", replaces = {  } },
	{ asset = "AST-035_CarHatch", x = 160, y = 0, z = -88, rotY = 180, paint = "Peach", group = "CityOuter", id = "PARK-OUT", replaces = {  } },
	{ asset = "AST-035_CarSedan", x = -160, y = 0, z = 76, rotY = 0, paint = "Lilac", group = "CityOuter", id = "PARK-OUT", replaces = {  } },
	{ asset = "AST-035_CarVan", x = 64, y = 0, z = 140, rotY = 90, paint = "Butter", group = "CityOuter", id = "PARK-OUT", replaces = {  } },
	{ asset = "AST-036_StreetLightCurved", x = 184, y = 0.24, z = -16.185, rotY = 0, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_LampHead", x = 184, y = 0.24, z = -14.405, rotY = 0, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_StreetLightCurved", x = 184, y = 0.24, z = 16.185, rotY = 180, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_LampHead", x = 184, y = 0.24, z = 14.405, rotY = 180, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_StreetLightCurved", x = 222, y = 0.24, z = -16.185, rotY = 0, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_LampHead", x = 222, y = 0.24, z = -14.405, rotY = 0, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_StreetLightCurved", x = 222, y = 0.24, z = 16.185, rotY = 180, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_LampHead", x = 222, y = 0.24, z = 14.405, rotY = 180, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_StreetLightCurved", x = -184, y = 0.24, z = -16.185, rotY = 0, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_LampHead", x = -184, y = 0.24, z = -14.405, rotY = 0, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_StreetLightCurved", x = -184, y = 0.24, z = 16.185, rotY = 180, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_LampHead", x = -184, y = 0.24, z = 14.405, rotY = 180, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_StreetLightCurved", x = -222, y = 0.24, z = -16.185, rotY = 0, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_LampHead", x = -222, y = 0.24, z = -14.405, rotY = 0, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_StreetLightCurved", x = -222, y = 0.24, z = 16.185, rotY = 180, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	{ asset = "AST-036_LampHead", x = -222, y = 0.24, z = 14.405, rotY = 180, group = "CityOuter", id = "POST-OUT", replaces = {  } },
	-- 8d. STREET PROPS in the play area (checked against the NpcNode graph, TR-* paths, CW/X-T boxes, Q/PS/REV/CS/SS
	--     points, the trailer -> Walker posts / WALKER-10 sight lines, the Pad -> WV-1..3 windows and the cutscene windows).
	{ asset = "AST-034_TreeLarge", x = -124, y = 0.4, z = 19.5, rotY = 0, group = "Ambience", id = "T-07", replaces = {  } },
	{ asset = "AST-034_TreeSmall", x = -60, y = 0.4, z = 19.5, rotY = 0, group = "Ambience", id = "T-08", replaces = {  } },
	{ asset = "AST-034_TreeLarge", x = -120, y = 0.4, z = -27.5, rotY = 0, group = "Ambience", id = "T-09", replaces = {  } },
	{ asset = "AST-034_TreeSmall", x = 120, y = 0.4, z = -27.5, rotY = 0, group = "Ambience", id = "T-10", replaces = {  } },
	{ asset = "AST-034_TreeLarge", x = 124, y = 0.4, z = 19.5, rotY = 0, group = "Ambience", id = "T-11", replaces = {  } },
	{ asset = "AST-034_TreeSmall", x = -20, y = 0.24, z = 64, rotY = 0, group = "Ambience", id = "T-12", replaces = {  }, note = "Juniper South west sidewalk" },
	{ asset = "AST-034_TreeSmall", x = -20, y = 0.24, z = 74, rotY = 0, group = "Ambience", id = "T-13", replaces = {  } },
	{ asset = "AST-034_TreeSmall", x = 22, y = 0.24, z = 62, rotY = 0, group = "Ambience", id = "T-14", replaces = {  }, note = "Juniper South east sidewalk, Pad corner" },
	{ asset = "AST-034_TreeSmall", x = -47, y = 0.4, z = 54, rotY = 0, group = "Ambience", id = "T-15", replaces = {  }, note = "plaza, between the bench and the west planter" },
	{ asset = "AST-034_TreeSmall", x = -33, y = 0.4, z = 54, rotY = 0, group = "Ambience", id = "T-16", replaces = {  }, note = "plaza, between the bench and the east planter" },
	{ asset = "AST-034_ParkBench", x = -80, y = 0.4, z = -29.5, rotY = 0, group = "Ambience", id = "Z-06", replaces = {  }, note = "in front of B3a, faces the street" },
	{ asset = "AST-034_ParkBench", x = 100, y = 0.4, z = 29.5, rotY = 180, group = "Ambience", id = "Z-02", replaces = {  }, note = "in front of B1, faces the street" },
	{ asset = "AST-034_Planter", x = 100, y = 0.4, z = -30.5, rotY = 0, group = "Ambience", id = "Z-06", replaces = {  } },
	{ asset = "AST-034_Planter", x = 76, y = 0.4, z = 30.8, rotY = 0, group = "Ambience", id = "Z-02", replaces = {  } },
	{ asset = "AST-034_Planter", x = 106, y = 0.4, z = 30.8, rotY = 0, group = "Ambience", id = "Z-02", replaces = {  } },
	{ asset = "AST-034_Hydrant", x = -100, y = 0.4, z = 17.5, rotY = 180, group = "Ambience", id = "Z-02", replaces = {  } },
	{ asset = "AST-034_Hydrant", x = 96, y = 0.4, z = -17.5, rotY = 180, group = "Ambience", id = "Z-06", replaces = {  } },
	{ asset = "AST-034_Hydrant", x = 22.5, y = 0.4, z = 48, rotY = 90, group = "Ambience", id = "Z-08", replaces = {  }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-034_Mailbox", x = 58, y = 0.4, z = -29.5, rotY = 180, group = "Ambience", id = "Z-06", replaces = {  }, note = "by the parking fence" },
	{ asset = "AST-034_StreetSign", x = -14.345, y = 0.4, z = -17.9, rotY = 0, group = "Ambience", id = "NW-corner", replaces = {  }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-034_StreetSign", x = 14.4, y = 0.4, z = 20.535, rotY = 90, group = "Ambience", id = "SE-corner", replaces = {  }, note = "user 2026-10-11: edited in Studio (captured)" },
	{ asset = "AST-034_Dumpster", x = 116.5, y = 0.4, z = 66, rotY = 0, group = "Ambience", id = "EX-E", replaces = {  }, note = "EX-E alley, 26 past the despawn point" },
	{ asset = "AST-034_Dumpster", x = -68.7, y = 0.4, z = -45.5, rotY = 0, group = "Ambience", id = "Z-06", replaces = {  }, note = "gap B3a / B2b, behind tree T-03" },
	{ asset = "AST-034_Dumpster", x = -33.8, y = 0.4, z = -69.602, rotY = 179.994, group = "Ambience", id = "AS-3", replaces = {  }, note = "against the Fill_NW row, beyond BAR-N" },
	{ asset = "AST-035_CarSedan", x = 76, y = 0.02, z = -81, rotY = 0, paint = "Butter", group = "Ambience", id = "Z-05", replaces = {  } },
	{ asset = "AST-035_CarHatch", x = 100, y = 0.02, z = -64, rotY = 0, paint = "MintGray", group = "Ambience", id = "Z-05", replaces = {  } },
	--     facade details: AC units / clotheslines out of reach (collide = false); AC origin = wall contact, bottom centre
	{ asset = "AST-034_ACUnit", x = -76, y = 12, z = -32, rotY = 180, collide = false, group = "Ambience", id = "AC", replaces = {  }, note = "B3a (wall plane measured in Studio)" },
	{ asset = "AST-034_ACUnit", x = -101, y = 9.5, z = -32, rotY = 180, collide = false, group = "Ambience", id = "AC", replaces = {  }, note = "B3b (wall plane measured in Studio)" },
	{ asset = "AST-034_ACUnit", x = -118, y = 12, z = -32, rotY = 180, collide = false, group = "Ambience", id = "AC", replaces = {  }, note = "B3c (wall plane measured in Studio)" },
	{ asset = "AST-034_ACUnit", x = -57.472, y = 12, z = -34.8, rotY = 180, collide = false, group = "Ambience", id = "AC", replaces = {  }, note = "B2b (wall plane measured in Studio)" },
	{ asset = "AST-034_ACUnit", x = 106, y = 12, z = -32, rotY = 180, collide = false, group = "Ambience", id = "AC", replaces = {  }, note = "B4 (wall plane measured in Studio)" },
	{ asset = "AST-034_ACUnit", x = 124, y = 9.5, z = -32, rotY = 180, collide = false, group = "Ambience", id = "AC", replaces = {  }, note = "B4 (wall plane measured in Studio)" },
	{ asset = "AST-034_ACUnit", x = 68, y = 12, z = 32, rotY = 0, collide = false, group = "Ambience", id = "AC", replaces = {  }, note = "B1 (wall plane measured in Studio)" },
	{ asset = "AST-034_ACUnit", x = 92, y = 9.5, z = 32, rotY = 0, collide = false, group = "Ambience", id = "AC", replaces = {  }, note = "B1 (wall plane measured in Studio)" },
	{ asset = "AST-034_ACUnit", x = 110, y = 12, z = 32, rotY = 0, collide = false, group = "Ambience", id = "AC", replaces = {  }, note = "B1 (wall plane measured in Studio)" },
	{ asset = "AST-034_ACUnit", x = 64, y = 12, z = 58, rotY = 90, collide = false, group = "Ambience", id = "AC", replaces = {  }, note = "B1 west face, above D1 (wall plane measured in Studio)" },
	{ asset = "AST-034_ACUnit", x = -48, y = 12, z = 56, rotY = 0, collide = false, group = "Ambience", id = "AC", replaces = {  }, note = "B5 (wall plane measured in Studio)" },
	{ asset = "AST-034_ACUnit", x = 24, y = 12, z = -70, rotY = 90, collide = false, group = "Ambience", id = "AC", replaces = {  }, note = "bank rear (wall plane measured in Studio)" },
	{ asset = "AST-034_Clothesline", x = -68.7, y = 13, z = -40, rotY = 0, parts = { ["Clothesline"] = { 0, 0, 0, size = { 6.8, 0.2, 2.13 } } }, collide = false, group = "Ambience", id = "LINE", replaces = {  }, note = "gap B3a / B2b" },
	{ asset = "AST-034_Clothesline", x = 116.6, y = 12, z = 58, rotY = 90, parts = { ["Clothesline"] = { 0, 0, 0, size = { 7, 0.2, 2.13 } } }, collide = false, group = "Ambience", id = "LINE", replaces = {  }, note = "EX-E alley" },
	{ asset = "AST-034_Clothesline", x = 116.6, y = 13.5, z = 72, rotY = 90, parts = { ["Clothesline"] = { 0, 0, 0, size = { 7, 0.2, 2.13 } } }, collide = false, group = "Ambience", id = "LINE", replaces = {  }, note = "EX-E alley" },
	-- captured from Studio 2026-10-11 (user additions)
	{ asset = "AST-028_SignName", x = -59.119, y = 9.925, z = 47.542, rotY = -90, group = "Mart", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	-- removed by the user in Studio 2026-10-11: { asset = "AST-030_FridgeDisplay", x = -67.6, y = 0.4, z = 62.75, rotY = 180, group = "MartInterior", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-028_MartAwning", x = -59.916, y = 6.065, z = 56.042, rotY = -90, parts = { ["AST-028_MartAwning"] = { 0, 1.913, -0.585, rotX = -17 } }, group = "Mart", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-028_MartAwning", x = -59.916, y = 6.065, z = 48.042, rotY = -90, parts = { ["AST-028_MartAwning"] = { 0, 1.913, -0.585, rotX = -17 } }, group = "Mart", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-028_MartAwning", x = -59.916, y = 6.065, z = 40.042, rotY = -90, parts = { ["AST-028_MartAwning"] = { 0, 1.913, -0.585, rotX = -17 } }, group = "Mart", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	-- captured from Studio 2026-10-11 (user additions)
	{ asset = "AST-034_ParkBench", x = 44, y = 0.45, z = 62.12, rotY = 0, group = "StreetFurniture", id = "L3", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	-- captured from Studio 2026-10-11 (user additions)
	{ asset = "AST-036_LampHead", x = -104, y = 0.4, z = -17.905, rotY = 0, group = "StreetLights", id = "Post_NinthN_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = -131.6, y = 0.4, z = -17.905, rotY = 0, group = "StreetLights", id = "Post_NinthN_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = -43.7, y = 0.4, z = -17.905, rotY = 0, group = "StreetLights", id = "Post_NinthN_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = -12.342, y = 0.3, z = 47.743, rotY = 90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = -12.342, y = 0.3, z = 76.843, rotY = 90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = -12.342, y = 0.3, z = 107.243, rotY = 90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 12.542, y = 0.3, z = 47.743, rotY = -90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 12.542, y = 0.3, z = 78.143, rotY = -90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 12.542, y = 0.3, z = 107.243, rotY = -90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 12.742, y = 0.3, z = -71.957, rotY = -90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 12.742, y = 0.3, z = -40.157, rotY = -90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 36.399, y = 0.3, z = -19.699, rotY = 0, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 36.399, y = 0.3, z = 19.685, rotY = 180, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 62.199, y = 0.3, z = 19.685, rotY = 180, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 107.799, y = 0.3, z = 19.685, rotY = 180, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = 131.399, y = 0.3, z = 19.685, rotY = 180, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = -12.642, y = 0.4, z = 23.843, rotY = 90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = -10.562, y = 0.3, z = 47.743, rotY = 90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = -10.562, y = 0.3, z = 76.843, rotY = 90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = -10.562, y = 0.3, z = 107.243, rotY = 90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = 10.762, y = 0.3, z = 47.743, rotY = -90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = 10.762, y = 0.3, z = 78.143, rotY = -90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = 10.762, y = 0.3, z = 107.243, rotY = -90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = 10.962, y = 0.3, z = -71.957, rotY = -90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = 10.962, y = 0.3, z = -40.157, rotY = -90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = 36.399, y = 0.3, z = -17.919, rotY = 0, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = 36.399, y = 0.3, z = 17.905, rotY = 180, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = 62.199, y = 0.3, z = 17.905, rotY = 180, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = 107.799, y = 0.3, z = 17.905, rotY = 180, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = 131.399, y = 0.3, z = 17.905, rotY = 180, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_LampHead", x = -10.862, y = 0.4, z = 23.843, rotY = 90, group = "StreetLights", id = "Post_NinthS_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = -104, y = 0.4, z = -19.685, rotY = 0, group = "StreetLights", id = "Post_NinthN_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = -131.6, y = 0.4, z = -19.685, rotY = 0, group = "StreetLights", id = "Post_NinthN_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-036_StreetLightCurved", x = -43.7, y = 0.4, z = -19.685, rotY = 0, group = "StreetLights", id = "Post_NinthN_W1", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	-- captured from Studio 2026-10-11 (user additions)
	{ asset = "AST-103_RollerShutterTriple", x = -93.7, y = 0.4, z = 47.887, rotY = -90, group = "Mart", id = "GEAR_STAND", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-104_GearStand", x = -96.625, y = 0.4, z = 47.887, rotY = -90, parts = { ["Structure"] = { 0, 5.69, 0.15, size = { 25.9, 11.38, 7.25 } } }, group = "Mart", id = "GEAR_STAND", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-105_PedestalS1", x = -95.5, y = 0.4, z = 37.887, rotY = -90, group = "Mart", id = "GEAR_STAND", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-106_SignSaucesSnacks", x = -83.6, y = 8.8, z = 61.085, rotY = 0, group = "MartInterior", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-106_SignMeatDeli", x = -77.7, y = 8.3, z = 48.587, rotY = 0, group = "MartInterior", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-050_BunDisplay", x = -76.1, y = 0.4, z = 33.587, rotY = 0, group = "MartInterior", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-106_WallSignDairy", x = -69.7, y = 8.2, z = 63.687, rotY = 0, group = "MartInterior", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-106_SignBakery", x = -76.1, y = 7.8, z = 33.887, rotY = 180, group = "MartInterior", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-107_MeatCase", x = -74.5, y = 0.4, z = 48.587, rotY = 0, group = "MartInterior", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-107_MeatCase", x = -81.3, y = 0.4, z = 48.587, rotY = 180, group = "MartInterior", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-105_Pedestal", x = -95.5, y = 0.4, z = 57.887, rotY = -90, group = "Mart", id = "GEAR_STAND", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-105_Pedestal", x = -95.5, y = 0.4, z = 54.887, rotY = -90, group = "Mart", id = "GEAR_STAND", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-105_Pedestal", x = -95.5, y = 0.4, z = 51.887, rotY = -90, group = "Mart", id = "GEAR_STAND", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-105_Pedestal", x = -95.5, y = 0.4, z = 43.887, rotY = -90, group = "Mart", id = "GEAR_STAND", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-105_Pedestal", x = -95.5, y = 0.4, z = 40.887, rotY = -90, group = "Mart", id = "GEAR_STAND", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-106_SignProduce", x = -83.9, y = 7.8, z = 33.887, rotY = 180, group = "MartInterior", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	-- captured from Studio 2026-10-11 (user additions)
	{ asset = "AST-029_GondolaBoxesBare", x = -90.05, y = 0.4, z = 62.837, rotY = 0, group = "MartInterior", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-029_GondolaBoxesBare", x = -81.05, y = 0.4, z = 62.837, rotY = 0, group = "MartInterior", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	{ asset = "AST-029_GondolaBoxesBare", x = -85.55, y = 0.4, z = 62.837, rotY = 0, group = "MartInterior", id = "MKT", replaces = {  }, note = "user 2026-10-11: added in Studio (captured)" },
	-- 2026-10-12: the 4 TRAILER picnic tables (FEAT-037, UPG-011): the owner put them by hand in Studio (loose in the Workspace root,
	-- SeatTable / TableGroup "Trailer" / TableIndex 6..9). Recorded here so a Place.run recreates them; the tag, TableIndex and the
	-- Seat1..4 parts are NOT in the placement: run tools/assetplace/trailer_tables.luau after bind_map01 (see tools/assetplace/STUDIO_LAYER.md).
	{ asset = "AST-100_PicnicTable", x = 47.9, y = 0.4, z = 54.587, rotY = 0, group = "TrailerTables", id = "TTBL-6", replaces = {  }, note = "owner 2026-10-12: trailer table TableIndex 6 moved to the Pad (same spot as Pad table 1, world -47.9, 13.3; they vanish when the trailer arrives)" },
	{ asset = "AST-100_PicnicTable", x = 56.5, y = 0.4, z = 54.587, rotY = 0, group = "TrailerTables", id = "TTBL-7", replaces = {  }, note = "owner 2026-10-12: trailer table TableIndex 7 moved to the Pad (same spot as Pad table 2, world -56.5, 13.3; they vanish when the trailer arrives)" },
	{ asset = "AST-100_PicnicTable", x = 38.9, y = 0.4, z = 54.587, rotY = 0, group = "TrailerTables", id = "TTBL-8", replaces = {  }, note = "owner 2026-10-12: trailer table TableIndex 8 moved to the Pad (same spot as Pad table 3, world -38.9, 13.3; they vanish when the trailer arrives)" },
	{ asset = "AST-100_PicnicTable", x = 29.6, y = 0.4, z = 54.587, rotY = 0, group = "TrailerTables", id = "TTBL-9", replaces = {  }, note = "owner 2026-10-12: trailer table TableIndex 9 moved to the Pad (same spot as Pad table 4, world -29.6, 13.3; they vanish when the trailer arrives)" },
}
