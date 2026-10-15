--!nonstrict
--[[
	anomaly_book.luau (TASK-335, Anomaly Book; owner request 2026-10-15, Provisional). Edit-mode Studio snippet, NOT
	gameplay code. Idempotent and reversible. run("assetplace/anomaly_book", "dry" | "undo" | nil).

	Puts the Anomaly Book inside the trailer, open on a small lectern against the back wall (the counters are all
	kitchen: Studio read 2026-10-15), with the prompt that opens it:
	  <trailer Model (tag Vehicle, Vehicle = "trailer")>.TRL-BOOK (Model)
	    Foot / Post / Desk  the lectern (Ink foot, Mustard post, Ink desk tilted LEAN degrees toward the aisle)
	    Cover   Ink slab under the pages (1.9 x 0.12 x 1.3), a little wider than them, on the desk
	    PageL / PageR  Cream pages, tilted up 6 degrees from the spine (open book), Ribbon (Mustard bookmark)
	    Label   SurfaceGui on the left page: "ANOMALY BOOK" (Fredoka One, Ink)
	    Prompt_Book (Attachment in Cover, 0.5 studs above): tag Interactable, PromptAction = read_journal
	            (Content.Journal.Rules; JournalService opens the book, JournalController makes the Model glow)
	Position: the first of SPOTS (trailer pivot frame, same frame as breaker.luau / the prompts of the kitchen) where a
	ray down hits the trailer floor (FLOOR_MIN..FLOOR_MAX studs over the pivot) and no other prompt anchor is within
	CLEAR studs of the book. The book faces local -Z (the aisle, toward the counter). Inside the trailer Model, so it
	follows every PivotTo of the vehicle. A Place.run that rebuilds the trailer drops it: run this again after
	bind_map01 (and after trailer_only_map).

	Marker: attribute _BOOK = true on the Model (undo removes only marked models).
]]

local CHS = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local arg = (...)
local UNDO = arg == "undo"
local DRY = arg == "dry"

local NAME = "TRL-BOOK"
local MARK = "_BOOK"
local ACTION = "read_journal"
local ANCHOR = "Prompt_Book"
-- local X, Z of the lectern foot in the trailer pivot frame, best first: the aisle floor by the back wall between
-- the coffee machine and the CCTV. Studio read 2026-10-15: floor Y 2.0, back wall from Z 3.2, coffee (-0.6, 2.2),
-- trash (3.5, 2.6), CCTV (-9.9, 5.0), kitchen counter Z -1.5 and beyond
local SPOTS = {
	Vector2.new(-5.0, 2.6),
	Vector2.new(-4.0, 2.6),
	Vector2.new(-6.5, 2.6),
	Vector2.new(-3.0, 2.6),
}
local RAY_FROM = 8.5 -- local Y the down ray starts from (under the roof)
local FLOOR_MIN, FLOOR_MAX = 1, 3 -- local Y window of the trailer floor
local CLEAR = 2.2 -- studs from the book to the nearest other prompt anchor
local HEIGHT = 2.6 -- studs from the floor to the desk centre (a reading height)
local LEAN = 20 -- degrees the desk tilts toward the reader
local DESK = Vector3.new(2.1, 0.12, 1.5)
local COVER = Vector3.new(1.9, 0.12, 1.3)
local PAGE = Vector3.new(0.88, 0.06, 1.18)
local TILT = 6 -- degrees each page rises from the spine
local INK = Color3.fromHex("#2B2233")
local CREAM = Color3.fromHex("#FFF1D6")
local MUSTARD = Color3.fromHex("#F6C12B")

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
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Other prompt anchors of the trailer (to keep the prompt spheres apart).
local function anchors(model: Model, except: Instance?)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d:GetAttribute("PromptAction") ~= nil and not (except and d:IsDescendantOf(except)) then
			table.insert(list, d.WorldPosition)
		end
	end
	return list
end

-- World CFrame of the lectern foot (on the floor, axes of the pivot) at the first free spot, or nil.
local function spot(model: Model, except: Instance?): CFrame?
	local pivot = model:GetPivot()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local others = anchors(model, except)
	for _, xz in SPOTS do
		local start = pivot:PointToWorldSpace(Vector3.new(xz.X, RAY_FROM, xz.Y))
		local hit = workspace:Raycast(start, -pivot.UpVector * RAY_FROM, params)
		if hit and not (except and hit.Instance:IsDescendantOf(except)) then
			local floor = pivot:PointToObjectSpace(hit.Position).Y
			local book = hit.Position + pivot.UpVector * HEIGHT
			local free = true
			for _, at in others do
				if (at - book).Magnitude < CLEAR then
					free = false
					break
				end
			end
			if floor >= FLOOR_MIN and floor <= FLOOR_MAX and free then
				log("info", ("spot (%.1f, %.1f): floor %.2f on %s"):format(xz.X, xz.Y, floor, hit.Instance:GetFullName()))
				return CFrame.fromMatrix(hit.Position, pivot.RightVector, pivot.UpVector)
			end
			log("skip", ("spot (%.1f, %.1f): floor %.2f, free %s"):format(xz.X, xz.Y, floor, tostring(free)))
		else
			log("skip", ("spot (%.1f, %.1f): no trailer floor under it"):format(xz.X, xz.Y))
		end
	end
	return nil
end

local function build(model: Model, frame: CFrame)
	local holder = Instance.new("Model")
	holder.Name = NAME
	holder:SetAttribute(MARK, true)

	-- lectern: foot on the floor, post, desk tilted toward local -Z (the aisle)
	local foot = part("Foot", Vector3.new(1.4, 0.2, 1.0), INK, Enum.Material.SmoothPlastic, holder)
	foot.CFrame = frame * CFrame.new(0, 0.1, 0)
	local post = part("Post", Vector3.new(0.4, HEIGHT - 0.3, 0.4), MUSTARD, Enum.Material.SmoothPlastic, holder)
	post.CFrame = frame * CFrame.new(0, 0.2 + (HEIGHT - 0.3) / 2, 0)
	local tilt = frame * CFrame.new(0, HEIGHT, 0) * CFrame.Angles(math.rad(-LEAN), 0, 0)
	local desk = part("Desk", DESK, INK, Enum.Material.SmoothPlastic, holder)
	desk.CFrame = tilt
	local lip = part("Lip", Vector3.new(DESK.X, 0.18, 0.12), INK, Enum.Material.SmoothPlastic, holder)
	lip.CFrame = tilt * CFrame.new(0, 0.1, -DESK.Z / 2 + 0.06)

	frame = tilt * CFrame.new(0, DESK.Y / 2 + COVER.Y / 2, 0.05)
	local cover = part("Cover", COVER, Color3.fromHex("#4A3D57"), Enum.Material.SmoothPlastic, holder)
	cover.CFrame = frame
	local lift = COVER.Y / 2 + PAGE.Y / 2
	-- each page hinges on the spine (local X = 0) and rises TILT degrees toward its outer edge
	local half = PAGE.X / 2 + 0.02
	local left = part("PageL", PAGE, CREAM, Enum.Material.SmoothPlastic, holder)
	left.CFrame = frame * CFrame.new(0, lift, 0) * CFrame.Angles(0, 0, math.rad(-TILT)) * CFrame.new(-half, 0, 0)
	local right = part("PageR", PAGE, CREAM, Enum.Material.SmoothPlastic, holder)
	right.CFrame = frame * CFrame.new(0, lift, 0) * CFrame.Angles(0, 0, math.rad(TILT)) * CFrame.new(half, 0, 0)
	local ribbon = part("Ribbon", Vector3.new(0.08, 0.02, 0.5), MUSTARD, Enum.Material.SmoothPlastic, holder)
	ribbon.CFrame = frame * CFrame.new(0.05, lift + PAGE.Y / 2 + 0.01, PAGE.Z / 2 + 0.15)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(176, 236)
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.5)
	label.Position = UDim2.fromScale(0.05, 0.25)
	label.BackgroundTransparency = 1
	label.Text = "ANOMALY\nBOOK"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = INK
	label.Parent = gui
	gui.Parent = left

	local anchor = Instance.new("Attachment")
	anchor.Name = ANCHOR
	anchor.Position = Vector3.new(0, 0.6, -0.3)
	anchor:SetAttribute("PromptAction", ACTION)
	anchor.Parent = cover
	CollectionService:AddTag(anchor, "Interactable")

	holder.PrimaryPart = foot
	holder.Parent = model
	log("done", ("%s at %s"):format(holder:GetFullName(), tostring(frame.Position)))
end

local recording = if DRY then nil else CHS:TryBeginRecording("Anomaly book " .. (if UNDO then "undo" else "apply"))

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
	-- a read_journal anchor authored elsewhere wins (JournalController uses the first it finds)
	for _, anchor in CollectionService:GetTagged("Interactable") do
		if anchor:GetAttribute("PromptAction") == ACTION and not (existing and anchor:IsDescendantOf(existing)) then
			log("skip", "a read_journal anchor already exists: " .. anchor:GetFullName())
			return
		end
	end
	if existing and not existing:GetAttribute(MARK) then
		log("skip", NAME .. " exists and is not ours (no " .. MARK .. "): left as is")
		return
	end
	local frame = spot(model, existing)
	if frame == nil then
		log("error", "no free counter spot: add one to SPOTS")
		return
	end
	if DRY then
		log("dry", ("would build %s.%s at %s"):format(model:GetFullName(), NAME, tostring(frame.Position)))
		return
	end
	if existing then
		existing:Destroy() -- rebuild from the current trailer pose
	end
	build(model, frame)
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
