--!strict
-- Rail visuals (TASK-030; FEAT-006 step 3; network.md §3.5, architecture.md §18.4).
-- A single Stations record (StationId * 100 + 0, Kind = rail) with `Count` = sausages resting on it (FIFO lives on
-- the server). Anchors `Slot1..6` (trailer 8) with `Slot`. The client shows `Count` SausageGrilled filling slots
-- 1..Count; when one leaves, the last one disappears (the queue is a server fact, the picture is just a count).
-- A Count above the number of anchors only fills the anchors that exist.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Context = require(script.Parent.Context)
local Slots = require(script.Parent.Slots)

const effect = Vide.effect
const derive = Vide.derive

const KIND = "rail"
const RECORD_SLOT = 0 -- single-record station (network.md §3.5)

const Rail = {}

Rail.Kinds = table.freeze({ [KIND] = true }) :: { [string]: boolean }

function Rail.Mount(station: Instance, context: Context.Context)
	const read = Slots.Reader(context, Slots.StationId(station), RECORD_SLOT, KIND)
	const count = derive(function(): number
		const record = read()
		return if record then record.Count else 0
	end)
	for slot, spot in Slots.Spots(station, false) do
		const shown = derive(function(): boolean
			return count() >= slot
		end)
		effect(function()
			if shown() then
				Slots.Food("SausageGrilled", spot, station)
			end
		end)
	end
end

return table.freeze(Rail) :: Context.Part
