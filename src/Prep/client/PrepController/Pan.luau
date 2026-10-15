--!strict
-- Pan: free navigation along the trail of stations of the 3D prep mode (feedback 2026-10-12, H; made free the same day). The trail is the
-- list of poses of the tabs of the current set (Poses.Trail: Grill -> Board -> Toppings, it follows Content.Prep.Tabs), `u` 0..1 is ANY
-- point on it (no magnet, it stops where the hand stops) and the camera is cut to the blend of the poses around `u` every frame
-- (CameraController:PrepGoal with no spring, so the drag is 1:1 with the finger; the smoothness is in `u`). Inputs that move `u`:
--   * a press on EMPTY space dragged sideways (touch and mouse): the world follows the pointer; on release the speed only decays
--     (`Decay`), nothing snaps
--   * the mouse at the left / right border of the screen (Rules.Camera.Pan.Edge of the width, speed rising smoothly toward the border),
--     also while a sausage or a plate is dragged; never over the chrome (a GUI that draws, a Zones overlay)
--   * LB / RB and the dots are plain tab changes (the controller glides the camera there): they only tell this module (Sync)
-- The ACTIVE station (stage, targets, hint) is the nearest one to `u` with a little hysteresis (`Hyst`) and changes while you move; while
-- something is in the hand it waits for the drop so the drag is not cancelled. NEVER while the player positions or pours a topping or
-- makes a precision gesture (cut, sauce): the touch pan needs that no tool is armed, and everything stops while `Precision` is true.
-- Reduced motion: no live movement; a sideways swipe is one station, applied by the controller as a blink.
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
	-- the trail of the seat (nil: the pan is off) and the index of the stop that is the active station now
	Trail: () -> Poses.Trail?,
	Stop: () -> number,
	-- camera retarget, a cut (eye, point looked at, field of view)
	Goal: (eye: Vector3, look: Vector3, fov: number) -> (),
	-- the active station changes to stop `index`. `live` = the camera is where the pan put it (do not glide it); false = a swipe of
	-- reduced motion, the controller glides / blinks there
	Commit: (index: number, live: boolean) -> (),
	-- the stop nearest to `u`, nil when none (the dots follow it); called when it changes
	Near: (index: number?) -> (),
	-- the mode is up and the chrome is on (not leaving, not forced out)
	Gate: () -> boolean,
	-- a tool is armed (the knife, a bottle...): no touch pan
	Armed: () -> boolean,
	-- a precision gesture runs, or the pointer positions a tool over the mat: no pan of any kind
	Precision: () -> boolean,
	-- something is in the hand (the Aim has a source): the edge scroll works, the active station waits for the drop
	Holding: () -> boolean,
	-- overlays that must not be scrolled under (Zones)
	Reserved: () -> { Zone },
	Reduced: () -> boolean,
}

export type Pan = {
	-- A pan, an edge scroll or a coast is going on.
	Active: (self: Pan) -> boolean,
	-- The controller moved the camera to stop `index` on its own (a tab, LB / RB, a dot): follow it.
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
const VELOCITY_MIX = 0.4 -- share of the new sample in the smoothed release velocity
const STALE = 0.08 -- s: a pointer that stood still this long before the release does not throw the camera

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
	local perPixel = 0.01 -- studs of the work plane under one pixel, fixed at the start of a drag (1:1 with the pointer)
	local velocity = 0 -- u per second, smoothed
	local lastMove = 0
	local lastPx = Vector2.zero
	local coasting = false
	local dirty = false -- the active station may need to change
	local near = 0

	const self = {} :: any

	local function trail(): Poses.Trail?
		return options.Trail()
	end

	-- the stop nearest to u, the active one counting `Hyst` closer
	local function nearest(trailNow: Poses.Trail, active: number): number
		local best, bestDistance = active, math.huge
		for index, stop in trailNow.Stops do
			local distance = math.abs(stop.U - u)
			if index ~= active then
				distance += rules.Hyst
			end
			if distance < bestDistance then
				best, bestDistance = index, distance
			end
		end
		return best
	end

	local function report(trailNow: Poses.Trail)
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

	-- Camera cut to the blend at the current u.
	local function aim(trailNow: Poses.Trail)
		const eye, look, fov = Poses.Sample(trailNow, u)
		options.Goal(eye, look, fov)
		report(trailNow)
		dirty = true
	end

	-- The active station follows u (never while something is in the hand: the drag must not be cancelled).
	local function follow(trailNow: Poses.Trail)
		if not dirty or options.Holding() then
			return
		end
		dirty = false
		const current = math.clamp(options.Stop(), 1, #trailNow.Stops)
		const pick = nearest(trailNow, current)
		if pick ~= current then
			options.Commit(pick, true)
		end
	end

	-- studs of the work plane under one screen pixel, at the current point of the trail
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

	-- Reduced motion: a sideways swipe is one station.
	local function swipe(trailNow: Poses.Trail, moved: number)
		mode = "Idle"
		const size = if workspace.CurrentCamera ~= nil then workspace.CurrentCamera.ViewportSize.X else 800
		const current = math.clamp(options.Stop(), 1, #trailNow.Stops)
		if math.abs(moved) > size * 0.12 then
			options.Commit(math.clamp(current + (if moved < 0 then 1 else -1), 1, #trailNow.Stops), false)
		end
	end

	-- Release: the speed only decays (coast); nothing is pulled to a station.
	local function release(trailNow: Poses.Trail, px: Vector2?)
		if options.Reduced() then
			swipe(trailNow, if px ~= nil then px.X - pressPx.X else 0)
			return
		end
		mode = "Idle"
		if os.clock() - lastMove > STALE then
			velocity = 0
		end
		coasting = math.abs(velocity) * trailNow.Length > rules.StopSpeed
		if not coasting then
			velocity = 0
		end
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
				coasting = false
				pressPx = px
				pressU = u
				lastPx = px
				velocity = 0
				lastMove = os.clock()
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
					release(trailNow, px)
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
		return mode ~= "Idle" or coasting
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
		coasting = false
		mode = "Idle"
		dirty = false
		if near ~= index then
			near = index
			options.Near(index)
		end
	end

	function self.Step(_: any, dt: number)
		const trailNow = trail()
		if trailNow == nil or not options.Gate() then
			mode = "Idle"
			coasting = false
			return
		end
		const step = math.min(dt, MAX_DT)
		-- a precision gesture (or a tool positioned over the mat) stops everything that moves the camera
		if (mode ~= "Idle" or coasting) and options.Precision() then
			mode = "Idle"
			coasting = false
			velocity = 0
			follow(trailNow)
			return
		end
		if mode == "Press" then
			if (pointer.Position - pressPx).Magnitude > rules.Slop then
				mode = "Drag"
				-- the world is held from where the press was: every pixel moved counts (the slop is not lost)
				lastPx = pointer.Position
				perPixel = studsPerPixel(trailNow)
			end
			return
		end
		if mode == "Drag" then
			if options.Reduced() then
				return
			end
			const before = u
			u = math.clamp(pressU - (pointer.Position.X - pressPx.X) * perPixel / trailNow.Length, 0, 1)
			if pointer.Position ~= lastPx then
				lastPx = pointer.Position
				lastMove = os.clock()
			end
			const sample = (u - before) / math.max(step, 1e-3)
			velocity = velocity * (1 - VELOCITY_MIX) + sample * VELOCITY_MIX
			aim(trailNow)
			follow(trailNow)
			return
		end
		-- no press: the mouse at the border scrolls (also with something in the hand, never while a gesture runs)
		if not options.Reduced() and not options.Precision() and (mode == "Idle" or mode == "Edge") then
			const direction, depth = edge()
			if direction ~= 0 and not (pointer.Down and not options.Holding()) then
				mode = "Edge"
				coasting = false
				const speed = rules.EdgeSpeed * depth * depth * (3 - 2 * depth)
				const before = u
				u = math.clamp(u + direction * speed * step / trailNow.Length, 0, 1)
				velocity = (u - before) / math.max(step, 1e-3)
				aim(trailNow)
				follow(trailNow)
				return
			elseif mode == "Edge" then
				-- out of the zone: the scroll coasts to a stop like a release
				mode = "Idle"
				coasting = math.abs(velocity) * trailNow.Length > rules.StopSpeed
				if not coasting then
					velocity = 0
				end
			end
		elseif mode == "Edge" then
			mode = "Idle"
			coasting = false
			velocity = 0
		end
		-- coasting: the speed decays, the camera goes on with it and stops anywhere
		if coasting then
			velocity *= math.exp(-rules.Decay * step)
			u += velocity * step
			if u <= 0 or u >= 1 then
				u = math.clamp(u, 0, 1)
				velocity = 0
			end
			if math.abs(velocity) * trailNow.Length <= rules.StopSpeed then
				coasting = false
				velocity = 0
			end
			aim(trailNow)
		end
		follow(trailNow)
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
