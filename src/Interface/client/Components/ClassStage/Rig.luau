--!strict
-- Motion of the class rig on show (ClassStage viewport and the LobbyController world stage share it):
--   Sway(t)       slow yaw swing (the "giro leve"): the rig turns a little left and right around its feet
--   Pop(model)    swap pop: the model grows from POP_FROM to 1 with a Back overshoot (Model:ScaleTo), POP_TIME s
--   Settle(model) back to scale 1 at once (a rig parked in a cache never stays shrunk)
-- Pure: no Vide, no network. Pop runs on Heartbeat and returns a cancel function.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

const SWAY_SPEED = 0.7 -- rad/s of the swing phase
const SWAY_ANGLE = math.rad(28) -- half swing
const POP_FROM = 0.72
const POP_TIME = 0.35

local function sway(t: number): CFrame
	return CFrame.Angles(0, math.sin(t * SWAY_SPEED) * SWAY_ANGLE, 0)
end

local function settle(model: Model)
	if model:GetScale() ~= 1 then
		model:ScaleTo(1)
	end
end

local function pop(model: Model): () -> ()
	local elapsed = 0
	local connection: RBXScriptConnection? = nil
	const ok = pcall(function()
		model:ScaleTo(POP_FROM)
	end)
	if not ok then
		return function() end
	end
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		const alpha = if model.Parent == nil then 1 else math.clamp(elapsed / POP_TIME, 0, 1)
		const eased = TweenService:GetValue(alpha, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		const scale = math.max(POP_FROM + (1 - POP_FROM) * eased, 0.05)
		pcall(function()
			model:ScaleTo(if alpha >= 1 then 1 else scale)
		end)
		if alpha >= 1 and connection then
			connection:Disconnect()
			connection = nil
		end
	end)
	return function()
		if connection then
			connection:Disconnect()
			connection = nil
			pcall(settle, model)
		end
	end
end

return table.freeze({
	Sway = sway,
	Pop = pop,
	Settle = settle,
})
