--!strict
-- NightLostScreen: "Shown" fades the cover in / out; "Run" drains the bar over 6 s (the NightLost phase); with "Run"
-- off, "Progress" picks how much of the wait is done. "LastChance" off shows the end-of-run line. Phone = 667 x 375.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local NightLostScreen = require(script.Parent)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup

type Controls = {
	Phone: () -> boolean,
	Shown: () -> boolean,
	Run: () -> boolean,
	Repeat: () -> boolean,
	Progress: () -> number,
}

const TOTAL = 6

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Shown = true,
		Run = false,
		Repeat = true,
		Progress = UILabs.Slider(0.4, 0, 1, 0.05),
	},
}, function(props)
	const controls: Controls = (props.controls :: any)

	const elapsed = source(-1)
	effect(function()
		if not controls.Run() then
			elapsed(-1)
			return
		end
		const startedAt = os.clock()
		const connection = RunService.Heartbeat:Connect(function()
			elapsed(math.min(os.clock() - startedAt, TOTAL))
		end)
		cleanup(function()
			connection:Disconnect()
		end)
	end)

	const progress = function(): number
		const t = elapsed()
		return if t >= 0 then t / TOTAL else controls.Progress()
	end

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Color3.fromRGB(90, 120, 140),
		ClipsDescendants = true,

		NightLostScreen({
			Shown = controls.Shown,
			Title = function()
				return "Everyone fainted…"
			end,
			Line = function()
				return if controls.Repeat() then "Restarting the night" else "No chances left"
			end,
			Progress = progress,
		}),
	})
end)
