--!strict
-- AnomalyBook: the Anomaly Book window (TASK-335; owner request 2026-10-15, Provisional), cartoon kit, mobile first.
-- An open book, one anomaly per spread (Content.Journal list order):
--   cover   Ink CartoonPanel (thick outline, lip), pops in (Motion.Pop); `Size` 600 x 320 px at UI scale 1, UiScale.Fit
--           shrinks it to the smallest landscape phone
--   left    Cream page: the "photo" (white print, tilted, Images.luau or a dark placeholder), the name and the tag chip
--           (Refuse Mustard · Hide Teal · Lights Violet · Careful Green); a "NEW!" sticker while the page is unread
--   right   Cream page: SIGNS (what shows up), NOT THERE (what does not), HOW TO BEAT IT, short bullets in Ink
--   locked  a page not met yet: "???" on a dark photo, "???" title, Content.Journal.Rules.LockedText
--   nav     round Mustard arrows on the bottom corners (named "Prev" / "Next": gamepad selection), "3 / 19" between
--           them, the Teal close button on the top-right corner
-- Pure: only props. Texts come from Content.Journal (English, house palette, never red).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIScale and UIStroke are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Visible: () -> boolean,
	-- unlocked pages (Content.Journal key -> true)
	Pages: () -> { [string]: boolean },
	-- unlocked but not read yet ("NEW!" sticker); nil = none
	Fresh: (() -> { [string]: boolean })?,
	-- spread shown, 1..#Content.Journal.List
	Index: () -> number,
	OnTurn: (delta: number) -> (),
	OnClose: () -> (),
	Scale: (() -> number)?,
	-- small line under the book (e.g. "LB / RB to turn pages"); "" or nil = none
	Hint: (() -> string)?,
	-- image ids by page key; default Images.luau (stories may pass their own)
	Images: { [string]: string }?,
}

const BOOK = Vector2.new(600, 320)
const DESIGN = Vector2.new(640, 372) -- the book plus the buttons over its edges and the hint line
const PAD = 8
const SPINE = 8
const PAGE_PAD = 12
const PHOTO = Vector2.new(196, 148)
const ARROW = 44
const TEXT = 15
const HEADING = 16
const BULLETS = 2 -- slots per section (Content.Journal rows have at most 2)
const DIM = Color3.fromHex("#4A3D57") -- placeholder photo (Tone.Ink top)
const PAPER_LINE = Color3.fromHex("#E9CF9C")

const TAGS: { [string]: { Text: string, Tone: Theme.Tone } } = {
	Refuse = { Text = "REFUSE", Tone = Theme.Tone.Mustard },
	Hide = { Text = "HIDE", Tone = Theme.Tone.Teal },
	Lights = { Text = "LIGHTS", Tone = Theme.Tone.Violet },
	Careful = { Text = "CAREFUL", Tone = Theme.Tone.Green },
}

const pages = Content.Journal.List
const rules = Content.Journal.Rules

local function pageAt(index: number): Content.JournalPage
	return pages[math.clamp(index, 1, #pages)]
end

local function list(children: { any }, padding: number): { any }
	return {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, padding),
		}),
		children,
	}
end

-- One Cream page of the book (half the cover, minus the spine).
local function paper(name: string, side: number, children: { any }): Frame
	return CartoonPanel({
		Name = name,
		AnchorPoint = Vector2.new(side, 0),
		Position = UDim2.fromScale(side, 0),
		Size = UDim2.new(0.5, -SPINE / 2, 1, 0),
		Tone = Theme.Tone.Cream,
		Outline = Theme.Outline.Normal,
		Radius = Theme.Radius.Small,
		Lip = 0,
		Gloss = false,
		Padding = PAGE_PAD,
		Children = children,
	})
end

return function(props: Props): Frame
	const pop = Motion.Pop(props.Visible)
	const area = source(Vector2.zero)
	const scale = function(): number
		const base = if props.Scale then math.max(math.min(props.Scale(), UiScale.Current()), Theme.Scale.Min) else 1
		return UiScale.Fit(base, area(), DESIGN)
	end
	const images = props.Images or Images

	const current = function(): Content.JournalPage
		return pageAt(props.Index())
	end
	const open = function(): boolean
		return props.Pages()[current().Key] == true
	end
	const fresh = function(): boolean
		return open() and props.Fresh ~= nil and props.Fresh()[current().Key] == true
	end
	const image = function(): string
		return if open() then images[current().Key] or "" else ""
	end
	const tag = function()
		return TAGS[current().Tag] or TAGS.Careful
	end

	-- One section of the right page: heading + up to BULLETS lines from `field` of the page row.
	local function section(order: number, title: string, color: Color3, field: "Signs" | "Not" | "Fight"): Frame
		const bullets: { any } = {}
		for slot = 1, BULLETS do
			const line = function(): string
				return if open() then (current() :: any)[field][slot] or "" else ""
			end
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
					Text = function()
						return `• {line()}`
					end,
					Visible = function()
						return line() ~= ""
					end,
				})
			)
		end
		return create("Frame")({
			Name = title,
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = open,
			list({
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
		Rotation = function()
			return if props.Index() % 2 == 0 then 2.5 else -2.5
		end,
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Outline.Normal }),
		create("UICorner")({ CornerRadius = UDim.new(0, 4) }),
		create("Frame")({
			Name = "Print",
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -24),
			BackgroundColor3 = DIM,
			BorderSizePixel = 0,
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
				TextSize = 44,
				Color = Theme.Color.Mustard,
				Text = "?",
				Visible = function()
					return image() == ""
				end,
			}),
			CartoonLabel({
				Name = "Ref",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -4),
				TextSize = 14,
				Color = Theme.Color.Cream,
				Text = function()
					return if open() then Content.Anomalies.ByKey[current().Key].Ref else rules.LockedTitle
				end,
				Visible = function()
					return image() == ""
				end,
			}),
		}),
		-- tape on the top edge
		create("Frame")({
			Name = "Tape",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(56, 16),
			Rotation = 4,
			BackgroundColor3 = Theme.Color.Gold,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
		}),
		-- unread page
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

	const left = paper("Left", 0, list({
		photo,
		CartoonLabel({
			Name = "Title",
			LayoutOrder = 2,
			TextSize = 22,
			Color = Theme.Color.Dark,
			Stroke = 0,
			Text = function()
				return if open() then current().Title else rules.LockedTitle
			end,
			Box = UDim2.new(1, 0, 0, 30),
			Scaled = true,
			MaxTextSize = 22,
		}),
		CartoonPanel({
			Name = "Tag",
			LayoutOrder = 3,
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			Tone = function(): Theme.Tone
				return tag().Tone
			end,
			Outline = Theme.Outline.Normal,
			Radius = Theme.Radius.Pill,
			Lip = 3,
			Padding = { Left = 12, Right = 12 },
			Visible = open,
			Children = {
				CartoonLabel({
					TextSize = 15,
					Color = function()
						return tag().Tone.Text
					end,
					Stroke = function()
						return if tag().Tone.Stroke then 2 else 0
					end,
					Text = function()
						return tag().Text
					end,
				}),
			},
		}),
	}, 8))

	const right = paper("Right", 1, list({
		section(1, "SIGNS", Theme.Color.Teal, "Signs"),
		section(2, "NOT THERE", Theme.Color.Slate, "Not"),
		section(3, "HOW TO BEAT IT", Theme.Color.Green, "Fight"),
		CartoonLabel({
			Name = "Locked",
			LayoutOrder = 4,
			TextSize = 40,
			Color = Theme.Color.Dark,
			Stroke = 0,
			Text = rules.LockedTitle,
			Box = UDim2.new(1, 0, 0, 120),
			YAlignment = Enum.TextYAlignment.Bottom,
			Visible = function()
				return not open()
			end,
		}),
		CartoonLabel({
			Name = "LockedText",
			LayoutOrder = 5,
			TextSize = TEXT,
			Color = Theme.Color.Dark,
			Stroke = 0,
			Wrapped = true,
			Text = rules.LockedText,
			Box = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = function()
				return not open()
			end,
		}),
	}, 6))

	local function arrow(name: string, side: number, delta: number): any
		return CartoonButton({
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(side, 0, 1, -4),
			Size = UDim2.fromOffset(ARROW, ARROW),
			Icon = if delta < 0 then "Ui/arrow_left" else "Ui/arrow_right",
			IconSize = ARROW - 16,
			Tone = Theme.Tone.Mustard,
			Enabled = function()
				const index = props.Index()
				return if delta < 0 then index > 1 else index < #pages
			end,
			OnActivated = function()
				props.OnTurn(delta)
			end,
		})
	end

	const root = create("Frame")({
		Name = "AnomalyBook",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = true,
		Visible = props.Visible,

		CartoonPanel({
			Name = "Cover",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -10),
			Size = UDim2.fromOffset(BOOK.X, BOOK.Y),
			Tone = Theme.Tone.Ink,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Lip = 6,
			Gloss = false,
			Padding = PAD,
			Decor = {
				createRaw("UIScale")({
					Scale = function()
						return scale() * pop()
					end,
				}),
				-- buttons over the cover edges (outside the padded content, drawn over the pages)
				create("Frame")({
					Name = "Over",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ZIndex = 5,
					arrow("Prev", 0, -1),
					arrow("Next", 1, 1),
					CartoonButton({
						Name = "Close",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(1, -6, 0, 6),
						Size = UDim2.fromOffset(ARROW, ARROW),
						Icon = "Ui/close",
						IconSize = ARROW - 18,
						Tone = Theme.Tone.Teal,
						OnActivated = props.OnClose,
					}),
					CartoonPanel({
						Name = "Count",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 1, -2),
						Size = UDim2.fromOffset(0, 30),
						AutomaticSize = Enum.AutomaticSize.X,
						Tone = Theme.Tone.Ink,
						Outline = Theme.Outline.Normal,
						Radius = Theme.Radius.Pill,
						Lip = 2,
						Padding = { Left = 12, Right = 12 },
						Children = {
							CartoonLabel({
								TextSize = 15,
								Text = function()
									local found = 0
									for _, row in pages do
										if props.Pages()[row.Key] then
											found += 1
										end
									end
									return `{props.Index()} / {#pages}  ·  {found} found`
								end,
							}),
						},
					}),
					CartoonLabel({
						Name = "Hint",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 1, 22),
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
			Children = {
				left,
				-- the spine between the pages
				create("Frame")({
					Name = "Spine",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.new(0, 2, 1, 0),
					BackgroundColor3 = PAPER_LINE,
					BorderSizePixel = 0,
					ZIndex = 2,
				}),
				right,
			},
		}),
	}) :: Frame
	const measure = function()
		if root.AbsoluteSize.X > 0 then
			area(root.AbsoluteSize)
		end
	end
	const connection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
	cleanup(function()
		connection:Disconnect()
	end)
	return root
end
