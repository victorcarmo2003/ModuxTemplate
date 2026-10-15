--!strict
-- Lobby zones, zone VFX, platform squads and camera (user request 2026-10-11, Provisional; docs/levels/LOBBY.md v2
-- §V2-4, §V2-5; architecture.md §20.6; network.md §16). Pure data, read by PartyService (server, platform occupancy),
-- LobbyController (client: zone triggers, zone VFX, camera) and ReplicatedStorage.shared.Lobby.LobbyZones.
-- Owner: frontend-coder. Every number Provisional (DEC-044: adjusted in playtest).
--
-- The MAP places the zones (user 2026-10-11: the floors are moved in Studio): a BasePart in Workspace tagged
-- "LobbyZone" with the attribute Zone = Key below is the zone floor. A Cylinder Part standing on its axis (or the
-- attribute Shape = "Circle") is a circle of half its diameter; anything else is a rectangle oriented with the Part
-- (its two horizontal sizes; attribute Shape = "Rect" forces it). Squad pads tagged "PartyPlatform" (attribute
-- Party = n) also count for Squad n. A row with no tagged Part falls back to a circle: centre = the MapPoint PointId
-- (WORLD) when the map has it, else Center; radius = Radius. Walking in (|dy| <= Trigger.Height from the floor top)
-- opens its panel; walking out (past the edge + Trigger.Hysteresis) closes it. Squad zones (Platform 1..4) are the
-- squad platforms: the server watches them.

export type Panel = "Classes" | "Shop" | "Codes" | "Platform"

export type Zone = {
	Key: string, -- = attribute Zone of the tagged floor Part
	Panel: Panel,
	Platform: number, -- 1..8 = squad platform n; 0 = not a platform
	PointId: string?, -- fallback: MapPoint that places the zone; nil = Center only
	Center: Vector3, -- fallback: WORLD, floor level (of PointId)
	Radius: number, -- fallback: studs, planar
	-- fallback rectangle (TASK-314, owner 2026-10-15): full X / Z size in studs of the floor apron drawn in the map
	-- (Apron_<Key>_Edge neon outline); set = the zone is that rectangle at Center instead of a circle
	Size: Vector2?,
	Color: Color3, -- frame colour (platforms: Squad.Colors by state instead)
}

-- Neon zone frame (user 2026-10-11, Provisional; LobbyController/Rings.luau): local Neon Parts following the floor
-- edge, a square frame on rectangles and a ring of segments on circles. The base frame stays on the floor and
-- pulses; Count "ghost" frames rise from the edge up to Height and fade out, with a light wobble.
export type Frame = {
	Thickness: number, -- studs: square cross-section of every bar
	Height: number, -- studs a ghost climbs before it is gone
	Count: number, -- ghost frames per zone (staggered over one Period)
	Period: number, -- s for one ghost to climb
	Segments: number, -- bars of the base ring of a circle
	GhostSegments: number, -- bars of a ghost ring (fewer: keeps a disc near 40 Parts)
	Outset: number, -- studs the frame sits outside the floor edge
	Lift: number, -- studs over the floor top (no z-fight)
	Base: number, -- transparency of the base frame at its brightest
	PulseAlpha: number, -- + transparency at the dim end of the breath
	PulsePeriod: number, -- s of one breath
	Ghost: number, -- transparency of a ghost at full strength
	Lighten: number, -- 0..1 towards white for the ghosts
	FadeIn: number, -- 0..1 of the climb: fades in from the floor
	FadeOut: number, -- 0..1 of the climb: fades out before the top
	WobbleTilt: number, -- deg: sine tilt of each ghost
	WobbleSpeed: number, -- rad/s of the tilt
	Light: {
		Brightness: number, -- PointLight in the zone colour over the centre; 0 = none
		Range: number,
		Height: number, -- studs over the floor
	},
}

export type ZoneVfx = {
	ColorTween: number, -- s of a colour change (squad platform state)
	ActiveDistance: number, -- studs from the camera: farther zones are hidden and not animated
}

-- Pad state keys (PadTag.State): Free / Configuring / Open / Closed / Starting.
export type PadPulse = {
	Period: number, -- s of one breath of the ring
	Alpha: number, -- + transparency at the dim end of the breath
}

-- Squad pad presentation (user request 2026-10-12, Provisional): ring + floor glow colour and breath per state, the
-- seal of the sign, the rising sparks. Read by LobbyController (Rings, Pads) and PadTag.
export type Pad = {
	Colors: { [string]: Color3 }, -- by pad state key
	Pulse: { [string]: PadPulse }, -- by pad state key
	-- What the seal under the count pill says: what the run will be ("D1" = day 1, "N1" = night 1). Provisional: every
	-- run starts at day 1; swap this for the real source (class / day of the room) when the run setup is decided.
	Badge: string,
	GlowRings: number, -- flat neon discs around the pad (floor glow; no lights, the lobby is at its 18 light budget)
	GlowAlpha: number, -- transparency of the innermost disc (the outer ones are fainter)
	Sparks: {
		Rate: number, -- particles per second while someone stands on the pad
		Distance: number, -- studs from the camera: farther pads emit nothing
	},
	KickTime: number, -- s of the colour shiver when someone steps on / off
}

export type Lobby = {
	Zones: { Zone },
	Trigger: {
		Hysteresis: number, -- studs added to the edge (radius / half size) to count as "out"
		Height: number, -- studs: max |dy| between the root and the zone floor top
		Poll: number, -- s between two client checks
	},
	Frame: Frame,
	ZoneVfx: ZoneVfx,
	Squad: {
		Poll: number, -- s between two server checks of the platforms
		Countdown: number, -- s between Start and the teleport (the platform is green)
		DefaultMaxPlayers: number,
		DefaultFriendsOnly: boolean,
		Colors: { Free: Color3, Busy: Color3, Starting: Color3 },
		Pad: Pad,
	},
	Camera: {
		MinZoom: number,
		MaxZoom: number,
		StartZoom: number, -- distance pushed once when the lobby takes the camera (out of a first-person zoom)
	},
}

const YELLOW = Color3.fromRGB(255, 200, 61) -- MUSTARD (LOBBY.md §12)
const GREEN = Color3.fromRGB(64, 224, 170) -- MINT
const BLUE = Color3.fromRGB(45, 120, 255)
const WHITE = Color3.fromRGB(255, 250, 240)

-- LOBBY v2 §V2-4: two rows of 4 (X 16 = near row 1..4, X 34 = far row 5..8), pitch 18 (10 studs between edges)
local function squad(n: number, x: number, z: number): Zone
	return {
		Key = `Squad{n}`,
		Panel = "Platform",
		Platform = n,
		PointId = `LOBBY-SQUAD-{n}`,
		Center = Vector3.new(x, 0.39, z),
		Radius = 8, -- pad diameter 16 (user 2026-10-11: pads were too small)
		Color = WHITE,
	}
end

const lobby: Lobby = {
	Zones = {
		-- in front of the stage rope (LW-STAGE blocks Z > -580): the class screen opens here; holds the class camera eye
		{
			Key = "Classes",
			Panel = "Classes",
			Platform = 0,
			PointId = nil,
			Center = Vector3.new(-1.5, 0, -576.45), -- centre of Apron_Classes_Edge (measured in Studio, TASK-314)
			Radius = 9.1,
			Size = Vector2.new(23.15, 16.64), -- Apron_Classes_Edge outline, inner (TASK-314)
			Color = YELLOW,
		},
		{
			Key = "Shop",
			Panel = "Shop",
			Platform = 0,
			PointId = "LOBBY-SHOP",
			Center = Vector3.new(-39.2, 0, -620.0),
			Radius = 7.15,
			Color = GREEN,
		},
		{
			Key = "Codes",
			Panel = "Codes",
			Platform = 0,
			PointId = "LOBBY-CODES",
			Center = Vector3.new(-14.5, 0, -659.65),
			Radius = 6.5,
			Size = Vector2.new(15.34, 11.44), -- Apron_Codes_Edge outline, inner (TASK-314)
			Color = BLUE,
		},
		squad(1, 19.3, -655.1),
		squad(2, 19.3, -631.7),
		squad(3, 19.3, -608.3),
		squad(4, 19.3, -584.9),
	},
	Trigger = {
		Hysteresis = 1.25,
		Height = 8,
		Poll = 0.1,
	},
	Frame = {
		Thickness = 0.22,
		Height = 5,
		Count = 2,
		Period = 2.4,
		Segments = 24,
		GhostSegments = 12,
		Outset = 0.05,
		Lift = 0.02,
		Base = 0,
		PulseAlpha = 0.35,
		PulsePeriod = 1.6,
		Ghost = 0.1,
		Lighten = 0.15,
		FadeIn = 0.12,
		FadeOut = 0.55,
		WobbleTilt = 3,
		WobbleSpeed = 1.8,
		Light = {
			Brightness = 1,
			Range = 12,
			Height = 2,
		},
	},
	ZoneVfx = {
		ColorTween = 0.3,
		ActiveDistance = 110, -- v2 plaza diagonal ~150 (LOBBY.md §V2-14)
	},
	Squad = {
		Poll = 0.15,
		Countdown = 5, -- FEAT-001 "contagem de 5 s"
		DefaultMaxPlayers = 4, -- DEC-012
		DefaultFriendsOnly = false,
		-- legacy ring colours (no longer read by the lobby: Pad.Colors replaced them; no red, style guide §7.4)
		Colors = { Free = WHITE, Busy = YELLOW, Starting = GREEN },
		Pad = {
			Colors = {
				Free = Color3.fromRGB(95, 200, 120), -- Green
				Configuring = Color3.fromRGB(255, 200, 61), -- Mustard
				Open = Color3.fromRGB(95, 200, 120),
				Closed = Color3.fromRGB(138, 143, 163), -- Slate
				Starting = Color3.fromRGB(63, 167, 181), -- Teal
			},
			Pulse = {
				Free = { Period = 2, Alpha = 0.35 },
				Configuring = { Period = 2.6, Alpha = 0.2 },
				Open = { Period = 2.2, Alpha = 0.25 },
				Closed = { Period = 3.2, Alpha = 0.1 },
				Starting = { Period = 0.7, Alpha = 0.5 },
			},
			Badge = "D1",
			GlowRings = 3,
			GlowAlpha = 0.86,
			Sparks = { Rate = 6, Distance = 60 },
			KickTime = 0.45,
		},
	},
	Camera = {
		MinZoom = 0.5,
		MaxZoom = 30,
		StartZoom = 12,
	},
}

return table.freeze(lobby)
