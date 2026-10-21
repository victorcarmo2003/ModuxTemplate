--!strict
-- Flat preview of the bar plus the real BillboardGui on a temporary part 8 studs in front of the
-- Studio camera (removed when the story closes). "Auto" simulates a 4 s grill cycle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local Bar = require(script.Parent.Bar)
local ProgressBar = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup

const CYCLE = 4

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Progress = UILabs.Slider(0.4, 0, 1, 0.01),
		Auto = false,
		ShowText = false,
		InWorld = true,
	},
}, function(props)
	const controls = props.controls

	const elapsed = source(0)
	const connection = RunService.Heartbeat:Connect(function(dt: number)
		if controls.Auto() then
			-- 1.25 cycles: the extra quarter shows the "ready" color before restarting.
			elapsed((elapsed() + dt) % (CYCLE * 1.25))
		end
	end)
	cleanup(connection)

	local function progress(): number
		return if controls.Auto() then elapsed() / CYCLE else controls.Progress()
	end

	local function fillColor(): Color3
		return if progress() >= 1 then Theme.Color.Ready else Theme.Color.Cooking
	end

	local function text(): string
		return if controls.ShowText() then `{math.floor(math.min(progress(), 1) * 100)}%` else ""
	end

	-- In-world preview.
	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__ProgressBarStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(1, 0.3, 0.3)
	anchor.Color = Color3.fromHex("#C2602F")
	anchor.CFrame = camera.CFrame * CFrame.new(0, -1, -8)
	anchor.Parent = workspace
	cleanup(anchor)

	const billboard = ProgressBar({
		Adornee = anchor,
		Progress = progress,
		FillColor = fillColor,
		Text = text,
		Visible = function()
			return controls.InWorld()
		end,
	})
	billboard.Parent = anchor

	return create("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(240, 36),
		BackgroundTransparency = 1,

		Bar({
			Progress = progress,
			FillColor = fillColor,
			Text = text,
		}),
	})
end)
