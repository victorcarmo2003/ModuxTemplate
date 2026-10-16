--!strict
-- ShopPanel: the in-run Robux shop of the HUD cart (TASK-290; owner request 2026-10-14, Provisional), same window as the
-- SettingsPanel (LobbyWindow 600 x 310 at Scale 1, cartoon kit, mobile first).
--   Items view  one scrolling column of SECTIONS (owner request 2026-10-16: categories, so a kid sees what is what):
--               each `Categories` row is a header (line, icon, title, line) and a grid of its Cream cards (3 per row):
--               icon, name, one line, and the price button (Green "R$ 15"; Slate and a short note when not on sale now,
--               e.g. "Night only"). A section without cards is not shown. `Flash` = key of the card that blinks a
--               Mustard outline (the owner toggles it).
--   Pick view   when `Picking` holds a pick: a title ("Who do you want to scare?") and one Ink button per option, plus
--               Back. The owner sends the pick and prompts the purchase.
--   Footer      one Cream line (`Status`: "Coming soon", "Thanks!", ...; "" = none).
-- Texts in English; house palette only (never red). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local LobbyWindow = require(script.Parent.LobbyWindow)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and ScrollingFrame are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Card = {
	Key: string,
	Name: string,
	Text: string,
	Icon: string, -- Icons name
	Price: string, -- "R$ 15"
	Enabled: boolean,
	Note: string, -- "" or why it is off ("Night only")
	Category: string, -- a Categories key
	Tone: string, -- Theme.Tone name of the card background ("" / unknown = Cream)
}

export type Category = { Key: string, Title: string, Icon: string }

export type Option = { Id: number, Text: string }

export type Pick = { Title: string, Options: { Option } }

export type Props = {
	Visible: () -> boolean,
	Items: () -> { Card },
	-- sections in order (Content.Shop.Categories); a card whose Category is not listed goes in a last "More" section
	Categories: { Category },
	OnBuy: (key: string) -> (),
	Flash: (() -> string)?,
	-- false = items view
	Picking: (() -> Pick | false)?,
	OnPick: ((id: number) -> ())?,
	OnBack: (() -> ())?,
	Status: (() -> string)?,
	OnClose: () -> (),
	Scale: (() -> number)?,
}

const WIDTH = 600
const HEIGHT = 400 -- taller for the sections (was 310)
const HEADER = 30
const LINE = 3
const CELL = Vector2.new(184, 116)
const GAP = 8
const FOOTER = 22
const ICON = 40
const BUY_HEIGHT = 40 -- close to Theme.MinTouch; the window never scales under 1 on touch (UiScale.Fit aside)

local function card(entry: () -> Card, flash: () -> string, onBuy: (key: string) -> ()): Frame
	const rect = function(): Icons.Rect
		return Icons.Rect(entry().Icon) or { Offset = Vector2.zero, Size = Vector2.zero }
	end
	const tone = function(): Theme.Tone
		return (Theme.Tone :: any)[entry().Tone] or Theme.Tone.Cream
	end
	-- light surfaces (Cream, Mustard...) take Ink text without stroke; dark ones white text with the stroke
	const ink = function(): boolean
		return not tone().Stroke
	end
	return CartoonPanel({
		Name = "Card",
		Size = UDim2.fromOffset(CELL.X, CELL.Y),
		Tone = tone,
		Outline = Theme.Outline.Normal,
		OutlineColor = function()
			return if flash() == entry().Key then Theme.Color.Mustard else Theme.Color.Ink
		end,
		Radius = Theme.Radius.Chip,
		Gloss = false,
		Padding = 6,
		Decor = {
			createRaw("UIStroke")({
				Name = "Flash",
				Color = Theme.Color.Mustard,
				Thickness = 5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Enabled = function()
					return flash() == entry().Key
				end,
			}),
		},
		Children = {
			create("ImageLabel")({
				Name = "Icon",
				Size = UDim2.fromOffset(ICON, ICON),
				BackgroundTransparency = 1,
				Image = function()
					return Icons.ImageOf(entry().Icon)
				end,
				ImageRectOffset = function()
					return rect().Offset
				end,
				ImageRectSize = function()
					return rect().Size
				end,
			}),
			CartoonLabel({
				Name = "Title",
				Position = UDim2.fromOffset(ICON + 6, 0),
				TextSize = 16,
				Color = function()
					return if ink() then Theme.Color.Dark else Theme.Color.Text
				end,
				Stroke = function()
					return if ink() then 0 else 2
				end,
				Text = function()
					return entry().Name
				end,
				XAlignment = Enum.TextXAlignment.Left,
				Truncate = true,
				Box = UDim2.new(1, -(ICON + 6), 0, 20),
			}),
			CartoonLabel({
				Name = "Line",
				Position = UDim2.fromOffset(ICON + 6, 20),
				TextSize = 14,
				Color = function()
					return if ink() then Theme.Color.Dark else Theme.Color.Text
				end,
				Stroke = function()
					return if ink() then 0 else 2
				end,
				Wrapped = true,
				Text = function()
					return entry().Text
				end,
				XAlignment = Enum.TextXAlignment.Left,
				YAlignment = Enum.TextYAlignment.Top,
				Box = UDim2.new(1, -(ICON + 6), 0, 34),
			}),
			CartoonButton({
				Name = "Buy",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -2),
				Size = UDim2.new(1, -4, 0, BUY_HEIGHT),
				TextSize = 16,
				Outline = Theme.Outline.Normal,
				Tone = function()
					-- the Robux green, except on a green card
					return if entry().Tone == "Green" then Theme.Tone.Mustard else Theme.Tone.Green
				end,
				Enabled = function()
					return entry().Enabled
				end,
				Text = function()
					const value = entry()
					return if value.Note ~= "" then value.Note else value.Price
				end,
				OnActivated = function()
					onBuy(Vide.untrack(entry).Key)
				end,
			}),
		},
	}) :: Frame
end

return function(props: Props): Frame
	const flash = function(): string
		return if props.Flash then props.Flash() else ""
	end
	const picking = function(): Pick | false
		return if props.Picking then props.Picking() else false
	end
	const pickOptions = function(): { Option }
		const pick = picking()
		return if pick then pick.Options else {}
	end
	const status = function(): string
		return if props.Status then props.Status() else ""
	end

	-- Section rows: the given categories, then "More" for any card with an unknown category
	const sections = function(): { Category }
		const known: { [string]: boolean } = {}
		for _, category in props.Categories do
			known[category.Key] = true
		end
		const out = table.clone(props.Categories)
		for _, entry in props.Items() do
			if not known[entry.Category] then
				table.insert(out, { Key = entry.Category, Title = "More", Icon = "" })
				known[entry.Category] = true
			end
		end
		return out
	end

	local function header(category: () -> Category): Frame
		const rect = function(): Icons.Rect
			return Icons.Rect(category().Icon) or { Offset = Vector2.zero, Size = Vector2.zero }
		end
		const line = function(name: string, order: number): Frame
			return create("Frame")({
				Name = name,
				LayoutOrder = order,
				Size = UDim2.new(0.5, -90, 0, LINE),
				BackgroundColor3 = Theme.Color.Cream,
				BorderSizePixel = 0,
				create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			}) :: Frame
		end
		return create("Frame")({
			Name = "Header",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, HEADER),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			line("LineLeft", 1),
			create("ImageLabel")({
				Name = "Icon",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(HEADER - 2, HEADER - 2),
				BackgroundTransparency = 1,
				Visible = function()
					return Icons.Has(category().Icon)
				end,
				Image = function()
					return Icons.ImageOf(category().Icon)
				end,
				ImageRectOffset = function()
					return rect().Offset
				end,
				ImageRectSize = function()
					return rect().Size
				end,
			}),
			CartoonLabel({
				Name = "Title",
				LayoutOrder = 3,
				TextSize = 20,
				Color = Theme.Color.Mustard,
				Text = function()
					return category().Title
				end,
			}),
			line("LineRight", 4),
		}) :: Frame
	end

	const grid = createRaw("ScrollingFrame")({
		Name = "Items",
		Size = UDim2.new(1, 0, 1, -(FOOTER + 4)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.Cream,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = function()
			return picking() == false
		end,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
		createRaw("UIPadding")({ PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }),
		indexes(sections, function(category: () -> Category, index: number)
			const cards = function(): { Card }
				const key = category().Key
				const out: { Card } = {}
				for _, entry in props.Items() do
					if entry.Category == key then
						table.insert(out, entry)
					end
				end
				return out
			end
			return create("Frame")({
				Name = "Section",
				LayoutOrder = index,
				Size = UDim2.new(1, -12, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = function()
					return #cards() > 0
				end,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				header(category),
				create("Frame")({
					Name = "Cards",
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					create("UIGridLayout")({
						CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
						CellPadding = UDim2.fromOffset(GAP, GAP),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					indexes(cards, function(entry: () -> Card, order: number)
						const made = card(entry, flash, props.OnBuy)
						made.LayoutOrder = order
						return made
					end),
				}),
			})
		end),
	})

	const pickView = create("Frame")({
		Name = "Pick",
		Size = UDim2.new(1, 0, 1, -(FOOTER + 4)),
		BackgroundTransparency = 1,
		Visible = function()
			return picking() ~= false
		end,
		CartoonLabel({
			Name = "Title",
			TextSize = 20,
			Color = Theme.Color.Mustard,
			Text = function()
				const pick = picking()
				return if pick then pick.Title else ""
			end,
			XAlignment = Enum.TextXAlignment.Left,
			Box = UDim2.new(1, -110, 0, Theme.MinTouch),
		}),
		CartoonButton({
			Name = "Back",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(100, Theme.MinTouch),
			TextSize = 16,
			Tone = Theme.Tone.Teal,
			Text = "Back",
			OnActivated = function()
				if props.OnBack then
					props.OnBack()
				end
			end,
		}),
		createRaw("ScrollingFrame")({
			Name = "Options",
			Position = UDim2.fromOffset(0, Theme.MinTouch + 8),
			Size = UDim2.new(1, 0, 1, -(Theme.MinTouch + 8)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Color.Cream,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			create("UIGridLayout")({
				CellSize = UDim2.fromOffset(CELL.X, Theme.MinTouch),
				CellPadding = UDim2.fromOffset(GAP, GAP),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			createRaw("UIPadding")({ PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
			indexes(pickOptions, function(option: () -> Option, index: number)
				return CartoonButton({
					Name = "Option",
					LayoutOrder = index,
					Size = UDim2.fromOffset(CELL.X, Theme.MinTouch),
					TextSize = 16,
					Tone = Theme.Tone.Ink,
					Text = function()
						return option().Text
					end,
					OnActivated = function()
						if props.OnPick then
							props.OnPick(Vide.untrack(option).Id)
						end
					end,
				})
			end),
		}),
	})

	return LobbyWindow({
		Name = "ShopPanel",
		Title = "Shop",
		Icon = "Ui/cash",
		Size = Vector2.new(WIDTH, HEIGHT),
		Visible = props.Visible,
		Scale = props.Scale,
		OnClose = props.OnClose,
		Rays = true, -- retro rays spinning behind the cards (owner request 2026-10-15)
		Children = {
			grid,
			pickView,
			CartoonLabel({
				Name = "Status",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				TextSize = 14,
				Color = Theme.Color.Cream,
				Text = function()
					const text = status()
					return if text ~= "" then text else "Prices in Robux. Purchases go to you or your crew."
				end,
				XAlignment = Enum.TextXAlignment.Left,
				Box = UDim2.new(1, 0, 0, FOOTER),
			}),
		},
	})
end
