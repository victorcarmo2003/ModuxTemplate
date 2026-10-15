--!strict
-- Haptics: the one module that vibrates (TASK-268; owner request 2026-10-14, Provisional). PlayStation and Xbox controllers
-- and phones where HapticService supports it all play the same profiles (Content.Haptics). Plain module (no Modux, no Vide
-- root): the prep mode, the anomaly effects and HapticsController call it directly.
--   Play(key)       a short pulse of a profile; a continuous Hold under it comes back when the pulse ends
--   Hold(key, on)   a continuous profile (Duration 0) while `on`; capped by Content.Haptics.MaxHold
--   Stop()          motors off now (leaving a mode, a context change)
-- Only the own player: a vibration is never sent over the network. Settings `Vibration` off (Prefs) = nothing, ever. The device
-- is the one of the last input (a gamepad of any slot, or Touch); keyboard and mouse never vibrate.
-- Support (checked at run time, every call): HapticService:IsVibrationSupported per UserInputType, then IsMotorSupported per
-- motor; a device with one motor gets the stronger of the two strengths. Every HapticService call is pcall'ed (a phone without
-- a vibration motor, or a platform that refuses, is silent, never an error).
local HapticService = game:GetService("HapticService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Prefs = require(StarterPlayer.StarterPlayerScripts.client.Settings.Prefs)

const Haptics = {}

local token = 0
local holding: Content.HapticKey? = nil
local holdToken = 0
local active: Enum.UserInputType? = nil

local function target(): Enum.UserInputType?
	const last = UserInputService:GetLastInputType()
	if string.sub(last.Name, 1, 7) == "Gamepad" then
		return last
	elseif last == Enum.UserInputType.Touch then
		return Enum.UserInputType.Touch
	end
	return nil
end

local function allowed(): boolean
	return Vide.untrack(Prefs.Vibration)
end

local function motors(kind: Enum.UserInputType, large: number, small: number)
	pcall(function()
		if not HapticService:IsVibrationSupported(kind) then
			return
		end
		const hasLarge = HapticService:IsMotorSupported(kind, Enum.VibrationMotor.Large)
		const hasSmall = HapticService:IsMotorSupported(kind, Enum.VibrationMotor.Small)
		if hasLarge and hasSmall then
			HapticService:SetMotor(kind, Enum.VibrationMotor.Large, large)
			HapticService:SetMotor(kind, Enum.VibrationMotor.Small, small)
		elseif hasLarge then
			HapticService:SetMotor(kind, Enum.VibrationMotor.Large, math.max(large, small))
		elseif hasSmall then
			HapticService:SetMotor(kind, Enum.VibrationMotor.Small, math.max(large, small))
		end
	end)
end

local function off()
	const kind = active
	active = nil
	if kind ~= nil then
		motors(kind, 0, 0)
	end
end

local function apply(profile: Content.HapticProfile): boolean
	const kind = target()
	if kind == nil then
		off()
		return false
	end
	if active ~= nil and active ~= kind then
		off()
	end
	active = kind
	motors(kind, profile.Large, profile.Small)
	return true
end

-- What should run when a pulse ends: the continuous profile still held, or nothing.
local function settle()
	const key = holding
	if key ~= nil and allowed() then
		apply(Content.Haptics.Profiles[key])
	else
		off()
	end
end

function Haptics.Play(key: Content.HapticKey)
	if not allowed() then
		return
	end
	const profile = Content.Haptics.Profiles[key]
	if profile == nil or not apply(profile) then
		return
	end
	token += 1
	const mine = token
	task.delay(math.max(profile.Duration, 0.03), function()
		if token == mine then
			settle()
		end
	end)
end

function Haptics.Hold(key: Content.HapticKey, on: boolean)
	if not on then
		if holding == key then
			holding = nil
			token += 1
			off()
		end
		return
	end
	if holding == key then
		return
	end
	holding = key
	holdToken += 1
	const mine = holdToken
	if allowed() then
		apply(Content.Haptics.Profiles[key])
	end
	-- leak guard: a hold nobody released stops by itself
	task.delay(Content.Haptics.MaxHold, function()
		if holdToken == mine and holding == key then
			holding = nil
			off()
		end
	end)
end

function Haptics.Stop()
	holding = nil
	token += 1
	holdToken += 1
	off()
end

return table.freeze(Haptics)
