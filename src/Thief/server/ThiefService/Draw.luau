--!strict
-- ThiefService/Draw: the day's thief draw (FEAT-013; DEC-050; architecture.md §19.10, §4 rule 6). TASK-072.
-- Pure: only Content.Thief. Random(hash(RunSeed, Day, "thief")): the same run and day always give the same answer
-- (a snapshot restore re-draws the same thief). Chance from ChanceByDay (Days[d], then Default; endless days too),
-- start minute uniform inside WindowClock, lurk point uniform among Lurks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Plan = {
	Day: number,
	At: number, -- game minute (Content.Shift clock) at which the thief tries to spawn
	Lurk: string, -- MapPoint / NpcNode id
}

const SEED_MAX = 2147483647
const DOMAIN = "thief"

const Draw = {}

-- djb2, same as CustomerService (architecture.md §4 rule 6)
local function hash(text: string): number
	local h = 5381
	for index = 1, #text do
		h = (h * 33 + string.byte(text, index)) % 4294967296
	end
	return h
end

-- Seeded Random of (run seed, day).
function Draw.random(seed: number, day: number): Random
	return Random.new(hash(`{seed}|{day}|{DOMAIN}`) % SEED_MAX + 1)
end

-- Chance of a thief on `day` (0..1).
function Draw.chance(day: number): number
	const chance = Content.Thief.ChanceByDay
	return chance.Days[day] or chance.Default
end

-- Plan of `day`, or nil (no thief that day). `rng` defaults to Draw.random(seed, day).
function Draw.roll(seed: number, day: number, rng: Random?): Plan?
	const random = rng or Draw.random(seed, day)
	const thief = Content.Thief
	if random:NextNumber() >= Draw.chance(day) then
		return nil
	end
	const window = thief.WindowClock
	return {
		Day = day,
		At = random:NextNumber(window[1], window[2]),
		Lurk = thief.Lurks[random:NextInteger(1, #thief.Lurks)],
	}
end

return table.freeze(Draw)
