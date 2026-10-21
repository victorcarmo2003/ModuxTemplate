--!strict
-- FlipMeter: the flip mini-game of the grill focus (DEC-311; owner 2026-10-19, restyled twice the same day: "não combina com o
-- design que a gente tem"). A sausage held at half its cook time waits for the flip. The card matches the HUD order cards: a White
-- CartoonPanel (thick Ink outline, lip) with a tilted Mustard pill tab (the sausage icon and the call), a Cream pill track with a
-- Gold NICE band and a Green PERFECT band in the middle (soft gradients, Ink edges), and the sausage icon of the sheet riding the
-- track on an Ink pin, wobbling, left and right without end; the press stops it and where it stopped is the score
-- (FlipMeter.Score). The card pops in. Status only: the press itself is the grill's pointer. Pure: only props; build it inside a
-- Vide root. Px at UI scale 1.
-- The bar in use is `Body` (the world cooking bar turns into it, ProgressBar's flip mode; `State` says which slot and where the
-- sausage is); `Meter` is the old screen card, unused. Zones: Zones.luau, the single source of PERFECT and NICE.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Zones = require(script.Zones)
local Body = require(script.Body)
local State = require(script.State)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIScale and UIGradient are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const PERFECT = Zones.PERFECT
const NICE = Zones.NICE
const WIDTH = 400
const BAR = 38
const MARKER = 64 -- px of the sausage icon riding the track

export type Props = {
	Visible: () -> boolean,
	-- 0..1 along the bar: where the sausage is
	Marker: () -> number,
	Text: () -> string,
}

-- Score 0..100 of a press at `at` (0..1): PERFECT 100..90, NICE 84..60, outside 45..20 (Content.Prep.Grades bands: Perfect >= 85,
-- Good >= 55)
local function score(at: number): number
	const distance = math.abs(at - 0.5)
	if distance <= PERFECT then
		return math.floor(100 - 10 * distance / PERFECT + 0.5)
	elseif distance <= NICE then
		return math.floor(84 - 24 * (distance - PERFECT) / (NICE - PERFECT) + 0.5)
	end
	return math.floor(45 - 25 * math.min((distance - NICE) / (0.5 - NICE), 1) + 0.5)
end

-- An icon of the shared sheets (nothing while the sheet is missing)
local function icon(name: string, size: number, z: number): ImageLabel
	const rect = Icons.Rect(name)
	return create("ImageLabel")({
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Image = Icons.ImageOf(name),
		ImageRectOffset = if rect then rect.Offset else Vector2.zero,
		ImageRectSize = if rect then rect.Size else Vector2.zero,
		ZIndex = z,
	}) :: ImageLabel
end

-- A zone of the track: a pill band around the middle; its name in small Ink-stroked letters at `spots` (shares of the band)
local function zone(name: string, half: number, color: Color3, label: string, spots: { number }, order: number): Frame
	const labels: { any } = {}
	for _, spot in spots do
		table.insert(
			labels,
			CartoonLabel({
				Name = "Label",
				Text = label,
				TextSize = 13,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(spot, 0.5),
				Box = UDim2.fromOffset(60, 20),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
				ZIndex = order + 1,
			})
		)
	end
	return create("Frame")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(half * 2, 0, 1, -8),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = order,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		createRaw("UIGradient")({
			Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3), color),
			Rotation = 90,
		}),
		labels,
	}) :: Frame
end

local function meter(props: Props): Frame
	const pop = Motion.Pop(props.Visible)
	const clock = Vide.source(0)
	const beat = RunService.Heartbeat:Connect(function(dt: number)
		clock(Vide.untrack(clock) + dt)
	end)
	Vide.cleanup(function()
		beat:Disconnect()
	end)
	return create("Frame")({
		Name = "FlipMeter",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = function(): boolean
			return props.Visible() or pop() > 0.02
		end,
		createRaw("UIScale")({
			Scale = function(): number
				return math.max(pop(), 0.01)
			end,
		}),
		CartoonPanel({
			Name = "Card",
			Tone = Theme.Tone.White,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Padding = { Top = 76, Bottom = 16, Left = 18, Right = 18 },
			Children = {
				-- the track
				CartoonPanel({
					Name = "Track",
					Tone = Theme.Tone.Cream,
					Outline = Theme.Outline.Normal,
					Radius = Theme.Radius.Pill,
					Lip = 0,
					Gloss = false,
					Size = UDim2.new(1, 0, 0, BAR),
					Children = {
						create("Frame")({
							Name = "Zones",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							-- NICE on each side of the green, PERFECT on a sparkle over it (the band is narrow)
							zone("Nice", NICE, Theme.Color.Gold, "NICE", { 0.18, 0.82 }, 2),
							zone("Perfect", PERFECT, Theme.Color.Green, "", {}, 4),
							create("Frame")({
								Name = "PerfectTag",
								AnchorPoint = Vector2.new(0.5, 1),
								Position = UDim2.new(0.5, 0, 0, -2),
								Size = UDim2.fromOffset(0, 18),
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								ZIndex = 6,
								CartoonLabel({
									Name = "Label",
									Text = "PERFECT",
									TextSize = 14,
									Color = Theme.Color.Green,
									Box = UDim2.new(0, 0, 1, 0),
									AutomaticSize = Enum.AutomaticSize.X,
									YAlignment = Enum.TextYAlignment.Center,
									ZIndex = 7,
								}),
							}),
						}),
						-- the sausage riding the track, a little Ink pointer under it
						create("Frame")({
							Name = "Marker",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = function(): UDim2
								return UDim2.fromScale(math.clamp(props.Marker(), 0, 1), 0.5)
							end,
							Size = UDim2.fromOffset(MARKER, MARKER),
							BackgroundTransparency = 1,
							ZIndex = 10,
							create("Frame")({
								Name = "Pin",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.new(0, 6, 0, BAR + 10),
								BackgroundColor3 = Theme.Color.Ink,
								BorderSizePixel = 0,
								ZIndex = 10,
								create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
							}),
							create("Frame")({
								Name = "Sausage",
								AnchorPoint = Vector2.new(0.5, 1),
								Position = UDim2.new(0.5, 0, 0.5, -BAR / 2 + 6),
								Size = UDim2.fromOffset(MARKER, MARKER),
								BackgroundTransparency = 1,
								ZIndex = 11,
								Rotation = function(): number
									-- a little wobble as it runs
									return math.sin(clock() * 14) * 10
								end,
								icon("Ingredient/sausage", MARKER, 12),
							}),
						}),
					},
				}),
			},
		}),
		-- the title tab: the spatula call in a Mustard pill with the sausage icon
		CartoonPanel({
			Name = "Title",
			Tone = Theme.Tone.Mustard,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -16),
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			Radius = Theme.Radius.Pill,
			Lip = 3,
			Padding = { Left = 10, Right = 16 },
			Rotation = -2,
			ZIndex = 20,
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				create("Frame")({
					Name = "Badge",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(26, 26),
					BackgroundTransparency = 1,
					ZIndex = 21,
					icon("Ingredient/sausage", 26, 21),
				}),
				CartoonLabel({
					Name = "Text",
					LayoutOrder = 2,
					Text = props.Text,
					TextSize = 20,
					Box = UDim2.new(0, 0, 0, 30),
					AutomaticSize = Enum.AutomaticSize.X,
					YAlignment = Enum.TextYAlignment.Center,
					ZIndex = 21,
				}),
			},
		}),
	}) :: Frame
end

return table.freeze({
	Meter = meter,
	Body = Body,
	State = State,
	Score = score,
})
