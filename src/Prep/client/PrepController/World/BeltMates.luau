--!strict
-- World/BeltMates: the plates of the conveyor seen in the world (TASK-519; Q-379 A, Q-380 A; tech/prep-conveyor.md §3,
-- network.md §19, MAP-01-r4 §16.5 a). Presentation only, local only: it reads the set PrepSeats and decides nothing.
--   Source   the PrepSeats records of the belt seats (Content.Prep.Conveyor.Seats.Belt), read with :get at POLL (no
--            responder here: the set is the controller's, and a late joiner simply reads the state the set already has).
--            Stop = stop 1..#Conveyor.Stops, Wait = 0 on the stop / 1 beside it on the left (WaitL_n) / 2 on the right
--            (WaitR_n), Ticket = NpcId of the plate's ticket, Plate = the content mask (Prep/shared/PlateMask), Away = the
--            owner left the seat and the plate is parked and reserved there.
--   Draws    one plate per belt record: the plate (kit Tool `plate`, else a Cream placeholder 1,8 x 0,12 x 1,0, AST-162)
--            with its Rim in the owner's crew colour (Crew/shared/CrewColor = Presence.Palette, never red), the content
--            on it (kit bun_sliced / hot_dog + HotDogVisual toppings, else drawn parts), and a tag over it: the ticket #n
--            (Customers.Number; "?" for an orphan) in a chip of his colour, his name, "Waiting" (Texts.BeltWait) while the
--            plate waits beside a busy stop. A parked plate (Away) has a faded card.
--   Moves    a stop / wait change slides the plate to its new anchor in MOVE s (ease out), well under the 0,3 s of the
--            acceptance; a new record (late join, a seat taken) appears directly on its anchor.
--   Skips    the own plate while the local player is IN the focus (own record without Away): World/Belt.luau (TASK-518)
--            draws that one with its prediction. Outside the focus the own parked plate is drawn here like the others.
--   Never    a plate whose record is gone, whose User is 0, whose Stop is 0 / nil or whose owner is no longer in the
--            server: it is destroyed the same poll (no ghost plate after the owner leaves).
-- Anchors: Binding.Stop / WaitLeft / WaitRight (formats, n = stop) searched inside the bench Model Binding.Model
-- (Mount_Belt, MAP-01-r4 §16.5 a) and, if not there, inside its parent (BENCH2). Attachment, BasePart or Model. A missing
-- wait anchor (WaitR_4 does not exist) falls back to the stop +/- WAIT_GAP along the belt. No bench = nothing drawn.
-- Mounted ONCE by World/Ghost.Mount (from PrepController:OnInit), so it runs in the world as well as in the focus. Inert
-- while Content.Prep.Rules.Mode ~= "Conveyor" (the trailer is unchanged). Its folder sits under the camera.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Content = require(ReplicatedStorage.shared.Content)
local CrewColor = require(ReplicatedStorage.shared.Crew.CrewColor)
local HotDogVisual = require(ReplicatedStorage.shared.Item.HotDogVisual)
local PlateMask = require(ReplicatedStorage.shared.Prep.PlateMask)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

const prep = Content.Prep
const conveyor = prep.Conveyor
const binding = conveyor.Binding
const presence = prep.Rules.World.Presence
const STOP_COUNT = #conveyor.Stops.List

const FOLDER_NAME = "PrepBeltMates"
const POLL = 1 / 20 -- s between two reads of the belt records (20 Hz: the stop change shows in <= 0,05 s + MOVE)
const MOVE = 0.22 -- s the plate takes to slide to its new anchor
const RESOLVE = 2 -- s between two searches of the bench (missing bench) / two refreshes of the anchor cache
const WAIT_GAP = 2.1 -- studs: a wait anchor the map lacks = the stop +/- this along the belt (MAP-01-r4 §16.5 a)
const PLATE_SIZE = Vector3.new(1.8, 0.12, 1.0) -- AST-162 placeholder
const RIM_SIZE = Vector3.new(1.9, 0.06, 1.1)
const TAG_LIFT = 1.4 -- studs over the plate
const TAG_WIDTH = 156 -- px (fixed in pixels: legible on a 667 x 375 phone at any distance up to Presence.Range)
const TAG_HEIGHT = 52
const AWAY_CARD = 0.4 -- BackgroundTransparency of a parked plate's card
const UNKNOWN_TICKET = "?" -- orphan ticket (the customer left), like the HUD of prep-conveyor.md §6.3
const PLATE_COLOR = Theme.Color.Cream
const BUN_COLOR = Color3.fromHex("#E8B36B")
const DOG_COLOR = Color3.fromHex("#C8553D")

-- What this module reads of a PrepSeats record (Net/init.luau prepSeatRecord)
type SeatRecord = {
	User: number,
	Ticket: number,
	Plate: number?,
	Stop: number?,
	Wait: number?,
	Line: number?,
	Away: boolean?,
}

type Puppet = {
	Seat: number,
	User: number,
	Root: Model,
	Plate: Model,
	PlateTop: number, -- studs from the base to the top of the plate
	Food: Model?,
	FoodMask: number,
	Tag: BillboardGui,
	Card: Frame,
	Stroke: UIStroke,
	Chip: Frame,
	Number: TextLabel,
	Name: TextLabel,
	Note: TextLabel,
	From: Vector3,
	To: Vector3,
	Pos: Vector3,
	Dir: Vector3,
	T: number,
}

const BeltMates = {}

local net: any = nil
local folder: Folder? = nil
local connection: RBXScriptConnection? = nil
local bench: Instance? = nil
local resolveIn = 0
local pollIn = 0
local warned = false
const anchorCache: { [string]: Vector3 | false } = {}
const puppets: { [number]: Puppet } = {}

const beltSeats: { number } = table.clone(conveyor.Seats.Belt)

-- Anchors -------------------------------------------------------------------------------------------------------------------

local function findBench(): Instance?
	if bench ~= nil and bench.Parent ~= nil then
		return bench
	end
	if resolveIn > 0 then
		return nil
	end
	resolveIn = RESOLVE
	table.clear(anchorCache)
	bench = Workspace:FindFirstChild(binding.Model, true)
	if bench == nil and not warned then
		warned = true
		warn(`[BeltMates] no {binding.Model} in Workspace: the plates of the belt are not drawn until it streams in`)
	end
	return bench
end

local function pointOf(instance: Instance): Vector3?
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

local function namedPoint(name: string): Vector3?
	const cached = anchorCache[name]
	if typeof(cached) == "Vector3" then
		return cached
	elseif cached == false then
		return nil
	end
	const root = findBench()
	if root == nil then
		return nil
	end
	local found = root:FindFirstChild(name, true)
	const parent = root.Parent
	if found == nil and parent ~= nil and parent ~= Workspace then
		found = parent:FindFirstChild(name, true)
	end
	const point = if found ~= nil then pointOf(found) else nil
	anchorCache[name] = point or false
	return point
end

local function stopPoint(stop: number): Vector3?
	if stop < 1 or stop > STOP_COUNT then
		return nil
	end
	return namedPoint(string.format(binding.Stop, stop))
end

local function flat(vector: Vector3): Vector3?
	const level = Vector3.new(vector.X, 0, vector.Z)
	return if level.Magnitude > 1e-3 then level.Unit else nil
end

-- Unit vector along the belt toward the higher stops (the plate's "Right"), from the stop anchors around `stop`.
local function beltDir(stop: number): Vector3
	const here = stopPoint(stop)
	if here ~= nil then
		const nextPoint = stopPoint(stop + 1)
		if nextPoint ~= nil then
			const dir = flat(nextPoint - here)
			if dir ~= nil then
				return dir
			end
		end
		const previous = stopPoint(stop - 1)
		if previous ~= nil then
			const dir = flat(here - previous)
			if dir ~= nil then
				return dir
			end
		end
	end
	return Vector3.xAxis
end

-- World point of a plate at `stop` with `wait` (0 on the stop, 1 waiting on the left, 2 on the right); nil = the map has
-- no such stop. Exported for World/Belt.luau (TASK-518), so the own plate and the colleagues' share one anchor rule.
function BeltMates.Anchor(stop: number, wait: number?): Vector3?
	const base = stopPoint(stop)
	if base == nil then
		return nil
	end
	if wait == 1 then
		return namedPoint(string.format(binding.WaitLeft, stop)) or base - beltDir(stop) * WAIT_GAP
	elseif wait == 2 then
		return namedPoint(string.format(binding.WaitRight, stop)) or base + beltDir(stop) * WAIT_GAP
	end
	return base
end

-- Models ----------------------------------------------------------------------------------------------------------------------

local function ensureFolder(): Folder
	const current: Folder = folder or Instance.new("Folder")
	if folder == nil then
		current.Name = FOLDER_NAME
		folder = current
	end
	const camera = Workspace.CurrentCamera
	if camera ~= nil and current.Parent ~= camera then
		current.Parent = camera
	end
	return current
end

local function quiet(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Massless = true
		elseif descendant:IsA("LuaSourceContainer") or descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		elseif descendant:IsA("ProximityPrompt") or descendant:IsA("BillboardGui") then
			descendant:Destroy()
		end
	end
end

-- Kit Tool `key` (ReplicatedStorage.Assets.Items.Tools) as an inert Model, primary = Handle; nil when the kit lacks it
local function kitModel(key: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const tools = if items then items:FindFirstChild("Tools") else nil
	const tool = if tools then tools:FindFirstChild(key) else nil
	if tool == nil or not tool:IsA("Tool") then
		return nil
	end
	const copy = tool:Clone()
	const model = Instance.new("Model")
	model.Name = key
	for _, child in copy:GetChildren() do
		if not child:IsA("LuaSourceContainer") then
			child.Parent = model
		end
	end
	copy:Destroy()
	const handle = model:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = handle
	quiet(model)
	return model
end

local function part(name: string, size: Vector3, color: Color3, parent: Instance): Part
	const made = Instance.new("Part")
	made.Name = name
	made.Size = size
	made.Color = color
	made.Material = Enum.Material.SmoothPlastic
	made.TopSurface = Enum.SurfaceType.Smooth
	made.BottomSurface = Enum.SurfaceType.Smooth
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Massless = true
	made.Parent = parent
	return made
end

-- Moves `model` so that its bounding-box bottom sits on `base`; returns its height
local function sitOn(model: Model, base: CFrame): number
	model:PivotTo(base)
	const box, size = model:GetBoundingBox()
	const bottom = base:PointToObjectSpace(box.Position).Y - size.Y / 2
	model:PivotTo(base * CFrame.new(0, -bottom, 0))
	return size.Y
end

-- The plate (AST-162): kit `plate` with its Rim in the owner's colour, else the placeholder (Cream top over a coloured rim)
local function buildPlate(color: Color3, parent: Instance): (Model, number)
	local model = kitModel("plate")
	if model ~= nil then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Name == "Rim" then
				descendant.Color = color
			end
		end
	else
		const drawn = Instance.new("Model")
		drawn.Name = "plate"
		const top = part("Handle", PLATE_SIZE, PLATE_COLOR, drawn)
		top.CFrame = CFrame.new(0, RIM_SIZE.Y + PLATE_SIZE.Y / 2 - 0.02, 0)
		const rim = part("Rim", RIM_SIZE, color, drawn)
		rim.CFrame = CFrame.new(0, RIM_SIZE.Y / 2, 0)
		drawn.PrimaryPart = top
		model = drawn
	end
	const plate = model :: Model
	plate.Parent = parent
	return plate, sitOn(plate, CFrame.identity)
end

-- Placeholder bun and / or sausage (kit missing)
local function drawnFood(bun: boolean, dog: boolean): Model
	const model = Instance.new("Model")
	model.Name = "PlateFood"
	if bun then
		part("Bun", Vector3.new(1.1, 0.3, 0.45), BUN_COLOR, model)
	end
	if dog then
		const sausage = part("Sausage", Vector3.new(1.2, 0.22, 0.22), DOG_COLOR, model)
		sausage.Shape = Enum.PartType.Cylinder
		sausage.CFrame = CFrame.new(0, if bun then 0.14 else 0, 0)
	end
	return model
end

-- The content of the plate from the mask (bun, sausage, toppings): rebuilt only when the mask changes
local function buildFood(puppet: Puppet, mask: number)
	if puppet.FoodMask == mask and (mask == 0 or puppet.Food ~= nil) then
		return
	end
	puppet.FoodMask = mask
	if puppet.Food ~= nil then
		puppet.Food:Destroy()
		puppet.Food = nil
	end
	const content = PlateMask.Unpack(mask)
	if not content.Cut and not content.Sausage then
		return
	end
	local model: Model? = nil
	if content.Cut and content.Sausage then
		model = kitModel("hot_dog")
		if model ~= nil and #content.Toppings > 0 then
			HotDogVisual.apply(model, content.Toppings)
			quiet(model)
		end
	elseif content.Cut then
		model = kitModel("bun_sliced")
	else
		model = kitModel("sausage_grilled")
	end
	const food = model or drawnFood(content.Cut, content.Sausage)
	food.Name = "Food"
	food.Parent = puppet.Root
	sitOn(food, puppet.Root:GetPivot() * CFrame.new(0, puppet.PlateTop, 0))
	puppet.Food = food
end

local function label(name: string, size: number, parent: Instance): TextLabel
	const text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.FontFace = Theme.Font.Body
	text.TextSize = size
	text.TextColor3 = Theme.Color.Ink
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Text = ""
	text.Parent = parent
	return text
end

-- The tag over a plate: ticket chip (#n, white with Ink stroke, in the owner's colour) + name + the "Waiting" line
local function buildTag(puppet: Puppet, adornee: BasePart, color: Color3)
	const gui = Instance.new("BillboardGui")
	gui.Name = "BeltMateTag"
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Active = false
	gui.Size = UDim2.fromOffset(TAG_WIDTH, TAG_HEIGHT)
	gui.StudsOffsetWorldSpace = Vector3.new(0, TAG_LIFT, 0)
	gui.MaxDistance = presence.Range
	gui.Adornee = adornee
	const card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Theme.Color.Cream
	card.BorderSizePixel = 0
	card.Parent = gui
	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	const stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = card
	const chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.Position = UDim2.fromOffset(6, 6)
	chip.Size = UDim2.fromOffset(52, TAG_HEIGHT - 12)
	chip.BackgroundColor3 = color
	chip.BorderSizePixel = 0
	chip.Parent = card
	const chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0, 10)
	chipCorner.Parent = chip
	const chipStroke = Instance.new("UIStroke")
	chipStroke.Color = Theme.Color.Ink
	chipStroke.Thickness = 2
	chipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	chipStroke.Parent = chip
	const ticket = label("Number", 20, chip)
	ticket.Size = UDim2.fromScale(1, 1)
	ticket.TextXAlignment = Enum.TextXAlignment.Center
	ticket.TextColor3 = Color3.new(1, 1, 1)
	ticket.FontFace = Theme.Font.Title
	const ticketStroke = Instance.new("UIStroke")
	ticketStroke.Color = Theme.Color.Ink
	ticketStroke.Thickness = 2
	ticketStroke.Parent = ticket
	const name = label("Name", 16, card)
	name.Position = UDim2.fromOffset(64, 5)
	name.Size = UDim2.new(1, -70, 0, 22)
	const note = label("Note", 14, card)
	note.Position = UDim2.fromOffset(64, 27)
	note.Size = UDim2.new(1, -70, 0, 18)
	gui.Parent = puppet.Root
	puppet.Tag, puppet.Card, puppet.Stroke, puppet.Chip = gui, card, stroke, chip
	puppet.Number, puppet.Name, puppet.Note = ticket, name, note
end

local function baseFrame(pos: Vector3, dir: Vector3): CFrame
	-- the plate's length (X) along the belt
	return CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0)
end

local function drop(seatId: number)
	const puppet = puppets[seatId]
	if puppet ~= nil then
		puppets[seatId] = nil
		puppet.Root:Destroy()
	end
end

local function makePuppet(seatId: number, user: number, pos: Vector3, dir: Vector3): Puppet
	const color = CrewColor.OfUser(user)
	const root = Instance.new("Model")
	root.Name = `BeltPlate_{seatId}`
	root.WorldPivot = CFrame.identity
	const plate, top = buildPlate(color, root)
	const puppet = {
		Seat = seatId,
		User = user,
		Root = root,
		Plate = plate,
		PlateTop = top,
		Food = nil,
		FoodMask = -1,
		From = pos,
		To = pos,
		Pos = pos,
		Dir = dir,
		T = MOVE,
	} :: any
	const adornee = plate.PrimaryPart or plate:FindFirstChildWhichIsA("BasePart", true)
	buildTag(puppet, adornee :: BasePart, color)
	root:PivotTo(baseFrame(pos, dir))
	root.Parent = ensureFolder()
	return puppet :: Puppet
end

-- Reading the set -------------------------------------------------------------------------------------------------------------

local function ticketText(npc: number): string
	if npc <= 0 or net == nil then
		return UNKNOWN_TICKET
	end
	const customer = net.Customers:get(npc)
	const value = if customer ~= nil then customer.Number else nil
	return if type(value) == "number" then `#{value}` else UNKNOWN_TICKET
end

-- The record of a belt seat that must be drawn here, nil = no plate to draw
local function drawable(seatId: number, me: number): (SeatRecord?, Player?)
	if net == nil then
		return nil, nil
	end
	const record: SeatRecord? = net.PrepSeats:get(seatId)
	if record == nil or record.User == 0 then
		return nil, nil
	end
	const stop = record.Stop or 0
	if stop < 1 or stop > STOP_COUNT then
		return nil, nil
	end
	-- the own plate while in the focus is World/Belt.luau's (TASK-518)
	if record.User == me and record.Away ~= true then
		return nil, nil
	end
	const owner = Players:GetPlayerByUserId(record.User)
	if owner == nil then
		return nil, nil -- the owner left: never a ghost plate, whatever the set still says
	end
	return record, owner
end

local function poll()
	const me = Players.LocalPlayer.UserId
	if folder ~= nil and not folder:IsDescendantOf(game) then
		-- the camera that held the folder was replaced (and destroyed with it): start over
		table.clear(puppets)
		folder = nil
	end
	if folder ~= nil then
		ensureFolder()
	end
	for _, seatId in beltSeats do
		const record, owner = drawable(seatId, me)
		if record == nil or owner == nil then
			drop(seatId)
			continue
		end
		const stop = record.Stop :: number
		const target = BeltMates.Anchor(stop, record.Wait)
		if target == nil then
			drop(seatId) -- the bench is not there (streamed out): nothing to sit on
			continue
		end
		local puppet = puppets[seatId]
		if puppet ~= nil and puppet.User ~= record.User then
			drop(seatId)
			puppet = nil
		end
		const dir = beltDir(stop)
		if puppet == nil then
			puppet = makePuppet(seatId, record.User, target, dir)
			puppets[seatId] = puppet
		end
		const live = puppet :: Puppet
		if (live.To - target).Magnitude > 1e-3 then
			live.From, live.To, live.T = live.Pos, target, 0
		end
		live.Dir = dir
		buildFood(live, record.Plate or 0)
		const color = CrewColor.OfUser(record.User)
		live.Stroke.Color = color
		live.Chip.BackgroundColor3 = color
		live.Number.Text = ticketText(record.Ticket)
		live.Name.Text = owner.Name -- the username, like the name tags of Mates.Tag
		const waiting = (record.Wait or 0) ~= 0
		live.Note.Text = if waiting then prep.Texts.BeltWait else ""
		live.Note.Visible = waiting
		live.Card.BackgroundTransparency = if record.Away == true then AWAY_CARD else 0
	end
end

local function step(dt: number)
	resolveIn -= dt
	pollIn -= dt
	if pollIn <= 0 then
		pollIn = POLL
		if resolveIn <= 0 and bench ~= nil then
			-- refresh the anchor cache now and then (the map may be edited / streamed while the server runs)
			table.clear(anchorCache)
			resolveIn = RESOLVE
		end
		poll()
	end
	for _, puppet in puppets do
		if puppet.T < MOVE then
			puppet.T = math.min(puppet.T + dt, MOVE)
			const alpha = puppet.T / MOVE
			const eased = 1 - (1 - alpha) ^ 3
			puppet.Pos = puppet.From:Lerp(puppet.To, eased)
			puppet.Root:PivotTo(baseFrame(puppet.Pos, puppet.Dir))
		end
	end
end

-- API ---------------------------------------------------------------------------------------------------------------------------

-- Once, from World/Ghost.Mount (PrepController:OnInit). `network` = the Libs.Net of the controller (sets PrepSeats, Customers).
-- No-op outside the conveyor mode.
function BeltMates.Mount(network: any)
	if connection ~= nil or prep.Rules.Mode ~= "Conveyor" then
		return
	end
	net = network
	connection = RunService.Heartbeat:Connect(step)
end

-- The drawn plate of a belt seat (QA / dev), nil = not drawn here
function BeltMates.PlateOf(seatId: number): Model?
	const puppet = puppets[seatId]
	return if puppet ~= nil then puppet.Root else nil
end

-- Everything off (tests, controller teardown)
function BeltMates.Destroy()
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
	for seatId in puppets do
		drop(seatId)
	end
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
	net = nil
	bench = nil
	table.clear(anchorCache)
end

return BeltMates
