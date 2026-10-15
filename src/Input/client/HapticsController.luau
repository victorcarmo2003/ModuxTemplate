--!strict
-- HapticsController: the game events that vibrate without a module of their own calling Haptics (TASK-268; Provisional).
-- Reads only, never writes, the VitalController record of the OWN player:
--   Faint   LocalState goes Active -> Down
--   Hit     own KnockedUntil moves forward (the car hit validated by the server; TrafficController predicts the ragdoll)
-- Turning Vibration off in Settings stops a running vibration at once. The scares (Jumpscare kit, grabs) and the prep actions
-- call Haptics themselves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Prefs = require(StarterPlayer.StarterPlayerScripts.client.Settings.Prefs)
local Haptics = require(script.Parent.Haptics)

const HapticsController = Modux.Controller("HapticsController", { Require = { "VitalController" }, Priority = 500 })

HapticsController:OnStart(function(self)
	const vital = self.Dependencies.VitalController
	local lastState = Vide.untrack(vital.LocalState)
	local lastKnock: number? = nil
	Vide.root(function()
		Vide.effect(function()
			const state = vital.LocalState()
			if state == "Down" and lastState == "Active" then
				Vide.untrack(function()
					Haptics.Play("Faint")
					return nil
				end)
			end
			lastState = state
		end)
		Vide.effect(function()
			const member = vital.Members()[Players.LocalPlayer.UserId]
			const knocked = if member ~= nil then member.KnockedUntil else nil
			if
				knocked ~= nil
				and lastKnock ~= nil
				and knocked > lastKnock
				and knocked > Workspace:GetServerTimeNow()
			then
				Vide.untrack(function()
					Haptics.Play("Hit")
					return nil
				end)
			end
			lastKnock = knocked
		end)
		Vide.effect(function()
			if not Prefs.Vibration() then
				Haptics.Stop()
			end
		end)
		return nil
	end)
end)

return HapticsController
