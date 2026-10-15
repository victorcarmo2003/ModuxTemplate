--!strict
-- Rows of the class screen from Content (Classes, Species, Shop.GamePasses). Pure: no Vide, no network.
-- Description (narrative-writer placeholder) is "perk. drawback." (Content.Classes header): a class with effects shows
-- its first sentence as the perk and the rest as drawbacks; a class without effects (the dog) shows neutral notes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Entry = {
	Key: string,
	Title: string,
	Animal: string,
	Species: string,
	Badge: string,
	Icon: string,
	Price: number,
	Available: boolean,
	Perks: { string },
	Drawbacks: { string },
	Notes: { string },
}

-- "Moves faster. Starts each night with 90 sanity." -> { "Moves faster.", "Starts each night with 90 sanity." }
local function sentences(text: string): { string }
	const out: { string } = {}
	for piece in string.gmatch(text .. " ", "(.-[%.!?])%s+") do
		const trimmed = string.match(piece, "^%s*(.-)%s*$") or piece
		if trimmed ~= "" then
			table.insert(out, trimmed)
		end
	end
	if #out == 0 and text ~= "" then
		table.insert(out, text)
	end
	return out
end

local function build(): { Entry }
	const list: { Entry } = {}
	for _, class in Content.Classes.List do
		const species = Content.Species.ByKey[class.Species]
		const animal = if species then species.Name else class.Species
		const parts = sentences(class.Description)
		const perks: { string } = {}
		const drawbacks: { string } = {}
		const notes: { string } = {}
		if #class.Effects == 0 then
			for _, part in parts do
				table.insert(notes, part)
			end
		else
			for index, part in parts do
				table.insert(if index == 1 then perks else drawbacks, part)
			end
		end
		table.insert(list, {
			Key = class.Key,
			Title = class.Name,
			Animal = animal,
			Species = class.Species,
			Badge = string.upper(string.sub(animal, 1, 1)),
			Icon = `Class/{class.Key}`,
			Price = class.Price,
			Available = class.InMvp,
			Perks = perks,
			Drawbacks = drawbacks,
			Notes = notes,
		})
	end
	return list
end

-- Suggested Robux price of a class Game Pass (display fallback) and its PassId; nil = no pass (PassId 0 or not sold).
local function robux(key: string): (number?, number)
	const pass = Content.Shop.GamePasses.ByKey[key]
	if pass == nil or pass.PassId <= 0 then
		return nil, 0
	end
	return pass.Robux, pass.PassId
end

return table.freeze({
	Build = build,
	Sentences = sentences,
	Robux = robux,
})
