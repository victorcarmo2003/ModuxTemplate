--!strict
-- ModuxIntro preview: plays the "POWERED BY MODUX" sting on loop. "Play" (either way) restarts it, "Speed" slows it
-- down to study the timing, "Scrub" freezes it at a time when "Paused" is on. "Accent" is the hairline colour.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ModuxIntro = require(script.Parent)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack

const CYCLE = 4.8 -- 3.9 s sting + 0.9 s of black before it loops

type Controls = {
	Play: () -> boolean,
	Loop: () -> boolean,
	Speed: () -> number,
	Paused: () -> boolean,
	Scrub: () -> number,
	Accent: () -> Color3,
	Word: () -> string,
	Caption: () -> string,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Play = false,
		Loop = true,
		Speed = UILabs.Slider(1, 0.1, 2, 0.05),
		Paused = false,
		Scrub = UILabs.Slider(2, 0, CYCLE, 0.05),
		Accent = Color3.fromHex("#FFFFFF"),
		Word = "MODUX",
		Caption = "POWERED BY",
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const time = source(0)

	const connection = RunService.Heartbeat:Connect(function(dt)
		if untrack(controls.Paused) then
			time(untrack(controls.Scrub))
			return
		end
		local elapsed = untrack(time) + dt * untrack(controls.Speed)
		if elapsed > CYCLE then
			elapsed = if untrack(controls.Loop) then 0 else CYCLE
		end
		time(elapsed)
	end)
	cleanup(function()
		connection:Disconnect()
	end)

	local primed = false
	effect(function()
		controls.Play()
		if primed then
			time(0)
		end
		primed = true
	end)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		-- Word/Caption are plain strings in the component: remount it when they change
		function()
			const word = controls.Word()
			const caption = controls.Caption()
			return untrack(function()
				return ModuxIntro({
					Time = time,
					Accent = controls.Accent,
					Word = word,
					Caption = caption,
				})
			end)
		end,
	})
end)
