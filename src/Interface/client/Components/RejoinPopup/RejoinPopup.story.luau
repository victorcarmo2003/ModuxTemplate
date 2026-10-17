--!strict
-- RejoinPopup on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport. "Offer" shows / hides the
-- card (pop in / shrink away); Day 0 = the "still starting" line; Rejoin turns Busy for 2 s ("Joining...") then hides,
-- Dismiss hides it at once. "Resume" = the resume offer (DEC-080), counting down from 12:40.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local RejoinPopup = require(script.Parent)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const untrack = Vide.untrack

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Offer: () -> boolean,
	Day: () -> number,
	Night: () -> boolean,
	Resume: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
		Offer = true,
		Day = UILabs.Slider(3, 0, 10, 1),
		Night = true,
		Resume = false,
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const open = source(true)
	const busy = source(false)
	const now = source(os.clock())
	const endsAt = os.clock() + 760
	local alive = true
	task.spawn(function()
		while alive do
			now(os.clock())
			task.wait(0.5)
		end
	end)
	Vide.cleanup(function()
		alive = false
	end)
	effect(function()
		const value = controls.Offer()
		untrack(function()
			open(value)
			busy(false)
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

		RejoinPopup({
			Offer = function(): RejoinPopup.Offer?
				if not open() then
					return nil
				end
				return { Day = controls.Day(), IsNight = controls.Night(), Resume = controls.Resume(), EndsAt = endsAt }
			end,
			Busy = busy,
			OnRejoin = function()
				print("[RejoinPopup story] rejoin")
				busy(true)
				task.delay(2, function()
					open(false)
					busy(false)
				end)
			end,
			OnDismiss = function()
				print("[RejoinPopup story] dismiss")
				open(false)
			end,
			Scale = controls.Scale,
			Now = now,
		}),
	})
end)
