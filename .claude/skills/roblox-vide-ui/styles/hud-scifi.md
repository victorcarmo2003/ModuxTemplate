# Style pack: sci-fi / military HUD

Covers near-future FPS HUDs (Call of Duty: Advanced Warfare / Infinite Warfare / Black Ops 3, Titanfall 2,
Halo, Destiny, Crysis, Ghost Recon) and tactical drone/scope overlays. The sub-language that matters most is
**AW-style "floating hairline HUD"**, documented first; variants after.

## A. Advanced Warfare language (measured from the Blacksmith MP/SP style guide boards)

### Core principles
1. **No panels.** MP HUD elements float directly over the world: no dark boxes, no card backgrounds, no frames
   around clusters. Legibility comes from white + slight glow + the world being darker. Adding a translucent
   black panel is the #1 way to lose the look. (Exception: contextual SP holo screens, see §A.6.)
2. **Hairlines.** Dividers 2 px at 1080p (often 60–80% opacity); icon strokes 2–3 px; nothing thicker
   except filled glyph blocks.
3. **Small and peripheral.** At 1920x1080 the whole weapon cluster is ≈ 270x160 px in the bottom-right,
   ~110 px from the right edge and ~60 px from the bottom. The round count numeral cap height ≈ 60–65 px,
   reserve ≈ 50% of that. Minimap ≈ 360x240 top-left at ~75 px margins. Don't scale things up "for Roblox".
4. **Condensed light numerals.** Tall, narrow, light weight (DIN/Bank Gothic Condensed family). In Roblox:
   **Oswald Light (300)** is the closest built-in by stroke weight (ExtraLight looks too thin next to the AW
   ref; both ~15% wider) → for the hero ammo numeral use a digit atlas from an OFL condensed font when fidelity
   matters. Tested sizes at 1080p: round count line box 255 → `TextSize 85` + `UIScale 3`; reserve line box
   128 → `TextSize 64` + `UIScale 2` (TextSize caps at 100, see fundamentals). Labels: Oswald
   Regular or Roboto Condensed, uppercase for system labels ("WINNING", "DEFEND", "CAPTURE"), mixed case for
   player names/feed.
5. **Geometric glyph icons.** Built from squares, rectangles, circles, thin connecting lines — "pixel-blocky
   but crisp" (exo launcher = stacked blocks + ring; exo ability = node graph; streak = rings + bars;
   unselected streak = scattered squares). Icons are white; **color is state**, not decoration.
6. **Dividers as structure.** A short horizontal rule separates stacked items (round over reserve; launcher over
   ability; streaks between each other). A vertical rule separates the equipment column from the ammo column.
7. **Line weight survives scaling.** Ring strokes ~5 px and glyph lines ≥ 3 px at 1080p in the mockup:
   the HUD runs at 0.6–0.8 scale on laptops and the AW look needs lines that still read (tested: 1.6 px node
   lines and 4 px rings came out visibly thinner than the reference).
8. **Glow, subtle.** White elements carry a faint bloom (glow radius ≈ 4–6 px, 40–55% transparent layer).
   Amber selected streak carries a stronger amber glow.

### Palette (extracted with `palette.py --ui-only` from weaponpanel/mphud)
| Role | Hex | Use |
|---|---|---|
| Primary | `#FEFEFE` @ 90–100% | numerals, icons, main labels |
| Secondary | `#B2B4B6` @ 70–85% | reserve ammo, dividers, unselected/dim items |
| Accent / earned / selected | `#F9C914` (shade `#BA8A42` for partial) | streak earned, selected; objective "DEFEND" |
| Danger | `#D8282A` | empty slot square, enemy score, low battery, enemy dots, hit indicator |
| Friendly / objective | `#7FD3F0`-ish cyan | friendly dots, "CAPTURE" objective, B marker |
| Holo contextual (SP) | `#8CFF5A` on `#1E5A1E` @ 40% | SP contextual videologs / schematic screens |

### Element recipes
| Element | Build |
|---|---|
| Ammo cluster | `TextLabel` round (or digit atlas) / 2 px Frame divider / `TextLabel` reserve in Secondary. Low ammo: round tints amber then red; reload: reserve flashes + "RELOAD" label below crosshair |
| Equipment column | slot squares as Frames (red = empty, white = full); launcher & ability glyph PNGs (ability = hub square + 6 round nodes of different radii + 2 small squares on the axis, 2 px spokes); battery = grey cap PNG (separate, 4 px gap) + shell PNG (r 5, stroke 2.5) + level fill via clip-reveal (r 3 bottom, flat top; red < 25%) |
| Streak column | 3 glyph PNGs stacked with 2 px dividers; in progress = ONE silhouette, brown `#A08A80` @75% behind + the same PNG in amber inside a clip whose width is the progress (cut is vertical); earned+selected = Accent + thin dark-orange rim (`#C8641E`, glow radius 2) + `>` selector; earned unselected = grey scattered squares |
| Selector `>` | chevron stroke 2.4, arms 18 px wide / 36 px tall; dot r 3.6 **centered on the chevron's vertical axis**, just left of the arm tips |
| Drone streak icon | two rotor rings (r 35.5, stroke 4.4) with center squares; turret = 2 tall side bars + shorter body block on top; a **2.4 px stem** runs from the body through the gap between rings to a lower block — without the stem it doesn't read as a drone |
| Crosshair | 4 tiny ticks (Frames 2x10 px) + no center dot; spread = spring on offset |
| Minimap | perspective trapezoid → **SurfaceGui on a tilted part** in front of the camera, or a ViewportFrame; flat fallback = rectangle with `brackets` corners. Compass letters above (Oswald 14–16 px), N bold |
| Score + time | big condensed numbers left (friendly white) / right (enemy red), "WINNING" + time stacked small in the middle |
| Kill feed | Roboto Condensed 18–20 px, rows fade by age (transparency 0 → 0.6), weapon silhouettes as atlas PNGs, enemy names in red |
| Objective markers | BillboardGui: letter in circle (PNG ring + TextLabel) + verb below ("CAPTURE", "DEFEND"), off-screen variant = edge arrow `<` chevron + marker clamped to screen edge |
| Hit indicator | PNG arc (~100°, radius ≈ 0.36 × screen height) with **halftone dot texture** and alpha fading to both ends; rotate the ImageLabel around screen center toward the damage source; multiple instances stack; fade 0.6 s |
| Exo battery (center, contextual) | small horizontal battery with dotted texture flanks under the crosshair, appears only while the ability drains |
| Contextual SP holo screen | green holo panel in perspective (SurfaceGui), corner brackets with dot terminals, title bar text in heavy condensed caps, scanline + subtle noise texture |

### Shapes to export (via `shapes.py`)
- `chevron` 22x40 stroke 2.5 (streak selector)
- `arc` for streak rings: r 36, thickness 4, full
- hit indicator arc: generate wedge in SVG, fill with a `<pattern>` of 3 px dots, mask with a linear/radial
  gradient for the faded ends — export with `data-keep-color="true"` (red baked) or white + tint
- `brackets` for minimap / holo corners (length 18, stroke 2)
- `battery` body without fill (fill is a Frame for live level)

## B. Variants

### Titanfall 2 / Halo-like
- Translucent panels allowed (10–25% dark fill) with chamfered corners (`chamfer --cut 10`), thicker 3 px strokes.
- Strong cyan/white primary, amber warnings. Segmented bars (`segbar --skew 20`) for shields/health.
- Big arcs around the crosshair for ability cooldowns (`arc --segments 12 --gap 3`).

### Drone / scope / turret overlays (references: FlyDroneHUD, SniperScope, StingerHUD, SentinelDrone)
- Full-screen overlay: reticle + range ticks + compass tape at top + altitude/zoom ladder on sides.
- Monospace readouts (Roboto Mono/Builder Mono 14–18 px) with leading zeros (`ALT 0142`).
- Vignette and scanlines as tiled low-opacity textures; slight green or white monochrome tint.
- Lock-on: `brackets` box that springs to the target's screen rect (from `WorldToViewportPoint`).

### Mech / vehicle cockpit
- Heavier frames, chamfered panels at the screen corners, segmented health with damage zones (silhouette PNG
  with per-zone overlays tinted by state).

## C. Checklist specific to this style
- [ ] No background panels on the MP-style HUD.
- [ ] Hero numerals narrow & light (measured with `font_match.py`), reserve ≈ half height, Secondary color.
- [ ] Divider rules present between stacked items, 2 px, Secondary.
- [ ] Icons white geometric glyphs; state = color (white / amber / red / grey).
- [ ] Glow faint (not neon). Accent glow only on selected/earned.
- [ ] Cluster size and edge margins match the measured px (not enlarged).
- [ ] Hit indicator uses a textured arc PNG, not Frames.
- [ ] Minimap perspective solved with SurfaceGui/ViewportFrame or documented as a flat fallback.
