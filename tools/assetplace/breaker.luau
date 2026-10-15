--!nonstrict
--[[
	breaker.luau (TASK-273, ANM-020 "The blackout", V2 family C; DEC-254). Edit-mode Studio snippet, NOT gameplay code.
	Idempotent and reversible. run("assetplace/breaker", "dry" | "undo" | nil).

	Builds the breaker box at the back of the trailer, where the player goes in the dark to hold E for 3 s:
	  <trailer Model (tag Vehicle, Vehicle = "trailer")>.TRL-BREAKER (Model)
	    Box     grey metal box (1.6 x 2.2 x 0.5) on the outer west wall, toward the back (west strip, where Exit Trailer
	            lands; ~8 studs from the Enter Trailer prompt so the two prompt spheres never overlap)
	    Door    thin front plate, Lever (Mustard handle), Label (SurfaceGui "BREAKER")
	    Prompt_Breaker (Attachment in Box, 0.6 studs in front): tag Interactable, PromptAction = breaker_reset,
	            PromptEnabled = false (LightService turns it on only while the power is out)
	Position: in the frame of the trailer pivot (local +X = the west strip, local +Z = the back wall; the same frame as
	TrailerDoorService and LightService BREAKER_OFFSET). A ray from the strip toward the trailer finds the outer wall;
	the box is at chest height over the ground found under it. Without a wall hit it uses OFFSET as is.
	Inside the trailer Model so it follows every PivotTo of the vehicle. A Place.run that rebuilds the trailer drops it:
	run this again after bind_map01 (and after trailer_only_map).

	Marker: attribute _BRK = true on the Model (undo removes only marked models).
]]

local CHS = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local arg = (...)
local UNDO = arg == "undo"
local DRY = arg == "dry"

local NAME = "TRL-BREAKER"
local MARK = "_BRK"
local ACTION = "breaker_reset"
local OFFSET = Vector3.new(15.6, 4.4, -4.6) -- LightService BREAKER_OFFSET (fallback without a wall hit)
local RAY_FROM_X = 24 -- local X the wall ray starts from (outside, on the strip side)
local CHEST = 4.2 -- studs over the ground for the box centre
local BOX = Vector3.new(1.6, 2.2, 0.5)
local SLATE = Color3.fromHex("#5B6270")
local INK = Color3.fromHex("#2B2233")
local MUSTARD = Color3.fromHex("#E8B23A")
local CREAM = Color3.fromHex("#F3E6C8")

local lines = {}
local function log(kind, text)
	table.insert(lines, ("[%s] %s"):format(kind, text))
end

local function trailer(): Model?
	local found = {}
	for _, instance in CollectionService:GetTagged("Vehicle") do
		if instance:IsA("Model") and instance:GetAttribute("Vehicle") == "trailer" and instance:IsDescendantOf(workspace) then
			table.insert(found, instance)
		end
	end
	if #found > 1 then
		log("warn", ("%d trailer Models with tag Vehicle; using %s"):format(#found, found[1]:GetFullName()))
	end
	return found[1]
end

local function part(name, size, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- World CFrame of the box: facing out of the wall (toward local +X of the trailer pivot)
local function boxFrame(model: Model): CFrame
	local pivot = model:GetPivot()
	local outward = pivot.RightVector -- local +X: the west strip
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local start = pivot:PointToWorldSpace(Vector3.new(RAY_FROM_X, OFFSET.Y, OFFSET.Z))
	local wall = workspace:Raycast(start, -outward * (RAY_FROM_X + 4), params)
	local spot
	if wall then
		spot = wall.Position + outward * (BOX.Z / 2 + 0.02)
		log("info", ("outer wall hit on %s"):format(wall.Instance:GetFullName()))
	else
		spot = pivot:PointToWorldSpace(OFFSET)
		log("warn", "no wall hit: box at the raw OFFSET")
	end
	-- chest height over the ground under the box (ignore the trailer)
	local down = RaycastParams.new()
	down.FilterType = Enum.RaycastFilterType.Exclude
	down.FilterDescendantsInstances = { model }
	local ground = workspace:Raycast(spot + outward * 1.5 + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0), down)
	if ground then
		spot = Vector3.new(spot.X, ground.Position.Y + CHEST, spot.Z)
	end
	return CFrame.lookAt(spot, spot + outward)
end

local function build(model: Model)
	local frame = boxFrame(model)
	local holder = Instance.new("Model")
	holder.Name = NAME
	holder:SetAttribute(MARK, true)

	-- the box looks along its own -Z (CFrame.lookAt): the front face is -Z
	local box = part("Box", BOX, SLATE, Enum.Material.Metal, holder)
	box.CFrame = frame
	local door = part("Door", Vector3.new(BOX.X - 0.2, BOX.Y - 0.2, 0.06), Color3.fromHex("#6E7584"), Enum.Material.Metal, holder)
	door.CFrame = frame * CFrame.new(0, 0, -BOX.Z / 2 - 0.03)
	local lever = part("Lever", Vector3.new(0.22, 0.7, 0.22), MUSTARD, Enum.Material.SmoothPlastic, holder)
	lever.CFrame = frame * CFrame.new(0.35, -0.2, -BOX.Z / 2 - 0.2)
	local plate = part("Label", Vector3.new(1.1, 0.32, 0.04), CREAM, Enum.Material.SmoothPlastic, holder)
	plate.CFrame = frame * CFrame.new(0, BOX.Y / 2 - 0.35, -BOX.Z / 2 - 0.08)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(220, 64)
	gui.LightInfluence = 1
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "BREAKER"
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = INK
	text.Parent = gui
	gui.Parent = plate

	local anchor = Instance.new("Attachment")
	anchor.Name = "Prompt_Breaker"
	anchor.Position = Vector3.new(0, 0, -0.6)
	anchor:SetAttribute("PromptAction", ACTION)
	anchor:SetAttribute("PromptEnabled", false)
	anchor.Parent = box
	CollectionService:AddTag(anchor, "Interactable")

	holder.PrimaryPart = box
	holder.Parent = model
	log("done", ("%s at %s"):format(holder:GetFullName(), tostring(frame.Position)))
end

local recording = if DRY then nil else CHS:TryBeginRecording("Breaker " .. (if UNDO then "undo" else "apply"))

local ok, err = pcall(function()
	local model = trailer()
	if model == nil then
		log("error", "no trailer Model (tag Vehicle, Vehicle = trailer) in the Workspace")
		return
	end
	local existing = model:FindFirstChild(NAME)
	if UNDO then
		if existing and existing:GetAttribute(MARK) then
			existing:Destroy()
			log("done", "removed " .. NAME)
		else
			log("skip", "nothing to undo")
		end
		return
	end
	-- any other breaker anchor already authored in the place wins (LightService uses every one it finds)
	for _, anchor in CollectionService:GetTagged("Interactable") do
		if anchor:GetAttribute("PromptAction") == ACTION and not (existing and anchor:IsDescendantOf(existing)) then
			log("skip", "a breaker_reset anchor already exists: " .. anchor:GetFullName())
			return
		end
	end
	if DRY then
		local frame = boxFrame(model)
		log("dry", ("would build %s.%s at %s"):format(model:GetFullName(), NAME, tostring(frame.Position)))
		return
	end
	if existing then
		if not existing:GetAttribute(MARK) then
			log("skip", NAME .. " exists and is not ours (no " .. MARK .. "): left as is")
			return
		end
		existing:Destroy() -- rebuild from the current trailer pose
	end
	build(model)
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
