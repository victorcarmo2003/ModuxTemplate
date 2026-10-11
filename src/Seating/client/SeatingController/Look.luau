--!strict
-- SeatingController/Look: the local look of a Pad table by its state (FEAT-037; network.md §14.1; TASK-147).
--   Hidden  Locked (before Seating.UnlockDay): every part and decal fully transparent, no shadow
--   Ghost   not bought: authored transparency pushed to Seating.GhostTransparency (1 - (1 - a)(1 - g)), no shadow
--   Solid   bought: the authored values back
-- Local only: the server never writes Transparency (it writes CanCollide, which replicates), so the authored values
-- read the first time a table is seen are the real ones. Parts that are already invisible (Seat markers, anchors)
-- stay invisible in every mode. Pure: no Modux, no network.
export type Mode = "Solid" | "Ghost" | "Hidden"

type PartLook = { Transparency: number, CastShadow: boolean }

export type Saved = {
	Parts: { [BasePart]: PartLook },
	Decals: { [Decal]: number }, -- Decal and Texture (Texture is a Decal subclass)
}

const Look = {}

-- Authored values of every part and decal of the table (call once, before any Apply).
function Look.Capture(model: Model): Saved
	const saved: Saved = { Parts = {}, Decals = {} }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			saved.Parts[descendant] = { Transparency = descendant.Transparency, CastShadow = descendant.CastShadow }
		elseif descendant:IsA("Decal") then
			saved.Decals[descendant] = descendant.Transparency
		end
	end
	return saved
end

local function blend(authored: number, mode: Mode, ghost: number): number
	if mode == "Hidden" then
		return 1
	elseif mode == "Ghost" then
		return 1 - (1 - authored) * (1 - ghost)
	end
	return authored
end

function Look.Apply(saved: Saved, mode: Mode, ghost: number)
	for part, look in saved.Parts do
		if part.Parent == nil then
			continue
		end
		part.Transparency = blend(look.Transparency, mode, ghost)
		part.CastShadow = look.CastShadow and mode == "Solid"
	end
	for decal, transparency in saved.Decals do
		if decal.Parent ~= nil then
			decal.Transparency = blend(transparency, mode, ghost)
		end
	end
end

return table.freeze(Look)
