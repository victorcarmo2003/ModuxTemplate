--!strict
--[[
	BackdropController (TASK-311, user request 2026-10-15, Provisional)

	The backdrop behind every lobby and in-game window: a soft camera blur (its own BlurEffect "UiBackdropBlur" in
	Lighting, so it never fights the atmosphere / sanity effects of AtmosphereController and VitalController) and a
	light Ink veil (ScreenGui "Backdrop", full screen, no insets, DisplayOrder 5: over the HUD, under the windows).
	Shown while Backdrop.Held() (the windows call Backdrop.Hold), except
	in the security cams view (SecurityController.Open) and while a cinematic owns the screen: those have their own looks.
	Fades in / out in FADE_IN / FADE_OUT s; with reduced motion (Motion.Reduced) it jumps.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Backdrop = require(StarterPlayer.StarterPlayerScripts.client.Interface.Backdrop)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

const BLUR_NAME = "UiBackdropBlur"
const BLUR_SIZE = 12 -- soft (Provisional)
const VEIL_TRANSPARENCY = 0.55 -- light Ink veil (Provisional)
const FADE_IN = 0.25 -- s
const FADE_OUT = 0.2 -- s
const DISPLAY_ORDER = 5 -- over the HUD (1), under the lobby windows (6) and the in-game windows (20)

const BackdropController = Modux.Controller("BackdropController", {
	Require = { "SecurityController" },
	Priority = 400,
})

function BackdropController:Setup()
	self.Blur = nil :: BlurEffect?
	self.Gui = nil :: ScreenGui?
	self.Tweens = {} :: { Tween }
end

function BackdropController:BlurEffect(): BlurEffect
	local blur = self.Blur
	if blur == nil or blur.Parent == nil then
		const existing = Lighting:FindFirstChild(BLUR_NAME)
		if existing and existing:IsA("BlurEffect") then
			blur = existing
		else
			const made = Instance.new("BlurEffect")
			made.Name = BLUR_NAME
			made.Size = 0
			made.Enabled = false
			made.Parent = Lighting
			blur = made
		end
		self.Blur = blur
	end
	return blur :: BlurEffect
end

-- Reactive: the backdrop should show now.
function BackdropController:Wanted(): boolean
	const deps = self.Dependencies
	return Backdrop.Held() and not deps.SecurityController.Open() and not Cinematic.Active()
end

function BackdropController:Apply(on: boolean, veil: Frame)
	for _, tween in self.Tweens do
		tween:Cancel()
	end
	table.clear(self.Tweens)
	const blur = self:BlurEffect()
	const gui = self.Gui
	const size = if on then BLUR_SIZE else 0
	const transparency = if on then VEIL_TRANSPARENCY else 1
	if on then
		blur.Enabled = true
		if gui then
			gui.Enabled = true
		end
	end
	if Motion.Reduced() then
		blur.Size = size
		veil.BackgroundTransparency = transparency
		if not on then
			blur.Enabled = false
			if gui then
				gui.Enabled = false
			end
		end
		return
	end
	const info = TweenInfo.new(if on then FADE_IN else FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	const blurTween = TweenService:Create(blur, info, { Size = size })
	const veilTween = TweenService:Create(veil, info, { BackgroundTransparency = transparency })
	if not on then
		blurTween.Completed:Connect(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed then
				blur.Enabled = false
				if gui then
					gui.Enabled = false
				end
			end
		end)
	end
	table.insert(self.Tweens, blurTween)
	table.insert(self.Tweens, veilTween)
	blurTween:Play()
	veilTween:Play()
end

function BackdropController:Mount(playerGui: Instance)
	const veil = Vide.create("Frame")({
		Name = "Veil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
	}) :: Frame
	const gui = Vide.create("ScreenGui")({
		Name = "Backdrop",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ClipToDeviceSafeArea = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = DISPLAY_ORDER,
		Enabled = false,
		veil,
	}) :: ScreenGui
	self.Gui = gui
	gui.Parent = playerGui
	Vide.root(function()
		Vide.effect(function()
			const on = self:Wanted()
			Vide.untrack(function()
				self:Apply(on, veil)
				return nil
			end)
		end)
		return nil
	end)
end

BackdropController:OnInit(function(self)
	self:Setup()
end)

BackdropController:OnStart(function(self)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return BackdropController
