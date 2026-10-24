# Style pack: simulator / tycoon / cartoon (v1 — Studio-tested 2026-10-05 on a shop screen)

Pet Simulator 99, Bee Swarm, catapult/brainrot simulators, tycoons. Goal: readable at phone size, juicy, loud,
toy-like. The opposite of the hairline HUD — and **mostly native**: almost everything is Frames, only
illustrations/badges/rays/textures are images. Worked example: `templates/example_sim_shop.luau`
(+ `templates/example_sim_icons.py` for the sticker icons).

## The chunky surface — real production anatomy (read from the original UI with `scripts/ui_dump.luau`)

Every button, tab, card, panel, price pill and close button is the same structure:

```
Card / Button (Frame|TextButton)  BackgroundColor = LIP color (dark: card #034D00, button #026F00)
 ├ UICorner (Scale, ~0.03 cards / ~0.14 buttons)
 ├ UIStroke black, StrokeSizingMode=ScaledSize (0.014 cards / 0.05 buttons), BorderStrokePosition=Outer
 └ Items (CanvasGroup) + UICorner          ← ROUNDED CLIP for everything inside (ClipsDescendants is rectangular)
    └ Inner (Frame, white) Size Y = 0.977 cards / 0.918 buttons  → the lip shows below
        ├ UICorner
        ├ UIGradient Rotation 90, 3 symmetric stops, LIGHTER MIDDLE: #37FF00 → #B6FF6D → #37FF00
        │   (blue card #00A6FF → #00FFFF → #00A6FF; price button #AEFF00 → #89FF02 → #3CE100)
        ├ UIStroke WHITE, Transparency ~0.5, ScaledSize 0.014, BorderStrokePosition=Inner  ← inner highlight rim
        ├ CanvasGroup + UICorner
        │   ├ StudTexture: Image rbxassetid://109444965047738 (Roblox studs), ScaleType Tile,
        │   │    TileSize Offset 90x90 (cards) or Scale {0.3,1} (buttons), ImageTransparency 0.7–0.89,
        │   │    UIGradient Transparency NS[0:0.37, 0.54:0, 1:0.59] Rotation 90 (fades top/bottom)
        │   └ Glow: Frame BackgroundColor (darker hue of the card, e.g. #30DC00), BackgroundTransparency 0.7,
        │        Size {1.12,1.23} centered, UICorner 0.26, UIGradient Transparency HARD-STEPPED bands, Rotation 45
        │        = the diagonal "light rays". No image.
        └ content: TextLabels (TextScaled + UIAspectRatioConstraint, UIStroke Contextual ScaledSize ~0.065,
                   RichText for mixed colors/sizes), icon ImageLabels (artist PNGs, ScaleType Fit, often rotated)
```
Glow band sequence (copy as is): `NS[0:0, .16:0, .17:.99, .43:0, .431:.98, .66:1, .661:0, .79:0, .791:1, .99:0, 1:1]`.

My first attempt (screenshot only) guessed the lip/gradient/stud idea right but missed: CanvasGroup clipping,
the 3-stop gradient, the inner white rim, the Roblox stud asset, gradient-only light bands, ScaledSize strokes.
`templates/example_sim_shop.luau` now follows the real anatomy (chunky() = CanvasGroup version).

Other production details:
- Strikethrough price = a thin red Frame **child of the price TextLabel**, Rotation ~96 (tall/thin), so it
  follows the text. Section titles ("Exclusive!") have a UIGradient on the text itself (white → #999999 bottom).
- Root panel: Frame #282828 @0.05 transparency, studs CanvasGroup at ZIndex -3, Scale layout with
  UIAspectRatioConstraint at every level (280 in one screen). Content = ScrollingFrame + UIListLayout
  (Padding Scale 0.025, AutomaticCanvasSize Y, ScrollBarThickness 0).
- Fonts: GothamSSm ExtraBold / Heavy (Builder Sans ExtraBold is the closest local match for mockups).
- Rainbow outline on a highlighted tab: UIGradient with a rainbow ColorSequence on the button's lip background.
- CanvasGroups everywhere is fine for a menu that is open briefly; do not copy that density into an always-on HUD.

## Text

- **Builder Sans ExtraBold** for titles, tabs, prices, descriptions (it is the successor of GothamBlack, the
  classic simulator font). Small all-caps button labels: Montserrat Heavy. Measured with `font_match.py`;
  Fredoka One scored close on one tab, but the board showed straight-bar "e" and Gotham weight → Builder Sans.
- White text + **UIStroke (Contextual) 3 px** near-black at 769p (title 4+, "2x" 4). Thin 2 px strokes read as
  "not quite right" — the first Studio pass had them and the detail board flagged every label.
- Price text green `#86FF0A` for income ("$??/s"); strikethrough old price = rotated red Frame (4 px, 8°).

## Palette (measured)

| Use | Top | Bottom | Lip |
|---|---|---|---|
| Buy / price / Cash tab | `#B4FF14` | `#52D800` | `#2E8600` |
| Exclusive / Class (blue) | `#12CCFF` | `#0A88E2` | `#0A4C8A` |
| Packs / Vote (yellow-orange) | `#FFF000` / `#FFC61A` | `#F4B400` / `#F28A00` | `#A86600` |
| Gamepass (red-pink) | `#FA7272` | `#DC3030` | `#8A1C1C` |
| Free / banner (magenta) | `#F000F2` | `#9800E8` | `#580090` |
| Shop button (pink) | `#FF5A86` | `#E8235A` | `#8C1D45` |
| Close X | `#FF3A3A` | `#E01414` | `#8A0A0A` |
| Gamepass card green | `#62F52A` | `#42DC14` | `#1F8A12` |
Rarity ladder (when items have rarity): Common grey `#B5B5B5`, Uncommon green `#55D86A`, Rare blue `#3FA9F5`,
Epic purple `#A55EEA`, Legendary gold `#FFC93C`, Mythic `#FF4D6D`, Secret = animated rainbow UIGradient.

## Images (only these)

- **Default: placeholders for cartoon/specific art** (pets, characters, items, badges with illustrated icons,
  catapults, cash stacks...). Production sims use artist PNGs or model renders (a badge + its icon is usually ONE
  image). Build a clearly marked placeholder (rounded Frame, dashed-look stroke, label "ICON: 2x Cash badge"),
  keep the exact box/rotation, and list every placeholder for the user to supply. Draw the illustrations
  yourself only when the user explicitly asks for it. (Geometric HUD glyphs like the AW pack are different:
  draw those.)
- **Sticker icons (only if asked)**: illustrated, thick dark outline (`stroke-width` 6–9 in a 100 box, `paint-order="stroke"`),
  2–3 flat shades + highlight. Draw in SVG, export keep-color. Rotation/tilt is set in Roblox (`Rotation`), never
  baked into the PNG (baked rotation clipped the title icon).
- **Badge**: scalloped ring PNG (dark red outline, white→yellow→orange gradient) + white inner disc PNG tinted
  in engine with a UIGradient (one ring asset serves every badge color) + rays PNG at low alpha + icon + sparkle
  PNGs + "2x" as live text with heavy stroke, slight rotation.
- **Rays** behind featured items (white wedges, ImageTransparency ~0.85, clipped by the card).
- **Stud tile** (17 px rounded square, white) shared by everything.
- **Character/pet art**: comes from the game (ViewportFrame of the model, or pre-rendered PNG). Placeholders are
  fine for layout, but say so.

## Layout conventions

- Left menu: 2-column grid of square chunky buttons (68 px at 769p), icon in the upper 60%, all-caps label at
  the bottom; small square utility buttons (settings, gift) below; red "!" notification sticker, tilted.
- Modal: dark chunky panel; title text overlapping the top edge with its icon tilted on the left; red X chunky at
  the top-right, overlapping. Category tabs as a vertical stack of colored chunky pills attached to the right.
- Featured banner on top (magenta), then section header ("Gamepass!") then a 2-column card grid.

## Motion (not yet Studio-verified for this pack)

Press: scale 0.92 → 1.05 → 1 (spring 0.25, damping 0.5); hover: scale 1.05 + rotate 2°; currency pop; shine sweep
via UIGradient Offset; rays rotate slowly.

## Checklist
- [ ] Every surface uses the chunky recipe (outline, lip, gradient, studs) — no flat Frames.
- [ ] Text strokes 3 px+ at reference resolution; titles 4 px.
- [ ] Child boxes inside repeated components are **component-local**, never copied from the first instance's
      absolute coords (a price button vanished from the 2nd card because of this).
- [ ] Readable on 844x390 phone (text ≥ 18 px effective, buttons ≥ 56 px).
- [ ] Rarity / category colors from one token table.
