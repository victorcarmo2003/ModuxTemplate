--!strict
-- AnomalyTablet: the Anomaly Tablet window (TASK-345, was the TASK-335 book; owner request 2026-10-15, Provisional),
-- cartoon kit, mobile first. A landscape tablet, ONE anomaly per page (Content.Journal list order):
--   frame   Ink CartoonPanel with round corners, thick outline and lip (the bezel), camera dot on the top bezel, round
--           home button on the bottom bezel (closes, like the Teal X); pops in (Motion.Pop); `Size` 620 x 340 px at UI
--           scale 1, UiScale.Fit shrinks it to the smallest landscape phone
--   screen  Teal two-tone screen: status bar ("ANOMALY TABLET" · found count · n / total), a strip of Cream page cards
--           that SLIDES sideways (spring, or a jump with Motion.Reduced), page dots at the bottom (tap one to jump)
--   page    left: the "photo" (white print, tilted, Images.luau or a dark placeholder), name, tag chip (Refuse Mustard ·
--           Hide Teal · Lights Violet · Careful Green), "NEW!" sticker while unread; right: SIGNS / NOT THERE /
--           HOW TO BEAT IT bullets. Locked: "???" print and title, Content.Journal.Rules.LockedText
--   input   drag with the mouse or swipe with a finger (the strip follows, past ~18% of the width or a quick flick
--           turns the page, rubber band at the ends), mouse wheel, round Mustard arrows on the side bezels ("Prev" /
--           "Next": gamepad selection). Triggers / D-pad / arrow keys are the owner's binds (JournalController)
-- Pure: only props. Texts come from Content.Journal (English, house palette, never red).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Theme)
local UiScale = require(script.Parent.UiScale)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Images = require(script.Images)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale, UIStroke, UIGradient and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Visible: () -> boolean,
	-- unlocked pages (Content.Journal key -> true)
	Pages: () -> { [string]: boolean },
	-- unlocked but not read yet ("NEW!" sticker); nil = none
	Fresh: (() -> { [string]: boolean })?,
	-- page shown, 1..#Content.Journal.List
	Index: () -> number,
	-- move by `delta` pages (arrows, swipe, wheel, dots)
	OnTurn: (delta: number) -> (),
	OnClose: () -> (),
	Scale: (() -> number)?,
	-- small line under the tablet (e.g. "Swipe or scroll to turn pages"); "" or nil = none
	Hint: (() -> string)?,
	-- image ids by page key; default Images.luau (stories may pass their own)
	Images: { [string]: string }?,
}

const SIZE = Vector2.new(620, 340)
const DESIGN = Vector2.new(660, 380) -- the tablet plus the buttons over its edges and the hint line
const BEZEL = 22
const LIP = 6
const STATUS = 22
const DOTS = 22
const CARD_GAP = 10
const PHOTO = Vector2.new(176, 124)
const ARROW = 44
const TEXT = 15
const HEADING = 16
const BULLETS = 2 -- slots per section (Content.Journal rows have at most 2)
const DOT = 8
const DOT_ON = 14
const TURN_SHARE = 0.18 -- of the screen width dragged to turn a page
const FLICK = 0.9 -- screen widths per second that turn a page on a short drag
const FLICK_MIN = 24 -- px a flick must still move
const RUBBER = 0.35 -- drag kept past the first / last page
const WHEEL_GAP = 0.25 -- s between two wheel turns
const SLIDE = 0.32 -- spring period of the slide
const SLIDE_DAMPING = 0.85
const DIM = Color3.fromHex("#4A3D57") -- placeholder photo (Tone.Ink top)
const SCREEN_TOP = Color3.fromHex("#63C8D4")
const SCREEN_BOTTOM = Color3.fromHex("#256E7A")

const TAGS: { [string]: { Text: string, Tone: Theme.Tone } } = {
	Refuse = { Text = "REFUSE", Tone = Theme.Tone.Mustard },
	Hide = { Text = "HIDE", Tone = Theme.Tone.Teal },
	Lights = { Text = "LIGHTS", Tone = Theme.Tone.Violet },
	Careful = { Text = "CAREFUL", Tone = Theme.Tone.Green },
}

const pages = Content.Journal.List
const rules = Content.Journal.Rules

local function vertical(children: { any }, padding: number, align: Enum.HorizontalAlignment?): { any }
	return {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, padding),
		}),
		children,
	}
end

local function circle(name: string, size: number, color: Color3, position: UDim2): Frame
	return create("Frame")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
	}) :: Frame
end

-- One page card (static row; lock and "NEW!" follow the props).
local function pageCard(props: Props, images: { [string]: string }, index: number, row: Content.JournalPage): Frame
	const open = function(): boolean
		return props.Pages()[row.Key] == true
	end
	const fresh = function(): boolean
		return open() and props.Fresh ~= nil and props.Fresh()[row.Key] == true
	end
	const image = function(): string
		return if open() then images[row.Key] or "" else ""
	end
	const tag = TAGS[row.Tag] or TAGS.Careful
	const ref = Content.Anomalies.ByKey[row.Key].Ref

	local function section(order: number, title: string, color: Color3, lines: { string }): Frame
		const bullets: { any } = {}
		for slot = 1, BULLETS do
			const line = lines[slot]
			if line ~= nil then
				table.insert(
					bullets,
					CartoonLabel({
						Name = `Line{slot}`,
						LayoutOrder = slot,
						TextSize = TEXT,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Wrapped = true,
						XAlignment = Enum.TextXAlignment.Left,
						YAlignment = Enum.TextYAlignment.Top,
						Box = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						Text = `• {line}`,
					})
				)
			end
		end
		return create("Frame")({
			Name = title,
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			vertical({
				CartoonLabel({
					Name = "Heading",
					LayoutOrder = 0,
					TextSize = HEADING,
					Color = color,
					Text = title,
					XAlignment = Enum.TextXAlignment.Left,
					Box = UDim2.new(1, 0, 0, HEADING + 6),
				}),
				bullets,
			}, 1),
		}) :: Frame
	end

	const photo = create("Frame")({
		Name = "Photo",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(PHOTO.X, PHOTO.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Rotation = if index % 2 == 0 then 2.5 else -2.5,
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Outline.Normal }),
		create("UICorner")({ CornerRadius = UDim.new(0, 4) }),
		create("Frame")({
			Name = "Print",
			Position = UDim2.fromOffset(7, 7),
			Size = UDim2.new(1, -14, 1, -22),
			BackgroundColor3 = DIM,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			create("ImageLabel")({
				Name = "Picture",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Crop,
				Image = image,
				Visible = function()
					return image() ~= ""
				end,
			}),
			CartoonLabel({
				Name = "Unknown",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				TextSize = 40,
				Color = Theme.Color.Mustard,
				Text = "?",
				Visible = function()
					return image() == ""
				end,
			}),
			CartoonLabel({
				Name = "Ref",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -3),
				TextSize = 14,
				Color = Theme.Color.Cream,
				Text = function()
					return if open() then ref else rules.LockedTitle
				end,
				Visible = function()
					return image() == ""
				end,
			}),
		}),
		create("Frame")({
			Name = "Tape",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(50, 14),
			Rotation = 4,
			BackgroundColor3 = Theme.Color.Gold,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
		}),
		CartoonPanel({
			Name = "New",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			Rotation = 12,
			Tone = Theme.Tone.Mustard,
			Outline = Theme.Outline.Normal,
			Lip = 2,
			Padding = { Left = 8, Right = 8 },
			Visible = fresh,
			Children = {
				CartoonLabel({ TextSize = 14, Color = Theme.Color.Dark, Stroke = 0, Text = "NEW!" }),
			},
		}),
	})

	const left = create("Frame")({
		Name = "Left",
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundTransparency = 1,
		vertical({
			photo,
			CartoonLabel({
				Name = "Title",
				LayoutOrder = 2,
				TextSize = 22,
				Color = Theme.Color.Dark,
				Stroke = 0,
				Text = function()
					return if open() then row.Title else rules.LockedTitle
				end,
				Box = UDim2.new(1, 0, 0, 28),
				Scaled = true,
				MaxTextSize = 22,
			}),
			CartoonPanel({
				Name = "Tag",
				LayoutOrder = 3,
				Size = UDim2.fromOffset(0, 28),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = tag.Tone,
				Outline = Theme.Outline.Normal,
				Radius = Theme.Radius.Pill,
				Lip = 3,
				Padding = { Left = 12, Right = 12 },
				Visible = open,
				Children = {
					CartoonLabel({
						TextSize = 15,
						Color = tag.Tone.Text,
						Stroke = if tag.Tone.Stroke then 2 else 0,
						Text = tag.Text,
					}),
				},
			}),
		}, 6, Enum.HorizontalAlignment.Center),
	})

	const right = create("Frame")({
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.6, -12, 1, 0),
		BackgroundTransparency = 1,
		create("Frame")({
			Name = "Entry",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = open,
			vertical({
				section(1, "SIGNS", Theme.Color.Teal, row.Signs),
				section(2, "NOT THERE", Theme.Color.Slate, row.Not),
				section(3, "HOW TO BEAT IT", Theme.Color.Green, row.Fight),
			}, 4),
		}),
		create("Frame")({
			Name = "Locked",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = function()
				return not open()
			end,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			CartoonLabel({
				Name = "Mark",
				LayoutOrder = 1,
				TextSize = 40,
				Color = Theme.Color.Dark,
				Stroke = 0,
				Text = rules.LockedTitle,
			}),
			CartoonLabel({
				Name = "Text",
				LayoutOrder = 2,
				TextSize = TEXT,
				Color = Theme.Color.Dark,
				Stroke = 0,
				Wrapped = true,
				Text = rules.LockedText,
				Box = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			}),
		}),
	})

	return create("Frame")({
		Name = `Page{index}`,
		Position = UDim2.fromScale(index - 1, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		CartoonPanel({
			Name = "Card",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -CARD_GAP * 2, 1, 0),
			Tone = Theme.Tone.Cream,
			Outline = Theme.Outline.Normal,
			Radius = Theme.Radius.Card,
			Lip = 3,
			Gloss = false,
			Padding = 10,
			Children = { left, right },
		}),
	}) :: Frame
end

return function(props: Props): Frame
	const pop = Motion.Pop(props.Visible)
	const area = source(Vector2.zero)
	const scale = function(): number
		const base = if props.Scale then math.max(math.min(props.Scale(), UiScale.Current()), Theme.Scale.Min) else 1
		return UiScale.Fit(base, area(), DESIGN)
	end
	const images = props.Images or Images
	const total = #pages

	-- sliding: the spring follows the page index plus the live drag (in screen widths), so a release slides on from
	-- where the finger let go
	const drag = source(0) -- px (real screen px), > 0 = pulled toward the next page
	const width = source(1) -- real px width of the screen viewport
	const target = function(): number
		return props.Index() + drag() / math.max(width(), 1)
	end
	const position: () -> number = if Motion.Reduced() then target else spring(target, SLIDE, SLIDE_DAMPING)

	const found = function(): number
		local count = 0
		for _, row in pages do
			if props.Pages()[row.Key] then
				count += 1
			end
		end
		return count
	end

	const cards: { any } = {}
	for index, row in pages do
		table.insert(cards, pageCard(props, images, index, row))
	end

	const dots: { any } = {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 5),
		}),
	}
	for index, row in pages do
		const on = function(): boolean
			return props.Index() == index
		end
		table.insert(
			dots,
			create("TextButton")({
				Name = `Dot{index}`,
				LayoutOrder = index,
				Size = function()
					return if on() then UDim2.fromOffset(DOT_ON, DOT_ON) else UDim2.fromOffset(DOT, DOT)
				end,
				Text = "",
				AutoButtonColor = false,
				Selectable = false,
				BackgroundColor3 = function()
					return if on()
						then Theme.Color.Mustard
						elseif props.Pages()[row.Key] then Theme.Color.Cream
						else Theme.Color.Slate
				end,
				Activated = function()
					props.OnTurn(index - untrack(props.Index))
				end,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2 }),
			})
		)
	end

	-- input on the screen: drag / swipe and the wheel
	local dragging = false
	local startX = 0
	local startAt = 0
	local wheelAt = 0
	local function release()
		if not dragging then
			return
		end
		dragging = false
		const moved = untrack(drag)
		const w = math.max(untrack(width), 1)
		const speed = math.abs(moved) / w / math.max(os.clock() - startAt, 0.05)
		local delta = 0
		if math.abs(moved) > w * TURN_SHARE or (math.abs(moved) > FLICK_MIN and speed > FLICK) then
			delta = if moved > 0 then 1 else -1
		end
		drag(0)
		if delta ~= 0 then
			props.OnTurn(delta)
		end
	end
	const moved = UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local pulled = startX - input.Position.X
			const index = untrack(props.Index)
			if (index <= 1 and pulled < 0) or (index >= total and pulled > 0) then
				pulled *= RUBBER
			end
			drag(pulled)
		end
	end)
	const ended = UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end)
	cleanup(function()
		moved:Disconnect()
		ended:Disconnect()
	end)

	const screen = create("Frame")({
		Name = "Screen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Active = true,
		ClipsDescendants = true,
		InputBegan = function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				startX = input.Position.X
				startAt = os.clock()
				drag(0)
			end
		end,
		InputChanged = function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseWheel and os.clock() - wheelAt > WHEEL_GAP then
				wheelAt = os.clock()
				props.OnTurn(if input.Position.Z < 0 then 1 else -1)
			end
		end,
		create("UICorner")({ CornerRadius = UDim.new(0, 12) }),
		createRaw("UIGradient")({ Rotation = 90, Color = ColorSequence.new(SCREEN_TOP, SCREEN_BOTTOM) }),

		-- status bar
		create("Frame")({
			Name = "Status",
			Size = UDim2.new(1, 0, 0, STATUS),
			BackgroundTransparency = 1,
			createRaw("UIPadding")({ PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
			CartoonLabel({
				Name = "Title",
				TextSize = 15,
				Text = "ANOMALY TABLET",
				Box = UDim2.fromScale(0.5, 1),
				XAlignment = Enum.TextXAlignment.Left,
			}),
			CartoonLabel({
				Name = "Count",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				TextSize = 15,
				Text = function()
					return `{found()} found  ·  {props.Index()} / {total}`
				end,
				Box = UDim2.fromScale(0.5, 1),
				XAlignment = Enum.TextXAlignment.Right,
			}),
		}),

		-- the sliding pages
		create("Frame")({
			Name = "Viewport",
			Position = UDim2.fromOffset(0, STATUS),
			Size = UDim2.new(1, 0, 1, -(STATUS + DOTS)),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			create("Frame")({
				Name = "Strip",
				Size = UDim2.fromScale(1, 1),
				Position = function()
					return UDim2.fromScale(-(position() - 1), 0)
				end,
				BackgroundTransparency = 1,
				cards,
			}),
		}),

		create("Frame")({
			Name = "Dots",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, DOTS),
			BackgroundTransparency = 1,
			dots,
		}),
	}) :: Frame
	const measureScreen = function()
		if screen.AbsoluteSize.X > 0 then
			width(screen.AbsoluteSize.X)
		end
	end
	const screenSize = screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(measureScreen)
	cleanup(function()
		screenSize:Disconnect()
	end)

	local function arrow(name: string, side: number, delta: number): any
		return CartoonButton({
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(side, 0.5),
			Size = UDim2.fromOffset(ARROW, ARROW),
			Icon = if delta < 0 then "Ui/arrow_left" else "Ui/arrow_right",
			IconSize = ARROW - 16,
			Tone = Theme.Tone.Mustard,
			Enabled = function()
				const index = props.Index()
				return if delta < 0 then index > 1 else index < total
			end,
			OnActivated = function()
				props.OnTurn(delta)
			end,
		})
	end

	const root = create("Frame")({
		Name = "AnomalyTablet",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = true,
		Visible = props.Visible,

		CartoonPanel({
			Name = "Tablet",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -10),
			Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
			Tone = Theme.Tone.Ink,
			Outline = Theme.Outline.Thick,
			Radius = UDim.new(0, 30),
			Lip = LIP,
			Gloss = false,
			Padding = BEZEL,
			Decor = {
				createRaw("UIScale")({
					Scale = function()
						return scale() * pop()
					end,
				}),
				-- bezel details and buttons over the edges, drawn over the screen
				create("Frame")({
					Name = "Over",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ZIndex = 5,
					circle("Camera", 8, Color3.fromHex("#17111C"), UDim2.fromOffset(SIZE.X / 2, BEZEL / 2)),
					create("TextButton")({
						Name = "Home",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 1, -(BEZEL / 2 + LIP)),
						Size = UDim2.fromOffset(16, 16),
						BackgroundColor3 = Color3.fromHex("#4A3D57"),
						Text = "",
						AutoButtonColor = true,
						Selectable = false,
						Activated = function()
							props.OnClose()
						end,
						create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						createRaw("UIStroke")({ Color = Theme.Color.Slate, Thickness = 2 }),
					}),
					arrow("Prev", 0, -1),
					arrow("Next", 1, 1),
					CartoonButton({
						Name = "Close",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(1, -8, 0, 8),
						Size = UDim2.fromOffset(ARROW, ARROW),
						Icon = "Ui/close",
						IconSize = ARROW - 18,
						Tone = Theme.Tone.Teal,
						OnActivated = props.OnClose,
					}),
					CartoonLabel({
						Name = "Hint",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 1, 8),
						TextSize = 14,
						Color = Theme.Color.Cream,
						Text = function()
							return if props.Hint then props.Hint() else ""
						end,
						Visible = function()
							return props.Hint ~= nil and props.Hint() ~= ""
						end,
					}),
				}),
			},
			Children = { screen },
		}),
	}) :: Frame
	const measure = function()
		if root.AbsoluteSize.X > 0 then
			area(root.AbsoluteSize)
		end
		measureScreen()
	end
	const connection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
	cleanup(function()
		connection:Disconnect()
	end)
	return root
end
