--!strict
-- Lobby zone rings (user request 2026-10-11, Provisional; Content.Lobby.Rings): every lobby zone is covered by a
-- cylinder of glowing rings that rise from the floor while they spin, with a clumsy wobble (sine tilt and sideways
-- drift per ring), fading in at the floor and out at the top. A take on the user's reference beam
-- (workspace.BeamExample: Texture 16892386886, Stretch, LightEmission 1, LightInfluence 0) bent into rings.
--
-- Build: one anchored invisible Part per ring (local, never replicated) holding `Points` Attachments on a circle,
-- each tangent to it (Axis = tangent), and one Beam between each pair of neighbours, curved into an arc
-- (CurveSize = 4/3 * tan(step / 4) * r, cubic Bezier circle; Rings.CurveSign flips it if a build of the engine reads
-- CurveSize1 the other way). FaceCamera ribbons, so a ring reads as a band from any side.
-- Animation: the caller's single Heartbeat calls Step(t); one BulkMoveTo moves every ring Part (the attachments
-- follow), transparency is written only when it changed by more than a step, colours only on SetColor. A zone farther
-- than ActiveDistance from the camera is unparented and skipped. Presentation only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local LobbyZones = require(ReplicatedStorage.shared.Lobby.LobbyZones)

export type Rings = {
	Step: (t: number, camera: Vector3?) -> (),
	SetColor: (key: string, color: Color3) -> (),
	Destroy: () -> (),
}

type Ring = {
	Part: BasePart,
	Beams: { Beam },
	Index: number,
	Alpha: number, -- last transparency written
}

type ZoneVfx = {
	Zone: LobbyZones.Zone,
	Folder: Folder,
	Rings: { Ring },
	Seed: number,
	Color: Color3,
	Shown: boolean,
}

const RULES = Content.Lobby.Rings
const ALPHA_STEP = 0.02
const LIFT = 0.05 -- studs over the floor (no z-fight with the platform top)

local function smooth(x: number): number
	const c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

local function newPart(name: string, parent: Instance): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Parent = parent
	return part
end

local function buildRing(zone: LobbyZones.Zone, index: number, color: Color3, parent: Instance): Ring
	const part = newPart(`Ring{index}`, parent)
	part.CFrame = CFrame.new(zone.Center)
	const count = math.max(RULES.Points, 3)
	const radius = zone.Radius * RULES.RadiusScale
	const step = 2 * math.pi / count
	const curve = RULES.CurveSign * (4 / 3) * math.tan(step / 4) * radius
	const attachments: { Attachment } = {}
	for i = 1, count do
		const angle = (i - 1) * step
		const position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		const tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		const attachment = Instance.new("Attachment")
		attachment.Name = `A{i}`
		attachment.CFrame = CFrame.fromMatrix(position, tangent, Vector3.yAxis)
		attachment.Parent = part
		attachments[i] = attachment
	end
	const beams: { Beam } = {}
	const transparency = NumberSequence.new(1)
	for i = 1, count do
		const beam = Instance.new("Beam")
		beam.Name = `B{i}`
		beam.Attachment0 = attachments[i]
		beam.Attachment1 = attachments[i % count + 1]
		beam.CurveSize0 = curve
		beam.CurveSize1 = curve
		beam.Segments = RULES.Segments
		beam.Width0 = RULES.Width
		beam.Width1 = RULES.Width
		beam.FaceCamera = true
		beam.Texture = RULES.Texture
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureLength = 1
		beam.TextureSpeed = RULES.TextureSpeed
		beam.LightEmission = RULES.LightEmission
		beam.LightInfluence = 0
		beam.Brightness = RULES.Brightness
		beam.Color = ColorSequence.new(color)
		beam.Transparency = transparency
		beam.Parent = part
		beams[i] = beam
	end
	return { Part = part, Beams = beams, Index = index, Alpha = 1 }
end

return function(): Rings
	const root = Instance.new("Folder")
	root.Name = "LobbyZoneRings"
	root.Parent = workspace

	const vfx: { [string]: ZoneVfx } = {}
	const order: { ZoneVfx } = {}
	const random = Random.new()

	local function build()
		for _, entry in order do
			entry.Folder:Destroy()
		end
		table.clear(order)
		table.clear(vfx)
		for _, zone in LobbyZones.List() do
			const folder = Instance.new("Folder")
			folder.Name = zone.Key
			const rings: { Ring } = {}
			for index = 1, RULES.Count do
				table.insert(rings, buildRing(zone, index, zone.Color, folder))
			end
			const entry: ZoneVfx = {
				Zone = zone,
				Folder = folder,
				Rings = rings,
				Seed = random:NextNumber(0, 100),
				Color = zone.Color,
				Shown = false,
			}
			vfx[zone.Key] = entry
			table.insert(order, entry)
		end
	end

	local function setColor(key: string, color: Color3)
		const entry = vfx[key]
		if entry == nil or entry.Color == color then
			return
		end
		entry.Color = color
		const sequence = ColorSequence.new(color)
		for _, ring in entry.Rings do
			for _, beam in ring.Beams do
				beam.Color = sequence
			end
		end
	end

	-- Zones resolved again when the lobby map streamed in (a point moved): rebuilt in place, colours kept.
	local function moved(): boolean
		const zones = LobbyZones.List()
		if #zones ~= #order then
			return true
		end
		for i, zone in zones do
			if order[i].Zone.Center ~= zone.Center or order[i].Zone.Key ~= zone.Key then
				return true
			end
		end
		return false
	end

	const parts: { BasePart } = {}
	const frames: { CFrame } = {}
	const tilt = math.rad(RULES.WobbleTilt)
	const spin = math.rad(RULES.Spin)
	const count = math.max(RULES.Count, 1)
	const height = math.max(RULES.Height, 0.1)
	const fadeIn = math.max(RULES.FadeIn, 0.001)
	const fadeOut = math.max(RULES.FadeOut, 0.001)

	local function step(t: number, camera: Vector3?)
		if moved() then
			const colors: { [string]: Color3 } = {}
			for key, entry in vfx do
				colors[key] = entry.Color
			end
			build()
			for key, color in colors do
				setColor(key, color)
			end
		end
		table.clear(parts)
		table.clear(frames)
		for _, entry in order do
			const center = entry.Zone.Center
			const near = camera == nil or (camera - center).Magnitude <= RULES.ActiveDistance
			if near ~= entry.Shown then
				entry.Shown = near
				entry.Folder.Parent = if near then root else nil
			end
			if near then
				const seed = entry.Seed
				for _, ring in entry.Rings do
					const i = ring.Index - 1
					const phase = (t * RULES.Rise / height + i / count + seed) % 1
					const strength = smooth(phase / fadeIn) * smooth((1 - phase) / fadeOut)
					const wobble = t * RULES.WobbleSpeed + seed
					const rx = tilt * math.sin(wobble + i * 1.9)
					const rz = tilt * math.cos(wobble * 0.83 + i * 2.7)
					const dx = RULES.WobbleShift * math.sin(wobble * 0.7 + i)
					const dz = RULES.WobbleShift * math.cos(wobble * 0.55 + i * 1.4)
					const turn = (if i % 2 == 0 then spin else -spin) * t + i * 0.9
					table.insert(parts, ring.Part)
					table.insert(
						frames,
						CFrame.new(center.X + dx, center.Y + LIFT + phase * height, center.Z + dz)
							* CFrame.Angles(rx, 0, rz)
							* CFrame.Angles(0, turn, 0)
					)
					local alpha = 1 - (1 - RULES.Transparency) * strength
					alpha = math.floor(alpha / ALPHA_STEP + 0.5) * ALPHA_STEP
					if alpha ~= ring.Alpha then
						ring.Alpha = alpha
						const sequence = NumberSequence.new(math.clamp(alpha, 0, 1))
						for _, beam in ring.Beams do
							beam.Transparency = sequence
						end
					end
				end
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
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
