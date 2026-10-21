--!strict
-- HudHold: "hide the game HUD for a moment" without touching the Hud ScreenGui (owner 2026-10-21: after the blackout the
-- clock and the order card never came back - a horror scene wrote Hud.Enabled = false over HudController's reactive
-- binding and nothing wrote it back when the scene ended without its own close). Holders take a key and give it back;
-- HudController's Enabled = not Cinematic.Active() and not HudHold.Held(). A key held twice is still one hold.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

const held = Vide.source(false)
const keys: { [string]: boolean } = {}

local function refresh()
	const any = next(keys) ~= nil
	if Vide.untrack(held) ~= any then
		held(any)
	end
end

return table.freeze({
	-- Reactive read: true while anyone holds the HUD hidden
	Held = function(): boolean
		return held()
	end,
	Hold = function(key: string)
		keys[key] = true
		refresh()
	end,
	Release = function(key: string)
		keys[key] = nil
		refresh()
	end,
})
