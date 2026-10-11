--!strict
-- Lobby zones, ring VFX, platform squads and camera (user request 2026-10-11, Provisional; docs/levels/LOBBY.md v2
-- §V2-4, §V2-5; architecture.md §20.6; network.md §16). Pure data, read by PartyService (server, platform occupancy),
-- LobbyController (client: zone triggers, ring VFX, camera) and ReplicatedStorage.shared.Lobby.LobbyZones.
-- Owner: frontend-coder. Every number Provisional (DEC-044: adjusted in playtest).
--
-- A zone is a circle on the floor. Center = the MapPoint `PointId` when the map has it (WORLD), else `Center`.
-- Walking in (planar distance <= Radius, |dy| <= Trigger.Height) opens its panel; walking out (distance >
-- Radius + Trigger.Hysteresis) closes it. Squad zones (Platform 1..4; lobby v2 scaled x1.3 around the spawn, 2026-10-11) are the squad platforms: the server watches them.

export type Panel = "Classes" | "Shop" | "Codes" | "Platform"

export type Zone = {
	Key: string,
	Panel: Panel,
	Platform: number, -- 1..8 = squad platform n; 0 = not a platform
	PointId: string?, -- MapPoint that places the zone; nil = Center only
	Center: Vector3, -- WORLD, floor level (fallback of PointId)
	Radius: number, -- studs, planar
	Color: Color3, -- ring colour (platforms: Squad.Colors by state instead)
}

-- "Light column" zone VFX (user choice 2026-10-11, Provisional): a soft cylinder of light in the zone colour made of
-- vertical Beam panels (the user's reference beam, workspace.BeamExample, texture scrolling up), thin coloured rings
-- rising and fading inside it, and a thin ring on the floor. Read by LobbyController/Rings.luau.
export type Column = {
	Height: number, -- studs from the floor to the top of the column
	Panels: number, -- vertical Beams around the circle (one per side of the prism)
	RadiusScale: number, -- column radius = zone Radius * this
	Overlap: number, -- panel width = side of the prism * this (hides the seams; >1.15 shows bright overlaps)
	Roll: number, -- deg: extra roll of each panel around its own vertical axis (90 if the panels read as spokes)
	Texture: string,
	TextureSpeed: number, -- > 0 scrolls the texture up (bottom attachment -> top attachment)
	TextureLength: number,
	Segments: number,
	LightEmission: number,
	Brightness: number, -- keep at 1: higher washes the colour into white
	Base: number, -- transparency at the floor
	Middle: number, -- transparency at half height (the top is always 1: fades out)
	PulsePeriod: number, -- s of one brightness breath
	PulseAlpha: number, -- +- transparency of the breath
}

export type Rings = {
	Count: number, -- thin rings per zone (staggered over one Period)
	RadiusScale: number, -- outer radius = zone Radius * this (a hair outside the column)
	Width: number, -- studs: ring band (outer - inner radius)
	Thickness: number, -- studs: vertical thickness of the band
	Lighten: number, -- 0..1 towards white (a ring is a bit lighter than its column)
	Period: number, -- s for one ring to climb from the floor to Reach
	Reach: number, -- 0..1 of Column.Height the ring climbs before it loops back
	Transparency: number, -- 0..1 at full strength
	FadeIn: number, -- 0..1 of the climb: fades in from the floor
	FadeOut: number, -- 0..1 of the climb: fades out before the top
	WobbleTilt: number, -- deg: sine tilt of each ring (very light)
	WobbleSpeed: number, -- rad/s of the tilt
}

export type Floor = {
	RadiusScale: number, -- outer radius = zone Radius * this
	Width: number, -- studs
	Thickness: number, -- studs
	Transparency: number,
	PulseAlpha: number, -- +- transparency, on Column.PulsePeriod
}

export type ZoneVfx = {
	ColorTween: number, -- s of a colour change (squad platform state)
	ActiveDistance: number, -- studs from the camera: farther zones are hidden and not animated
}

export type Lobby = {
	Zones: { Zone },
	Trigger: {
		Hysteresis: number, -- studs added to the radius to count as "out"
		Height: number, -- studs: max |dy| between the root and the zone floor
		Poll: number, -- s between two client checks
	},
	Column: Column,
	Rings: Rings,
	Floor: Floor,
	ZoneVfx: ZoneVfx,
	Squad: {
		Poll: number, -- s between two server checks of the platforms
		Countdown: number, -- s between Start and the teleport (the platform is green)
		DefaultMaxPlayers: number,
		DefaultFriendsOnly: boolean,
		Colors: { Free: Color3, Busy: Color3, Starting: Color3 },
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
const RED = Color3.fromRGB(235, 70, 60) -- KETCHUP

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
			Center = Vector3.new(-1.5, 0, -577.1),
			Radius = 9.1,
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
	Column = {
		Height = 7,
		Panels = 0, -- 0 = no light column, rings only (user 2026-10-11)
		RadiusScale = 1,
		Overlap = 1.08,
		Roll = 0,
		Texture = "rbxassetid://16892386886", -- the user's reference beam (workspace.BeamExample)
		TextureSpeed = 0.5,
		TextureLength = 1,
		Segments = 10,
		LightEmission = 1,
		Brightness = 1,
		Base = 0.35,
		Middle = 0.6,
		PulsePeriod = 2,
		PulseAlpha = 0.08,
	},
	Rings = {
		Count = 3,
		RadiusScale = 1.04,
		Width = 0.15,
		Thickness = 0.04,
		Lighten = 0.25,
		Period = 2.5,
		Reach = 0.85,
		Transparency = 0.15,
		FadeIn = 0.2,
		FadeOut = 0.45,
		WobbleTilt = 2,
		WobbleSpeed = 1.6,
	},
	Floor = {
		RadiusScale = 1.04,
		Width = 0.2,
		Thickness = 0.04,
		Transparency = 0.25,
		PulseAlpha = 0.2,
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
		Colors = { Free = WHITE, Busy = RED, Starting = GREEN },
	},
	Camera = {
		MinZoom = 0.5,
		MaxZoom = 30,
		StartZoom = 12,
	},
}

return table.freeze(lobby)
