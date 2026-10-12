--!strict
-- Tutorial / voice test commands (user request 2026-10-11, Provisional). Server side through TutorialService,
-- BossService, CutsceneService and RoundService; the client side (voice test, debug panel, step jump, status) goes to
-- the caller through TutorialService:DevSend (dev-only `DevClient` packet) and prints in the client Output.
--   tutorial                 server status (who has it pending, customer, buns, phone) + the client's status
--   tutorial reset           reopens the tutorial in this run (any day, memory only: the profile is not touched), intro
--                            skipped if it is on, tutorial call and customer start over, the client restarts its tutorial
--   tutorial step <key>      the client jumps to a step (Steps.luau keys; "auto" = back to the live flow)
--   intro skip               ends the intro cutscene and its phase now (straight to the day Prep: the tutorial)
--   voice <text>             the client says <text> with Walt's voice (the tutorial call's Speech) and prints its
--                            load status, reason, Master x Voice volume and fader
--   voice tutorial           the client loads and says every tutorial line in order, status per line
--   voice stop               stops the voice test
--   tutdebug                 toggles the client's tutorial debug panel (F8 does the same)
-- From the Command Bar (no caller) the client commands go to the first player.
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

type Tutorials = {
	DevSend: (self: any, player: Player, command: string, text: string?) -> (),
	DevReset: (self: any, player: Player) -> (),
	DevStatus: (self: any) -> string,
}

type Boss = {
	DevStatus: (self: any) -> string,
	DevResetTutorial: (self: any) -> (),
}

type Cutscenes = {
	IsPlaying: (self: any) -> boolean,
	IsWaiting: (self: any) -> boolean,
	Finish: (self: any) -> (),
}

type Round = {
	GetPhase: (self: any) -> string,
	DevSkipPhase: (self: any) -> (),
}

const TUTORIAL_USAGE = "tutorial [reset | step <key|auto>]"
const VOICE_USAGE = "voice <text> | voice tutorial | voice stop"

const Tutorial: Api.Module = function(ctx: Api.Context): { Api.Command }
	const tutorials = ctx.Get("TutorialService") :: Tutorials
	const boss = ctx.Get("BossService") :: Boss
	const cutscenes = ctx.Get("CutsceneService") :: Cutscenes
	const round = ctx.Get("RoundService") :: Round

	local function target(caller: Player?): Player
		const player = caller or Players:GetPlayers()[1]
		if player == nil then
			error("no player in the server", 0)
		end
		return player
	end

	-- Ends the intro chain and its phase (the probe would end it on the next tick; skipping now is the same path)
	local function skipIntro(): string
		local done = "no intro"
		if cutscenes:IsPlaying() or cutscenes:IsWaiting() then
			cutscenes:Finish()
			done = "cutscene finished"
		end
		if round:GetPhase() == "Intro" then
			round:DevSkipPhase()
			done ..= ", Intro phase skipped"
		end
		return `{done}; phase {round:GetPhase()}`
	end

	return {
		{
			Name = "tutorial",
			Usage = TUTORIAL_USAGE,
			Help = "first-hot-dog tutorial: status; reset (reopen in this run, restart without the intro); jump to a step",
			Run = function(args: { string }, caller: Player?): string?
				const sub = if args[1] then string.lower(args[1]) else nil
				if sub == nil then
					tutorials:DevSend(target(caller), "tutorial_status", "")
					return `{tutorials:DevStatus()} | {boss:DevStatus()} (client status in the client Output)`
				elseif sub == "reset" then
					const player = target(caller)
					-- tutorial state first: the Day 1 Prep reached by the intro skip then queues the tutorial call, not the
					-- regular day call
					boss:DevResetTutorial()
					tutorials:DevReset(player)
					const intro = skipIntro()
					return `{player.Name}: tutorial reopened in this run (nothing saved), restarts ({intro})`
				elseif sub == "step" then
					const key = args[2]
					if key == nil then
						error(`usage: {TUTORIAL_USAGE}`, 0)
					end
					tutorials:DevSend(target(caller), "tutorial_step", string.lower(key))
					return `step {key} sent to the client`
				end
				error(`usage: {TUTORIAL_USAGE}`, 0)
			end,
		},
		{
			Name = "intro",
			Usage = "intro skip",
			Help = "ends the intro cutscene and the Intro phase now (straight to the tutorial)",
			Run = function(args: { string }, _caller: Player?): string?
				if args[1] == nil or string.lower(args[1]) ~= "skip" then
					error("usage: intro skip", 0)
				end
				return skipIntro()
			end,
		},
		{
			Name = "voice",
			Usage = VOICE_USAGE,
			Help = "client says a line with Walt's voice and prints load status / volume; 'tutorial' = every tutorial line",
			Run = function(args: { string }, caller: Player?): string?
				if #args == 0 then
					error(`usage: {VOICE_USAGE}`, 0)
				end
				const first = string.lower(args[1])
				const player = target(caller)
				if #args == 1 and first == "tutorial" then
					tutorials:DevSend(player, "voice_tutorial", "")
					return "voice test of every tutorial line sent to the client"
				elseif #args == 1 and first == "stop" then
					tutorials:DevSend(player, "voice_stop", "")
					return "voice test stopped"
				end
				const text = table.concat(args, " ")
				tutorials:DevSend(player, "voice", text)
				return `voice test sent to the client: "{text}"`
			end,
		},
		{
			Name = "tutdebug",
			Usage = "tutdebug",
			Help = "toggles the client's tutorial debug panel (F8 in Studio does the same)",
			Run = function(_args: { string }, caller: Player?): string?
				tutorials:DevSend(target(caller), "tutdebug", "")
				return "debug panel toggled on the client"
			end,
		},
	}
end

return Tutorial
