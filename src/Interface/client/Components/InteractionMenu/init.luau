--!strict
-- InteractionMenu: the interaction buttons shown while prompts are in reach (user request 2026-10-12: the pills
-- "fought" over the counter; the wide centred rows hid the view, "a interface precisa ser compacta, principalmente no
-- mobile"). Two layouts, picked by `Device`:
--   Touch          ACTION CIRCLE (64 px) above the Roblox jump button (right, bottom). It shows the icon of the selected
--                  (primary) action; a tap runs it, a hold action fills a progress ring on the circle. With 2+ options a
--                  small counter sits on the circle and the options FAN OUT in an arc up/left of it (<= 4, 52 px round
--                  buttons, icon + short label under each; stable order, index 1 = straight up). Never in the middle of
--                  the screen, never over the joystick (bottom-left), the jump button (under the circle) or the top-right HUD.
--   KeyboardMouse  compact COLUMN (fits the widest label, 150-220 px, 36 px rows, 15 px text, 24 px icons, 12 px footer) to the right of the crosshair, mid height:
--   Gamepad        chip "1".."4" (direct pick) or "X" on the selected row, footer "1-N · wheel · E" / "D-pad · X".
-- The selected option is Mustard (interactive accent), the others Cream; an option whose prompt is out of reach but still
-- in its 1.5 s grace is dimmed (`Enabled` false) and cannot be used. A hold action fills Green (ring on touch, row fill on
-- desktop). The circle / an option pops when `Done` goes up (the interaction was sent).
-- Pure: only props. PromptController owns candidates, order, selection, input and the hold timer; this only draws and
-- reports taps. The list is keyed by Item table identity: the owner reuses the same table for the same prompt so an
-- option keeps its instances (and its animation) while the order or the content changes around it.
-- Global UI scale (Theme.Scale) is applied here, so the owner mounts it in a plain full-screen ScreenGui.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
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
-- Vide 0.4.1 types `create` for 19 classes only; UIScale, UIPadding, UIStroke, UIGradient and UIListLayout are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Device = "KeyboardMouse" | "Gamepad" | "Touch"

export type Item = {
	Text: () -> string,
	-- Short label of the fan option on touch ("Serve", "Ketchup", "Collect"); falls back to Text when empty
	Short: () -> string,
	-- Icon name of `Components/Icons` ("" = no icon)
	Icon: () -> string,
	Holding: () -> boolean,
	-- Seconds the hold takes (0 = tap)
	HoldDuration: () -> number,
	-- Completion counter: +1 plays the pop
	Done: () -> number,
	-- false = out of reach, in its grace: dimmed, never used
	Enabled: () -> boolean,
	-- Extra hint of the selected row ("  ·  hold R: Refuse"), shown in the footer (desktop / gamepad)
	Hint: () -> string,
}

-- Gamepad button glyphs (UserInputService:GetImageForKeyCode of the controller in use); "" = no image, a text fallback shows
export type Glyphs = { Use: string, Refuse: string, Up: string, Down: string }

export type Props = {
	-- Glyphs of the console buttons (owner PromptController; reads UserInputService, so it follows Xbox / PlayStation)
	Glyphs: (() -> Glyphs)?,
	-- Reports the focusable button of a row (nil when the row is destroyed) so the owner can drive GuiService.SelectedObject
	OnFocusButton: ((item: Item, button: GuiButton?) -> ())?,
	Items: () -> { Item },
	Selected: () -> Item?,
	Visible: () -> boolean,
	Device: () -> Device,
	-- Buttons take taps (touch). Desktop / gamepad keep it off: an Active button under the locked cursor stops the camera.
	Tappable: () -> boolean,
	OnSelect: ((item: Item) -> ())?,
	OnPress: ((item: Item) -> ())?,
	OnRelease: ((item: Item) -> ())?,
	-- UI scale override (stories); default Theme global scale.
	Scale: (() -> number)?,
	Name: string?,
}

-- Desktop / gamepad column
const MIN_WIDTH = 150 -- the column fits its widest label between these
const MAX_WIDTH = 220
const ROW_HEIGHT = 36 -- face 32 + lip 4
const ROW_GAP = 4
const TEXT_SIZE = 15
const HINT_SIZE = 14 -- touch labels (fan) and chips
const FOOTER_SIZE = 12 -- desktop footer hint
const CHIP_SIZE = 22
const ICON_SIZE = 24
const PAD_LEFT = 7
const PAD_RIGHT = 8
const INNER_GAP = 5
const CHROME = PAD_LEFT + PAD_RIGHT + CHIP_SIZE + ICON_SIZE + INNER_GAP * 2
const COLUMN_GAP = 36 -- px right of the crosshair

-- Touch action circle and fan
const MAIN_SIZE = 64
const OPTION_SIZE = 52 -- face 48 + lip 4 (>= Theme.MinTouch)
const TOUCH_RIGHT = 28 -- the jump button of a phone sits under the circle (x centre = 60 from the right edge)
const TOUCH_BOTTOM = 112 -- jump top is about 90 px from the bottom
const FAN_RADIUS = 108
const FAN_START = 90 -- degrees, counter-clockwise from the right: 90 = straight up, then sweeping left
const FAN_STEP = 38
const MAX_FAN = 4
const RING_THICKNESS = 6
const OPTION_ICON = 24
const MAIN_ICON = 30

const EMPTY_GLYPHS: Glyphs = { Use = "", Refuse = "", Up = "", Down = "" }
const GLYPH_SIZE = 18 -- console button image in the chip (22) / the footer strip
const RELEASE_TIME = 0.15
const SELECT_SCALE = 1.04
const DISABLED_TRANSPARENCY = 0.5
-- Hard-edged half: with a gradient rotated by 0..180 degrees it sweeps one half of a ring
const RING_SWEEP = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.499, 0),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local function trimHint(hint: string): string
	-- "  ·  hold R: Refuse" -> "hold R: Refuse"
	const text = string.gsub(hint, "^[%s\194\183]+", "")
	return text
end

-- Linear 0..1 progress of a hold: fills over the HoldDuration while held, drains quickly from where it stopped on release
local function holdProgress(holding: () -> boolean, duration: () -> number): () -> number
	const fill = UseTween(function()
		return if holding() then UDim2.fromScale(1, 1) else UDim2.fromScale(0, 1)
	end, function()
		return if untrack(holding) then untrack(duration) else RELEASE_TIME
	end, Enum.EasingStyle.Linear)
	return function(): number
		return fill().X.Scale
	end
end

-- Progress ring over a circle: two clipped half rings whose gradient rotation sweeps clockwise from the top.
local function ring(progress: () -> number): Frame
	local function half(right: boolean): Frame
		return create("Frame")({
			Name = if right then "Right" else "Left",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.fromScale(0.5, 1),
			Position = UDim2.fromScale(if right then 0.5 else 0, 0),
			create("Frame")({
				Name = "Circle",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(2, 1),
				Position = UDim2.fromScale(if right then -1 else 0, 0),
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				createRaw("UIStroke")({
					Color = Theme.Color.Green,
					Thickness = RING_THICKNESS,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					createRaw("UIGradient")({
						Transparency = RING_SWEEP,
						Rotation = function()
							const degrees = progress() * 360
							return if right then math.clamp(degrees, 0, 180) else math.clamp(degrees, 180, 360)
						end,
					}),
				}),
			}),
		})
	end
	return create("Frame")({
		Name = "Ring",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Visible = function()
			return progress() > 0.001
		end,
		half(true),
		half(false),
	}) :: Frame
end

-- Centre offset (relative to the circle centre) of fan option `index`
local function fanPosition(index: number): UDim2
	const angle = math.rad(FAN_START + (index - 1) * FAN_STEP)
	return UDim2.new(0.5, FAN_RADIUS * math.cos(angle), 0.5, -FAN_RADIUS * math.sin(angle))
end

return function(props: Props): Frame
	const scale = props.Scale or UiScale.Current
	const shown = props.Visible
	const pop = Motion.Pop(shown)

	local function count(): number
		return #props.Items()
	end
	const isTouch = function(): boolean
		return props.Device() == "Touch"
	end

	-- One width for every row: the widest label (fixed text size) + chip + icon, clamped
	const rowWidth = function(): number
		local widest = 0
		for _, item in props.Items() do
			const bounds = TextService:GetTextSize(item.Text(), TEXT_SIZE, Enum.Font.FredokaOne, Vector2.new(1000, 100))
			widest = math.max(widest, bounds.X)
		end
		return math.clamp(math.ceil(widest) + 6 + CHROME, MIN_WIDTH, MAX_WIDTH)
	end

	const navHint = function(): string
		const device = props.Device()
		if device == "KeyboardMouse" then
			return `1-{math.max(count(), 1)} · wheel · E`
		end
		return "" -- gamepad: the glyph strip (PadHint) instead
	end
	-- The number keys belong to the menu rows; every other key keeps swapping the hotbar item
	const keysHint = function(): string
		if props.Device() ~= "KeyboardMouse" then
			return ""
		end
		const rows = math.min(count(), MAX_FAN)
		return if rows >= 9 then "" else `1-{rows}: menu  ·  {rows + 1}-9: items`
	end
	const extraHint = function(): string
		const item = props.Selected()
		return if item and props.Device() ~= "Gamepad" then trimHint(item.Hint()) else ""
	end
	-- "hold Y: Refuse" -> "hold: Refuse" (the glyph of the button sits before it)
	const padExtraText = function(): string
		const item = props.Selected()
		const hint = if item then trimHint(item.Hint()) else ""
		const action = string.match(hint, ":%s*(.+)$")
		return if action then `hold: {action}` else ""
	end
	const glyphs = function(): Glyphs
		return if props.Glyphs then props.Glyphs() else EMPTY_GLYPHS
	end
	const isPad = function(): boolean
		return props.Device() == "Gamepad"
	end

	local function iconImage(iconOf: () -> string, size: number, dimmed: (() -> boolean)?): ImageLabel
		const iconRect = function()
			return Icons.Rect(iconOf())
		end
		return create("ImageLabel")({
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Image = function()
				return Icons.ImageOf(iconOf())
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
				return if dimmed and dimmed() then DISABLED_TRANSPARENCY else 0
			end,
			Visible = function()
				return iconRect() ~= nil
			end,
		}) :: ImageLabel
	end

	-- Compact footer line (12 px, desktop / gamepad only; the list is hidden on touch)
	local function footer(name: string, order: number, color: Color3, text: () -> string): TextLabel
		return create("TextLabel")({
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromOffset(0, FOOTER_SIZE + 4),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextSize = FOOTER_SIZE,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = text,
			Visible = function()
				return text() ~= ""
			end,
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round }),
		}) :: TextLabel
	end

	-- Gamepad footer strip: [D-pad up][D-pad down] move  [X] use  [Y] hold: Refuse (glyphs of the controller in use)
	local function padGlyph(name: string, order: number, pick: (Glyphs) -> string, visible: (() -> boolean)?): ImageLabel
		const image = function(): string
			return pick(glyphs())
		end
		return create("ImageLabel")({
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromOffset(GLYPH_SIZE, GLYPH_SIZE),
			BackgroundTransparency = 1,
			Image = image,
			Visible = function()
				return image() ~= "" and (visible == nil or visible())
			end,
		}) :: ImageLabel
	end
	local function padStrip(): Frame
		const hasExtra = function(): boolean
			return padExtraText() ~= ""
		end
		return create("Frame")({
			Name = "PadHint",
			LayoutOrder = 102,
			Size = UDim2.fromOffset(0, GLYPH_SIZE),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Visible = isPad,
			createRaw("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 3),
			}),
			padGlyph("Up", 1, function(set: Glyphs)
				return set.Up
			end),
			padGlyph("Down", 2, function(set: Glyphs)
				return set.Down
			end),
			footer("MoveText", 3, Theme.Color.Cream, function()
				return "move"
			end),
			padGlyph("Use", 4, function(set: Glyphs)
				return set.Use
			end),
			footer("UseText", 5, Theme.Color.Cream, function()
				return "use"
			end),
			padGlyph("Refuse", 6, function(set: Glyphs)
				return set.Refuse
			end, hasExtra),
			footer("RefuseText", 7, Theme.Color.Gold, padExtraText),
		}) :: Frame
	end

	-- Desktop / gamepad row ----------------------------------------------------------------------------------------
	local function row(item: Item, index: () -> number): Frame
		const pressed = source(false)
		const isSelected = function(): boolean
			return props.Selected() == item
		end
		const press = Motion.Press(pressed, isSelected)
		const bump = Motion.Bump(item.Done, 1.1)
		const progress = holdProgress(item.Holding, item.HoldDuration)

		-- Gamepad: the selected row shows the "use" button, the others the D-pad direction that reaches them
		const padAbove = function(): boolean
			const selected = props.Selected()
			const at = if selected then table.find(props.Items(), selected) else nil
			return at ~= nil and index() < at
		end
		const glyphOf = function(): string
			if not isPad() then
				return ""
			end
			const set = glyphs()
			return if isSelected() then set.Use elseif padAbove() then set.Up else set.Down
		end
		const chipText = function(): string
			const device = props.Device()
			if device == "KeyboardMouse" then
				return tostring(index())
			elseif device == "Gamepad" and glyphOf() == "" then
				return if isSelected() then "X" elseif padAbove() then "^" else "v" -- no glyph image: text fallback
			end
			return ""
		end
		const iconRect = function()
			return Icons.Rect(item.Icon())
		end
		const hasIcon = function(): boolean
			return iconRect() ~= nil
		end

		-- fixed slot in the column; the panel scales from its centre inside it, so a selected / pressed row never pushes
		-- the others or grows to the right (owner request 2026-10-15)
		return create("Frame")({
			Name = "RowSlot",
			LayoutOrder = index,
			Size = function()
				return UDim2.fromOffset(rowWidth(), ROW_HEIGHT)
			end,
			BackgroundTransparency = 1,
			CartoonPanel({
				Name = "Row",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
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
					-- Console focus target: only the selected row is Selectable (gamepad), so the stick cannot walk the selection
					-- off while moving; the owner chains the rows and drives GuiService.SelectedObject (default focus ring).
					-- Never Active: it takes no mouse / touch.
					(function(): GuiButton
						const button = create("TextButton")({
							Name = "Focus",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = "",
							ZIndex = 7,
							Active = false,
							AutoButtonColor = false,
							Selectable = function()
								return isPad() and isSelected() and item.Enabled()
							end,
						}) :: GuiButton
						if props.OnFocusButton then
							const report = props.OnFocusButton
							report(item, button)
							Vide.cleanup(function()
								report(item, nil)
							end)
						end
						return button
					end)(),

					-- Hold fill, under the content
					create("Frame")({
						Name = "Fill",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 3, 0.5, 0),
						Size = function()
							const f = progress()
							return UDim2.new(f, -6 * f, 1, -6)
						end,
						BackgroundColor3 = Color3.new(1, 1, 1),
						ZIndex = 0,
						Visible = function()
							return progress() > 0.001
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
							CartoonPanel({
								Name = "Chip",
								Size = UDim2.fromScale(1, 1),
								Tone = Theme.Tone.Ink,
								Radius = Theme.Radius.Small,
								Lip = 2,
								Outline = Theme.Outline.Thin,
								Visible = function()
									return chipText() ~= "" or glyphOf() ~= ""
								end,
								Children = {
									create("ImageLabel")({
										Name = "Glyph",
										AnchorPoint = Vector2.new(0.5, 0.5),
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromOffset(GLYPH_SIZE, GLYPH_SIZE),
										BackgroundTransparency = 1,
										ZIndex = 3,
										Image = glyphOf,
										Visible = function()
											return glyphOf() ~= ""
										end,
									}),
									CartoonLabel({
										Box = UDim2.fromScale(1, 1),
										TextSize = HINT_SIZE,
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
							Box = function()
								return UDim2.fromOffset(rowWidth() - CHROME, ROW_HEIGHT - Theme.Lip)
							end,
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
				},
			}),
		}) :: Frame
	end

	-- Touch fan option ---------------------------------------------------------------------------------------------
	local function option(item: Item, index: () -> number): Frame
		const pressed = source(false)
		const isSelected = function(): boolean
			return props.Selected() == item
		end
		const press = Motion.Press(pressed, nil)
		const bump = Motion.Bump(item.Done, 1.15)
		const progress = holdProgress(item.Holding, item.HoldDuration)
		const dimmed = function(): boolean
			return not item.Enabled()
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

		return create("Frame")({
			Name = "Option",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				return fanPosition(index())
			end,
			Size = UDim2.fromOffset(OPTION_SIZE, OPTION_SIZE),
			BackgroundTransparency = 1,
			Visible = function()
				return index() <= MAX_FAN
			end,
			createRaw("UIScale")({
				Scale = function()
					return press() * bump() * (if isSelected() then SELECT_SCALE else 1)
				end,
			}),
			CartoonPanel({
				Name = "Button",
				Size = UDim2.fromScale(1, 1),
				Radius = Theme.Radius.Pill,
				Tone = function()
					return if isSelected() then Theme.Tone.Mustard else Theme.Tone.Cream
				end,
				Transparency = function()
					return if item.Enabled() then 0 else DISABLED_TRANSPARENCY
				end,
				Outline = Theme.Outline.Normal,
				Children = {
					iconImage(item.Icon, OPTION_ICON, dimmed),
					ring(progress),
				},
			}),
			CartoonLabel({
				Name = "Short",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, -9),
				Box = UDim2.fromOffset(84, HINT_SIZE + 6),
				TextSize = HINT_SIZE,
				Truncate = true,
				ZIndex = 4,
				Transparency = function()
					return if item.Enabled() then 0 else DISABLED_TRANSPARENCY
				end,
				Text = function()
					const short = item.Short()
					return if short ~= "" then short else item.Text()
				end,
			}),
			-- Tap / hold target over the whole button
			create("TextButton")({
				Name = "Hit",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 6,
				Active = props.Tappable,
				Visible = props.Tappable,
				AutoButtonColor = false,
				Selectable = props.Tappable, -- console focus on the touch buttons too (a pad paired with a tablet)
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
		}) :: Frame
	end

	-- Touch action circle (primary action) ----------------------------------------------------------------------
	const mainPressed = source(false)
	const mainPress = Motion.Press(mainPressed, nil)
	const mainBump = Motion.Bump(function(): number
		const item = props.Selected()
		return if item then item.Done() else 0
	end, 1.12)
	const mainProgress = holdProgress(function(): boolean
		const item = props.Selected()
		return item ~= nil and item.Holding()
	end, function(): number
		const item = untrack(props.Selected)
		return if item then item.HoldDuration() else 0
	end)
	-- the item that was pressed, so the release goes to the same one even if the selection moves
	local mainItem: Item? = nil
	local function mainRelease()
		if not mainPressed() then
			return
		end
		mainPressed(false)
		const item = mainItem
		mainItem = nil
		if item and props.OnRelease then
			props.OnRelease(item)
		end
	end
	const mainIcon = function(): string
		const item = props.Selected()
		return if item then item.Icon() else ""
	end

	const circle = create("Frame")({
		Name = "ActionCircle",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -TOUCH_RIGHT, 1, -TOUCH_BOTTOM),
		Size = UDim2.fromOffset(MAIN_SIZE, MAIN_SIZE),
		BackgroundTransparency = 1,
		Visible = function()
			return isTouch() and count() >= 1 and (shown() or pop() > 0.02)
		end,
		createRaw("UIScale")({ Scale = pop }),

		-- The fan: behind the circle, 2+ options only
		create("Frame")({
			Name = "Fan",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = function()
				return count() >= 2
			end,
			values(props.Items, option),
		}),

		create("Frame")({
			Name = "Main",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			createRaw("UIScale")({
				Scale = function()
					return mainPress() * mainBump()
				end,
			}),
			CartoonPanel({
				Name = "Button",
				Size = UDim2.fromScale(1, 1),
				Radius = Theme.Radius.Pill,
				Tone = Theme.Tone.Mustard,
				Outline = Theme.Outline.Thick,
				Children = {
					iconImage(mainIcon, MAIN_ICON, nil),
					ring(mainProgress),
				},
			}),
			-- Counter: how many options are fanned out
			CartoonPanel({
				Name = "Counter",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.fromOffset(24, 24),
				Radius = Theme.Radius.Pill,
				Tone = Theme.Tone.Ink,
				Lip = 2,
				Outline = Theme.Outline.Thin,
				ZIndex = 5,
				Visible = function()
					return count() >= 2
				end,
				Children = {
					CartoonLabel({
						Box = UDim2.fromScale(1, 1),
						TextSize = HINT_SIZE,
						Stroke = 0,
						Text = function()
							return tostring(math.min(count(), MAX_FAN))
						end,
					}),
				},
			}),
			create("TextButton")({
				Name = "Hit",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 6,
				Active = props.Tappable,
				Visible = props.Tappable,
				AutoButtonColor = false,
				Selectable = props.Tappable, -- console focus on the touch buttons too (a pad paired with a tablet)
				MouseLeave = mainRelease,
				MouseButton1Down = function()
					const item = untrack(props.Selected)
					if item == nil or mainPressed() or not item.Enabled() then
						return
					end
					mainPressed(true)
					mainItem = item
					if props.OnSelect then
						props.OnSelect(item)
					end
					if props.OnPress then
						props.OnPress(item)
					end
				end,
				MouseButton1Up = mainRelease,
			}),
		}),
	}) :: Frame

	-- The column pops from its centre (owner request 2026-10-15): anchored at its middle, placed half its width right of
	-- the gap. Width in px at scale 1: measured size / (pop x UI scale), kept while the pop is too small to divide by.
	const listWidth = source(0)
	const list = create("Frame")({
		Name = "List",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function()
			return UDim2.new(0.5, COLUMN_GAP + listWidth() / 2, 0.5, 0)
		end,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = function()
			return not isTouch() and (shown() or pop() > 0.02)
		end,
		createRaw("UIScale")({ Scale = pop }),
		createRaw("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ROW_GAP),
		}),

		values(props.Items, row),

		footer("NavHint", 100, Theme.Color.Cream, navHint),
		footer("KeysHint", 100, Theme.Color.Cream, keysHint),
		footer("ExtraHint", 101, Theme.Color.Gold, extraHint),
		padStrip(),
	}) :: Frame
	const measureList = function()
		const factor = Vide.untrack(pop) * Vide.untrack(scale)
		if factor > 0.2 then
			const px = list.AbsoluteSize.X / factor
			if math.abs(px - Vide.untrack(listWidth)) > 0.5 then
				listWidth(px)
			end
		end
	end
	const listConnection = list:GetPropertyChangedSignal("AbsoluteSize"):Connect(measureList)
	Vide.cleanup(function()
		listConnection:Disconnect()
	end)

	return create("Frame")({
		Name = props.Name or "InteractionMenu",
		Size = function()
			const s = scale()
			return UDim2.fromScale(1 / s, 1 / s)
		end,
		BackgroundTransparency = 1,
		Active = false,
		createRaw("UIScale")({ Scale = scale }),

		circle,

		-- Compact column to the right of the crosshair (desktop / gamepad)
		list,
	}) :: Frame
end
