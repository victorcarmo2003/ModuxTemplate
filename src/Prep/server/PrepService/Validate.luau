--!strict
-- PrepFinish validation by plausibility (docs/tech/prep-mode.md §3, DT-2; TASK-170). Pure: no Modux, Lync nor services; the
-- caller passes the server clock (`elapsed`), the sausage score stamped by the server and a read-only stock view.
-- The math (bands, plate band, time floors) is src/Prep/shared/Grade.luau; this file only checks the shape of the summary.
-- Refusals are Content.Prep.Reasons keys; nothing here mutates anything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)

export type Summary = {
	Cut: number,
	Place: number,
	Toppings: { { Key: string, Score: number } },
	Ms: number,
	-- the drawn sauce lines (cosmetic, never graded: the scores above are what counts); see PrepService:SauceOf
	Sauces: { { Key: string, Points: { number } } }?,
}

-- Read-only view of the kitchen stock (KitchenService:GetStock / IsBlocked)
export type Stock = {
	Amount: (key: string) -> number,
	IsBlocked: (key: string) -> boolean,
}

export type Verdict = {
	Keys: { string }, -- toppings in the order added
	Band: Grade.Band,
	Points: number, -- Grades.Points of the band
	Average: number,
	Capped: boolean, -- a Perfect lowered to Good by the time floor
	-- what Grade.Plate was fed without the sausage: PrepService feeds it again once the kitchen says the sausage score
	Stages: Grade.Stages,
}

const MAX_MS = 120000 -- PrepFinish.Ms wire range

const Validate = {}

local function isScore(value: any): boolean
	return type(value) == "number" and value == value and value == math.floor(value) and value >= 0 and value <= 100
end

-- (verdict, reason, value). verdict = nil means refused; value = ingredient index for NoStock, else 0.
function Validate.Summary(
	cfg: Grade.Config,
	summary: Summary,
	elapsed: number,
	sausage: number?,
	stock: Stock
): (Verdict?, string, number)
	if type(summary) ~= "table" or type(summary.Toppings) ~= "table" then
		return nil, "Invalid", 0
	end
	const list = summary.Toppings
	if #list > Content.OrderRules.MaxToppings then
		return nil, "Invalid", 0
	end
	if not isScore(summary.Cut) or not isScore(summary.Place) then
		return nil, "Invalid", 0
	end
	const ms = summary.Ms
	if type(ms) ~= "number" or ms ~= ms or ms < 0 or ms > MAX_MS then
		return nil, "Invalid", 0
	end

	const keys: { string } = {}
	const scores: { number } = {}
	const seen: { [string]: boolean } = {}
	for _, entry in list do
		if type(entry) ~= "table" then
			return nil, "Invalid", 0
		end
		const key = entry.Key
		if type(key) ~= "string" or not isScore(entry.Score) then
			return nil, "Invalid", 0
		end
		if seen[key] or table.find(Content.Ingredients.ToppingKeys, key) == nil or Content.Prep.Tolerances.ByKey[key] == nil then
			return nil, "Invalid", 0
		end
		seen[key] = true
		const index = Content.Ingredients.IndexOf[key] or 0
		-- a topping the kitchen has not opened yet (UnlockDay) or has run out of
		if stock.IsBlocked(key) or stock.Amount(key) < 1 then
			return nil, "NoStock", index
		end
		table.insert(keys, key)
		table.insert(scores, entry.Score)
	end

	-- server clock: floor MinPlate + PerTopping x K, ceiling PlateMax, client Ms <= server + MsSlack
	const ok, reason = Grade.Plausible(cfg, #keys, elapsed, ms)
	if not ok then
		return nil, reason or "Invalid", 0
	end

	const stages: Grade.Stages = { Cut = summary.Cut, Place = summary.Place, Toppings = scores, Sausage = sausage }
	const plate = Grade.Plate(cfg, stages, elapsed)
	return {
		Keys = keys,
		Band = plate.Band,
		Points = Grade.Points(cfg, plate.Band),
		Average = plate.Average,
		Capped = plate.Capped,
		Stages = stages,
	}, "None", 0
end

return table.freeze(Validate)
