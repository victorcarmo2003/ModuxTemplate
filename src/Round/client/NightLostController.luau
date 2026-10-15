--!strict
-- Lost night cover (TASK-338; owner request 2026-10-15, Provisional). While the Shift phase is NightLost (6 s, then the
-- server repeats the night or ends the run) the bodies lie still and the clock holds, which read as a frozen game.
-- This mounts NightLostScreen over everything but the settings / shop windows: Ink fade, "Everyone fainted…" (or
-- "The night is lost" when someone was still standing: a critical anomaly), "Restarting the night" while a chance is
-- left (Shift.Chances, never shown as a number, DEC-053) or "No chances left" when the run ends, and a bar + whole
-- seconds from PhaseStartedAt / PhaseDuration (server time). It stays (bar full) until the next phase arrives, so the
-- restore gap is covered too. Presentation only: the server decides the phase. Game servers only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local NightLostScreen = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.NightLostScreen)

const PHASE = "NightLost"
const DISPLAY_ORDER = 18 -- over the HUD (1) and the Revive Kit button (15), under the settings / shop windows (20)
const TICK_RATE = 10 -- Hz

const NightLostController = Modux.Controller("NightLostController", {
	Require = { "PlaceController", "RoundController", "VitalController" },
	Priority = 520,
})

function NightLostController:Setup()
	self.Elapsed = Vide.source(0) :: Vide.Source<number>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.Gui = nil :: ScreenGui?
end

function NightLostController:Shown(): boolean
	return self.Dependencies.RoundController.Phase() == PHASE
end

-- Nobody on their feet (every member Down / Spectator / Away): the wipe. Someone Active = a critical loss.
function NightLostController:Title(): string
	for _, state in self.Dependencies.VitalController.State() do
		if state == "Active" or state == "Reviving" then
			return "The night is lost"
		end
	end
	return "Everyone fainted…"
end

function NightLostController:Line(): string
	return if self.Dependencies.RoundController.Chances() > 0 then "Restarting the night" else "No chances left"
end

function NightLostController:Progress(): number
	const duration = self.Dependencies.RoundController.PhaseDuration()
	if duration <= 0 then
		return 1
	end
	return math.clamp(self.Elapsed() / duration, 0, 1)
end

function NightLostController:Seconds(): number
	const duration = self.Dependencies.RoundController.PhaseDuration()
	return math.max(math.ceil(duration - self.Elapsed()), 0)
end

function NightLostController:Tick()
	const round = self.Dependencies.RoundController
	if Vide.untrack(round.Phase) ~= PHASE then
		return
	end
	const elapsed = workspace:GetServerTimeNow() - Vide.untrack(round.PhaseStartedAt)
	-- tenths are enough for the bar; the whole seconds follow
	const stepped = math.floor(math.max(elapsed, 0) * TICK_RATE) / TICK_RATE
	if stepped ~= Vide.untrack(self.Elapsed) then
		self.Elapsed(stepped)
	end
end

function NightLostController:WatchViewport()
	local connection: RBXScriptConnection? = nil
	local function bind()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		const camera = workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self.Scale(Theme.ScaleOf(camera.ViewportSize))
			end)
			self.Scale(Theme.ScaleOf(camera.ViewportSize))
		end
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
	bind()
end

function NightLostController:Mount(playerGui: Instance)
	const _, gui = Vide.root(function()
		return Vide.create("ScreenGui")({
			Name = "NightLost",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = DISPLAY_ORDER,

			NightLostScreen({
				Shown = function()
					return self:Shown()
				end,
				Title = function()
					return self:Title()
				end,
				Line = function()
					return self:Line()
				end,
				Progress = function()
					return self:Progress()
				end,
				Seconds = function()
					return self:Seconds()
				end,
				Scale = self.Scale,
			}),
		})
	end)
	self.Gui = gui
	gui.Parent = playerGui
end

NightLostController:OnInit(function(self)
	self:Setup()
end)

NightLostController:OnStart(function(self)
	if self.Dependencies.PlaceController:Is("Lobby") then
		return
	end
	-- a fresh NightLost starts the bar at 0 (no leftover from the previous one)
	Vide.root(function()
		Vide.effect(function()
			self.Dependencies.RoundController.Phase()
			Vide.untrack(function()
				self.Elapsed(0)
				self:Tick()
				return nil
			end)
		end)
		return nil
	end)
	self:WatchViewport()
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

NightLostController:OnTick(function(self)
	self:Tick()
end, TICK_RATE)

return NightLostController
