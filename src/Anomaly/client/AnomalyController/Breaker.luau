--!strict
--[[
	Breaker panel clarity (TASK-334, owner 2026-10-15: "the breaker should only work in the blackout"). Presentation only:
	the prompt itself is LightService's (`breaker_reset`, PromptEnabled = true only while the power is out, ANM-020).

	  Power out (anchor PromptEnabled true): the Mustard 3D guide arrow (Interface/Arrow3D) bobs over the breaker, seen
	           from anywhere, so the panel is found in the dark (Effects/ANM-020 adds its pulsing glow on top). The
	           panel model itself gets a Mustard / Ink Highlight (owner 2026-10-21: "no breaker trip não tem highlight no
	           modelo"), seen through walls, in every tripped case (ANM-020, the trip, the burnt bulb); it goes when the
	           breaker is reset. Left out while the ANM-020 effect has its own pulsing one on the panel.
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
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

const ANCHOR_TAG = "Interactable"
const BREAKER_ACTION = "breaker_reset"
const NOTE_TEXT = "No power issue"
const NOTE_RANGE = 10 -- studs from the panel where the grey pill shows
const ARROW_LIFT = 2.4 -- studs above the anchor where the arrow tip rests
const TICK = 0.1 -- s between two state reads
const FOLDER_NAME = "BreakerGuide"
const PANEL_MODEL = "TRL-BREAKER" -- panel model (tools/assetplace/breaker.luau); else the anchor's part
const HIGHLIGHT_NAME = "BreakerHighlight"
const ANM_HIGHLIGHT = "ANM020_Highlight" -- Effects/ANM-020's own pulsing one
const HIGHLIGHT_FILL = 0.7
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

-- What the highlight wraps: the whole panel model, else the part the anchor sits on
local function panelOf(anchor: Instance): Instance?
	const model = anchor:FindFirstAncestor(PANEL_MODEL)
	if model ~= nil then
		return model
	end
	return if anchor:IsA("Attachment") then anchor.Parent else anchor
end

local function buildHighlight(): Highlight
	const highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_NAME
	highlight.FillColor = Theme.Color.Mustard
	highlight.FillTransparency = HIGHLIGHT_FILL
	highlight.OutlineColor = Theme.Color.Ink
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	return highlight
end

function Breaker.Start()
	const arrow = Arrow3D.new()
	const highlight = buildHighlight()
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
			-- the panel's own outline while tripped (local; parented to the panel, adornee = it)
			const panel = if anchor ~= nil and powerOut then panelOf(anchor) else nil
			if panel ~= nil and panel:FindFirstChild(ANM_HIGHLIGHT) == nil then
				if highlight.Adornee ~= panel then
					highlight.Adornee = panel
				end
				if highlight.Parent ~= panel then
					highlight.Parent = panel
				end
			elseif highlight.Parent ~= nil then
				highlight.Parent = nil
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
