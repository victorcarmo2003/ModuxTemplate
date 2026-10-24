--!strict
-- SauceGuide: the way of the sauce on the hot dog, drawn as 2D Mustard arrows (owner 2026-10-22: "em vez desses dots, a setinha
-- do tutorial, porém 2D, na interface, com espaçamento"). The caller gives the S already on screen (Points, px, start -> end:
-- Toppings projects the S's points on the sausage every frame, so the arrows bend with it); one arrow every Spacing px along it,
-- pointing the way, the first one a little bigger. Pure: only props; build it inside a Vide root. The geometry helpers
-- (Dense, Project) are shared with the cooking focus and the UI Labs story.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const derive = Vide.derive
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for some classes only (UIStroke is not among them)
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Points: () -> { Vector2 }, -- px, start -> end
	Spacing: (() -> number)?, -- px between two arrows (default 26)
	Size: (() -> number)?, -- px of an arrow (default 16)
	Visible: (() -> boolean)?,
	Name: string?,
}

type Arrow = { At: Vector2, Angle: number, Lead: boolean }

const SPACING = 26
const SIZE = 16
const LEAD = 1.35 -- the first arrow (where to start) is this much bigger
const ARM = 0.62 -- arm length, share of the arrow size
const THICK = 0.24 -- arm thickness, share of the arrow size
const SPREAD = math.rad(42) -- each arm's angle off the way back
const STROKE = 2

-- One arrow every `spacing` px along the polyline, half a spacing in (pure)
local function arrowsOf(points: { Vector2 }, spacing: number): { Arrow }
	const out: { Arrow } = {}
	if #points < 2 or spacing <= 1 then
		return out
	end
	local want = spacing / 2
	local walked = 0
	for index = 2, #points do
		const a, b = points[index - 1], points[index]
		const leg = (b - a).Magnitude
		if leg < 1e-3 then
			continue
		end
		const direction = (b - a) / leg
		while want <= walked + leg do
			table.insert(out, {
				At = a + direction * (want - walked),
				Angle = math.deg(math.atan2(direction.Y, direction.X)),
				Lead = #out == 0,
			})
			want += spacing
		end
		walked += leg
	end
	return out
end

-- one arm of a chevron pointing +X: from the tip back at `sign` x SPREAD, inside a size x size box
local function arm(size: () -> number, sign: number): Instance
	return create("Frame")({
		Name = if sign > 0 then "ArmA" else "ArmB",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Color.Mustard,
		BorderSizePixel = 0,
		Position = function(): UDim2
			const s = size()
			const tip = Vector2.new(s * 0.3, 0)
			const back = Vector2.new(-math.cos(SPREAD), sign * math.sin(SPREAD))
			const centre = tip + back * (s * ARM / 2)
			return UDim2.new(0.5, centre.X, 0.5, centre.Y)
		end,
		Size = function(): UDim2
			const s = size()
			return UDim2.fromOffset(s * ARM + s * THICK, s * THICK)
		end,
		Rotation = math.deg(math.atan2(sign * math.sin(SPREAD), -math.cos(SPREAD))),
		create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = STROKE }),
	})
end

local SauceGuide = {}

-- The S of Content.Prep.Build.Sauce.Path in bun space with `steps` points per stretch (it bends once put on the sausage)
function SauceGuide.Dense(path: { { X: number, Y: number } }, steps: number): { Vector2 }
	const out: { Vector2 } = {}
	for index = 2, #path do
		const a, b = path[index - 1], path[index]
		for step = 0, steps - 1 do
			const t = step / steps
			table.insert(out, Vector2.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t))
		end
	end
	const tail = path[#path]
	if tail ~= nil then
		table.insert(out, Vector2.new(tail.X, tail.Y))
	end
	return out
end

-- A world point on a screen of `size` px seen by `camera` (any Camera: a ViewportFrame's has no ViewportSize of its own);
-- nil behind it
function SauceGuide.Project(camera: Camera, size: Vector2, world: Vector3): Vector2?
	const local_ = camera.CFrame:PointToObjectSpace(world)
	if local_.Z >= -1e-3 then
		return nil
	end
	const half = math.tan(math.rad(camera.FieldOfView) / 2)
	const aspect = if size.Y > 0 then size.X / size.Y else 1
	const x = (local_.X / -local_.Z) / (half * aspect)
	const y = (local_.Y / -local_.Z) / half
	return Vector2.new((x + 1) / 2 * size.X, (1 - y) / 2 * size.Y)
end

function SauceGuide.Component(props: Props): Frame
	const spacing = props.Spacing or function(): number
		return SPACING
	end
	const size = props.Size or function(): number
		return SIZE
	end
	const arrows = derive(function(): { Arrow }
		return arrowsOf(props.Points(), spacing())
	end)
	return create("Frame")({
		Name = props.Name or "SauceGuide",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible or true,
		indexes(arrows, function(arrow: () -> Arrow, _: number)
			local function scaled(): number
				return size() * (if arrow().Lead then LEAD else 1)
			end
			return create("Frame")({
				Name = "Arrow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = function(): UDim2
					const at = arrow().At
					return UDim2.fromOffset(at.X, at.Y)
				end,
				Size = function(): UDim2
					const s = scaled()
					return UDim2.fromOffset(s, s)
				end,
				Rotation = function(): number
					return arrow().Angle
				end,
				arm(scaled, 1),
				arm(scaled, -1),
			})
		end),
	}) :: Frame
end

return table.freeze(SauceGuide)
