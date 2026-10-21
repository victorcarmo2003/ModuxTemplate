--!strict
-- Body: the 2D flip bar of the world progress bar (owner 2026-10-20: the flip bar IS the cooking bar, not a second billboard
-- over it). Fills its parent, which is a studs-sized BillboardGui about 1.0 x 0.8 (ProgressBar's flip mode): a Mustard "FLIP!"
-- seal on top, a Cream pill track below with the Gold NICE band and the Green PERFECT band (same constants as the score) and the
-- sausage icon riding it on an Ink pin. Every outline is a proportional Ink shape behind the colour (a pixel UIStroke would go
-- thin in studs, like Bar). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local Icons = require(script.Parent.Parent.Icons)
local Zones = require(script.Parent.Zones)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const TRACK_Y = 0.6 -- share of the height where the track is centred
const TRACK_H = 0.26 -- share of the height the track takes
const LANE_W = 0.97 -- the Cream lane inside the Ink track (the rest is the outline)
const LANE_H = 0.7
const ZONE_H = 0.74
const ZONE_EDGE_W = 0.014 -- extra width (share of the lane) of the Ink behind a zone
const ZONE_EDGE_H = 0.94
-- owner 2026-10-21: the gui went from 1.5 to 1.0 studs wide (ProgressBar FLIP_GUI); the icon and the seal keep their old
-- studs (0.25 x 1.5 and 0.44 x 1.5), so their shares grow
const MARKER_W = 0.375 -- share of the lane the sausage icon's frame takes
const SEAL_W = 0.64 -- share of the width the "FLIP!" seal takes

export type Props = {
	-- 0..1 along the bar: where the sausage is
	Marker: () -> number,
	-- Whether the bar is shown; the clock of the wobbles only runs while it is (a grill has up to 8 of these)
	Active: (() -> boolean)?,
}

local function pill(name: string, color: Color3, size: any, position: UDim2, z: number): Frame
	return create("Frame")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
	}) :: Frame
end

-- A band of the lane: an Ink pill a little bigger behind a coloured one with a soft vertical gradient
local function zone(name: string, half: number, color: Color3, order: number, pulse: (() -> number)?): { Instance }
	const middle = UDim2.fromScale(0.5, 0.5)
	const colored = pill(
		name,
		color,
		if pulse
			then function(): UDim2
				return UDim2.fromScale(half * 2, ZONE_H * pulse())
			end
			else UDim2.fromScale(half * 2, ZONE_H),
		middle,
		order + 1
	)
	createRaw("UIGradient")({
		Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.08)),
		Rotation = 90,
	}).Parent = colored
	return {
		pill(`{name}Edge`, Theme.Color.Ink, UDim2.fromScale(half * 2 + ZONE_EDGE_W, ZONE_EDGE_H), middle, order),
		colored,
	}
end

return function(props: Props): Frame
	const clock = Vide.source(0)
	const beat = RunService.Heartbeat:Connect(function(dt: number)
		const active = props.Active
		if active == nil or Vide.untrack(active) then
			clock(Vide.untrack(clock) + dt)
		end
	end)
	Vide.cleanup(function()
		beat:Disconnect()
	end)

	const rect = Icons.Rect("Ingredient/sausage")
	const sausage = Icons.ImageOf("Ingredient/sausage")

	-- the Perfect band breathes a little
	local function breath(): number
		return 1 + 0.12 * math.sin(clock() * 7)
	end

	const lane = create("Frame")({
		Name = "Lane",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(LANE_W, LANE_H),
		BackgroundColor3 = Theme.Color.Cream,
		BorderSizePixel = 0,
		ZIndex = 2,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIGradient")({
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(225, 215, 195)),
			Rotation = 90,
		}),
		zone("Nice", Zones.NICE, Theme.Color.Gold, 3, nil),
		zone("Perfect", Zones.PERFECT, Theme.Color.Green, 5, breath),
		-- the sausage riding the lane on an Ink pin; the pin is taller than the lane
		create("Frame")({
			Name = "Marker",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function(): UDim2
				return UDim2.fromScale(math.clamp(props.Marker(), 0, 1), 0.5)
			end,
			Size = UDim2.fromScale(MARKER_W, 1),
			BackgroundTransparency = 1,
			ZIndex = 10,
			pill("Pin", Theme.Color.Ink, UDim2.fromScale(0.064, 1.6), UDim2.fromScale(0.5, 0.5), 10),
			create("ImageLabel")({
				Name = "Sausage",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.2),
				Size = UDim2.fromScale(1, 2.4),
				BackgroundTransparency = 1,
				Image = sausage,
				ImageRectOffset = if rect then rect.Offset else Vector2.zero,
				ImageRectSize = if rect then rect.Size else Vector2.zero,
				ScaleType = Enum.ScaleType.Fit,
				Rotation = function(): number
					return math.sin(clock() * 14) * 10
				end,
				ZIndex = 12,
			}),
		}),
	})

	-- the "FLIP!" seal: Ink pill, Mustard pill inside, white letters with an Ink edge; it rocks
	const seal = create("Frame")({
		Name = "Seal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(SEAL_W, 0.3),
		BackgroundColor3 = Theme.Color.Ink,
		BorderSizePixel = 0,
		ZIndex = 6,
		Rotation = function(): number
			return math.sin(clock() * 6) * 4
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		create("Frame")({
			Name = "Face",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.95, 0.8),
			BackgroundColor3 = Theme.Tone.Mustard.Top,
			BorderSizePixel = 0,
			ZIndex = 7,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIGradient")({
				Color = ColorSequence.new(Theme.Tone.Mustard.Top, Theme.Tone.Mustard.Bottom),
				Rotation = 90,
			}),
			create("TextLabel")({
				Name = "Call",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.9, 0.82),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				Text = "FLIP!",
				TextScaled = true,
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeColor3 = Theme.Color.Ink,
				TextStrokeTransparency = 0,
				ZIndex = 8,
			}),
		}),
	})

	return create("Frame")({
		Name = "FlipBody",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		seal,
		-- the track: the Ink pill is its own outline
		create("Frame")({
			Name = "Track",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, TRACK_Y),
			Size = UDim2.fromScale(1, TRACK_H),
			BackgroundColor3 = Theme.Color.Ink,
			BorderSizePixel = 0,
			ZIndex = 1,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			lane,
		}),
	}) :: Frame
end
