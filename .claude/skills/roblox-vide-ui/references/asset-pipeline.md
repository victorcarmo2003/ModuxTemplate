# Asset pipeline: SVG mockup → PNG layers → Roblox

## 1. Author the mockup (one SVG at 1920x1080)

Start from `templates/mockup.svg`. Conventions read by `export_layers.py`:

| Id | Becomes | Attributes |
|---|---|---|
| `group-NAME` | container Frame (children positioned relative to it) | `data-anchor="br"` (tl,tc,tr,ml,mc,mr,bl,bc,br — first letter t/m/b, second l/c/r) |
| `asset-NAME` | white PNG + ImageLabel, color read from its fill → ImageColor3 | draw it in its real color; `data-tint="#hex"` (override), `data-glow="6"`, `data-slice="12"`, `data-keep-color="true"`, `data-z="2"` |
| `frame-NAME` (a `<rect>`) | native Frame | fill, fill-opacity / opacity |
| `text-NAME` (a `<text>`) | TextLabel | font-family/weight/size, fill, text-anchor |
| `ref`, `guide-*`, `bg*` | ignored (hidden on export) | put the reference `<image id="ref" href="...">` here while aligning |

Authoring rules:
- Coordinates in reference px. Read them from `grid.py` zooms, never by eye.
- Use `shapes.py` primitives (import it from a small Python generator script, like `templates/make_mockup.py`)
  so geometry is parametric: changing the arc segments = changing one number.
- Fonts: paste `roblox_fonts.py "<Family>"` output inside the `<svg>` so the mockup renders with the Roblox font.
- Opacity on the element (not baked into colors) — exported as `*Transparency`.
- States: prefer one white shape + tint/transparency per state. When a state needs different art
  (`asset-cell_full` vs `asset-cell_empty`), put the alternates in a second file (`mock_states.svg`) at the same
  coordinates. `display="none"` elements have an empty box and export as nothing.
- A group needs an invisible bounds `<rect fill="none">` if its visual box should be larger than its ink.

## 2. Render + compare (cheap loop)

```
python render.py mock.svg -o mock.png
python render.py mock.svg -o over.png --bg ref.jpg --opacity 0.6     # misalignment shows as ghosting
python compare.py ref.jpg mock.png -o cmp.png --crop x,y,w,h          # scores per HUD region
```
Iterate on the SVG until the overlay shows no ghosting on the elements you recreate.

## 3. Export

```
python export_layers.py mock.svg -o out/ --scale 2
```
- `out/<name>.png` white + alpha, `out/<name>_glow.png` if `data-glow`, `out/layout.json`, `out/_preview.png`.
- WARN lines: an asset > 1024 px at that scale. Lower `--scale` for big panels (1.5 or 1) or split, or 9-slice it.
- Hairline check: any stroke that becomes < 2 px in the PNG will shimmer — thicken in SVG or make it a Frame.

## 4. 9-slice, atlas, digits

- Resizable panels: `data-slice` in the mockup, or after export `nineslice.py out/panel.png --preview 900x300`.
  Corners (chamfers, brackets) must be fully inside the margin. Use `SliceScale = 1/exportScale`.
- Many small icons: `atlas.py out/icon_*.png -o hud_icons.png --luau HudIcons.luau`.
- Hero numerals with no matching Roblox font (`font_match.py` best score < 0.75 or width error > 10%):
  render `0123456789` glyphs from a licensed font (OFL e.g. Barlow Condensed, Saira Condensed, Rajdhani)
  into an atlas, compose digits with `UIListLayout` (Horizontal, Padding = tracking). Keep the reserve/small
  numbers as real text.

## 5. Upload

Prefer, in order:
1. **The project's pipeline** (e.g. `tools/upload/upload.py` + `manifest.json` → generates `AssetIds.luau`).
   Add a manifest entry/glob for the new PNGs, run `--dry-run`, then real run. Never print or log API keys.
2. **Roblox Studio MCP `upload_image`** — takes **http(s) URLs**, not file paths. Serve the folder locally:
   `python -m http.server 8765 --directory out` (run in background), then
   `upload_image(imagePaths=["http://localhost:8765/battery.png", ...], studio_id=...)` → map url → rbxassetid.
   Stop the server afterwards.
3. **`robloxstudio` MCP `upload_decal`** (Decal asset; needs cookie or Open Cloud env). Decal ids are not
   Image ids — convert/verify the image id before use (a Decal's texture id differs from the decal id).
Record every id in **one** Luau module (project's `AssetIds` or a `HudAssets.luau`), keyed by asset name.
Write down the file hash → id mapping so unchanged files are not re-uploaded.

Moderation: freshly uploaded images can render blank for a while. Don't "fix" code because of it — verify the
id in the Toolbox/asset page or wait and re-capture.

## 6. Naming

`<area>_<element>[_<variant>][_glow].png` — `hud_ammo_frame`, `hud_exo_cell_full`, `shop_card_epic`.
Luau keys in PascalCase of the same name.
