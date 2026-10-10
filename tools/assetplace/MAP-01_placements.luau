--[[
	MAP-01 "Ninth & Juniper" - placement table of the real assets (technical prototype, Phase 0).
	DATA ONLY. Status: Rascunho (level-designer, 2026-10-10). Not gameplay code.

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
	- x, z: MAP-01 world coords (origin = Juniper centre on the Ninth axis, +X east, +Z south).
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
	   Mount_Trash exactly on BIN-C (56, 42), Hide_1..4 exactly on H1..H4. So the asset LookVector
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
	     Trailer bench / Hide cabinets are KP pack pieces (front -Z): bench 0, Hide 180.
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
	- Ninth Avenue (32 wide), the intersection box (24 x 32), BackStreet (16), Ninth sidewalks (16)
	  and the Juniper sidewalk strip Z -136..-128 (8): no 24-stud tile fits. Ninth stays blockout;
	  the far strip becomes a gap at ground level (Z-13, beyond BAR-N, in the fog).
	- Kenney crossing tile not used for CW-1: its stripes are centred on the tile (~7.6 wide) and
	  CW-1 (Z 34..42) would need a tile at Z 26..50, leaving a 10-stud hole at Z 16..26. CW-1..4,
	  SL lines and the yellow centre lines stay as blockout paint (the tiles also carry a thin
	  white centre line; recolour is the art-director's call).
	- Pad floor, plaza, parking lot, red curb, stall lines, parking fence, plaza tables: no asset.
	- Fill_* boxes (background masses): stay until BG cards (AST-033 BG_Card) exist.
	- TRUCK (AST-048, no new model). Ambulance + stretcher (AST-052) and long car (AST-065):
	  dynamic actors, not static scenery.
	- Marquee "OPEN 24 HOURS", SS marking, C-01 clock + hands, WV-1..3, BankSign, BankDoor,
	  Door_D1, Door_SP-B, the three "NO HELP WANTED" windows, PARE-N / PARE-S (CR stop sign is
	  excluded in asset-sourcing), CoffeeRack, ProduceSign, Opal OP-1: no asset yet or they are
	  ID anchors; they overlay the new facades like decals.
	- P-01 flyer (AST-037): not in this pass. The blockout flyer sits 0.36 from the pole axis, the
	  new pole has radius 0.52 -> the flyer ends up INSIDE the pole (move to ~0.56 when swapped).
	- Mount_Counter (cart and trailer): no asset fits (AST-019 counter is 3.5 tall, the mount is at
	  counter-top height). Cart Mount_Sign is the skirt decal (AST-072), not the OPEN sign.
	- Bottles AST-004/005 on the holder (Att_Bottle_*): editing in progress, runtime.
	- Upgrade states (CoolerL2/L3, Rail_8, Lock, grill levels) and AST-043 tarp: runtime / not modelled.
	- AST-050_BunDisplay: MAP-01 §7.4 has no slot for it (buns are bought at the gondola, Q-135).
	- Not used: AST-034_Cone (same role as AST-047_ConstructionCone), AST-036_StreetLightSquare,
	  AST-047_WorkLight.

	==============================================================================================
	CONFLICTS / OPEN POINTS FOUND (for the user and the art-director)
	==============================================================================================
	- AST-045_ApartmentBlock is 22.57 tall; MAP-01 lot is ~30 (bank ~18 + WV-1..3 at 19..28).
	  The blockout WV glass will float up to 4.4 above the roof. Needs Y scale ~1.33 or new WV.
	- Void behind the bank (X 24..52, Z -64..-50) visible from the Juniper Norte east sidewalk;
	  void inside the B1 block (X 81..113, Z 50..88) visible from the EX-E alley; 6.6 gap between
	  B3a and B2b (X -72..-65.4, tree T-03 in front of it).
	- AST-024 OPEN sign is 4 tall; DEC-048 / MAP-01 §5.1 ask <= 3. SIGN-T needs 4 x 5 (asset 2 x 4).
	- AST-030 fridge is 7 tall and one-sided; MAP-01 asks low fridges, and Bacon (-81, 44) is bought
	  at the back of the north fridge.
	- Cart phone (on the Parasol_E pole, Mount_Phone) intersects the sauce holder (~0.8 stud).
	- AST-028_MartAwning still has its legs (edition pending in AST-028); side not confirmed.
	- AST-031 checkout side not confirmed (detail side -Z put towards Opal).
	- Rail: the FBX has Rail_6 and Rail_8 on top of each other; Rail_6 used.
	- Barriers moved 0.8 towards the play area (Z -74.0 / 78.0) so they do not cut the cones.
]]

return {
	---------------------------------------------------------------------------------------------
	-- 1. ROADS (Juniper only; road tiles rotY 90 = carriageway along Z) and SIDEWALKS
	---------------------------------------------------------------------------------------------
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -28, rotY = 90, group = "Roads", id = "Z-07", replaces = { "Roads/Juniper_North" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -52, rotY = 90, group = "Roads", id = "Z-07", replaces = { "Roads/Juniper_North" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -76, rotY = 90, group = "Roads", id = "Z-07", replaces = { "Roads/Juniper_North" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -100, rotY = 90, group = "Roads", id = "Z-13", replaces = { "Roads/Juniper_North" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = -124, rotY = 90, group = "Roads", id = "Z-13", replaces = { "Roads/Juniper_North" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 28, rotY = 90, group = "Roads", id = "Z-08", replaces = { "Roads/Juniper_South" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 52, rotY = 90, group = "Roads", id = "Z-08", replaces = { "Roads/Juniper_South" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 76, rotY = 90, group = "Roads", id = "Z-08", replaces = { "Roads/Juniper_South" } },
	{ asset = "AST-032_RoadStraight", x = 0, y = -0.24, z = 100, rotY = 90, group = "Roads", id = "Z-08", replaces = { "Roads/Juniper_South" } },
	{ asset = "AST-032_RoadStraightHalf", x = 0, y = -0.24, z = 118, rotY = 90, group = "Roads", id = "Z-08", replaces = { "Roads/Juniper_South" }, note = "covers Z 112..124 (blockout road ended at 120; out of view after the curve)" },

	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = -44, rotY = 0, group = "Sidewalks", id = "Z-07", replaces = { "Sidewalks/JuniperNorth_W" } },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = -68, rotY = 0, group = "Sidewalks", id = "Z-07", replaces = { "Sidewalks/JuniperNorth_W" } },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = -92, rotY = 0, group = "Sidewalks", id = "Z-13", replaces = { "Sidewalks/JuniperNorth_W" } },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = -116, rotY = 0, group = "Sidewalks", id = "Z-13", replaces = { "Sidewalks/JuniperNorth_W" }, note = "Z -136..-128 left as a gap" },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = -44, rotY = 0, group = "Sidewalks", id = "Z-07", replaces = { "Sidewalks/JuniperNorth_E" } },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = -68, rotY = 0, group = "Sidewalks", id = "Z-07", replaces = { "Sidewalks/JuniperNorth_E" } },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = -92, rotY = 0, group = "Sidewalks", id = "Z-13", replaces = { "Sidewalks/JuniperNorth_E" } },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = -116, rotY = 0, group = "Sidewalks", id = "Z-13", replaces = { "Sidewalks/JuniperNorth_E" }, note = "Z -136..-128 left as a gap" },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = 44, rotY = 0, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_W" }, note = "west half hidden inside the plaza slab" },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = 68, rotY = 0, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_W" } },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = 92, rotY = 0, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_W" } },
	{ asset = "AST-032_SidewalkTile", x = -24, y = -0.24, z = 116, rotY = 0, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_W" } },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = 44, rotY = 0, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_E" }, note = "east half hidden inside the Pad slab" },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = 68, rotY = 0, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_E" } },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = 92, rotY = 0, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_E" } },
	{ asset = "AST-032_SidewalkTile", x = 24, y = -0.24, z = 116, rotY = 0, group = "Sidewalks", id = "Z-08", replaces = { "Sidewalks/JuniperSouth_E" } },

	---------------------------------------------------------------------------------------------
	-- 2a. CORNER CART (tier 1, day) + stations on its mounts. Pivot (41, 0.45, 37.5), rotY 180.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-026_CornerCart", x = 41, y = 0.45, z = 37.5, rotY = 0, group = "Cart", id = "CART", layer = "day", replaces = { "Pad/CART/Base", "Pad/CART/UmbrellaPole_1", "Pad/CART/UmbrellaPole_2", "Pad/CART/Umbrella_1", "Pad/CART/Umbrella_2" }, note = "queue side is local +Z; LookVector faces the operator (south)" },
	{ asset = "AST-018_CoolerL1", x = 29.5, y = 0.95, z = 37.66, rotY = 180, group = "Cart", id = "CART-S", layer = "day", replaces = { "Pad/CART/1_S_Stock" }, note = "Mount_StockSausage (low, inside the cart body)" },
	{ asset = "AST-012_RollerGrill", x = 33.5, y = 3.95, z = 37.5, rotY = 180, group = "Cart", id = "CART-G", layer = "day", replaces = { "Pad/CART/2_G_Grill", "Pad/CART/GrillPlate" } },
	{ asset = "AST-013_RestRail", part = { "Rail_6" }, x = 37.5, y = 3.95, z = 37.5, rotY = 180, group = "Cart", id = "CART-R", layer = "day", replaces = { "Pad/CART/3_R_Rest" }, note = "low end + Prompt_Rail towards the operator" },
	{ asset = "AST-015_BunCrate", x = 40, y = 3.95, z = 37.5, rotY = 180, group = "Cart", id = "CART-B", layer = "day", replaces = { "Pad/CART/4_B_Bun" } },
	{ asset = "AST-014_CuttingBoard", x = 42.5, y = 3.95, z = 37.5, rotY = 180, group = "Cart", id = "CART-T", layer = "day", replaces = { "Pad/CART/5_T_Board" }, note = "knife edge towards the operator" },
	{ asset = "AST-017_ToppingGrid", x = 47, y = 3.95, z = 37.5, rotY = 0, group = "Cart", id = "CART-K", layer = "day", replaces = { "Pad/CART/6_K_Toppings", "Pad/CART/Lid_Ketchup", "Pad/CART/Lid_Mustard", "Pad/CART/Lid_Cheese", "Pad/CART/Lid_Bacon", "Pad/CART/Lid_PotatoSticks", "Pad/CART/Lid_CreamCheese" }, note = "rotY 180: front row F (Ketchup X45, Mustard X47, Cheese X49) on the queue side, as MAP-01 7.1" },
	{ asset = "AST-016_SauceHolder", x = 46, y = 4.10, z = 36.75, rotY = 0, group = "Cart", id = "CART-K-SAUCE", layer = "day", replaces = {}, note = "sits on grid cells F1 (Ketchup, X45) + F2 (Mustard, X47); bottles go on Att_Bottle_* at runtime" },
	{ asset = "AST-020_CashRegister", x = 52, y = 3.95, z = 37.5, rotY = 0, group = "Cart", id = "DRAWER", layer = "day", replaces = { "Pad/CART/7_H_Delivery", "Pad/CART/DRAWER" }, note = "delivery stand X 50..52, drawer X 52.4..54; keep the DRAWER tag visible" },
	{ asset = "AST-042_VehiclePhone", part = { "Phone_Cart", "Cart_Body", "Cart_Cord", "Cart_Handset", "Cart_Lamp", "Lid" }, x = 47.5, y = 4.65, z = 36.84, rotY = 180, group = "Cart", id = "CART-PHONE", layer = "day", replaces = {}, note = "Att_Mount on Mount_Phone (Parasol_E pole); intersects the sauce holder ~0.8" },
	{ asset = "AST-025_Trashcan", x = 56, y = 0.45, z = 42, rotY = 90, group = "Cart", id = "BIN-C", layer = "day", replaces = { "Pad/BIN-C" }, note = "Mount_Trash rotY 90 would point the pedal east; 270 = pedal to the corridor" },

	---------------------------------------------------------------------------------------------
	-- 2b. OPEN LATE TRAILER on the Pad (night) + interior. Pivot (40, 0.45, 41), rotY 180.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-027_OpenLateTrailer", x = 40, y = 0.45, z = 41, rotY = 0, group = "Trailer", id = "TRL", layer = "night", replaces = { "Pad/TRL", "Pad/TRL_Hitch" }, note = "window/awning north (queue), back door X 47..51 south, hitch to X 21.5; floor at Y 2.45" },
	{ asset = "AST-018_CoolerL1", x = 28.5, y = 5.95, z = 37.5, rotY = 180, group = "Trailer", id = "TRL-S", layer = "night", replaces = {}, note = "cooler level carries over from the cart (Q-075)" },
	{ asset = "AST-012_RollerGrill", x = 33, y = 5.95, z = 37.5, rotY = 180, group = "Trailer", id = "TRL-G", layer = "night", replaces = {} },
	{ asset = "AST-013_RestRail", part = { "Rail_6" }, x = 37.5, y = 5.95, z = 37.5, rotY = 180, group = "Trailer", id = "TRL-R", layer = "night", replaces = {} },
	{ asset = "AST-015_BunCrate", x = 40, y = 5.95, z = 37.5, rotY = 180, group = "Trailer", id = "TRL-B", layer = "night", replaces = {} },
	{ asset = "AST-014_CuttingBoard", x = 42.5, y = 5.95, z = 37.5, rotY = 180, group = "Trailer", id = "TRL-T", layer = "night", replaces = {} },
	{ asset = "AST-017_ToppingGrid", x = 47, y = 5.95, z = 37.5, rotY = 0, group = "Trailer", id = "TRL-K", layer = "night", replaces = {} },
	{ asset = "AST-016_SauceHolder", x = 46, y = 6.10, z = 36.75, rotY = 0, group = "Trailer", id = "TRL-K-SAUCE", layer = "night", replaces = {} },
	{ asset = "AST-020_CashRegister", x = 52, y = 5.95, z = 37, rotY = 0, group = "Trailer", id = "TRL-DRAWER", layer = "night", replaces = {} },
	{ asset = "AST-042_VehiclePhone", part = { "Phone_Trailer", "Trailer_Cord", "Trailer_Handset", "Trailer_Lamp" }, x = 30.7, y = 7.72, z = 36.28, rotY = 180, group = "Trailer", id = "TRL-PHONE", layer = "night", replaces = {}, note = "trailer variant sits 2.2 off the FBX origin; its back lands on Mount_Phone (28.5, 8.45, 36), front wall" },
	{ asset = "AST-022_CoffeeMachine", x = 40, y = 5.95, z = 44, rotY = 0, group = "Trailer", id = "TRL-COFFEE", layer = "night", replaces = {} },
	{ asset = "AST-025_Trashcan", x = 43.5, y = 2.45, z = 44, rotY = 0, group = "Trailer", id = "TRL-BIN", layer = "night", replaces = {} },
	{ asset = "AST-039_LightSwitch", x = 46, y = 6.45, z = 46, rotY = 0, group = "Trailer", id = "TRL-SWITCH", layer = "night", replaces = {}, note = "back plate on the south wall (Z 46), lever to the north" },
	{ asset = "AST-040_TrailerBench", x = 28.5, y = 2.45, z = 44.5, rotY = 0, group = "Trailer", id = "TRL-BENCH-1", layer = "night", replaces = {} },
	{ asset = "AST-040_TrailerBench", x = 31.5, y = 2.45, z = 44.5, rotY = 0, group = "Trailer", id = "TRL-BENCH-2", layer = "night", replaces = {} },
	{ asset = "AST-040_TrailerBench", x = 34.5, y = 2.45, z = 44.5, rotY = 0, group = "Trailer", id = "TRL-BENCH-3", layer = "night", replaces = {} },
	{ asset = "AST-041_HideCabinet", x = 31, y = 2.45, z = 38.3, rotY = 180, group = "Trailer", id = "H1", layer = "night", replaces = {}, note = "door face 0.1 proud of the counter front (Z 39), facing the corridor" },
	{ asset = "AST-041_HideCabinet", x = 37, y = 2.45, z = 38.3, rotY = 180, group = "Trailer", id = "H2", layer = "night", replaces = {} },
	{ asset = "AST-041_HideCabinet", x = 43, y = 2.45, z = 38.3, rotY = 180, group = "Trailer", id = "H3", layer = "night", replaces = {} },
	{ asset = "AST-041_HideCabinet", x = 49, y = 2.45, z = 38.3, rotY = 180, group = "Trailer", id = "H4", layer = "night", replaces = {} },
	{ asset = "AST-023_TrailerLights", part = { "Lights_Mast", "Lights_Mast_Lamps" }, x = 40, y = 11.45, z = 41, rotY = 0, group = "Trailer", id = "TRL-LIGHTS", layer = "night", replaces = {}, note = "UPG-005: only after purchase; Mount_Lights on the roof" },
	{ asset = "AST-023_TrailerLights", part = { "Lights_String", "Lights_String_Bulbs" }, x = 41.25, y = 11.05, z = 34.9, rotY = 0, group = "Trailer", id = "TRL-LIGHTS", layer = "night", replaces = {}, note = "UPG-005; Mount_LightsString over the window. Same FBX placed twice (mast / string share the origin)" },

	---------------------------------------------------------------------------------------------
	-- 2c. SALE TRAILER, signs, queue marks
	---------------------------------------------------------------------------------------------
	{ asset = "AST-027_OpenLateTrailer", x = 78, y = 0.02, z = -58, rotY = 180, group = "Trailer", id = "TRL-SALE", replaces = { "Trailer/TRL-SALE" }, note = "window faces south (Pad); hitch east, like the blockout" },
	{ asset = "AST-024_SignStand", x = 78, y = 0.02, z = -40, rotY = 180, group = "Pad", id = "SIGN-T", replaces = { "Trailer/SIGN-T" }, note = "MAP asks 4 x 5; asset is 2 x 4 (scale or variant)" },
	{ asset = "AST-024_SignStand", x = 25, y = 0.45, z = 35, rotY = 0, group = "Pad", id = "OPEN", replaces = { "Pad/OPEN" }, note = "4 tall vs <= 3 (DEC-048 sight band). Trailer has Mount_Sign at (27.5, 0.45, 33) as alternative" },
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
	{ asset = "AST-036_StreetLightCurved", x = -14.185, y = 0.4, z = -24, rotY = 90, group = "StreetLights", id = "JL-01", replaces = { "StreetLights/JL-01/Pole", "StreetLights/JL-01/Arm" } },
	{ asset = "AST-036_LampHead", x = -12.405, y = 0.4, z = -24, rotY = 90, group = "StreetLights", id = "JL-01", replaces = { "StreetLights/JL-01/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -14.185, y = 0.24, z = -32, rotY = 90, group = "StreetLights", id = "JL-02", replaces = { "StreetLights/JL-02/Pole", "StreetLights/JL-02/Arm" } },
	{ asset = "AST-036_LampHead", x = -12.405, y = 0.24, z = -32, rotY = 90, group = "StreetLights", id = "JL-02", replaces = { "StreetLights/JL-02/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -14.185, y = 0.24, z = -40, rotY = 90, group = "StreetLights", id = "JL-03", replaces = { "StreetLights/JL-03/Pole", "StreetLights/JL-03/Arm" } },
	{ asset = "AST-036_LampHead", x = -12.405, y = 0.24, z = -40, rotY = 90, group = "StreetLights", id = "JL-03", replaces = { "StreetLights/JL-03/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -14.185, y = 0.24, z = -48, rotY = 90, group = "StreetLights", id = "JL-04", replaces = { "StreetLights/JL-04/Pole", "StreetLights/JL-04/Arm" } },
	{ asset = "AST-036_LampHead", x = -12.405, y = 0.24, z = -48, rotY = 90, group = "StreetLights", id = "JL-04", replaces = { "StreetLights/JL-04/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -14.185, y = 0.24, z = -56, rotY = 90, group = "StreetLights", id = "JL-05", replaces = { "StreetLights/JL-05/Pole", "StreetLights/JL-05/Arm" } },
	{ asset = "AST-036_LampHead", x = -12.405, y = 0.24, z = -56, rotY = 90, group = "StreetLights", id = "JL-05", replaces = { "StreetLights/JL-05/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -14.185, y = 0.24, z = -64, rotY = 90, group = "StreetLights", id = "JL-06", replaces = { "StreetLights/JL-06/Pole", "StreetLights/JL-06/Arm" } },
	{ asset = "AST-036_LampHead", x = -12.405, y = 0.24, z = -64, rotY = 90, group = "StreetLights", id = "JL-06", replaces = { "StreetLights/JL-06/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -14.185, y = 0.24, z = -72, rotY = 90, group = "StreetLights", id = "JL-07", replaces = { "StreetLights/JL-07/Pole", "StreetLights/JL-07/Arm" } },
	{ asset = "AST-036_LampHead", x = -12.405, y = 0.24, z = -72, rotY = 90, group = "StreetLights", id = "JL-07", replaces = { "StreetLights/JL-07/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -14.185, y = 0.24, z = -80, rotY = 90, group = "StreetLights", id = "JL-08", replaces = { "StreetLights/JL-08/Pole", "StreetLights/JL-08/Arm" } },
	{ asset = "AST-036_LampHead", x = -12.405, y = 0.24, z = -80, rotY = 90, group = "StreetLights", id = "JL-08", replaces = { "StreetLights/JL-08/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -14.185, y = 0.24, z = -88, rotY = 90, group = "StreetLights", id = "JL-09", replaces = { "StreetLights/JL-09/Pole", "StreetLights/JL-09/Arm" } },
	{ asset = "AST-036_LampHead", x = -12.405, y = 0.24, z = -88, rotY = 90, group = "StreetLights", id = "JL-09", replaces = { "StreetLights/JL-09/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = 18.717, y = 0.4, z = 18.717, rotY = 225, group = "StreetLights", id = "P-01", replaces = { "StreetLights/P-01/Pole", "StreetLights/P-01/Arm" }, note = "foot (20, 20), arm to the NW over the intersection; flyer must move out to r ~0.56" },
	{ asset = "AST-036_LampHead", x = 17.459, y = 0.4, z = 17.459, rotY = 225, group = "StreetLights", id = "P-01", replaces = { "StreetLights/P-01/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -40, y = 0.4, z = 16.185, rotY = 180, group = "StreetLights", id = "Post_NinthS_W1", replaces = { "StreetLights/Post_NinthS_W1/Pole", "StreetLights/Post_NinthS_W1/Arm" } },
	{ asset = "AST-036_LampHead", x = -40, y = 0.4, z = 14.405, rotY = 180, group = "StreetLights", id = "Post_NinthS_W1", replaces = { "StreetLights/Post_NinthS_W1/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -90, y = 0.4, z = 16.185, rotY = 180, group = "StreetLights", id = "Post_NinthS_W2", replaces = { "StreetLights/Post_NinthS_W2/Pole", "StreetLights/Post_NinthS_W2/Arm" } },
	{ asset = "AST-036_LampHead", x = -90, y = 0.4, z = 14.405, rotY = 180, group = "StreetLights", id = "Post_NinthS_W2", replaces = { "StreetLights/Post_NinthS_W2/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = -76, y = 0.4, z = -16.185, rotY = 0, group = "StreetLights", id = "Post_NinthN_W1", replaces = { "StreetLights/Post_NinthN_W1/Pole", "StreetLights/Post_NinthN_W1/Arm" } },
	{ asset = "AST-036_LampHead", x = -76, y = 0.4, z = -14.405, rotY = 0, group = "StreetLights", id = "Post_NinthN_W1", replaces = { "StreetLights/Post_NinthN_W1/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = 108, y = 0.4, z = -16.185, rotY = 0, group = "StreetLights", id = "Post_NinthN_E1", replaces = { "StreetLights/Post_NinthN_E1/Pole", "StreetLights/Post_NinthN_E1/Arm" } },
	{ asset = "AST-036_LampHead", x = 108, y = 0.4, z = -14.405, rotY = 0, group = "StreetLights", id = "Post_NinthN_E1", replaces = { "StreetLights/Post_NinthN_E1/Lamp" } },
	{ asset = "AST-036_StreetLightCurved", x = 84, y = 0.4, z = 16.185, rotY = 180, group = "StreetLights", id = "Post_L2", replaces = { "StreetLights/Post_L2/Pole", "StreetLights/Post_L2/Arm" }, note = "L2 lurk post" },
	{ asset = "AST-036_LampHead", x = 84, y = 0.4, z = 14.405, rotY = 180, group = "StreetLights", id = "Post_L2", replaces = { "StreetLights/Post_L2/Lamp" } },

	---------------------------------------------------------------------------------------------
	-- 4. BUILDINGS (pivot y 0). Front (+Z) on the lot line: rotY 0 = faces south, 180 = north,
	--    90 = east, 270 = west. A = BuildingA (16.4 x 17.45 deep), H = BuildingH (16.4 x 18.71).
	---------------------------------------------------------------------------------------------
	-- North of the Ninth, facades on Z -32
	{ asset = "AST-033_BuildingA", x = -80.2, y = 0, z = -40.725, rotY = 0, group = "Buildings", id = "B3", replaces = { "Buildings/B3" }, note = "B3a, X -88.4..-72" },
	{ asset = "AST-033_BuildingH", x = -96.6, y = 0, z = -41.355, rotY = 0, group = "Buildings", id = "B3", replaces = { "Buildings/B3" }, note = "B3b, behind the NO HELP WANTED window X -92" },
	{ asset = "AST-033_BuildingA", x = -113.0, y = 0, z = -40.725, rotY = 0, group = "Buildings", id = "B3", replaces = { "Buildings/B3" }, note = "B3c" },
	{ asset = "AST-033_BuildingH", x = -129.4, y = 0, z = -41.355, rotY = 0, group = "Buildings", id = "B3", replaces = { "Buildings/B3" }, note = "B3d, ends at X -137.6" },
	{ asset = "AST-033_BuildingH", x = -57.2, y = 0, z = -41.355, rotY = 0, group = "Buildings", id = "B2", replaces = { "Buildings/B2/Block" }, note = "B2b annex west of the laundry, behind window X -56; gap X -72..-65.4 to B3a" },
	{ asset = "AST-046_Laundry", x = -37.0, y = 0, z = -39.34, rotY = 0, group = "Buildings", id = "B2", replaces = { "Buildings/B2/Block", "Buildings/B2/Awning" }, note = "Z-10; mesh door ~X -40 = SP-B; Door_SP-B and window X -32 stay" },
	{ asset = "AST-033_BuildingA", x = -32.725, y = 0, z = -55.8, rotY = 90, group = "Buildings", id = "B2", replaces = { "Buildings/B2/Block" }, note = "B2c faces the Juniper (east), Z -64..-47.6: closes the lot seen from the trailer window" },
	{ asset = "AST-045_ApartmentBlock", x = 38, y = 0, z = -41, rotY = 180, group = "Buildings", id = "Z-11", replaces = { "Buildings/BellmoorSavings/Bank_GroundFloor", "Buildings/BellmoorSavings/Apartments", "Buildings/BellmoorSavings/Cornice" }, note = "Bellmoor Savings + apartments; 22.57 tall vs ~30 (WV-1..3 float); C-01, WV, BankSign, BankDoor stay" },
	{ asset = "AST-044_Column", x = 25.5, y = 0.4, z = -33, rotY = 0, group = "Buildings", id = "Z-11", replaces = {}, note = "bank portico, optional" },
	{ asset = "AST-044_Column", x = 35.5, y = 0.4, z = -33, rotY = 0, group = "Buildings", id = "Z-11", replaces = {} },
	{ asset = "AST-044_Column", x = 40.5, y = 0.4, z = -33, rotY = 0, group = "Buildings", id = "Z-11", replaces = {}, note = "C-01 clock (39, 14) sits between the two middle columns" },
	{ asset = "AST-044_Column", x = 50.5, y = 0.4, z = -33, rotY = 0, group = "Buildings", id = "Z-11", replaces = {} },
	{ asset = "AST-033_BuildingH", x = 112.2, y = 0, z = -41.355, rotY = 0, group = "Buildings", id = "B4", replaces = { "Buildings/B4" }, note = "Ninth front" },
	{ asset = "AST-033_BuildingA", x = 128.6, y = 0, z = -40.725, rotY = 0, group = "Buildings", id = "B4", replaces = { "Buildings/B4" } },
	{ asset = "AST-033_BuildingA", x = 112.725, y = 0, z = -58.91, rotY = 270, group = "Buildings", id = "B4", replaces = { "Buildings/B4" }, note = "faces the parking lot (west)" },
	{ asset = "AST-033_BuildingH", x = 113.355, y = 0, z = -75.31, rotY = 270, group = "Buildings", id = "B4", replaces = { "Buildings/B4" } },
	{ asset = "AST-033_BuildingA", x = 112.725, y = 0, z = -91.71, rotY = 270, group = "Buildings", id = "B4", replaces = { "Buildings/B4" } },
	{ asset = "AST-033_BuildingH", x = 113.355, y = 0, z = -108.11, rotY = 270, group = "Buildings", id = "B4", replaces = { "Buildings/B4" } },
	{ asset = "AST-033_BuildingA", x = 112.725, y = 0, z = -124.51, rotY = 270, group = "Buildings", id = "B4", replaces = { "Buildings/B4" } },
	-- South of the Ninth: B1 behind the Pad (Door_D1 part stays at X 64, Z 46..50)
	{ asset = "AST-033_BuildingA", x = 72.2, y = 0, z = 40.725, rotY = 180, group = "Buildings", id = "B1", replaces = { "Buildings/B1/Block_East" }, note = "corner, Ninth front; its west side wall (X 64) carries Door_D1" },
	{ asset = "AST-033_BuildingH", x = 88.6, y = 0, z = 41.355, rotY = 180, group = "Buildings", id = "B1", replaces = { "Buildings/B1/Block_East" } },
	{ asset = "AST-033_BuildingA", x = 105.0, y = 0, z = 40.725, rotY = 180, group = "Buildings", id = "B1", replaces = { "Buildings/B1/Block_East" }, note = "ends X 113.2: EX-E alley 6.8 wide" },
	{ asset = "AST-033_BuildingA", x = 72.725, y = 0, z = 57.65, rotY = 270, group = "Buildings", id = "B1", replaces = { "Buildings/B1/Block_East" }, note = "faces the Pad (west), Z 49.45..65.85" },
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
	{ asset = "AST-028_MartWall", x = -72, y = 0.4, z = 66.4, rotY = 0, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_S" } },
	{ asset = "AST-028_MartWall", x = -102.4, y = 0.4, z = 36, rotY = 270, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_W" }, note = "inside Fill_SW_West; GEAR WALL leans on it" },
	{ asset = "AST-028_MartWall", x = -102.4, y = 0.4, z = 44, rotY = 270, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_W" } },
	{ asset = "AST-028_MartWall", x = -102.4, y = 0.4, z = 52, rotY = 270, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_W" } },
	{ asset = "AST-028_MartWall", x = -102.4, y = 0.4, z = 60, rotY = 270, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/Wall_W" } },
	{ asset = "AST-028_MartAwning", x = -96, y = 5.9, z = 26.46, rotY = 180, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Awning" }, note = "plate top at 9.9; pack legs still on the mesh (edit pending); side to confirm" },
	{ asset = "AST-028_MartAwning", x = -88, y = 5.9, z = 26.46, rotY = 180, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Awning" } },
	{ asset = "AST-028_MartAwning", x = -80, y = 5.9, z = 26.46, rotY = 180, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Awning" } },
	{ asset = "AST-028_MartAwning", x = -72, y = 5.9, z = 26.46, rotY = 180, group = "Mart", id = "MKT", replaces = { "Mart/MKT_Shell/North_Awning" } },

	-- Interior (Mart floor top 0.4)
	{ asset = "AST-049_GearWall", x = -99, y = 0.4, z = 48, rotY = 270, group = "MartInterior", id = "GEAR_WALL", replaces = { "Mart/Interior/GEAR_WALL/Bench", "Mart/Interior/GEAR_WALL/BenchTopTrim", "Mart/Interior/GEAR_WALL/Panel", "Mart/Interior/GEAR_WALL/Title", "Mart/Interior/GEAR_WALL/S1_Vitrine" }, note = "Slot_B1 lands on Z 40.5, S1 on 46.5, B5 on 55.5 (= MAP-01 7.4); Title SurfaceGui still renders when hidden" },
	{ asset = "AST-031_MartCheckout", x = -75, y = 0.4, z = 35.5, rotY = 0, group = "MartInterior", id = "OP-1", replaces = { "Mart/Interior/CheckoutCounter" }, note = "6 wide (blockout 10); detail side (-Z) towards Opal, confirm" },
	{ asset = "AST-029_GondolaBoxes", x = -75.75, y = 0.4, z = 42, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaN_Shelf" } },
	{ asset = "AST-029_GondolaBags", x = -71.25, y = 0.4, z = 42, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaN_Shelf" } },
	{ asset = "AST-029_GondolaEnd", x = -66.75, y = 0.4, z = 42, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaN_Shelf" } },
	{ asset = "AST-029_GondolaBoxes", x = -75.75, y = 0.4, z = 50, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaS_Shelf" } },
	{ asset = "AST-029_GondolaBags", x = -71.25, y = 0.4, z = 50, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaS_Shelf" } },
	{ asset = "AST-029_GondolaEnd", x = -66.75, y = 0.4, z = 50, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaS_Shelf" } },
	{ asset = "AST-030_FridgeDisplay", x = -81, y = 0.4, z = 42, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaN_Fridge" }, note = "glass north (Cheese -81,40); Bacon (-81,44) is at its back; 7 tall vs low fridge" },
	{ asset = "AST-030_FridgeDisplay", x = -81, y = 0.4, z = 50, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/GondolaS_Fridge" }, note = "glass north (Cream Cheese -81,48)" },
	{ asset = "AST-029_GondolaBoxes", x = -97.75, y = 0.4, z = 62.75, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" } },
	{ asset = "AST-029_GondolaBoxes", x = -93.25, y = 0.4, z = 62.75, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" } },
	{ asset = "AST-029_GondolaBoxes", x = -88.75, y = 0.4, z = 62.75, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" } },
	{ asset = "AST-029_GondolaBoxes", x = -84.25, y = 0.4, z = 62.75, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" } },
	{ asset = "AST-029_GondolaBoxes", x = -79.75, y = 0.4, z = 62.75, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" } },
	{ asset = "AST-029_GondolaBoxes", x = -75.25, y = 0.4, z = 62.75, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" } },
	{ asset = "AST-029_GondolaBoxes", x = -70.75, y = 0.4, z = 62.75, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" } },
	{ asset = "AST-029_GondolaBoxes", x = -66.25, y = 0.4, z = 62.75, rotY = 0, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/BackShelves" } },
	{ asset = "AST-050_FruitDisplay", x = -94, y = 0.4, z = 35.5, rotY = 180, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/ProduceDisplay", "Mart/Interior/Fruit1", "Mart/Interior/Fruit2", "Mart/Interior/Fruit3", "Mart/Interior/Fruit4" }, note = "scenery, no prompt (DEC-109)" },
	{ asset = "AST-050_LettuceCrate", x = -91, y = 0.4, z = 35.5, rotY = 180, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/ProduceDisplay" } },
	{ asset = "AST-050_LettuceCrate", x = -89, y = 0.4, z = 35.5, rotY = 180, group = "MartInterior", id = "MKT", replaces = { "Mart/Interior/ProduceDisplay" } },

	---------------------------------------------------------------------------------------------
	-- 6. STREET FURNITURE (proposed spots, Provisório; nothing > 3 tall in the Z 30..47 band)
	---------------------------------------------------------------------------------------------
	{ asset = "AST-034_ParkBench", x = 58, y = 0.45, z = 58, rotY = 0, group = "StreetFurniture", id = "L3", replaces = { "Pad/PadBench_L3" }, note = "faces north (drawer)" },
	{ asset = "AST-034_ParkBench", x = -39, y = 0.4, z = 54.5, rotY = 0, group = "StreetFurniture", id = "Z-12", replaces = {} },
	{ asset = "AST-034_Planter", x = -54, y = 0.4, z = 54.5, rotY = 0, group = "StreetFurniture", id = "Z-12", replaces = {} },
	{ asset = "AST-034_Planter", x = -28, y = 0.4, z = 54.5, rotY = 0, group = "StreetFurniture", id = "Z-12", replaces = {} },
	{ asset = "AST-034_TreeLarge", x = -108, y = 0.4, z = 19.5, rotY = 0, group = "StreetFurniture", id = "T-01", replaces = {} },
	{ asset = "AST-034_TreeSmall", x = -84, y = 0.4, z = 19.5, rotY = 0, group = "StreetFurniture", id = "T-02", replaces = {} },
	{ asset = "AST-034_TreeLarge", x = -68, y = 0.4, z = -27.5, rotY = 0, group = "StreetFurniture", id = "T-03", replaces = {}, note = "in front of the B3a / B2b gap" },
	{ asset = "AST-034_TreeSmall", x = -108, y = 0.4, z = -27.5, rotY = 0, group = "StreetFurniture", id = "T-04", replaces = {} },
	{ asset = "AST-034_TreeSmall", x = 104, y = 0.4, z = 19.5, rotY = 0, group = "StreetFurniture", id = "T-05", replaces = {} },
	{ asset = "AST-034_TreeLarge", x = 92, y = 0.4, z = -27.5, rotY = 0, group = "StreetFurniture", id = "T-06", replaces = {} },
	{ asset = "AST-034_TrashCan", x = -46, y = 0.4, z = 17.5, rotY = 180, group = "StreetFurniture", id = "Z-02", replaces = {} },
	{ asset = "AST-034_TrashCan", x = 66, y = 0.4, z = 17.5, rotY = 180, group = "StreetFurniture", id = "Z-02", replaces = {} },
	{ asset = "AST-034_TrashCan", x = -30, y = 0.4, z = -17.5, rotY = 180, group = "StreetFurniture", id = "Z-06", replaces = {} },
	{ asset = "AST-034_Hydrant", x = 32, y = 0.4, z = -17.5, rotY = 180, group = "StreetFurniture", id = "Z-06", replaces = {}, note = "red-curb stretch" },
	{ asset = "AST-034_Mailbox", x = -46, y = 0.4, z = -18.5, rotY = 180, group = "StreetFurniture", id = "Z-06", replaces = {} },
	{ asset = "AST-034_StreetSign", x = 13, y = 0.4, z = -17.5, rotY = 0, group = "StreetFurniture", id = "NE-corner", replaces = {}, note = "NINTH AVE / JUNIPER ST decal (AST-072)" },
	{ asset = "AST-034_StreetSign", x = -13, y = 0.4, z = 17.5, rotY = 0, group = "StreetFurniture", id = "SW-corner", replaces = {} },

	-- Barriers BAR-N / BAR-S (AST-047): fence along X on each Juniper sidewalk, on tiles (y 0.24)
	{ asset = "AST-047_Barrier", x = -18, y = 0.24, z = -74, rotY = 90, group = "Barriers", id = "BAR-N", replaces = { "Signs/SidewalkClosed_BAR-N_W" }, note = "0.8 south of the sawhorse so it clears the cones" },
	{ asset = "AST-047_Barrier", x = 18, y = 0.24, z = -74, rotY = 90, group = "Barriers", id = "BAR-N", replaces = { "Signs/SidewalkClosed_BAR-N_E" } },
	{ asset = "AST-047_Barrier", x = -18, y = 0.24, z = 78, rotY = 90, group = "Barriers", id = "BAR-S", replaces = { "Signs/SidewalkClosed_BAR-S_W" } },
	{ asset = "AST-047_Barrier", x = 18, y = 0.24, z = 78, rotY = 90, group = "Barriers", id = "BAR-S", replaces = { "Signs/SidewalkClosed_BAR-S_E" } },
	{ asset = "AST-047_ConstructionCone", x = -22, y = 0.24, z = -75, rotY = 0, group = "Barriers", id = "BAR-N", replaces = { "Signs/Cones_AST-047/Cone_-22_-75" } },
	{ asset = "AST-047_ConstructionCone", x = -14, y = 0.24, z = -75, rotY = 0, group = "Barriers", id = "BAR-N", replaces = { "Signs/Cones_AST-047/Cone_-14_-75" } },
	{ asset = "AST-047_ConstructionCone", x = 14, y = 0.24, z = -75, rotY = 0, group = "Barriers", id = "BAR-N", replaces = { "Signs/Cones_AST-047/Cone_14_-75" } },
	{ asset = "AST-047_ConstructionCone", x = 22, y = 0.24, z = -75, rotY = 0, group = "Barriers", id = "BAR-N", replaces = { "Signs/Cones_AST-047/Cone_22_-75" } },
	{ asset = "AST-047_ConstructionCone", x = -22, y = 0.24, z = 79, rotY = 0, group = "Barriers", id = "BAR-S", replaces = { "Signs/Cones_AST-047/Cone_-22_79" } },
	{ asset = "AST-047_ConstructionCone", x = -14, y = 0.24, z = 79, rotY = 0, group = "Barriers", id = "BAR-S", replaces = { "Signs/Cones_AST-047/Cone_-14_79" } },
	{ asset = "AST-047_ConstructionCone", x = 14, y = 0.24, z = 79, rotY = 0, group = "Barriers", id = "BAR-S", replaces = { "Signs/Cones_AST-047/Cone_14_79" } },
	{ asset = "AST-047_ConstructionCone", x = 22, y = 0.24, z = 79, rotY = 0, group = "Barriers", id = "BAR-S", replaces = { "Signs/Cones_AST-047/Cone_22_79" } },

	---------------------------------------------------------------------------------------------
	-- 7. PARKED VEHICLES (AST-035; headlights = local +Z). PARK-N faces west (rotY 270) on the
	--    WB parking lane, Z -12.6 (up to 0.6 over the lane line). Lot cars nose-in to the north.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-035_CarSedan", x = -104, y = 0, z = -12.6, rotY = 90, group = "Vehicles", id = "PARK-N", paint = "Butter", replaces = { "Parking/PARK-N/ParkN_Car_1" } },
	{ asset = "AST-035_CarHatch", x = -90, y = 0, z = -12.6, rotY = 90, group = "Vehicles", id = "PARK-N", paint = "Peach", replaces = { "Parking/PARK-N/ParkN_Car_2" } },
	{ asset = "AST-035_CarVan", x = -62, y = 0, z = -12.6, rotY = 90, group = "Vehicles", id = "PARK-N", paint = "TealLight", replaces = { "Parking/PARK-N/ParkN_Car_3" } },
	{ asset = "AST-035_CarPickup", x = -44, y = 0, z = -12.6, rotY = 90, group = "Vehicles", id = "PARK-N", paint = "Lilac", replaces = { "Parking/PARK-N/ParkN_Car_4" }, note = "ends at X -37, clear of the red curb (-32)" },
	{ asset = "AST-035_CarSedan", x = 84, y = 0, z = -12.6, rotY = 90, group = "Vehicles", id = "PARK-N", paint = "MintGray", replaces = { "Parking/PARK-N/ParkN_Car_5" } },
	{ asset = "AST-035_CarHatch", x = 98, y = 0, z = -12.6, rotY = 90, group = "Vehicles", id = "PARK-N", paint = "Butter", replaces = { "Parking/PARK-N/ParkN_Car_6" } },
	{ asset = "AST-035_CarHatch", x = 60, y = 0.02, z = -81, rotY = 0, group = "Vehicles", id = "Z-05", paint = "Peach", replaces = { "Parking/LotCar_1" } },
	{ asset = "AST-035_CarSedan", x = 68, y = 0.02, z = -81, rotY = 0, group = "Vehicles", id = "Z-05", paint = "Lilac", replaces = { "Parking/LotCar_2" } },
	{ asset = "AST-035_CarPickup", x = 100, y = 0.02, z = -48, rotY = 0, group = "Vehicles", id = "Z-05", paint = "TealLight", replaces = { "Parking/LotCar_3" } },
	{ asset = "AST-035_CarVan", x = 92, y = 0.02, z = -72.5, rotY = 0, group = "Vehicles", id = "AS-1", paint = "MintGray", replaces = { "Parking/Van_AS-1_Cover" }, note = "6.35 tall, Z -79..-66: still hides AS-1 (92, -80) from the Pad" },
}
