--!strict
-- World/Stages/Grill: the 3D grill, the vertical slice of the 3D prep mode (docs/tech/prep-3d.md §3.2, §12; TASK-203). The tab Grill
-- is the real roller grill of the trailer, seen from the Grill view; no GuiObject here (the HUD is PrepShell).
--   Put      tap the sausage box (the first free roller) or drag from it to a roller, or tap a free roller: PrepGrill Place with the
--            preferred Slot (N1). A ghost sausage invites on every free roller; the box pulses while nothing is cooking.
--   Cook     the sausage of the world changes colour by the SERVER clock (KitchenController Grill part: raw model, grilled model
--            fading in). This stage only reads the clock to draw the ring.
--   Flip     in the flip window (Rules.Grill From..To of the Duration) the 3D ring converges on the sausage (target at Target) and the
--            sausage pulses; a tap sends PrepGrill Flip, the server stamps its own clock and answers with the grade; the sausage
--            turns at once (prediction) and a burst shows the band. Before the window a tap only shivers the sausage and sends
--            nothing; after it ("late") the tap still flips.
--   Collect  a ready sausage (check mark): tap it, or drag it to the rail; it flies to the next slot of the real rail.
--   Rollback the server's records (`Stations`, `PrepResult`) always win: a refused act undoes its prediction with a shake.
-- Sends only through Feed (Place, Flip, Collect: the same queue and rates as the 2D stage). The grade is the server's: nothing is
-- computed here besides the look of the ring. All numbers are in Content.Prep (Rules.World.Grill, Ring, Grill).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Feed = require(script.Parent.Parent.Parent.Feed)
local Stage = require(script.Parent.Parent.Parent.Stage)
local GrillView = require(script.Parent.Parent.GrillView)
local Types = require(script.Parent.Parent.Types)
local Targets = require(script.Parent.Parent.Targets)
local StockLid = require(script.Parent.Parent.StockLid)
local World = require(script.Parent.Parent)

const untrack = Vide.untrack

const prep = Content.Prep
const rules = prep.Rules
const world = rules.World
const window = rules.Grill

const MAX_SLOTS = 8
const PRED_TTL = 4 -- s a prediction waits for the records before it is dropped
const OUT_TEXT = "Out of sausages" -- Provisional
const FULL_TEXT = "The grill is full."
const RAIL_TEXT = "The warmer is full."
const WORK_DROP = 0.1 -- studs: the work plane sits this far over the roller top

type Phase = Types.SlotPhase

type Pred = { Kind: string, At: number, Settled: boolean } -- Kind: Place | Flip | Collect | Trash

type Session = {
	Controller: any,
	Kitchen: any,
	View: GrillView.View,
	Pred: { [number]: Pred },
	Inflight: { { Act: string, Slot: number } },
	TrashQueue: { { From: string, Slot: number } }, -- PrepTrash on its way, in the order sent
	LastTrash: number,
	CoachTried: boolean,
	Pulse: { [string]: boolean },
	Drag: { Kind: string, Slot: number }?,
	Phases: { [number]: Phase },
	Stop: (() -> ())?,
	-- the lid of the sausage container (opens while the pointer is over it)
	Lid: StockLid.StockLid?,
	Targets: { [string]: Types.Target },
	Active: boolean,
}

local session: Session? = nil

-- `/dev prep ray` (player attribute PrepRay) also narrates the grill acts in the client output: what was sent, at which share of the
-- Duration, and what the server answered.
local function note(text: string)
	if Players.LocalPlayer:GetAttribute("PrepRay") == true then
		print(`[prep grill] {text}`)
	end
end

-- Reading the world ------------------------------------------------------------------------------------------------------

local function recordOf(current: Session, slot: number): any?
	const entry = current.Kitchen:SlotView("grill", slot)
	if entry == nil then
		return nil
	end
	const id = entry.Station:GetAttribute("StationId")
	if type(id) ~= "number" then
		return nil
	end
	const record: any = current.Kitchen:SlotOf(id * 100 + slot)
	if record == nil or record.Kind ~= "grill" then
		return nil
	end
	return record
end

-- Phase and cooking share (0..1) of a roller. Exists = the roller has a record on this grill.
local function phaseOf(current: Session, slot: number, now: number): (boolean, Phase, number)
	const record = recordOf(current, slot)
	if record == nil then
		return false, "Free", 0
	end
	if record.State == "Empty" then
		return true, "Free", 0
	end
	const predicted = current.Pred[slot]
	const flipped = record.Flip > 0 or (predicted ~= nil and predicted.Kind == "Flip")
	if record.State == "Ready" then
		return true, "Ready", 1
	end
	const progress = if record.Duration > 0 then math.clamp((now - record.StartedAt) / record.Duration, 0, 1) else 0
	if progress >= 1 then
		return true, "Ready", 1
	end
	if flipped then
		return true, "Flipped", progress
	elseif progress < window.From then
		return true, "Cooking", progress
	elseif progress <= window.To then
		return true, "FlipWindow", progress
	end
	return true, "Late", progress
end

local function stockLeft(): number
	return untrack(Feed.Stock)
end

-- The sausage of the slot has been flipped (the record, or a flip on its way): its marks show on the face that is up.
local function isFlipped(current: Session, slot: number): boolean
	const record = recordOf(current, slot)
	const predicted = current.Pred[slot]
	return (record ~= nil and record.Flip > 0) or (predicted ~= nil and predicted.Kind == "Flip")
end

-- The slot of the real rail the next collected sausage lands on (the ones already there and those on their way count).
local function railCapacity(current: Session): number
	local top = 0
	for slot = 1, MAX_SLOTS do
		if current.Kitchen:SlotView("rail", slot) ~= nil then
			top = slot
		end
	end
	return top
end

local function pendingCollects(current: Session): number
	local count = 0
	for _, pred in current.Pred do
		if pred.Kind == "Collect" and not pred.Settled then
			count += 1
		end
	end
	return count
end

-- First roller that is free and has no Place on its way, nil = none.
local function firstFree(current: Session, now: number): number?
	for slot = 1, MAX_SLOTS do
		const exists, phase = phaseOf(current, slot, now)
		const predicted = current.Pred[slot]
		if exists and phase == "Free" and (predicted == nil or predicted.Kind ~= "Place") then
			return slot
		end
	end
	return nil
end

-- Acts ---------------------------------------------------------------------------------------------------------------------

local function place(current: Session, wanted: number)
	const controller = current.Controller
	const now = workspace:GetServerTimeNow()
	if stockLeft() == 0 then
		controller:Toast(OUT_TEXT, "Alert")
		return
	end
	local slot = wanted
	if slot > 0 then
		const exists, phase = phaseOf(current, slot, now)
		const predicted = current.Pred[slot]
		if not exists or phase ~= "Free" or (predicted ~= nil and predicted.Kind == "Place") then
			slot = 0
		end
	end
	if slot == 0 then
		slot = firstFree(current, now) or 0
	end
	if slot == 0 then
		controller:Toast(FULL_TEXT, "Alert")
		return
	end
	if not Feed.Place(controller, slot) then
		return
	end
	note(`Place sent, slot {slot} (asked {wanted})`)
	World.Coach():Done("Grill")
	current.Pred[slot] = { Kind = "Place", At = os.clock(), Settled = false }
	table.insert(current.Inflight, { Act = "Place", Slot = slot })
end

local function flip(current: Session, slot: number)
	if not Feed.Flip(current.Controller, slot) then
		return
	end
	const _, _, share = phaseOf(current, slot, workspace:GetServerTimeNow())
	note(`Flip sent, slot {slot} at {string.format("%.3f", share)} of the Duration`)
	current.Pred[slot] = { Kind = "Flip", At = os.clock(), Settled = false }
	table.insert(current.Inflight, { Act = "Flip", Slot = slot })
	current.View:Turn(slot, 1)
end

local function collect(current: Session, slot: number, from: CFrame?)
	const controller = current.Controller
	const capacity = railCapacity(current)
	const count = untrack(Feed.Rail) + pendingCollects(current)
	if capacity > 0 and count >= capacity then
		controller:Toast(RAIL_TEXT, "Alert")
		current.View:Shake(slot)
		return
	end
	if not Feed.Collect(controller, slot) then
		return
	end
	note(`Collect sent, slot {slot}, rail {count} -> {count + 1}`)
	current.Pred[slot] = { Kind = "Collect", At = os.clock(), Settled = false }
	table.insert(current.Inflight, { Act = "Collect", Slot = slot })
	current.View:Hide(slot, true)
	current.View:Fly(slot, count + 1, from)
end

-- The bin by drag: a sausage of the grill (any state) or the front of the rail. The thing in hand is swallowed by the bin at once
-- (prediction); the server answers with PrepResult Act = Trash (Value 1 grill, 2 rail) and the records do the rest. A refusal gives it back.
local function throw(current: Session, from: string, slot: number)
	const clock = os.clock()
	if clock - current.LastTrash < 0.25 then
		current.View:Hide(slot, false)
		return
	end
	current.LastTrash = clock
	const controller = current.Controller
	const model = current.View:TakeCarry()
	if from == "Grill" then
		current.Pred[slot] = { Kind = "Trash", At = clock, Settled = false }
		current.View:Hide(slot, true)
	end
	table.insert(current.TrashQueue, { From = from, Slot = slot })
	note(`Trash sent, {from} {slot}`)
	controller:Trash(from, slot)
	const bin = World.Bin()
	if model ~= nil and bin ~= nil then
		bin:Eat(model)
	elseif model ~= nil then
		model:Destroy()
	end
end

-- Every sausage that was lifted and is not on its way anywhere goes back to its roller.
local function restore(current: Session)
	for slot, phase in current.Phases do
		const predicted = current.Pred[slot]
		if phase ~= "Free" and (predicted == nil or (predicted.Kind ~= "Collect" and predicted.Kind ~= "Trash")) then
			current.View:Hide(slot, false)
		end
	end
end

-- A tap on a roller does what its phase invites.
local function tapSlot(current: Session, slot: number)
	const now = workspace:GetServerTimeNow()
	const exists, phase = phaseOf(current, slot, now)
	if not exists then
		return
	end
	if phase == "Free" then
		place(current, slot)
	elseif phase == "FlipWindow" or phase == "Late" then
		flip(current, slot)
	elseif phase == "Ready" then
		collect(current, slot, nil)
	else
		-- Cooking / Flipped: too early, nothing is sent
		current.View:Shake(slot, world.Grill.ShakeAmount * 0.6)
	end
end

-- Frame -------------------------------------------------------------------------------------------------------------------

local function setPulse(current: Session, id: string, on: boolean)
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

local function frame(current: Session, dt: number, time: number)
	const now = workspace:GetServerTimeNow()
	const clock = os.clock()
	const view = current.View
	const stock = stockLeft()
	local anyCooking = false
	local cooking, occupied = 0, 0
	for slot = 1, MAX_SLOTS do
		const exists, phase, progress = phaseOf(current, slot, now)
		const id = `GrillSlot:{slot}`
		const target = current.Targets[id]
		-- predictions the records have caught up with (or that timed out) go
		const predicted = current.Pred[slot]
		if predicted ~= nil then
			const record = recordOf(current, slot)
			if predicted.Kind == "Place" and (phase ~= "Free" or clock - predicted.At > PRED_TTL) then
				current.Pred[slot] = nil
			elseif predicted.Kind == "Flip" and ((record ~= nil and record.Flip > 0) or clock - predicted.At > PRED_TTL) then
				current.Pred[slot] = nil
			elseif predicted.Kind == "Collect" and (phase == "Free" or clock - predicted.At > PRED_TTL) then
				current.Pred[slot] = nil
				view:Hide(slot, false)
			elseif predicted.Kind == "Trash" and (phase == "Free" or clock - predicted.At > PRED_TTL) then
				current.Pred[slot] = nil
				view:Hide(slot, false)
			end
		end
		const trashing = current.Pred[slot] ~= nil and current.Pred[slot].Kind == "Trash"
		const placing = current.Pred[slot] ~= nil and current.Pred[slot].Kind == "Place"
		view:SetActive(slot, exists)
		if phase ~= "Free" then
			anyCooking = true
		end
		-- what is drawn
		view:SetGhost(slot, if not exists or phase ~= "Free" or trashing then "None" elseif placing then "Predicted" elseif stock ~= 0 then "Ghost" else "None")
		view:SetRing(slot, if trashing then "None" elseif phase == "FlipWindow" then "Converge" elseif phase == "Late" then "Late" else "None", progress)
		view:SetCheck(slot, phase == "Ready" and not trashing and (current.Pred[slot] == nil or current.Pred[slot].Kind ~= "Collect"))
		-- the marks of the bars show on the face that is up after the flip and darken with the server clock until it is ready
		view:SetMarks(slot, if exists and phase ~= "Free" and not trashing and isFlipped(current, slot) then 0.4 + 0.6 * progress else 0)
		-- the target: its contour follows the sausage (or the ghost on a free roller) and pulses when it invites
		if target ~= nil then
			const model = view:ModelOf(slot, phase == "Ready" or progress >= 1)
			if target.Model ~= model then
				target.Model = model
			end
			setPulse(current, id, phase == "FlipWindow" or phase == "Late" or phase == "Ready")
		end
		current.Phases[slot] = phase
		if phase ~= "Free" and not trashing then
			cooking += 1
			occupied += 1
		end
	end
	setPulse(current, "SausageStock", not anyCooking and stock ~= 0)
	view:SetBusy(cooking, MAX_SLOTS)
	-- the bin shows while there is a sausage to throw (a roller or the rail)
	const bin = World.Bin()
	if bin ~= nil then
		bin:SetWanted(occupied > 0 or untrack(Feed.Rail) > 0)
	end
	-- the hand of the tutorial: from the box to the first free roller, once per station and session
	if not current.CoachTried and stock ~= 0 and not anyCooking and not World.Coach():Active() then
		current.CoachTried = true
		const stockTarget = World.Targets()
		const box = if stockTarget ~= nil then stockTarget:Get("SausageStock") else nil
		const free = firstFree(current, now)
		const pose = if free ~= nil then current.View:PoseOf(free) else nil
		if box ~= nil and box.Parts[1] ~= nil and pose ~= nil then
			const lift = Vector3.new(0, WORK_DROP, 0)
			const from = Vector3.new(box.Parts[1].Position.X, pose.Position.Y, box.Parts[1].Position.Z) + lift
			World.Coach():Show("Grill", { from, pose.Position + lift })
		end
	end
	if current.Lid ~= nil then
		current.Lid:Step(dt)
	end
	view:Step(dt, time)
end

-- Targets -----------------------------------------------------------------------------------------------------------------

-- Registers the targets of this stage over the scanned hitboxes (the registry starts with every target off).
local function register(current: Session, registry: Targets.Registry): number
	local count = 0
	for _, scanned in table.clone(registry:List()) do
		const kind = scanned.Target.Kind
		local enabled: (() -> boolean)? = nil
		local handlers: Targets.Handlers? = nil
		if kind == "GrillSlot" then
			const slot = scanned.Target.Slot
			enabled = function(): boolean
				const open = session
				if open == nil or not open.Active then
					return false
				end
				return recordOf(open, slot) ~= nil
			end
		elseif kind == "SausageStock" then
			enabled = function(): boolean
				const open = session
				return open ~= nil and open.Active
			end
			const lidFolder = if workspace.CurrentCamera ~= nil then workspace.CurrentCamera:FindFirstChild(Types.FolderName) else nil
			if current.Lid == nil and scanned.Parts[1] ~= nil and lidFolder ~= nil then
				current.Lid = StockLid.new(lidFolder :: Folder, scanned.Parts[1])
			end
			const lidHandlers: Targets.Handlers = {
				Hover = function(entered: boolean)
					if current.Lid ~= nil then
						current.Lid:SetOpen(entered)
					end
				end,
			}
			handlers = lidHandlers
		elseif kind == "Rail" then
			-- the drop target of a ready sausage while one waits, and the source of the front one (to the bin) while the rail has any
			enabled = function(): boolean
				const open = session
				if open == nil or not open.Active then
					return false
				end
				if untrack(Feed.Rail) > 0 then
					return true
				end
				for _, phase in open.Phases do
					if phase == "Ready" then
						return true
					end
				end
				return false
			end
		end
		if enabled ~= nil then
			const added = registry:Add({
				Target = scanned.Target,
				Parts = scanned.Parts,
				Model = scanned.Model,
				Enabled = enabled,
				Handlers = handlers,
			})
			current.Targets[added.Target.Id] = added
			if kind == "GrillSlot" then
				count += 1
			end
		end
	end
	return count
end

-- The plane a drag is read on: the top of the roller of the first slot, a little over it.
local function workPlane(current: Session)
	for slot = 1, MAX_SLOTS do
		const pose = current.View:PoseOf(slot)
		if pose ~= nil then
			World.SetWorkPlane({ Origin = pose.Position + Vector3.new(0, WORK_DROP, 0), Normal = Vector3.yAxis })
			return
		end
	end
end

local function build(controller: any)
	const registry = World.Targets()
	const aim = World.Aim()
	const folder = if workspace.CurrentCamera ~= nil then workspace.CurrentCamera:FindFirstChild(Types.FolderName) else nil
	if registry == nil or aim == nil or folder == nil then
		error("the 3D world is not running")
	end
	const kitchen = controller.Dependencies.KitchenController
	const view = GrillView.new({
		Folder = folder :: Folder,
		Rules = world,
		SlotView = function(kind: string, slot: number)
			return kitchen:SlotView(kind, slot)
		end,
		Slots = MAX_SLOTS,
		Juice = World.Juice,
	})
	const current: Session = {
		Controller = controller,
		Kitchen = kitchen,
		View = view,
		Pred = {},
		Inflight = {},
		TrashQueue = {},
		LastTrash = 0,
		CoachTried = false,
		Pulse = {},
		Drag = nil,
		Phases = {},
		Stop = nil,
		Lid = nil,
		Targets = {},
		Active = true,
	}
	session = current
	const grillTargets = register(current, registry)
	if grillTargets == 0 then
		view:Destroy()
		session = nil
		error("no GrillSlot hitbox in the trailer (tag PrepTarget, TargetKind GrillSlot)")
	end
	workPlane(current)
	current.Stop = aim:OnFrame(function(dt: number, time: number)
		const ok, problem = pcall(frame, current, dt, time)
		if not ok then
			warn(`[PrepWorld] Grill frame: {problem}`)
		end
	end)
end

local function teardown()
	const current = session
	if current == nil then
		return
	end
	session = nil
	current.Active = false
	if current.Stop ~= nil then
		current.Stop()
	end
	if current.Lid ~= nil then
		current.Lid:Destroy()
		current.Lid = nil
	end
	const bin = World.Bin()
	if bin ~= nil then
		bin:SetWanted(false)
	end
	for slot in current.Pred do
		current.View:Hide(slot, false)
	end
	current.View:Destroy()
	World.SetWorkPlane(nil)
	const registry = World.Targets()
	if registry ~= nil then
		registry:Touch()
	end
end

-- The stage ---------------------------------------------------------------------------------------------------------------

-- The customer at the counter that has not been taken yet, 0 = none.
local function toTake(): number
	if untrack(Feed.Pinned) ~= 0 then
		return 0
	end
	for _, id in untrack(Feed.Ids) do
		if untrack(Feed.CardOf(id)).Status == "Ready" then
			return id
		end
	end
	return 0
end

const Grill: Stage.Stage3D = {
	Tabs = { "Grill" },
	Enter = function(controller: any, _tab: string)
		teardown()
		const ok, problem = pcall(build, controller)
		if not ok then
			-- never leave the player seated without a way to play: give the seat back
			warn(`[PrepController] 3D grill failed to start, leaving the mode: {problem}`)
			task.defer(function()
				controller:Leave("StageFailed", false, false)
			end)
		end
	end,
	Leave = function(_controller: any, _tab: string)
		const aim = World.Aim()
		if aim ~= nil then
			aim:Cancel("Leave")
		end
		teardown()
	end,
	Step = function(_controller: any, _step: string) end,
	Hint = function(_controller: any): string
		if not Feed.HasGrill() then
			return "No grill here"
		end
		local ready, windowOpen = false, false
		for index = 1, MAX_SLOTS do
			const state = Feed.Slots[index]().State
			if state == "Window" or state == "Late" then
				windowOpen = true
			elseif state == "Ready" then
				ready = true
			end
		end
		if windowOpen then
			return "Tap the sausage as the ring closes"
		elseif ready then
			return "Tap it or drag it to the rail"
		elseif Feed.Stock() == 0 then
			return OUT_TEXT
		elseif Feed.Rail() > 0 then
			return "Press Next when you are ready"
		end
		return "Drag a sausage onto the grill"
	end,
	Next = function(_controller: any): Stage.Next
		if toTake() ~= 0 then
			return { Label = prep.Texts.Take, Enabled = true, Pulse = true }
		end
		return { Label = prep.Steps3D.ByKey.grill.NextLabel, Enabled = true, Pulse = Feed.Rail() > 0 and Feed.Pinned() ~= 0 }
	end,
	OnNext = function(controller: any)
		const id = toTake()
		if id ~= 0 then
			note(`Take sent, customer {id}`)
			Feed.Take(controller, id)
			return
		end
		note("Next: to the board")
		controller:SetStage("bun")
	end,
	OnAim = function(_controller: any, message: any)
		const current = session
		if current == nil then
			return
		end
		const kind: string = message.Kind
		if kind == "Press" then
			const target = message.Target :: Types.Target
			current.Drag = { Kind = target.Target.Kind, Slot = target.Target.Slot }
		elseif kind == "Move" then
			const source = message.Source :: Types.Target
			const over = message.Over :: Types.Target?
			const now = workspace:GetServerTimeNow()
			if source.Target.Kind == "SausageStock" then
				local snap: number? = nil
				if over ~= nil and over.Target.Kind == "GrillSlot" then
					const exists, phase = phaseOf(current, over.Target.Slot, now)
					if exists and phase == "Free" then
						snap = over.Target.Slot
					end
				end
				current.View:SetCarry(message.Point, snap, false)
			elseif source.Target.Kind == "GrillSlot" then
				-- any sausage can be lifted: to the rail when it is ready, to the bin whatever it is
				const _, phase, share = phaseOf(current, source.Target.Slot, now)
				if phase ~= "Free" then
					current.View:SetCarry(message.Point, nil, phase == "Ready" or share >= 0.5)
					current.View:Hide(source.Target.Slot, true)
				end
			elseif source.Target.Kind == "Rail" then
				current.View:SetCarry(message.Point, nil, true)
			end
		elseif kind == "Release" or kind == "Cancel" then
			current.View:SetCarry(nil, nil, false)
			current.Drag = nil
			-- a sausage that was lifted and not dropped anywhere goes back
			restore(current)
		elseif kind == "Drop" then
			const source = message.Source :: Types.Target
			const over = message.Over :: Types.Target
			const from = if current.View:PoseOf(source.Target.Slot) ~= nil then current.View:PoseOf(source.Target.Slot) else nil
			current.Drag = nil
			if over.Target.Kind == "Bin" and (source.Target.Kind == "GrillSlot" or source.Target.Kind == "Rail") then
				-- the carried model goes into the bin (throw takes it)
				if source.Target.Kind == "GrillSlot" then
					throw(current, "Grill", source.Target.Slot)
				else
					throw(current, "Rail", 1)
				end
				restore(current)
				return
			end
			current.View:SetCarry(nil, nil, false)
			if source.Target.Kind == "SausageStock" and over.Target.Kind == "GrillSlot" then
				place(current, over.Target.Slot)
			elseif source.Target.Kind == "GrillSlot" and over.Target.Kind == "Rail" then
				const _, phase = phaseOf(current, source.Target.Slot, workspace:GetServerTimeNow())
				if phase == "Ready" then
					collect(current, source.Target.Slot, from)
				else
					current.View:Hide(source.Target.Slot, false)
					current.View:Shake(source.Target.Slot)
				end
			end
			restore(current)
		elseif kind == "Tap" then
			const target = message.Target :: Types.Target
			current.Drag = nil
			if target.Target.Kind == "SausageStock" then
				place(current, 0)
			elseif target.Target.Kind == "GrillSlot" then
				tapSlot(current, target.Target.Slot)
			end
		end
	end,
	OnResult = function(controller: any, result: any)
		const current = session
		if result.Act ~= "Grill" then
			note(`{result.Act}: ok {tostring(result.Ok)} reason {result.Reason}`)
		end
		if current ~= nil and result.Act == "Trash" and result.Value ~= 0 then
			-- the answer of a sausage thrown by drag (Value 1 = grill, 2 = rail); the records move the sausage, a refusal gives it back
			const sent = table.remove(current.TrashQueue, 1)
			if sent ~= nil and not result.Ok then
				if sent.From == "Grill" then
					current.Pred[sent.Slot] = nil
					current.View:Hide(sent.Slot, false)
					current.View:Shake(sent.Slot)
				end
				controller:Toast(if result.Reason == "Busy" then prep.Texts.TrashBusy else prep.Texts.TrashEmpty, "Alert")
			end
			return
		end
		if current == nil or result.Act ~= "Grill" then
			return
		end
		const sent = table.remove(current.Inflight, 1)
		if sent == nil then
			return
		end
		const slot = sent.Slot
		note(`{sent.Act} slot {slot}: ok {tostring(result.Ok)} reason {result.Reason} grade {result.Grade}`)
		const predicted = current.Pred[slot]
		if not result.Ok then
			current.Pred[slot] = nil
			if sent.Act == "Place" then
				current.View:Reject(slot)
			elseif sent.Act == "Flip" then
				current.View:Turn(slot, -1)
			elseif sent.Act == "Collect" then
				current.View:Hide(slot, false)
				current.View:Shake(slot)
			end
			return
		end
		if predicted ~= nil then
			predicted.Settled = true
		end
		if sent.Act == "Flip" then
			const band: string = result.Grade
			current.View:Burst(slot, band)
			const label = prep.Grades.Labels[band :: any]
			if label ~= nil then
				controller:Toast(label, if band == "Messy" then "Info" else "Good")
			end
		end
	end,
}

return Grill
