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
--   any slot Working   SFX-021 `grill_sizzle` loop on the grill (volume by frying slots) + smoke, Rate 3 per frying slot
--                      (owner 2026-10-21: a Ready / Burnt sausage left on the rollers or a cleaning grill is silent)
--   Flip 0 -> 1        the sausage hops up and rolls over (owner 2026-10-22: "dá um pulinho e realmente gira"), local,
--                      FLIP_TIME s, FLIP_HOP studs high, about its long axis; it lands turned (the same pose as Turn)
-- Wave 3 (TASK-110): a slot with `Altered` >= 1 shows SausageWrong (AST-061) whatever the bar says (no ready burst).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Context = require(script.Parent.Context)
local FlipMeter = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.FlipMeter)
local Fx = require(script.Parent.Fx)
local Slots = require(script.Parent.Slots)

const effect = Vide.effect
const derive = Vide.derive
const cleanup = Vide.cleanup
const untrack = Vide.untrack

const SIZZLE_MIN = 0.5 -- sizzle volume with 1 frying slot; full with every slot frying
const SMOKE_RISE = 0.3

const KIND = "grill"
const SAUSAGE_HEIGHT = 0.24 -- AST-002 (build_items.luau)
const OVERLAY_SCALE = 1.012 -- the grilled model over the raw one: no z-fight
const FADE_FROM = 0.1 -- cooking share at which the grilled colour starts to show (Provisional, S1)
-- DEC-311: an unflipped sausage waits at this share until its flip (the server holds it without touching the record)
const HOLD_AT = Content.Restaurant.Grill.HoldAt
const FLIP_TIME = 0.42 -- s of the hop (Provisional, judged in Play)
const FLIP_HOP = 0.55 -- studs at the top of the hop
const FLIP_ROLL = 3 * math.pi -- a roll and a half about the long axis: it lands turned over (Turn = pi)

local function spotPosition(spot: Slots.Spot): Vector3
	return (spot.Host.CFrame * spot.Offset).Position
end

local function mountSlot(
	station: Instance,
	stationId: () -> number?,
	spot: Slots.Spot,
	read: Slots.Reader,
	clock: () -> number,
	audio: Context.Audio
)
	-- TASK-594 (owner 2026-10-19: the bar ran to full before the flip, then dropped back to half): unflipped, the bar stops at
	-- HoldAt like the server; the flip moves StartedAt so it goes on from there
	local function progress(): number
		const value = Slots.Progress(read, clock)
		const record = read()
		if record ~= nil and record.State == "Working" and record.Flip == 0 then
			return math.min(value, HOLD_AT)
		end
		return value
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

	-- One container per slot with the raw sausage and, laid over it (1.2 % bigger), the grilled one: the colour of the cooking is
	-- the grilled model fading in by the server clock (S1 of prep-3d.md: cross-fade of the two real models, no EditableMesh).
	-- The pair is made once when the slot fills and lives until it empties, so a hover contour, a flip turn or a hop of the 3D
	-- prep mode never loses its model at the "ready" instant. A wrong (altered) sausage stays a single model.
	const entry = Slots.Track(station, KIND, spot)
	const mode = derive(function(): string?
		const record = read()
		if record == nil or record.State == "Empty" then
			return nil
		elseif record.Altered > 0 then
			return "Wrong" -- AST-061 (network.md §13.5 allows it on the grill; TASK-109 does not use it today)
		end
		return "Pair"
	end)

	-- the hop in progress lands at once when the slot unmounts (its effects re-run on every record change)
	local landing: (() -> ())? = nil
	cleanup(function()
		if landing ~= nil then
			landing()
		end
	end)
	-- the flip hop: the models of the slot leave their welds, jump and roll about the long axis, land turned and weld again
	local function hop(models: { Model })
		if landing ~= nil then
			landing() -- a hop still in the air lands first
		end
		const centre = CFrame.new(0, Slots.FlipCenter, 0)
		local function frame(): CFrame
			return spot.Host.CFrame * spot.Offset * centre
		end
		const start = frame()
		const rel: { [Model]: CFrame } = {}
		for _, model in models do
			Slots.Detach(model)
			rel[model] = start:ToObjectSpace(model:GetPivot())
		end
		const began = os.clock()
		local connection: RBXScriptConnection? = nil
		local function land()
			landing = nil
			if connection ~= nil then
				connection:Disconnect()
				connection = nil
			end
			for _, model in models do
				if model.Parent ~= nil and spot.Host.Parent ~= nil then
					-- the landing pose: turned once (the rebuild's Turn = pi); the extra roll is whole turns
					model:PivotTo(frame() * CFrame.Angles(math.pi, 0, 0) * rel[model])
					Slots.Attach(model, spot.Host)
				end
			end
		end
		connection = RunService.RenderStepped:Connect(function()
			const t = math.clamp((os.clock() - began) / FLIP_TIME, 0, 1)
			if t >= 1 or spot.Host.Parent == nil then
				land()
				return
			end
			-- up and down (a parabola), the roll eased out so it settles on the grill
			const lift = FLIP_HOP * 4 * t * (1 - t)
			const roll = FLIP_ROLL * (1 - (1 - t) ^ 2)
			const at = frame() * CFrame.new(0, lift, 0) * CFrame.Angles(roll, 0, 0)
			for _, model in models do
				if model.Parent ~= nil then
					model:PivotTo(at * rel[model])
				end
			end
		end)
		landing = land
	end

	-- Flip 0 -> > 0 on the record while the slot shows its models: the hop (a rebuild already lands turned)
	local lastFlip = -1
	effect(function()
		const record = read()
		const flip = if record ~= nil then record.Flip else 0
		untrack(function()
			const before = lastFlip
			lastFlip = flip
			if before == 0 and flip > 0 then
				const models: { Model } = {}
				for _, model in { entry.Raw, entry.Over } do
					if model ~= nil and model.Parent ~= nil then
						table.insert(models, model)
					end
				end
				if #models > 0 then
					hop(models)
				end
			end
			return nil
		end)
	end)

	local lastProgress = 0
	local shownAlpha = -1
	local shownDone = false
	effect(function()
		const kind = mode()
		entry.Container = nil
		entry.Raw = nil
		entry.Over = nil
		if kind ~= nil then
			const record = untrack(read)
			const turn = if record ~= nil and record.Flip > 0 then math.pi else 0
			const holder = Instance.new("Model")
			holder.Name = `Sausage_Slot{spot.Slot}`
			holder.Parent = station
			cleanup(holder)
			if kind == "Wrong" then
				entry.Raw = Slots.Food("SausageWrong", spot, holder, { Turn = turn })
			else
				entry.Raw = Slots.Food("SausageRaw", spot, holder, { Turn = turn })
				entry.Over = Slots.Food("SausageGrilled", spot, holder, { Turn = turn, Scale = OVERLAY_SCALE })
			end
			entry.Container = holder
			lastProgress = untrack(progress)
		end
		shownAlpha = -1
		shownDone = false
		Slots.Notify(entry)
	end)

	-- the cooking colour: raw until FADE_FROM, grilled fully over it at 1 (and then alone)
	effect(function()
		const kind = mode()
		const p = progress()
		untrack(function()
			const over = entry.Over
			const raw = entry.Raw
			if kind ~= "Pair" or over == nil or raw == nil then
				return nil
			end
			const done = p >= 1
			const fade = math.clamp((p - FADE_FROM) / (1 - FADE_FROM), 0, 1)
			const alpha = if done then 0 else math.floor((1 - fade) * 50 + 0.5) / 50 -- Transparency of the grilled one, 50 steps
			-- done is part of the key: the overlay reaches alpha 0 a little before 1, and the raw one must still go (owner
			-- 2026-10-22: it stayed under the grilled one and the two fought)
			if alpha ~= shownAlpha or done ~= shownDone then
				shownAlpha = alpha
				shownDone = done
				for _, part in over:GetDescendants() do
					if part:IsA("BasePart") then
						part.Transparency = alpha
					end
				end
				for _, part in raw:GetDescendants() do
					if part:IsA("BasePart") then
						part.Transparency = if done then 1 else 0
					end
				end
			end
			if lastProgress < 1 and done then
				if audio.Current(station) then
					const at = spotPosition(spot) + Vector3.new(0, SAUSAGE_HEIGHT, 0)
					audio.Play(station, "grill_ready", at)
					Fx.Burst(at, "Ready", 10)
				end
			end
			lastProgress = p
			return nil
		end)
	end)

	Slots.Bar(spot, SAUSAGE_HEIGHT, progress, function()
		const record = read()
		return record ~= nil and record.State ~= "Empty"
	end, true, function(): boolean
		-- the focused cook mode says which sausage is being flipped (the same record id as the Stations set)
		const id = stationId()
		return id ~= nil and FlipMeter.State.Active() == id * 100 + spot.Slot
	end, FlipMeter.State.Marker)
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
			if record and record.State == "Working" then
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
		mountSlot(station, stationId, spot, readers[slot], clock, context.Audio)
	end
	mountGrill(station, spots, readers, context.Audio)
end

return table.freeze(Grill) :: Context.Part
