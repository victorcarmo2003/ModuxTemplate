--!strict
-- Lightning of a storm atmosphere (TASK-275, ATM-5). Pure timing: AtmosphereController adds the returned flash level
-- to Lighting. One strike per Every-second window of server time, at an offset drawn from Random(window), so every
-- client flashes at the same moment without a packet. Flash = two quick pulses inside Flash seconds; the thunder plays
-- ThunderDelay later (also drawn from the window, same on every client).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

type Bolt = Content.AtmosphereLightning

const SEED_SALT = 7919
const EDGE = 0.15 -- strikes stay inside [EDGE, 1 - EDGE] of the window, so two never touch

export type Lightning = {
	Window: number, -- last window handled
	StrikeAt: number, -- server time of the last strike seen (0 = none)
	Drawn: number, -- window of the cached draw below
	DrawnAt: number, -- strike time of that window
	DrawnDelay: number, -- thunder delay of that window
	Listeners: { (number) -> () },
	Reset: (self: Lightning) -> (),
	Listen: (self: Lightning, callback: (number) -> ()) -> () -> (),
	Step: (self: Lightning, bolt: Bolt, now: number, armed: boolean, thunder: () -> ()) -> number,
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
	return setmetatable({ Window = -1, StrikeAt = 0, Drawn = -1, DrawnAt = 0, DrawnDelay = 0, Listeners = {} }, Lightning) :: any
end

function Lightning.Reset(self: Lightning)
	self.Window = -1
	self.StrikeAt = 0
end

function Lightning.Listen(self: Lightning, callback: (number) -> ()): () -> ()
	table.insert(self.Listeners, callback)
	return function()
		const index = table.find(self.Listeners, callback)
		if index then
			table.remove(self.Listeners, index)
		end
	end
end

-- Flash level 0..1 at `now`; fires listeners and schedules `thunder` once per strike.
function Lightning.Step(self: Lightning, bolt: Bolt, now: number, armed: boolean, thunder: () -> ()): number
	const window = math.floor(now / bolt.Every)
	if window ~= self.Window then
		if window ~= self.Drawn then
			const rng = Random.new(window * SEED_SALT + 17)
			self.Drawn = window
			self.DrawnAt = (window + rng:NextNumber(EDGE, 1 - EDGE)) * bolt.Every
			self.DrawnDelay = rng:NextNumber(bolt.ThunderDelay[1], bolt.ThunderDelay[2])
		end
		const strikeAt = self.DrawnAt
		const delay = self.DrawnDelay
		if now >= strikeAt then
			self.Window = window
			-- a strike already gone (late join, fade-in) is skipped silently
			if armed and now - strikeAt <= bolt.Flash then
				self.StrikeAt = strikeAt
				task.delay(math.max(0, delay - (now - strikeAt)), thunder)
				for _, listener in table.clone(self.Listeners) do
					task.spawn(listener, strikeAt)
				end
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
	return math.max(pulse(t, 0, bolt.Flash * 0.4), 0.7 * pulse(t, bolt.Flash * 0.5, bolt.Flash * 0.5))
end

return Lightning
