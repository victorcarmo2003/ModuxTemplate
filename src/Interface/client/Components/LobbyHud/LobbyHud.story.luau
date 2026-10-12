--!strict
-- LobbyHud on a screen-sized frame: "Screen" picks 360x640 (portrait phone), 667x375 (phone landscape), 1280x720,
-- 1920x1080 or the whole viewport; the global UI scale follows the screen (Theme.ScaleOf, touch floor 1 on the phones).
-- "Play" picks the Play button + squad card state (solo PLAY, forming squad START SQUAD, member READY, starting);
-- "Squad" the badge on the tile; "Keys" shows the desktop key badges. Taps print the tile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local LobbyHud = require(script.Parent)
local SquadStatus = require(script.Parent.Parent.SquadStatus)

const create = Vide.create

type Controls = {
	Screen: () -> string,
	Gems: () -> number,
	Play: () -> string,
	Squad: () -> string,
	Keys: () -> boolean,
}

const SCREENS: { [string]: Vector2 } = {
	["360x640"] = Vector2.new(360, 640),
	["667x375"] = Vector2.new(667, 375),
	["1280x720"] = Vector2.new(1280, 720),
	["1920x1080"] = Vector2.new(1920, 1080),
}

const PLAY: { [string]: LobbyHud.PlayButton } = {
	Solo = { Text = "PLAY", Kind = "Go", Enabled = true },
	Leader = { Text = "START SQUAD", Kind = "Wait", Enabled = true },
	NotReady = { Text = "READY", Kind = "Wait", Enabled = true },
	Ready = { Text = "READY!", Kind = "Go", Enabled = true },
	Starting = { Text = "STARTING...", Kind = "Go", Enabled = true },
	Waiting = { Text = "...", Kind = "Off", Enabled = false },
}

local function infoOf(state: string): SquadStatus.Info
	const me = Players.LocalPlayer.UserId
	if state == "Leader" or state == "NotReady" or state == "Ready" then
		return {
			Squad = true,
			Members = {
				{ UserId = me, Leader = state == "Leader", Ready = state ~= "NotReady" },
				{ UserId = 1, Leader = state ~= "Leader", Ready = false },
			},
			Max = 4,
			FriendsOnly = state == "Leader",
			Status = "Waiting for 1 player",
		}
	elseif state == "Starting" then
		return {
			Squad = true,
			Members = { { UserId = me, Leader = true, Ready = true }, { UserId = 1, Leader = false, Ready = true } },
			Max = 2,
			FriendsOnly = false,
			Status = "Starting in 3...",
		}
	end
	return {
		Squad = false,
		Members = { { UserId = me, Leader = true, Ready = true } },
		Max = 1,
		FriendsOnly = false,
		Status = if state == "Waiting" then "Starting..." else "Pick solo or squad",
	}
end

local function scaleOf(size: Vector2): number
	-- phones keep the touch floor of 1 (Theme.Scale.MinTouch), the others follow the viewport rule
	return if size.Y <= 640 then 1 else Theme.ScaleOf(size)
end

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Screen = UILabs.Choose({ "667x375", "360x640", "1280x720", "1920x1080", "Fill" }),
		Gems = UILabs.Slider(120, 0, 9999, 1),
		Play = UILabs.Choose({ "Solo", "Leader", "NotReady", "Ready", "Starting", "Waiting" }),
		Squad = "2/4",
		Keys = true,
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const sizeOf = function(): Vector2?
		return SCREENS[controls.Screen()]
	end

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			const size = sizeOf()
			return if size then UDim2.fromOffset(size.X, size.Y) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Theme.Color.Teal,
		BackgroundTransparency = 0.6,
		ClipsDescendants = true,

		LobbyHud({
			Visible = function()
				return true
			end,
			Gems = controls.Gems,
			Squad = function()
				return if controls.Play() == "Solo" or controls.Play() == "Waiting" then "" else controls.Squad()
			end,
			Play = function()
				return PLAY[controls.Play()] or PLAY.Solo
			end,
			Card = function()
				return infoOf(controls.Play())
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
			Scale = function()
				const size = sizeOf()
				return if size then scaleOf(size) else Theme.ScaleOf(workspace.CurrentCamera.ViewportSize)
			end,
		}),
	})
end)
