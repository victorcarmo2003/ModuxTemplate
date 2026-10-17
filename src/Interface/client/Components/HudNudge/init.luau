--!strict
-- HudNudge: a quick clickable note at the right edge of the HUD (TASK-290; owner request 2026-10-14, Provisional), e.g.
-- "Press B to scare your friends" or the receipt of a shop utility ("+$100 for the crew!"). A Mustard CartoonButton
-- that pops in while `Text` is not "" and pops out when it turns "" (Motion.Pop). Clicking or tapping it calls
-- OnActivated (the owner opens the shop). The owner decides when it shows, for how long and the words per device.
-- `{pad}` in the text is replaced by the controller button image `Pad` (UserInputService:GetImageForKeyCode); with no
-- image it reads `PadText`. Height: Theme.MinTouch on touch (`Touch`), smaller otherwise.
-- Icon (TASK-363, contextual offers): an Icons name shown left of the text ("" = none), e.g. the product of an offer.
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Icons = require(script.Parent.Icons)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Text: () -> string, -- "" = hidden; may hold "{pad}"
	OnActivated: () -> (),
	-- Controller button image for "{pad}" ("" = use PadText)
	Pad: (() -> string)?,
	PadText: string?,
	-- Touch screen: a full touch-size target
	Touch: (() -> boolean)?,
	-- Icons name left of the text ("" or nil = none)
	Icon: (() -> string)?,
	AnchorPoint: Vector2?,
	Position: (UDim2 | () -> UDim2)?,
	Name: string?,
}

const HEIGHT = 36
const TOKEN = "{pad}"
const PAD_ICON = 24
const ICON = 26

return function(props: Props): Frame
	-- the last text stays on the button while it pops out
	const shownText = source("")
	effect(function()
		const text = props.Text()
		if text ~= "" then
			untrack(function()
				shownText(text)
				return nil
			end)
		end
	end)
	const shown = function(): boolean
		return props.Text() ~= ""
	end
	const pop = Motion.Pop(shown)
	const height = function(): number
		return if props.Touch and props.Touch() then Theme.MinTouch else HEIGHT
	end
	-- the icon follows the text: kept while the note pops out
	const shownIcon = source("")
	effect(function()
		const text = props.Text()
		const icon = if props.Icon then props.Icon() else ""
		if text ~= "" then
			untrack(function()
				shownIcon(icon)
				return nil
			end)
		end
	end)
	const iconRect = function(): Icons.Rect
		return Icons.Rect(shownIcon()) or { Offset = Vector2.zero, Size = Vector2.zero }
	end
	const padImage = function(): string
		return if props.Pad then props.Pad() else ""
	end
	-- text before and after the pad slot; no slot = all in `before`
	const parts = function(): (string, string, boolean)
		const text = shownText()
		const at = string.find(text, TOKEN, 1, true)
		if at == nil then
			return text, "", false
		end
		const before = string.sub(text, 1, at - 1)
		const after = string.sub(text, at + #TOKEN)
		if padImage() == "" then
			return before .. (props.PadText or "") .. after, "", false
		end
		return before, after, true
	end
	const label = function(name: string, order: number, read: () -> string): TextLabel
		return CartoonLabel({
			Name = name,
			LayoutOrder = order,
			TextSize = 16,
			Color = Theme.Tone.Mustard.Text,
			Stroke = 0,
			Text = read,
			Visible = function()
				return read() ~= ""
			end,
		})
	end

	return create("Frame")({
		Name = props.Name or "HudNudge",
		AnchorPoint = props.AnchorPoint or Vector2.new(1, 0),
		Position = props.Position or UDim2.new(1, -10, 0, 120),
		Size = function()
			return UDim2.fromOffset(0, height())
		end,
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Visible = function()
			return pop() > 0.01
		end,

		createRaw("UIScale")({ Scale = pop }),

		CartoonButton({
			Name = "Note",
			Size = function()
				return UDim2.fromOffset(0, height())
			end,
			AutomaticSize = Enum.AutomaticSize.X,
			Tone = Theme.Tone.Mustard,
			Padding = 12,
			OnActivated = props.OnActivated,
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				create("ImageLabel")({
					Name = "Icon",
					LayoutOrder = 0,
					Size = UDim2.fromOffset(ICON, ICON),
					BackgroundTransparency = 1,
					Image = function()
						return Icons.ImageOf(shownIcon())
					end,
					ImageRectOffset = function()
						return iconRect().Offset
					end,
					ImageRectSize = function()
						return iconRect().Size
					end,
					ScaleType = Enum.ScaleType.Fit,
					Visible = function()
						return shownIcon() ~= "" and Icons.Has(shownIcon())
					end,
				}),
				label("Before", 1, function()
					const before = parts()
					return before
				end),
				create("ImageLabel")({
					Name = "Pad",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(PAD_ICON, PAD_ICON),
					BackgroundTransparency = 1,
					Image = padImage,
					Visible = function()
						const _, _, slot = parts()
						return slot
					end,
				}),
				label("After", 3, function()
					const _, after = parts()
					return after
				end),
			},
		}),
	}) :: Frame
end
