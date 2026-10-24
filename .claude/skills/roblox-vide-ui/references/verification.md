# Verification: capture, compare, iterate

"It compiles" is not "it looks like the reference". Every UI task ends with a capture and a comparison.

## Capture options

| Option | How | Notes |
|---|---|---|
| UI Labs story | open the story in Studio (UI Labs plugin), set controls, then capture | best: isolated, every state reachable |
| Roblox Studio MCP | `screen_capture(capture_id, studio_id)` (edit mode viewport) | UI must be visible in the edit viewport: parent a test ScreenGui to `StarterGui` or mount into `CoreGui`-like preview via `execute_luau` |
| robloxstudio MCP | `capture_screenshot()` | needs Game Settings > Security > "Allow Mesh / Image APIs"; edit mode |
| Playtest | `start_playtest` / `start_stop_play` then capture | needed for live data / player-driven HUD |
| User screenshot | ask the user to drop a PNG | fallback |

Set the viewport to the reference aspect before capturing (Studio device emulator, 1920x1080 custom device).
Captured image size ≠ 1920x1080? `compare.py` resizes; but aspect must match or positions drift.

**Capture stage (use this, proven on the AW test):** the Studio viewport is rarely 16:9 (e.g. 1148x794).
Mount the UI inside a 16:9 letterboxed Frame with a flat background close to the reference world color
(UIAspectRatioConstraint 16/9, AnchorPoint 0.5, black ScreenGui background), and pass `Scale = stageHeight/1080`.
Then crop the stage rect from the capture and resize to 1920x1080:
`Image.open(cap).crop((0, stageY, W, stageY + stageH)).resize((1920, 1080))`.
Render the mockup over the same flat color (`<rect id="bg" fill="#5A5F64">`, ignored by export) and compare
mock vs capture — background identical, so the scores measure only the UI.
Do not upload copyrighted reference screenshots to Roblox just to use as a background.

**Fastest iteration (Studio-verified): fetch the module over HTTP.** Serve the work folder
(`python -m http.server 8769 --bind 127.0.0.1`, run in background) and in `execute_luau`:
`mod.Source = HttpService:GetAsync("http://127.0.0.1:8769/Component.luau", true)` then remount. Edit the local
file, rerun the same short mount script — no pasting hundreds of lines. Needs `HttpService.HttpEnabled` (check it;
ask before enabling it in someone's place). Stop the server at the end.

If the reference is not 16:9 (e.g. a 1275x769 Studio screenshot), set the stage `AspectRatio` to the
reference's own aspect and the scale to `stageHeight / refHeight`; `detail_board.py` resizes the capture to the
reference size automatically.

Iterate without re-pasting the whole module (fallback when HTTP is off): keep the component in a ModuleScript under
`ServerStorage.__UITest`, patch its `Source` with `gsub` from `execute_luau`, and `require(mod:Clone())` (the
clone bypasses the require cache).

Quick mount for capture (edit mode) via `execute_luau`:
```luau
local Vide = require(game.ReplicatedStorage.Packages.Vide)
local Comp = require(path.to.Component)
local gui = Instance.new("ScreenGui")
gui.Name = "__UICapture"
gui.Parent = game:GetService("StarterGui")
local destroy = Vide.mount(function()
	return Comp({ --[[ static props for the state under test ]] })
end, gui)
-- capture, then: destroy(); gui:Destroy()
```
Always remove the capture ScreenGui (and `ServerStorage.__UITest`) afterwards — StarterGui content ships.

Reference result (AW weapon panel, 2026-10-05): mock vs Roblox capture went ssim 0.908 / edge 0.809 (round 1,
TextSize capped) → 0.946 / 0.946 (round 2, text fixed) → glow layering fixed in round 3. Ref vs capture
edge 0.80 — the rest was font shape (Oswald vs AW condensed) and approximated icon art.

## Compare

```
python compare.py ref.jpg capture.png -o cmp.png --crop <hud region>
python compare.py mock.png capture.png -o cmp2.png            # did the Roblox build match the mockup?
```
Two comparisons, two different questions:
- **mock vs capture** → implementation errors (positions, fonts, transparency, missing glow). Should be near
  identical (edge > 0.85). If not, the bug is in the Roblox build.
- **ref vs mock** → design errors (wrong shape language, proportions). Fix in the SVG first.

Look at the board image every time; scores alone miss "right shapes, wrong vibe".

## Detail pass (mandatory, after the global compare)

```
python detail_board.py ref.jpg capture.png --layout out/layout.json --only "asset-*" --zoom 3 -o details.png
python detail_board.py ref.jpg mock.png --layout out/layout.json --zoom 3      # same, before uploading
python detail_board.py capA.png capB.png --box "name:x,y,w,h" --zoom 4         # before/after of one fix
```
Read every tile against this checklist (each item was a real miss in the AW test):
- [ ] **Reads as the thing.** Cover the reference and ask what the icon depicts; then compare. Thin connectors
  (stems, axles, cables, struts) carry the meaning — a drone without the stem joining turret to body reads as
  "random blocks".
- [ ] **Related parts share an axis.** Dot/arrow/marker centers on the same line as the shape it points at
  (compute it: `cy = (top + bottom) / 2` of the chevron), symmetric parts mirror exactly.
- [ ] **Corner language is consistent.** A fill inside a rounded shell is rounded too (inner radius ≈ outer
  radius − gap); a level fill is rounded at the bottom and **flat at the cut** (clip pattern, vide-patterns.md).
- [ ] **One shape, two states, not two shapes.** Progress/charge shown as color change on part of one silhouette
  = same image twice + a clip, never a second drawing.
- [ ] **Small primitives exist.** Little squares vs dots, node sizes, gaps — count them on the zoom.
- [ ] **Edges are clean.** No dark halo around light art (alpha bleed, `export_layers.py` does it; re-export
  old PNGs). No blur beyond what the reference has.
- [ ] **Weights.** Stroke thickness in the tile equals the reference ± 0.5 px at 1080p.
- [ ] **Rim/glow color.** AW-style glow is a thin darker rim (e.g. orange under amber), not a same-color bloom.

## Iteration discipline

- Round 1: structure (positions, sizes, presence of every element). Round 2: weight & type (line thickness,
  fonts, opacity). Round 3: polish (glow, motion, states).
- Write a short diff list after each round: `[x] ammo numerals Oswald Light 176 — width still +15% → digit atlas`.
- Stop when the remaining list contains only engine limits (write them in the final report).

## Final report to the user

- Screenshot(s) of the result + the compare board.
- Remaining differences and why (engine limit / needs asset / needs decision).
- Assets uploaded (names → ids) and where the ids live.
- Story controls available for each state.
