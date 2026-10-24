--!strict
-- Credits: the roll of the "credits" scene (TASK-657, DEC-363; data in Content.Cutscenes.Rules.Credits).
-- A centred column (title, tagline, sections, closing line) that scrolls up over the black of the scene. Its place is
-- a pure function of `Progress` (0 = the top of the column at the bottom of the screen, 1 = the column gone above it):
-- AnchorPoint Y and Position Y move together, so no measuring is needed and a late client lands on the same line.
-- Px at UI scale 1 (drawn for the 667 x 375 phone; the owner's UIScale sizes it), text never under Theme.MinTextSize.
-- Nothing clickable: the column never takes input, the skip pill (a sibling with a higher ZIndex) stays on top.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local CartoonLabel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UISizeConstraint is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

type Data = typeof(Content.Cutscenes.Rules.Credits)

export type Props = {
	Name: string?,
	Data: Data,
	Progress: () -> number,
	Visible: () -> boolean,
}

-- PROVISIONAL (frontend-coder, 2026-10-23): sizes and gaps, judged at 667 x 375
const WIDTH = 520 -- most the column takes (leaves the skip pill its corner on a phone)
const SIDE = 48 -- px kept free on each side on a narrow screen
const TITLE_SIZE = 34
const TAGLINE_SIZE = 16
const HEADER_SIZE = 22
const LINE_SIZE = 18
const NOTE_SIZE = 14
const SECTION_GAP = 30
const LINE_GAP = 8

local function label(name: string, text: string, size: number, color: Color3, order: number): TextLabel
	return CartoonLabel({
		Name = name,
		Text = text,
		TextSize = size,
		Color = color,
		Wrapped = true,
		Box = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	})
end

local function list(padding: number): UIListLayout
	return create("UIListLayout")({
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding),
	})
end

local function block(name: string, order: number, gap: number, children: { any }): Frame
	return create("Frame")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		create("UIPadding")({ PaddingTop = UDim.new(0, gap) }),
		list(LINE_GAP),
		children,
	})
end

return function(props: Props): Frame
	const data = props.Data
	const color = Theme.Color

	const rows: { any } = {
		label("Title", data.Title, TITLE_SIZE, color.Mustard, 1),
	}
	const tagline = data.Tagline
	if tagline ~= nil then
		table.insert(rows, label("Tagline", tagline, TAGLINE_SIZE, color.Cream, 2))
	end
	for index, section in data.Sections do
		const entries: { any } = { label("Header", section.Title, HEADER_SIZE, color.Mustard, 0) }
		for order, line in section.Lines do
			const children: { any } = { list(2), label("Text", line.Text, LINE_SIZE, color.Text, 1) }
			const note = line.Note
			if note ~= nil then
				table.insert(children, label("Note", note, NOTE_SIZE, color.Cream, 2))
			end
			table.insert(
				entries,
				create("Frame")({
					Name = `Line{order}`,
					LayoutOrder = order,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					children,
				})
			)
		end
		table.insert(rows, block(`Section{index}`, 2 + index, SECTION_GAP, entries))
	end
	const closing = data.Closing
	if closing ~= nil then
		table.insert(
			rows,
			block("Closing", 3 + #data.Sections, SECTION_GAP * 2, {
				label("Text", closing, HEADER_SIZE, color.Cream, 0),
			})
		)
	end

	return create("Frame")({
		Name = props.Name or "Credits",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Active = false,
		ZIndex = 0,
		Visible = props.Visible,
		create("Frame")({
			Name = "Column",
			AnchorPoint = function(): Vector2
				return Vector2.new(0.5, props.Progress())
			end,
			Position = function(): UDim2
				return UDim2.fromScale(0.5, 1 - props.Progress())
			end,
			Size = UDim2.new(1, -2 * SIDE, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			createRaw("UISizeConstraint")({ MaxSize = Vector2.new(WIDTH, math.huge) }),
			list(LINE_GAP),
			rows,
		}),
	}) :: Frame
end
