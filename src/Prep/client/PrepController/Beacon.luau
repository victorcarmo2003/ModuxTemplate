--!strict
-- Beacon: the pulsing marker above the Work prompts of the trailer (P-3 of the polish of 2026-10-12). A player who has not entered the
-- prep mode yet is told where to start: a small Mustard diamond bobs and turns over each Prompt_Work, with a Cream ring that grows and
-- fades under it. It shows only while it can be used (the shop is selling, the player is not in the mode, the prompt is enabled and
-- the camera is within Beacon range), and not with reduced motion beyond a still diamond. Parts only, local to this client, two at most;
-- nothing is networked. No Modux, no Vide.
local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")
local HintMark = require(StarterPlayer.StarterPlayerScripts.client.Interface.HintMark)

export type Beacon = {
	-- Per frame. `active` = it may show (selling, not in the mode, alive); the rest is decided here.
	Step: (self: Beacon, dt: number, active: boolean) -> (),
	Destroy: (self: Beacon) -> (),
}

type Mark = { Anchor: Attachment, Arrow: HintMark.Mark, Ring: HintMark.Mark, Shown: boolean }

const BeaconModule = {}

const ACTION = "prep_work" -- Content.Actions key of the Work prompt
const RANGE = 45 -- studs from the camera
const LIFT = 0.9 -- studs over the prompt (where the arrow is)
const SCAN_EVERY = 2 -- s: the list of Work prompts is rebuilt (they come and go with streaming)
const RING_SIDE = 1.1 -- studs
const ARROW_SIDE = 0.7

function BeaconModule.new(): Beacon
	-- the markers are HintMarks (studs, on the prompt, always on top): an arrow over each Work prompt and a ring at its foot
	const marks: { Mark } = {}
	local scanAt = 0
	local clock = 0

	local function drop(mark: Mark)
		mark.Arrow:Destroy()
		mark.Ring:Destroy()
	end

	local function scan()
		for index = #marks, 1, -1 do
			const mark = marks[index]
			if mark.Anchor.Parent == nil then
				drop(mark)
				table.remove(marks, index)
			end
		end
		for _, instance in CollectionService:GetTagged("Interactable") do
			if instance:IsA("Attachment") and instance:GetAttribute("PromptAction") == ACTION and instance:IsDescendantOf(workspace) then
				local known = false
				for _, mark in marks do
					if mark.Anchor == instance then
						known = true
						break
					end
				end
				if not known and #marks < 4 then
					table.insert(marks, { Anchor = instance, Arrow = HintMark.new(), Ring = HintMark.new(), Shown = false })
				end
			end
		end
	end

	const self = {} :: any

	function self.Step(_: any, dt: number, active: boolean)
		clock += dt
		if clock >= scanAt then
			scanAt = clock + SCAN_EVERY
			scan()
		end
		const camera = workspace.CurrentCamera
		for _, mark in marks do
			local show = active and camera ~= nil and mark.Anchor.Parent ~= nil and mark.Anchor:GetAttribute("PromptEnabled") ~= false
			local origin = Vector3.zero
			if show and camera ~= nil then
				origin = mark.Anchor.WorldPosition
				show = (origin - camera.CFrame.Position).Magnitude <= RANGE
			end
			if not show then
				if mark.Shown then
					mark.Shown = false
					mark.Arrow:Hide()
					mark.Ring:Hide()
				end
				continue
			end
			mark.Shown = true
			mark.Ring:Show("Ring", origin + Vector3.new(0, 0.05, 0), RING_SIDE)
			mark.Arrow:Show("Arrow", origin + Vector3.new(0, LIFT, 0), ARROW_SIDE)
		end
	end

	function self.Destroy(_: any)
		for _, mark in marks do
			drop(mark)
		end
		table.clear(marks)
	end

	return self :: Beacon
end

return BeaconModule
