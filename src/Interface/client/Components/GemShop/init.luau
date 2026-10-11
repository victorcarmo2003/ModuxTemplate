--!strict
-- GemShop: the lobby gem shop (user request 2026-10-11; Content.Shop.GemPacks), cartoon kit (AST-091), mobile first.
-- A LobbyWindow (560 x 320 at Scale 1) with one Cream card per pack in a row: gem icon (bigger for bigger packs),
-- "+130", pack name, a "Best value" tag on the cheapest gem, and a Green "R$ 229" button. A pack whose product is not
-- created yet (ProductId 0) shows a Slate "Soon" button. Pure: only props; the caller prompts the purchase
-- (MarketplaceService:PromptProductPurchase) and the server credits the gems on the receipt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local LobbyWindow = require(script.Parent.LobbyWindow)
local Icon = require(script.Parent.LobbyWindow.Icon)

const create = Vide.create

export type Pack = {
	Key: string,
	Name: string,
	Gems: number,
	Robux: number, -- price shown (Creator Hub price when known, else the suggested one)
	Available: boolean, -- product created (ProductId > 0)
}

export type Props = {
	Packs: { Pack },
	Visible: () -> boolean,
	Gems: () -> number,
	-- Live price per pack (GetProductInfo); nil = Pack.Robux.
	PriceOf: ((key: string) -> number?)?,
	-- A purchase prompt is open: the buttons wait.
	Busy: (() -> boolean)?,
	OnBuy: (key: string) -> (),
	OnClose: () -> (),
	Scale: (() -> number)?,
}

const WIDTH = 560
const HEIGHT = 320
const GAP = 8
const BUTTON = 44

local function bestValue(packs: { Pack }): string?
	local best: string? = nil
	local rate = math.huge
	for _, pack in packs do
		if pack.Gems > 0 and pack.Robux / pack.Gems < rate then
			rate = pack.Robux / pack.Gems
			best = pack.Key
		end
	end
	return if #packs > 1 then best else nil
end

return function(props: Props): Frame
	const best = bestValue(props.Packs)
	const count = math.max(#props.Packs, 1)
	const cardWidth = math.floor((WIDTH - 20 - GAP * (count - 1)) / count)
	const busy = function(): boolean
		return props.Busy ~= nil and props.Busy()
	end

	const cards: { Instance } = {}
	for index, pack in props.Packs do
		const iconSize = math.min(40 + index * 8, 72)
		const price = function(): number
			const live = if props.PriceOf then props.PriceOf(pack.Key) else nil
			return live or pack.Robux
		end
		table.insert(
			cards,
			CartoonPanel({
				Name = pack.Key,
				LayoutOrder = index,
				Size = UDim2.new(0, cardWidth, 1, 0),
				Tone = Theme.Tone.Cream,
				Outline = Theme.Outline.Thick,
				Radius = Theme.Radius.Card,
				Padding = 8,
				Children = {
					create("Frame")({
						Name = "Stack",
						Size = UDim2.new(1, 0, 1, -(BUTTON + 4)),
						BackgroundTransparency = 1,
						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 2),
						}),
						create("Frame")({
							Name = "Art",
							LayoutOrder = 1,
							Size = UDim2.fromOffset(cardWidth - 16, 76),
							BackgroundTransparency = 1,
							create("UIListLayout")({
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							Icon("Hud/gem", iconSize, 1),
						}),
						CartoonLabel({
							Name = "Amount",
							LayoutOrder = 2,
							TextSize = 26,
							Color = Theme.Color.Dark,
							Stroke = 0,
							Text = `+{pack.Gems}`,
						}),
						CartoonLabel({
							Name = "Title",
							LayoutOrder = 3,
							Box = UDim2.fromOffset(cardWidth - 16, 36),
							TextSize = Theme.MinTextSize,
							Wrapped = true,
							Color = Theme.Color.Dark,
							Stroke = 0,
							Transparency = 0.25,
							Text = pack.Name,
						}),
					}),
					-- "Best value" tag over the top edge
					CartoonPanel({
						Name = "Best",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 0, -6),
						Size = UDim2.fromOffset(0, 24),
						AutomaticSize = Enum.AutomaticSize.X,
						Rotation = -4,
						Tone = Theme.Tone.Violet,
						Lip = 2,
						Outline = 2,
						Padding = { Left = 8, Right = 8 },
						Visible = best == pack.Key,
						Children = {
							CartoonLabel({
								Box = UDim2.new(0, 0, 1, 0),
								AutomaticSize = Enum.AutomaticSize.X,
								TextSize = Theme.MinTextSize,
								Text = "Best value",
							}),
						},
					}),
					CartoonButton({
						Name = "Buy",
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.fromScale(0.5, 1),
						Size = UDim2.new(1, 0, 0, BUTTON),
						TextSize = 18,
						Outline = Theme.Outline.Thick,
						Tone = Theme.Tone.Green,
						Enabled = function()
							return pack.Available and not busy()
						end,
						Text = function()
							if not pack.Available then
								return "Soon"
							end
							return if busy() then "..." else `R$ {price()}`
						end,
						OnActivated = function()
							props.OnBuy(pack.Key)
						end,
					}),
				},
			})
		)
	end

	return LobbyWindow({
		Name = "GemShop",
		Title = "Gem Shop",
		Icon = "Hud/gem",
		Size = Vector2.new(WIDTH, HEIGHT),
		Visible = props.Visible,
		Scale = props.Scale,
		Gems = props.Gems,
		OnClose = props.OnClose,
		Children = {
			create("Frame")({
				Name = "Packs",
				Position = UDim2.fromOffset(0, 10),
				Size = UDim2.new(1, 0, 1, -10),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, GAP),
				}),
				cards,
			}),
		},
	})
end
