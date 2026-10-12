--!strict
-- World/Highlight: the contour on a target (docs/tech/prep-3d.md §2.4, §2.6, §8; TASK-196). Two modes: Hover (the pointer is on
-- it: steady contour + Mustard fill) and Pulse (the target invites by itself: the same, breathing; touch has no hover). A pool of
-- Rules.World.Budget.Highlights Highlight instances made once; none is created or destroyed while the mode runs. At a low
-- graphics level (Budget.LowQuality) no Highlight exists at all: a flat Neon ring on the floor of the target stands in for it
-- (pool of Budget.Rings). Never red; Mustard fill, Cream contour (Ink under the fill so it reads on Cream). No Modux, no Vide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Types = require(script.Parent.Types)

export type Mode = "Hover" | "Pulse"

export type Outline = {
	-- True when the ring fallback is in use (low quality).
	Fallback: boolean,
	-- The target under the pointer (nil clears it). One at a time.
	SetHover: (self: Outline, target: Types.Target?) -> (),
	-- Pulses every enabled target flagged `Pulse`, up to the budget (call when the registry version changes).
	Sync: (self: Outline, targets: { Types.Target }, enabled: (Types.Target) -> boolean) -> (),
	-- Advances the breathing; `time` in seconds. Only writes numbers.
	Step: (self: Outline, time: number) -> (),
	Destroy: (self: Outline) -> (),
}

type Slot = {
	Light: Highlight?, -- the Highlight instance (nil in the ring fallback)
	Ring: Part?, -- the ring (fallback)
	Base: Vector3, -- ring size at rest
	Target: Types.Target?,
	Mode: Mode,
}

const FILL_HOVER = 0.55 -- FillTransparency while hovering
const FILL_FROM, FILL_TO = 0.62, 0.86 -- the pulse breathes between them
const PULSE_HZ = 1.4
const RING_THICKNESS = 0.03

const Highlight = {}

-- Graphics quality 1..3 (SavedQualityLevel) is low; Automatic (0) counts as high (same rule as Fx.luau and the prep camera).
local function lowQuality(level: number): boolean
	const ok, saved = pcall(function(): any
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok then
		return false
	end
	const value = (saved :: Enum.SavedQualitySetting).Value
	return value ~= 0 and value <= level
end

function Highlight.new(folder: Folder, rules: Content.PrepWorldRules, reduced: (() -> boolean)?): Outline
	const fallback = lowQuality(rules.Budget.LowQuality)
	const count = if fallback then rules.Budget.Rings else rules.Budget.Highlights
	const slots: { Slot } = {}
	const free: { Slot } = {}
	const byId: { [string]: Slot } = {}
	local hover: Slot? = nil

	for _ = 1, count do
		const slot: Slot = { Light = nil, Ring = nil, Base = Vector3.zero, Target = nil, Mode = "Pulse" }
		if fallback then
			const ring = Instance.new("Part")
			ring.Name = "HighlightRing"
			ring.Shape = Enum.PartType.Cylinder
			ring.Material = Enum.Material.Neon
			ring.Color = Theme.Color.Mustard
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CanTouch = false
			ring.CastShadow = false
			ring.Transparency = 1
			ring.Size = Vector3.new(RING_THICKNESS, 1, 1)
			ring.Parent = folder
			slot.Ring = ring
		else
			const light = Instance.new("Highlight")
			light.Name = "TargetHighlight"
			light.FillColor = Theme.Color.Mustard
			light.OutlineColor = Theme.Color.Cream
			light.FillTransparency = FILL_TO
			light.OutlineTransparency = 0
			light.DepthMode = Enum.HighlightDepthMode.Occluded
			light.Enabled = false
			light.Parent = folder
			slot.Light = light
		end
		table.insert(slots, slot)
		table.insert(free, slot)
	end

	-- The thing the contour is drawn around: the real object, else the hitbox itself.
	local function adorneeOf(target: Types.Target): Instance?
		return target.Model or target.Parts[1]
	end

	local function attach(slot: Slot, target: Types.Target, mode: Mode)
		slot.Target = target
		slot.Mode = mode
		const adornee = adorneeOf(target)
		if slot.Light ~= nil then
			slot.Light.Adornee = adornee
			slot.Light.FillTransparency = if mode == "Hover" then FILL_HOVER else FILL_TO
			slot.Light.Enabled = adornee ~= nil
		elseif slot.Ring ~= nil and adornee ~= nil then
			-- the floor ring under the object: its footprint, the lowest point of its box
			local cframe = CFrame.identity
			local size = Vector3.zero
			if adornee:IsA("Model") then
				cframe, size = adornee:GetBoundingBox()
			elseif adornee:IsA("BasePart") then
				cframe, size = adornee.CFrame, adornee.Size
			end
			const diameter = math.max(size.X, size.Z) * 1.25
			slot.Base = Vector3.new(RING_THICKNESS, diameter, diameter)
			slot.Ring.Size = slot.Base
			slot.Ring.CFrame = CFrame.new(cframe.Position - Vector3.new(0, size.Y / 2 - 0.02, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			slot.Ring.Transparency = if mode == "Hover" then 0.2 else 0.5
		end
	end

	local function release(slot: Slot)
		if slot.Target ~= nil then
			byId[slot.Target.Target.Id] = nil
		end
		slot.Target = nil
		if slot.Light ~= nil then
			slot.Light.Enabled = false
			slot.Light.Adornee = nil
		end
		if slot.Ring ~= nil then
			slot.Ring.Transparency = 1
		end
		table.insert(free, slot)
	end

	local function take(): Slot?
		return table.remove(free)
	end

	const self = { Fallback = fallback } :: any

	function self.SetHover(_: any, target: Types.Target?)
		if hover ~= nil then
			const previous = hover.Target
			if previous ~= nil and target ~= nil and previous.Target.Id == target.Target.Id then
				return
			end
			-- a pulsing target keeps breathing after the pointer leaves it
			if previous ~= nil and previous.Pulse then
				attach(hover, previous, "Pulse")
			else
				release(hover)
			end
			hover = nil
		end
		if target == nil then
			return
		end
		const slot = byId[target.Target.Id]
		if slot ~= nil then
			-- already pulsing: promote it to the steady hover look
			slot.Mode = "Hover"
			hover = slot
			attach(slot, target, "Hover")
			return
		end
		const fresh = take()
		if fresh == nil then
			return
		end
		byId[target.Target.Id] = fresh
		hover = fresh
		attach(fresh, target, "Hover")
	end

	function self.Sync(_: any, targets: { Types.Target }, enabled: (Types.Target) -> boolean)
		-- drop the pulses that are no longer wanted
		for _, slot in slots do
			const current = slot.Target
			if current ~= nil and slot ~= hover and (not enabled(current) or not current.Pulse) then
				release(slot)
			end
		end
		-- the hover keeps one slot; the rest of the budget is for pulses
		for _, target in targets do
			if not target.Pulse or not enabled(target) or byId[target.Target.Id] ~= nil then
				continue
			end
			const slot = take()
			if slot == nil then
				break
			end
			byId[target.Target.Id] = slot
			attach(slot, target, "Pulse")
		end
	end

	function self.Step(_: any, time: number)
		const still = reduced ~= nil and reduced()
		const breath = if still then 0 else (math.sin(time * math.pi * 2 * PULSE_HZ) + 1) / 2
		for _, slot in slots do
			if slot.Target == nil or slot.Mode ~= "Pulse" then
				continue
			end
			if slot.Light ~= nil then
				slot.Light.FillTransparency = FILL_TO + (FILL_FROM - FILL_TO) * breath
			elseif slot.Ring ~= nil then
				const grow = 1 + 0.08 * breath
				slot.Ring.Size = Vector3.new(slot.Base.X, slot.Base.Y * grow, slot.Base.Z * grow)
			end
		end
	end

	function self.Destroy(_: any)
		for _, slot in slots do
			if slot.Light ~= nil then
				slot.Light:Destroy()
			end
			if slot.Ring ~= nil then
				slot.Ring:Destroy()
			end
		end
		table.clear(slots)
		table.clear(free)
		table.clear(byId)
		hover = nil
	end

	return self :: Outline
end

return Highlight
