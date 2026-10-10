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

-- TASK-079: sound (sound-list §5.4) and one-shot clip (Content.Animations) per Sale result.
-- Perfect/Complete -> SFX-045 + npc_happy (Cust_Happy; the "pay" beat is the coin on the drawer, EconomyController);
-- Incomplete -> SFX-046 + npc_complain; Wrong -> SFX-047 + npc_complain; Left -> SFX-048 + npc_refuse_leave;
-- Refused -> SFX-049 + npc_refuse_leave. Served = something was handed over (SFX-042 `serve`).
export type Feedback = {
	Sound: string, -- Content.Sounds key ("" = none)
	Clip: string, -- Content.Animations key ("" = none)
	Served: boolean,
}

const FEEDBACK: { [string]: Feedback } = {
	Perfect = { Sound = "cust_happy", Clip = "npc_happy", Served = true },
	Complete = { Sound = "cust_happy", Clip = "npc_happy", Served = true },
	Incomplete = { Sound = "cust_complain", Clip = "npc_complain", Served = true },
	Wrong = { Sound = "cust_wrong", Clip = "npc_complain", Served = true },
	Left = { Sound = "cust_leave", Clip = "npc_refuse_leave", Served = false },
	Refused = { Sound = "refuse", Clip = "npc_refuse_leave", Served = false },
}
const NO_FEEDBACK: Feedback = { Sound = "", Clip = "", Served = false }

const Reactions = {}

function Reactions.Feedback(result: string): Feedback
	return FEEDBACK[result] or NO_FEEDBACK
end

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
