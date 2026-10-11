--!strict
-- CallSubtitle on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport.
-- "Play" runs the chosen BossCalls row line by line at BossCallRules.LineTime (2.5 s), like the client does from
-- the Call set; with "Play" off, the strip shows the "Text" control.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Parent.Theme)
local CallSubtitle = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

type Controls = {
	PhoneFrame: () -> boolean,
	Visible: () -> boolean,
	Play: () -> boolean,
	Call: () -> string,
	Night: () -> number,
	Text: () -> string,
	Vehicle: () -> string,
	Scale: () -> number,
}

const CALLS = { "call_night_7", "call_day_1", "call_night_4", "call_night_short", "hint_serve", "call_trailer_bought" }

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		PhoneFrame = true,
		Visible = true,
		Play = true,
		Call = UILabs.Choose(CALLS),
		Night = UILabs.Slider(7, 1, 10, 1),
		Text = "Clock stops? Lights off, count five, lights on.",
		Vehicle = UILabs.Choose({ "trailer", "cart" }),
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)
	const now = source(os.clock())
	local startedAt = os.clock()
	local lastCall = ""

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

	local function line(): Content.BossCallLine?
		const key = controls.Call()
		if key ~= lastCall then
			lastCall = key
			startedAt = os.clock()
		end
		const lines = Content.BossCalls.LinesOf(key, controls.Night())
		if #lines == 0 then
			return nil
		end
		-- loops the call so the story keeps running
		const index = math.floor((now() - startedAt) / Content.BossCallRules.LineTime) % #lines + 1
		return lines[index]
	end

	const subtitle = CallSubtitle({
		Visible = controls.Visible,
		Speaker = function()
			const current = if controls.Play() then line() else nil
			return if current and current.Speaker then current.Speaker else "Walt"
		end,
		Text = function()
			if not controls.Play() then
				return controls.Text()
			end
			const current = line()
			return if current then current.Text else ""
		end,
		Phone = controls.Vehicle,
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
			BackgroundColor3 = Color3.fromHex("#1B2440"),
			ClipsDescendants = true,
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),

			subtitle,
		}),
	})
end)
