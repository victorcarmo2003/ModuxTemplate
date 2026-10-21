--!strict
--[[
	Walt on the radio during an anomaly (was inside Kit/Hide until TASK-339; TASK-334 uses it for the Hush). A strip
	low on the screen ("WALT (radio): <line>") for `seconds`, the radio squelch, and Walt's voice through
	BossController:Speak when this build can (best effort: the strip always shows). Not a phone call (no ring, no
	answer). House palette: Ink strip, Mustard stroke, Cream text.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Parent.Effect)

const RADIO_KEY = "phone_glitch"
const INK = Color3.fromHex("#2B2233")
const CREAM = Color3.fromHex("#FFF1D6")
const MUSTARD = Color3.fromHex("#F6C12B")

const Radio = {}

local function voice(text: string)
	const client = script:FindFirstAncestor("client")
	const feature = if client then client:FindFirstChild("Boss") else nil
	const module = if feature then feature:FindFirstChild("BossController") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return
	end
	pcall(function()
		const boss: any = (require :: any)(module)
		const speak: any = if type(boss) == "table" then boss.Speak else nil
		if type(speak) == "function" then
			(speak :: any)(boss, text)
		end
	end)
end

local function strip(text: string, seconds: number)
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	const gui = Instance.new("ScreenGui")
	gui.Name = "WaltRadio"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	const frame = Instance.new("Frame")
	frame.Name = "Strip"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -110)
	frame.Size = UDim2.new(0.5, 0, 0, 46)
	frame.BackgroundColor3 = INK
	frame.BackgroundTransparency = 0.12
	frame.Parent = gui
	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = frame
	const stroke = Instance.new("UIStroke")
	stroke.Color = MUSTARD
	stroke.Thickness = 3
	stroke.Parent = frame
	const size = Instance.new("UISizeConstraint")
	size.MinSize = Vector2.new(280, 0)
	size.MaxSize = Vector2.new(640, 46)
	size.Parent = frame
	const label = Instance.new("TextLabel")
	label.Name = "Line"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.94, 0.8)
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.Text = `<font color="#F6C12B">WALT (radio):</font> {text}`
	label.RichText = true
	label.TextScaled = true
	label.TextColor3 = CREAM
	label.Parent = frame
	gui.Parent = playerGui
	task.delay(seconds, function()
		const fade = TweenInfo.new(0.3)
		TweenService:Create(frame, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		task.wait(0.35)
		gui:Destroy()
	end)
end

-- owner 2026-10-21: the squelch (`phone_glitch`, a 6.5 s file) is cut in the middle, and a new one stops the last
local lastSquelch: Sound? = nil
const SQUELCH_CUT = 3.25 -- s
const SQUELCH_FADE = 0.25

local function cut(sound: Sound)
	if sound.Parent == nil or not sound.IsPlaying then
		return
	end
	TweenService:Create(sound, TweenInfo.new(SQUELCH_FADE), { Volume = 0 }):Play()
	task.delay(SQUELCH_FADE, function()
		sound:Stop()
	end)
end

-- Squelch, voice and strip for `seconds`.
function Radio.Say(ctx: Effect.Context, text: string, seconds: number)
	if Content.Sounds.ByKey[RADIO_KEY] ~= nil then
		const previous = lastSquelch
		if previous ~= nil then
			cut(previous)
		end
		const sound = ctx.Play(RADIO_KEY)
		lastSquelch = sound
		if sound ~= nil then
			task.delay(SQUELCH_CUT, function()
				if lastSquelch == sound then
					lastSquelch = nil
				end
				cut(sound)
			end)
		end
	end
	voice(text)
	strip(text, seconds)
end

return table.freeze(Radio)
