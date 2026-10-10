--!strict
-- Toast + ToastStack. "Push toast" adds one with the current controls; "Auto" pushes every 1.5 s to
-- check the queue (at most MaxVisible on screen, the rest wait their turn).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent)
local Stack = require(script.Parent.Stack)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const KINDS: { Toast.Kind } = { "Info", "Good", "Alert" }

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Text = "+$12 tip from a happy customer",
		Kind = UILabs.Choose({ "Info", "Good", "Alert" }),
		Duration = UILabs.Slider(4, 3, 6, 0.5),
		Auto = false,
	},
}, function(props)
	const controls = props.controls
	const entries = source({} :: { Stack.Entry })
	local count = 0

	local function push()
		count += 1
		const text = controls.Text() :: string
		const kind = controls.Kind() :: Toast.Kind
		const list = table.clone(entries())
		table.insert(list, {
			Text = if controls.Auto() then `{text} ({count})` else text,
			Kind = if controls.Auto() then KINDS[(count - 1) % #KINDS + 1] else kind,
			Duration = controls.Duration() :: number,
		})
		entries(list)
	end

	const loop = task.spawn(function()
		while true do
			task.wait(1.5)
			if controls.Auto() then
				push()
			end
		end
	end)
	cleanup(function()
		if coroutine.status(loop) == "suspended" then
			task.cancel(loop)
		end
	end)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		Stack({
			Entries = entries,
			OnDone = function(entry: Stack.Entry)
				const list = table.clone(entries())
				const index = table.find(list, entry)
				if index then
					table.remove(list, index)
					entries(list)
				end
			end,
		}),

		create("TextButton")({
			Name = "Push",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 16, 1, -16),
			Size = UDim2.fromOffset(160, Theme.MinTouch),
			BackgroundColor3 = Theme.Color.Mustard,
			FontFace = Theme.Font.Title,
			TextSize = 18,
			TextColor3 = Theme.Color.Ink,
			Text = "Push toast",
			Activated = push,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = Theme.Stroke,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
	})
end)
