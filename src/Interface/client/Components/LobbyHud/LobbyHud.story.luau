--!strict
-- LobbyHud on a screen-sized frame: "Screen" picks 360x640 (portrait phone), 667x375 (phone landscape), 1280x720,
-- 1920x1080 or the whole viewport; the global UI scale follows the screen (Theme.ScaleOf, touch floor 1 on the phones).
-- "Play" picks the Play button + squad card state (solo PLAY, room still being set up SET UP ROOM, leader of a created
-- room START + the gear (TASK-306), member READY, starting);
-- "Squad" the badge on the tile; "Keys" shows the desktop key badges; "InSquad" off hides the card + Play button
-- (TASK-296: no squad yet; toggle it to see the pop). Tiles on the left, gem pill on the right (TASK-295). Taps print
-- the tile. "Online" picks the players-online pill count at the top centre (TASK-312; K / M format; 0 = hidden).
-- "PadRoom" puts the player in a pad room (owner request 2026-10-21): pad bar with the state line over START NOW and the
-- queue strip (faces + EXIT) instead of the online pill; "PadMembers" picks how many are in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local LobbyHud = require(script.Parent)

const create = Vide.create

type Controls = {
	Screen: () -> string,
	Gems: () -> number,
	Play: () -> string,
	Squad: () -> string,
	Keys: () -> boolean,
	InSquad: () -> boolean,
	Online: () -> string,
	PadRoom: () -> boolean,
	PadMembers: () -> number,
}

-- public Roblox accounts, only for the head shots of the story
const USERS = { 1, 156, 261, 2032622 }

const SCREENS: { [string]: Vector2 } = {
	["360x640"] = Vector2.new(360, 640),
	["667x375"] = Vector2.new(667, 375),
	["1280x720"] = Vector2.new(1280, 720),
	["1920x1080"] = Vector2.new(1920, 1080),
}

const PLAY: { [string]: LobbyHud.PlayButton } = {
	Solo = { Text = "PLAY", Kind = "Go", Enabled = true },
	Setup = { Text = "SET UP ROOM", Kind = "Wait", Enabled = true },
	Leader = { Text = "START", Kind = "Go", Enabled = true },
	NotReady = { Text = "READY", Kind = "Wait", Enabled = true },
	Ready = { Text = "READY!", Kind = "Go", Enabled = true },
	Starting = { Text = "STARTING...", Kind = "Go", Enabled = true },
	Cancel = { Text = "CANCEL", Kind = "Cancel", Enabled = true },
	Waiting = { Text = "...", Kind = "Off", Enabled = false },
}

local function scaleOf(size: Vector2): number
	-- phones keep the touch floor of 1 (Theme.Scale.MinTouch), the others follow the viewport rule
	return if size.Y <= 640 then 1 else Theme.ScaleOf(size)
end

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Screen = UILabs.Choose({ "667x375", "360x640", "1280x720", "1920x1080", "Fill" }),
		Gems = UILabs.Slider(3750, 0, 50000, 50),
		Play = UILabs.Choose({ "Solo", "Setup", "Leader", "NotReady", "Ready", "Starting", "Cancel", "Waiting" }),
		Squad = "2/4",
		Keys = true,
		InSquad = true,
		Online = UILabs.Choose({ "200", "1", "1234", "12000", "1250000", "0" }),
		PadRoom = true,
		PadMembers = UILabs.Slider(2, 1, 4, 1),
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
			CancelKey = function()
				return if controls.Keys() then "X" else ""
			end,
			PlayShown = controls.InSquad,
			Online = function()
				return tonumber(controls.Online()) or 0
			end,
			Gear = function()
				return controls.Play() == "Leader"
			end,
			OnGear = function()
				print("[LobbyHud story] room setup")
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
			Pad = function()
				return if controls.PadRoom() then { Leader = true, Skip = false, Friends = true } else nil
			end,
			OnPad = function(action)
				print(`[LobbyHud story] pad {action}`)
			end,
			Queue = function()
				if not controls.PadRoom() then
					return nil
				end
				const members: { number } = {}
				for index = 1, math.floor(controls.PadMembers()) do
					members[index] = USERS[index]
				end
				return { Members = members, Max = 4, Leader = USERS[1], Status = "Starting in 9..." }
			end,
			OnExit = function()
				print("[LobbyHud story] exit")
			end,
			Scale = function()
				const size = sizeOf()
				return if size then scaleOf(size) else Theme.ScaleOf(workspace.CurrentCamera.ViewportSize)
			end,
		}),
	})
end)
