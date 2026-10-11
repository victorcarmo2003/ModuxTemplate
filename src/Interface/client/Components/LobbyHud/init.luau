--!strict
-- LobbyHud: the lobby HUD (user request 2026-10-11), cartoon kit (AST-091), mobile first.
-- Laid out for the smallest landscape phone (620 x 340 px at Scale 1, inside CoreUISafeInsets); `Scale` grows it.
--   top left     gem balance pill (a button: opens the gem shop), gem icon + amount + "+"
--   left column  four big tiles (62 px): Classes · Shop · Codes · Squad (Squad shows "2/4" when in a squad)
--   bottom centre the big Play button (text and colour from `Play`: Play / Ready / Not ready / Start / ...)
-- Kept clear of the mobile thumbstick (bottom left) and jump button (bottom right). Key chips ("C", "Y"...) on the tiles
-- when the device is not touch (`Keys`). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Icon = require(script.Parent.LobbyWindow.Icon)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Tile = "Classes" | "Shop" | "Codes" | "Squad"

export type PlayKind = "Go" | "Wait" | "Off"

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
	-- Key chip per tile ("C", "Y"); "" or missing = no chip (touch).
	Keys: () -> { [string]: string },
	OnOpen: (tile: Tile) -> (),
	OnPlay: () -> (),
	Scale: (() -> number)?,
	-- Short line over the Play button ("Waiting for 1 more"); "" = none.
	Status: (() -> string)?,
}

const MARGIN = 12
const TILE = 62
const TILE_GAP = 6
const TOP = 60 -- first tile under the gem pill
const PILL = 44
const PLAY_WIDTH = 190
const PLAY_HEIGHT = 60

const PLAY_TONE: { [PlayKind]: Theme.Tone } = {
	Go = Theme.Tone.Green,
	Wait = Theme.Tone.Mustard,
	Off = Theme.Tone.Slate,
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
		return if props.Scale then math.max(props.Scale(), 1) else 1
	end
	const pop = Motion.Pop(props.Visible)
	const scaled = function(): number
		return scale() * pop()
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
				Size = UDim2.fromOffset(TILE, TILE),
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
						Icon(def.Icon, 30, 1),
						CartoonLabel({
							LayoutOrder = 1,
							TextSize = 22,
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
					-- key chip (desktop / gamepad)
					CartoonPanel({
						Name = "Key",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, 10, 0, -12),
						Size = UDim2.fromOffset(24, 24),
						AutomaticSize = Enum.AutomaticSize.X,
						Tone = Theme.Tone.Ink,
						Lip = 2,
						Outline = 2,
						Padding = { Left = 4, Right = 4 },
						Visible = function()
							return keyText() ~= ""
						end,
						Children = {
							CartoonLabel({
								Box = UDim2.new(0, 0, 1, 0),
								AutomaticSize = Enum.AutomaticSize.X,
								TextSize = Theme.MinTextSize,
								Text = keyText,
							}),
						},
					}),
					-- squad badge
					CartoonPanel({
						Name = "Badge",
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, 12, 1, 8),
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

	return create("Frame")({
		Name = "LobbyHud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		-- Gem balance: opens the shop
		create("Frame")({
			Name = "GemsAnchor",
			Position = UDim2.fromOffset(MARGIN, 8),
			Size = UDim2.fromOffset(0, PILL),
			AutomaticSize = Enum.AutomaticSize.X,
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

		-- Left column of tiles
		create("Frame")({
			Name = "Tiles",
			Position = UDim2.fromOffset(MARGIN, TOP),
			Size = UDim2.fromOffset(TILE, TILE * #TILES + TILE_GAP * (#TILES - 1)),
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, TILE_GAP),
			}),
			tiles,
		}),

		-- Play
		create("Frame")({
			Name = "PlayAnchor",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -MARGIN),
			Size = UDim2.fromOffset(PLAY_WIDTH, PLAY_HEIGHT),
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = scaled }),

			CartoonLabel({
				Name = "Status",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -4),
				TextSize = 16,
				Text = function()
					return if props.Status then props.Status() else ""
				end,
				Visible = function()
					return props.Status ~= nil and props.Status() ~= ""
				end,
			}),

			CartoonButton({
				Name = "Play",
				Size = UDim2.fromScale(1, 1),
				TextSize = 30,
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
		}),
	}) :: Frame
end
