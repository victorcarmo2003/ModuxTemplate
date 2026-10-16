--!nonstrict
--[[
	anomaly_tablet.luau (TASK-345, Anomaly Tablet; owner request 2026-10-15, Provisional). Edit-mode Studio snippet, NOT
	gameplay code. Idempotent and reversible. run("assetplace/anomaly_tablet", "dry" | "undo" | nil).

	Builds the Anomaly Tablet where the owner put the placeholder Part (`Workspace.MAP01_Assets.Part`, Studio read
	2026-10-15: 0.2 x 1.5 x 1, standing on the inner west wall of the trailer, eye height). The Part gives position,
	orientation and size: the screen faces its THINNEST axis, on the side that looks at the trailer centre (or the
	Part's own +axis when it is outside the trailer); attribute ScreenFace = "Front" | "Back" | "Left" | ... on the Part
	overrides that. The Part is then hidden (Transparency 1, no collide / query / touch; attribute _TABLET_MARKER),
	never destroyed, so a rerun rebuilds from it and `undo` shows it again.
	  TRL-TABLET (Model; inside the trailer Model when the Part is inside its box, so it follows every PivotTo)
	    Mount   Mustard wall plate behind the tablet
	    Body    Ink slab (the bezel), Corner* Ink cylinders that round its corners
	    Screen  lit screen (SurfaceGui, LightInfluence 0): Teal "ANOMALY / TABLET" + "?" sticker
	    Camera  small dark dot on the top bezel · Home  round button on the bottom bezel
	    Prompt_Tablet (Attachment in Screen, 0.8 studs out): tag Interactable, PromptAction = read_journal
	            (Content.Journal.Rules; JournalService opens it, JournalController makes the Model glow)
	Also removes the old TRL-BOOK of TASK-335 (only a marked one, _BOOK) if it was ever built.
	A Place.run that rebuilds the trailer drops the tablet: run this again after bind_map01 / trailer_only_map.

	Marker: attribute _TABLET = true on the Model (undo removes only marked models).
]]

local CHS = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local arg = (...)
local UNDO = arg == "undo"
local DRY = arg == "dry"

local NAME = "TRL-TABLET"
local MARK = "_TABLET"
local MARKER = "_TABLET_MARKER"
local OLD_BOOK, OLD_MARK = "TRL-BOOK", "_BOOK"
local ACTION = "read_journal"
local ANCHOR = "Prompt_Tablet"
local PLACEHOLDER = "Part" -- direct child of Workspace.MAP01_Assets
local DEPTH = 0.16 -- tablet thickness
local BEZEL = 0.09 -- studs of bezel around the screen
local INK = Color3.fromHex("#2B2233")
local INK_TOP = Color3.fromHex("#4A3D57")
local TEAL = Color3.fromHex("#3FA7B5")
local CREAM = Color3.fromHex("#FFF1D6")
local MUSTARD = Color3.fromHex("#F6C12B")

local lines = {}
local function log(kind, text)
	table.insert(lines, ("[%s] %s"):format(kind, text))
end

local function trailer(): Model?
	for _, instance in CollectionService:GetTagged("Vehicle") do
		if instance:IsA("Model") and instance:GetAttribute("Vehicle") == "trailer" and instance:IsDescendantOf(workspace) then
			return instance
		end
	end
	return nil
end

-- The placeholder: a marked one anywhere first (already used), else MAP01_Assets.Part.
local function placeholder(): BasePart?
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute(MARKER) then
			return d
		end
	end
	local folder = workspace:FindFirstChild("MAP01_Assets")
	local part = if folder then folder:FindFirstChild(PLACEHOLDER) else nil
	return if part and part:IsA("BasePart") then part else nil
end

local function part(name, size, color, material, parent, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Frame of the tablet: origin at the Part centre, -Z = the screen normal (out of the screen), Y = up along the
-- longer of the two other axes when it is vertical-ish. Returns (frame, width, height).
local function tabletFrame(marker: BasePart, model: Model?): (CFrame, number, number)
	local cf, size = marker.CFrame, marker.Size
	local axes = {
		{ Vector = cf.RightVector, Size = size.X, Name = "X" },
		{ Vector = cf.UpVector, Size = size.Y, Name = "Y" },
		{ Vector = cf.LookVector, Size = size.Z, Name = "Z" }, -- LookVector = -Z of the Part, same axis
	}
	table.sort(axes, function(a, b)
		return a.Size < b.Size
	end)
	local normal = axes[1].Vector
	local face = marker:GetAttribute("ScreenFace")
	if type(face) == "string" and Enum.NormalId[face] then
		normal = cf:VectorToWorldSpace(Vector3.FromNormalId(Enum.NormalId[face]))
		log("info", "ScreenFace override: " .. face)
	elseif model then
		local toward = (model:GetPivot().Position - cf.Position) * Vector3.new(1, 0, 1)
		if toward.Magnitude > 0.01 and normal:Dot(toward) < 0 then
			normal = -normal
		end
	end
	-- of the other two axes, "up" is the one closest to world up
	local a, b = axes[2], axes[3]
	local up, side = a, b
	if math.abs(b.Vector.Y) > math.abs(a.Vector.Y) then
		up, side = b, a
	end
	local upVector = if up.Vector.Y < 0 then -up.Vector else up.Vector
	-- right-handed with LookVector (-Z) = normal: Z = -normal, X = Y x Z = up x -normal
	local frame = CFrame.fromMatrix(cf.Position, upVector:Cross(-normal), upVector)
	return frame, side.Size, up.Size
end

local function insideBox(model: Model, position: Vector3): boolean
	local box, size = model:GetBoundingBox()
	local p = box:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

local function build(parent: Instance, frame: CFrame, width: number, height: number)
	local holder = Instance.new("Model")
	holder.Name = NAME
	holder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- holds gameplay tags (PlaceService rule 5)
	holder:SetAttribute(MARK, true)

	-- frame: -Z out of the screen; the tablet's back sits on the Part centre plane
	local mount = part("Mount", Vector3.new(width * 0.6, height * 0.5, 0.06), MUSTARD, Enum.Material.SmoothPlastic, holder)
	mount.CFrame = frame * CFrame.new(0, 0, 0.03)
	local body = part("Body", Vector3.new(width, height - BEZEL * 2, DEPTH), INK, Enum.Material.SmoothPlastic, holder)
	body.CFrame = frame * CFrame.new(0, 0, -DEPTH / 2)
	local cap = part("BodyTop", Vector3.new(width - BEZEL * 2, height, DEPTH), INK, Enum.Material.SmoothPlastic, holder)
	cap.CFrame = body.CFrame
	for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		local c = part(("Corner%d%d"):format(corner[1] + 1, corner[2] + 1), Vector3.new(DEPTH, BEZEL * 2, BEZEL * 2), INK, Enum.Material.SmoothPlastic, holder, Enum.PartType.Cylinder)
		-- a cylinder's axis is its X: turn it to the depth axis
		c.CFrame = body.CFrame * CFrame.new(corner[1] * (width / 2 - BEZEL), corner[2] * (height / 2 - BEZEL), 0) * CFrame.Angles(0, math.rad(90), 0)
	end

	local screenSize = Vector3.new(width - BEZEL * 2, height - BEZEL * 4, 0.02)
	local screen = part("Screen", screenSize, TEAL, Enum.Material.SmoothPlastic, holder)
	screen.CFrame = frame * CFrame.new(0, 0, -DEPTH - 0.01)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(200, math.floor(200 * screenSize.Y / screenSize.X))
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = TEAL
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromHex("#63C8D4"), Color3.fromHex("#256E7A"))
	gradient.Parent = bg
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(0.9, 0.3)
	title.Position = UDim2.fromScale(0.05, 0.08)
	title.BackgroundTransparency = 1
	title.Text = "ANOMALY\nTABLET"
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = CREAM
	title.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Parent = title
	local sticker = Instance.new("TextLabel")
	sticker.AnchorPoint = Vector2.new(0.5, 0.5)
	sticker.Size = UDim2.fromScale(0.42, 0.42)
	sticker.Position = UDim2.fromScale(0.5, 0.66)
	sticker.SizeConstraint = Enum.SizeConstraint.RelativeXX
	sticker.BackgroundColor3 = MUSTARD
	sticker.Text = "?"
	sticker.Font = Enum.Font.FredokaOne
	sticker.TextScaled = true
	sticker.TextColor3 = INK
	sticker.Parent = bg
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = sticker
	local ring = Instance.new("UIStroke")
	ring.Color = INK
	ring.Thickness = 3
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = sticker
	gui.Parent = screen

	local camera = part("Camera", Vector3.new(0.02, 0.05, 0.05), INK_TOP, Enum.Material.Glass, holder, Enum.PartType.Cylinder)
	camera.CFrame = frame * CFrame.new(0, height / 2 - BEZEL, -DEPTH - 0.005) * CFrame.Angles(0, math.rad(90), 0)
	local home = part("Home", Vector3.new(0.02, 0.1, 0.1), INK_TOP, Enum.Material.SmoothPlastic, holder, Enum.PartType.Cylinder)
	home.CFrame = frame * CFrame.new(0, -height / 2 + BEZEL, -DEPTH - 0.005) * CFrame.Angles(0, math.rad(90), 0)

	local anchor = Instance.new("Attachment")
	anchor.Name = ANCHOR
	anchor.Position = Vector3.new(0, 0, -0.8) -- the screen part's front is its -Z
	anchor:SetAttribute("PromptAction", ACTION)
	anchor.Parent = screen
	CollectionService:AddTag(anchor, "Interactable")

	holder.PrimaryPart = body
	holder.Parent = parent
	log("done", ("%s at %s (%.2f x %.2f)"):format(holder:GetFullName(), tostring(frame.Position), width, height))
end

local function hideMarker(marker: BasePart)
	if marker:GetAttribute(MARKER) then
		return
	end
	marker:SetAttribute(MARKER, true)
	marker:SetAttribute("_TabletWas", ("%s|%s|%s|%s"):format(marker.Transparency, tostring(marker.CanCollide), tostring(marker.CanQuery), tostring(marker.CanTouch)))
	marker.Transparency = 1
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	log("done", "placeholder hidden: " .. marker:GetFullName())
end

local function showMarker(marker: BasePart)
	local was = marker:GetAttribute("_TabletWas")
	if type(was) == "string" then
		local t, collide, query, touch = string.match(was, "^([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
		marker.Transparency = tonumber(t) or 0
		marker.CanCollide = collide == "true"
		marker.CanQuery = query == "true"
		marker.CanTouch = touch == "true"
	end
	marker:SetAttribute(MARKER, nil)
	marker:SetAttribute("_TabletWas", nil)
	log("done", "placeholder shown again: " .. marker:GetFullName())
end

local function existingTablet(): Model?
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d.Name == NAME then
			return d
		end
	end
	return nil
end

local recording = if DRY then nil else CHS:TryBeginRecording("Anomaly tablet " .. (if UNDO then "undo" else "apply"))

local ok, err = pcall(function()
	local model = trailer()
	local marker = placeholder()
	local existing = existingTablet()
	if UNDO then
		if existing and existing:GetAttribute(MARK) then
			existing:Destroy()
			log("done", "removed " .. NAME)
		else
			log("skip", "no tablet to undo")
		end
		if marker and marker:GetAttribute(MARKER) then
			showMarker(marker)
		end
		return
	end
	if marker == nil then
		log("error", "no placeholder: Workspace.MAP01_Assets." .. PLACEHOLDER .. " (a BasePart) is missing")
		return
	end
	for _, anchor in CollectionService:GetTagged("Interactable") do
		if
			anchor:GetAttribute("PromptAction") == ACTION
			and not (existing and anchor:IsDescendantOf(existing))
			and not anchor:FindFirstAncestor(OLD_BOOK)
		then
			log("skip", "a read_journal anchor already exists: " .. anchor:GetFullName())
			return
		end
	end
	if existing and not existing:GetAttribute(MARK) then
		log("skip", NAME .. " exists and is not ours (no " .. MARK .. "): left as is")
		return
	end
	local frame, width, height = tabletFrame(marker, model)
	local parent: Instance = if model and insideBox(model, marker.Position) then model else marker.Parent
	if DRY then
		log("dry", ("would build %s.%s at %s facing %s (%.2f x %.2f)"):format(parent:GetFullName(), NAME, tostring(frame.Position), tostring(frame.LookVector), width, height))
		return
	end
	local book = workspace:FindFirstChild(OLD_BOOK, true)
	if book and book:GetAttribute(OLD_MARK) then
		book:Destroy()
		log("done", "removed the old " .. OLD_BOOK)
	end
	if existing then
		existing:Destroy() -- rebuild from the placeholder
	end
	build(parent, frame, width, height)
	hideMarker(marker)
end)

if recording then
	CHS:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	log("error", tostring(err))
end
local out = table.concat(lines, "\n")
print(out)
return out
