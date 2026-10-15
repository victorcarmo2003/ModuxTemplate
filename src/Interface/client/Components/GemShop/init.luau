--!strict
-- GemShop: the lobby gem shop (user request 2026-10-11; Content.Shop.GemPacks), cartoon kit (AST-091), mobile first.
-- Promotion pass (TASK-301, owner request 2026-10-15): a LobbyWindow (640 x 360 at Scale 1, shrinks to fit a phone)
-- with one card per pack in a row:
--   ribbon    "BEST VALUE" (Mustard) / "POPULAR" (Violet) over the top edge (Pack.Badge)
--   art       the pack gems filling the top of the card (GemShop/Images: shop/art, no tile, no number; Hud/gem until
--             uploaded) over the retro rays spinning slowly (Sunburst; owner request 2026-10-15, no "+30%" chip anymore)
--   total     gem icon + "10,000" (what the receipt credits, Pack.Gems)
--   split     Green "200 BONUS" pill (only the bonus, TASK-307); the pack name when there is no bonus
--   price     Green "R$ 899" pill (live Creator Hub price when known); Slate "Soon" for a product not created
-- The whole card is the button (TASK-307, better for kids): a transparent TextButton "Buy" per slot, a click or tap
-- anywhere on it calls OnBuy; the price pill is only its face. Hovered (mouse or gamepad selection) a card pops from
-- its centre (UIScale on a centred card inside a fixed slot, the list layout never moves) and gets the shine sweep.
-- The "Best" card is vivid blue with studs, the shine sweeping on its own, white stars bursting around the art and a
-- slow pulse; the others are a muted slate blue with studs and no motion until hovered. Motion.Reduced: no pop, no
-- pulse, stars still, a hovered card shows a still shine band (checked twice a second, the setting can change while the
-- shop is open). The clock only runs while visible.
-- Base / Bonus / Badge are display only (Base + Bonus == Gems); a Pack without them reads Content.Shop.GemPacks.
-- Pure: only props; the caller prompts the purchase (MarketplaceService:PromptProductPurchase) and the server credits
-- the gems on the receipt. Gamepad: every card button "Buy" is Selectable (LobbyController selects the first "Buy").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local LobbyWindow = require(script.Parent.LobbyWindow)
local Icon = require(script.Parent.LobbyWindow.Icon)
local Sunburst = require(script.Parent.Sunburst)
local Images = require(script.Images)
local Count = require(script.Parent.HudPill.Count)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
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
	-- A purchase prompt is open: the cards wait.
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
const ART = 104 -- height of the art area at the top of the card (the full inner width)

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
const HOVER = 1.06 -- scale of a hovered card
const PRESS = 0.97 -- scale of a pressed card
const CHECK = 0.5 -- s between two reads of Motion.Reduced

-- White stars bursting around the art of the highlighted card: px size, period (s), phase (s). Each cycle a star pops
-- (0 -> overshoot), shrinks away and waits; every cycle it lands somewhere else on the art.
const STARS: { { number } } = {
	{ 22, 1.9, 0 },
	{ 16, 2.3, 0.7 },
	{ 18, 2.1, 1.3 },
	{ 14, 2.6, 0.4 },
	{ 20, 2.4, 1.8 },
}
-- Where the stars rest with reduced motion (scale of the art frame).
const STILL: { Vector2 } = {
	Vector2.new(0.14, 0.18),
	Vector2.new(0.86, 0.14),
	Vector2.new(0.9, 0.8),
	Vector2.new(0.1, 0.82),
	Vector2.new(0.5, 0.08),
}
const GROW = 0.16 -- share of the cycle popping in (0 -> overshoot)
const FADE = 0.42 -- share of the cycle after which the star is gone until the next one
const SETTLE = 1.15 * math.sin(math.pi * 0.62) -- star scale at the end of the pop, where it starts shrinking

type Display = { Bonus: number, Badge: Badge? }

local function display(pack: Pack): Display
	const data = Content.Shop.GemPacks.ByKey[pack.Key]
	const bonus = pack.Bonus or (if data then data.Bonus else 0)
	const badge: Badge? = pack.Badge or (if data then data.Badge else nil)
	return { Bonus = bonus, Badge = badge }
end

-- Pack gems filling the art area (centred, Fit), or the sheet gem while the pack art is not uploaded.
local function art(key: string): Instance
	const image = Images[key]
	if image == nil then
		return create("Frame")({
			Name = "Image",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 1,
			create("UIListLayout")({
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Icon("Hud/gem", ART - 24, 1),
		})
	end
	return create("ImageLabel")({
		Name = "Image",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 1,
	})
end

-- 0..1 noise from two numbers (the spot of a star in one cycle).
local function hash(a: number, b: number): number
	const x = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- Ray of a star: a white bar fading at both ends.
local function ray(length: number, thick: number, rotation: number): Instance
	return create("Frame")({
		Name = "Ray",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(length, 0, 0, thick),
		Rotation = rotation,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIGradient")({
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

-- One white star burst (drawn, no image): pops 0 -> overshoot, shrinks away, waits, then pops at another spot of the
-- art. Reduced motion: still at its STILL spot.
local function star(index: number, clock: () -> number, calm: () -> boolean): Instance
	const spec = STARS[index]
	const size, period, phase = spec[1], spec[2], spec[3]
	const cycle = function(): (number, number)
		const t = (clock() + phase) / period
		const n = math.floor(t)
		return n, t - n
	end
	const scale = function(): number
		if calm() then
			return 0.8
		end
		const _, u = cycle()
		if u < GROW then
			-- sine arc past its top: 0 -> 1.15 (overshoot) -> SETTLE at the end of the pop
			return 1.15 * math.sin((u / GROW) * math.pi * 0.62)
		elseif u < FADE then
			const v = (u - GROW) / (FADE - GROW)
			return SETTLE * (1 - v * v)
		end
		return 0
	end
	return create("Frame")({
		Name = "Star",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function()
			if calm() then
				const spot = STILL[index]
				return UDim2.fromScale(spot.X, spot.Y)
			end
			const n = cycle()
			return UDim2.fromScale(0.1 + 0.8 * hash(n, index), 0.1 + 0.8 * hash(index, n + 0.5))
		end,
		Size = function()
			const s = math.floor(size * scale() + 0.5)
			return UDim2.fromOffset(s, s)
		end,
		Rotation = function()
			return if calm() then 0 else clock() * 60 + index * 25
		end,
		Visible = function()
			return scale() > 0.02
		end,
		BackgroundTransparency = 1,
		ZIndex = 2,
		create("Frame")({
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.5,
			ZIndex = 2,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),
		ray(1, 3, 0),
		ray(1, 3, 90),
		ray(0.6, 2, 45),
		ray(0.6, 2, -45),
	})
end

-- White band sweeping across the face (UIGradient offset: follows the round corners, no clipping needed). `origin` is
-- the clock time the sweep counts from (the hover start); reduced motion: a still band across the middle.
local function shine(clock: () -> number, calm: () -> boolean, visible: () -> boolean, origin: () -> number): Instance
	return create("Frame")({
		Name = "Shine",
		Size = UDim2.new(1, 0, 1, -Theme.Lip),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Visible = visible,
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
				if calm() then
					return Vector2.zero
				end
				const t = (clock() - origin()) % PERIOD
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

	-- Animation clock (s) of the cards; runs only while the shop is open and motion is allowed.
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
		const price = function(): number
			const live = if props.PriceOf then props.PriceOf(pack.Key) else nil
			return live or pack.Robux
		end
		const enabled = function(): boolean
			return pack.Available and not busy()
		end

		-- Hover (mouse or gamepad selection) and press of the whole card. Only a product that exists reacts.
		const hovered = source(false)
		const pressed = source(false)
		const since = source(0) -- clock at the hover start: the shine sweeps from there
		const lit = function(): boolean
			return pack.Available and hovered()
		end
		const hover = function(on: boolean)
			if on and not untrack(hovered) then
				since(untrack(clock) - SWEEP * 0.1)
			end
			hovered(on)
			if not on then
				pressed(false)
			end
		end
		const pop = spring(function()
			if pressed() and enabled() then
				return PRESS
			end
			return if lit() then HOVER else 1
		end, Theme.Motion.Press, 0.5)
		const scale = function(): number
			if calm() then
				return 1
			end
			return math.max(pop(), 0) * (if best then pulse() else 1)
		end
		const shining = function(): boolean
			return lit() or (best and not calm())
		end
		const origin = function(): number
			return if lit() then since() else 0
		end

		const tone = function(): Theme.Tone
			if not pack.Available then
				return Theme.Tone.Slate
			end
			return if best then Theme.Tone.Mustard else Theme.Tone.Green
		end

		const artChildren: { any } = {
			create("UICorner")({ CornerRadius = Theme.Radius.Chip }),
			Sunburst({ Visible = props.Visible, Transparency = 0.72, ZIndex = 0 }),
			art(pack.Key),
		}
		const stars: { Instance } = {}
		if best then
			for i = 1, #STARS do
				table.insert(stars, star(i, clock, calm))
			end
		end

		-- "200 BONUS" (only the bonus) or, without a bonus, the pack name
		const split: { any } = if info.Bonus > 0
			then {
				create("UIListLayout")({
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				CartoonPanel({
					Name = "Bonus",
					Size = UDim2.fromOffset(0, 24),
					AutomaticSize = Enum.AutomaticSize.X,
					Tone = Theme.Tone.Green,
					Lip = 2,
					Outline = 2,
					Gloss = false,
					Padding = { Left = 8, Right = 8 },
					Children = {
						CartoonLabel({
							Box = UDim2.new(0, 0, 1, -2),
							AutomaticSize = Enum.AutomaticSize.X,
							TextSize = Theme.MinTextSize,
							Text = `{Count(info.Bonus)} BONUS`,
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
					Size = UDim2.fromOffset(inner, ART),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0.88,
					artChildren,
					stars,
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
						Text = Count(pack.Gems),
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
			-- the face of the card button: looks like the old Buy button, the whole card takes the click
			CartoonPanel({
				Name = "Price",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, BUTTON),
				Tone = tone,
				Outline = Theme.Outline.Thick,
				Radius = Theme.Radius.Pill,
				Children = {
					CartoonLabel({
						Box = UDim2.fromScale(1, 1),
						TextSize = 20,
						Color = function()
							return tone().Text
						end,
						Stroke = function()
							return if tone().Stroke then Theme.TextStroke(20) else 0
						end,
						Text = function()
							if not pack.Available then
								return "Soon"
							end
							return if busy() then "..." else `R$ {price()}`
						end,
					}),
				},
			}),
		}

		if info.Badge == "Best" then
			table.insert(children, ribbon("BEST VALUE", Theme.Tone.Mustard, nil))
		elseif info.Badge == "Popular" then
			table.insert(children, ribbon("POPULAR", Theme.Tone.Violet, nil))
		end

		-- fixed slot in the row; the card button fills it and the card scales from its centre inside it, so the list
		-- layout never sees the size change. The hovered slot draws over its neighbours.
		table.insert(
			cards,
			create("Frame")({
				Name = pack.Key,
				LayoutOrder = index,
				Size = UDim2.new(0, cardWidth, 1, 0),
				BackgroundTransparency = 1,
				ZIndex = function()
					return if hovered() then 2 else 1
				end,
				create("TextButton")({
					Name = "Buy",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					AutoButtonColor = false,
					Selectable = true,
					Active = enabled,
					Text = "",
					MouseEnter = function()
						hover(true)
					end,
					MouseLeave = function()
						hover(false)
					end,
					SelectionGained = function()
						hover(true)
					end,
					SelectionLost = function()
						hover(false)
					end,
					MouseButton1Down = function()
						if enabled() then
							pressed(true)
						end
					end,
					MouseButton1Up = function()
						pressed(false)
					end,
					Activated = function()
						if enabled() then
							props.OnBuy(pack.Key)
						end
					end,
					CartoonPanel({
						Name = "Card",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
						Tone = if best then VIVID else MUTED,
						Outline = Theme.Outline.Thick,
						Radius = Theme.Radius.Card,
						Studs = true,
						Padding = PAD,
						Decor = {
							createRaw("UIScale")({ Scale = scale }),
							shine(clock, calm, shining, origin),
						},
						Children = children,
					}),
				}),
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
		Rays = true, -- retro rays spinning behind the cards (owner request 2026-10-15)
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
