--!strict
-- OrderStack/Sprites: the ids of the ticket sprites (docs/art/ticket-sprites.md, AST-109..112). The one place with these ids.
-- A layer picture is { Id, Tint? }: Tint is for the white zig-zag of the sauces. Provisional until the owner approves the art.
export type Layer = { Id: string, Tint: Color3? }

const Sprites = {
	-- 9-slice bands (Slice, SliceCenter 16,16,48,48 of 64x64)
	BandCream = "rbxassetid://102719563623924",
	BandMustard = "rbxassetid://112934820577899",
	BandSlice = Rect.new(16, 16, 48, 48),
	Medallion = "rbxassetid://114660860458809",
	Pin = "rbxassetid://84992795924518",
	Layers = {
		bun = { Id = "rbxassetid://123150128305850" },
		sausage = { Id = "rbxassetid://112402250741884" },
		cheese = { Id = "rbxassetid://139927057417790" },
		bacon = { Id = "rbxassetid://122238322479758" },
		potato_sticks = { Id = "rbxassetid://90795375171927" },
		ketchup = { Id = "rbxassetid://93105718703873", Tint = Color3.fromHex("#E2402E") },
		mustard = { Id = "rbxassetid://93105718703873", Tint = Color3.fromHex("#F6C12B") },
		cream_cheese = { Id = "rbxassetid://93105718703873", Tint = Color3.fromHex("#FFF8EC") },
	} :: { [string]: Layer },
}

return table.freeze(Sprites)
