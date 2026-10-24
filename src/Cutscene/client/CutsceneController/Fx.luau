--!strict
--[[
	Fx: the screen and audio effects of a cutscene (Content.Cutscenes[].Fx; "The Second Coffee", owner request 2026-10-22,
	PROVISIONAL). Like Timeline and Director every value is a pure function of (scene, elapsed), so a client that joins late
	shows the same frame; there is no state to replay.

	  Blur    a BlurEffect "CutsceneBlur" of our own in Lighting
	  Grade   a ColorCorrectionEffect "CutsceneGrade" of our own (stacked on the preset of LightController, which skips it)
	  Flash   a full-screen frame in a ScreenGui under the letterbox (white flash, or a black blink of a failing light)
	  Quake   a camera offset and tilt the controller adds to the shot rig (Shake())
	  Duck    the Music group multiplier (AudioController:SetMusicDuck)

	Photosensitivity: a Flash is capped by the content (Validate: alpha <= 0.9) and shows at 30% with reduced motion; a Quake
	at 25%. With no effect of a kind running the effect is neutral (blur 0, grade none); a Duck is the exception: it holds
	until the chain ends (the credits bring the music back with a Duck of their own), and Destroy gives the music back.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)

type Scene = Content.Cutscene
type Effect = Content.CutsceneFx

export type Context = {
	-- Music group multiplier (AudioController:SetMusicDuck)
	Duck: (multiplier: number, time: number?) -> (),
}

export type Fx = {
	Step: (scene: Scene, elapsed: number) -> (),
	-- camera offset (studs, camera space) and tilt (radians) of the Quake effects of this frame
	Shake: () -> (Vector3, Vector3),
	Destroy: () -> (),
}

const BLUR_NAME = "CutsceneBlur"
const GRADE_NAME = "CutsceneGrade"
const GUI_NAME = "CutsceneFx"
const GUI_ORDER = 49 -- under the letterbox (50), the fade (51) and the subtitles (52)
const ATTACK = 0.03 -- s a flash takes to reach its alpha
const QUAKE_STUDS = 0.35 -- shake offset at amplitude 1
const QUAKE_TILT = 0.03 -- radians of pitch / yaw at amplitude 1 (roll 1.6x)
const REDUCED_FLASH = 0.3
const REDUCED_QUAKE = 0.25
const DEFAULT_RATE = 14 -- Hz
const GIVE_BACK = 1.5 -- s the music takes to come back when the chain ends
const WHITE = Color3.new(1, 1, 1)

const Fx = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- 0..1 progress of an effect at `elapsed` (an instant effect, Duration 0, is already done)
local function progress(fx: Effect, elapsed: number): number
	return if fx.Duration > 0 then math.clamp((elapsed - fx.At) / fx.Duration, 0, 1) else 1
end

-- Last effect of `kind` that already started
local function lastOf(list: { Effect }, kind: string, elapsed: number): Effect?
	local found: Effect? = nil
	for _, fx in list do
		if fx.At > elapsed then
			break
		end
		if fx.Kind == kind then
			found = fx
		end
	end
	return found
end

-- Existing effect of the class under Lighting with our name, or a new one
local function effectOf(className: string, name: string): any
	const existing = Lighting:FindFirstChild(name)
	if existing ~= nil and existing.ClassName == className then
		return existing
	end
	const created = Instance.new(className :: any)
	created.Name = name
	created.Parent = Lighting
	return created
end

function Fx.new(ctx: Context): Fx
	local blur: BlurEffect? = nil
	local grade: ColorCorrectionEffect? = nil
	local gui: ScreenGui? = nil
	local flash: Frame? = nil
	local shakeOffset = Vector3.zero
	local shakeTilt = Vector3.zero
	local duck: number? = nil

	local function ensureBlur(): BlurEffect
		local current = blur
		if current == nil or current.Parent == nil then
			current = effectOf("BlurEffect", BLUR_NAME) :: BlurEffect
			current.Size = 0
			blur = current
		end
		return current :: BlurEffect
	end

	local function ensureGrade(): ColorCorrectionEffect
		local current = grade
		if current == nil or current.Parent == nil then
			current = effectOf("ColorCorrectionEffect", GRADE_NAME) :: ColorCorrectionEffect
			grade = current
		end
		return current :: ColorCorrectionEffect
	end

	local function ensureFlash(): Frame?
		const current = flash
		if current ~= nil and current.Parent ~= nil then
			return current
		end
		const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui == nil then
			return nil
		end
		const screen = Instance.new("ScreenGui")
		screen.Name = GUI_NAME
		screen.ResetOnSpawn = false
		screen.IgnoreGuiInset = true
		screen.DisplayOrder = GUI_ORDER
		screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		const frame = Instance.new("Frame")
		frame.Name = "Flash"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BorderSizePixel = 0
		frame.Active = false
		frame.BackgroundTransparency = 1
		frame.Visible = false
		frame.Parent = screen
		screen.Parent = playerGui
		gui = screen
		flash = frame
		return frame
	end

	return {
		Step = function(scene: Scene, elapsed: number)
			const list = scene.Fx or {}
			const reduced = Motion.Reduced()

			-- Blur: the last one started, then holds its end
			const blurFx = lastOf(list, "Blur", elapsed)
			if blurFx ~= nil or blur ~= nil then
				const size = if blurFx ~= nil then lerp(blurFx.Value, blurFx.To or blurFx.Value, progress(blurFx, elapsed)) else 0
				if size > 0.05 or (blur ~= nil and blur.Size > 0) then
					const effect = ensureBlur()
					effect.Size = size
					effect.Enabled = size > 0.05
				end
			end

			-- Grade: saturation of the last one started; the tint runs from the end colour of the one before
			local saturation = 0
			local tint = WHITE
			local before = WHITE
			local graded = false
			for _, fx in list do
				if fx.Kind ~= "Grade" then
					continue
				end
				if fx.At > elapsed then
					break
				end
				graded = true
				const p = progress(fx, elapsed)
				const target = fx.Color or WHITE
				saturation = lerp(fx.Value, fx.To or fx.Value, p)
				tint = before:Lerp(target, p)
				before = target
			end
			if graded or grade ~= nil then
				const effect = ensureGrade()
				effect.Saturation = saturation
				effect.TintColor = tint
				effect.Enabled = graded
			end

			-- Flash: the strongest running one, a short attack and a squared decay
			local alpha = 0
			local color = WHITE
			for _, fx in list do
				if fx.Kind ~= "Flash" then
					continue
				end
				if fx.At > elapsed then
					break
				end
				const dt = elapsed - fx.At
				if dt >= fx.Duration then
					continue
				end
				const p = dt / math.max(fx.Duration, 1e-3)
				const value = fx.Value * (1 - p) * (1 - p) * math.min(dt / ATTACK, 1) * (if reduced then REDUCED_FLASH else 1)
				if value > alpha then
					alpha = value
					color = fx.Color or WHITE
				end
			end
			if alpha > 0.002 or flash ~= nil then
				const frame = ensureFlash()
				if frame ~= nil then
					frame.BackgroundColor3 = color
					frame.BackgroundTransparency = 1 - math.clamp(alpha, 0, 0.9)
					frame.Visible = alpha > 0.002
				end
			end

			-- Quake: amplitudes add up, noise at the fx Rate
			local offset = Vector3.zero
			local tilt = Vector3.zero
			for _, fx in list do
				if fx.Kind ~= "Quake" then
					continue
				end
				if fx.At > elapsed then
					break
				end
				const dt = elapsed - fx.At
				if dt >= fx.Duration then
					continue
				end
				const p = dt / math.max(fx.Duration, 1e-3)
				const amp = fx.Value * (1 - p) * (1 - p) * (if reduced then REDUCED_QUAKE else 1)
				const t = elapsed * (fx.Rate or DEFAULT_RATE)
				offset += Vector3.new(math.noise(t, 3.1, 0), math.noise(t, 17.7, 0), math.noise(t, 41.3, 0) * 0.4) * (amp * QUAKE_STUDS * 2)
				tilt += Vector3.new(math.noise(t, 5.9, 0), math.noise(t, 23.3, 0), math.noise(t, 61.1, 0) * 1.6) * (amp * QUAKE_TILT * 2)
			end
			shakeOffset = offset
			shakeTilt = tilt

			-- Duck: the last one started; none yet = untouched (holds across segments)
			const duckFx = lastOf(list, "Duck", elapsed)
			if duckFx ~= nil then
				const value = lerp(duckFx.Value, duckFx.To or duckFx.Value, progress(duckFx, elapsed))
				if duck == nil or math.abs(value - duck) > 0.004 then
					duck = value
					ctx.Duck(value, 0)
				end
			end
		end,
		Shake = function(): (Vector3, Vector3)
			return shakeOffset, shakeTilt
		end,
		Destroy = function()
			if blur ~= nil then
				blur:Destroy()
				blur = nil
			end
			if grade ~= nil then
				grade:Destroy()
				grade = nil
			end
			if gui ~= nil then
				gui:Destroy()
				gui = nil
				flash = nil
			end
			shakeOffset = Vector3.zero
			shakeTilt = Vector3.zero
			if duck ~= nil then
				duck = nil
				ctx.Duck(1, GIVE_BACK)
			end
		end,
	}
end

return table.freeze(Fx)
