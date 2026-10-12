--!strict
-- World/Ray: from a pointer point to a ray in the world, and the raycast over the PrepTarget hitboxes (docs/tech/prep-3d.md §2.1,
-- TASK-196). The ONE place that knows the coordinate spaces, so a fix for an inset or a device lands here and nowhere else:
--   Mouse, Touch  InputObject.Position = GUI space (the topbar inset is already taken out): Camera:ScreenPointToRay
--   Pad           the virtual cursor (Cursor.luau) lives in raw viewport px (its ScreenGui has ScreenInsets = None):
--                 Camera:ViewportPointToRay
-- `/dev prep ray` prints both spaces next to the hit so the three screens (1280x720, 844x390, 667x375) can be checked by click.
-- The raycast is `Include` over the hitboxes only (no decoration, NPC or rig ever blocks it) and never reads ProximityPrompt or
-- ClickDetector. No Modux, no Vide.
local GuiService = game:GetService("GuiService")
local Pointer = require(script.Parent.Parent.Pointer)

const Ray = {}

-- Studs: how far a pointer ray reaches (the camera of the mode is ~2.5 studs from the work).
Ray.Range = 60

-- The raw viewport px of a pointer point (what Camera:WorldToViewportPoint speaks).
function Ray.ToViewport(px: Vector2, device: Pointer.Device): Vector2
	if device == "Pad" then
		return px
	end
	const inset = GuiService:GetGuiInset()
	return px + inset
end

-- The unit ray of a pointer point: its origin and direction.
function Ray.Of(camera: Camera, px: Vector2, device: Pointer.Device): (Vector3, Vector3)
	local unit: Ray
	if device == "Pad" then
		unit = camera:ViewportPointToRay(px.X, px.Y)
	else
		unit = camera:ScreenPointToRay(px.X, px.Y)
	end
	return unit.Origin, unit.Direction
end

-- RaycastParams that only see the listed hitboxes; the registry fills FilterDescendantsInstances (Targets:Refresh).
function Ray.NewParams(): RaycastParams
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.IgnoreWater = true
	params.RespectCanCollide = false
	params.FilterDescendantsInstances = {}
	return params
end

function Ray.Cast(params: RaycastParams, origin: Vector3, direction: Vector3): RaycastResult?
	return workspace:Raycast(origin, direction * Ray.Range, params)
end

-- Where a world point is on the screen: viewport px (the space of the gamepad cursor) and whether it is in front of the camera.
function Ray.Project(camera: Camera, world: Vector3): (Vector2, boolean)
	const point, visible = camera:WorldToViewportPoint(world)
	return Vector2.new(point.X, point.Y), visible and point.Z > 0
end

return table.freeze(Ray)
