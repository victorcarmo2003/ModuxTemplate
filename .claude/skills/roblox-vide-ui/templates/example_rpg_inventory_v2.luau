-- Worked example (Studio-verified 2026-10-05): RPG inventory after the material pass (see references/material-pass.md). Asset ids are test uploads.
--!strict
-- RpgInventory v2 (material pass): "The Ashen Reliquary" dark-fantasy inventory (design space 1920x1080, offset layout + UIScale).
-- Ornaments are 9-slice/vector PNGs; everything else is native. Item art and the character are PLACEHOLDERS
-- (labelled) for the game's real icons / ViewportFrame. Interactive: tabs filter, click selects, tooltip follows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring
local indexes = Vide.indexes
local show = Vide.show

local hex = Color3.fromHex
local C = {
	Bg0 = hex("#120E0B"),
	Bg1 = hex("#1E1712"),
	Well = hex("#0A0806"),
	Gold = hex("#C9A45C"),
	GoldHi = hex("#F3D88B"),
	GoldLo = hex("#6B4E24"),
	Ember = hex("#E0662A"),
	EmberDeep = hex("#7A2E12"),
	Txt = hex("#EDE3CF"),
	Txt2 = hex("#A89A82"),
	Txt3 = hex("#6E6353"),
	Bonus = hex("#7CDB6A"),
}
local RARITY: { [string]: Color3 } = {
	common = hex("#C8C8C8"),
	magic = hex("#6E8BFF"),
	rare = hex("#FFE15C"),
	epic = hex("#B86BFF"),
	legendary = hex("#FF8A1F"),
}
-- Roblox TextSize = CSS size x line-box ratio (measured: Grenze 1.48, Merriweather 1.25, Fondamento 1.39, SSP 1.25)
local F = {
	Title = Font.new("rbxasset://fonts/families/GrenzeGotisch.json", Enum.FontWeight.Bold),
	Name = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold),
	Number = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy),
	Lore = Font.new("rbxasset://fonts/families/Fondamento.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic),
	Body = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold),
}
local ASSET = {
	-- material pass: Blender-rendered gold/iron/ember ornaments + Poly Haven leather (CC0) + baked shadows
	PanelFrame = "rbxassetid://124868162473417",
	TitlePlate = "rbxassetid://127391170082640",
	TitleShadow = "rbxassetid://81924975493210",
	CloseShadow = "rbxassetid://121379696485058",
	Leather = "rbxassetid://111694533921735",
	Inset = "rbxassetid://102522839049834",
	InsetLip = "rbxassetid://90401954980025",
	DropShadow = "rbxassetid://110692926018224",
	Embers = "rbxassetid://91466261052865",
	TipFrame = "rbxassetid://133827825932484",
	Close = "rbxassetid://108642770657035",
	Divider = "rbxassetid://100629014292691",
	SlotFrame = "rbxassetid://72241153545423",
	BarFrame = "rbxassetid://89931973249243",
	SelGlow = "rbxassetid://124344058916733",
	SelGlowSoft = "rbxassetid://120810956730157",
	Coin = "rbxassetid://84629663487671",
	Glyph = {
		head = "rbxassetid://106799243564024",
		amulet = "rbxassetid://136032389291323",
		chest = "rbxassetid://84553115865602",
		hands = "rbxassetid://76725940695818",
		ring = "rbxassetid://82306637089277",
		legs = "rbxassetid://97399550791911",
		feet = "rbxassetid://137361708699915",
		weapon = "rbxassetid://78434038475043",
		offhand = "rbxassetid://92301936654802",
	},
}

-- ---------------------------------------------------------------- data (demo)
export type Item = {
	id: string,
	name: string,
	short: string, -- placeholder label until real icon art exists
	rarity: string,
	category: string,
	count: number?,
	kind: string?, -- "LEGENDARY GREATSWORD"
	ilvl: number?,
	damage: string?,
	stats: { { text: string, special: boolean? } }?,
	lore: string?,
	sell: number?,
}
local ITEMS: { Item } = {
	{ id = "emberfall", name = "Emberfall, Oath of the Last Pyre", short = "GREATSWORD", rarity = "legendary", category = "Weapons", kind = "LEGENDARY GREATSWORD", ilvl = 40, damage = "184 – 231",
		stats = { { text = "+42 Strength" }, { text = "+18% Fire Damage" }, { text = "+6% Critical Chance" }, { text = "Ignites foes on critical hits", special = true } },
		lore = "“The last pyre burned for a hundred years. So shall its oath.”", sell = 3420 },
	{ id = "helm", name = "Cindermarch Helm", short = "HELM", rarity = "rare", category = "Armor", kind = "RARE HELM", ilvl = 38, stats = { { text = "+212 Armor" }, { text = "+9 Vitality" } }, sell = 640 },
	{ id = "potion_hp", name = "Draught of Embers", short = "POTION", rarity = "magic", category = "Potions", count = 12, kind = "CONSUMABLE", stats = { { text = "Restores 640 Health over 4s" } }, sell = 25 },
	{ id = "potion_mp", name = "Ashwater Tonic", short = "POTION", rarity = "magic", category = "Potions", count = 4, kind = "CONSUMABLE", stats = { { text = "Restores 320 Mana" } }, sell = 25 },
	{ id = "ore", name = "Smoldering Ore", short = "ORE", rarity = "common", category = "Materials", count = 37, kind = "CRAFTING MATERIAL", sell = 3 },
	{ id = "staff", name = "Staff of the Grey Choir", short = "STAFF", rarity = "epic", category = "Weapons", kind = "EPIC STAFF", ilvl = 41, damage = "96 – 142", stats = { { text = "+31 Intellect" }, { text = "+12% Spell Haste" } }, sell = 1210 },
	{ id = "gloves", name = "Vow-Bound Gauntlets", short = "GLOVES", rarity = "rare", category = "Armor", kind = "RARE GAUNTLETS", ilvl = 37, stats = { { text = "+118 Armor" }, { text = "+6 Strength" } }, sell = 410 },
	{ id = "hide", name = "Charred Hide", short = "HIDE", rarity = "common", category = "Materials", count = 9, kind = "CRAFTING MATERIAL", sell = 2 },
	{ id = "amulet", name = "Pendant of Quiet Ash", short = "AMULET", rarity = "epic", category = "Armor", kind = "EPIC AMULET", ilvl = 40, stats = { { text = "+14 All Attributes" }, { text = "Fire Resistance +20%", special = true } }, sell = 980 },
	{ id = "herb", name = "Gravebloom", short = "HERB", rarity = "common", category = "Potions", count = 21, kind = "REAGENT", sell = 1 },
	{ id = "ring", name = "Band of the Lantern", short = "RING", rarity = "magic", category = "Armor", kind = "MAGIC RING", ilvl = 33, stats = { { text = "+5% Movement Speed" } }, sell = 120 },
	{ id = "bread", name = "Hearth Bread", short = "BREAD", rarity = "common", category = "Potions", count = 3, kind = "FOOD", stats = { { text = "Restores 120 Stamina" } }, sell = 1 },
	{ id = "bow", name = "Pyrewood Longbow", short = "BOW", rarity = "rare", category = "Weapons", kind = "RARE BOW", ilvl = 36, damage = "88 – 120", stats = { { text = "+19 Dexterity" } }, sell = 520 },
	{ id = "rune", name = "Rune of the Unburnt", short = "RUNE", rarity = "legendary", category = "Materials", kind = "LEGENDARY RUNE", ilvl = 40, stats = { { text = "Socket: +25% Fire Damage", special = true } }, sell = 2900 },
}
local GRID = { X = 925, Y = 266, Cell = 76, Gap = 6, Cols = 8, Rows = 6 }

-- ---------------------------------------------------------------- helpers
type TextOpts = { font: Font?, color: (Color3 | () -> Color3)?, align: Enum.TextXAlignment?, z: number?, rich: boolean? }
-- Text box centered vertically on cy; height = TextSize (one Roblox line box).
local function txt(s: string | () -> string, x: number, cy: number, w: number, size: number, o: TextOpts?): Instance
	local opts: TextOpts = o or {}
	return create("TextLabel")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, cy - size / 2),
		Size = UDim2.fromOffset(w, size),
		Text = s,
		TextSize = size,
		FontFace = opts.font or F.Body,
		TextColor3 = opts.color or C.Txt,
		TextXAlignment = opts.align or Enum.TextXAlignment.Left,
		RichText = opts.rich or false,
		ZIndex = opts.z or 3,
	})
end

local function image(img: string, x: number, y: number, w: number, h: number, props: { [any]: any }?): Instance
	local p: { [any]: any } = {
		BackgroundTransparency = 1,
		Image = img,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}
	for k, v in props or {} do
		p[k] = v
	end
	return create("ImageLabel")(p)
end

-- 9-slice gold corner-tick frame over a w x h box (source drawn at 76 + 4 px padding, 2x export)
-- Recessed well: inner shadow (darker at the top, light from above) + a faint lit lip at the bottom edge.
-- Replaces v1's gold corner ticks on every slot (fewer outlines; separation by depth, not by lines).
local function slotFrame(w: number, h: number, z: number?): Instance
	return create("Frame")({
		Name = "Inset",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z or 4,
		image(ASSET.Inset, 0, 0, w, h, { Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(40, 40, 88, 88), SliceScale = 0.5, ZIndex = z or 4 }),
		image(ASSET.InsetLip, 0, 0, w, h, { Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(40, 40, 88, 88), SliceScale = 0.5, ZIndex = z or 4 }),
		create("UIStroke")({ Color = C.GoldLo, Thickness = 1, Transparency = 0.55 }),
	})
end

local function leather(z: number?, tint: Color3?): Instance
	return create("ImageLabel")({
		Name = "Leather",
		BackgroundTransparency = 1,
		Image = ASSET.Leather,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(256, 256),
		ImageColor3 = tint or Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = z or 0,
	})
end

local function plaque(x: number, y: number, w: number, h: number, kids: { any }): Instance
	return create("Frame")({
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = C.Bg1,
		BorderSizePixel = 0,
		create("UIStroke")({ Color = C.GoldLo, Thickness = 1, Transparency = 0.2 }),
		create("UIGradient")({
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, hex("#2A2019")),
				ColorSequenceKeypoint.new(1, hex("#17120E")),
			}),
			Rotation = 90,
		}),
		kids,
	})
end

-- ---------------------------------------------------------------- pieces
local function equipSlot(kind: string, x: number, y: number, rarity: string?, label: string?): Instance
	local size = GRID.Cell
	local tint = rarity and RARITY[rarity]
	return create("Frame")({
		Name = "Eq_" .. kind,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = hex("#0B0807"),
		BorderSizePixel = 0,
		if tint
			then create("Frame")({ Name = "Tint", BackgroundColor3 = tint, BackgroundTransparency = 0.86, BorderSizePixel = 0, Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4) })
			else image(ASSET.Glyph[kind], 14, 14, size - 28, size - 28, { ScaleType = Enum.ScaleType.Fit, ImageTransparency = 0.82, ZIndex = 2 }),
		if tint then create("Frame")({ Name = "RarityBar", BackgroundColor3 = tint, BorderSizePixel = 0, Position = UDim2.new(0, 2, 1, -5), Size = UDim2.new(1, -4, 0, 3), ZIndex = 2 }) else nil,
		if label then txt(label, 0, size / 2, size, 13, { color = C.Txt3, align = Enum.TextXAlignment.Center }) else nil,
		slotFrame(size, size),
	})
end

local function bar(name: string, y: number, value: () -> number, max: number, c0: string, c1: string): Instance
	local ratio = spring(function()
		return math.clamp(value() / max, 0, 1)
	end, 0.35)
	return create("Frame")({
		Name = "Bar_" .. name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		txt(string.upper(name), 380, y + 8, 90, 16, { color = C.Txt2 }),
		create("Frame")({
			Name = "Track",
			Position = UDim2.fromOffset(476, y),
			Size = UDim2.fromOffset(280, 16),
			BackgroundColor3 = C.Well,
			BorderSizePixel = 0,
			create("Frame")({
				Name = "Fill",
				Position = UDim2.fromOffset(2, 2),
				Size = function()
					return UDim2.new(ratio(), -4, 1, -4)
				end,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				create("UIGradient")({
					-- lighter middle band (the sim lesson) reads as a glassy tube
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, hex(c1)),
						ColorSequenceKeypoint.new(0.35, hex(c0)),
						ColorSequenceKeypoint.new(0.55, hex(c0):Lerp(Color3.new(1, 1, 1), 0.25)),
						ColorSequenceKeypoint.new(1, hex(c1)),
					}),
					Rotation = 90,
				}),
			}),
		}),
		-- frame with diamond caps: horizontal-only 9-slice (bar height is fixed)
		image(ASSET.BarFrame, 459, y - 11, 314, 34, { ZIndex = 4 }), -- rendered at the exact length: no slice
		txt(function()
			return string.format("%d / %d", math.floor(value()), max)
		end, 770, y + 8, 80, 16, { align = Enum.TextXAlignment.Right }),
	})
end

local function attribute(key: string, value: number, x: number): Instance
	return plaque(x, 862, 96, 44, {
		txt(key, 12, 22, 40, 16, { color = C.Txt2 }),
		txt(tostring(value), 40, 23, 46, 28, { font = F.Number, align = Enum.TextXAlignment.Right }),
	})
end

local function tooltip(item: () -> Item?, anchor: () -> Vector2): Instance
	local function rows(): { Instance }
		local it = item()
		local list: { Instance } = {}
		if not it then
			return list
		end
		local col = RARITY[it.rarity]
		local order = 0
		local function add(inst: Instance)
			order += 1;
			(inst :: any).LayoutOrder = order
			table.insert(list, inst)
		end
		local function row(h: number, kids: { any }): Instance
			return create("Frame")({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h), kids })
		end
		add(create("TextLabel")({
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = it.name,
			TextWrapped = true,
			TextSize = 26,
			FontFace = F.Name,
			TextColor3 = col,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 13,
		}))
		add(row(22, {
			txt(it.kind or "", 0, 11, 240, 16, { color = C.Txt2, z = 13 }),
			if it.ilvl then txt("ITEM LV " .. it.ilvl, 200, 11, 140, 16, { color = C.Txt3, align = Enum.TextXAlignment.Right, z = 13 }) else nil,
		}))
		add(row(20, { image(ASSET.Divider, -4, 0, 348, 24, { ZIndex = 13 }) }))
		if it.damage then
			add(row(40, {
				txt(it.damage, 0, 20, 150, 38, { font = F.Number, z = 13 }),
				txt("DAMAGE", 152, 22, 100, 16, { color = C.Txt2, z = 13 }),
			}))
		end
		for _, s in it.stats or {} do
			add(row(26, { txt(s.text, 16, 13, 324, 20, { color = if s.special then col else C.Bonus, z = 13 }) }))
		end
		if it.lore then
			add(row(20, { image(ASSET.Divider, -4, 0, 348, 24, { ZIndex = 13 }) }))
			add(create("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = it.lore,
				TextWrapped = true,
				TextSize = 21,
				FontFace = F.Lore,
				TextColor3 = C.Txt2,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 13,
			}))
		end
		add(row(30, {
			txt("SELL VALUE", 0, 18, 160, 15, { color = C.Txt3, z = 13 }),
			image(ASSET.Coin, 254, 9, 18, 18, { ZIndex = 13 }),
			txt(string.format("%d", it.sell or 0):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""), 276, 18, 64, 19,
				{ font = F.Name, color = C.GoldHi, align = Enum.TextXAlignment.Right, z = 13 }),
		}))
		return list
	end
	local color = function(): Color3
		local it = item()
		return if it then RARITY[it.rarity] else C.Gold
	end
	return create("Frame")({
		Name = "Tooltip",
		Visible = function()
			return item() ~= nil
		end,
		Position = function()
			local a = anchor()
			return UDim2.fromOffset(a.X, a.Y)
		end,
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = hex("#0D0A08"),
		BackgroundTransparency = 0.03,
		BorderSizePixel = 0,
		ZIndex = 10,
		create("UIStroke")({ Color = color, Thickness = 1.5, Transparency = 0.35 }),
		leather(10, Color3.fromRGB(150, 150, 150)),
		create("Frame")({
			Name = "Band",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 92),
			ZIndex = 11,
			create("UIGradient")({ Rotation = 90, Transparency = NumberSequence.new(0.62, 1) }),
		}),
		-- corner-tick frame follows the auto-sized tooltip: scale size + 4 px overhang each side
		create("ImageLabel")({
			BackgroundTransparency = 1,
			Image = ASSET.TipFrame,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(36, 36, 224, 224),
			SliceScale = 0.5,
			Position = UDim2.fromOffset(-9, -9),
			Size = UDim2.new(1, 18, 1, 18),
			ZIndex = 14,
		}),
		create("Frame")({
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 12,
			create("UIPadding")({ PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 10) }),
			create("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			rows,
		}),
	})
end

-- ---------------------------------------------------------------- screen
export type Props = {
	Scale: (() -> number)?,
	-- Initial state (UI Labs stories / tests drive these; the screen owns the state afterwards)
	InitialTab: string?,
	InitialSelected: string?,
}

local TABS = { "All", "Weapons", "Armor", "Potions", "Materials" }

local function RpgInventory(props: Props): Instance
	local scale = function(): number
		return if props.Scale then math.max(props.Scale(), 0.01) else 1
	end
	local tab = source(props.InitialTab or "All")
	local selected = source((props.InitialSelected or "emberfall") :: string?)
	local health = source(1840)

	local filtered = function(): { Item | false }
		local t = tab()
		local list: { Item | false } = {}
		for _, it in ITEMS do
			if t == "All" or it.category == t then
				table.insert(list, it)
			end
		end
		while #list < GRID.Cols * GRID.Rows do
			table.insert(list, false)
		end
		return list
	end
	local selectedItem = function(): Item?
		local id = selected()
		for _, it in ITEMS do
			if it.id == id and (tab() == "All" or it.category == tab()) then
				return it
			end
		end
		return nil
	end
	local cellPos = function(): Vector2
		local id = selected()
		for i, it in filtered() do
			if it and (it :: Item).id == id then
				local c, r = (i - 1) % GRID.Cols, (i - 1) // GRID.Cols
				return Vector2.new(GRID.X + c * (GRID.Cell + GRID.Gap), GRID.Y + r * (GRID.Cell + GRID.Gap))
			end
		end
		return Vector2.new(GRID.X, GRID.Y)
	end
	local tipAnchor = function(): Vector2
		local p = cellPos()
		local x = p.X + GRID.Cell + 17
		if x + 380 > 1600 then
			x = p.X - 17 - 380
		end
		return Vector2.new(x - 300, math.clamp(p.Y - 10, 170, 520) - 150) -- panel-local
	end

	local cells = indexes(filtered, function(entry: () -> Item | false, index: number): Instance
		local it = function(): Item?
			local e = entry()
			return if e then e :: Item else nil
		end
		local isSel = function(): boolean
			local i = it()
			return i ~= nil and i.id == selected()
		end
		return create("ImageButton")({
			Name = "Cell" .. index,
			LayoutOrder = index,
			BackgroundColor3 = hex("#0B0807"),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			slotFrame(76, 76, 4),
			ZIndex = function()
				return if isSel() then 3 else 1
			end,
			Activated = function()
				local i = it()
				selected(if i then i.id else nil)
			end,
			create("Frame")({
				Name = "Tint",
				BackgroundColor3 = function()
					local i = it()
					return if i then RARITY[i.rarity] else C.Bg1
				end,
				BackgroundTransparency = function()
					return if it() then 0.88 else 1
				end,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(2, 2),
				Size = UDim2.new(1, -4, 1, -4),
			}),
			create("Frame")({
				Name = "RarityBar",
				Visible = function()
					return it() ~= nil
				end,
				BackgroundColor3 = function()
					local i = it()
					return if i then RARITY[i.rarity] else C.Bg1
				end,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 2, 1, -5),
				Size = UDim2.new(1, -4, 0, 3),
				ZIndex = 2,
			}),
			txt(function()
				local i = it()
				return if i then i.short else ""
			end, 0, 40, 76, 13, { color = C.Txt3, align = Enum.TextXAlignment.Center }),
			txt(function()
				local i = it()
				return if i and i.count then "x" .. i.count else ""
			end, 0, 62, 70, 18, { font = F.Name, align = Enum.TextXAlignment.Right }),
			-- ember selection: soft glow + crisp ring, both children of the selected cell (raised ZIndex)
			image(ASSET.SelGlowSoft, -31, -31, 138, 138, {
				ImageColor3 = C.Ember,
				ImageTransparency = function()
					return if isSel() then 0.35 else 1
				end,
				ZIndex = 5,
			}),
			image(ASSET.SelGlow, -31, -31, 138, 138, {
				ImageColor3 = C.Ember,
				ImageTransparency = function()
					return if isSel() then 0 else 1
				end,
				ZIndex = 6,
			}),
		})
	end)

	local tabButtons = {}
	for i, name in TABS do
		local active = function(): boolean
			return tab() == name
		end
		table.insert(tabButtons, create("TextButton")({
			Name = "Tab" .. name,
			Position = UDim2.fromOffset(925 - 300 + (i - 1) * 131, 206 - 150),
			Size = UDim2.fromOffset(123, 38),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = function()
				return if active() then hex("#3A2216") else C.Bg1
			end,
			BorderSizePixel = 0,
			Activated = function()
				tab(name)
			end,
			create("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = function()
					return if active() then C.Gold else C.GoldLo
				end,
				Thickness = function()
					return if active() then 1.5 else 1
				end,
				Transparency = function()
					return if active() then 0 else 0.5
				end,
			}),
			create("Frame")({
				Name = "Underline",
				Visible = active,
				BackgroundColor3 = C.Ember,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, -2),
				Size = UDim2.new(1, 0, 0, 2),
			}),
			txt(string.upper(name), 0, 19, 123, 18, {
				align = Enum.TextXAlignment.Center,
				color = function()
					return if active() then C.GoldHi else C.Txt2
				end,
			}),
		}))
	end

	-- panel-local coordinates from here (panel at 300,150)
	local function L(x: number, y: number): (number, number)
		return x - 300, y - 150
	end
	local cx, cy = L(386, 300)

	return create("Frame")({
		Name = "RpgInventory",
		BackgroundTransparency = 1,
		Size = function()
			local s = scale()
			return UDim2.fromScale(1 / s, 1 / s)
		end,
		create("UIScale")({ Scale = scale }),
		image(ASSET.DropShadow, 300 - 48, 150 - 36, 1320 + 96, 780 + 96, { Name = "PanelShadow", ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(96, 96, 160, 160), SliceScale = 0.5, ImageTransparency = 0.1 }),
		create("Frame")({
			Name = "Panel",
			Position = UDim2.fromOffset(300, 150),
			Size = UDim2.fromOffset(1320, 780),
			BackgroundColor3 = C.Bg0,
			BorderSizePixel = 0,
			leather(-2), -- below ember/vignette frames (ZIndex 0): same-ZIndex sibling order is not guaranteed
			-- embers drifting up from the bottom (tile scrolled by a looping tween; static in edit-mode captures)
			create("Frame")({
				Name = "Embers",
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
				create("ImageLabel")({
					BackgroundTransparency = 1,
					Image = ASSET.Embers,
					ScaleType = Enum.ScaleType.Tile,
					TileSize = UDim2.fromOffset(256, 256),
					ImageColor3 = C.Ember,
					ImageTransparency = 0.35,
					Size = UDim2.new(1, 0, 1, 256),
					create("UIGradient")({ Rotation = 90, Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.85), NumberSequenceKeypoint.new(1, 0.2) }) }),
					Vide.action(function(inst: Instance)
						local TweenService = game:GetService("TweenService")
						local tw = TweenService:Create(inst, TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
							{ Position = UDim2.fromOffset(0, -256) })
						tw:Play()
						Vide.cleanup(function()
							tw:Cancel()
						end)
					end),
				}),
			}),
			-- atmosphere: ember glow rising from the bottom + edge vignette (gradients only, no images)
			create("Frame")({
				Name = "Ember",
				BackgroundColor3 = C.EmberDeep,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 0,
				create("UIGradient")({ Rotation = 90, Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.92), NumberSequenceKeypoint.new(1, 0.5) }) }),
			}),
			create("Frame")({
				Name = "VignetteX",
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 0,
				create("UIGradient")({ Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.15, 1), NumberSequenceKeypoint.new(0.85, 1), NumberSequenceKeypoint.new(1, 0.5) }) }),
			}),
			create("Frame")({
				Name = "VignetteY",
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 0,
				create("UIGradient")({ Rotation = 90, Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.18, 1), NumberSequenceKeypoint.new(0.85, 1), NumberSequenceKeypoint.new(1, 0.6) }) }),
			}),
			-- ornate 9-slice frame (source 200x200 drawn, corners 64, 2x export, 5 px pad)
			image(ASSET.PanelFrame, -5, -5, 1330, 790, { ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(138, 138, 282, 282), SliceScale = 0.5, ZIndex = 8 }),
			image(ASSET.TitleShadow, 722 - 300 - 12 + 3, 111 - 150 - 12 + 6, 500, 106, { ZIndex = 9, ImageTransparency = 0.15 }),
			image(ASSET.TitlePlate, 722 - 300, 111 - 150, 476, 82, { ZIndex = 9 }),
			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(727 - 300, 4 - 34),
				Size = UDim2.fromOffset(466, 68),
				Text = "Inventory",
				TextSize = 68,
				FontFace = F.Title,
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 10,
				-- engraved gold: vertical gold gradient on the glyphs + dark outline
				create("UIGradient")({ Rotation = 90, Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, hex("#FFF1C4")), ColorSequenceKeypoint.new(0.5, hex("#E8BE6A")), ColorSequenceKeypoint.new(1, hex("#9C6A2C")) }) }),
				create("UIStroke")({ Color = hex("#1A0F08"), Thickness = 2, Transparency = 0.1 }),
			}),
			create("ImageButton")({
				Name = "Close",
				BackgroundTransparency = 1,
				Image = ASSET.Close,
				Position = UDim2.fromOffset(1579 - 300, 121 - 150),
				Size = UDim2.fromOffset(70, 70),
				ZIndex = 9,
			}),
			image(ASSET.CloseShadow, 1579 - 300 - 9 + 2, 121 - 150 - 9 + 4, 88, 88, { ZIndex = 8, ImageTransparency = 0.15 }),

			-- character column
			txt("Kaelen Ashbound", 100, 236 - 150 - 10, 400, 38, { font = F.Name, align = Enum.TextXAlignment.Center }),
			txt("LEVEL 42  ·  TEMPLAR OF THE PYRE", 100, 262 - 150 - 5, 400, 18, { color = C.Txt2, align = Enum.TextXAlignment.Center }),
			image(ASSET.Divider, 381 - 300, 269 - 150, 438, 30),
			create("Frame")({
				Name = "CharacterPlaceholder",
				Position = UDim2.fromOffset(480 - 300, 300 - 150),
				Size = UDim2.fromOffset(240, 310),
				BackgroundColor3 = hex("#0B0807"),
				BorderSizePixel = 0,
				create("UICorner")({ CornerRadius = UDim.new(0, 18) }),
				slotFrame(240, 310, 1),
				create("UIStroke")({ Color = C.GoldLo, Thickness = 1.5 }),
				txt("CHARACTER", 0, 150, 240, 18, { color = C.Txt3, align = Enum.TextXAlignment.Center }),
				txt("ViewportFrame placeholder", 0, 172, 240, 16, { color = C.Txt3, align = Enum.TextXAlignment.Center }),
			}),
			equipSlot("head", cx, cy, "epic", "HEAD"),
			equipSlot("amulet", cx, cy + 86),
			equipSlot("chest", cx, cy + 172, "rare", "CHEST"),
			equipSlot("hands", cx, cy + 258),
			equipSlot("ring", cx + 352, cy),
			equipSlot("ring", cx + 352, cy + 86, "magic", "RING"),
			equipSlot("legs", cx + 352, cy + 172),
			equipSlot("feet", cx + 352, cy + 258, "common", "FEET"),
			equipSlot("weapon", 516 - 300, 630 - 150),
			equipSlot("offhand", 608 - 300, 630 - 150),

			-- vitals (positions in this sub-frame are screen-absolute minus panel offset)
			create("Frame")({
				Name = "Vitals",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(-300, -150),
				Size = UDim2.fromOffset(1920, 1080),
				bar("Health", 744, health, 2210, "#E0453A", "#7A1414"),
				bar("Mana", 784, function() return 620 end, 980, "#4F7BFF", "#1A2F86"),
				bar("Stamina", 824, function() return 410 end, 410, "#C9D84A", "#4E6A14"),
				attribute("STR", 48, 388),
				attribute("DEX", 31, 498),
				attribute("INT", 22, 608),
				attribute("VIT", 40, 718),
			}),
			image(ASSET.Divider, 880 - 300 - 219, 540 - 150 - 15, 438, 30, { Rotation = 90 }),

			-- inventory column
			tabButtons,
			create("Frame")({
				Name = "Grid",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(GRID.X - 300, GRID.Y - 150),
				Size = UDim2.fromOffset(GRID.Cols * GRID.Cell + (GRID.Cols - 1) * GRID.Gap, GRID.Rows * GRID.Cell + (GRID.Rows - 1) * GRID.Gap),
				create("UIGridLayout")({
					CellSize = UDim2.fromOffset(GRID.Cell, GRID.Cell),
					CellPadding = UDim2.fromOffset(GRID.Gap, GRID.Gap),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				cells,
			}),
			-- footer
			image(ASSET.Coin, 925 - 300, 809 - 150, 34, 34),
			txt("12,480", 964 - 300, 826 - 150, 200, 30, { font = F.Number, color = C.GoldHi }),
			txt("WEIGHT", 1180 - 300, 811 - 150, 100, 16, { color = C.Txt2 }),
			txt("86 / 120", 1340 - 300, 811 - 150, 100, 16, { align = Enum.TextXAlignment.Right }),
			create("Frame")({
				Name = "WeightTrack",
				Position = UDim2.fromOffset(1180 - 300, 826 - 150),
				Size = UDim2.fromOffset(260, 10),
				BackgroundColor3 = C.Well,
				BorderSizePixel = 0,
				create("UIStroke")({ Color = C.GoldLo, Thickness = 1 }),
				create("Frame")({
					BackgroundColor3 = C.Gold,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(86 / 120, 1),
					create("UIGradient")({ Rotation = 90, Color = ColorSequence.new(C.GoldHi, C.GoldLo) }),
				}),
			}),
			create("TextButton")({
				Name = "Sort",
				Text = "",
				AutoButtonColor = false,
				Position = UDim2.fromOffset(1470 - 300, 804 - 150),
				Size = UDim2.fromOffset(108, 40),
				BackgroundColor3 = C.Bg1,
				BorderSizePixel = 0,
				create("UIStroke")({ Color = C.Gold, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				txt("SORT", 0, 20, 108, 18, { color = C.GoldHi, align = Enum.TextXAlignment.Center }),
			}),

			show(function()
				return selectedItem() ~= nil
			end, function()
				return tooltip(selectedItem, tipAnchor)
			end),
		}),
	})
end

return RpgInventory
