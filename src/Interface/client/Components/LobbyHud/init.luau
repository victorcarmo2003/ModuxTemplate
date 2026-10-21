--!strict
-- LobbyHud: the lobby HUD (user request 2026-10-11; layout 2026-10-12), cartoon kit (AST-091), mobile first.
-- Laid out for the smallest landscape phone (620 x 340 px at Scale 1, inside DeviceSafeInsets); `Scale` grows it.
-- Layout (user request 2026-10-15, TASK-295):
--   left, centred vertically  four big tiles: Classes, Shop, Codes, Squad (Squad shows "2/4" when in a squad). One
--                  column (56 px tiles); on a short screen (under 440 px tall, phones in landscape) a 2 x 2 grid in the
--                  same order, so it stays clear of the mobile thumbstick (bottom left); tiles 48 px (over the 44 px
--                  touch target) on narrow screens. Never higher than TOPBAR_FREE real px from the top: the Roblox
--                  buttons (menu, chat, microphone) live in the top-left corner
--   right, centred vertically  the gem balance pill, alone (a button: opens the gem shop), gem icon + amount + "+";
--                  never over the mobile jump button (the lowest FREE_BOTTOM px of the right edge stay free)
--   bottom centre  the big Play button (text and colour from `Play`: PLAY green, START SQUAD mustard, READY,
--                  STARTING..., CANCEL dark mustard while the countdown can still be aborted). Shown only while
--                  `PlayShown` (TASK-296: the player is in a squad); pops in / out with Motion.Pop. While `Gear` (TASK-306:
--                  the leader of a created room) the Play button (START) shrinks to the left and a round gear
--                  (GearButton) sits on its right: it reopens the room setup (OnGear). The squad card that sat over it
--                  is gone (owner request 2026-10-17, mobile clean-up): the faces and the countdown live on the pad sign
--                  (PadTag)
--   bottom centre, in a pad room (owner request 2026-10-21, Provisional; `Pad`)  instead of Play: SKIP TUTORIAL (mine)
--                  on the left, START NOW (Green, bigger, leader) in the middle, FRIENDS ONLY (leader) on the right. A
--                  toggle is grey off, Green on; each flip turns it over like a card (180 deg on a spring: it narrows to
--                  its edge and opens again, with a slight tilt and pop), the colour blends Slate <-> Green on the way and
--                  a white shine sweeps across it. Reduced motion: the colour only. The countdown lives on the pad sign
-- Mobile clean-up (owner request 2026-10-17, Provisional): each tile's name sits UNDER the tile (white, thin Ink
-- stroke), never inside it (it spilled out and overlapped on phones); bigger icons; Normal outlines instead of Thick;
-- smaller gem and online pills.
--   top centre     players online in the whole game (TASK-312, owner request 2026-10-15): Ink pill, people icon +
--                  "200 players online" (12K, 1.2M), rolls with Motion.Count. The Roblox top bar keeps its buttons in
--                  the corners, so the pill sits at TOP; on a narrow screen (portrait phone) under the bar (TOPBAR_FREE).
--                  The Notices column (LobbyController) starts under it (same rule there, NOTICE_TOP*)
-- Kept clear of the mobile thumbstick (bottom left) and jump button (bottom right). Key badges ("C", "Y"...) on the
-- tiles when the device is not touch (`Keys`). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local UiScale = require(script.Parent.UiScale)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local KeyChip = require(script.Parent.KeyChip)
local GearButton = require(script.Parent.GearButton)
local Icon = require(script.Parent.LobbyWindow.Icon)
local Count = require(script.Parent.HudPill.Count)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
const spring = Vide.spring
-- Vide 0.4.1 types `create` for 19 classes only; UIScale and UIGridLayout are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Tile = "Classes" | "Shop" | "Codes" | "Squad"

-- Cancel: the countdown can still be aborted (dark mustard, never red: style guide 7.4)
export type PlayKind = "Go" | "Wait" | "Off" | "Cancel"

export type PlayButton = {
	Text: string,
	Kind: PlayKind,
	Enabled: boolean,
}

export type PadAction = "StartNow" | "SkipTutorial" | "FriendsOnly"

-- The pad bar of a pad room (LobbyController:PadBar)
export type PadBar = {
	Leader: boolean, -- START NOW and FRIENDS ONLY are the leader's
	Skip: boolean, -- I skip the run's tutorial
	Friends: boolean, -- Access Friends
}

export type Props = {
	Visible: () -> boolean,
	Gems: () -> number,
	-- "2/4" while in a squad; "" = no badge.
	Squad: () -> string,
	Play: () -> PlayButton,
	-- Key chip per tile ("C", "Y"); "" or missing = no chip (touch).
	Keys: () -> { [string]: string },
	OnOpen: (tile: Tile) -> (),
	OnPlay: () -> (),
	-- Key chip on the Play button while it says CANCEL ("X", "ButtonX"); "" or missing = none (touch).
	CancelKey: (() -> string)?,
	-- Card + Play button shown (in a squad, TASK-296); missing = always shown.
	PlayShown: (() -> boolean)?,
	-- Round gear on the right of the Play button (TASK-306: the leader of a created room); missing = never.
	Gear: (() -> boolean)?,
	-- Tap on the gear (reopens the room setup).
	OnGear: (() -> ())?,
	Scale: (() -> number)?,
	-- Players online in the whole game (TASK-312, `Online` set); missing or 0 = no pill.
	Online: (() -> number)?,
	-- The pad bar (in a pad room); missing or nil = none.
	Pad: (() -> PadBar?)?,
	OnPad: ((action: PadAction) -> ())?,
}

const MARGIN = 12
const MENU_LEFT = MARGIN + 18 -- px: room for the key badge that sits half outside each tile (owner 2026-10-16)
const TOP = 8
const TILE = 52
const TILE_SMALL = 46 -- compact / narrow: still over the 44 px touch target
const TILE_GAP = 4
const ICON = 0.62 -- icon size / tile size
const CELL_WIDTH = 64 -- px: a grid cell is wider than its tile so the name under it fits ("Classes" at 14 px)
const CAPTION = 17 -- px: the name line under a tile
const CAPTION_STROKE = 1.5
const PILL = 34
const PLAY_WIDTH = 190
const PLAY_HEIGHT = 46
const GEAR_GAP = 8 -- px between the Play button and the gear (the gear is PLAY_HEIGHT round)
const PAD_START = Vector2.new(196, 58) -- px, START NOW (the big one, in the middle)
const PAD_TOGGLE = Vector2.new(156, 46) -- px, a toggle (over the 44 px touch target)
const PAD_GAP = 12
const PAD_WIDTH = PAD_START.X + PAD_TOGGLE.X * 2 + PAD_GAP * 2
-- toggle flip (PROVISIONAL, tune in play): springs of the turn and of the colour, tilt and pop at the edge
const FLIP_PERIOD, FLIP_DAMPING = 0.5, 0.5
const TINT_PERIOD, TINT_DAMPING = 0.4, 1
const FLIP_TILT = 7 -- deg at the edge
const FLIP_POP = 0.14 -- extra scale at the edge
const FLIP_TEXT_HIDE = 0.35 -- the label fades out while the card is narrower than this

-- Slate -> Green at t (0..1), every colour of the two-tone surface
local function blendTone(a: Theme.Tone, b: Theme.Tone, t: number): Theme.Tone
	return {
		Top = a.Top:Lerp(b.Top, t),
		Bottom = a.Bottom:Lerp(b.Bottom, t),
		Lip = a.Lip:Lerp(b.Lip, t),
		Text = a.Text:Lerp(b.Text, t),
		Stroke = if t < 0.5 then a.Stroke else b.Stroke,
	}
end
const SHORT = 440 -- px tall screens under this get the 2 x 2 grid
const NARROW = 420 -- px wide screens under this get the small tiles
-- The gem pill sits at the middle of the screen height, but never lower than this many real px from the bottom edge: the
-- Roblox jump / use buttons live bottom right (360 x 640, 667 x 375, 844 x 390, 1280 x 720 all keep the corner clear)
const FREE_BOTTOM = 200
-- The tile column sits at the middle too, but never higher than this many real px from the top edge: the Roblox top bar
-- (menu, chat, microphone; ~58 px, HudController TOPBAR_REAL) is over the top-left corner
const TOPBAR_FREE = 64
const ONLINE_PILL = 28 -- px tall (UIScale grows it)

-- "950", "1.2K", "12K", "3.4M": one decimal under 10 of a unit, none above.
local function short(value: number): string
	const whole = math.max(math.floor(value + 0.5), 0)
	if whole >= 1e6 then
		const amount = whole / 1e6
		return if amount < 10 then `{math.floor(amount * 10) / 10}M` else `{math.floor(amount)}M`
	elseif whole >= 1e3 then
		const amount = whole / 1e3
		return if amount < 10 then `{math.floor(amount * 10) / 10}K` else `{math.floor(amount)}K`
	end
	return tostring(whole)
end

local function onlineText(value: number): string
	const whole = math.max(math.floor(value + 0.5), 0)
	return `{short(whole)} {if whole == 1 then "player" else "players"} online`
end

-- Dark mustard, Ink text stroke: reads as "stop" next to the green PLAY without the forbidden alert red.
const CANCEL_TONE: Theme.Tone = {
	Top = Color3.fromHex("#D9A21E"),
	Bottom = Color3.fromHex("#B07A0C"),
	Lip = Color3.fromHex("#6E4A05"),
	Text = Color3.new(1, 1, 1),
	Stroke = true,
}

const PLAY_TONE: { [PlayKind]: Theme.Tone } = {
	Go = Theme.Tone.Green,
	Wait = Theme.Tone.Mustard,
	Off = Theme.Tone.Slate,
	Cancel = CANCEL_TONE,
}

type TileDef = { Key: Tile, Text: string, Icon: string, Tone: Theme.Tone, Fallback: string }

const TILES: { TileDef } = {
	{ Key = "Classes", Text = "Classes", Icon = "Ui/paw", Tone = Theme.Tone.Mustard, Fallback = "C" },
	{ Key = "Shop", Text = "Shop", Icon = "Hud/gem", Tone = Theme.Tone.Teal, Fallback = "$" },
	{ Key = "Codes", Text = "Codes", Icon = "Ui/sparkle", Tone = Theme.Tone.Violet, Fallback = "#" },
	{ Key = "Squad", Text = "Squad", Icon = "Ui/friends", Tone = Theme.Tone.Green, Fallback = "S" },
}

return function(props: Props): Frame
	const scale = function(): number
		return if props.Scale then math.max(math.min(props.Scale(), UiScale.Current()), UiScale.Floor()) else 1
	end
	const pop = Motion.Pop(props.Visible)
	const scaled = function(): number
		return scale() * pop()
	end
	const playShown = function(): boolean
		return if props.PlayShown then props.PlayShown() else true
	end
	const playPop = Motion.Pop(playShown)
	const gearShown = function(): boolean
		return props.Gear ~= nil and props.Gear()
	end
	const padBar = function(): PadBar?
		return if props.Pad then props.Pad() else nil
	end
	const pressPad = function(action: PadAction)
		return function()
			if props.OnPad then
				props.OnPad(action)
			end
		end
	end
	-- toggle: grey off, Green on; every flip adds half a turn that a spring follows (a card turned over), the colour
	-- blends on its own spring. `mine` = this player may flip it
	local function padToggle(
		action: PadAction,
		order: number,
		text: string,
		on: (bar: PadBar) -> boolean,
		mine: (bar: PadBar) -> boolean
	)
		const isOn = function(): boolean
			const bar = padBar()
			return bar ~= nil and on(bar)
		end
		const reduced = Motion.Reduced()
		const turns = source(0) -- degrees the card should be turned to
		const lit = source(if Vide.untrack(isOn) then 1 else 0)
		local last = Vide.untrack(isOn)
		Vide.effect(function()
			const now = isOn()
			if now ~= last then
				last = now
				-- written outside the effect: a source write inside one breaks Vide's graph
				task.defer(function()
					turns(Vide.untrack(turns) + 180)
					lit(if now then 1 else 0)
				end)
			end
		end)
		const angle: () -> number = if reduced then turns else spring(turns, FLIP_PERIOD, FLIP_DAMPING)
		const tint: () -> number = if reduced then lit else spring(lit, TINT_PERIOD, TINT_DAMPING)
		-- 1 = face on, 0 = edge on
		const face = function(): number
			return if reduced then 1 else math.abs(math.cos(math.rad(angle())))
		end
		const edge = function(): number
			return if reduced then 0 else math.abs(math.sin(math.rad(angle())))
		end
		-- 0..1 through the current half turn (the shine crosses the card once per flip)
		const sweep = function(): number
			return math.clamp(1 - (turns() - angle()) / 180, 0, 1)
		end
		return create("Frame")({
			Name = action,
			LayoutOrder = order,
			Size = UDim2.fromOffset(PAD_TOGGLE.X, PAD_TOGGLE.Y),
			BackgroundTransparency = 1,
			createRaw("UIScale")({
				Scale = function()
					return 1 + FLIP_POP * edge()
				end,
			}),
			create("Frame")({
				Name = "Card",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = function()
					return UDim2.fromScale(math.max(face(), 0.04), 1)
				end,
				Rotation = function()
					return if reduced then 0 else FLIP_TILT * math.sin(math.rad(angle() * 2))
				end,
				BackgroundTransparency = 1,
				CartoonButton({
					Name = "Button",
					Size = UDim2.fromScale(1, 1),
					Outline = Theme.Outline.Normal,
					Radius = Theme.Radius.Card,
					Tone = function()
						return blendTone(Theme.Tone.Slate, Theme.Tone.Green, math.clamp(tint(), 0, 1))
					end,
					Enabled = function()
						const bar = padBar()
						return bar ~= nil and mine(bar)
					end,
					OnActivated = pressPad(action),
					Children = {
						CartoonLabel({
							Name = "Label",
							Box = UDim2.fromScale(1, 1),
							TextSize = 16,
							Text = text,
							Transparency = function()
								return math.clamp((FLIP_TEXT_HIDE - face()) / FLIP_TEXT_HIDE, 0, 1)
							end,
						}),
						-- white shine crossing the card during a flip
						create("Frame")({
							Name = "Shine",
							Size = UDim2.fromScale(1, 1),
							BackgroundColor3 = Color3.new(1, 1, 1),
							BackgroundTransparency = 0,
							BorderSizePixel = 0,
							ZIndex = 3,
							Visible = function()
								const at = sweep()
								return not reduced and at > 0.02 and at < 0.98
							end,
							create("UICorner")({ CornerRadius = Theme.Radius.Card }),
							create("UIGradient")({
								Rotation = 20,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 1),
									NumberSequenceKeypoint.new(0.4, 1),
									NumberSequenceKeypoint.new(0.5, 0.45),
									NumberSequenceKeypoint.new(0.6, 1),
									NumberSequenceKeypoint.new(1, 1),
								}),
								Offset = function()
									return Vector2.new(-1 + 2 * sweep(), 0)
								end,
							}),
						}),
					},
				}),
			}),
		})
	end

	-- Real px size of the screen (this root fills it): decides the grid and the tile size.
	const area = source(Vector2.new(1000, 700))
	const compact = function(): boolean
		return area().Y < SHORT
	end
	const tile = function(): number
		return if compact() or area().X < NARROW then TILE_SMALL else TILE
	end
	-- Real px height of the tile column and of the gem pill (they scale by `scaled`): decide where they sit
	const menuHeight = source(0)
	const gemsHeight = source(0)
	const menuTop = function(): number
		const real = area()
		return math.max(TOPBAR_FREE, real.Y / 2 - menuHeight() / 2)
	end
	const gemsTop = function(): number
		const real = area()
		const height = gemsHeight()
		const centred = real.Y / 2 - height / 2
		const lowest = real.Y - FREE_BOTTOM - height
		return math.max(TOP, math.min(centred, lowest))
	end
	const tileSize = function(): UDim2
		return UDim2.fromOffset(tile(), tile())
	end
	const cellSize = function(): UDim2
		return UDim2.fromOffset(math.max(CELL_WIDTH, tile()), tile() + CAPTION)
	end
	const iconSize = function(): number
		return math.floor(tile() * ICON)
	end

	const online = function(): number
		return if props.Online then props.Online() else 0
	end
	const onlineShown = Motion.Count(online)

	const tiles: { Instance } = {}
	for index, def in TILES do
		const keyText = function(): string
			return props.Keys()[def.Key] or ""
		end
		const badge = function(): string
			return if def.Key == "Squad" then props.Squad() else ""
		end
		const icon = Icon(def.Icon, 24, 1)
		Vide.effect(function()
			icon.Size = UDim2.fromOffset(iconSize(), iconSize())
		end)
		table.insert(
			tiles,
			create("Frame")({
				Name = `{def.Key}Cell`,
				LayoutOrder = index,
				BackgroundTransparency = 1,
				CartoonButton({
					Name = def.Key, -- LobbyController finds the Squad tile by name (gamepad selection)
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = tileSize,
					Tone = def.Tone,
					Outline = Theme.Outline.Normal,
					Radius = Theme.Radius.Card,
					OnActivated = function()
						props.OnOpen(def.Key)
					end,
					Children = {
						create("Frame")({
							Name = "Stack",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							create("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							icon,
							CartoonLabel({
								LayoutOrder = 1,
								TextSize = 22,
								Text = def.Fallback,
								Visible = not Icons.Has(def.Icon),
							}),
						}),
						-- key badge (desktop / gamepad), centred on the top-left corner: free of the screen edge
						KeyChip({
							Name = "Key",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromOffset(2, 2),
							Text = keyText,
						}),
						-- squad badge, centred on the bottom-right corner
						CartoonPanel({
							Name = "Badge",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(1, -2, 1, -4),
							Size = UDim2.fromOffset(0, 20),
							AutomaticSize = Enum.AutomaticSize.X,
							Tone = Theme.Tone.Violet,
							Lip = 2,
							Outline = 2,
							Padding = { Left = 5, Right = 5 },
							Visible = function()
								return badge() ~= ""
							end,
							Children = {
								CartoonLabel({
									Box = UDim2.new(0, 0, 1, 0),
									AutomaticSize = Enum.AutomaticSize.X,
									TextSize = Theme.MinTextSize,
									Stroke = CAPTION_STROKE,
									Text = badge,
								}),
							},
						}),
					},
				}),
				-- the name, under the tile (owner 2026-10-17: inside it spilled out and overlapped on phones)
				CartoonLabel({
					Name = "Caption",
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.5, 1),
					Box = UDim2.new(1, 0, 0, CAPTION),
					TextSize = Theme.MinTextSize,
					Stroke = CAPTION_STROKE,
					Text = def.Text,
				}),
			})
		)
	end

	const root = create("Frame")({
		Name = "LobbyHud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		-- Top centre: players online in the whole game (TASK-312). The UIScale sits on a wrapper around the whole pill:
		-- inside the pill's content it grew the icon and text but not the pill, so they spilled out on big screens
		create("Frame")({
			Name = "Online",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = function()
				return UDim2.new(0.5, 0, 0, if area().X < NARROW then TOPBAR_FREE else TOP)
			end,
			Size = UDim2.fromOffset(0, ONLINE_PILL),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Visible = function()
				return online() > 0
			end,
			createRaw("UIScale")({ Scale = scaled }),
			CartoonPanel({
				Name = "Pill",
				Size = UDim2.fromOffset(0, ONLINE_PILL),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = Theme.Tone.Ink,
				Lip = 2,
				Outline = 2,
				Padding = { Left = 10, Right = 10 }, -- even sides: icon + text centred in the pill (owner 2026-10-16)
				Children = {
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					Icon("Ui/friends", ONLINE_PILL - 10, 1),
					CartoonLabel({
						Name = "Count",
						LayoutOrder = 2,
						TextSize = 15,
						Stroke = CAPTION_STROKE,
						Text = function()
							return onlineText(onlineShown())
						end,
					}),
				},
			}),
		}),

		-- Right, centred vertically: the gem pill alone (opens the shop)
		create("Frame")({
			Name = "Wallet",
			AnchorPoint = Vector2.new(1, 0),
			Position = function()
				return UDim2.new(1, -MARGIN, 0, gemsTop())
			end,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),

			CartoonButton({
				Name = "Gems",
				Size = UDim2.fromOffset(0, PILL),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = Theme.Tone.Ink,
				Outline = Theme.Outline.Normal,
				Padding = 3,
				OnActivated = function()
					props.OnOpen("Shop")
				end,
				Children = {
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					Icon("Hud/gem", PILL - 8, 1),
					CartoonLabel({
						Name = "Amount",
						LayoutOrder = 2,
						TextSize = 18,
						Text = function()
							return Count(props.Gems())
						end,
					}),
					CartoonPanel({
						Name = "Plus",
						LayoutOrder = 3,
						Size = UDim2.fromOffset(24, 24),
						Tone = Theme.Tone.Green,
						Lip = 2,
						Outline = 2,
						Children = {
							CartoonLabel({
								Box = UDim2.fromScale(1, 1),
								TextSize = 18,
								Text = "+",
							}),
						},
					}),
				},
			}),
		}),

		-- Left, centred vertically: the tiles, a column or a 2 x 2 grid on short screens (same order, one UIScale)
		create("Frame")({
			Name = "Menu",
			Position = function()
				return UDim2.fromOffset(MENU_LEFT, menuTop())
			end,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			createRaw("UIGridLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				FillDirectionMaxCells = function()
					return if compact() then 2 else 1
				end,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				CellSize = cellSize,
				CellPadding = UDim2.fromOffset(TILE_GAP, TILE_GAP),
			}),
			tiles,
		}),

		-- Pad bar (pad room): SKIP TUTORIAL · START NOW (big, middle) · FRIENDS ONLY
		create("Frame")({
			Name = "PadBar",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -MARGIN),
			Size = UDim2.fromOffset(PAD_WIDTH, PAD_START.Y),
			BackgroundTransparency = 1,
			Visible = function()
				return padBar() ~= nil
			end,
			createRaw("UIScale")({ Scale = scaled }),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, PAD_GAP),
			}),
			padToggle("SkipTutorial", 1, "SKIP TUTORIAL", function(bar: PadBar): boolean
				return bar.Skip
			end, function(_bar: PadBar): boolean
				return true
			end),
			CartoonButton({
				Name = "StartNow",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(PAD_START.X, PAD_START.Y),
				TextSize = 22,
				Outline = Theme.Outline.Normal,
				Radius = Theme.Radius.Card,
				Studs = true,
				Tone = Theme.Tone.Green,
				Text = "START NOW",
				Enabled = function()
					const bar = padBar()
					return bar ~= nil and bar.Leader
				end,
				OnActivated = pressPad("StartNow"),
			}),
			padToggle("FriendsOnly", 3, "FRIENDS ONLY", function(bar: PadBar): boolean
				return bar.Friends
			end, function(bar: PadBar): boolean
				return bar.Leader
			end),
		}),

		-- Play, with the squad status card over it
		create("Frame")({
			Name = "PlayAnchor",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -MARGIN),
			Size = UDim2.fromOffset(PLAY_WIDTH, PLAY_HEIGHT),
			BackgroundTransparency = 1,
			-- hidden until the player is in a squad (TASK-296); stays up while it shrinks away
			Visible = function()
				return playShown() or playPop() > 0.02
			end,
			createRaw("UIScale")({
				Scale = function()
					return scaled() * playPop()
				end,
			}),

			CartoonButton({
				Name = "Play",
				-- the gear takes the right end of the same width (TASK-306)
				Size = function()
					return if gearShown() then UDim2.new(1, -(PLAY_HEIGHT + GEAR_GAP), 1, 0) else UDim2.fromScale(1, 1)
				end,
				TextSize = 22,
				Outline = Theme.Outline.Normal,
				Radius = Theme.Radius.Card,
				Studs = true,
				Tone = function()
					return PLAY_TONE[props.Play().Kind]
				end,
				Enabled = function()
					return props.Play().Enabled
				end,
				Text = function()
					return props.Play().Text
				end,
				OnActivated = props.OnPlay,
			}),
			-- room setup again (leader of a created room, TASK-306)
			GearButton({
				Name = "Gear",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = PLAY_HEIGHT,
				Visible = gearShown,
				OnActivated = function()
					if props.OnGear then
						props.OnGear()
					end
				end,
			}),
			-- key badge of CANCEL, on the top-left corner of the button
			KeyChip({
				Name = "CancelKey",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(4, 2),
				ZIndex = 5,
				Text = function()
					const key = if props.CancelKey then props.CancelKey() else ""
					return if props.Play().Kind == "Cancel" then key else ""
				end,
			}),
		}),
	}) :: Frame

	const measure = function()
		if root.AbsoluteSize.X > 0 then
			area(root.AbsoluteSize)
		end
	end
	const connection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
	-- real px heights of the two side blocks (with their UIScale): keep them centred
	const connections = { connection }
	const blocks: { [string]: Vide.Source<number> } = { Menu = menuHeight, Wallet = gemsHeight }
	for name, height in blocks do
		const frame = root:FindFirstChild(name) :: Frame?
		if frame then
			const measureFrame = function()
				if frame.AbsoluteSize.Y > 0 then
					height(frame.AbsoluteSize.Y)
				end
			end
			table.insert(connections, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(measureFrame))
			measureFrame()
		end
	end
	cleanup(function()
		for _, each in connections do
			each:Disconnect()
		end
	end)
	return root
end
