--!strict
-- Cutting board visuals (TASK-030; FEAT-006 steps 4-5, DEC-190, DEC-215; network.md §3.5, architecture.md §18.4).
-- 2 shared slots on the cart (3 on the trailer): one Stations record per slot (Kind = board), anchors
-- `Att_Bun1..n` with `Slot`. Same pattern as the grill:
--   Empty     nothing on the board
--   Working   BunClosed (whole bun) + ProgressBar of the cut (Stations.bun_crate.Params.CutTime, 0.8 s)
--   Ready     BunOpen (sliced, waiting for "Add Sausage"); no bar
-- The bun swaps to BunOpen when the local bar ends, like the grill. Buns lie end to end along the line of slots
-- (Att_Bun1/2 = Att_Bun -/+ 0.55 along its X; bun 1.0 long: Provisional until the visual check in the place).
-- Sound (TASK-079; sound-list §5.3), on transitions only (a late joiner's first record is silent):
--   Empty -> Working   SFX-024 `bun_slice` at the slot, speed fitted to the record Duration so the knife ends with
--                      the bar (user request 2026-10-11)
--   Ready -> Empty     SFX-025 `hotdog_assemble` at the slot ("Add Sausage" took the bun)
-- Wave 3 (TASK-110, ANM-002): a slot with `Altered` >= 1 shows BunBitten (AST-061; the server writes it Ready, already
-- sliced). It appears silently: no `bun_slice`, since nobody cut it (Provisional, frontend-coder).
-- TASK-260 (owner request 2026-10-14): a plate of the prep mode on a slot is seen by EVERY player: the board model carries
-- `Plate<slot>` (server, Stations/Board): nil = no plate; a number = its PlateMask. The bun shows open once cut (no cut bar for a
-- plate), the grilled sausage sits in it and the toppings stack on top (the kit of Assets.Items.Toppings).
-- TASK-283 / TASK-289 (owner requests 2026-10-14): the plate is ONE model `BunPlate_Slot<n>` (bun, sausage, toppings) drawn at the
-- size and place the 3D prep mode draws it (Content.Prep.Rules.World.Board.Scale, the middle of the board mesh), so leaving the mode
-- leaves the same hot dog in the world, and it follows the mask live for everyone. While the local 3D Build view of that seat is
-- up it sets the local attribute `PrepView<slot>` on the board model and the copy steps aside (the view draws its own plate); on
-- any other tab of the mode the copy stays, whole. The sausage of a plate is still the front one of the rail until the hot dog is
-- made (KitchenService Plate.Finish pops it): Rail.luau leaves those front slots empty.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local HotDogVisual = require(ReplicatedStorage.shared.Item.HotDogVisual)
local PlateMask = require(ReplicatedStorage.shared.Prep.PlateMask)
local Context = require(script.Parent.Context)
local Slots = require(script.Parent.Slots)

const effect = Vide.effect
const derive = Vide.derive
const untrack = Vide.untrack

const KIND = "board"
const BUN_HEIGHT = 0.35 -- AST-001 BunClosed (build_items.luau)
const PLATE_ATTRIBUTE = "Plate"
const VIEW_ATTRIBUTE = "PrepView" -- local, set by the 3D prep mode (World/BoardView) while it draws the plate of that slot
const PLATE_SCALE = Content.Prep.Rules.World.Board.Scale
const SAUSAGE_LIFT = 0.17 -- studs: the sausage in the groove of the open bun (the Serve stage uses the same)
const TOPPING_LIFT = 0.3 -- studs: the first topping over the sausage

local function toppingKit(): Instance?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	return if items then items:FindFirstChild("Toppings") else nil
end

-- A local anchored copy of a topping model of the kit, pivot at `at` (removed with the effect)
local function addTopping(key: string, at: CFrame, parent: Instance): number
	const kit = toppingKit()
	const template = if kit then kit:FindFirstChild(key) else nil
	if template == nil or not template:IsA("Model") then
		return 0
	end
	const copy = template:Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	copy:PivotTo(at)
	copy.Parent = parent
	Vide.cleanup(copy)
	const height = template:GetAttribute("TopHeight")
	return if type(height) == "number" then height else 0.08
end

-- The whole plate as one local model `BunPlate_Slot<n>`: built at kit size on the slot, scaled about the slot to the prep mode's size,
-- moved to the middle of the board (the 3D mode's working spot) and welded to the board like the other station food. Removed with
-- the calling effect.
local function drawPlate(station: Instance, spot: Slots.Spot, board: BasePart?, plate: PlateMask.Plate)
	const base = spot.Host.CFrame * spot.Offset
	const model = Instance.new("Model")
	model.Name = `BunPlate_Slot{spot.Slot}`
	model.WorldPivot = base
	Slots.Food(if plate.Cut then "BunOpen" else "BunClosed", spot, model)
	if plate.Sausage then
		const lifted: Slots.Spot = { Slot = spot.Slot, Host = spot.Host, Offset = spot.Offset * CFrame.new(0, SAUSAGE_LIFT, 0) }
		Slots.Food("SausageGrilled", lifted, model)
		local cursor = base * CFrame.new(0, TOPPING_LIFT, 0)
		for _, key in HotDogVisual.order(plate.Toppings) do
			cursor *= CFrame.new(0, addTopping(key, cursor, model), 0)
		end
	end
	-- free of the welds Slots.Food made, scaled and placed, then welded again
	Slots.Detach(model)
	if PLATE_SCALE ~= 1 then
		model:ScaleTo(PLATE_SCALE)
	end
	if board ~= nil then
		model:PivotTo(CFrame.new(board.Position.X, base.Position.Y, base.Position.Z) * base.Rotation)
	end
	model.Parent = station
	Slots.Attach(model, spot.Host)
	Vide.cleanup(model)
end

local function mountSlot(
	station: Instance,
	spot: Slots.Spot,
	read: Slots.Reader,
	clock: () -> number,
	audio: Context.Audio,
	board: BasePart?
)
	-- the plate on this slot (TASK-260): nil = none, else its PlateMask
	const name = `{PLATE_ATTRIBUTE}{spot.Slot}`
	local function readMask(): number
		const value = station:GetAttribute(name)
		return if type(value) == "number" then value else -1 -- -1 = no plate
	end
	const plate = Vide.source(readMask()) :: Vide.Source<number>
	const connection = station:GetAttributeChangedSignal(name):Connect(function()
		plate(readMask())
	end)
	-- the 3D prep view of this slot is up (it draws the plate itself)
	const viewName = `{VIEW_ATTRIBUTE}{spot.Slot}`
	const viewing = Vide.source(station:GetAttribute(viewName) == true)
	const viewConnection = station:GetAttributeChangedSignal(viewName):Connect(function()
		viewing(station:GetAttribute(viewName) == true)
	end)
	Vide.cleanup(function()
		connection:Disconnect()
		viewConnection:Disconnect()
	end)
	local function mask(): number?
		const value = plate()
		return if value >= 0 then value else nil
	end
	local function progress(): number
		return Slots.Progress(read, clock)
	end

	-- state transitions (nil = no record seen yet: the first one is silent)
	local last: string? = nil
	effect(function()
		const record = read()
		const state = if record then record.State else nil
		const previous = last
		last = state
		if previous == nil or state == nil or previous == state then
			return
		end
		const altered = record ~= nil and record.Altered > 0
		untrack(function()
			const at = (spot.Host.CFrame * spot.Offset).Position
			if previous == "Empty" and not altered then
				audio.Play(station, "bun_slice", at, { Fit = if record and record.Duration > 0 then record.Duration else nil })
			elseif state == "Empty" and previous == "Ready" then
				audio.Play(station, "hotdog_assemble", at)
			end
			return nil
		end)
	end)

	const model = derive(function(): string?
		const record = read()
		if record == nil or record.State == "Empty" then
			return nil
		elseif record.Altered > 0 then
			return "BunBitten" -- AST-061: arrives already sliced (Ready)
		end
		if mask() ~= nil then
			return nil -- a prep plate: drawn whole below
		end
		return if progress() >= 1 then "BunOpen" else "BunClosed"
	end)

	-- a prep plate, for everyone: bun (open once cut), sausage, toppings in ONE model, at the size of the prep mode, in the middle of
	-- the board (where the 3D mode works); out of the way while the local 3D Build view of this slot draws it
	effect(function()
		const current = mask()
		if current == nil or viewing() then
			return
		end
		const record = read()
		if record ~= nil and record.Altered > 0 then
			return -- the altered bun (ANM-002) keeps its own picture
		end
		untrack(function()
			drawPlate(station, spot, board, PlateMask.Unpack(current))
			return nil
		end)
	end)

	effect(function()
		const name = model()
		if name then
			Slots.Food(name, spot, station)
		end
	end)

	Slots.Bar(spot, BUN_HEIGHT, progress, function()
		const record = read()
		-- a prep plate holds the slot "Working" for its whole life: no cut bar for it
		return record ~= nil and record.State == "Working" and mask() == nil
	end)
end

const Board = {}

Board.Kinds = table.freeze({ [KIND] = true }) :: { [string]: boolean }

function Board.Mount(station: Instance, context: Context.Context)
	const stationId = Slots.StationId(station)
	const spots = Slots.Spots(station, true)
	const readers: { [number]: Slots.Reader } = {}
	for slot in spots do
		readers[slot] = Slots.Reader(context, stationId, slot, KIND)
	end
	const clock = Slots.Clock(function()
		return Slots.AnyWorking(readers)
	end)
	-- the cutting board mesh (the prep mode's plate sits in its middle)
	const mesh = station:FindFirstChild("Board", true)
	const board = if mesh ~= nil and mesh:IsA("BasePart") then mesh else nil
	for slot, spot in spots do
		-- where the 3D prep mode finds the board's bun to hide it locally (SlotView("board", slot).Station)
		Slots.Track(station, KIND, spot)
		mountSlot(station, spot, readers[slot], clock, context.Audio, board)
	end
end

return table.freeze(Board) :: Context.Part
