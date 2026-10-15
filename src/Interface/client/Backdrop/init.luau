--!strict
-- Backdrop (TASK-311, user request 2026-10-15, Provisional): the one count of "a window is open" behind every lobby and
-- in-game window (ClassSelect, GemShop, CodeRedeem, SquadPanel / SquadSetup / PlayChoice, SettingsPanel, ShopPanel).
-- Plain state, not a component: each window only calls `Hold(shown)` inside its Vide root; BackdropController
-- (src/Interface/client/BackdropController) reads `Held()` and draws the soft camera blur + the light Ink veil.
-- Two windows open = one backdrop; closing one keeps it while another still holds. Outside a play session (UI Labs
-- stories) nobody reads it, so stories are unaffected.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

const count = Vide.source(0)

local function add(delta: number)
	count(math.max(Vide.untrack(count) + delta, 0))
end

-- Inside a Vide scope: the backdrop shows while `shown()` is true; the scope's cleanup lets it go.
local function hold(shown: () -> boolean)
	local held = false
	local function set(on: boolean)
		if on ~= held then
			held = on
			add(if on then 1 else -1)
		end
	end
	Vide.effect(function()
		const on = shown()
		Vide.untrack(function()
			set(on)
			return nil
		end)
	end)
	Vide.cleanup(function()
		set(false)
	end)
end

local function held(): boolean
	return count() > 0
end

return table.freeze({
	-- Reactive read: true while at least one window holds the backdrop.
	Held = held,
	-- Called by each window inside its Vide root.
	Hold = hold,
})
