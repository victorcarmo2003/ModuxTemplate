--!strict
-- Cutscene commands (TASK-120; architecture.md §19.16). Go through the CutsceneService API, so the Cutscene set,
-- the freeze, the traffic hold and the vote behave as in play.
--   cutscene                 scene, elapsed time, votes / needed, participants
--   cutscene list           every scene key with its length, chain (Next) and the one the Finale phase plays
--   cutscene play <key>      plays a chain now with the connected members (outside its phase: no probe waits on it);
--                            the head of the Finale chain (Rules.Finale) goes through `cutscene finale` instead
--   cutscene finale          enters the Finale phase now (RoundService:DevFinale): the game pauses (no customer, no
--                            anomaly, no boss call), the phase plays Rules.Finale, and the run ends as after Night 10
--   cutscene vote            the caller votes Skip (same checks as the SkipVote packet)
--   cutscene skip            ends the current segment as if the vote passed (finale -> credits)
--   cutscene stop            ends the whole chain
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "cutscene [list|play <key>|finale|vote|skip|stop]"

type Cutscenes = {
	Scene: string,
	StartedAt: number,
	Participants: { number },
	IsPlaying: (self: any) -> boolean,
	VoteCount: (self: any) -> number,
	Needed: (self: any) -> number,
	Play: (self: any, key: string, owner: string?) -> boolean,
	Vote: (self: any, player: Player) -> boolean,
	EndSegment: (self: any) -> (),
	Finish: (self: any) -> (),
}

type Round = {
	DevFinale: (self: any) -> (),
}

const Cutscene: Api.Module = function(ctx: Api.Context): { Api.Command }
	const cutscenes = ctx.Get("CutsceneService") :: Cutscenes
	const round = ctx.Get("RoundService") :: Round

	local function status(): string
		if not cutscenes:IsPlaying() then
			return "no cutscene"
		end
		const elapsed = workspace:GetServerTimeNow() - cutscenes.StartedAt
		return string.format(
			"%s t=%.1fs votes=%d/%d participants=%s",
			cutscenes.Scene,
			elapsed,
			cutscenes:VoteCount(),
			cutscenes:Needed(),
			table.concat(cutscenes.Participants, ",")
		)
	end

	return {
		{
			Name = "cutscene",
			Usage = USAGE,
			Help = "play a cutscene chain, vote skip as the caller, skip the segment, stop; no args shows the state",
			Run = function(args: { string }, caller: Player?): string?
				const sub = args[1]
				if sub == nil then
					return status()
				elseif sub == "list" then
					const lines: { string } = {}
					for _, scene in Content.Cutscenes.List do
						if scene.Key ~= "none" then
							table.insert(
								lines,
								string.format(
									"%s (%.0f s, cap %.0f)%s%s",
									scene.Key,
									scene.Duration,
									scene.Cap,
									if scene.Next ~= nil then ` -> {scene.Next}` else "",
									if scene.Key == Content.Cutscenes.Rules.Finale then "  [Finale phase]" else ""
								)
							)
						end
					end
					return table.concat(lines, "\n")
				elseif sub == "play" then
					const key = args[2]
					if key == nil then
						error(`usage: {USAGE}`, 0)
					end
					-- the Finale chain plays inside its phase, so the night stops under it
					if key == Content.Cutscenes.Rules.Finale then
						round:DevFinale()
						return "Finale phase: " .. status()
					end
					if not cutscenes:Play(key, nil) then
						error(`could not play {key} (unknown key or nobody connected)`, 0)
					end
					return status()
				elseif sub == "finale" then
					round:DevFinale()
					return "Finale phase: " .. status()
				elseif sub == "vote" then
					if caller == nil then
						error("needs a caller (run from the chat)", 0)
					end
					if not cutscenes:Vote(caller) then
						error("vote refused (no skippable scene, not a participant, or already voted)", 0)
					end
					return status()
				elseif sub == "skip" then
					if not cutscenes:IsPlaying() then
						error("no cutscene", 0)
					end
					cutscenes:EndSegment()
					return status()
				elseif sub == "stop" then
					cutscenes:Finish()
					return status()
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Cutscene
