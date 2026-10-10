--!strict
-- HudSanity: drag "Value" through the bands (>= 60 Day, 40-59 Mid, < 40 Night; < 25 breathes). "Max" = 0 hides it
-- (day). "Species" swaps the portrait; "Atlas" off shows the letter fallback. Phone = 667 x 375 (iPhone SE landscape).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local CrewLooks = require(ReplicatedStorage.shared.Crew.CrewLooks)
local Theme = require(script.Parent.Parent.Theme)
local HudSanity = require(script.Parent)

const create = Vide.create

type Controls = {
	Phone: () -> boolean,
	Value: () -> number,
	Max: () -> number,
	Species: () -> string,
	Atlas: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Value = UILabs.Slider(72, 0, 150, 1),
		Max = UILabs.Slider(100, 0, 150, 1),
		Species = UILabs.Choose({ "dog", "rabbit", "cat", "bear", "fox", "owl", "panda", "lion" }),
		Atlas = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const band = function(): HudSanity.Band
		const value = controls.Value()
		if controls.Max() <= 0 or value >= 60 then
			return "Day"
		elseif value >= 40 then
			return "Mid"
		end
		return "Night"
	end

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

		HudSanity({
			Value = function()
				return math.min(controls.Value(), controls.Max())
			end,
			Max = controls.Max,
			Band = band,
			Shown = function()
				return controls.Max() > 0
			end,
			Icon = function()
				return if controls.Atlas() then `Class/class_{controls.Species()}` else ""
			end,
			Letter = function()
				return string.upper(string.sub(controls.Species(), 1, 1))
			end,
			Fur = function()
				const look = CrewLooks.Species[controls.Species()]
				return if look then look.Fur else Theme.Color.Cream
			end,
			Position = UDim2.new(0.5, 0, 0, 62),
		}),
	})
end)
