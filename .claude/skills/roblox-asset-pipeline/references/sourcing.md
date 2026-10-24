# Sourcing free models

## Families (verified 2026-10)

| Family | Licence | Colour | Good for | Notes |
|---|---|---|---|---|
| **Kenney** (kenney.nl) Food Kit, Car Kit, City Kit Roads/Commercial/Suburban, Mini Market, Furniture | CC0 (License.txt in each zip) | colormap atlas (~512², same ~30-colour family, **different file per pack**) | food, roads, buildings, cars, market | Zips: `curl` the page, grep `media/pages/assets/<pack>/.../*.zip` |
| **KayKit** (kaylousberg.itch.io) Restaurant Bits, City Builder Bits | CC0 | gradient-band atlas 8×4 (`restaurantbits_texture.png`) | kitchen/counters/crates | itch.io "name your price" needs a human click - ask the user to download |
| **Quaternius** | pages say CC0, licence page changed to "QAL v1.0" (no redistribution) | flat colour | junk food, city | treat as ambiguous; avoid or ask |
| **Poly Pizza** (via Blender MCP `search_assets source=polypizza`) | CC0 or CC-BY per model | varies | single gaps (Kenney/KayKit items are on it too) | prefer Kenney/KayKit authors; CC-BY = credit |
| **Sketchfab** | per model; no download = all rights reserved | PBR/hand-painted | rarely fits low-poly families | needs API key in the addon |
| Poly Haven | CC0 | realistic PBR | textures/HDRIs, not toy props | |

"Hand-painted, free, covers a whole game" did not exist (research 2026-10). Mixing hand-painted packs from many
authors fails coherence. Kenney + KayKit as-is won the user's side-by-side test.

## Mapping table (one row per sheet)

`ID | name | candidate file(s) | fit (direct / edit: what / model) | risk note`. Prefixes keep it short
(`FP/` FoodPack, `KP/` KitchenPack, `CK/` Car Kit, `CR/` City Roads, `CC/` City Commercial, `CS/` Suburban,
`MM/` Mini Market). Look at the actual previews (`Previews/*.png`) before claiming a file fits - names lie
(`hot-dog-raw` is the sausage alone, `sausage` is a tied link, `meat-sausage` is curved, `cup` is a mug).

## Brand / reserved-trait traps found

- Cars: police/taxi liveries, real-car silhouettes; ambulance crosses (check ALL sides); a building with a green
  pharmacy cross; soda bottle shaped like a famous brand; fast-food red/yellow fries box; USPS-like mailbox
  (blue + rounded) and Royal-Mail-like (red cylinder) → generic green box instead.
- Project-reserved colours/traits (anomaly colours, gold for one item) must not appear on generic props.

## Approval boards

1. `thumbs.py` renders every candidate with the same ortho camera/sun (transparent bg) - one PNG per key.
2. `board.py rows.json` lays one row per sheet: label + fit colour (green direct / yellow edit / red model) +
   note + candidate thumbnails. Arial font (PIL default breaks accents).
3. Copy boards into `docs/art/sourcing-boards/`. The user approves per category; record it, then build.
Boards are cheaper than Studio previews; Studio previews are better for scale/feel - do boards first, then a
test batch per category in Studio before mass work.

## Downloads

Put each download in its own new folder (untrusted data), extract with Python `zipfile` checking for path
traversal, verify `License.txt`, then move to `Assets/<PackName>`. Atlas count grows with packs (each Kenney
pack has its own colormap): record it and let the art owner decide (accept N atlases or re-UV into one).
