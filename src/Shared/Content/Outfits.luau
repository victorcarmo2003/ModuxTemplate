--!strict
-- Outfits and Looks (content-data.md §3.10b; DEC-148, DEC-159..161, DEC-166, DEC-167, DEC-188).
-- Values of the character attribute Outfit are these keys (network.md §5.2). Texture ids live in CrewLooks.
local Table = require(script.Parent.Table)

export type Pack = "Day" | "Mid" | "Night"
export type Arms = "Uniform" | "Civil"
export type Use = "Crew" | "Civil" | "Reserved"

export type Outfit = {
	Key: string,
	Ref: string,
	Arms: Arms,
	Packs: { Pack },
	Use: Use, -- Crew: players only, never NPC (DEC-188); Civil: drawn per customer type; Reserved: ReservedFor
	ReservedFor: string?,
}

export type Looks = {
	Packs: { Pack }, -- values of the LookPack attribute
	PackFace: { [Pack]: string }, -- crew face per sanity band (DEC-166, DEC-167)
	Expressions: { string }, -- closed list; name = SurfaceAppearance in ReplicatedStorage.CrewExpressions
	NpcNeverUses: { Expressions: { string }, Outfits: { string } },
}

const ALL_PACKS: { Pack } = { "Day", "Mid", "Night" }

local function civil(letter: string): Outfit
	return { Key = `civil_{letter}`, Ref = "AST-054", Arms = "Civil", Packs = ALL_PACKS, Use = "Civil" }
end

const base = Table.new({
	{ Key = "crew", Ref = "AST-053", Arms = "Uniform", Packs = ALL_PACKS, Use = "Crew" },
	civil("a"),
	civil("b"),
	civil("c"),
	civil("d"),
	civil("e"),
	civil("f"),
	civil("g"),
	civil("h"),
} :: { Outfit })

const looks: Looks = {
	Packs = ALL_PACKS,
	PackFace = { Day = "Normal", Mid = "Exhausted", Night = "Normal_Night" },
	Expressions = {
		"Normal",
		"Happy",
		"Smile",
		"Sad",
		"Fainted",
		"Skeptical",
		"Exhausted",
		"Stressed",
		"Normal_Night",
	},
	NpcNeverUses = {
		Expressions = { "Fainted" }, -- Provisional (DEC-187)
		Outfits = { "crew" }, -- DEC-188
	},
}

return Table.with(base, {
	Looks = Table.record(looks),
})
