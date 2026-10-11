--!strict
-- HudBanner: toggle "Shown" to pop the ribbon in/out; "Kind" picks the night start, the repeated night or 6:00 AM.
-- Phone = 667 x 375.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local HudBanner = require(script.Parent)

const create = Vide.create

type Controls = {
	Phone: () -> boolean,
	Shown: () -> boolean,
	Kind: () -> string,
	Night: () -> number,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Shown = true,
		Kind = UILabs.Choose({ "Start", "Repeat", "Dawn" }),
		Night = UILabs.Slider(3, 1, 10, 1),
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = 0.3,
		ClipsDescendants = true,

		HudBanner({
			Banner = function(): HudBanner.Shown
				if not controls.Shown() then
					return false
				end
				const kind = controls.Kind()
				if kind == "Dawn" then
					return { Title = "6:00 AM", Line = "You made it!" }
				end
				return {
					Title = `Night {controls.Night()}`,
					Line = if kind == "Repeat" then "Same night. Same rules." else "Stay open till 6:00 AM.",
				}
			end,
		}),
	})
end)
