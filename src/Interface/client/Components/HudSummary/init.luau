--!strict
-- HudSummary: end-of-shift card (FEAT-014; style guide §7.4 "Fim de turno"; AST-091 "Cartão Cream"): centred Cream
-- card with studs, title on an Ink ribbon tab, huge grade letter on a round badge (A Mustard, B Green, C Teal,
-- D Slate; never red) tilted like a sticker, money lines, gems of the shift when there are any.
-- Status only (DEC-015, FEAT-032): no close button. The owner shows it by setting `Report` and hides it by setting
-- false (HudController does it after 15 s day / 20 s night); the card pops in (Motion.Pop) and shrinks away with the
-- last report on it.
-- No reputation, no boss chances, no XP (DEC-051, DEC-053, DEC-081). Texts are placeholders until ui-text.md.
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local Money = require(script.Parent.HudPill.Money)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Grade = "A" | "B" | "C" | "D"

-- What the card shows; HudController builds it from the ShiftReport packet (network.md §4.4).
export type Report = {
	Title: string, -- "Day 3" / "Night 2"
	Arrived: number,
	Completed: number,
	Drawer: number,
	Stolen: number,
	Grade: Grade,
	Bonus: number,
	Deposited: number,
	Gems: number, -- already credited this shift (DEC-104)
	GemsTotal: number?, -- account total, when known
	AfkLocked: boolean, -- DEC-083
	LastChanceUsed: boolean, -- night summary only (DEC-053, DEC-110)
}

-- false = hidden (a Source of an optional type is ambiguous to call under the new solver)
export type Shown = Report | false

export type Props = {
	Report: () -> Shown,
	Name: string?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
}

const WIDTH = 280
const ROW_HEIGHT = 24
const TEXT_SIZE = 16
const TITLE_SIZE = 22
const GRADE = 60 -- badge
const GRADE_SIZE = 40
const ICON = 22

const GRADE_TONE: { [Grade]: Theme.Tone } = {
	A = Theme.Tone.Mustard,
	B = Theme.Tone.Green,
	C = Theme.Tone.Teal,
	D = Theme.Tone.Slate,
}

local function icon(name: string): Instance
	const rect = Icons.Rect(name)
	return create("ImageLabel")({
		Name = "Icon",
		LayoutOrder = 0,
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundTransparency = 1,
		Image = Icons.ImageOf(name),
		ImageRectOffset = if rect then rect.Offset else Vector2.zero,
		ImageRectSize = if rect then rect.Size else Vector2.zero,
		Visible = rect ~= nil,
	})
end

-- One line: optional icon + label on the left, value on the right. `chip` puts the value on a tone chip.
local function row(order: number, iconName: string, left: string, right: string, chip: Theme.Tone?): Frame
	return create("Frame")({
		Name = "Row",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT + (if chip then 6 else 0)),
		BackgroundTransparency = 1,

		create("Frame")({
			Name = "Left",
			Size = UDim2.fromScale(0.6, 1),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			if iconName ~= "" then icon(iconName) else {},
			CartoonLabel({
				Name = "Label",
				LayoutOrder = 1,
				Text = left,
				TextSize = TEXT_SIZE,
				Color = Theme.Color.Dark,
				Stroke = 0,
			}),
		}),

		if chip
			then CartoonPanel({
				Name = "Value",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(0, ROW_HEIGHT + 4),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = chip,
				Outline = Theme.Outline.Normal,
				Lip = 3,
				Padding = { Left = 10, Right = 10 },
				Children = {
					CartoonLabel({
						Box = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						Text = right,
						TextSize = TEXT_SIZE + 2,
						Color = chip.Text,
						Stroke = if chip.Stroke then 2 else 0,
					}),
				},
			})
			else CartoonLabel({
				Name = "Value",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Box = UDim2.new(0.4, 0, 1, 0),
				Text = right,
				TextSize = TEXT_SIZE,
				XAlignment = Enum.TextXAlignment.Right,
				Color = Theme.Color.Dark,
				Stroke = 0,
			}),
	})
end

local function note(order: number, text: string): TextLabel
	return CartoonLabel({
		Name = "Note",
		LayoutOrder = order,
		Box = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Text = text,
		TextSize = Theme.MinTextSize + 2,
		Color = Theme.Color.Slate,
		Stroke = 0,
	})
end

-- FEAT-014 lines, in order. "Stolen" only when something was stolen; gems only when the shift credited any.
local function rows(report: Report): { Instance }
	const list: { Instance } = {}
	table.insert(list, row(1, "Ui/friends", "Customers", `{report.Completed} / {report.Arrived}`))
	table.insert(list, row(2, "Ui/cash", "Drawer", Money(report.Drawer)))
	if report.Stolen > 0 then
		table.insert(list, row(3, "", "Stolen", Money(-report.Stolen)))
	end
	table.insert(list, row(4, "Ui/sparkle", `Grade {report.Grade} bonus`, "+" .. Money(report.Bonus)))
	table.insert(list, row(5, "Hud/coin", "Deposited", Money(report.Deposited), Theme.Tone.Mustard))
	if report.Gems > 0 then
		const total = report.GemsTotal
		table.insert(
			list,
			row(6, "Hud/gem", "Gems", if total then `+{report.Gems} / {total}` else `+{report.Gems}`, Theme.Tone.Teal)
		)
	end
	if report.AfkLocked then
		table.insert(list, note(7, "No gems: away too long"))
	end
	if report.LastChanceUsed then
		table.insert(list, note(8, "Last chance used"))
	end
	return list
end

return function(props: Props): Frame
	-- Keeps the last report so the card can shrink away with its content after the owner sets false.
	const last = source(untrack(props.Report))
	effect(function()
		const report = props.Report()
		if report then
			last(report)
		end
	end)

	const scale = Motion.Pop(function()
		return props.Report() ~= false
	end)

	const grade = function(): Grade
		const report = last()
		return if report then report.Grade else "D"
	end

	return create("Frame")({
		Name = props.Name or "HudSummary",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = function()
			return last() ~= false and scale() > 0.02
		end,

		createRaw("UIScale")({ Scale = scale }),

		CartoonPanel({
			Name = "Card",
			Position = UDim2.fromOffset(0, 14),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Tone = Theme.Tone.Cream,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Lip = 6,
			Studs = true,
			Gloss = false,
			Padding = { Left = 18, Right = 18, Top = 40, Bottom = 12 },
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				-- Rows build components with their own effects: untrack gives them a scope of their own (Vide refuses
				-- a new reactive scope inside this reactive child).
				function(): { Instance }
					const report = last()
					return if report
						then untrack(function()
							return rows(report)
						end)
						else {}
				end,
			},
		}),

		-- Title tab over the top edge (ribbon look)
		CartoonPanel({
			Name = "Title",
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			Rotation = -2,
			Tone = Theme.Tone.Ink,
			Outline = Theme.Outline.Normal,
			Padding = { Left = 16, Right = 16 },
			ZIndex = 2,
			Children = {
				CartoonLabel({
					Box = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					TextSize = TITLE_SIZE,
					Text = function()
						const report = last()
						return if report then report.Title else ""
					end,
				}),
			},
		}),

		-- Grade sticker
		CartoonPanel({
			Name = "Grade",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 16, 0, -22),
			Size = UDim2.fromOffset(GRADE, GRADE),
			Rotation = 10,
			Tone = function()
				return GRADE_TONE[grade()]
			end,
			Outline = Theme.Outline.Thick,
			ZIndex = 3,
			Children = {
				CartoonLabel({
					Box = UDim2.fromScale(1, 1),
					TextSize = GRADE_SIZE,
					Text = grade,
					Stroke = 4,
				}),
			},
		}),
	})
end
