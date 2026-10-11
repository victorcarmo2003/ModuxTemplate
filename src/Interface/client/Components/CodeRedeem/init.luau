--!strict
-- CodeRedeem: the lobby codes window (user request 2026-10-11), cartoon kit (AST-091), mobile first.
-- A LobbyWindow (400 x 230 at Scale 1): a Cream text box ("Enter code", 48 px tall), the Green "Redeem" button and one
-- feedback line under them: Good (Green check, "+50 Gems!"), Bad (Mustard warning: invalid / expired / already used;
-- never red, style guide §7.4), Wait ("..."). The box empties after a Good answer. Enter in the box redeems too.
-- Pure: only props; the caller sends CodeRedeem and the server decides.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local LobbyWindow = require(script.Parent.LobbyWindow)
local Icon = require(script.Parent.LobbyWindow.Icon)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; TextBox is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Kind = "None" | "Wait" | "Good" | "Bad"

export type Feedback = { Text: string, Kind: Kind }

export type Props = {
	Visible: () -> boolean,
	Feedback: () -> Feedback,
	OnRedeem: (code: string) -> (),
	OnClose: () -> (),
	Scale: (() -> number)?,
}

const WIDTH = 400
const HEIGHT = 230
const BOX = 48
const MAX_LENGTH = 32

const COLOR: { [Kind]: Color3 } = {
	None = Theme.Color.Text,
	Wait = Theme.Color.Text,
	Good = Theme.Color.Green,
	Bad = Theme.Color.Mustard,
}

const ICON: { [Kind]: string } = {
	None = "",
	Wait = "Ui/hourglass",
	Good = "Ui/check",
	Bad = "Ui/warning",
}

return function(props: Props): Frame
	const text = source("")
	const waiting = function(): boolean
		return props.Feedback().Kind == "Wait"
	end

	const box = createRaw("TextBox")({
		Name = "Input",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		FontFace = Theme.Font.Title,
		TextSize = 22,
		TextColor3 = Theme.Color.Ink,
		PlaceholderText = "Enter code",
		PlaceholderColor3 = Theme.Color.Slate,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		TextTruncate = Enum.TextTruncate.AtEnd,
	}) :: TextBox

	local function redeem()
		const code = string.match(box.Text, "^%s*(.-)%s*$") or ""
		if code == "" or untrack(waiting) then
			return
		end
		props.OnRedeem(code)
	end

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > MAX_LENGTH then
			box.Text = string.sub(box.Text, 1, MAX_LENGTH)
			return
		end
		text(box.Text)
	end)
	box.FocusLost:Connect(function(enter: boolean)
		if enter then
			redeem()
		end
	end)

	-- a Good answer empties the box
	effect(function()
		if props.Feedback().Kind == "Good" then
			untrack(function()
				box.Text = ""
				return nil
			end)
		end
	end)

	return LobbyWindow({
		Name = "CodeRedeem",
		Title = "Codes",
		Icon = "Ui/sparkle",
		Size = Vector2.new(WIDTH, HEIGHT),
		Visible = props.Visible,
		Scale = props.Scale,
		OnClose = props.OnClose,
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			}),
			create("Frame")({
				Name = "Row",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, BOX + 4),
				BackgroundTransparency = 1,
				CartoonPanel({
					Name = "Box",
					Size = UDim2.new(1, -138, 1, 0),
					Tone = Theme.Tone.White,
					Outline = Theme.Outline.Thick,
					Radius = Theme.Radius.Chip,
					Gloss = false,
					Padding = { Left = 10, Right = 10 },
					Children = { box },
				}),
				CartoonButton({
					Name = "Redeem",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(128, BOX + 4),
					TextSize = 20,
					Outline = Theme.Outline.Thick,
					Tone = Theme.Tone.Green,
					Enabled = function()
						return text() ~= "" and not waiting()
					end,
					Text = function()
						return if waiting() then "..." else "Redeem"
					end,
					OnActivated = redeem,
				}),
			}),
			create("Frame")({
				Name = "Feedback",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				Icon(function()
					return ICON[props.Feedback().Kind]
				end, 26, 1),
				CartoonLabel({
					LayoutOrder = 2,
					TextSize = 18,
					Color = function()
						return COLOR[props.Feedback().Kind]
					end,
					Text = function()
						const feedback = props.Feedback()
						return if feedback.Kind == "None" then "Follow us for codes!" else feedback.Text
					end,
				}),
			}),
		},
	})
end
