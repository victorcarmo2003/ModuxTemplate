--!nonstrict
--[[
	security_cams.luau (TASK-285, FEAT-040; owner request 2026-10-14). Edit-mode Studio snippet, NOT gameplay code.
	Idempotent and reversible. run("assetplace/security_cams", "dry" | "undo" | nil).

	Moves the owner's security camera models and the CCTV monitor into one folder, without touching any pivot:
	  Workspace.CAM1, Workspace.CAM2, Workspace.CCTV  ->  Workspace.SecurityCams.{CAM1, CAM2, CCTV}
	The folder lives OUTSIDE MAP01_Assets on purpose: Place.run destroys and rebuilds MAP01_Assets, and these models are hand
	made in Studio (not in the placements). The pivot of each CAM model is the exact view (Content.Security); a reparent never
	moves a model, and the snippet checks the pivot before and after anyway.
	Also sets ModelStreamingMode = Persistent on the three models (the client reads the camera pivots and the monitor screen
	without having to stream them in).

	Markers (for undo): _SEC_OrigParent (full path of the old parent), _SEC_OrigMode (old ModelStreamingMode name).
	Undo: each marked model goes back to its old parent and mode, markers removed, the folder removed when empty.
	Content.Security.Rules.Folder / Monitor and Cams[*].Model must match FOLDER and NAMES.
]]

local CHS = game:GetService("ChangeHistoryService")
local arg = (...)
local UNDO = arg == "undo"
local DRY = arg == "dry"

local FOLDER = "SecurityCams"
local NAMES = { "CAM1", "CAM2", "CCTV" }
local MARK_PARENT, MARK_MODE = "_SEC_OrigParent", "_SEC_OrigMode"

local lines = {}
local function log(kind, text)
	table.insert(lines, ("[%s] %s"):format(kind, text))
end

local function resolve(path: string): Instance?
	local node: Instance? = game
	for part in string.gmatch(path, "[^%.]+") do
		if node == nil then
			return nil
		end
		node = if node == game then game:FindFirstChild(part) or game:GetService(part) else node:FindFirstChild(part)
	end
	return node
end

local function find(name: string): Model?
	local folder = workspace:FindFirstChild(FOLDER)
	local inside = folder and folder:FindFirstChild(name)
	if inside and inside:IsA("Model") then
		return inside
	end
	local loose = workspace:FindFirstChild(name)
	if loose and loose:IsA("Model") then
		return loose
	end
	-- not at the root: anywhere else in the Workspace (one match only, else report)
	local found = {}
	for _, d in workspace:GetDescendants() do
		if d.Name == name and d:IsA("Model") then
			table.insert(found, d)
		end
	end
	if #found == 1 then
		return found[1]
	elseif #found > 1 then
		log("warn", ("%s: %d models with that name, none moved"):format(name, #found))
	end
	return nil
end

local recording = if DRY then nil else CHS:TryBeginRecording("SecurityCams " .. (if UNDO then "undo" else "apply"))

local ok, err = pcall(function()
	if UNDO then
		local folder = workspace:FindFirstChild(FOLDER)
		for _, name in NAMES do
			local model = folder and folder:FindFirstChild(name)
			if not (model and model:IsA("Model")) then
				log("skip", name .. ": not in the folder")
				continue
			end
			local path = model:GetAttribute(MARK_PARENT)
			local parent = if type(path) == "string" then resolve(path) else nil
			if parent == nil then
				log("warn", ("%s: old parent %s not found, left in the folder"):format(name, tostring(path)))
				continue
			end
			local pivot = model:GetPivot()
			if not DRY then
				model.Parent = parent
				local mode = model:GetAttribute(MARK_MODE)
				if type(mode) == "string" then
					model.ModelStreamingMode = Enum.ModelStreamingMode[mode]
				end
				model:SetAttribute(MARK_PARENT, nil)
				model:SetAttribute(MARK_MODE, nil)
			end
			local moved = (model:GetPivot().Position - pivot.Position).Magnitude
			log("undo", ("%s -> %s (pivot drift %.4f)"):format(name, parent:GetFullName(), moved))
		end
		if folder and #folder:GetChildren() == 0 and not DRY then
			folder:Destroy()
			log("undo", "folder removed")
		end
		return
	end

	local folder = workspace:FindFirstChild(FOLDER)
	if folder == nil then
		if DRY then
			log("dry", "would create Workspace." .. FOLDER)
		else
			folder = Instance.new("Folder")
			folder.Name = FOLDER
			folder.Parent = workspace
			log("make", "Workspace." .. FOLDER)
		end
	end
	for _, name in NAMES do
		local model = find(name)
		if model == nil then
			log("warn", name .. ": not found")
			continue
		end
		if folder and model.Parent == folder then
			log("skip", name .. ": already in the folder, pivot " .. tostring(model:GetPivot().Position))
			continue
		end
		local pivot = model:GetPivot()
		if DRY then
			log("dry", ("%s from %s, pivot %s, mode %s"):format(name, model.Parent:GetFullName(), tostring(pivot.Position), model.ModelStreamingMode.Name))
			continue
		end
		model:SetAttribute(MARK_PARENT, model.Parent:GetFullName())
		model:SetAttribute(MARK_MODE, model.ModelStreamingMode.Name)
		model.Parent = folder
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		local after = model:GetPivot()
		local drift = (after.Position - pivot.Position).Magnitude
		local turn = math.deg(math.acos(math.clamp(after.LookVector:Dot(pivot.LookVector), -1, 1)))
		log(if drift < 1e-3 and turn < 0.01 then "move" else "WARN", ("%s -> %s (pivot drift %.5f studs, %.4f deg)"):format(name, folder:GetFullName(), drift, turn))
	end
end)

if recording then
	CHS:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	table.insert(lines, "[error] " .. tostring(err))
end
return table.concat(lines, "\n")
