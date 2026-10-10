--!strict
-- Grill visuals (TASK-030; FEAT-006 steps 2-3, DEC-015, DEC-029, DEC-201; network.md §3.5, architecture.md §18.4).
-- One Stations record per slot (StationId * 100 + Slot, Kind = grill); one anchor per slot (`Att_Slot<n>`, `Slot`).
--   Empty            nothing on the rollers, no bar
--   Working          SausageRaw + ProgressBar from StartedAt/Duration (orange)
--   bar full/Ready   SausageGrilled + full green bar until "Collect" (no burning in the MVP, FEAT-006)
-- The raw -> grilled swap happens when the local bar reaches the end (same instant as the bar turns green), so the
-- sausage and the bar agree; Ready from the server keeps it grilled. Presentation only: the server owns the slot.
-- A late joiner gets the current records through onAdded: a slot halfway shows the bar at the right point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Context = require(script.Parent.Context)
local Slots = require(script.Parent.Slots)

const effect = Vide.effect
const derive = Vide.derive

const KIND = "grill"
const SAUSAGE_HEIGHT = 0.24 -- AST-002 (build_items.luau)

local function mountSlot(station: Instance, spot: Slots.Spot, read: Slots.Reader, clock: () -> number)
	local function progress(): number
		return Slots.Progress(read, clock)
	end

	const model = derive(function(): string?
		const record = read()
		if record == nil or record.State == "Empty" then
			return nil
		end
		return if progress() >= 1 then "SausageGrilled" else "SausageRaw"
	end)

	effect(function()
		const name = model()
		if name then
			Slots.Food(name, spot, station)
		end
	end)

	Slots.Bar(spot, SAUSAGE_HEIGHT, progress, function()
		const record = read()
		return record ~= nil and record.State ~= "Empty"
	end)
end

const Grill = {}

Grill.Kinds = table.freeze({ [KIND] = true }) :: { [string]: boolean }

function Grill.Mount(station: Instance, context: Context.Context)
	const stationId = Slots.StationId(station)
	const spots = Slots.Spots(station, false)
	const readers: { [number]: Slots.Reader } = {}
	for slot in spots do
		readers[slot] = Slots.Reader(context, stationId, slot, KIND)
	end
	const clock = Slots.Clock(function()
		return Slots.AnyWorking(readers)
	end)
	for slot, spot in spots do
		mountSlot(station, spot, readers[slot], clock)
	end
end

return table.freeze(Grill) :: Context.Part
