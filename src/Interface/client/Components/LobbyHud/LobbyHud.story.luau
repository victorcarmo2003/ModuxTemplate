--!strict
-- LobbyHud on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport. "Play" picks the state of
-- the Play button (solo Play, member Ready / Not ready, leader Start, waiting "..."); "Squad" the badge on the tile;
-- "Keys" shows the desktop key chips. Taps print the tile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local LobbyHud = require(script.Parent)

const create = Vide.create

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Gems: () -> number,
	Play: () -> string,
	Squad: () -> string,
	Keys: () -> boolean,
}

const PLAY: { [string]: LobbyHud.PlayButton } = {
	Solo = { Text = "Play", Kind = "Go", Enabled = true },
	Ready = { Text = "Ready", Kind = "Go", Enabled = true },
	NotReady = { Text = "Not ready", Kind = "Wait", Enabled = true },
	Start = { Text = "Start", Kind = "Go", Enabled = true },
	Waiting = { Text = "...", Kind = "Off", Enabled = false },
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
		Gems = UILabs.Slider(120, 0, 9999, 1),
		Play = UILabs.Choose({ "Solo", "Ready", "NotReady", "Start", "Waiting" }),
		Squad = "2/4",
		Keys = true,
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

		LobbyHud({
			Visible = function()
				return true
			end,
			Gems = controls.Gems,
			Squad = controls.Squad,
			Play = function()
				return PLAY[controls.Play()] or PLAY.Solo
			end,
			Status = function()
				return if controls.Play() == "Waiting" then "Waiting for 1 more" else ""
			end,
			Keys = function()
				if not controls.Keys() then
					return {}
				end
				return { Classes = "C", Shop = "B", Codes = "K", Squad = "P" }
			end,
			OnOpen = function(tile)
				print(`[LobbyHud story] open {tile}`)
			end,
			OnPlay = function()
				print("[LobbyHud story] play")
			end,
			Scale = controls.Scale,
		}),
	})
end)
