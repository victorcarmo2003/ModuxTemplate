--!strict
-- Grill visuals (TASK-030; FEAT-006 steps 2-3, DEC-015, DEC-029, DEC-201; network.md §3.5, architecture.md §18.4).
-- One Stations record per slot (StationId * 100 + Slot, Kind = grill); one anchor per slot (`Att_Slot<n>`, `Slot`).
--   Empty            nothing on the rollers, no bar
--   Working          SausageRaw + ProgressBar from StartedAt/Duration (orange)
--   bar full/Ready   SausageGrilled + full green bar until "Collect" (no burning in the MVP, FEAT-006)
-- The raw -> grilled swap happens when the local bar reaches the end (same instant as the bar turns green), so the
-- sausage and the bar agree; Ready from the server keeps it grilled. Presentation only: the server owns the slot.
-- A late joiner gets the current records through onAdded: a slot halfway shows the bar at the right point.
-- Sound and VFX (TASK-079; sound-list §5.3, AST-092), on transitions only (a late joiner's first record is silent):
--   Empty -> Working   SFX-020 `grill_drop` at the slot
--   bar reaches 1      SFX-022 `grill_ready` + ReadyVFX (10 stars) at the slot
--   Ready -> Empty     SFX-023 `grill_collect` at the slot ("Collect" took it to the rail)
--   any slot busy      SFX-021 `grill_sizzle` loop on the grill (volume by busy slots) + smoke, Rate 3 per busy slot
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Context = require(script.Parent.Context)
local Fx = require(script.Parent.Fx)
local Slots = require(script.Parent.Slots)

const effect = Vide.effect
const derive = Vide.derive
const cleanup = Vide.cleanup
const untrack = Vide.untrack

const SIZZLE_MIN = 0.5 -- sizzle volume with 1 busy slot; full with every slot busy
const SMOKE_RISE = 0.3

const KIND = "grill"
const SAUSAGE_HEIGHT = 0.24 -- AST-002 (build_items.luau)

local function spotPosition(spot: Slots.Spot): Vector3
	return (spot.Host.CFrame * spot.Offset).Position
end

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
		untrack(function()
			if previous == "Empty" then
				audio.Play(station, "grill_drop", spotPosition(spot))
			elseif state == "Empty" and previous == "Ready" then
				audio.Play(station, "grill_collect", spotPosition(spot))
			end
			return nil
		end)
	end)

	const model = derive(function(): string?
		const record = read()
		if record == nil or record.State == "Empty" then
			return nil
		end
		return if progress() >= 1 then "SausageGrilled" else "SausageRaw"
	end)

	local shown: string? = nil
	effect(function()
		const name = model()
		const previous = shown
		shown = name
		if name then
			Slots.Food(name, spot, station)
		end
		if previous == "SausageRaw" and name == "SausageGrilled" then
			untrack(function()
				if audio.Current(station) then
					const at = spotPosition(spot) + Vector3.new(0, SAUSAGE_HEIGHT, 0)
					audio.Play(station, "grill_ready", at)
					Fx.Burst(at, "Ready", 10)
				end
				return nil
			end)
		end
	end)

	Slots.Bar(spot, SAUSAGE_HEIGHT, progress, function()
		const record = read()
		return record ~= nil and record.State ~= "Empty"
	end)
end

-- Sizzle loop + smoke for the whole grill, from the number of busy slots.
local function mountGrill(
	station: Instance,
	spots: { [number]: Slots.Spot },
	readers: { [number]: Slots.Reader },
	audio: Context.Audio
)
	local total = 0
	local sum = Vector3.zero
	local host: BasePart? = nil
	for _, spot in spots do
		total += 1
		sum += spotPosition(spot)
		host = host or spot.Host
	end
	if host == nil or total == 0 then
		return
	end
	const anchor = Instance.new("Attachment")
	anchor.Name = "Fx_Grill"
	anchor.Parent = host
	anchor.WorldPosition = sum / total + Vector3.new(0, SMOKE_RISE, 0)
	cleanup(anchor)

	const smoke = Fx.Smoke(anchor)
	cleanup(smoke)

	const busy = derive(function(): number
		local count = 0
		for _, read in readers do
			const record = read()
			if record and record.State ~= "Empty" then
				count += 1
			end
		end
		return count
	end)

	effect(function()
		const count = busy()
		untrack(function()
			const current = audio.Current(station)
			Fx.SetSmoke(smoke, if current then count else 0)
			audio.Loop(station, "grill_sizzle", anchor, count > 0, SIZZLE_MIN + (1 - SIZZLE_MIN) * count / total)
			return nil
		end)
	end)
	cleanup(function()
		audio.Loop(station, "grill_sizzle", anchor, false)
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
		mountSlot(station, spot, readers[slot], clock, context.Audio)
	end
	mountGrill(station, spots, readers, context.Audio)
end

return table.freeze(Grill) :: Context.Part
