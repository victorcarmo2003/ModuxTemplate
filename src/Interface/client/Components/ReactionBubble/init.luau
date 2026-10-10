--!strict
-- ReactionBubble: the customer's reaction to a sale over its head (FEAT-011 "balão feliz/neutro/reclamação"; style
-- guide §7.3 "Reação do cliente": original icons, happy = star, complaint = scribbled cloud; no font emoji) plus an
-- optional one-line speech (ui-text.md §8). Pure: only props. CustomerController (TASK-034) picks the kind and the
-- line, mounts it for a few seconds and destroys it.
-- Fixed pixel size (not studs): icon 44 px and text 16 px on a phone at any distance it is drawn (MaxDistance).
-- Pops in (scale 0 -> 1, Back easing) when mounted.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local UseTween = require(script.Parent.UseTween)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Kind = "Happy" | "Neutral" | "Complaint"

export type Props = {
	Adornee: Instance?,
	Kind: () -> Kind,
	-- One line under the icon; "" hides it.
	Text: () -> string,
	Offset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 240
const ICON = 44
const LINE_HEIGHT = 30
const GAP = 4
const HEIGHT = ICON + GAP + LINE_HEIGHT
const TEXT_SIZE = 16
const POP_TIME = 0.25

const WHITE = Color3.fromHex("#FFFFFF")

local function stroke(): Instance
	return createRaw("UIStroke")({
		Color = Theme.Color.Ink,
		Thickness = Theme.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- 8-point star: two Mustard squares, one turned 45°, and a lighter core.
local function star(): Frame
	return create("Frame")({
		Name = "Star",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			BackgroundColor3 = Theme.Color.Mustard,
			stroke(),
		}),
		create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			Rotation = 45,
			BackgroundColor3 = Theme.Color.Mustard,
			stroke(),
		}),
		create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.62),
			Rotation = 22.5,
			BackgroundColor3 = Theme.Color.Mustard,
			ZIndex = 2,
		}),
		create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.3, 0.3),
			BackgroundColor3 = Theme.Color.Cream,
			ZIndex = 3,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),
	})
end

-- Scribbled cloud: three Slate puffs and a white zigzag.
local function cloud(): Frame
	local function puff(x: number, y: number, size: number): Frame
		return create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(size, size),
			BackgroundColor3 = Theme.Color.Slate,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			stroke(),
		})
	end
	return create("Frame")({
		Name = "Cloud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		puff(0.3, 0.6, 0.5),
		puff(0.7, 0.6, 0.5),
		puff(0.5, 0.42, 0.62),
		create("TextLabel")({
			Name = "Scribble",
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0.04),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextSize = 22,
			TextColor3 = Theme.Color.Text,
			Text = "~~",
			ZIndex = 2,
		}),
	})
end

-- Neutral: Cream circle with "...".
local function dots(): Frame
	return create("Frame")({
		Name = "Dots",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundColor3 = Theme.Color.Cream,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		stroke(),
		create("TextLabel")({
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, -0.12),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextSize = 22,
			TextColor3 = Theme.Color.Ink,
			Text = "...",
		}),
	})
end

return function(props: Props): BillboardGui
	const shown = source(false)
	const thread = task.defer(function()
		shown(true)
	end)
	cleanup(function()
		if coroutine.status(thread) == "suspended" then
			task.cancel(thread)
		end
	end)
	const size = UseTween(function()
		return if shown() then UDim2.fromScale(1, 1) else UDim2.fromScale(0, 0)
	end, POP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local function hasText(): boolean
		return props.Text() ~= ""
	end

	return create("BillboardGui")({
		Name = props.Name or "ReactionBubble",
		Adornee = props.Adornee,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		SizeOffset = Vector2.new(0, 0.5),
		StudsOffsetWorldSpace = props.Offset or Vector3.new(0, 1.5, 0),
		MaxDistance = props.MaxDistance or 60,
		LightInfluence = 0,
		ResetOnSpawn = false,

		create("Frame")({
			Name = "Pop",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = size,
			BackgroundTransparency = 1,

			create("Frame")({
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(ICON / WIDTH, ICON / HEIGHT),
				BackgroundTransparency = 1,
				create("Frame")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Visible = function()
						return props.Kind() == "Happy"
					end,
					star(),
				}),
				create("Frame")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Visible = function()
						return props.Kind() == "Complaint"
					end,
					cloud(),
				}),
				create("Frame")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Visible = function()
						return props.Kind() == "Neutral"
					end,
					dots(),
				}),
			}),

			create("TextLabel")({
				Name = "Line",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				-- as wide as the line (pill), height follows the pop
				Size = UDim2.fromScale(0, LINE_HEIGHT / HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = WHITE,
				FontFace = Theme.Font.Body,
				TextSize = TEXT_SIZE,
				TextScaled = false,
				TextColor3 = Theme.Color.Ink,
				Text = props.Text,
				Visible = function()
					-- hidden while the pop is tiny: TextSize is fixed and would spill out of a small frame
					return hasText() and shown()
				end,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				stroke(),
				createRaw("UIPadding")({
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
				}),
			}),
		}),
	})
end
