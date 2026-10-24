--!strict
--[[
	OpenSignController (user request 2026-10-11; tools/assetplace/decor_mart.luau Decor.runDetails)

	The Pad sign stand (OPEN_AST-024_SignStand, tag OpenSignBoard) carries SurfaceGuis "Detail_OpenSign" with two
	TextLabels, Open and Closed. This shows OPEN while the current phase sells (Content.Shift row Selling = true:
	Open and Night) or is the day's Last call (row LastCall, DEC-240) and CLOSED otherwise. Purely visual and local: the shop state itself is the server's (RoundService).

	Trailer side neon (user request 2026-10-12, Provisional): two tube signs on the right flank of the trailer, Models
	tagged ShopNeon (and NeonSign, so the flicker of NeonController applies) with the attribute ShopState = "Open"
	(green) or "Closed" (red). The one that matches the shop state stays lit, the other is put out (SmoothPlastic, the
	colour darkened) and carries NeonOverride = true so NeonController does not flicker it back on. The stand left the
	Pad with the same request; its code stays for the places that still carry one (the lobby boards).
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const TAG = "OpenSignBoard"
const GUI_NAME = "Detail_OpenSign"
const TICK_RATE = 2 -- Hz: the phase changes a few times per shift
const NEON_TAG = "ShopNeon"
const STATE_ATTRIBUTE = "ShopState" -- "Open" | "Closed"
const OPEN_STATE = "Open"
const COLOR_ATTRIBUTE = "Color" -- lit colour of a NeonSign Model (Content.Neon.ColorAttribute)
const OVERRIDE_ATTRIBUTE = "NeonOverride" -- Content.Neon.OverrideAttribute
const OUT_DARKEN = 0.8 -- 0..1: a put-out tube is the lit colour lerped toward black by this much
const TUBE_NAMES = { "Tube", "Joint" } -- Content.Neon.PartNames
const BLACK = Color3.new(0, 0, 0)

const OpenSignController = Modux.Controller("OpenSignController", { Require = { "RoundController" }, Priority = 300 })

function OpenSignController:Setup()
	self.Shown = nil :: boolean?
	-- last look written on each ShopNeon Model: Lit = lit or out; Count = tubes seen (late-streamed parts repaint)
	self.Neons = {} :: { [Instance]: { Lit: boolean, Count: number } }
end

-- true while the current phase sells (or is the day's Last call)
function OpenSignController:IsOpen(): boolean
	const round = self.Dependencies.RoundController
	const phase = Content.Shift.ByKey[round.Phase()]
	if phase == nil or round.Paused() then
		return false
	end
	-- Last call (DEC-240): the Closing keeps the sign OPEN until the line is served; at night only when its Night override
	-- is a last call too (owner 2026-10-21)
	if round.IsNight() then
		return phase.Selling or (phase.Night ~= nil and phase.Night.LastCall == true)
	end
	return phase.Selling or phase.LastCall == true
end

-- The faces may sit on the tagged mesh or on a proxy part of the same stand model (user 2026-10-11: "Board" part,
-- the mesh surface was not flat enough for a SurfaceGui), so the whole stand is searched.
function OpenSignController:Paint(board: Instance, open: boolean)
	const stand = board.Parent or board
	for _, gui in stand:GetDescendants() do
		if gui.Name == GUI_NAME then
			const openLabel = gui:FindFirstChild("Open")
			const closedLabel = gui:FindFirstChild("Closed")
			if openLabel and openLabel:IsA("GuiObject") then
				openLabel.Visible = open
			end
			if closedLabel and closedLabel:IsA("GuiObject") then
				closedLabel.Visible = not open
			end
		end
	end
end

local function tubeCount(model: Instance): number
	local count = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and table.find(TUBE_NAMES, part.Name) ~= nil then
			count += 1
		end
	end
	return count
end

-- Lit or out look of every tube of a ShopNeon sign
function OpenSignController:PaintNeon(model: Instance, lit: boolean)
	const attribute = model:GetAttribute(COLOR_ATTRIBUTE)
	if typeof(attribute) ~= "Color3" then
		return
	end
	model:SetAttribute(OVERRIDE_ATTRIBUTE, if lit then nil else true)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and table.find(TUBE_NAMES, part.Name) ~= nil then
			if lit then
				if part.Material ~= Enum.Material.Neon then
					part.Material = Enum.Material.Neon
					part.Color = attribute
				end
			elseif part.Material == Enum.Material.Neon or part.Color == attribute then
				part.Material = Enum.Material.SmoothPlastic
				part.Color = attribute:Lerp(BLACK, OUT_DARKEN)
			end
		end
	end
	self.Neons[model] = { Lit = lit, Count = tubeCount(model) }
end

function OpenSignController:RefreshNeons(open: boolean)
	for _, model in CollectionService:GetTagged(NEON_TAG) do
		const lit = (model:GetAttribute(STATE_ATTRIBUTE) == OPEN_STATE) == open
		const known = self.Neons[model]
		if known == nil or known.Lit ~= lit or known.Count ~= tubeCount(model) then
			self:PaintNeon(model, lit)
		end
	end
end

-- Repaints every tick (2 Hz, a few labels): the stand streams in part by part (the "Board" proxy can arrive after the
-- tagged mesh), so painting only on a phase change could leave a late part on the old face.
function OpenSignController:Refresh()
	const open = self:IsOpen()
	self.Shown = open
	for _, board in CollectionService:GetTagged(TAG) do
		self:Paint(board, open)
	end
	self:RefreshNeons(open)
end

OpenSignController:OnInit(function(self)
	self:Setup()
end)

OpenSignController:OnStart(function(self)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(board)
		self:Paint(board, self:IsOpen())
	end)
	CollectionService:GetInstanceRemovedSignal(NEON_TAG):Connect(function(model)
		self.Neons[model] = nil
	end)
	self:Refresh()
end)

OpenSignController:OnTick(function(self)
	self:Refresh()
end, TICK_RATE)

return OpenSignController
