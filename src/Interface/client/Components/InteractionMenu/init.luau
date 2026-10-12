--!strict
-- InteractionMenu: the ordered list of interaction buttons shown when SEVERAL prompts are in reach at once (user
-- request 2026-10-12: the pills "fought" over the counter - Take Order, Refuse, ketchup, Collect Cash). One column of
-- cartoon buttons at the middle-right of the screen (never over the crosshair or the lower right free zone, style guide
-- §7.2), each with an icon, the action text and a shortcut chip:
--   KeyboardMouse  chip = "1".."4" (direct pick); footer "1-N or wheel: choose · E: use"
--   Gamepad        chip "X" on the selected row; footer "D-pad: choose · X: use"
--   Touch          no chip, no footer; every row is a tap target >= Theme.MinTouch tall
-- The selected row is Mustard (interactive accent), the others Cream; a row whose prompt is out of reach but still in
-- its 1.5 s grace is dimmed (`Enabled` false) and cannot be used. A hold action fills its row Green over HoldDuration.
-- A row pops when `Done` goes up (the interaction was sent).
-- Pure: only props. PromptController owns candidates, order, selection, input and the hold timer; this only draws and
-- reports taps. The list is keyed by Item table identity: the owner reuses the same table for the same prompt so a row
-- keeps its instances (and its animation) while the order or the content changes around it.
-- Global UI scale (Theme.Scale) is applied here, so the owner mounts it in a plain full-screen ScreenGui.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local UiScale = require(script.Parent.UiScale)
local UseTween = require(script.Parent.UseTween)
local Motion = require(script.Parent.Motion)
local Icons = require(script.Parent.Icons)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const values = Vide.values
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale, UIPadding and UIListLayout are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Device = "KeyboardMouse" | "Gamepad" | "Touch"

export type Item = {
	Text: () -> string,
	-- Icon name of `Components/Icons` ("" = no icon)
	Icon: () -> string,
	Holding: () -> boolean,
	-- Seconds the hold takes (0 = tap)
	HoldDuration: () -> number,
	-- Completion counter: +1 plays the row pop
	Done: () -> number,
	-- false = out of reach, in its grace: dimmed, never used
	Enabled: () -> boolean,
	-- Extra hint of the selected row ("  ·  hold R: Refuse"), shown in the footer
	Hint: () -> string,
}

export type Props = {
	Items: () -> { Item },
	Selected: () -> Item?,
	Visible: () -> boolean,
	Device: () -> Device,
	-- Rows take taps (touch). Desktop / gamepad keep it off: an Active button under the locked cursor stops the camera.
	Tappable: () -> boolean,
	OnSelect: ((item: Item) -> ())?,
	OnPress: ((item: Item) -> ())?,
	OnRelease: ((item: Item) -> ())?,
	-- Distance from the right edge in px at UI scale 1 (touch: clears the jump / use buttons). Default 16.
	Right: (() -> number)?,
	-- Vertical anchor, fraction of the screen height. Default 0.42.
	Y: number?,
	-- UI scale override (stories); default Theme global scale.
	Scale: (() -> number)?,
	Name: string?,
}

const ROW_WIDTH = 300
const ROW_HEIGHT = 48 -- face 44 (>= Theme.MinTouch) + lip 4
const ROW_GAP = 6
const TEXT_SIZE = 17
const HINT_SIZE = 14
const CHIP_SIZE = 28
const ICON_SIZE = 28
const PAD_LEFT = 10
const PAD_RIGHT = 14
const INNER_GAP = 8
const LABEL_WIDTH = ROW_WIDTH - PAD_LEFT - PAD_RIGHT - CHIP_SIZE - ICON_SIZE - INNER_GAP * 2
const RELEASE_TIME = 0.15
const SELECT_SCALE = 1.04
const DISABLED_TRANSPARENCY = 0.5

local function trimHint(hint: string): string
	-- "  ·  hold R: Refuse" -> "hold R: Refuse"
	const text = string.gsub(hint, "^[%s\194\183]+", "")
	return text
end

return function(props: Props): Frame
	const scale = props.Scale or UiScale.Current
	const shown = props.Visible
	const pop = Motion.Pop(shown)

	local function count(): number
		return #props.Items()
	end

	const navHint = function(): string
		const device = props.Device()
		if device == "KeyboardMouse" then
			return `1-{math.max(count(), 1)} or wheel: choose  ·  E: use`
		elseif device == "Gamepad" then
			return "D-pad: choose  ·  X: use"
		end
		return ""
	end
	const extraHint = function(): string
		const item = props.Selected()
		return if item then trimHint(item.Hint()) else ""
	end

	local function row(item: Item, index: () -> number): Frame
		const pressed = source(false)
		const isSelected = function(): boolean
			return props.Selected() == item
		end
		const press = Motion.Press(pressed, isSelected)
		const bump = Motion.Bump(item.Done, 1.1)

		-- Hold fill: linear over HoldDuration while held, quick drain from where it stopped on release
		const fill = UseTween(function()
			return if item.Holding() then UDim2.fromScale(1, 1) else UDim2.fromScale(0, 1)
		end, function()
			return if untrack(item.Holding) then untrack(item.HoldDuration) else RELEASE_TIME
		end, Enum.EasingStyle.Linear)

		const chipText = function(): string
			const device = props.Device()
			if device == "KeyboardMouse" then
				return tostring(index())
			elseif device == "Gamepad" and isSelected() then
				return "X"
			end
			return ""
		end
		const iconRect = function()
			return Icons.Rect(item.Icon())
		end
		const hasIcon = function(): boolean
			return iconRect() ~= nil
		end

		local function release()
			if not pressed() then
				return
			end
			pressed(false)
			if props.OnRelease then
				props.OnRelease(item)
			end
		end

		return CartoonPanel({
			Name = "Row",
			LayoutOrder = index,
			Size = UDim2.fromOffset(ROW_WIDTH, ROW_HEIGHT),
			Tone = function()
				return if isSelected() then Theme.Tone.Mustard else Theme.Tone.Cream
			end,
			Transparency = function()
				return if item.Enabled() then 0 else DISABLED_TRANSPARENCY
			end,
			Outline = Theme.Outline.Normal,
			Decor = {
				createRaw("UIScale")({
					Scale = function()
						return press() * bump() * (if isSelected() then SELECT_SCALE else 1)
					end,
				}),
			},
			Children = {
				-- Hold fill, under the content
				create("Frame")({
					Name = "Fill",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 3, 0.5, 0),
					Size = function()
						const f = fill().X.Scale
						return UDim2.new(f, -6 * f, 1, -6)
					end,
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 0,
					Visible = function()
						return fill().X.Scale > 0.001
					end,
					create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
					createRaw("UIGradient")({ Rotation = 90, Color = Theme.Gradient(Theme.Tone.Green) }),
				}),

				create("Frame")({
					Name = "Body",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ZIndex = 1,
					createRaw("UIPadding")({
						PaddingLeft = UDim.new(0, PAD_LEFT),
						PaddingRight = UDim.new(0, PAD_RIGHT),
					}),
					createRaw("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, INNER_GAP),
					}),

					-- Shortcut chip (fixed slot, so the labels line up whichever device is in use)
					create("Frame")({
						Name = "ChipSlot",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(CHIP_SIZE, CHIP_SIZE),
						BackgroundTransparency = 1,
						Visible = function()
							return props.Device() ~= "Touch"
						end,
						CartoonPanel({
							Name = "Chip",
							Size = UDim2.fromScale(1, 1),
							Tone = Theme.Tone.Ink,
							Radius = Theme.Radius.Small,
							Lip = 3,
							Outline = Theme.Outline.Thin,
							Visible = function()
								return chipText() ~= ""
							end,
							Children = {
								CartoonLabel({
									Box = UDim2.fromScale(1, 1),
									TextSize = TEXT_SIZE,
									Text = chipText,
								}),
							},
						}),
					}),

					create("ImageLabel")({
						Name = "Icon",
						LayoutOrder = 2,
						Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
						BackgroundTransparency = 1,
						Image = function()
							return Icons.ImageOf(item.Icon())
						end,
						ImageRectOffset = function()
							const rect = iconRect()
							return if rect then rect.Offset else Vector2.zero
						end,
						ImageRectSize = function()
							const rect = iconRect()
							return if rect then rect.Size else Vector2.zero
						end,
						ImageTransparency = function()
							return if item.Enabled() then 0 else DISABLED_TRANSPARENCY
						end,
						Visible = hasIcon,
					}),

					CartoonLabel({
						Name = "Label",
						LayoutOrder = 3,
						Box = UDim2.fromOffset(LABEL_WIDTH, ROW_HEIGHT - Theme.Lip),
						TextSize = TEXT_SIZE,
						Color = Theme.Color.Dark,
						Stroke = 0,
						XAlignment = Enum.TextXAlignment.Left,
						Truncate = true,
						Transparency = function()
							return if item.Enabled() then 0 else DISABLED_TRANSPARENCY
						end,
						Text = item.Text,
					}),
				}),

				-- Tap / click target over the whole row (touch only, see Props.Tappable)
				create("TextButton")({
					Name = "Hit",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 5,
					Active = props.Tappable,
					Visible = props.Tappable,
					AutoButtonColor = false,
					Selectable = false,
					MouseLeave = release,
					MouseButton1Down = function()
						if not item.Enabled() or pressed() then
							return
						end
						pressed(true)
						if props.OnSelect then
							props.OnSelect(item)
						end
						if props.OnPress then
							props.OnPress(item)
						end
					end,
					MouseButton1Up = release,
				}),
			},
		})
	end

	return create("Frame")({
		Name = props.Name or "InteractionMenu",
		Size = function()
			const s = scale()
			return UDim2.fromScale(1 / s, 1 / s)
		end,
		BackgroundTransparency = 1,
		Active = false,
		createRaw("UIScale")({ Scale = scale }),

		create("Frame")({
			Name = "List",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = function()
				const right = if props.Right then props.Right() else 16
				return UDim2.new(1, -right, props.Y or 0.42, 0)
			end,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Visible = function()
				return shown() or pop() > 0.02
			end,
			createRaw("UIScale")({ Scale = pop }),
			createRaw("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, ROW_GAP),
			}),

			values(props.Items, row),

			CartoonLabel({
				Name = "NavHint",
				LayoutOrder = 100,
				TextSize = HINT_SIZE,
				Color = Theme.Color.Cream,
				XAlignment = Enum.TextXAlignment.Right,
				Text = navHint,
				Visible = function()
					return navHint() ~= ""
				end,
			}),
			CartoonLabel({
				Name = "ExtraHint",
				LayoutOrder = 101,
				TextSize = HINT_SIZE,
				Color = Theme.Color.Gold,
				XAlignment = Enum.TextXAlignment.Right,
				Text = extraHint,
				Visible = function()
					return extraHint() ~= ""
				end,
			}),
		}),
	}) :: Frame
end
