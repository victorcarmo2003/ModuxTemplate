--!strict
-- HudSpectate: what a player who is not on their feet sees (FEAT-025, DEC-091, DEC-093, DEC-115, DEC-129;
-- ui-text.md §12.3; style guide §7.2).
--   top centre  card, for a while after the change: Down "You fainted!" · "Your crew's still on shift."
--               Out (Spectator) "You're out for now." · "Watch your crew. Cheer them on!" · "Your gems are safe."
--   bottom      pill "Watching: {name}" (or "Watching the trailer" with nobody standing) + the switch hint of the
--               current device ("Tap to switch" / "Press E to switch" / "Press X to switch")
-- Wave 2: no ambulance, no revive offer, no lobby button. Status only: the switch itself is the camera's bind
-- (CameraController); nothing here is clickable (FEAT-032). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local HudPill = require(script.Parent.HudPill)

const create = Vide.create
const spring = Vide.spring
const source = Vide.source
const effect = Vide.effect
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

-- None = on their feet (nothing shown); Down = fainted tonight; Out = spectator until the next night.
export type Mode = "None" | "Down" | "Out"

export type Props = {
	Mode: () -> Mode,
	-- Show the top card (the owner turns it off after a few seconds).
	Card: () -> boolean,
	-- Name of the watched crewmate; "" = nobody standing (fixed trailer view).
	Target: () -> string,
	-- Switch hint for the current device; "" hides it.
	Hint: () -> string,
	-- Top of the card in px (under the clock). Default 62.
	CardTop: number?,
	-- Distance of the pill from the bottom in px (above the hotbar). Default 84.
	Bottom: number?,
	Name: string?,
}

const CARD_WIDTH = 300
const TITLE_SIZE = 28
const LINE_SIZE = 18
const HINT_SIZE = 16

const LINES: { [Mode]: { string } } = {
	None = {},
	Down = { "You fainted!", "Your crew's still on shift." },
	Out = { "You're out for now.", "Watch your crew. Cheer them on!", "Your gems are safe." },
}

local function line(order: number, size: number, font: Font, value: () -> string): TextLabel
	return create("TextLabel")({
		Name = `Line{order}`,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, size + 8),
		BackgroundTransparency = 1,
		FontFace = font,
		TextSize = size,
		TextColor3 = if order == 1 then Theme.Color.Text else Theme.Color.Cream,
		TextWrapped = true,
		Text = value,
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
	})
end

return function(props: Props): Frame
	const shown = function(): boolean
		return props.Mode() ~= "None"
	end
	-- Keep the last mode so the card fades out with its text.
	const initial: Mode = if props.Mode() == "None" then "Down" else props.Mode()
	const lastMode = source(initial)
	effect(function()
		const mode = props.Mode()
		if mode ~= "None" then
			lastMode(mode)
		end
	end)
	const cardAlpha = spring(function()
		return if shown() and props.Card() then 0 else 1
	end, 0.25, 1)

	const textAt = function(index: number): () -> string
		return function()
			return LINES[lastMode()][index] or ""
		end
	end

	return create("Frame")({
		Name = props.Name or "HudSpectate",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = function()
			return shown() or cardAlpha() < 0.99
		end,

		create("CanvasGroup")({
			Name = "Card",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, props.CardTop or 62),
			Size = UDim2.fromOffset(CARD_WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = Theme.Transparency.Panel,
			GroupTransparency = cardAlpha,
			Visible = function()
				return cardAlpha() < 0.99
			end,
			create("UICorner")({ CornerRadius = UDim.new(0, 18) }),
			createRaw("UIPadding")({
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 10),
			}),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			line(1, TITLE_SIZE, Theme.Font.Title, textAt(1)),
			line(2, LINE_SIZE, Theme.Font.Body, textAt(2)),
			create("Frame")({
				Name = "Third",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = function()
					return textAt(3)() ~= ""
				end,
				line(3, LINE_SIZE, Theme.Font.Body, textAt(3)),
			}),
		}),

		create("Frame")({
			Name = "Watching",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -(props.Bottom or 84)),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Visible = shown,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			HudPill({
				Name = "Target",
				LayoutOrder = 1,
				Height = 44,
				TextSize = 20,
				MinWidth = 180,
				Text = function()
					const target = props.Target()
					return if target == "" then "Watching the trailer" else `Watching: {target}`
				end,
			}),
			create("TextLabel")({
				Name = "Hint",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, HINT_SIZE + 6),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Body,
				TextSize = HINT_SIZE,
				TextColor3 = Theme.Color.Cream,
				Text = props.Hint,
				Visible = function()
					return props.Hint() ~= ""
				end,
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
			}),
		}),
	})
end
