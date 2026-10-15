--!strict
--[[
	EdgePointer: the screen-edge side of "the arrow is 3D, the 2D one only when the target is off screen" (owner request
	2026-10-14, Provisional). Pure maths, no GUI: the owner feeds the world points that stand for the guide (the tip of the
	3D arrow and the target) every frame and gets back whether to show the TutorialPointer badge, where (px, viewport pixels,
	for an overlay that ignores the GUI inset) and at which angle (degrees; 0 = right, 90 = down).

	  - Shown ONLY when none of the points is on screen (in front of the camera and inside the viewport). The margin only
	    PLACES the badge (a ring inside the screen, scaled by the UI scale); it never decides whether it shows.
	  - Hysteresis (HYSTERESIS px): to show, every point must be that far OUTSIDE the viewport; to hide, one point must be
	    that far INSIDE. A point right at the edge does not flicker the badge.
	  - A point behind the camera mirrors its projection: the delta is flipped so the badge points the way to turn.
	  - The direction follows the FIRST point (the arrow tip). Occlusion by walls or UI is ignored on purpose: only the
	    viewport decides.
]]
export type EdgePointer = {
	-- shown, at (px), angle (degrees); `at` and `angle` mean nothing when not shown.
	Update: (worldPoints: { Vector3 }, uiScale: number) -> (boolean, Vector2, number),
	-- Forget the hysteresis (the guide went away).
	Reset: () -> (),
}

-- PROVISIONAL
const HYSTERESIS = 6 -- px
const DEFAULT_MARGIN = 56 -- px from the screen edge (x UI scale) where the badge sits

const EdgePointer = {}

-- margin = px from the screen edge where the badge is placed (default 56; the Market uses 48)
function EdgePointer.new(margin: number?): EdgePointer
	const edge = margin or DEFAULT_MARGIN
	local shown = false

	return {
		Update = function(worldPoints: { Vector3 }, uiScale: number): (boolean, Vector2, number)
			const camera = workspace.CurrentCamera
			if camera == nil or #worldPoints == 0 then
				shown = false
				return false, Vector2.zero, 0
			end
			const viewport = camera.ViewportSize
			-- shown: one point this far inside hides; hidden: every point must be this far outside to show
			const inset = if shown then HYSTERESIS else -HYSTERESIS
			local anyInside = false
			local direction = Vector2.zero
			for index, world in worldPoints do
				const point = camera:WorldToViewportPoint(world)
				if
					point.Z > 0
					and point.X >= inset
					and point.X <= viewport.X - inset
					and point.Y >= inset
					and point.Y <= viewport.Y - inset
				then
					anyInside = true
					break
				end
				if index == 1 then
					local delta = Vector2.new(point.X, point.Y) - viewport / 2
					if point.Z < 0 then
						delta = -delta -- behind the camera: the projection is mirrored
					end
					direction = delta
				end
			end
			if anyInside then
				shown = false
				return false, Vector2.zero, 0
			end
			shown = true
			local delta = direction
			if delta.Magnitude < 1 then
				delta = Vector2.new(0, 1) -- exactly behind the lens axis: the bottom edge
			end
			const margin = edge * uiScale
			const halfX = math.max(viewport.X / 2 - margin, 1)
			const halfY = math.max(viewport.Y / 2 - margin, 1)
			const t = math.min(
				if delta.X ~= 0 then halfX / math.abs(delta.X) else math.huge,
				if delta.Y ~= 0 then halfY / math.abs(delta.Y) else math.huge
			)
			return true, viewport / 2 + delta * t, math.deg(math.atan2(delta.Y, delta.X))
		end,
		Reset = function()
			shown = false
		end,
	}
end

return table.freeze(EdgePointer)
