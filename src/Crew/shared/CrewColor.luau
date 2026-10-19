--!strict
-- CrewColor: one colour per player of the server (owner request 2026-10-16, Provisional). The same colour paints his
-- name tag over the head, the outline on his character (Crew/client/NameTagController) and everything of his in the
-- co-op kitchen, so the crew tells who is who at a glance.
-- Colours = PALETTE below (never red; moved here from the focused prep's Presence.Palette, TASK-581). The server (CrewColorService) writes the palette
-- index on the Player attribute `CrewColor` (lowest free one on join); until it arrives the index comes from the join
-- order (sorted UserId), so a client never shows a colourless tag.
-- Pure: no Modux, Lync or Vide.
local Players = game:GetService("Players")

-- Teal, Mustard, Lilac, Mint, Apricot, Sky, Pink, Lime (Provisional)
const PALETTE: { Color3 } = {
	Color3.fromHex("#3FA7B5"),
	Color3.fromHex("#F6C12B"),
	Color3.fromHex("#A98BD6"),
	Color3.fromHex("#6FCF97"),
	Color3.fromHex("#F29B6B"),
	Color3.fromHex("#5BA8F0"),
	Color3.fromHex("#E58BC0"),
	Color3.fromHex("#B7D84B"),
}

const CrewColor = {}

CrewColor.Attribute = "CrewColor"
CrewColor.Count = #PALETTE

-- Palette index (1..Count) of `player`
function CrewColor.Index(player: Player): number
	const value = player:GetAttribute(CrewColor.Attribute)
	if type(value) == "number" and value >= 1 and value <= #PALETTE then
		return value
	end
	const ids: { number } = {}
	for _, other in Players:GetPlayers() do
		table.insert(ids, other.UserId)
	end
	table.sort(ids)
	const at = table.find(ids, player.UserId) or 1
	return (at - 1) % #PALETTE + 1
end

function CrewColor.Of(player: Player): Color3
	return PALETTE[CrewColor.Index(player)]
end

-- Colour of a UserId (a player who already left gets the palette entry of his id, stable)
function CrewColor.OfUser(userId: number): Color3
	const player = Players:GetPlayerByUserId(userId)
	if player ~= nil then
		return CrewColor.Of(player)
	end
	return PALETTE[math.abs(userId) % #PALETTE + 1]
end

return table.freeze(CrewColor)
