--!strict
-- UseTween: port of AnimalPlane `shared/Interface/UseTween` (DEC-029).
-- Returns a source that eases from its current value to `getTarget()` whenever the target changes.
-- Unlike a spring it has a fixed duration, which is what a hold fill or a timed bar needs.
-- `duration` may be reactive; it is read (untracked) at the start of each tween.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)

const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack

export type Duration = number | () -> number

local function read(duration: Duration?): number
	if duration == nil then
		return 0.3
	elseif type(duration) == "number" then
		return duration
	end
	return untrack(duration)
end

return function(
	getTarget: () -> UDim2,
	duration: Duration?,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): () -> UDim2
	const easing = style or Enum.EasingStyle.Exponential
	const way = direction or Enum.EasingDirection.Out

	const value = source(untrack(getTarget))
	local connection: RBXScriptConnection? = nil

	local function cancel()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	effect(function()
		const target = getTarget()
		const from = untrack(value)
		const span = read(duration)

		cancel()
		if span <= 0 or from == target then
			value(target)
			return
		end

		local elapsed = 0
		connection = RunService.Heartbeat:Connect(function(dt: number)
			elapsed += dt
			const alpha = math.clamp(elapsed / span, 0, 1)
			value(from:Lerp(target, TweenService:GetValue(alpha, easing, way)))
			if alpha >= 1 then
				cancel()
			end
		end)
	end)

	cleanup(cancel)

	return function(): UDim2
		return value()
	end
end
