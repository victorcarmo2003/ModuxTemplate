--!strict
-- Drive-thru of the restaurant (TASK-574; tech/restaurant-flow.md §3.4, wave R3; design FEAT-049). Run place only, and
-- only with Content.Restaurant.Drive.Enabled and DT-IN / DT-STOP / DT-OUT in the map. Single writer of the Net.Restaurant
-- DriveCars set (record = lane spot 1..Drive.Lanes, 1 = at the window).
--
-- Spawn: CustomerService:Attempt asks Try(party) first (SetDriver): from night Drive.UnlockNight on, with a free lane spot
-- (1 + Drive.QueueByParty[party] spots), a draw under Drive.ShareByParty[party] turns the attempt into a car. The customer
-- is an ordinary Customers record with Drive = spot and a rig of the NPC pool (plan B of §3.4: one NPC slot per car),
-- anchored at its spot and marked with the rig attribute DriveThru (the client seats it at the wheel of its car, seen
-- through the glass; its balloon rides over the car). Looks: a random Content.Traffic look (own Random, the seeded draws stay).
-- Life: Arriving (the car drives to its spot, Lane.MoveTime) -> Waiting at the spot; the first stop joins the line
-- (CustomerService:JoinDrive: arrival counted, ticket drawn); at spot 1 FrontDrive starts the window clock
-- (Drive.OrderPatience). The order is taken at DT-PC (TabletService, tablet Rules.DrivePcIndex, same talk and ticket as
-- TAB-1; the Order clock is Drive.PrepBase + PrepPerK x K) and served with drive_serve at DT-WIN (CustomerService:ServeFor,
-- same verdict and pay). Any Leave (served, wrong, gave up, window shut, shift end) calls Left: the car drives off
-- (Leaving, Drive.LeaveTime from the window) and the record and the rig go when it is gone; the cars behind move up.
-- Horn: nothing on the wire (the client derives it from the customer's patience, Drive.HornAt).
-- Anchors: DT-PC = a copy of TAB-1 (TabletIndex = Rules.DrivePcIndex) and DT-WIN = an invisible part with the
-- Prompt_Serve attachment, both on the window sill (MapPoint DT-WIN, else the part DT_Sill, else 6 studs from DT-STOP
-- towards the kitchen), made here when the map has none. Priority 566 > TabletService 564: DT-PC exists before it binds.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local Lane = require(ReplicatedStorage.shared.DriveThru.Lane)
local Modux = require(ServerScriptService.server.Modux)

export type CarState = "Arriving" | "Waiting" | "Leaving"

export type Car = {
	Npc: number,
	Look: number,
	Spot: number,
	State: CarState,
	At: number, -- server time of the State change
	From: number, -- distance along the lane when the move started
	To: number, -- distance it moves to
	Ends: number, -- server time the move ends
	Joined: boolean, -- reached a spot once (JoinDrive done)
	Model: Model?, -- the driver's rig (its DriveThru attribute is cleared however the customer goes)
}

const ACTION = "drive_serve"
const ANCHOR_TAG = "Interactable"
const HIDDEN = "DriveThru" -- rig attribute: this rig drives a drive-thru car (the client seats it in the car)
const WINDOW_FOLDER = "DriveThru_Anchors"
const DT_PC = "DT-PC"
const TICK_RATE = 5 -- Hz
const DRIVER_UP = 1 -- studs: the rig stands this much above the road (its head over the car roof, for the balloon)
const WINDOW_OUT = 6 -- studs from DT-STOP towards the kitchen when the map has neither DT-WIN nor DT_Sill
const SILL = "DT_Sill"
const SERVE_ANCHOR = "Prompt_Serve"

local function now(): number
	return workspace:GetServerTimeNow()
end

local function find(id: string): CFrame?
	const ok, point = pcall(MapIndex.FindPoint, id)
	return if ok then point else nil
end

-- Horizontal axis unit nearest to `v` (the window wall is axis aligned in MAP-01)
local function axis(v: Vector3): Vector3
	if math.abs(v.X) >= math.abs(v.Z) then
		return Vector3.new(if v.X >= 0 then 1 else -1, 0, 0)
	end
	return Vector3.new(0, 0, if v.Z >= 0 then 1 else -1)
end

const DriveThruService = Modux.Service("DriveThruService", {
	Require = {
		"PlaceService",
		"NetService",
		"RunStateService",
		"RoundService",
		"EconomyService",
		"InteractionService",
		"NpcService",
		"CustomerService",
		"ItemService",
	},
	Priority = 566,
})

function DriveThruService:Setup()
	self.Enabled = false :: boolean
	self.Lane = nil :: Lane.Lane?
	-- lane spot -> car (a leaving car keeps its spot until it is gone)
	self.Cars = {} :: { [number]: Car }
	self.Published = {} :: { [number]: boolean }
	self.Window = nil :: Attachment?
	self.WindowOn = false :: boolean
	-- own Random: the share draw and the look never shift the seeded customer draws
	self.Rng = Random.new() :: Random
	-- dev: the next Try makes a car whatever the night, the share and the party queue (/dev drive car)
	self.Force = false :: boolean
end

-- Reads -----------------------------------------------------------------------------------------------------------------

function DriveThruService:CarOf(npc: number): Car?
	for _, car in self.Cars do
		if car.Npc == npc then
			return car
		end
	end
	return nil
end

-- Lane spots usable now: 1 at the window + QueueByParty[party] behind, never more than Drive.Lanes or the lane's spots
function DriveThruService:Allowed(party: number): number
	const drive = Content.Restaurant.Drive
	const queue = drive.QueueByParty[math.clamp(party, 1, #drive.QueueByParty)] or 0
	const lane = self.Lane
	return math.min(1 + queue, drive.Lanes, if lane then #lane.Spots else 1)
end

-- Spot a new car takes: right behind the last car (0 = the lane is full)
function DriveThruService:NextSpot(allowed: number): number
	local last = 0
	for spot in self.Cars do
		last = math.max(last, spot)
	end
	return if last + 1 <= allowed then last + 1 else 0
end

-- Distance of a car along the lane now
function DriveThruService:DistOf(car: Car, t: number): number
	if car.Ends <= car.At then
		return car.To
	end
	return Lane.Ease(car.From, car.To, (t - car.At) / (car.Ends - car.At))
end

-- Spawn -------------------------------------------------------------------------------------------------------------------

-- CustomerService:Attempt hook: the NpcId when this attempt became a car
-- Balance (owner 2026-10-20, Provisional): `counter` = customers at / walking to the counter. More of them than cars = this
-- attempt is a car (when the lane has room); more cars than them = it goes to the counter; even = the ShareByParty draw.
function DriveThruService:Try(party: number, counter: number): number?
	const lane = self.Lane
	if not self.Enabled or lane == nil then
		return nil
	end
	const drive = Content.Restaurant.Drive
	const forced = self.Force
	if not forced then
		if self.Dependencies.RoundService:Info().Night < drive.UnlockNight then
			return nil
		end
		local cars = 0
		for _, car in self.Cars do
			if car.State ~= "Leaving" then
				cars += 1
			end
		end
		if cars > counter then
			return nil
		elseif cars == counter then
			const share = drive.ShareByParty[math.clamp(party, 1, #drive.ShareByParty)] or 0
			if self.Rng:NextNumber() >= share then
				return nil
			end
		end
	end
	const spot = self:NextSpot(if forced then drive.Lanes else self:Allowed(party))
	if spot == 0 then
		return nil
	end
	return self:Spawn(spot, false)
end

-- The tutorial customer as a car (owner 2026-10-20, Provisional): any night, no draw; nil = lane full / no NPC
function DriveThruService:TryTutorial(): number?
	if not self.Enabled or self.Lane == nil then
		return nil
	end
	const spot = self:NextSpot(Content.Restaurant.Drive.Lanes)
	if spot == 0 then
		return nil
	end
	return self:Spawn(spot, true)
end

-- A car with its driver at lane `spot` (Create with the spot); nil = no NPC
function DriveThruService:Spawn(spot: number, tutorial: boolean): number?
	const lane = self.Lane :: Lane.Lane
	const to = Lane.Spot(lane, spot)
	const npc = self.Dependencies.NpcService
	const id = npc:Spawn({ Rng = self.Rng, At = self:DriverPose(to) })
	if id == nil then
		return nil
	end
	self.Force = false
	const model = npc:GetModel(id)
	if model ~= nil then
		model:SetAttribute(HIDDEN, true)
	end
	self:Anchor(id, true)
	self.Dependencies.CustomerService:Create(id, nil, nil, if tutorial then true else nil, spot)
	const looks = Content.Traffic.Looks
	const t = now()
	const car: Car = {
		Npc = id,
		Look = self.Rng:NextInteger(1, #looks.Shapes * #looks.Paints),
		Spot = spot,
		State = "Arriving",
		At = t,
		From = 0,
		To = to,
		Ends = t + Lane.MoveTime(lane, 0, to),
		Joined = false,
		Model = model,
	}
	self.Cars[spot] = car
	self:Publish(spot)
	return id
end

-- Floor pose of the hidden driver at lane distance `s`
function DriveThruService:DriverPose(s: number): CFrame
	const lane = self.Lane :: Lane.Lane
	return Lane.Pose(lane, s) + Vector3.new(0, DRIVER_UP, 0)
end

-- The driver's rig sits still (anchored) at its car's spot
function DriveThruService:Anchor(id: number, on: boolean)
	const rig = self.Dependencies.NpcService:GetRig(id)
	if rig ~= nil then
		rig.Root.Anchored = on
	end
end

function DriveThruService:PlaceDriver(car: Car)
	const lane = self.Lane
	const rig = self.Dependencies.NpcService:GetRig(car.Npc)
	if lane == nil or rig == nil then
		return
	end
	const pose = self:DriverPose(car.To)
	rig.Model:PivotTo(CFrame.new(pose.Position + Vector3.new(0, 3, 0)) * pose.Rotation)
end

-- Life ----------------------------------------------------------------------------------------------------------------------

-- CustomerService:Leave hook: the car drives off from where it is
function DriveThruService:Left(id: number)
	const car = self:CarOf(id)
	const lane = self.Lane
	if car == nil or lane == nil or car.State == "Leaving" then
		return
	end
	const t = now()
	const from = self:DistOf(car, t)
	const finish = lane.Path.Length
	car.State = "Leaving"
	car.At = t
	car.From = from
	car.To = finish
	-- from the window: Drive.LeaveTime; from further back, the same speed over the longer way
	const span = math.max(finish - lane.Stop, 1)
	car.Ends = t + math.max(Lane.LeaveTime() * (finish - from) / span, 1)
	self:Publish(car.Spot)
end

-- The car is gone: record off the wire, customer and rig back to the pool
function DriveThruService:Drop(spot: number)
	const car = self.Cars[spot]
	if car == nil then
		return
	end
	self.Cars[spot] = nil
	self:Unpublish(spot)
	self:Release(car)
end

function DriveThruService:Release(car: Car)
	self:Unhide(car)
	self:Anchor(car.Npc, false)
	self.Dependencies.CustomerService:Remove(car.Npc)
end

-- The rig goes back to the pool unmarked (the next customer on it walks)
function DriveThruService:Unhide(car: Car)
	const model = car.Model
	if model ~= nil then
		model:SetAttribute(HIDDEN, nil)
		car.Model = nil
	end
end

-- A car reached its spot
function DriveThruService:Arrive(car: Car, t: number)
	car.State = "Waiting"
	car.At = t
	car.From = car.To
	car.Ends = t
	self:PlaceDriver(car)
	const customers = self.Dependencies.CustomerService
	if not car.Joined then
		car.Joined = true
		customers:JoinDrive(car.Npc)
	end
	if car.Spot == 1 then
		customers:FrontDrive(car.Npc)
	end
	self:Publish(car.Spot)
end

-- The cars behind move up into a free spot (never past a leaving car)
function DriveThruService:Compact(t: number)
	const lane = self.Lane
	if lane == nil then
		return
	end
	for spot = 1, Content.Restaurant.Drive.Lanes do
		if self.Cars[spot] ~= nil then
			continue
		end
		local next: number? = nil
		for behind = spot + 1, Content.Restaurant.Drive.Lanes do
			if self.Cars[behind] ~= nil then
				next = behind
				break
			end
		end
		if next == nil then
			return
		end
		const car = self.Cars[next] :: Car
		if car.State == "Leaving" then
			return
		end
		self.Cars[next] = nil
		self:Unpublish(next)
		const from = self:DistOf(car, t)
		const to = Lane.Spot(lane, spot)
		car.Spot = spot
		car.State = "Arriving"
		car.At = t
		car.From = from
		car.To = to
		car.Ends = t + Lane.MoveTime(lane, from, to)
		self.Cars[spot] = car
		self.Dependencies.CustomerService:SetDriveSpot(car.Npc, spot)
		self:Publish(spot)
	end
end

function DriveThruService:Step()
	const t = now()
	const customers = self.Dependencies.CustomerService
	for spot, car in self.Cars do
		const customer = customers:Get(car.Npc)
		if customer == nil then
			-- removed under us (despawned by someone else, shift reset): the car just goes
			self:Unhide(car)
			if car.State ~= "Leaving" then
				self:Left(car.Npc)
			end
			if t >= car.Ends then
				self.Cars[spot] = nil
				self:Unpublish(spot)
			end
			continue
		end
		if car.State == "Arriving" and t >= car.Ends then
			self:Arrive(car, t)
		elseif car.State == "Leaving" and t >= car.Ends then
			self:Drop(spot)
		elseif car.State ~= "Leaving" and customer.State == "Leaving" then
			self:Left(car.Npc) -- a Leave that did not reach the hook (should not happen; safety)
		end
	end
	self:Compact(t)
	self:SyncWindow()
end

-- Wire ----------------------------------------------------------------------------------------------------------------------

function DriveThruService:Publish(spot: number)
	const car = self.Cars[spot]
	if car == nil or not self.Dependencies.NetService:IsRunning() then
		return
	end
	const record = {
		State = car.State,
		Npc = math.clamp(car.Npc, 0, 65535),
		Look = math.clamp(car.Look, 1, 32),
		At = car.At,
	}
	if self.Published[spot] then
		Restaurant.DriveCars:update(spot, record)
	else
		Restaurant.DriveCars:add(spot, record)
		self.Published[spot] = true
	end
end

function DriveThruService:Unpublish(spot: number)
	if not self.Published[spot] then
		return
	end
	self.Published[spot] = nil
	if self.Dependencies.NetService:IsRunning() then
		Restaurant.DriveCars:remove(spot)
	end
end

-- Window (DT-WIN) -----------------------------------------------------------------------------------------------------------

-- The customer at the window waiting for its food (order taken), or nil
function DriveThruService:ServeTarget(): number?
	const customers = self.Dependencies.CustomerService
	const id = customers:DriveFront()
	if id == nil then
		return nil
	end
	const customer = customers:Get(id)
	const ticket = customers:GetTicket(id)
	if customer == nil or ticket == nil or customer.State ~= "Waiting" or ticket.TakenAt <= 0 then
		return nil
	end
	const car = self.Cars[1]
	if car == nil or car.Npc ~= id or car.State ~= "Waiting" then
		return nil
	end
	return id
end

-- "Hand Out" shows only while the car at the window waits for its food
function DriveThruService:SyncWindow()
	const anchor = self.Window
	if anchor == nil then
		return
	end
	const on = self:ServeTarget() ~= nil
	if on ~= self.WindowOn or anchor:GetAttribute("PromptEnabled") ~= on then
		self.WindowOn = on
		self.Dependencies.InteractionService:SetPrompt(anchor, on)
	end
end

-- Window spot on the sill and the unit towards the kitchen
function DriveThruService:WindowSpot(): (Vector3?, Vector3)
	const stop = find(Content.Restaurant.Binding.DriveStop)
	const point = find(Content.Restaurant.Binding.DriveWindow)
	local window: Vector3? = if point then point.Position else nil
	if window == nil then
		const sill = workspace:FindFirstChild(SILL, true)
		if sill ~= nil and sill:IsA("BasePart") then
			window = sill.Position + Vector3.new(0, sill.Size.Y / 2, 0)
		end
	end
	if stop == nil then
		return window, Vector3.xAxis
	end
	if window == nil then
		const trailer = find("TRL")
		const toward = if trailer then axis(trailer.Position - stop.Position) else Vector3.xAxis
		window = stop.Position + toward * WINDOW_OUT + Vector3.new(0, 3, 0)
	end
	return window, axis((window :: Vector3) - stop.Position)
end

-- DT-PC (tablet copy) and the DT-WIN serve anchor, made when the map has none
function DriveThruService:MakeAnchors()
	const window, inward = self:WindowSpot()
	if window == nil then
		warn("[DriveThruService] no DT-WIN, DT_Sill nor DT-STOP: no drive-thru window")
		return
	end
	const along = inward:Cross(Vector3.yAxis)
	local folder = workspace:FindFirstChild(WINDOW_FOLDER)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = WINDOW_FOLDER
		folder.Parent = workspace
	end
	const binding = Content.Restaurant.Binding
	const pcIndex = Content.Restaurant.Rules.DrivePcIndex
	local hasPc = false
	for _, model in CollectionService:GetTagged(binding.TabletTag) do
		if model:IsDescendantOf(workspace) and model:GetAttribute(binding.TabletIndex) == pcIndex then
			hasPc = true
		end
	end
	if not hasPc then
		local template: Model? = nil
		for _, model in CollectionService:GetTagged(binding.TabletTag) do
			if model:IsA("Model") and model:IsDescendantOf(workspace) and model:GetAttribute(binding.TabletIndex) == 1 then
				template = model
			end
		end
		if template == nil then
			warn("[DriveThruService] no TAB-1 to copy for DT-PC: the drive-thru orders cannot be taken")
		else
			const pc = (template :: Model):Clone()
			pc.Name = DT_PC
			pc:SetAttribute("MapId", DT_PC)
			pc:SetAttribute(binding.TabletIndex, pcIndex)
			-- on the sill, beside the window, the screen turned to the kitchen
			const at = window + inward * 0.5 - along * 1.3 + Vector3.new(0, 0.1, 0)
			-- TAB-1's screen faces +Z: turned about Y until it faces `inward` (+Z -> (sin, 0, cos))
			const yaw = math.atan2(inward.X, inward.Z)
			pc:PivotTo(CFrame.new(at) * CFrame.Angles(0, yaw, 0) * (template :: Model):GetPivot().Rotation)
			pc.Parent = folder
		end
	end
	const part = Instance.new("Part")
	part.Name = binding.DriveWindow
	part.Size = Vector3.new(0.4, 0.4, 0.4)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = CFrame.new(window + inward * 0.6 + along * 1.0 + Vector3.new(0, 0.8, 0))
	const anchor = Instance.new("Attachment")
	anchor.Name = SERVE_ANCHOR
	-- attributes before the tag: InteractionService reads them when the anchor is tagged
	anchor:SetAttribute("PromptAction", ACTION)
	anchor:SetAttribute("PromptEnabled", false)
	anchor.Parent = part
	part.Parent = folder
	CollectionService:AddTag(anchor, ANCHOR_TAG)
	self.Window = anchor
end

-- Dev (PlaceService:IsDev; /dev drive) ----------------------------------------------------------------------------------------

function DriveThruService:DevCheck()
	if not self.Dependencies.PlaceService:IsDev() then
		error("[DriveThruService] dev mode only", 3)
	end
	if not self.Enabled then
		error("drive-thru off (Content.Restaurant.Drive.Enabled, or DT-IN / DT-STOP / DT-OUT missing)", 0)
	end
end

-- The next spawn attempt is a car (any night, no share draw), and it is due now
function DriveThruService:DevCar(): string
	self:DevCheck()
	const customers = self.Dependencies.CustomerService
	if not customers:IsSelling() then
		return "not a selling phase: no customer arrives now"
	end
	self.Force = true
	const outcome, id = customers:Attempt()
	if self.Force then
		self.Force = false
		return `no car: {outcome} (lane full, NPC cap or customer cap)`
	end
	return `car {id} arriving (attempt {outcome})`
end

function DriveThruService:DevState(): string
	self:DevCheck()
	const t = now()
	const customers = self.Dependencies.CustomerService
	const lines: { string } = {}
	for spot = 1, Content.Restaurant.Drive.Lanes do
		const car = self.Cars[spot]
		if car == nil then
			table.insert(lines, `spot {spot}: -`)
			continue
		end
		const customer = customers:Get(car.Npc)
		table.insert(
			lines,
			string.format(
				"spot %d: npc %d %s (%.1f s), look %d, customer %s, patience %.0f s",
				spot,
				car.Npc,
				car.State,
				math.max(car.Ends - t, 0),
				car.Look,
				if customer then customer.State else "gone",
				if customer and customer.PatienceEndsAt > 0 then customer.PatienceEndsAt - t else 0
			)
		)
	end
	table.insert(
		lines,
		`night {self.Dependencies.RoundService:Info().Night} (unlock {Content.Restaurant.Drive.UnlockNight}), window prompt {self.WindowOn}`
	)
	return table.concat(lines, "\n")
end

-- Hands the plate out as `player` without the range check (the window prompt's rules otherwise). `exact` = first a hot
-- dog with the exact toppings of the order goes into the hand (ItemService:Give)
function DriveThruService:DevServe(player: Player, exact: boolean?): string
	self:DevCheck()
	const id = self:ServeTarget()
	if id == nil then
		return "no car waiting for its food at the window"
	end
	if exact then
		const lines = self.Dependencies.CustomerService:PendingToppings(id)
		const tool = self.Dependencies.ItemService:Give(player, "hot_dog", {
			Toppings = table.concat(lines[1] or {}, ","),
			Equip = true,
		})
		if tool == nil then
			return "could not give the hot dog (hands full?)"
		end
	end
	const result = self.Dependencies.CustomerService:ServeFor(player, nil, id)
	return `served {id}: {result or "nothing (no hot dog in hand / drawer closed)"}`
end

DriveThruService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") or not Content.Restaurant.Drive.Enabled then
		return
	end
	self.Enabled = true
	-- Priority 566 < 730: InteractionService already built its handler table
	self.Dependencies.InteractionService:RegisterAction(ACTION, {
		Validate = function(player: Player, anchor: Instance): boolean
			return anchor == self.Window
				and self.Dependencies.RunStateService:IsActive(player)
				and self.Dependencies.EconomyService:IsDrawerOpen()
				and self:ServeTarget() ~= nil
		end,
		Run = function(player: Player)
			const id = self:ServeTarget()
			if id ~= nil then
				self.Dependencies.CustomerService:ServeFor(player, nil, id)
			end
		end,
	})
end)

DriveThruService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- The map is loaded (StreamingEnabled off, T57)
	const lane = Lane.Build(find)
	if lane == nil then
		warn("[DriveThruService] DT-IN, DT-STOP or DT-OUT missing in the map: drive-thru off")
		self.Enabled = false
		return
	end
	self.Lane = lane
	-- owner 2026-10-20 (Provisional): no DT-PC tablet nor DT-WIN "Hand Out" any more; the car at the window carries the
	-- prompt (CustomerService:FrontDrive / SetPrompts). MakeAnchors stays for a rollback.
	if Content.Restaurant.Drive.WindowAnchors then
		self:MakeAnchors()
	end
	self.Dependencies.CustomerService:SetDriver({
		Try = function(party: number, counter: number): number?
			return self:Try(party, counter)
		end,
		TryTutorial = function(): number?
			return self:TryTutorial()
		end,
		Left = function(id: number)
			self:Left(id)
		end,
	})
	-- A new shift starts empty: CustomerService removed every customer, the cars go with them
	self.Dependencies.RoundService.ShiftStarted:Connect(function()
		for spot, car in self.Cars do
			self:Unhide(car)
			self.Cars[spot] = nil
			self:Unpublish(spot)
		end
	end)
end)

DriveThruService:OnTick(function(self)
	if self.Enabled and self.Lane ~= nil then
		self:Step()
	end
end, TICK_RATE)

return DriveThruService
