--!strict
-- StationTag: the name plate over a prep station of the trailer (docs/tech/prep-mode.md §4; spec §6.7), seen by the OTHER
-- players: who works there and on which tab. One small Cream card: the station number in a round Mustard seal, the name of
-- the crew member (truncated) and the tab they are on (Order / Grill / Build / Serve) as a word plus a shape mark.
-- A free station shows "Free" in Slate. Sized in studs (a BillboardGui, like PadTag): it shrinks with distance, faces the
-- player, MaxDistance 40 studs. The owner (PrepController, P8) feeds it from the PrepSeats set; the own seat is not tagged
-- (the player is in the focused view). Pure: only props. Build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; BillboardGui, CanvasGroup, UIScale and UIListLayout are not all among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	-- 1..4
	Station: number,
	-- Name of the crew member working here; "" = the station is free.
	Who: () -> string,
	-- Label of the tab they are on (Content.Prep.Tabs Label).
	Tab: () -> string,
	-- World-space offset over the adornee (studs).
	Offset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 5.2 -- studs
const HEIGHT = 1.5
const DEFAULT_DISTANCE = 40
const NAME_CHARS = 12

local function short(name: string): string
	const length = utf8.len(name)
	if length == nil or length <= NAME_CHARS then
		return name
	end
	const cut = (utf8.offset(name, NAME_CHARS + 1) or (#name + 1)) - 1
	return string.sub(name, 1, cut) .. "..."
end

return function(props: Props): BillboardGui
	const busy = function(): boolean
		return props.Who() ~= ""
	end
	const shown = function(): boolean
		return props.Visible() and not Cinematic.Active()
	end
	const reveal = Motion.Reveal(shown)
	const pop = Motion.Pop(shown)

	return createRaw("BillboardGui")({
		Name = props.Name or "StationTag",
		Adornee = props.Adornee,
		Size = UDim2.fromScale(WIDTH, HEIGHT),
		StudsOffsetWorldSpace = props.Offset or Vector3.zero,
		MaxDistance = props.MaxDistance or DEFAULT_DISTANCE,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = function()
			return shown() or reveal() > 0.02
		end,

		createRaw("CanvasGroup")({
			Name = "Root",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			GroupTransparency = function()
				return 1 - reveal()
			end,
			createRaw("UIScale")({
				Scale = function()
					return 0.6 + 0.4 * pop()
				end,
			}),
			CartoonPanel({
				Name = "Card",
				Tone = function()
					return if busy() then Theme.Tone.Cream else Theme.Tone.Slate
				end,
				Radius = Theme.Radius.Pill,
				Size = UDim2.fromScale(1, 1),
				Padding = { Left = 6, Right = 10 },
				Children = {
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					-- number seal
					create("Frame")({
						Name = "Seal",
						LayoutOrder = 1,
						Size = UDim2.fromScale(0, 0.78),
						BackgroundColor3 = Theme.Tone.Mustard.Bottom,
						createRaw("UIAspectRatioConstraint")({}),
						create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						createRaw("UIStroke")({
							Color = Theme.Color.Ink,
							Thickness = 3,
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						}),
						CartoonLabel({
							Text = tostring(props.Station),
							Color = Theme.Color.Ink,
							Stroke = 0,
							Scaled = true,
							MaxTextSize = 40,
							Box = UDim2.fromScale(1, 1),
							XAlignment = Enum.TextXAlignment.Center,
							YAlignment = Enum.TextYAlignment.Center,
						}),
					}),
					create("Frame")({
						Name = "Lines",
						LayoutOrder = 2,
						Size = UDim2.fromScale(0.72, 0.9),
						BackgroundTransparency = 1,
						CartoonLabel({
							Name = "Who",
							Text = function()
								return if busy() then short(props.Who()) else "Free"
							end,
							Color = Theme.Color.Ink,
							Stroke = 0,
							Scaled = true,
							MaxTextSize = 40,
							Box = UDim2.fromScale(1, 0.55),
							XAlignment = Enum.TextXAlignment.Left,
							YAlignment = Enum.TextYAlignment.Center,
						}),
						CartoonLabel({
							Name = "Tab",
							Position = UDim2.fromScale(0, 0.55),
							Text = function()
								return if busy() then props.Tab() else ""
							end,
							Color = Theme.Color.Ink,
							Stroke = 0,
							Scaled = true,
							MaxTextSize = 30,
							Box = UDim2.fromScale(1, 0.4),
							XAlignment = Enum.TextXAlignment.Left,
							YAlignment = Enum.TextYAlignment.Center,
						}),
					}),
				},
			}),
		}),
	}) :: BillboardGui
end
