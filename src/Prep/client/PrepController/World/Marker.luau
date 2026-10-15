--!strict
-- World/Marker: the 3D marker of the pointer (docs/tech/prep-3d.md §2.1, §2.6; TASK-196): a square frame exactly on the point that counts
-- (the one the raycast / plane gives), so a finger with its 28 px offset or a gamepad cursor always shows where the action lands.
-- Two states: Open (Mustard, aiming) and Held (Cream, tight: a drag has begun). A HintMark (studs, always on top), no Part of its own.
-- No Modux, no Vide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local HintMark = require(StarterPlayer.StarterPlayerScripts.client.Interface.HintMark)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

export type Marker = {
	-- Moves the marker to a world point (`lift` studs above it along the plane normal, set by SetNormal).
	Place: (self: Marker, point: Vector3) -> (),
	-- Kept for the callers that lay the plane (the frame faces the camera): the lift follows the normal.
	SetNormal: (self: Marker, normal: Vector3) -> (),
	SetHeld: (self: Marker, held: boolean) -> (),
	SetVisible: (self: Marker, visible: boolean) -> (),
	Destroy: (self: Marker) -> (),
}

const OPEN_SCALE, HELD_SCALE = 1.4, 0.9 -- of Rules.World.Marker
const LIFT = 0.03 -- studs over the plane

const Marker = {}

-- The aim marker is a HintMark Rect now (studs, always on top, exactly on the point): Open = Mustard and wide, Held = Cream and tight.
function Marker.new(_folder: Folder, rules: Content.PrepWorldRules): Marker
	const mark = HintMark.new()
	local held = false
	local visible = false
	local normal = Vector3.yAxis
	local point = Vector3.zero

	local function paint()
		if not visible then
			mark:Hide()
			return
		end
		mark:SetColor(if held then Theme.Color.Cream else Theme.Color.Mustard)
		mark:Show("Rect", point + normal * LIFT, rules.Marker * (if held then HELD_SCALE else OPEN_SCALE))
	end

	const self = {} :: any
	function self.Place(_: any, value: Vector3)
		point = value
		if visible then
			paint()
		end
	end
	function self.SetNormal(_: any, value: Vector3)
		if (value - normal).Magnitude < 1e-4 then
			return
		end
		normal = value.Unit
	end
	function self.SetHeld(_: any, value: boolean)
		if held ~= value then
			held = value
			paint()
		end
	end
	function self.SetVisible(_: any, value: boolean)
		if visible ~= value then
			visible = value
			paint()
		end
	end
	function self.Destroy(_: any)
		mark:Destroy()
	end
	return self :: Marker
end

return Marker
