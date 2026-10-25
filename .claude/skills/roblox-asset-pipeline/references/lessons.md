# Lessons (failure → fix). Add new ones at the bottom with the date.

1. Props built from stacked Parts looked artificial (coffee leaking, floating handle, elliptical cylinders where
   Size.Y≠Size.Z) → real meshes; Part cylinders only with Y = Z; CSG or Blender for hollow/curved.
2. Procedural "painted" bake on Kenney meshes looked worse than the pack atlas (pale, lost colour) → test
   painted vs atlas side by side in Studio before committing to textures.
3. Pack names lie (hot-dog-raw = sausage only, cup = mug) → look at previews before mapping.
4. KayKit furniture proportions (1:2) explode at game scale → box scale to the sheet, stretch only parts that grow.
5. Burger-bun crate = 2,772 tris (sesame seeds) → delete islands + rebuild box (648 tris with hot dog buns).
6. Stool "flatten" by stacking a new disc left a gap; user's way (F + Ctrl+T) is right → delete dent island,
   weld, fill only the inner loop, copy neighbour UVs.
7. Mirrored glTF nodes (scale -1) gave inverted faces in Roblox → flip normals when determinant < 0.
8. Z-fight: coplanar overlaps between islands (tray lining, wire segments, flyer tape) → area-based checker +
   fix_zfight; crank knob through its arm → move knob to the arm's outer face.
9. FBX imported at 100× → `global_scale=0.01`; FBX `axis_forward` ignored by Roblox → rotate geometry 180°.
10. Textures missing after import → `embed_textures=True`; alpha-mix materials still don't embed → upload PNGs.
11. Placement author assumed "front = +Z" for own models (measured in Blender) → 50 entries 180° off; lamp
    heads behind poles; trailer window facing away from the queue → raycast probe in Studio, fix the table.
12. Two folders with the same name ("Trailer" day/night) broke the layer swap → prefix night folders.
13. A measurement relayed by an agent ("cargo ~2 deep") was wrong (8.37) → re-measure geometry before deciding.
14. Windows WMI hang froze every headless Blender → `_wmi` shadow wrapper (bl.sh); tasklist/wmic hang too.
15. Studio captures black when the window is minimised → probes instead, retry later.
16. EditableMesh previews: engine does not recentre vertices; previews may not survive a reload → upload for real.
17. Group-owned place → upload with `groupId` creator; the key must have group asset permission.
18. User-tuned previews (gondola 8 → 4.5 wide, long car proportions) must be written back to sheets/sources.
19. (2026-10-10) Mart windows showed the whole colormap tiled: Kenney glass is a separate object with a flat-colour
    material (no image, alpha 0.5, UVs -11..27); joining it into the atlas mesh made it read the atlas → the
    exporter now collapses flat-material UVs onto the nearest atlas texel and keeps glass as a separate "Glass"
    part; the placement runner sets Glass* parts to Transparency 0.5. Scan packs for untextured materials before export.
20. (2026-10-10) Boxy heads with modelled eyes looked off-reference → one round/oval head mesh + face shell with a
    standard UV; expressions are textures (Normal/Happy/Smile/Sad/Fainted/Night). The face shell needs
    SurfaceAppearance AlphaMode=Transparency (a TextureID paints transparent texels with the part Color);
    ColorMap is not script-settable at runtime → keep one SurfaceAppearance per expression in
    ReplicatedStorage.CrewExpressions and clone it to swap (Crew.setExpression).
21. (2026-10-10) Taller heads moved HatAttachment +0.30 but the builder used the cap's FBX position → cap over the
    eyes. When a head changes height, move every accessory that rides on its attachments (capRaise).
22. (2026-10-10) Eyes looked droopy/stretched from the side: the face shell wrapped around the head sides, so the
    eye ovals near the UV edge projected onto curved faces → keep only faces with normal·front ≥ 0.5 in the shell,
    move eyes inward/up (u 0.34/0.66), narrow them, one small top-right highlight. Check faces at 3/4 and profile.
    Not enough: the eye bottom still sat on the snout's upper slope and "slid down" it in profile, and the coarse
    lattice (22 x 10) showed facet lines. Fix that worked: compact oval snout bump A*(1-r2)^1.5 that ends below the
    eyes, longer below its centre (round chin), extra rings in the eye/snout zone, shell normals copied from the head.
    Always render 60 and 75 degree close-ups of the eyes before uploading.
23. (2026-10-10) A downloaded model with flat (untextured) materials (black POS) would arrive grey in Roblox and a
    MeshPart has one Color → remap its materials onto atlas bands (uv_band) so the FBX embeds the atlas.
24. (2026-10-10) Grid/station labels must face the side the PLAYER works from: check the operator side in Studio
    (which row is nearest) before orienting labels/locks; an agent oriented each row "outward" and hid half of them.
25. (2026-10-10) Multi-part assets with protruding fronts (portico, frames) have a bbox centre != origin; whether
    the Roblox model pivot ends up at the FBX origin or at the bbox centre, a 1-stud offset appears → recentre every
    asset so the mesh bbox base centre IS the origin, then compute the placement from the old anchor point.
26. (2026-10-10) Overlays on pack facades (doors, signs) need the facade measured on the EXPORTED FBX (re-import a
    copy in the scratchpad: importing next to the file drops a .fbm folder). Their world position is the same for
    either axis convention as long as the building faces the street; flag if the table's Kenney rotY is ever fixed.
27. (2026-10-10) Kenney City Kit buildings scaled to the street are small inside (building-e: awning at 4.74, door
    3.9 tall; building-a ground floor 7.5) → check door clearance against the 5-stud character before promising a
    4 x 7.5 door on a pack facade.
28. (2026-10-10) Anomaly windows (ANM-006): pack windows scaled with the building (1.35 stud) do not read at 70 studs →
    rebuild the floor with 3 x 3.6 windows and keep each anomaly window as its own objects (glass / Lit behind /
    curtain / waver slot) so states are visibility swaps, not UV changes.
29. (2026-10-10) Icon sheet (AST-071): Blender `render.filepath` with a RELATIVE `--out` wrote to `C:/renders` (Blender's
    cwd, not the shell's) → always pass absolute output paths to bl.sh scripts. Plain Python (numpy/scipy) also hung
    on the WMI query → run it with `PYTHONPATH=<skill>/scripts/blender/nowmi` too. A scratch file named `inspect.py`
    shadowed the stdlib and broke numpy → never name helper scripts after stdlib modules.
30. (2026-10-10) Icons from models: ortho camera framed on the projected vertex extent, render 512 with view transform
    Standard (atlas colours stay true), crop alpha bbox, outline by distance-transform dilation (4 px at 128), light
    fill under the silhouette so glass bottles don't go see-through, downscale 4x in premultiplied alpha (RGBa).
    Heads made for a cap look flat-topped without it: render portraits with the cap. Generic pack shapes (bags/cans)
    need a per-item colour ramp (RGBToBW → ColorRamp) plus an ingredient badge to tell them apart at 32 px.
29. (2026-10-10) Head accessories fitted by raycasting from the head centre outward hit internal faces first → dome
    too low, head poked through. Cast from OUTSIDE inward (outermost surface) and take the max over all species plus
    an angular-neighbourhood envelope of head verts; low-poly domes sag between rings on boxy heads.
30. (2026-10-10) Boolean ear slots on an open (single-sided) dome leave cutter walls/leftover faces that collide with
    the ears; after the boolean delete faces whose vertices ALL lie inside the cutter ellipse and re-orient normals.
    Verify every accessory against all species kits with a BVH overlap sweep (raise/scale search) → per-species
    offsets JSON; hand-held pieces need an explicit Anchor (bbox centre is nearer the leg than the arm).
31. (2026-10-11) A pack piece exported as ONE mesh (Mart door: wall + frame + 2 leaves + handles) cannot animate. Split an
    already-exported FBX in headless Blender: import with `global_scale=100` (object scale 0.01 + rot Z 180 baked by our
    exporter), apply the object matrix and rotate Z 180 back to the +Y-front convention, split by connected islands
    classified by bbox (leaf = inside the doorway y/z box and entirely x<0 or x>0; wall quads that merely share a y
    plane are frame), set each leaf's origin at its hinge edge, pack the image, save the .blend, then re-export with
    export_import.py `--only` (it rewrites _export_log.json with just that file: `git checkout` it). Verify the union of
    world vertices equals the original (SAME_VERTS). A new Open Cloud upload needs the old key renamed in _asset_ids.json
    (the uploader skips known names). Open Cloud keys cannot read asset-delivery (403): resolve MeshId/TextureID in Studio
    with InsertService:LoadAsset. Never name scratch files common.py/insp.py in a shared scratchpad (overwrites).
32. (2026-10-11) First-person counter game: the player's eye is only ~0.7 over a 2.6-high counter, so a window SILL at the old
    counter height (3.5) plus tall stations hid the customers. Lowering a counter baked into a shell mesh = piecewise
    Z remap in Blender (squash the cabinet/skirt linearly, SHIFT the window-sill ring rigidly, keep the head), move
    the matching Mount_* empties, and in Studio swap MeshId/TextureID per part from InsertService:LoadAsset(new) and
    move each MeshPart by its centre delta computed in the Body frame (old vs new loaded asset), plus Size from the
    new mesh (MeshPart scales the mesh to Size). Re-bake WeldConstraints after moving parts. Update every bind/check
    constant that encodes the counter height (pivot + 5.5 appeared in 4 files). Scripted, idempotent via an attribute.
33. (2026-10-11) "Orange feet sunk in the floor" on a bench were NOT geometry below the floor: the pack cabinet's U handle
    was at Z 0.25 (floor level) after the bench reuse. Measure first (z-level histogram of verts, island list) before
    moving the asset; fix = translate the handle islands to the door top (translation, not a mirror: mirroring flips
    normals). A source .blend missing for an exported asset: re-import the FBX copy in the scratchpad
    (global_scale=100, bake matrix, rotate Z 180), pack the image, save the .blend, edit, re-export with --only.
34. (2026-10-12) "Wrong product on the shelf" (ketchup/mustard showed a milk carton): the Kenney Mini Market shelves
    (shelf-boxes / shelf-bags) have their STOCK BAKED into the mesh; no script placed it. Strip it in Blender by colormap
    column (frame faces u 0.2 / 0.5, stock u 0.3 / 0.6 / 0.8 on shelf-boxes; faces are unwelded quads, so classify by
    face-centre UV, not by island), re-export as `<Name>Bare` (bbox top drops: the centre moves down by half the delta,
    bottom stays on the floor), upload under a NEW name, then in Studio clone-swap the MeshPart (MeshId is not scriptable)
    and put the real product packs on the board tops as anchored, non-colliding clones keyed off the BUY-* anchors.
35. (2026-10-12) "Closed cabinet with nothing inside" (Mart dairy fridge): when a product must be SEEN in a pack piece that is a
    solid shell, rebuild it as separate MeshParts by role (Body / Trim / Doors / Shelves / Led) with the SAME bbox, pivot and
    door side as the old export, so the live CFrame stays valid. Transparency, Material (Glass / Neon) and Color tint are
    per-MeshPart properties set in Studio, not baked: keep glass panes and LED strips as their own objects and a white
    flat atlas band for parts that get a Color tint (Teal trim). Frame check: import the old and the new FBX
    (global_scale=100) and print the world bboxes: doors must sit on the same side. Roblox local = (x, z - h/2, -y) of the
    Blender source around the bbox centre, so a snippet can place props from the asset frame; keep the assembly bbox equal
    to the old mesh and assert it. In the snippet find live instances by MeshId / name (never coordinates: the owner moves
    things), clone-swap each part, move children / welds / attributes to the Body, keep the hand-edit Size factor.
36. (2026-10-12) "Texture the lobby" (flat lilac/white floor made of Kenney mesh tiles): do NOT re-model or Place.run. Generate seamless
    tiles in numpy (noise with scipy `gaussian_filter(mode='wrap')`, joints centred on the tile edge, darker than the old floor
    because the Lobby preset is brightness 1.6 + amber), upload via upload_image (HTTP server on the repo ROOT; delete the copies
    after), then add child `Texture`s (Face Top, StudsPerTile 8, second transparent stain Texture at ZIndex 2) to the MeshParts: it
    works on MeshPart tops, `Color3` on the Texture tints (keeps semantic colours, e.g. brick on the red stage). Names prefixed
    `TexLobby_` make the snippet idempotent/UNDO without touching the originals. Textures of a just-uploaded asset appear blank for a
    while: wait/recapture before judging. Edit lighting is cold: judge the colour in Play (`workspace:SetAttribute("ServerRoleOverride",
    "Lobby")`, start_stop_play, then RESTORE the owner's attribute: it was "Round"). Run python helper scripts WITHOUT `-I` when they
    need numpy (isolated mode drops user site-packages).
37. (2026-10-12) "Replace a machine by a real-looking grill" (Sell Hotdogs AST-120): no pack has a bar grill with loose bars, so it was
    modelled with toylib (1,060 tris: open firebox Base + Frame + 14 Bar_n + drip Tray + Burner + Flame + knobs). Rules that worked:
    each bar its own cylinder (6 sides, 20 tris) in a LIGHT atlas band (0,4 top slice) because Roblox Color/Neon multiplies the texture,
    a dark band could never glow; flames one joined object (single Transparency/Neon switch); empties `Slot_n` parented to Base with
    the food centre = bar top + half the food diameter (FlipCenter). Measure the food first (headless FBX import: sausage 1.2 x 0.24)
    and derive the layout from it. Do NOT drive the user's live Blender MCP scene when it holds their own rig work (scene had 47 meshes
    of an armature): build and render headless (`bl.sh` + toylib.render, view with Read) and save straight to Assets/blender.
    `look` direction (0,0.01,1) degenerates the camera (came out as a front view): use (0.01,-0.01,1) or a tiny X offset for top views.
    overlap_check args: `--root Assets/blender --files equipment/X.blend` (relative to the blender folder, not Assets).
38. (2026-10-14) "Procedural meshes show inside-out in Studio" (AST-061 bugs and slimes): script-built ellipsoids/tubes had 80-84 of
    ~90 faces pointing inward; the object matrix was fine (det +1), the winding of the builder was wrong. Fix in the builder
    (`remove_doubles` + `recalc_face_normals`), recalc again after a boolean, orient open cones by hand, then verify by ray test and
    re-run on the regenerated .blend (0 inverted). Never skip: it passes every size/pivot/texture check.
39. (2026-10-14) "The bite nobody sees" (AST-061 bun): a 3-tooth bite, cream on cream, vanished at game distance. Make marks big,
    contrasting in value (grayscale test) and checked from the player's camera, not only in the 3/4 render.
40. (2026-10-14) "Yellow coat turns black at night" (AST-059 accessory): `Dress` swaps every piece whose TextureID is the Day atlas
    for the Night atlas, and the yellow cell is near-black there. Accessories that must keep their colour need a keep-atlas rule
    (attribute read by Dress) or their own texture. Check every accessory in Day, Mid and Night.
41. (2026-10-14) "Wrong scale after upload": the `Assets/models` FBX carry Lcl Scaling 100 in the nodes; the `Assets/import` FBX (what
    Studio uses) are global_scale 0.01 with no Lcl Scaling and the same vertices. Re-export through the import procedure; calibrate
    with `LoadAsset` (sausage 1.2 studs).
42. (2026-10-14) "Blender MCP dropped mid-task": an agent called `read_factory_settings` on the live connection and killed it (answer
    `Not connected`). Never reset the live Blender from an agent; go headless. Fallback keeps the work reproducible (script + .blend).
43. (2026-10-14) "One white pixel row for the whole coat": the R6 kit torso/legs UVs sample one texel row, so a texture outfit can only
    make horizontal bands (no hood, buttons or zip). Hood, cape and anything with form must be 3D accessories (ceiling 400 tris per
    sheet, raise it if the owner agrees: models are light).

44. (2026-10-17) "Scale the vehicle mesh up" (Sell Hotdogs, trailer expandido): the AST-027 Body mesh had a 21.75-wide window and SOLID
    end/back walls (measured by a raycast grid from outside), so no drive-thru window or pantry door could exist in it, and a
    1.35 x 1.48 stretch would bend its trims. Probe a shell mesh's openings by raycast BEFORE deciding to reuse it; when the plan
    needs openings the mesh lacks, rebuild the shell as a Part kit with the same read (rounded corners = vertical cylinders r 1,
    rounded roof edge = horizontal cylinders + corner balls, livery bands as 0.07 skins) and reuse the mesh's separate pieces.
45. (2026-10-17) A cloned Model placed with `PivotTo(T * src:GetPivot())` jumped 2.2 studs after the owner reset its WorldPivot in
    Studio. Place clones part by part from the source (`part.CFrame = T * srcPart.CFrame`), then set WorldPivot; key parts by a
    path WITH the ordinal of same-named siblings (`Label#2`), or the second "Label" lands on the first (z-fight + missing label).
46. (2026-10-17) Owner hand edits vs an idempotent snippet: add a `diff` mode that builds into a scratch folder with the same code,
    compares part by part (CFrame, Size, Color, Material, Transparency, CanCollide; deleted / new) and moved external items, and
    emits an OVERRIDES table that the build applies last. Edits that move generated pieces become data, and `diff = 0` proves the
    script and the place agree before any rebuild.
47. (2026-10-17) Z-fight sweep for Part kits: compare the 6 world faces of every axis-aligned BasePart, same facing, same plane
    (±0.004), overlap area > 0.01. The worst visible offenders were trims built with the SAME thin extent as the skin they sit on
    (fix: trim 0.03 proud on the thin axis), wall tops flush with counter tops, jambs flush with wall ends (jamb 0.06 proud).
48. (2026-10-17) Doors the player must use: 5 x 8 clear, leaves opened flat on the wall with CanCollide false, locks as welded
    parts of the leaf (a loose lock part fell/floated), and an R6 Blockcast sweep (2 x 4.6 x 1, RespectCanCollide) along every
    route instead of eyeballing captures.
49. (2026-10-17) Studio is shared: another agent's Play session blocks Edit (execute_luau "Edit datamodel not available"); read the
    Server DM read-only meanwhile and never stop someone else's Play. screen_capture can return the PREVIOUS request's image when
    two captures are sent in parallel: send captures one at a time.
50. (2026-10-21, Halloween overlay) Seasonal decor = its own workspace folder built by an idempotent placement snippet (destroy +
    rebuild), never inside the map root; served to Studio by `python -m http.server` + HttpService:GetAsync + loadstring instead of
    pasting the file into execute_luau. With StreamingEnabled the folder reaches the client AFTER controllers start: set
    ModelStreamingMode Persistent on the models and let the client pick pieces up lazily (scan once a second for ~30 s).
51. (2026-10-21) Flat "corner" props (cobwebs) made in the Blender XZ plane run along the model's local +X in Roblox after the
    exporter's 180 deg turn - verify the direction with one capture before placing all corners (all four came out mirrored).
52. (2026-10-21) A liquid disc sitting under a container rim is invisible from a player's eye height: dome it (scale Y up and lift)
    at placement time. In a dark night preset only Neon details read: plain props vanish, so swap fillers for glowing variants.
53. (2026-10-21) Concave outlines (moon crescent) through bmesh ear-clip can fill the hollow; build them as a quad strip between
    matching outer/inner points. Facial features slabbed onto a curved body need `lift` > the facet sag (cos(pi/segs)) or they sink.
54. (2026-10-25) A MeshPart `TextureID` is drawn ignoring its alpha (probe: magenta part + texture with alpha-0 texels
    showed the RGB stored under them, not the magenta). Where the part Color must show through the texture (fur, tint
    masks), wear it as a SurfaceAppearance with AlphaMode Overlay: ColorMap is Plugin-only, so build one template per
    texture id in edit mode and clone it at runtime. Measured on Sell Hotdogs outfit sheets (grey hands on every species).
