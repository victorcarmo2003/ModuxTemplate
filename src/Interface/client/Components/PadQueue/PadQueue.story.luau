--!strict
-- PadQueue: "Count" members in a room of "Max" seats (leader first, Mustard ring); "Add" pops one more in. EXIT prints.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local PadQueue = require(script.Parent)

const create = Vide.create

type Controls = {
	Count: () -> number,
	Max: () -> number,
}

-- public Roblox accounts, only for the head shots of the story
const USERS = { 1, 156, 261, 2032622 }

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Count = UILabs.Slider(1, 0, 4, 1),
		Max = UILabs.Slider(4, 1, 4, 1),
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	return create("Frame")({
		Name = "Screen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Teal,
		BackgroundTransparency = 0.6,
		PadQueue({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 12),
			Members = function()
				const out: { number } = {}
				for index = 1, math.floor(controls.Count()) do
					out[index] = USERS[index]
				end
				return out
			end,
			Max = function()
				return math.floor(controls.Max())
			end,
			Leader = function()
				return USERS[1]
			end,
			OnExit = function()
				print("[PadQueue story] EXIT")
			end,
		}),
	})
end)
