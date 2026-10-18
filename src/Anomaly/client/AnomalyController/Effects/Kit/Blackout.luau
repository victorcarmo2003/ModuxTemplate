--!strict
--[[
	Blackout: the total dark of ANM-020 in the restaurant (owner request 2026-10-17; Content.LightPresets.Blackout, every
	number PROVISIONAL). Lives in Effects/Kit/ (a Folder), so AnomalyController:LoadEffects never takes it for an effect.
	Presentation only, client side only: nothing here decides or sends anything.

	```lua
	local Blackout = require(script.Parent.Kit.Blackout)
	local handle = Blackout.Darken(skip)  -- every light under LightPresets.Blackout.Roots off locally (skip = owned by others)
	handle.Restore()                      -- gives back what is still as we left it
	handle.Sweep(1.5, origin)             -- same, nearest first, spread over 1.5 s (horror scene Cascade, TASK-462)
	Blackout.Look(true)                   -- Lighting blends to the blackout look over FadeIn s
	Blackout.Look(false)                  -- and back to the night values over FadeOut s
	```

	Darken, over every root of Blackout.Roots (Workspace paths: the restaurant folder outside the vehicle, the table
	torches of MAP01_Assets.Extra), except any subtree whose instance is named in KeepNames or has a MapId in KeepMapIds
	(the emergency lamp EMERG-P) and the instances in `skip`:
	  * Light (Point / Spot / Surface) Enabled off;
	  * Neon BasePart (visible) -> SmoothPlastic, dark lamp colour;
	  * flames (an instance named FlameName and everything under it): BaseParts hidden (LocalTransparencyModifier 1),
	    Fire / ParticleEmitter / Smoke / Sparkles / Beam / Trail Enabled off;
	  * SurfaceGui: Brightness -> SignBrightness, LightInfluence -> SignLightInfluence (the signs still read, dim).

	Look: the six Lighting fields of the look (Ambient, OutdoorAmbient, EnvironmentDiffuseScale,
	EnvironmentSpecularScale, Brightness, ExposureCompensation) are rewritten every frame in a render step after the
	AtmosphereController's, as a blend from the night value to the look. The night value is whatever another writer
	(LightController preset, AtmosphereController) left in Lighting since our last write, so a preset change in the dark
	is followed, and when the fade-out ends the last write is exactly the night value again (nothing to restore).
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)

const LOOK = Content.LightPresets.Blackout
const RENDER_STEP = "ANM020_BlackoutLook"
const RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 3 -- after AtmosphereController (Camera + 2)
const LAMP_OFF_MATERIAL = Enum.Material.SmoothPlastic
const LAMP_OFF_COLOR = Color3.fromHex("#3A3540")

export type Handle = { Restore: () -> (), Sweep: (duration: number, origin: Vector3) -> () }

type Saved = {
	Instance: Instance,
	Kind: string, -- "Light" | "Neon" | "Flame" | "Emitter" | "Gui"
	Material: Enum.Material?,
	Color: Color3?,
	Number: number?, -- Flame: LocalTransparencyModifier; Gui: Brightness
	Influence: number?, -- Gui: LightInfluence
}

const Blackout = {}

-- Darken ------------------------------------------------------------------------------------------------------------

const KEEP_NAMES: { [string]: boolean } = {}
for _, name in LOOK.KeepNames do
	KEEP_NAMES[name] = true
end
const KEEP_IDS: { [string]: boolean } = {}
for _, id in LOOK.KeepMapIds do
	KEEP_IDS[id] = true
end

local function kept(instance: Instance): boolean
	if KEEP_NAMES[instance.Name] then
		return true
	end
	const id = instance:GetAttribute("MapId")
	return type(id) == "string" and KEEP_IDS[id] == true
end

local function resolve(path: { string }): Instance?
	local node: Instance? = Workspace
	for _, name in path do
		if node == nil then
			return nil
		end
		node = (node :: Instance):FindFirstChild(name)
	end
	return node
end

local function isEmitter(instance: Instance): boolean
	return instance:IsA("Fire")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Smoke")
		or instance:IsA("Sparkles")
		or instance:IsA("Beam")
		or instance:IsA("Trail")
end

local function off(instance: Instance, flame: boolean, out: { Saved })
	if instance:IsA("Light") then
		if instance.Enabled then
			table.insert(out, { Instance = instance, Kind = "Light" })
			instance.Enabled = false
		end
	elseif flame and instance:IsA("BasePart") then
		if instance.LocalTransparencyModifier < 1 then
			table.insert(out, { Instance = instance, Kind = "Flame", Number = instance.LocalTransparencyModifier })
			instance.LocalTransparencyModifier = 1
		end
	elseif instance:IsA("BasePart") then
		if instance.Material == Enum.Material.Neon and instance.Transparency < 1 then
			table.insert(out, { Instance = instance, Kind = "Neon", Material = instance.Material, Color = instance.Color })
			instance.Material = LAMP_OFF_MATERIAL
			instance.Color = LAMP_OFF_COLOR
		end
	elseif isEmitter(instance) then
		const emitter = instance :: any
		if emitter.Enabled then
			table.insert(out, { Instance = instance, Kind = "Emitter" })
			emitter.Enabled = false
		end
	elseif instance:IsA("SurfaceGui") then
		table.insert(out, { Instance = instance, Kind = "Gui", Number = instance.Brightness, Influence = instance.LightInfluence })
		instance.Brightness = LOOK.SignBrightness
		instance.LightInfluence = LOOK.SignLightInfluence
	end
end

local function walk(node: Instance, flame: boolean, skip: { [Instance]: boolean }, out: { Saved })
	for _, child in node:GetChildren() do
		if kept(child) then
			continue
		end
		const isFlame = flame or child.Name == LOOK.FlameName
		if not skip[child] then
			off(child, isFlame, out)
		end
		walk(child, isFlame, skip, out)
	end
end

local function restoreOne(saved: Saved)
	const instance = saved.Instance
	if instance.Parent == nil then
		return
	end
	-- only what is still in the state we left it in (another system may have changed it meanwhile)
	if saved.Kind == "Light" then
		const light = instance :: Light
		if not light.Enabled then
			light.Enabled = true
		end
	elseif saved.Kind == "Neon" then
		const part = instance :: BasePart
		if part.Material == LAMP_OFF_MATERIAL then
			part.Material = saved.Material :: Enum.Material
			part.Color = saved.Color :: Color3
		end
	elseif saved.Kind == "Flame" then
		const part = instance :: BasePart
		if part.LocalTransparencyModifier == 1 then
			part.LocalTransparencyModifier = saved.Number :: number
		end
	elseif saved.Kind == "Emitter" then
		const emitter = instance :: any
		if not emitter.Enabled then
			emitter.Enabled = true
		end
	elseif saved.Kind == "Gui" then
		const gui = instance :: SurfaceGui
		gui.Brightness = saved.Number :: number
		gui.LightInfluence = saved.Influence :: number
	end
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	end
	const part = instance:FindFirstAncestorWhichIsA("BasePart")
	return if part ~= nil then part.Position else nil
end

-- Restores the entries nearest to origin first, the farthest one `duration` s later (a staggered power-up)
local function sweep(entries: { Saved }, duration: number, origin: Vector3)
	if duration <= 0 then
		for _, entry in entries do
			restoreOne(entry)
		end
		return
	end
	const distance: { [Saved]: number } = {}
	local far = 0
	for _, entry in entries do
		const position = positionOf(entry.Instance)
		const d = if position ~= nil then (position - origin).Magnitude else 0
		distance[entry] = d
		far = math.max(far, d)
	end
	for _, entry in entries do
		const delay = if far > 0 then duration * distance[entry] / far else 0
		if delay <= 0 then
			restoreOne(entry)
		else
			task.delay(delay, restoreOne, entry)
		end
	end
end

-- Everything that glows under the roots goes off locally. skip = instances another system drives (LightController
-- fixtures, what the effect already saved): never touched
function Blackout.Darken(skip: { [Instance]: boolean }): Handle
	const saved: { Saved } = {}
	for _, path in LOOK.Roots do
		const root = resolve(path)
		if root ~= nil and not kept(root) then
			walk(root, root.Name == LOOK.FlameName, skip, saved)
		end
	end
	local done = false
	return {
		Restore = function()
			if done then
				return
			end
			done = true
			for _, entry in saved do
				restoreOne(entry)
			end
			table.clear(saved)
		end,
		Sweep = function(duration: number, origin: Vector3)
			if done then
				return
			end
			done = true
			const entries = table.clone(saved)
			table.clear(saved)
			sweep(entries, duration, origin)
		end,
	}
end

-- Look --------------------------------------------------------------------------------------------------------------

type Field = { Prop: string, Target: any, Base: any, Last: any }

local function field(prop: string, target: any): Field
	return { Prop = prop, Target = target, Base = nil, Last = nil }
end

const FIELDS: { Field } = {
	field("Ambient", LOOK.Ambient),
	field("OutdoorAmbient", LOOK.OutdoorAmbient),
	field("EnvironmentDiffuseScale", LOOK.EnvDiffuse),
	field("EnvironmentSpecularScale", LOOK.EnvSpecular),
	field("Brightness", LOOK.Brightness),
	field("ExposureCompensation", LOOK.Exposure),
}

local alpha = 0
local goal = 0
local bound = false

local function lerp(from: any, to: any, t: number): any
	if typeof(from) == "Color3" then
		return (from :: Color3):Lerp(to :: Color3, t)
	end
	return (from :: number) + ((to :: number) - (from :: number)) * t
end

local function unbind()
	if bound then
		bound = false
		RunService:UnbindFromRenderStep(RENDER_STEP)
	end
	for _, entry in FIELDS do
		entry.Base = nil
		entry.Last = nil
	end
end

local function step(dt: number)
	const span = if goal > alpha then LOOK.FadeIn else LOOK.FadeOut
	const move = if span > 0 then dt / span else 1
	alpha = if goal > alpha then math.min(goal, alpha + move) else math.max(goal, alpha - move)
	const eased = alpha * alpha * (3 - 2 * alpha) -- smoothstep
	const lighting = Lighting :: any
	for _, entry in FIELDS do
		const current = lighting[entry.Prop]
		if entry.Last == nil or current ~= entry.Last then
			entry.Base = current -- another writer set the night value since our last frame
		end
		lighting[entry.Prop] = if eased <= 0 then entry.Base else lerp(entry.Base, entry.Target, eased)
		entry.Last = lighting[entry.Prop] -- read back (float32 storage)
	end
	if alpha <= 0 and goal <= 0 then
		unbind() -- the last write was the night value itself
	end
end

-- true = blend to the blackout look, false = back to the night values (then the render step goes away)
function Blackout.Look(on: boolean)
	goal = if on then 1 else 0
	if on and not bound then
		bound = true
		RunService:BindToRenderStep(RENDER_STEP, RENDER_PRIORITY, step)
	end
end

return table.freeze(Blackout)
