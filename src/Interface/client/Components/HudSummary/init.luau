--!strict
-- HudSummary: end-of-shift card (FEAT-014; style guide §7.4 "Fim de turno"): centred card, huge grade letter
-- (A Mustard, B Green, C Teal, D Slate; never red), money lines, gems of the shift when there are any.
-- Status only (DEC-015, FEAT-032): no close button. The owner shows it by setting `Report` and hides it by setting
-- false (HudController does it after 15 s day / 20 s night); the card fades out with the last report on it.
-- No reputation, no boss chances, no XP (DEC-051, DEC-053, DEC-081). Texts are placeholders until ui-text.md.
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Money = require(script.Parent.HudPill.Money)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const effect = Vide.effect
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UISizeConstraint are not among them.
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

const WIDTH = 320
const ROW_HEIGHT = 26
const TEXT_SIZE = 18
const TITLE_SIZE = 28
const GRADE_SIZE = 64

const GRADE_COLOR: { [Grade]: Color3 } = {
	A = Theme.Color.Mustard,
	B = Theme.Color.Green,
	C = Theme.Color.Teal,
	D = Theme.Color.Slate,
}

local function label(name: string, text: string, x: number, align: Enum.TextXAlignment, color: Color3?): TextLabel
	return create("TextLabel")({
		Name = name,
		Position = UDim2.fromScale(x, 0),
		Size = UDim2.new(0.5, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Body,
		TextSize = TEXT_SIZE,
		TextColor3 = color or Theme.Color.Text,
		TextXAlignment = align,
		Text = text,
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
	})
end

local function row(order: number, left: string, right: string, color: Color3?): Frame
	return create("Frame")({
		Name = "Row",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		label("Label", left, 0, Enum.TextXAlignment.Left),
		label("Value", right, 0.5, Enum.TextXAlignment.Right, color),
	})
end

local function note(order: number, text: string): TextLabel
	return create("TextLabel")({
		Name = "Note",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Body,
		TextSize = TEXT_SIZE,
		TextColor3 = Theme.Color.Cream,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
	})
end

-- FEAT-014 lines, in order. "Stolen" only when something was stolen; gems only when the shift credited any.
local function rows(report: Report): { Instance }
	const list: { Instance } = {}
	table.insert(list, row(1, "Customers", `{report.Completed} / {report.Arrived}`))
	table.insert(list, row(2, "Drawer", Money(report.Drawer)))
	if report.Stolen > 0 then
		table.insert(list, row(3, "Stolen", Money(-report.Stolen), Theme.Color.Cream))
	end
	table.insert(list, row(4, `Grade {report.Grade} bonus`, "+" .. Money(report.Bonus)))
	table.insert(list, row(5, "Deposited", Money(report.Deposited), Theme.Color.Mustard))
	if report.Gems > 0 then
		const total = report.GemsTotal
		table.insert(list, row(6, "Gems", if total then `+{report.Gems} / {total}` else `+{report.Gems}`))
	end
	if report.AfkLocked then
		table.insert(list, note(7, "No gems: away too long"))
	end
	if report.LastChanceUsed then
		table.insert(list, note(8, "Last chance used"))
	end
	return list
end

return function(props: Props): CanvasGroup
	-- Keeps the last report so the card can fade out with its content after the owner sets false.
	const last = source(untrack(props.Report))
	effect(function()
		const report = props.Report()
		if report then
			last(report)
		end
	end)

	const alpha = spring(function()
		return if props.Report() then 0 else 1
	end, 0.2, 1)

	return create("CanvasGroup")({
		Name = props.Name or "HudSummary",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = Theme.Transparency.Panel,
		GroupTransparency = alpha,
		Visible = function()
			return last() ~= false and (props.Report() ~= false or alpha() < 0.99)
		end,

		create("UICorner")({ CornerRadius = UDim.new(0, 18) }),
		createRaw("UIPadding")({
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 16),
		}),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),

		create("Frame")({
			Name = "Header",
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, GRADE_SIZE + 4),
			BackgroundTransparency = 1,

			create("TextLabel")({
				Name = "Title",
				Size = UDim2.new(1, -GRADE_SIZE, 1, 0),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				TextSize = TITLE_SIZE,
				TextColor3 = Theme.Color.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = function()
					const report = last()
					return if report then report.Title else ""
				end,
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
			}),

			create("TextLabel")({
				Name = "Grade",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(GRADE_SIZE, GRADE_SIZE),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				TextSize = GRADE_SIZE,
				TextColor3 = function()
					const report = last()
					return if report then GRADE_COLOR[report.Grade] else Theme.Color.Text
				end,
				Text = function()
					const report = last()
					return if report then report.Grade else ""
				end,
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3 }),
			}),
		}),

		function(): { Instance }
			const report = last()
			return if report then rows(report) else {}
		end,
	})
end
