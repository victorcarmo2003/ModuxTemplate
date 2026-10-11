--!strict
-- CartoonLabel: the one text style of the cartoon UI kit (Theme): Fredoka One, white with a round Ink stroke whose
-- thickness follows the size (Theme.TextStroke), or Ink without stroke on light surfaces (`Color = Theme.Color.Dark`,
-- `Stroke = 0`). Sizes in px at UI scale 1, never under Theme.MinTextSize.
-- Default box: as wide as the text (AutomaticSize X), one line tall. `Box` sets a fixed box instead.
-- Pure: only props. Reactive props accept a value or a source.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UITextSizeConstraint are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Value<T> = T | () -> T

export type Props = {
	Text: Value<string>,
	-- px. Default 18.
	TextSize: number?,
	Color: Value<Color3>?,
	-- Stroke px; 0 = none. Default Theme.TextStroke(TextSize).
	Stroke: Value<number>?,
	StrokeColor: Value<Color3>?,
	Font: Font?,
	XAlignment: Enum.TextXAlignment?,
	YAlignment: Enum.TextYAlignment?,
	Wrapped: boolean?,
	RichText: boolean?,
	Truncate: boolean?,
	-- Text fits its box (world tags sized in studs); `MaxTextSize` caps it. Default false.
	Scaled: boolean?,
	MaxTextSize: number?,
	-- Text and stroke transparency (fades).
	Transparency: Value<number>?,
	-- Fixed box; nil = auto width, one line tall.
	Box: Value<UDim2>?,
	AutomaticSize: Enum.AutomaticSize?,
	Name: string?,
	LayoutOrder: Value<number>?,
	AnchorPoint: Vector2?,
	Position: Value<UDim2>?,
	Rotation: Value<number>?,
	Visible: Value<boolean>?,
	ZIndex: number?,
	Children: { any }?,
}

return function(props: Props): TextLabel
	const size = math.max(props.TextSize or 18, Theme.MinTextSize)
	const stroke: Value<number> = props.Stroke or Theme.TextStroke(size)
	const transparency: Value<number> = props.Transparency or 0
	const children: { any } = {
		createRaw("UIStroke")({
			Color = props.StrokeColor or Theme.Color.Ink,
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = stroke,
			Transparency = transparency,
			Enabled = function()
				return (if type(stroke) == "function" then stroke() else stroke) > 0
			end,
		}),
	}
	if props.Scaled and props.MaxTextSize then
		table.insert(children, createRaw("UITextSizeConstraint")({ MaxTextSize = props.MaxTextSize }))
	end
	if props.Children then
		table.insert(children, props.Children)
	end

	return create("TextLabel")({
		Name = props.Name or "Label",
		LayoutOrder = props.LayoutOrder or 0,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Box or UDim2.fromOffset(0, size + 6),
		AutomaticSize = props.AutomaticSize
			or (if props.Box then Enum.AutomaticSize.None else Enum.AutomaticSize.X),
		Rotation = props.Rotation or 0,
		Visible = if props.Visible == nil then true else props.Visible,
		ZIndex = props.ZIndex or 1,
		BackgroundTransparency = 1,
		FontFace = props.Font or Theme.Font.Title,
		TextSize = size,
		TextScaled = props.Scaled == true,
		TextColor3 = props.Color or Theme.Color.Text,
		TextTransparency = transparency,
		TextXAlignment = props.XAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.YAlignment or Enum.TextYAlignment.Center,
		TextWrapped = props.Wrapped == true,
		TextTruncate = if props.Truncate then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None,
		RichText = props.RichText == true,
		Text = props.Text,
		children,
	}) :: TextLabel
end
