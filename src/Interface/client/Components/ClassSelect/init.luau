--!strict
-- ClassSelect: the lobby class screen (user request 2026-10-11, "Animal Hospital" style), cartoon kit (AST-091).
-- Laid out for the smallest landscape phone (718 x 340 px at Scale 1, inside DeviceSafeInsets); `Scale` grows it.
--   centre   the class rig standing, facing the camera: the world stage (LobbyController moves the camera, nothing
--            here) or `Stage` (a ClassStage viewport) behind the panels; the class name (shrinks to fit) over the
--            arrows under it, which cycle the classes (TASK-298)
--   sides    list and card centred on the vertical, BODY_SHARE of the screen tall (TASK-297), clear of the header
--            and of the Roblox buttons (top left: the title tab sits right of them)
--   left     Ink list of every class (Content.Classes): icon, name, animal, lock / "Soon" / equipped check; scrolls
--   right    Cream card of the focused class (TASK-299): round portrait, big name, species / price chips; a flavour
--            line, attribute bars around the Rookie line (middle), passive skill cards (TASK-302), packed together at the top
--            (the free height sits above the buttons) and shrunk together on a short screen; the buttons at the bottom:
--              not owned   "Buy  2,000" (gems, Mustard; "Get 1,600 more" without the gems: the server prompts the gem pack
--                          that covers it, Shop TopUp) + "Buy  R$ 79" (Robux,
--                          Green; Slate "Robux (soon)" while the product id is 0)
--              owned       "Equip" (Mustard) / "Equipped" (Green, not pressable)
--              not in MVP  "Coming soon" (Slate)
--            gift (TASK-353, owner request 2026-10-16): with `OnGift`, a round GiftButton (44 px) right of the Robux /
--            Equip button (owned or not: a class can be gifted either way); hidden for "Coming soon" and for a class
--            without a gift row (`Giftable`), Slate while `CanGift` says the product is not created yet
-- The card pops on every class change. No backdrop: the rig shows through the middle. Pure: only props; the caller
-- sends the requests and the server decides (Profile / Wallet / ClassBuyResult).
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local UiScale = require(script.Parent.UiScale)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local UseTween = require(script.Parent.UseTween)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Icon = require(script.Parent.LobbyWindow.Icon)
local Count = require(script.Parent.HudPill.Count)
local SkillImages = require(script.SkillImages)
local GiftButton = require(script.Parent.GiftButton)

const create = Vide.create
const effect = Vide.effect
const source = Vide.source
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale, UIPadding, ScrollingFrame are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Entry = {
	Key: string, -- Content.Classes key
	Title: string,
	Animal: string,
	Species: string,
	Badge: string, -- placeholder letter
	Icon: string, -- Icons name ("Class/class_fox"); unknown = Badge
	Price: number, -- gems
	Available: boolean, -- InMvp: false = "Coming soon"
	Blurb: string, -- flavour line under the header ("" = none)
	Stats: { Stat }, -- attribute bars against the Rookie
	Skills: { Skill }, -- passive skill cards (TASK-302)
}

-- Attribute bar: value next to the Rookie baseline (Entries.Stat); higher = better.
-- Passive skill card (Entries.Skill): presentation of the class effects only.
export type Skill = {
	Name: string,
	Text: string,
	Icon: string, -- SkillImages key
	Kind: "Perk" | "Drawback",
}

export type Stat = {
	Key: string,
	Label: string,
	Value: number,
	Base: number,
	Text: string,
}

-- Equipped: owned and selected · Owned · Locked: for sale, not owned · Soon: not in the MVP
export type State = "Equipped" | "Owned" | "Locked" | "Soon"

export type Props = {
	Entries: { Entry },
	Visible: () -> boolean,
	Gems: () -> number,
	Focus: () -> string,
	StateOf: (key: string) -> State,
	-- Robux price of a class; nil = product not created yet (the Robux button shows disabled).
	RobuxOf: (key: string) -> number?,
	-- A request is on its way (or the profile has not arrived): the buttons are disabled.
	Busy: () -> boolean,
	OnFocus: (key: string) -> (),
	OnBuyGems: (key: string) -> (),
	OnBuyRobux: (key: string) -> (),
	OnEquip: (key: string) -> (),
	-- Gift button of the buy row (TASK-353); nil = none. `Giftable` false = hidden (no gift row), `CanGift` false =
	-- disabled (product not created yet).
	OnGift: ((key: string) -> ())?,
	Giftable: ((key: string) -> boolean)?,
	CanGift: ((key: string) -> boolean)?,
	OnClose: () -> (),
	-- Viewport stage (ClassStage) drawn behind the panels; nil = world stage.
	Stage: Instance?,
	Scale: (() -> number)?,
	-- Real px (in this root's space) of the Roblox buttons block at the top left; nil = GuiService.TopbarInset.
	Reserved: (() -> Vector2)?,
}

const MARGIN = 12
const HEADER = 44
const BODY_SHARE = 0.7 -- list and card height, share of the screen (TASK-297)
const BODY_MIN = 220 -- px at scale 1: under it the card buttons crowd the lines
const LIST_WIDTH = 236 -- 196 + 20% (TASK-297)
const CARD_WIDTH = 272 -- 226 + 20%
const ROW = 52
const ROW_GAP = 6
const PAD = 10
const BUTTON = 44
const ARROW = 48
const NAME_WIDTH = 170 -- class name over the arrows (TASK-298); a long name shrinks to fit
const NAME_HEIGHT = 34
const FOOT = NAME_HEIGHT + 2 + ARROW
const STAGE_WIDTH = 220
-- Card (TASK-299)
const PORTRAIT = 58
const CHIP = 24
const STAT_ROW = 18
const STAT_BAR = 10
const STAT_LABEL = 52
const STAT_VALUE = 64
const SECTION_GAP = 12 -- blurb, attributes and skills stay together at the top; the free height goes above the buttons
const SKILL_GAP = 8 -- between two skill cards
const SKILL_ICON = 40 -- square skill art (TASK-302)
const EDGE = 4 -- room inside the clipped body for the outlines (2 px Outside stroke + 2 px lip)
-- Skill name / line width in px: a fixed width wraps reliably inside the auto-sized card (a scale width under the
-- kit's measured AutomaticSize kept one line and cut the text). Card inner width minus padding, art and gap.
const SKILL_TEXT = CARD_WIDTH - PAD * 2 - EDGE * 2 - 14 - 4 - SKILL_ICON - 8
const SKILL_LINES = 36 -- the skill line always has room for 2 lines (14 px); AutomaticSize grows it past that
const STAT_TWEEN = 0.25 -- s, bar fill on a class swap (none with reduced motion)
const FIT_GAP = 0.08 -- the section gaps, as a share of the content, when deciding to shrink
const FIT_MIN = 0.7 -- smallest body scale (14 px text x 0.7 ~ 10 px at the phone floor: still readable)
-- Margins, list, card and the name between them, at scale 1.
const DESIGN = Vector2.new(MARGIN * 2 + LIST_WIDTH + CARD_WIDTH + 16 + NAME_WIDTH, 340)
-- Roblox buttons while GuiService.TopbarInset is unknown (real px; HudController TOPBAR_REAL).
const TOPBAR_LEFT = 120
const TOPBAR_HEIGHT = 60

-- Bar fill (share of the track): the middle is the Rookie (100%), so value / base x 0.5, full at twice the Rookie
-- or more. A base of 0 (no Rookie value): middle when equal, full above, empty below.
local function share(stat: Stat): number
	if stat.Base == 0 then
		return if stat.Value > 0 then 1 elseif stat.Value < 0 then 0 else 0.5
	end
	return math.clamp(stat.Value / stat.Base * 0.5, 0, 1)
end

return function(props: Props): Frame
	const byKey: { [string]: Entry } = {}
	for _, entry in props.Entries do
		byKey[entry.Key] = entry
	end
	const first = props.Entries[1]
	local function focused(): Entry
		return byKey[props.Focus()] or first
	end
	local function step(delta: number)
		const key = untrack(focused).Key
		local index = 1
		for i, entry in props.Entries do
			if entry.Key == key then
				index = i
			end
		end
		const n = #props.Entries
		props.OnFocus(props.Entries[(index - 1 + delta) % n + 1].Key)
	end

	-- Real px size of the screen (this root fills it): the screen shrinks to fit a narrow one (DESIGN).
	const area = source(Vector2.zero)
	const origin = source(Vector2.zero)
	const topbar = source(GuiService.TopbarInset)
	const scale = function(): number
		const base = if props.Scale then math.max(math.min(props.Scale(), UiScale.Current()), Theme.Scale.Min) else 1
		return UiScale.Fit(base, area(), DESIGN)
	end
	const pop = Motion.Pop(props.Visible)
	const scaled = function(): number
		return scale() * pop()
	end

	-- Real px of the Roblox buttons block (top left) in this root's space.
	const reserved = function(): Vector2
		if props.Reserved then
			return props.Reserved()
		end
		const inset = topbar()
		const at = origin()
		const width = if inset.Height > 0 then inset.Min.X else TOPBAR_LEFT
		const height = math.max(inset.Max.Y, TOPBAR_HEIGHT)
		return Vector2.new(math.max(width - at.X, 0), math.max(height - at.Y, 0))
	end
	-- Title tab: right of the Roblox buttons (real px).
	const titleX = function(): number
		return math.max(MARGIN, reserved().X + 8)
	end
	-- List and card height (px at scale 1): BODY_SHARE of the screen, centred, clear of the header and of the Roblox
	-- buttons on top (the same room at the bottom keeps them centred).
	const body = function(): number
		const s = scale()
		const height = area().Y
		if height <= 0 then
			return BODY_MIN
		end
		const clear = math.max(8 + HEADER * s + 6, reserved().Y + 6)
		const real = math.min(height * BODY_SHARE, height - clear * 2)
		return math.max(real / s, BODY_MIN)
	end

	-- List rows ---------------------------------------------------------------------------------------------------
	const rows: { Instance } = {}
	for index, entry in props.Entries do
		const state = function(): State
			return props.StateOf(entry.Key)
		end
		const isFocused = function(): boolean
			return focused().Key == entry.Key
		end
		table.insert(
			rows,
			CartoonButton({
				Name = entry.Key,
				LayoutOrder = index,
				Size = UDim2.new(1, -8, 0, ROW),
				Tone = function()
					return if isFocused() then Theme.Tone.Mustard else Theme.Tone.Cream
				end,
				Outline = function()
					return if isFocused() then Theme.Outline.Thick else Theme.Outline.Normal
				end,
				Radius = Theme.Radius.Chip,
				Padding = 6,
				OnActivated = function()
					props.OnFocus(entry.Key)
				end,
				SelectionGained = function()
					props.OnFocus(entry.Key)
				end,
				Children = {
					-- portrait
					CartoonPanel({
						Name = "Portrait",
						Size = UDim2.fromOffset(ROW - 16, ROW - 16),
						Tone = Theme.Tone.White,
						Radius = Theme.Radius.Small,
						Lip = 2,
						Outline = 2,
						Gloss = false,
						Children = {
							create("UIListLayout")({
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							Icon(entry.Icon, ROW - 18, 1),
							CartoonLabel({
								Box = UDim2.fromScale(1, 1),
								TextSize = 20,
								Color = Theme.Color.Dark,
								Stroke = 0,
								Text = entry.Badge,
								Visible = not Icons.Has(entry.Icon),
							}),
						},
					}),
					CartoonLabel({
						Name = "Title",
						Position = UDim2.fromOffset(ROW - 8, -2),
						Box = UDim2.new(1, -(ROW - 8) - 30, 0, 22),
						TextSize = 18,
						XAlignment = Enum.TextXAlignment.Left,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Truncate = true,
						Text = entry.Title,
					}),
					CartoonLabel({
						Name = "Animal",
						Position = UDim2.fromOffset(ROW - 8, 18),
						Box = UDim2.new(1, -(ROW - 8) - 30, 0, 18),
						TextSize = Theme.MinTextSize,
						XAlignment = Enum.TextXAlignment.Left,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Transparency = 0.3,
						Truncate = true,
						Text = entry.Animal,
					}),
					-- status on the right: lock, check, "Soon"
					create("Frame")({
						Name = "Status",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, 0, 0.5, -2),
						Size = UDim2.fromOffset(28, 28),
						BackgroundTransparency = 1,
						Icon(function()
							const s = state()
							return if s == "Locked"
								then "Notice/lock"
								elseif s == "Equipped" then "Ui/check"
								else ""
						end, 28, 1),
						CartoonLabel({
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.fromScale(1, 0.5),
							TextSize = Theme.MinTextSize,
							Color = Theme.Color.Dark,
							Stroke = 0,
							Text = function()
								const s = state()
								if s == "Soon" then
									return "Soon"
								elseif s == "Locked" and not Icons.Has("Notice/lock") then
									return "Lock"
								elseif s == "Equipped" and not Icons.Has("Ui/check") then
									return "On"
								end
								return ""
							end,
						}),
					}),
				},
			})
		)
	end

	-- Card of the focused class -----------------------------------------------------------------------------------
	const cardPop = createRaw("UIScale")({ Scale = 1 }) :: UIScale
	effect(function()
		props.Focus()
		if not untrack(props.Visible) then
			return
		end
		cardPop.Scale = 0.88
		TweenService:Create(
			cardPop,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end)

	const state = function(): State
		return props.StateOf(focused().Key)
	end
	const robux = function(): number?
		return props.RobuxOf(focused().Key)
	end
	const canGems = function(): boolean
		return props.Gems() >= focused().Price
	end
	const onGift = props.OnGift
	const giftShown = function(): boolean
		if onGift == nil or state() == "Soon" then
			return false
		end
		const giftable = props.Giftable
		return giftable == nil or giftable(focused().Key)
	end
	-- the Robux / Equip button leaves room for the gift button
	const rowButton = function(): UDim2
		return UDim2.new(1, if giftShown() then -(BUTTON + 6) else 0, 1, 0)
	end

	const buttons: { any } = {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		-- Buy with gems
		CartoonButton({
			Name = "BuyGems",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, BUTTON),
			TextSize = 18,
			Outline = Theme.Outline.Thick,
			Icon = "Hud/gem",
			IconSize = 28,
			Visible = function()
				return state() == "Locked"
			end,
			Tone = Theme.Tone.Mustard,
			Enabled = function()
				return not props.Busy()
			end,
			Text = function()
				if props.Busy() then
					return "..."
				end
				const price = focused().Price
				return if canGems() then `Buy  {Count(price)}` else `Get {Count(price - props.Gems())} more`
			end,
			OnActivated = function()
				props.OnBuyGems(focused().Key)
			end,
		}),
		-- Buy with Robux / Equip, and the gift button beside them (TASK-353)
		create("Frame")({
			Name = "Row",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, BUTTON),
			BackgroundTransparency = 1,
			-- Buy with Robux
			CartoonButton({
				Name = "BuyRobux",
				Size = rowButton,
				TextSize = 18,
				Outline = Theme.Outline.Thick,
				Visible = function()
					return state() == "Locked"
				end,
				Tone = Theme.Tone.Green,
				Enabled = function()
					return robux() ~= nil and not props.Busy()
				end,
				Text = function()
					const price = robux()
					if price == nil then
						return "Robux (soon)"
					end
					return if price > 0 then `Buy  R$ {price}` else "Buy with Robux"
				end,
				OnActivated = function()
					props.OnBuyRobux(focused().Key)
				end,
			}),
			-- Equip / Equipped / Coming soon
			CartoonButton({
				Name = "Equip",
				Size = rowButton,
				TextSize = 20,
				Outline = Theme.Outline.Thick,
				Icon = function()
					return if state() == "Equipped" then "Ui/check" else ""
				end,
				IconSize = 26,
				Visible = function()
					return state() ~= "Locked"
				end,
				Tone = function()
					const s = state()
					return if s == "Equipped" then Theme.Tone.Green else Theme.Tone.Mustard
				end,
				Enabled = function()
					return state() == "Owned" and not props.Busy()
				end,
				Text = function()
					const s = state()
					if s == "Equipped" then
						return "Equipped"
					elseif s == "Soon" then
						return "Coming soon"
					end
					return if props.Busy() then "..." else "Equip"
				end,
				OnActivated = function()
					props.OnEquip(focused().Key)
				end,
			}),
			GiftButton({
				Name = "Gift",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = BUTTON,
				Visible = giftShown,
				Enabled = function()
					const canGift = props.CanGift
					return (canGift == nil or canGift(focused().Key)) and not props.Busy()
				end,
				OnActivated = function()
					if onGift then
						onGift(focused().Key)
					end
				end,
			}),
		}),
	}

	-- Card body (TASK-299): blurb, attribute bars, trait chips, packed at the top under the header (owner 2026-10-15:
	-- the free height goes between them and the buttons) and shrunk together (UIScale `fit`) on a short screen.
	local function chip(
		name: string,
		order: number,
		tone: () -> Theme.Tone,
		icon: (() -> string)?,
		text: () -> string,
		visible: () -> boolean
	)
		return CartoonPanel({
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromOffset(0, CHIP),
			AutomaticSize = Enum.AutomaticSize.X,
			Tone = tone,
			Radius = Theme.Radius.Pill,
			Outline = 2,
			Lip = 2,
			Gloss = false,
			Padding = { Left = if icon then 3 else 8, Right = 8 },
			Visible = visible,
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2),
				}),
				if icon then Icon(icon, CHIP - 6, 1) else nil,
				CartoonLabel({
					LayoutOrder = 2,
					TextSize = Theme.MinTextSize,
					Color = function()
						return tone().Text
					end,
					Stroke = function()
						return if tone().Stroke then 2 else 0
					end,
					Text = text,
				}),
			},
		})
	end

	local function statRow(stat: () -> Stat, index: number)
		-- Fill grows / shrinks around the middle line (the Rookie, 100%), tweened on every class swap.
		const fill = UseTween(function()
			return UDim2.fromScale(share(stat()), 1)
		end, function()
			return if Motion.Reduced() then 0 else STAT_TWEEN
		end, Enum.EasingStyle.Quad)
		return create("Frame")({
			Name = "Stat",
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, STAT_ROW),
			BackgroundTransparency = 1,
			CartoonLabel({
				Name = "Label",
				Box = UDim2.new(0, STAT_LABEL, 1, 0),
				TextSize = Theme.MinTextSize,
				XAlignment = Enum.TextXAlignment.Left,
				Color = Theme.Color.Dark,
				Stroke = 0,
				Text = function()
					return stat().Label
				end,
			}),
			create("Frame")({
				Name = "Track",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, STAT_LABEL, 0.5, 0),
				Size = UDim2.new(1, -STAT_LABEL - STAT_VALUE - 4, 0, STAT_BAR),
				BackgroundColor3 = Theme.Color.Ink,
				BackgroundTransparency = 0.82,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				-- the class value: green over the Rookie, mustard under it, teal equal
				create("Frame")({
					Name = "Fill",
					ZIndex = 2,
					Size = fill,
					BackgroundColor3 = function()
						const s = stat()
						return if s.Value > s.Base
							then Theme.Color.Green
							elseif s.Value < s.Base then Theme.Color.Mustard
							else Theme.Color.Teal
					end,
					Visible = function()
						return fill().X.Scale > 0.005
					end,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2 }),
				}),
				-- the Rookie line, fixed in the middle of every bar
				create("Frame")({
					Name = "Base",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(0, 2, 1, 6),
					BackgroundColor3 = Theme.Color.Ink,
					BorderSizePixel = 0,
					ZIndex = 3,
				}),
			}),
			CartoonLabel({
				Name = "Value",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Box = UDim2.new(0, STAT_VALUE, 1, 0),
				TextSize = Theme.MinTextSize,
				XAlignment = Enum.TextXAlignment.Right,
				Color = Theme.Color.Dark,
				Stroke = 0,
				Text = function()
					return stat().Text
				end,
			}),
		})
	end

	-- Passive skill card (TASK-302): square icon (SkillImages; the check / warning sheet icon until uploaded), name and
	-- a short line. A drawback gets the Cream tone and the yellow warning mark on its icon.
	local function skillCard(skill: () -> Skill, index: number)
		const drawback = function(): boolean
			return skill().Kind == "Drawback"
		end
		const image = function(): string
			return SkillImages[skill().Icon] or ""
		end
		return CartoonPanel({
			Name = "Skill",
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Tone = function()
				return if drawback() then Theme.Tone.Cream else Theme.Tone.White
			end,
			Radius = Theme.Radius.Chip,
			Outline = 2,
			Lip = 2,
			Gloss = false,
			Padding = { Top = 6, Bottom = 6, Left = 6, Right = 8 },
			Children = {
				create("Frame")({
					Name = "Art",
					Size = UDim2.fromOffset(SKILL_ICON, SKILL_ICON),
					BackgroundTransparency = 1,
					create("ImageLabel")({
						Name = "Image",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = image,
						Visible = function()
							return image() ~= ""
						end,
					}),
					-- not uploaded: the sheet icon of the kind
					create("Frame")({
						Name = "Fallback",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = function()
							return image() == ""
						end,
						create("UIListLayout")({
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Icon(function()
							return if drawback() then "Ui/warning" else "Ui/check"
						end, SKILL_ICON - 8, 1),
					}),
					-- warning mark of a drawback, on the icon corner
					create("Frame")({
						Name = "Warning",
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, 6, 1, 6),
						Size = UDim2.fromOffset(20, 20),
						BackgroundTransparency = 1,
						ZIndex = 2,
						Visible = function()
							return drawback() and image() ~= ""
						end,
						Icon("Ui/warning", 20, 1),
						CartoonLabel({
							Box = UDim2.fromScale(1, 1),
							TextSize = 16,
							Color = Theme.Color.Mustard,
							Text = "!",
							Visible = not Icons.Has("Ui/warning"),
						}),
					}),
				}),
				CartoonLabel({
					Name = "Title",
					Position = UDim2.fromOffset(SKILL_ICON + 8, 0),
					Box = UDim2.fromOffset(SKILL_TEXT, 20),
					TextSize = 16,
					XAlignment = Enum.TextXAlignment.Left,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Truncate = true,
					Text = function()
						return skill().Name
					end,
				}),
				CartoonLabel({
					Name = "Text",
					Position = UDim2.fromOffset(SKILL_ICON + 8, 20),
					Box = UDim2.fromOffset(SKILL_TEXT, SKILL_LINES),
					AutomaticSize = Enum.AutomaticSize.Y,
					TextSize = Theme.MinTextSize,
					XAlignment = Enum.TextXAlignment.Left,
					YAlignment = Enum.TextYAlignment.Top,
					Wrapped = true,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Transparency = 0.2,
					Text = function()
						return skill().Text
					end,
				}),
			},
		})
	end

	const fit = source(1)
	const fitLayout = createRaw("UIListLayout")({
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, SECTION_GAP),
	}) :: UIListLayout
	const fitFrame = create("Frame")({
		Name = "Fit",
		Size = function()
			const s = fit()
			return UDim2.fromScale(1 / s, 1 / s)
		end,
		BackgroundTransparency = 1,
		createRaw("UIScale")({ Scale = fit }),
		fitLayout,
		-- room for the outlines (Outside UIStroke + lip): the Body clips, the sides must not cut them
		createRaw("UIPadding")({
			PaddingTop = UDim.new(0, EDGE),
			PaddingBottom = UDim.new(0, EDGE),
			PaddingLeft = UDim.new(0, EDGE),
			PaddingRight = UDim.new(0, EDGE),
		}),
		CartoonLabel({
			Name = "Blurb",
			LayoutOrder = 1,
			Box = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = Theme.MinTextSize,
			XAlignment = Enum.TextXAlignment.Left,
			YAlignment = Enum.TextYAlignment.Top,
			Wrapped = true,
			Color = Theme.Color.Dark,
			Stroke = 0,
			Transparency = 0.25,
			Text = function()
				return focused().Blurb
			end,
			Visible = function()
				return focused().Blurb ~= ""
			end,
		}),
		CartoonPanel({
			Name = "Stats",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Tone = Theme.Tone.White,
			Radius = Theme.Radius.Chip,
			Outline = 2,
			Lip = 2,
			Gloss = false,
			Padding = { Top = 8, Bottom = 8, Left = 10, Right = 10 },
			Visible = function()
				return #focused().Stats > 0
			end,
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				-- legend of the middle line (always shown: the box keeps its height across class swaps)
				create("Frame")({
					Name = "Legend",
					LayoutOrder = 0,
					Size = UDim2.new(1, 0, 0, STAT_ROW),
					BackgroundTransparency = 1,
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					create("Frame")({
						Name = "Swatch",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(2, STAT_BAR + 6),
						BackgroundColor3 = Theme.Color.Ink,
						BorderSizePixel = 0,
					}),
					CartoonLabel({
						LayoutOrder = 2,
						TextSize = Theme.MinTextSize,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Transparency = 0.35,
						Text = "Rookie",
					}),
				}),
				Vide.indexes(function()
					return focused().Stats
				end, statRow),
			},
		}),
		create("Frame")({
			Name = "Skills",
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, SKILL_GAP),
			}),
			Vide.indexes(function()
				return focused().Skills
			end, skillCard),
		}),
	}) :: Frame
	const bodyFrame = create("Frame")({
		Name = "Body",
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		createRaw("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Fill }),
		fitFrame,
	}) :: Frame
	-- Shrink the body when its sections do not fit (a phone); back to 1 when they do. The sizes are read at the
	-- current `fit`, so the natural height does not depend on it (no feedback loop; a small dead band).
	const refit = function()
		const height = bodyFrame.AbsoluteSize.Y
		if height <= 0 then
			return
		end
		const s = untrack(fit)
		local used = 0
		for _, child in fitFrame:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				used += child.AbsoluteSize.Y
			end
		end
		if used <= 0 then
			return
		end
		const natural = used * (1 + FIT_GAP) / s
		const target = math.clamp(height / natural, FIT_MIN, 1)
		if math.abs(target - s) > 0.02 then
			fit(target)
		end
	end

	const card = CartoonPanel({
		Name = "Card",
		-- centred: the focus pop (cardPop) grows from the middle of the card
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Tone = Theme.Tone.Cream,
		Outline = Theme.Outline.Thick,
		Radius = Theme.Radius.Card,
		Padding = PAD,
		Decor = { cardPop },
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			-- header: round portrait, big name, species / price chips
			create("Frame")({
				Name = "Header",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, PORTRAIT),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				-- Atlas icon (AST-091 sheet). The round shop portraits (Assets/textures/ui/shop/class_<animal>.png)
				-- have no asset id yet: swap them in here once uploaded.
				CartoonPanel({
					Name = "Portrait",
					Size = UDim2.fromOffset(PORTRAIT, PORTRAIT),
					Tone = Theme.Tone.White,
					Radius = Theme.Radius.Pill,
					Outline = Theme.Outline.Thick,
					Lip = 3,
					Children = {
						create("UIListLayout")({
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						Icon(function()
							return focused().Icon
						end, PORTRAIT - 14, 1),
						CartoonLabel({
							LayoutOrder = 2,
							TextSize = 26,
							Color = Theme.Color.Dark,
							Stroke = 0,
							Text = function()
								return focused().Badge
							end,
							Visible = function()
								return not Icons.Has(focused().Icon)
							end,
						}),
					},
				}),
				CartoonLabel({
					Name = "Name",
					Position = UDim2.fromOffset(PORTRAIT + 8, 0),
					Box = UDim2.new(1, -(PORTRAIT + 8), 0, 30),
					TextSize = 26,
					Scaled = true,
					MaxTextSize = 26,
					XAlignment = Enum.TextXAlignment.Left,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Text = function()
						return focused().Title
					end,
				}),
				create("Frame")({
					Name = "Chips",
					Position = UDim2.fromOffset(PORTRAIT + 8, 32),
					Size = UDim2.new(1, -(PORTRAIT + 8), 0, CHIP),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Wraps = true,
						Padding = UDim.new(0, 4),
					}),
					chip("Species", 1, function()
						return Theme.Tone.Teal
					end, function()
						return "Ui/paw"
					end, function()
						return focused().Animal
					end, function()
						return true
					end),
					chip("Price", 2, function()
						const s = state()
						return if s == "Locked"
							then Theme.Tone.Mustard
							elseif s == "Soon" then Theme.Tone.Slate
							else Theme.Tone.Green
					end, function()
						const s = state()
						return if s == "Locked" then "Hud/gem" elseif s == "Soon" then "Notice/lock" else "Ui/check"
					end, function()
						const s = state()
						if s == "Locked" then
							return Count(focused().Price)
						elseif s == "Soon" then
							return "Soon"
						end
						return if s == "Equipped" then "Equipped" else "Owned"
					end, function()
						return true
					end),
					chip("Robux", 3, function()
						return Theme.Tone.Green
					end, nil, function()
						const price = robux()
						return if price and price > 0 then `R$ {price}` else "Robux"
					end, function()
						return state() == "Locked" and robux() ~= nil
					end),
				}),
			}),
			bodyFrame,
			-- footer: the buttons
			create("Frame")({
				Name = "Buttons",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				buttons,
			}),
		},
	})

	const root = create("Frame")({
		Name = "ClassSelect",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = true,
		Visible = props.Visible,

		-- stage (viewport fallback) under everything
		if props.Stage
			then create("Frame")({
				Name = "StageAnchor",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = function()
					return UDim2.new(0.5, 0, 1, -MARGIN - FOOT * scale())
				end,
				Size = function()
					return UDim2.fromOffset(STAGE_WIDTH, body())
				end,
				BackgroundTransparency = 1,
				ZIndex = 0,
				createRaw("UIScale")({ Scale = scale }),
				props.Stage,
			})
			else nil,

		-- header: title tab
		create("Frame")({
			Name = "TitleAnchor",
			Position = function()
				return UDim2.fromOffset(titleX(), 8)
			end,
			Size = UDim2.fromOffset(0, HEADER),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			CartoonPanel({
				Name = "Title",
				Size = UDim2.fromOffset(0, HEADER),
				AutomaticSize = Enum.AutomaticSize.X,
				Rotation = -2,
				Tone = Theme.Tone.Mustard,
				Padding = { Left = 8, Right = 16 },
				Children = {
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					Icon("Ui/paw", HEADER - 12, 1),
					CartoonLabel({
						LayoutOrder = 2,
						TextSize = 26,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Text = "Classes",
					}),
				},
			}),
		}),

		-- header: gems + close
		create("Frame")({
			Name = "TopRight",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -MARGIN, 0, 8),
			Size = UDim2.fromOffset(0, HEADER),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			CartoonPanel({
				Name = "Gems",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(96, HEADER),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = Theme.Tone.Ink,
				Padding = { Left = 4, Right = 14 },
				Children = {
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					Icon("Hud/gem", HEADER - 6, 1),
					CartoonLabel({
						Name = "Amount",
						LayoutOrder = 2,
						TextSize = 22,
						Text = function()
							return Count(props.Gems())
						end,
					}),
				},
			}),
			CartoonButton({
				Name = "Close",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(HEADER, HEADER),
				Tone = Theme.Tone.Teal,
				OnActivated = props.OnClose,
				Children = {
					create("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Icon("Ui/close", HEADER - 16, 1),
					CartoonLabel({
						LayoutOrder = 2,
						TextSize = 22,
						Text = "X",
						Visible = not Icons.Has("Ui/close"),
					}),
				},
			}),
		}),

		-- left: class list
		create("Frame")({
			Name = "ListAnchor",
			-- anchored at its centre (left edge at MARGIN once fully open): the open pop grows from the middle
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				return UDim2.new(0, MARGIN + LIST_WIDTH * scale() / 2, 0.5, 0)
			end,
			Size = function()
				return UDim2.fromOffset(LIST_WIDTH, body())
			end,
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			CartoonPanel({
				Name = "List",
				Size = UDim2.fromScale(1, 1),
				Tone = Theme.Tone.Ink,
				Outline = Theme.Outline.Thick,
				Radius = Theme.Radius.Card,
				Studs = true,
				Gloss = false,
				Padding = { Top = 8, Bottom = 6, Left = 8, Right = 4 },
				Children = {
					createRaw("ScrollingFrame")({
						Name = "Rows",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 4,
						ScrollBarImageColor3 = Theme.Color.Cream,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						Selectable = false,
						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, ROW_GAP),
						}),
						createRaw("UIPadding")({
							PaddingTop = UDim.new(0, 2),
							PaddingBottom = UDim.new(0, 6),
							PaddingLeft = UDim.new(0, 2),
						}),
						rows,
					}),
				},
			}),
		}),

		-- right: card of the focused class
		create("Frame")({
			Name = "CardAnchor",
			-- anchored at its centre (right edge at MARGIN once fully open): the open pop grows from the middle
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				return UDim2.new(1, -MARGIN - CARD_WIDTH * scale() / 2, 0.5, 0)
			end,
			Size = function()
				return UDim2.fromOffset(CARD_WIDTH, body())
			end,
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			card,
		}),

		-- class name over the arrows, arrows under the rig
		create("Frame")({
			Name = "Arrows",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -MARGIN),
			Size = UDim2.fromOffset(NAME_WIDTH, FOOT),
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			CartoonLabel({
				Name = "ClassName",
				Box = UDim2.fromOffset(NAME_WIDTH, NAME_HEIGHT),
				TextSize = 32,
				Scaled = true,
				MaxTextSize = 32,
				Text = function()
					return focused().Title
				end,
			}),
			CartoonButton({
				Name = "Previous",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromOffset(ARROW, ARROW),
				Tone = Theme.Tone.Teal,
				OnActivated = function()
					step(-1)
				end,
				Children = {
					create("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Icon("Ui/arrow_left", ARROW - 16, 1),
					CartoonLabel({
						Box = UDim2.fromScale(1, 1),
						TextSize = 22,
						Text = "<",
						Visible = not Icons.Has("Ui/arrow_left"),
					}),
				},
			}),
			CartoonButton({
				Name = "Next",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.fromOffset(ARROW, ARROW),
				Tone = Theme.Tone.Teal,
				OnActivated = function()
					step(1)
				end,
				Children = {
					create("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Icon("Ui/arrow_right", ARROW - 16, 1),
					CartoonLabel({
						Box = UDim2.fromScale(1, 1),
						TextSize = 22,
						Text = ">",
						Visible = not Icons.Has("Ui/arrow_right"),
					}),
				},
			}),
		}),
	}) :: Frame
	const measure = function()
		if root.AbsoluteSize.X > 0 then
			area(root.AbsoluteSize)
			origin(root.AbsolutePosition)
		end
	end
	const connections = {
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure),
		root:GetPropertyChangedSignal("AbsolutePosition"):Connect(measure),
		bodyFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit),
		fitLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refit),
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
			topbar(GuiService.TopbarInset)
		end),
	}
	cleanup(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	return root
end
