--!strict
-- HudPill: one status pill of the HUD (style guide §7.1/§7.2; AST-091 "Pílula de HUD"), cartoon pass: an Ink
-- CartoonPanel (gradient, lip, thick outline) with a big icon of the AST-071/AST-091 sheets on the left (coin, sun,
-- moon, clock) and a CartoonLabel. A drawn coin/sun/moon stays as the fallback while a sheet is missing.
-- Status only (DEC-015, FEAT-032): Frames and labels, nothing clickable.
-- `Bump`: when that number goes up the pill jumps and settles (Motion.Bump; style guide §7.2 "ao ganhar, número pula").
-- `Shown`: progressive reveal (Motion.Pop), e.g. the money pill appears with the first sale of the tutorial.
-- Stays Ink on purpose (style guide §7.1): a status pill floats over a sunny, busy street; Ink with white text and an
-- Ink stroke keeps the highest contrast on any background, while reading surfaces (prompts, subtitles, tutorial)
-- went Cream (user request 2026-10-11).
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIScale and UISizeConstraint are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Icon = "None" | "Coin" | "Sun" | "Moon" | "Clock"

export type Props = {
	Text: () -> string,
	Icon: (() -> Icon)?,
	-- Pixel height of the pill (>= Theme.MinChip: status only, never touched). Default 36.
	Height: number?,
	-- Pixel text size (>= Theme.MinTextSize). Default 18.
	TextSize: number?,
	-- Minimum pill width, so a short text ("Day 1") does not make a tiny pill.
	MinWidth: number?,
	Bump: (() -> number)?,
	-- Pops in when it turns true and shrinks away when false (progressive HUD reveal of the tutorial). nil = shown.
	Shown: (() -> boolean)?,
	Name: string?,
	LayoutOrder: number?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
}

const SHEET: { [Icon]: string } = {
	None = "",
	Coin = "Hud/coin",
	Sun = "Hud/sun",
	Moon = "Hud/moon",
	Clock = "Ui/clock",
}

-- Drawn fallback (coin "$", sun, moon) while the sheet is missing.
local function drawn(kind: () -> Icon, size: number, hasArt: () -> boolean): Frame
	return create("Frame")({
		Name = "Drawn",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		Visible = function()
			return not hasArt() and kind() ~= "None" and kind() ~= "Clock"
		end,
		BackgroundColor3 = function()
			return if kind() == "Moon" then Theme.Color.Cream else Theme.Color.Mustard
		end,
		create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Outline.Normal }),
		CartoonLabel({
			Box = UDim2.fromScale(1, 1),
			Text = function()
				return if kind() == "Coin" then "$" else ""
			end,
			TextSize = math.max(Theme.MinTextSize, math.floor(size * 0.55)),
			Color = Theme.Color.Dark,
			Stroke = 0,
		}),
	})
end

return function(props: Props): Frame
	const height = math.max(props.Height or 36, Theme.MinChip)
	const textSize = math.max(props.TextSize or 18, Theme.MinTextSize)
	const iconKind: () -> Icon = props.Icon or function(): Icon
		return "None"
	end
	const iconSize = height - 2
	const name = function(): string
		return SHEET[iconKind()]
	end
	const hasArt = function(): boolean
		return Icons.Has(name())
	end
	const hasIcon = function(): boolean
		const kind = iconKind()
		return hasArt() or (kind ~= "None" and kind ~= "Clock")
	end
	const rect = function(): Icons.Rect
		return Icons.Rect(name()) or { Offset = Vector2.zero, Size = Vector2.zero }
	end

	const bumpOn = props.Bump
	const bump = if bumpOn then Motion.Bump(bumpOn) else function(): number
		return 1
	end
	const shownOn = props.Shown
	const pop = if shownOn then Motion.Pop(shownOn) else function(): number
		return 1
	end
	const scale = function(): number
		return bump() * pop()
	end

	return CartoonPanel({
		Name = props.Name or "HudPill",
		LayoutOrder = props.LayoutOrder or 0,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		Tone = Theme.Tone.Ink,
		Transparency = Theme.Transparency.Panel,
		Outline = Theme.Outline.Normal,
		-- out of the layout once it has shrunk away (the pills under it move up)
		Visible = function()
			return pop() > 0.02
		end,
		Decor = {
			createRaw("UIScale")({ Scale = scale }),
			createRaw("UISizeConstraint")({ MinSize = Vector2.new(props.MinWidth or height, height) }),
		},
		Children = {
			createRaw("UIPadding")({
				PaddingLeft = function()
					return UDim.new(0, if hasIcon() then 0 else math.floor(height * 0.36))
				end,
				PaddingRight = UDim.new(0, math.floor(height * 0.36)),
			}),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),

			-- Big icon, a little over the pill edge (toy badge look).
			create("Frame")({
				Name = "Icon",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(iconSize, iconSize),
				BackgroundTransparency = 1,
				Visible = hasIcon,
				create("ImageLabel")({
					Name = "Art",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.42, 0.5),
					Size = UDim2.fromScale(1.18, 1.18),
					BackgroundTransparency = 1,
					Image = function()
						return Icons.ImageOf(name())
					end,
					ImageRectOffset = function()
						return rect().Offset
					end,
					ImageRectSize = function()
						return rect().Size
					end,
					Visible = hasArt,
				}),
				drawn(iconKind, iconSize, hasArt),
			}),

			CartoonLabel({
				Name = "Label",
				LayoutOrder = 2,
				Text = props.Text,
				TextSize = textSize,
			}),
		},
	})
end
