--!strict
-- SkinRow: the row of round skin buttons under the class card (owner request 2026-10-17, design/skins-proposal.md).
-- First circle = the crew uniform (""), then the skins of the focused class. A click only previews (OnFocus): buying and
-- equipping are the card buttons. The focused circle is Mustard and bigger outline; a check marks the one worn; a skin
-- not owned is shaded (dark, translucent) with a lock in the middle, and still previews on click (owner 2026-10-21);
-- a "LIMITED" tag sits on a limited skin. The art is the skin icon when uploaded (Image), else the two Swatch colours
-- split diagonally. `Vertical` stacks the circles in a column (the bubbles beside the class card).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonButton = require(script.Parent.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)
local CartoonPanel = require(script.Parent.Parent.CartoonPanel)
local Icon = require(script.Parent.Parent.LobbyWindow.Icon)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIGradient are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type SkinEntry = {
	Key: string, -- Content.Skins key; "" = the crew uniform
	Name: string,
	Text: string, -- line of the card while it is previewed
	Swatch: { Color3 },
	Image: string, -- rbxassetid of the icon; "" = swatch
	Limited: boolean,
}

-- Equipped: worn with the class · Owned · Locked: for sale, not owned · Soon: no product yet · NeedsClass: owned, the
-- class is not
export type SkinState = "Equipped" | "Owned" | "Locked" | "Soon" | "NeedsClass"

export type Props = {
	Entries: () -> { SkinEntry },
	Focus: () -> string,
	StateOf: (key: string) -> SkinState,
	OnFocus: (key: string) -> (),
	Size: number, -- circle px at scale 1
	Gap: number,
	Vertical: boolean?, -- column instead of a row
}

const SHADE = 0.4 -- transparency of the dark veil over a skin not owned (0 = opaque)

return function(props: Props): Frame
	local function circle(entry: () -> SkinEntry, index: number)
		const focused = function(): boolean
			return props.Focus() == entry().Key
		end
		const state = function(): SkinState
			return props.StateOf(entry().Key)
		end
		const locked = function(): boolean
			const s = state()
			return s == "Locked" or s == "NeedsClass" or s == "Soon"
		end
		return CartoonButton({
			Name = "Skin",
			LayoutOrder = index,
			Size = UDim2.fromOffset(props.Size, props.Size),
			Radius = Theme.Radius.Pill,
			Tone = function()
				return if focused() then Theme.Tone.Mustard else Theme.Tone.White
			end,
			Outline = function()
				return if focused() then Theme.Outline.Thick else Theme.Outline.Normal
			end,
			Padding = 4,
			OnActivated = function()
				props.OnFocus(entry().Key)
			end,
			Children = {
				-- art: icon or the two swatch colours
				create("Frame")({
					Name = "Art",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = function()
						return entry().Swatch[1] or Theme.Color.Cream
					end,
					create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
					createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2 }),
					createRaw("UIGradient")({
						Rotation = 45,
						Color = function()
							const swatch = entry().Swatch
							const a = swatch[1] or Theme.Color.Cream
							const b = swatch[2] or a
							return ColorSequence.new({
								ColorSequenceKeypoint.new(0, a),
								ColorSequenceKeypoint.new(0.5, a),
								ColorSequenceKeypoint.new(0.501, b),
								ColorSequenceKeypoint.new(1, b),
							})
						end,
						Enabled = function()
							return entry().Image == ""
						end,
					}),
					create("ImageLabel")({
						Name = "Image",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = function()
							return entry().Image
						end,
						Visible = function()
							return entry().Image ~= ""
						end,
						create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
					}),
				}),
				-- not owned: dark translucent veil over the art, lock in the middle
				create("Frame")({
					Name = "Veil",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.Color.Ink,
					BackgroundTransparency = SHADE,
					ZIndex = 2,
					Visible = locked,
					create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
					create("Frame")({
						Name = "Lock",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.5, 0.5),
						BackgroundTransparency = 1,
						Icon("Notice/lock", math.floor(props.Size * 0.5), 1),
					}),
				}),
				-- status: check (worn)
				create("Frame")({
					Name = "Status",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, 6, 1, 6),
					Size = UDim2.fromOffset(20, 20),
					BackgroundTransparency = 1,
					ZIndex = 3,
					Icon(function()
						const s = state()
						return if s == "Equipped" then "Ui/check" else ""
					end, 20, 1),
				}),
				-- LIMITED tag across the bottom of a limited skin
				CartoonPanel({
					Name = "Limited",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, -12),
					Size = UDim2.fromOffset(props.Size + 8, 15),
					Tone = Theme.Tone.Violet,
					Radius = Theme.Radius.Pill,
					Outline = 2,
					Lip = 1,
					Gloss = false,
					Visible = function()
						return entry().Limited
					end,
					Children = {
						CartoonLabel({
							Box = UDim2.fromScale(1, 1),
							TextSize = 11,
							Scaled = true,
							MaxTextSize = 11,
							Color = Theme.Color.Gold,
							Text = "LIMITED",
						}),
					},
				}),
			},
		})
	end

	const vertical = props.Vertical == true
	return create("Frame")({
		Name = "SkinRow",
		Size = if vertical then UDim2.fromScale(1, 1) else UDim2.new(1, 0, 0, props.Size + 14),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = if vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = if vertical then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, props.Gap),
		}),
		Vide.indexes(props.Entries, circle),
	}) :: Frame
end
