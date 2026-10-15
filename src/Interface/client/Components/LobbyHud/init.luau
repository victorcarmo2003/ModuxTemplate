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
--   bottom centre  squad status card (SquadStatus: Solo / Squad n/4, member heads, Friends only) over the big Play
--                  button (text and colour from `Play`: PLAY green, START SQUAD mustard, READY, STARTING..., CANCEL dark
--                  mustard while the countdown can still be aborted). Shown only while `PlayShown` (TASK-296: the
--                  player is in a squad); pops in / out with Motion.Pop
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
	-- Card + Play button shown (in a squad, TASK-296); missing = always shown.
	PlayShown: (() -> boolean)?,
	Scale: (() -> number)?,
}

const MARGIN = 12
const TOP = 8
const TILE = 56
const TILE_SMALL = 48 -- compact / narrow: still over the 44 px touch target
const TILE_GAP = 6
const PILL = 44
const PLAY_WIDTH = 210
const PLAY_HEIGHT = 52
const CARD_GAP = 8
const SHORT = 440 -- px tall screens under this get the 2 x 2 grid
const NARROW = 420 -- px wide screens under this get the small tiles
-- The gem pill sits at the middle of the screen height, but never lower than this many real px from the bottom edge: the
-- Roblox jump / use buttons live bottom right (360 x 640, 667 x 375, 844 x 390, 1280 x 720 all keep the corner clear)
const FREE_BOTTOM = 200
-- The tile column sits at the middle too, but never higher than this many real px from the top edge: the Roblox top bar
-- (menu, chat, microphone; ~58 px, HudController TOPBAR_REAL) is over the top-left corner
const TOPBAR_FREE = 64

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
	const playShown = function(): boolean
		return if props.PlayShown then props.PlayShown() else true
	end
	const playPop = Motion.Pop(playShown)

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
		}),

		-- Left, centred vertically: the tiles, a column or a 2 x 2 grid on short screens (same order, one UIScale)
		create("Frame")({
			Name = "Menu",
			Position = function()
				return UDim2.fromOffset(MARGIN, menuTop())
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
				CellSize = tileSize,
				CellPadding = UDim2.fromOffset(TILE_GAP, TILE_GAP),
			}),
			tiles,
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
