--!strict
-- Juice: the feedback of the cooking focus (owner 2026-10-19: "melhorar os efeitos e feedback visual do modo cozinha"). Plain module,
-- local instances only (under the focus folder, gone with it).
--   Popup(at, band, text)  the grade of a gesture floats up from where it was made: "Perfect!" Mustard, "Nice!" Green, "Good"
--                          Teal, "Oops" Slate; thick Ink stroke, pops big, rises and fades (a BillboardGui on a local anchor)
--   Celebrate(at, band)    particles for the band: Perfect = a Mustard sparkle burst + confetti, Nice = a Green sparkle, Good =
--                          a few sparks, Messy = nothing
--   Burst / Sound          thin wrappers over the kitchen's particle budget (KitchenController/Fx) and AudioController
-- Reduced motion: the popup does not pop or rise, it shows and fades.
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)

export type Juice = {
	Popup: (self: Juice, at: Vector3, band: string, text: string) -> (),
	Celebrate: (self: Juice, at: Vector3, band: string) -> (),
	Burst: (self: Juice, at: Vector3, preset: Fx.Preset, count: number, color: Color3?) -> (),
	Sound: (self: Juice, key: string, at: Vector3?) -> (),
}

export type Audio = { Play: (self: any, key: string, at: any?) -> any }

const RISE = 1.4 -- studs the popup rises
const LIFE = 0.95 -- s on screen
const COLORS: { [string]: Color3 } = {
	Perfect = Theme.Color.Mustard,
	Nice = Theme.Color.Green,
	Good = Theme.Color.Teal,
	Messy = Theme.Color.Slate,
}
const SIZES: { [string]: number } = { Perfect = 46, Nice = 40, Good = 34, Messy = 30 }

const JuiceModule = {}

function JuiceModule.new(folder: Instance, audio: Audio): Juice
	const self = {} :: any

	function self.Popup(_: any, at: Vector3, band: string, text: string)
		const anchor = Instance.new("Part")
		anchor.Name = "GradePopup"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.Position = at + Vector3.new(0, 0.4, 0)
		anchor.Parent = folder
		const gui = Instance.new("BillboardGui")
		gui.Name = "Grade"
		gui.Adornee = anchor
		gui.Size = UDim2.fromOffset(260, 80)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Parent = anchor
		const label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.FontFace = Theme.Font.Title
		label.Text = text
		label.TextColor3 = COLORS[band] or Theme.Color.Text
		label.TextSize = SIZES[band] or 34
		label.TextStrokeColor3 = Theme.Color.Ink
		label.TextStrokeTransparency = 0
		label.Rotation = if band == "Perfect" then -6 else 0
		label.Parent = gui
		const scale = Instance.new("UIScale")
		scale.Parent = label
		const reduced = Motion.Reduced()
		if not reduced then
			scale.Scale = 0.3
			TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			TweenService:Create(gui, TweenInfo.new(LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffsetWorldSpace = Vector3.new(0, RISE, 0),
			}):Play()
		end
		TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, LIFE - 0.3), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(LIFE + 0.05, function()
			anchor:Destroy()
		end)
	end

	function self.Celebrate(_: any, at: Vector3, band: string)
		if band == "Perfect" then
			Fx.Burst(at, "Ready", 14, Theme.Color.Mustard)
			Fx.Burst(at + Vector3.new(0, 0.3, 0), "Confetti", 12, nil)
		elseif band == "Nice" then
			Fx.Burst(at, "Ready", 10, Theme.Color.Green)
		elseif band == "Good" then
			Fx.Burst(at, "Ready", 5, Theme.Color.Teal)
		end
	end

	function self.Burst(_: any, at: Vector3, preset: Fx.Preset, count: number, color: Color3?)
		Fx.Burst(at, preset, count, color)
	end

	function self.Sound(_: any, key: string, at: Vector3?)
		audio:Play(key, at)
	end

	return self :: Juice
end

return JuiceModule
