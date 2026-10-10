--!strict
-- HudWipe: "Run" counts 10 -> 0 in real seconds (as the HUD does from Shift.WipeEndsAt); turn it off to see the fade.
-- "Seconds" picks a fixed value while "Run" is off; -1 hides the card. Phone = 667 x 375.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local HudWipe = require(script.Parent)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup

type Controls = {
	Phone: () -> boolean,
	Run: () -> boolean,
	Seconds: () -> number,
}

const TOTAL = 10

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Run = false,
		Seconds = UILabs.Slider(7, -1, TOTAL, 1),
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const running = source(-1)
	effect(function()
		if not controls.Run() then
			running(-1)
			return
		end
		const endsAt = os.clock() + TOTAL
		const connection = RunService.Heartbeat:Connect(function()
			const left = math.max(math.ceil(endsAt - os.clock()), 0)
			if left ~= running() then
				running(left)
			end
		end)
		cleanup(function()
			connection:Disconnect()
		end)
	end)

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = 0.2,
		ClipsDescendants = true,

		HudWipe({
			Seconds = function()
				return if controls.Run() then running() else controls.Seconds()
			end,
			Total = TOTAL,
		}),
	})
end)
