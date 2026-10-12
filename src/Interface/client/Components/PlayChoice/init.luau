--!strict
-- PlayChoice: what the lobby Play button opens outside a squad (user request 2026-10-11, Provisional), cartoon kit
-- (AST-091), mobile first. A small LobbyWindow (420 x 220 at Scale 1) with two big buttons side by side:
--   Play Solo     (Green)   "Start right now"      -> the caller sends PartyQuickPlay { Mode = "Solo" }
--   Create Squad  (Mustard) "Invite your friends"  -> the caller sends PartyQuickPlay { Mode = "Squad" }
-- Each button: icon (text fallback while the sheet is missing), title, one short line, key chip ("1" / "2") when the
-- device is not touch (`Keys`). Pure: only props; the server creates the squad and decides.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local KeyChip = require(script.Parent.KeyChip)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local LobbyWindow = require(script.Parent.LobbyWindow)
local Icon = require(script.Parent.LobbyWindow.Icon)

const create = Vide.create

export type Choice = "Solo" | "Squad"

export type Props = {
	Visible: () -> boolean,
	-- a request is on its way: both buttons off
	Busy: (() -> boolean)?,
	-- key chip per choice ({ Solo = "1", Squad = "2" }); missing or "" = no chip (touch)
	Keys: (() -> { [string]: string })?,
	OnChoose: (choice: Choice) -> (),
	OnClose: () -> (),
	Scale: (() -> number)?,
}

type Def = { Key: Choice, Title: string, Line: string, Icon: string, Fallback: string, Tone: Theme.Tone }

const DEFS: { Def } = {
	{
		Key = "Solo",
		Title = "Play Solo",
		Line = "Start right now",
		Icon = "Ui/paw",
		Fallback = ">",
		Tone = Theme.Tone.Green,
	},
	{
		Key = "Squad",
		Title = "Create Squad",
		Line = "Invite your friends",
		Icon = "Ui/friends",
		Fallback = "+",
		Tone = Theme.Tone.Mustard,
	},
}

const WIDTH = 420
const HEIGHT = 220
const GAP = 10
const ICON = 40

return function(props: Props): Frame
	const busy = function(): boolean
		return props.Busy ~= nil and props.Busy()
	end

	const buttons: { Instance } = {}
	for index, def in DEFS do
		const keyText = function(): string
			return if props.Keys then props.Keys()[def.Key] or "" else ""
		end
		const textColor = def.Tone.Text
		const stroke = if def.Tone.Stroke then 2 else 0
		table.insert(
			buttons,
			CartoonButton({
				-- instance names: LobbyController selects "Solo" first on a gamepad
				Name = def.Key,
				LayoutOrder = index,
				Size = UDim2.new(0.5, -GAP / 2, 1, 0),
				Tone = def.Tone,
				Outline = Theme.Outline.Thick,
				Radius = Theme.Radius.Card,
				Studs = true,
				Padding = 6,
				Enabled = function()
					return not busy()
				end,
				OnActivated = function()
					props.OnChoose(def.Key)
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
							Padding = UDim.new(0, 2),
						}),
						Icon(def.Icon, ICON, 1),
						CartoonLabel({
							LayoutOrder = 1,
							TextSize = 28,
							Color = textColor,
							Stroke = stroke,
							Text = def.Fallback,
							Visible = not Icons.Has(def.Icon),
						}),
						CartoonLabel({
							Name = "Title",
							LayoutOrder = 2,
							TextSize = 24,
							Color = textColor,
							Stroke = if def.Tone.Stroke then Theme.TextStroke(24) else 0,
							Text = def.Title,
						}),
						CartoonLabel({
							Name = "Line",
							LayoutOrder = 3,
							TextSize = Theme.MinTextSize,
							Color = textColor,
							Stroke = stroke,
							Transparency = 0.15,
							Text = def.Line,
						}),
					}),
					-- key chip (desktop / gamepad): inside the top-left corner of the card, number centred in the badge
					KeyChip({
						Name = "Key",
						Position = UDim2.fromOffset(2, 2),
						Text = keyText,
					}),
				},
			})
		)
	end

	return LobbyWindow({
		Name = "PlayChoice",
		Title = "Play",
		Icon = "Ui/paw",
		Size = Vector2.new(WIDTH, HEIGHT),
		Visible = props.Visible,
		Scale = props.Scale,
		OnClose = props.OnClose,
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, GAP),
			}),
			buttons,
		},
	})
end
