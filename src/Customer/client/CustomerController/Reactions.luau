--!strict
-- Sale result -> reaction bubble kind and line (FEAT-011 "balão feliz/neutro/reclamação"; style guide §7.3;
-- lines from story/ui-text.md §8, English in game). Pure: no Vide, no network.
-- Provisional (TASK-034): Refused = Neutral with no line (ui-text §8 has no line for it); Incomplete uses the line
-- without {item}, since the client does not know what was served. Owner of the texts: narrative-writer.
export type Result = "Perfect" | "Complete" | "Incomplete" | "Wrong" | "Left" | "Refused"
export type Kind = "Happy" | "Neutral" | "Complaint"

const KIND: { [string]: Kind } = {
	Perfect = "Happy",
	Complete = "Happy",
	Incomplete = "Complaint",
	Wrong = "Complaint",
	Left = "Complaint",
	Refused = "Neutral",
}

const LINES: { [string]: { string } } = {
	Perfect = { "Perfect, thanks!", "Yum!", "See you tomorrow!" },
	Complete = { "Perfect, thanks!", "Yum!", "See you tomorrow!" },
	Incomplete = { "Something's missing..." },
	Wrong = { "That's not what I asked for." },
	Left = { "Too slow... bye.", "I'll eat somewhere else." },
	Refused = {},
}

const Reactions = {}

-- Kind and line for a Sale result; unknown result = Neutral, no line.
function Reactions.For(result: string, rng: Random): (Kind, string)
	const kind = KIND[result] or "Neutral"
	const pool = LINES[result]
	if pool == nil or #pool == 0 then
		return kind, ""
	end
	return kind, pool[rng:NextInteger(1, #pool)]
end

return table.freeze(Reactions)
