--[[
	LOBBY "Bramble's Corner Dogs HQ" - placement table of the real assets.
	DATA ONLY. Status: Draft / Provisional (level-designer, 2026-10-11). Not gameplay code.
	Layout, points, lights and procedural pieces: docs/levels/LOBBY.md (source of truth for the numbers).

	==============================================================================================
	COORDINATES: WORLD. NOT MAP-01 COORDINATES. NO MAP_FRAME.
	==============================================================================================
	- x, y, z, rotY are WORLD values: pose = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotY), 0).
	- Do NOT feed this table to place_assets.luau Place.run(): Place.run applies MAP_FRAME (map_frame.luau, the 180
	  turn of MAP-01) and rebuilds/restores workspace.MAP01_Assets. Use a runner with the same build() rules
	  (part / parts / drop / pivot / copies / collide) but frameOf = identity and its own root (suggested
	  workspace.LOBBY_Assets). `replaces` is always empty (the lobby has no blockout).
	- Lobby box: X -30..30.4, Z -630..-570 (plaza floor X -30..28 + curb 28..30.4), floor top Y 0.
	  Centre ~ (0, 0, -600). MAP-01 is at world Z >= -60 (behind the HQ row, +Z); DevScenes at Z ~4000 untouched.
	- y = world height of the asset pivot (pivot = bottom centre, same as MAP-01). Plaza floor top = 0,
	  road asphalt top = -0.24 (road tiles at y -0.48 so the curb strip is flush with the plaza).

	FRONT CONVENTION (measured on MAP-01, same assets; rotY in WORLD):
	- Modelled assets (cart, trailer, stations, AST-024 sign, AST-034 bench/bin/mailbox, AST-104 stand,
	  AST-105 pedestals): front = LookVector (local -Z).
	  rotY 0 -> front faces -Z | 90 -> -X | 180 -> +Z | -90 (270) -> +X.
	- Kenney buildings AST-033_BuildingA/H and BG cards: storefront = local +Z (opposite):
	  rotY 0 -> storefront +Z | 90 -> +X | 180 -> -Z | 270 -> -X.
	- Street light AST-036: arm = local +Z, d = (sin rotY, cos rotY); pole pivot = foot + 1.815 * d,
	  LampHead pivot = pole pivot + 1.78 * d (same rotY, y = floor).
	- Cart AST-026 / trailer AST-027: queue side / service window = LookVector.
	- Front not measured (check in Studio, turn 180 if wrong): AST-035 cars, AST-037 flyer, AST-019 queue post/mark,
	  AST-047 barrier, AST-034 hydrant / street sign (symmetric enough).

	FIELDS (same as MAP-01_placements.luau): asset, x, y, z, rotY, group, id, replaces = {}, note
	  optional: part = { meshes to keep }, parts = { [mesh] = { x, y, z, rotX?, rotY?, rotZ?, size? } } (mesh centre in
	  the ASSET frame), drop = { meshes }, pivot = { x, y, z, rotY } (WORLD here), paint (AST-035 colour variant),
	  collide = false.

	OPEN POINTS: docs/levels/LOBBY.md section 15 (P-L1..P-L14).
]]

return {
	---------------------------------------------------------------------------------------------
	-- 1. FLOOR: plaza 3 x 3 sidewalk tiles scaled to 19.333 x 20 (X -30..28, Z -630..-570), top Y 0;
	--    two filler strips X 24.6..28 behind the back / front walls (between the last building and the road).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-032_SidewalkTile", x = -20.333, y = -0.48, z = -620, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 19.333, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR", replaces = {}, note = "plaza tile; top Y 0" },
	{ asset = "AST-032_SidewalkTile", x = -1.0, y = -0.48, z = -620, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 19.333, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 18.333, y = -0.48, z = -620, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 19.333, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -20.333, y = -0.48, z = -600, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 19.333, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -1.0, y = -0.48, z = -600, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 19.333, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 18.333, y = -0.48, z = -600, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 19.333, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -20.333, y = -0.48, z = -580, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 19.333, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = -1.0, y = -0.48, z = -580, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 19.333, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 18.333, y = -0.48, z = -580, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 19.333, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR", replaces = {} },
	{ asset = "AST-032_SidewalkTile", x = 26.3, y = -0.48, z = -560, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 3.4, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR-GAP", replaces = {}, note = "gap BK-4 / road, behind LW-N (Z -570..-550)" },
	{ asset = "AST-032_SidewalkTile", x = 26.3, y = -0.48, z = -640, rotY = 0, parts = { ["AST-032_SidewalkTile"] = { 0, 0.24, 0, size = { 3.4, 0.48, 20 } } }, group = "LobbyFloor", id = "LB-FLOOR-GAP", replaces = {}, note = "gap FR-4 / road, behind LW-S (Z -650..-630)" },

	---------------------------------------------------------------------------------------------
	-- 2. ROAD (east side, outside the play area): 4 straight tiles along Z (rotY 90), X 28..52, Z -648..-552.
	--    y -0.48: curb strips (X 28..30.4 and 49.6..52) top 0 = plaza; asphalt X 30.4..49.6 top -0.24.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-032_RoadStraight", x = 40, y = -0.48, z = -564, rotY = 90, group = "LobbyRoad", id = "LB-ROAD", replaces = {}, note = "curb top 0, asphalt -0.24" },
	{ asset = "AST-032_RoadStraight", x = 40, y = -0.48, z = -588, rotY = 90, group = "LobbyRoad", id = "LB-ROAD", replaces = {} },
	{ asset = "AST-032_RoadStraight", x = 40, y = -0.48, z = -612, rotY = 90, group = "LobbyRoad", id = "LB-ROAD", replaces = {} },
	{ asset = "AST-032_RoadStraight", x = 40, y = -0.48, z = -636, rotY = 90, group = "LobbyRoad", id = "LB-ROAD", replaces = {} },
	{ asset = "AST-047_Barrier", x = 40, y = -0.24, z = -555, rotY = 0, group = "LobbyRoad", id = "LB-BAR-N", replaces = {}, note = "road closed north (decor; the wall is LW-E)" },
	{ asset = "AST-047_Barrier", x = 40, y = -0.24, z = -645, rotY = 0, group = "LobbyRoad", id = "LB-BAR-S", replaces = {}, note = "road closed south" },

	---------------------------------------------------------------------------------------------
	-- 3. BACKDROP BUILDINGS. Front line on the play-area edge. Front offsets measured on MAP-01:
	--    BuildingA pivot 12.725 behind the front line, BuildingH 13.355. Storefront = local +Z.
	---------------------------------------------------------------------------------------------
	-- 3a. back row (+Z side, front line Z -570, storefront faces -Z: rotY 180). BK-3 carries the HQ neon (LOBBY.md 12.1).
	{ asset = "AST-033_BuildingH", x = -32.8, y = 0, z = -556.645, rotY = 180, group = "LobbyBackdrop", id = "LB-BK1", replaces = {}, note = "X -41..-24.6" },
	{ asset = "AST-033_BuildingA", x = -16.4, y = 0, z = -557.275, rotY = 180, group = "LobbyBackdrop", id = "LB-BK2", replaces = {} },
	{ asset = "AST-033_BuildingH", x = 0, y = 0, z = -556.645, rotY = 180, group = "LobbyBackdrop", id = "LB-BK3", replaces = {}, note = "HQ facade: CORNER DOGS HQ neon board at Z ~ -569.6 (check the wall plane by raycast)" },
	{ asset = "AST-033_BuildingA", x = 16.4, y = 0, z = -557.275, rotY = 180, group = "LobbyBackdrop", id = "LB-BK4", replaces = {}, note = "X 8.2..24.6" },
	-- 3b. front row (-Z side, front line Z -630, storefront faces +Z: rotY 0). Behind the spawn; codes mural in front of FR-2/FR-3.
	{ asset = "AST-033_BuildingA", x = -32.8, y = 0, z = -642.725, rotY = 0, group = "LobbyBackdrop", id = "LB-FR1", replaces = {} },
	{ asset = "AST-033_BuildingH", x = -16.4, y = 0, z = -643.355, rotY = 0, group = "LobbyBackdrop", id = "LB-FR2", replaces = {} },
	{ asset = "AST-033_BuildingA", x = 0, y = 0, z = -642.725, rotY = 0, group = "LobbyBackdrop", id = "LB-FR3", replaces = {} },
	{ asset = "AST-033_BuildingH", x = 16.4, y = 0, z = -643.355, rotY = 0, group = "LobbyBackdrop", id = "LB-FR4", replaces = {}, note = "X 8.2..24.6" },
	-- 3c. west side (front line X -30, storefront faces +X: rotY 90). Mostly hidden by the gem shop; tops read above it.
	{ asset = "AST-033_BuildingA", x = -42.725, y = 0, z = -578.2, rotY = 90, group = "LobbyBackdrop", id = "LB-LF1", replaces = {}, note = "Z -586.4..-570 (back-left corner, visible)" },
	{ asset = "AST-033_BuildingH", x = -43.355, y = 0, z = -594.6, rotY = 90, group = "LobbyBackdrop", id = "LB-LF2", replaces = {} },
	{ asset = "AST-033_BuildingA", x = -42.725, y = 0, z = -611.0, rotY = 90, group = "LobbyBackdrop", id = "LB-LF3", replaces = {} },
	{ asset = "AST-033_BuildingH", x = -43.455, y = 0, z = -621.8, rotY = 90, group = "LobbyBackdrop", id = "LB-LF4", replaces = {}, note = "overlaps LF3 by 5.6 in Z; set 0.1 back (front X -30.1) so the facades do not z-fight" },
	-- 3d. east side beyond the road (cards, > 30 studs from the play area; storefront faces -X: rotY 270)
	{ asset = "AST-033_BGCard_A", x = 53.5, y = 0, z = -566, rotY = 270, group = "LobbyBackdrop", id = "LB-RC1", replaces = {}, note = "Z -578..-554; check the card's front side (MAP-01 uses front = local +Z)" },
	{ asset = "AST-033_BGCard_C", x = 53.5, y = 0, z = -588, rotY = 270, group = "LobbyBackdrop", id = "LB-RC2", replaces = {}, note = "Z -598..-578" },
	{ asset = "AST-033_BGCard_B", x = 53.5, y = 0, z = -606, rotY = 270, group = "LobbyBackdrop", id = "LB-RC3", replaces = {}, note = "Z -614..-598" },
	{ asset = "AST-033_BGCard_A", x = 53.5, y = 0, z = -626, rotY = 270, group = "LobbyBackdrop", id = "LB-RC4", replaces = {}, note = "Z -638..-614" },
	{ asset = "AST-033_BGCard_C", x = 53.5, y = 0, z = -648, rotY = 270, group = "LobbyBackdrop", id = "LB-RC5", replaces = {}, note = "Z -658..-638" },
	-- 3e. road ends (close the street; card widened to cover X 24..52.4 including the gap strip)
	{ asset = "AST-033_BGCard_A", x = 38.2, y = 0, z = -550.5, rotY = 180, parts = { ["BG_Card_A"] = { 0, 13, 0, size = { 28.4, 26, 4.2 } } }, group = "LobbyBackdrop", id = "LB-RE-N", replaces = {}, note = "faces the plaza (-Z)" },
	{ asset = "AST-033_BGCard_A", x = 38.2, y = 0, z = -649.5, rotY = 0, parts = { ["BG_Card_A"] = { 0, 13, 0, size = { 28.4, 26, 4.2 } } }, group = "LobbyBackdrop", id = "LB-RE-S", replaces = {}, note = "faces the plaza (+Z)" },
	{ asset = "AST-102_BushLarge", x = 26.3, y = 0, z = -567, rotY = 0, group = "LobbyBackdrop", id = "LB-GAP-N", replaces = {}, note = "fills the 3.4 gap BK-4 / curb" },
	{ asset = "AST-102_BushLarge", x = 26.3, y = 0, z = -633, rotY = 0, group = "LobbyBackdrop", id = "LB-GAP-S", replaces = {}, note = "fills the 3.4 gap FR-4 / curb" },

	---------------------------------------------------------------------------------------------
	-- 4. HQ: the original Corner Cart on display, backdrop of the class stage. Pivot (0, 0, -572.8), rotY 0:
	--    queue side + skirt logo face the plaza (-Z), back at Z -570.66 (wall LW-N at -570).
	--    Stations = cart pivot + the same offsets as MAP-01 (cart rotY 0 in both frames; MAP-01 section 2a).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-026_CornerCart", x = 0, y = 0, z = -572.8, rotY = 0, parts = { ["Parasol_W"] = { -6.5, 5.926, -1.624, rotX = -6.3, size = { 12.9, 6.372, 10.014 } }, ["Parasol_E"] = { 6.5, 5.901, -1.77, rotX = -9 } }, group = "LobbyCart", id = "LB-CART", replaces = {}, note = "display only (no Vehicle tag, no Station tags); parasols tilted like MAP-01 (user hand edit)" },
	{ asset = "AST-012_RollerGrill", part = { "Grill_L1" }, x = -7.5, y = 3.0, z = -572.8, rotY = 180, group = "LobbyCart", id = "LB-CART-G", replaces = {}, note = "decor, no Station tag" },
	{ asset = "AST-013_RestRail", part = { "Rail_6" }, x = -3.5, y = 3.0, z = -572.8, rotY = 180, group = "LobbyCart", id = "LB-CART-R", replaces = {} },
	{ asset = "AST-015_BunCrate", x = -1, y = 3.0, z = -572.8, rotY = 180, group = "LobbyCart", id = "LB-CART-B", replaces = {} },
	{ asset = "AST-014_CuttingBoard", x = 1.5, y = 3.0, z = -572.8, rotY = 0, parts = { ["Knife"] = { 0, 0.163, -0.1, size = { 1.246, 0.083, 0.276 } }, ["Board"] = { 0, 0.06, 0.1, size = { 2.6, 0.12, 1.7 } } }, group = "LobbyCart", id = "LB-CART-T", replaces = {} },
	{ asset = "AST-017_ToppingGrid", x = 6, y = 3.0, z = -572.948, rotY = 180, group = "LobbyCart", id = "LB-CART-K", replaces = {} },
	{ asset = "AST-020_CashRegister", x = 12.143, y = 3.0, z = -572.639, rotY = 180, drop = { "DeliveryStand" }, pivot = { 10.743, 3.0, -572.639, 180 }, group = "LobbyCart", id = "LB-CART-DRAWER", replaces = {}, note = "same hand edit as MAP-01 DRAWER (pivot in WORLD)" },
	{ asset = "AST-042_VehiclePhone", part = { "Phone_Cart", "Cart_Body", "Cart_Handset", "Cart_Lamp" }, x = -9.1, y = 3.0, z = -572.46, rotY = -174.3, group = "LobbyCart", id = "LB-CART-PHONE", replaces = {}, note = "decor (no prompt); same offset as MAP-01 CART-PHONE" },
	{ asset = "AST-024_SignStand", x = -15.3, y = 0, z = -577.1, rotY = 0, parts = { ["AST-024_SignStand"] = { 0, 2.0, 0 } }, group = "LobbyCart", id = "LB-CART-SIGN", replaces = {}, note = "OPEN-style easel at the west end of the cart, faces the plaza; mesh centre +2.0 (MAP-01 OPEN needed +1.89 over the Pad: confirm)" },

	---------------------------------------------------------------------------------------------
	-- 5. CLASS STAGE dressing (stage, spot, rope, stage lights are procedural: LOBBY.md 12.6).
	--    Stage top Y 1.0, X -6..6, Z -584..-577. Rig on LOBBY-CLASS-STAGE (0, 1.02, -580.5) facing -Z.
	--    Nothing here may enter the class camera frame between the camera and the rig (LOBBY.md 11).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-102_PottedPlant", x = -5.3, y = 1.0, z = -577.6, rotY = 0, group = "LobbyStage", id = "LB-STAGE-PLANT", replaces = {}, note = "on the stage, back-left of the rig (in the class camera frame)" },
	{ asset = "AST-102_PottedPlant", x = 5.3, y = 1.0, z = -577.6, rotY = 0, group = "LobbyStage", id = "LB-STAGE-PLANT", replaces = {}, note = "on the stage, back-right of the rig" },
	{ asset = "AST-019_QueuePost", x = -7, y = 0, z = -584.7, rotY = 0, group = "LobbyStage", id = "LB-STAGE-ROPE", replaces = {}, note = "low rope (y 2.0) to X 7 is procedural; posts stay outside the camera frame (half width 6.5 at this depth)" },
	{ asset = "AST-019_QueuePost", x = 7, y = 0, z = -584.7, rotY = 0, group = "LobbyStage", id = "LB-STAGE-ROPE", replaces = {} },
	{ asset = "AST-034_Planter", x = -11.5, y = 0, z = -584.0, rotY = 0, group = "LobbyStage", id = "LB-STAGE-PLANTER", replaces = {}, note = "marks the end of the stage block (LW-STAGE X -16..16, Z -585..-570)" },
	{ asset = "AST-034_Planter", x = 11.5, y = 0, z = -584.0, rotY = 0, group = "LobbyStage", id = "LB-STAGE-PLANTER", replaces = {} },

	---------------------------------------------------------------------------------------------
	-- 6. GEM SHOP: Gear Stand kiosk (AST-104) on the west side, front faces +X (rotY -90), WITHOUT the roller
	--    shutters (= always open). Pivot (-25.5, 0, -600): front face X -22.03, Z -612.95..-587.05.
	--    Pedestals = stand pivot + 1.125 forward (+X) + local X offset along world +Z (same as MAP-01 GEAR_STAND).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-104_GearStand", x = -25.5, y = 0, z = -600, rotY = -90, group = "LobbyShop", id = "LB-SHOP", replaces = {}, note = "GEM SHOP neon on Neon_Upgrades -> WORLD (-22.0, 9.75, -600); name plates -> (-22.3, 9.75, -589.5 / -610.5); Opal counter in the middle is the shop counter (no NPC)" },
	{ asset = "AST-105_PedestalS1", x = -24.375, y = 0, z = -610, rotY = -90, group = "LobbyShop", id = "LB-SHOP-S1", replaces = {}, note = "best-value slot; Mini_Anchor at y 4.2 holds the procedural gem" },
	{ asset = "AST-105_Pedestal", x = -24.375, y = 0, z = -607, rotY = -90, group = "LobbyShop", id = "LB-SHOP-P5", replaces = {} },
	{ asset = "AST-105_Pedestal", x = -24.375, y = 0, z = -604, rotY = -90, group = "LobbyShop", id = "LB-SHOP-P4", replaces = {} },
	{ asset = "AST-105_Pedestal", x = -24.375, y = 0, z = -596, rotY = -90, group = "LobbyShop", id = "LB-SHOP-P3", replaces = {} },
	{ asset = "AST-105_Pedestal", x = -24.375, y = 0, z = -593, rotY = -90, group = "LobbyShop", id = "LB-SHOP-P2", replaces = {} },
	{ asset = "AST-105_Pedestal", x = -24.375, y = 0, z = -590, rotY = -90, group = "LobbyShop", id = "LB-SHOP-P1", replaces = {} },
	{ asset = "AST-102_PottedPlant", x = -21.2, y = 0, z = -614.5, rotY = 0, group = "LobbyShop", id = "LB-SHOP-PLANT", replaces = {} },
	{ asset = "AST-102_PottedPlant", x = -21.2, y = 0, z = -585.5, rotY = 0, group = "LobbyShop", id = "LB-SHOP-PLANT", replaces = {} },

	---------------------------------------------------------------------------------------------
	-- 7. SQUAD PADS (procedural discs, LOBBY.md 12.3) along the east curb, centres X 20, Z -588 / -598 / -608 / -618,
	--    top Y 0.3. Per pad: board AST-024 on the curb side (faces -X, the plaza) + 4 slot marks AST-019.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-024_SignStand", x = 25.3, y = 0, z = -588, rotY = 90, parts = { ["AST-024_SignStand"] = { 0, 2.0, 0 } }, group = "LobbySquad", id = "LB-SQ1-BOARD", replaces = {}, note = "SurfaceGui SQUAD 1 n/4 + Prompt_Start_1 (owner); faces -X" },
	{ asset = "AST-024_SignStand", x = 25.3, y = 0, z = -598, rotY = 90, parts = { ["AST-024_SignStand"] = { 0, 2.0, 0 } }, group = "LobbySquad", id = "LB-SQ2-BOARD", replaces = {} },
	{ asset = "AST-024_SignStand", x = 25.3, y = 0, z = -608, rotY = 90, parts = { ["AST-024_SignStand"] = { 0, 2.0, 0 } }, group = "LobbySquad", id = "LB-SQ3-BOARD", replaces = {} },
	{ asset = "AST-024_SignStand", x = 25.3, y = 0, z = -618, rotY = 90, parts = { ["AST-024_SignStand"] = { 0, 2.0, 0 } }, group = "LobbySquad", id = "LB-SQ4-BOARD", replaces = {} },
	-- slot marks (Slot_1..4 of each pad): pad centre +-1.8 in X and Z, on the pad top (0.3)
	{ asset = "AST-019_QueueMark", x = 18.2, y = 0.3, z = -589.8, rotY = 90, group = "LobbySquad", id = "LB-SQ1-SLOT1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 21.8, y = 0.3, z = -589.8, rotY = 90, group = "LobbySquad", id = "LB-SQ1-SLOT2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 18.2, y = 0.3, z = -586.2, rotY = 90, group = "LobbySquad", id = "LB-SQ1-SLOT3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 21.8, y = 0.3, z = -586.2, rotY = 90, group = "LobbySquad", id = "LB-SQ1-SLOT4", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 18.2, y = 0.3, z = -599.8, rotY = 90, group = "LobbySquad", id = "LB-SQ2-SLOT1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 21.8, y = 0.3, z = -599.8, rotY = 90, group = "LobbySquad", id = "LB-SQ2-SLOT2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 18.2, y = 0.3, z = -596.2, rotY = 90, group = "LobbySquad", id = "LB-SQ2-SLOT3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 21.8, y = 0.3, z = -596.2, rotY = 90, group = "LobbySquad", id = "LB-SQ2-SLOT4", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 18.2, y = 0.3, z = -609.8, rotY = 90, group = "LobbySquad", id = "LB-SQ3-SLOT1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 21.8, y = 0.3, z = -609.8, rotY = 90, group = "LobbySquad", id = "LB-SQ3-SLOT2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 18.2, y = 0.3, z = -606.2, rotY = 90, group = "LobbySquad", id = "LB-SQ3-SLOT3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 21.8, y = 0.3, z = -606.2, rotY = 90, group = "LobbySquad", id = "LB-SQ3-SLOT4", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 18.2, y = 0.3, z = -619.8, rotY = 90, group = "LobbySquad", id = "LB-SQ4-SLOT1", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 21.8, y = 0.3, z = -619.8, rotY = 90, group = "LobbySquad", id = "LB-SQ4-SLOT2", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 18.2, y = 0.3, z = -616.2, rotY = 90, group = "LobbySquad", id = "LB-SQ4-SLOT3", replaces = {} },
	{ asset = "AST-019_QueueMark", x = 21.8, y = 0.3, z = -616.2, rotY = 90, group = "LobbySquad", id = "LB-SQ4-SLOT4", replaces = {} },

	---------------------------------------------------------------------------------------------
	-- 8. START SHIFT: crew van parked on the road against the curb, side to the plaza; START SHIFT neon sign on the
	--    curb above LOBBY-START (procedural, LOBBY.md 12.4). Trailer across as a teaser of the night (can go).
	---------------------------------------------------------------------------------------------
	{ asset = "AST-035_CarVan", x = 34.5, y = -0.24, z = -603, rotY = 0, paint = "Butter", group = "LobbyStart", id = "LB-VAN", replaces = {}, note = "13 long (Z -609.5..-596.5), 6.35 tall; width ~6 assumed (X ~31.5..37.5). Crew Van colours (Ketchup/Cream + logo) pending (P-L7); front side not measured" },
	{ asset = "AST-027_OpenLateTrailer", x = 44, y = -0.24, z = -580, rotY = 90, group = "LobbyStart", id = "LB-TRL", replaces = {}, note = "teaser: window faces the plaza (-X), body X 38..50 / Z -594..-566, hitch to Z ~-561.5; out of the class camera frame. Shell only, no Vehicle tag" },
	{ asset = "AST-035_CarSedan", x = 45, y = -0.24, z = -628, rotY = 180, paint = "Peach", group = "LobbyStart", id = "LB-CAR", replaces = {}, note = "parked, life on the street" },
	{ asset = "AST-034_Hydrant", x = 27, y = 0, z = -622.5, rotY = 0, group = "LobbyStart", id = "LB-HYDRANT", replaces = {} },
	{ asset = "AST-034_StreetSign", x = 26.8, y = 0, z = -628.2, rotY = 0, group = "LobbyStart", id = "LB-STREETSIGN", replaces = {}, note = "street name decal: narrative-writer (P-L11)" },

	---------------------------------------------------------------------------------------------
	-- 9. CODES corner (front-left): mural is procedural (LOBBY.md 12.5); flyers pinned on it, picnic table, bench.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-037_Flyer", x = -12.7, y = 4.8, z = -626.25, rotY = 175, collide = false, group = "LobbyCodes", id = "LB-CODES-FLYER", replaces = {}, note = "pinned on the mural face (Z -626.4); front assumed = LookVector (+Z at 180): check; pivot assumed centre" },
	{ asset = "AST-037_Flyer", x = -7.4, y = 2.6, z = -626.25, rotY = 186, collide = false, group = "LobbyCodes", id = "LB-CODES-FLYER", replaces = {} },
	{ asset = "AST-100_PicnicTable", x = -21, y = 0, z = -624.5, rotY = 0, group = "LobbyCodes", id = "LB-PICNIC", replaces = {}, note = "5.38 x 4.34: X -23.7..-18.3, clear of SL-A base (-26, -626)" },
	{ asset = "AST-034_TrashCan", x = -3.5, y = 0, z = -627.6, rotY = 180, group = "LobbyCodes", id = "LB-BIN", replaces = {}, note = "decor, no prompt" },
	{ asset = "AST-034_Mailbox", x = -27.6, y = 0, z = -617.5, rotY = -90, group = "LobbyCodes", id = "LB-MAILBOX", replaces = {}, note = "faces +X" },

	---------------------------------------------------------------------------------------------
	-- 10. PLAZA DECOR: benches, trees, welcome easel.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-034_ParkBench", x = 13, y = 0, z = -627.4, rotY = 180, group = "LobbyDecor", id = "LB-BENCH-1", replaces = {}, note = "faces the plaza (+Z)" },
	{ asset = "AST-034_ParkBench", x = -21.5, y = 0, z = -572.6, rotY = 0, group = "LobbyDecor", id = "LB-BENCH-2", replaces = {}, note = "back-left corner, faces the plaza (-Z)" },
	{ asset = "AST-034_TreeSmall", x = -24.5, y = 0, z = -582, rotY = 0, group = "LobbyDecor", id = "LB-TREE-1", replaces = {} },
	{ asset = "AST-034_TreeSmall", x = 21, y = 0, z = -580.5, rotY = 0, group = "LobbyDecor", id = "LB-TREE-2", replaces = {}, note = "behind pad 1 (edge Z -584)" },
	{ asset = "AST-024_SignStand", x = 6.5, y = 0, z = -597.5, rotY = 0, parts = { ["AST-024_SignStand"] = { 0, 2.0, 0 } }, group = "LobbyDecor", id = "LB-WELCOME", replaces = {}, note = "faces the spawn (-Z): WELCOME, CREW! + 4 arrows (SurfaceGui, text P-L11)" },

	---------------------------------------------------------------------------------------------
	-- 11. STREET LIGHTS at the 4 corners, arms pointing into the plaza; string-light spans tie to the pole axis
	--     (the feet) at y 11.5 (LOBBY.md 12.7). Feet: SL-A (-26, -626), SL-B (24, -626), SL-C (-26, -576), SL-D (24, -576).
	--     SpotLight per LampHead: LOBBY.md 10.
	---------------------------------------------------------------------------------------------
	{ asset = "AST-036_StreetLightCurved", x = -24.717, y = 0, z = -624.717, rotY = 45, group = "LobbyLights", id = "LB-SL-A", replaces = {}, note = "foot (-26, -626), arm to +X+Z" },
	{ asset = "AST-036_LampHead", x = -23.458, y = 0, z = -623.458, rotY = 45, group = "LobbyLights", id = "LB-SL-A", replaces = {} },
	{ asset = "AST-036_StreetLightCurved", x = 22.717, y = 0, z = -624.717, rotY = -45, group = "LobbyLights", id = "LB-SL-B", replaces = {}, note = "foot (24, -626), arm to -X+Z" },
	{ asset = "AST-036_LampHead", x = 21.458, y = 0, z = -623.458, rotY = -45, group = "LobbyLights", id = "LB-SL-B", replaces = {} },
	{ asset = "AST-036_StreetLightCurved", x = -24.717, y = 0, z = -577.283, rotY = 135, group = "LobbyLights", id = "LB-SL-C", replaces = {}, note = "foot (-26, -576), arm to +X-Z" },
	{ asset = "AST-036_LampHead", x = -23.458, y = 0, z = -578.542, rotY = 135, group = "LobbyLights", id = "LB-SL-C", replaces = {} },
	{ asset = "AST-036_StreetLightCurved", x = 22.717, y = 0, z = -577.283, rotY = 225, group = "LobbyLights", id = "LB-SL-D", replaces = {}, note = "foot (24, -576), arm to -X-Z" },
	{ asset = "AST-036_LampHead", x = 21.458, y = 0, z = -578.542, rotY = 225, group = "LobbyLights", id = "LB-SL-D", replaces = {} },
}
