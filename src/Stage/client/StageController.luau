--!strict
--[[
	StageController (user request 2026-10-11, Provisional): decides when a cinematic owns the screen and writes it to
	Interface/Cinematic, the one switch the HUD and the world tags read (SaleSign, ShelfTag, StockCounter, StockPlate,
	ProgressBar, DrawerValue, BenchCard, OrderBubble, ReactionBubble).

	Cinematic = in the Run place and any of:
	  * no Shift record yet (the first frames of a run, before the intro starts), for at most WAIT_LIMIT s;
	  * Shift.Phase is Intro or Finale (the phases that own a cutscene chain, Content.Shift);
	  * the Cutscene set plays a scene (CutsceneController.SceneKey ~= "none": intro, finale, credits).
	The lobby never has a cinematic.

	PROVISIONAL: reads CutsceneController.SceneKey (the Vide source it already fills from the Cutscene set), since the
	controller exposes no "cutscene active" signal of its own yet. When it does, swap `SceneActive` to it.
	Presentation only: nothing here changes what the server decides.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)

const NONE = "none"
const CINEMATIC_PHASES: { [string]: boolean } = { Intro = true, Finale = true }
-- s without a Shift record before the HUD shows anyway (a run that never writes the record must not stay blank)
const WAIT_LIMIT = 15

const StageController = Modux.Controller(
	"StageController",
	{ Require = { "CutsceneController", "RoundController", "PlaceController" }, Priority = 550 }
)

function StageController:Setup()
	self.Waited = Vide.source(false) :: Vide.Source<boolean>
	self.Unmount = nil :: (() -> ())?
end

-- Reactive: the Cutscene set plays a scene
function StageController:SceneActive(): boolean
	return self.Dependencies.CutsceneController.SceneKey() ~= NONE
end

-- Reactive: a cinematic owns the screen
function StageController:Active(): boolean
	if not self.Dependencies.PlaceController:Is("Run") then
		return false
	end
	const round = self.Dependencies.RoundController
	if not round.Ready() then
		return not self.Waited()
	end
	if CINEMATIC_PHASES[round.Phase()] then
		return true
	end
	return self:SceneActive()
end

StageController:OnInit(function(self)
	self:Setup()
end)

StageController:OnStart(function(self)
	-- every OnInit ran: the sources of RoundController and CutsceneController exist
	const unmount = Vide.root(function()
		Vide.effect(function()
			Cinematic.Set(self:Active())
		end)
	end)
	self.Unmount = unmount
	task.delay(WAIT_LIMIT, function()
		self.Waited(true)
	end)
end)

return StageController
