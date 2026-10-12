--!strict
-- StrokeCanvas: a zig-zag drawn point by point (the pool reuses 63 segments, never more than 64 points). Controls: Points (0 to
-- 64; drag it to "draw"), Guide (the faint target path), Meter (the sauce meter, with Fill against the target window), Sauce.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonPanel = require(script.Parent.Parent.CartoonPanel)
local StrokeCanvas = require(script.Parent)

const create = Vide.create

type Controls = {
	Points: () -> number,
	Guide: () -> boolean,
	Meter: () -> boolean,
	Fill: () -> number,
	Sauce: () -> string,
}

const COLORS: { [string]: Color3 } = {
	Ketchup = Color3.fromHex("#E2402E"),
	Mustard = Color3.fromHex("#F6C12B"),
	Cream = Color3.fromHex("#FFF8EA"),
}

-- 64 points of a zig-zag over the canvas (x runs 0.08 to 0.92, y swings 0.3 to 0.7)
local function zigzag(): { Vector2 }
	const list: { Vector2 } = {}
	for index = 0, 63 do
		const t = index / 63
		const swing = math.abs((t * 8) % 2 - 1)
		table.insert(list, Vector2.new(0.08 + 0.84 * t, 0.3 + 0.4 * swing))
	end
	return list
end

const FULL = zigzag()

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Points = UILabs.Slider(40, 0, 64, 1),
		Guide = true,
		Meter = true,
		Fill = UILabs.Slider(0.6, 0, 1, 0.05),
		Sauce = UILabs.Choose({ "Ketchup", "Mustard", "Cream" }),
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),

		CartoonPanel({
			Position = UDim2.fromOffset(24, 24),
			Size = UDim2.fromOffset(360, 160),
			Tone = Theme.Tone.Cream,
			Radius = Theme.Radius.Card,
			Children = {
				StrokeCanvas({
					Points = function(): { Vector2 }
						return table.move(FULL, 1, controls.Points(), 1, {})
					end,
					Guide = function(): { Vector2 }
						return if controls.Guide() then FULL else {}
					end,
					Color = function(): Color3
						return COLORS[controls.Sauce()] or Theme.Tone.Mustard.Bottom
					end,
					Meter = function(): StrokeCanvas.Meter?
						return if controls.Meter() then { Fill = controls.Fill(), Target = 0.6, Window = 0.25 } else nil
					end,
				}),
			},
		}),
	})
end)
