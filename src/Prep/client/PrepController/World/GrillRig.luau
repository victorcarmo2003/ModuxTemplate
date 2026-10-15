--!strict
-- World/GrillRig: the PLACEHOLDER bar grill of the 3D prep (decision of the owner, 2026-10-12: the roller grill leaves, a grill of BARS
-- comes; the sausage lies across the bars and is FLIPPED, not rolled). Parts only, until AST-120 (the final model, another task) exists:
-- the Parts are named like the model so the swap is a model swap (Base, Frame, Bar_n, Tray, Burner, Flame; AST-120 sheet in
-- docs/art/asset-list.md). It draws, from the poses of the slots the world already has (GrillView hands them over):
--   Base    the dark slab under the bars         Frame  the four Cream edges of it
--   Bar_n   Neon bars across the slot line, steel grey when cold, orange and then bright when hot (the heat follows how much cooks)
--   Flame   ONE Neon slab under the bars, turned on by Transparency/Color with the heat       Burner  the housing in front of it
--   Tray    the drip tray on the side the camera looks from
-- and keeps the roller grill of the trailer hidden locally while the mode runs (LocalTransparencyModifier, given back on Destroy;
-- the food on it is not touched). Rules.World.Rig.Placeholder = false draws nothing and leaves the rollers visible: that is the
-- switch for the day the map has the real grill. The sausage keeps the same pose and the same flip pivot (Slots.FlipCenter), the
-- hitboxes stay the authored GrillSlot:n ones and the camera anchors do not change. No Modux, no Vide, no network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

export type Rig = {
	-- `busy` = slots with a sausage, `total` = slots of the grill, `ready` = cooking share (0..1) of the furthest one.
	Step: (self: Rig, dt: number, busy: number, total: number) -> (),
	-- The frame of the rig: X along the sausage, Z along the line of slots (nil until the poses are known).
	Frame: (self: Rig) -> CFrame?,
	Heat: (self: Rig) -> number,
	Destroy: (self: Rig) -> (),
}

export type Options = {
	Folder: Folder,
	Rules: Content.PrepWorldRules,
	-- pose of the food of a slot (GrillView.PoseOf), nil when it is not streamed in
	PoseOf: (slot: number) -> CFrame?,
	-- the slot is in use at this level of the grill (the plate covers these only; an upgrade rebuilds it)
	Active: (slot: number) -> boolean,
	-- the model of the real roller grill (the host of the slots), hidden locally
	Roller: () -> Model?,
	Slots: number,
}

const GrillRig = {}

const SAUSAGE = 1.0 -- studs (AST-002 long axis)
const HIDE_EVERY = 0.25 -- s: the world re-makes its models, so the hiding is re-applied at 4 Hz
const COLD = Color3.fromHex("#5A5F6B")
const WARM = Color3.fromHex("#E2641C")
const HOT = Color3.fromHex("#FF9A3C")
const SLAB = Color3.fromHex("#2B2233")
const STAND = 0.24 -- studs: the housing from the counter up to the slab (the trailer grill is the same model, see tools/assetplace/bar_grill_world.luau)
const RISE, FALL = 0.9, 0.3 -- heat per second

local function block(folder: Folder, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	const made = Instance.new("Part")
	made.Name = name
	made.Size = size
	made.Color = color
	made.Material = material
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Massless = true
	made.Parent = folder
	return made
end

local function setLocal(root: Instance, value: number)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- the sausages that sit on the grill are not part of it
			local food = false
			local parent: Instance? = descendant.Parent
			while parent ~= nil and parent ~= root do
				if parent:IsA("Model") and string.find(parent.Name, "^Sausage") ~= nil then
					food = true
					break
				end
				parent = parent.Parent
			end
			if not food then
				descendant.LocalTransparencyModifier = value
			end
		end
	end
end

function GrillRig.new(options: Options): Rig
	const rig = options.Rules.Rig
	local frame: CFrame? = nil
	local built = false
	local built_signature = ""
	local heat = 0
	local hideAt = 0
	local hidden: Model? = nil
	const bars: { Part } = {}
	const frames: { Part } = {}
	local base: Part? = nil
	local flame: Part? = nil
	local burner: Part? = nil
	local tray: Part? = nil
	local stand: Part? = nil

	-- Builds the parts once the poses of the slots are known: the frame is the pose of the first slot, centred on all of them.
	local function build(): boolean
		local first: CFrame? = nil
		local sum = Vector3.zero
		local count = 0
		local lowest, highest = math.huge, -math.huge
		local reference: CFrame? = nil
		for slot = 1, options.Slots do
			const pose = if options.Active(slot) then options.PoseOf(slot) else nil
			if pose ~= nil then
				first = first or pose
				reference = reference or pose
				sum += pose.Position
				count += 1
			end
		end
		if first == nil or reference == nil or count == 0 then
			return false
		end
		const ref = reference :: CFrame
		const centre = sum / count
		-- the span of the slots along the line (the Z of the pose)
		for slot = 1, options.Slots do
			const pose = if options.Active(slot) then options.PoseOf(slot) else nil
			if pose ~= nil then
				const along = (pose.Position - centre):Dot(ref.ZVector)
				lowest = math.min(lowest, along)
				highest = math.max(highest, along)
			end
		end
		const spanZ = (highest - lowest) + 2 * rig.Margin + 0.55
		const spanX = SAUSAGE + 2 * rig.Margin
		-- the foot of the sausage is the pose height; the middle of the span along the line is the middle of the slots
		const middle = centre + ref.ZVector * ((highest + lowest) / 2)
		const origin = CFrame.fromMatrix(Vector3.new(middle.X, ref.Position.Y, middle.Z), ref.XVector, ref.YVector)
		frame = origin
		-- Base: the slab, its top 0.16 under the foot of the sausage; the bars stand over it
		const slabH = 0.12
		base = block(options.Folder, "Base", Vector3.new(spanX, slabH, spanZ), SLAB, Enum.Material.SmoothPlastic)
		base.CFrame = origin * CFrame.new(0, -0.16 - slabH / 2, 0)
		stand = block(options.Folder, "Stand", Vector3.new(spanX - 0.1, STAND, spanZ - 0.1), SLAB, Enum.Material.SmoothPlastic)
		stand.CFrame = origin * CFrame.new(0, -0.16 - slabH - STAND / 2, 0)
		-- the edge: four Cream strips, the toy-plastic rim
		const edge = 0.07
		for index = 1, 4 do
			const along = index <= 2
			const side = if index % 2 == 1 then 1 else -1
			const strip = block(
				options.Folder,
				"Frame",
				if along then Vector3.new(edge, edge * 1.2, spanZ + edge) else Vector3.new(spanX + edge, edge * 1.2, edge),
				Theme.Color.Cream,
				Enum.Material.SmoothPlastic
			)
			strip.CFrame = origin * CFrame.new(
				if along then side * (spanX / 2) else 0,
				-0.16 - slabH + edge * 0.6,
				if along then 0 else side * (spanZ / 2)
			)
			table.insert(frames, strip)
		end
		-- Flame: one Neon slab under the bars, lit by the heat
		flame = block(options.Folder, "Flame", Vector3.new(spanX - 0.1, 0.02, spanZ - 0.1), WARM, Enum.Material.Neon)
		flame.CFrame = origin * CFrame.new(0, -0.15, 0)
		flame.Transparency = 1
		-- Bars: along the line of slots (Z), side by side across the sausage (X); the foot of the sausage rests on them
		const gap = rig.BarGap
		const barCount = math.clamp(math.floor((spanX - 0.1) / gap) + 1, 2, math.max(rig.Bars * 2, 2))
		for index = 1, barCount do
			const x = -((barCount - 1) * gap) / 2 + (index - 1) * gap
			const bar = block(options.Folder, `Bar_{index}`, Vector3.new(rig.BarRadius * 2, rig.BarRadius * 2, spanZ - 0.1), COLD, Enum.Material.Neon)
			bar.CFrame = origin * CFrame.new(x, -rig.BarRadius, 0)
			table.insert(bars, bar)
		end
		-- Tray: on the side of the sausage the camera looks from
		const camera = workspace.CurrentCamera
		local side = 1
		if camera ~= nil then
			side = if (camera.CFrame.Position - origin.Position):Dot(origin.XVector) >= 0 then 1 else -1
		end
		tray = block(options.Folder, "Tray", Vector3.new(rig.Tray.Depth, 0.07, spanZ), Theme.Color.Mustard, Enum.Material.SmoothPlastic)
		tray.CFrame = origin * CFrame.new(side * (spanX / 2 + rig.Tray.Depth / 2 - 0.02), -0.16 - rig.Tray.Drop, 0)
		burner = block(options.Folder, "Burner", Vector3.new(rig.Tray.Depth * 0.8, 0.16, spanZ * 0.8), Theme.Tone.Slate.Bottom, Enum.Material.SmoothPlastic)
		burner.CFrame = origin * CFrame.new(-side * (spanX / 2 + rig.Tray.Depth * 0.4), -0.22, 0)
		return true
	end

	-- the slots in use as a string: when it changes (an upgrade of the grill) the plate is built again
	local function signature(): string
		local text = ""
		for slot = 1, options.Slots do
			text ..= if options.Active(slot) then "1" else "0"
		end
		return text
	end

	local function clear()
		for _, bar in bars do
			bar:Destroy()
		end
		table.clear(bars)
		for _, strip in frames do
			strip:Destroy()
		end
		table.clear(frames)
		for _, piece in { base, flame, burner, tray, stand } do
			if piece ~= nil then
				piece:Destroy()
			end
		end
		base, flame, burner, tray, stand = nil, nil, nil, nil, nil
		frame = nil
	end

	local function paint()
		const warm = rig.Heat.Warm
		-- steel grey -> orange (Warm) -> bright (Hot), by the heat of the grill
		local color: Color3
		if heat <= warm then
			color = COLD:Lerp(WARM, math.clamp(heat / math.max(warm, 1e-3), 0, 1))
		else
			color = WARM:Lerp(HOT, math.clamp((heat - warm) / math.max(rig.Heat.Hot - warm, 1e-3), 0, 1))
		end
		for _, bar in bars do
			bar.Color = color
		end
		if flame ~= nil then
			flame.Color = color
			flame.Transparency = 1 - 0.6 * math.clamp((heat - warm) / math.max(1 - warm, 1e-3), 0, 1)
		end
	end

	const self = {} :: any

	function self.Step(_: any, dt: number, busy: number, total: number)
		if not rig.Placeholder then
			return
		end
		const now = signature()
		if built and now ~= built_signature then
			clear()
			built = false
		end
		if not built then
			built = build()
			if built then
				built_signature = now
				paint()
			end
		end
		const wanted = if busy > 0 then math.clamp(0.4 + 0.6 * busy / math.max(total, 1), 0, 1) else 0
		const rate = if wanted > heat then RISE else FALL
		const before = heat
		heat += math.clamp(wanted - heat, -rate * dt, rate * dt)
		if built and math.abs(heat - before) > 1e-3 then
			paint()
		end
		hideAt -= dt
		if hideAt <= 0 then
			hideAt = HIDE_EVERY
			const roller = options.Roller()
			if roller ~= nil then
				hidden = roller
				setLocal(roller, 1)
			end
		end
	end

	function self.Frame(_: any): CFrame?
		return frame
	end

	function self.Heat(_: any): number
		return heat
	end

	function self.Destroy(_: any)
		if hidden ~= nil and hidden.Parent ~= nil then
			setLocal(hidden, 0)
		end
		hidden = nil
		clear()
	end

	return self :: Rig
end

return GrillRig
