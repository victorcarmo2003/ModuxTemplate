# Rules — composition, psychology, colour, type, Roblox limits

Condensed from the market study (`market-study.md`) plus research notes (Roblox Creator Hub, DevForum, vidIQ 2026
thumbnail study, Glocker 2009 on cuteness, Cantor on children's fear, Palcu 2017 on gaze cueing). Where a number
is our own recommendation rather than a sourced fact it is marked (rec.).

## 1. One picture, one question
- Max **3 elements**: hero, threat/goal, one prop. Everything else is background.
- Freeze the **instant before** the event. The viewer must be able to form the question ("will it see him?",
  "which one is wrong?", "will she make it?").
- **One focal point** carried by value contrast: the brightest, sharpest, most saturated spot is the face (or the
  monster's eyes). Second element reads second; nothing ties.
- Gaze: hero looking at the camera = connection; hero looking at the threat = the viewer looks there too
  (gaze cueing). Good first A/B variable.

## 2. Scale and camera
- Hero head **40–70 % of the frame height** in a thumbnail, **60–90 %** in an icon. If the face is smaller than
  25 % you are shooting a scene, not a thumbnail. Children's attention goes to big faces and big eyes.
- Monster cut by the frame edge, bigger than the hero, partially hidden (door, shelf, shoulder).
- Camera **low** (threat looks bigger) or **eye level**; high camera only to make the hero look small/vulnerable.
- **FOV 50–65°** for drama with the hero near the lens; **35–45°** to compress a monster "right behind" the hero.
- Three depth planes: sharp hero in front, mid prop, blurred/dark threat or scenery behind.

## 3. Light
- **Warm hero, cool world** (or the reverse) — temperature contrast is what makes the subject pop, not brightness.
  Target in `thumb.py check`: warm 0.15–0.50 and cool 0.10–0.45 at the same time.
- **Rim light** on every dark subject (3–6 px band) or it becomes a blob at 250 px.
- Horror: ~75 % cool (night blue / cyan / purple) + ~25 % warm (a lamp, the hero) + **pure white** as the loudest
  accent (eyes, teeth, text). Family horror (Animal Hospital type): bright room, cute faces, ONE wrong detail.
- Simulator / cute: saturated sky, flat shadows, everything lit; dark pixels < 15 %.
- Stage the light in-engine (Studio PointLight/SpotLight, black ambient for horror) rather than painting it later:
  it reads as "a photo of the game" and the owner of this skill prefers it to painted effects.

## 4. Finish (post)
- **Outline**: uniform distance-field outline 8–12 px dark at 1080p on the hero (the market standard), optional 4–6
  px white inner ring for the sticker look. Horror can skip the outline and use rim + glow instead.
- **Glow**: only around monsters / emissive things; 40–70 px, strength ≤ 0.8. Keep eye glow tight (1–2 % of
  height); soft glow everywhere turns into grey mush on a phone.
- **Background**: blur 3–7 px, desaturate 20–45 %, darken 15–30 %, keep ONE accent (a red cap, a neon sign).
- **Grade**: contrast +5–10 %, saturation +5–15 % on subjects only, light teal-and-orange (`warm_cool` 0.1–0.2),
  vignette 25–40 % biased to the bottom.
- **Sharpen** after the final resize only: unsharp 0.3–0.6, radius ~1 px. Our earlier batch failed here —
  edge density 0.05 vs market 0.13 — because blur + soft light + no outline.
- No fake shadows of things that are not in the scene; no gore; no blood (Mild rating).

## 5. Text
- **0–3 words.** 28 % of breakout YouTube thumbs have no text; the rest median 5 words (vidIQ). Roblox asks for
  text "sparingly" and only about gameplay — no "BEST GAME", no claims.
- Size **12–20 % of the height** (rec.), heavy round font (see `fonts.md`), white or yellow→orange gradient,
  dark stroke **0.9–1.2 % of height** (10–13 px at 1080p), optional white outer stroke 2 %, hard shadow offset
  0.6–1 % no blur, tilt −5° to −12° for action.
- Position: top band or a corner; **never the bottom 15 %** (player-count overlay) and never over the face.
- Icon: no text, or only the logo.

## 6. Roblox limits and ratings
- Thumbnail **16:9, 1920×1080, < 3 MB**; other ratios get stretched. Up to 10 per game. Icon **512×512**,
  displayed as small as **150×150**.
- Thumbnail Personalization: activate **2–5** thumbnails, Roblox splits impressions and favours the winner
  (+8.5 % average, up to +50 % reported). Change thumbnails per big update, one big variable at a time.
- **June 2026: QPTR retired.** Ranking now uses Play-Through Rate and First-Play Bounce Rate — a click that
  bounces in seconds counts against you. Show the real game; the hook must exist in-game.
- Content maturity: jump scares and creepy NPCs = **Mild**; disfigured mouth with realistic blood = Moderate.
  Cartoon teeth yes, blood no. Realistic gore gets moderated regardless of rating.
- Community Standards forbid "deceptive, sensational, misleading content or metadata" in thumbnails.
- No real brands / other games' characters / IP.

## 7. Legibility gate (every deliverable)
Run `thumb.py check` and look at the preview: 250×141 colour, 250×141 greyscale (150×150 for icons).
Pass = you can tell who the hero is, what the threat/goal is, and where to look, in under a second, in grey.
Also fill the subjects' silhouettes black in your head: if the silhouette alone does not read, re-pose.

## 8. A/B plan
Test one big variable per round, in this order: concept → focus (hero vs monster) → expression → gaze
(camera vs threat) → palette (cool vs warm world) → character species → text on/off.
