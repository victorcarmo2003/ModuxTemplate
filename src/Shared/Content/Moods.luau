--!strict
-- Customer moods (content-data.md §3.16; DEC-162, DEC-187). PROVISIONAL (Q-164): wave 1 is visual only and does
-- not touch DEC-072 pay. Keys are wire enum values (Customers.Mood), PascalCase by rule §1.3.
-- The full dynamic mood (DEC-187) adds rows and MoodRules fields here; Net does not change.
local Table = require(script.Parent.Table)

export type Mood = {
	Key: string,
	Expression: string, -- one of Looks.Expressions
}

export type MoodRules = {
	AnnoyedAt: number, -- fraction of patience left
	AffectsPay: boolean,
}

const base = Table.new({
	{ Key = "Neutral", Expression = "Normal" }, -- arrival
	{ Key = "Happy", Expression = "Happy" }, -- Complete/Perfect sale
	{ Key = "Annoyed", Expression = "Skeptical" }, -- patience left <= AnnoyedAt
	{ Key = "Complaining", Expression = "Stressed" }, -- gave up, Wrong, Refuse
} :: { Mood })

const rules: MoodRules = {
	AnnoyedAt = 0.33,
	AffectsPay = false,
}

return Table.with(base, {
	Rules = Table.record(rules),
})
