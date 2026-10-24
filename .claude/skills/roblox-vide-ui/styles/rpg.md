# Style pack: RPG / fantasy / MMO (v1 — Studio-tested 2026-10-05 on an original inventory screen)

Diablo, Genshin, WoW, Elden Ring, Deepwoken-like Roblox RPGs. Two dialects: **ornate classic** (gold filigree,
dark stone/leather, embers) and **clean modern fantasy** (Genshin: soft cream panels, thin gold lines, diamond
accents). Worked example: `templates/example_rpg_mockup.py` (design + ornaments) and
`templates/example_rpg_inventory.luau` (interactive Vide screen: tabs filter, click selects, tooltip follows);
**v2 after the material pass:** `templates/example_rpg_inventory_v2.luau` + `references/material-pass.md`.

> User verdict on v1: layout/typography good, but **"too raw — gradients alone are not enough, the ornaments
> look like 2010 Flash games"**. Flat vector line-ornaments + flat fills = dated. v2 fixed it with the
> material pass (Blender-lit gold/iron/ember ornaments, Poly Haven leather, recessed slots, shadows, embers) —
> read `references/material-pass.md` before building any RPG screen.

## Principles
1. **Ornament lives in corners, calm edges, clean content.** Panels = 9-slice frame: filigree corners
   (curls + diamond + dots), double gold rule on the edges (3 px outer gradient gold + 1.2 px inner at 70%).
2. **Material palette (ornate):** stone/leather `#120E0B` → `#1E1712`, well `#0A0806`, gold `#C9A45C`
   (hi `#F3D88B`, lo `#6B4E24`), ember accent `#E0662A` (selection, active tab underline), text `#EDE3CF` /
   `#A89A82` / `#6E6353`. Modern: cream `#ECE5D8`, ink `#3B4255`, gold line `#D3BC8E`.
3. **Rarity ladder, used in 4 places consistently** (slot tint 12%, 3 px bottom bar, tooltip border/band,
   item name): common `#C8C8C8`, magic `#6E8BFF`, rare `#FFE15C`, epic `#B86BFF`, legendary `#FF8A1F`.
   Bonus stat lines green `#7CDB6A`, unique effects in the rarity color.
4. **Typography (Roblox families, measured line/em -> Roblox TextSize = CSS px x ratio):**
   titles **Grenze Gotisch Bold** (1.48), item names & numbers **Merriweather Bold/Heavy** (1.25), lore
   **Fondamento Italic** (1.39), labels/body **Source Sans Pro SemiBold** (1.25), uppercase for labels.
5. **Diamond grammar.** Dividers = gradient-faded gold rule + center diamond + two small diamonds. Bar ends,
   title plate ends and the close button are diamonds.
6. **Atmosphere** (necessary, not sufficient): ember glow rising from the bottom + vignette as two black Frames
   with edge-only transparency gradients (X and Y).

## Material pass (what v1 lacked)
- Surfaces need a **material texture**, not a gradient: seamless tiled stone/leather/parchment/metal
  (CC0 Poly Haven textures via the Blender MCP, or procedural fBm noise + fibers generated in Python), low
  contrast, color-graded with ImageColor3, under the gradients.
- Ornaments need **light**: bevel + specular (SVG `feDiffuseLighting`/`feSpecularLighting` on the alpha as bump,
  or a real render: model/extrude the filigree in Blender with a metallic gold material + HDRI, orthographic,
  transparent background) plus a baked **drop shadow** under them. Flat 1-color line art reads as clipart.
- **Depth**: recessed slots (inner-shadow 9-slice PNG) instead of drawing a gold outline on every slot; panels
  get an inner shadow along the frame and a soft outer shadow on the world.
- **Fewer outlines**: gold is for the frame and the selected/active thing; everything else separates by value
  and depth.
- Real item icons change everything — placeholders keep a screen looking raw; say so in the report.

## Technique table (as built in v1)
| Element | Build |
|---|---|
| Ornate panel frame | draw the frame SMALL (200x200, corners 64) only for export -> 9-slice `SliceCenter` from layout, `SliceScale 0.5`. Drawing it at panel size exports 2640 px (> 1024 cap) |
| Title plate | elongated hexagon cartouche PNG (fixed size) + Grenze Gotisch text on top |
| Vertical divider | the horizontal divider PNG with `Rotation = 90` (a vertical export was 1296 px tall) |
| Slot | native Frame + rarity tint Frame + rarity bar + slot-type glyph (white PNG @0.82 transp.) when empty + corner-tick 9-slice PNG overhanging 4 px (`Rect(32,32,136,136)`, SliceScale 0.5) |
| Item art / character | **placeholders** (rarity tint + short label / "ViewportFrame placeholder"); list them |
| Selection | ember ring PNG + soft glow PNG as **children of the selected cell**, cell ZIndex raised (UIGridLayout positions every sibling, so a glow cannot be a sibling inside the grid) |
| Grid | `UIGridLayout` + `Vide.indexes` over the filtered list padded with `false` to the cell count |
| Tabs | TextButtons; active = warm bg `#3A2216`, gold stroke 1.5, ember 2 px underline, gold text |
| Bars | well Frame + fill with 4-stop gradient (dark edge -> color -> lighter band -> dark edge), `spring` on the ratio, horizontal-only 9-slice frame with diamond caps (`Rect(28,22,620,26)`: slice margins must fit the bar height) |
| Tooltip | Frame AutomaticSize Y + UIListLayout rows from item data; UIStroke + band in rarity color; corner-tick 9-slice overlay sized `UDim2.new(1,8,1,8)` so it follows the auto height |

## Lessons from the test
- Mockup first paid off: two self-critique passes in the browser cost seconds; the Roblox build then matched it.
- A tooltip anchored right of the slot covers neighbouring items (verified: 3 potions hidden). Hover: follow the
  cursor with edge flipping; click-select: consider a docked details pane.
- Expose initial state as props (`InitialTab`, `InitialSelected`) so stories/captures show every state.
- When measuring fonts in an ad-hoc page, put the text in the DOM before awaiting `document.fonts.ready`
  (fonts load on use; measuring first gave fallback metrics for every family).

## Checklist
- [ ] Material texture under every large surface; ornaments lit (bevel/specular) with a drop shadow.
- [ ] 9-slice sources small (<= 1024 at export scale), margins fit the element size, no smear.
- [ ] Rarity color identical in slot tint, slot bar, tooltip border/band and item name.
- [ ] Gothic/serif titles, readable sans labels; no sci-fi condensed fonts.
- [ ] Illustrations are labelled placeholders + listed for the user.
- [ ] Tooltip never hides the item it describes; auto height verified with a short and a long item.
