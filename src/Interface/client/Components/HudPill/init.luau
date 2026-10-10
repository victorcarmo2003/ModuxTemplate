--!strict
-- HudPill: one status pill of the HUD (style guide §7.1/§7.2): Ink at 70%, radius 50%, white text with Ink outline,
-- optional drawn icon on the left (coin, sun, moon) until the icon sheet (AST-071) exists.
-- Status only (DEC-015, FEAT-032): Frames and TextLabels, nothing clickable.
-- `Bump`: when that number goes up the pill bumps (scale 1.15 for 0.2 s, style guide §7.2 "ao ganhar, número pula").
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Icon = "None" | "Coin" | "Sun" | "Moon"

export type Props = {
	Text: () -> string,
	Icon: (() -> Icon)?,
	-- Pixel height of the pill (>= Theme.MinTouch). Default 44.
	Height: number?,
	-- Pixel text size (>= Theme.MinTextSize). Default 22.
	TextSize: number?,
	-- Minimum pill width, so a short text ("Day 1") does not make a tiny pill.
	MinWidth: number?,
	Bump: (() -> number)?,
	Name: string?,
	LayoutOrder: number?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
}

const BUMP_SCALE = 1.15
const BUMP_TIME = 0.2

local function icon(kind: () -> Icon, size: number): Frame
	return create("Frame")({
		Name = "Icon",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(size, size),
		Visible = function()
			return kind() ~= "None"
		end,
		BackgroundColor3 = function()
			return if kind() == "Moon" then Theme.Color.Cream else Theme.Color.Mustard
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({
			Color = function()
				return if kind() == "Moon" then Theme.Color.Violet else Theme.Color.Ink
			end,
			Thickness = Theme.Stroke,
		}),
		create("TextLabel")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextSize = math.max(Theme.MinTextSize, math.floor(size * 0.65)),
			TextColor3 = Theme.Color.Ink,
			Text = function()
				return if kind() == "Coin" then "$" else ""
			end,
		}),
	})
end

return function(props: Props): Frame
	const height = math.max(props.Height or Theme.MinTouch, Theme.MinTouch)
	const textSize = math.max(props.TextSize or 22, Theme.MinTextSize)
	const iconKind: () -> Icon = props.Icon or function(): Icon
		return "None"
	end

	const bumped = source(false)
	const bumpOn = props.Bump
	if bumpOn then
		local last = untrack(bumpOn)
		local thread: thread? = nil
		effect(function()
			const value = bumpOn()
			if value > last then
				if thread and coroutine.status(thread) == "suspended" then
					task.cancel(thread)
				end
				bumped(true)
				thread = task.delay(BUMP_TIME, function()
					thread = nil
					bumped(false)
				end)
			end
			last = value
		end)
		cleanup(function()
			if thread and coroutine.status(thread) == "suspended" then
				task.cancel(thread)
			end
		end)
	end

	const scale = spring(function()
		return if bumped() then BUMP_SCALE else 1
	end, 0.1, 0.6)

	return create("Frame")({
		Name = props.Name or "HudPill",
		LayoutOrder = props.LayoutOrder or 0,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = Theme.Transparency.Panel,

		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIScale")({ Scale = scale }),
		createRaw("UISizeConstraint")({ MinSize = Vector2.new(props.MinWidth or height, height) }),
		createRaw("UIPadding")({
			PaddingLeft = function()
				return UDim.new(0, math.floor(height * (if iconKind() == "None" then 0.36 else 0.22)))
			end,
			PaddingRight = UDim.new(0, math.floor(height * 0.36)),
		}),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),

		icon(iconKind, math.floor(height * 0.62)),

		create("TextLabel")({
			Name = "Label",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, height),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextSize = textSize,
			TextColor3 = Theme.Color.Text,
			Text = props.Text,
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
		}),
	})
end
