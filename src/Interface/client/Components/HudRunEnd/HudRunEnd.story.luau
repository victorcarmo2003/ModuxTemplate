--!strict
-- HudRunEnd: "Shown" fades the dawn in and pops the card; "Result" Failed (lost night, Walt quote) or Success (Night 10).
-- Phone = 667 x 375.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Parent.Theme)
local HudRunEnd = require(script.Parent)

const create = Vide.create

type Controls = {
	Phone: () -> boolean,
	Shown: () -> boolean,
	Result: () -> string,
	Day: () -> number,
	Night: () -> number,
	Gems: () -> number,
}

local function quote(): { string }
	const call = Content.BossCalls.ByKey.call_run_over
	const lines: { string } = {}
	if call then
		for _, line in call.Lines do
			table.insert(lines, line.Text)
		end
	end
	return lines
end

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Shown = true,
		Result = UILabs.Choose({ "Failed", "Success" }),
		Day = UILabs.Slider(14, 1, 200, 1),
		Night = UILabs.Slider(4, 1, 10, 1),
		Gems = UILabs.Slider(23, 0, 500, 1),
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)
	const lines = quote()

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Theme.Color.Teal,
		ClipsDescendants = true,

		HudRunEnd({
			Report = function(): HudRunEnd.Shown
				if not controls.Shown() then
					return false
				end
				const success = controls.Result() == "Success"
				return {
					Result = if success then "Success" else "Failed",
					Day = controls.Day(),
					Night = if success then 10 else controls.Night(),
					Gems = controls.Gems(),
					Quote = lines,
				}
			end,
		}),
	})
end)
