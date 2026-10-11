--!strict
-- PlayChoice on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport. "Open" pops it in / out;
-- a choice prints, turns the buttons off for "Latency" s (the server answering) and closes the window. "Keys" shows the
-- desktop key chips.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local PlayChoice = require(script.Parent)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const untrack = Vide.untrack
const cleanup = Vide.cleanup

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Open: () -> boolean,
	Keys: () -> boolean,
	Latency: () -> number,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
		Open = true,
		Keys = true,
		Latency = UILabs.Slider(0.4, 0, 3, 0.1),
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const open = source(true)
	const busy = source(false)
	effect(function()
		const value = controls.Open()
		untrack(function()
			open(value)
			return nil
		end)
	end)

	local pending: thread? = nil
	cleanup(function()
		const thread = pending
		if thread and coroutine.status(thread) == "suspended" then
			task.cancel(thread)
		end
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

		PlayChoice({
			Visible = open,
			Busy = busy,
			Keys = function()
				return if controls.Keys() then { Solo = "1", Squad = "2" } else {}
			end,
			OnChoose = function(choice: PlayChoice.Choice)
				print(`[PlayChoice story] {choice}`)
				busy(true)
				pending = task.delay(controls.Latency(), function()
					pending = nil
					busy(false)
					open(false)
				end)
			end,
			OnClose = function()
				print("[PlayChoice story] close")
				open(false)
			end,
			Scale = controls.Scale,
		}),
	})
end)
