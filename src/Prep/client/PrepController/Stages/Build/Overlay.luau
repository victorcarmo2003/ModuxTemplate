--!strict
-- Overlay: what the Build board draws on top of the PlateView besides the plate itself (docs/art/prep-ui-spec.md §5.3):
--   the sausage chip   the sausage "from the front of the rail", dragged to the groove of the bun (waits for the grill when
--                      the rail is empty)
--   the stroke canvas  the sauce zig-zag, its dotted guide and the meter (sauce amount, potato bar), laid exactly over the bun
--   the hold pill      "Hold": hold instead of drag (touch accessibility); only on a touch device
--   the carry ghost    the cheese slice that follows the pointer (inside the bun, in bun space)
--   the rings          the bacon rings that close (inside the bun)
-- Everything is Mustard / Cream / Ink flat shapes (no sprites yet, Q-152), no red; the only reds are food (ketchup).
-- Built inside the Vide scope of the board; no rule here (the Director arms the gestures, the Session scores them).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CartoonButton = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonButton)
local CartoonLabel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonLabel)
local StrokeCanvas = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.StrokeCanvas)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Rail = require(script.Parent.Rail)
local Session = require(script.Parent.Session)

const create = Vide.create
const source = Vide.source
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and the constraints are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const build = Content.Prep.Build

export type Carry = { Key: string, X: number, Y: number }

export type RingState = "Hidden" | "Closing" | "Tapped" | "Missed"

export type Ring = { Scale: number, State: RingState }

export type Ctx = {
	Controller: any,
	-- The mat and the bun of the PlateView (set by OnMount).
	Mat: Frame?,
	Bun: Frame?,
	Chip: Frame,
	-- The sausage is being dragged (the chip hides).
	Dragging: Vide.Source<boolean>,
	Carry: Vide.Source<Carry | false>,
	Rings: Vide.Source<{ Ring }>,
	-- Children of the mat, for PlateView's `Overlay`.
	Overlay: { any },
}

-- The PlateView draws the bun at 0.64 x 0.5 of the mat with this ratio and cap (PlateView BUN_RATIO / BUN_MAX): the canvas of
-- the strokes is laid over it with the same numbers so a point of a gesture (bun space) is a point of the canvas.
const BUN_SCALE = Vector2.new(0.64, 0.5)
const BUN_RATIO = 3.1
const BUN_MAX = 340
const CHIP_SIZE = Vector2.new(132, 44)
const RING_SIZE = 44
const RING_OUTER = 3 -- px at UI scale 1: the stroke of a ring

-- Food colours of the carried slice (pictures of food, not UI states).
const FOOD: { [string]: Color3 } = {
	cheese = Color3.fromHex("#FFC64D"),
	ketchup = Color3.fromHex("#E2402E"),
	mustard = Color3.fromHex("#F6C12B"),
	cream_cheese = Color3.fromHex("#FFF8EA"),
	bacon = Color3.fromHex("#C8553D"),
	potato_sticks = Color3.fromHex("#E8C26A"),
}
const SAUSAGE_COLOR = Color3.fromHex("#B9573C")

const Overlay = {}

function Overlay.FoodColor(key: string): Color3
	return FOOD[key] or Theme.Tone.Slate.Bottom
end

local function newRings(): { Ring }
	const list: { Ring } = {}
	for index = 1, build.Bacon.Count do
		list[index] = { Scale = 1, State = "Hidden" }
	end
	return list
end

function Overlay.HiddenRings(): { Ring }
	return newRings()
end

local function ringColor(state: RingState): Color3
	if state == "Tapped" then
		return Theme.Tone.Green.Bottom
	elseif state == "Missed" then
		return Theme.Tone.Slate.Bottom
	end
	return Theme.Color.Mustard
end

-- The chip of the sausage, built from the view-model: visible while the bun is open and the sausage is not in it.
local function makeChip(controller: any, dragging: Vide.Source<boolean>): Frame
	const view = controller.View
	const ready = function(): boolean
		return Rail.Count(controller) > 0
	end
	return create("Frame")({
		Name = "SausageChip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.fromOffset(CHIP_SIZE.X, CHIP_SIZE.Y),
		BackgroundColor3 = Theme.Tone.Cream.Bottom,
		BackgroundTransparency = function()
			return if ready() then 0 else 0.35
		end,
		BorderSizePixel = 0,
		ZIndex = 6,
		Visible = function()
			return controller.Step() == "build"
				and view.Bun() == "Open"
				and not Session.Placed()
				and not dragging()
				and view.Seal() == false
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = 3,
			LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		-- the sausage picture
		create("Frame")({
			Name = "Picture",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(40, 18),
			BackgroundColor3 = SAUSAGE_COLOR,
			BackgroundTransparency = function()
				return if ready() then 0 else 0.7
			end,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		CartoonLabel({
			Name = "Text",
			Text = function()
				return if ready() then build.Texts.Sausage else Content.Prep.Texts.Waiting
			end,
			TextSize = Theme.MinTextSize,
			Color = Theme.Color.Ink,
			Stroke = 0,
			Wrapped = true,
			Position = UDim2.fromOffset(56, 0),
			Box = UDim2.new(1, -62, 1, 0),
			XAlignment = Enum.TextXAlignment.Left,
			YAlignment = Enum.TextYAlignment.Center,
			ZIndex = 7,
		}),
	}) :: Frame
end

local function makeHold(controller: any): any
	const device = controller.Dependencies.InputController.Device
	return CartoonButton({
		Name = "HoldMode",
		Text = build.Texts.HoldMode,
		TextSize = 16,
		Tone = function()
			return if Session.Hold() then Theme.Tone.Teal else Theme.Tone.Cream
		end,
		Outline = function()
			return if Session.Hold() then Theme.Outline.Thick else Theme.Outline.Normal
		end,
		Radius = Theme.Radius.Chip,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(72, 44),
		Visible = function()
			return device() == "Touch" or Session.Hold()
		end,
		OnActivated = function()
			Session.SetHold(not Vide.untrack(Session.Hold))
			controller:CancelGestures()
		end,
	})
end

-- The pieces that belong to the mat; `Attach` adds the ones that live inside the bun once it exists.
function Overlay.New(controller: any): Ctx
	const view = controller.View
	const dragging = source(false)
	const chip = makeChip(controller, dragging)
	const canvas = StrokeCanvas({
		Name = "Strokes",
		Points = view.Stroke,
		Guide = view.StrokeGuide,
		Color = view.StrokeColor,
		Thickness = 10,
		Meter = function()
			const value = view.Meter()
			return if value ~= false then value else nil
		end,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(BUN_SCALE.X, BUN_SCALE.Y),
		-- under the bun, where the bin of the sauce reads (the default would sit on the bun)
		MeterPosition = UDim2.new(0.5, 0, 1, 30),
	})
	createRaw("UIAspectRatioConstraint")({ AspectRatio = BUN_RATIO, DominantAxis = Enum.DominantAxis.Width, Parent = canvas })
	createRaw("UISizeConstraint")({ MaxSize = Vector2.new(BUN_MAX, BUN_MAX / BUN_RATIO), Parent = canvas })
	return {
		Controller = controller,
		Mat = nil,
		Bun = nil,
		Chip = chip,
		Dragging = dragging,
		Carry = source(false :: Carry | false),
		Rings = source(newRings()),
		Overlay = { canvas, chip, makeHold(controller) },
	}
end

-- Inside the bun: the carried slice and the bacon rings (positions in bun space).
function Overlay.Attach(ctx: Ctx)
	const bun = ctx.Bun
	if bun == nil then
		return
	end
	const ghost = create("Frame")({
		Name = "Carry",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function(): UDim2
			const value = ctx.Carry()
			return if value ~= false then UDim2.fromScale(value.X, value.Y) else UDim2.new()
		end,
		Size = UDim2.fromOffset(64, 40),
		BackgroundColor3 = function(): Color3
			const value = ctx.Carry()
			return if value ~= false then Overlay.FoodColor(value.Key) else Theme.Tone.Slate.Bottom
		end,
		BorderSizePixel = 0,
		ZIndex = 9,
		Visible = function()
			return ctx.Carry() ~= false
		end,
		create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = 3,
			LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}) :: Frame
	ghost.Parent = bun

	for index = 1, build.Bacon.Count do
		const x = build.Bacon.X[index] or 0.5
		const y = build.Bacon.Y
		const state = function(): Ring
			const ring: Ring? = ctx.Rings()[index]
			return if ring ~= nil then ring else { Scale = 1, State = "Hidden" }
		end
		-- the fixed target
		const target = create("Frame")({
			Name = `RingTarget{index}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(RING_SIZE, RING_SIZE),
			BackgroundTransparency = 1,
			ZIndex = 8,
			Visible = function()
				return state().State ~= "Hidden"
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = 3,
				Transparency = 0.25,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}) :: Frame
		target.Parent = bun
		-- the ring that closes onto it
		const ring = create("Frame")({
			Name = `Ring{index}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = function(): UDim2
				const side = RING_SIZE * math.max(state().Scale, 0.2)
				return UDim2.fromOffset(side, side)
			end,
			BackgroundTransparency = 1,
			ZIndex = 9,
			Visible = function()
				return state().State ~= "Hidden"
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({
				Color = function(): Color3
					return ringColor(state().State)
				end,
				Thickness = RING_OUTER + 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}) :: Frame
		ring.Parent = bun
	end
end

return Overlay
