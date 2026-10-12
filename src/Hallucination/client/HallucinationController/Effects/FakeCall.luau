--!strict
-- fake_call (< 60; script.md §8, ui-text.md §12.4, sound-list.md §5.12): the vehicle's wall phone rings (the real
-- SFX-080 on purpose, lamp blinking like a real call) and then the strip shows only "Walt: ..." -- no "Answer", no
-- prompt, not a call (FEAT-018). Only while no real call is up; a real call arriving cancels it at once.
local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")
local Context = require(script.Parent.Parent.Context)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

const PHONE_IDS: { [string]: boolean } = { ["TRL-PHONE"] = true }
const PHONE_ACTION = "answer_phone"
const LIGHT_NAME = "Light_Ring"
const LAMP_SUFFIX = "_Lamp"
const RING_KEY = "phone_ring"
const GLITCH_KEY = "phone_glitch" -- the "line" of the fake call: glitched phone noise (user request 2026-10-10)
const SPEAKER = "Walt"
const TEXT = "..." -- ui-text.md §12.4 "Walt: ..."
const RING_TIME = 3.5 -- s: about two rings
const PAUSE = 0.4
const LINE_TIME = 2.5 -- BossCallRules.LineTime
const BLINK_HZ = 2
const STEP = 0.1
const HEAR_RANGE = 45 -- studs from the phone: farther away the ring would not be noticed

local function findPhone(vehicle: Instance): Instance?
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("Model") then
			const id = descendant:GetAttribute("MapId")
			if type(id) == "string" and PHONE_IDS[id] then
				return descendant
			end
		end
	end
	for _, anchor in CollectionService:GetTagged("Interactable") do
		if anchor:GetAttribute("PromptAction") == PHONE_ACTION and vehicle:IsAncestorOf(anchor) then
			local current = anchor.Parent
			while current and current ~= vehicle do
				if current:IsA("Model") then
					return current
				end
				current = current.Parent
			end
		end
	end
	return nil
end

local function lampsOf(phone: Instance): { BasePart }
	const out: { BasePart } = {}
	for _, descendant in phone:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == LIGHT_NAME then
			table.insert(out, descendant)
			return out
		end
	end
	for _, descendant in phone:GetDescendants() do
		if descendant:IsA("BasePart") and string.sub(descendant.Name, -#LAMP_SUFFIX) == LAMP_SUFFIX then
			table.insert(out, descendant)
		end
	end
	return out
end

local function phoneOf(env: Context.Env): Instance?
	const vehicle = env.Vehicle()
	return if vehicle then findPhone(vehicle) else nil
end

const FakeCall: Context.Effect = {
	CanRun = function(env: Context.Env): boolean
		if not env.CallIdle() then
			return false
		end
		const phone = phoneOf(env)
		const root = Context.Root()
		if phone == nil or root == nil then
			return false
		end
		const at = Context.PositionOf(phone)
		return at ~= nil and (at - root.Position).Magnitude <= HEAR_RANGE
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const phone = phoneOf(env)
		if phone == nil then
			return
		end
		const lamps = lampsOf(phone)
		const host: Instance = lamps[1] or phone

		-- lamp: local writes, restored as found
		const saved: { [BasePart]: { Color: Color3, Material: Enum.Material } } = {}
		for _, lamp in lamps do
			saved[lamp] = { Color = lamp.Color, Material = lamp.Material }
		end
		local function setLamp(on: boolean)
			for lamp, look in saved do
				lamp.Color = if on then Theme.Color.Mustard else look.Color
				lamp.Material = if on then Enum.Material.Neon else look.Material
			end
		end
		run:Cleanup(function()
			setLamp(false)
			env.Loop(RING_KEY, host, false)
			env.Subtitle(SPEAKER, "")
		end)

		env.Loop(RING_KEY, host, true)
		const started = os.clock()
		while os.clock() - started < RING_TIME do
			if not env.CallIdle() then
				return -- a real call: the controller's Finish restores everything
			end
			setLamp(math.floor((os.clock() - started) * BLINK_HZ * 2) % 2 == 0)
			if not run:Wait(STEP) then
				return
			end
		end
		setLamp(false)
		env.Loop(RING_KEY, host, false)
		if not run:Wait(PAUSE) or not env.CallIdle() then
			return
		end
		env.Subtitle(SPEAKER, TEXT)
		env.Sound(GLITCH_KEY, host)
		const shown = os.clock()
		while os.clock() - shown < LINE_TIME do
			if not env.CallIdle() or not run:Wait(STEP) then
				return
			end
		end
	end,
}

return FakeCall
