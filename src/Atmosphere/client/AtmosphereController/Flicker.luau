--!strict
-- Kitchen tube flicker (owner 2026-10-18: "a parte interna da cozinha tá muito suave, precisamos de algo mais
-- aterrorizante"). At night only (Workspace attribute Atmosphere set by AtmosphereService), every GAP_MIN..GAP_MAX s one
-- fixture of the kitchen's switch group flickers for a moment with a buzz, the way Effects/Kit/Hide flickers the trailer:
-- the fixture is marked Lit/Live so LightController leaves it, toggled, then unmarked so LightController repaints it.
-- Skipped while the blackout owns the lights. Local only, presentation only.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

type Lamp = { Part: BasePart, Material: Enum.Material, Color: Color3 }
type Fixture = { Position: Vector3, Lights: { Light }, Lamps: { Lamp }, Lit: boolean?, Live: boolean? }
type LightKit = { Fixtures: { [string]: { Fixture } } }
type Audio = { Play: (self: any, key: string, at: Vector3?, options: any?) -> any }

const GROUP = "trailer_interior"
const GAP_MIN = 22
const GAP_MAX = 50
const OFF_COLOR = Color3.fromHex("#C9D3CF")
const PATTERNS = {
	{ 0.06, 0.05, 0.09, 0.4, 0.05, 0.12 },
	{ 0.15, 0.08, 0.05, 0.06, 0.6 },
	{ 0.04, 0.04, 0.04, 0.3, 0.08, 0.05, 0.08 },
}
const BUZZ = "post_buzz"
const BLACKOUT_EFFECT = "ANM020_Blackout" -- Effects/ANM-020's own ColorCorrectionEffect while the power is out

local function paint(fixture: Fixture, on: boolean)
	for _, lamp in fixture.Lamps do
		if on then
			lamp.Part.Material = lamp.Material
			lamp.Part.Color = lamp.Color
		else
			lamp.Part.Material = Enum.Material.SmoothPlastic
			lamp.Part.Color = OFF_COLOR
		end
	end
	for _, item in fixture.Lights do
		item.Enabled = on
	end
end

local function once(light: LightKit, audio: Audio, rng: Random)
	const list = light.Fixtures[GROUP]
	if list == nil or #list == 0 then
		return
	end
	const fixture = list[rng:NextInteger(1, #list)]
	if fixture.Lit == false then
		return -- already off (switch off, Hush)
	end
	fixture.Lit = true
	fixture.Live = true
	pcall(function()
		audio:Play(BUZZ, fixture.Position, { Volume = 0.5 })
	end)
	local on = false
	for _, wait in PATTERNS[rng:NextInteger(1, #PATTERNS)] do
		paint(fixture, on)
		on = not on
		task.wait(wait)
	end
	paint(fixture, true)
	fixture.Lit = nil
	fixture.Live = nil
end

return function(light: LightKit, audio: Audio)
	const rng = Random.new()
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(GAP_MIN, GAP_MAX))
			if Workspace:GetAttribute("Atmosphere") ~= nil and Lighting:FindFirstChild(BLACKOUT_EFFECT) == nil then
				once(light, audio, rng)
			end
		end
	end)
end
