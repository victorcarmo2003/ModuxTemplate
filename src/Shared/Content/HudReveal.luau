--!strict
-- HudReveal: progressive presentation of the run HUD (owner request 2026-10-12, Provisional; docs/tasks/playtest-2026-10-12.md).
-- A first run starts with ONLY the essentials on screen and the rest is released as the player meets it. Each row is one
-- HUD element and WHEN it appears; the client (HudController) decides, from the tutorial step and the shift, and latches
-- it for the session: once an element appeared it stays. The server does not know about it.
-- Triggers:
--   Start        as soon as the day shift starts (after the intro cinematic)
--   Step         the first time the tutorial reaches the step `Step` (or any later step of Tutorial/Steps.luau)
--   TutorialEnd  when the tutorial ends: done, skipped (Q) or over. A player who skips sees everything at once
--   Night        the first time night `Night` (or a later one) is on; `Pulse` = a short ring pulse introduces it
-- Everything is open from the start (no animation) when the run is not a first run (past Day 1, tutorial already done)
-- and also while a night shift is on. The reveal of an element is a 0.25 s scale (Theme.Motion.Reveal, Motion.Reveal;
-- instant with the player's "reduced motion" setting). Dev: `/dev hud reveal all|reset`.
-- Not here (they bring their own context, nothing to reveal): night banner, 6:00 AM banner, 10 s window, spectate card,
-- end-of-shift summary, end of run screen, the Roblox hotbar (CharacterController). The HUD has no "customers served"
-- counter yet: when it does, it gets a row here (Trigger Step "serve").
-- Keys are what HudController asks for (Validate requires every one of REQUIRED below).
local Table = require(script.Parent.Table)

export type Trigger = "Start" | "Step" | "TutorialEnd" | "Night"

export type Element = {
	Key: string,
	-- What the element is, for people reading the table
	Name: string,
	Trigger: Trigger,
	-- Trigger Step: key of Tutorial/Steps.luau ("" for the other triggers)
	Step: string,
	-- Trigger Night: night number, 1-based (0 for the other triggers)
	Night: number,
	-- Introduces the element with a short ring pulse the first time it appears (Night only)
	Pulse: boolean,
}

return Table.new({
	-- clock "8:00 AM": top centre, right at the start
	{ Key = "clock", Name = "Clock", Trigger = "Start", Step = "", Night = 0, Pulse = false },
	-- order card (top left): the first time a customer is taken care of
	{ Key = "order_card", Name = "Order card", Trigger = "Step", Step = "order", Night = 0, Pulse = false },
	-- toasts (bottom centre): from the first customer; before that nothing is worth a notice
	{ Key = "toasts", Name = "Toast stack", Trigger = "Step", Step = "order", Night = 0, Pulse = false },
	-- money pill: the first sale (step "money", with its spotlight)
	{ Key = "money", Name = "Money pill", Trigger = "Step", Step = "money", Night = 0, Pulse = false },
	-- "Day N" / "Night N" label: when the tutorial is over
	{ Key = "shift", Name = "Day / Night label", Trigger = "TutorialEnd", Step = "", Night = 0, Pulse = false },
	-- sanity meter: night 1 falls (it only shows at night anyway), with a presentation pulse
	{ Key = "sanity", Name = "Sanity meter", Trigger = "Night", Step = "", Night = 1, Pulse = true },
} :: { Element })
