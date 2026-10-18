--[[
	lobby_light_pass.luau — TASK-449 (DEC-289 L2, L3, L4; art/direcao-ambiente-lobby-mapa.md §3). Edit-mode Studio snippet,
	NOT gameplay code. Paste into the Command Bar (or run through the Studio MCP) with MODE set below.

	  apply   floor neon -> solid colour; floor tiles and cobble paths darker; plaza/spawn warm lights at 40 %;
	          ~1 in 3 building windows lit, building lights off; 3 warm key lights on the focal points
	          (HQ cart, Gem Shop, food court) in LOBBY_Assets.Lighting.FocusKeys
	  revert  every touched property back to the value stored in its LP_* attribute; FocusKeys removed
	  diff    reports what apply would change (writes nothing)

	Idempotent: the authored value of each property is stored ONCE in an attribute (LP_<Property>) the first time apply
	touches it, and apply always computes from that stored value (running it twice does not darken twice). The zone
	outlines that pulse at runtime are LobbyController's (TASK-450), not map parts. Light budget (style guide §5.1):
	-35 building lights, +3 keys.
]]
local MODE = "apply" -- "apply" | "revert" | "diff"

local lobby = workspace:FindFirstChild("LOBBY_Assets")
assert(lobby, "LOBBY_Assets not found")

local FLOOR_FACTOR = Color3.new(0.62, 0.6, 0.68) -- per channel, tiles and cobble (cold-ish dark, mockup 2026-10-18)
local PLAZA_LIGHT_FACTOR = 0.4
local WINDOW_OFF_COLOR = Color3.fromRGB(28, 30, 44)
local KEEP_EVERY = 3 -- 1 window in KEEP_EVERY stays lit
local PLAZA_CENTER = Vector3.new(3, 0, -615) -- spawn medallion (LOBBY.md V2-4)
local PLAZA_RADIUS = 22 -- studs, planar: only the fill lights over the spawn / plaza centre (every street head is
-- named Light_LB-SL-A, so the name alone would dim the whole lobby)

local changes = 0
local function log(s)
	print("[LobbyLightPass] " .. s)
end

-- authored value without storing it (stored one if any, else the current one)
local function peek(inst, prop)
	local v = inst:GetAttribute("LP_" .. prop)
	if v == nil then
		v = inst[prop]
		if typeof(v) == "EnumItem" then
			v = v.Name
		end
	end
	return v
end

-- stored authored value (first touch wins); call only on what is about to change
local function orig(inst, prop)
	local key = "LP_" .. prop
	local v = inst:GetAttribute(key)
	if v == nil then
		v = inst[prop]
		if typeof(v) == "EnumItem" then
			v = v.Name
		end
		if MODE == "apply" then
			inst:SetAttribute(key, v)
		end
	end
	return v
end

local function set(inst, prop, value)
	local cur = inst[prop]
	local same = cur == value
	if typeof(cur) == "number" and typeof(value) == "number" then
		same = math.abs(cur - value) < 1e-4
	elseif typeof(cur) == "Color3" and typeof(value) == "Color3" then
		same = math.abs(cur.R - value.R) + math.abs(cur.G - value.G) + math.abs(cur.B - value.B) < 1e-3
	end
	if same then
		return
	end
	changes += 1
	if MODE == "diff" then
		log(("[diff] %s.%s %s -> %s"):format(inst:GetFullName(), prop, tostring(cur), tostring(value)))
	else
		inst[prop] = value
	end
end

local function mul(c, f)
	return Color3.new(c.R * f.R, c.G * f.G, c.B * f.B)
end

if MODE == "revert" then
	for _, inst in lobby:GetDescendants() do
		for key, v in inst:GetAttributes() do
			if key:sub(1, 3) == "LP_" then
				local prop = key:sub(4)
				if prop == "Material" then
					inst.Material = Enum.Material[v]
				else
					inst[prop] = v
				end
				inst:SetAttribute(key, nil)
				changes += 1
			end
		end
	end
	local keys = lobby:FindFirstChild("Lighting") and lobby.Lighting:FindFirstChild("FocusKeys")
	if keys then
		keys:Destroy()
	end
	log("reverted " .. changes .. " properties")
	return
end

-- L2a. floor neon (arrows, apron outlines, spawn ring) -> solid
for _, p in lobby:GetDescendants() do
	if p:IsA("BasePart") then
		-- thinnest side, not Size.Y: the spawn ring is a Cylinder lying on its X axis (Size 0.13 x 10.9 x 10.9)
		if peek(p, "Material") == "Neon" and p.Position.Y < 1.2 and math.min(p.Size.X, p.Size.Y, p.Size.Z) < 1 then
			orig(p, "Material")
			set(p, "Material", Enum.Material.SmoothPlastic)
		end
	end
end

-- L2b. floor tiles and cobble paths darker
local floor = lobby:FindFirstChild("Plaza") and lobby.Plaza:FindFirstChild("LobbyFloor")
if floor then
	for _, p in floor:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 0.8 then
			set(p, "Color", mul(orig(p, "Color"), FLOOR_FACTOR))
		end
	end
end
for _, p in lobby:GetDescendants() do
	if p:IsA("BasePart") and peek(p, "Material") == "Cobblestone" and p.Position.Y < 1.2 then
		set(p, "Color", mul(orig(p, "Color"), FLOOR_FACTOR))
	end
end

-- L2c. plaza / spawn warm fill at 40 %
for _, l in lobby:GetDescendants() do
	if l:IsA("Light") and l.Parent and l.Parent:IsA("BasePart")
		and (l.Parent.Position * Vector3.new(1, 0, 1) - PLAZA_CENTER).Magnitude < PLAZA_RADIUS then
		set(l, "Brightness", orig(l, "Brightness") * PLAZA_LIGHT_FACTOR)
	end
end

-- L3. building windows: 1 in KEEP_EVERY stays lit (stable order by full name), building lights off
local buildings = lobby:FindFirstChild("Buildings")
if buildings then
	local windows = {}
	for _, p in buildings:GetDescendants() do
		if p:IsA("BasePart") and peek(p, "Material") == "Neon" then
			table.insert(windows, p)
		end
	end
	table.sort(windows, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	for i, p in windows do
		if i % KEEP_EVERY ~= 0 then
			orig(p, "Material")
			orig(p, "Color")
			set(p, "Material", Enum.Material.SmoothPlastic)
			set(p, "Color", WINDOW_OFF_COLOR)
		end
	end
	for _, l in buildings:GetDescendants() do
		if l:IsA("Light") then
			orig(l, "Enabled")
			set(l, "Enabled", false)
		end
	end
end

-- L4. warm keys on the 3 focal points
local function key(folder, name, pos, kind, target, color, brightness, range, angle)
	local holder = folder:FindFirstChild(name)
	if not holder then
		if MODE == "diff" then
			changes += 1
			log("[diff] would add key light " .. name)
			return
		end
		holder = Instance.new("Part")
		holder.Name = name
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.CastShadow = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.4, 0.4, 0.4)
		holder.Parent = folder
		changes += 1
	elseif MODE == "diff" then
		return
	end
	holder.CFrame = target and CFrame.lookAt(pos, target) or CFrame.new(pos)
	local l = holder:FindFirstChildOfClass(kind) or Instance.new(kind)
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	if kind == "SpotLight" then
		l.Face = Enum.NormalId.Front
		l.Angle = angle
	end
	l.Parent = holder
end
local lightingFolder = lobby:FindFirstChild("Lighting")
if lightingFolder then
	local keys = lightingFolder:FindFirstChild("FocusKeys")
	if not keys and MODE == "apply" then
		keys = Instance.new("Folder")
		keys.Name = "FocusKeys"
		keys.Parent = lightingFolder
	end
	if keys or MODE == "diff" then
		local f = keys or Instance.new("Folder")
		key(f, "Key_HQ", Vector3.new(0, 11, -582), "SpotLight", Vector3.new(0, 3, -569), Color3.fromRGB(255, 200, 140), 4, 26, 50)
		key(f, "Key_Shop", Vector3.new(-33, 7, -620), "PointLight", nil, Color3.fromRGB(255, 225, 170), 2.2, 14)
		key(f, "Key_Food", Vector3.new(-36, 8, -580), "PointLight", nil, Color3.fromRGB(255, 190, 120), 1.6, 14)
	end
end

log(MODE .. ": " .. changes .. " change(s)")
