--!strict
-- Security cameras (FEAT-040, TASK-285; owner request 2026-10-14; PROVISIONAL). The CCTV monitor in the trailer opens a fixed
-- camera view; the player flips between the cameras and between the Normal and Night (night vision) looks. Read by
-- SecurityService (server: the prompt, the freeze) and SecurityController (client: camera, overlay, monitor screen).
--
-- Place contract (owner layout, Studio): `Workspace.<Folder>` holds one Model per camera (`Cams[i].Model`); the PIVOT of each
-- model is the exact eye and facing of the view (the owner stored his own camera CFrame in it), so moving or turning a camera
-- in Studio moves the view. The monitor is the Model `CCTV` in the same folder (its Part `Primary` carries the screen).
--
-- Anomaly hook (TASK-285): while watching, the LocalPlayer carries the attributes `SecurityView` = "" | "Normal" | "Night" and
-- `SecurityCam` = the Key of the camera ("" outside). Only the client reads them (AnomalyController, effects that show only, or
-- better, in night vision). Presentation only: no anomaly rule depends on them.
local Table = require(script.Parent.Table)

export type View = "Normal" | "Night"

export type Cam = {
	Key: string, -- SecurityCam attribute value
	Model: string, -- name of the Model inside the folder (its pivot = the view)
	Label: string, -- stamp on screen ("CAM 1")
	Fov: number, -- degrees
}

export type Look = {
	-- ColorCorrectionEffect (local, under Lighting)
	Tint: Color3,
	Brightness: number,
	Contrast: number,
	Saturation: number,
	-- overlay (0 = invisible, 1 = solid)
	Noise: number, -- grain opacity
	Scanlines: number,
	Vignette: number,
	Band: number, -- opacity of the rolling bright band, 0 = none (the "leve distorção"; the view itself is static, TASK-323)
	-- local infrared illuminator at the camera eye (a PointLight only this client sees): night vision lifts the dark street
	Illuminator: number, -- PointLight Brightness, 0 = none
	Range: number, -- studs (PointLight max 60)
}

export type Rules = {
	Folder: string, -- Workspace.<Folder>
	Monitor: string, -- Model of the CCTV monitor inside the folder
	Screen: string, -- Part of the monitor that carries the screen
	Face: Enum.NormalId, -- face of the Screen part shown to the player
	Anchor: string, -- name of the prompt Attachment made on the Screen (server)
	Action: string, -- Content.Actions key of the prompt
	AnchorOut: number, -- studs the anchor sits in front of the screen face
	Enter: number, -- s: the cut into the camera (0 = a cut; the static burst covers it)
	Switch: number, -- s of static burst on a camera or view switch
	Channel: number, -- s each channel shows on the idle monitor in the world
	Rec: number, -- s of one REC blink (on + off)
	DefaultView: View,
	ViewAttribute: string,
	CamAttribute: string,
	FreezeReason: string, -- CharacterService:Freeze reason (server)
}

export type Textures = {
	Noise: string, -- 256 px white grain, alpha = noise (Assets/textures/ui/security/sec_noise.png)
	Scanlines: string, -- 8 px tile, 3 dark rows (sec_scanlines.png)
	Vignette: string, -- 512 px black, alpha to the corners (sec_vignette.png)
}

export type Security = {
	Rules: Rules,
	Looks: { [View]: Look },
	Textures: Textures,
	Cams: Table.Table<Cam>,
}

const security: Security = {
	Rules = {
		Folder = "SecurityCams",
		Monitor = "CCTV",
		Screen = "Primary",
		Face = Enum.NormalId.Front,
		Anchor = "Prompt_Cameras",
		Action = "watch_cameras",
		AnchorOut = 0.6,
		Enter = 0,
		Switch = 0.35,
		Channel = 3.5,
		Rec = 1.2,
		DefaultView = "Night",
		ViewAttribute = "SecurityView",
		CamAttribute = "SecurityCam",
		FreezeReason = "Security",
	},
	Looks = {
		Normal = {
			Tint = Color3.fromRGB(235, 240, 235),
			Brightness = 0,
			Contrast = 0.05,
			Saturation = -0.35,
			Noise = 0.1,
			Scanlines = 0.08,
			Vignette = 0.35,
			Band = 0,
			Illuminator = 0,
			Range = 0,
		},
		Night = {
			Tint = Color3.fromRGB(120, 255, 140),
			Brightness = 0.18,
			Contrast = 0.35,
			Saturation = -1,
			Noise = 0.32,
			Scanlines = 0.22,
			Vignette = 0.75,
			Band = 0.08,
			Illuminator = 1.1,
			Range = 60,
		},
	},
	Textures = {
		Noise = "rbxassetid://102541930174273",
		Scanlines = "rbxassetid://116541509043121",
		Vignette = "rbxassetid://118506746509108",
	},
	Cams = Table.new({
		{ Key = "CAM1", Model = "CAM1", Label = "CAM 1", Fov = 70 },
		{ Key = "CAM2", Model = "CAM2", Label = "CAM 2", Fov = 70 },
	}),
}

return Table.record(security)
