# Lessons (user feedback → fix). Add new ones with the date.

1. (2026-10-10) Boxy heads with modelled eyes/nose rejected ("mais texturizado, mais cartonizado") → one round/oval
   head mesh with snout volume, every face feature by texture, expressions by texture swap.
2. Face shell with a plain TextureID painted its transparent texels with the part Color → SurfaceAppearance
   (AlphaMode Transparency) templates cloned at runtime (ColorMap is not script-writable).
3. Taller head moved HatAttachment +0.30 but the cap was placed from its FBX position → cap over the eyes. Move every
   accessory riding on the head's attachments when the head changes height (`capRaise`).
4. "Olhos caídos" #1: the shell wrapped around the head sides → front-only shell (normal·front ≥ 0.5), eyes inward/up,
   narrower, one small top-right highlight.
5. "Olhos caídos" #2 + visible vertex lines: eye bottom sat on the snout's upper slope; 22 × 10 lattice too coarse →
   compact oval snout that ends below the eyes, extra rings in the eye/snout zone, shell normals copied from the head.
   Always check 60°/75° renders.
6. "Não tem queixo, nariz pontiagudo" → snout bump longer below its centre (rzd = 1.8·rz) and fuller front-bottom rings
   = round, cuddly chin; rounder tip (exponent 1.5).
7. "Esqueceu as orelhas" (night): atlas-coloured accessories kept day colours → night atlas swap on Night builds.
8. Night overlay with partial alpha renders nearly opaque in Roblox → judge night colours in Studio; consider opaque
   per-species night fur.
9. Denser heads raised the character to 1.9-2.1k tris, above a 1.8k NPC ceiling → state the budget hit to the user
   and offer to thin the back of the head (hidden by the cap).
10. Studio captures came back black while Studio was minimised → ask the user to keep it visible; probes meanwhile.
11. (2026-10-10) 10 species built in parallel (5 agents × 2) from one brief: isolation by work dir + per-species file
    names worked; a session restart stopped them mid-way — resume each agent, it picks up from the files on disk.
12. In Studio every Night species came out the same navy (partial-alpha overlay renders opaque) → species become
    indistinguishable at night; decide per project whether night keeps the species colour (bake opaque per species).
13. Beaked/disc snouts (Owl, Penguin, Pig, Mouse) cover the shared painted nose — fine, the mouth stays visible below.
14. (2026-10-10) "Dois narizes": the shared expression sheets drew a nose on top of species with their own nose
    (pig disc, mouse bead, koala's painted nose, pink noses) → the nose is NOT on T_Expr (EXPR_NOSE off); each species
    gets exactly one nose, painted in its T_Head (`heads/nosefix.py`) or modelled.
15. Compositing onto a head sheet zeroed the RGB under alpha-0 texels → in Roblox the fur turned black. The painter
    stores the fur colour as RGB under alpha 0 and Roblox shows it: never change RGB where alpha stays 0.
16. Puffed uniform sleeves (elastic line) look wrong on casual clothes → civilians use plain arms (AST-053_CivilArms).
17. Hands: cartoon paws (pink palm pad + toe beans, opaque) on every outfit sheet; fur texels fully transparent.
18. (2026-10-10) Pig ears came out inside-out (closed islands with negative volume; built mirrored by hand) → run
    `heads/invscan.py` on every character blend before export (0 INV lines), and the fix is flipping those islands.
19. (2026-10-10) Night hands kept the day species colour while the night head went navy → night outfit sheets get
    the same worn-fur overlay as the night heads on every fur texel (RGB 30,32,54, alpha 68); pads/clothes untouched.
    Day sheets keep fur texels fully transparent. Triangle budget (~2.0-2.5k per character) approved by the user.
20. (2026-10-10) Animation rig (AST-069) from the community CommunityR6 blend: its IK put the rigid R6 limb on the
    IK forearm/shin (clavicle in the chain) → limb translates off the Motor6D pivot (0.30 shoulder, 1.09 hip). Fix:
    per-limb aim bone at the R6 pivot (child of the torso positioner, DAMPED_TRACK to the IK control) + CHILD_OF on the
    positioner, toggle "Pin Joint". Headless gotchas: a hand-computed CHILD_OF inverse on a pose bone came out off by
    the armature object offset → use `set_inverse_pending` evaluated at rest with the constraint enabled; frame_set
    re-applies the file's rest keys (unassign the action to test poses); ID-prop drivers need `update_tag()`;
    a generated (non-file) image LUT turns black after save → use a constant ColorRamp. Verify with joint separation
    (pivot seen from Part0 vs Part1) = 0, not only renders. Build/verify scripts: Sell Hotdogs `tools/animrig/`.
