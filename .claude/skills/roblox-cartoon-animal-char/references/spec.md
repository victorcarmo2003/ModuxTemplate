# Body, rig and accessories

Axes: Blender +Y = front, Z up, 1 unit = 1 stud. Roblox after export: -Z front, Y up. Character stands on y = 0.

## Body (common to every species) — `scripts/body/crew_base.py`

| Part | Size (X × Y up × Z) | Centre (Roblox) | Tris | Note |
|---|---|---|---|---|
| HumanoidRootPart | 2 × 2 × 1 | (0, 3, 0) | 12 | invisible; a plain Part works in game |
| Torso | 2 × 2 × 1 | (0, 3, 0) | 76 | exact R6 box |
| Left/Right Arm | 1 × 2 × 1 | (∓1.5, 3, 0) | 108 | exact R6 box, hands = fur by alpha |
| Left/Right Leg | 1 × 2 × 1 | (∓0.5, 1, 0) | 92 | exact R6 box |
| Head (round, per species) | ≈ 2.85 × 2.05 × 2.5 | base y 3.95, top 6.00 | 728 | see heads.md |
| Cap (accessory) | 2.44 × 1.04 × 2.69 | y 5.34 (+0.30 on round heads) | 224 | `HatAttachment`; ears-up species use Cap_EarsUp |
| Apron (accessory) | 1.84 × 2.35 × 0.675 | (0, 2.875, -0.44) | 92 | `BodyFrontAttachment`, flat logo panel |

Keep Torso/limbs at the exact R6 boxes: then every Motor6D except `Neck.C1` is stock R6 and default
Animate/emotes/tools work. Object origins on the joints only for posing in Blender; in Roblox a MeshPart CFrame is the
bbox centre, so C1 is solved from the rest pose: `C1 = part1.CFrame:ToObjectSpace(part0.CFrame * C0)`.

Stock C0 (Part0 side): RootJoint/Neck `(0, 0|1, 0, -1,0,0, 0,0,1, 0,1,0)`; Shoulders `(±1, 0.5, 0, 0,0,±1, 0,1,0, ∓1,0,0)`;
Hips `(±1, -1, 0, ...)`. Neck C1 per species ≈ `(0, -0.975, z_off)` — z_off = head bbox centre depth (snout moves it).

Attachments (part-local): Head `HatAttachment`/`HairAttachment` (0, top, 0), `FaceFrontAttachment` (0, 0, -front),
`FaceCenterAttachment`, `EarLeft/RightAttachment` (±0.94, +0.815(+0.30), 0) rotated ±30° about Z,
`SnoutAttachment`; Torso `NeckAttachment`, `BodyFront/Back`, `Left/RightCollar`, `WaistFront/Back/Center`,
`TailAttachment` (0, -0.75, +0.5); arms `Left/RightGripAttachment`. Empties are NOT imported as Attachments from
FBX: keep them in a `_joints.json` and create them in Studio.

Wave/arm poses: the R6 shoulder pivot is at the inner edge of the arm; a big head gets hit by a sideways wave —
test wave forward-and-out, holding a tool, running 45-60° (`crew_pose.py` renders + penetration report).

## Accessories per species — `scripts/accessories/animals.py`

- `Ears_<A>` (one mesh with both ears, welded by EarLeftAttachment), `Tail_<A>` (TailAttachment), extras
  (`Shell_Turtle` on the back, `Beak_Owl` on SnoutAttachment). Coloured from the colour atlas (uv bands).
- Ear types: pointed (cat, fox: inner pink/white, black tips), rabbit long, round (bear, panda), tufts (owl),
  floppy (dog, hangs on the head sides, outside the cap). Turtle none.
- Ears-up species need a cap WITH ear holes (one `Cap_EarsUp` for all, holes at the fixed ear sockets); floppy/none
  use the plain cap.
- When the head shape changes, re-check ear-to-head gap (floppy ears shift by the head half-width at ear height) and
  cap clearance (`heads/capcheck.py`).

## Fur colours (example `templates/colors_example.json`)
`fur` (main, = MeshPart.Color on head and body parts), `hand` (paw colour shown through the outfit alpha),
secondary marks are painted in the head texture (muzzle, blaze, patches, mask, facial disc).
