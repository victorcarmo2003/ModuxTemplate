--!strict
-- InvitePopup on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport. "Invite" shows / hides the
-- card (pop in / shrink away); Accept and Decline hide it and print the answer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local InvitePopup = require(script.Parent)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const untrack = Vide.untrack

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Invite: () -> boolean,
	Name: () -> string,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 1, 2, 0.05),
		Invite = true,
		Name = "MustardMaster",
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const open = source(true)
	effect(function()
		const value = controls.Invite()
		untrack(function()
			open(value)
			return nil
		end)
	end)

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

		InvitePopup({
			Invite = function(): InvitePopup.Invite?
				if not open() then
					return nil
				end
				return { UserId = 156, Name = controls.Name() }
			end,
			OnAccept = function()
				print("[InvitePopup story] accept")
				open(false)
			end,
			OnDecline = function()
				print("[InvitePopup story] decline")
				open(false)
			end,
			Scale = controls.Scale,
		}),
	})
end)
