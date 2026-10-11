--!strict
-- CustomerService/Group: customer pairs, pure (FEAT-038; Content.Flow.Groups; Q-182 A; TASK-146). No Service, no
-- network, no Instance: chance, pair draw, partner look and the partner's follow spot. Same Random state in = same
-- result out (architecture.md §4 rule 6: the caller passes the shift Random).
--
--   chance   Day >= FromDay: ChanceDay; Night >= FromNight: ChanceNight; else 0 (Day 1 / Night 1 have none).
--   pair     weighted draw among Groups.Pairs of the shift; a pair with a type locked this shift weighs 0 (same unlock
--            rule as NpcService/Look.PickType).
--   look     the partner never has the leader's species AND outfit; at night never the leader's species (ANM-004
--            copies): another species when the type has one, else (day only) another civil outfit.
--   spot     walking: FollowGap behind the leader (Couple: SideGap to its right); standing: QueueGap to its right.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Pair = Content.GroupPair
export type Look = { Species: string, Outfit: string }

const Group = {}

-- Chance that one spawn attempt brings a pair this shift.
function Group.Chance(day: number, night: number, isNight: boolean): number
	const groups = Content.Flow.Groups
	if isNight then
		return if night >= groups.FromNight then groups.ChanceNight else 0
	end
	return if day >= groups.FromDay then groups.ChanceDay else 0
end

-- The customer type comes on this shift (Look.PickType rule, weight apart).
function Group.Unlocked(key: string, day: number, night: number, isNight: boolean): boolean
	const row = Content.CustomerTypes.ByKey[key]
	if row == nil or row.Role ~= "Customer" then
		return false
	end
	if isNight then
		return row.Shift ~= "Day" and row.UnlockNight >= 1 and night >= row.UnlockNight
	end
	return row.Shift ~= "Night" and row.UnlockDay >= 1 and day >= row.UnlockDay
end

-- Pairs of this shift with their weight now (0 = a type is locked).
function Group.Candidates(day: number, night: number, isNight: boolean): { Pair }
	const shift = if isNight then "Night" else "Day"
	const out: { Pair } = {}
	for _, pair in Content.Flow.Groups.Pairs do
		if
			pair.Shift == shift
			and pair.Weight > 0
			and Group.Unlocked(pair.Leader, day, night, isNight)
			and Group.Unlocked(pair.Partner, day, night, isNight)
		then
			table.insert(out, pair)
		end
	end
	return out
end

-- Weighted pair draw. nil when no pair is possible this shift.
function Group.Pick(day: number, night: number, isNight: boolean, rng: Random): Pair?
	const list = Group.Candidates(day, night, isNight)
	local total = 0
	for _, pair in list do
		total += pair.Weight
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, pair in list do
		roll -= pair.Weight
		if roll < 0 then
			return pair
		end
	end
	return list[#list]
end

-- One attempt: a pair (chance then weighted draw) or nil.
function Group.Roll(day: number, night: number, isNight: boolean, rng: Random): Pair?
	const chance = Group.Chance(day, night, isNight)
	if chance <= 0 or rng:NextNumber() >= chance then
		return nil
	end
	return Group.Pick(day, night, isNight, rng)
end

local function validSpecies(key: string): boolean
	const row = Content.Species.ByKey[key]
	return row ~= nil and row.Customer and row.ReservedFor == nil
end

local function validOutfit(key: string): boolean
	const row = Content.Outfits.ByKey[key]
	return row ~= nil and row.Use == "Civil" and table.find(Content.Looks.NpcNeverUses.Outfits, key) == nil
end

-- Partner look for `partnerType` next to a leader wearing `species` / `outfit`. nil = no valid look (night with no
-- other species): the caller spawns the leader alone.
function Group.PartnerLook(partnerType: string, species: string, outfit: string, isNight: boolean, rng: Random): Look?
	const row = Content.CustomerTypes.ByKey[partnerType]
	if row == nil then
		return nil
	end
	const others: { string } = {}
	local same = false
	for _, key in row.Species do
		if not validSpecies(key) then
			continue
		end
		if key == species then
			same = true
		else
			table.insert(others, key)
		end
	end
	const outfits: { string } = {}
	for _, key in row.Outfits do
		if validOutfit(key) then
			table.insert(outfits, key)
		end
	end
	if #outfits == 0 then
		return nil
	end
	if #others > 0 then
		return { Species = others[rng:NextInteger(1, #others)], Outfit = outfits[rng:NextInteger(1, #outfits)] }
	end
	if isNight or not same then
		return nil
	end
	-- day, same species only: another outfit (invariant 3)
	const different: { string } = {}
	for _, key in outfits do
		if key ~= outfit then
			table.insert(different, key)
		end
	end
	if #different == 0 then
		return nil
	end
	return { Species = species, Outfit = different[rng:NextInteger(1, #different)] }
end

-- Where the partner should stand, from the leader's HumanoidRootPart frame.
function Group.Spot(leader: CFrame, moving: boolean, couple: boolean): Vector3
	const groups = Content.Flow.Groups
	local offset: Vector3
	if not moving then
		offset = Vector3.new(groups.QueueGap, 0, 0)
	elseif couple then
		offset = Vector3.new(groups.SideGap, 0, 0)
	else
		offset = Vector3.new(0, 0, groups.FollowGap) -- +Z = behind (the rig faces -Z)
	end
	return leader * offset
end

return table.freeze(Group)
