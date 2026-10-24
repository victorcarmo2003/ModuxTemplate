# Style pack: pixel art / retro (v0 — not yet tested in Studio; refine with real references)

NES/SNES/GameBoy/PICO-8 looks. The whole style lives or dies on **integer scaling** and **nearest-neighbour**.

## Principles
1. **Author at native pixel size** (e.g. a 16x16 icon, a 48x16 button) as PNG, never as smooth SVG. If you
   draw with SVG, render at 1x with `shape-rendering="crispEdges"` and no anti-aliasing, then upscale ×N with
   nearest neighbour in Python (`Image.resize(..., Image.NEAREST)`) only if needed for upload.
2. **Display at integer multiples** only (×2, ×3, ×4…). Every element's size = source px × N, positions on the
   N-pixel grid. A ×2.5 scale ruins the look. Compute N from viewport height (`N = floor(viewportY / 270)` for a
   480x270 virtual screen) and drive all Offsets with it (not UIScale with a fractional value).
3. **`ResampleMode = Enum.ResampleMode.Pixelated`** on every ImageLabel. 9-slice works with pixel frames
   (SliceCenter in source px) and `SliceScale = N`.
4. **Locked palette.** Pick a palette (PICO-8 16, Endesga 32, NES 54, GameBoy 4 greens) and quantize every asset
   to it: `Image.quantize(palette=...)`. No gradients, no alpha except fully transparent.
5. **Fonts:** Press Start 2P (Roblox built-in) at multiples of 8 px; for other bitmap fonts use a glyph atlas
   (`atlas.py`) and compose text — Roblox TextLabels anti-alias.
6. **Motion:** step, don't ease. Blink 2 frames, bounce in 1–2 px steps, `ImageRectOffset` frame animation at
   8–12 fps. Disable springs (or snap their output to the pixel grid: `math.floor(v / N) * N`).

## Technique table additions
| Element | Build |
|---|---|
| Window / dialog box | 9-slice pixel frame PNG (e.g. 24x24, slice 8) |
| Health hearts | atlas of full/half/empty heart, UIListLayout, padding = N px |
| Cursor / selector | blinking pixel arrow PNG, steps between items |
| Text box typing | reveal `MaxVisibleGraphemes` step by step with a blip sound |

## Checklist
- [ ] Every image Pixelated; no blurry edges at any resolution tested.
- [ ] All sizes/positions integer multiples of N.
- [ ] Palette count ≤ chosen palette; no stray anti-aliased colors (`palette.py` on the capture to check).
- [ ] No smooth tweens on position.
