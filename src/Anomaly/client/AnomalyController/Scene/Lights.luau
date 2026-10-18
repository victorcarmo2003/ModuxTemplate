--!strict
--[[
	Lights steps of a horror scene (TASK-462). The same means the blackout already uses, nothing new on the map:
	  * LightController fixtures (lamps and their lights): darkened locally and MARKED (Lit/Live = true) so its
	    Paint leaves them; unmarked (nil) to give them back, and it repaints them from the Lights set on its next tick
	    (the trick of Kit/Hide and the ANM-020 omen);
	  * the rest of the map: Kit/Blackout.Darken (roots of Content.LightPresets.Blackout) and Blackout.Look.
	Off holds the dark (re-marks what LightController repainted) until On / Cascade. Flicker = the ANM-020 omen pattern
	stretched over Duration on the fixtures near the camera (skipped while the dark is held). Cascade = the dark
	given back nearest first over Duration (Blackout handle Sweep). One state for the whole client: the last step wins.
]]
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Effect = require(script.Parent.Parent.Effect)
local Blackout = require(script.Parent.Parent.Effects.Kit.Blackout)

type Lamp = { Part: BasePart, Color: Color3, Material: Enum.Material }
type Fixture = { Position: Vector3, Lights: { Light }, Lamps: { Lamp }, Lit: boolean?, Live: boolean? }

const FLICKER: { number } = { 0.09, 0.14, 0.07, 0.45, 0.16, 0.1 } -- off / on ... s; Effects/ANM-020 OMEN_FLICKER
const FLICKER_TOTAL = 1.01
const FLICKER_RADIUS = 80 -- studs from the camera
const HOLD_TICK = 0.1 -- s between two re-marks while Off is held
const LAMP_OFF_MATERIAL = Enum.Material.SmoothPlastic
const LAMP_OFF_COLOR = Color3.fromHex("#3A3540")

const Lights = {}

local ctx: Effect.Context? = nil
local held = false
local map: Blackout.Handle? = nil
local hold: RBXScriptConnection? = nil
local token = 0 -- a newer step cancels a flicker / cascade in progress

local function fixtures(): { Fixture }
	const out: { Fixture } = {}
	const c = ctx
	if c == nil then
		return out
	end
	for _, list in c.Light.Fixtures do
		for _, fixture in list do
			table.insert(out, fixture :: any)
		end
	end
	return out
end

local function eye(): Vector3
	const camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.CFrame.Position else Vector3.zero
end

local function dark(fixture: Fixture)
	for _, lamp in fixture.Lamps do
		lamp.Part.Material = LAMP_OFF_MATERIAL
		lamp.Part.Color = LAMP_OFF_COLOR
	end
	for _, light in fixture.Lights do
		light.Enabled = false
	end
	fixture.Lit = true
	fixture.Live = true
end

local function give(fixture: Fixture)
	for _, lamp in fixture.Lamps do
		lamp.Part.Material = lamp.Material
		lamp.Part.Color = lamp.Color
	end
	for _, light in fixture.Lights do
		light.Enabled = light:GetAttribute("PadHidden") ~= true
	end
	fixture.Lit = nil
	fixture.Live = nil
end

-- what LightController drives: Kit/Blackout never touches it
local function owned(): { [Instance]: boolean }
	const out: { [Instance]: boolean } = {}
	for _, fixture in fixtures() do
		for _, light in fixture.Lights do
			out[light] = true
		end
		for _, lamp in fixture.Lamps do
			out[lamp.Part] = true
		end
	end
	return out
end

local function stopHold()
	const connection = hold
	if connection ~= nil then
		connection:Disconnect()
		hold = nil
	end
end

function Lights.Bind(context: Effect.Context)
	ctx = context
end

function Lights.IsOff(): boolean
	return held
end

function Lights.Off()
	token += 1
	if held then
		return
	end
	held = true
	for _, fixture in fixtures() do
		dark(fixture)
	end
	map = Blackout.Darken(owned())
	Blackout.Look(true)
	local last = os.clock()
	hold = RunService.Heartbeat:Connect(function()
		if os.clock() - last < HOLD_TICK then
			return
		end
		last = os.clock()
		for _, fixture in fixtures() do
			if fixture.Lit ~= true or fixture.Live ~= true then
				dark(fixture) -- LightController repainted it (a preset or the Lights set changed)
			end
		end
	end)
end

function Lights.On()
	token += 1
	if not held then
		return
	end
	held = false
	stopHold()
	for _, fixture in fixtures() do
		give(fixture)
	end
	const handle = map
	map = nil
	if handle ~= nil then
		handle.Restore()
	end
	Blackout.Look(false)
end

function Lights.Cascade(duration: number)
	if duration <= 0 then
		Lights.On()
		return
	end
	token += 1
	if not held then
		return
	end
	held = false
	stopHold()
	const mine = token
	const origin = eye()
	const list = fixtures()
	local far = 0
	for _, fixture in list do
		far = math.max(far, (fixture.Position - origin).Magnitude)
	end
	for _, fixture in list do
		const delay = if far > 0 then duration * (fixture.Position - origin).Magnitude / far else 0
		task.delay(delay, function()
			if token == mine or not held then
				give(fixture)
			end
		end)
	end
	const handle = map
	map = nil
	if handle ~= nil then
		handle.Sweep(duration, origin)
	end
	Blackout.Look(false)
end

function Lights.Flicker(duration: number)
	if held or duration <= 0 then
		return
	end
	token += 1
	const mine = token
	const origin = eye()
	const near: { Fixture } = {}
	for _, fixture in fixtures() do
		if (fixture.Position - origin).Magnitude <= FLICKER_RADIUS then
			table.insert(near, fixture)
		end
	end
	const scale = duration / FLICKER_TOTAL
	task.spawn(function()
		local off = true
		for _, wait in FLICKER do
			if token ~= mine then
				break -- a newer Lights step: Off keeps them dark, anything else gets them back below
			end
			for _, fixture in near do
				if off then
					dark(fixture)
				else
					give(fixture)
					fixture.Lit = true -- still ours until the pattern ends
					fixture.Live = true
				end
			end
			off = not off
			task.wait(wait * scale)
		end
		if not held then
			for _, fixture in near do
				give(fixture)
			end
		end
	end)
end

return table.freeze(Lights)
