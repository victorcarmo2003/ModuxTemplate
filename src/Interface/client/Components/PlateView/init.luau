--!strict
-- PlateView: the work surface of the focused prep mode, in 2D (docs/art/prep-ui-spec.md §5.3, §5.4, §6.9; no 3D here:
-- the world behind is just blurred scenery). One bun on the mat with what the stages put on it:
--   Bun        None (nothing on the board: the empty state) / Closed / Cut (the guide and the cut line growing) / Open (the
--              groove for the sausage)
--   Sausage    a state (Raw, Half, Ready, Ghost) at a point inside the bun, 0..1 on both axes (centre = 0.5, 0.5)
--   Toppings   the ones already on the plate (sauce bands, cheese slice, bacon strips, potato sticks); each with an Amount
--   Seal       the grade seal of the plate pinned at the corner (Perfect / Good / Messy)
--   Message    the empty-state line ("Waiting for the grill", "Nothing to serve") with the ghost of the bun
-- Flat Frames in the food colours until the sprites exist (AST-110, AST-111). `OnMount(mat, bun)` hands the two frames to
-- the owner (pointer maths in screen px: AbsolutePosition / AbsoluteSize); `Overlay` children (the StrokeCanvas) sit in the
-- mat on top of everything. Pure: only props. Build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Seal = require(script.Seal)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIGradient, UIAspectRatioConstraint, UISizeConstraint and
-- UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type BunState = "None" | "Closed" | "Cut" | "Open"

export type SausageState = "Raw" | "Half" | "Ready" | "Ghost"

export type Sausage = { X: number, Y: number, State: SausageState }

export type Topping = { Key: string, Amount: number }

export type Props = {
	Bun: () -> BunState,
	-- 0..1 of the cut line (Bun = Cut).
	Cut: (() -> number)?,
	-- The dashed guide of the cut.
	Guide: (() -> boolean)?,
	Sausage: (() -> Sausage?)?,
	Toppings: (() -> { Topping })?,
	Seal: (() -> Seal.Grade?)?,
	SealLabel: ((Seal.Grade) -> string)?,
	SealSize: number?,
	-- Empty-state line, shown with Bun = None.
	Message: (() -> string)?,
	OnMount: ((mat: Frame, bun: Frame) -> ())?,
	Overlay: { any }?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Name: string?,
}

export type Grade = Seal.Grade

-- Food colours (pictures of food, not UI states).
const BUN_TOP = Color3.fromHex("#EFC27F")
const BUN_BOTTOM = Color3.fromHex("#D49A52")
const GROOVE = Color3.fromHex("#B97F0A")
const SAUSAGE: { [SausageState]: Color3 } = {
	Raw = Color3.fromHex("#EFAFA6"),
	Half = Color3.fromHex("#DD8570"),
	Ready = Color3.fromHex("#B9573C"),
	Ghost = Color3.fromHex("#2B2233"),
}
const TOPPING: { [string]: Color3 } = {
	ketchup = Color3.fromHex("#E2402E"),
	mustard = Color3.fromHex("#F6C12B"),
	cream_cheese = Color3.fromHex("#FFF8EA"),
	cheese = Color3.fromHex("#FFC64D"),
	bacon = Color3.fromHex("#C8553D"),
	potato_sticks = Color3.fromHex("#E8C26A"),
}
const BUN_RATIO = 3.1 -- 260 x 84 of the spec
const BUN_MAX = 340 -- px at UI scale 1
const DASHES = 12

local function outlined(color: Color3, extra: { [any]: any }, children: { any }?): Frame
	const props: { [any]: any } = {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}
	for key, value in extra do
		props[key] = value
	end
	const list: { any } = {
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = 3,
			LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}
	if children ~= nil then
		table.insert(list, children)
	end
	props[1] = list
	return create("Frame")(props) :: Frame
end

-- A topping already on the plate, in bun coordinates (0..1). `slot` 0..2 stacks them without hiding each other.
local function toppingView(key: string, amount: () -> number, slot: number): Frame
	const color = TOPPING[key] or Theme.Tone.Slate.Bottom
	const y = 0.3 + slot * 0.2
	if key == "cheese" then
		return outlined(color, {
			Name = "Cheese",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromScale(0.5, 0.3),
			Rotation = -4 + slot * 5,
		}, nil)
	elseif key == "bacon" then
		const strips: { any } = {}
		for index = 1, 3 do
			table.insert(
				strips,
				create("Frame")({
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.25 + 0.25 * (index - 1), 0.5),
					Size = UDim2.fromScale(0.16, 1.2),
					Rotation = 12 - index * 6,
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					create("UICorner")({ CornerRadius = UDim.new(0.4, 0) }),
					createRaw("UIStroke")({
						Color = Theme.Color.Ink,
						Thickness = 2,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				})
			)
		end
		return create("Frame")({
			Name = "Bacon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromScale(0.7, 0.2),
			BackgroundTransparency = 1,
			strips,
		})
	elseif key == "potato_sticks" then
		const sticks: { any } = {}
		for index = 1, 8 do
			table.insert(
				sticks,
				create("Frame")({
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.08 + 0.12 * (index - 1), 0.5),
					Size = UDim2.fromScale(0.05, 1),
					Rotation = (index * 37) % 50 - 25,
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				})
			)
		end
		return create("Frame")({
			Name = "PotatoSticks",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromScale(0.74, 0.2),
			BackgroundTransparency = 1,
			sticks,
		})
	end
	-- sauces: a band whose length is the amount, with a lighter streak
	return outlined(color, {
		Name = "Sauce",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = function()
			return UDim2.fromScale(0.86 * math.clamp(amount(), 0.05, 1), 0.1)
		end,
		Rotation = (slot - 1) * 2,
	}, nil)
end

return function(props: Props): Frame
	const cutProgress = props.Cut or function(): number
		return 0
	end

	-- the bun box: every bun-relative piece lives inside it
	const bunPieces: { any } = {
		createRaw("UIAspectRatioConstraint")({ AspectRatio = BUN_RATIO, DominantAxis = Enum.DominantAxis.Width }),
		createRaw("UISizeConstraint")({ MaxSize = Vector2.new(BUN_MAX, BUN_MAX / BUN_RATIO) }),
	}

	-- body of the bun (gradient), the groove when open
	table.insert(
		bunPieces,
		create("Frame")({
			Name = "Body",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Visible = function()
				return props.Bun() ~= "None"
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = 3,
				LineJoinMode = Enum.LineJoinMode.Round,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			createRaw("UIGradient")({ Rotation = 90, Color = ColorSequence.new(BUN_TOP, BUN_BOTTOM) }),
		})
	)
	table.insert(
		bunPieces,
		create("Frame")({
			Name = "Groove",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.42),
			BackgroundColor3 = GROOVE,
			BorderSizePixel = 0,
			Visible = function()
				return props.Bun() == "Open"
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		})
	)

	-- the dashed guide of the cut
	const guide: { any } = {}
	for index = 1, DASHES do
		table.insert(
			guide,
			create("Frame")({
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale((index - 1) / DASHES + 0.02, 0.5),
				Size = UDim2.fromScale(0.5 / DASHES, 0.05),
				BackgroundColor3 = Theme.Color.Ink,
				BorderSizePixel = 0,
			})
		)
	end
	table.insert(
		bunPieces,
		create("Frame")({
			Name = "Guide",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = function()
				const state = props.Bun()
				return (state == "Closed" or state == "Cut") and props.Guide ~= nil and props.Guide()
			end,
			guide,
		})
	)
	table.insert(
		bunPieces,
		create("Frame")({
			Name = "CutLine",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.04, 0.5),
			Size = function()
				return UDim2.new(0.92 * math.clamp(cutProgress(), 0, 1), 0, 0, 5)
			end,
			BackgroundColor3 = Theme.Color.Ink,
			BorderSizePixel = 0,
			Visible = function()
				return props.Bun() == "Cut"
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		})
	)

	-- the sausage, positioned inside the bun box (centre = X, Y)
	if props.Sausage ~= nil then
		const sausage = props.Sausage
		table.insert(
			bunPieces,
			outlined(SAUSAGE.Raw, {
				Name = "Sausage",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = function()
					const value = sausage()
					return if value ~= nil then UDim2.fromScale(value.X, value.Y) else UDim2.fromScale(0.5, 0.5)
				end,
				Size = UDim2.fromScale(0.86, 0.36),
				ZIndex = 3,
				BackgroundColor3 = function()
					const value = sausage()
					const state: SausageState = if value ~= nil then value.State else "Raw"
					return SAUSAGE[state]
				end,
				BackgroundTransparency = function()
					const value = sausage()
					return if value ~= nil and value.State == "Ghost" then 0.82 else 0
				end,
				Visible = function()
					return sausage() ~= nil
				end,
			}, nil)
		)
	end

	-- toppings: three slots at most (OrderRules.MaxToppings), each built once for the key it holds now
	if props.Toppings ~= nil then
		const toppings = props.Toppings
		for slot = 0, 2 do
			const holder = create("Frame")({
				Name = `Topping{slot + 1}`,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 4,
				Visible = function()
					return toppings()[slot + 1] ~= nil
				end,
			})
			-- Vide children are static: swap the picture when the key of the slot changes
			-- (the picture lives in its own root so a re-run of this effect does not tear its bindings down)
			const shown = source("")
			local destroyView: (() -> ())? = nil
			Vide.effect(function()
				const entry = toppings()[slot + 1]
				const key = if entry ~= nil then entry.Key else ""
				if key == Vide.untrack(shown) then
					return
				end
				Vide.untrack(function()
					shown(key)
					if destroyView ~= nil then
						destroyView()
						destroyView = nil
					end
					holder:ClearAllChildren()
					if key ~= "" then
						const destroy, view = Vide.root(function(): Frame
							return toppingView(key, function(): number
								const current = toppings()[slot + 1]
								return if current ~= nil then current.Amount else 0
							end, slot)
						end)
						destroyView = destroy
						view.Parent = holder
					end
					return nil
				end)
			end)
			cleanup(function()
				if destroyView ~= nil then
					destroyView()
				end
			end)
			table.insert(bunPieces, holder)
		end
	end

	const bun = create("Frame")({
		Name = "Bun",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.64, 0.5),
		BackgroundTransparency = 1,
		bunPieces,
	})

	-- empty state: the ghost of the bun, the line and (not reduced) three breathing dots
	const message = props.Message
	const dots = source(0)
	const dotThread = task.spawn(function()
		while true do
			task.wait(0.5)
			dots((Vide.untrack(dots) + 1) % 4)
		end
	end)
	cleanup(function()
		if coroutine.status(dotThread) == "suspended" then
			task.cancel(dotThread)
		end
	end)
	const empty = create("Frame")({
		Name = "Empty",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = function()
			return props.Bun() == "None"
		end,
		create("Frame")({
			Name = "Ghost",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(0.64, 0.5),
			BackgroundTransparency = 1,
			createRaw("UIAspectRatioConstraint")({ AspectRatio = BUN_RATIO, DominantAxis = Enum.DominantAxis.Width }),
			createRaw("UISizeConstraint")({ MaxSize = Vector2.new(BUN_MAX, BUN_MAX / BUN_RATIO) }),
			create("Frame")({
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Color.Ink,
				BackgroundTransparency = 0.82,
				BorderSizePixel = 0,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
		}),
		CartoonLabel({
			Name = "Line",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.72),
			Box = UDim2.new(0.9, 0, 0, 24),
			Text = function()
				const line = if message ~= nil then message() else ""
				if line == "" then
					return ""
				end
				return if Motion.Reduced() then line else line .. string.rep(".", dots())
			end,
			TextSize = 16,
			Color = Theme.Color.Ink,
			Stroke = 0,
			XAlignment = Enum.TextXAlignment.Center,
			YAlignment = Enum.TextYAlignment.Center,
		}),
	})

	const children: { any } = { empty, bun }

	if props.Seal ~= nil then
		const size = props.SealSize or 96
		table.insert(
			children,
			Seal({
				Name = "PlateSeal",
				Grade = props.Seal,
				Size = size,
				Label = props.SealLabel,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 4),
			})
		)
	end
	if props.Overlay ~= nil then
		table.insert(children, props.Overlay)
	end

	const mat = create("Frame")({
		Name = props.Name or "PlateView",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		children,
	})
	if props.OnMount ~= nil then
		props.OnMount(mat, bun)
	end
	return mat
end
