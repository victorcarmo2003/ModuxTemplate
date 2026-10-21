--!strict
-- HudSummary: toggle "Shown" to pop the card in/out; the other controls fill the ShiftReport fields.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local HudSummary = require(script.Parent)

const create = Vide.create

type Controls = {
	Shown: () -> boolean,
	Night: () -> boolean,
	Number: () -> number,
	Arrived: () -> number,
	Completed: () -> number,
	Sales: () -> number,
	Tips: () -> number,
	Grade: () -> string,
	Bonus: () -> number,
	Gems: () -> number,
	AfkLocked: () -> boolean,
	LastChanceUsed: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Shown = true,
		Night = false,
		Number = UILabs.Slider(3, 1, 100, 1),
		Arrived = UILabs.Slider(9, 0, 60, 1),
		Completed = UILabs.Slider(7, 0, 60, 1),
		Sales = UILabs.Slider(84, 0, 2000, 1),
		Tips = UILabs.Slider(12, 0, 500, 1),
		Grade = UILabs.Choose({ "A", "B", "C", "D" }),
		Bonus = UILabs.Slider(8, 0, 500, 1),
		Gems = UILabs.Slider(0, 0, 20, 1),
		AfkLocked = false,
		LastChanceUsed = false,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		HudSummary({
			Report = function(): HudSummary.Shown
				if not controls.Shown() then
					return false
				end
				const night = controls.Night()
				return {
					Title = `{if night then "Night" else "Day"} {controls.Number()}`,
					Arrived = controls.Arrived(),
					Completed = controls.Completed(),
					Sales = controls.Sales(),
					Tips = controls.Tips(),
					Grade = controls.Grade() :: HudSummary.Grade,
					Bonus = controls.Bonus(),
					Deposited = controls.Sales() + controls.Tips() + controls.Bonus(),
					Gems = controls.Gems(),
					GemsTotal = 57,
					AfkLocked = controls.AfkLocked(),
					LastChanceUsed = night and controls.LastChanceUsed(),
				}
			end,
		}),
	})
end)
