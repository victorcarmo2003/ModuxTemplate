--!strict
-- HorrorCaption on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport, over a dark kitchen
-- colour. "Loop" shows the caption for its Content.Score duration (2.6 s) every 5 s, like the blackout does.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local HorrorCaption = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

type Controls = {
	PhoneFrame: () -> boolean,
	Loop: () -> boolean,
	Shown: () -> boolean,
	Title: () -> string,
	Line: () -> string,
	Scale: () -> number,
}

const SHOW_TIME = 2.6
const PERIOD = 5

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		PhoneFrame = true,
		Loop = true,
		Shown = true,
		Title = "POWER OUT",
		Line = "HIDE IN THE BACK",
		Scale = UILabs.Slider(1, 0.8, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const now = source(os.clock())
	const started = os.clock()
	const loop = task.spawn(function()
		while true do
			task.wait(0.1)
			now(os.clock())
		end
	end)
	cleanup(function()
		if coroutine.status(loop) == "suspended" then
			task.cancel(loop)
		end
	end)

	const caption = HorrorCaption({
		Shown = function()
			return if controls.Loop() then (now() - started) % PERIOD < SHOW_TIME else controls.Shown()
		end,
		Title = controls.Title,
		Line = controls.Line,
		Scale = controls.Scale,
	})

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		create("Frame")({
			Name = "Screen",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				return if controls.PhoneFrame() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
			end,
			BackgroundColor3 = Color3.fromHex("#14121A"),
			ClipsDescendants = true,
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),

			caption,
		}),
	})
end)
