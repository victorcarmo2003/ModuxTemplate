--[[
	lighting_edit_default.luau  (Studio Edit snippet, NOT gameplay code; owner request 2026-10-12: "a iluminacao do estudio
	parece estourada"). Idempotent. Run with Studio MCP execute_luau (Edit) or the command bar.

	Makes the SAVED Lighting of the place (properties + Atmosphere / Bloom / ColorCorrection / SunRays) equal to the Day
	look, so the Edit viewport, the thumbnail and the first frames before LightController runs match the game.
	LightController stays the only runtime writer of Lighting (no script is added by this snippet).

	Source of the numbers: Content.LightPresets.Day (src/Shared/Content/LightPresets.luau). Keep DAY below in sync with it.
	Pass 2 (2026-10-12, still blown out): Brightness 1.3, Exposure -0.5, EnvDiffuse 0.6, Bloom 0.22. Backup of the previous state: Folder ServerStorage.Lighting_Backup_<yyyymmdd> (attributes). UNDO = true restores it.
	Nothing else is touched (Sky, DepthOfField, VitalColor / VitalBlur are left alone).
]]
local UNDO = false

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local BACKUP = "Lighting_Backup_20261012b"

-- Day preset (PROVISIONAL, mirrors Content.LightPresets.Day) + Edit-only fields the preset has no key for
local DAY = {
	Brightness = 1.3,
	ExposureCompensation = -0.5, -- LightController writes it too (preset.Exposure)
	Ambient = Color3.fromRGB(86, 74, 64),
	OutdoorAmbient = Color3.fromRGB(110, 94, 80),
	ColorShift_Top = Color3.fromRGB(255, 226, 186),
	ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.6,
	ShadowSoftness = 0.25,
	ClockTime = 9.4, -- unchanged by the preset in Edit; game clock overrides it
}
local ATMOSPHERE = {
	Density = 0.35, Offset = 1, Glare = 1.2, Haze = 0.35,
	Color = Color3.fromRGB(214, 190, 168), Decay = Color3.fromRGB(232, 170, 118),
}
local CORRECTION = { Brightness = 0, Saturation = 0.1, Contrast = 0.1, TintColor = Color3.fromRGB(255, 244, 228) }
local BLOOM = { Intensity = 0.22, Size = 24, Threshold = 2 }
local RAYS = { Intensity = 0.03, Spread = 0.1 }

local function child(className: string): Instance
	for _, c in Lighting:GetChildren() do
		if c.ClassName == className and c.Name ~= "VitalColor" and c.Name ~= "VitalBlur" then
			return c
		end
	end
	local c = Instance.new(className :: any)
	c.Parent = Lighting
	return c
end

local function snapshot(inst: Instance, props: { [string]: any }, prefix: string, folder: Folder)
	for k in props do
		folder:SetAttribute(prefix .. k, (inst :: any)[k])
	end
end

local function restore(inst: Instance, props: { [string]: any }, prefix: string, folder: Folder)
	for k in props do
		local v = folder:GetAttribute(prefix .. k)
		if v ~= nil then
			(inst :: any)[k] = v
		end
	end
end

local sets = {
	{ Lighting, DAY, "L_" },
	{ child("Atmosphere"), ATMOSPHERE, "A_" },
	{ child("ColorCorrectionEffect"), CORRECTION, "C_" },
	{ child("BloomEffect"), BLOOM, "B_" },
	{ child("SunRaysEffect"), RAYS, "R_" },
}

local backup = ServerStorage:FindFirstChild(BACKUP)

if UNDO then
	if not backup then
		return "no backup " .. BACKUP
	end
	for _, s in sets do
		restore(s[1], s[2], s[3], backup :: Folder)
	end
	return "restored from " .. BACKUP
end

if not backup then
	local folder = Instance.new("Folder")
	folder.Name = BACKUP
	for _, s in sets do
		snapshot(s[1], s[2], s[3], folder)
	end
	folder.Parent = ServerStorage
end

for _, s in sets do
	for k, v in s[2] do
		(s[1] :: any)[k] = v
	end
end
return "Lighting set to Day default; backup " .. BACKUP
