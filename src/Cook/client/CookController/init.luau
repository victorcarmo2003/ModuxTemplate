--!strict
--[[
	CookController (kitchen-focus.md §2; owner 2026-10-19)

	The cooking focus on this client. The server accepts the station prompt (cook_focus) and sends CookOpen; this controller:
	  - moves the camera over the station (CameraController Prep mode: a glide, the mouse free) from the side the player stands,
	    looking at the top of the station (CamAnchor_Cook / Focus_Cook attachments inside the station win when authored);
	  - holds the "Cook" input context (world prompts hidden) and sinks walking; W A S D / arrows / Space, Backspace, Q, the
	    gamepad's B and the Back button leave; the station leaves by itself a moment after its step is over (Done);
	  - gives the station module (Board, Grill, Toppings) one pointer (mouse, touch, gamepad cursor), a folder for its local
	    props, a hint line and the grade pop, and sends its gestures as the Cook packet.
	The server decides everything (stock, plate, grill, scores clamped); the props are local and go with the focus.
]]
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Board = require(script.Board)
local Grill = require(script.Grill)
local Hud = require(script.Hud)
local Kit = require(script.Kit)
local Pointer = require(script.Pointer)
local Session = require(script.Session)
local Toppings = require(script.Toppings)

const HOLD = "Cook"
const FOCUS_ATTRIBUTE = "CookStation" -- local attribute on the own Player while a focus is open
const SINK_ACTION = "CookFocusSink"
const LEAVE_ACTION = "CookFocusLeave"
const SINK_PRIORITY = 3000
const FOV = 55
-- Framing (DEC-310, owner 2026-10-19: "the grill is too close"): the camera looks down at PITCH and backs off until the framed
-- box fits the screen with MARGIN around it, never closer than MIN_DISTANCE. Provisional, judged in Play.
const PITCH: { [string]: number } = { Board = math.rad(58), Grill = math.rad(55), Toppings = math.rad(52) }
const MARGIN = 1.35
const MIN_DISTANCE = 4.5
-- what else the camera frames with the station: the grill shows the rest rail its sausages go to, the board the two bun crates
const ALSO: { [string]: { string } } = { Grill = { "rail" }, Board = { "bun_crate", "board" } }
const NEAR = 9 -- studs: an ALSO station farther than this from the focused one is not framed
const PLATE_INSET = 0.45 -- studs from the table's front edge to the hot dog (Toppings)
const CEILING_GAP = 0.5 -- studs the camera keeps under a ceiling between it and the station
const TRAVEL = 0.45
const LEAVE_TRAVEL = 0.35
const DONE_DELAY = 1.1 -- s the result stays on screen before the focus leaves by itself
const GRADE_SHOW = 1.2 -- s the grade of a gesture stays
const WALK_KEYS: { Enum.KeyCode } = {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.Up,
	Enum.KeyCode.Down,
	Enum.KeyCode.Left,
	Enum.KeyCode.Right,
	Enum.KeyCode.Space,
}
const LEAVE_KEYS: { Enum.KeyCode } = { Enum.KeyCode.Backspace, Enum.KeyCode.Q, Enum.KeyCode.ButtonB }
-- the gamepad stick and buttons drive the cursor: never the character while focused
const PAD_SINK: { Enum.KeyCode } = { Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2 }
const SINK_KEYS: { Enum.KeyCode } = table.clone(WALK_KEYS)
for _, key in PAD_SINK do
	table.insert(SINK_KEYS, key)
end

type Station = "Board" | "Grill" | "Toppings"

type Active = {
	Station: Station,
	Session: Session.Session,
	Handler: Session.Handler,
	Pointer: Pointer.Pointer,
	Unmount: () -> (),
	Gui: Instance,
	Folder: Folder,
	Heartbeat: RBXScriptConnection,
}

const CookController = Modux.Controller("CookController", { Require = { "CameraController", "InputController" }, Priority = 640 })

function CookController:Setup()
	self.Active = nil :: Active?
	self.Hint = Vide.source("") :: Vide.Source<string>
	self.Grade = Vide.source(false :: string | false) :: Vide.Source<string | false>
	-- os.clock() at which the focus leaves by itself (the step is over), nil = not yet
	self.DoneAt = nil :: number?
	self.GradeToken = 0 :: number
	self.Scale = Vide.source(1) :: Vide.Source<number>
	-- NpcId -> order bitfield of each line (Customers set), for the held plate's order
	self.Orders = {} :: { [number]: { { [string]: boolean } } }
end

-- Reads -------------------------------------------------------------------------------------------------------------

function CookController:IsOpen(): boolean
	return self.Active ~= nil
end

-- The station open now ("Board" | "Grill" | "Toppings"), nil = none (the tutorial reads it)
function CookController:Station(): string?
	const active = self.Active
	return if active then active.Station else nil
end

function CookController:Held(): Tool?
	const character = Players.LocalPlayer.Character
	return if character then character:FindFirstChildOfClass("Tool") else nil
end

-- Topping keys of the order of the held plate's ticket line, nil = not known
function CookController:Order(): { string }?
	const held = self:Held()
	const ticket = if held then held:GetAttribute("Ticket") else nil
	if type(ticket) ~= "number" or ticket == 0 then
		return nil
	end
	const lines = self.Orders[ticket]
	if lines == nil then
		return nil
	end
	const line = held and held:GetAttribute("TicketLine")
	const order = lines[if line == 2 then 2 else 1]
	if order == nil then
		return nil
	end
	const out: { string } = {}
	for _, key in Content.Ingredients.ToppingKeys do
		if order[key] then
			table.insert(out, key)
		end
	end
	return out
end

-- Camera pose ----------------------------------------------------------------------------------------------------------

-- `flat` turned to the nearest horizontal side of the station (the counter's front), so the camera looks square at it and not
-- along the line from wherever the player stood
local function squared(target: Instance, flat: Vector3): Vector3
	const frame = if target:IsA("Model") then target:GetPivot() elseif target:IsA("BasePart") then target.CFrame else CFrame.identity
	local best, bestDot = flat, -math.huge
	for _, axis in { frame.RightVector, -frame.RightVector, frame.LookVector, -frame.LookVector } do
		const horizontal = Vector3.new(axis.X, 0, axis.Z)
		if horizontal.Magnitude < 0.5 then
			continue
		end
		const unit = horizontal.Unit
		const dot = unit:Dot(flat)
		if dot > bestDot then
			best, bestDot = unit, dot
		end
	end
	return best
end

-- The first solid surface on the way from `from` along `offset` (ignoring the own character and the focus props), nil = none
local function castAlong(from: Vector3, offset: Vector3): RaycastResult?
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = {}
	const character = Players.LocalPlayer.Character
	if character ~= nil then
		table.insert(ignore, character)
	end
	if Workspace.CurrentCamera ~= nil then
		table.insert(ignore, Workspace.CurrentCamera)
	end
	params.FilterDescendantsInstances = ignore
	return Workspace:Raycast(from, offset, params)
end

-- Where the hot dog rests on the condiment table: the middle of its front edge, on the surface found there (the slab between the
-- front pans), pulled back toward the middle while the ray finds no counter (an edge that overhangs the floor)
local function restSpot(top: Vector3, size: Vector3, toward: Vector3): Vector3
	const depth = math.abs(size.X * toward.X) + math.abs(size.Z * toward.Z)
	local inset = math.max(depth / 2 - PLATE_INSET, 0)
	for _ = 1, 10 do
		const probe = top + toward * inset
		const hit = castAlong(probe + Vector3.yAxis * 2, Vector3.yAxis * -(size.Y + 3.5))
		if hit ~= nil and hit.Position.Y > top.Y - size.Y - 0.5 then
			return Vector3.new(probe.X, hit.Position.Y, probe.Z)
		end
		inset = math.max(inset - 0.3, 0)
	end
	return top
end

-- What the camera frames: the station and its ALSO neighbours (by StationKind, within NEAR studs)
local function framed(station: Station, target: Instance, top: Vector3): { Instance }
	const list: { Instance } = { target }
	const kinds = ALSO[station]
	if kinds == nil then
		return list
	end
	for _, other in CollectionService:GetTagged("Station") do
		if other == target or not other:IsDescendantOf(Workspace) or table.find(kinds, other:GetAttribute("StationKind") :: any) == nil then
			continue
		end
		const at = Kit.Bounds(other)
		if (at - top).Magnitude <= NEAR then
			table.insert(list, other)
		end
	end
	return list
end

-- Distance from the look point that fits a box (half extents along screen right, toward the camera and up) in the view
local function fitDistance(halfWide: number, halfDeep: number, halfTall: number, pitch: number): number
	const camera = Workspace.CurrentCamera
	const viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	const aspect = math.max(viewport.X, 1) / math.max(viewport.Y, 1)
	const tanV = math.tan(math.rad(FOV) / 2)
	const tanH = tanV * aspect
	const projected = halfDeep * math.sin(pitch) + halfTall * math.cos(pitch)
	const distance = math.max(halfWide / tanH, projected / tanV) * MARGIN + halfDeep * math.cos(pitch)
	return math.max(distance, MIN_DISTANCE)
end

-- Top centre and size of the station, its horizontal "toward the player" and screen right, and the eye of the camera
function CookController:Pose(station: Station, target: Instance): (Vector3, Vector3, Vector3, Vector3, CFrame, Vector3)
	local top, size = Kit.Bounds(target)
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local toward = Vector3.new(0, 0, 1)
	if root ~= nil and root:IsA("BasePart") then
		const flat = Vector3.new(root.Position.X - top.X, 0, root.Position.Z - top.Z)
		if flat.Magnitude > 0.05 then
			toward = squared(target, flat.Unit)
		end
	end
	const right = (-toward):Cross(Vector3.yAxis).Unit
	-- the framed box (station + neighbours) in screen axes
	const boxTop, boxSize = Kit.BoundsOf(framed(station, target, top))
	const halfWide = (math.abs(boxSize.X * right.X) + math.abs(boxSize.Z * right.Z)) / 2
	const halfDeep = (math.abs(boxSize.X * toward.X) + math.abs(boxSize.Z * toward.Z)) / 2
	if station == "Toppings" then
		top = restSpot(top, size, toward)
	end
	const pitch = PITCH[station] or math.rad(55)
	-- the middle of the box, a little under its top; Toppings leans toward the hot dog (the work)
	local look = boxTop - Vector3.yAxis * (math.min(boxSize.Y, 1) * 0.5)
	if station == "Toppings" then
		look = look:Lerp(top, 0.4)
	end
	local distance = fitDistance(halfWide, halfDeep, math.min(boxSize.Y, 1.5) / 2, pitch)
	const back = toward * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	-- a low ceiling (lamps, the roof) between the station and the eye: the camera stays under it (the ray starts a stud out, clear
	-- of the station's own parts)
	const roof = if distance > 1 then castAlong(look + back, back * (distance - 1)) else nil
	if roof ~= nil then
		distance = math.max(roof.Distance + 1 - CEILING_GAP, 1.5)
	end
	local eye = look + back * distance
	const camAnchor = target:FindFirstChild("CamAnchor_Cook", true)
	const focusAnchor = target:FindFirstChild("Focus_Cook", true)
	if camAnchor ~= nil and camAnchor:IsA("Attachment") then
		eye = camAnchor.WorldPosition
	end
	if focusAnchor ~= nil and focusAnchor:IsA("Attachment") then
		look = focusAnchor.WorldPosition
	end
	return top, size, toward, right, CFrame.lookAt(eye, look), look
end

-- Focus --------------------------------------------------------------------------------------------------------------

-- The own body is between the camera and the station: hidden locally while focused (every frame: the camera layer may write it)
local function hideBody(hidden: boolean)
	const character = Players.LocalPlayer.Character
	if character == nil then
		return
	end
	const value = if hidden then 1 else 0
	for _, part in character:GetDescendants() do
		if (part:IsA("BasePart") or part:IsA("Decal")) and part.LocalTransparencyModifier ~= value then
			part.LocalTransparencyModifier = value
		end
	end
end

function CookController:ShowGrade(score: number)
	self.GradeToken += 1
	const token = self.GradeToken
	self.Grade(Grade.Band(Content.Prep, score))
	task.delay(GRADE_SHOW, function()
		if self.GradeToken == token then
			self.Grade(false)
		end
	end)
end

function CookController:Enter(station: Station, target: Instance)
	if self.Active ~= nil then
		self:Leave()
	end
	if target.Parent == nil then
		return
	end
	const camera = self.Dependencies.CameraController
	const top, size, toward, right, frame, look = self:Pose(station, target)
	camera:Prep(true, frame, { Fov = FOV, Travel = TRAVEL, Min = 0.25, Look = look })
	if Vide.untrack(camera.Mode) ~= "Prep" then
		return -- a cutscene / spectate owns the camera
	end
	const viewport = if Workspace.CurrentCamera then Workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
	self.Scale(Theme.ScaleOf(viewport))

	const folder = Instance.new("Folder")
	folder.Name = "CookFocus"
	folder.Parent = Workspace.CurrentCamera or Workspace
	self.Hint("")
	self.DoneAt = nil
	const pointer = Pointer.new()
	const session: Session.Session = {
		Target = target,
		Folder = folder,
		Top = top,
		Size = size,
		Right = right,
		Toward = toward,
		Hint = function(text: string)
			self.Hint(text)
		end,
		Graded = function(score: number)
			self:ShowGrade(score)
		end,
		Done = function()
			if self.DoneAt == nil then
				self.DoneAt = os.clock() + DONE_DELAY
			end
		end,
		Send = function(data: Session.Send)
			Restaurant.Cook:fireServer(data :: any)
		end,
		Held = function(): Tool?
			return self:Held()
		end,
		Records = function(): { [number]: any }
			const out: { [number]: any } = {}
			for id, record in self.Libs.Net.Stations:entries() do
				out[id] = record
			end
			return out
		end,
		Order = function(): { string }?
			return self:Order()
		end,
	}
	const module = if station == "Board" then Board elseif station == "Grill" then Grill else Toppings
	const handler = module.Start(session)
	pointer:On(function(kind: Pointer.Kind, position: Vector2)
		handler.Pointer(kind, position)
	end)

	const unmount, gui = Vide.root(function()
		const screen, dot = Hud.Screen({
			Hint = function()
				return self.Hint()
			end,
			Grade = function()
				return self.Grade()
			end,
			Scale = function()
				return self.Scale()
			end,
			OnBack = function()
				self:Leave()
			end,
		})
		pointer:SetDot(dot)
		return screen
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- walking leaves; the stick and the press buttons are the cursor's
	ContextActionService:BindActionAtPriority(SINK_ACTION, function(_name: string, state: Enum.UserInputState, input: InputObject)
		if state == Enum.UserInputState.Begin and table.find(WALK_KEYS, input.KeyCode) ~= nil then
			task.defer(function()
				self:Leave()
			end)
		end
		return Enum.ContextActionResult.Sink
	end, false, SINK_PRIORITY, table.unpack(SINK_KEYS))
	ContextActionService:BindActionAtPriority(LEAVE_ACTION, function(_name: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			task.defer(function()
				self:Leave()
			end)
		end
		return Enum.ContextActionResult.Sink
	end, false, SINK_PRIORITY, table.unpack(LEAVE_KEYS))
	self.Dependencies.InputController:Hold(HOLD, true)

	const active: Active = {
		Station = station,
		Session = session,
		Handler = handler,
		Pointer = pointer,
		Unmount = unmount,
		Gui = gui,
		Folder = folder,
		Heartbeat = RunService.Heartbeat:Connect(function(dt: number)
			const current = self.Active
			if current == nil then
				return
			end
			const character = Players.LocalPlayer.Character
			const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid == nil or humanoid.Health <= 0 or Vide.untrack(camera.Mode) ~= "Prep" or target.Parent == nil then
				self:Leave()
				return
			end
			hideBody(true)
			current.Handler.Step(dt)
			const doneAt = self.DoneAt
			if doneAt ~= nil and os.clock() >= doneAt then
				self:Leave()
			end
		end),
	}
	self.Active = active
	-- the tutorial reads it (TutorialController: which focus is open)
	Players.LocalPlayer:SetAttribute(FOCUS_ATTRIBUTE, station)
end

function CookController:Leave()
	const active = self.Active
	if active == nil then
		return
	end
	self.Active = nil
	Players.LocalPlayer:SetAttribute(FOCUS_ATTRIBUTE, nil)
	active.Heartbeat:Disconnect()
	pcall(active.Handler.Stop)
	active.Pointer:Destroy()
	active.Unmount()
	active.Gui:Destroy()
	active.Folder:Destroy()
	hideBody(false)
	ContextActionService:UnbindAction(SINK_ACTION)
	ContextActionService:UnbindAction(LEAVE_ACTION)
	self.Dependencies.InputController:Hold(HOLD, false)
	self.Hint("")
	self.Grade(false)
	self.DoneAt = nil
	self.Dependencies.CameraController:Prep(false, nil, { Travel = LEAVE_TRAVEL })
end

-- Orders of the Customers set (the held plate's order)
function CookController:WriteCustomer(id: number, record: any?)
	if record == nil then
		self.Orders[id] = nil
		return
	end
	const lines: { { [string]: boolean } } = { table.clone(record.Order) }
	if record.Order2 ~= nil then
		table.insert(lines, table.clone(record.Order2))
	end
	self.Orders[id] = lines
end

CookController:OnInit(function(self)
	self:Setup()
	Restaurant.CookOpen:onClient(function(data)
		const target = data.Target
		if typeof(target) == "Instance" then
			self:Enter(data.Station :: Station, target)
		end
	end)
	const customers = self.Libs.Net.Customers
	customers:onAdded(function(id, record)
		self:WriteCustomer(id, record)
	end)
	customers:onChanged(function(id, record)
		self:WriteCustomer(id, record)
	end)
	customers:onRemoved(function(id)
		self:WriteCustomer(id, nil)
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		self:Leave()
	end)
end)

return CookController
