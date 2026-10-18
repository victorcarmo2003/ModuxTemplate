--[[
	restaurant_mood_pass.luau — owner 2026-10-18 ("essa parte do mapa tá muito clara, vamos escurecer ela; a parte interna da
	cozinha também tá muito suave, precisamos de algo mais aterrorizante; limpar um pouco a frente do cachorro quente para
	ficar mais deserto"). Edit-mode Studio snippet, NOT gameplay code. Command Bar or Studio MCP, MODE below.

	  apply   patio lamps / gate / umbrella bulbs and the kitchen lights dimmer and colder (sickly kitchen white), every
	          touched property stored ONCE in an MP_<Property> attribute (running it twice does not darken twice); the
	          cheerful front props (A-frame, potted plant, hydrant, string lights) moved to ServerStorage.MoodPassRetired with
	          attribute MP_From = their old parent's full name
	  revert  every MP_* property back; the retired props back to their parent
	  diff    reports what apply would change (writes nothing)
	The street fog is the night preset (Content.LightPresets Night1/Night10 Atm*), not this snippet.
]]
local MODE = "apply" -- "apply" | "revert" | "diff"

local RETIRED = "MoodPassRetired"
local PATIO = { MinX = -80, MaxX = -12, MinZ = 12, MaxZ = 50 }
local KITCHEN = { MinX = -62, MaxX = -24, MinZ = -12, MaxZ = 12 }

-- name -> { Brightness factor, Range factor, Color (or nil) }
local PATIO_LIGHTS = {
	Light_Lamp = { 0.35, 0.75, Color3.fromRGB(196, 210, 255) }, -- the five patio lamps (were 2.0 / 18)
	["LIT-GATE"] = { 0.5, 0.85, nil },
	Bulb = { 0.45, 0.8, nil },
	Flame = { 0.6, 0.85, nil },
}
local KITCHEN_LIGHTS = {
	Light_K1 = { 0.6, 0.85, Color3.fromRGB(214, 228, 222) }, -- cold, sickly fluorescent
	Light_K3 = { 0.6, 0.85, Color3.fromRGB(214, 228, 222) },
	Light_P = { 0.6, 0.9, Color3.fromRGB(206, 214, 230) },
	Light_P2 = { 0.6, 0.9, Color3.fromRGB(206, 214, 230) },
	Lens = { 0.7, 0.9, nil },
}
local PROPS = {
	"MAP01_Assets.StreetSigns.AFrame_CornerDogs",
	"MAP01_Assets.Extra.AST-102_PottedPlant",
	"MAP01_Assets.Extra.Z-08_AST-034_Hydrant",
	"MAP01_Restaurant.TRL.Front.TrailerDeco.TRL-LIGHTS_AST-023_TrailerLights",
}

local changes = 0
local function log(s)
	print("[MoodPass] " .. s)
end

local function inside(p, box)
	return p.X >= box.MinX and p.X <= box.MaxX and p.Z >= box.MinZ and p.Z <= box.MaxZ
end

local function orig(inst, prop)
	local key = "MP_" .. prop
	local v = inst:GetAttribute(key)
	if v == nil then
		v = inst[prop]
		if MODE == "apply" then
			inst:SetAttribute(key, v)
		end
	end
	return v
end

local function set(inst, prop, value)
	local cur = inst[prop]
	if typeof(cur) == "number" and math.abs(cur - value) < 1e-4 then
		return
	end
	if cur == value then
		return
	end
	changes += 1
	if MODE == "diff" then
		log(("[diff] %s.%s %s -> %s"):format(inst:GetFullName(), prop, tostring(cur), tostring(value)))
	else
		inst[prop] = value
	end
end

local function find(path)
	local node = workspace
	for name in path:gmatch("[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local storage = game:GetService("ServerStorage")

if MODE == "revert" then
	for _, root in { workspace:FindFirstChild("MAP01_Restaurant"), workspace:FindFirstChild("MAP01_Assets") } do
		if root then
			for _, inst in root:GetDescendants() do
				for key, v in inst:GetAttributes() do
					if key:sub(1, 3) == "MP_" and key ~= "MP_From" then
						inst[key:sub(4)] = v
						inst:SetAttribute(key, nil)
						changes += 1
					end
				end
			end
		end
	end
	local retired = storage:FindFirstChild(RETIRED)
	if retired then
		for _, item in retired:GetChildren() do
			local from = item:GetAttribute("MP_From")
			local parent = from and find((from:gsub("^Workspace%.", "")))
			if parent then
				item.Parent = parent
				item:SetAttribute("MP_From", nil)
				changes += 1
			end
		end
	end
	log("reverted " .. changes)
	return
end

-- lights
for _, root in { workspace:FindFirstChild("MAP01_Restaurant"), workspace:FindFirstChild("MAP01_Assets") } do
	if root then
		for _, l in root:GetDescendants() do
			if l:IsA("Light") and l.Parent and l.Parent:IsA("BasePart") then
				local p = l.Parent.Position
				local row = (inside(p, PATIO) and PATIO_LIGHTS[l.Parent.Name]) or (inside(p, KITCHEN) and KITCHEN_LIGHTS[l.Parent.Name])
				if row then
					set(l, "Brightness", orig(l, "Brightness") * row[1])
					set(l, "Range", orig(l, "Range") * row[2])
					if row[3] then
						orig(l, "Color")
						set(l, "Color", row[3])
					end
				end
			end
		end
	end
end

-- front props
local retired = storage:FindFirstChild(RETIRED)
for _, path in PROPS do
	local item = find(path)
	if item then
		changes += 1
		if MODE == "diff" then
			log("[diff] retire " .. item:GetFullName())
		else
			if not retired then
				retired = Instance.new("Folder")
				retired.Name = RETIRED
				retired.Parent = storage
			end
			item:SetAttribute("MP_From", item.Parent:GetFullName())
			item.Parent = retired
		end
	end
end

log(MODE .. ": " .. changes .. " change(s)")
