--!strict
-- CartoonButton: the button of the cartoon UI kit (AST-091 "primário Mustard, secundário Cream, desabilitado Slate,
-- pressionado escala 0,95"): a transparent TextButton (the hit box, >= Theme.MinTouch) holding a CartoonPanel with an
-- optional icon (Icons name) and a CartoonLabel. Squashes on press, grows a little on hover (Motion.Press).
-- The press / hover scale is on the Body, anchored at the centre of the hit box, so the button always grows and shrinks
-- from its centre whatever its AnchorPoint (owner request 2026-10-15: buttons grew to the right). The hit box never
-- scales. Auto width (no `Size`, or AutomaticSize X): the Body sizes itself from its content and the hit box copies
-- that width (measured), since a parent AutomaticSize does not follow a centred child.
-- Disabled (`Enabled` false): Slate face, not Active, never fires. Gamepad: Selectable, SelectionGained forwarded.
-- `Children` replaces the default icon + label content (cards). The root keeps `Name`, so a controller can find it
-- and give it to GuiService.SelectedObject. Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Value<T> = T | () -> T

export type Props = {
	Text: Value<string>?,
	TextSize: number?,
	-- Icons name ("Ui/close", "Hud/gem"); "" or unknown = no icon.
	Icon: Value<string>?,
	IconSize: number?,
	-- Default Theme.Tone.Mustard (primary).
	Tone: Value<Theme.Tone>?,
	Enabled: Value<boolean>?,
	OnActivated: (() -> ())?,
	SelectionGained: (() -> ())?,
	Outline: Value<number>?,
	OutlineColor: Value<Color3>?,
	Radius: UDim?,
	Studs: boolean?,
	Children: { any }?,
	Padding: number?,
	Name: string?,
	LayoutOrder: Value<number>?,
	AnchorPoint: Vector2?,
	Position: Value<UDim2>?,
	-- Default 44 px tall, as wide as the content.
	Size: Value<UDim2>?,
	AutomaticSize: Enum.AutomaticSize?,
	Visible: Value<boolean>?,
	Selectable: boolean?,
}

-- Current value of a Value<T> (reads, so it tracks inside a reactive binding). One per type: a generic reader
-- would bind T to the whole `T | () -> T` union under the new solver.
local function call(value: any): any
	if type(value) == "function" then
		const getter = value :: () -> any
		return getter()
	end
	return value
end
local function readTone(value: Value<Theme.Tone>): Theme.Tone
	return call(value)
end
local function readBoolean(value: Value<boolean>): boolean
	return call(value)
end
local function readString(value: Value<string>): string
	return call(value)
end
local function readSize(value: Value<UDim2>): UDim2
	return call(value)
end

return function(props: Props): TextButton
	const pressed = source(false)
	const hovered = source(false)
	const enabled = function(): boolean
		return if props.Enabled == nil then true else readBoolean(props.Enabled)
	end
	const tone = function(): Theme.Tone
		if not enabled() then
			return Theme.Tone.Slate
		end
		return if props.Tone then readTone(props.Tone) else Theme.Tone.Mustard
	end
	const scale = Motion.Press(pressed, hovered)
	const textSize = math.max(props.TextSize or 17, Theme.MinTextSize)
	const iconSize = props.IconSize or math.floor(textSize * 1.6)
	const auto = props.AutomaticSize
		or (if props.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.X)
	const autoX = auto == Enum.AutomaticSize.X
	const baseSize = function(): UDim2
		return if props.Size then readSize(props.Size) else UDim2.fromOffset(0, Theme.MinTouch)
	end
	-- auto width: px (UI scale 1) of the Body, measured from its own automatic size
	const width = source(0)

	const iconName = function(): string
		return if props.Icon then readString(props.Icon) else ""
	end
	const hasIcon = function(): boolean
		return Icons.Has(iconName())
	end
	const rect = function(): Icons.Rect
		return Icons.Rect(iconName()) or { Offset = Vector2.zero, Size = Vector2.zero }
	end

	const content: { any } = props.Children
		or {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			create("ImageLabel")({
				Name = "Icon",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(iconSize, iconSize),
				BackgroundTransparency = 1,
				Image = function()
					return Icons.ImageOf(iconName())
				end,
				ImageRectOffset = function()
					return rect().Offset
				end,
				ImageRectSize = function()
					return rect().Size
				end,
				Visible = hasIcon,
			}),
			CartoonLabel({
				LayoutOrder = 2,
				Text = props.Text or "",
				TextSize = textSize,
				Color = function()
					return tone().Text
				end,
				Stroke = function()
					return if tone().Stroke then Theme.TextStroke(textSize) else 0
				end,
				Visible = function()
					return (if props.Text then readString(props.Text) else "") ~= ""
				end,
			}),
		}

	const body = CartoonPanel({
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(if autoX then 0 else 1, 1),
		AutomaticSize = if autoX then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		Tone = tone,
		Outline = props.Outline or Theme.Outline.Normal,
		OutlineColor = props.OutlineColor,
		Radius = props.Radius or Theme.Radius.Pill,
		Studs = props.Studs,
		Padding = if props.Children
			then (props.Padding or 0)
			else { Left = props.Padding or 14, Right = props.Padding or 14 },
		Decor = { createRaw("UIScale")({ Scale = scale }) },
		Children = content,
	})

	if autoX then
		-- local width = measured width x (local height / measured height): the press scale and any ancestor UIScale
		-- multiply both measures alike, so the ratio holds while the Body squashes
		const measure = function()
			const real = body.AbsoluteSize
			const height = Vide.untrack(baseSize).Y.Offset
			const localHeight = if height > 0 then height else Theme.MinTouch
			-- a Body squashed near 0 (pop-in / pop-out) gives a garbage ratio: keep the last width (CartoonPanel)
			if real.Y < localHeight * 0.25 then
				return
			end
			const px = real.X / real.Y * localHeight
			if math.abs(px - Vide.untrack(width)) > 0.5 then
				width(math.ceil(px))
			end
		end
		const connection = body:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		measure()
		cleanup(function()
			connection:Disconnect()
		end)
	end

	return create("TextButton")({
		Name = props.Name or "CartoonButton",
		LayoutOrder = props.LayoutOrder or 0,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = function()
			const size = baseSize()
			return if autoX then UDim2.new(0, width(), size.Y.Scale, size.Y.Offset) else size
		end,
		AutomaticSize = if autoX then Enum.AutomaticSize.None else auto,
		Visible = if props.Visible == nil then true else props.Visible,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = if props.Selectable == nil then true else props.Selectable,
		Active = enabled,
		Text = "",
		MouseEnter = function()
			hovered(true)
		end,
		MouseLeave = function()
			hovered(false)
			pressed(false)
		end,
		MouseButton1Down = function()
			if enabled() then
				pressed(true)
			end
		end,
		MouseButton1Up = function()
			pressed(false)
		end,
		Activated = function()
			if enabled() and props.OnActivated then
				props.OnActivated()
			end
		end,
		SelectionGained = function()
			if props.SelectionGained then
				props.SelectionGained()
			end
		end,

		body,
	}) :: TextButton
end
