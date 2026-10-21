--!strict
-- Lightning (TASK-275, ATM-4 / ATM-5). Pure timing: AtmosphereController adds the returned flash level to Lighting.
-- Natural strikes: each Every-second window of server time draws, from Random(window), whether it has a strike
-- (Chance), when (an offset inside the window), whether it is near (Near) and the thunder delay, so every client
-- flashes at the same moment without a packet. Forced strikes (Force: /dev bolt, AtmosphereService:Strike) come at a
-- given server time. Flash = two quick pulses inside Flash seconds, NearScale brighter for a near one; the thunder
-- callback runs ThunderDelay (far) or NearDelay (near) later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

type Bolt = Content.AtmosphereLightning

const SEED_SALT = 7919
const EDGE = 0.15 -- strikes stay inside [EDGE, 1 - EDGE] of the window, so two never touch

export type Lightning = {
	Window: number, -- last window handled
	StrikeAt: number, -- server time of the last strike seen (0 = none)
	StrikeScale: number, -- flash multiplier of that strike (NearScale when near)
	Drawn: number, -- window of the cached draw below
	DrawnHas: boolean, -- that window has a strike
	DrawnAt: number, -- strike time of that window
	DrawnNear: boolean,
	DrawnDelay: number, -- thunder delay of that window
	ForcedAt: number?, -- server time of a pending forced strike
	ForcedNear: boolean,
	Listeners: { (number, boolean) -> () },
	Reset: (self: Lightning) -> (),
	Force: (self: Lightning, at: number, near: boolean) -> (),
	Listen: (self: Lightning, callback: (number, boolean) -> ()) -> () -> (),
	Strike: (self: Lightning, bolt: Bolt, at: number, near: boolean, delay: number, now: number, thunder: (boolean) -> ()) -> (),
	Step: (self: Lightning, bolt: Bolt, now: number, natural: boolean, thunder: (boolean) -> ()) -> number,
}

local function pulse(t: number, at: number, width: number): number
	const x = (t - at) / width
	if x < 0 or x > 1 then
		return 0
	end
	return 1 - math.abs(x * 2 - 1)
end

const Lightning = {}
Lightning.__index = Lightning

function Lightning.new(): Lightning
	return setmetatable({
		Window = -1,
		StrikeAt = 0,
		StrikeScale = 1,
		Drawn = -1,
		DrawnHas = false,
		DrawnAt = 0,
		DrawnNear = false,
		DrawnDelay = 0,
		ForcedAt = nil,
		ForcedNear = false,
		Listeners = {},
	}, Lightning) :: any
end

function Lightning.Reset(self: Lightning)
	self.Window = -1
	self.StrikeAt = 0
end

-- A strike at server time `at` (dev / scripted scare), on top of the natural ones.
function Lightning.Force(self: Lightning, at: number, near: boolean)
	self.ForcedAt = at
	self.ForcedNear = near
end

function Lightning.Listen(self: Lightning, callback: (number, boolean) -> ()): () -> ()
	table.insert(self.Listeners, callback)
	return function()
		const index = table.find(self.Listeners, callback)
		if index then
			table.remove(self.Listeners, index)
		end
	end
end

function Lightning.Strike(self: Lightning, bolt: Bolt, at: number, near: boolean, delay: number, now: number, thunder: (boolean) -> ())
	self.StrikeAt = at
	self.StrikeScale = if near then bolt.NearScale else 1
	task.delay(math.max(0, delay - (now - at)), thunder, near)
	for _, listener in table.clone(self.Listeners) do
		task.spawn(listener, at, near)
	end
end

-- Flash level at `now` (0..NearScale); fires listeners and schedules `thunder(near)` once per strike. `natural` =
-- the row has its own Lightning and is mostly in (forced strikes play anyway).
function Lightning.Step(self: Lightning, bolt: Bolt, now: number, natural: boolean, thunder: (boolean) -> ()): number
	const forcedAt = self.ForcedAt
	if forcedAt ~= nil and now >= forcedAt then
		self.ForcedAt = nil
		if now - forcedAt <= bolt.Flash then
			const rng = Random.new()
			const range = if self.ForcedNear then bolt.NearDelay else bolt.ThunderDelay
			self:Strike(bolt, forcedAt, self.ForcedNear, rng:NextNumber(range[1], range[2]), now, thunder)
		end
	end

	const window = math.floor(now / bolt.Every)
	if window ~= self.Window then
		if window ~= self.Drawn then
			const rng = Random.new(window * SEED_SALT + 17)
			self.Drawn = window
			self.DrawnHas = rng:NextNumber() < bolt.Chance
			self.DrawnAt = (window + rng:NextNumber(EDGE, 1 - EDGE)) * bolt.Every
			self.DrawnNear = rng:NextNumber() < bolt.Near
			const range = if self.DrawnNear then bolt.NearDelay else bolt.ThunderDelay
			self.DrawnDelay = rng:NextNumber(range[1], range[2])
		end
		const strikeAt = self.DrawnAt
		if now >= strikeAt then
			self.Window = window
			-- a strike already gone (late join, fade-in) is skipped silently
			if natural and self.DrawnHas and now - strikeAt <= bolt.Flash then
				self:Strike(bolt, strikeAt, self.DrawnNear, self.DrawnDelay, now, thunder)
			end
		end
	end
	if self.StrikeAt == 0 then
		return 0
	end
	const t = now - self.StrikeAt
	if t > bolt.Flash then
		return 0
	end
	-- main pulse (first 40%), a smaller second one (last 50%)
	return self.StrikeScale * math.max(pulse(t, 0, bolt.Flash * 0.4), 0.7 * pulse(t, bolt.Flash * 0.5, bolt.Flash * 0.5))
end

return Lightning
