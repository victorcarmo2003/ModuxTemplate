--!strict
-- Cutscene commands (TASK-120; architecture.md §19.16). Go through the CutsceneService API, so the Cutscene set,
-- the freeze, the traffic hold and the vote behave as in play.
--   cutscene                 scene, elapsed time, votes / needed, participants
--   cutscene play <key>      plays a chain now with the connected members (outside its phase: no probe waits on it)
--   cutscene vote            the caller votes Skip (same checks as the SkipVote packet)
--   cutscene skip            ends the current segment as if the vote passed (finale -> credits)
--   cutscene stop            ends the whole chain
local Api = require(script.Parent.Parent.Api)

const USAGE = "cutscene [play <key>|vote|skip|stop]"

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

const Cutscene: Api.Module = function(ctx: Api.Context): { Api.Command }
	const cutscenes = ctx.Get("CutsceneService") :: Cutscenes

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
				elseif sub == "play" then
					const key = args[2]
					if key == nil then
						error(`usage: {USAGE}`, 0)
					end
					if not cutscenes:Play(key, nil) then
						error(`could not play {key} (unknown key or nobody connected)`, 0)
					end
					return status()
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
