--!strict
-- The dark Walt in the parking lot (DEC-371, TASK-638; easter egg, ties to the post-credits of DEC-374). The same dark Walt
-- of the final scene (WaltLoom) stands still at the map point Rules.Point every night from Rules.FromNight on, facing the
-- shop. A player who gets closer than Rules.Distance makes him fade (Rules.Fade s) for everyone until the next night, and
-- Walt reacts once per run (Rules.React, via ReactionService). Never an anomaly (DEC-177 note), outside the scheduler, no
-- sanity, no verb, no NPC slot; not there before the night call while those nights' call runs (tutorial of Night 1).
-- Server: WaltWatchService (TASK-646) writes Net `WaltWatch`. Client: WaltWatchController (TASK-647) shows the figure.
-- All numbers PROVISIONAL (DEC-371 suggestions).
local WaltReactions = require(script.Parent.WaltReactions)
local RunParams = require(script.Parent.RunParams)

export type Rules = {
	Point: string, -- MapPoint id of the spot in the parking lot (TASK-645, docs/levels/MAP-01-r4-restaurant.md)
	Distance: number, -- studs: an active player closer than this makes him fade (horizontal distance)
	Fade: number, -- s of the fade out on Present = false (and of the fade in on Present = true)
	FromNight: number, -- first night he stands there
	-- nights 1..WaitCallUntil: he shows up only once that night's call is over (Call back to Idle), never during the
	-- Night 1 call / tutorial
	WaitCallUntil: number,
	CallWait: number, -- s to wait for that call before showing up anyway (a call that never ends must not hide him)
	React: string, -- Content.WaltReactions key played when he fades (R6), once per run like every reaction
}

const rules: Rules = {
	Point = "WALT-PARK",
	Distance = 20,
	Fade = 2,
	FromNight = 1,
	WaitCallUntil = 1,
	CallWait = 60,
	React = "r06_park",
}

if WaltReactions.ByKey[rules.React] == nil then
	error(`[Content.WaltWatch] Rules.React {rules.React} is not a Content.WaltReactions key`)
end
if rules.FromNight < 1 or rules.FromNight > RunParams.Nights then
	error(`[Content.WaltWatch] Rules.FromNight {rules.FromNight} is not a night of the run (1..{RunParams.Nights})`)
end
if rules.Distance <= 0 or rules.Fade < 0 or rules.CallWait < 0 then
	error("[Content.WaltWatch] Distance must be > 0, Fade and CallWait >= 0")
end

return table.freeze({
	Rules = table.freeze(rules),
})
