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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Context = require(script.Parent.Context)
local Slots = require(script.Parent.Slots)

const effect = Vide.effect
const derive = Vide.derive
const untrack = Vide.untrack

const KIND = "board"
const BUN_HEIGHT = 0.35 -- AST-001 BunClosed (build_items.luau)

local function mountSlot(
	station: Instance,
	spot: Slots.Spot,
	read: Slots.Reader,
	clock: () -> number,
	audio: Context.Audio
)
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
		return if progress() >= 1 then "BunOpen" else "BunClosed"
	end)

	effect(function()
		const name = model()
		if name then
			Slots.Food(name, spot, station)
		end
	end)

	Slots.Bar(spot, BUN_HEIGHT, progress, function()
		const record = read()
		return record ~= nil and record.State == "Working"
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
	for slot, spot in spots do
		mountSlot(station, spot, readers[slot], clock, context.Audio)
	end
end

return table.freeze(Board) :: Context.Part
