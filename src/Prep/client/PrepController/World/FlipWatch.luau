--!strict
--[[
	FlipWatch: the call back to the grill. A sausage can only be flipped with the grill in view (the server rule does not
	change), but the player walks on to the board while it cooks. While the mode runs and the front tab is NOT the grill, this
	watches the Feed (the shared picture of the grill, alive on every tab, with or without the Grill stage mounted) and, when the
	flip window of ANY sausage is open, publishes `Alert` for the shell: the Grill dot pulses with a mini bar and a "Flip!" chip
	appears near it. A tap on either one goes back to the grill (PrepController:SetTab). The alert goes when the window closes
	(Feed state leaves "Window"), when the sausage is flipped, or when the grill is in front again. Several sausages: the most
	urgent one (the furthest into its window) is shown.

	Reads only: it sends nothing and decides nothing (the window and the grade are the server's). Driven by
	PrepController:Update (`Step`), cleared by `Reset` when the mode ends. Sources only, no Vide effect lives here.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Feed = require(script.Parent.Parent.Feed)

const source = Vide.source
const untrack = Vide.untrack

const prep = Content.Prep
const TAB = "Grill"
const SETTLE = 0.25 -- s a window must stay open before the call shows (a flip just sent has not come back yet)
const STEP = 0.04 -- the bar moves in steps of 4 % of the window

export type Alert = {
	Tab: string,
	Slot: number,
	-- 0..1 through the window of the sausage (the mini bar)
	Share: number,
	-- grows with every new call (a sound and an entrance per call)
	Id: number,
	Text: string,
}

const FlipWatch = {}

FlipWatch.Alert = source(false :: Alert | false)

local openedAt = 0
local lastSlot = 0
local callId = 0

-- The mode is over (or the shell is gone): nothing to call about.
function FlipWatch.Reset()
	openedAt = 0
	lastSlot = 0
	if untrack(FlipWatch.Alert) ~= false then
		FlipWatch.Alert(false)
	end
end

-- One frame of the watch. `play` = the sound player of the mode (key, speed), nil = silent.
function FlipWatch.Step(controller: any, play: ((key: string, speed: number) -> ())?)
	const row = prep.Tabs.ByKey[TAB]
	if
		row == nil
		or not controller.InMode
		or controller.Leaving
		or untrack(controller.Shown :: () -> boolean) ~= true
		or untrack(controller.Tab :: () -> string) == TAB
	then
		FlipWatch.Reset()
		return
	end
	const window = prep.Rules.Grill
	local bestSlot, bestShare = 0, -1
	for index, slot in Feed.Slots do
		const value = untrack(slot)
		if value.Exists and value.State == "Window" then
			const share = math.clamp((value.Progress - window.From) / math.max(window.To - window.From, 0.01), 0, 1)
			if share > bestShare then
				bestSlot, bestShare = index, share
			end
		end
	end
	if bestSlot == 0 then
		FlipWatch.Reset()
		return
	end
	const now = os.clock()
	if openedAt == 0 then
		openedAt = now
	end
	if now - openedAt < SETTLE then
		return
	end
	const share = math.floor(bestShare / STEP + 0.5) * STEP
	const current = untrack(FlipWatch.Alert)
	if current ~= false and current.Slot == bestSlot and current.Share == share then
		return
	end
	if current == false or lastSlot ~= bestSlot then
		callId += 1
		lastSlot = bestSlot
		if play ~= nil then
			play("grill_ready", 1.3)
		end
	end
	FlipWatch.Alert({ Tab = TAB, Slot = bestSlot, Share = share, Id = callId, Text = prep.Texts.FlipAlert })
end

return FlipWatch
