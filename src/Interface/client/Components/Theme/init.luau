--!strict
-- UI tokens from docs/art/style-guide.md §2 and §7. Components read colors and fonts from here,
-- never from literals, so a palette change is one edit.

const Theme = {
	Color = {
		-- §7.1: pill panels are Ink at 70% opacity, white text with an Ink outline.
		Ink = Color3.fromHex("#2B2233"),
		Text = Color3.fromHex("#FFFFFF"),
		Mustard = Color3.fromHex("#F6C12B"), -- interactive accent
		Teal = Color3.fromHex("#3FA7B5"),
		Green = Color3.fromHex("#5FA36A"),
		Cream = Color3.fromHex("#FFF1D6"),
		Violet = Color3.fromHex("#6A5ACD"), -- thief bar (§7.3)
		Slate = Color3.fromHex("#8A8FA3"), -- grade D on the shift summary (§7.4, never red)
		-- Price the party cannot pay (FEAT-008 "preço em vermelho"); same Ketchup red as Low. Grades/sanity never red.
		NoCash = Color3.fromHex("#E2402E"),
		-- CookInterface colors from AnimalPlane (DEC-029): orange while cooking, green when ready.
		Cooking = Color3.fromRGB(252, 172, 1),
		Ready = Color3.fromRGB(0, 255, 115),
		-- FEAT-007: stock counter turns red at <= 2 (Ketchup of §2.1).
		Low = Color3.fromHex("#E2402E"),
	},

	Transparency = {
		Panel = 0.3,
		Track = 0.5,
	},

	Font = {
		Title = Font.fromEnum(Enum.Font.FredokaOne),
		Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	},

	-- Smallest readable size on a phone (frontend rule: text >= 14 px on the smallest screen).
	MinTextSize = 14,
	-- Smallest touch target (44 px).
	MinTouch = 44,
	Stroke = 2,
}

return table.freeze(Theme)
