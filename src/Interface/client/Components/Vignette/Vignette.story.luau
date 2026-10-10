--!strict
-- Vignette over a lit "scene" on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport.
-- Presets follow AST-084: Dark 0.25, Mid 0.20, Night 0.35; "Pulse" shows the < 25 sanity breathing (0.5 Hz).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local Vignette = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup

type Controls = {
	Phone: () -> boolean,
	Strength: () -> number,
	Pulse: () -> boolean,
	Blackout: () -> number,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Strength = UILabs.Slider(0.35, 0, 1, 0.01),
		Pulse = false,
		Blackout = UILabs.Slider(0, 0, 1, 0.01),
	},
}, function(props)
	const controls: Controls = (props.controls :: any)

	const clock = source(0)
	const connection = RunService.Heartbeat:Connect(function(dt: number)
		clock(clock() + dt)
	end)
	cleanup(connection)

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Theme.Color.Cream,
		ClipsDescendants = true,

		Vignette({
			Strength = function()
				const base = controls.Strength()
				if not controls.Pulse() then
					return base
				end
				return base * (0.8 + 0.2 * math.sin(clock() * math.pi))
			end,
			Blackout = controls.Blackout,
		}),
	})
end)
