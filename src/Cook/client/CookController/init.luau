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
local GuiService = game:GetService("GuiService")
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
local Juice = require(script.Juice)
local Paw = require(script.Paw)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)
local Pointer = require(script.Pointer)
local Session = require(script.Session)
local Toppings = require(script.Toppings)

const HOLD = "Cook"
const FOCUS_ATTRIBUTE = "CookStation" -- local attribute on the own Player while a focus is open
const BACK_HINT = "CookBackHint" -- local attribute the tutorial sets: pulse the Back button (DEC-311)
const HUD_LEAN = "HudLean" -- local attribute of HudController: lean tutorial HUD, the hint line stays off (owner 2026-10-19)
const SINK_ACTION = "CookFocusSink"
const LEAVE_ACTION = "CookFocusLeave"
const SINK_PRIORITY = 3000
const FOV = 55
-- Framing (DEC-310, owner 2026-10-19: "the grill is too close"): the camera looks down at PITCH and backs off until the framed
-- box fits the screen with MARGIN around it, never closer than MIN_DISTANCE. Provisional, judged in Play.
-- owner 2026-10-20 ("n coloca muito de cima não... mais baixa e olhando para a grelha"): grill 55 -> 40, board 58 -> 45
const PITCH: { [string]: number } = { Board = math.rad(45), Grill = math.rad(40), Toppings = math.rad(52) }
-- owner 2026-10-20 ("a tela do cachorro quente tá muito afastada, pode aproximar mais?"): 1.35 left a third of the screen to
-- floor and wall; the box now fills ~90% of the limiting side
const MARGIN = 1.1
const MIN_DISTANCE = 3
-- what else the camera frames with the station: the grill shows the rest rail its sausages go to, the board the two bun crates
-- (DEC-311: the grill sits in the middle, the sausage box on its left and the rest rail on its right)
const ALSO: { [string]: { string } } = { Grill = { "sausage_stock", "rail" }, Board = { "bun_crate", "board" } }
-- stations the camera centres on (the neighbours fit around them, the frame as wide as the farther one)
const CENTRED: { [string]: boolean } = { Grill = true, Board = true }
-- owner 2026-10-20 ("muito afastado ainda"): the box, grill and rail make a row five grills wide, so the whole row kept the grill
-- small. A centred station now frames only PEEK studs of each neighbour past the gap (the box's lid and front, the rail's first
-- places: clicks on the box and on a ready sausage do the same as the drags). Provisional, judged in Play
const PEEK = 0.9
const NEAR = 9 -- studs: an ALSO station farther than this from the focused one is not framed
const PLATE_INSET = 0.45 -- studs from the table's front edge to the hot dog (Toppings)
const CEILING_GAP = 0.5 -- studs the camera keeps under a ceiling between it and the station
const FOV_MAX = 80 -- the field of view may open up to this when a ceiling holds the camera closer than the fit
const TRAVEL = 0.45
const LEAVE_TRAVEL = 0.35
const DONE_DELAY = 1.1 -- s the result stays on screen before the focus leaves by itself
const GRADE_SHOW = 1.2 -- s the grade of a gesture stays
const NICE = 70 -- a gesture score from here to Perfect pops "Nice!" (DEC-311; the plate bands stay Perfect / Good / Messy)
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

const CookController =
	Modux.Controller("CookController", { Require = { "CameraController", "InputController", "AudioController" }, Priority = 640 })

function CookController:Setup()
	self.Active = nil :: Active?
	self.Hint = Vide.source("") :: Vide.Source<string>
	self.Grade = Vide.source(false :: string | false) :: Vide.Source<string | false>
	-- the live bar of the gesture in progress (Session.Progress), false = hidden
	self.Progress = Vide.source(false :: number | false) :: Vide.Source<number | false>
	-- os.clock() at which the focus leaves by itself (the step is over), nil = not yet
	self.DoneAt = nil :: number?
	self.GradeToken = 0 :: number
	self.Scale = Vide.source(1) :: Vide.Source<number>
	-- os.clock() while a focus is open (the Back button's pulse, DEC-311)
	self.Pulse = Vide.source(0) :: Vide.Source<number>
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

-- The camera's horizontal "toward" (owner 2026-10-19: from the side of the grill the view ran along the counter): square to the
-- LONG side of the framed box (the counter the stations stand on), on the side the player stands (+Z/+X when the player is right
-- on the line)
local function facing(boxSize: Vector3, from: Vector3, player: Vector3?): Vector3
	const alongX = boxSize.X >= boxSize.Z
	const offset = if player ~= nil then player - from else Vector3.zero
	if alongX then
		return Vector3.new(0, 0, if offset.Z < 0 then -1 else 1)
	end
	return Vector3.new(if offset.X < 0 then -1 else 1, 0, 0)
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

-- Top centre and size of the station, its horizontal "toward the player" and screen right, the eye of the camera and its FOV
function CookController:Pose(station: Station, target: Instance): (Vector3, Vector3, Vector3, Vector3, CFrame, Vector3, number)
	local top, size = Kit.Bounds(target)
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	-- the framed box (station + neighbours): the camera faces its long side
	const framedList = framed(station, target, top)
	const boxTop, boxSize = Kit.BoundsOf(framedList)
	const toward = facing(boxSize, boxTop, if root ~= nil and root:IsA("BasePart") then root.Position else nil)
	const right = (-toward):Cross(Vector3.yAxis).Unit
	local halfWide = (math.abs(boxSize.X * right.X) + math.abs(boxSize.Z * right.Z)) / 2
	local halfDeep = (math.abs(boxSize.X * toward.X) + math.abs(boxSize.Z * toward.Z)) / 2
	if CENTRED[station] then
		-- centred on the station: its own width and depth plus PEEK studs of each neighbour past the gap
		halfDeep = (math.abs(size.X * toward.X) + math.abs(size.Z * toward.Z)) / 2
		halfWide = (math.abs(size.X * right.X) + math.abs(size.Z * right.Z)) / 2
		for _, other in framedList do
			if other == target then
				continue
			end
			const at, otherSize = Kit.Bounds(other)
			const otherHalf = (math.abs(otherSize.X * right.X) + math.abs(otherSize.Z * right.Z)) / 2
			const inner = math.abs((at - top):Dot(right)) - otherHalf
			halfWide = math.max(halfWide, inner + math.min(PEEK, otherHalf * 2))
		end
	end
	if station == "Toppings" then
		top = restSpot(top, size, toward)
	end
	const pitch = PITCH[station] or math.rad(55)
	-- the middle of the box, a little under its top; Toppings leans toward the hot dog (the work)
	local look = (if CENTRED[station] then Vector3.new(top.X, boxTop.Y, top.Z) else boxTop) - Vector3.yAxis * (math.min(boxSize.Y, 1) * 0.5)
	if station == "Toppings" then
		look = look:Lerp(top, 0.4)
	end
	local distance = fitDistance(halfWide, halfDeep, math.min(boxSize.Y, 1.5) / 2, pitch)
	const fitted = distance
	const back = toward * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	-- a low ceiling (lamps, the roof) between the station and the eye: the camera stays under it (the ray starts a stud out, clear
	-- of the station's own parts)
	const roof = if distance > 1 then castAlong(look + back, back * (distance - 1)) else nil
	if roof ~= nil then
		distance = math.max(roof.Distance + 1 - CEILING_GAP, 1.5)
	end
	local eye = look + back * distance
	-- held closer by the ceiling: the view opens so the same box still fits
	local fov = FOV
	if distance < fitted then
		fov = math.min(math.deg(2 * math.atan(math.tan(math.rad(FOV) / 2) * fitted / distance)), FOV_MAX)
	end
	const camAnchor = target:FindFirstChild("CamAnchor_Cook", true)
	const focusAnchor = target:FindFirstChild("Focus_Cook", true)
	if camAnchor ~= nil and camAnchor:IsA("Attachment") then
		eye = camAnchor.WorldPosition
	end
	if focusAnchor ~= nil and focusAnchor:IsA("Attachment") then
		look = focusAnchor.WorldPosition
	end
	return top, size, toward, right, CFrame.lookAt(eye, look), look, fov
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

-- The band a gesture score shows: the plate bands plus the gesture-only "Nice" (DEC-311)
local function bandOf(score: number): string
	const band = Grade.Band(Content.Prep, score)
	return if band == "Good" and score >= NICE then "Nice" else band
end

const POPUP_TEXT: { [string]: string } = { Perfect = "Perfect!", Nice = "Nice!", Good = "Good", Messy = "Oops!" }
const GRADE_SOUND: { [string]: string } = { Perfect = "buy", Nice = "ticket_pop", Good = "ticket_pop", Messy = "ticket_pop" }

-- The grade of a gesture: at a world point it floats up from there with particles and a sound (owner 2026-10-19: more feedback),
-- else it pops in the middle of the screen
function CookController:Feedback(juice: Juice.Juice, score: number, at: Vector3?)
	const band = bandOf(score)
	juice:Sound(GRADE_SOUND[band] or "ticket_pop")
	if at == nil then
		self:ShowGrade(score)
		return
	end
	juice:Popup(at, band, POPUP_TEXT[band] or band)
	juice:Celebrate(at, band)
end

function CookController:ShowGrade(score: number)
	self.GradeToken += 1
	const token = self.GradeToken
	self.Grade(bandOf(score))
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
	const top, size, toward, right, frame, look, fov = self:Pose(station, target)
	camera:Prep(true, frame, { Fov = fov, Travel = TRAVEL, Min = 0.25, Look = look })
	if Vide.untrack(camera.Mode) ~= "Prep" then
		return -- a cutscene / spectate owns the camera
	end
	const viewport = if Workspace.CurrentCamera then Workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
	self.Scale(Theme.ScaleOf(viewport))

	const folder = Instance.new("Folder")
	folder.Name = "CookFocus"
	folder.Parent = Workspace.CurrentCamera or Workspace
	self.Hint("")
	self.Progress(false)
	self.DoneAt = nil
	const pointer = Pointer.new()
	const paw = Paw.new(folder)
	const juice = Juice.new(folder, self.Dependencies.AudioController)
	-- the grill's smoke reads as one dot from this close: it grows and comes more often while focused
	Fx.SetNear(true)
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
		Graded = function(score: number, at: Vector3?)
			self:Feedback(juice, score, at)
		end,
		Progress = function(fraction: number?)
			self.Progress(if fraction ~= nil then fraction else false)
		end,
		Juice = juice,
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
		Paw = paw,
	}
	const module = if station == "Board" then Board elseif station == "Grill" then Grill else Toppings
	const handler = module.Start(session)
	pointer:On(function(kind: Pointer.Kind, position: Vector2)
		handler.Pointer(kind, position)
	end)

	const unmount, gui = Vide.root(function()
		const screen, dot = Hud.Screen({
			Hint = function()
				-- read each frame through the pulse clock (the attribute is HudController's)
				self.Pulse()
				return if Players.LocalPlayer:GetAttribute(HUD_LEAN) == true then "" else self.Hint()
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
			BackHint = function(): number?
				-- read each frame through the pulse clock (the attribute is the tutorial's)
				const clock = self.Pulse()
				return if Players.LocalPlayer:GetAttribute(BACK_HINT) == true then clock else nil
			end,
			Progress = function(): number?
				const value = self.Progress()
				return if value ~= false then value else nil
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
	-- owner 2026-10-20: the stick sat under Back on a phone and walking does nothing here; the jump goes with it
	GuiService.TouchControlsEnabled = false

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
			self.Pulse(os.clock())
			current.Handler.Step(dt)
			paw:Step(dt)
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
	active.Session.Paw:Destroy()
	active.Pointer:Destroy()
	active.Unmount()
	active.Gui:Destroy()
	active.Folder:Destroy()
	Fx.SetNear(false)
	hideBody(false)
	ContextActionService:UnbindAction(SINK_ACTION)
	ContextActionService:UnbindAction(LEAVE_ACTION)
	self.Dependencies.InputController:Hold(HOLD, false)
	GuiService.TouchControlsEnabled = true
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
