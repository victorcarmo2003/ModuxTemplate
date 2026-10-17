--!strict
--[[
	SessionController (owner request 2026-10-17; DEC-063; architecture.md §5.4; TASK-360, Provisional)

	Lobby side of rejoining a run in progress. The server (SessionService) sends Reconnect { Mode = "Rejoin" } when
	this player dropped out of a run that is still live; this controller shows RejoinPopup at the top right (own
	ScreenGui over the lobby HUD, under the lobby windows' pickers):
	  - Rejoin: ReconnectReply { Accept = true }, the card turns "Joining..." until the teleport takes the player away
	    or the server answers Reconnect { Mode = "None", Reason } (Ended / Failed / StudioNoTeleport -> a lobby toast;
	    Failed brings the card back);
	  - Dismiss: ReconnectReply { Accept = false }; the card goes away and the server forgets the run pointer.
	Reconnect { Mode = "Resume", Left } (DEC-080, Q-291): nobody is in the run, it waits Left s for a member to come
	back and resume it from the start of its shift. Same card ("Resume Day 7 - 12:40 left", counting down) and the same
	reply; the card goes away by itself when the countdown ends.
	No card outside lobby roles. The server decides everything; this only shows it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Roles = require(ReplicatedStorage.shared.ServerRole.Roles)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local RejoinPopup = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.RejoinPopup)
local UiScale = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.UiScale)

const DISPLAY_ORDER = 7 -- over the lobby HUD (Lobby 6), under the gift picker (8)
const CLICK_SOUND = "ui_click"
const ANSWER_TIMEOUT = 45 -- s "Joining..." waits before the buttons come back (the server retries 2/5/10 s)
const TICK = 0.5 -- s between two updates of the Resume countdown

-- Reconnect.Reason -> lobby toast
const TOASTS: { [string]: { Text: string, Kind: "Info" | "Good" | "Alert" } } = {
	Ended = { Text = "That shift is over.", Kind = "Info" },
	Failed = { Text = "Couldn't get you back in. Try again!", Kind = "Alert" },
	StudioNoTeleport = { Text = "Studio can't teleport: test Rejoin on a live server", Kind = "Info" },
}

const SessionController = Modux.Controller("SessionController", {
	Require = { "PlaceController", "LobbyController", "AudioController" },
	Priority = 430,
})

function SessionController:Setup()
	self.Active = false :: boolean
	-- the offer on screen: 0 or 1 entry (a list, since an optional source is ambiguous to call)
	self.Offer = Vide.source({}) :: Vide.Source<{ RejoinPopup.Offer }>
	self.Busy = Vide.source(false) :: Vide.Source<boolean>
	-- bumps on every Rejoin press: a stale timeout never frees a newer one
	self.Token = 0 :: number
	self.Gui = nil :: ScreenGui?
	-- os.clock() of the Resume countdown, ticked every TICK s while the card is mounted
	self.Now = Vide.source(os.clock()) :: Vide.Source<number>
end

function SessionController:Click()
	pcall(function()
		self.Dependencies.AudioController:Play(CLICK_SOUND)
	end)
end

function SessionController:Toast(text: string, kind: "Info" | "Good" | "Alert")
	pcall(function()
		self.Dependencies.LobbyController:Toast(text, kind)
	end)
end

function SessionController:OnReconnect(
	data: { Mode: string, Day: number, IsNight: boolean, Reason: string, Left: number }
)
	self.Busy(false)
	if data.Mode == "Rejoin" or data.Mode == "Resume" then
		const resume = data.Mode == "Resume"
		self.Offer({
			{
				Day = data.Day,
				IsNight = data.IsNight,
				Resume = resume,
				EndsAt = if resume then os.clock() + data.Left else nil,
			},
		})
		return
	end
	self.Offer({})
	const toast = TOASTS[data.Reason]
	if toast then
		self:Toast(toast.Text, toast.Kind)
	end
end

function SessionController:Rejoin()
	if #Vide.untrack(self.Offer) == 0 or Vide.untrack(self.Busy) then
		return
	end
	self:Click()
	self.Busy(true)
	self.Token += 1
	const token = self.Token
	self.Libs.Net.ReconnectReply:fireServer({ Accept = true })
	task.delay(ANSWER_TIMEOUT, function()
		if self.Token == token and Vide.untrack(self.Busy) then
			self.Busy(false)
		end
	end)
end

function SessionController:Dismiss()
	if #Vide.untrack(self.Offer) == 0 or Vide.untrack(self.Busy) then
		return
	end
	self:Click()
	self.Offer({})
	self.Libs.Net.ReconnectReply:fireServer({ Accept = false })
end

-- Ticks the countdown; a Resume offer whose window closed goes away (not while a teleport is on its way)
function SessionController:Tick()
	const now = os.clock()
	self.Now(now)
	const offer = Vide.untrack(self.Offer)[1]
	if offer ~= nil and offer.Resume and offer.EndsAt ~= nil and now >= offer.EndsAt and not Vide.untrack(self.Busy) then
		self.Offer({})
		self:Toast(TOASTS.Ended.Text, TOASTS.Ended.Kind)
	end
end

function SessionController:Mount(playerGui: Instance)
	const unmount, gui = Vide.root(function()
		return Vide.create("ScreenGui")({
			Name = "Rejoin",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = DISPLAY_ORDER,
			RejoinPopup({
				Offer = function(): RejoinPopup.Offer?
					return self.Offer()[1]
				end,
				Busy = function()
					return self.Busy()
				end,
				OnRejoin = function()
					self:Rejoin()
				end,
				OnDismiss = function()
					self:Dismiss()
				end,
				Scale = UiScale.Current,
				Now = function()
					return self.Now()
				end,
			}),
		})
	end)
	gui.Parent = playerGui
	self.Gui = gui
	-- the card lives as long as the client; nothing unmounts it
	local _ = unmount
	task.spawn(function()
		while true do
			task.wait(TICK)
			self:Tick()
		end
	end)
end

SessionController:OnInit(function(self)
	self:Setup()
	-- listener in OnInit (before Lync.start); it only fills sources, the card exists only on lobby servers
	self.Libs.Net.Reconnect:onClient(function(data)
		if self.Active then
			self:OnReconnect(data :: any)
		end
	end)
end)

SessionController:OnStart(function(self)
	if not Roles.IsLobby(self.Dependencies.PlaceController:GetServerRole()) then
		return
	end
	self.Active = true
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return SessionController
