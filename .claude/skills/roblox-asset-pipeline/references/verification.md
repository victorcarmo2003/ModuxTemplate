# Verification

## In Blender (before export)

- Renders: 3/4, front, side, top, **first-person** (eye height over the real surface), **close-ups of every
  joint** (handle↔body, arm↔knob, lid hinge, cap↔ears), section render for hollow/transparent things (liquid
  inside glass: check no vertex outside the cavity).
- `overlap_check.py` (area-based z-fight) = 0. Tris per part reported.
- Contact sheet of all previews for the user (`board.py` or a quick PIL grid) - read it yourself first.

## In Studio (after placement) - Studio MCP

- `screen_capture(camera_position, look_at_position)` saves a JPG on disk (path in the result) → you can zoom
  or compare with PIL. If captures come back **black** while lighting/camera are fine, the Studio window is
  minimised/unfocused: continue with geometric probes and retry later.
- Probes (`scripts/studio/probes.luau`):
  - `Probes.front(model, featureOffset, height)` - which side a protruding feature is on (raycast both sides).
  - `Probes.size(model)` - bbox vs sheet.
  - `Probes.armTip(pole)` - farthest point of an arm via downward rays (to seat lamp heads).
- Overview + one capture per area (street, market inside, cart from the queue AND from the operator,
  trailer outside AND inside, characters at eye level). Markers/labels of the blockout stay visible - fine.
- Read the place state at the end (folder names, counts) and list what you created; never destroy instances
  you did not create (hide/restore instead).

## Report

What was placed (counts per group), what stayed blockout and why, measured deviations from the level doc
(heights, widths), and the list of decisions for the user. Be explicit about anything only previewed
(EditableMesh) vs really uploaded.
