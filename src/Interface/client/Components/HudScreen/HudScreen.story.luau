--!strict
-- HudScreen: the full HUD on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport.
-- "Toast" pushes a notice; "Summary" shows the end-of-shift card; move "Cash" up to see the bump.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local HudScreen = require(script.Parent)
local HudSummary = require(script.Parent.Parent.HudSummary)
local ToastStack = require(script.Parent.Parent.Toast.Stack)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const untrack = Vide.untrack

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Clock: () -> string,
	Day: () -> number,
	Night: () -> boolean,
	Cash: () -> number,
	Toast: () -> boolean,
	Summary: () -> boolean,
}

const NOTICES: { { Text: string, Kind: "Info" | "Good" | "Alert" } } = {
	{ Text = "Hands full", Kind = "Alert" },
	{ Text = "Grill upgraded!", Kind = "Good" },
	{ Text = "New: Cheese!", Kind = "Good" },
	{ Text = "Not enough cash ($60)", Kind = "Alert" },
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 1, 2, 0.05),
		Clock = "8:00 AM",
		Day = UILabs.Slider(3, 1, 100, 1),
		Night = false,
		Cash = UILabs.Slider(123, 0, 5000, 1),
		Toast = false,
		Summary = false,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const toasts = source({} :: { ToastStack.Entry })
	local count = 0

	-- Toggle "Toast" (either way) to push the next notice.
	local primed = false
	effect(function()
		controls.Toast()
		if not primed then
			primed = true
			return
		end
		count += 1
		const notice = NOTICES[(count - 1) % #NOTICES + 1]
		const list = table.clone(untrack(toasts))
		table.insert(list, { Text = notice.Text, Kind = notice.Kind, Duration = 4 })
		toasts(list)
	end)

	const hud = HudScreen({
		Clock = controls.Clock,
		Shift = function()
			return if controls.Night() then "Night" else `Day {controls.Day()}`
		end,
		IsNight = controls.Night,
		Cash = controls.Cash,
		Toasts = toasts,
		OnToastDone = function(entry)
			const list = table.clone(untrack(toasts))
			const index = table.find(list, entry)
			if index then
				table.remove(list, index)
				toasts(list)
			end
		end,
		Report = function(): HudSummary.Shown
			if not controls.Summary() then
				return false
			end
			return {
				Title = `Day {controls.Day()}`,
				Arrived = 9,
				Completed = 7,
				Drawer = 84,
				Stolen = 0,
				Grade = "B",
				Bonus = 8,
				Deposited = 92,
				Gems = 0,
				GemsTotal = nil,
				AfkLocked = false,
				LastChanceUsed = false,
			}
		end,
		Scale = controls.Scale,
	})

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
		hud,
	})
end)
