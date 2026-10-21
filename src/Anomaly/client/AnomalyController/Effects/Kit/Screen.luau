--!strict
--[[
	Screen: the full-screen layer of the horror scenes (TASK-464; DEC-290, DEC-291; tech/horror-scene.md §4).
	Lives in Effects/Kit/ (a Folder), so AnomalyController:LoadEffects never takes it for an effect module.

	```lua
	local Screen = require(script.Parent.Kit.Screen)
	Screen.SetVignette(0, 0.35, 15, "anm_020_blackout")  -- eases the screen edges 0 -> 0.35 over 15 s (scene step Vignette)
	Screen.ClearVignette("anm_020_blackout")              -- drops that channel at once (scene cancelled)
	Screen.Pulse(0.25)                                    -- grain/jitter flash at a climax (<= 0.3 s; off with Motion.Reduced)
	Screen.Layer()                                        -- the Frame the ramped "HIDE" words live in (Kit/Whispers)
	Screen.Clear()                                        -- every channel off (also on character reset / teleport)
	```
	Vignette channels: each caller (scene key) owns one channel; the screen shows the strongest channel, capped at
	Content.HorrorScenes.Rules.MaxVignette (0.6). Two scenes at once never add up past the cap, and one scene ending
	does not cut the other. A new SetVignette on a channel starts from `from` (the scene timeline is the authority).

	One ScreenGui `HorrorScreen` (DisplayOrder 0, under the HUD at 1): the vignette, the word layer and the pulse never
	cover a HUD button. Colours from the house palette (cold near-black edge, ink and cream grain): never alert red.
	Presentation only: nothing here decides, sends or reads a rule.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Vignette = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Vignette)

type Channel = {
	From: number,
	To: number,
	StartedAt: number,
	Duration: number,
}

const MAX_VIGNETTE = Content.HorrorScenes.Rules.MaxVignette
const DEFAULT_CHANNEL = "default"
const EDGE = Color3.fromHex("#0B0D1E") -- night Decay (style guide §5.3), same as the sanity vignette
const INK = Color3.fromHex("#2B2233")
const CREAM = Color3.fromHex("#FFF1D6")
const PULSE_MAX = 0.3 -- s (TASK-464: a climax flash, never a strobe)
const PULSE_BARS = 14 -- thin horizontal bars of the grain/jitter
const PULSE_DIM = 0.82 -- transparency of the ink flash at its peak (1 = none)

const Screen = {}

const channels: { [string]: Channel } = {}
local strength: Vide.Source<number>? = nil
local gui: ScreenGui? = nil
local layer: Frame? = nil
local pulse: Frame? = nil
local stepper: RBXScriptConnection? = nil

local function eased(channel: Channel, now: number): number
	if channel.Duration <= 0 then
		return channel.To
	end
	const alpha = math.clamp((now - channel.StartedAt) / channel.Duration, 0, 1)
	return channel.From + (channel.To - channel.From) * TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

-- Strongest channel now, capped; true while some channel is still easing.
local function sample(now: number): (number, boolean)
	local top = 0
	local moving = false
	for _, channel in channels do
		top = math.max(top, eased(channel, now))
		if now - channel.StartedAt < channel.Duration then
			moving = true
		end
	end
	return math.clamp(top, 0, MAX_VIGNETTE), moving
end

local function ensure(): ScreenGui?
	const existing = gui
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	const source = Vide.source(0)
	const _unmount, created = Vide.root(function()
		return Vide.create("ScreenGui")({
			Name = "HorrorScreen",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			ClipToDeviceSafeArea = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 0, -- under the HUD (1): the words and the dark never hide a button

			Vignette({ Name = "HorrorVignette", Strength = source, Color = EDGE }),
			Vide.create("Frame")({
				Name = "Words",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Active = false,
				ZIndex = 2,
			}),
			Vide.create("Frame")({
				Name = "Pulse",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = INK,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Active = false,
				Visible = false,
				ZIndex = 3,
			}),
		})
	end)
	created.Parent = playerGui
	strength = source
	gui = created
	layer = created:FindFirstChild("Words") :: Frame
	pulse = created:FindFirstChild("Pulse") :: Frame
	return created
end

local function write()
	const source = strength
	if source == nil then
		return
	end
	const value, moving = sample(os.clock())
	source(value)
	if not moving and stepper ~= nil then
		stepper:Disconnect()
		stepper = nil
	end
end

local function run()
	if stepper == nil then
		stepper = RunService.Heartbeat:Connect(write)
	end
	write()
end

-- Eases the vignette of `channel` (default "default") from `from` to `to` over `duration` s (0 = at once).
-- Values are clamped to 0..Rules.MaxVignette.
function Screen.SetVignette(from: number, to: number, duration: number, channel: string?)
	if ensure() == nil then
		return
	end
	channels[channel or DEFAULT_CHANNEL] = {
		From = math.clamp(from, 0, MAX_VIGNETTE),
		To = math.clamp(to, 0, MAX_VIGNETTE),
		StartedAt = os.clock(),
		Duration = math.max(duration, 0),
	}
	run()
end

-- Drops one channel at once (a scene that was cancelled); the others stay.
function Screen.ClearVignette(channel: string?)
	channels[channel or DEFAULT_CHANNEL] = nil
	run()
end

-- Current shown strength (after the cap); 0 before anything was set.
function Screen.Vignette(): number
	return (sample(os.clock()))
end

-- Grain/jitter flash for a climax: a faint ink dim and thin cream/ink bars that jump, `seconds` (<= 0.3). Nothing
-- with Motion.Reduced(). Does not yield.
function Screen.Pulse(seconds: number?)
	if Motion.Reduced() then
		return
	end
	const root = ensure()
	const frame = pulse
	if root == nil or frame == nil then
		return
	end
	const length = math.clamp(seconds or 0.2, 1 / 30, PULSE_MAX)
	const rng = Random.new()
	frame:ClearAllChildren()
	frame.Visible = true
	frame.BackgroundTransparency = PULSE_DIM
	const bars: { Frame } = {}
	for index = 1, PULSE_BARS do
		const bar = Instance.new("Frame")
		bar.Name = `Bar{index}`
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = if rng:NextNumber() < 0.5 then CREAM else INK
		bar.BackgroundTransparency = 0.75 + rng:NextNumber() * 0.15
		bar.Size = UDim2.new(1, 0, 0, rng:NextInteger(1, 4))
		bar.Parent = frame
		table.insert(bars, bar)
	end
	const startedAt = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		const t = (os.clock() - startedAt) / length
		if t >= 1 or frame.Parent == nil then
			if connection ~= nil then
				connection:Disconnect()
			end
			frame:ClearAllChildren()
			frame.Visible = false
			frame.BackgroundTransparency = 1
			return
		end
		frame.BackgroundTransparency = PULSE_DIM + (1 - PULSE_DIM) * t
		for _, bar in bars do
			bar.Position = UDim2.new(rng:NextNumber() * 0.02 - 0.01, 0, rng:NextNumber(), 0)
		end
	end)
end

-- The Frame (full screen, under the HUD) where the ramped words are spawned; nil without a PlayerGui.
function Screen.Layer(): Frame?
	if ensure() == nil then
		return nil
	end
	return layer
end

-- Every channel off at once, the pulse and the words gone (character reset, teleport, night end).
function Screen.Clear()
	table.clear(channels)
	run()
	const frame = pulse
	if frame ~= nil then
		frame:ClearAllChildren()
		frame.Visible = false
		frame.BackgroundTransparency = 1
	end
	const words = layer
	if words ~= nil then
		words:ClearAllChildren()
	end
end

-- reset / teleport: nothing of a scene survives the character that saw it
Players.LocalPlayer.CharacterAdded:Connect(Screen.Clear)
Players.LocalPlayer.OnTeleport:Connect(function(state: Enum.TeleportState)
	if state == Enum.TeleportState.Started then
		Screen.Clear()
	end
end)

return table.freeze(Screen)
