--!strict
-- CallSubtitle: the boss call subtitle (style guide §7.2 "Legenda de ligação": bottom strip above the hotbar, phone
-- icon of the vehicle + "Walt:" + one line; no portrait, DEC-076; no replay button, DEC-077; ui-text.md §12.4).
-- One line at a time (lines are <= 42 characters, ui-text.md §11); a longer line wraps to a 2nd row instead of
-- shrinking, so the text never goes under Theme.MinTextSize. Narrow on purpose (60% of the width, 300..560 px) so it
-- stays clear of the thumbstick and the jump button on a phone.
-- Cartoon pass (AST-091): round phone badge (CartoonPanel in the phone colour) with the AST-071 `Hud/phone` icon
-- (drawn handset while missing); pops and slides up (Motion.Pop + spring).
-- Light pass (user request 2026-10-11: the Ink strip read dark with low-contrast text): Cream strip with a thick Ink
-- outline, Ink line text without stroke, speaker name in SPEAKER_COLOR (dark Ketchup, high contrast on Cream).
-- Pure: only props. The owner (BossController) decides the speaker, the line and when it shows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const spring = Vide.spring
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding, UIScale, UIListLayout and UISizeConstraint
-- are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Phone = "cart" | "trailer"

export type Props = {
	Visible: () -> boolean,
	-- "Walt" (BossCalls Line.Speaker nil)
	Speaker: () -> string,
	Text: () -> string,
	-- Vehicle key: the badge takes the colour of that phone (AST-042: red on the cart, cream in the trailer)
	Phone: (() -> string)?,
	-- UI scale of the owner (1 on the smallest phone)
	Scale: (() -> number)?,
	-- rbxassetid of a phone icon; "" or nil = the drawn placeholder handset
	Icon: string?,
	Name: string?,
}

const TEXT_SIZE = 18 -- >= Theme.MinTextSize on the smallest phone
const WIDTH_SCALE = 0.6
const MIN_WIDTH = 300
const MAX_WIDTH = 560
const BADGE = Theme.MinTouch -- 44 px round badge
-- Clear of the native hotbar (DEC-040) on the bottom centre
const BOTTOM_GAP = 84
const SLIDE = 24
-- Speaker name on the Cream strip: the Ketchup lip (dark red-orange), contrast > 5:1 on Cream
const SPEAKER_COLOR = Theme.Tone.Ketchup.Lip

-- AST-042 colours (style guide §2.1): Ketchup phone on the cart, Cream phone in the trailer
const PHONE_TONE: { [string]: Theme.Tone } = {
	cart = Theme.Tone.Ketchup,
	trailer = Theme.Tone.Cream,
}
const HANDSET_COLOR: { [string]: Color3 } = {
	cart = Theme.Color.Cream,
	trailer = Theme.Color.Ink,
}

local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function hex(color: Color3): string
	return "#" .. color:ToHex()
end

-- Placeholder handset: a rounded bar with an ear cup and a mouth cup, tilted
local function handset(color: () -> Color3): Frame
	local function cup(x: number): Frame
		return create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromOffset(10, 12),
			BackgroundColor3 = color,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		})
	end
	return create("Frame")({
		Name = "Handset",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 6),
		Rotation = -35,
		BackgroundColor3 = color,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		cup(0.08),
		cup(0.92),
	})
end

return function(props: Props): Frame
	const scale = Motion.Pop(props.Visible)
	const offset = spring(function()
		return if props.Visible() then 0 else SLIDE
	end, 0.22, 0.8)

	local function phone(): string
		return if props.Phone then props.Phone() else "cart"
	end

	const hasIcon = props.Icon ~= nil and props.Icon ~= ""
	const sheet = Icons.Rect("Hud/phone")

	return create("Frame")({
		Name = props.Name or "CallSubtitle",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_GAP),
		Size = UDim2.fromScale(WIDTH_SCALE, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = function()
			-- keep it in the tree while it shrinks away
			return props.Visible() or scale() > 0.02
		end,

		createRaw("UISizeConstraint")({ MinSize = Vector2.new(MIN_WIDTH, 0), MaxSize = Vector2.new(MAX_WIDTH, 10000) }),
		createRaw("UIScale")({
			Scale = function()
				return (if props.Scale then props.Scale() else 1) * scale()
			end,
		}),

		CartoonPanel({
			Name = "Strip",
			Position = function()
				return UDim2.fromOffset(0, offset())
			end,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Tone = Theme.Tone.Cream,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Decor = {
				createRaw("UISizeConstraint")({ MinSize = Vector2.new(0, BADGE + 12 + Theme.Lip) }),
			},
			Padding = { Left = 8, Right = 16, Top = 6, Bottom = 6 },
			Children = {
				createRaw("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
				}),

				-- Phone badge
				CartoonPanel({
					Name = "Phone",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(BADGE, BADGE),
					Tone = function()
						return PHONE_TONE[phone()] or PHONE_TONE.cart
					end,
					Outline = Theme.Outline.Normal,
					Lip = 3,
					Children = {
						if hasIcon
							then create("ImageLabel")({
								Name = "Icon",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.8, 0.8),
								BackgroundTransparency = 1,
								Image = props.Icon,
							})
							elseif sheet then create("ImageLabel")({
								Name = "Icon",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.95, 0.95),
								BackgroundTransparency = 1,
								Image = Icons.ImageOf("Hud/phone"),
								ImageRectOffset = sheet.Offset,
								ImageRectSize = sheet.Size,
							})
							else handset(function()
								return HANDSET_COLOR[phone()] or HANDSET_COLOR.cart
							end),
					},
				}),

				-- "Walt: line"
				CartoonLabel({
					Name = "Line",
					LayoutOrder = 2,
					Box = UDim2.new(1, -(BADGE + 10), 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					TextSize = TEXT_SIZE,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Wrapped = true,
					RichText = true,
					XAlignment = Enum.TextXAlignment.Left,
					Text = function()
						return `<font color="{hex(SPEAKER_COLOR)}">{escape(props.Speaker())}:</font> {escape(props.Text())}`
					end,
					Children = {
						createRaw("UIPadding")({
							PaddingTop = UDim.new(0, 6),
							PaddingBottom = UDim.new(0, 6),
						}),
					},
				}),
			},
		}),
	})
end
