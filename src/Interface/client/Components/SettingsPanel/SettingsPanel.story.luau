--!strict
-- SettingsPanel on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport, with the HUD gear that
-- opens it. Every change is kept in a local source and printed (no server). "Hint" shows the desktop key line.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local SettingsRules = require(ReplicatedStorage.shared.Settings.SettingsRules)
local Theme = require(script.Parent.Parent.Theme)
local GearButton = require(script.Parent.Parent.GearButton)
local SettingsPanel = require(script.Parent)

const create = Vide.create
const source = Vide.source
const untrack = Vide.untrack

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Hint: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
		Hint = true,
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const values = source(table.clone(SettingsRules.Defaults))
	const open = source(true)

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

		GearButton({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 6),
			Size = 38,
			Open = open,
			OnActivated = function()
				open(not untrack(open))
			end,
		}),

		SettingsPanel({
			Visible = open,
			Values = values,
			Scale = controls.Scale,
			Hint = function()
				return if controls.Hint() then "Press M to open or close" else ""
			end,
			OnChange = function(key: SettingsRules.Key, value: any)
				const nextValues = table.clone(untrack(values)) :: any
				nextValues[key] = value
				values(SettingsRules.Sanitize(nextValues))
				print(`[SettingsPanel story] {key} = {value}`)
			end,
			OnClose = function()
				open(false)
			end,
		}),
	})
end)
