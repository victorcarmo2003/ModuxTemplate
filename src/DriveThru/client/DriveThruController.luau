--!strict
--[[
	DriveThruController (TASK-574; tech/restaurant-flow.md §3.4, wave R3)

	Presents the drive-thru; decides nothing (DriveThruService moves the cars, CustomerService and TabletService run the
	customer, the window prompt is the InteractionService one).

	  - DriveCars set (Net.Restaurant, record = lane spot, 1 = at the window) -> one local car per customer (keyed by Npc,
	    so a car that moves up a spot keeps its model). The car is a Traffic kit car of record.Look
	    (`Assets.Vehicles.DriveCars/<Shape>`: the AST-035 car with a translucent Glass and a dark Interior, owner
	    2026-10-20; else `Cars/<Shape>`), paint `Paints/<Paint>`, Content.Traffic.LookOf; the TrafficController is not
	    touched; anchored, no collision, query or touch.
	  - Motion: along the shared lane (DriveThru/shared/Lane: DT-IN -> DTQ-n..1 -> U-turn -> DT-STOP -> DT-OUT). Arriving =
	    eased move from where the car is to its spot in Lane.MoveTime (from record.At, server time); Waiting = parked on the
	    spot; Leaving = pulls away to DT-OUT and on for Lane.ExtraOut studs, then gone. A record that disappears without
	    Leaving (shift reset) drives off the same way.
	  - Horn (nothing on the wire): when the patience fraction of the car's customer (Customers PatienceEndsAt /
	    PatienceSpan) crosses each Drive.HornAt value, `car_horn` on the car and a little hop; not while its order is being
	    taken at DT-PC (Tablets record Rules.DrivePcIndex Talking with this Npc: the server froze the clock). A car that
	    leaves Complaining (gave up, wrong order, window shut) honks `car_horn_long`.
	  - The driver is the customer's own rig (server NPC with the attribute DriveThru, plan B of §3.4): every frame it is
	    put locally on the driver's seat of its car (window side, SEAT), seen through the glass; its balloon rides over
	    the car. The server only anchors it at the lane spot; the local pose wins until the rig goes back to the pool.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local Lane = require(ReplicatedStorage.shared.DriveThru.Lane)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type CarRecord = { State: string, Npc: number, Look: number, At: number, Pet: boolean? }

export type Patience = { EndsAt: number, Span: number, Phase: string, State: string, Mood: string }

export type Move = { From: number, To: number, Start: number, Duration: number, Accel: boolean }

export type View = {
	Npc: number,
	Model: Model,
	S: number, -- distance along the lane now
	Move: Move?,
	State: string,
	Spot: number, -- 0 = no record any more
	LostAt: number, -- os.clock() the record went (0 = has one)
	Horned: { [number]: boolean }, -- HornAt indices played for the running clock
	ClockKey: number, -- PatienceEndsAt the Horned set belongs to
	HopAt: number, -- os.clock() of the last horn (hop)
	Seat: CFrame, -- the driver's root, from the car pivot
	Rig: Model?, -- the customer's rig on that seat (nil = not found yet)
}

const DRIVE = Content.Restaurant.Drive
const TRAFFIC = Content.Traffic
const HIDDEN = "DriveThru" -- rig attribute set by DriveThruService: this rig drives a drive-thru car
const NPC_FOLDER = "Npcs"
const FOLDER_NAME = "DriveThruCars"
const MAP_WAIT = 30 -- s
const FIND_EVERY = 0.4 -- s between two looks for a driver's rig not found yet
const LOST_GRACE = 0.6 -- s: a record removed and not re-added (a car moving up is remove + add) = the car goes
const HOP_TIME = 0.35 -- s
const HOP_HEIGHT = 0.35 -- studs
const COMPLAINING = "Complaining"
const FALLBACK_SIZE = Vector3.new(7, 5, 12)
const FALLBACK_COLOR = Color3.fromHex("#F4B183")
-- driver's seat from the car pivot: share of the width to the window side (-X: the left, MAP-01 window), share of the
-- length from the centre towards the nose (-Z), root height over the road (head in the window band of AST-035)
const SEAT_SIDE = 0.22
const SEAT_FORWARD = 0.04
const SEAT_UP = 2.7

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function find(id: string): CFrame?
	local found = MapIndex.FindPoint(id)
	if found == nil then
		MapIndex.Refresh() -- the point may have streamed in after the last scan
		found = MapIndex.FindPoint(id)
	end
	return found
end

-- Car model -----------------------------------------------------------------------------------------------------------

local function fallbackModel(): Model
	const model = Instance.new("Model")
	const body = Instance.new("Part")
	body.Name = "Body"
	body.Size = FALLBACK_SIZE
	body.Color = FALLBACK_COLOR
	body.Material = Enum.Material.SmoothPlastic
	body.CFrame = CFrame.new(0, FALLBACK_SIZE.Y / 2, 0)
	body.Parent = model
	model.PrimaryPart = body
	body.PivotOffset = body.CFrame:Inverse()
	return model
end

-- Kit car of a Traffic look (same assets as TrafficController), or the placeholder block
local function cloneLook(look: number): Model
	const shape, paint = TRAFFIC.LookOf(look)
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const vehicles = if assets then assets:FindFirstChild("Vehicles") else nil
	const cars = if vehicles then (vehicles:FindFirstChild("DriveCars") or vehicles:FindFirstChild("Cars")) else nil
	const template = if cars and shape then cars:FindFirstChild(shape) else nil
	if template == nil or not template:IsA("Model") then
		return fallbackModel()
	end
	const model = template:Clone()
	const paints = model:FindFirstChild("Paints")
	if paints then
		local chosen = if paint then paints:FindFirstChild(paint) else nil
		if chosen == nil then
			const default = model:GetAttribute("DefaultPaint")
			chosen = if type(default) == "string" then paints:FindFirstChild(default) else nil
		end
		if chosen then
			chosen.Name = "Paint"
			chosen.Parent = model
		end
		paints:Destroy()
	end
	return model
end

local function makeCar(look: number): Model
	const model = cloneLook(look)
	model.Name = "DriveThruCar"
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	return model
end

-- Driver's seat (root of the rig) from the car pivot
local function seatOf(model: Model): CFrame
	const _, size = model:GetBoundingBox()
	const length = math.max(size.Z, size.X)
	const width = math.min(size.Z, size.X)
	return CFrame.new(-width * SEAT_SIDE, SEAT_UP, -length * SEAT_FORWARD)
end

const DriveThruController = Modux.Controller("DriveThruController", { Require = { "AudioController" }, Priority = 655 })

function DriveThruController:Setup()
	self.Lane = nil :: Lane.Lane?
	-- lane spot -> record
	self.Records = {} :: { [number]: CarRecord }
	-- Npc -> car
	self.Views = {} :: { [number]: View }
	-- Npc -> its Customers clock (drive customers only)
	self.Patience = {} :: { [number]: Patience }
	-- Npc whose order is being taken at DT-PC (0 = none)
	self.DriveTalk = 0 :: number
	self.FindAt = 0 :: number
	self.Folder = nil :: Folder?
end

function DriveThruController:Container(): Folder
	local folder = self.Folder
	if folder == nil or folder.Parent == nil then
		const made = Instance.new("Folder")
		made.Name = FOLDER_NAME
		made.Parent = Workspace
		folder = made
		self.Folder = made
	end
	return folder :: Folder
end

-- Records -----------------------------------------------------------------------------------------------------------------

function DriveThruController:OnRecord(spot: number, record: CarRecord?)
	const old = self.Records[spot]
	self.Records[spot] = record
	if old ~= nil and (record == nil or record.Npc ~= old.Npc) then
		const view = self.Views[old.Npc]
		if view ~= nil and view.Spot == spot then
			view.Spot = 0
			view.LostAt = os.clock()
		end
	end
	if record ~= nil then
		self:Apply(spot, record)
	end
end

function DriveThruController:Apply(spot: number, record: CarRecord)
	const lane = self.Lane
	if lane == nil then
		return -- the map is not ready yet: Rebuild applies every record
	end
	const t = now()
	local view = self.Views[record.Npc]
	if view == nil then
		const model = makeCar(record.Look)
		const made: View = {
			Npc = record.Npc,
			Model = model,
			S = 0,
			Move = nil,
			State = "",
			Spot = spot,
			LostAt = 0,
			Horned = {},
			ClockKey = 0,
			HopAt = 0,
			Seat = CFrame.identity,
			Rig = nil,
		}
		view = made
		self.Views[record.Npc] = made
		model:PivotTo(CFrame.identity)
		made.Seat = seatOf(model)
		model:PivotTo(Lane.Pose(lane, 0))
		model.Parent = self:Container()
		if record.State ~= "Arriving" then
			view.S = Lane.Spot(lane, spot) -- joined late: the car is already there
		end
	end
	const car = view :: View
	const target = Lane.Spot(lane, spot)
	const changed = car.State ~= record.State or car.Spot ~= spot
	car.Spot = spot
	car.LostAt = 0
	if not changed then
		return
	end
	const was = car.State
	car.State = record.State
	if record.State == "Arriving" then
		const from = car.S
		car.Move = { From = from, To = target, Start = record.At, Duration = Lane.MoveTime(lane, from, target), Accel = false }
	elseif record.State == "Waiting" then
		if math.abs(car.S - target) > 0.5 then
			car.Move = { From = car.S, To = target, Start = t, Duration = Lane.MoveTime(lane, car.S, target), Accel = false }
		end
	elseif record.State == "Leaving" then
		self:Leave(car, record.At)
		if was ~= "Leaving" then
			const clock = self.Patience[car.Npc]
			if clock ~= nil and clock.Mood == COMPLAINING then
				self:Horn(car, "car_horn_long")
			end
		end
	end
end

-- Pulls away to DT-OUT and on, at the Drive.LeaveTime pace
function DriveThruController:Leave(car: View, at: number)
	const lane = self.Lane
	if lane == nil then
		return
	end
	const finish = lane.Path.Length + Lane.ExtraOut
	const pace = math.max(lane.Path.Length - lane.Stop, 1) / math.max(Lane.LeaveTime(), 0.1)
	car.State = "Leaving"
	car.Move = { From = car.S, To = finish, Start = at, Duration = math.max((finish - car.S) / pace, 0.5), Accel = true }
end

-- Horn ----------------------------------------------------------------------------------------------------------------------

function DriveThruController:Horn(car: View, sound: string)
	car.HopAt = os.clock()
	const primary = car.Model.PrimaryPart
	self.Dependencies.AudioController:Play(sound, if primary then primary else car.Model:GetPivot().Position)
end

function DriveThruController:CheckHorn(car: View, t: number)
	const clock = self.Patience[car.Npc]
	if clock == nil or clock.Phase == "None" or clock.Span <= 0 or clock.EndsAt <= 0 or clock.State == "Leaving" then
		return
	end
	if car.State ~= "Waiting" or self.DriveTalk == car.Npc then
		return
	end
	if clock.EndsAt ~= car.ClockKey then
		-- a new clock (Queue -> Order) or a resumed one: only the marks still ahead may play
		car.ClockKey = clock.EndsAt
		table.clear(car.Horned)
		const left = (clock.EndsAt - t) / clock.Span
		for index, at in DRIVE.HornAt do
			if left <= at then
				car.Horned[index] = true
			end
		end
		return
	end
	const left = (clock.EndsAt - t) / clock.Span
	for index, at in DRIVE.HornAt do
		if not car.Horned[index] and left <= at then
			car.Horned[index] = true
			self:Horn(car, "car_horn")
			return
		end
	end
end

-- Frame ---------------------------------------------------------------------------------------------------------------------

function DriveThruController:Step()
	const lane = self.Lane
	if lane == nil then
		return
	end
	const t = now()
	const clockNow = os.clock()
	for npc, car in self.Views do
		if car.Spot == 0 and car.State ~= "Leaving" and clockNow - car.LostAt > LOST_GRACE then
			self:Leave(car, t) -- the record went without Leaving (shift reset): it drives off anyway
		end
		const move = car.Move
		if move ~= nil then
			const alpha = if move.Duration > 0 then math.clamp((t - move.Start) / move.Duration, 0, 1) else 1
			car.S = if move.Accel then move.From + (move.To - move.From) * alpha * alpha else Lane.Ease(move.From, move.To, alpha)
			if alpha >= 1 then
				car.Move = nil
				if car.State == "Leaving" then
					car.Model:Destroy()
					self.Views[npc] = nil
					continue
				end
			end
		end
		self:CheckHorn(car, t)
		local pose = Lane.Pose(lane, car.S)
		const hop = clockNow - car.HopAt
		if hop < HOP_TIME then
			pose += Vector3.new(0, math.sin(math.pi * hop / HOP_TIME) * HOP_HEIGHT, 0)
		end
		car.Model:PivotTo(pose)
		self:SeatDriver(car, pose)
	end
	if clockNow >= self.FindAt then
		self.FindAt = clockNow + FIND_EVERY
		self:FindRigs()
	end
end

-- The customer's rig on the driver's seat (local pose; the server keeps it anchored at the lane spot)
function DriveThruController:SeatDriver(car: View, pose: CFrame)
	const rig = car.Rig
	if rig == nil then
		return
	end
	if rig.Parent == nil or rig:GetAttribute(HIDDEN) ~= true or rig:GetAttribute("NpcId") ~= car.Npc then
		car.Rig = nil -- back in the pool (or reused): leave it alone
		return
	end
	rig:PivotTo(pose * car.Seat)
end

-- Rigs of the drivers not found yet (the rig replicates a moment after the car record)
function DriveThruController:FindRigs()
	const folder = Workspace:FindFirstChild(NPC_FOLDER)
	if folder == nil then
		return
	end
	for npc, car in self.Views do
		if car.Rig == nil and car.State ~= "Leaving" then
			const model = folder:FindFirstChild(`Npc_{npc}`)
			if model ~= nil and model:IsA("Model") and model:GetAttribute(HIDDEN) == true then
				car.Rig = model
			end
		end
	end
end

-- The map is ready: build the lane and show the cars already on the wire
function DriveThruController:Rebuild()
	const lane = Lane.Build(find)
	if lane == nil then
		warn("[DriveThruController] DT-IN, DT-STOP or DT-OUT missing: no drive-thru cars")
		return
	end
	self.Lane = lane
	for spot, record in self.Records do
		self:Apply(spot, record)
	end
end

DriveThruController:OnInit(function(self)
	self:Setup()
	if not DRIVE.Enabled then
		return
	end
	const cars = Restaurant.DriveCars
	cars:onAdded(function(id, record)
		self:OnRecord(id, record :: any)
	end)
	cars:onChanged(function(id, record)
		self:OnRecord(id, record :: any)
	end)
	cars:onRemoved(function(id)
		self:OnRecord(id, nil)
	end)
	-- the patience clock of the drive customers (horn)
	const customers = self.Libs.Net.Customers
	local function onCustomer(id: number, record: any)
		if record == nil or record.Drive == nil then
			self.Patience[id] = nil
			return
		end
		self.Patience[id] = {
			EndsAt = record.PatienceEndsAt,
			Span = record.PatienceSpan,
			Phase = record.Phase,
			State = record.State,
			Mood = record.Mood,
		}
	end
	customers:onAdded(onCustomer)
	customers:onChanged(onCustomer)
	customers:onRemoved(function(id)
		self.Patience[id] = nil
	end)
	-- the order being taken at DT-PC: its clock is frozen on the server, no horn meanwhile
	const pc = Content.Restaurant.Rules.DrivePcIndex
	local function onTablet(id: number, record: any)
		if id == pc then
			self.DriveTalk = if record ~= nil and record.State == "Talking" then record.Npc else 0
		end
	end
	Restaurant.Tablets:onAdded(onTablet)
	Restaurant.Tablets:onChanged(onTablet)
	Restaurant.Tablets:onRemoved(function(id)
		onTablet(id, nil)
	end)
end)

DriveThruController:OnStart(function(self)
	if not DRIVE.Enabled then
		return
	end
	RunService.RenderStepped:Connect(function()
		self:Step()
	end)
	-- The map streams in after boot: wait off the start chain
	task.spawn(function()
		if not MapIndex.WaitReady(MAP_WAIT) then
			warn("[DriveThruController] map binding not ready: the drive-thru waits for it")
		end
		self:Rebuild()
	end)
end)

return DriveThruController
