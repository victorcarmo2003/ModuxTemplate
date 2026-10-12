--!nonstrict
--[[
	trailer_side_neon.luau (owner request 2026-10-12: a neon OPEN / CLOSED tube sign on the RIGHT side of the trailer, where the
	owner drew "OPEN" over the screenshot; Provisional). Edit-mode Studio snippet, NOT gameplay code. Idempotent (the folder
	TRL-SIDENEON is rebuilt on every run), NO Place.run, nothing outside the folder is touched, NO new light (flat neon material
	only; local light budget stays 17/18). Undo: run("trailer_side_neon", "undo") destroys the folder.

	The glyph font, tube and joint builders are the ones of decor_mart.luau (neonText); only the letters O P E N C L S D are
	copied. Two signs on the east flank (the wall facing +X; the window faces +Z, so "right" when facing the window):
	  Neon_ShopOpen   "OPEN"   green (70, 255, 120)   ShopState = "Open"
	  Neon_ShopClosed "CLOSED" neon red (255, 50, 70) ShopState = "Closed"
	Both Models carry the tags NeonSign (Flicker = true: NeonController flickers a lit one now and then) and ShopNeon
	(OpenSignController lights the one that matches the shop state and puts the other out: SmoothPlastic, colour x 0.2, and
	NeonOverride = true so the flicker does not light it). Initial state saved in the place: shop closed (CLOSED lit).
	The folder lives inside the trailer Model, so it follows the trailer (PivotTo / the height of trailer_ground).
	Wall plane X is read by a raycast on Body from +X at the sign heights; the tubes stand 0.35 off it.
]]

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local UNDO = (...) == "undo"

local FOLDER = "TRL-SIDENEON"
local GREEN = Color3.fromRGB(70, 255, 120)
local RED = Color3.fromRGB(255, 50, 70)
local OUT_DARKEN = 0.8 -- same as OpenSignController
local OFF_WALL = 0.35 -- studs from the wall to the tube centre line
-- world heights with the trailer on the ground (trailer_ground): the flank above the orange stripe
local ROWS = {
	{ name = "Neon_ShopOpen", text = "OPEN", state = "Open", color = GREEN, centreY = 7.9, height = 1.9 },
	{ name = "Neon_ShopClosed", text = "CLOSED", state = "Closed", color = RED, centreY = 5.8, height = 1.5 },
}

-- Stroke font on a 2 x 3 grid (y up), the letters this snippet needs (decor_mart.luau GLYPHS)
local GLYPHS = {
	C = { { 2, 2.6, 1.5, 3, 0.5, 3, 0, 2.4, 0, 0.6, 0.5, 0, 1.5, 0, 2, 0.4 } },
	D = { { 0, 0, 0, 3, 1.2, 3, 2, 2.2, 2, 0.8, 1.2, 0, 0, 0 } },
	E = { { 2, 3, 0, 3, 0, 0, 2, 0 }, { 0, 1.5, 1.4, 1.5 } },
	L = { { 0, 3, 0, 0, 2, 0 } },
	N = { { 0, 0, 0, 3, 2, 0, 2, 3 } },
	O = { { 0.5, 0, 0, 0.6, 0, 2.4, 0.5, 3, 1.5, 3, 2, 2.4, 2, 0.6, 1.5, 0, 0.5, 0 } },
	P = { { 0, 0, 0, 3, 1.5, 3, 2, 2.5, 2, 2, 1.5, 1.5, 0, 1.5 } },
	S = { { 2, 2.6, 1.5, 3, 0.5, 3, 0, 2.5, 0, 2, 0.5, 1.5, 1.5, 1.5, 2, 1, 2, 0.5, 1.5, 0, 0.5, 0, 0, 0.4 } },
}
local ADVANCE = 2.7

local function tube(model, a, b, d, color)
	local len = (b - a).Magnitude
	if len < 1e-3 then
		return
	end
	local p = Instance.new("Part")
	p.Name = "Tube"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(len, d, d)
	p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = model
end
local function joint(model, at, d, color)
	local p = Instance.new("Part")
	p.Name = "Joint"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(d, d, d)
	p.CFrame = CFrame.new(at)
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = model
end

-- Neon text centred on `cf`, readable from the cf.LookVector side (decor_mart.luau neonText, horizontal only)
local function neonText(parent, name, text, cf, height, color)
	local model = Instance.new("Model")
	model.Name = name
	local k = height / 3
	local d = math.max(0.12, height * 0.09)
	local n = #text
	local width = (n * ADVANCE - (ADVANCE - 2)) * k
	for i = 1, n do
		local strokes = GLYPHS[string.upper(string.sub(text, i, i))]
		if strokes then
			local u0, v0 = -width / 2 + (i - 1) * ADVANCE * k, -height / 2
			local function at(u, v)
				return (cf * CFrame.new(-(u0 + u * k), v0 + v * k, 0)).Position
			end
			for _, s in strokes do
				local prev = nil
				for j = 1, #s, 2 do
					local q = at(s[j], s[j + 1])
					if prev then
						tube(model, prev, q, d, color)
					end
					if j > 1 and j < #s - 1 then
						joint(model, q, d, color)
					end
					prev = q
				end
				joint(model, at(s[1], s[2]), d, color)
				joint(model, at(s[#s - 1], s[#s]), d, color)
			end
		end
	end
	model:SetAttribute("Color", color)
	model.Parent = parent
	return model
end

local trailer
for _, m in CS:GetTagged("Vehicle") do
	if m:IsDescendantOf(workspace) and m:GetAttribute("Vehicle") == "trailer" then
		trailer = m
	end
end
if not trailer then
	return "[err] no trailer Model in the Workspace"
end
local old = trailer:FindFirstChild(FOLDER)
if old then
	old:Destroy()
end
if UNDO then
	return "TRL-SIDENEON removed"
end
pcall(function()
	CHS:SetWaypoint("trailer_side_neon: before")
end)

local body = trailer:FindFirstChild("Body")
local zc = trailer:GetPivot().Position.Z
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { body }
local folder = Instance.new("Folder")
folder.Name = FOLDER
local log = {}
for _, row in ROWS do
	-- the east wall (+X) at this height, in the middle of the flank
	local origin = Vector3.new(trailer:GetPivot().Position.X + 40, row.centreY, zc)
	local hit = workspace:Raycast(origin, Vector3.new(-80, 0, 0), params)
	if not hit then
		return "[err] no wall hit at y " .. row.centreY
	end
	local x = hit.Position.X + OFF_WALL
	local pos = Vector3.new(x, row.centreY, zc)
	local cf = CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
	local model = neonText(folder, row.name, row.text, cf, row.height, row.color)
	model:SetAttribute("ShopState", row.state)
	model:SetAttribute("Flicker", true)
	CS:AddTag(model, "NeonSign")
	CS:AddTag(model, "ShopNeon")
	-- saved state: the shop is closed (Prep) -> OPEN out, CLOSED lit; OpenSignController keeps it right at run time
	if row.state == "Open" then
		model:SetAttribute("NeonOverride", true)
		for _, part in model:GetChildren() do
			part.Material = Enum.Material.SmoothPlastic
			part.Color = row.color:Lerp(Color3.new(0, 0, 0), OUT_DARKEN)
		end
	end
	table.insert(log, string.format("%s: x %.2f, y %.2f, z %.2f, %d tubes/joints", row.name, x, row.centreY, zc, #model:GetChildren()))
end
folder.Parent = trailer
pcall(function()
	CHS:SetWaypoint("trailer_side_neon: after")
end)
return table.concat(log, "\n")
