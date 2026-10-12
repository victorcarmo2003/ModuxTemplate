--!strict
-- UiScale: the global UI scale (Theme.ScaleOf, user request 2026-10-11 "as interfaces ... muito grandes") of the
-- current camera viewport as one shared reactive value. Controllers that own a ScreenGui may keep their own source
-- (fed by Theme.ScaleOf); components that get a scale from an owner they cannot trust to follow the global rule cap
-- it with `Current()` (e.g. the lobby windows: math.min(props.Scale(), UiScale.Current())).
-- The camera is watched lazily, on the first read, and for the life of the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

local value: Vide.Source<number>? = nil

-- Follows the viewport. The first value is set by the caller: no write here on the first (maybe reactive) read.
local function watch(target: Vide.Source<number>)
	local connection: RBXScriptConnection? = nil
	local function rescale(camera: Camera)
		const scale = Theme.ScaleOf(camera.ViewportSize)
		if math.abs(scale - Vide.untrack(target)) > 0.01 then
			target(scale)
		end
	end
	local function bind(initial: boolean)
		if connection then
			connection:Disconnect()
			connection = nil
		end
		const camera = workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				rescale(camera)
			end)
			if not initial then
				rescale(camera)
			end
		end
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		bind(false)
	end)
	bind(true)
end

-- Global scale of the current viewport (reactive: read it inside a Vide scope to follow resizes).
local function shared(): Vide.Source<number>
	const existing = value
	if existing then
		return existing
	end
	const camera = workspace.CurrentCamera
	const created = Vide.source(if camera then Theme.ScaleOf(camera.ViewportSize) else 1)
	value = created
	watch(created)
	return created
end

local function current(): number
	return shared()()
end

-- Smallest fit factor (a window on a very narrow screen shrinks at most to this; under it the text would be unreadable).
const FIT_FLOOR = 0.5
const FIT_MARGIN = 16

-- `base` capped so a fixed layout of `design` px (drawn at scale 1) stays inside `area` (the real px size of the
-- ScreenGui, read from a full-size frame: it follows CoreUISafeInsets and the story frame alike). area 0 = unknown.
local function fit(base: number, area: Vector2, design: Vector2): number
	if area.X <= 0 or area.Y <= 0 then
		return base
	end
	const limit = math.min((area.X - FIT_MARGIN) / design.X, (area.Y - FIT_MARGIN / 2) / design.Y)
	return math.min(base, math.max(limit, FIT_FLOOR))
end

return table.freeze({
	Current = current,
	Fit = fit,
	-- Same rule for a given viewport (and optional fixed layout to keep on screen); see Theme.ScaleOf.
	Of = Theme.ScaleOf,
})
