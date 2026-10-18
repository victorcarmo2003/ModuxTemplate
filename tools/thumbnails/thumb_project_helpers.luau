--!nocheck
-- Sell Hotdogs additions to the roblox-thumbnail skill's _G.Thumb (run after scripts/studio_capture.luau).
-- Project-specific: CrewRig rigs, the Tools folder, and the placeholder "grin" monster used when an anomaly
-- has no asset yet.
local T = _G.Thumb
local CrewRig = require(game.ReplicatedStorage.shared.Crew.CrewRig)

-- T.rig(folder, "fox", "crew", nil, "Stressed", "Fox", Vector3.new(x, floorY, z), yawDeg)
-- species lowercase; outfits crew / civil_a..h / thief; expressions Normal, Happy, Smile, Sad, Fainted,
-- Skeptical, Exhausted, Stressed, Thief, EyesWhite, Blank, EyesClosed, Angry. yaw 0 faces +Z, 180 faces -Z.
function T.rig(f, species, outfit, ctype, expr, name, pos, yawDeg)
	local o = f:FindFirstChild(name); if o then o:Destroy() end
	local m = CrewRig.Build(species, outfit, { CustomerType = ctype, Name = name, Anchored = true,
		CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) })
	m.Parent = f
	CrewRig.Dress(m, "Day", expr, expr == "Blank")
	m:PivotTo(m:GetPivot() * CFrame.Angles(0, math.pi + math.rad(yawDeg or 0), 0))
	T.noNames(m)
	return m
end

function T.dress(m, expr) CrewRig.Dress(m, "Day", expr, expr == "Blank") end

-- T.holdTool(rig, "hot_dog") — names in ReplicatedStorage.Assets.Items.Tools
function T.holdTool(m, toolName, armName)
	return T.hold(m, game.ReplicatedStorage.Assets.Items.Tools[toolName], armName)
end

-- placeholder grin monster ---------------------------------------------------------------------------------
local BODY = Color3.fromHex("#1E1A2B"); local EYE = Color3.fromHex("#F4F1E8"); local TOOTH = Color3.fromHex("#FFFFFF")

local function part(model, name, shape, size, at, color)
	local p = Instance.new("Part"); p.Name = name; p.Shape = shape; p.Size = size; p.CFrame = at; p.Color = color
	p.Material = (color == EYE or color == TOOTH) and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CastShadow = color ~= EYE; p.Parent = model; return p
end

local function ellipse(parent, name, M, size, color, mat)
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.Size = size
	p.CFrame = M; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic; p.CastShadow = false
	local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = p
	p.Parent = parent; return p
end

local function wedge(parent, cf, size, color)
	local w = Instance.new("WedgePart"); w.Anchored = true; w.CanCollide = false; w.CastShadow = false
	w.Size = size; w.CFrame = cf; w.Color = color; w.Material = Enum.Material.Neon; w.Parent = parent; return w
end

local function tooth(parent, M, x, baseY, h, w, down)
	local up = down and Vector3.new(0, -1, 0) or Vector3.new(0, 1, 0)
	local cy = down and (baseY - h / 2) or (baseY + h / 2)
	local size = Vector3.new(0.08, h, w / 2)
	local vxR = down and Vector3.new(0, 0, -1) or Vector3.new(0, 0, 1)
	wedge(parent, M * CFrame.fromMatrix(Vector3.new(x + w / 4, cy, -0.06), vxR, up), size, TOOTH)
	wedge(parent, M * CFrame.fromMatrix(Vector3.new(x - w / 4, cy, -0.06), -vxR, up), size, TOOTH)
end

function T.addGrin(model, opts)
	opts = opts or {}
	local head = model.Head
	local W, H = opts.W or 2.4, opts.H or 1.0
	local M = head.CFrame * CFrame.new(0, opts.Y or -0.6, -(opts.Z or 1.2)) * CFrame.Angles(0, math.pi, 0)
	local g = model:FindFirstChild("MonsterGrin") or Instance.new("Model"); g.Name = "MonsterGrin"; g:ClearAllChildren()
	ellipse(g, "MouthDark", M, Vector3.new(W, H, 0.1), Color3.fromHex("#2A0508"))
	local iw, ih = W * 0.9, H * 0.82
	ellipse(g, "MouthRed", M * CFrame.new(0, 0, 0.03), Vector3.new(iw, ih, 0.1), Color3.fromHex("#C4142E"))
	ellipse(g, "Throat", M * CFrame.new(0, -ih * 0.05, 0.05), Vector3.new(iw * 0.45, ih * 0.4, 0.1), Color3.fromHex("#5A0612"))
	ellipse(g, "Tongue", M * CFrame.new(0, -ih * 0.26, 0.07), Vector3.new(iw * 0.35, ih * 0.28, 0.1), Color3.fromHex("#FF4FA3"), Enum.Material.Neon)
	local a, b = iw / 2, ih / 2
	local nUp, nLo = opts.Up or 8, opts.Lo or 7
	for i = 1, nUp do
		local x = -a * 0.86 + (i - 1) * (a * 1.72 / (nUp - 1))
		local edge = b * math.sqrt(math.max(0, 1 - (x / a) ^ 2))
		tooth(g, M * CFrame.new(0, 0, 0.09), x, edge + 0.02, 0.32 * (0.6 + 0.4 * edge / b) * (opts.TS or 1), a * 1.72 / (nUp - 1) * 0.85, true)
	end
	for i = 1, nLo do
		local x = -a * 0.78 + (i - 1) * (a * 1.56 / (nLo - 1))
		local edge = b * math.sqrt(math.max(0, 1 - (x / a) ^ 2))
		tooth(g, M * CFrame.new(0, 0, 0.09), x, -edge - 0.02, 0.28 * (0.6 + 0.4 * edge / b) * (opts.TS or 1), a * 1.56 / (nLo - 1) * 0.85, false)
	end
	g.Parent = model; return g
end

-- Round dark head with Neon eyes and a big grin (Sorriso stand-in). cf = where the pivot (floor) goes.
function T.monsterGrin(f, name, cf)
	local o = f:FindFirstChild(name); if o then o:Destroy() end
	local m = Instance.new("Model"); m.Name = name
	local h = CFrame.new(0, 6.5, 0)
	part(m, "Head", Enum.PartType.Ball, Vector3.one * 7, h, BODY)
	for _, x in { -1, 1 } do
		part(m, "Eye", Enum.PartType.Ball, Vector3.one * 1.5, h * CFrame.new(x * 3.5 * 0.42, 3.5 * 0.15, -3.5 * 0.82), EYE)
	end
	part(m, "Neck", Enum.PartType.Block, Vector3.new(1.6, 3.5, 1.6), CFrame.new(0, 1.75, 0), BODY)
	m.WorldPivot = CFrame.identity; m:PivotTo(cf); m.Parent = f
	T.addGrin(m, { Y = -1.35, W = 4.8, H = 2.0, Z = 3.25, TS = 2.6, Up = 9, Lo = 8 })
	return m
end

return T
