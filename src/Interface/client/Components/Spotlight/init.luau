--!strict
-- Spotlight: dims the screen around one UI element and rings it (tutorial step on a UI element, user request
-- 2026-10-11: "escurecer a tela em volta com um recorte"). Four Ink frames around the hole (a hole cannot be cut out
-- of one frame) plus a pulsing Mustard ring with an Ink outline over the hole. Nothing here is clickable: the dim
-- frames are not Active, so the game keeps its input.
-- The hole follows `Target` every frame (AbsolutePosition/AbsoluteSize, relative to this frame), so a HUD that
-- rescales (Theme.Scale UIScale) or a pill that pops in is tracked; AbsolutePosition/AbsoluteSize already carry every
-- UIScale above the target, and this component has no UIScale of its own (only the ring pulse).
-- Playtest 2026-10-11 (an undimmed strip at the top, the hole off the money pill): mount it in a ScreenGui with the
-- SAME insets as the target's ScreenGui (the HUD: ScreenInsets = DeviceSafeInsets), so both
-- frames share one origin whatever the top bar / safe area of the device; the dim bands overscan OVERSCAN px past the
-- frame on every side, so the top bar and the notch areas are dimmed too.
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Shown: () -> boolean,
	-- The element to show through the hole; nil = dim only.
	Target: () -> GuiObject?,
	-- px of air around the target. Default 10.
	Padding: number?,
	-- Dim transparency when fully shown. Default 0.45.
	Dim: number?,
	Name: string?,
}

type Hole = { Position: Vector2, Size: Vector2 }

const PULSE_SPEED = 4 -- rad/s
const PULSE = 0.04
const RADIUS = UDim.new(0, 18)
const OVERSCAN = 2000 -- px the dim bands reach past the frame (top bar, notch, any inset)

return function(props: Props): Frame
	const pad = props.Padding or 10
	const dim = props.Dim or 0.45
	const pop = Motion.Pop(props.Shown)
	const hole = source({ Position = Vector2.zero, Size = Vector2.zero } :: Hole)
	const pulse = source(1)
	const screen = source(Vector2.zero)
	-- the target is laid out and `hole` matches it
	const ready = source(false)

	const root = create("Frame")({
		Name = props.Name or "Spotlight",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = function()
			return pop() > 0.01
		end,
	})

	const connection = RunService.RenderStepped:Connect(function()
		if untrack(pop) <= 0.01 then
			return
		end
		if untrack(screen) ~= root.AbsoluteSize then
			screen(root.AbsoluteSize)
		end
		const target = untrack(props.Target)
		-- a target not laid out yet (popping in from size 0, hidden) keeps the screen dimmed without a hole, so the
		-- ring never flashes at the frame corner
		const laid = target ~= nil
			and target.Parent ~= nil
			and target.Visible
			and target.AbsoluteSize.X >= 1
			and target.AbsoluteSize.Y >= 1
		if laid and target then
			const at = target.AbsolutePosition - root.AbsolutePosition - Vector2.new(pad, pad)
			const size = target.AbsoluteSize + Vector2.new(pad * 2, pad * 2)
			const current = untrack(hole)
			if current.Position ~= at or current.Size ~= size then
				hole({ Position = at, Size = size })
			end
		end
		if untrack(ready) ~= laid then
			ready(laid)
		end
		pulse(1 + math.sin(os.clock() * PULSE_SPEED) * PULSE)
	end)
	cleanup(function()
		connection:Disconnect()
	end)

	local function hasHole(): boolean
		return props.Target() ~= nil and ready()
	end

	local function transparency(): number
		return 1 - (1 - dim) * math.clamp(pop(), 0, 1)
	end

	-- One dim band; `box` returns position and size in px.
	local function band(name: string, box: () -> (Vector2, Vector2)): Frame
		return create("Frame")({
			Name = name,
			Position = function()
				const at = box()
				return UDim2.fromOffset(at.X, at.Y)
			end,
			Size = function()
				const _, size = box()
				return UDim2.fromOffset(math.max(size.X, 0), math.max(size.Y, 0))
			end,
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		})
	end

	-- Frame size (px); the bands reach OVERSCAN past it on every side.
	local function full(): Vector2
		return screen()
	end

	const children: { Instance } = {
		-- Without a target the top band covers everything.
		band("Top", function()
			const size = full()
			if not hasHole() then
				return Vector2.new(-OVERSCAN, -OVERSCAN), size + Vector2.new(OVERSCAN * 2, OVERSCAN * 2)
			end
			return Vector2.new(-OVERSCAN, -OVERSCAN), Vector2.new(size.X + OVERSCAN * 2, hole().Position.Y + OVERSCAN)
		end),
		band("Bottom", function()
			if not hasHole() then
				return Vector2.zero, Vector2.zero
			end
			const size = full()
			const h = hole()
			const top = h.Position.Y + h.Size.Y
			return Vector2.new(-OVERSCAN, top), Vector2.new(size.X + OVERSCAN * 2, size.Y - top + OVERSCAN)
		end),
		band("Left", function()
			if not hasHole() then
				return Vector2.zero, Vector2.zero
			end
			const h = hole()
			return Vector2.new(-OVERSCAN, h.Position.Y), Vector2.new(h.Position.X + OVERSCAN, h.Size.Y)
		end),
		band("Right", function()
			if not hasHole() then
				return Vector2.zero, Vector2.zero
			end
			const size = full()
			const h = hole()
			const left = h.Position.X + h.Size.X
			return Vector2.new(left, h.Position.Y), Vector2.new(size.X - left + OVERSCAN, h.Size.Y)
		end),

		-- Ring over the hole
		create("Frame")({
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				const h = hole()
				const centre = h.Position + h.Size / 2
				return UDim2.fromOffset(centre.X, centre.Y)
			end,
			Size = function()
				const h = hole()
				return UDim2.fromOffset(h.Size.X, h.Size.Y)
			end,
			BackgroundTransparency = 1,
			Visible = hasHole,
			create("UICorner")({ CornerRadius = RADIUS }),
			createRaw("UIScale")({ Scale = pulse }),
			createRaw("UIStroke")({
				Color = Theme.Color.Mustard,
				Thickness = Theme.Outline.Thick,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			create("Frame")({
				Name = "Inner",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				create("UICorner")({ CornerRadius = RADIUS }),
				createRaw("UIStroke")({
					Color = Theme.Color.Ink,
					Thickness = 2,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				}),
			}),
		}),
	}
	for _, child in children do
		child.Parent = root
	end
	return root
end
