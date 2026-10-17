--!strict
-- HorrorCaption: the big short warning of a horror beat (TASK-444, owner request 2026-10-17: "POWER OUT — HIDE IN THE
-- BACK"). Cinematic, not a HUD card: a dark soft band across the screen a little above the centre, a wide spaced title
-- in Cream with an Ink outline, a thin Mustard rule and one short line under it. It fades in, drifts a few px while it
-- holds and fades out by itself (the owner flips Shown). No button and nothing Active: in first person the cursor sits
-- in the centre and an Active object there would eat the camera (README, "armadilha da UI no centro"). Never alert red
-- (style-guide §7). Text >= Theme.MinTextSize on the smallest phone.
-- Pure: only props. The owner (AnomalyController/Score) decides the texts and when it shows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const spring = Vide.spring
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIScale and UIGradient are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Shown: () -> boolean,
	Title: () -> string,
	Line: () -> string,
	-- UI scale of the owner (1 on the smallest phone)
	Scale: (() -> number)?,
	Name: string?,
}

const TITLE_SIZE = 46 -- px at scale 1
const LINE_SIZE = 20 -- >= Theme.MinTextSize
const BAND_HEIGHT = 124
const BAND_DARK = 0.25 -- band transparency at its middle when shown
const DRIFT = 14 -- px the block rises while it fades in
const RULE_WIDTH = 220
-- "POWER OUT" -> "P O W E R   O U T": the wide-tracked title of a film card (Roblox text has no letter spacing)
local function spaced(text: string): string
	const out: { string } = {}
	for _, code in utf8.codes(text) do
		const char = utf8.char(code)
		table.insert(out, if char == " " then "  " else char)
	end
	return table.concat(out, " ")
end

return function(props: Props): Frame
	-- keep the last texts while fading out
	local lastTitle = ""
	local lastLine = ""
	const title = function(): string
		const value = props.Title()
		if props.Shown() and value ~= "" then
			lastTitle = value
		end
		return spaced(lastTitle)
	end
	const line = function(): string
		const value = props.Line()
		if props.Shown() and value ~= "" then
			lastLine = value
		end
		return lastLine
	end
	const alpha = spring(function()
		return if props.Shown() then 0 else 1
	end, 0.45, 1)
	const rise = spring(function()
		return if props.Shown() then 0 else DRIFT
	end, 0.9, 1)
	const band = function(): number
		return BAND_DARK + (1 - BAND_DARK) * alpha()
	end

	return create("Frame")({
		Name = props.Name or "HorrorCaption",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.34),
		Size = UDim2.new(1, 0, 0, BAND_HEIGHT),
		BackgroundTransparency = 1,
		Active = false,
		Visible = function()
			return alpha() < 0.99
		end,

		createRaw("UIScale")({
			Scale = function()
				return if props.Scale then props.Scale() else 1
			end,
		}),

		-- dark soft band, fading to nothing at the top and bottom edges
		create("Frame")({
			Name = "Band",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = band,
			BorderSizePixel = 0,
			Active = false,
			createRaw("UIGradient")({
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, 0),
					NumberSequenceKeypoint.new(0.7, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		}),

		create("Frame")({
			Name = "Block",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				return UDim2.new(0.5, 0, 0.5, rise())
			end,
			Size = UDim2.new(1, -24, 1, -16),
			BackgroundTransparency = 1,
			Active = false,

			create("TextLabel")({
				Name = "Title",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0.5, 4),
				Size = UDim2.new(1, 0, 0, TITLE_SIZE + 6),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				TextSize = TITLE_SIZE,
				TextColor3 = Theme.Color.Cream,
				TextTransparency = alpha,
				Text = title,
				createRaw("UIStroke")({
					Color = Theme.Color.Ink,
					Thickness = Theme.Outline.Normal,
					Transparency = alpha,
				}),
			}),

			create("Frame")({
				Name = "Rule",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 12),
				Size = UDim2.fromOffset(RULE_WIDTH, 3),
				BackgroundColor3 = Theme.Color.Mustard,
				BackgroundTransparency = alpha,
				BorderSizePixel = 0,
				Active = false,
			}),

			create("TextLabel")({
				Name = "Line",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0.5, 20),
				Size = UDim2.new(1, 0, 0, LINE_SIZE + 6),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Body,
				TextSize = LINE_SIZE,
				TextColor3 = Theme.Color.Text,
				TextTransparency = alpha,
				Text = line,
				createRaw("UIStroke")({
					Color = Theme.Color.Ink,
					Thickness = Theme.Stroke,
					Transparency = alpha,
				}),
			}),
		}),
	})
end
