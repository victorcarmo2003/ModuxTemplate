--!strict
-- Admin console UI (ConchUI). The key is bound only when AdminSettings.IsAllowed says so; that is a UX gate, the
-- real one is server-side (AdminService grants the Conch role and re-checks on every command).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local AdminArguments = require(ReplicatedStorage.shared.Admin.AdminArguments)
local AdminSettings = require(ReplicatedStorage.shared.Admin.AdminSettings)
local ConchUI = require(ReplicatedStorage.Packages.ConchUI)
local conch = require(ReplicatedStorage.Packages.Conch)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const _ARGUMENTS = AdminArguments -- keeps the type registration alive

const AdminController = Modux.Controller("AdminController", { Priority = 50 })

AdminController:OnStart(function(_self)
	if not AdminSettings.IsAllowed(Players.LocalPlayer) then
		return
	end
	conch.initiate_default_lifecycle()
	ConchUI.bind_to(AdminSettings.ToggleKey)
end)

return AdminController
