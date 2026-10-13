--!strict
-- Pan: continuous navigation along the trail of stations of the 3D prep mode (feedback 2026-10-12, H). The trail is the list of poses
-- of the tabs of the current set (Poses.Trail: Grill -> Board -> Toppings, it follows Content.Prep.Tabs), `u` 0..1 is a point on it
-- and the camera is retargeted every frame to the blend of the two poses around `u` (CameraController:PrepGoal, the springs of the
-- camera do the smoothing). Three inputs move `u`:
--   * a press on EMPTY space dragged sideways (touch and mouse): the world follows the finger; on release the landing point (with a
--     little inertia, or a fling) snaps to the nearest station, which is the only moment the stage changes (Commit)
--   * the mouse at the left / right border of the screen (Rules.Camera.Pan.Edge of the width, speed grows toward the border), also
--     while a sausage or a plate is dragged; never over the chrome (a GUI that draws, a Zones overlay)
--   * LB / RB and the dots are plain tab changes (the controller): they only tell this module where the camera went (Sync)
-- NEVER while the player positions or pours a topping or makes a precision gesture (cut, sauce): the touch pan needs that no tool is
-- armed and nothing is in the hand, the edge scroll stops while a gesture runs or the pointer is over the mat (`Precision`).
-- Reduced motion: no live movement and no inertia; a sideways swipe is one station, applied as a blink by the controller.
-- No Modux, no Vide: plain callbacks; the controller owns one and destroys it with the mode.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Poses = require(script.Parent.Poses)
local Pointer = require(script.Parent.Pointer)

type Rules = typeof(Content.Prep.Rules.Camera.Pan)

export type Zone = { X: number, Y: number, W: number, H: number }

export type Options = {
	Pointer: Pointer.Pointer,
	Rules: Rules,
	-- the trail of the seat (nil: the pan is off) and the index of the stop the controller stands on
	Trail: () -> Poses.Trail?,
	Stop: () -> number,
	-- camera retarget (eye, point looked at, field of view, spring omega)
	Goal: (eye: Vector3, look: Vector3, fov: number, omega: number) -> (),
	-- the pan settled on a stop: the controller changes the tab (or re-glides) there
	Commit: (index: number) -> (),
	-- the stop nearest to `u` right now, nil when none (the dots follow it); called when it changes
	Near: (index: number?) -> (),
	-- the mode is up and the chrome is on (not leaving, not forced out)
	Gate: () -> boolean,
	-- a tool is armed (the knife, a bottle...): no touch pan
	Armed: () -> boolean,
	-- a precision gesture runs, or the pointer positions a tool over the mat: no pan of any kind
	Precision: () -> boolean,
	-- something is in the hand (the Aim has a source): the edge scroll works, the stage does not change until it is let go
	Holding: () -> boolean,
	-- overlays that must not be scrolled under (Zones)
	Reserved: () -> { Zone },
	Reduced: () -> boolean,
}

export type Pan = {
	-- A pan, an edge scroll or a pending settle is going on.
	Active: (self: Pan) -> boolean,
	-- The controller moved the camera to stop `index` on its own (a tab, LB / RB, a station change): follow it.
	Sync: (self: Pan, index: number) -> (),
	Step: (self: Pan, dt: number) -> (),
	-- The current point of the trail, 0..1.
	U: (self: Pan) -> number,
	Destroy: (self: Pan) -> (),
}

type Mode = "Idle" | "Press" | "Drag" | "Edge"

-- GUIs that draw over the whole screen without being interface (their name or an ancestor's)
const PASS_THROUGH: { [string]: boolean } = { Vignette = true, PrepCursor = true, PrepVeil = true, Blackout = true, PanThrough = true }
const MAX_DT = 0.1
const VELOCITY_MIX = 0.35 -- share of the new sample in the smoothed release velocity

local function isPassThrough(object: Instance): boolean
	local node: Instance? = object
	while node ~= nil and not node:IsA("LayerCollector") do
		if PASS_THROUGH[node.Name] or node:GetAttribute("PanThrough") == true then
			return true
		end
		node = node.Parent
	end
	return node ~= nil and PASS_THROUGH[node.Name] == true
end

-- Does a GUI that draws (or takes a click) sit under this screen point? The empty world only has the transparent root of the shell.
local function overUi(px: Vector2): boolean
	const gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if gui == nil then
		return false
	end
	for _, object in gui:GetGuiObjectsAtPosition(px.X, px.Y) do
		if not object.Visible or isPassThrough(object) then
			continue
		end
		if object:IsA("GuiButton") then
			return true
		end
		if object.BackgroundTransparency < 0.9 then
			return true
		end
		if object:IsA("ImageLabel") and object.ImageTransparency < 0.9 and object.Image ~= "" then
			return true
		end
		if object:IsA("TextLabel") and object.TextTransparency < 0.9 and object.Text ~= "" then
			return true
		end
	end
	return false
end

local function insideZone(px: Vector2, zones: { Zone }): boolean
	for _, zone in zones do
		if zone.W > 0 and zone.H > 0 and px.X >= zone.X and px.X <= zone.X + zone.W and px.Y >= zone.Y and px.Y <= zone.Y + zone.H then
			return true
		end
	end
	return false
end

const Pan = {}

function Pan.new(options: Options): Pan
	const pointer = options.Pointer
	const rules = options.Rules
	const disconnect: { () -> () } = {}
	local mode: Mode = "Idle"
	local u = 0
	local pressPx = Vector2.zero
	local pressU = 0
	local lastU = 0
	local velocity = 0 -- u per second, smoothed
	local pending = false -- a settle waits for the hand to be empty
	local near = 0

	const self = {} :: any

	local function trail(): Poses.Trail?
		return options.Trail()
	end

	local function report(trailNow: Poses.Trail)
		-- the stop nearest to u, for the dots
		local best, bestDistance = 1, math.huge
		for index, stop in trailNow.Stops do
			const distance = math.abs(stop.U - u)
			if distance < bestDistance then
				best, bestDistance = index, distance
			end
		end
		if best ~= near then
			near = best
			options.Near(best)
		end
	end

	-- Camera goal at the current u.
	local function aim(trailNow: Poses.Trail)
		const eye, look, fov = Poses.Sample(trailNow, u)
		options.Goal(eye, look, fov, rules.Omega)
		report(trailNow)
	end

	-- studs of the work plane under one screen pixel, at the current camera
	local function studsPerPixel(trailNow: Poses.Trail): number
		const camera = workspace.CurrentCamera
		if camera == nil then
			return 0.01
		end
		const eye, look, fov = Poses.Sample(trailNow, u)
		const halfHeight = (eye - look).Magnitude * math.tan(math.rad(fov) / 2)
		const size = camera.ViewportSize
		return 2 * halfHeight * (size.X / math.max(size.Y, 1)) / math.max(size.X, 1)
	end

	-- Where the pan settles: the stop nearest to the landing point (the one it started on counts `Hold` closer), or the next one in
	-- the direction of a fling.
	local function settle(trailNow: Poses.Trail, fromSwipe: number?)
		pending = false
		mode = "Idle"
		const stops = trailNow.Stops
		const current = math.clamp(options.Stop(), 1, #stops)
		local pick = current
		if options.Reduced() then
			const size = if workspace.CurrentCamera ~= nil then workspace.CurrentCamera.ViewportSize.X else 800
			const moved = fromSwipe or 0
			if math.abs(moved) > size * 0.12 then
				pick = math.clamp(current + (if moved < 0 then 1 else -1), 1, #stops)
			end
		else
			const landing = u + velocity * rules.Inertia
			local bestDistance = math.huge
			for index, stop in stops do
				local distance = math.abs(landing - stop.U)
				if index == current then
					distance *= 1 - rules.Hold
				end
				if distance < bestDistance then
					pick, bestDistance = index, distance
				end
			end
			if pick == current and math.abs(velocity) * trailNow.Length >= rules.FlingMin then
				pick = math.clamp(current + (if velocity > 0 then 1 else -1), 1, #stops)
			end
		end
		velocity = 0
		u = stops[pick].U
		if pick ~= near then
			near = pick
			options.Near(pick)
		end
		options.Commit(pick)
	end

	local function release(trailNow: Poses.Trail, fromSwipe: number?)
		if options.Holding() then
			-- the sausage / plate in the hand: the camera stays where it is, the stage changes after the drop
			mode = "Idle"
			pending = true
			return
		end
		settle(trailNow, fromSwipe)
	end

	-- Down: only a press on empty space with nothing armed and nothing in the hand can begin a pan. The Aim hears the same press in
	-- its own task, so the decision is taken after it.
	table.insert(
		disconnect,
		pointer:OnDown(function(px: Vector2)
			task.defer(function()
				if mode ~= "Idle" or not pointer.Down or not options.Gate() or trail() == nil then
					return
				end
				if options.Holding() or options.Armed() or options.Precision() or overUi(px) then
					return
				end
				mode = "Press"
				pressPx = px
				pressU = u
				lastU = u
				velocity = 0
				pending = false
			end)
		end)
	)
	table.insert(
		disconnect,
		pointer:OnUp(function(px: Vector2)
			if mode == "Press" then
				mode = "Idle"
			elseif mode == "Drag" then
				const trailNow = trail()
				if trailNow ~= nil then
					release(trailNow, px.X - pressPx.X)
				else
					mode = "Idle"
				end
			end
		end)
	)

	-- the screen-edge direction (-1 left, 1 right, 0 none) and how deep (0..1) the pointer is in the zone
	local function edge(): (number, number)
		if pointer.Device ~= "Mouse" then
			return 0, 0
		end
		const camera = workspace.CurrentCamera
		if camera == nil then
			return 0, 0
		end
		const width = camera.ViewportSize.X
		const x = pointer.Position.X
		const zone = width * rules.Edge
		local direction, depth = 0, 0
		if x <= zone then
			direction, depth = -1, 1 - x / zone
		elseif x >= width - zone then
			direction, depth = 1, 1 - (width - x) / zone
		end
		if direction == 0 or depth <= 0 then
			return 0, 0
		end
		if insideZone(pointer.Position, options.Reserved()) or overUi(pointer.Position) then
			return 0, 0
		end
		return direction, math.clamp(depth, 0, 1)
	end

	function self.Active(_: any): boolean
		return mode ~= "Idle" or pending
	end

	function self.U(_: any): number
		return u
	end

	function self.Sync(_: any, index: number)
		const trailNow = trail()
		if trailNow == nil then
			return
		end
		const stop = trailNow.Stops[math.clamp(index, 1, #trailNow.Stops)]
		u = stop.U
		velocity = 0
		mode = "Idle"
		pending = false
		if near ~= index then
			near = index
			options.Near(index)
		end
	end

	function self.Step(_: any, dt: number)
		const trailNow = trail()
		if trailNow == nil or not options.Gate() then
			if mode ~= "Idle" then
				mode = "Idle"
			end
			return
		end
		const step = math.min(dt, MAX_DT)
		-- a precision gesture (or a tool positioned over the mat) stops everything that moves the camera
		if (mode == "Drag" or mode == "Edge" or mode == "Press") and options.Precision() then
			mode = "Idle"
			pending = false
			self:Sync(options.Stop())
			options.Commit(math.clamp(options.Stop(), 1, #trailNow.Stops))
			return
		end
		if mode == "Press" then
			if (pointer.Position - pressPx).Magnitude > rules.Slop then
				mode = "Drag"
				-- the world is held from where the finger is NOW, so the slop does not jump the view
				pressPx = pointer.Position
				pressU = u
			end
			return
		end
		if mode == "Drag" then
			if options.Reduced() then
				return
			end
			const perPixel = studsPerPixel(trailNow)
			const moved = (pointer.Position.X - pressPx.X) * perPixel
			u = math.clamp(pressU - moved / trailNow.Length, 0, 1)
			const sample = (u - lastU) / math.max(step, 1e-3)
			velocity = velocity * (1 - VELOCITY_MIX) + sample * VELOCITY_MIX
			lastU = u
			aim(trailNow)
			return
		end
		-- no press: the mouse at the border scrolls (also with something in the hand, never while a gesture runs)
		if not options.Reduced() and not options.Precision() and (mode == "Idle" or mode == "Edge") then
			const direction, depth = edge()
			if direction ~= 0 and not (pointer.Down and not options.Holding()) then
				mode = "Edge"
				pending = false
				const speed = rules.EdgeSpeed * depth * depth * (3 - 2 * depth)
				const before = u
				u = math.clamp(u + direction * speed * step / trailNow.Length, 0, 1)
				velocity = (u - before) / math.max(step, 1e-3)
				lastU = u
				aim(trailNow)
				return
			elseif mode == "Edge" then
				release(trailNow, nil)
				return
			end
		elseif mode == "Edge" then
			release(trailNow, nil)
			return
		end
		-- a settle that waited for the hand to be empty
		if pending and not options.Holding() then
			settle(trailNow, nil)
		end
	end

	function self.Destroy(_: any)
		for _, stop in disconnect do
			stop()
		end
		table.clear(disconnect)
	end

	return self :: Pan
end

return Pan
