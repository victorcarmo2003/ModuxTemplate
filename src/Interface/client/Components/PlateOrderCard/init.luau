--!strict
-- PlateOrderCard: the order card over a plate slot of the front counter (DEC-311; owner 2026-10-19). The plate shows only while a
-- ticket line waits for it, and this card says which order it is, so the cook picks the plate of the order they will make.
--   Tab      "#n" (Mustard) over the top-left corner; "Drive-thru" chip when the order came from the lane
--   Stack    the order as the layered hot dog (OrderStack, vertical): bun, sausage, the toppings, the lid. Sized so the pictures
--            fit their bands (the old ticket had pictures much bigger than the card: Sprite <= Pitch + 4 here)
--   Bar      the customer's patience, draining (Green, Mustard under WARN; never red, style guide §2.4); hidden with no clock
-- Status only: nothing clickable. Pure: only props; build it inside a Vide root. Pixel layout: SlotCards fits it to a studs
-- billboard with a UIScale (it shrinks with distance).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonLabel = require(script.Parent.CartoonLabel)
local OrderStack = require(script.Parent.OrderStack)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Number: () -> number?,
	Toppings: () -> { string },
	-- a bun alone, no sausage (Content.OrderRules.BreadOnly; OrderStack Bread). Default false
	Bread: (() -> boolean)?,
	Drive: (() -> boolean)?,
	-- 0..1 of the patience left, nil = no clock running (the bar hides)
	Patience: (() -> number?)?,
}

const WIDTH = 132
const PAD = 8
const TAB_HEIGHT = 22
const PITCH = 22 -- px of a layer band
const SPRITE = 26 -- px of a layer picture (a little over its band, never twice it)
const MEDALLION = 20
const BAR = 8
const WARN = 0.35

-- Px height of the card for an order of `toppings` (the stack grows with it; BillboardGui sizes follow)
local function cardHeight(toppings: number): number
	const layers = 2 + math.min(toppings, 3) + (if toppings <= 2 then 1 else 0)
	return TAB_HEIGHT / 2 + PAD + layers * PITCH + (SPRITE - PITCH) + PAD + BAR + PAD
end

local function card(props: Props): Frame
	const patience = props.Patience or function(): number?
		return nil
	end
	return create("Frame")({
		Name = "PlateOrderCard",
		Size = function(): UDim2
			return UDim2.fromOffset(WIDTH, cardHeight(#props.Toppings()))
		end,
		BackgroundTransparency = 1,
		-- the card body under the tab
		create("Frame")({
			Name = "Body",
			Position = UDim2.fromOffset(0, TAB_HEIGHT / 2),
			Size = UDim2.new(1, 0, 1, -TAB_HEIGHT / 2),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0, 12) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			create("Frame")({
				Name = "Stack",
				Position = UDim2.fromOffset(PAD, PAD),
				Size = UDim2.new(1, -PAD * 2, 1, -(PAD * 3 + BAR)),
				BackgroundTransparency = 1,
				OrderStack({
					Toppings = props.Toppings,
					Bread = props.Bread,
					Direction = "Vertical",
					Pitch = PITCH,
					Sprite = SPRITE,
					Medallion = MEDALLION,
				}),
			}),
			-- the patience bar
			create("Frame")({
				Name = "Bar",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, PAD, 1, -PAD),
				Size = UDim2.new(1, -PAD * 2, 0, BAR),
				BackgroundColor3 = Theme.Color.Cream,
				BorderSizePixel = 0,
				Visible = function(): boolean
					return patience() ~= nil
				end,
				create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2 }),
				create("Frame")({
					Name = "Fill",
					Size = function(): UDim2
						return UDim2.fromScale(math.clamp(patience() or 0, 0, 1), 1)
					end,
					BackgroundColor3 = function(): Color3
						return if (patience() or 1) < WARN then Theme.Color.Mustard else Theme.Color.Green
					end,
					BorderSizePixel = 0,
					create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				}),
			}),
		}),
		-- the "#n" tab
		create("Frame")({
			Name = "Tab",
			Position = UDim2.fromOffset(PAD, 0),
			Size = UDim2.fromOffset(0, TAB_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.Color.Mustard,
			BorderSizePixel = 0,
			ZIndex = 20,
			create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			createRaw("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
			}),
			CartoonLabel({
				Name = "Number",
				Text = function(): string
					const number = props.Number()
					return if number ~= nil then `#{number}` else "?"
				end,
				TextSize = 16,
				Color = Theme.Color.Dark,
				Stroke = 0,
				ZIndex = 21,
			}),
			CartoonLabel({
				Name = "Drive",
				Text = function(): string
					return if props.Drive ~= nil and props.Drive() then "Drive-thru" else ""
				end,
				TextSize = Theme.MinTextSize,
				Color = Theme.Color.Dark,
				Stroke = 0,
				ZIndex = 21,
			}),
		}),
	}) :: Frame
end

return table.freeze({
	Card = card,
	Height = cardHeight,
	Width = WIDTH,
})
