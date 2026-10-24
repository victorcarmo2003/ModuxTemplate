---
name: roblox-thumbnail
description: Produce high-CTR Roblox game thumbnails (16:9) and icons (512x512) for any genre - horror, anomaly, simulator, tycoon, pets, roleplay, obby, action - from scene staging in Studio (camera, poses, in-engine lighting, matte/chroma passes) through compositing (outline, glow, text with stroke, warm/cool grading, vignette) to a legibility gate and A/B variants, following a 2026 study of 178 top Roblox thumbnails. Use this skill whenever the user asks for a thumbnail, icon, game-page art, ad creative, "capa", "thumb", key art, A/B thumbnail variants, or says a thumbnail "has no focus / no pop / low CTR", even if they only ask to "take a nice screenshot of the game for the store page". Prefer it over ad-hoc screenshots or generic image editing for anything that will be shown on a Roblox game card.
---

# Roblox thumbnail — from scene to high-CTR game-card art

A Roblox thumbnail is not a screenshot. It is a 250 px card competing with 20 others for a child's one-second
glance. The top games share a recipe (measured on 178 of them, see `references/market-study.md`): **one big
expressive face, pure-white eyes as the brightest pixel, thick outline or rim light separating subject from a
simplified background, warm-vs-cool colour contrast, 0–3 words of fat text, nothing important in the bottom 15 %.**
Our own first batch (14 thumbs, CTR flat) failed on exactly these: no white anchor (1 % bright pixels vs 13 %),
monochrome warm (no cool counter-colour), soft (edge density 0.05 vs 0.13), subjects too small.

This skill gives you the recipe, the numbers, scripts that do the mechanical parts, and a gate that tells you
when a thumb is still "flat".

## 0. Read first
- `references/rules.md` — composition, scale, light, finish, text, Roblox limits, A/B order. **Read every time.**
- `references/market-study.md` — the metrics table + per-genre archetypes + reference games. Read when picking a
  concept or when `check` warns.
- `references/fonts.md` — bundled free fonts and which genre uses which.
- `references/spec.md` — every field of the compose spec.
- Deeper research, read only when a question comes up: `research-roblox-platform.md` (official limits, A/B,
  moderation, ad formats), `research-psychology.md` (faces, curiosity gap, children's fear, composition sources),
  `research-typography-colour.md` (fonts, text treatment, grading numbers), `research-pipeline.md` (Blender route,
  4K capture in Studio, artist workflow, market prices). `assets/ref_*.png` — contact sheets of the top games.
- Project docs outrank this skill (style guide, approved decisions, rating). If the project says "no outline", skip
  the outline and get separation from rim light + background darkening instead.

## 1. Brief → concept (10 minutes, before touching Studio)

Answer in writing, one line each:
1. **Genre archetype** (`market-study.md` §archetypes): cute+wrong-detail, hero+monster-behind, monster-only icon,
   chase, giant-number, pet close-up, …
2. **The question** the image asks ("will it see him?", "which one is wrong?"). No question → no click.
3. **Hero** (species/outfit/expression) and **threat or goal**. Max 3 elements.
4. **Focal point** and where it sits (left or right third, upper half). The face is the brightest, sharpest spot.
5. **Palette**: hero warm / world cool, or the reverse. Name the ONE accent colour (red cap, cyan sign).
6. **Text**: none, or 1–3 words + font from `fonts.md`.
7. **Camera**: low/eye-level/high, FOV 35–45 (compress threat behind) or 50–65 (drama, hero near lens).

Write the concept as a spec skeleton (`assets/templates/*.json` has one per archetype) before shooting, so the
shots are taken for the layout and not the other way round.

## 2. Shoot in Studio (layers, same camera every pass)

Load `scripts/studio_capture.luau` through the Studio MCP `execute_luau` once per session (it defines `_G.Thumb`),
then stage with its helpers:

```lua
local T = _G.Thumb
local f = T.stage("Scene_Hero")                 -- Workspace.ThumbnailScenes.Scene_Hero
-- place/clone models into f, pose with T.pose(model, {["Right Shoulder"]=90, Neck={-20,0,0}}), T.face(model, camPos)
T.noNames(model); T.eyes(monster, {W=0.7, H=0.75})      -- white Neon eyes = the white anchor
T.lookDark(0.4); T.rig3(f, hero, warm, cool)   -- horror: black ambient + 3-point rig; T.lookDay() for bright genres
T.fx({DOF={8,4,0.4,0}})                         -- optional camera post for the beauty pass
T.cam(pos, lookAt, 50)
```

Passes (one `screen_capture` each, **re-call `T.cam` with a 0.02-stud nudge before every capture**: Studio only
refreshes local lights after the camera moves; if the viewport comes back empty, ask the user to click it):
1. **beauty** — the lit scene.
2. **matte visible** — `T.matte(f, {Hero=Color3.fromRGB(0,255,255), Monster=Color3.fromRGB(255,0,255)}, "visible")`
   → flat colours, occluders respected. Use as `mask` in the spec so a counter/shelf in front keeps covering the hero.
3. **matte full** — same with `"full"` when you need the hidden part (outline that stops at the occluder).
4. **chroma solo** (optional, for a clean cutout to reposition/scale freely): `T.chroma()` then
   `T.solo(f, "Hero", offset, camPos, camLook, fov)` per character; neutral day light; use `key: "green"` (or
   `"magenta"` via `T.chroma(Color3.fromRGB(255,0,255))` when the character wears green).
5. **background plate** — `T.showOnly("__none__")` or park the characters, capture the empty scene.

Screenshots come out at viewport size; for 4K, set Device Emulator to a custom 3840×2160 with "Actual
resolution" before capturing. Save every pass next to the spec. **Always finish with `T.cleanup()`** — it removes
`ThumbnailScenes`, `ThumbnailChroma`, parked folders, hidden-part attributes and restores Lighting and the camera.
Blender route (icons, special poses): render the rig with film transparent → PNG RGBA → `key: "alpha"`.

Pitfalls seen in production (all handled by helpers):
- Green lines on a rig = WeldConstraint gizmos → `T.stripWelds(model)` (thumb models are anchored).
- Rig textures grey in a fresh session → `ContentProvider:PreloadAsync` the TextureIDs/ColorMaps, wait, re-dress.
- Map lights blow the plate under `lookDark` → `T.dimLights(mapFolder, 0.15)`; cleanup restores them.
- `T.showOnly("__none__")` parks **every** scene (good for the plate); lights for the plate go in their own folder.
- Posing: `T.freezePose(m, {Neck={yaw,pitch,roll}, ["Right Shoulder"]={lift}})` once on a fresh rig. Never edit
  Motor6D.C0 on an anchored rig or rotate the Head after `stripWelds`: the model tips over, or the Face part
  stays put and the face floats off the head (a thumb the owner rejected). Yaw 180 = "neck inverted".
  `T.hold(m, toolInstance)` after the pose.
- Shoot a chroma group (a queue) in one pass with the same offset: `model:PivotTo(pivot + offset)` for each,
  camera + offset. Composite the group as one layer; a red `spot` behind the wrong one marks it. A foreground
  prop (counter) comes back as a `key: "none"` + `crop` layer cut from the plate, drawn between group and hero.
- A character cut by the frame edge gets a flat outline edge; pull the camera back so the cutout is whole and
  let the canvas crop it instead.
- `T.cleanup()` restores Lighting from the FIRST snapshot it took (on the first `T.lookDay/lookDark/stage`). If you
  change Lighting by hand before calling any `T.*`, snapshot first or keep your own backup and restore it AFTER
  `cleanup` — otherwise cleanup "restores" your edited values (happened 2026-10-18).
- Green fringe on the cutout (bounce from the chroma walls, half-transparent edge): layer `choke` 2–3 px +
  `spill` 18–24. Zoom the head/shoulders at 100 % before delivering; the owner spots it at once.
- "Which one is wrong" in a group pass: layer `highlight` {region (source px) or mask, color, width, fill,
  glow} draws a Roblox-Highlight-style outline on that one character only.
- Text with `rotate` near the top edge clips: keep `at` y ≥ 0.15 or size ≤ 0.13 for long phrases.

## 3. Compose

```
python scripts/thumb.py compose spec.json        # writes the PNG, then prints check metrics + warnings
python scripts/thumb.py check out.png [--icon]   # 250 px / 150 px colour + greyscale preview, metrics vs market bands
python scripts/thumb.py batch spec.json --vary "text.0.text=\"RUN!\"|\"DON'T LOOK\"" --vary "layers.1.flip=true|false"
```

Defaults that match the market (1080p): hero `height` 0.9–1.2 anchored at the bottom edge, head in the upper
half; `outline` 8–12 px dark + optional `outline2` 4–6 px white; monster `glow` 40–70 px ≤ 0.8; background `blur`
2–5, `saturation` 0.5–0.7, `brightness` 0.75–0.9, cool `tint` when the hero is warm; `grade.warm_cool` 0.1–0.2,
`vignette` 0.3 with `bottom_bias`; final `sharpen` 0.3–0.6. Text `size` 0.14–0.18, stroke 0.011, yellow→orange
gradient for simulators, white for the rest, top band.

Icons: `size: [512, 512]`, one subject at `height` 0.85–1.0, no text or logo only, `--icon` on check.

## 4. Gate (do not deliver without it)

`check` prints the market bands and a `_check.png` with the 250 px colour and greyscale preview. Look at it:
- Who is the hero, what is the threat/goal, where do I look — readable in grey in under a second?
- Warnings: `no bright anchor` → bigger/whiter eyes or text; `monochrome warm` → cool the background or add a cool
  rim; `edges low` → less blur, add outline, sharpen; `dark high` (non-horror) → lift the plate.
- Bottom 15 %: nothing essential (player count overlay). Top: text does not touch the edge.
- Rating: cartoon teeth yes, blood no; no other game's characters or brands; the scene must exist in the game
  (Roblox now ranks on play-through and first-play bounce — a misleading click is punished).

## 5. Deliver and test
- Thumbnail 1920×1080 PNG < 3 MB (JPEG q92 if over), icon 512×512.
- 2–5 variants into Thumbnail Personalization; change one big variable per round (`rules.md` §8); review after a
  week and after each big update. Keep the specs: a variant is a one-line change.
- Note what you learned in the project's marketing doc (what won, what the gate flagged).

## Scripts and assets
- `scripts/thumb.py` — compose / check / batch (Pillow + OpenCV + numpy).
- `scripts/studio_capture.luau` — staging, lighting rigs, poses, eyes, matte/chroma passes, cleanup.
- `scripts/market_sheet.py` — pull the current charts' icons/thumbnails into per-genre contact sheets + metrics.
- `assets/fonts/` — 16 free display fonts (`fonts.md`). `assets/templates/` — one spec per archetype.
