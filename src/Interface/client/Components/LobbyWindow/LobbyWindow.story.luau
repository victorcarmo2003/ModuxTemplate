--!strict
-- LobbyWindow on a screen-sized frame ("Screen": 360x640, 667x375, 1280x720, 1920x1080 or the whole viewport; the window shrinks to fit a narrow one). "Open" pops it in/out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)
local LobbyWindow = require(script.Parent)

const create = Vide.create

-- Screen sizes of the lobby checks (phone portrait, phone landscape, 720p, 1080p); "Fill" = the whole viewport.
const SCREENS: { [string]: Vector2 } = {
	["360x640"] = Vector2.new(360, 640),
	["667x375"] = Vector2.new(667, 375),
	["1280x720"] = Vector2.new(1280, 720),
	["1920x1080"] = Vector2.new(1920, 1080),
}

type Controls = {
	Screen: () -> string,
	Open: () -> boolean,
	Scale: () -> number,
	Gems: () -> number,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Screen = UILabs.Choose({ "667x375", "360x640", "1280x720", "1920x1080", "Fill" }),
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
			const size = SCREENS[controls.Screen()]
			return if size then UDim2.fromOffset(size.X, size.Y) else UDim2.fromScale(1, 1)
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
