--!strict
-- GemShop: the lobby gem shop (user request 2026-10-11; Content.Shop.GemPacks), cartoon kit (AST-091), mobile first.
-- Promotion pass (TASK-301, owner request 2026-10-15): a LobbyWindow (640 x 360 at Scale 1, shrinks to fit a phone)
-- with one card per pack in a row:
--   ribbon    "BEST VALUE" (Mustard) / "POPULAR" (Violet) over the top edge (Pack.Badge)
--   chip      "+30%" tilted in the top-left corner (Bonus / Base), only with a bonus
--   art       the pack image (GemShop/Images; Hud/gem until uploaded), bigger for bigger packs
--   total     gem icon + "700" (what the receipt credits, Pack.Gems)
--   split     "500" + Green "+200 BONUS" pill; the pack name when there is no bonus
--   buy       Green "R$ 899" button (live Creator Hub price when known); Slate "Soon" for a product not created
-- The "Best" card is vivid blue with studs, a shine sweeping across it, twinkling sparkles around the art and a slow
-- pulse; the others are a muted slate blue with studs and no motion. Motion.Reduced: no shine, no pulse, sparkles
-- still (checked twice a second, the setting can change while the shop is open). The clock only runs while visible.
-- Base / Bonus / Badge are display only (Base + Bonus == Gems); a Pack without them reads Content.Shop.GemPacks.
-- Pure: only props; the caller prompts the purchase (MarketplaceService:PromptProductPurchase) and the server credits
-- the gems on the receipt. Gamepad: every Buy button is Selectable (LobbyController selects the first "Buy").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local LobbyWindow = require(script.Parent.LobbyWindow)
local Icon = require(script.Parent.LobbyWindow.Icon)
local Images = require(script.Images)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale and UIGradient are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Badge = "Popular" | "Best"

export type Pack = {
	Key: string,
	Name: string,
	Gems: number,
	Robux: number, -- price shown (Creator Hub price when known, else the suggested one)
	Available: boolean, -- product created (ProductId > 0)
	-- Display split (Base + Bonus == Gems) and ribbon; nil = read from Content.Shop.GemPacks by Key.
	Base: number?,
	Bonus: number?,
	Badge: Badge?,
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

const WIDTH = 640
const HEIGHT = 360
const GAP = 10
const TOP = 14 -- room over the cards for the ribbons
const BUTTON = 44
const PAD = 8

-- Card surfaces: the highlighted pack is vivid blue, the others a muted slate blue (never the alert red).
const VIVID: Theme.Tone = {
	Top = Color3.fromHex("#7CCBFF"),
	Bottom = Color3.fromHex("#2C86F2"),
	Lip = Color3.fromHex("#1B4FAA"),
	Text = Color3.new(1, 1, 1),
	Stroke = true,
}
const MUTED: Theme.Tone = {
	Top = Color3.fromHex("#76809A"),
	Bottom = Color3.fromHex("#59627A"),
	Lip = Color3.fromHex("#383E50"),
	Text = Color3.new(1, 1, 1),
	Stroke = true,
}
const GOLD = Color3.fromHex("#FFE27A")

-- Shine sweep: SWEEP s across the card, then a pause, every PERIOD s.
const SWEEP = 0.9
const PERIOD = 2.8
const PULSE = 0.025 -- scale amplitude of the highlighted card
const CHECK = 0.5 -- s between two reads of Motion.Reduced

-- Sparkles around the art of the highlighted card: position (scale of the art frame), px size, phase.
const SPARKLES: { { number } } = {
	{ 0.14, 0.18, 18, 0 },
	{ 0.86, 0.12, 14, 1.7 },
	{ 0.9, 0.78, 16, 3.1 },
	{ 0.1, 0.82, 12, 4.4 },
}

type Display = { Base: number, Bonus: number, Badge: Badge? }

local function display(pack: Pack): Display
	const data = Content.Shop.GemPacks.ByKey[pack.Key]
	const base = pack.Base or (if data then data.Base else pack.Gems)
	const bonus = pack.Bonus or (if data then data.Bonus else 0)
	const badge: Badge? = pack.Badge or (if data then data.Badge else nil)
	return { Base = base, Bonus = bonus, Badge = badge }
end

-- Pack image, or the sheet gem while the pack art is not uploaded.
local function art(key: string, size: number): Instance
	const image = Images[key]
	if image == nil then
		return Icon("Hud/gem", size, 1)
	end
	return create("ImageLabel")({
		Name = "Art",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
	})
end

-- One twinkling star (Ui/sparkle): grows, turns and fades with the clock; still with reduced motion.
local function sparkle(spec: { number }, clock: () -> number, calm: () -> boolean): Instance
	const name = "Ui/sparkle"
	const rect = Icons.Rect(name)
	const size, phase = spec[3], spec[4]
	const wave = function(): number
		return if calm() then 0.85 else 0.5 + 0.5 * math.sin(clock() * 2.6 + phase)
	end
	return create("ImageLabel")({
		Name = "Sparkle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(spec[1], spec[2]),
		Size = function()
			const s = math.floor(size * (0.45 + 0.55 * wave()))
			return UDim2.fromOffset(s, s)
		end,
		Rotation = function()
			return if calm() then 0 else clock() * 45 + phase * 30
		end,
		BackgroundTransparency = 1,
		ImageColor3 = GOLD,
		ImageTransparency = function()
			return 0.6 * (1 - wave())
		end,
		Image = Icons.ImageOf(name),
		ImageRectOffset = if rect then rect.Offset else Vector2.zero,
		ImageRectSize = if rect then rect.Size else Vector2.zero,
		Visible = Icons.Has(name),
		ZIndex = 2,
	})
end

-- White band sweeping across the face (UIGradient offset: follows the round corners, no clipping needed).
local function shine(clock: () -> number, calm: () -> boolean): Instance
	return create("Frame")({
		Name = "Shine",
		Size = UDim2.new(1, 0, 1, -Theme.Lip),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Visible = function()
			return not calm()
		end,
		ZIndex = 1,
		create("UICorner")({ CornerRadius = Theme.Radius.Card }),
		createRaw("UIGradient")({
			Rotation = 20,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.4, 1),
				NumberSequenceKeypoint.new(0.48, 0.6),
				NumberSequenceKeypoint.new(0.52, 0.6),
				NumberSequenceKeypoint.new(0.6, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Offset = function()
				const t = clock() % PERIOD
				const x = if t < SWEEP then -1.2 + 2.4 * (t / SWEEP) else 1.2
				return Vector2.new(x, 0)
			end,
		}),
	})
end

-- Tilted ribbon over the top edge.
local function ribbon(text: string, tone: Theme.Tone, scale: (() -> number)?): Instance
	return CartoonPanel({
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = -4,
		Tone = tone,
		Lip = 3,
		Outline = Theme.Outline.Normal,
		Padding = { Left = 10, Right = 10 },
		ZIndex = 3,
		Decor = if scale
			then {
				createRaw("UIScale")({ Scale = scale }),
			}
			else nil,
		Children = {
			CartoonLabel({
				Box = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				TextSize = 16,
				Color = tone.Text,
				Stroke = if tone.Stroke then nil else 0,
				Text = text,
			}),
		},
	})
end

return function(props: Props): Frame
	const count = math.max(#props.Packs, 1)
	const cardWidth = math.floor((WIDTH - 20 - GAP * (count - 1)) / count)
	const inner = cardWidth - PAD * 2
	const busy = function(): boolean
		return props.Busy ~= nil and props.Busy()
	end

	-- Animation clock (s) of the highlighted card; runs only while the shop is open and motion is allowed.
	const clock = source(0)
	const calm = source(Motion.Reduced())
	local elapsed = 0
	local sinceCheck = 0
	const connection = RunService.Heartbeat:Connect(function(dt: number)
		if not untrack(props.Visible) then
			return
		end
		sinceCheck += dt
		if sinceCheck >= CHECK then
			sinceCheck = 0
			const reduced = Motion.Reduced()
			if reduced ~= untrack(calm) then
				calm(reduced)
			end
		end
		if untrack(calm) then
			return
		end
		elapsed += dt
		clock(elapsed)
	end)
	cleanup(function()
		connection:Disconnect()
	end)
	const pulse = function(): number
		return if calm() then 1 else 1 + PULSE * math.sin(clock() * 3)
	end

	const cards: { Instance } = {}
	for index, pack in props.Packs do
		const info = display(pack)
		const best = info.Badge == "Best"
		const iconSize = math.min(68 + index * 8, inner - 8)
		const price = function(): number
			const live = if props.PriceOf then props.PriceOf(pack.Key) else nil
			return live or pack.Robux
		end
		const percent = if info.Base > 0 then math.floor(info.Bonus / info.Base * 100 + 0.5) else 0

		const artChildren: { any } = {
			create("UIListLayout")({
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			art(pack.Key, iconSize),
		}
		const sparkles: { Instance } = {}
		if best then
			for _, spec in SPARKLES do
				table.insert(sparkles, sparkle(spec, clock, calm))
			end
		end

		-- "500 + 200 BONUS" or, without a bonus, the pack name
		const split: { any } = if info.Bonus > 0
			then {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				CartoonLabel({
					Name = "Base",
					LayoutOrder = 1,
					TextSize = 16,
					Transparency = 0.1,
					Text = tostring(info.Base),
				}),
				CartoonPanel({
					Name = "Bonus",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(0, 24),
					AutomaticSize = Enum.AutomaticSize.X,
					Tone = Theme.Tone.Green,
					Lip = 2,
					Outline = 2,
					Gloss = false,
					Padding = { Left = 6, Right = 6 },
					Children = {
						CartoonLabel({
							Box = UDim2.new(0, 0, 1, -2),
							AutomaticSize = Enum.AutomaticSize.X,
							TextSize = Theme.MinTextSize,
							Text = `+{info.Bonus} BONUS`,
						}),
					},
				}),
			}
			else {
				CartoonLabel({
					Name = "Title",
					Box = UDim2.fromScale(1, 1),
					TextSize = Theme.MinTextSize,
					Transparency = 0.15,
					Truncate = true,
					Text = pack.Name,
				}),
			}

		const children: { any } = {
			create("Frame")({
				Name = "Stack",
				Size = UDim2.new(1, 0, 1, -(BUTTON + 4)),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				create("Frame")({
					Name = "Art",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(inner, 100),
					BackgroundTransparency = 1,
					artChildren,
					sparkles,
				}),
				create("Frame")({
					Name = "Total",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(inner, 32),
					BackgroundTransparency = 1,
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 2),
					}),
					Icon("Hud/gem", 28, 1),
					CartoonLabel({
						Name = "Amount",
						LayoutOrder = 2,
						TextSize = if best then 32 else 28,
						Color = if best then GOLD else Color3.new(1, 1, 1),
						Text = tostring(pack.Gems),
					}),
				}),
				create("Frame")({
					Name = "Split",
					LayoutOrder = 3,
					Size = UDim2.fromOffset(inner, 26),
					BackgroundTransparency = 1,
					split,
				}),
			}),
			CartoonButton({
				Name = "Buy",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, BUTTON),
				TextSize = 20,
				Outline = Theme.Outline.Thick,
				Tone = if best then Theme.Tone.Mustard else Theme.Tone.Green,
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
		}

		if percent > 0 then
			table.insert(
				children,
				CartoonPanel({
					Name = "Percent",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(10, 12),
					Size = UDim2.fromOffset(0, 26),
					AutomaticSize = Enum.AutomaticSize.X,
					Rotation = -10,
					Tone = Theme.Tone.Green,
					Lip = 2,
					Outline = Theme.Outline.Normal,
					Padding = { Left = 6, Right = 6 },
					ZIndex = 3,
					Children = {
						CartoonLabel({
							Box = UDim2.new(0, 0, 1, -2),
							AutomaticSize = Enum.AutomaticSize.X,
							TextSize = 16,
							Text = `+{percent}%`,
						}),
					},
				})
			)
		end
		if info.Badge == "Best" then
			table.insert(children, ribbon("BEST VALUE", Theme.Tone.Mustard, pulse))
		elseif info.Badge == "Popular" then
			table.insert(children, ribbon("POPULAR", Theme.Tone.Violet, nil))
		end

		table.insert(
			cards,
			CartoonPanel({
				Name = pack.Key,
				LayoutOrder = index,
				Size = UDim2.new(0, cardWidth, 1, 0),
				Tone = if best then VIVID else MUTED,
				Outline = Theme.Outline.Thick,
				Radius = Theme.Radius.Card,
				Studs = true,
				Padding = PAD,
				Decor = if best
					then {
						createRaw("UIScale")({ Scale = pulse }),
						shine(clock, calm),
					}
					else nil,
				Children = children,
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
				Position = UDim2.fromOffset(0, TOP),
				Size = UDim2.new(1, 0, 1, -TOP),
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
