--!strict
-- LobbyHud: the lobby HUD (user request 2026-10-11; layout 2026-10-12), cartoon kit (AST-091), mobile first.
-- Laid out for the smallest landscape phone (620 x 340 px at Scale 1, inside DeviceSafeInsets); `Scale` grows it.
-- ALL of the lobby UI lives on the RIGHT side; the left side stays free for the Roblox menu and chat.
--   right, a little above the middle of the screen (never over the mobile jump button: the lowest ~200 px of the right
--                  edge stay free; short screens pin it to the top)
--                  gem balance pill (a button: opens the gem shop), gem icon + amount + "+"
--   under the pill four big tiles: Classes, Shop, Codes, Squad (Squad shows "2/4" when in a squad). One column
--                  (56 px tiles); on a short screen (under 440 px tall, phones in landscape) a 2 x 2 grid in the same
--                  order, so it stays clear of the mobile jump button (bottom right); tiles 48 px (over the 44 px
--                  touch target) on narrow screens
--   bottom centre  squad status card (SquadStatus: Solo / Squad n/4, member heads, Friends only) over the big Play
--                  button (text and colour from `Play`: PLAY green, START SQUAD mustard, READY, STARTING..., CANCEL dark
--                  mustard while the countdown can still be aborted)
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
local SquadStatus = require(script.Parent.SquadStatus)
local Icon = require(script.Parent.LobbyWindow.Icon)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
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

export type Props = {
	Visible: () -> boolean,
	Gems: () -> number,
	-- "2/4" while in a squad; "" = no badge.
	Squad: () -> string,
	Play: () -> PlayButton,
	-- Card over the Play button: solo or squad, members, friends only, one status line.
	Card: () -> SquadStatus.Info,
	-- Key chip per tile ("C", "Y"); "" or missing = no chip (touch).
	Keys: () -> { [string]: string },
	OnOpen: (tile: Tile) -> (),
	OnPlay: () -> (),
	-- Tap on a free slot of the card (opens the invite list).
	OnInvite: (() -> ())?,
	-- Key chip on the Play button while it says CANCEL ("X", "ButtonX"); "" or missing = none (touch).
	CancelKey: (() -> string)?,
	Scale: (() -> number)?,
}

const MARGIN = 12
const TOP = 8
const TILE = 56
const TILE_SMALL = 48 -- compact / narrow: still over the 44 px touch target
const TILE_GAP = 6
const SIDE_GAP = 8 -- between the pill and the tiles
const PILL = 44
const PLAY_WIDTH = 210
const PLAY_HEIGHT = 52
const CARD_GAP = 8
const SHORT = 440 -- px tall screens under this get the 2 x 2 grid
const NARROW = 420 -- px wide screens under this get the small tiles
-- The column sits at 45% of the screen height, but never lower than this many real px from the bottom edge: the Roblox
-- jump / use buttons live bottom right (360 x 640, 667 x 375, 844 x 390, 1280 x 720 all keep the corner clear)
const FREE_BOTTOM = 200
const CENTER = 0.45

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
		return if props.Scale then math.max(math.min(props.Scale(), UiScale.Current()), Theme.Scale.Min) else 1
	end
	const pop = Motion.Pop(props.Visible)
	const scaled = function(): number
		return scale() * pop()
	end

	-- Real px size of the screen (this root fills it): decides the grid and the tile size.
	const area = source(Vector2.new(1000, 700))
	const compact = function(): boolean
		return area().Y < SHORT
	end
	const tile = function(): number
		return if compact() or area().X < NARROW then TILE_SMALL else TILE
	end
	-- Real px height of the right column (it scales by `scaled`): decides where it sits
	const sideHeight = source(0)
	const sideTop = function(): number
		const real = area()
		const height = sideHeight()
		const centred = real.Y * CENTER - height / 2
		const lowest = real.Y - FREE_BOTTOM - height
		return math.max(TOP, math.min(centred, lowest))
	end
	const tileSize = function(): UDim2
		return UDim2.fromOffset(tile(), tile())
	end

	const tiles: { Instance } = {}
	for index, def in TILES do
		const keyText = function(): string
			return props.Keys()[def.Key] or ""
		end
		const badge = function(): string
			return if def.Key == "Squad" then props.Squad() else ""
		end
		table.insert(
			tiles,
			CartoonButton({
				Name = def.Key,
				LayoutOrder = index,
				Size = tileSize,
				Tone = def.Tone,
				Outline = Theme.Outline.Thick,
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
						Icon(def.Icon, 24, 1),
						CartoonLabel({
							LayoutOrder = 1,
							TextSize = 20,
							Text = def.Fallback,
							Visible = not Icons.Has(def.Icon),
						}),
						CartoonLabel({
							LayoutOrder = 2,
							TextSize = Theme.MinTextSize,
							Color = def.Tone.Text,
							Stroke = if def.Tone.Stroke then 2 else 0,
							Text = def.Text,
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
						Position = UDim2.new(1, -2, 1, -6),
						Size = UDim2.fromOffset(0, 24),
						AutomaticSize = Enum.AutomaticSize.X,
						Tone = Theme.Tone.Violet,
						Lip = 2,
						Outline = 2,
						Padding = { Left = 6, Right = 6 },
						Visible = function()
							return badge() ~= ""
						end,
						Children = {
							CartoonLabel({
								Box = UDim2.new(0, 0, 1, 0),
								AutomaticSize = Enum.AutomaticSize.X,
								TextSize = Theme.MinTextSize,
								Text = badge,
							}),
						},
					}),
				},
			})
		)
	end

	const root = create("Frame")({
		Name = "LobbyHud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		-- Right column: gem pill on top, the tiles under it (one stable order, one UIScale)
		create("Frame")({
			Name = "Side",
			AnchorPoint = Vector2.new(1, 0),
			Position = function()
				return UDim2.new(1, -MARGIN, 0, sideTop())
			end,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, SIDE_GAP),
			}),

			-- Gem balance: opens the shop
			CartoonButton({
				Name = "Gems",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(0, PILL),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = Theme.Tone.Ink,
				Padding = 4,
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
					Icon("Hud/gem", PILL - 6, 1),
					CartoonLabel({
						Name = "Amount",
						LayoutOrder = 2,
						TextSize = 22,
						Text = function()
							return tostring(props.Gems())
						end,
					}),
					CartoonPanel({
						Name = "Plus",
						LayoutOrder = 3,
						Size = UDim2.fromOffset(30, 30),
						Tone = Theme.Tone.Green,
						Lip = 3,
						Children = {
							CartoonLabel({
								Box = UDim2.fromScale(1, 1),
								TextSize = 22,
								Text = "+",
							}),
						},
					}),
				},
			}),

			-- Tiles: a column, or a 2 x 2 grid on short screens (same order)
			create("Frame")({
				Name = "Tiles",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				createRaw("UIGridLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					FillDirectionMaxCells = function()
						return if compact() then 2 else 1
					end,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					SortOrder = Enum.SortOrder.LayoutOrder,
					CellSize = tileSize,
					CellPadding = UDim2.fromOffset(TILE_GAP, TILE_GAP),
				}),
				tiles,
			}),
		}),

		-- Play, with the squad status card over it
		create("Frame")({
			Name = "PlayAnchor",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -MARGIN),
			Size = UDim2.fromOffset(PLAY_WIDTH, PLAY_HEIGHT),
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),

			SquadStatus({
				Name = "Card",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -CARD_GAP),
				Info = props.Card,
				OnInvite = props.OnInvite,
			}),

			CartoonButton({
				Name = "Play",
				Size = UDim2.fromScale(1, 1),
				TextSize = 24,
				Outline = Theme.Outline.Thick,
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
	const side = root:FindFirstChild("Side") :: Frame?
	const measureSide = function()
		if side and side.AbsoluteSize.Y > 0 then
			sideHeight(side.AbsoluteSize.Y)
		end
	end
	const sideConnection = if side then side:GetPropertyChangedSignal("AbsoluteSize"):Connect(measureSide) else nil
	measureSide()
	cleanup(function()
		connection:Disconnect()
		if sideConnection then
			sideConnection:Disconnect()
		end
	end)
	return root
end
