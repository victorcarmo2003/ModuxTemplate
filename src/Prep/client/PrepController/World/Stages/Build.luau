--!strict
-- World/Stages/Build: the 3D Board and Toppings sections of the prep mode (docs/tech/prep-3d.md §3.3, §3.4; TASK-204, 205). ONE module
-- serves both tabs (Stage3D.Tabs = Board, Toppings) because the plate lives across them: the bun, the sausage and the toppings sit on
-- the real cutting board of the trailer, seen from the Board and the Toppings views; no GuiObject here (the HUD is PrepShell).
--   Board     tap the bun CRATE: PrepBegin and the REAL kit bun lands on the board (predicted at once, undone if the server refuses);
--             the real knife follows the pointer, drag it along the dashed guide (the slice gesture, the same Grade as the 2D mode):
--             BunClosed swaps to BunOpen with a hop; then drag the FRONT sausage of the rail into the groove (magnet), a drop that
--             misses goes back. Pips Cut and Place; Next goes to Toppings.
--   Toppings  the six bowls of the trailer: press one (or tap it) and its tool follows the pointer: a bottle that leans and pours
--             a sauce as 3D segments over guide dots, a cheese slice that slides on, bacon rings that close, a potato sticks mound
--             that grows to its ring. Up to 3, never twice; Next sends the ONE summary (PrepFinish), the bun closes over the plate and
--             the seal shows. The virtual bin of the view (World/Bin, lower left) takes the plate if you drag it there (PrepTrash).
-- Everything the player does is measured by Director3D with the gesture modules and `Prep/shared/Grade` (never here), kept in the
-- 2D `Stages/Build/Session` (plate, scores, pips, PrepBegin / PrepFinish / PrepTrash and their PrepResult) and sent only through it.
-- The server decides stock, band and the hot dog; this module predicts what it shows (the bun on the board) and undoes it when the
-- records or the PrepResult say no. The cosmetic plate mask goes up with PrepTab (controller.PlateMask).
-- Rollback without code: Rules.World.Stages.Board / Toppings = false puts the 2D Build stage back. Provisional numbers and texts.
-- Delivery from the Toppings view (owner request 2026-10-14, Provisional): the customer waiting for its food at the service window
-- (a Taken card at the Counter, the pinned one first) gets a code-made hitbox (target Customer) and a DeliverMark (Green "DELIVER"
-- card) while the plate is ready (bun open, sausage in, no Finish on its way). Dragging the PLATE onto him is Done + Serve: the one
-- summary (PrepFinish) goes out and, once it is accepted, PrepOrder Serve for that customer (Feed.Serve); the SERVER judges the hot
-- dog just made (PrepService passes seat.Made to CustomerService:ServeFor). The Done button and the world `serve` prompt stay.
-- Conveyor (TASK-520; DEC-302, DEC-303 Q-382, DEC-305; tech/prep-conveyor.md §6.5, network.md §19, ui-text.md §17.2). With
-- Content.Prep.Rules.Mode = "Conveyor" the plate is the assembler's own plate ON THE BELT: the Board tab is the Board stop, the
-- Toppings tab the Toppings stop, and the bun, the sausage and the toppings are drawn on the plate prop of World/Belt (TASK-518:
-- the stops, the arrows, the camera and the dish are the controller's; the stack here follows `World.Belt.PlateFrame()`):
--   Board     tap the crate: the bun lands on the plate (drawn only, nothing is sent: the bun leaves the stock with the cut); drag
--             the knife along the line: PrepStage Cut with the score. Drag ANY free sausage of the rest table (the rail; the one
--             nearest the press, never one a colleague holds: Ghost.HeldBy) into the bun: PrepGrab claims that position and the
--             drop sends PrepStage Dog with its Slot. Each commit is predicted and undone when PrepResult Stage says no.
--   Toppings  the bowls of the ticket pulse; each sauce is traced along ITS pattern (World/Strokes: ketchup Zigzag, mustard Wave,
--             cream cheese Line), drawn over the bun and scored against it with the same trace measure and Grade. Right on this
--             stop is OnNext = the one PrepFinish; the seal is the SERVER's grade (PrepResult Finish), the stack leaves to the hand
--             (the server moves the plate to Out and gives it back) and the toast says "#n ready. Table or pickup".
-- Nothing is committed unless controller:BeltCanWork() (the plate stands on the stop in the record). The seat record
-- (PrepSeats.Plate, bun and sausage bits written by the server at each commit) is the truth: a plate taken over from the table or
-- parked earlier shows what the server has. No delivery by drag; the bin empties the plate and keeps the ticket (§6.6).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local PlateMask = require(ReplicatedStorage.shared.Prep.PlateMask)
local Poses = require(script.Parent.Parent.Parent.Poses)
local Score = require(script.Parent.Parent.Parent.Gestures.Score)
local Stage = require(script.Parent.Parent.Parent.Stage)
local Feed = require(script.Parent.Parent.Parent.Feed)
local Session = require(script.Parent.Parent.Parent.Stages.Build.Session)
local BoardView = require(script.Parent.Parent.BoardView)
local Director3D = require(script.Parent.Parent.Director3D)
local Ghost = require(script.Parent.Parent.Ghost)
local Plane = require(script.Parent.Parent.Plane)
local Strokes = require(script.Parent.Parent.Strokes)
local Targets = require(script.Parent.Parent.Targets)
local trace = require(script.Parent.Parent.Parent.Gestures.trace)
local ToolView = require(script.Parent.Parent.ToolView)
local Types = require(script.Parent.Parent.Types)
local World = require(script.Parent.Parent)
local DeliverMark = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.DeliverMark)

const untrack = Vide.untrack
const source = Vide.source

const prep = Content.Prep
const world = prep.Rules.World
const boardRules = world.Board
const build = prep.Build
const MAX = Content.OrderRules.MaxToppings
const GROOVE = Vector2.new(build.Groove.X, build.Groove.Y)
const HAND_OVER = 0.25 -- s: the plate dropped on the customer flies to him and shrinks away (bug 2026-10-14: no slide back)
const MASK_RETRY = 2.5 -- s: the server drops a mask that comes too early, so an unaccepted one is sent again (3 times at most)
const FRAME_TICK = 0.1 -- s: the plate and the targets are re-judged at 10 Hz
-- the customer drop target of the Toppings view (owner request 2026-10-14): the area is Content.Prep.Build.Deliver (TASK-253)
const FIND_EVERY = 0.25 -- s between two searches for the rig
const CUSTOMER_ID = Types.IdOf("Customer", 0, "")

-- Conveyor (TASK-520) ------------------------------------------------------------------------------------------------------------
const CONVEYOR = prep.Rules.Mode == "Conveyor"
const conveyor = prep.Conveyor
const STAGE_TIMEOUT = 3 -- s without a PrepResult Stage: the commit is forgotten and the seat record decides
const STAGE_RETRY = 0.6 -- s: a commit refused for its rate (Reason Rate) is sent once more after this
const MASK_GRACE = 1.5 -- s a confirmed bun / sausage may be missing from the seat record before the picture follows it
const BENCH_REACH = 25 -- studs: a scanned target farther than this from the plate belongs to another kitchen
const READY_TOAST_DELAY = 0.9 -- s after the grade toast: "#n ready. Table or pickup"
const PLATE_TOP = 0.14 -- studs over World/Belt.PlateFrame(): the top of the plate prop (its lift 0.08 + half its 0.12 thickness)
-- ui-text.md §17.2 (BELT_TIP_*, Provisional; English, DEC-022; <= 36 characters)
const BELT_TEXT = {
	Dog = "Drag a sausage from the warmer", -- BELT_TIP_DOG
	BoardDone = "Press Right for the toppings", -- BELT_TIP_BOARD_DONE
	Toppings = "Pick a glowing topping and draw", -- BELT_TIP_TOPPINGS
	Finish = "All set. Press Finish", -- BELT_TIP_FINISH
	NoTop = "No toppings. Press Finish", -- BELT_TIP_NOTOP
}

-- The commits of the belt plate (module level: they outlive a stop left while the answer travels). Pending = "Cut" | "Dog" | "".
type Belt = {
	Pending: string,
	Stamp: number,
	Score: number,
	Slot: number,
	Retried: boolean,
	-- the server accepted it (a missing bit in the seat record afterwards means the server emptied the plate)
	Confirmed: { [string]: boolean },
	MissSince: number, -- os.clock() a confirmed bit was first seen missing, 0 = none
	Quiet: number, -- os.clock() before which the seat record is not read (the bin emptied the plate; the record follows later)
}
const belt: Belt = { Pending = "", Stamp = 0, Score = 0, Slot = 0, Retried = false, Confirmed = {}, MissSince = 0, Quiet = 0 }

local function beltForget()
	belt.Pending = ""
	belt.Stamp += 1
	belt.Retried = false
	table.clear(belt.Confirmed)
	belt.MissSince = 0
end

-- Where an anchor is in the world (Attachment, Part or Model), nil = none.
local function anchorPosition(instance: Instance?): Vector3?
	if instance == nil then
		return nil
	elseif instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

-- Where the bun base goes: on the own plate prop of World/Belt, or on the stop of `tab` when the prop is not drawn.
local function beltPoint(tab: string): Vector3?
	const frame = World.Belt.PlateFrame()
	if frame ~= nil then
		return frame.Position + Vector3.yAxis * PLATE_TOP
	end
	const index = conveyor.Stops.IndexOf[if tab == "Toppings" then "Toppings" else "Board"]
	const at = if index ~= nil then anchorPosition(World.Belt.Anchor(string.format(conveyor.Binding.Stop, index))) else nil
	return if at ~= nil then at + Vector3.yAxis * PLATE_TOP else nil
end

-- The own PrepSeats record (nil = none).
local function seatRecord(controller: any): any
	const station = Session.Peek(controller.Station)
	if type(station) ~= "number" or station < 1 then
		return nil
	end
	const ok, record = pcall(function(): any
		return controller.Libs.Net.PrepSeats:get(station)
	end)
	return if ok then record else nil
end

-- The #n of the ticket of the plate on the belt (0 = not known).
local function ticketNumber(controller: any): number
	const station = Session.Peek(controller.Station)
	if type(station) ~= "number" then
		return 0
	end
	const ok, number = pcall(function(): any
		return controller:BeltTicketNumber(station)
	end)
	return if ok and type(number) == "number" then number else 0
end

-- The toppings the plate's ticket asks for (Order, or Order2 for the 2nd line of a pair), nil = not known. Reactive on the customer.
local function wantedToppings(controller: any): { [string]: boolean }?
	const record = seatRecord(controller)
	const npc = if record ~= nil then record.Ticket else nil
	if type(npc) ~= "number" or npc <= 0 then
		return nil
	end
	const customer: any = controller.Dependencies.CustomerController:RecordOf(npc)
	if customer == nil then
		return nil
	end
	const bits = if record.Line == 2 and customer.Order2 ~= nil then customer.Order2 else customer.Order
	return if type(bits) == "table" then bits else nil
end

-- The stage may commit now (the plate stands on its stop in the record; TASK-518). Always true in the trailer.
local function canWork(controller: any): boolean
	if not CONVEYOR then
		return true
	end
	const ok, answer = pcall(function(): any
		return controller:BeltCanWork()
	end)
	return ok and answer == true
end

-- Short texts (Provisional; ui-text.md §16, PREP3D_*; English, DEC-022; <= 36 characters)
const TEXT = {
	Crate = "Tap the crate for a bun", -- PREP3D_TIP_CRATE
	Knife = "Cut the bun with the knife", -- PREP3D_TIP_BOARD
	Slice = "Drag the knife along the line", -- PREP3D_GST_SLICE
	SliceHold = "Hold the knife on the line", -- PREP3D_GST_SLICE_HOLD
	Place = "Tap the sausage, or drag it in", -- PREP3D_GST_PLACE
	CutFirst = "Cut the bun first", -- Provisional
	Rail = "Ready franks wait on the rail", -- PREP3D_TIP_RAIL
	NextBoard = "Next: add toppings", -- PREP3D_TIP_NEXT_BOARD
	NeedBoard = "Cut the bun and add the frank first", -- PREP3D_TIP_NEXT_BOARD_OFF
	NeedPlate = "Cut the bun and add the frank first",
	Add = "Add a topping or press Next", -- PREP3D_GST_ADD
	Full = "3 toppings max. Press Next", -- Build.Texts.Full (ui-text §16.3)
	TopMax = "3 toppings max!", -- PREP3D_REF_TOP_MAX
	PlaceFirst = "Place the frank first", -- PREP3D_REF_PLACE_FIRST
	Bin = "Drag the plate to the bin", -- PREP3D_TIP_BIN
	Deliver = "Drag the plate to the customer", -- Provisional (owner request 2026-10-14)
	NoCustomer = "Nobody is waiting for it", -- Provisional
	Trashed = "Plate trashed", -- PREP3D_REF_TRASHED
	NoBun = "Out of buns! Restock it.", -- PREP3D_REF_NOBUNS
	Miss = "Drop it on the bun", -- Provisional
	Trace = "Press and drag over the dashes", -- PREP3D_GST_TRACE
	TraceHold = "Hold to pour, let go at the mark", -- PREP3D_GST_TRACE_HOLD
	TracePad = "Hold the trigger, let go at the mark", -- TASK-268, Provisional
	TracePadFree = "Steer the bottle, trigger pours", -- TASK-268, Provisional
	Slide = "Drag the slice onto the bun", -- PREP3D_GST_SLIDE
	SlideHold = "Hold where the slice goes", -- PREP3D_GST_SLIDE_HOLD
	Taps = "Tap each ring as it closes", -- PREP3D_GST_TAPS
	Hold = "Hold, let go at the ring", -- PREP3D_GST_HOLD
}

-- The tip of a bowl on hover (PREP3D_TIP_BOWL_*)
const BOWL_TIPS: { [string]: string } = {
	ketchup = "Ketchup: tap it, then drag on the bun",
	mustard = "Mustard: tap it, then drag on the bun",
	cream_cheese = "Cream cheese: tap it, then drag",
	cheese = "Cheese: drag the slice on",
	bacon = "Bacon: tap each ring as it closes",
	potato_sticks = "Potato sticks: hold, then let go",
}

-- The name of a topping in a sentence
local function nameOf(key: string): string
	const row = Content.Ingredients.ByKey[key]
	return if row ~= nil then string.lower(row.Name) else (string.gsub(key, "_", " "))
end

type Drag = { Kind: string, Points: { Vector2 } }

type Sess = {
	Controller: any,
	Kitchen: any,
	Folder: Folder,
	Seat: number,
	View: BoardView.View,
	Tool: ToolView.Tool,
	Strokes: Strokes.Strokes,
	Director: Director3D.Director,
	Hitbox: Part,
	Targets: { [string]: Types.Target },
	Pulse: { [string]: boolean },
	Stop: (() -> ())?,
	Tab: string,
	Step: string,
	Active: boolean,
	LeavePending: boolean,
	Dead: boolean,
	Closing: boolean,
	Drag: Drag?,
	Drawn: { [string]: boolean },
	SausageOn: boolean,
	WantMode: string,
	HeldPending: boolean,
	PickedHeld: boolean,
	ToolKey: string,
	Tick: number,
	MaskSent: number,
	MaskTries: number,
	Home: Vector3, -- where the plate sits in the Board view (the middle of the board)
	Placed: boolean, -- the plate has been placed at least once (the first Enter does not slide)
	Flying: boolean, -- a tapped sausage is flying to the bun
	Assembly: Vector3?, -- where the plate sits beside the bowls (derived once from the bowl targets and the bench)
	CoachBoard: boolean, -- the tutorial hand was tried for the cut
	CoachTop: boolean, -- ... and for the toppings
	CoachSausage: boolean, -- ... and for the sausage from the rail to the bun (owner request 2026-10-14)
	CoachDeliver: boolean, -- ... and for the plate to the customer's delivery area (TASK-254)
	-- delivery from the Toppings view: the hitbox / target / rig of the customer that can take the plate (0 = none), the next
	-- rig search, the DELIVER card, the customer a Done-by-drop serves once the Finish is accepted, the plate carried over him
	CustomerBox: Part,
	CustomerTarget: Types.Target?,
	CustomerId: number,
	CustomerModel: Model?,
	CustomerLook: number,
	Mark: DeliverMark.Mark,
	DeliverTo: number,
	CarryOver: boolean,
	RailGrab: boolean, -- DEC-259: the front rail sausage is claimed by this drag (PrepGrab On sent)
	-- conveyor (TASK-520): the rest table position the drag took (PrepGrab / PrepStage Dog Slot; always 1 in the trailer)
	RailSlot: number,
}

local session: Sess? = nil

-- The hover tip (a source: the hint line reads it)
const hover = source("")

-- `/dev prep ray` (player attribute PrepRay) also narrates this stage in the client output.
local function note(text: string)
	if Players.LocalPlayer:GetAttribute("PrepRay") == true then
		print(`[prep build] {text}`)
	end
end

local function sfx(current: Sess, key: string, at: Vector3?)
	if Content.Sounds.ByKey[key] == nil then
		return
	end
	pcall(function()
		current.Kitchen.Dependencies.AudioController:Play(key, at)
	end)
end

local function bandOf(score: number): string
	return Score.Band(prep, score)
end

-- State -------------------------------------------------------------------------------------------------------------------------

local function plateOpen(): boolean
	return untrack(Session.Open)
end

local function placed(): boolean
	return untrack(Session.Placed)
end

local function bunState(current: Sess): string
	return Session.Peek(current.Controller.View.Bun)
end

local function toolKey(): string
	return untrack(Session.Active)
end

local function usedKeys(current: Sess): { [string]: boolean }
	return Session.Peek(current.Controller.View.Used)
end

-- The real object a hitbox stands for: the model of the trailer whose name starts with the hitbox `Object` (a MapId), or, for a
-- bowl, the lidded bin of the topping grid. nil = the hitbox itself is the adornee.
local function realObject(part: BasePart, kind: string, key: string): Instance?
	const targets = part.Parent
	const trailer = if targets ~= nil then targets.Parent else nil
	const object = part:GetAttribute("Object")
	if trailer == nil or type(object) ~= "string" then
		return nil
	end
	if kind == "Topping" then
		const camel = string.gsub(key, "_(%a)", function(letter: string): string
			return string.upper(letter)
		end)
		const name = `Bin_{string.upper(string.sub(camel, 1, 1))}{string.sub(camel, 2)}`
		return trailer:FindFirstChild(name, true)
	end
	for _, child in trailer:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, #object + 1) == `{object}_` then
			return child
		end
	end
	return nil
end

-- Delivery (Toppings view) ---------------------------------------------------------------------------------------------------

-- The rig of NPC `id` (attribute NpcId, tag AnimalRig), nil when it is not in the world.
local function rigOf(id: number): Model?
	for _, instance in CollectionService:GetTagged("AnimalRig") do
		if instance:IsA("Model") and instance:GetAttribute("NpcId") == id then
			return instance
		end
	end
	return nil
end

-- The customer that waits for its food at the counter: the pinned ticket first, else the first taken one. 0 = none.
local function deliverable(): number
	const pinned = untrack(Feed.Pinned)
	local first = 0
	for _, id in untrack(Feed.Ids) do
		const card = untrack(Feed.CardOf(id))
		if card.Status == "Taken" and card.Place == "Counter" then
			if id == pinned then
				return id
			end
			if first == 0 then
				first = id
			end
		end
	end
	return first
end

-- The plate can go to the customer now (the Done of the Toppings view, by drag)
local function canDeliver(current: Sess): boolean
	-- the conveyor delivers at the table or the pickup, never by drag from the belt (DEC-304)
	if CONVEYOR then
		return false
	end
	return current.Active
		and not current.Dead
		and not current.Closing
		and current.Tab == "Toppings"
		and plateOpen()
		and placed()
		and current.View:Bun() == "Open"
		and untrack(Session.Pending) ~= "Finish"
		and current.CustomerId ~= 0
		and current.CustomerModel ~= nil
end

-- Every frame: the hitbox follows the rig of the deliverable customer, the DELIVER card shows while the plate can go to him.
local function followCustomer(current: Sess)
	const id = deliverable()
	const clock = os.clock()
	if id ~= current.CustomerId then
		current.CustomerId = id
		current.CustomerModel = nil
		current.CustomerLook = 0
	end
	if id ~= 0 and current.CustomerModel == nil and clock >= current.CustomerLook then
		current.CustomerLook = clock + FIND_EVERY
		current.CustomerModel = rigOf(id)
	end
	local model = current.CustomerModel
	local root: Instance? = if model ~= nil then (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) else nil
	if model ~= nil and (model.Parent == nil or root == nil) then
		current.CustomerModel = nil
		model = nil
		root = nil
	end
	const target = current.CustomerTarget
	if target ~= nil and target.Model ~= model then
		target.Model = model
		const registry = World.Targets()
		if registry ~= nil then
			registry:Touch()
		end
	end
	if root ~= nil and root:IsA("BasePart") then
		-- TASK-253: the delivery AREA covers the customer's body (the drop target is the same box)
		const area = build.Deliver
		const centre = root.Position + Vector3.new(0, area.Lift, 0)
		current.CustomerBox.CFrame = CFrame.new(centre)
		if canDeliver(current) and toolKey() == "" then
			current.Mark:Show(centre, area.Width, area.Height)
			current.Mark:SetHot(current.Drag ~= nil and current.Drag.Kind == "Plate" and current.CarryOver)
			return
		end
	else
		current.CustomerBox.CFrame = CFrame.new(0, -500, 0)
	end
	current.Mark:Hide()
end

-- The plate dropped on the customer: the Done (one PrepFinish), then Serve for him once the Finish is accepted (OnEvent)
local function deliver(current: Sess): boolean
	const controller = current.Controller
	const npc = current.CustomerId
	if npc == 0 or not canDeliver(current) then
		controller:Toast(TEXT.NoCustomer, "Info")
		sfx(current, "error", nil)
		return false
	end
	-- a sauce still selected lands first: its score goes into the summary
	current.Director:Commit()
	if not Session.Finish(controller) then
		controller:Toast(TEXT.NeedPlate, "Alert")
		sfx(current, "error", nil)
		return false
	end
	current.DeliverTo = npc
	current.Mark:Kick(8)
	World.Coach():Done("Deliver")
	note(`plate dropped on customer {npc}: Finish sent, Serve follows`)
	return true
end

-- The copy of the plate dropped on the customer flies into his box and shrinks away (the originals are already hidden)
local function handOver(current: Sess, thrown: Model)
	const from = thrown:GetPivot()
	const goal = current.CustomerBox.Position
	const scale = thrown:GetScale()
	local t = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function(dt: number)
		t = math.min(1, t + dt / HAND_OVER)
		if thrown.Parent == nil then
			if connection ~= nil then
				connection:Disconnect()
			end
			return
		end
		thrown:PivotTo(from:Lerp(CFrame.new(goal) * from.Rotation, t))
		thrown:ScaleTo(math.max(0.05, scale * (1 - t)))
		if t >= 1 then
			if connection ~= nil then
				connection:Disconnect()
			end
			thrown:Destroy()
		end
	end)
end

-- The Finish of a plate dropped on a customer was accepted: the hot dog just made goes to him (the server judges it)
local function serveDelivered(current: Sess)
	const npc = current.DeliverTo
	current.DeliverTo = 0
	if npc == 0 then
		return
	end
	const controller = current.Controller
	if not Feed.Serve(controller, npc) then
		-- no Feed session (or one already on its way): the same packet straight
		controller.Libs.Net.PrepOrder:fireServer({ Act = "Serve", Npc = math.clamp(math.floor(npc), 1, 65535) })
	end
	note(`Serve sent to customer {npc}`)
end

-- Targets -----------------------------------------------------------------------------------------------------------------------

local function setPulse(current: Sess, id: string, on: boolean)
	if current.Pulse[id] == on then
		return
	end
	current.Pulse[id] = on
	const target = current.Targets[id]
	if target ~= nil then
		target.Pulse = on
		const registry = World.Targets()
		if registry ~= nil then
			registry:Touch()
		end
	end
end

local function live(): Sess?
	const current = session
	if current ~= nil and current.Active and not current.Dead then
		return current
	end
	return nil
end

-- Conveyor: the rest table position a press at `point` takes: the filled one (1..Feed.Rail) nearest the press that no colleague
-- holds (DEC-259 claims), nil = none free; the second value is the "<name> is holding it" line when one was skipped.
local function restSlotAt(current: Sess, point: Vector3?): (number?, string?)
	const count = math.clamp(untrack(Feed.Rail), 0, conveyor.Rest.Capacity)
	local best: number? = nil
	local bestDistance = math.huge
	local heldText: string? = nil
	for slot = 1, count do
		const holder, text = Ghost.HeldBy("Rail", slot)
		if holder ~= nil then
			heldText = heldText or text
			continue
		end
		-- without a picture of the slot the front (oldest) one wins
		local distance = 1e6 + slot
		const entry = current.Kitchen:SlotView("rail", slot)
		if point ~= nil and entry ~= nil and entry.Spot ~= nil and entry.Spot.Host ~= nil then
			distance = ((entry.Spot.Host.CFrame * entry.Spot.Offset).Position - point).Magnitude
		end
		if distance < bestDistance then
			best = slot
			bestDistance = distance
		end
	end
	return best, heldText
end

-- Conveyor: the scanned hitboxes of this kitchen only (the trailer may be streamed in too, with targets of the same ids).
local function nearParts(current: Sess, parts: { BasePart }): { BasePart }
	if not CONVEYOR then
		return parts
	end
	const kept: { BasePart } = {}
	for _, part in parts do
		if (part.Position - current.Home).Magnitude <= BENCH_REACH then
			table.insert(kept, part)
		end
	end
	return kept
end

local function register(current: Sess, registry: Targets.Registry)
	for _, scanned in table.clone(registry:List()) do
		const kind = scanned.Target.Kind
		local enabled: (() -> boolean)? = nil
		if kind == "BunCrate" then
			enabled = function(): boolean
				const open = live()
				return open ~= nil
					and open.Tab == "Board"
					and not plateOpen()
					and untrack(Session.Pending) == ""
					and not open.Closing
					and Session.Peek(open.Controller.View.Seal) == false
					and (not CONVEYOR or (belt.Pending == "" and canWork(open.Controller)))
			end
		elseif kind == "Rail" then
			-- the drag source of the front sausage (any free one on the conveyor), while the bun waits for it
			enabled = function(): boolean
				const open = live()
				return open ~= nil
					and open.Tab == "Board"
					and plateOpen()
					and not open.Flying
					and not placed()
					and untrack(Feed.Rail) > 0
					and (not CONVEYOR or (belt.Pending == "" and canWork(open.Controller) and restSlotAt(open, nil) ~= nil))
			end
		elseif kind == "Topping" then
			const key = scanned.Target.Topping
			enabled = function(): boolean
				const open = live()
				return open ~= nil and open.Tab == "Toppings" and plateOpen() and not open.Closing and untrack(Session.Pending) ~= "Finish"
					and (not placed() or (usedKeys(open)[key] ~= true) or toolKey() == key)
			end
		end
		const parts = nearParts(current, scanned.Parts)
		if enabled ~= nil and #parts > 0 then
			const real = if parts[1] ~= nil then realObject(parts[1], kind, scanned.Target.Topping) else nil
			const added = registry:Add({
				Target = scanned.Target,
				Parts = parts,
				Model = real or scanned.Model,
				Enabled = enabled,
			})
			current.Targets[added.Target.Id] = added
		end
	end
	-- the board: a hitbox as big as the working bun (the drop target of the sausage, the handle of the plate)
	const board = registry:Add({
		Target = Types.Target("Board", current.Seat),
		Parts = { current.Hitbox },
		Model = nil,
		Enabled = function(): boolean
			const open = live()
			if open == nil or not plateOpen() or open.Closing then
				return false
			end
			-- the drop target of the sausage and, once the bun is open, the handle of the plate (to the virtual bin) in both sections
			if open.Tab == "Board" then
				return open.View:Bun() == "Open"
			end
			return open.View:Bun() == "Open" and toolKey() == "" and untrack(Session.Pending) ~= "Finish"
		end,
	})
	current.Targets[board.Target.Id] = board
	-- the customer at the service window: the drop target of the plate in the Toppings view (delivery by drag)
	const customer = registry:Add({
		Target = Types.Target("Customer", 0, ""),
		Parts = { current.CustomerBox },
		Model = nil,
		Enabled = function(): boolean
			const open = live()
			return open ~= nil and canDeliver(open) and open.Drag ~= nil and open.Drag.Kind == "Plate"
		end,
	})
	current.CustomerTarget = customer
end

-- Acts -------------------------------------------------------------------------------------------------------------------------

-- A bun out of the crate: PrepBegin, and the bun lands on the board at once (the frame draws it from Pending).
local function beginPlate(current: Sess)
	const controller = current.Controller
	if plateOpen() or untrack(Session.Pending) ~= "" then
		return
	end
	const record = controller.Dependencies.KitchenController:StockOf("bun")
	if record ~= nil and record.Amount <= 0 then
		controller:Toast(TEXT.NoBun, "Alert")
		sfx(current, "error", nil)
		return
	end
	if CONVEYOR then
		if belt.Pending ~= "" or not canWork(controller) then
			return
		end
		-- the bun is only drawn: it leaves the stock with the cut (PrepStage Cut), so the plate opens here without a packet
		note("bun on the belt plate (drawn; the cut commits it)")
		Session.OnResult(controller, { Act = "Begin", Ok = true, Reason = "None", Grade = "None", Value = 0 })
		sfx(current, "grill_collect", current.View.Plane.Frame.Position)
		return
	end
	note("Begin sent (the bun crate)")
	Session.Begin(controller)
	sfx(current, "grill_collect", current.View.Plane.Frame.Position)
end

-- Conveyor commits (PrepStage) -------------------------------------------------------------------------------------------------

local function sendStage(current: Sess, stage: string, score: number, slot: number, retry: boolean)
	const controller = current.Controller
	belt.Pending = stage
	belt.Score = score
	belt.Slot = slot
	belt.Retried = retry
	belt.Stamp += 1
	const stamp = belt.Stamp
	if controller.Mock then
		-- `/dev prep ui`: no packet, the prediction is the truth
		belt.Pending = ""
		belt.Confirmed[stage] = true
		return
	end
	note(`PrepStage {stage} score {math.floor(score)} slot {slot}`)
	controller.Libs.Net.PrepStage:fireServer({
		Stage = stage,
		Score = math.clamp(math.floor(score), 0, 100),
		Slot = math.clamp(math.floor(slot), 0, 8),
	})
	task.delay(STAGE_TIMEOUT, function()
		if belt.Stamp == stamp and belt.Pending == stage then
			-- no answer: the seat record decides (reconcile)
			belt.Pending = ""
		end
	end)
end

-- The server has the bit of a stage on the plate (PrepSeats.Plate), nil = no record.
local function maskHas(controller: any, stage: string): boolean?
	const record = seatRecord(controller)
	if record == nil then
		return nil
	end
	const mask = if type(record.Plate) == "number" then record.Plate else 0
	const plate = PlateMask.Unpack(mask)
	return if stage == "Cut" then plate.Cut else plate.Sausage
end

-- A refused commit: the prediction goes (the Notice of the reason was shown by the controller).
local function undoStage(controller: any, stage: string, reason: string)
	note(`PrepStage {stage} refused: {reason}`)
	if stage == "Cut" then
		controller:ResetPlate()
		Session.Reset()
		beltForget()
		controller.Step("bun")
		return
	end
	Vide.batch(function()
		Session.Placed(false)
		controller.View.Sausage(false)
	end)
	controller:Need("SausagePlaced", false)
	controller:Need("PlateBuilt", false)
	const current = session
	if current ~= nil then
		current.SausageOn = false
		current.View:SetSausage("None", nil)
		current.View:SetCarry(nil, nil, nil)
	end
	if reason == "Held" then
		controller:Toast(Ghost.HeldText("Rail", belt.Slot), "Alert")
	end
end

-- PrepResult Act = Stage (whatever tab is in front).
local function onStageResult(controller: any, result: any)
	const stage = belt.Pending
	if stage == "" then
		return
	end
	if result.Ok then
		belt.Pending = ""
		belt.Confirmed[stage] = true
		belt.MissSince = 0
		note(`PrepStage {stage} accepted ({tostring(result.Value)})`)
		return
	end
	const reason: string = result.Reason
	if reason == "Rate" and not belt.Retried then
		const stamp = belt.Stamp
		task.delay(STAGE_RETRY, function()
			const current = session
			if belt.Stamp == stamp and belt.Pending == stage and current ~= nil and not current.Dead then
				sendStage(current, stage, belt.Score, belt.Slot, true)
			end
		end)
		return
	end
	belt.Pending = ""
	-- Invalid = the plate already has it (a lost answer, a plate taken over): the record says which
	if reason == "Invalid" and maskHas(controller, stage) == true then
		belt.Confirmed[stage] = true
		return
	end
	undoStage(controller, stage, reason)
end

-- The picture follows the server's plate (PrepSeats.Plate): a bun / sausage it has and the picture lacks is adopted (a plate taken
-- over, a parked one); a confirmed one it lost (the plate was emptied, the ticket left) goes after MASK_GRACE.
local function reconcile(current: Sess)
	const controller = current.Controller
	if belt.Pending ~= "" or untrack(Session.Pending) ~= "" or current.Closing or current.Flying or current.Drag ~= nil then
		return
	end
	if os.clock() < belt.Quiet or Session.Peek(controller.View.Seal) ~= false then
		return
	end
	const record = seatRecord(controller)
	if record == nil or type(record.Stop) ~= "number" or record.Stop <= 0 then
		return
	end
	const plate = PlateMask.Unpack(if type(record.Plate) == "number" then record.Plate else 0)
	const neutral = prep.Grades.Bands.Good -- the score of a stage done elsewhere: the server keeps the real one
	if plate.Cut and Session.Cut() == nil then
		note("the server's plate has its bun cut: adopted")
		if not plateOpen() then
			Session.OnResult(controller, { Act = "Begin", Ok = true, Reason = "None", Grade = "None", Value = 0 })
		end
		Vide.batch(function()
			controller.View.Bun("Open")
			controller.View.Cut(1)
			controller.View.Guide(false)
		end)
		Session.SetCut(controller, neutral)
		belt.Confirmed.Cut = true
		controller.Step("place")
	end
	if plate.Cut and plate.Sausage and not placed() then
		note("the server's plate has its sausage: adopted")
		Session.SetPlace(controller, neutral)
		controller:Need("SausagePlaced", true)
		controller.View.Sausage({ X = build.Groove.X, Y = build.Groove.Y, State = "Ready" })
		belt.Confirmed.Dog = true
	end
	const lostCut = belt.Confirmed.Cut == true and not plate.Cut and Session.Cut() ~= nil
	const lostDog = belt.Confirmed.Dog == true and not plate.Sausage and placed()
	if not lostCut and not lostDog then
		belt.MissSince = 0
		return
	end
	const now = os.clock()
	if belt.MissSince == 0 then
		belt.MissSince = now
		return
	end
	if now - belt.MissSince < MASK_GRACE then
		return
	end
	belt.MissSince = 0
	if lostCut then
		note("the server's plate is empty: the picture follows")
		controller:ResetPlate()
		Session.Reset()
		beltForget()
		controller.Step("bun")
	else
		belt.Confirmed.Dog = false
		undoStage(controller, "Dog", "Lost")
	end
end

local function pickTool(current: Sess, key: string, held: boolean)
	const controller = current.Controller
	if toolKey() == key then
		-- the same bowl again puts the tool down
		Session.Active("")
		return
	end
	if not plateOpen() or untrack(Session.Pending) == "Finish" then
		return
	end
	-- another sauce still selected with its stroke on the bun: it lands first (and frees its slot)
	current.Director:Commit()
	if not placed() then
		controller:Toast(TEXT.PlaceFirst, "Alert")
		sfx(current, "error", nil)
		return
	end
	if usedKeys(current)[key] == true then
		controller:Toast(`It already has {nameOf(key)}.`, "Alert")
		sfx(current, "error", nil)
		return
	end
	if #Session.Toppings() >= MAX then
		controller:Toast(TEXT.TopMax, "Alert")
		sfx(current, "error", nil)
		return
	end
	const info = controller:InfoOf(key)
	-- a gift bowl still closed (owner request 2026-10-14): it is opened in the world ("Open"), never from here
	if info.Wrapped then
		controller:Toast(`Open the {nameOf(key)} bowl first!`, "Alert")
		sfx(current, "error", nil)
		return
	end
	-- (dev: `/dev prep ray` lets the gestures be tried with an empty bowl; the server still refuses the plate at Finish)
	if (info.Locked or info.Stock <= 0) and Players.LocalPlayer:GetAttribute("PrepRay") ~= true then
		controller:Toast(`Out of {nameOf(key)}! Restock it.`, "Alert")
		sfx(current, "error", nil)
		return
	end
	current.PickedHeld = held
	Session.Active(key)
	note(`tool {key}`)
end

local function onCut(current: Sess, score: number)
	const controller = current.Controller
	const view = controller.View
	Vide.batch(function()
		view.Bun("Open")
		view.Cut(1)
		view.Guide(false)
	end)
	current.View:SetBun("Open", true)
	Session.SetCut(controller, score)
	World.Coach():Done("Board")
	controller.Step("place")
	current.Step = "place"
	current.View:Burst(bandOf(score))
	note(`cut {score}`)
	if CONVEYOR then
		sendStage(current, "Cut", score, 0, false)
	end
end

local function onPlaced(current: Sess, score: number)
	const controller = current.Controller
	Session.SetPlace(controller, score)
	controller:Need("SausagePlaced", true)
	controller.View.Sausage({ X = build.Groove.X, Y = build.Groove.Y, State = "Ready" })
	current.SausageOn = true
	World.Coach():Done("Sausage")
	current.View:SetSausage("Placed", GROOVE)
	current.View:SetCarry(nil, nil, nil)
	sfx(current, "hotdog_assemble", current.View.Plane.Frame.Position)
	current.View:Burst(bandOf(score))
	note(`placed {score}`)
	if CONVEYOR then
		-- the plate stays on the belt (the dish is World/Belt's); the player moves it on with the arrows
		sendStage(current, "Dog", score, current.RailSlot, false)
		return
	end
	-- the bun crate stands where the plate will sit (between the board and the bowls): it steps aside while the plate is open
	const crate = current.Targets["BunCrate"]
	if crate ~= nil and crate.Model ~= nil then
		current.View:HideWorld(crate.Model)
	end
	-- the hot dog goes onto a plate at once; the plate slides to the bowls with the camera (Enter of the Toppings tab)
	current.View:SetPlate(true)
	task.delay(0.35, function()
		if session == current and current.Active and not current.Dead and current.Tab == "Board" and plateOpen() and placed() then
			controller:SetStage("toppings")
		end
	end)
end

-- Where the plate sits to be dressed: next to the bowls, on the bench, derived from the real bowl targets (centre of the grid, the
-- side of the player, never off the bench: View:FindSpot). Cached; the board itself is the fallback.
local function assemblyOf(current: Sess): Vector3
	if CONVEYOR then
		-- the plate is dressed where it stands: on the Toppings stop of the belt
		return beltPoint("Toppings") or current.Home
	end
	if current.Assembly ~= nil then
		return current.Assembly
	end
	const bowls: { BasePart } = {}
	local sumX, sumZ = 0, 0
	for id, target in current.Targets do
		if string.sub(id, 1, 8) == "Topping:" then
			for _, part in target.Parts do
				table.insert(bowls, part)
				sumX += part.Position.X
				sumZ += part.Position.Z
			end
		end
	end
	local spot: Vector3? = nil
	if #bowls > 0 then
		-- the bowls go round the plate (map: arc of 2 + 4): the spot is the front centre, in the gap between the two front bowls
		-- (middle of the row nearest to the camera); a map without that gap (a bowl in the way) falls back to the nearest free spot
		const pose = Poses.Of(current.Seat, "Toppings")
		if pose ~= nil then
			const camera = pose.Frame.Position
			const flat = Vector3.new(pose.Frame.LookVector.X, 0, pose.Frame.LookVector.Z)
			const ahead = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
			-- depth along the view: the front row is the one nearest to the player
			local nearest = math.huge
			for _, part in bowls do
				nearest = math.min(nearest, (part.Position - camera):Dot(ahead))
			end
			local countFront = 0
			local frontPoint = Vector3.zero
			for _, part in bowls do
				if (part.Position - camera):Dot(ahead) <= nearest + 0.5 then
					frontPoint += part.Position
					countFront += 1
				end
			end
			if countFront >= 2 then
				const middle = frontPoint / countFront
				const candidate = Vector3.new(middle.X, current.Home.Y, middle.Z)
				-- clear of the FRONT row only: the plate is wider than the gap to the back row on purpose (it sits on the white Board slab at
				-- the front of the counter; the back bowls may sit a little over its rim), so only the two bowls that flank it are tested
				local clear = true
				for _, part in bowls do
					if (part.Position - camera):Dot(ahead) > nearest + 0.5 then
						continue
					end
					const local_ = part.CFrame:PointToObjectSpace(Vector3.new(candidate.X, part.Position.Y, candidate.Z))
					const outX = math.max(math.abs(local_.X) - part.Size.X / 2, 0)
					const outZ = math.max(math.abs(local_.Z) - part.Size.Z / 2, 0)
					if math.sqrt(outX * outX + outZ * outZ) < current.View.PlateRadius * 0.9 then
						clear = false
						break
					end
				end
				if clear then
					spot = candidate
				end
			end
		end
	end
	if spot == nil and #bowls > 0 then
		const pose = Poses.Of(current.Seat, "Toppings")
		const toward = if pose ~= nil then -pose.Frame.LookVector else Vector3.zero
		spot = current.View:FindSpot(Vector3.new(sumX / #bowls, current.Home.Y, sumZ / #bowls), bowls, toward)
	end
	const chosen: Vector3 = spot or current.Home
	current.Assembly = chosen
	note(`assembly point {tostring(chosen)}`)
	return chosen
end

local function onTopping(current: Sess, key: string, measured: number, amount: number, path: { { Vector2 } }?)
	const controller = current.Controller
	local score = measured
	-- conveyor (DEC-305): a drawn sauce is scored against ITS pattern (the same trace measure and Grade); the guided pour (hold, the
	-- gamepad) keeps its own score, it does not draw
	const guided = untrack(function(): boolean
		return Session.Guided("trace")
	end)
	if CONVEYOR and path ~= nil and #path > 0 and Strokes.PatternOf(key) ~= nil and not guided then
		const params: trace.Params = {
			Aspect = Plane.Aspect(current.View.Plane),
			Path = Strokes.PathOf(key),
			Reach = build.Sauce.Reach,
			Spill = build.Sauce.Spill,
		}
		const coverage, excess = trace.MeasureAll(path :: { { any } }, params)
		score = Score.Value(prep, key, coverage, excess, Session.Peek(controller.Assist) == true)
		note(`topping {key} on the {Strokes.PatternOf(key) or "?"}: coverage {math.floor(coverage)} excess {math.floor(excess)}`)
	end
	current.Drawn[key] = true
	Session.AddTopping(controller, key, score, amount, path)
	World.Coach():Done("Toppings")
	current.View:Burst(bandOf(score))
	note(`topping {key} {score}`)
end

-- Plate -----------------------------------------------------------------------------------------------------------------------

local function resetPlate(current: Sess, dust: boolean)
	if dust then
		current.View:Dust()
	end
	current.View:SetBun("None", false)
	const crate = current.Targets["BunCrate"]
	if crate ~= nil and crate.Model ~= nil then
		current.View:ShowWorld(crate.Model)
	end
	current.View:SetPlate(false)
	current.View:MoveTo(if CONVEYOR then (beltPoint(current.Tab) or current.Home) else current.Home, 0)
	current.View:SetSausage("None", nil)
	current.View:SetCarry(nil, nil, nil)
	for key in current.Drawn do
		current.View:SetTopping(key, nil, 0)
	end
	table.clear(current.Drawn)
	current.Strokes:Clear()
	current.Tool:Set("None", "")
	current.SausageOn = false
	current.ToolKey = ""
	if toolKey() ~= "" then
		Session.Active("")
	end
end

-- The picture follows the plate of the Session: the bun (predicted while PrepBegin waits), the sausage, the toppings.
local function syncPlate(current: Sess)
	const bun = bunState(current)
	const pending = untrack(Session.Pending) == "Begin"
	const wanted: BoardView.BunState = if bun == "Open" then "Open" elseif bun == "Closed" or bun == "Cut" or pending then "Closed" else "None"
	const shown = current.View:Bun()
	if wanted ~= shown then
		if wanted == "None" then
			resetPlate(current, true)
		else
			current.View:SetBun(wanted, false)
		end
	end
	if wanted == "None" then
		return
	end
	if placed() and not current.SausageOn then
		current.SausageOn = true
		current.View:SetSausage("Placed", GROOVE)
	elseif not placed() and current.SausageOn then
		current.SausageOn = false
		current.View:SetSausage("None", nil)
	end
	-- a plate seen again (a tab left and entered): the toppings it already has are drawn once
	for _, entry in Session.Toppings() do
		if not current.Drawn[entry.Key] then
			current.Drawn[entry.Key] = true
			const tolerance = prep.Tolerances.ByKey[entry.Key]
			if tolerance ~= nil and tolerance.Gesture == "trace" then
				-- the line as it was drawn (Session keeps it), else the guide path
				const path = entry.Path
				if path ~= nil and #path > 0 then
					for _, segment in path do
						current.Strokes:Begin(Strokes.ColorOf(entry.Key), entry.Key)
						for _, point in segment do
							current.Strokes:Add(point)
						end
						current.Strokes:Keep()
					end
				else
					current.Strokes:Begin(Strokes.ColorOf(entry.Key))
					for _, point in Strokes.PathOf(entry.Key) do
						current.Strokes:Add(Vector2.new(point.X, point.Y))
					end
					current.Strokes:Keep()
				end
			else
				current.View:SetTopping(entry.Key, GROOVE, 1)
			end
		end
	end
end

-- The cosmetic mask of the plate rides on PrepTab.
local function syncMask(current: Sess)
	const controller = current.Controller
	local mask = 0
	if bunState(current) ~= "None" and plateOpen() then
		const keys: { string } = {}
		for _, entry in Session.Toppings() do
			table.insert(keys, entry.Key)
		end
		mask = PlateMask.Pack({ Cut = Session.Cut() ~= nil, Sausage = placed(), Toppings = keys })
	end
	const now = os.clock()
	if controller.PlateMask ~= mask then
		controller.PlateMask = mask
		current.MaskSent = now
		current.MaskTries = 0
		controller:SendTab()
	elseif mask ~= 0 and current.MaskTries < 3 and now - current.MaskSent > MASK_RETRY then
		current.MaskSent = now
		current.MaskTries += 1
		controller:SendTab()
	end
end

-- The hand of the drag tutorial: the knife along the dashes (Board, once the bun waits), a bowl to the bun (Toppings, once the sausage
-- is in). Each is tried once per visit of the mode; the Coach keeps what was shown in this session.
local function coach(current: Sess)
	const hand = World.Coach()
	if hand:Active() then
		return
	end
	if current.Tab == "Board" and not current.CoachBoard and plateOpen() and (bunState(current) == "Closed" or bunState(current) == "Cut") then
		current.CoachBoard = true
		const cut = build.Cut
		const plane = current.View.Plane
		hand:Show("Board", {
			Plane.ToWorld(plane, Vector2.new(cut.From, cut.Y), boardRules.Guide.Lift),
			Plane.ToWorld(plane, Vector2.new(cut.To, cut.Y), boardRules.Guide.Lift),
		})
	elseif
		current.Tab == "Board"
		and not current.CoachSausage
		and plateOpen()
		and bunState(current) == "Open"
		and not placed()
		and not current.Flying
		and current.Drag == nil
		and untrack(Feed.Rail) > 0
	then
		-- the paw: the front sausage of the rail -> the groove of the bun (owner request 2026-10-14)
		local rail: BasePart? = nil
		for id, target in current.Targets do
			if string.sub(id, 1, 5) == "Rail:" and target.Parts[1] ~= nil then
				rail = target.Parts[1]
				break
			end
		end
		if rail ~= nil then
			current.CoachSausage = true
			const plane = current.View.Plane
			const groove = Plane.ToWorld(plane, GROOVE, boardRules.Guide.Lift)
			hand:Show("Sausage", { Vector3.new(rail.Position.X, groove.Y, rail.Position.Z), groove })
		end
	elseif
		current.Tab == "Toppings"
		and not current.CoachDeliver
		and #Session.Toppings() > 0
		and toolKey() == ""
		and canDeliver(current)
	then
		-- the paw: the plate -> the customer's delivery area (TASK-254), once a topping is on
		current.CoachDeliver = true
		const plane = current.View.Plane
		const from = plane.Frame.Position + Vector3.new(0, 0.1, 0)
		hand:Show("Deliver", { from, current.CustomerBox.Position })
	elseif current.Tab == "Toppings" and not current.CoachTop and plateOpen() and placed() and #Session.Toppings() == 0 and toolKey() == "" then
		current.CoachTop = true
		-- from the first bowl with stock to the middle of the bun
		for key in BOWL_TIPS do
			const target = current.Targets[`Topping:{key}`]
			if target ~= nil and target.Parts[1] ~= nil and current.Controller:InfoOf(key).Stock > 0 then
				const plane = current.View.Plane
				const from = Vector3.new(target.Parts[1].Position.X, plane.Frame.Position.Y, target.Parts[1].Position.Z)
				-- the plate may still be sliding to the topping table: the hand goes to where it will rest, not to where the plane is now
				const rest = assemblyOf(current)
				const goal = Vector3.new(rest.X, plane.Frame.Position.Y + 0.1, rest.Z)
				hand:Show("Toppings", { from, goal })
				break
			end
		end
	end
end

-- The gesture the plate wants now (Director3D mode), "none" when nothing is armed.
local function wantedMode(current: Sess): string
	if current.Closing or current.Flying or not plateOpen() or untrack(Session.Pending) == "Finish" or current.Drag ~= nil then
		return "none"
	end
	-- conveyor: nothing is worked while the plate travels, waits beside a busy stop or a commit is on its way
	if CONVEYOR and (belt.Pending ~= "" or not canWork(current.Controller)) then
		return "none"
	end
	-- the touch Hold pill, or the guided default of a gamepad (TASK-268: sauce and knife), arms the hold form
	local function guided(gesture: string): boolean
		return untrack(function(): boolean
			return Session.Guided(gesture)
		end)
	end
	if current.Tab == "Board" then
		const bun = bunState(current)
		if bun == "Closed" or bun == "Cut" then
			return if guided("slice") then "slice_hold" else "slice"
		end
		return "none"
	end
	if not placed() then
		return "none"
	end
	const key = toolKey()
	const tolerance = if key ~= "" then prep.Tolerances.ByKey[key] else nil
	if tolerance == nil then
		return "none"
	end
	const gesture = tolerance.Gesture
	return if (gesture == "trace" or gesture == "slide") and guided(gesture) then `{gesture}_hold:{key}` else `{gesture}:{key}`
end

local function frame(current: Sess, dt: number, time: number)
	if current.Dead then
		return
	end
	const controller = current.Controller
	const registry = World.Targets()
	Session.Sync(controller)
	current.Tick -= dt
	if current.Tick <= 0 then
		current.Tick = FRAME_TICK
		if current.Active then
			if CONVEYOR then
				reconcile(current)
			end
			syncPlate(current)
			syncMask(current)
			-- the virtual bin shows while the plate can be thrown (an open bun, no finish on its way)
			const bin = World.Bin()
			if bin ~= nil then
				bin:SetWanted(plateOpen() and current.View:Bun() == "Open" and not current.Closing and untrack(Session.Pending) ~= "Finish")
			end
			coach(current)
			if registry ~= nil then
				-- pulses: the invitation of the moment (touch has no hover)
				const open = plateOpen()
				const working = not CONVEYOR or (belt.Pending == "" and canWork(controller))
				setPulse(current, "BunCrate", working and current.Tab == "Board" and not open and untrack(Session.Pending) == "")
				setPulse(current, "Rail", working and current.Tab == "Board" and open and current.View:Bun() == "Open" and not placed() and untrack(Feed.Rail) > 0)
				-- conveyor: only the bowls of the ticket still missing glow (DEC-299 / TASK-502 rule, BELT_TIP_TOPPINGS)
				const wanted = if CONVEYOR then untrack(function(): { [string]: boolean }?
					return wantedToppings(controller)
				end) else nil
				const used = usedKeys(current)
				for key in current.Targets do
					if string.sub(key, 1, 8) == "Topping:" then
						const topping = string.sub(key, 9)
						const asked = wanted == nil or (wanted[topping] == true and used[topping] ~= true)
						setPulse(current, key, working and asked and current.Tab == "Toppings" and open and placed() and toolKey() == "" and #Session.Toppings() < MAX)
					end
				end
				const board = current.Targets[`Board:{current.Seat}`]
				if board ~= nil and board.Model ~= current.View:BunModel() then
					board.Model = current.View:BunModel()
					registry:Touch()
				end
			end
		end
	end
	if current.Active then
		-- the tool in the hand follows the key of the Session
		const key = toolKey()
		if key ~= current.ToolKey then
			current.ToolKey = key
			-- the guide track follows the pattern of the sauce (conveyor; a no-op in the trailer), before the gesture arms
			current.Strokes:SetPattern(if key ~= "" then key else nil)
			if key == "" then
				current.Tool:Set("None", "")
			else
				current.Tool:Set((prep.ToolOf[key] or "None") :: ToolView.Kind, key)
			end
		end
		-- the gesture: armed when the mode changes; a tool picked by a press that is still down waits for the pointer to reach the mat
		const want = wantedMode(current)
		const pointer = controller.Pointer
		if want ~= current.WantMode then
			current.WantMode = want
			current.HeldPending = want ~= "none" and current.PickedHeld and pointer ~= nil and pointer.Down
			current.PickedHeld = false
			current.Director:SetMode(if current.HeldPending then "none" else want, false)
		end
		if current.HeldPending and pointer ~= nil then
			if not pointer.Down then
				current.HeldPending = false
				current.Director:SetMode(want, false)
			elseif current.Director:Inside(pointer.Position) then
				current.HeldPending = false
				current.Director:SetMode(want, true)
			end
		end
		current.Director:Frame(dt)
		followCustomer(current)
		if CONVEYOR and not (current.Drag ~= nil and current.Drag.Kind == "Plate") then
			-- the stack rides on the own plate of World/Belt (it glides between the stops)
			const at = beltPoint(current.Tab)
			if at ~= nil and (at - current.View:Anchor()).Magnitude > 0.01 then
				current.View:MoveTo(at, 0)
			end
		end
	else
		current.Mark:Hide()
	end
	current.View:Step(dt, time)
	current.Tool:Step(dt)
end

-- Build and tear down ------------------------------------------------------------------------------------------------------------

-- DEC-259: lets go of the claimed front rail sausage (PrepGrab Off).
local function releaseRail(current: Sess)
	if not current.RailGrab then
		return
	end
	current.RailGrab = false
	current.Controller.Libs.Net.PrepGrab:fireServer({ From = "Rail", Slot = math.clamp(current.RailSlot, 1, 8), On = false })
end

local function teardown()
	const current = session
	if current == nil then
		return
	end
	session = nil
	current.Dead = true
	current.Active = false
	if current.Stop ~= nil then
		current.Stop()
	end
	releaseRail(current)
	current.Director:Destroy()
	current.Tool:Destroy()
	current.Strokes:Destroy()
	current.View:Destroy()
	current.Hitbox:Destroy()
	current.CustomerBox:Destroy()
	current.Mark:Destroy()
	hover("")
	World.SetWorkPlane(nil)
	const bin = World.Bin()
	if bin ~= nil then
		bin:SetWanted(false)
	end
	const registry = World.Targets()
	if registry ~= nil then
		-- the target made of this session's own parts goes with it
		registry:Remove(`Board:{current.Seat}`)
		if current.CustomerTarget ~= nil and registry:Get(CUSTOMER_ID) == current.CustomerTarget then
			registry:Remove(CUSTOMER_ID)
		end
		registry:Touch()
	end
end

local function build3D(controller: any)
	const registry = World.Targets()
	const aim = World.Aim()
	const camera = workspace.CurrentCamera
	const folder = if camera ~= nil then camera:FindFirstChild(Types.FolderName) else nil
	if registry == nil or aim == nil or folder == nil then
		error("the 3D world is not running")
	end
	const seat = Session.Peek(controller.Station)
	local centre: Vector3
	local knifeInstance: Instance? = nil
	local right = Vector3.xAxis
	if CONVEYOR then
		-- the belt (TASK-520): the bun goes on the own plate of World/Belt, at the stop in front; the bench's knife cuts it
		const point = beltPoint(Session.Peek(controller.Tab))
		if point == nil then
			error("no plate on the conveyor (World/Belt has no plate frame and the bench has no Stop_n)")
		end
		centre = point :: Vector3
		const knife = World.Belt.Anchor("Knife")
		if knife ~= nil and knife:IsA("BasePart") and (knife.Position - centre).Magnitude <= BENCH_REACH then
			knifeInstance = knife
		end
		-- the screen right of the stop view, flat: the bun lies along it (the belt runs along it too)
		const pose = controller:BeltPose("Board")
		const reference = if pose ~= nil then pose.Frame else (camera :: Camera).CFrame
		const flat = Vector3.new(reference.RightVector.X, 0, reference.RightVector.Z)
		right = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	else
		-- the authored hitbox of the seat's board slot (the registry may hold a stage target of an older entry instead)
		local part: BasePart? = nil
		for _, instance in CollectionService:GetTagged(world.Tag) do
			if
				instance:IsA("BasePart")
				and instance:GetAttribute(world.Attr.Kind) == "Board"
				and instance:GetAttribute(world.Attr.Slot) == seat
				and instance:IsDescendantOf(workspace)
			then
				part = instance
				break
			end
		end
		if part == nil then
			error("no Board hitbox for the seat in the trailer (tag PrepTarget, TargetKind Board)")
		end
		const targetsModel = part.Parent
		const trailer = if targetsModel ~= nil then targetsModel.Parent else nil
		const attachment = if trailer ~= nil then trailer:FindFirstChild(`Att_Bun{seat}`, true) else nil
		const anchor = if attachment ~= nil and attachment:IsA("Attachment") then attachment.WorldPosition else part.Position - Vector3.new(0, 0.25, -0.2)
		-- the working bun sits in the middle of the board mesh (the seat's slot would crowd the crate), at the height of the slot
		-- (the CUTTING board of the trailer: the topping counter has a white slab named Board too, the plate's spot, not this one)
		local boardMesh: Instance? = nil
		if trailer ~= nil then
			for _, child in trailer:GetChildren() do
				if child:IsA("Model") and child:GetAttribute("StationKind") == "board" then
					boardMesh = child:FindFirstChild("Board", true)
					break
				end
			end
			boardMesh = boardMesh or trailer:FindFirstChild("Board", true)
		end
		centre = if boardMesh ~= nil and boardMesh:IsA("BasePart") then Vector3.new(boardMesh.Position.X, anchor.Y, anchor.Z) else anchor
		knifeInstance = if trailer ~= nil then trailer:FindFirstChild("Knife", true) else nil
		-- the screen right of the Board view, flat: the bun lies along it
		const pose = Poses.Of(seat, "Board")
		const reference = if pose ~= nil then pose.Frame else (camera :: Camera).CFrame
		const flat = Vector3.new(reference.RightVector.X, 0, reference.RightVector.Z)
		right = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	end
	const kitchen = controller.Dependencies.KitchenController
	const view = BoardView.new({
		Folder = folder :: Folder,
		Rules = world,
		Seat = seat,
		Anchor = centre,
		Right = right,
		SlotView = function(kind: string, slot: number): any
			return kitchen:SlotView(kind, slot)
		end,
		Knife = if knifeInstance ~= nil and knifeInstance:IsA("BasePart") then knifeInstance else nil,
		RailFront = 1,
		Belt = CONVEYOR,
		Juice = World.Juice,
		Altered = function(): boolean
			return untrack(Session.Altered)
		end,
	})
	const tool = ToolView.new(folder :: Folder, world, view.Orient)
	const strokes = Strokes.new(folder :: Folder, world, view.Plane, function(uv: Vector2): number
	return view:SurfaceHeight(uv)
end)
	-- the hitbox of the board: the bun as it is drawn, a little generous
	const hitbox = Instance.new("Part")
	hitbox.Name = "Prep_BunHitbox"
	hitbox.Size = Vector3.new(view.Plane.Length * 1.15, 0.9, view.Plane.Width * 1.25)
	hitbox.CFrame = CFrame.new(view.Plane.Frame.Position - Vector3.yAxis * 0.35) * view.Orient
	hitbox.Anchored = true
	hitbox.Transparency = 1
	hitbox.CanQuery = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.Parent = folder
	const customerBox = Instance.new("Part")
	customerBox.Name = "Prep_CustomerHitbox"
	customerBox.Size = Vector3.new(build.Deliver.Width, build.Deliver.Height, build.Deliver.Depth)
	customerBox.CFrame = CFrame.new(0, -500, 0)
	customerBox.Anchored = true
	customerBox.Transparency = 1
	customerBox.CanQuery = true
	customerBox.CanCollide = false
	customerBox.CanTouch = false
	customerBox.Parent = folder
	const current: Sess = {
		Controller = controller,
		Kitchen = kitchen,
		Folder = folder :: Folder,
		Seat = seat,
		View = view,
		Tool = tool,
		Strokes = strokes,
		Director = nil :: any,
		Hitbox = hitbox,
		Targets = {},
		Pulse = {},
		Stop = nil,
		Tab = "Board",
		Step = "bun",
		Active = true,
		LeavePending = false,
		Dead = false,
		Closing = false,
		Drag = nil,
		Drawn = {},
		SausageOn = false,
		WantMode = "none",
		HeldPending = false,
		PickedHeld = false,
		ToolKey = "",
		Tick = 0,
		MaskSent = 0,
		MaskTries = 0,
		Home = centre,
		Placed = false,
		Flying = false,
		Assembly = nil,
		CoachBoard = false,
		CoachTop = false,
		CoachSausage = false,
		CoachDeliver = false,
		CustomerBox = customerBox,
		CustomerTarget = nil,
		CustomerId = 0,
		CustomerModel = nil,
		CustomerLook = 0,
		Mark = DeliverMark.new(),
		DeliverTo = 0,
		CarryOver = false,
		RailGrab = false,
		RailSlot = 1,
	}
	current.Director = Director3D.new({
		Folder = folder :: Folder,
		Gestures = controller.Gestures,
		Pointer = controller.Pointer,
		View = view,
		Tool = tool,
		Strokes = strokes,
		Assist = function(): boolean
			return Session.Peek(controller.Assist) == true
		end,
		Sfx = function(key: string, at: Vector3?)
			sfx(current, key, at)
		end,
		OnCut = function(score: number)
			onCut(current, score)
		end,
		OnTopping = function(key: string, score: number, amount: number, path: { { Vector2 } }?)
			onTopping(current, key, score, amount, path)
		end,
		Deselect = function()
			if toolKey() ~= "" then
				note("tool put down")
				Session.Active("")
			end
		end,
		OverTarget = function(): boolean
			const aim = World.Aim()
			return aim ~= nil and aim.Source ~= nil
		end,
		CanLand = function(): boolean
			return not current.Dead and not current.Closing and plateOpen() and placed() and untrack(Session.Pending) ~= "Finish"
				and bunState(current) == "Open"
		end,
		Refuse = function(text: string)
			note(`refused: {text}`)
			controller:Toast(text, "Info")
			sfx(current, "error", nil)
		end,
	})
	-- the plate follows the section: the sauce segments and the hitbox slide with it
	view:SetMoved(function(delta: Vector3)
		strokes:Shift(delta)
		hitbox.Position += delta
	end)
	session = current
	register(current, registry)
	World.SetWorkPlane({ Origin = view.Plane.Frame.Position, Normal = Vector3.yAxis })
	current.Stop = aim:OnFrame(function(dt: number, time: number)
		const ok, problem = pcall(frame, current, dt, time)
		if not ok then
			warn(`[PrepWorld] Board frame: {problem}`)
		end
	end)
	-- the mode can end while another tab is in front: the world's own objects must come back
	folder.Destroying:Connect(function()
		if session == current then
			teardown()
		end
	end)
end

-- Aim -------------------------------------------------------------------------------------------------------------------------

local function setHover(current: Sess, target: Types.Target?)
	if target == nil then
		hover("")
		return
	end
	const kind = target.Target.Kind
	if kind == "BunCrate" then
		hover(TEXT.Crate)
	elseif kind == "Rail" then
		hover(if current.View:Bun() == "Open" then TEXT.Place else TEXT.CutFirst)
	elseif kind == "Board" then
		hover(if current.Tab == "Board" and not placed() then (if current.View:Bun() == "Open" then TEXT.Place else TEXT.Knife) else TEXT.Bin)
	elseif kind == "Topping" then
		hover(BOWL_TIPS[target.Target.Topping] or "")
	elseif kind == "Bin" then
		hover(TEXT.Bin)
	elseif kind == "Customer" then
		hover(TEXT.Deliver)
	else
		hover("")
	end
end

-- The bun-space point UNDER the pointer: the camera ray through the (lifted) point of the aim, cut by the bun plane. What the finger
-- covers is where it lands; the lifted point itself would read a quarter of a bun width off (it floats over the bun).
local function underPointer(current: Sess, point: Vector3): Vector2
	const camera = workspace.CurrentCamera
	if camera ~= nil then
		const origin = camera.CFrame.Position
		const offset = point - origin
		if offset.Magnitude > 1e-3 then
			const uv = Plane.FromRay(current.View.Plane, origin, offset.Unit)
			if uv ~= nil then
				return uv
			end
		end
	end
	return Plane.ToUV(current.View.Plane, point)
end

-- The sausage under the pointer: samples in the bun space, the snap to the groove inside the magnet.
local function dragSausage(current: Sess, point: Vector3)
	const drag = current.Drag
	if drag == nil then
		return
	end
	const uv = underPointer(current, point)
	table.insert(drag.Points, uv)
	if #drag.Points > 90 then
		table.remove(drag.Points, 1)
	end
	const _, near = current.Director:MeasurePlace({ uv, uv, uv })
	current.View:SetCarry("Sausage", point, if near then GROOVE else nil)
	current.View:SetSausage(if near then "Ghost" else "None", GROOVE)
end

local function endDrag(current: Sess)
	releaseRail(current)
	const had = current.Drag ~= nil
	current.Drag = nil
	current.CarryOver = false
	current.View:SetCarry(nil, nil, nil)
	if not placed() then
		current.View:SetSausage("None", nil)
	end
	if had then
		-- the gesture of the mode may arm again
		current.WantMode = "?"
	end
end

const Build: Stage.Stage3D = {
	Tabs = { "Board", "Toppings" },
	Enter = function(controller: any, tab: string)
		local current = session
		if current ~= nil and (current.Dead or current.Folder.Parent == nil) then
			teardown()
			current = nil
		end
		if current == nil then
			const ok, problem = pcall(build3D, controller)
			if not ok then
				-- never leave the player seated without a way to play: give the seat back
				warn(`[PrepController] 3D board failed to start, leaving the mode: {problem}`)
				task.defer(function()
					controller:Leave("StageFailed", false, false)
				end)
				return
			end
			current = session
		end
		if current == nil then
			return
		end
		const first = not current.Placed
		current.LeavePending = false
		current.Active = true
		current.Tab = tab
		current.WantMode = "?"
		-- the hot dog is on a plate once the sausage is in: the plate sits beside the bowls (assemblyOf) in whichever tab, and slides
		-- there with the camera (a spring); before that the bun stays on the board
		-- Where the hot dog is, in ONE place: once the sausage is in (placed) the plate is on the topping table and never goes back to
		-- the board. A stage that was torn down and built again (the pan crossed the Grill and came back) starts with no plate in its
		-- view, so the plate is rebuilt from the Session here, before it is placed.
		if CONVEYOR then
			-- the stack rides on the belt plate (the frame keeps it there while it glides)
			current.View:MoveTo(beltPoint(tab) or current.View:Anchor(), 0)
		else
			if placed() and plateOpen() and not current.View:HasPlate() then
				current.View:SetPlate(true)
			end
			current.View:MoveTo(
				if current.View:HasPlate() then assemblyOf(current) else current.Home,
				if first then 0 else boardRules.Slide
			)
		end
		current.Placed = true
		Session.Sync(controller)
		-- coming back to the Board with the bun already cut: the step follows the plate
		if tab == "Board" and Session.Cut() ~= nil and Session.Peek(controller.Step) == "bun" then
			controller.Step("place")
		end
		const registry = World.Targets()
		if registry ~= nil then
			registry:Touch()
		end
	end,
	Leave = function(controller: any, _tab: string)
		const current = session
		if current == nil then
			return
		end
		current.Active = false
		current.LeavePending = true
		current.Drag = nil
		current.Director:SetMode("none", false)
		current.Tool:Set("None", "")
		current.ToolKey = ""
		if toolKey() ~= "" then
			Session.Active("")
		end
		const aim = World.Aim()
		if aim ~= nil then
			aim:Cancel("Leave")
		end
		hover("")
		-- the other tab of this stage takes it over in the same frame; anything else lets the plate go
		task.defer(function()
			if session == current and current.LeavePending then
				teardown()
			end
		end)
	end,
	Step = function(_controller: any, step: string)
		const current = session
		if current ~= nil then
			current.Step = step
		end
	end,
	Hint = function(controller: any): string
		const tip = hover()
		if tip ~= "" and toolKey() == "" then
			return tip
		end
		const tab = controller.Tab()
		const open = Session.Open()
		if controller.View.Seal() ~= false then
			return if CONVEYOR then "" else prep.Build.Texts.Ready
		end
		if CONVEYOR then
			if tab == "Board" then
				if not open then
					return TEXT.Crate
				end
				const bun = controller.View.Bun()
				if bun == "Closed" or bun == "Cut" then
					return if Session.Guided("slice") then TEXT.SliceHold else TEXT.Slice
				end
				if not Session.Placed() then
					return if Feed.Rail() == 0 then prep.Texts.Waiting else BELT_TEXT.Dog
				end
				return BELT_TEXT.BoardDone
			end
			if not open or not Session.Placed() then
				return TEXT.NeedPlate
			end
			const key = Session.Active()
			const tolerance = if key ~= "" then prep.Tolerances.ByKey[key] else nil
			if tolerance ~= nil and tolerance.Gesture == "trace" and not Session.Guided("trace") then
				-- BELT_PAT_*: "Ketchup: trace the zigzag"
				const pattern = Strokes.PatternOf(key)
				const row = Content.Ingredients.ByKey[key]
				if pattern ~= nil and row ~= nil then
					return `{row.Name}: trace the {string.lower(prep.Texts.Patterns[key] or pattern)}`
				end
			end
			if tolerance == nil then
				const wanted = wantedToppings(controller)
				const used = controller.View.Used()
				if wanted ~= nil then
					local asked, missing = 0, 0
					for topping, on in wanted do
						if on then
							asked += 1
							if used[topping] ~= true then
								missing += 1
							end
						end
					end
					if asked == 0 then
						return BELT_TEXT.NoTop
					end
					return if missing == 0 or #Session.Toppings() >= MAX then BELT_TEXT.Finish else BELT_TEXT.Toppings
				end
				return if #Session.Toppings() >= MAX then BELT_TEXT.Finish else BELT_TEXT.Toppings
			end
		end
		if tab == "Board" then
			if not open then
				return TEXT.Crate
			end
			const bun = controller.View.Bun()
			if bun == "Closed" or bun == "Cut" then
				return if Session.Guided("slice") then TEXT.SliceHold else TEXT.Slice
			end
			if not Session.Placed() then
				return if Feed.Rail() == 0 then prep.Texts.Waiting else TEXT.Place
			end
			return TEXT.NextBoard
		end
		if not open or not Session.Placed() then
			return TEXT.NeedPlate
		end
		const key = Session.Active()
		const tolerance = if key ~= "" then prep.Tolerances.ByKey[key] else nil
		if tolerance == nil then
			return if #Session.Toppings() >= MAX then TEXT.Full else TEXT.Add
		end
		const gesture = tolerance.Gesture
		if gesture == "trace" then
			-- gamepad (TASK-268): the guided pour, or free drawing; X / Square switches (glyphs by KeyHint in the shell)
			if Session.Pad() then
				return if Session.Guided("trace") then TEXT.TracePad else TEXT.TracePadFree
			end
			return if Session.Guided("trace") then TEXT.TraceHold else TEXT.Trace
		elseif gesture == "slide" then
			return if Session.Guided("slide") then TEXT.SlideHold else TEXT.Slide
		elseif gesture == "taps" then
			return TEXT.Taps
		end
		return TEXT.Hold
	end,
	Next = function(controller: any): Stage.Next
		-- every source is read first: a short-circuited read would not be a dependency of the binding
		const open = Session.Open()
		const isPlaced = Session.Placed()
		const sealed = controller.View.Seal() ~= false
		const finishing = Session.Pending() == "Finish"
		const cut = controller.Needs().BunCut == true
		const tab = controller.Tab()
		const toppings = #controller.View.Toppings()
		if CONVEYOR then
			-- the belt (TASK-518): Right is the arrow; on the Toppings stop it is this Finish (OnNext), ready with the bun and the sausage
			if tab ~= "Toppings" then
				return { Label = prep.Texts.Right, Enabled = false }
			end
			const ready = open and isPlaced and not sealed and not finishing
			return { Label = prep.Texts.Finish, Enabled = ready, Pulse = ready }
		end
		if sealed or finishing then
			return { Label = prep.Texts.Next, Enabled = false }
		end
		if tab == "Board" then
			const ready = open and cut and isPlaced
			return { Label = prep.Texts.Next, Enabled = ready, Pulse = ready }
		end
		const ready = open and isPlaced
		return { Label = if prep.Rules.Delivery == "Prompt" then prep.Texts.Done else prep.Texts.Next, Enabled = ready, Pulse = ready and toppings > 0 }
	end,
	OnNext = function(controller: any)
		if CONVEYOR then
			-- the Finish of the Toppings stop (the Right arrow); the Board stop has no Next (the arrow moves the plate)
			const current = session
			if Session.Peek(controller.Tab) ~= "Toppings" or (current ~= nil and current.Closing) then
				return
			end
			if belt.Pending ~= "" or not canWork(controller) then
				return
			end
			if current ~= nil then
				current.Director:Commit()
			end
			note("Finish: PrepFinish (conveyor)")
			Session.Finish(controller)
			return
		end
		if Session.Peek(controller.Tab) == "Board" then
			note("Next: to the toppings")
			controller:SetStage("toppings")
			return
		end
		const current = session
		if current ~= nil and current.Closing then
			return
		end
		-- a sauce still selected lands first: its score goes into the summary
		if current ~= nil then
			current.Director:Commit()
		end
		note("Next: PrepFinish")
		Session.Finish(controller)
	end,
	OnAim = function(controller: any, message: any)
		const current = live()
		if current == nil then
			return
		end
		const kind: string = message.Kind
		if kind == "Hover" then
			setHover(current, message.Target)
		elseif kind == "Press" then
			const target = message.Target :: Types.Target
			const targetKind = target.Target.Kind
			if targetKind == "BunCrate" then
				beginPlate(current)
			elseif targetKind == "Rail" then
				if current.View:Bun() ~= "Open" then
					controller:Toast(TEXT.CutFirst, "Alert")
					sfx(current, "error", nil)
					return
				end
				if CONVEYOR then
					-- any free sausage of the rest table, the one nearest the press; a colleague's is out of reach at once (DEC-259)
					if belt.Pending ~= "" or not canWork(controller) then
						return
					end
					const slot, heldText = restSlotAt(current, message.Point)
					if slot == nil then
						controller:Toast(heldText or prep.Texts.Waiting, "Alert")
						sfx(current, "error", nil)
						return
					end
					current.RailSlot = slot
					current.View:SetRailSlot(slot)
					current.RailGrab = true
					controller.Libs.Net.PrepGrab:fireServer({ From = "Rail", Slot = slot, On = true })
				else
					-- DEC-259: a colleague holds the front sausage of the rail: it does not come
					const holder, heldText = Ghost.HeldBy("Rail", 1)
					if holder ~= nil then
						controller:Toast(heldText :: string, "Alert")
						sfx(current, "error", nil)
						return
					end
					if prep.Rules.World.GhostHand and not current.RailGrab then
						current.RailGrab = true
						controller.Libs.Net.PrepGrab:fireServer({ From = "Rail", Slot = 1, On = true })
					end
				end
				current.Drag = { Kind = "Sausage", Points = {} }
				current.View:SetCarry("Sausage", message.Point, nil)
				current.Director:SetMode("none", false)
				current.WantMode = "none"
			elseif targetKind == "Topping" then
				-- a sauce is SELECTED by the press (it floats over the bun, nothing flows); the others are dragged from the bowl
				const picked: string = target.Target.Topping
				const tolerance = prep.Tolerances.ByKey[picked]
				pickTool(current, picked, not (tolerance ~= nil and tolerance.Gesture == "trace"))
			elseif targetKind == "Board" then
				current.Drag = { Kind = "Plate", Points = {} }
				current.View:SetCarry("Plate", message.Point, nil)
			end
		elseif kind == "Move" then
			const drag = current.Drag
			if drag == nil then
				return
			end
			if drag.Kind == "Sausage" then
				dragSausage(current, message.Point)
			else
				current.View:SetCarry("Plate", message.Point, nil)
				const over = message.Over :: Types.Target?
				current.CarryOver = over ~= nil and over.Target.Kind == "Customer"
			end
		elseif kind == "Tap" then
			-- a tap on the rail sausage sends it to the bun on its own: the same landing as a finished drag (onPlaced)
			const drag = current.Drag
			if drag ~= nil and drag.Kind == "Sausage" and not current.Flying then
				current.Drag = nil
				current.Flying = true
				current.Director:SetMode("none", false)
				current.WantMode = "none"
				const score = current.Director:MeasurePlace({ GROOVE, GROOVE, GROOVE })
				note(`sausage tapped: sent to the bun, score {tostring(score)}`)
				current.View:Fly(function()
					current.Flying = false
					if CONVEYOR and not current.Dead and not placed() then
						-- the commit (PrepStage Dog) takes the claimed position: the server drops the claim with it
						current.RailGrab = false
					end
					releaseRail(current)
					current.WantMode = "?"
					if current.Dead or placed() then
						current.View:SetCarry(nil, nil, nil)
						return
					end
					onPlaced(current, score or 100)
				end)
			end
		elseif current.Flying and (kind == "Release" or kind == "Cancel") then
			return
		elseif kind == "Release" or kind == "Cancel" then
			const drag = current.Drag
			if drag ~= nil and drag.Kind == "Sausage" and kind == "Release" then
				note("sausage released over nothing")
				sfx(current, "error", nil)
				controller:Toast(TEXT.Miss, "Info")
			elseif drag ~= nil and drag.Kind == "Plate" and kind == "Release" and canDeliver(current) then
				-- TASK-253: the plate goes back; say where it goes
				sfx(current, "error", nil)
				controller:Toast(build.Texts.DropOnCustomer, "Info")
			end
			endDrag(current)
		elseif kind == "Drop" then
			const drag = current.Drag
			const over = message.Over :: Types.Target
			if drag == nil then
				return
			end
			if drag.Kind == "Sausage" and over.Target.Kind == "Board" then
				const uv = underPointer(current, message.Point)
				table.insert(drag.Points, uv)
				const score, near = current.Director:MeasurePlace(drag.Points)
				note(`sausage drop: uv ({string.format("%.2f", uv.X)}, {string.format("%.2f", uv.Y)}), {#drag.Points} samples, score {tostring(score)}, inside the magnet {tostring(near)}`)
				if CONVEYOR and score ~= nil and near then
					-- the commit (PrepStage Dog) takes the claimed position: the server drops the claim with it
					current.RailGrab = false
				end
				endDrag(current)
				if score ~= nil and near then
					onPlaced(current, score)
				else
					sfx(current, "error", nil)
					controller:Toast(TEXT.Miss, "Info")
				end
			elseif drag.Kind == "Plate" and over.Target.Kind == "Customer" then
				-- bug 2026-10-14: the stack must not slide back to the board while the Finish travels. The lifted stack
				-- becomes a copy that flies to the customer; the originals and the sauce lines go at once.
				const thrown = current.View:TakeCarry()
				endDrag(current)
				if deliver(current) then
					current.Strokes:Clear()
					if thrown ~= nil then
						handOver(current, thrown)
					end
				else
					if thrown ~= nil then
						thrown:Destroy()
					end
					current.View:Restore()
				end
			elseif drag.Kind == "Plate" and over.Target.Kind == "Bin" then
				-- the plate ghost in the hand is swallowed by the bin (it keeps its pose, shrinks and falls in)
				const thrown = current.View:TakeCarry()
				endDrag(current)
				note("plate to the bin")
				const bin = World.Bin()
				if thrown ~= nil and bin ~= nil then
					bin:Eat(thrown)
				elseif thrown ~= nil then
					thrown:Destroy()
				end
				controller:Trash("Plate")
				if CONVEYOR then
					-- §6.6: the plate stays on the belt, empty, with its ticket
					beltForget()
					belt.Quiet = os.clock() + MASK_GRACE
					controller:Toast(prep.Texts.Toasts.Emptied, "Info")
				end
			else
				endDrag(current)
			end
		end
	end,
	OnResult = function(controller: any, result: any)
		-- DEC-259: the server says a colleague got the front rail sausage first; the drag drops
		const current = live()
		if current == nil or result.Act ~= "Grab" or result.Ok or result.Reason ~= "Held" or not current.RailGrab then
			return
		end
		current.RailGrab = false
		const aim = World.Aim()
		if aim ~= nil then
			aim:Cancel("Held")
		end
		endDrag(current)
		controller:Toast(Ghost.HeldText("Rail", current.RailSlot), "Alert")
		sfx(current, "error", nil)
	end,
	-- The acts of the plate (PrepBegin, PrepFinish, PrepTrash) are heard here whatever tab is in front: the plate lives in the
	-- Session, not in a tab. An accepted Finish closes the bun over the plate first (0.4 s), then the Session moves to Serve.
	OnEvent = function(controller: any, event: any)
		if event.Kind ~= "Result" then
			return
		end
		const result = event.Result
		const act: string = result.Act
		if CONVEYOR and act == "Stage" then
			onStageResult(controller, result)
			return
		end
		if act ~= "Begin" and act ~= "Finish" and act ~= "Trash" then
			return
		end
		if CONVEYOR and act == "Finish" and result.Ok then
			-- the hot dog goes back to the hand (the server moved the plate to Out): say where it goes next (BELT_TOAST_READY)
			const number = ticketNumber(controller)
			beltForget()
			if number > 0 then
				task.delay(READY_TOAST_DELAY, function()
					controller:Toast(string.format(prep.Texts.Toasts.Ready, number), "Good")
				end)
			end
		end
		-- a sausage thrown from the grill or the rail (Trash with a Value) is the business of the Grill stage
		if act == "Trash" and result.Value ~= 0 then
			return
		end
		note(`{act}: ok {tostring(result.Ok)} reason {result.Reason} grade {result.Grade}`)
		-- the server zeroes its mask at Begin, Finish and Trash
		if act ~= "Finish" or result.Ok then
			controller.PlateMask = 0
		end
		const current = session
		if act == "Trash" and not result.Ok and current ~= nil then
			-- the bin refused: the plate comes back from where the bin swallowed it
			current.View:Restore()
		end
		const delivered = act == "Finish" and current ~= nil and current.DeliverTo ~= 0
		if act == "Finish" and current ~= nil then
			if result.Ok then
				serveDelivered(current)
			else
				if current.DeliverTo ~= 0 then
					-- refused after a drop: the plate comes back (the sauce lines were cleared at the drop)
					current.View:Restore()
				end
				current.DeliverTo = 0
			end
		end
		if act == "Finish" and result.Ok and current ~= nil and current.Active and not current.Closing and current.View:Bun() == "Open" then
			current.Closing = true
			current.Director:SetMode("none", false)
			current.Tool:Set("None", "")
			local fired = false
			local function run()
				if fired then
					return
				end
				fired = true
				current.Closing = false
				if prep.Rules.Delivery == "Prompt" then
					-- the hot dog is in the hand now: the plate goes with it, nothing stays on the table
					current.View:TakeAway()
					-- TASK-267: the originals go at once too (the sauce lines are not part of the take-away and the view stays up
					-- during the camera's way out), and the plate picture is emptied so no frame draws it again
					controller.View.Bun("None")
					resetPlate(current, false)
				end
				Session.OnResult(controller, result)
			end
			sfx(current, "hotdog_assemble", current.View.Plane.Frame.Position)
			current.View:Burst(result.Grade)
			current.View:Celebrate(result.Grade)
			if delivered then
				-- dropped on the customer: the plate already left the board, no bun closing over an empty plate
				run()
				return
			end
			current.View:Close(run)
			task.delay(boardRules.Close + 0.5, run)
			return
		end
		Session.OnResult(controller, result)
	end,
}

return Build
