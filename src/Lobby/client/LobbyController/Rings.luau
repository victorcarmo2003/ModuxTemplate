--!strict
-- Lobby zone VFX, neon frames (user request 2026-10-11, Provisional; Content.Lobby.Frame / ZoneVfx).
-- Every zone read from LobbyZones (placed by the tagged floor Parts of the map; any count, no position in code) gets
-- local Neon Parts (Workspace.LobbyZoneVfx, created by this client, never replicated; CanCollide / CanQuery /
-- CanTouch / CastShadow off) in the zone colour:
--  * a base frame on the floor edge: 4 bars on a rectangle (corners closed), Frame.Segments bars on a circle,
--    breathing between Frame.Base and Base + PulseAlpha transparency;
--  * Frame.Count ghost frames (same outline; Frame.GhostSegments bars on a circle) a bit lighter, rising from the edge
--    up to Frame.Height and fading out, staggered, with a light tilt wobble;
--  * optionally a weak PointLight in the zone colour over the centre (Frame.Light).
-- Rectangle: 4 x (1 + Count) Parts; circle: Segments + Count x GhostSegments Parts (24 + 2 x 12 = 48 by default).
-- SetColor tweens a zone to a colour in ZoneVfx.ColorTween s (squad platforms: free / busy / starting).
-- The caller's single Heartbeat calls Step(t); ghosts move with one workspace:BulkMoveTo per zone; transparency is
-- written only when it moved by more than a step; a zone farther than ActiveDistance from the camera is unparented
-- and skipped. LobbyZones.Version() moving (a floor edited / streamed in) rebuilds the frames, colours kept.
-- Presentation only: the server decides squads and what the colours mean.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local LobbyZones = require(ReplicatedStorage.shared.Lobby.LobbyZones)

export type Rings = {
	Step: (t: number, camera: Vector3?) -> (),
	SetColor: (key: string, color: Color3) -> (),
	-- Squad pad: ring + floor glow colour, breath (nil = the zone default), someone standing on it (sparks).
	SetPad: (key: string, color: Color3, pulse: Content.LobbyPadPulse?, occupied: boolean) -> (),
	-- Colour shiver of the ring (someone stepped on / off).
	Kick: (key: string) -> (),
	-- Every zone frame out of the world while true (the class stage shows the character over them, owner 2026-10-16)
	SetHidden: (on: boolean) -> (),
	Destroy: () -> (),
}

type Bar = {
	Offset: CFrame, -- in the zone frame, at the floor
	Size: Vector3,
}

type Ghost = {
	Parts: { BasePart },
	Offsets: { CFrame },
	Targets: { CFrame }, -- reused every frame by BulkMoveTo
	Index: number,
	Alpha: number, -- last transparency written
}

type ZoneVfx = {
	Zone: LobbyZones.Zone,
	Folder: Folder,
	Base: { BasePart },
	Ghosts: { Ghost },
	Light: PointLight?,
	-- squad pads only: flat neon discs (floor glow) and the sparks rising while someone stands on it
	Glow: { BasePart },
	GlowAlpha: { number }, -- last transparency written per disc
	Sparks: ParticleEmitter?,
	Pulse: Content.LobbyPadPulse?, -- breath override (pad state); nil = Content.Lobby.Frame
	Phase: number, -- radians of the breath
	Occupied: boolean,
	KickAt: number, -- t of the colour shiver; < 0 = none
	Seed: number,
	Color: Color3, -- shown now
	From: Color3, -- tween start
	Target: Color3, -- tween end
	TweenAt: number, -- t the tween started; < 0 = no tween running
	BaseAlpha: number, -- last transparency written to the base frame
	Shown: boolean,
}

const LOBBY = Content.Lobby
const FRAME = LOBBY.Frame
const VFX = LOBBY.ZoneVfx
const PAD = LOBBY.Squad.Pad
const ALPHA_STEP = 0.02
const GLOW_GROW = 1.4 -- studs each glow disc reaches past the one inside it
const WHITE = Color3.new(1, 1, 1)
const FOLDER = "LobbyZoneVfx"

local function smooth(x: number): number
	const c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

local function quantize(x: number): number
	return math.floor(x / ALPHA_STEP + 0.5) * ALPHA_STEP
end

local function ghostColor(color: Color3): Color3
	return color:Lerp(WHITE, math.clamp(FRAME.Lighten, 0, 1))
end

-- Bars of the outline, in the zone frame (Y = 0 at the floor top; the bar centre is half a thickness up).
local function outline(zone: LobbyZones.Zone, segments: number): { Bar }
	const t = math.max(FRAME.Thickness, 0.05)
	const y = FRAME.Lift + t / 2
	const bars: { Bar } = {}
	if zone.Shape == "Rect" then
		const hx = zone.HalfX + FRAME.Outset + t / 2
		const hz = zone.HalfZ + FRAME.Outset + t / 2
		-- X sides run the full length (corners closed), Z sides fit between them (no overlap, no z-fight)
		table.insert(bars, { Offset = CFrame.new(0, y, -hz), Size = Vector3.new(2 * hx + t, t, t) })
		table.insert(bars, { Offset = CFrame.new(0, y, hz), Size = Vector3.new(2 * hx + t, t, t) })
		table.insert(bars, { Offset = CFrame.new(-hx, y, 0), Size = Vector3.new(t, t, math.max(2 * hz - t, t)) })
		table.insert(bars, { Offset = CFrame.new(hx, y, 0), Size = Vector3.new(t, t, math.max(2 * hz - t, t)) })
		return bars
	end
	const n = math.max(math.floor(segments), 6)
	const half = math.pi / n
	const radius = zone.Radius + FRAME.Outset + t / 2 -- bar centre line
	const apothem = radius * math.cos(half)
	const length = 2 * radius * math.sin(half) + t * math.tan(half) -- closes the outer seam
	for i = 1, n do
		const angle = (i - 1) * 2 * half
		const normal = Vector3.new(math.cos(angle), 0, math.sin(angle))
		const tangent = Vector3.new(-normal.Z, 0, normal.X)
		table.insert(bars, {
			Offset = CFrame.fromMatrix(normal * apothem + Vector3.new(0, y, 0), tangent, Vector3.yAxis),
			Size = Vector3.new(length, t, t),
		})
	end
	return bars
end

local function newBar(name: string, bar: Bar, cframe: CFrame, color: Color3, alpha: number, parent: Instance): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = alpha
	part.Size = bar.Size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Locked = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function newLight(zone: LobbyZones.Zone, color: Color3, parent: Instance): PointLight?
	const settings = FRAME.Light
	if settings.Brightness <= 0 then
		return nil
	end
	const anchor = Instance.new("Part")
	anchor.Name = "LightAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Massless = true
	anchor.Locked = true
	anchor.CFrame = zone.CFrame * CFrame.new(0, settings.Height, 0)
	anchor.Parent = parent
	const light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = settings.Brightness
	light.Range = settings.Range
	light.Shadows = false
	light.Parent = anchor
	return light
end

-- Flat Neon disc (a block on a rectangle) over the floor: the glow of a squad pad. Disc 1 covers the pad, the next
-- ones reach past its edge, fainter; the bigger the disc, the lower it lies (no z-fight).
local function newGlow(zone: LobbyZones.Zone, index: number, color: Color3, parent: Instance): Part
	const grow = (index - 1) * GLOW_GROW
	const part = Instance.new("Part")
	part.Name = `Glow{index}`
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = math.min(PAD.GlowAlpha + (index - 1) * 0.04, 0.98)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Locked = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	const y = FRAME.Lift + 0.01 * (PAD.GlowRings - index + 1)
	if zone.Shape == "Rect" then
		part.Size = Vector3.new(2 * zone.HalfX + 2 * grow, 0.04, 2 * zone.HalfZ + 2 * grow)
		part.CFrame = zone.CFrame * CFrame.new(0, y + 0.02, 0)
	else
		part.Shape = Enum.PartType.Cylinder
		const diameter = 2 * (zone.Radius + grow)
		part.Size = Vector3.new(0.04, diameter, diameter)
		part.CFrame = zone.CFrame * CFrame.new(0, y + 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2)
	end
	part.Parent = parent
	return part
end

-- Sparks rising from the pad while someone stands on it (off until then; Step switches it by occupancy and distance).
local function newSparks(zone: LobbyZones.Zone, color: Color3, parent: Instance): ParticleEmitter
	const anchor = Instance.new("Part")
	anchor.Name = "SparkAnchor"
	anchor.Size = Vector3.new(zone.HalfX * 1.3, 0.2, zone.HalfZ * 1.3)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Massless = true
	anchor.Locked = true
	anchor.CFrame = zone.CFrame * CFrame.new(0, 0.5, 0)
	anchor.Parent = parent
	const emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparks"
	emitter.Enabled = false
	emitter.Rate = PAD.Sparks.Rate
	emitter.Lifetime = NumberRange.new(1.2, 1.8)
	emitter.Speed = NumberRange.new(3, 4.5)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Drag = 0.6
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.LightEmission = 0.7
	emitter.LightInfluence = 0
	emitter.Color = ColorSequence.new(color:Lerp(WHITE, 0.35))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = anchor
	return emitter
end

-- The map draws a neon outline around some floors (Apron_<Key>_Edge parts); they take the zone colour on this client so
-- the map outline and the frame read as one (TASK-314: the Codes outline was cream under a blue frame). Pads excluded.
local function tintApron(zone: LobbyZones.Zone, color: Color3)
	if zone.Platform > 0 then
		return
	end
	const assets = workspace:FindFirstChild("LOBBY_Assets")
	if assets == nil then
		return
	end
	const name = `Apron_{zone.Key}_Edge`
	for _, descendant in assets:GetDescendants() do
		if descendant.Name == name and descendant:IsA("BasePart") then
			descendant.Color = color
		end
	end
end

local function buildZone(zone: LobbyZones.Zone, color: Color3, seed: number): ZoneVfx
	const folder = Instance.new("Folder")
	folder.Name = zone.Key
	tintApron(zone, color)
	const base: { BasePart } = {}
	for i, bar in outline(zone, FRAME.Segments) do
		base[i] = newBar(`Base{i}`, bar, zone.CFrame * bar.Offset, color, FRAME.Base, folder)
	end
	const ghosts: { Ghost } = {}
	const light = ghostColor(color)
	const ghostBars = outline(zone, FRAME.GhostSegments)
	for index = 1, math.max(math.floor(FRAME.Count), 0) do
		const parts: { BasePart } = {}
		const offsets: { CFrame } = {}
		const targets: { CFrame } = {}
		for i, bar in ghostBars do
			const cframe = zone.CFrame * bar.Offset
			parts[i] = newBar(`Ghost{index}_{i}`, bar, cframe, light, 1, folder)
			offsets[i] = bar.Offset
			targets[i] = cframe
		end
		table.insert(ghosts, { Parts = parts, Offsets = offsets, Targets = targets, Index = index, Alpha = 1 })
	end
	const glow: { BasePart } = {}
	const glowAlpha: { number } = {}
	local sparks: ParticleEmitter? = nil
	if zone.Platform > 0 then
		for i = 1, math.max(math.floor(PAD.GlowRings), 0) do
			glow[i] = newGlow(zone, i, color, folder)
			glowAlpha[i] = glow[i].Transparency
		end
		sparks = newSparks(zone, color, folder)
	end
	return {
		Zone = zone,
		Folder = folder,
		Base = base,
		Ghosts = ghosts,
		Light = newLight(zone, color, folder),
		Glow = glow,
		GlowAlpha = glowAlpha,
		Sparks = sparks,
		Pulse = nil,
		Phase = seed,
		Occupied = false,
		KickAt = -1,
		Seed = seed,
		Color = color,
		From = color,
		Target = color,
		TweenAt = -1,
		BaseAlpha = FRAME.Base,
		Shown = false,
	}
end

-- Writes `color` to every part of the zone (entry.Color stays the colour the zone is heading to / resting at).
local function paint(entry: ZoneVfx, color: Color3)
	for _, part in entry.Base do
		part.Color = color
	end
	for _, part in entry.Glow do
		part.Color = color
	end
	if entry.Sparks then
		entry.Sparks.Color = ColorSequence.new(color:Lerp(WHITE, 0.35))
	end
	const light = ghostColor(color)
	for _, ghost in entry.Ghosts do
		for _, part in ghost.Parts do
			part.Color = light
		end
	end
	if entry.Light then
		entry.Light.Color = color
	end
end

return function(): Rings
	const root = Instance.new("Folder")
	root.Name = FOLDER
	root.Parent = workspace

	const vfx: { [string]: ZoneVfx } = {}
	const order: { ZoneVfx } = {}
	const random = Random.new()
	local clock = 0
	local built = -1 -- LobbyZones.Version() the frames were built for
	local hidden = false

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
				entry.Seed = old.Seed
				entry.From = old.From
				entry.Target = old.Target
				entry.TweenAt = old.TweenAt
				entry.Pulse = old.Pulse
				entry.Phase = old.Phase
				entry.Occupied = old.Occupied
				entry.KickAt = old.KickAt
			end
			vfx[zone.Key] = entry
			table.insert(order, entry)
		end
		built = LobbyZones.Version()
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

	local function setPad(key: string, color: Color3, pulse: Content.LobbyPadPulse?, occupied: boolean)
		const entry = vfx[key]
		if entry == nil then
			return
		end
		entry.Pulse = pulse
		entry.Occupied = occupied
		setColor(key, color)
	end

	local function kick(key: string)
		const entry = vfx[key]
		if entry then
			entry.KickAt = clock
		end
	end

	const ghostCount = math.max(math.floor(FRAME.Count), 1)
	const period = math.max(FRAME.Period, 0.1)
	const pulsePeriod = math.max(FRAME.PulsePeriod, 0.1)
	const fadeIn = math.max(FRAME.FadeIn, 0.001)
	const fadeOut = math.max(FRAME.FadeOut, 0.001)
	const tilt = math.rad(FRAME.WobbleTilt)
	const tween = math.max(VFX.ColorTween, 0.001)

	local function step(t: number, camera: Vector3?)
		if hidden then
			return
		end
		const dt = math.clamp(t - clock, 0, 0.1)
		clock = t
		if LobbyZones.Version() ~= built then
			build()
		end
		for _, entry in order do
			local repaint = false
			if entry.TweenAt >= 0 then
				const k = (t - entry.TweenAt) / tween
				if k >= 1 then
					entry.TweenAt = -1
					entry.Color = entry.Target
				else
					entry.Color = entry.From:Lerp(entry.Target, smooth(k))
				end
				repaint = true
			end
			local shown = entry.Color
			if entry.KickAt >= 0 then
				const k = (t - entry.KickAt) / math.max(PAD.KickTime, 0.05)
				if k >= 1 then
					entry.KickAt = -1 -- last repaint with the resting colour
				else
					-- quick shiver towards white, fading out
					shown = shown:Lerp(WHITE, 0.8 * (1 - k) * (0.5 + 0.5 * math.sin(k * 45)))
				end
				repaint = true
			end
			if repaint then
				paint(entry, shown)
			end
			const zone = entry.Zone
			const near = camera == nil or (camera - zone.Center).Magnitude <= VFX.ActiveDistance + zone.Radius
			if near ~= entry.Shown then
				entry.Shown = near
				entry.Folder.Parent = if near then root else nil
			end
			if near then
				const seed = entry.Seed
				-- base frame: brightest at wave 1, dims by the breath depth (a pad state sets its own period and depth)
				const pulse = entry.Pulse
				entry.Phase += dt * 2 * math.pi / math.max(if pulse then pulse.Period else pulsePeriod, 0.1)
				const wave = 0.5 + 0.5 * math.sin(entry.Phase)
				const depth = if pulse then pulse.Alpha else FRAME.PulseAlpha
				const baseAlpha = math.clamp(quantize(FRAME.Base + depth * (1 - wave)), 0, 1)
				-- floor glow follows the breath, brighter while someone stands on the pad
				for i, part in entry.Glow do
					const faint = math.min(PAD.GlowAlpha + (i - 1) * 0.04, 0.98)
					const alpha = math.clamp(quantize(faint - (if entry.Occupied then 0.06 else 0) - 0.06 * wave), 0, 1)
					if alpha ~= entry.GlowAlpha[i] then
						entry.GlowAlpha[i] = alpha
						part.Transparency = alpha
					end
				end
				const sparks = entry.Sparks
				if sparks then
					const on = entry.Occupied and (camera == nil or (camera - zone.Center).Magnitude <= PAD.Sparks.Distance)
					if sparks.Enabled ~= on then
						sparks.Enabled = on
					end
				end
				if baseAlpha ~= entry.BaseAlpha then
					entry.BaseAlpha = baseAlpha
					for _, part in entry.Base do
						part.Transparency = baseAlpha
					end
				end
				for _, ghost in entry.Ghosts do
					const i = ghost.Index - 1
					const phase = (t / period + i / ghostCount + seed) % 1
					const strength = smooth(phase / fadeIn) * smooth((1 - phase) / fadeOut)
					const wobble = t * FRAME.WobbleSpeed + seed
					const rx = tilt * math.sin(wobble + i * 1.9)
					const rz = tilt * math.cos(wobble * 0.83 + i * 2.7)
					const lift = zone.CFrame * CFrame.new(0, phase * FRAME.Height, 0) * CFrame.Angles(rx, 0, rz)
					const targets = ghost.Targets
					for k, offset in ghost.Offsets do
						targets[k] = lift * offset
					end
					workspace:BulkMoveTo(ghost.Parts, targets, Enum.BulkMoveMode.FireCFrameChanged)
					const alpha = math.clamp(quantize(1 - (1 - FRAME.Ghost) * strength), 0, 1)
					if alpha ~= ghost.Alpha then
						ghost.Alpha = alpha
						for _, part in ghost.Parts do
							part.Transparency = alpha
						end
					end
				end
			end
		end
	end

	local function setHidden(on: boolean)
		hidden = on
		root.Parent = if on then nil else workspace
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
		SetPad = setPad,
		Kick = kick,
		SetHidden = setHidden,
		Destroy = destroy,
	}
end
