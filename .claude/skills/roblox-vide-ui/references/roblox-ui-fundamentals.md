# Roblox UI fundamentals — what web instincts get wrong

## Coordinates and scaling

- `UDim2.new(xScale, xOffset, yScale, yOffset)`. Scale = fraction of parent, Offset = pixels.
- **HUD rule of thumb:** pin each cluster to a screen corner/edge with `AnchorPoint` = that corner and an Offset
  margin; size clusters in Offset; scale the whole HUD uniformly with one `UIScale`
  (`scale = viewportHeight / 1080`, clamped e.g. 0.6–1.4). Proportions and hairlines stay exact.
  Trick: UIScale also scales its parent, so a full-screen root under UIScale `s` must be `Size = fromScale(1/s, 1/s)`.
- Pure Scale layouts distort on ultrawide/phones (things stretch or drift). Use Scale for full-screen menus
  with `UIAspectRatioConstraint` on panels.
- `UIAspectRatioConstraint` keeps icons/rings round. `UISizeConstraint`/`UITextSizeConstraint` set bounds.
- `AutomaticSize` for content-driven boxes (chips, tooltips); combine with `UIPadding`.
- Layouts: `UIListLayout` (rows/columns, `Padding`, `HorizontalAlignment`, `SortOrder = LayoutOrder`,
  flex since 2024: `HorizontalFlex`/`VerticalFlex`, child `UIFlexItem`), `UIGridLayout` (inventories),
  `UIPageLayout` (tabs/carousels), `UITableLayout` (rare).

## Screen, safe area, devices

- `ScreenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets` (default) keeps UI out of notches; use
  `CoreUISafeInsets` to also avoid the Roblox top bar. `IgnoreGuiInset` is legacy.
- Top bar (Roblox menu/chat buttons) occupies the top-left ~ 60 px (2024+ top bar; check in Studio). Don't put the
  health/ammo there.
- Test sizes: 1920x1080, 1366x768, 2560x1440, phone landscape 844x390 / 932x430, tablet 1024x768.
  Studio: Test > Device emulator. Phone: thumbs cover bottom-left (move) and bottom-right (jump/fire) — HUD
  elements must move away; most projects have a Desktop/Mobile layout switch — use it.
- `ZIndexBehavior = Sibling` (Vide default for ScreenGui): ZIndex compares among siblings only, and **a child
  always draws above its parent** whatever its ZIndex. So anything that must sit *under* an element (glow,
  shadow, back plate) is a **sibling with lower ZIndex**, never a child with ZIndex -1 (seen in Studio: a child
  glow covered the art). A plain `Instance.new("ScreenGui")` defaults to `Global`; set Sibling explicitly.
  `DisplayOrder` orders ScreenGuis.

## Drawing primitives (and what is missing)

| Have | Notes |
|---|---|
| Frame bg color/transparency | rectangles only |
| `UICorner` | radius in Scale or Offset; `UDim.new(0.5,0)` = pill/circle |
| `UIStroke` | outline of the parent shape (follows UICorner) or of text (`ApplyStrokeMode.Contextual` on TextLabel strokes the glyphs). `LineJoinMode` Round/Bevel/Miter. **`StrokeSizingMode = ScaledSize`** makes `Thickness` a fraction of the object size (0.05 etc.) so strokes scale with Scale layouts; **`BorderStrokePosition` Outer/Center/Inner** (Inner + white @0.5 = highlight rim). A second UIStroke on a child frame gives a second outline. |
| `UIGradient` | `Color` + `Transparency` sequences + `Rotation` + `Offset`. Affects the parent and is multiplied with image/text. Great for fades, sweeps, masks along one axis. |
| `ImageLabel` | `ScaleType` Stretch/Slice/Tile/Fit/Crop, `SliceCenter`, `SliceScale`, `TileSize`, `ImageRectOffset/Size`, `ImageColor3` (multiply tint), `ResampleMode` (Default bilinear / Pixelated) |
| `CanvasGroup` | group transparency/tint for a whole subtree, and — with a `UICorner` — the only **rounded clip** (textures, glows, studs inside a rounded card stay inside the corners; `ClipsDescendants` clips rectangles only). Renders to a texture: costly and can blur at large sizes; fine in menus, avoid in always-on HUD |
| `Rotation` | any GuiObject; rotates around center; Clipping (`ClipsDescendants`) ignores rotation |
| `Path2D` (newer) | vector path instance for lines/curves; check the project's engine version and availability before relying on it; SVG→PNG remains the portable path |

**Missing:** skew/perspective, blur/backdrop-filter, box-shadow, blend modes (additive), clip-path, masks
except rectangular `ClipsDescendants` and gradient transparency, letter-spacing, text gradients beyond UIGradient
on TextLabel, multiple strokes. Every one of those must be pre-rendered into an image or faked differently.

## Images

- Max effective resolution **1024x1024** (bigger uploads are downscaled). Export ≈ 2x display size.
- Bilinear filtering: hairlines < 2 source px shimmer; keep ≥ 2 px transparent padding.
- **Alpha bleed or dark fringes.** Roblox filters without premultiplied alpha: the RGB of *fully transparent*
  pixels bleeds into edges. Browser/Photoshop exports often store those as black → a dark halo around every
  light shape (confirmed in Studio). White assets: set RGB = 255 for every pixel; colored: spread edge colors
  outward. `export_layers.py` does this automatically (`bleed()`).
- `ImageColor3` multiplies: author **white** art to tint freely; colored art can only be darkened.
- 9-slice: `ScaleType.Slice`, `SliceCenter = Rect.new(left, top, right, bottom)` in source pixels;
  `SliceScale` scales the corners (0.5 if exported at 2x).
- Atlas: `ImageRectOffset` + `ImageRectSize` crop one icon from a sheet; one request for all icons.
- `ContentProvider:PreloadAsync({...})` on HUD images at spawn to avoid pop-in.
- `ResampleMode = Pixelated` for pixel art (nearest neighbour).
- New uploads may show blank until moderation passes.

## Text and fonts

**Measured in Studio (2026-10-05), these break every naive port from CSS/SVG:**
- **`TextSize` caps at 100** (setting 172 reads back 100). **`TextScaled` also caps at 100.**
  Bigger text: `TextSize = size / k`, label `Size / k`, and a `UIScale` with `Scale = k` inside the label.
  UIScale scales the label around its **AnchorPoint** (position stays put). `layout_to_vide.py` does this.
- **Roblox `TextSize` = full line box (ascent + descent), not the CSS em.** Glyphs come out smaller than CSS at the
  same number: Oswald ≈ 1.48× (CSS 172 px ≈ Roblox TextSize 255). In the mockup the `<text>` box height *is* the
  Roblox TextSize; `font_match.py` already prints the Roblox value.
- `TextBounds.Y == TextSize` for one line; size labels at least that tall.

- Set `FontFace = Font.new("rbxasset://fonts/families/<Family>.json", Enum.FontWeight.X, Enum.FontStyle.Y)`.
  Families: run `scripts/roblox_fonts.py --list`. Pick by measurement: `scripts/font_match.py`.
- Good HUD/sci-fi families on Roblox: **Oswald** (narrow, tall; 200–700), **Roboto Condensed** (300/400/700),
  **Titillium Web**, **Michroma** (wide techno, titles only), **Jura**, **Sarpanch**, **Zekton**, **Builder Mono**
  / **Roboto Mono** (data readouts), **Highway Gothic**.
  Cartoon/simulator: **Fredoka One**, **Luckiest Guy**, **Bangers**, **Denk One**, **Builder Sans ExtraBold**.
  Fantasy/RPG: **Fondamento**, **Grenze Gotisch**, **Merriweather**, **Accanthis ADF Std**, **Balthazar**.
  Pixel: **Press Start 2P**.
- No letter-spacing property. Tracking-heavy labels (`W E A P O N`) → spaces in the string (`"W E A P O N"`)
  for wide tracking, or pre-render the label if it is static.
- `TextScaled` fights consistent sizing: prefer fixed `TextSize` from tokens × UIScale. If you must scale, add
  `UITextSizeConstraint`.
- `RichText = true` enables `<font color="#FFC83D">`, `<b>`, `<stroke>`, `<font transparency="0.5">` for mixed
  styles in one label (e.g. "AMMO <font color='#F33'>LOW</font>").
- Glow text: a duplicate label behind with `UIStroke` (Contextual, Thickness 2–3, Transparency 0.6) gives a soft
  halo; stronger glow = pre-rendered image (static text only).
- Numbers that change: `FontFace` with tabular digits (mono or Oswald) to avoid jitter; or right-align.
- Text below 12 px on desktop / 14 px on phone is unreadable — HUD micro-text in references ("data noise") can
  be a texture, not real text.

## Performance

- Hundreds of GuiObjects animating every frame → cost. Prefer one image over 40 Frames.
- Avoid property writes every frame from Lua when a spring/tween does it.
- `CanvasGroup` per HUD element = bad. One CanvasGroup per full-screen fade = fine.
- `ClipsDescendants` + rotation = no clipping (by design); plan masks without rotation.

## Diegetic / world UI

- `BillboardGui` (always faces camera; `AlwaysOnTop`, `MaxDistance`, `Size` in studs (Scale) or px (Offset),
  `LightInfluence = 0` for HUD-like glow) — enemy tags, waypoints, objective markers.
- `SurfaceGui` on a Part — holographic panels, weapon-attached ammo counters (AW-style ammo on the gun),
  perspective HUD panels (part parented in front of the camera, CFrame each RenderStep). `PixelsPerStud` sets
  resolution; `LightInfluence = 0`, `Brightness > 1` makes it glow with Bloom post-processing.
- World-space line connectors (leader lines from a target to its label) → `Beam` or a rotated Frame in screen
  space computed from `Camera:WorldToViewportPoint` each frame.
