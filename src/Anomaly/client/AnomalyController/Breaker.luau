--!strict
--[[
	Breaker panel clarity (TASK-334, owner 2026-10-15: "the breaker should only work in the blackout"). Presentation only:
	the prompt itself is LightService's (`breaker_reset`, PromptEnabled = true only while the power is out, ANM-020).

	  Power out (anchor PromptEnabled true): the Mustard 3D guide arrow (Interface/Arrow3D) bobs over the breaker, seen
	           from anywhere, so the panel is found in the dark (Effects/ANM-020 adds its pulsing glow on top).
	  Power on  (prompt off): a Slate pill "No power issue" shows on the panel when the local character stands within
	           NOTE_RANGE: the panel is there, it just has nothing to do.
	Runs on its own (AnomalyController:OnStart), 10 Hz for the state and RenderStepped only while the arrow is up.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Arrow3D = require(StarterPlayer.StarterPlayerScripts.client.Interface.Arrow3D)

const ANCHOR_TAG = "Interactable"
const BREAKER_ACTION = "breaker_reset"
const NOTE_TEXT = "No power issue"
const NOTE_RANGE = 10 -- studs from the panel where the grey pill shows
const ARROW_LIFT = 2.4 -- studs above the anchor where the arrow tip rests
const TICK = 0.1 -- s between two state reads
const FOLDER_NAME = "BreakerGuide"
const SLATE = Color3.fromHex("#8A8FA3")
const SLATE_DARK = Color3.fromHex("#5D6173")
const INK = Color3.fromHex("#2B2233")
const WHITE = Color3.fromHex("#F1ECE4")

const Breaker = {}

local function anchorOf(): Instance?
	for _, anchor in CollectionService:GetTagged(ANCHOR_TAG) do
		if anchor:GetAttribute("PromptAction") == BREAKER_ACTION and anchor:IsDescendantOf(Workspace) then
			return anchor
		end
	end
	return nil
end

local function positionOf(anchor: Instance): Vector3?
	if anchor:IsA("Attachment") then
		return anchor.WorldPosition
	elseif anchor:IsA("BasePart") then
		return anchor.Position
	elseif anchor:IsA("Model") then
		return anchor:GetPivot().Position
	end
	return nil
end

local function buildNote(): BillboardGui
	const gui = Instance.new("BillboardGui")
	gui.Name = "BreakerNote"
	gui.AlwaysOnTop = false -- owner 2026-10-18: the note showed through the walls (kitchen side)
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(170, 38)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.4, 0)
	gui.MaxDistance = NOTE_RANGE + 4
	gui.ResetOnSpawn = false
	const pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = SLATE
	pill.BackgroundTransparency = 0.05
	pill.Parent = gui
	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	const stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = pill
	const label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 1, -6)
	label.Position = UDim2.fromOffset(8, 3)
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.Text = NOTE_TEXT
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.TextStrokeColor3 = SLATE_DARK
	label.TextStrokeTransparency = 0.4
	label.Parent = pill
	return gui
end

-- own Workspace folder: the anomaly folder is emptied at the end of every night, which would destroy the arrow
local function guideFolder(): Folder
	const found = Workspace:FindFirstChild(FOLDER_NAME)
	if found ~= nil and found:IsA("Folder") then
		return found
	end
	const folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

function Breaker.Start()
	const arrow = Arrow3D.new()
	const note = buildNote()
	local tip: Vector3? = nil
	local stepping: RBXScriptConnection? = nil

	local function stopArrow()
		const connection = stepping
		if connection ~= nil then
			connection:Disconnect()
			stepping = nil
		end
		if arrow.Mounted() then
			arrow.Detach()
		end
	end

	task.spawn(function()
		while true do
			task.wait(TICK)
			const anchor = anchorOf()
			const at = if anchor ~= nil then positionOf(anchor) else nil
			const powerOut = anchor ~= nil and anchor:GetAttribute("PromptEnabled") == true
			if at ~= nil and powerOut then
				tip = at + Vector3.new(0, ARROW_LIFT, 0)
				if stepping == nil then
					arrow.Show(guideFolder())
					stepping = RunService.RenderStepped:Connect(function()
						const rest = tip
						if rest ~= nil then
							arrow.Step(rest, 1, true)
						end
					end)
				end
			else
				stopArrow()
			end
			-- grey note only with the power on and the character close to the panel
			const character = Players.LocalPlayer.Character
			const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			const close = at ~= nil
				and root ~= nil
				and root:IsA("BasePart")
				and (root.Position - at).Magnitude <= NOTE_RANGE
			if anchor ~= nil and close and not powerOut then
				-- a BillboardGui adorns an Attachment or a part directly
				if note.Adornee ~= anchor and (anchor:IsA("Attachment") or anchor:IsA("PVInstance")) then
					note.Adornee = anchor :: any
				end
				const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
				if playerGui ~= nil and note.Parent ~= playerGui then
					note.Parent = playerGui
				end
			elseif note.Parent ~= nil then
				note.Parent = nil
			end
		end
	end)
end

return table.freeze(Breaker)
