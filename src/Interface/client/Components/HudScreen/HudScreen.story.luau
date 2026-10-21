--!strict
-- HudScreen: the full HUD on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport.
-- "Toast" pushes a notice (bottom centre, stacking up); "Summary" shows the end-of-shift card; move "Cash" up to see the
-- bump; "ShowClock" / "ShowShift" / "ShowCash" / "ShowToasts" play the progressive reveal (Content.HudReveal). Drag
-- "Scale" and toggle "Phone" to check the toast margins (844 x 390 emulator = Phone off, Scale 1).
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
	ShowCash: () -> boolean,
	ShowClock: () -> boolean,
	ShowShift: () -> boolean,
	ShowToasts: () -> boolean,
	Fainted: () -> boolean,
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
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
		Clock = "8:00 AM",
		Day = UILabs.Slider(3, 1, 100, 1),
		Night = false,
		Cash = UILabs.Slider(123, 0, 5000, 1),
		Toast = false,
		Summary = false,
		ShowCash = true, -- progressive reveal: toggle to see the pill scale in / shrink away
		ShowClock = true,
		ShowShift = true,
		ShowToasts = true,
		Fainted = false, -- clean faint screen (TASK-485): clock, day, money and the cart go away
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
		Calm = controls.Fainted,
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
				Sales = 72,
				Tips = 12,
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
		Reveal = function(key: string): boolean
			if key == "money" then
				return controls.ShowCash()
			elseif key == "clock" then
				return controls.ShowClock()
			elseif key == "shift" then
				return controls.ShowShift()
			elseif key == "toasts" then
				return controls.ShowToasts()
			end
			return true
		end,
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
