--[[
studio_capture.luau - helpers for staging a thumbnail scene in Roblox Studio and capturing it in layers.

Run through the Studio MCP `execute_luau` (datamodel Edit). Each call defines `_G.Thumb` so later calls can use it.
Nothing here touches the game's own objects permanently: everything created goes under
Workspace.ThumbnailScenes.<SceneName> and `_G.Thumb.cleanup()` removes it and restores Lighting.

Workflow (one capture per step, same camera every time):
  1. Thumb.stage("Scene_X")                 -> folder; put models/lights in it
  2. Thumb.lookDay() / Thumb.lookNight()    -> neutral day light for chroma, or the game's night
  3. Thumb.cam(pos, lookAt, fov)            -> ALWAYS re-call with a tiny offset before each screen_capture: Studio
                                               only updates local lights after the camera moves
  4. Thumb.matte(folder, {Model=Color3,...}, "visible"|"full"|"off") -> flat Highlight passes for cutouts
  5. Thumb.chroma(colour) / Thumb.solo(folder, modelName, offset, camPos, camLook, fov) -> green-screen pass
  6. Thumb.cleanup()
]]

local SS = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local Selection = game:GetService("Selection")

local T = {}
_G.Thumb = T

-- lighting backup ------------------------------------------------------------------------------------------
local KEYS = { "ClockTime", "Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GlobalShadows" }

local function backupFolder()
	local f = SS:FindFirstChild("ThumbLightingBackup")
	if not f then
		f = Instance.new("Folder"); f.Name = "ThumbLightingBackup"; f.Parent = SS
		for _, k in KEYS do f:SetAttribute(k, Lighting[k]) end
		for _, e in Lighting:GetChildren() do
			if e:IsA("PostEffect") or e:IsA("Atmosphere") then
				f:SetAttribute("FX_" .. e.Name, e:IsA("Atmosphere") and e.Density or e.Enabled)
			end
		end
		f:SetAttribute("FOV", workspace.CurrentCamera.FieldOfView)
	end
	return f
end

function T.restoreLighting()
	local f = SS:FindFirstChild("ThumbLightingBackup")
	if not f then return end
	for _, k in KEYS do Lighting[k] = f:GetAttribute(k) end
	for _, e in Lighting:GetChildren() do
		local v = f:GetAttribute("FX_" .. e.Name)
		if v ~= nil then
			if e:IsA("Atmosphere") then e.Density = v else e.Enabled = v end
		end
	end
	local cam = workspace.CurrentCamera
	cam.FieldOfView = f:GetAttribute("FOV") or 70
	for _, c in cam:GetChildren() do if c.Name:find("^Thumb_") then c:Destroy() end end
end

-- scene folders --------------------------------------------------------------------------------------------
local function root()
	local r = workspace:FindFirstChild("ThumbnailScenes")
	if not r then r = Instance.new("Folder"); r.Name = "ThumbnailScenes"; r.Parent = workspace end
	return r
end

local function park()
	local p = SS:FindFirstChild("ThumbParked")
	if not p then p = Instance.new("Folder"); p.Name = "ThumbParked"; p.Parent = SS end
	return p
end

function T.stage(name)
	backupFolder()
	local r = root()
	local f = r:FindFirstChild(name) or park():FindFirstChild(name)
	if not f then f = Instance.new("Folder"); f.Name = name end
	f.Parent = r
	return f
end

-- show only one scene (others parked in ServerStorage so they do not leak into the frame)
function T.showOnly(name)
	local r, p = root(), park()
	for _, f in p:GetChildren() do if f.Name == name then f.Parent = r end end
	for _, f in r:GetChildren() do if f.Name ~= name then f.Parent = p end end
	Selection:Set({})
end

-- temporarily hide map parts that sit in the shot (knife on the board, a tree); restored by cleanup()
function T.hide(instances)
	for _, inst in instances do
		for _, p in inst:IsA("BasePart") and { inst } or inst:GetDescendants() do
			if p:IsA("BasePart") and p:GetAttribute("ThumbOrigTransparency") == nil then
				p:SetAttribute("ThumbOrigTransparency", p.Transparency); p.Transparency = 1
			end
		end
	end
end

local function unhideAll()
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("ThumbOrigTransparency") ~= nil then
			d.Transparency = d:GetAttribute("ThumbOrigTransparency"); d:SetAttribute("ThumbOrigTransparency", nil)
		end
	end
end

-- camera ---------------------------------------------------------------------------------------------------
function T.cam(pos, lookAt, fov)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Fixed
	cam.CameraSubject = nil
	if fov then cam.FieldOfView = fov end
	cam.CFrame = CFrame.lookAt(pos, lookAt)
	cam.Focus = CFrame.new(lookAt)
	Selection:Set({})
	return pos, lookAt
end

-- camera post effects for this capture only (live on the Camera, removed by restoreLighting)
function T.fx(o)
	local cam = workspace.CurrentCamera
	for _, c in cam:GetChildren() do if c.Name:find("^Thumb_") then c:Destroy() end end
	o = o or {}
	if o.Bloom then local b = Instance.new("BloomEffect"); b.Name = "Thumb_Bloom"; b.Intensity, b.Size, b.Threshold = o.Bloom[1], o.Bloom[2], o.Bloom[3]; b.Parent = cam end
	if o.DOF then local d = Instance.new("DepthOfFieldEffect"); d.Name = "Thumb_DOF"; d.FocusDistance, d.InFocusRadius, d.FarIntensity, d.NearIntensity = o.DOF[1], o.DOF[2], o.DOF[3] or 0.6, o.DOF[4] or 0.3; d.Parent = cam end
	if o.CC then local c = Instance.new("ColorCorrectionEffect"); c.Name = "Thumb_CC"; c.TintColor = o.CC.Tint or Color3.new(1, 1, 1); c.Saturation = o.CC.Sat or 0; c.Contrast = o.CC.Con or 0; c.Brightness = o.CC.Bri or 0; c.Parent = cam end
end

-- looks ----------------------------------------------------------------------------------------------------
function T.lookDay()
	backupFolder()
	Lighting.ClockTime = 14; Lighting.Brightness = 2.2; Lighting.ExposureCompensation = 0
	Lighting.Ambient = Color3.fromRGB(150, 150, 160); Lighting.OutdoorAmbient = Color3.fromRGB(160, 160, 170)
	Lighting.EnvironmentDiffuseScale = 0.6; Lighting.EnvironmentSpecularScale = 0.6
	for _, e in Lighting:GetChildren() do
		if e:IsA("Atmosphere") then e.Density = 0 elseif e:IsA("PostEffect") then e.Enabled = false end
	end
end

-- "only my lights": black ambient so PointLights/SpotLights carve the subject (horror, night)
function T.lookDark(exposure)
	backupFolder()
	Lighting.ClockTime = 0; Lighting.Brightness = 0; Lighting.ExposureCompensation = exposure or 0.4
	Lighting.Ambient = Color3.fromRGB(10, 12, 22); Lighting.OutdoorAmbient = Color3.fromRGB(8, 10, 20)
	Lighting.EnvironmentDiffuseScale = 0; Lighting.EnvironmentSpecularScale = 0
	for _, e in Lighting:GetChildren() do
		if e:IsA("Atmosphere") then e.Density = 0 elseif e:IsA("PostEffect") then e.Enabled = false end
	end
end

function T.lookNight() T.restoreLighting() end

-- lights ---------------------------------------------------------------------------------------------------
-- point(folder, name, pos, color, brightness, range) / spot(folder, name, pos, target, color, brightness, range, angle)
function T.point(f, name, pos, color, b, r)
	local old = f:FindFirstChild(name); if old then old:Destroy() end
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false
	p.Transparency = 1; p.Size = Vector3.one * 0.2; p.Position = pos; p.Parent = f
	local l = Instance.new("PointLight"); l.Color = color; l.Brightness = b; l.Range = r; l.Shadows = true; l.Parent = p
	return p
end

function T.spot(f, name, pos, target, color, b, r, angle)
	local old = f:FindFirstChild(name); if old then old:Destroy() end
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false
	p.Transparency = 1; p.Size = Vector3.one * 0.2; p.CFrame = CFrame.lookAt(pos, target); p.Parent = f
	local l = Instance.new("SpotLight"); l.Face = Enum.NormalId.Front; l.Angle = angle or 45
	l.Color = color; l.Brightness = b; l.Range = r; l.Shadows = true; l.Parent = p
	return p
end

-- three-point rig around a model's head: warm key front-left, cool rim back-right, weak fill
function T.rig3(f, model, keyColor, rimColor)
	local h = (model:FindFirstChild("Head") or model.PrimaryPart or model:GetBoundingBox()).Position
	T.point(f, "L_Key", h + Vector3.new(-3, 2.5, 4), keyColor or Color3.fromRGB(255, 225, 190), 3, 10)
	T.point(f, "L_Rim", h + Vector3.new(3, 3, -3), rimColor or Color3.fromRGB(140, 180, 255), 5, 9)
	T.point(f, "L_Fill", h + Vector3.new(3, -1, 4), Color3.fromRGB(120, 140, 200), 1, 9)
end

-- glowing eyes on any model with a Head (white, Neon) --------------------------------------------------------
function T.eyes(model, o)
	o = o or {}
	local head = model:FindFirstChild("Head"); if not head then return end
	local g = model:FindFirstChild("ThumbEyes") or Instance.new("Model"); g.Name = "ThumbEyes"; g:ClearAllChildren()
	for _, s in { -1, 1 } do
		local M = head.CFrame * CFrame.new(s * (o.X or 0.5), o.Y or 0.2, -(o.Z or 1.0))
		local e = Instance.new("Part"); e.Name = "Eye"; e.Anchored = true; e.CanCollide = false; e.CastShadow = false
		e.Material = Enum.Material.Neon; e.Color = o.Color or Color3.fromRGB(255, 255, 255)
		e.Size = Vector3.new(o.W or 0.6, o.H or 0.65, 0.12); e.CFrame = M; e.Parent = g
		local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = e
	end
	g.Parent = model
	return g
end

-- matte passes ---------------------------------------------------------------------------------------------
-- colours: { ModelName = Color3 }; mode "visible" respects occluders, "full" draws through, "off" disables
function T.matte(f, colours, mode)
	for name, col in colours do
		local m = f:FindFirstChild(name)
		if m then
			local h = m:FindFirstChild("Thumb_Mask") or Instance.new("Highlight")
			h.Name = "Thumb_Mask"; h.FillColor = col; h.FillTransparency = 0; h.OutlineTransparency = 1
			h.DepthMode = mode == "full" and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
			h.Enabled = mode ~= "off"; h.Parent = m
		end
	end
	Selection:Set({})
end

-- chroma room far from the map; returns its centre
function T.chroma(colour)
	local ch = workspace:FindFirstChild("ThumbnailChroma")
	local C = Vector3.new(0, 700, -6000)
	if not ch then
		ch = Instance.new("Folder"); ch.Name = "ThumbnailChroma"; ch.Parent = workspace
		local S = 400
		local function wall(size, off)
			local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CastShadow = false
			p.Size = size; p.Position = C + off; p.Material = Enum.Material.SmoothPlastic; p.Parent = ch
		end
		wall(Vector3.new(S, 2, S), Vector3.new(0, -S / 2, 0)); wall(Vector3.new(S, 2, S), Vector3.new(0, S / 2, 0))
		wall(Vector3.new(2, S, S), Vector3.new(-S / 2, 0, 0)); wall(Vector3.new(2, S, S), Vector3.new(S / 2, 0, 0))
		wall(Vector3.new(S, S, 2), Vector3.new(0, 0, -S / 2)); wall(Vector3.new(S, S, 2), Vector3.new(0, 0, S / 2))
	end
	for _, p in ch:GetChildren() do if p:IsA("BasePart") then p.Color = colour or Color3.fromRGB(0, 255, 0) end end
	return C
end

-- move one model of a scene into the chroma room keeping the camera relation; call again with the next model
function T.solo(f, modelName, offset, camPos, camLook, fov)
	local hold = SS:FindFirstChild("ThumbSoloHold") or Instance.new("Folder"); hold.Name = "ThumbSoloHold"; hold.Parent = SS
	for _, m in hold:GetChildren() do m.Parent = f end
	if f:GetAttribute("ChromaShift") == nil then
		for _, m in f:GetChildren() do if m:IsA("Model") or m:IsA("BasePart") then m:PivotTo(m:GetPivot() + offset) end end
		f:SetAttribute("ChromaShift", offset)
	end
	for _, m in f:GetChildren() do
		if m:IsA("Model") and m.Name ~= modelName then m.Parent = hold end
		if m:IsA("BasePart") and m.Name:find("^L_") then for _, l in m:GetChildren() do if l:IsA("Light") then l.Enabled = false end end end
	end
	T.lookDay()
	T.fx({})
	workspace.CurrentCamera.FieldOfView = fov or 50
	return T.cam(camPos + offset, camLook + offset, fov)
end

function T.unsolo(f)
	local hold = SS:FindFirstChild("ThumbSoloHold")
	if hold then for _, m in hold:GetChildren() do m.Parent = f end end
	local d = f:GetAttribute("ChromaShift")
	if d then
		for _, m in f:GetChildren() do if m:IsA("Model") or m:IsA("BasePart") then m:PivotTo(m:GetPivot() - d) end end
		f:SetAttribute("ChromaShift", nil)
	end
	for _, m in f:GetDescendants() do if m:IsA("Light") then m.Enabled = true end end
end

-- R6 posing: degrees per joint; moves parts welded to the joint's Part1 along (accessories, held items)
function T.pose(m, a)
	local torso = m:FindFirstChild("Torso"); if not torso then return end
	local function welded(part)
		local set = { [part] = true }
		for _, j in m:GetDescendants() do
			if (j:IsA("Weld") or j:IsA("WeldConstraint") or j:IsA("ManualWeld")) and j.Part0 and j.Part1 then
				if j.Part0 == part then set[j.Part1] = true elseif j.Part1 == part then set[j.Part0] = true end
			end
		end
		return set
	end
	local head = m:FindFirstChild("Head"); local before = head and head.CFrame
	for name, deg in a do
		local j = torso:FindFirstChild(name)
		if j and j:IsA("Motor6D") then
			local base = j:GetAttribute("BaseC0") or j.C0
			j:SetAttribute("BaseC0", base)
			local rot = type(deg) == "table" and CFrame.Angles(math.rad(deg[1]), math.rad(deg[2]), math.rad(deg[3])) or CFrame.Angles(0, 0, math.rad(deg))
			j.C0 = base * rot
			local target = torso.CFrame * j.C0 * j.C1:Inverse()
			local delta = target * j.Part1.CFrame:Inverse()
			for p in welded(j.Part1) do if p ~= torso then p.CFrame = delta * p.CFrame end end
		end
	end
	if head and a.Neck then
		local delta = head.CFrame * before:Inverse()
		local g = m:FindFirstChild("ThumbEyes")
		if g then for _, p in g:GetDescendants() do if p:IsA("BasePart") then p.CFrame = delta * p.CFrame end end end
	end
end

-- turn a model so its head faces `dir` (flat), or faces a point
function T.face(m, dirOrPoint)
	local p = m:GetPivot().Position
	local dir = dirOrPoint
	if (dirOrPoint - p).Magnitude > 2 then dir = dirOrPoint - p end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	m:PivotTo(CFrame.lookAt(p, p + dir))
	local head = m:FindFirstChild("Head")
	if head and head.CFrame.LookVector:Dot(dir) < 0 then m:PivotTo(m:GetPivot() * CFrame.Angles(0, math.pi, 0)) end
end

-- hide nameplates for the shot
function T.noNames(m)
	for _, d in m:GetDescendants() do
		if d:IsA("Humanoid") then d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	end
end

-- rig hygiene ----------------------------------------------------------------------------------------------
-- Studio draws WeldConstraint/Weld gizmos as green lines on selected or recently built rigs and they end up
-- in the capture. Thumb models are anchored, so the welds can simply go.
function T.stripWelds(m)
	for _, d in m:GetDescendants() do
		if d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("ManualWeld") then d:Destroy() end
	end
end

function T.hideAttachments(m)
	for _, d in m:GetDescendants() do if d:IsA("Attachment") then d.Visible = false end end
end

-- Put a Tool instance into a hand: clones its parts anchored at the grip attachment.
function T.hold(m, tool, armName)
	armName = armName or "Right Arm"
	local arm = m[armName]
	local att = arm:FindFirstChild(armName == "Right Arm" and "RightGripAttachment" or "LeftGripAttachment")
	local gripCF = att and att.WorldCFrame
		or (arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
	local old = m:FindFirstChild("Held_" .. tool.Name); if old then old:Destroy() end
	local held = Instance.new("Model"); held.Name = "Held_" .. tool.Name
	local hcf = gripCF * tool.Grip:Inverse()
	for _, p in tool:GetChildren() do
		if p:IsA("BasePart") then
			local c = p:Clone(); c.Anchored = true; c.CanCollide = false
			c.CFrame = hcf * tool.Handle.CFrame:ToObjectSpace(p.CFrame)
			for _, w in c:GetChildren() do if w:IsA("JointInstance") or w:IsA("WeldConstraint") then w:Destroy() end end
			c.Parent = held
		end
	end
	held.Parent = m; return held
end

-- Static pose for anchored thumb rigs. Editing Motor6D.C0 on an anchored rig fights the solver (the whole
-- model tips over) and anything welded to the Head (Face decal part, Cap, Ears) stays behind once welds are
-- stripped - the "face floating off the head" bug. freezePose computes every part's final CFrame from the
-- joint rotations, then deletes ALL joints/welds and writes the CFrames: nothing can drift, no gizmos.
-- rot = { Neck = {yaw, pitch, roll}, ["Right Shoulder"] = {lift, spread}, ["Left Shoulder"] = {lift, spread},
--         ["Right Hip"] = {lift}, ["Left Hip"] = {lift} }  degrees. Neck: + yaw = looks to its own left,
-- + pitch = looks up. Shoulders: + lift = arm forward/up (150 = hands up). Call once on a fresh rig, before
-- T.hold (the grip follows the arm). Replaces stripWelds for posed rigs.
function T.freezePose(m, rot)
	local torso = m:FindFirstChild("Torso")
	local links = {}
	for _, j in m:GetDescendants() do
		if j:IsA("JointInstance") or j:IsA("WeldConstraint") then table.insert(links, j) end
	end
	local function group(root)
		local seen, out, q = { [root] = true, [torso] = true }, { root }, { root }
		while #q > 0 do
			local p = table.remove(q)
			for _, w in links do
				if not (w:IsA("Motor6D") and (w.Part0 == torso or w.Part1 == torso)) then
					local o = (w.Part0 == p and w.Part1) or (w.Part1 == p and w.Part0)
					if o and not seen[o] then seen[o] = true; table.insert(out, o); table.insert(q, o) end
				end
			end
		end
		return out
	end
	local moves = {}
	for name, a in rot or {} do
		local j = torso and torso:FindFirstChild(name)
		if j and j:IsA("Motor6D") then
			local J = torso.CFrame * j.C0
			if name == "Neck" then
				local hc = j.Part1.CFrame
				local new = hc * CFrame.Angles(0, math.rad(a[1] or 0), 0) * CFrame.Angles(math.rad(a[2] or 0), 0, math.rad(a[3] or 0))
				local d = new * hc:Inverse()
				local pivot = CFrame.new(J.Position)
				table.insert(moves, { group(j.Part1), pivot * (d - d.Position) * pivot:Inverse() })
			else
				local sign = name:find("Left") and -1 or 1
				local R = CFrame.Angles(0, 0, math.rad(a[1] or 0) * sign) * CFrame.Angles(math.rad(a[2] or 0), 0, 0)
				table.insert(moves, { group(j.Part1), J * R * J:Inverse() })
			end
		end
	end
	local final = {}
	for _, p in m:GetDescendants() do if p:IsA("BasePart") then final[p] = p.CFrame end end
	for _, mv in moves do for _, p in mv[1] do final[p] = mv[2] * final[p] end end
	for _, w in links do w:Destroy() end
	for p, cf in final do p.Anchored = true; p.CFrame = cf end
end

-- map lights ------------------------------------------------------------------------------------------------
-- The map's own lights blow out a plate under lookDark. Dim them (0.15 is a good start); cleanup restores
-- them from the ThumbOrigBrightness attribute.
function T.dimLights(rootInst, factor)
	local n = 0
	for _, x in rootInst:GetDescendants() do
		if x:IsA("Light") and x:GetAttribute("ThumbOrigBrightness") == nil then
			x:SetAttribute("ThumbOrigBrightness", x.Brightness); x.Brightness = x.Brightness * factor; n += 1
		end
	end
	return n
end

function T.restoreLights()
	local n = 0
	for _, x in workspace:GetDescendants() do
		if x:IsA("Light") and x:GetAttribute("ThumbOrigBrightness") ~= nil then
			x.Brightness = x:GetAttribute("ThumbOrigBrightness"); x:SetAttribute("ThumbOrigBrightness", nil); n += 1
		end
	end
	return n
end

-- cleanup ---------------------------------------------------------------------------------------------------
function T.cleanup()
	unhideAll()
	T.restoreLighting()
	T.restoreLights()
	for _, n in { "ThumbnailScenes", "ThumbnailChroma" } do
		local x = workspace:FindFirstChild(n); if x then x:Destroy() end
	end
	for _, n in { "ThumbParked", "ThumbSoloHold", "ThumbLightingBackup" } do
		local x = SS:FindFirstChild(n); if x then x:Destroy() end
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
	Selection:Set({})
	local strays = {}
	for _, d in game:GetDescendants() do
		local ok, n = pcall(function() return d.Name end)
		if ok and (n:find("^Thumb") or n == "ThumbEyes") then table.insert(strays, d:GetFullName()) end
	end
	return #strays == 0 and "clean" or ("strays: " .. table.concat(strays, ", "))
end

return T
