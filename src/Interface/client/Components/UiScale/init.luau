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

-- Short screen = a phone in landscape: the touch floor kept Theme.ScaleOf at 0.8 there, which left the in-run panels too
-- big (owner 2026-10-20: tasks, subtitle, order card, rejoin popup). Those multiply their scale by `Compact(factor)`.
-- A touch phone now gets Theme.Scale.MinPhone (the PC proportions) from the rule itself: there `factor` is undone by
-- the lower floor (factor x MinTouch / MinPhone, at most 1), so the panels do not shrink twice.
local function compact(factor: number): number
	current()
	const camera = workspace.CurrentCamera
	if camera == nil or camera.ViewportSize.Y <= 0 or camera.ViewportSize.Y > Theme.Scale.PhoneHeight then
		return 1
	end
	if Theme.FloorOf(camera.ViewportSize) == Theme.Scale.MinPhone then
		return math.min(factor * Theme.Scale.MinTouch / Theme.Scale.MinPhone, 1)
	end
	return factor
end

-- Floor for a scale a component caps with `Current()` (replaces Theme.Scale.Min there): MinPhone on a touch phone.
-- Reactive on the viewport (through the shared scale).
local function floor(): number
	current()
	const camera = workspace.CurrentCamera
	return if camera then Theme.FloorOf(camera.ViewportSize) else Theme.Scale.Min
end

return table.freeze({
	Current = current,
	Compact = compact,
	Floor = floor,
	Fit = fit,
	-- Same rule for a given viewport (and optional fixed layout to keep on screen); see Theme.ScaleOf.
	Of = Theme.ScaleOf,
})
