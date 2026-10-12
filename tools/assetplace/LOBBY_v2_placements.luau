--[[
	LOBBY v2 "Bramble's Corner Dogs HQ" - placement table of the real assets.
	DATA ONLY. Status: Draft / Provisional (level-designer, 2026-10-11). Not gameplay code.
	Layout, points, lights and procedural pieces: docs/levels/LOBBY.md section "LOBBY v2" (V2-1..V2-16), the source of
	truth for the numbers. Replaces LOBBY_placements.luau (v1, 60 x 60) in the same world region.

	==============================================================================================
	COORDINATES: WORLD. NOT MAP-01 COORDINATES. NO MAP_FRAME.
	==============================================================================================
	- Same rules as v1: pose = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotY), 0). Build with
	  Place.runInto(<this table>, ids, "LOBBY_Assets", true) (frameOf = identity, `replaces` ignored). The force flag
	  DESTROYS the v1 root and any hand edits made on it in Studio: sync them first (LOBBY.md V2-15 P-L21).
	- Walkable box: X -56..50.4, Z -675..-565 (plaza floor X -56..48 + curb 48..50.4), floor top Y 0.
	  Plaza centre ~ (-3, 0, -620); LOBBY-SPAWN (5, 0, -620). MAP-01 is at world Z >= -60; DevScenes at Z ~4000 untouched.
	- y = world height of the asset pivot (bottom centre). Plaza top 0; road tiles at y -0.48 (curb top 0, asphalt -0.24).

	FRONT CONVENTION (same as v1, measured on MAP-01):
	- Modelled assets (cart, trailer, stations, AST-024 sign, AST-034 bench/bin/mailbox, AST-104 stand, AST-105
	  pedestals): front = LookVector. rotY 0 -> -Z | 90 -> -X | 180 -> +Z | -90 -> +X.
	- Kenney buildings AST-033_BuildingA/H and BG cards: storefront = local +Z (opposite): rotY 0 -> +Z | 90 -> +X |
	  180 -> -Z | 270 -> -X. BuildingA pivot 12.725 behind its front line, BuildingH 13.355; both 16.4 wide.
	- Street light AST-036: arm = local +Z, d = (sin rotY, cos rotY); pole pivot = foot + 1.815 * d,
	  LampHead pivot = pole pivot + 1.78 * d (same rotY, y = floor).
	- Trailer AST-027 at rotY 0: window = -Z, body X pivot +-14 / Z pivot +-6, hitch to pivot X - 18.5.
	- Not measured (check in Studio, turn 180 if wrong): AST-035 cars, AST-037 flyer, AST-019, AST-047, AST-034 hydrant /
	  street sign, AST-100 tables (5.38 x 4.34 assumed long in X at rotY 0).

	FIELDS (same as v1): asset, x, y, z, rotY, group, id, replaces = {}, note; optional part, parts, drop, pivot (WORLD),
	paint, collide = false.
]]

local PAD_FLOOR = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 20.8, 0.48, 22 } } }
local SIGN_UP = { ["AST-024_SignStand"] = { 0, 2.0, 0 } }

return {
	---------------------------------------------------------------------------------------------
	-- 1. FLOOR: plaza 5 x 5 sidewalk tiles scaled to 20.8 x 22 (X -56..48, Z -675..-565), top Y 0;
	--    two filler strips X 41..48 behind LW-N / LW-S (between the last building and the road).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-032_SidewalkTile", x = -45.6, y = -0.48, z = -664, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {}, note = "plaza tile; top Y 0" },
	{ asset = "AST-032_SidewalkTile", x = -24.8, y = -0.48, z = -664, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -4.0, y = -0.48, z = -664, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 16.8, y = -0.48, z = -664, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 37.6, y = -0.48, z = -664, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -45.6, y = -0.48, z = -642, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -24.8, y = -0.48, z = -642, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -4.0, y = -0.48, z = -642, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 16.8, y = -0.48, z = -642, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 37.6, y = -0.48, z = -642, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -45.6, y = -0.48, z = -620, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -24.8, y = -0.48, z = -620, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -4.0, y = -0.48, z = -620, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 16.8, y = -0.48, z = -620, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 37.6, y = -0.48, z = -620, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -45.6, y = -0.48, z = -598, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -24.8, y = -0.48, z = -598, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -4.0, y = -0.48, z = -598, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 16.8, y = -0.48, z = -598, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 37.6, y = -0.48, z = -598, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -45.6, y = -0.48, z = -576, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -24.8, y = -0.48, z = -576, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -4.0, y = -0.48, z = -576, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 16.8, y = -0.48, z = -576, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 37.6, y = -0.48, z = -576, rotY = 0, parts = PAD_FLOOR, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 44.5, y = -0.48, z = -555, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 7, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR-GAP", replaces = {}, note = "gap BK6 / road behind LW-N (X 41..48, Z -565..-545)" },
	{ asset = "AST-032_SidewalkTile", x = 44.5, y = -0.48, z = -685, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 7, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR-GAP", replaces = {}, note = "gap FR6 / road behind LW-S (Z -695..-675)" },

	---------------------------------------------------------------------------------------------
	-- 2. ROAD (east, outside the play area): 6 straight tiles along Z (rotY 90), X 48..72, Z -693..-549.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-032_RoadStraight", x = 60, y = -0.48, z = -681, rotY = 90, group = "LobbyRoad", id = "LB-ROAD", replaces = {}, note = "curb X 48..50.4 top 0, asphalt -0.24" },
	{ asset = "AST-032_RoadStraight", x = 60, y = -0.48, z = -657, rotY = 90, group = "LobbyRoad", id = "LB-ROAD", replaces = {} },
	{ asset = "AST-032_RoadStraight", x = 60, y = -0.48, z = -633, rotY = 90, group = "LobbyRoad", id = "LB-ROAD", replaces = {} },
	{ asset = "AST-032_RoadStraight", x = 60, y = -0.48, z = -609, rotY = 90, group = "LobbyRoad", id = "LB-ROAD", replaces = {} },
	{ asset = "AST-032_RoadStraight", x = 60, y = -0.48, z = -585, rotY = 90, group = "LobbyRoad", id = "LB-ROAD", replaces = {} },
	{ asset = "AST-032_RoadStraight", x = 60, y = -0.48, z = -561, rotY = 90, group = "LobbyRoad", id = "LB-ROAD", replaces = {} },
	{ asset = "AST-047_Barrier", x = 60, y = -0.24, z = -552, rotY = 0, group = "LobbyRoad", id = "LB-BAR-N", replaces = {}, note = "road closed north (decor; the wall is LW-E)" },
	{ asset = "AST-047_Barrier", x = 60, y = -0.24, z = -690, rotY = 0, group = "LobbyRoad", id = "LB-BAR-S", replaces = {} },

	---------------------------------------------------------------------------------------------
	-- 3. BACKDROP BUILDINGS (front line on the play-area edge).
	---------------------------------------------------------------------------------------------
	-- 3a. back row (+Z, front line Z -565, storefront -Z: rotY 180). BK4 (X 0) carries the HQ neon (LOBBY.md V2-12.1).
	{ asset = "AST-033_BuildingA", x = -49.2, y = 0, z = -552.275, rotY = 180, group = "LobbyBackdrop", id = "LB-BK1", replaces = {}, note = "X -57.4..-41" },
	{ asset = "AST-033_BuildingH", x = -32.8, y = 0, z = -551.645, rotY = 180, group = "LobbyBackdrop", id = "LB-BK2", replaces = {} },
	{ asset = "AST-033_BuildingA", x = -16.4, y = 0, z = -552.275, rotY = 180, group = "LobbyBackdrop", id = "LB-BK3", replaces = {} },
	{ asset = "AST-033_BuildingH", x = 0, y = 0, z = -551.645, rotY = 180, group = "LobbyBackdrop", id = "LB-BK4", replaces = {}, note = "HQ facade: CORNER DOGS HQ board at Z ~ -564.6 (check the wall plane by raycast)" },
	{ asset = "AST-033_BuildingA", x = 16.4, y = 0, z = -552.275, rotY = 180, group = "LobbyBackdrop", id = "LB-BK5", replaces = {} },
	{ asset = "AST-033_BuildingH", x = 32.8, y = 0, z = -551.645, rotY = 180, group = "LobbyBackdrop", id = "LB-BK6", replaces = {}, note = "X 24.6..41" },
	-- 3b. front row (-Z, front line Z -675, storefront +Z: rotY 0). Behind the codes mural and the fountain.
	{ asset = "AST-033_BuildingH", x = -49.2, y = 0, z = -688.355, rotY = 0, group = "LobbyBackdrop", id = "LB-FR1", replaces = {} },
	{ asset = "AST-033_BuildingA", x = -32.8, y = 0, z = -687.725, rotY = 0, group = "LobbyBackdrop", id = "LB-FR2", replaces = {} },
	{ asset = "AST-033_BuildingH", x = -16.4, y = 0, z = -688.355, rotY = 0, group = "LobbyBackdrop", id = "LB-FR3", replaces = {} },
	{ asset = "AST-033_BuildingA", x = 0, y = 0, z = -687.725, rotY = 0, group = "LobbyBackdrop", id = "LB-FR4", replaces = {} },
	{ asset = "AST-033_BuildingH", x = 16.4, y = 0, z = -688.355, rotY = 0, group = "LobbyBackdrop", id = "LB-FR5", replaces = {} },
	{ asset = "AST-033_BuildingA", x = 32.8, y = 0, z = -687.725, rotY = 0, group = "LobbyBackdrop", id = "LB-FR6", replaces = {}, note = "X 24.6..41" },
	-- 3c. west side (front line X -56, storefront +X: rotY 90). Seen over the garden behind the gem shop.
	{ asset = "AST-033_BuildingA", x = -68.725, y = 0, z = -573.2, rotY = 90, group = "LobbyBackdrop", id = "LB-LF1", replaces = {}, note = "Z -581.4..-565" },
	{ asset = "AST-033_BuildingH", x = -69.355, y = 0, z = -589.6, rotY = 90, group = "LobbyBackdrop", id = "LB-LF2", replaces = {} },
	{ asset = "AST-033_BuildingA", x = -68.725, y = 0, z = -606.0, rotY = 90, group = "LobbyBackdrop", id = "LB-LF3", replaces = {} },
	{ asset = "AST-033_BuildingH", x = -69.355, y = 0, z = -622.4, rotY = 90, group = "LobbyBackdrop", id = "LB-LF4", replaces = {} },
	{ asset = "AST-033_BuildingA", x = -68.725, y = 0, z = -638.8, rotY = 90, group = "LobbyBackdrop", id = "LB-LF5", replaces = {} },
	{ asset = "AST-033_BuildingH", x = -69.355, y = 0, z = -655.2, rotY = 90, group = "LobbyBackdrop", id = "LB-LF6", replaces = {} },
	{ asset = "AST-033_BuildingA", x = -68.825, y = 0, z = -666.8, rotY = 90, group = "LobbyBackdrop", id = "LB-LF7", replaces = {}, note = "Z -675..-658.6, overlaps LF6 by 4.8: set 0.1 back (front X -56.1) so the facades do not z-fight" },
	-- 3d. east side beyond the road (cards; storefront -X: rotY 270). A = 24, C = 20, B = 16 wide.
	{ asset = "AST-033_BGCard_A", x = 73.5, y = 0, z = -559, rotY = 270, group = "LobbyBackdrop", id = "LB-RC1", replaces = {}, note = "Z -571..-547; check the card's front side" },
	{ asset = "AST-033_BGCard_C", x = 73.5, y = 0, z = -581, rotY = 270, group = "LobbyBackdrop", id = "LB-RC2", replaces = {}, note = "Z -591..-571" },
	{ asset = "AST-033_BGCard_B", x = 73.5, y = 0, z = -599, rotY = 270, group = "LobbyBackdrop", id = "LB-RC3", replaces = {}, note = "Z -607..-591" },
	{ asset = "AST-033_BGCard_A", x = 73.5, y = 0, z = -619, rotY = 270, group = "LobbyBackdrop", id = "LB-RC4", replaces = {}, note = "Z -631..-607 (behind the van)" },
	{ asset = "AST-033_BGCard_C", x = 73.5, y = 0, z = -641, rotY = 270, group = "LobbyBackdrop", id = "LB-RC5", replaces = {}, note = "Z -651..-631" },
	{ asset = "AST-033_BGCard_B", x = 73.5, y = 0, z = -659, rotY = 270, group = "LobbyBackdrop", id = "LB-RC6", replaces = {}, note = "Z -667..-651" },
	{ asset = "AST-033_BGCard_A", x = 73.5, y = 0, z = -679, rotY = 270, group = "LobbyBackdrop", id = "LB-RC7", replaces = {}, note = "Z -691..-667" },
	-- 3e. road ends (card widened to X 41..72.4, including the gap strip)
	{ asset = "AST-033_BGCard_A", x = 56.7, y = 0, z = -547.5, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13, 0, size = { 31.4, 26, 4.2 } } }, group = "LobbyBackdrop", id = "LB-RE-N", replaces = {}, note = "faces the plaza (-Z)" },
	{ asset = "AST-033_BGCard_A", x = 56.7, y = 0, z = -694.5, rotY = 0, parts = { ["BG_Card_A"] = { 0, 13, 0, size = { 31.4, 26, 4.2 } } }, group = "LobbyBackdrop", id = "LB-RE-S", replaces = {}, note = "faces the plaza (+Z)" },
	{ asset = "AST-102_BushLarge", x = 44.5, y = 0, z = -561, rotY = 0, group = "LobbyBackdrop", id = "LB-GAP-N", replaces = {}, note = "fills the gap BK6 / curb behind LW-N" },
	{ asset = "AST-102_BushLarge", x = 44.5, y = 0, z = -679, rotY = 0, group = "LobbyBackdrop", id = "LB-GAP-S", replaces = {} },

	---------------------------------------------------------------------------------------------
	-- 4. HQ: the original Corner Cart on display (v1 + 5 in Z). Pivot (0, 0, -567.8), rotY 0: queue side + skirt
	--    logo face the plaza (-Z). Stations = cart pivot + the MAP-01 offsets, decor only (no Vehicle / Station tags).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-026_CornerCart", x = 0, y = 0, z = -567.8, rotY = 0, parts = { ["Parasol_W"] = { -6.5, 5.926, -1.624, rotX = -6.3, size = { 12.9, 6.372, 10.014 } }, ["Parasol_E"] = { 6.5, 5.901, -1.77, rotX = -9 } }, group = "LobbyCart", id = "LB-CART", replaces = {}, note = "display only; parasols tilted like MAP-01 (user hand edit)" },
	{ asset = "AST-012_RollerGrill", part = { "Grill_L1" }, x = -7.5, y = 3.0, z = -567.8, rotY = 180, group = "LobbyCart", id = "LB-CART-G", replaces = {}, note = "decor, no Station tag" },
	{ asset = "AST-013_RestRail", part = { "Rail_6" }, x = -3.5, y = 3.0, z = -567.8, rotY = 180, group = "LobbyCart", id = "LB-CART-R", replaces = {} },
	{ asset = "AST-015_BunCrate", x = -1, y = 3.0, z = -567.8, rotY = 180, group = "LobbyCart", id = "LB-CART-B", replaces = {} },
	{ asset = "AST-014_CuttingBoard", x = 1.5, y = 3.0, z = -567.8, rotY = 0, parts = { ["Knife"] = { 0, 0.163, -0.1, size = { 1.246, 0.083, 0.276 } }, ["Board"] = { 0, 0.06, 0.1, size = { 2.6, 0.12, 1.7 } } }, group = "LobbyCart", id = "LB-CART-T", replaces = {} },
	{ asset = "AST-017_ToppingGrid", x = 6, y = 3.0, z = -567.948, rotY = 180, group = "LobbyCart", id = "LB-CART-K", replaces = {} },
	{ asset = "AST-020_CashRegister", x = 12.143, y = 3.0, z = -567.639, rotY = 180, drop = { "DeliveryStand" }, pivot = { 10.743, 3.0, -567.639, 180 }, group = "LobbyCart", id = "LB-CART-DRAWER", replaces = {}, note = "same hand edit as MAP-01 DRAWER (pivot in WORLD)" },
	{ asset = "AST-042_VehiclePhone", part = { "Phone_Cart", "Cart_Body", "Cart_Handset", "Cart_Lamp" }, x = -9.1, y = 3.0, z = -567.46, rotY = -174.3, group = "LobbyCart", id = "LB-CART-PHONE", replaces = {}, note = "decor (no prompt)" },
	{ asset = "AST-024_SignStand", x = -13.5, y = 0, z = -574, rotY = 0, parts = SIGN_UP, group = "LobbyCart", id = "LB-CART-SIGN", replaces = {}, note = "OPEN easel at the west end of the cart, inside LW-STAGE, faces the plaza" },

	---------------------------------------------------------------------------------------------
	-- 5. CLASS STAGE dressing (stage 20 x 7, X -10..10, Z -579..-572, top Y 1.0; stage, spot, rope, stage lights are
	--    procedural: LOBBY.md V2-12.6). Rig on LOBBY-CLASS-STAGE (0, 1.02, -575.5). Camera (0, 4.5, -587.5).
	--    Nothing here may stand between the camera and the rig.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-102_PottedPlant", x = -5.3, y = 1.0, z = -572.6, rotY = 0, group = "LobbyStage", id = "LB-STAGE-PLANT", replaces = {}, note = "on the stage, behind the rig (in the class camera frame)" },
	{ asset = "AST-102_PottedPlant", x = 5.3, y = 1.0, z = -572.6, rotY = 0, group = "LobbyStage", id = "LB-STAGE-PLANT", replaces = {} },
	{ asset = "AST-102_PottedPlant", x = -8.8, y = 1.0, z = -572.6, rotY = 0, group = "LobbyStage", id = "LB-STAGE-PLANT", replaces = {} },
	{ asset = "AST-102_PottedPlant", x = 8.8, y = 1.0, z = -572.6, rotY = 0, group = "LobbyStage", id = "LB-STAGE-PLANT", replaces = {} },
	{ asset = "AST-019_QueuePost", x = -10.6, y = 0, z = -579.7, rotY = 0, group = "LobbyStage", id = "LB-STAGE-ROPE", replaces = {}, note = "low rope (y 2.0) to X 10.6 is procedural; inside LW-STAGE; out of the camera frame" },
	{ asset = "AST-019_QueuePost", x = 10.6, y = 0, z = -579.7, rotY = 0, group = "LobbyStage", id = "LB-STAGE-ROPE", replaces = {} },
	{ asset = "AST-034_Planter", x = -13.5, y = 0, z = -578.5, rotY = 0, group = "LobbyStage", id = "LB-STAGE-PLANTER", replaces = {}, note = "marks the end of the stage block (LW-STAGE X -16..16, Z -580..-565)" },
	{ asset = "AST-034_Planter", x = 13.5, y = 0, z = -578.5, rotY = 0, group = "LobbyStage", id = "LB-STAGE-PLANTER", replaces = {} },

	---------------------------------------------------------------------------------------------
	-- 6. FOOD COURT (north-west POI): Open Late trailer parked as a shell (no Vehicle tag) + 3 picnic tables.
	--    Trailer body X -50..-22, Z -577.5..-565.5, hitch to X -54.5; blocked by LW-TRUCK (X -56..-16, Z -578..-565).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-027_OpenLateTrailer", x = -36, y = 0, z = -571.5, rotY = 0, group = "LobbyFoodCourt", id = "LB-TRL", replaces = {}, note = "window faces the plaza (-Z); shell only, no Vehicle tag; L-TRUCK light under the window" },
	{ asset = "AST-100_PicnicTable", x = -46, y = 0, z = -587, rotY = 0, group = "LobbyFoodCourt", id = "LB-PICNIC-M1", replaces = {}, note = "CC-BY 3.0 J-Toastie: credits.md 'Usado em' (4 tables in the lobby)" },
	{ asset = "AST-100_PicnicTable", x = -36, y = 0, z = -587, rotY = 0, group = "LobbyFoodCourt", id = "LB-PICNIC-M2", replaces = {} },
	{ asset = "AST-100_PicnicTable", x = -26, y = 0, z = -587, rotY = 0, group = "LobbyFoodCourt", id = "LB-PICNIC-M3", replaces = {} },
	{ asset = "AST-034_TrashCan", x = -20, y = 0, z = -584, rotY = 0, group = "LobbyFoodCourt", id = "LB-FC-BIN", replaces = {}, note = "decor, no prompt" },
	{ asset = "AST-034_TreeSmall", x = -19, y = 0, z = -575.5, rotY = 0, group = "LobbyFoodCourt", id = "LB-FC-TREE", replaces = {}, note = "fills the closed gap trailer / stage (inside LW-TRUCK)" },
	{ asset = "AST-102_Bush", x = -53.5, y = 0, z = -590, rotY = 0, group = "LobbyFoodCourt", id = "LB-FC-BUSH", replaces = {} },

	---------------------------------------------------------------------------------------------
	-- 7. GEM SHOP: Gear Stand kiosk (AST-104) free-standing on the west side, front faces +X (rotY -90), WITHOUT the
	--    roller shutters. Pivot (-37.5, 0, -620): front face X -34.03, Z -632.95..-607.05. Pedestals = pivot + 1.125
	--    forward (+X), Z offsets -10 / -7 / -4 / +4 / +7 / +10 (same as v1).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-104_GearStand", x = -37.5, y = 0, z = -620, rotY = -90, group = "LobbyShop", id = "LB-SHOP", replaces = {}, note = "GEM SHOP neon on Neon_Upgrades -> WORLD (-34.0, 9.75, -620); name plates (-34.3, 9.75, -609.5 / -630.5); counter = shop counter (no NPC)" },
	{ asset = "AST-105_PedestalS1", x = -36.375, y = 0, z = -630, rotY = -90, group = "LobbyShop", id = "LB-SHOP-S1", replaces = {}, note = "best-value slot; Mini_Anchor y 4.2 holds the procedural gem" },
	{ asset = "AST-105_Pedestal", x = -36.375, y = 0, z = -627, rotY = -90, group = "LobbyShop", id = "LB-SHOP-P5", replaces = {} },
	{ asset = "AST-105_Pedestal", x = -36.375, y = 0, z = -624, rotY = -90, group = "LobbyShop", id = "LB-SHOP-P4", replaces = {} },
	{ asset = "AST-105_Pedestal", x = -36.375, y = 0, z = -616, rotY = -90, group = "LobbyShop", id = "LB-SHOP-P3", replaces = {} },
	{ asset = "AST-105_Pedestal", x = -36.375, y = 0, z = -613, rotY = -90, group = "LobbyShop", id = "LB-SHOP-P2", replaces = {} },
	{ asset = "AST-105_Pedestal", x = -36.375, y = 0, z = -610, rotY = -90, group = "LobbyShop", id = "LB-SHOP-P1", replaces = {} },
	{ asset = "AST-102_PottedPlant", x = -33.2, y = 0, z = -634.5, rotY = 0, group = "LobbyShop", id = "LB-SHOP-PLANT", replaces = {} },
	{ asset = "AST-102_PottedPlant", x = -33.2, y = 0, z = -605.5, rotY = 0, group = "LobbyShop", id = "LB-SHOP-PLANT", replaces = {} },
	-- garden behind the kiosk (X -56..-41), open at both ends
	{ asset = "AST-034_TreeLarge", x = -48.5, y = 0, z = -612, rotY = 0, group = "LobbyGarden", id = "LB-GARDEN-T1", replaces = {} },
	{ asset = "AST-034_TreeLarge", x = -48.5, y = 0, z = -628, rotY = 0, group = "LobbyGarden", id = "LB-GARDEN-T2", replaces = {} },
	{ asset = "AST-100_PlanterBushes", x = -43, y = 0, z = -620, rotY = 90, group = "LobbyGarden", id = "LB-GARDEN-PLANTER", replaces = {}, note = "against the kiosk back (X -41); check its size, keep 2 of passage to the trees" },
	{ asset = "AST-034_Mailbox", x = -54.5, y = 0, z = -604, rotY = -90, group = "LobbyGarden", id = "LB-MAILBOX", replaces = {}, note = "faces +X" },

	---------------------------------------------------------------------------------------------
	-- 8. SQUAD PADS (procedural discs, LOBBY.md V2-12.3): 2 rows x 4, pitch 18 (gap 10). Row near X 16 (pads 1..4),
	--    row far X 34 (pads 5..8); Z -647 / -629 / -611 / -593. Per pad: board AST-024 at X + 5.6 facing -X (the spawn)
	--    + 4 slot marks AST-019 (+-1.8) on the pad top (0.3).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-024_SignStand", x = 21.6, y = 0, z = -647, rotY = 90, parts = SIGN_UP, group = "LobbySquad", id = "LB-SQ1-BOARD", replaces = {}, note = "SurfaceGui SQUAD 1 n/4 + names; faces -X" },
	{ asset = "AST-024_SignStand", x = 21.6, y = 0, z = -629, rotY = 90, parts = SIGN_UP, group = "LobbySquad", id = "LB-SQ2-BOARD", replaces = {} },
	{ asset = "AST-024_SignStand", x = 21.6, y = 0, z = -611, rotY = 90, parts = SIGN_UP, group = "LobbySquad", id = "LB-SQ3-BOARD", replaces = {} },
	{ asset = "AST-024_SignStand", x = 21.6, y = 0, z = -593, rotY = 90, parts = SIGN_UP, group = "LobbySquad", id = "LB-SQ4-BOARD", replaces = {} },
	{ asset = "AST-024_SignStand", x = 39.6, y = 0, z = -647, rotY = 90, parts = SIGN_UP, group = "LobbySquad", id = "LB-SQ5-BOARD", replaces = {} },
	{ asset = "AST-024_SignStand", x = 39.6, y = 0, z = -629, rotY = 90, parts = SIGN_UP, group = "LobbySquad", id = "LB-SQ6-BOARD", replaces = {} },
	{ asset = "AST-024_SignStand", x = 39.6, y = 0, z = -611, rotY = 90, parts = SIGN_UP, group = "LobbySquad", id = "LB-SQ7-BOARD", replaces = {} },
	{ asset = "AST-024_SignStand", x = 39.6, y = 0, z = -593, rotY = 90, parts = SIGN_UP, group = "LobbySquad", id = "LB-SQ8-BOARD", replaces = {} },
	-- slot marks (Slot_1..4 of each pad)
	{ asset = "AST-019_QueueMark", x = 14.2, y = 0.3, z = -648.8, rotY = 90, group = "LobbySquad", id = "LB-SQ1-SLOT1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 17.8, y = 0.3, z = -648.8, rotY = 90, group = "LobbySquad", id = "LB-SQ1-SLOT2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 14.2, y = 0.3, z = -645.2, rotY = 90, group = "LobbySquad", id = "LB-SQ1-SLOT3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 17.8, y = 0.3, z = -645.2, rotY = 90, group = "LobbySquad", id = "LB-SQ1-SLOT4", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 14.2, y = 0.3, z = -630.8, rotY = 90, group = "LobbySquad", id = "LB-SQ2-SLOT1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 17.8, y = 0.3, z = -630.8, rotY = 90, group = "LobbySquad", id = "LB-SQ2-SLOT2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 14.2, y = 0.3, z = -627.2, rotY = 90, group = "LobbySquad", id = "LB-SQ2-SLOT3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 17.8, y = 0.3, z = -627.2, rotY = 90, group = "LobbySquad", id = "LB-SQ2-SLOT4", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 14.2, y = 0.3, z = -612.8, rotY = 90, group = "LobbySquad", id = "LB-SQ3-SLOT1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 17.8, y = 0.3, z = -612.8, rotY = 90, group = "LobbySquad", id = "LB-SQ3-SLOT2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 14.2, y = 0.3, z = -609.2, rotY = 90, group = "LobbySquad", id = "LB-SQ3-SLOT3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 17.8, y = 0.3, z = -609.2, rotY = 90, group = "LobbySquad", id = "LB-SQ3-SLOT4", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 14.2, y = 0.3, z = -594.8, rotY = 90, group = "LobbySquad", id = "LB-SQ4-SLOT1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 17.8, y = 0.3, z = -594.8, rotY = 90, group = "LobbySquad", id = "LB-SQ4-SLOT2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 14.2, y = 0.3, z = -591.2, rotY = 90, group = "LobbySquad", id = "LB-SQ4-SLOT3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 17.8, y = 0.3, z = -591.2, rotY = 90, group = "LobbySquad", id = "LB-SQ4-SLOT4", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 32.2, y = 0.3, z = -648.8, rotY = 90, group = "LobbySquad", id = "LB-SQ5-SLOT1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 35.8, y = 0.3, z = -648.8, rotY = 90, group = "LobbySquad", id = "LB-SQ5-SLOT2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 32.2, y = 0.3, z = -645.2, rotY = 90, group = "LobbySquad", id = "LB-SQ5-SLOT3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 35.8, y = 0.3, z = -645.2, rotY = 90, group = "LobbySquad", id = "LB-SQ5-SLOT4", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 32.2, y = 0.3, z = -630.8, rotY = 90, group = "LobbySquad", id = "LB-SQ6-SLOT1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 35.8, y = 0.3, z = -630.8, rotY = 90, group = "LobbySquad", id = "LB-SQ6-SLOT2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 32.2, y = 0.3, z = -627.2, rotY = 90, group = "LobbySquad", id = "LB-SQ6-SLOT3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 35.8, y = 0.3, z = -627.2, rotY = 90, group = "LobbySquad", id = "LB-SQ6-SLOT4", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 32.2, y = 0.3, z = -612.8, rotY = 90, group = "LobbySquad", id = "LB-SQ7-SLOT1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 35.8, y = 0.3, z = -612.8, rotY = 90, group = "LobbySquad", id = "LB-SQ7-SLOT2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 32.2, y = 0.3, z = -609.2, rotY = 90, group = "LobbySquad", id = "LB-SQ7-SLOT3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 35.8, y = 0.3, z = -609.2, rotY = 90, group = "LobbySquad", id = "LB-SQ7-SLOT4", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 32.2, y = 0.3, z = -594.8, rotY = 90, group = "LobbySquad", id = "LB-SQ8-SLOT1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 35.8, y = 0.3, z = -594.8, rotY = 90, group = "LobbySquad", id = "LB-SQ8-SLOT2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 32.2, y = 0.3, z = -591.2, rotY = 90, group = "LobbySquad", id = "LB-SQ8-SLOT3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 35.8, y = 0.3, z = -591.2, rotY = 90, group = "LobbySquad", id = "LB-SQ8-SLOT4", replaces = {} },

	---------------------------------------------------------------------------------------------
	-- 9. START SHIFT: crew van parked on the road against the curb, side to the plaza; START SHIFT neon on the curb
	--    (procedural, V2-12.4). Parked cars on the far lane = life on the street.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-035_CarVan", x = 54.5, y = -0.24, z = -620, rotY = 0, paint = "Butter", group = "LobbyStart", id = "LB-VAN", replaces = {}, note = "13 long (Z -626.5..-613.5); Crew Van colours pending (P-L7); front side not measured" },
	{ asset = "AST-035_CarSedan", x = 65.5, y = -0.24, z = -662, rotY = 180, paint = "Peach", group = "LobbyStart", id = "LB-CAR-1", replaces = {}, note = "parked, far lane" },
	{ asset = "AST-035_CarPickup", x = 65.5, y = -0.24, z = -578, rotY = 180, paint = "Lilac", group = "LobbyStart", id = "LB-CAR-2", replaces = {}, note = "parked, far lane" },
	{ asset = "AST-034_Hydrant", x = 47, y = 0, z = -652, rotY = 0, group = "LobbyStart", id = "LB-HYDRANT", replaces = {} },
	{ asset = "AST-034_StreetSign", x = 46.8, y = 0, z = -668.2, rotY = 0, group = "LobbyStart", id = "LB-STREETSIGN", replaces = {}, note = "street name decal: narrative-writer (P-L11)" },

	---------------------------------------------------------------------------------------------
	-- 10. CODES (south): mural is procedural (V2-12.5, board face Z -655.4); flyers pinned on it; table and bin behind.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-037_Flyer", x = -13.2, y = 4.8, z = -655.25, rotY = 175, collide = false, group = "LobbyCodes", id = "LB-CODES-FLYER", replaces = {}, note = "pinned on the mural face; front assumed = LookVector: check" },
	{ asset = "AST-037_Flyer", x = -6.8, y = 2.6, z = -655.25, rotY = 186, collide = false, group = "LobbyCodes", id = "LB-CODES-FLYER", replaces = {} },
	{ asset = "AST-034_TrashCan", x = -2.5, y = 0, z = -657.6, rotY = 180, group = "LobbyCodes", id = "LB-CODES-BIN", replaces = {} },
	{ asset = "AST-100_PicnicTable", x = 6, y = 0, z = -666, rotY = 0, group = "LobbyCodes", id = "LB-PICNIC-M4", replaces = {} },

	---------------------------------------------------------------------------------------------
	-- 11. FOUNTAIN (south-west POI): fountain is procedural (V2-12.12) at (-34, -654); 4 benches face it.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-034_ParkBench", x = -34, y = 0, z = -644.5, rotY = 0, group = "LobbyFountain", id = "LB-FT-BENCH-N", replaces = {}, note = "faces the fountain (-Z)" },
	{ asset = "AST-034_ParkBench", x = -34, y = 0, z = -663.5, rotY = 180, group = "LobbyFountain", id = "LB-FT-BENCH-S", replaces = {}, note = "faces +Z" },
	{ asset = "AST-034_ParkBench", x = -24.5, y = 0, z = -654, rotY = 90, group = "LobbyFountain", id = "LB-FT-BENCH-E", replaces = {}, note = "faces -X" },
	{ asset = "AST-034_ParkBench", x = -43.5, y = 0, z = -654, rotY = -90, group = "LobbyFountain", id = "LB-FT-BENCH-W", replaces = {}, note = "faces +X" },
	{ asset = "AST-034_TreeLarge", x = -48, y = 0, z = -667, rotY = 0, group = "LobbyFountain", id = "LB-FT-TREE", replaces = {} },
	{ asset = "AST-034_TreeLarge", x = -20, y = 0, z = -669, rotY = 0, group = "LobbyFountain", id = "LB-FT-TREE", replaces = {} },
	{ asset = "AST-102_Bush", x = -42, y = 0, z = -646, rotY = 0, group = "LobbyFountain", id = "LB-FT-BUSH", replaces = {} },
	{ asset = "AST-102_Bush", x = -26, y = 0, z = -662, rotY = 0, group = "LobbyFountain", id = "LB-FT-BUSH", replaces = {} },

	---------------------------------------------------------------------------------------------
	-- 12. PLAZA DECOR: mast planter bush, welcome easel, bleacher benches (south-east), photo booth corner (north-east).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-102_Bush", x = 5, y = 1.2, z = -628.5, rotY = 0, group = "LobbyDecor", id = "LB-MAST-BUSH", replaces = {}, note = "on the mast planter (V2-12.9, top Y 1.2); must not hide the pole" },
	{ asset = "AST-024_SignStand", x = -3, y = 0, z = -609, rotY = 0, parts = SIGN_UP, group = "LobbyDecor", id = "LB-WELCOME", replaces = {}, note = "faces the spawn (-Z): WELCOME, CREW! + 4 arrows (SurfaceGui, text P-L11); clear of the CLASSES route (X 1.3..3.5)" },
	{ asset = "AST-034_ParkBench", x = 22, y = 0, z = -657, rotY = 180, group = "LobbyDecor", id = "LB-BLEACH-1", replaces = {}, note = "faces the pads (+Z)" },
	{ asset = "AST-034_ParkBench", x = 30, y = 0, z = -657, rotY = 180, group = "LobbyDecor", id = "LB-BLEACH-2", replaces = {} },
	{ asset = "AST-034_TrashCan", x = 26, y = 0, z = -658.5, rotY = 180, group = "LobbyDecor", id = "LB-BLEACH-BIN", replaces = {} },
	{ asset = "AST-034_TreeLarge", x = 41, y = 0, z = -664, rotY = 0, group = "LobbyDecor", id = "LB-SE-TREE", replaces = {} },
	{ asset = "AST-034_Planter", x = 12, y = 0, z = -669, rotY = 0, group = "LobbyDecor", id = "LB-SE-PLANTER", replaces = {} },
	{ asset = "AST-034_ParkBench", x = 23.5, y = 0, z = -567.6, rotY = 0, group = "LobbyDecor", id = "LB-NE-BENCH", replaces = {}, note = "against LW-N, faces the plaza (-Z), next to the photo booth" },
	{ asset = "AST-102_PottedPlant", x = 27, y = 0, z = -574, rotY = 0, group = "LobbyDecor", id = "LB-PHOTO-PLANT", replaces = {}, note = "flanks the photo booth front (booth X 28..34, procedural)" },
	{ asset = "AST-102_PottedPlant", x = 35, y = 0, z = -574, rotY = 0, group = "LobbyDecor", id = "LB-PHOTO-PLANT", replaces = {} },
	{ asset = "AST-034_TreeLarge", x = 44.5, y = 0, z = -569, rotY = 0, group = "LobbyDecor", id = "LB-NE-TREE", replaces = {} },

	---------------------------------------------------------------------------------------------
	-- 13. STREET LIGHTS (8), arms pointing into the plaza. String-light spans go from the mast ring (5, 16, -628.5) to
	--     each pole axis (the foot) at y 11.5 (V2-12.7). Real SpotLight on A, B, C, F, G, H; D and E Neon only (V2-10).
	--     Feet: A (-52, -671) B (44, -671) C (-52, -600) D (-19, -569) E (19, -569) F (44, -602) G (44, -638) H (-52, -640).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-036_StreetLightCurved", x = -50.717, y = 0, z = -669.717, rotY = 45, group = "LobbyLights", id = "LB-SL-A", replaces = {}, note = "foot (-52, -671), arm to +X+Z" },
	{ asset = "AST-036_LampHead", x = -49.458, y = 0, z = -668.458, rotY = 45, group = "LobbyLights", id = "LB-SL-A", replaces = {} },
	{ asset = "AST-036_StreetLightCurved", x = 42.717, y = 0, z = -669.717, rotY = -45, group = "LobbyLights", id = "LB-SL-B", replaces = {}, note = "foot (44, -671), arm to -X+Z" },
	{ asset = "AST-036_LampHead", x = 41.458, y = 0, z = -668.458, rotY = -45, group = "LobbyLights", id = "LB-SL-B", replaces = {} },
	{ asset = "AST-036_StreetLightCurved", x = -50.185, y = 0, z = -600, rotY = 90, group = "LobbyLights", id = "LB-SL-C", replaces = {}, note = "foot (-52, -600), arm to +X" },
	{ asset = "AST-036_LampHead", x = -48.405, y = 0, z = -600, rotY = 90, group = "LobbyLights", id = "LB-SL-C", replaces = {} },
	{ asset = "AST-036_StreetLightCurved", x = -19, y = 0, z = -570.815, rotY = 180, group = "LobbyLights", id = "LB-SL-D", replaces = {}, note = "foot (-19, -569), arm to -Z; inside LW-TRUCK; out of the class camera frame (check)" },
	{ asset = "AST-036_LampHead", x = -19, y = 0, z = -572.595, rotY = 180, group = "LobbyLights", id = "LB-SL-D", replaces = {} },
	{ asset = "AST-036_StreetLightCurved", x = 19, y = 0, z = -570.815, rotY = 180, group = "LobbyLights", id = "LB-SL-E", replaces = {}, note = "foot (19, -569), arm to -Z; out of the class camera frame (check)" },
	{ asset = "AST-036_LampHead", x = 19, y = 0, z = -572.595, rotY = 180, group = "LobbyLights", id = "LB-SL-E", replaces = {} },
	{ asset = "AST-036_StreetLightCurved", x = 42.185, y = 0, z = -602, rotY = -90, group = "LobbyLights", id = "LB-SL-F", replaces = {}, note = "foot (44, -602), arm to -X; frames START SHIFT (north)" },
	{ asset = "AST-036_LampHead", x = 40.405, y = 0, z = -602, rotY = -90, group = "LobbyLights", id = "LB-SL-F", replaces = {} },
	{ asset = "AST-036_StreetLightCurved", x = 42.185, y = 0, z = -638, rotY = -90, group = "LobbyLights", id = "LB-SL-G", replaces = {}, note = "foot (44, -638), arm to -X; frames START SHIFT (south)" },
	{ asset = "AST-036_LampHead", x = 40.405, y = 0, z = -638, rotY = -90, group = "LobbyLights", id = "LB-SL-G", replaces = {} },
	{ asset = "AST-036_StreetLightCurved", x = -50.185, y = 0, z = -640, rotY = 90, group = "LobbyLights", id = "LB-SL-H", replaces = {}, note = "foot (-52, -640), arm to +X" },
	{ asset = "AST-036_LampHead", x = -48.405, y = 0, z = -640, rotY = 90, group = "LobbyLights", id = "LB-SL-H", replaces = {} },
}
