---
name: roblox-vide-ui
description: Build Roblox game UI (HUDs, menus, shops, inventories, overlays) with the Vide library (centau/vide) from a text brief or from reference images/screenshots (image-to-UI). Use whenever the task is a Roblox ScreenGui/SurfaceGui/BillboardGui interface, a HUD that must "look like" an existing game (Call of Duty, Halo, Titanfall, Pet Simulator, Genshin, Diablo...), a Vide component or UI Labs story, or turning a mockup/screenshot into Roblox UI. Covers the vector-asset pipeline (SVG mockup -> PNG layers -> upload -> rbxassetid), Roblox UI fundamentals, verification against the reference, and style packs: sci-fi/military HUD, simulator, RPG, pixel art. Prefer this over web design skills for anything rendered inside Roblox.
---

# Roblox UI with Vide — reference to shipped component

Web design skills assume CSS: borders on any shape, blur, skew, clip-path, letter-spacing, box-shadow.
Roblox has **none of that**. Most "it doesn't look like the reference" failures come from trying to fake
non-rectangular art with stacked Frames. This skill fixes that with one rule and one loop.

**The rule:** every visual element is assigned a *technique* before any code is written (§2).
**The loop:** mockup → measure → assets → Vide → capture → compare → fix, at least two rounds (§1).

## 0. Context first (always)

1. Find the project's UI conventions before writing anything:
   - `wally.toml` → Vide version (this skill targets **0.4.x**; read `references/vide-patterns.md`).
   - Existing components (`**/Components/**/init.luau`), their `*.story.luau` (UI Labs), a `Theme`/tokens module,
     a `Layout` (Desktop/Mobile) module, an asset id module (`AssetIds.luau` or similar), an upload pipeline.
   - Match their idiom exactly (e.g. `const`, `create("Frame")({...})` vs `create "Frame" {...}`, prop shapes as
     `() -> T`, comment density, tokens instead of hardcoded colors).
2. If the project has a style guide / design docs, they outrank this skill's style packs. Style packs fill gaps.
3. Pick the style pack(s) in `styles/` that match the brief and read them fully:
   | Brief mentions | Read |
   |---|---|
   | sci-fi, military, FPS, CoD, Halo, Titanfall, Destiny, hologram, exo, drone, scope, tactical | `styles/hud-scifi.md` |
   | simulator, tycoon, pets, clicker, obby, cartoon, "Pet Sim", "Bee Swarm" | `styles/simulator.md` |
   | RPG, fantasy, inventory, quest, Diablo, Genshin, MMO, parchment, rarity | `styles/rpg.md` |
   | pixel, retro, 8-bit, 16-bit, NES, GameBoy | `styles/pixel-art.md` |

## 1. The loop

```
 A. INTAKE      refs → palette.py + grid.py (measure in reference px) → element inventory
 B. DECOMPOSE   inventory → technique per element (§2) → write it down as a table
 C. MOCKUP      one SVG at reference resolution (1920x1080) with every asset as <g id="asset-*">
                render it, compare.py vs reference, fix until it reads the same (cheap iterations here!)
 D. EXPORT      export_layers.py → white PNG per asset (+glow) + layout.json (scale positions)
 E. UPLOAD      project pipeline if it exists, else MCP upload; record ids in one module
 F. BUILD       layout_to_vide.py skeleton → real Vide component + UI Labs story + states
 G. VERIFY      capture in Studio at 1920x1080 → compare.py vs mockup/reference → checklist (§5) → back to C/F
 H. DETAIL      detail_board.py ref vs capture, one magnified tile per element → detail checklist → fix
```

Whole-screen scores reach 0.94 while an icon is still unreadable. **H is mandatory**: in the AW test the user
spotted a drone turret missing its 2 px stem, a dot 1.5 px off the chevron axis and a square battery fill inside a
rounded shell — none of which moved the global score. Measure every icon at **5–7× zoom** before drawing it
(`grid.py --crop ... --zoom 6`); never draw icon geometry from the full-screen view.

**Native-first styles (simulator, most menus):** when ≥ 70% of the screen is Frames (chunky buttons, cards,
tabs, text), skip the full-screen SVG mockup: draw only the *images* in SVG (icons, badges, rays, tiles), export
them, then build the screen directly in Vide and iterate in Studio with the HTTP fetch loop
(verification.md) — native tweaks are cheaper in Studio than duplicating them in SVG. Hairline/vector-heavy
styles (sci-fi HUD) keep the full mockup.

Why the SVG mockup: iteration in a browser costs seconds; iteration in Studio costs minutes. The mockup is also
the **source of truth for assets** — the same file exports the PNGs and the layout, so code and art never drift.
Skip C only for trivial UI (a text label, a plain bar).

Commands (scripts live in this skill's `scripts/` folder; run with `python <skill>/scripts/X.py -h`):

| Step | Command |
|---|---|
| Palette | `palette.py ref.jpg --crop x,y,w,h --ui-only -k 6` → hex + share + role guess |
| Measure | `grid.py ref.jpg -o grid.png` ; zoom: `grid.py ref.jpg --crop 1400,850,500,230 --zoom 3` (labels in full-image px) |
| Font pick | `font_match.py ref.jpg --crop x,y,w,h --text "25"` → ranked Roblox fonts + `FontFace` + TextSize |
| Mockup fonts | `roblox_fonts.py "Oswald" "Roboto Condensed"` → `<style>` with the exact Roblox font files; `--list` for families |
| Mockup start | copy `templates/make_mockup.py` (Python generator using `shapes.py`), edit BODY |
| Primitives | `shapes.py <kind> ...` prints SVG snippet (chamfer, brackets, arc, ticks, chevron, segbar, hexcell, leader, battery, reticle, scanlines) |
| Mockup render | `render.py mock.svg -o mock.png [--bg ref.jpg] [--opacity 0.5]` |
| Compare | `compare.py ref.jpg capture.png -o cmp.png [--crop x,y,w,h]` → side by side, overlay, diff, score |
| Detail pass | `detail_board.py ref.jpg capture.png --layout out/layout.json --zoom 3` → magnified ref/candidate/overlay per element |
| Export | `export_layers.py mock.svg -o out/ --scale 2 --glow 6` → `out/*.png`, `out/layout.json` |
| 9-slice | `nineslice.py frame.png` → `SliceCenter = Rect.new(...)` |
| Atlas | `atlas.py out/icons/*.png -o atlas.png --luau Atlas.luau` → ImageRectOffset/Size map |
| Vide skeleton | `layout_to_vide.py out/layout.json --name WeaponPanel > init.luau` (fonts mapped to `Font.new`) |
| Learn a UI | paste `scripts/ui_dump.luau` into execute_luau (set ROOT) → real layering, strokes, gradients, textures, image ids |
| Lit ornaments | Blender MCP: paste `templates/blender_ui_kit.py`, build with `B(...)`, `render(...)` → gold/iron/gem PNGs with real light |
| Material pass | `templates/example_material_pass.py`: Poly Haven texture → graded seamless tile, shadows, inset 9-slices, embers |
| Syntax check | `lune run <skill>/scripts/parse_check.luau init.luau` (run from a folder where `lune` resolves, e.g. the project) |

Python deps: Pillow, numpy, scipy, playwright (+ `python -m playwright install chromium`). Check once per machine.

## 2. Technique decision (the core rule)

For each element in the inventory, choose exactly one. Write the table in your plan.

| Element shape | Technique | Why |
|---|---|---|
| Axis-aligned rectangle, bar, divider, 1–2px straight line | **Native Frame** (offset thickness) | pixel-crisp, tweenable, free |
| Rounded rectangle, pill, circle (filled or stroked) | **Native Frame + UICorner (+ UIStroke)** | crisp at any scale |
| Bar fill / progress / gauge that animates **linearly** | **Native Frame** size tween, or **ClipsDescendants** mask over an image | no per-frame asset |
| Chamfered/angled panel, cut corners, trapezoid, chevron, arrow, bracket, hexagon | **SVG → PNG ImageLabel** (9-slice if it resizes) | Roblox has no clip-path/skew |
| Arc, ring segments, radial ticks, circular gauge | **SVG → PNG**; animate with **UIGradient Transparency + Rotation** on the image or by layering N segment images | no arc primitive |
| Icon, logo, glyph, silhouette | **SVG → PNG** (white), tint with `ImageColor3`; pack many in an **atlas** | one asset, many states |
| Glow / bloom / soft shadow | **Pre-blurred PNG** under the shape (`--glow`) | no blur/shadow in UI |
| Grid, scanlines, noise, wireframe overlay | **Tiled PNG** (`ScaleType.Tile`, `TileSize`) at low opacity | thousands of Frames = lag |
| Perspective / skewed holo panel | **SurfaceGui on a Part** in front of the camera (or bake skew into the PNG) | 2D GUI cannot skew |
| Numbers, labels, live text | **TextLabel** with explicit `FontFace`, `TextSize` from tokens | localizable, dynamic |
| Stylized fixed title text (custom font, tracking, outline glow) | **PNG of the text** only if it never changes | Roblox fonts/tracking are limited |
| Animated sprite (spinner, flicker, loading) | **Sprite sheet** + `ImageRectOffset` stepping | |

**Gradients are not a material.** Any screen with large surfaces or ornaments (RPG, fantasy, premium menus) gets a
material pass before it is called done: texture under the surfaces, lit ornaments (Blender kit) with dark drop
shadows, recessed wells instead of outlines everywhere. See `references/material-pass.md` (user verdict on the
gradients-only version: "looks like a 2010 Flash game").

**Illustrated art = placeholder by default.** Cartoon/specific illustrations (pets, characters, item art,
illustrated badges, mascots) are the user's to provide: build an exact-size, clearly labelled placeholder and
list them at the end. Draw them only when the user asks for it. Geometric/vector UI glyphs (HUD icons, arrows,
rings, brackets, battery, chevrons) you do draw — that is UI, not illustration.

**Learn from an existing UI when one is available.** If the user can bring the original (or a similar) UI into
Studio, run `scripts/ui_dump.luau` on it *before* building: the real layering beats guessing from a screenshot
(see styles/simulator.md for what that revealed).

**Read the place state back before reporting.** List StarterGui ScreenGuis (name, Enabled, children) at start
and end; if something changed that your scripts did not do, say so plainly and ask — users also edit the place
between turns (in one test they deleted the old capture GUIs on purpose; the read-back surfaced it).

**Never destroy or overwrite instances you did not create.** Capture ScreenGuis get unique names
(`__<Name>Capture`); before `:Destroy()`ing one, check it holds only your children (users drop originals into
them). To hide something of theirs during a capture, toggle `Enabled` and restore it afterwards.

Hard bans (these are the failures that triggered this skill):
- **Never** build a diagonal line, chevron, arc, triangle or bracket out of rotated/overlapping Frames.
  One rotated Frame for a single straight diagonal stroke is acceptable; two or more meeting at angles is not.
- **Never** fake a glow with 3–5 stacked UIStrokes of rising transparency. Export a glow layer.
- **Never** draw a grid/scanline pattern with Frames in a loop.
- **Never** bake color into a single-color asset. Export white, tint in engine (one asset → white/amber/red states).
- **Never** bake live values (ammo, timer, names) into images.

## 3. Asset rules (details in `references/asset-pipeline.md`)

- Author at reference resolution (1920x1080 mockup). Export at **2x** display size, cap **1024 px** per side
  (Roblox downsamples anything larger). Tiny assets (< 32 px displayed): export 4x.
- Stroke widths: design for the **smallest HUD scale** you support. A HUD scaled by viewportHeight/1080 runs at
  ~0.6 on a 650 px-tall Studio viewport / small laptop, so a 2 px line becomes 1.2 px and looks thinner than the
  reference. Rule: stroke ≥ 2 / minScale px in the mockup (≈ 3 px for 0.65) for lines that must read, or clamp
  the HUD scale (e.g. `math.max(h / 1080, 0.75)`).
- In the mockup, draw every asset **in its real color**; export forces white and records the color as
  `ImageColor3` (`data-tint` only overrides). Drawing white and tagging the tint hides color mistakes in the check.
- Text: Roblox `TextSize` ≠ CSS font-size and caps at 100 — see fundamentals "Text and fonts". Trust
  `layout_to_vide.py` / `font_match.py` numbers, not the SVG font-size.
- Transparent padding of ≥ 2 px around every asset (bilinear filtering bleeds edges otherwise).
- White fill `#FFFFFF`, color via `ImageColor3`. Multi-color assets only when colors are fixed (e.g. a badge).
- Name: `<area>_<element>[_state].png` (e.g. `hud_ammo_frame.png`, `hud_exo_cell_glow.png`).
- After upload, ids go in **one** Luau module; components never contain raw `rbxassetid://` literals.
- Uploaded images take a moment to pass moderation; until then they render blank — not a bug in your code.

## 4. Building in Vide (details in `references/vide-patterns.md`)

- Component = function(props) → Instance. Props reactive (`() -> T`) so stories and live data share one API.
- Layout: position with **Scale** relative to a root that has `UIAspectRatioConstraint` or uses a scale factor;
  thickness/stroke/padding with **Offset** multiplied by a `UIScale` or the project `Layout` metrics.
  HUD corners anchor to corners (`AnchorPoint` = the corner you are pinned to).
- Every state from the reference is a prop or derived source (low ammo, empty slot, selected/unselected,
  cooldown, critical). Build a story control for each state.
- Animation: `Vide.spring` for values that follow data; `TweenService` for one-shots (flash, pop-in).
  Respect a ReduceMotion flag if the project has one.
- Dynamic lists → `Vide.indexes`/`Vide.values`, never reactive scopes created inside a function child.
- Phone and world UI: read `references/phone-and-scaling.md` first. Musts: one global scale rule proportional to
  the PC with a ~0.6 touch-phone floor; `UITextSizeConstraint { MaxTextSize = TextSize }` on every non-scaled text
  (the player's Text Size setting adds px after UIScale); skip auto-size measures under a ~0.25 scale; studs
  billboards use `TextScaled` + scaled outlines, px billboards that act like objects get a distance UIScale.

## 5. Verification checklist (run every round; details in `references/verification.md`)

Capture at **1920x1080** (and one phone size, e.g. 844x390) and compare with `compare.py`.
- [ ] Silhouette: squint test — same masses in the same places as the reference at 25% zoom.
- [ ] Line weight: thin lines are thin (1–2 px at 1080p). No chunky borders where the ref is hairline.
- [ ] Angles: every diagonal/chamfer in the ref exists, at the same angle (usually 45°).
- [ ] Palette: dominant + accent colors within the extracted palette; opacity matches (HUDs are rarely 100%).
- [ ] Type: font family class (condensed vs wide, mono numerals), weight, case, relative sizes (big ammo vs small reserve).
- [ ] Negative space: HUD elements hug the screen edges with the same margins (measure, don't guess).
- [ ] States: every state in the brief/reference is reachable from the story controls.
- [ ] No banned technique from §2 survived.
- [ ] Phone layout: nothing overlaps thumbs/topbar; text ≥ 14 px effective.
- [ ] Phone fit (844x390, touch floor simulated): every section of every card visible or scrollable; no label under
      a bar/button; no outline clipped by a scroll/clip container; no text past its box with Text Size "Largest".
- [ ] World UI: walk away from every BillboardGui — text and outlines shrink with a studs sign; a px billboard does
      not end up bigger than its object.
Report the score from `compare.py` and the remaining differences honestly. Two rounds minimum; stop when the
remaining differences are only things Roblox cannot do (list them).

## 6. When images are the brief (image-to-UI)

Read `references/image-to-ui.md`. Short version: never trust your first glance at a screenshot — run
`grid.py` and zoom into every element; write the inventory with measured px boxes; separate **diegetic**
(world-anchored, BillboardGui/SurfaceGui) from **screen** HUD; note which parts are game art behind the HUD
(do not recreate the world). Concept boards with callout lines ("Round count —") are annotations, not UI.

## 7. Files

- `references/roblox-ui-fundamentals.md` — engine facts and gotchas (Scale/Offset, ZIndex, CanvasGroup, fonts, safe area…)
- `references/vide-patterns.md` — Vide 0.4 API, component and story templates, pitfalls
- `references/asset-pipeline.md` — SVG authoring, export, 9-slice, atlas, upload paths
- `references/image-to-ui.md` — reference analysis protocol and inventory template
- `references/verification.md` — capture methods (MCP, UI Labs), compare, iteration discipline
- `references/material-pass.md` — textures, Blender-lit ornaments, shadows, depth (fixes the "flat / Flash-era" look)
- `references/phone-and-scaling.md` — phone scale rule, PreferredTextSize cap, auto-size under UIScale, card fitting,
  scroll/outline clipping, studs vs px BillboardGui (text, strokes, distance scale), phone verification in Studio
- `styles/*.md` — style packs
- `templates/make_mockup.py` — mockup generator starter; `templates/example_aw_weapon_panel.py` — Studio-verified sci-fi HUD example; `templates/example_sim_shop.luau` + `example_sim_icons.py` — Studio-verified simulator shop (production anatomy); `templates/example_rpg_mockup.py` + `example_rpg_inventory.luau` (v1) / `example_rpg_inventory_v2.luau` (material pass) — Studio-verified interactive RPG inventory; `templates/blender_ui_kit.py` + `example_material_pass.py` — lit ornaments and textures
- Component and story templates live in `references/vide-patterns.md`
