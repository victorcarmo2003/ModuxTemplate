--!strict
-- CodeRedeem on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport. A fake server answers after
-- "Latency" seconds: HOTDOG = +50 Gems (then "already used"), OLDCODE = expired, anything else = invalid.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CodeRedeem = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Latency: () -> number,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
		Latency = UILabs.Slider(0.6, 0, 3, 0.1),
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const feedback = source({ Text = "", Kind = "None" } :: CodeRedeem.Feedback)
	const used: { [string]: boolean } = {}

	local thread: thread? = nil
	cleanup(function()
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

		CodeRedeem({
			Visible = function()
				return true
			end,
			Feedback = feedback,
			OnRedeem = function(code: string)
				feedback({ Text = "", Kind = "Wait" })
				thread = task.delay(controls.Latency(), function()
					thread = nil
					const upper = string.upper(code)
					if upper == "HOTDOG" and not used[upper] then
						used[upper] = true
						feedback({ Text = "+50 Gems!", Kind = "Good" })
					elseif upper == "HOTDOG" then
						feedback({ Text = "You already used this code", Kind = "Bad" })
					elseif upper == "OLDCODE" then
						feedback({ Text = "This code has expired", Kind = "Bad" })
					else
						feedback({ Text = "Invalid code", Kind = "Bad" })
					end
				end)
			end,
			OnClose = function()
				print("[CodeRedeem story] close")
			end,
			Scale = controls.Scale,
		}),
	})
end)
