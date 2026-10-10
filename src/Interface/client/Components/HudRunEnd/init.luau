--!strict
-- HudRunEnd: end of the run screen from the `RunReport` packet (FEAT-026, FEAT-027; architecture.md §19.16;
-- network.md §13.1; ui-text.md §14; style guide §7.4 "mesma linguagem do fim de turno, fundo do amanhecer").
--   Failed   "Shift's Over" · "Days worked: {Day}" · "Nights survived: {Night - 1}" · "Gems earned: {Gems}"
--            · quote "Walt: ..." (the lines of `call_run_over`, never rung)
--   Success  "You Kept the Light On" · "Nights survived: {Night}" · "Gems earned: {Gems}"
--   footer   "Starting over at Day 1..." (waves 2-3: ResetDev, no lobby yet)
-- Never mentions the boss chances (DEC-053). No button (waves 2-3; "Back to Lobby" comes with the lobby, wave 4).
-- The owner shows it by setting `Report` and hides it with false (15 s). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const effect = Vide.effect
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UIGradient are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Result = "Success" | "Failed"

export type Report = {
	Result: Result,
	Day: number,
	Night: number, -- Failed: the night that was lost; Success: 10
	Gems: number, -- gems of this run for this player (RunRewards)
	Quote: { string }, -- Failed only: lines quoted as "Walt: ..."
}

-- false = hidden (a Source of an optional type is ambiguous to call under the new solver)
export type Shown = Report | false

export type Props = {
	Report: () -> Shown,
	Name: string?,
}

const WIDTH = 340
const TITLE_SIZE = 32
const ROW_SIZE = 20
const QUOTE_SIZE = 16
const FOOTER_SIZE = 16

-- Dawn behind the card (style guide §5.2/§7.4): cream sky over a warm horizon, soft enough to read white text on Ink.
const DAWN = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("#3B3A6B")),
	ColorSequenceKeypoint.new(0.55, Color3.fromHex("#E89A6A")),
	ColorSequenceKeypoint.new(1, Theme.Color.Mustard),
})

-- ui-text.md §14: {n} on Failed = Night - 1 (the lost night does not count); the client computes it.
local function survived(report: Report): number
	return if report.Result == "Success" then report.Night else math.max(report.Night - 1, 0)
end

local function label(order: number, text: string, size: number, font: Font, color: Color3): TextLabel
	return create("TextLabel")({
		Name = `Row{order}`,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = font,
		TextSize = size,
		TextColor3 = color,
		TextWrapped = true,
		Text = text,
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
	})
end

local function rows(report: Report): { Instance }
	const list: { Instance } = {}
	const success = report.Result == "Success"
	table.insert(
		list,
		label(1, if success then "You Kept the Light On" else "Shift's Over", TITLE_SIZE, Theme.Font.Title, Theme.Color.Text)
	)
	if not success then
		table.insert(list, label(2, `Days worked: {report.Day}`, ROW_SIZE, Theme.Font.Body, Theme.Color.Text))
	end
	table.insert(list, label(3, `Nights survived: {survived(report)}`, ROW_SIZE, Theme.Font.Body, Theme.Color.Text))
	table.insert(list, label(4, `Gems earned: {report.Gems}`, ROW_SIZE, Theme.Font.Body, Theme.Color.Mustard))
	if not success and #report.Quote > 0 then
		const quote = `Walt: "{table.concat(report.Quote, " ")}"`
		table.insert(list, label(5, quote, QUOTE_SIZE, Theme.Font.Body, Theme.Color.Cream))
	end
	table.insert(list, label(6, "Starting over at Day 1...", FOOTER_SIZE, Theme.Font.Body, Theme.Color.Cream))
	return list
end

return function(props: Props): CanvasGroup
	-- Keeps the last report so the screen fades out with its content.
	const last = source(untrack(props.Report))
	effect(function()
		const report = props.Report()
		if report then
			last(report)
		end
	end)
	const alpha = spring(function()
		return if props.Report() then 0 else 1
	end, 0.4, 1)

	return create("CanvasGroup")({
		Name = props.Name or "HudRunEnd",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
		GroupTransparency = alpha,
		Visible = function()
			return last() ~= false and (props.Report() ~= false or alpha() < 0.99)
		end,
		createRaw("UIGradient")({ Color = DAWN, Rotation = 90 }),

		create("Frame")({
			Name = "Card",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = Theme.Transparency.Panel,
			create("UICorner")({ CornerRadius = UDim.new(0, 18) }),
			createRaw("UIPadding")({
				PaddingLeft = UDim.new(0, 18),
				PaddingRight = UDim.new(0, 18),
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 14),
			}),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),

			function(): { Instance }
				const report = last()
				return if report then rows(report) else {}
			end,
		}),
	})
end
