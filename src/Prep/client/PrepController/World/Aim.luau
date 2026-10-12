--!strict
-- World/Aim: from the Pointer (mouse, first touch, gamepad cursor) to "which target, and what happened to it" (docs/tech/prep-3d.md
-- §2.1, §2.3, §9; TASK-196). It owns the ONE per-frame loop of the 3D layer (RenderStepped, connected in `new`, gone in
-- `Destroy`: the world creates it on Enter and destroys it on Leave); other layers hang a function on it with `OnFrame` instead of
-- connecting their own. What it does each frame, cheaply:
--   * at 10 Hz asks the registry to re-evaluate which targets are enabled and to size the hitboxes (Targets:Refresh)
--   * when the pointer moved, the camera moved or the enabled set changed: AT MOST ONE ray (Include, hitboxes only), then the
--     hover (Highlight), the marker and, while dragging, the Move message. A parked pointer costs nothing.
--   * a gamepad cursor that misses every hitbox is attracted to the nearest enabled target closer than Rules.World.Attract px
--     on the screen; `Next` (the X button) jumps the cursor to the next enabled target in the order of the stage
-- Press, Release and Up cast at once (they are rare). The stage hears everything as AimMsg through the listener (Hover, Press, Move,
-- Release, Drop, Tap, Cancel) and each target can carry its own Handlers. Nothing here sends a packet or touches money, stock or a
-- sale: it only says where the pointer is and what it did. No Modux, no Vide.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Pointer = require(script.Parent.Parent.Pointer)
local Highlight = require(script.Parent.Highlight)
local Marker = require(script.Parent.Marker)
local Plane = require(script.Parent.Plane)
local Ray = require(script.Parent.Ray)
local Targets = require(script.Parent.Targets)
local Types = require(script.Parent.Types)

-- The plane a drag is read on: the top of the bench (Y of the view focus); a carried thing floats `Rules.World.Lift` over it.
export type WorkPlane = { Origin: Vector3, Normal: Vector3 }

export type Options = {
	Pointer: Pointer.Pointer,
	Targets: Targets.Registry,
	Rules: Content.PrepWorldRules,
	Marker: Marker.Marker?,
	Highlight: Highlight.Outline?,
	-- Assist on? (hitboxes x1.3)
	Assist: () -> boolean,
	Listener: ((Types.AimMsg) -> ())?,
	-- `/dev prep ray`: print what every press hits
	Debug: (() -> boolean)?,
}

export type Aim = {
	-- Read-only state.
	Hovered: Types.Target?,
	Source: Types.Target?, -- the target the pointer is down on
	Last: Types.Hit, -- the last cast (reused table: do not keep it)
	SetListener: (self: Aim, listener: ((Types.AimMsg) -> ())?) -> (),
	SetWorkPlane: (self: Aim, plane: WorkPlane?) -> (),
	-- The bun top, only to print its uv in the debug line (the gestures get theirs from Plane.Region).
	SetBun: (self: Aim, plane: Plane.Plane?) -> (),
	-- The next enabled target in the order of the stage after the focus: moves the gamepad cursor onto it (X button).
	Next: (self: Aim) -> Types.Target?,
	-- Drops a drag in progress (tab change, leaving the mode).
	Cancel: (self: Aim, reason: string) -> (),
	-- Runs `fn(dt, time)` in the shared frame; returns the function that stops it.
	OnFrame: (self: Aim, fn: (dt: number, time: number) -> ()) -> () -> (),
	Destroy: (self: Aim) -> (),
}

const SLOP = 14 -- px: further than this from the press is a drag, not a tap (same as the Gestures tap)
const REFRESH = 0.1 -- s: the registry re-evaluates Enabled and the hitbox sizes
const FALLBACK_DISTANCE = 2.5 -- studs: where a point goes when the ray meets neither a target nor the work plane

const Aim = {}

local function kindOf(device: Pointer.Device): Types.PointerKind
	return if device == "Pad" then "Gamepad" elseif device == "Touch" then "Touch" else "Mouse"
end

function Aim.new(options: Options): Aim
	const pointer = options.Pointer
	const registry = options.Targets
	const rules = options.Rules
	const marker = options.Marker
	const outline = options.Highlight
	local listener = options.Listener
	local workPlane: WorkPlane? = nil
	local bun: Plane.Plane? = nil
	const connections: { () -> () } = {}
	const frames: { [(number, number) -> ()]: boolean } = {}
	const scratch: { Types.Target } = {}

	const hit: Types.Hit = { Target = nil, Position = Vector3.zero, Distance = 0 }
	local hovered: Types.Target? = nil
	local source: Types.Target? = nil
	local dragged = false
	local pressedPx = Vector2.zero
	local focusId = ""
	local seen = false -- the pointer has said something
	local dirty = false
	local time = 0
	local lastRefresh = -1
	local seenVersion = -1
	local lastCamera = CFrame.identity
	-- the last ray, kept for the debug line and the work point
	local rayOrigin = Vector3.zero
	local rayDirection = Vector3.zAxis
	local workPoint: Vector3? = nil

	const self = { Hovered = nil, Source = nil, Last = hit } :: any

	local function send(message: Types.AimMsg)
		if listener ~= nil then
			listener(message)
		end
	end

	local function isEnabled(target: Types.Target): boolean
		return registry:IsEnabled(target)
	end

	local function refresh(camera: Camera)
		lastRefresh = time
		registry:Refresh(camera, options.Assist())
		if registry.Version ~= seenVersion then
			seenVersion = registry.Version
			dirty = true
			if outline ~= nil then
				outline:Sync(registry:List(), isEnabled)
			end
		end
	end

	-- The point a drag is read on: the ray cut by the work plane (lifted while something is carried).
	local function planePoint(): Vector3?
		const plane = workPlane
		if plane == nil then
			return nil
		end
		const lift = if source ~= nil and dragged then rules.Lift else 0
		return Plane.Intersect(rayOrigin, rayDirection, plane.Origin + plane.Normal * lift, plane.Normal)
	end

	-- A gamepad cursor that touches no hitbox: the nearest enabled target within Rules.World.Attract px on the screen.
	local function attract(camera: Camera, px: Vector2): Types.Target?
		local best: Types.Target? = nil
		local bestDistance = rules.Attract
		for _, target in registry:List() do
			const part = target.Parts[1]
			if part == nil or not isEnabled(target) then
				continue
			end
			const screen, visible = Ray.Project(camera, part.Position)
			if visible then
				const distance = (screen - px).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					best = target
				end
			end
		end
		return best
	end

	-- One ray for a pointer point: fills `hit` and `workPoint`.
	local function cast(px: Vector2, device: Pointer.Device)
		const camera = workspace.CurrentCamera
		hit.Target = nil
		hit.Distance = 0
		workPoint = nil
		if camera == nil then
			return
		end
		rayOrigin, rayDirection = Ray.Of(camera, px, device)
		workPoint = planePoint()
		local position: Vector3? = nil
		if registry:HasEnabled() then
			const result = Ray.Cast(registry:Params(), rayOrigin, rayDirection)
			if result ~= nil then
				hit.Target = registry:ByPart(result.Instance)
				position = result.Position
				hit.Distance = result.Distance
			end
		end
		if hit.Target == nil and device == "Pad" then
			const near = attract(camera, px)
			if near ~= nil then
				hit.Target = near
				position = near.Parts[1].Position
				workPoint = position -- the marker snaps to what the cursor is pulled to
				hit.Distance = (position - rayOrigin).Magnitude
			end
		end
		hit.Position = position or workPoint or rayOrigin + rayDirection * FALLBACK_DISTANCE
	end

	local function setHover(target: Types.Target?, device: Pointer.Device)
		const previous = hovered
		if (previous == nil and target == nil) or (previous ~= nil and target ~= nil and previous.Target.Id == target.Target.Id) then
			return
		end
		hovered = target
		self.Hovered = target
		if outline ~= nil then
			outline:SetHover(target)
		end
		if previous ~= nil then
			const handlers = registry:Handlers(previous)
			if handlers ~= nil and handlers.Hover ~= nil then
				handlers.Hover(false)
			end
		end
		if target ~= nil then
			focusId = target.Target.Id
			const handlers = registry:Handlers(target)
			if handlers ~= nil and handlers.Hover ~= nil then
				handlers.Hover(true)
			end
		end
		send({ Kind = "Hover", Target = target, Previous = previous, Pointer = kindOf(device) })
	end

	-- Touch has no hover: its contour only follows the finger while it is down.
	local function hoverWanted(device: Pointer.Device): boolean
		return device ~= "Touch" or pointer.Down
	end

	local function showMarker(device: Pointer.Device)
		if marker == nil then
			return
		end
		const point = workPoint
		const wanted = point ~= nil and (device == "Pad" or pointer.Down)
		marker:SetVisible(wanted)
		if wanted and point ~= nil then
			marker:Place(point)
		end
		marker:SetHeld(source ~= nil)
	end

	local function describe(px: Vector2, device: Pointer.Device)
		const camera = workspace.CurrentCamera
		const mouse = UserInputService:GetMouseLocation()
		local uv = ""
		if bun ~= nil then
			const found = Plane.FromRay(bun, rayOrigin, rayDirection)
			if found ~= nil then
				uv = string.format(" uv=(%.3f, %.3f)", found.X, found.Y)
			else
				uv = " uv=miss"
			end
		end
		const viewport = if camera ~= nil then camera.ViewportSize else Vector2.zero
		const target = hit.Target
		print(
			string.format(
				"[prep ray] %s px=(%.0f, %.0f) viewport=(%.0f, %.0f) of (%.0f, %.0f) mouse=(%.0f, %.0f) hit=%s part=%s dist=%.2f world=(%.2f, %.2f, %.2f)%s",
				device,
				px.X,
				px.Y,
				Ray.ToViewport(px, device).X,
				Ray.ToViewport(px, device).Y,
				viewport.X,
				viewport.Y,
				mouse.X,
				mouse.Y,
				if target ~= nil then target.Target.Id else "none",
				if target ~= nil then target.Parts[1].Name else "-",
				hit.Distance,
				hit.Position.X,
				hit.Position.Y,
				hit.Position.Z,
				uv
			)
		)
	end

	local function onDown(px: Vector2)
		seen = true
		const camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		const device = pointer.Device
		refresh(camera)
		cast(px, device)
		dirty = false
		pressedPx = px
		dragged = false
		if options.Debug ~= nil and options.Debug() then
			describe(px, device)
		end
		const target = hit.Target
		if target == nil then
			source = nil
			self.Source = nil
			setHover(nil, device)
			showMarker(device)
			return
		end
		source = target
		self.Source = target
		setHover(target, device)
		const point = if hit.Target ~= nil then hit.Position else (workPoint or hit.Position)
		const handlers = registry:Handlers(target)
		if handlers ~= nil and handlers.Press ~= nil then
			handlers.Press(point)
		end
		send({ Kind = "Press", Target = target, Point = point, Pointer = kindOf(device) })
		showMarker(device)
	end

	local function onMove(px: Vector2)
		seen = true
		dirty = true
		if source ~= nil and not dragged and (px - pressedPx).Magnitude > SLOP then
			dragged = true
		end
	end

	local function onUp(px: Vector2)
		seen = true
		const camera = workspace.CurrentCamera
		const device = pointer.Device
		const held = source
		if camera ~= nil then
			cast(px, device)
		end
		dirty = false
		if held ~= nil then
			source = nil
			self.Source = nil
			const over = hit.Target
			const point = workPoint or hit.Position
			if not dragged then
				-- pressed and released in place
				const handlers = registry:Handlers(held)
				if handlers ~= nil and handlers.Tap ~= nil then
					handlers.Tap(point)
				end
				send({ Kind = "Tap", Target = held, Point = point })
			elseif over ~= nil and over.Target.Id ~= held.Target.Id then
				const handlers = registry:Handlers(over)
				if handlers ~= nil and handlers.Drop ~= nil then
					handlers.Drop(held, point)
				end
				send({ Kind = "Drop", Source = held, Over = over, Point = point })
			else
				send({ Kind = "Release", Source = held, Point = point })
			end
		end
		dragged = false
		setHover(if hoverWanted(device) then hit.Target else nil, device)
		showMarker(device)
	end

	local function step(dt: number)
		time += dt
		const camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		if time - lastRefresh >= REFRESH then
			refresh(camera)
		end
		if camera.CFrame ~= lastCamera then
			lastCamera = camera.CFrame
			dirty = true
		end
		-- at most one ray per frame, and none while the pointer is parked
		if dirty and seen then
			dirty = false
			const device = pointer.Device
			cast(pointer.Position, device)
			if source ~= nil then
				const over = hit.Target
				if dragged then
					send({
						Kind = "Move",
						Source = source,
						Point = workPoint or hit.Position,
						Over = if over ~= nil and over.Target.Id ~= source.Target.Id then over else nil,
					})
				end
				-- the drop candidate is the contour while something is carried
				setHover(if dragged and over ~= nil and over.Target.Id ~= source.Target.Id then over else source, device)
			else
				setHover(if hoverWanted(device) then hit.Target else nil, device)
			end
			showMarker(device)
		end
		if outline ~= nil then
			outline:Step(time)
		end
		for fn in frames do
			fn(dt, time)
		end
	end

	table.insert(connections, pointer:OnDown(onDown))
	table.insert(connections, pointer:OnMove(onMove))
	table.insert(connections, pointer:OnUp(onUp))
	const frame = RunService.RenderStepped:Connect(step)
	table.insert(connections, function()
		frame:Disconnect()
	end)

	function self.SetListener(_: any, fn: ((Types.AimMsg) -> ())?)
		listener = fn
	end

	function self.SetWorkPlane(_: any, plane: WorkPlane?)
		workPlane = plane
		if plane ~= nil and marker ~= nil then
			marker:SetNormal(plane.Normal)
		end
		dirty = true
	end

	function self.SetBun(_: any, plane: Plane.Plane?)
		bun = plane
	end

	function self.Next(_: any): Types.Target?
		const camera = workspace.CurrentCamera
		if camera == nil then
			return nil
		end
		table.clear(scratch)
		for _, target in registry:List() do
			if isEnabled(target) then
				table.insert(scratch, target)
			end
		end
		if #scratch == 0 then
			return nil
		end
		local index = 0
		for position, target in scratch do
			if target.Target.Id == focusId then
				index = position
				break
			end
		end
		const next = scratch[index % #scratch + 1]
		focusId = next.Target.Id
		const part = next.Parts[1]
		if part ~= nil then
			const screen, visible = Ray.Project(camera, part.Position)
			if visible then
				pointer:Inject("Move", screen, "Pad")
			end
		end
		return next
	end

	function self.Cancel(_: any, reason: string)
		const held = source
		source = nil
		self.Source = nil
		dragged = false
		if held ~= nil then
			send({ Kind = "Cancel", Source = held, Reason = reason })
		end
		if marker ~= nil then
			marker:SetHeld(false)
		end
	end

	function self.OnFrame(_: any, fn: (dt: number, time: number) -> ()): () -> ()
		frames[fn] = true
		return function()
			frames[fn] = nil
		end
	end

	function self.Destroy(_: any)
		for _, disconnect in connections do
			disconnect()
		end
		table.clear(connections)
		table.clear(frames)
		table.clear(scratch)
		source = nil
		hovered = nil
		listener = nil
	end

	return self :: Aim
end

return Aim
