--!strict
-- Lobby zones, ring VFX, platform squads and camera (user request 2026-10-11, Provisional; docs/levels/LOBBY.md §5,
-- §7; architecture.md §20.6; network.md §16). Pure data, read by PartyService (server, platform occupancy),
-- LobbyController (client: zone triggers, ring VFX, camera) and ReplicatedStorage.shared.Lobby.LobbyZones.
-- Owner: frontend-coder. Every number Provisional (DEC-044: adjusted in playtest).
--
-- A zone is a circle on the floor. Center = the MapPoint `PointId` when the map has it (WORLD), else `Center`.
-- Walking in (planar distance <= Radius, |dy| <= Trigger.Height) opens its panel; walking out (distance >
-- Radius + Trigger.Hysteresis) closes it. Squad zones (Platform 1..4) are the squad platforms: the server watches them.

export type Panel = "Classes" | "Shop" | "Codes" | "Platform"

export type Zone = {
	Key: string,
	Panel: Panel,
	Platform: number, -- 1..4 = squad platform n; 0 = not a platform
	PointId: string?, -- MapPoint that places the zone; nil = Center only
	Center: Vector3, -- WORLD, floor level (fallback of PointId)
	Radius: number, -- studs, planar
	Color: Color3, -- ring colour (platforms: Squad.Colors by state instead)
}

export type Rings = {
	Count: number, -- rings stacked per zone
	Points: number, -- attachments per ring (beams = Points, curved into a circle)
	RadiusScale: number, -- ring radius = zone Radius * this
	Height: number, -- studs a ring rises before it loops back to the floor
	Rise: number, -- studs/s
	Spin: number, -- deg/s (odd rings spin the other way)
	Width: number, -- beam width (studs)
	Segments: number, -- beam segments (curve smoothness)
	CurveSign: number, -- 1 or -1: flips the arc of each beam if the rings look like a star instead of a circle
	Texture: string,
	TextureSpeed: number,
	LightEmission: number,
	Brightness: number,
	Transparency: number, -- 0..1 at full strength (middle of the climb)
	FadeIn: number, -- 0..1 of the climb: fades in from the floor
	FadeOut: number, -- 0..1 of the climb: fades out before the top
	WobbleTilt: number, -- deg: sine tilt of each ring (the "clumsy" look)
	WobbleSpeed: number, -- rad/s of the tilt
	WobbleShift: number, -- studs: sine sideways drift of the ring centre
	ActiveDistance: number, -- studs from the camera: farther zones are hidden and not animated
}

export type Lobby = {
	Zones: { Zone },
	Trigger: {
		Hysteresis: number, -- studs added to the radius to count as "out"
		Height: number, -- studs: max |dy| between the root and the zone floor
		Poll: number, -- s between two client checks
	},
	Rings: Rings,
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

local function squad(n: number, z: number): Zone
	return {
		Key = `Squad{n}`,
		Panel = "Platform",
		Platform = n,
		PointId = `LOBBY-SQUAD-{n}`,
		Center = Vector3.new(20, 0.3, z),
		Radius = 4,
		Color = WHITE,
	}
end

const lobby: Lobby = {
	Zones = {
		-- in front of the stage rope (LW-STAGE blocks Z > -585): the class screen opens here
		{
			Key = "Classes",
			Panel = "Classes",
			Platform = 0,
			PointId = nil,
			Center = Vector3.new(0, 0, -587.5),
			Radius = 3.5,
			Color = YELLOW,
		},
		{
			Key = "Shop",
			Panel = "Shop",
			Platform = 0,
			PointId = "LOBBY-SHOP",
			Center = Vector3.new(-19.5, 0, -600),
			Radius = 3.5,
			Color = GREEN,
		},
		{
			Key = "Codes",
			Panel = "Codes",
			Platform = 0,
			PointId = "LOBBY-CODES",
			Center = Vector3.new(-10, 0, -622.5),
			Radius = 3.5,
			Color = BLUE,
		},
		squad(1, -588),
		squad(2, -598),
		squad(3, -608),
		squad(4, -618),
	},
	Trigger = {
		Hysteresis = 1.25,
		Height = 8,
		Poll = 0.1,
	},
	Rings = {
		Count = 4,
		Points = 8,
		RadiusScale = 1,
		Height = 4.5,
		Rise = 1.1,
		Spin = 40,
		Width = 0.45,
		Segments = 10,
		CurveSign = 1,
		Texture = "rbxassetid://16892386886", -- the user's reference beam (workspace.BeamExample)
		TextureSpeed = 0.4,
		LightEmission = 1,
		Brightness = 2,
		Transparency = 0.15,
		FadeIn = 0.2,
		FadeOut = 0.35,
		WobbleTilt = 7,
		WobbleSpeed = 2.4,
		WobbleShift = 0.15,
		ActiveDistance = 80,
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
