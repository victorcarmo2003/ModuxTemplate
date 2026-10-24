# Market study — what the top Roblox thumbnails actually look like (2026-10)

Source: 178 games (160 from roblox.com/charts BR + 18 mega-games fetched by name), icon 512 and first 16:9
thumbnail of each, public thumbnail API. Numbers are averages per image at 384×216 / 256×256.
Re-run with `scripts/market_sheet.py` when you want a fresh sample (the charts change weekly).

## Metrics by genre (16:9 thumbnails)

| Genre | n | dark (<0.2) | bright (>0.8) | contrast (std) | saturation | warm | cool | edges |
|---|---|---|---|---|---|---|---|---|
| Simulation | 57 | 0.18 | 0.14 | 0.23 | 0.56 | 0.26 | 0.31 | 0.14 |
| Survival (horror/anomaly) | 31 | 0.56 | 0.04 | 0.19 | 0.49 | 0.35 | 0.16 | 0.08 |
| Action | 19 | 0.17 | 0.18 | 0.23 | 0.44 | 0.30 | 0.17 | 0.12 |
| Roleplay / Avatar | 12 | 0.17 | 0.25 | 0.23 | 0.40 | 0.23 | 0.17 | 0.12 |
| RPG | 10 | 0.34 | 0.11 | 0.25 | 0.51 | 0.25 | 0.33 | 0.17 |
| Obby | 4 | 0.07 | 0.14 | 0.21 | 0.54 | 0.35 | 0.23 | 0.12 |
| **All** | 178 | 0.27 | 0.13 | 0.22 | 0.52 | 0.28 | 0.25 | 0.13 |
| **Mega (top 18)** | 18 | 0.33 | 0.10 | 0.20 | 0.56 | 0.33 | 0.24 | 0.10 |

Icons are the same picture pushed further: +5 % saturation, warm share 0.50 on the mega set, one subject.

`thumb.py check` warns when an image leaves these bands:
dark 0.10–0.45 · bright 0.06–0.30 · contrast 0.18–0.30 · sat 0.40–0.65 · warm 0.15–0.50 · cool 0.10–0.45 · edges 0.09–0.20.
Horror may sit darker (0.56) **only** with pure-white anchors (eyes, teeth, text) and one focal point.

## What every genre shares (direct observation of the sheets)

1. **One big face or one big object** owns the frame: hero head = 40–70 % of the height (Pet Sim 99, Adopt Me,
   99 Nights, Dandy's World, Cat Battles, Sell Fries).
2. **Huge eyes with pure white** + big black pupil. The eyes are the brightest pixels in the image. For monsters,
   a white eye alone is the whole face (99 Nights icon, DOORS' Figure).
3. **Thick dark outline (2–4 px at 512) or glow** separates character from background in nearly every simulator /
   cute game. Horror separates with rim light + black instead.
4. **Background = real game scene, simplified, blurred or darkened**; it never competes. Saturated blue sky is the
   default simulator backdrop.
5. **Camera low or at eye level, slightly wide**: subject "entering" the frame, hands/props in the foreground,
   forced perspective (huge pumpkin next to a small avatar).
6. **Icon ≠ thumbnail.** Icon is an even tighter close-up (1 face / 1 object / 1 logo). Thumbnail opens to
   2–3 figures + scenery.
7. **Text, when present: 1–3 words**, round heavy font (Luckiest Guy / Fredoka / Lilita / Titan One), white or
   yellow with a thick dark stroke, 10–15 % of the height, top or bottom corner, never dead centre. Simulators
   use giant numbers ("$997,151,167/s", "1 in 900a", "+1 +3", "2X", "NEW", "SECRET").
8. **Saturated subject, calmer background.** Red, orange, cyan and lime are the accent colours.
9. **Frozen on the instant before**: running, hand reaching out, mouth open, "zzz" asleep with the monster behind.
10. **Nothing essential in the bottom 15 %**; main text sits on top.

## Per-genre archetypes

### Horror / anomaly (Survival)
- **Black + one colour** (red: Pressure, Forsaken, Steal or Die; green: DOORS; fire orange: 99 Nights).
- **Partial monster, large, white eyes**: DOORS (Figure peeking through a door), 99 Nights (deer with round white
  eyes filling the icon), IT WANTS IN (skull at the door).
- **Cute-animal anomaly games (Animal Hospital, Sell Fries, Scary Shawarma, Don't Get Fired)** are BRIGHT,
  well-lit interiors (waiting room, kitchen), cute characters in a line / at a counter, and the anomaly is ONE
  wrong detail (toothy mouth on the middle bunny, a pumpkin with red eyes at the window). Not dark. The fear
  comes from cute × wrong, not from darkness. **This is the archetype for family-friendly horror.**
- Logo in a "dirty"/dripping face (DOORS, Pressure, Forsaken) or no text at all.

### Simulator / tycoon / incremental
- Saturated blue sky, green grass, confident-eyebrow happy avatar.
- Absurd numbers in giant text; arrows "+1 +3"; NEW / 2X / SECRET badges.
- One oversized object (pumpkin, egg, dinosaur) next to the small avatar.
- Rainbow palette, zero black.

### Cute / pets / roleplay
- Character looking at the camera, big head, pink cheeks, open smile.
- Pink / light-blue background with sparkles, particles, gems.
- Game title as a logo (ADOPT ME!, Brookhaven, LifeTogether) in white with stroke.
- Dress to Impress = editorial / influencer look (realistic render, pastel, bokeh).

### Obby / party / minigame
- Two characters with opposite expressions (smug vs terrified), comedic action.
- Sunset colours (pink / orange / purple), everything saturated.
- Arrows and circles explaining the mechanic (Scooter Duo, Hide in Pixels).

## Reference games by archetype

| Archetype | Reference | Use it for |
|---|---|---|
| Cute + one wrong detail (bright) | Animal Hospital, Sell Fries, Scary Shawarma | family horror, anomaly games |
| Big hero + monster behind (dark) | 99 Nights (thumb), DOORS | "it's behind you" |
| Monster only (icon) | 99 Nights (icon), Pressure, IT WANTS IN | icons for horror |
| Chase / action | Cat Battles, Fart Obby, Bumpy Flight | low camera, wide lens, motion |
| Giant number / NEW | Steal a Brainrot, Grow a Garden | simulators, updates |
| Pet close-up | Pet Simulator 99, Adopt Me | cute games, icons |

## Refreshing the study

1. Open roblox.com/charts in a browser, scroll to the bottom, run in the console:
   `JSON.stringify(Object.fromEntries([...document.querySelectorAll('a[href*="universeId="]')].map(a=>[new URL(a.href).searchParams.get('universeId'),a.textContent.trim().slice(0,40)])))`
   and save as `charts.json`.
2. `python scripts/market_sheet.py --ids charts.json --search "DOORS" "Adopt Me" --out market`
3. Read the sheets per genre; update the table above and the `BANDS` in `thumb.py` if the market moved.
