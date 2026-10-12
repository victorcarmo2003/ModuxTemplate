--!strict
-- Parts: the pieces every stage of the focused prep mode builds its Board / Panel from (so the four placeholders and the
-- real stages of P7 look the same): the plate on the board, the ingredient panel, a one-line notice, the empty grill slots.
-- All read the controller's view-model (`controller.View`, Vide sources the stages write); nothing here decides a rule.
-- Build them inside the Vide scope of a Board / Panel function (the shell calls those inside its root).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local CartoonLabel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonLabel)
local CartoonPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonPanel)
local IngredientPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.IngredientPanel)
local PlateView = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PlateView)
local Seal = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PlateView.Seal)
local StrokeCanvas = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.StrokeCanvas)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIGridLayout is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const Parts = {}

-- The plate on the board, fed by the view-model. `onMount(mat, bun)` gives the frames for the gestures (Regions).
function Parts.Plate(controller: any, onMount: ((mat: Frame, bun: Frame) -> ())?, overlay: { any }?): Frame
	const view = controller.View
	return PlateView({
		Bun = view.Bun,
		Cut = view.Cut,
		Guide = view.Guide,
		Sausage = function(): PlateView.Sausage?
			const value = view.Sausage()
			return if value ~= false then value else nil
		end,
		Toppings = view.Toppings,
		Seal = function(): Seal.Grade?
			const value = view.Seal()
			return if value ~= false then value else nil
		end,
		SealLabel = function(grade: Seal.Grade): string
			return Content.Prep.Grades.Labels[grade]
		end,
		Message = view.Message,
		OnMount = onMount,
		Overlay = overlay,
	})
end

-- The sauce stroke layer for the plate overlay.
function Parts.Strokes(controller: any): Frame
	const view = controller.View
	return StrokeCanvas({
		Points = view.Stroke,
		Guide = view.StrokeGuide,
		Meter = function(): StrokeCanvas.Meter?
			const value = view.Meter()
			return if value ~= false then value else nil
		end,
		Color = view.StrokeColor,
		Thickness = 10,
	})
end

-- The topping boxes (Build tab). Stock and lock come from the KitchenController through the view-model.
function Parts.Ingredients(controller: any, layout: () -> any): Frame
	const view = controller.View
	return IngredientPanel({
		Info = function(key: string)
			return view.Info(key)
		end,
		Cols = function(): number
			return layout().Cols
		end,
		Rows = function(): number
			return layout().Rows
		end,
		Box = function(): number
			return layout().Box
		end,
		Full = view.Full,
		Disabled = function(): boolean
			return controller.Step() ~= "build"
		end,
		OnPick = function(key: string)
			controller:OnPick(key)
		end,
		Focus = view.Focus,
		Refused = view.Refused,
	})
end

-- A centred line on the board (a stage that has nothing to show yet).
function Parts.Notice(text: () -> string): Frame
	return create("Frame")({
		Name = "Notice",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		CartoonLabel({
			Text = text,
			TextSize = 18,
			Color = Theme.Color.Ink,
			Stroke = 0,
			Box = UDim2.fromScale(1, 1),
			Wrapped = true,
			XAlignment = Enum.TextXAlignment.Center,
			YAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

-- Empty grill slots (4 x 2 on a phone): the layout of the Grill tab before P7b brings the cooking in.
function Parts.GrillSlots(controller: any): Frame
	const slots: { any } = {
		createRaw("UIGridLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			CellSize = UDim2.new(0.25, -8, 0.5, -8),
			CellPadding = UDim2.fromOffset(8, 8),
			FillDirection = Enum.FillDirection.Horizontal,
		}),
	}
	for index = 1, 8 do
		table.insert(
			slots,
			CartoonPanel({
				Name = `Slot{index}`,
				LayoutOrder = index,
				Tone = Theme.Tone.Cream,
				Radius = Theme.Radius.Chip,
				Outline = 2,
				Gloss = false,
				Children = {
					CartoonLabel({
						Text = "+",
						TextSize = 24,
						Color = Theme.Color.Ink,
						Stroke = 0,
						Box = UDim2.fromScale(1, 1),
						XAlignment = Enum.TextXAlignment.Center,
						YAlignment = Enum.TextYAlignment.Center,
					}),
				},
			})
		)
	end
	return create("Frame")({
		Name = "GrillSlots",
		Size = UDim2.fromScale(1, 0.8),
		BackgroundTransparency = 1,
		slots,
	})
end

return Parts
