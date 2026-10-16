--!strict
--[[
	OutsideController (owner request 2026-10-16, Provisional): at night, a player who stays out of the trailer for a
	long time starts seeing "get inside" whispered on screen, the same creepy words as the family B "hide" sign
	(Effects/Kit/Whispers). Local only, presentation only: nothing happens to the player because of it.

	  - Counts only in the Night phase, with a character, outside the trailer (VehicleController:IsInside, LZ-1).
	  - After OUTSIDE_AFTER s outside: a burst of BURST s, then again every REPEAT s while he stays out.
	  - Back inside = the count starts over.
	  - Never during a family B occurrence (hide out back is the right answer then): the count pauses.
]]
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Whispers = require(script.Parent.AnomalyController.Effects.Kit.Whispers)

const OUTSIDE_AFTER = 25 -- s outside before the first burst
const BURST = 4 -- s of words
const REPEAT = 14 -- s between two bursts while still outside
const TICK = 0.5 -- s between two checks
const NIGHT_PHASE = "Night"

const WORDS = {
	"get inside",
	"get inside",
	"get inside...",
	"GET INSIDE",
	"inside. now.",
	"go back",
	"back to the trailer",
	"it's not safe",
	"you're too far",
	"they see you",
	"come back",
}

const OutsideController = Modux.Controller("OutsideController", {
	Require = { "RoundController", "VehicleController", "AnomalyController" },
	Priority = 40,
})

function OutsideController:Setup()
	-- s spent outside the trailer at night (paused during a family B occurrence)
	self.Outside = 0 :: number
	-- os.clock of the next burst allowed
	self.NextBurst = 0 :: number
end

function OutsideController:HideLive(): boolean
	for _, occ in self.Dependencies.AnomalyController:Occurrences() do
		if occ.Row.Family == "B" then
			return true
		end
	end
	return false
end

function OutsideController:Check(dt: number)
	const round = self.Dependencies.RoundController
	const character = Players.LocalPlayer.Character
	if Vide.untrack(round.Phase) ~= NIGHT_PHASE or character == nil or self.Dependencies.VehicleController:IsInside() then
		self.Outside = 0
		return
	end
	if self:HideLive() then
		return -- hiding out back is right: no nag, the count waits
	end
	self.Outside += dt
	const now = os.clock()
	if self.Outside >= OUTSIDE_AFTER and now >= self.NextBurst then
		self.NextBurst = now + BURST + REPEAT
		task.spawn(Whispers.Play, BURST, WORDS, 0.7)
	end
end

OutsideController:OnStart(function(self)
	self:Setup()
	task.spawn(function()
		while true do
			task.wait(TICK)
			self:Check(TICK)
		end
	end)
end)

return OutsideController
