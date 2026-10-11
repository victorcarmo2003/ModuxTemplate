--!strict
--[[
	OpenSignController (user request 2026-10-11; tools/assetplace/decor_mart.luau Decor.runDetails)

	The Pad sign stand (OPEN_AST-024_SignStand, tag OpenSignBoard) carries SurfaceGuis "Detail_OpenSign" with two
	TextLabels, Open and Closed. This shows OPEN while the current phase sells (Content.Shift row Selling = true:
	Open and Night) and CLOSED otherwise. Purely visual and local: the shop state itself is the server's (RoundService).
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const TAG = "OpenSignBoard"
const GUI_NAME = "Detail_OpenSign"
const TICK_RATE = 2 -- Hz: the phase changes a few times per shift

const OpenSignController = Modux.Controller("OpenSignController", { Require = { "RoundController" }, Priority = 300 })

function OpenSignController:Setup()
	self.Shown = nil :: boolean?
end

-- true while the current phase sells
function OpenSignController:IsOpen(): boolean
	const phase = Content.Shift.ByKey[self.Dependencies.RoundController.Phase()]
	return phase ~= nil and phase.Selling
end

function OpenSignController:Paint(board: Instance, open: boolean)
	for _, gui in board:GetChildren() do
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

function OpenSignController:Refresh(force: boolean?)
	const open = self:IsOpen()
	if open == self.Shown and not force then
		return
	end
	self.Shown = open
	for _, board in CollectionService:GetTagged(TAG) do
		self:Paint(board, open)
	end
end

OpenSignController:OnInit(function(self)
	self:Setup()
end)

OpenSignController:OnStart(function(self)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(board)
		self:Paint(board, self:IsOpen())
	end)
	self:Refresh(true)
end)

OpenSignController:OnTick(function(self)
	self:Refresh()
end, TICK_RATE)

return OpenSignController
