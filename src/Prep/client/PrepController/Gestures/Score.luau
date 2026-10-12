--!strict
-- Score: raw measure of a gesture -> 0..100, with the SAME Prep/shared/Grade the server uses for the verdict (docs/tech/prep-mode.md
-- §3: "a conta de nota vive em um lugar só"). The client shows the score as a pip / seal at once; the server turns the
-- wire score into a band again (and caps it by time). Assist (Content.Prep.Rules.Assist, x1.3) widens the limits inside Grade.
-- Pure: `cfg` is Content.Prep or a table of the same shape (the table test feeds its own).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Grade = require(ReplicatedStorage.shared.Prep.Grade)

export type Config = Grade.Config & {
	read Tolerances: { read ByKey: { [string]: Grade.Tolerance } },
}

const Score = {}

-- Score of a measure against the tolerance row `key`. Sauces (gesture `trace`) give coverage and excess (a, b), every other
-- gesture one raw error (a).
function Score.Value(cfg: Config, key: string, a: number, b: number?, assist: boolean?): number
	const tolerance = cfg.Tolerances.ByKey[key]
	if tolerance == nil then
		return 0
	end
	const raw = if tolerance.Gesture == "trace" then Grade.CoverageError(tolerance, a, b or 0) else a
	return Grade.Score(cfg, tolerance, raw, assist)
end

-- Band of a score (Perfect / Good / Messy), the one the seals and pips show.
function Score.Band(cfg: Config, score: number): Grade.Band
	return Grade.Band(cfg, score)
end

return table.freeze(Score)
