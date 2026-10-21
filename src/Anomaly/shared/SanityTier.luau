--!strict
-- Sanity tier of a value (DEC-352, Provisional; Content.Sanity.Tiers). The server (AnomalyService pressure: personal
-- scares, extra anomalies) and the client (VitalController screen and sound, HallucinationController roll) read the same
-- ladder from here, so both sides always agree on the step.
--   index(value, max)   1 = the top row (Calm) .. #Tiers; max 0 (day, no sanity) is always 1
--   of(value, max)      the row itself
--   ceiling(index)      From of the tier above (math.huge for the first): rows this tier unlocks have MaxSanity <= it
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

const TIERS = Content.Sanity.Tiers

export type Tier = typeof(TIERS[1])

const SanityTier = {}

function SanityTier.index(value: number, max: number): number
	if max <= 0 then
		return 1
	end
	for index, row in TIERS do
		if value >= row.From then
			return index
		end
	end
	return #TIERS
end

function SanityTier.of(value: number, max: number): Tier
	return TIERS[SanityTier.index(value, max)]
end

function SanityTier.ceiling(index: number): number
	if index <= 1 then
		return math.huge
	end
	return TIERS[index - 1].From
end

return table.freeze(SanityTier)
