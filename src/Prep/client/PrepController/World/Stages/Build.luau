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
--             the seal shows. The bin (a PLACEHOLDER on the bench) takes the plate if you drag it there (PrepTrash).
-- Everything the player does is measured by Director3D with the gesture modules and `Prep/shared/Grade` (never here), kept in the
-- 2D `Stages/Build/Session` (plate, scores, pips, PrepBegin / PrepFinish / PrepTrash and their PrepResult) and sent only through it.
-- The server decides stock, band and the hot dog; this module predicts what it shows (the bun on the board) and undoes it when the
-- records or the PrepResult say no. The cosmetic plate mask goes up with PrepTab (controller.PlateMask).
-- Rollback without code: Rules.World.Stages.Board / Toppings = false puts the 2D Build stage back. Provisional numbers and texts.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local Plane = require(script.Parent.Parent.Plane)
local Strokes = require(script.Parent.Parent.Strokes)
local Targets = require(script.Parent.Parent.Targets)
local ToolView = require(script.Parent.Parent.ToolView)
local Types = require(script.Parent.Parent.Types)
local World = require(script.Parent.Parent)

const untrack = Vide.untrack
const source = Vide.source

const prep = Content.Prep
const world = prep.Rules.World
const boardRules = world.Board
const build = prep.Build
const MAX = Content.OrderRules.MaxToppings
const GROOVE = Vector2.new(build.Groove.X, build.Groove.Y)
const MASK_RETRY = 2.5 -- s: the server drops a mask that comes too early, so an unaccepted one is sent again (3 times at most)
const FRAME_TICK = 0.1 -- s: the plate and the targets are re-judged at 10 Hz

-- Short texts (Provisional; ui-text.md §16, PREP3D_*; English, DEC-022; <= 36 characters)
const TEXT = {
	Crate = "Tap the crate for a bun", -- PREP3D_TIP_CRATE
	Knife = "Cut the bun with the knife", -- PREP3D_TIP_BOARD
	Slice = "Drag the knife along the line", -- PREP3D_GST_SLICE
	SliceHold = "Hold the knife on the line", -- PREP3D_GST_SLICE_HOLD
	Place = "Drag the frank into the bun", -- PREP3D_GST_PLACE
	Rail = "Ready franks wait on the rail", -- PREP3D_TIP_RAIL
	NextBoard = "Next: add toppings", -- PREP3D_TIP_NEXT_BOARD
	NeedBoard = "Cut the bun and add the frank first", -- PREP3D_TIP_NEXT_BOARD_OFF
	NeedPlate = "Cut the bun and add the frank first",
	Add = "Add a topping or press Next", -- PREP3D_GST_ADD
	Full = "3 toppings max. Press Next", -- Build.Texts.Full (ui-text §16.3)
	TopMax = "3 toppings max!", -- PREP3D_REF_TOP_MAX
	PlaceFirst = "Place the frank first", -- PREP3D_REF_PLACE_FIRST
	Bin = "Drag the plate to the bin", -- PREP3D_TIP_BIN
	Trashed = "Plate trashed", -- PREP3D_REF_TRASHED
	NoBun = "Out of buns! Restock it.", -- PREP3D_REF_NOBUNS
	Miss = "Drop it on the bun", -- Provisional
	Trace = "Trace the zig-zag", -- PREP3D_GST_TRACE
	TraceHold = "Hold to pour, let go at the mark", -- PREP3D_GST_TRACE_HOLD
	Slide = "Drag the slice onto the bun", -- PREP3D_GST_SLIDE
	SlideHold = "Hold where the slice goes", -- PREP3D_GST_SLIDE_HOLD
	Taps = "Tap each ring as it closes", -- PREP3D_GST_TAPS
	Hold = "Hold, let go at the ring", -- PREP3D_GST_HOLD
}

-- The tip of a bowl on hover (PREP3D_TIP_BOWL_*)
const BOWL_TIPS: { [string]: string } = {
	ketchup = "Ketchup: trace the zig-zag",
	mustard = "Mustard: trace the zig-zag",
	cream_cheese = "Cream cheese: trace the zig-zag",
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
			end
		elseif kind == "Rail" then
			-- the drag source of the front sausage, while the bun waits for it
			enabled = function(): boolean
				const open = live()
				return open ~= nil
					and open.Tab == "Board"
					and plateOpen()
					and open.View:Bun() == "Open"
					and not placed()
					and untrack(Feed.Rail) > 0
			end
		elseif kind == "Topping" then
			const key = scanned.Target.Topping
			enabled = function(): boolean
				const open = live()
				return open ~= nil and open.Tab == "Toppings" and plateOpen() and not open.Closing and untrack(Session.Pending) ~= "Finish"
					and (not placed() or (usedKeys(open)[key] ~= true) or toolKey() == key)
			end
		end
		if enabled ~= nil then
			const real = if scanned.Parts[1] ~= nil then realObject(scanned.Parts[1], kind, scanned.Target.Topping) else nil
			const added = registry:Add({
				Target = scanned.Target,
				Parts = scanned.Parts,
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
			if open.Tab == "Board" then
				return open.View:Bun() == "Open" and not placed()
			end
			return placed() and toolKey() == "" and untrack(Session.Pending) ~= "Finish"
		end,
	})
	current.Targets[board.Target.Id] = board
	-- the placeholder bin on the bench (the real one is on the floor behind the camera)
	const bin = registry:Add({
		Target = Types.Target("Bin"),
		Parts = { current.View.BinPart },
		Model = current.View.BinModel,
		Enabled = function(): boolean
			const open = live()
			return open ~= nil and plateOpen() and not open.Closing and open.Tab == "Toppings"
		end,
	})
	current.Targets[bin.Target.Id] = bin
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
	note("Begin sent (the bun crate)")
	Session.Begin(controller)
	sfx(current, "grill_collect", current.View.Plane.Frame.Position)
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
	controller.Step("place")
	current.Step = "place"
	current.View:Burst(bandOf(score))
	note(`cut {score}`)
end

local function onPlaced(current: Sess, score: number)
	const controller = current.Controller
	Session.SetPlace(controller, score)
	controller:Need("SausagePlaced", true)
	controller.View.Sausage({ X = build.Groove.X, Y = build.Groove.Y, State = "Ready" })
	current.SausageOn = true
	current.View:SetSausage("Placed", GROOVE)
	current.View:SetCarry(nil, nil, nil)
	sfx(current, "hotdog_assemble", current.View.Plane.Frame.Position)
	current.View:Burst(bandOf(score))
	note(`placed {score}`)
end

local function onTopping(current: Sess, key: string, score: number, amount: number)
	const controller = current.Controller
	current.Drawn[key] = true
	Session.AddTopping(controller, key, score, amount)
	current.View:Burst(bandOf(score))
	note(`topping {key} {score}`)
end

-- Plate -----------------------------------------------------------------------------------------------------------------------

local function resetPlate(current: Sess, dust: boolean)
	if dust then
		current.View:Dust()
	end
	current.View:SetBun("None", false)
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
				current.Strokes:Begin(Strokes.ColorOf(entry.Key))
				for _, point in build.Sauce.Path do
					current.Strokes:Add(Vector2.new(point.X, point.Y))
				end
				current.Strokes:Keep()
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

-- The gesture the plate wants now (Director3D mode), "none" when nothing is armed.
local function wantedMode(current: Sess): string
	if current.Closing or not plateOpen() or untrack(Session.Pending) == "Finish" or current.Drag ~= nil then
		return "none"
	end
	const holdMode = untrack(Session.Hold)
	if current.Tab == "Board" then
		const bun = bunState(current)
		if bun == "Closed" or bun == "Cut" then
			return if holdMode then "slice_hold" else "slice"
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
	return if holdMode and (gesture == "trace" or gesture == "slide") then `{gesture}_hold:{key}` else `{gesture}:{key}`
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
			syncPlate(current)
			syncMask(current)
			if registry ~= nil then
				-- pulses: the invitation of the moment (touch has no hover)
				const open = plateOpen()
				setPulse(current, "BunCrate", current.Tab == "Board" and not open and untrack(Session.Pending) == "")
				setPulse(current, "Rail", current.Tab == "Board" and open and current.View:Bun() == "Open" and not placed() and untrack(Feed.Rail) > 0)
				for key in current.Targets do
					if string.sub(key, 1, 8) == "Topping:" then
						setPulse(current, key, current.Tab == "Toppings" and open and placed() and toolKey() == "" and #Session.Toppings() < MAX)
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
	end
	current.View:Step(dt, time)
	current.Tool:Step(dt)
end

-- Build and tear down ------------------------------------------------------------------------------------------------------------

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
	current.Director:Destroy()
	current.Tool:Destroy()
	current.Strokes:Destroy()
	current.View:Destroy()
	current.Hitbox:Destroy()
	hover("")
	World.SetWorkPlane(nil)
	const registry = World.Targets()
	if registry ~= nil then
		-- the two targets made of this session's own parts go with it
		registry:Remove(`Board:{current.Seat}`)
		registry:Remove("Bin")
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
	const boardMesh = if trailer ~= nil then trailer:FindFirstChild("Board", true) else nil
	const centre = if boardMesh ~= nil and boardMesh:IsA("BasePart") then Vector3.new(boardMesh.Position.X, anchor.Y, anchor.Z) else anchor
	const knifeInstance = if trailer ~= nil then trailer:FindFirstChild("Knife", true) else nil
	-- the screen right of the Board view, flat: the bun lies along it
	const pose = Poses.Of(seat, "Board")
	const reference = if pose ~= nil then pose.Frame else (camera :: Camera).CFrame
	const flat = Vector3.new(reference.RightVector.X, 0, reference.RightVector.Z)
	const right = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
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
	})
	const tool = ToolView.new(folder :: Folder, world, view.Orient)
	const strokes = Strokes.new(folder :: Folder, world, view.Plane)
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
		OnTopping = function(key: string, score: number, amount: number)
			onTopping(current, key, score, amount)
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
		hover(TEXT.Rail)
	elseif kind == "Board" then
		hover(if current.Tab == "Board" then (if current.View:Bun() == "Open" then TEXT.Place else TEXT.Knife) else TEXT.Bin)
	elseif kind == "Topping" then
		hover(BOWL_TIPS[target.Target.Topping] or "")
	elseif kind == "Bin" then
		hover(TEXT.Bin)
	else
		hover("")
	end
end

-- The sausage under the pointer: samples in the bun space, the snap to the groove inside the magnet.
local function dragSausage(current: Sess, point: Vector3)
	const drag = current.Drag
	if drag == nil then
		return
	end
	const uv = Plane.ToUV(current.View.Plane, point)
	table.insert(drag.Points, uv)
	if #drag.Points > 90 then
		table.remove(drag.Points, 1)
	end
	const _, near = current.Director:MeasurePlace({ uv, uv, uv })
	current.View:SetCarry("Sausage", point, if near then GROOVE else nil)
	current.View:SetSausage(if near then "Ghost" else "None", GROOVE)
end

local function endDrag(current: Sess)
	const had = current.Drag ~= nil
	current.Drag = nil
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
		-- the Toppings view looks at the bowls: the plate slides to the left part of it; the bin is only there
		const shift = boardRules.Shift
		const centre = current.Home
		current.View:MoveTo(
			if tab == "Toppings" then centre + current.View.Orient.XVector * shift.Right + current.View.Orient.ZVector * shift.Back else centre,
			if first then 0 else boardRules.Slide
		)
		current.View:SetBinVisible(tab == "Toppings")
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
			return prep.Build.Texts.Ready
		end
		if tab == "Board" then
			if not open then
				return TEXT.Crate
			end
			const bun = controller.View.Bun()
			if bun == "Closed" or bun == "Cut" then
				return if Session.Hold() then TEXT.SliceHold else TEXT.Slice
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
		const holdMode = Session.Hold()
		const gesture = tolerance.Gesture
		if gesture == "trace" then
			return if holdMode then TEXT.TraceHold else TEXT.Trace
		elseif gesture == "slide" then
			return if holdMode then TEXT.SlideHold else TEXT.Slide
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
		if sealed or finishing then
			return { Label = prep.Texts.Next, Enabled = false }
		end
		if tab == "Board" then
			const ready = open and cut and isPlaced
			return { Label = prep.Texts.Next, Enabled = ready, Pulse = ready }
		end
		const ready = open and isPlaced
		return { Label = prep.Texts.Next, Enabled = ready, Pulse = ready and toppings > 0 }
	end,
	OnNext = function(controller: any)
		if Session.Peek(controller.Tab) == "Board" then
			note("Next: to the toppings")
			controller:SetStage("toppings")
			return
		end
		const current = session
		if current ~= nil and current.Closing then
			return
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
				current.Drag = { Kind = "Sausage", Points = {} }
				current.View:SetCarry("Sausage", message.Point, nil)
				current.Director:SetMode("none", false)
				current.WantMode = "none"
			elseif targetKind == "Topping" then
				pickTool(current, target.Target.Topping, true)
			elseif targetKind == "Board" and current.Tab == "Toppings" then
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
			end
		elseif kind == "Release" or kind == "Cancel" then
			const drag = current.Drag
			if drag ~= nil and drag.Kind == "Sausage" and kind == "Release" then
				sfx(current, "error", nil)
				controller:Toast(TEXT.Miss, "Info")
			end
			endDrag(current)
		elseif kind == "Drop" then
			const drag = current.Drag
			const over = message.Over :: Types.Target
			if drag == nil then
				return
			end
			if drag.Kind == "Sausage" and over.Target.Kind == "Board" then
				const uv = Plane.ToUV(current.View.Plane, message.Point)
				table.insert(drag.Points, uv)
				const score, near = current.Director:MeasurePlace(drag.Points)
				endDrag(current)
				if score ~= nil and near then
					onPlaced(current, score)
				else
					sfx(current, "error", nil)
					controller:Toast(TEXT.Miss, "Info")
				end
			elseif drag.Kind == "Plate" and over.Target.Kind == "Bin" then
				endDrag(current)
				sfx(current, "error", nil)
				current.View:Dust()
				note("plate to the bin")
				controller:Trash()
			else
				endDrag(current)
			end
		end
	end,
	OnResult = function(_controller: any, _result: any) end,
	-- The acts of the plate (PrepBegin, PrepFinish, PrepTrash) are heard here whatever tab is in front: the plate lives in the
	-- Session, not in a tab. An accepted Finish closes the bun over the plate first (0.4 s), then the Session moves to Serve.
	OnEvent = function(controller: any, event: any)
		if event.Kind ~= "Result" then
			return
		end
		const result = event.Result
		const act: string = result.Act
		if act ~= "Begin" and act ~= "Finish" and act ~= "Trash" then
			return
		end
		note(`{act}: ok {tostring(result.Ok)} reason {result.Reason} grade {result.Grade}`)
		-- the server zeroes its mask at Begin, Finish and Trash
		if act ~= "Finish" or result.Ok then
			controller.PlateMask = 0
		end
		const current = session
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
				Session.OnResult(controller, result)
			end
			sfx(current, "hotdog_assemble", current.View.Plane.Frame.Position)
			current.View:Burst(result.Grade)
			current.View:Close(run)
			task.delay(boardRules.Close + 0.5, run)
			return
		end
		Session.OnResult(controller, result)
	end,
}

return Build
