--!strict
-- Achievements and badges (content-data.md §3.11; architecture.md §19.11; data.md §1; DEC-058, DEC-084, DEC-315;
-- design/badges.md). Owner: game-designer + narrative-writer (Name). Key = what the profile stores in Achievements;
-- Notice "achievement" carries IndexOf. Two kinds:
--   Counter  numeric field of the profile Template that drives it, unlocked when it reaches Target (RewardService
--            CheckAchievements);
--   event    Counter nil: a service calls RewardService:Unlock(player, Key) when it happens (Target 1).
-- BadgeId 0 = no badge yet (the owner creates it in the Creator Hub and passes the id; 5 free per day).
local Table = require(script.Parent.Table)

export type Achievement = {
	Key: string,
	Name: string,
	Hidden: boolean, -- secret until unlocked (DEC-058)
	Counter: string?, -- nil = unlocked by event (RewardService:Unlock)
	Target: number,
	Gems: number,
	BadgeId: number,
}

local function event(key: string, name: string, hidden: boolean, badgeId: number): Achievement
	return { Key = key, Name = name, Hidden = hidden, Target = 1, Gems = 0, BadgeId = badgeId }
end

-- Order = design/badges.md §2 (the icon numbers in Assets/ui/badges)
return Table.new({
	event("welcome", "Welcome to the Corner", false, 2319638173193014), -- 1: first join
	event("tutorial_done", "Clocked In", false, 1723416246988299), -- 2: tutorial finished (not skipped)
	event("first_hotdog", "First Dog Served", false, 2233023475659459), -- 3: first complete order served
	event("golden_flip", "Golden Flip", false, 2104755363239074), -- 4: a Perfect flip on the grill
	event("first_night", "First Night Shift", false, 579574344858433), -- 5: Night 1 won
	event("not_today", "Not Today", false, 664777349866945), -- 6: a customer anomaly refused
	event("lights_back", "Lights Back On", false, 3346220351559110), -- 7: blackout fixed in time (ANM-020); trigger pending
	event("bolted_shut", "Bolted Shut", false, 25820054546149), -- 8: locked the back door in time on ANM-009 (DEC-359)
	event("eyes_down", "Eyes Down", true, 1336379813159280), -- 9: ANM-019 without looking up; trigger pending
	event("met_hunter", "Met the Hunter", true, 3893516056885966), -- 10: Q-404; trigger pending
	event("halfway", "Halfway to Dawn", false, 3931705433826652), -- 11: Night 5 won
	event("hot_dog_hundred", "Hot Dog Hundred", false, 0), -- 12: 100 complete orders; trigger pending (Stats counter)
	event("kept_light", "Kept the Light On", false, 0), -- 13: last night won
	event("not_a_scratch", "Not a Scratch", true, 0), -- 14: run without fainting; trigger pending
	{
		Key = "day_100",
		Name = "Never Clocked Out", -- ui-text.md §9
		Hidden = true, -- DEC-058
		Counter = "EndlessDays", -- data.md §1 (endless days with anti-AFK, across sessions)
		Target = 100, -- DEC-084
		Gems = 22500, -- DEC-084: 300, x75 (TASK-308)
		BadgeId = 0,
	},
} :: { Achievement })
