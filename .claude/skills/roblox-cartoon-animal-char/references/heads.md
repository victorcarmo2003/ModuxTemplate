# Round heads, face shell and expressions

## Head mesh — `scripts/heads/geom.py`, parameters in `hcommon.py`

- Lattice of superellipse rings (z, half-width a, front depth bf, back depth bb, exponent n) from the neck (3.95)
  to the crown (6.00), poles at bottom/top. `N_AZ = 26` azimuth segments biased to the front, `RING_INSERT`
  adds rings in the eye/snout zone (4.33, 4.51, 4.69, 4.87) → 728 tris. Fewer (22 × 10 = 440) showed facets and a
  diagonal crease in Roblox.
- Bottom rings deeper at the front (bf 0.78 / 0.98 / 1.09 for z 3.95 / 4.07 / 4.24) = round, cuddly chin.
- Snout (`SNOUT3` per species): compact smooth oval bump added to the front depth,
  `y += A·0.88·(1 - r²)^1.5·√cos`, r² = (x/(1.12·rx))² + ((z - zc)/rz)², `rz` above zc, `rzd = 1.8·rz` below
  (the snout flows into the chin). zc = 4.40, top of the bump below the eye bottom. Example A/rx/rz:
  Dog .34/.52/.30, Cat .15/.40/.24, Rabbit .16/.40/.24, Fox .48/.42/.28 (stays a bit pointy, fits a fox),
  Bear .34/.56/.32, Panda .23/.50/.28, Turtle .10/.72/.34, Owl none (beak accessory).
- Per-species ring tweaks `A[an]["da"/"dbf"]` (wider cheeks for cat/rabbit/bear/panda, flatter turtle face), cat/fox
  cheek tufts.
- Smooth shading (`set_sharp_from_angle` 60°). Head UV = cylindrical lattice UV (512²) for the marks sheet.

## Face shell `Face_<A>`

- Copy of the head faces whose flat normal·front ≥ 0.50, below the cap line, |x| ≤ 1.20; pushed 0.012 out along
  the vertex normals; own MeshPart welded to Head (FaceFrontAttachment).
- **Custom normals = the head's vertex normals** (`normals_split_custom_set_from_vertices`): no shading seam.
- **Standard UV for every species** (frontal projection, image space v from the top):
  `u = 0.5 - 0.40·x`, `v = 0.30 + 0.40·(4.86 - y)` (x, y = character space).
  Eyes at u 0.34/0.66, v 0.30 (x ±0.40, y 4.86, ovals 0.165 × 0.237 world); nose u 0.5 y 4.47; mouth y 4.33.
  One expression sheet then fits every animal.
- `facecheck.py`: coverage (no expression texel cut) and eye stretch (h, v) ≈ 1.00-1.02 on all species.

## Expression sheets — `paint_heads.py expr` (512², RGBA, transparent background)

Normal, Happy, Smile, Sad, Fainted (X eyes + X mouth), Normal_Night (small glowing pupils, droopy lids, fang),
Skeptical (one raised brow, one half-lidded eye, side mouth), Exhausted (heavy lids, eye bags, small frown),
Stressed (wide eyes, small pupils, furrowed brows, clenched zig-zag teeth, sweat drop) — moods for NPCs. NO nose.
Eyes: tall dark ovals (EYE_RX 0.150, EYE_RZ 0.215 design units), lighter lower half, ONE small white highlight at
the top-right of each eye (user reference). Blush ellipses below-outside the eyes. Nose = rounded dark oval with a
tiny highlight. Add new expressions as new `expr()` branches using the same anchors (EYE_X/EYE_Z/NOSE_Z/MOUTH_Z).

## Head marks — `paint_heads.py heads`
`T_Head_<A>.png`: alpha 0 = main fur (MeshPart.Color shows), opaque = marks (light muzzle, blaze, patches, fox mask,
owl facial disc, panda eye patches). Painted in 3D from the layout (texel → world position/normal).
`T_Head_<A>_Night.png`: worn darker fur overlay + desaturated, darker marks with grime.
