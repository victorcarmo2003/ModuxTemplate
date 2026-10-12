--!nonstrict
--[[
	warm_lobby.luau (owner request 2026-10-12: "the lobby is too cold"; docs/levels/LOBBY.md V2-10, style-guide §5.1;
	Q-208, PROVISIONAL). Edit-mode snippet for Studio, NOT gameplay code. Paste in the command bar / run by hand.
	The Place.run is NOT used (the user hand-edits the place): this only touches Lights, a few new anchors and (optionally)
	the Color of cold props under workspace.LOBBY_Assets. Idempotent: run it as many times as you like.

	  1. Existing lights (the 14 of V2-10, found by the nearest anchor to the placed position): warmer colour, more
	     Brightness / Range where the lobby was dark. The two teal accents (L-RIM, L-FOUNTAIN) keep their hue
	     (contrast with the neon), only a little brighter.
	  2. 3 new warm lights, named WarmLobby_* (budget: 14 + 3 = 17 <= 18; none with shadows):
	       WarmLobby_Spawn   pool of light on the spawn medallion (5, -620)
	       WarmLobby_Plaza   under the string-light mast ring (5, -628.5) -> bulbs of the tent glow on the floor
	       WarmLobby_Squads  over the squad platforms (25, -620), between the two rows
	  3. Cold props (blue-dominant or ice-white Parts, only Part/MeshPart WITHOUT texture) lerp toward cream. The original
	     colour is kept in the attribute WarmOrig, so a re-run starts from it (and `UNDO = true` restores it).
	     Never touched: Neon material, transparent, zone rings / pads / chevrons / gems / water / signs (semantic colours).

	Needs LOBBY_Assets (placements + Decor.runLobby already done). Returns a log string; read the report in the output.
]]

local UNDO = false -- true: restores the original Color of the warmed props and the original of the lights
local WARM_PROPS = true -- false: only lights

local lobby = workspace:FindFirstChild("LOBBY_Assets")
if not lobby then
	return "[err] no workspace.LOBBY_Assets"
end

local SODIUM = Color3.fromHex("FFB25A")
local WARM = Color3.fromHex("FFD9A0")
local CREAM_LIGHT = Color3.fromHex("FFE7C2")
local log: { string } = {}

-- id, expected world position, light class, target colour (nil = keep hue), brightness, range, angle (spot, nil = keep)
local PLAN = {
	{ "L-KEY", Vector3.new(-9.2, 8.0, -578.6), "SpotLight", CREAM_LIGHT, 4.5, 20, nil },
	{ "L-FILL", Vector3.new(9.2, 6.6, -578.6), "SpotLight", WARM, 2.2, 18, nil },
	{ "L-RIM", Vector3.new(0, 6.8, -572.0), "SpotLight", nil, 1.5, 9, nil }, -- teal accent kept
	{ "L-HQ", Vector3.new(0, 10.5, -567.5), "PointLight", Color3.fromRGB(255, 200, 120), 2.0, 26, nil },
	{ "L-SHOP", Vector3.new(-36.5, 8.0, -620), "PointLight", WARM, 1.9, 22, nil },
	{ "L-CODES", Vector3.new(-10, 7.0, -653.6), "SpotLight", WARM, 2.2, 12, nil },
	{ "L-TRUCK", Vector3.new(-36, 7.0, -579.0), "PointLight", WARM, 1.9, 22, nil },
	{ "L-FOUNTAIN", Vector3.new(-34, 2.0, -654), "PointLight", nil, 1.3, 14, nil }, -- teal accent kept
}
local LAMP_IDS = { "LB-SL-A", "LB-SL-B", "LB-SL-C", "LB-SL-F", "LB-SL-G", "LB-SL-H" }

local function lightOf(anchor: Instance, class: string): Light?
	for _, c in anchor:GetChildren() do
		if c:IsA(class) then
			return c :: any
		end
	end
	return nil
end

local function remember(l: Light)
	if l:GetAttribute("WarmOrigBrightness") == nil then
		l:SetAttribute("WarmOrigBrightness", l.Brightness)
		l:SetAttribute("WarmOrigRange", l.Range)
		l:SetAttribute("WarmOrigColor", l.Color)
	end
end

local function restore(l: Light)
	if l:GetAttribute("WarmOrigBrightness") ~= nil then
		l.Brightness = l:GetAttribute("WarmOrigBrightness")
		l.Range = l:GetAttribute("WarmOrigRange")
		l.Color = l:GetAttribute("WarmOrigColor")
	end
end

-- nearest anchor (a Part holding a light of `class`) to `pos`, within 3 studs
local function nearest(pos: Vector3, class: string): Light?
	local best: Light?, bestD = nil, 3
	for _, d in lobby:GetDescendants() do
		if d:IsA(class) and d.Parent and d.Parent:IsA("BasePart") and not string.find(d.Name, "WarmLobby", 1, true) then
			local dist = (d.Parent.Position - pos).Magnitude
			if dist < bestD then
				best, bestD = d :: any, dist
			end
		end
	end
	return best
end

-- 1. existing lights
local changed = 0
for _, row in PLAN do
	local id, pos, class, color, brightness, range = row[1], row[2], row[3], row[4], row[5], row[6]
	local l = nearest(pos, class)
	if not l then
		table.insert(log, "[warn] " .. id .. " not found near " .. tostring(pos))
		continue
	end
	if UNDO then
		restore(l)
	else
		remember(l)
		if color then
			l.Color = color
		end
		l.Brightness = brightness
		l.Range = range
	end
	changed += 1
end
-- lamp heads: SpotLight "Light_<MapId>" anchors made by Decor.runLobby
local lampN = 0
for _, id in LAMP_IDS do
	for _, d in lobby:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Light_" .. id then
			local s = lightOf(d, "SpotLight")
			if s then
				if UNDO then
					restore(s)
				else
					remember(s)
					s.Color = SODIUM
					s.Brightness = 2.2
					s.Range = 26
					s.Angle = 110
				end
				lampN += 1
			end
		end
	end
end
table.insert(log, ("lights adjusted: %d/8 + lamps %d/6"):format(changed, lampN))

-- 2. new warm lights (idempotent by name; UNDO removes them)
local procedural = lobby:FindFirstChild("LobbyProcedural") or lobby
local NEW = {
	{ "WarmLobby_Spawn", Vector3.new(5, 7.5, -620), "Point", SODIUM, 1.6, 22 },
	{ "WarmLobby_Plaza", Vector3.new(5, 14.5, -628.5), "Point", WARM, 1.4, 26 },
	{ "WarmLobby_Squads", Vector3.new(25, 8.5, -620), "Point", WARM, 1.5, 28 },
}
for _, row in NEW do
	local name = row[1]
	local old = procedural:FindFirstChild(name)
	if UNDO then
		if old then
			old:Destroy()
		end
		continue
	end
	local anchor = old
	if not anchor then
		anchor = Instance.new("Part")
		anchor.Name = name
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Parent = procedural
	end
	anchor.Position = row[2]
	local pl = anchor:FindFirstChildOfClass("PointLight")
	if not pl then
		pl = Instance.new("PointLight")
		pl.Parent = anchor
	end
	pl.Color = row[4]
	pl.Brightness = row[5]
	pl.Range = row[6]
	pl.Shadows = false
end

-- slow flicker (existing NeonController attribute): only the HQ sign and one mast topper, never zone neons
local flick = 0
for _, d in lobby:GetDescendants() do
	if (d.Name == "Neon_HQ" or d.Name == "Mast_Topper") and d:GetAttribute("Flicker") ~= nil then
		if d.Name == "Neon_HQ" or flick == 0 then
			d:SetAttribute("Flicker", not UNDO)
			flick += 1
		end
	end
end
table.insert(log, "flicker set on " .. flick)

-- count every local light of the lobby (budget: target 14, max 18)
local total = 0
for _, d in lobby:GetDescendants() do
	if d:IsA("Light") and d.Enabled then
		total += 1
	end
end
table.insert(log, ("local lights in LOBBY_Assets: %d (budget max 18)"):format(total))

-- 3. cold props
if WARM_PROPS then
	local SKIP_NAMES = { "Neon", "Rim", "Ring", "Edge", "Chevron", "Gem", "Squad", "Medallion", "Water", "Jet", "Bulb", "Wire", "Sign", "Label", "Route", "Flash", "Fountain_Icon", "Mast_Topper" }
	local cream = Color3.fromRGB(255, 226, 190)
	local count, list = 0, {}
	for _, d in lobby:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		if UNDO then
			local o = d:GetAttribute("WarmOrig")
			if typeof(o) == "Color3" then
				d.Color = o
				d:SetAttribute("WarmOrig", nil)
				count += 1
			end
			continue
		end
		if d.Material == Enum.Material.Neon or d.Transparency >= 0.5 or d:FindFirstChildOfClass("SurfaceAppearance") then
			continue
		end
		if d:IsA("MeshPart") and d.TextureID ~= "" then
			continue
		end
		local skip = false
		local node: Instance? = d
		while node and node ~= lobby do
			for _, key in SKIP_NAMES do
				if string.find(node.Name, key, 1, true) then
					skip = true
				end
			end
			if node:GetAttribute("Color") ~= nil or game:GetService("CollectionService"):HasTag(node, "NeonSign") then
				skip = true
			end
			node = node.Parent
		end
		if skip then
			continue
		end
		local orig = d:GetAttribute("WarmOrig")
		local c: Color3 = if typeof(orig) == "Color3" then orig else d.Color
		local r, g, b = c.R * 255, c.G * 255, c.B * 255
		local mx, mn = math.max(r, g, b), math.min(r, g, b)
		local sat = if mx > 0 then (mx - mn) / mx else 0
		local amount = 0
		if b > r + 8 and sat > 0.08 then
			amount = 0.4 -- blue-dominant: the coldest
		elseif mn > 215 and b >= r - 2 then
			amount = 0.3 -- ice white
		elseif sat < 0.07 and mx > 70 and mx < 215 then
			amount = 0.18 -- neutral grey
		end
		if amount > 0 then
			if typeof(orig) ~= "Color3" then
				d:SetAttribute("WarmOrig", c)
			end
			d.Color = c:Lerp(cream, amount)
			count += 1
			if #list < 25 then
				table.insert(list, ("%s (%d,%d,%d) x%.2f"):format((string.gsub(d:GetFullName(), "^Workspace%.LOBBY_Assets%.", "")), r, g, b, amount))
			end
		elseif typeof(orig) == "Color3" then
			d.Color = orig -- no longer cold under the current rules: back to the original
			d:SetAttribute("WarmOrig", nil)
		end
	end
	table.insert(log, ("props %s: %d"):format(if UNDO then "restored" else "warmed", count))
	for _, l in list do
		table.insert(log, "  " .. l)
	end
end

return table.concat(log, "\n")
