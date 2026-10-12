--!strict
-- SquadStatus (the squad card over the lobby Play button) with the Play button under it, in a bottom-centre frame.
-- Controls: Members 1..4 (the first is the local player), Max players, Squad (off = solo), Friends only, Leader (am I
-- the leader), Starting (countdown line; Cancel on = the button says CANCEL), Phone (667 x 375 frame).
-- Member 2..4 use well-known user ids (head shots load through Players:GetUserThumbnailAsync); the last one is not ready.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonButton = require(script.Parent.Parent.CartoonButton)
local SquadStatus = require(script.Parent)

const create = Vide.create

type Controls = {
	Phone: () -> boolean,
	Squad: () -> boolean,
	Members: () -> number,
	Max: () -> number,
	FriendsOnly: () -> boolean,
	Leader: () -> boolean,
	Starting: () -> boolean,
	Cancel: () -> boolean,
}

const OTHERS: { { Id: number, Name: string } } = {
	{ Id = 1, Name = "Roblox" },
	{ Id = 156, Name = "builderman" },
	{ Id = 261, Name = "Shedletsky" },
}

local function infoOf(controls: Controls): SquadStatus.Info
	const me = Players.LocalPlayer.UserId
	const squad = controls.Squad()
	const leader = controls.Leader()
	const count = if squad then math.clamp(controls.Members(), 1, 4) else 1
	const max = if squad then math.max(controls.Max(), count) else 1
	const members: { SquadStatus.Member } = {
		{ UserId = me, Leader = leader or not squad, Ready = true, Name = Players.LocalPlayer.DisplayName },
	}
	for index = 2, count do
		const other = OTHERS[index - 1]
		table.insert(members, {
			UserId = other.Id,
			Leader = not leader and index == 2,
			Ready = index < count,
			Name = other.Name,
		})
	end
	const starting = controls.Starting()
	return {
		Squad = squad,
		Members = members,
		Max = max,
		FriendsOnly = squad and controls.FriendsOnly(),
		Status = if starting then "Starting in 3..." elseif squad then "Waiting for players" else "Pick solo or squad",
		CanInvite = squad and leader and not starting,
		Starting = starting,
	}
end

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Squad = true,
		Members = UILabs.Slider(2, 1, 4, 1),
		Max = UILabs.Slider(4, 1, 4, 1),
		FriendsOnly = false,
		Leader = true,
		Starting = false,
		Cancel = true,
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

		create("Frame")({
			Name = "Anchor",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.fromOffset(210, 52),
			BackgroundTransparency = 1,

			SquadStatus({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -8),
				Info = function()
					return infoOf(controls)
				end,
				OnInvite = function()
					print("[SquadStatus story] invite")
				end,
			}),
			CartoonButton({
				Name = "Play",
				Size = UDim2.fromScale(1, 1),
				TextSize = 24,
				Outline = Theme.Outline.Thick,
				Tone = function()
					return if controls.Starting() and controls.Cancel()
						then Theme.ToneOf(Color3.fromHex("#B07A0C"))
						else Theme.Tone.Green
				end,
				Text = function()
					return if controls.Starting() then (if controls.Cancel() then "CANCEL" else "STARTING...") else "PLAY"
				end,
			}),
		}),
	})
end)
