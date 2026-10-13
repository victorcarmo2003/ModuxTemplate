--!strict
-- Zones: screen rectangles that a transient overlay occupies (the call subtitle of Walt, the HUD banner), published so the
-- PrepShell layout can keep its own transient blocks (hint, toast) off them (user request 2026-10-12: "Hint e Toast nunca sobre
-- eles"). Rectangles are in screen px of the viewport (AbsolutePosition space); the owner of a zone removes it when it hides.
-- Plain shared state like Cinematic. Outside a play session (UI Labs stories) the list stays empty.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Zone = { X: number, Y: number, W: number, H: number }

const zones = Vide.source({} :: { [string]: Zone })

return table.freeze({
	-- Reactive read: every zone by owner name.
	All = function(): { [string]: Zone }
		return zones()
	end,
	Set = function(name: string, zone: Zone?)
		const current = Vide.untrack(zones)
		const existing = current[name]
		if zone == nil and existing == nil then
			return
		end
		if zone ~= nil and existing ~= nil and existing.X == zone.X and existing.Y == zone.Y and existing.W == zone.W and existing.H == zone.H then
			return
		end
		const nextZones: { [string]: Zone } = table.clone(current)
		nextZones[name] = zone
		zones(nextZones)
	end,
})
