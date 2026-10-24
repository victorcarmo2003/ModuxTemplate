# Phone, scaling and world-UI lessons (learned the hard way)

Field notes from a production Roblox game (cartoon kit, Vide, landscape phones). Each item is a bug that shipped to a
real phone and looked fine in Studio. Read before building any screen that must work on a phone, and before any
BillboardGui.

## 1. One global scale rule, proportional to the PC

- Scale every screen from the viewport height: `scale = viewportY / 1080 * Factor` (Factor ~1.4 → 1080p = 1.4).
  The same layout then occupies the same share of the screen on PC and phone ("1:1 with the PC").
- Clamp with a **floor per device class**, decided in ONE helper (`Theme.FloorOf(viewport)`):
  mouse ~0.86, touch tablet ~0.8, **touch phone (TouchEnabled and viewportY <= 500) ~0.6**.
  A touch floor of 0.8–1.0 made every phone screen ~40% bigger than its PC share: cards ran out of height,
  panels covered the game.
- Components that cap a caller's scale (`math.max(math.min(props.Scale(), Current()), FLOOR)`) must read the floor
  from that helper, never a hard `Theme.Scale.Min`, or they silently undo the phone floor.
- Do not stack per-component "compact" multipliers on top of a floor change: they shrink twice. If one exists, make
  it neutral where the new floor already applies.
- Studio is not a touch device: `UserInputService.TouchEnabled` is false, so the phone floor never shows there.
  Simulate it (see §8) instead of trusting the Studio look.

## 2. The player's Text Size setting (GuiService.PreferredTextSize)

- On by default for every experience. It **adds pixels after the UIScale**, so the smaller the UI scale, the more the
  text outgrows its box: labels over bars, names past rows, "MM:SS left" past the card edge.
- Fix: every non-scaled text gets `UITextSizeConstraint { MaxTextSize = TextSize }` (the engine honours Min/Max over
  the setting). Put it in the kit label component AND add a client watcher over PlayerGui (and the Workspace for
  world UI) that caps any raw TextLabel / TextButton / TextBox without a constraint, following TextSize changes.
- `TextScaled` labels ignore the setting; `AutomaticSize` labels grow with it.

## 3. Auto-size measured under a UIScale

- Measuring `content.AbsoluteSize / scale` (to undo an ancestor UIScale) explodes while a pop/spring scale passes
  near 0: text keeps a minimum render size, so `content / 0.01` = thousands of px. The panel then sticks at the
  screen width ("a grey bar across the screen").
- Skip measures when the scale is under ~0.25 (keep the last good size). Same for any width derived from a ratio
  of a squashed AbsoluteSize.

## 4. Fitting a card on a short screen

- Give each side panel its **own vertical band**. Mirroring the top clearance at the bottom "to stay centred" cost
  the card half its height on a phone.
- `GuiService.TopbarInset` (or the Roblox-buttons block you derive from it) can report about twice the real height
  on a device. Cap the reserved height at the real topbar (~60 px), and only make the panel that sits *under* the
  Roblox buttons (top left) clear them.
- Card body that may not fit: shrink it with a UIScale down to ~0.9, and past that let it **scroll**
  (ScrollingFrame, `AutomaticCanvasSize = Y`, the content frame `AutomaticSize = Y`). Reset `CanvasPosition` when the
  shown item changes. Below ~0.9 the text becomes unreadable on a phone.
- Fixed label columns: size them for the longest label at its real width (e.g. "Sanity" at 14 px ~50 px), not a
  round guess; a bar starting at 52 px covered the label's end.
- A label beside a control (`"Who can join"  [button]`): box = remaining width (`1, -(CONTROL + gap)`) with
  `TextScaled` + `MaxTextSize`, so it shrinks instead of sliding under the button.

## 5. ScrollingFrame and outlines

- `VerticalScrollBarInset = ScrollBar` with a scale-width child makes the content as wide as the *window*, not the
  inset canvas: the right side (and its UIStroke) is clipped when the bar shows. Use `None` and reserve the bar's
  thickness in the content's right padding.
- An `Outside` UIStroke + lip needs ~4 px of padding inside any clipping container on every side.

## 6. BillboardGui: pick studs or pixels deliberately

| Billboard sized in | Looks like | Text | Outlines |
|---|---|---|---|
| **Scale (studs)** — signs, tags on objects | shrinks with distance like a real object | must be `TextScaled` + `MaxTextSize` (fixed TextSize keeps its px → text "grows" past the sign far away) | UIStroke is in px → scale its Thickness by `billboard.AbsoluteSize.Y / reference`, ≤ 1 (else a black blot far away) |
| **Offset (px)** — prompts, name tags | same size on screen at any distance → far away it looks huge next to the object | TextSize fine | fine |

- A px billboard that should behave like an object (a "+$5" pop over a table, a stock pill): keep the px layout and
  add a distance UIScale (`scale = clamp(NEAR / distance, MIN, 1)`, gui Size = base * scale) — one PreRender loop for
  all tracked guis.
- A studs billboard that lays out a px design under a fit UIScale (`scale = billboard px / design px`) already scales
  its text and strokes: a global "make billboard text TextScaled" rule must skip it (look for a UIScale between the
  label and the billboard).
- A px card whose height changes (empty / filled) under a distance scale needs a `Resize(gui, w, h)` on the tracker;
  a reactive `Size` on the gui fights the tracker's writes.
- Non-AlwaysOnTop billboards are cut by world geometry in front of them; a px card that outgrows its object from far
  away gets cut by shelves and pillars ("half a price plate, no title").
- Use `UIStroke.StrokeSizingMode = ScaledSize` only where one thickness ratio fits the element; for a whole kit,
  scaling Thickness from the billboard height is simpler.

## 7. Other engine gotchas seen

- `Highlight.Adornee` does not light a **Folder**: only Models/BaseParts. To mark a group, highlight one model or
  place the prompt/button on the piece you highlight (a button floating outside the lit piece reads as broken).
- Drag gestures (drawing a sauce line, swiping): when the pointer leaves the target, **pause** (no ink, no points)
  and resume a fresh segment when it comes back. Clamping the off-target pointer to the edge burnt the budget and
  "ended" the gesture.

## 8. Verify for a phone in Studio (MCP execute_luau)

1. Clone the component tree into ReplicatedStorage (`Interface:Clone()`) — a fresh require, no module cache.
2. Patch the clone's Theme source to simulate the touch phone floor (`Min = 0.86` → `Min = 0.6`).
3. Mount with `Vide.mount` into a Frame of **844 x 390** in a StarterGui ScreenGui; pass the reserved topbar the
   device reports (e.g. 245 x 125) to stress the layout.
4. Read AbsoluteSize / AbsolutePosition of the panels and sections (card, body, each section, canvas) and take a
   `screen_capture`. Then clean up the ScreenGui and the clone.
Phone screenshots from the user beat everything: measure from them (element px / image px * 390 pt) to tell which
rule fired (e.g. a card at BODY_MIN means the clearance, not the scale, is wrong).
