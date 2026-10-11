--!strict
-- HudRunEnd: end of the run screen from the `RunReport` packet (FEAT-026, FEAT-027; architecture.md §19.16;
-- network.md §13.1; ui-text.md §14; style guide §7.4 "mesma linguagem do fim de turno, fundo do amanhecer").
--   Failed   "Shift's Over" · "Days worked: {Day}" · "Nights survived: {Night - 1}" · "Gems earned: {Gems}"
--            · quote "Walt: ..." (the lines of `call_run_over`, never rung)
--   Success  "You Kept the Light On" · "Nights survived: {Night}" · "Gems earned: {Gems}"
--   footer   "Starting over at Day 1..." (waves 2-3: ResetDev, no lobby yet)
-- Never mentions the boss chances (DEC-053). No button (waves 2-3; "Back to Lobby" comes with the lobby, wave 4).
-- The owner shows it by setting `Report` and hides it with false (15 s). Pure: only props.
-- Cartoon pass (AST-091): dawn gradient fades in behind a Cream card with studs that pops in (Motion.Pop); title
-- on a Mustard ribbon tab (trophy on success), rows with icons (calendar, lantern, gem).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const effect = Vide.effect
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale and UIGradient are not among them.
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
const TITLE_SIZE = 30
const ROW_SIZE = 20
const QUOTE_SIZE = 16
const FOOTER_SIZE = 16
const ICON = 30

-- Dawn behind the card (style guide §5.2/§7.4): night violet over a warm horizon.
const DAWN = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("#3B3A6B")),
	ColorSequenceKeypoint.new(0.55, Color3.fromHex("#E89A6A")),
	ColorSequenceKeypoint.new(1, Theme.Color.Mustard),
})

-- ui-text.md §14: {n} on Failed = Night - 1 (the lost night does not count); the client computes it.
local function survived(report: Report): number
	return if report.Result == "Success" then report.Night else math.max(report.Night - 1, 0)
end

local function line(order: number, iconName: string, text: string, size: number, color: Color3): Frame
	const rect = Icons.Rect(iconName)
	return create("Frame")({
		Name = `Row{order}`,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		create("ImageLabel")({
			Name = "Icon",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(ICON, ICON),
			BackgroundTransparency = 1,
			Image = Icons.ImageOf(iconName),
			ImageRectOffset = if rect then rect.Offset else Vector2.zero,
			ImageRectSize = if rect then rect.Size else Vector2.zero,
			Visible = rect ~= nil,
		}),
		CartoonLabel({
			LayoutOrder = 2,
			Box = if rect then UDim2.new(1, -(ICON + 8), 0, 0) else UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Wrapped = true,
			Text = text,
			TextSize = size,
			Color = color,
			Stroke = 0,
		}),
	})
end

local function rows(report: Report): { Instance }
	const list: { Instance } = {}
	const success = report.Result == "Success"
	if not success then
		table.insert(list, line(2, "Ui/calendar", `Days worked: {report.Day}`, ROW_SIZE, Theme.Color.Dark))
	end
	table.insert(list, line(3, "Ui/lantern", `Nights survived: {survived(report)}`, ROW_SIZE, Theme.Color.Dark))
	table.insert(list, line(4, "Hud/gem", `Gems earned: {report.Gems}`, ROW_SIZE + 2, Theme.Color.Teal))
	if not success and #report.Quote > 0 then
		const quote = `Walt: "{table.concat(report.Quote, " ")}"`
		table.insert(list, line(5, "", quote, QUOTE_SIZE, Theme.Color.Violet))
	end
	table.insert(list, line(6, "", "Starting over at Day 1...", FOOTER_SIZE, Theme.Color.Slate))
	return list
end

return function(props: Props): Frame
	-- Keeps the last report so the screen goes away with its content.
	const last = source(untrack(props.Report))
	effect(function()
		const report = props.Report()
		if report then
			last(report)
		end
	end)
	const shown = function(): boolean
		return props.Report() ~= false
	end
	const alpha = spring(function()
		return if shown() then 0.15 else 1
	end, 0.4, 1)
	const scale = Motion.Pop(shown)
	const success = function(): boolean
		const report = last()
		return report ~= false and report.Result == "Success"
	end

	return create("Frame")({
		Name = props.Name or "HudRunEnd",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = alpha,
		Active = false,
		Visible = function()
			return last() ~= false and (shown() or alpha() < 0.99)
		end,
		createRaw("UIGradient")({ Color = DAWN, Rotation = 90 }),

		create("Frame")({
			Name = "Holder",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = function()
				return scale() > 0.02
			end,
			createRaw("UIScale")({ Scale = scale }),

			CartoonPanel({
				Name = "Card",
				Position = UDim2.fromOffset(0, 20),
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Tone = Theme.Tone.Cream,
				Outline = Theme.Outline.Thick,
				Radius = Theme.Radius.Card,
				Lip = 6,
				Studs = true,
				Gloss = false,
				Padding = { Left = 18, Right = 18, Top = 40, Bottom = 16 },
				Children = {
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
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

			-- Title on a ribbon tab over the top edge
			CartoonPanel({
				Name = "Title",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromOffset(0, 48),
				AutomaticSize = Enum.AutomaticSize.X,
				Rotation = -2,
				Tone = function()
					return if success() then Theme.Tone.Mustard else Theme.Tone.Violet
				end,
				Outline = Theme.Outline.Thick,
				Padding = { Left = 14, Right = 18 },
				ZIndex = 2,
				Children = {
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					create("ImageLabel")({
						Name = "Trophy",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(40, 40),
						BackgroundTransparency = 1,
						Image = Icons.ImageOf("Ui/trophy"),
						ImageRectOffset = (Icons.Rect("Ui/trophy") or { Offset = Vector2.zero }).Offset,
						ImageRectSize = (Icons.Rect("Ui/trophy") or { Size = Vector2.zero }).Size,
						Visible = function()
							return success() and Icons.Has("Ui/trophy")
						end,
					}),
					CartoonLabel({
						LayoutOrder = 2,
						TextSize = TITLE_SIZE,
						Text = function()
							return if success() then "You Kept the Light On" else "Shift's Over"
						end,
						Color = function()
							return if success() then Theme.Color.Dark else Theme.Color.Text
						end,
						Stroke = function()
							return if success() then 0 else 3
						end,
					}),
				},
			}),
		}),
	})
end
