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
const ALPHA_STEP = 0.02
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

local function buildZone(zone: LobbyZones.Zone, color: Color3, seed: number): ZoneVfx
	const folder = Instance.new("Folder")
	folder.Name = zone.Key
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
	return {
		Zone = zone,
		Folder = folder,
		Base = base,
		Ghosts = ghosts,
		Light = newLight(zone, color, folder),
		Seed = seed,
		Color = color,
		From = color,
		Target = color,
		TweenAt = -1,
		BaseAlpha = FRAME.Base,
		Shown = false,
	}
end

local function paint(entry: ZoneVfx, color: Color3)
	entry.Color = color
	for _, part in entry.Base do
		part.Color = color
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

	const ghostCount = math.max(math.floor(FRAME.Count), 1)
	const period = math.max(FRAME.Period, 0.1)
	const pulsePeriod = math.max(FRAME.PulsePeriod, 0.1)
	const fadeIn = math.max(FRAME.FadeIn, 0.001)
	const fadeOut = math.max(FRAME.FadeOut, 0.001)
	const tilt = math.rad(FRAME.WobbleTilt)
	const tween = math.max(VFX.ColorTween, 0.001)

	local function step(t: number, camera: Vector3?)
		clock = t
		if LobbyZones.Version() ~= built then
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
			const zone = entry.Zone
			const near = camera == nil or (camera - zone.Center).Magnitude <= VFX.ActiveDistance + zone.Radius
			if near ~= entry.Shown then
				entry.Shown = near
				entry.Folder.Parent = if near then root else nil
			end
			if near then
				const seed = entry.Seed
				-- base frame: brightest at wave 1, dims by PulseAlpha
				const wave = 0.5 + 0.5 * math.sin(2 * math.pi * t / pulsePeriod + seed)
				const baseAlpha = math.clamp(quantize(FRAME.Base + FRAME.PulseAlpha * (1 - wave)), 0, 1)
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
