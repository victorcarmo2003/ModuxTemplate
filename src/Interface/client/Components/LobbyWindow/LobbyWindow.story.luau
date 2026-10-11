--!strict
-- LobbyWindow on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport. "Open" pops it in/out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)
local LobbyWindow = require(script.Parent)

const create = Vide.create

type Controls = {
	Phone: () -> boolean,
	Open: () -> boolean,
	Scale: () -> number,
	Gems: () -> number,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Open = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
		Gems = UILabs.Slider(120, 0, 9999, 1),
	},
}, function(props)
	const controls: Controls = (props.controls :: any)

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Theme.Color.Teal,
		BackgroundTransparency = 0.6,
		ClipsDescendants = true,

		LobbyWindow({
			Title = "Window",
			Icon = "Ui/info",
			Size = Vector2.new(460, 280),
			Visible = controls.Open,
			Scale = controls.Scale,
			Gems = controls.Gems,
			OnClose = function()
				print("[LobbyWindow story] close")
			end,
			Children = {
				CartoonLabel({
					Box = UDim2.fromScale(1, 1),
					TextSize = 18,
					Text = "Body",
				}),
			},
		}),
	})
end)
