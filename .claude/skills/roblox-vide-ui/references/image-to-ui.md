# Image → UI: reading references correctly

The first-glance description of a screenshot is always too vague ("thin white lines, some numbers, yellow
icons"). That vagueness is what produced "inspired by" results instead of "looks like". Measure everything.

## Protocol

1. **Normalize.** All references to 1920x1080 space (`grid.py` does it). Note the source aspect.
2. **Classify every reference image:**
   - *In-game screenshot* — HUD over the world. Recreate the HUD only. World art, weapon model, bloom are not UI.
   - *Style-guide / concept board* — callout lines and labels ("Round count —", "Exo Ability") are
     **annotations**, not UI. Title text of the board is not UI. Use their explanations as the state spec
     ("Battery turns red when below 25%" = a state to implement).
   - *Close-up / zoomed crop* — great for shape detail; position comes from a full-screen shot.
3. **Inventory.** For each element write one row. Template:

| # | Element | Box (x,y,w,h @1080p) | Anchor | Shape notes | Color / opacity | Text (font class, size) | States | Technique |
|---|---|---|---|---|---|---|---|---|
| 1 | Round count | 900,432,138,141 | br | light condensed numerals, tabular | #FFFFFF 100% | ~176 px Oswald Light? (font_match) | normal / low (amber) / empty (red) | TextLabel or digit atlas |
| 2 | Ammo divider | 885,598,173,4 | br | flat bar | #B2B4B6 80% | – | – | Frame |
| 3 | Exo battery | 617,595,40,98 | br | rounded body, cap, fill level | white / red <25% | – | level 0..1, low | PNG body + Frame fill (ClipsDescendants) |

4. **Zoom on every row.** `grid.py ref.jpg --crop x,y,w,h --zoom 4`. Record: stroke width in px, corner cut
   size and angle, gaps between segments, alignment (shared baselines, shared left edges), letter case.
5. **Palette.** `palette.py ref.jpg --crop <hud region> --ui-only`. Assign roles: primary (neutral HUD white/
   cyan), secondary (dim neutral for reserve info), accent (selected/earned), warning (amber), danger (red),
   holo/contextual (green/blue). Opacity matters as much as hue — HUD whites are often 70–90%.
6. **Type.** `font_match.py` for each distinct text style. Screens often mix families (sim shop: Builder Sans
   ExtraBold titles + Montserrat Heavy small caps). Below ~30 px ink height the score cannot separate weights or
   close families reliably — open the board image and decide by letterforms (e.g. straight "e" bar, "a" shape).
   Crop only the white glyphs; a crop that catches other UI gives nonsense scores. (big numeral, label caps, micro-data). Record size ratio
   between levels (e.g. round 176 : reserve 86 ≈ 2:1).
7. **Grid & rhythm.** Find the spacing unit (often 4 or 8 px at 1080p), the margin to screen edges, the shared
   axes. Write them down as layout tokens.
8. **States & motion.** List every state seen across all references (low ammo, reload, empty slot, selected
   streak, cooldown, damage direction…) and motion hints (sweep, flicker, slide). Each becomes a prop + story control.
9. **Technique column** last, using SKILL.md §2.

## Interpreting common HUD visuals

| You see | It usually is | Build as |
|---|---|---|
| Soft halo around lines | bloom/glow | `_glow.png` layer under art, ImageTransparency 0.4–0.6 |
| Lines thinner than 1 px, dim | 1 px line at 40–60% opacity | Frame 1 px, BackgroundTransparency 0.5 |
| Perspective-tilted panel | 3D holo | SurfaceGui on a part in front of camera, or skew baked into PNG |
| Tiny unreadable text blocks | decorative data noise | static texture, low opacity |
| Grid / wireframe over targets | scan effect | tiled texture or 3D highlight (`Highlight` instance) — not GUI |
| Text that sits in the world (names over people) | diegetic label | BillboardGui |
| Big number on the weapon model | diegetic weapon display | SurfaceGui on the viewmodel part, or screen HUD if no viewmodel |

## Don'ts

- Don't recreate franchise logos, trademarks or copyrighted icons 1:1 for a shipped game; reproduce the *language*
  (line weight, geometry, rhythm, palette) with original icons. Fine for internal tests.
- Don't average multiple references into one HUD without picking which one defines each element.
- Don't skip states because the screenshot shows only one.
