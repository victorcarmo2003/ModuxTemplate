--!strict
-- Dread: the punishment of the lights left off (owner 2026-10-19: "se ele passar muito tempo com as luzes apagadas, acontece alguma
-- coisa ... deixando o ambiente bem aterrorizante e diminuir a sanidade dele um pouco mais rápido"). VitalService sets the Player
-- attribute Content.Sanity.DreadAttribute after DreadAfter s in the dark at night (and drains DreadPerSecond); this client turns
-- the place terrifying while it is on, as a crescendo (horror style: silence, breath, blur, grading):
--   Grading   own ColorCorrection: darker, crushed, washed out, a cold violet tint, rising over RISE s
--   Blur      a soft blur that throbs with the heartbeat
--   Sound     a sting at the start, the heartbeat and a whisper bed looping, and now and then a creak, a knock
--             or a whisper (every SCARE_MIN..SCARE_MAX s once the dread is full)
-- The lights back on (or the attribute gone) fade it all out in FALL s. Local only; nothing here feeds a rule.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Content = require(ReplicatedStorage.shared.Content)

type Audio = {
	Play: (self: Audio, key: string, at: any?, opts: any?) -> Sound?,
	Loop: (self: Audio, key: string, at: any?, on: boolean, opts: any?) -> Sound?,
}

const RISE = 6 -- s to the full dread
const FALL = 1.5 -- s back to nothing once the lights are on
const BEAT = 1.6 -- heartbeats per second at the full dread
const SCARE_MIN = 6
const SCARE_MAX = 12
const SCARES = { "floor_creak", "door_knock", "whisper" } -- no breath_held: owner 2026-10-21, random sighs
const TINT = Color3.fromRGB(196, 178, 226)

return function(audio: Audio)
	const player = Players.LocalPlayer
	const attribute = Content.Sanity.DreadAttribute
	const grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DarkDread"
	grade.Enabled = false
	grade.Parent = Lighting
	const blur = Instance.new("BlurEffect")
	blur.Name = "DarkDreadBlur"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting

	local level = 0
	local looping = false
	local clock = 0
	local nextScare = 0

	local function loops(on: boolean)
		if looping == on then
			return
		end
		looping = on
		audio:Loop("heartbeat", nil, on, { Volume = 1.2 })
		audio:Loop("whispers_bed", nil, on, { Volume = 0.8 })
	end

	player:GetAttributeChangedSignal(attribute):Connect(function()
		if player:GetAttribute(attribute) == true and level < 0.05 then
			audio:Play("horror_sting", nil, { Scare = true })
			nextScare = clock + SCARE_MIN
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		const on = player:GetAttribute(attribute) == true
		level = if on then math.min(level + dt / RISE, 1) else math.max(level - dt / FALL, 0)
		const active = level > 0.001
		grade.Enabled = active
		blur.Enabled = active
		loops(on)
		if not active then
			return
		end
		const eased = level * level * (3 - 2 * level)
		grade.Brightness = -0.14 * eased
		grade.Contrast = 0.3 * eased
		grade.Saturation = -0.75 * eased
		grade.TintColor = Color3.new(1, 1, 1):Lerp(TINT, eased)
		-- the throb: a short swell on every beat
		const beat = math.max(0, math.sin(clock * BEAT * math.pi * 2)) ^ 8
		blur.Size = eased * (2 + 5 * beat)
		if on and level >= 1 and clock >= nextScare then
			nextScare = clock + SCARE_MIN + math.random() * (SCARE_MAX - SCARE_MIN)
			audio:Play(SCARES[math.random(1, #SCARES)], nil, { Scare = true })
		end
	end)
end
