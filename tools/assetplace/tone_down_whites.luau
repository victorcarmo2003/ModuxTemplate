--[[
	tone_down_whites.luau  (Studio Edit snippet, NOT gameplay code; owner request 2026-10-12: lighting "estourado").
	Idempotent. Run with Studio MCP execute_luau (Edit).

	Darkens slightly (x0.85, warm bias) the Parts/MeshParts whose Color3 is almost white (min channel >= 205) and that are
	large (longest side > 6 studs). Never touched: Neon / Glass / ForceField, Transparency >= 0.5, UI / signs / water /
	zone rings / gradients (name, ancestor or child hints below), textures and SurfaceAppearance (only Color3 changes).
	Each touched part keeps its original colour in the attribute ToneDownOrig (Color3); a part with that attribute is skipped
	on a second run, so running twice does nothing more. UNDO = true restores ToneDownOrig and clears it. DRY = true only reports.
]]
local DRY = false
local UNDO = false

local MIN_CHANNEL = 205 / 255
local MIN_SIZE = 6
local FACTOR = Color3.new(0.85, 0.85 * 0.97, 0.85 * 0.92) -- x0.85 with a warm bias
local ATTR = "ToneDownOrig"
local SKIP_NAME = { "neon", "sign", "letter", "ring", "zone", "water", "pool", "gradient", "light", "lamp", "bulb", "glow", "stripe", "crosswalk", "marking", "line", "stall", "pad", "medallion", "truck", "policecar" }

local function skipByName(inst: Instance): boolean
	local n = string.lower(inst.Name)
	for _, w in SKIP_NAME do
		if string.find(n, w, 1, true) then
			return true
		end
	end
	return false
end

local function excluded(p: BasePart): boolean
	if p.Material == Enum.Material.Neon or p.Material == Enum.Material.Glass or p.Material == Enum.Material.ForceField or p.Material == Enum.Material.Water then
		return true
	end
	if p.Transparency >= 0.5 or p.Size.Magnitude == 0 then
		return true
	end
	if p:FindFirstChildWhichIsA("UIGradient") or p:FindFirstChildWhichIsA("SurfaceGui") or p:FindFirstChildWhichIsA("Decal") or p:FindFirstChildWhichIsA("Texture") or p:FindFirstChildWhichIsA("SurfaceAppearance") then
		return true
	end
	local a: Instance? = p
	while a and a ~= workspace do
		if skipByName(a) or a:FindFirstAncestorWhichIsA("ScreenGui") then
			return true
		end
		a = a.Parent
	end
	return false
end

local out, changed, restored, skipped = {}, 0, 0, 0
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and not d:IsA("Terrain") then
		local orig = d:GetAttribute(ATTR)
		if UNDO then
			if typeof(orig) == "Color3" then
				d.Color = orig
				d:SetAttribute(ATTR, nil)
				restored += 1
			end
		elseif orig == nil then
			local c = d.Color
			local s = d.Size
			if math.min(c.R, c.G, c.B) >= MIN_CHANNEL and math.max(s.X, s.Y, s.Z) > MIN_SIZE then
				if excluded(d) then
					skipped += 1
				else
					changed += 1
					if #out < 60 then
						out[#out + 1] = d:GetFullName()
					end
					if not DRY then
						d:SetAttribute(ATTR, c)
						d.Color = Color3.new(c.R * FACTOR.R, c.G * FACTOR.G, c.B * FACTOR.B)
					end
				end
			end
		end
	end
end
return string.format("%s changed=%d restored=%d excluded=%d\n%s", if DRY then "DRY" else "OK", changed, restored, skipped, table.concat(out, "\n"))
