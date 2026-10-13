--!strict
-- Objective: the tutorial step that the focused prep mode shows in ITS card (user request 2026-10-12: during the prep the
-- tutorial banner and the prep progress card were two cards fighting for the top of the screen; now there is ONE).
-- Plain shared state, like Cinematic: TutorialController writes `Card` (nil / false = no step on screen) and `OnSkip`;
-- PrepController writes `Hosted` (true while the PrepShell is on screen with its own progress card and shows the step);
-- TutorialPanel reads `Hosted` to hide itself. Outside a play session (UI Labs stories) everything stays at its default.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Card = {
	Step: number,
	Total: number,
	Text: string,
	-- the line under the instruction ("" = none)
	Hint: string,
	-- "STEP 2 OF 7"
	Label: string,
	Done: boolean,
	Urgent: boolean,
	-- "Skip (Q)" ("" = no Skip)
	SkipText: string,
}

const card = Vide.source(false :: Card | false)
const hosted = Vide.source(false)
local onSkip: (() -> ())? = nil

return table.freeze({
	-- Reactive read: the step to show, or false.
	Card = function(): Card | false
		return card()
	end,
	-- Only TutorialController writes.
	SetCard = function(value: Card | false)
		card(value)
	end,
	-- Reactive read: the prep shell shows the step, the tutorial banner stays hidden.
	Hosted = function(): boolean
		return hosted()
	end,
	-- Only PrepController writes.
	SetHosted = function(value: boolean)
		if Vide.untrack(hosted) ~= value then
			hosted(value)
		end
	end,
	SetSkip = function(callback: (() -> ())?)
		onSkip = callback
	end,
	Skip = function()
		if onSkip ~= nil then
			onSkip()
		end
	end,
})
