--!strict
-- SquadStatus (the card over the lobby Play button) in a bottom-centre frame: solo, a forming squad, a full one,
-- friends only, starting. "Phone" frames it 667 x 375. The head shots are the player's own user id.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local SquadStatus = require(script.Parent)

const create = Vide.create

type Controls = {
	Phone: () -> boolean,
	State: () -> string,
}

local function member(userId: number, leader: boolean, ready: boolean): SquadStatus.Member
	return { UserId = userId, Leader = leader, Ready = ready }
end

local function infoOf(state: string): SquadStatus.Info
	const me = Players.LocalPlayer.UserId
	if state == "Squad 2/4" then
		return {
			Squad = true,
			Members = { member(me, true, true), member(1, false, false) },
			Max = 4,
			FriendsOnly = false,
			Status = "Waiting for 1 player",
		}
	elseif state == "Full" then
		return {
			Squad = true,
			Members = { member(me, false, true), member(1, true, true), member(156, false, true), member(261, false, false) },
			Max = 4,
			FriendsOnly = false,
			Status = "Everyone is ready!",
		}
	elseif state == "Friends only" then
		return {
			Squad = true,
			Members = { member(me, true, true) },
			Max = 3,
			FriendsOnly = true,
			Status = "Invite your friends",
		}
	elseif state == "Starting" then
		return {
			Squad = true,
			Members = { member(me, true, true), member(1, false, true) },
			Max = 2,
			FriendsOnly = false,
			Status = "Starting in 3...",
		}
	end
	return { Squad = false, Members = { member(me, true, true) }, Max = 1, FriendsOnly = false, Status = "Pick solo or squad" }
end

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		State = UILabs.Choose({ "Solo", "Squad 2/4", "Full", "Friends only", "Starting" }),
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

		SquadStatus({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -72),
			Info = function()
				return infoOf(controls.State())
			end,
		}),
	})
end)
