--!strict
-- SecurityFeed preview: "Night" switches the look, "Cam" the camera, "Device" the key chips, "Static" the switch burst,
-- "Scale" the UI scale, "Inset" the height of the Roblox top bar (the viewfinder and its stamps stay below it). The
-- background is a flat street-ish colour (the real grade is the controller's ColorCorrectionEffect).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local SecurityFeed = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup

type Controls = {
	Night: () -> boolean,
	Cam: () -> number,
	Device: () -> string,
	Static: () -> number,
	Scale: () -> number,
	Inset: () -> number,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Night = true,
		Cam = UILabs.Slider(1, 1, 2, 1),
		Device = UILabs.Choose({ "KeyboardMouse", "Gamepad", "Touch" }),
		Static = UILabs.Slider(0, 0, 1, 0.05),
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02),
		Inset = UILabs.Slider(58, 0, 80, 2),
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const time = source(0)
	const connection = RunService.Heartbeat:Connect(function()
		time(os.clock())
	end)
	cleanup(function()
		connection:Disconnect()
	end)
	const cams = {}
	for _, cam in Content.Security.Cams.List do
		table.insert(cams, { Key = cam.Key, Label = cam.Label })
	end
	const view = function(): Content.SecurityView
		return if controls.Night() then "Night" else "Normal"
	end

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(38, 44, 52),

		SecurityFeed({
			Cams = cams,
			Cam = function()
				return Content.Security.Cams.List[math.clamp(controls.Cam(), 1, #cams)].Key
			end,
			View = view,
			Look = function()
				return Content.Security.Looks[view()]
			end,
			Time = time,
			Since = function()
				return 0
			end,
			Static = controls.Static,
			Clock = function()
				return "11:42 PM"
			end,
			Night = function()
				return "NIGHT 3"
			end,
			Device = controls.Device,
			Scale = controls.Scale,
			Inset = controls.Inset,
			OnCam = function(_key) end,
			OnView = function() end,
			OnExit = function() end,
		}),
	})
end)
