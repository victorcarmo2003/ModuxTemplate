--!strict
-- Vignette: dark screen edges for the dark and low sanity (AST-084, Rascunho; DEC-038: only on the owner's client).
-- Four edge bands, each a Frame with a linear UIGradient (opaque at the edge, clear inward), until the
-- `T_Vignette` texture (AST-084, 512²) exists. A full-screen `Blackout` layer covers the faint fade (FEAT-025).
-- Never red, never shakes (AST-084 rules): the color is a cold near-black from the night palette (style guide §5.3).
-- Pure: only props. Mount it in a ScreenGui with `IgnoreGuiInset = true` under the HUD (lower DisplayOrder).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create

export type Props = {
	-- 0..1: opacity at the very edge (AST-084 "vinheta 25%" = 0.25).
	Strength: () -> number,
	-- 0..1: full-screen dark layer (faint fade). Defaults to 0.
	Blackout: (() -> number)?,
	-- Edge color. Defaults to the night Decay color `#0B0D1E` (style guide §5.3).
	Color: Color3?,
	Name: string?,
}

const EDGE_COLOR = Color3.fromHex("#0B0D1E")
-- Depth of each band, in fraction of the screen: deeper top/bottom reads as a round vignette on a wide phone.
const DEPTH_Y = 0.38
const DEPTH_X = 0.28
-- Soft falloff: most of the dark sits on the outer third of the band.
const FALLOFF = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.35, 0.45),
	NumberSequenceKeypoint.new(0.7, 0.85),
	NumberSequenceKeypoint.new(1, 1),
})

return function(props: Props): Frame
	const color = props.Color or EDGE_COLOR

	local function transparency(): number
		return 1 - math.clamp(props.Strength(), 0, 1)
	end

	-- UIGradient rotation: 0 = opaque on the left; 90 = on top; 180 = on the right; 270 = at the bottom.
	local function edge(name: string, size: UDim2, position: UDim2, anchor: Vector2, rotation: number): Frame
		return create("Frame")({
			Name = name,
			AnchorPoint = anchor,
			Position = position,
			Size = size,
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			Visible = function()
				return props.Strength() > 0.001
			end,

			create("UIGradient")({
				Rotation = rotation,
				Transparency = FALLOFF,
			}),
		})
	end

	return create("Frame")({
		Name = props.Name or "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,

		edge("Top", UDim2.fromScale(1, DEPTH_Y), UDim2.fromScale(0, 0), Vector2.zero, 90),
		edge("Bottom", UDim2.fromScale(1, DEPTH_Y), UDim2.fromScale(0, 1), Vector2.new(0, 1), 270),
		edge("Left", UDim2.fromScale(DEPTH_X, 1), UDim2.fromScale(0, 0), Vector2.zero, 0),
		edge("Right", UDim2.fromScale(DEPTH_X, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180),

		create("Frame")({
			Name = "Blackout",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 2,
			BackgroundTransparency = function()
				return 1 - math.clamp(if props.Blackout then props.Blackout() else 0, 0, 1)
			end,
			Visible = function()
				return props.Blackout ~= nil and props.Blackout() > 0.001
			end,
		}),
	})
end
