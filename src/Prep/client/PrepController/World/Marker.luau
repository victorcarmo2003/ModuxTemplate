--!strict
-- World/Marker: the 3D marker of the pointer (docs/tech/prep-3d.md §2.1, §2.6; TASK-196): a small Neon disc lying on the work
-- plane at the point that counts (the one the raycast / plane gives), so a finger with its 28 px offset or a gamepad cursor always
-- shows exactly where the action lands. Two states: Open (a pale disc, aiming) and Held (smaller, solid: a drag has begun).
-- One Part made once under the PrepWorld folder; per frame only Position / Size / Transparency are written (no CFrame, no
-- allocation). The tool in the hand (knife, bottle...) follows the same point (TASK-204/205). No Modux, no Vide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

export type Marker = {
	-- Moves the marker to a world point (`lift` studs above it along the plane normal, set by SetNormal).
	Place: (self: Marker, point: Vector3) -> (),
	-- Lays the disc on a plane with this normal (once per plane change, not per frame).
	SetNormal: (self: Marker, normal: Vector3) -> (),
	SetHeld: (self: Marker, held: boolean) -> (),
	SetVisible: (self: Marker, visible: boolean) -> (),
	Destroy: (self: Marker) -> (),
}

const OPEN_SCALE, HELD_SCALE = 1.4, 0.9 -- of Rules.World.Marker
const OPEN_ALPHA, HELD_ALPHA = 0.45, 0.05
const THICKNESS = 0.02
const LIFT = 0.015 -- studs over the plane (no z-fight with the board)

const Marker = {}

function Marker.new(folder: Folder, rules: Content.PrepWorldRules): Marker
	const disc = Instance.new("Part")
	disc.Name = "AimMarker"
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.Neon
	disc.Color = Theme.Color.Mustard
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Massless = true
	disc.Transparency = 1
	disc.Size = Vector3.new(THICKNESS, rules.Marker, rules.Marker)
	disc.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2) -- lying flat: the cylinder axis is X
	disc.Parent = folder

	local held = false
	local visible = false
	local normal = Vector3.yAxis

	local function paint()
		const scale = if held then HELD_SCALE else OPEN_SCALE
		const side = rules.Marker * scale
		disc.Size = Vector3.new(THICKNESS, side, side)
		disc.Transparency = if not visible then 1 elseif held then HELD_ALPHA else OPEN_ALPHA
	end
	paint()

	const self = {} :: any
	function self.Place(_: any, point: Vector3)
		disc.Position = point + normal * LIFT
	end
	function self.SetNormal(_: any, value: Vector3)
		if (value - normal).Magnitude < 1e-4 then
			return
		end
		normal = value.Unit
		-- a cylinder lies along its X axis: turn X to the normal
		const reference = if math.abs(normal.Y) < 0.99 then Vector3.yAxis else Vector3.xAxis
		disc.CFrame = CFrame.fromMatrix(disc.Position, normal, normal:Cross(reference).Unit)
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
		disc:Destroy()
	end
	return self :: Marker
end

return Marker
