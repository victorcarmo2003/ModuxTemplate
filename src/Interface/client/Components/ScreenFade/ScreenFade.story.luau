--!strict
-- ScreenFade preview: "Alpha" sets the cover directly; toggle "Play" (either way) to run the vehicle swap curve
-- (in 0.2 s, hold 0.5 s, out 0.8 s = 1.5 s, VehicleController constants).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local ScreenFade = require(script.Parent)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack

const FADE_IN = 0.2
const HOLD = 0.5
const FADE_OUT = 0.8

type Controls = {
	Alpha: () -> number,
	Play: () -> boolean,
}

local function curve(elapsed: number): number
	if elapsed < FADE_IN then
		return elapsed / FADE_IN
	elseif elapsed < FADE_IN + HOLD then
		return 1
	end
	return math.max(1 - (elapsed - FADE_IN - HOLD) / FADE_OUT, 0)
end

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Alpha = UILabs.Slider(0.5, 0, 1, 0.05),
		Play = false,
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const alpha = source(untrack(controls.Alpha))

	effect(function()
		alpha(controls.Alpha())
	end)

	local connection: RBXScriptConnection? = nil
	local primed = false
	effect(function()
		controls.Play()
		if not primed then
			primed = true
			return
		end
		if connection then
			connection:Disconnect()
		end
		const started = os.clock()
		connection = RunService.Heartbeat:Connect(function()
			const elapsed = os.clock() - started
			alpha(curve(elapsed))
			if elapsed >= FADE_IN + HOLD + FADE_OUT and connection then
				connection:Disconnect()
				connection = nil
			end
		end)
	end)
	cleanup(function()
		if connection then
			connection:Disconnect()
		end
	end)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Cream,

		create("TextLabel")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(420, 40),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextSize = 24,
			TextColor3 = Theme.Color.Ink,
			Text = "Under the fade",
		}),

		ScreenFade({ Alpha = alpha }),
	})
end)
