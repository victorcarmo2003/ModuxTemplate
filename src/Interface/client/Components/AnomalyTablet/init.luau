--!strict
-- AnomalyTablet: the Anomaly Tablet window (TASK-345, was the TASK-335 book; owner request 2026-10-15, Provisional).
-- Dark cartoon pass (owner 2026-10-17: darker to match the flash photos, hazard flavour, but the cartoon kit's look and
-- type; the three entry blocks clearly apart). Mobile first, ONE anomaly per page (Content.Journal list order):
--   frame   dark CartoonPanel (the bezel) with a Mustard / Ink hazard band on the top bezel and an "ANOMALY FILES" plate
--           on it, round home button on the bottom bezel (closes, like the X); pops in (Motion.Pop); `Size` 620 x 340 px
--           at UI scale 1, UiScale.Fit shrinks it to the smallest landscape phone
--   screen  night-blue screen: status bar (title · found count · n / total), a strip of dark page cards that SLIDES
--           sideways (spring, or a jump with Motion.Reduced), page dots at the bottom (tap one to jump)
--   page    left: the flash photo as a white print (tilted, tape, ref under it; Images.luau or a dark placeholder), name,
--           threat chip (Refuse Mustard · Hide Teal · Lights Violet · Careful Green), "NEW!" sticker while unread; right:
--           SIGNS / NOT THERE / HOW TO BEAT IT, each its own rounded box with a coloured title pill, SECTION_GAP apart.
--           Locked: "???" print and title, Content.Journal.Rules.LockedText
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
const STATUS = 24
const DOTS = 22
const CARD_GAP = 10
const PHOTO = Vector2.new(184, 128)
const ARROW = 44
const TEXT = 14
const HEADING = 13
const BULLETS = 2 -- slots per section (Content.Journal rows have at most 2)
const SECTION_GAP = 8 -- px between the SIGNS / NOT THERE / HOW TO BEAT IT boxes
const DOT = 8
const DOT_ON = 14
const TURN_SHARE = 0.18 -- of the screen width dragged to turn a page
const FLICK = 0.9 -- screen widths per second that turn a page on a short drag
const FLICK_MIN = 24 -- px a flick must still move
const RUBBER = 0.35 -- drag kept past the first / last page
const WHEEL_GAP = 0.25 -- s between two wheel turns
const SLIDE = 0.32 -- spring period of the slide
const SLIDE_DAMPING = 0.85
const DIM = Color3.fromHex("#2B2233") -- placeholder photo (Ink)
const SCREEN_TOP = Color3.fromHex("#22334A")
const SCREEN_BOTTOM = Color3.fromHex("#111A28")

-- dark tones of this window (Theme.Tone shape: light top, darker bottom, lip under it)
const SHELL: Theme.Tone = {
	Top = Color3.fromHex("#3B3444"),
	Bottom = Color3.fromHex("#29232F"),
	Lip = Color3.fromHex("#16121A"),
	Text = Theme.Color.Cream,
	Stroke = true,
}
const CARD: Theme.Tone = {
	Top = Color3.fromHex("#2C3B52"),
	Bottom = Color3.fromHex("#223047"),
	Lip = Color3.fromHex("#141D2B"),
	Text = Theme.Color.Cream,
	Stroke = true,
}
const BOX: Theme.Tone = {
	Top = Color3.fromHex("#1A2536"),
	Bottom = Color3.fromHex("#16202F"),
	Lip = Color3.fromHex("#0E1520"),
	Text = Theme.Color.Cream,
	Stroke = true,
}
const HAZARD_INK = Color3.fromHex("#1A161E")

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

-- Ink diagonal stripes over the Mustard band (clipped by it)
local function hazardStripes(count: number, width: number): { any }
	const out: { any } = {}
	for i = 0, count do
		table.insert(
			out,
			create("Frame")({
				Name = "Stripe",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, i * width * 2, 0.5, 0),
				Size = UDim2.new(0, width, 3, 0),
				Rotation = 40,
				BackgroundColor3 = HAZARD_INK,
				BorderSizePixel = 0,
			})
		)
	end
	return out
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

	-- One block of the entry: its own rounded dark box, the title as a pill in the block's tone, the lines under it.
	local function section(order: number, title: string, tone: Theme.Tone, lines: { string }): any
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
						Color = Theme.Color.Cream,
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
		return CartoonPanel({
			Name = title,
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Tone = BOX,
			Outline = 2,
			OutlineColor = tone.Bottom,
			Radius = UDim.new(0, 10),
			Lip = 2,
			Gloss = false,
			Padding = { Left = 8, Right = 8, Top = 6, Bottom = 7 },
			Children = vertical({
				CartoonPanel({
					Name = "Heading",
					LayoutOrder = 0,
					Size = UDim2.fromOffset(0, HEADING + 8),
					AutomaticSize = Enum.AutomaticSize.X,
					Tone = tone,
					Outline = 2,
					Radius = Theme.Radius.Pill,
					Lip = 2,
					Gloss = false,
					Padding = { Left = 9, Right = 9 },
					Children = {
						CartoonLabel({
							TextSize = HEADING,
							Color = tone.Text,
							Stroke = if tone.Stroke then 2 else 0,
							Text = title,
						}),
					},
				}),
				bullets,
			}, 4),
		})
	end

	const photo = create("Frame")({
		Name = "Photo",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(PHOTO.X, PHOTO.Y),
		BackgroundColor3 = Theme.Color.Cream,
		Rotation = if index % 2 == 0 then 2.5 else -2.5,
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Outline.Normal }),
		create("UICorner")({ CornerRadius = UDim.new(0, 4) }),
		create("Frame")({
			Name = "Print",
			Position = UDim2.fromOffset(7, 7),
			Size = UDim2.new(1, -14, 1, -26),
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
				Position = UDim2.fromScale(0.5, 0.5),
				TextSize = 40,
				Color = Theme.Color.Mustard,
				Text = "?",
				Visible = function()
					return image() == ""
				end,
			}),
		}),
		-- the ref written under the print
		CartoonLabel({
			Name = "Ref",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -2),
			TextSize = 13,
			Color = Theme.Color.Ink,
			Stroke = 0,
			Text = function()
				return if open() then ref else rules.LockedTitle
			end,
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
				CartoonLabel({ TextSize = 15, Color = Theme.Color.Dark, Stroke = 0, Text = "NEW!" }),
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
				TextSize = 21,
				Color = Theme.Color.Cream,
				Text = function()
					return if open() then row.Title else rules.LockedTitle
				end,
				Box = UDim2.new(1, 0, 0, 28),
				Scaled = true,
				MaxTextSize = 21,
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
				section(1, "SIGNS", Theme.Tone.Mustard, row.Signs),
				section(2, "NOT THERE", Theme.Tone.Cream, row.Not),
				section(3, "HOW TO BEAT IT", Theme.Tone.Teal, row.Fight),
			}, SECTION_GAP),
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
				Color = Theme.Color.Mustard,
				Text = rules.LockedTitle,
			}),
			CartoonLabel({
				Name = "Text",
				LayoutOrder = 2,
				TextSize = TEXT,
				Color = Theme.Color.Cream,
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
			Tone = CARD,
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
				Color = Theme.Color.Mustard,
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

	-- the hazard band on the top bezel: a Mustard pill with Ink stripes and a dark plate with the title on it
	const band = CartoonPanel({
		Name = "Hazard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, BEZEL / 2),
		Size = UDim2.fromOffset(260, 22),
		Tone = Theme.Tone.Mustard,
		Outline = 2,
		Radius = Theme.Radius.Pill,
		Lip = 0,
		Gloss = false,
		Padding = 0,
		Children = {
			create("Frame")({
				Name = "Stripes",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				hazardStripes(16, 9),
			}),
			CartoonPanel({
				Name = "Plate",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(0, 18),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = SHELL,
				Outline = 2,
				Radius = Theme.Radius.Pill,
				Lip = 0,
				Gloss = false,
				Padding = { Left = 10, Right = 10 },
				Children = {
					CartoonLabel({ TextSize = 13, Color = Theme.Color.Mustard, Stroke = 0, Text = "ANOMALY FILES" }),
				},
			}),
		},
	})

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
			Tone = SHELL,
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
					band,
					create("TextButton")({
						Name = "Home",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 1, -(BEZEL / 2 + LIP)),
						Size = UDim2.fromOffset(16, 16),
						BackgroundColor3 = SHELL.Lip,
						Text = "",
						AutoButtonColor = true,
						Selectable = false,
						Activated = function()
							props.OnClose()
						end,
						create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						createRaw("UIStroke")({ Color = Theme.Color.Slate, Thickness = 2 }),
					}),
					circle("Lamp", 8, Theme.Color.Mustard, UDim2.fromOffset(36, BEZEL / 2)),
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
