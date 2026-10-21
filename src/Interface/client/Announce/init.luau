--!strict
-- Announce: the big title of the blackout (HorrorCaption, TASK-444) reused for the big events of a run (TASK-595, owner
-- Play 2026-10-19, Provisional): the shift change (a new day / a new night / 6:00 AM) and the shop opening of the
-- tutorial. Same look as the scene caption (dark band, wide spaced title, Mustard rule, one short line), its own
-- ScreenGui so it never fights the anomaly scene's caption.
-- Plain state, not a component (like Interface/Cinematic): any client controller calls `Show`; the newest call wins and
-- each one hides itself after its hold. Off while a cinematic owns the screen (Interface/Cinematic): a call made then
-- is dropped, not queued. Texts are the caller's (ui-text.md §12.2).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Cinematic)
local HorrorCaption = require(script.Parent.Components.HorrorCaption)
local UiScale = require(script.Parent.Components.UiScale)

const HOLD = 3.5 -- s on screen by default (the HudBanner time it replaces)

const shown = Vide.source(false)
const title = Vide.source("")
const line = Vide.source("")
local token = 0
local mounted = false

local function mount()
	if mounted then
		return
	end
	mounted = true
	task.spawn(function()
		const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		const _, gui = Vide.root(function()
			return Vide.create("ScreenGui")({
				Name = "Announce",
				ResetOnSpawn = false,
				IgnoreGuiInset = true,
				ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
				ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
				DisplayOrder = 3, -- as the scene caption: over the HUD, under full-screen fades and the jumpscare
				HorrorCaption({
					Shown = function()
						return shown() and not Cinematic.Active()
					end,
					Title = title,
					Line = line,
					Scale = UiScale.Current,
					Name = "AnnounceCaption",
				}),
			})
		end)
		gui.Parent = playerGui
	end)
end

-- Big title + one short line for `hold` s (HOLD by default); replaces whatever is showing.
local function show(text: string, under: string, hold: number?)
	if Vide.untrack(Cinematic.Active) then
		return
	end
	mount()
	token += 1
	const mine = token
	Vide.batch(function()
		title(text)
		line(under)
		shown(true)
	end)
	task.delay(hold or HOLD, function()
		if token == mine then
			shown(false)
		end
	end)
end

local function hide()
	token += 1
	shown(false)
end

return table.freeze({
	Show = show,
	Hide = hide,
	-- reactive: true while an announcement is on screen (a caller may hold its own banner meanwhile)
	Shown = function(): boolean
		return shown()
	end,
})
