--!strict
-- ShopPanel: the in-run Robux shop of the HUD cart (TASK-290; owner request 2026-10-14, Provisional), same window as the
-- SettingsPanel (LobbyWindow 600 x 310 at Scale 1, cartoon kit, mobile first).
--   Items view  a scrolling grid of Cream cards (3 per row): icon, name, one line, and the price button (Green
--               "R$ 15"; Slate and a short note when not on sale now, e.g. "Night only"). `Flash` = key of the card that
--               blinks a Mustard outline (the owner toggles it).
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
}

export type Option = { Id: number, Text: string }

export type Pick = { Title: string, Options: { Option } }

export type Props = {
	Visible: () -> boolean,
	Items: () -> { Card },
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
const HEIGHT = 310
const CELL = Vector2.new(184, 116)
const GAP = 8
const FOOTER = 22
const ICON = 40
const BUY_HEIGHT = 40 -- close to Theme.MinTouch; the window never scales under 1 on touch (UiScale.Fit aside)

local function card(entry: () -> Card, flash: () -> string, onBuy: (key: string) -> ()): Frame
	const rect = function(): Icons.Rect
		return Icons.Rect(entry().Icon) or { Offset = Vector2.zero, Size = Vector2.zero }
	end
	return CartoonPanel({
		Name = "Card",
		Size = UDim2.fromOffset(CELL.X, CELL.Y),
		Tone = Theme.Tone.Cream,
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
				Color = Theme.Color.Dark,
				Stroke = 0,
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
				Color = Theme.Color.Dark,
				Stroke = 0,
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
				Tone = Theme.Tone.Green,
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
		create("UIGridLayout")({
			CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		createRaw("UIPadding")({ PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
		indexes(props.Items, function(entry: () -> Card, index: number)
			const made = card(entry, flash, props.OnBuy)
			made.LayoutOrder = index
			return made
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
