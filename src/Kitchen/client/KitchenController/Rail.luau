--!strict
-- Rail visuals (TASK-030; FEAT-006 step 3; network.md §3.5, architecture.md §18.4).
-- A single Stations record (StationId * 100 + 0, Kind = rail) with `Count` = sausages resting on it (FIFO lives on
-- the server). Anchors `Slot1..6` (trailer 8) with `Slot`. The client shows `Count` SausageGrilled filling slots
-- 1..Count; when one leaves, the last one disappears (the queue is a server fact, the picture is just a count).
-- A Count above the number of anchors only fills the anchors that exist.
-- Wave 3 (TASK-110, ANM-002): `Altered` = position 1..Count of the gray sausage (position 1 = front = slot 1, the
-- next "Add Sausage"); that slot shows SausageWrong (AST-061) instead. Positions shift with the queue, so the
-- picture follows the server's field, never a local guess.
-- TASK-283 (owner report 2026-10-14): a prep plate with its sausage in (`Plate<slot>` of the board, Sausage bit) still counts that
-- sausage on the rail until the hot dog is made (KitchenService Plate.Finish pops the front one), so the picture showed it twice.
-- The front slots, one per such plate, stay empty; the plate model on the board (Board.luau) carries it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Context = require(script.Parent.Context)
local Slots = require(script.Parent.Slots)
local RailSlot = require(ReplicatedStorage.shared.Kitchen.RailSlot)
local PlateMask = require(ReplicatedStorage.shared.Prep.PlateMask)

const effect = Vide.effect
const derive = Vide.derive

const KIND = "rail"
const RECORD_SLOT = 0 -- single-record station (network.md §3.5)
const PLATE_PATTERN = "^Plate%d+$" -- Board.luau / server Stations/Board: the mask of a prep plate per slot

-- Sausages the prep plates on the board next to this rail already hold (live: follows the board's attributes)
local function plateSausages(station: Instance): () -> number
	const held = Vide.source(0)
	const parent = station.Parent
	local board: Instance? = nil
	if parent ~= nil then
		for _, sibling in parent:GetChildren() do
			if sibling:GetAttribute("StationKind") == "board" then
				board = sibling
				break
			end
		end
	end
	if board == nil then
		return held
	end
	const found = board :: Instance
	local function count()
		local n = 0
		for name, value in found:GetAttributes() do
			if string.match(name, PLATE_PATTERN) ~= nil and type(value) == "number" and PlateMask.Unpack(value).Sausage then
				n += 1
			end
		end
		held(n)
	end
	count()
	const connection = found.AttributeChanged:Connect(function(name: string)
		if string.match(name, PLATE_PATTERN) ~= nil then
			count()
		end
	end)
	Vide.cleanup(function()
		connection:Disconnect()
	end)
	return held
end

const Rail = {}

Rail.Kinds = table.freeze({ [KIND] = true }) :: { [string]: boolean }

function Rail.Mount(station: Instance, context: Context.Context)
	const read = Slots.Reader(context, Slots.StationId(station), RECORD_SLOT, KIND)
	const count = derive(function(): number
		const record = read()
		return if record then record.Count else 0
	end)
	const altered = derive(function(): number
		const record = read()
		return if record then record.Altered else 0
	end)
	const reserved = plateSausages(station)
	-- pose of each sausage = Rail_<slot>/Part (owner request 2026-10-12; RailSlot), anchors only as fallback
	const spots = Slots.Spots(station, false)
	RailSlot.Spots(station, spots)
	for slot, spot in spots do
		Slots.Track(station, KIND, spot) -- where the 3D prep mode flies a collected sausage to
		const model = derive(function(): string?
			if count() < slot or slot <= reserved() then
				return nil
			end
			return if altered() == slot then "SausageWrong" else "SausageGrilled"
		end)
		effect(function()
			const name = model()
			if name then
				Slots.Food(name, spot, station)
			end
		end)
	end
end

return table.freeze(Rail) :: Context.Part
