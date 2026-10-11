--!strict
-- Lobby zone VFX, "light column" (user choice 2026-10-11, Provisional; Content.Lobby.Column / Rings / Floor / ZoneVfx).
-- Every zone read from LobbyZones (any count, no position in code) gets:
--  * a soft cylinder of light in the zone colour: Column.Panels vertical Beams on the sides of a prism around the
--    circle (FaceCamera off, attachment X = up, Y = outward normal, Z = tangent, so the ribbon width runs along the
--    tangent; Column.Roll turns them if an engine build reads the width on the other axis). The user's reference beam
--    (workspace.BeamExample): texture 16892386886, Stretch, LightEmission 1, LightInfluence 0, scrolling up; the
--    transparency goes Base at the floor -> Middle at half height -> 1 at the top, breathing +-PulseAlpha;
--  * Rings.Count thin rings (a CylinderHandleAdornment with InnerRadius each: a clean circle, one instance) a bit
--    lighter than the column, rising from the floor with a fade in/out, staggered, with a very light tilt wobble;
--  * a thin ring on the floor (same adornment kind) pulsing with the column.
-- SetColor tweens a zone to a colour in ZoneVfx.ColorTween s (squad platforms: free / busy / starting).
-- Cost: Panels beams + Count + 1 adornments per zone; the caller's single Heartbeat calls Step(t); transparency is
-- written only when it moved by more than a step; a zone farther than ActiveDistance from the camera is unparented
-- and skipped. Local only, never replicated. Presentation only: the server decides squads and colours' meaning.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local LobbyZones = require(ReplicatedStorage.shared.Lobby.LobbyZones)

export type Rings = {
	Step: (t: number, camera: Vector3?) -> (),
	SetColor: (key: string, color: Color3) -> (),
	Destroy: () -> (),
}

type Ring = {
	Adornment: CylinderHandleAdornment,
	Index: number,
	Alpha: number, -- last transparency written
}

type ZoneVfx = {
	Zone: LobbyZones.Zone,
	Folder: Folder,
	Anchor: BasePart,
	Panels: { Beam },
	Rings: { Ring },
	Floor: CylinderHandleAdornment,
	Seed: number,
	Color: Color3, -- shown now
	From: Color3, -- tween start
	Target: Color3, -- tween end
	TweenAt: number, -- t the tween started; < 0 = no tween running
	PanelAlpha: number, -- last pulse offset written to the panels
	FloorAlpha: number,
	Shown: boolean,
}

const LOBBY = Content.Lobby
const COLUMN = LOBBY.Column
const RINGS = LOBBY.Rings
const FLOOR = LOBBY.Floor
const VFX = LOBBY.ZoneVfx
const ALPHA_STEP = 0.02
const LIFT = 0.05 -- studs over the floor (no z-fight with the platform top)
const WHITE = Color3.new(1, 1, 1)
const FLAT = CFrame.Angles(math.pi / 2, 0, 0) -- a handle cylinder runs along its Z axis: lay it flat

local function smooth(x: number): number
	const c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

local function quantize(x: number): number
	return math.floor(x / ALPHA_STEP + 0.5) * ALPHA_STEP
end

local function ringColor(color: Color3): Color3
	return color:Lerp(WHITE, math.clamp(RINGS.Lighten, 0, 1))
end

local function panelSequence(pulse: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, math.clamp(COLUMN.Base + pulse, 0, 1)),
		NumberSequenceKeypoint.new(0.5, math.clamp(COLUMN.Middle + pulse, 0, 1)),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function newAnchor(zone: LobbyZones.Zone, parent: Instance): Part
	const part = Instance.new("Part")
	part.Name = "Anchor"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.CFrame = CFrame.new(zone.Center)
	part.Parent = parent
	return part
end

local function newBand(
	name: string,
	anchor: BasePart,
	outer: number,
	width: number,
	thickness: number,
	color: Color3,
	alpha: number
): CylinderHandleAdornment
	const band = Instance.new("CylinderHandleAdornment")
	band.Name = name
	band.Adornee = anchor
	band.Radius = math.max(outer, 0.1)
	band.InnerRadius = math.clamp(outer - width, 0, band.Radius)
	band.Height = math.max(thickness, 0.01)
	band.CFrame = CFrame.new(0, LIFT, 0) * FLAT
	band.Color3 = color
	band.Transparency = alpha
	band.AlwaysOnTop = false
	band.ZIndex = 0
	band.Parent = anchor
	return band
end

local function buildPanels(zone: LobbyZones.Zone, anchor: BasePart, color: Color3): { Beam }
	-- Panels = 0 turns the light column off (user 2026-10-11: rings only, no pillars)
	if COLUMN.Panels <= 0 then
		return {}
	end
	const count = math.max(math.floor(COLUMN.Panels), 3)
	const radius = zone.Radius * COLUMN.RadiusScale
	const step = 2 * math.pi / count
	const apothem = radius * math.cos(step / 2)
	const width = 2 * radius * math.sin(step / 2) * COLUMN.Overlap
	const height = math.max(COLUMN.Height, 0.5)
	const roll = CFrame.Angles(math.rad(COLUMN.Roll), 0, 0)
	const colors = ColorSequence.new(color)
	const transparency = panelSequence(0)
	const beams: { Beam } = {}
	for i = 1, count do
		const angle = (i - 0.5) * step
		const normal = Vector3.new(math.cos(angle), 0, math.sin(angle))
		const bottom = Instance.new("Attachment")
		bottom.Name = `P{i}Bottom`
		bottom.CFrame = CFrame.fromMatrix(normal * apothem + Vector3.new(0, LIFT, 0), Vector3.yAxis, normal) * roll
		bottom.Parent = anchor
		const top = Instance.new("Attachment")
		top.Name = `P{i}Top`
		top.CFrame = CFrame.fromMatrix(normal * apothem + Vector3.new(0, height, 0), Vector3.yAxis, normal) * roll
		top.Parent = anchor
		const beam = Instance.new("Beam")
		beam.Name = `P{i}`
		beam.Attachment0 = bottom
		beam.Attachment1 = top
		beam.CurveSize0 = 0
		beam.CurveSize1 = 0
		beam.Segments = math.max(math.floor(COLUMN.Segments), 1)
		beam.Width0 = width
		beam.Width1 = width
		beam.FaceCamera = false
		beam.Texture = COLUMN.Texture
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureLength = COLUMN.TextureLength
		beam.TextureSpeed = COLUMN.TextureSpeed
		beam.LightEmission = COLUMN.LightEmission
		beam.LightInfluence = 0
		beam.Brightness = COLUMN.Brightness
		beam.Color = colors
		beam.Transparency = transparency
		beam.Parent = anchor
		beams[i] = beam
	end
	return beams
end

local function buildZone(zone: LobbyZones.Zone, color: Color3, seed: number): ZoneVfx
	const folder = Instance.new("Folder")
	folder.Name = zone.Key
	const anchor = newAnchor(zone, folder)
	const panels = buildPanels(zone, anchor, color)
	const rings: { Ring } = {}
	for index = 1, math.max(math.floor(RINGS.Count), 0) do
		const band = newBand(
			`Ring{index}`,
			anchor,
			zone.Radius * RINGS.RadiusScale,
			RINGS.Width,
			RINGS.Thickness,
			ringColor(color),
			1
		)
		table.insert(rings, { Adornment = band, Index = index, Alpha = 1 })
	end
	const floor = newBand(
		"Floor",
		anchor,
		zone.Radius * FLOOR.RadiusScale,
		FLOOR.Width,
		FLOOR.Thickness,
		color,
		FLOOR.Transparency
	)
	return {
		Zone = zone,
		Folder = folder,
		Anchor = anchor,
		Panels = panels,
		Rings = rings,
		Floor = floor,
		Seed = seed,
		Color = color,
		From = color,
		Target = color,
		TweenAt = -1,
		PanelAlpha = 0,
		FloorAlpha = FLOOR.Transparency,
		Shown = false,
	}
end

local function paint(entry: ZoneVfx, color: Color3)
	entry.Color = color
	const sequence = ColorSequence.new(color)
	for _, beam in entry.Panels do
		beam.Color = sequence
	end
	const light = ringColor(color)
	for _, ring in entry.Rings do
		ring.Adornment.Color3 = light
	end
	entry.Floor.Color3 = color
end

return function(): Rings
	const root = Instance.new("Folder")
	root.Name = "LobbyZoneRings"
	root.Parent = workspace

	const vfx: { [string]: ZoneVfx } = {}
	const order: { ZoneVfx } = {}
	const random = Random.new()
	local clock = 0

	local function build()
		const kept: { [string]: ZoneVfx } = table.clone(vfx)
		for _, entry in order do
			entry.Folder:Destroy()
		end
		table.clear(order)
		table.clear(vfx)
		for _, zone in LobbyZones.List() do
			const old = kept[zone.Key]
			const entry = buildZone(zone, if old then old.Color else zone.Color, random:NextNumber(0, 100))
			if old then
				entry.From = old.From
				entry.Target = old.Target
				entry.TweenAt = old.TweenAt
			end
			vfx[zone.Key] = entry
			table.insert(order, entry)
		end
	end

	local function setColor(key: string, color: Color3)
		const entry = vfx[key]
		if entry == nil or entry.Target == color then
			return
		end
		entry.From = entry.Color
		entry.Target = color
		entry.TweenAt = clock
	end

	-- Zones resolved again when the lobby map streamed in (a point moved): rebuilt in place, colours kept.
	local function moved(): boolean
		const zones = LobbyZones.List()
		if #zones ~= #order then
			return true
		end
		for i, zone in zones do
			const entry = order[i]
			if entry.Zone.Center ~= zone.Center or entry.Zone.Key ~= zone.Key or entry.Zone.Radius ~= zone.Radius then
				return true
			end
		end
		return false
	end

	const ringCount = math.max(math.floor(RINGS.Count), 1)
	const reach = math.max(COLUMN.Height * RINGS.Reach, 0.1)
	const period = math.max(RINGS.Period, 0.1)
	const pulsePeriod = math.max(COLUMN.PulsePeriod, 0.1)
	const fadeIn = math.max(RINGS.FadeIn, 0.001)
	const fadeOut = math.max(RINGS.FadeOut, 0.001)
	const tilt = math.rad(RINGS.WobbleTilt)
	const tween = math.max(VFX.ColorTween, 0.001)

	local function step(t: number, camera: Vector3?)
		clock = t
		if moved() then
			build()
		end
		for _, entry in order do
			if entry.TweenAt >= 0 then
				const k = (t - entry.TweenAt) / tween
				if k >= 1 then
					entry.TweenAt = -1
					paint(entry, entry.Target)
				else
					paint(entry, entry.From:Lerp(entry.Target, smooth(k)))
				end
			end
			const center = entry.Zone.Center
			const near = camera == nil or (camera - center).Magnitude <= VFX.ActiveDistance
			if near ~= entry.Shown then
				entry.Shown = near
				entry.Folder.Parent = if near then root else nil
			end
			if near then
				const seed = entry.Seed
				const wave = math.sin(2 * math.pi * t / pulsePeriod + seed)
				const pulse = quantize(COLUMN.PulseAlpha * wave)
				if pulse ~= entry.PanelAlpha then
					entry.PanelAlpha = pulse
					const sequence = panelSequence(pulse)
					for _, beam in entry.Panels do
						beam.Transparency = sequence
					end
				end
				const floorAlpha = math.clamp(quantize(FLOOR.Transparency - FLOOR.PulseAlpha * wave), 0, 1)
				if floorAlpha ~= entry.FloorAlpha then
					entry.FloorAlpha = floorAlpha
					entry.Floor.Transparency = floorAlpha
				end
				for _, ring in entry.Rings do
					const i = ring.Index - 1
					const phase = (t / period + i / ringCount + seed) % 1
					const strength = smooth(phase / fadeIn) * smooth((1 - phase) / fadeOut)
					const wobble = t * RINGS.WobbleSpeed + seed
					const rx = tilt * math.sin(wobble + i * 1.9)
					const rz = tilt * math.cos(wobble * 0.83 + i * 2.7)
					ring.Adornment.CFrame = CFrame.new(0, LIFT + phase * reach, 0) * CFrame.Angles(rx, 0, rz) * FLAT
					const alpha = math.clamp(quantize(1 - (1 - RINGS.Transparency) * strength), 0, 1)
					if alpha ~= ring.Alpha then
						ring.Alpha = alpha
						ring.Adornment.Transparency = alpha
					end
				end
			end
		end
	end

	local function destroy()
		root:Destroy()
		table.clear(order)
		table.clear(vfx)
	end

	build()

	return {
		Step = step,
		SetColor = setColor,
		Destroy = destroy,
	}
end
