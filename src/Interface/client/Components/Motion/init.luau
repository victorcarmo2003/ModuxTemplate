--!strict
-- Motion: the micro-animations of the cartoon UI kit (Theme.Motion), as sources to bind to a UIScale / Text.
--   Bump(value)    scale that jumps (Theme.Motion.BumpScale) and settles each time the number goes up
--   Count(value)   number that rolls from the old value to the new one (money "pulando")
--   Pop(shown)     scale 0 -> 1 with overshoot when shown, back to 0 when hidden (clamped >= 0)
--   Press(pressed, hovered?)  squash on press, slight grow on hover
-- Must be called inside a Vide scope (a component). Pure: no instances.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const source = Vide.source
const spring = Vide.spring
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack

local function cancel(thread: thread?)
	if thread and coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
end

local function bump(value: () -> number, scale: number?, time: number?): () -> number
	const peak = scale or Theme.Motion.BumpScale
	const hold = time or Theme.Motion.Bump
	const up = source(false)
	local last = untrack(value)
	local thread: thread? = nil
	effect(function()
		const now = value()
		if now > last then
			cancel(thread)
			up(true)
			thread = task.delay(hold, function()
				thread = nil
				up(false)
			end)
		end
		last = now
	end)
	cleanup(function()
		cancel(thread)
	end)
	const s = spring(function()
		return if up() then peak else 1
	end, 0.12, 0.45)
	return function(): number
		return math.max(s(), 0)
	end
end

local function count(value: () -> number, duration: number?): () -> number
	const span = duration or Theme.Motion.Count
	const shown = source(untrack(value))
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end
	effect(function()
		const target = value()
		const from = untrack(shown)
		stop()
		if from == target then
			return
		end
		local elapsed = 0
		connection = RunService.Heartbeat:Connect(function(dt: number)
			elapsed += dt
			const alpha = math.clamp(elapsed / span, 0, 1)
			const eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			shown(if alpha >= 1 then target else from + (target - from) * eased)
			if alpha >= 1 then
				stop()
			end
		end)
	end)
	cleanup(stop)
	return function(): number
		return shown()
	end
end

local function pop(shown: () -> boolean): () -> number
	const s = spring(function()
		return if shown() then 1 else 0
	end, Theme.Motion.Pop, Theme.Motion.PopDamping)
	return function(): number
		return math.max(s(), 0)
	end
end

local function press(pressed: () -> boolean, hovered: (() -> boolean)?): () -> number
	const s = spring(function()
		if pressed() then
			return Theme.Motion.PressScale
		elseif hovered and hovered() then
			return Theme.Motion.HoverScale
		end
		return 1
	end, Theme.Motion.Press, 0.5)
	return function(): number
		return math.max(s(), 0)
	end
end

return table.freeze({
	Bump = bump,
	Count = count,
	Pop = pop,
	Press = press,
})
