-- Worked example v2 (Studio-verified 2026-10-05): simulator shop rebuilt with the production anatomy read via ui_dump.luau (CanvasGroup rounded clip, 3-stop gradient, inner rim, Roblox studs, gradient light bands). Icons here were drawn on request for the test; default is placeholders. Asset ids are test uploads.
--!strict
-- SimShop: simulator-style shop (reference 1275x769). Native chunky primitives (outline + face gradient + darker
-- lip + stud texture) for every button/card; PNG only for illustrations, badge ring, rays, robux glyph.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local REF_H = 769
local OUTLINE = Color3.fromHex("#141416")
local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local FONT_LABEL = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

local ASSET = {
	Gear = "rbxassetid://119294415469932",
	Robux = "rbxassetid://112445960432106",
	Sparkle = "rbxassetid://138353182057190",
	Cash = "rbxassetid://92333166425636",
	CharBlocky = "rbxassetid://85253383074738",
	BadgeInner = "rbxassetid://100795189952470",
	Map = "rbxassetid://121876747585467",
	Sword = "rbxassetid://72355001866834",
	Catapult = "rbxassetid://72284677695278",
	CharOwl = "rbxassetid://81634182356507",
	TitleBasket = "rbxassetid://135434529421476",
	Stud = "rbxassetid://77007140089672",
	CharHouse = "rbxassetid://139787855527814",
	Rays = "rbxassetid://126109076939392",
	Gift = "rbxassetid://117399643012325",
	Basket = "rbxassetid://129183854731306",
	Faces = "rbxassetid://120388366218941",
	BadgeRing = "rbxassetid://133556052191571",
	Excl = "rbxassetid://82730650936903",
	RobloxStuds = "rbxassetid://109444965047738", -- the studs texture the production UI tiles on every surface
}

type Box = { number } -- x, y, w, h in reference px

local function at(box: Box): (UDim2, UDim2)
	return UDim2.fromOffset(box[1], box[2]), UDim2.fromOffset(box[3], box[4])
end

-- Image at a reference box (boxes come from export_layers layout.json, padding included).
local function img(name: string, image: string, box: Box, extra: { [any]: any }?): Instance
	local pos, size = at(box)
	local props: { [any]: any } = {
		Name = name,
		BackgroundTransparency = 1,
		Image = image,
		Position = pos,
		Size = size,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return create("ImageLabel")(props)
end

type LabelSpec = {
	Text: string,
	Box: Box,
	TextSize: number,
	Color: Color3?,
	Stroke: number?,
	XAlign: Enum.TextXAlignment?,
	Font: Font?,
	ZIndex: number?,
	Rotation: number?,
}

-- White chunky text with a dark outline (UIStroke Contextual = glyph outline).
local function label(spec: LabelSpec): Instance
	local pos, size = at(spec.Box)
	return create("TextLabel")({
		BackgroundTransparency = 1,
		Position = pos,
		Size = size,
		Text = spec.Text,
		TextSize = spec.TextSize,
		TextColor3 = spec.Color or Color3.new(1, 1, 1),
		FontFace = spec.Font or FONT,
		TextXAlignment = spec.XAlign or Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = spec.ZIndex or 3,
		Rotation = spec.Rotation or 0,
		create("UIStroke")({
			Color = OUTLINE,
			Thickness = spec.Stroke or 3,
			LineJoinMode = Enum.LineJoinMode.Round,
		}),
	})
end

type ChunkySpec = {
	Name: string,
	Box: Box,
	Top: Color3,
	Bottom: Color3,
	Lip: Color3,
	LipH: number?,
	Radius: number?,
	Stroke: number?,
	StudAlpha: number?,
	Mid: Color3?, -- 3-stop symmetric gradient (lighter middle band), as in the production UI
	Glow: Color3?, -- light bands color (cards)
	StudTile: UDim2?,
	Children: { Instance }?,
}

-- Chunky surface: outline on the whole body, darker lip at the bottom, face with vertical gradient and an
-- embossed stud texture. Lip = body background; face = inset frame that stops LipH above the bottom.
local function chunky(spec: ChunkySpec): Instance
	local pos, size = at(spec.Box)
	local lipH = spec.LipH or 5
	local radius = UDim.new(0, spec.Radius or 6)
	-- Anatomy copied from a production simulator UI (studied in Studio):
	-- Body (lip color + black outline) > Items CanvasGroup (rounded clip) > Inner face (gradient, inner white rim)
	-- > Deco CanvasGroup > [StudTexture (Roblox studs, faded top/bottom), Glow (stepped-transparency light bands)].
	local studs = create("ImageLabel")({
		Name = "StudTexture",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = ASSET.RobloxStuds,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = spec.StudTile or UDim2.fromOffset(90, 90),
		ImageTransparency = spec.StudAlpha or 0.77,
		ZIndex = 1,
		create("UIGradient")({
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.37),
				NumberSequenceKeypoint.new(0.54, 0),
				NumberSequenceKeypoint.new(1, 0.59),
			}),
			Rotation = 90,
		}),
	})
	local glow = if spec.Glow
		then create("Frame")({
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.12, 1.23),
			BackgroundColor3 = spec.Glow,
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
			ZIndex = 0,
			create("UIGradient")({
				-- hard-stepped bands at 45 deg: these ARE the "light rays" (no image)
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.16, 0),
					NumberSequenceKeypoint.new(0.17, 0.99),
					NumberSequenceKeypoint.new(0.43, 0),
					NumberSequenceKeypoint.new(0.431, 0.98),
					NumberSequenceKeypoint.new(0.66, 1),
					NumberSequenceKeypoint.new(0.661, 0),
					NumberSequenceKeypoint.new(0.79, 0),
					NumberSequenceKeypoint.new(0.791, 1),
					NumberSequenceKeypoint.new(0.99, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 45,
			}),
		})
		else nil
	local colors = if spec.Mid
		then ColorSequence.new({
			ColorSequenceKeypoint.new(0, spec.Top),
			ColorSequenceKeypoint.new(0.5, spec.Mid),
			ColorSequenceKeypoint.new(1, spec.Bottom),
		})
		else ColorSequence.new(spec.Top, spec.Bottom)
	local face = create("CanvasGroup")({
		Name = "Items",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0, -- below the chunky's content children
		create("UICorner")({ CornerRadius = radius }),
		create("Frame")({
			Name = "Inner",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, -lipH),
			create("UICorner")({ CornerRadius = radius }),
			create("UIGradient")({ Color = colors, Rotation = 90 }),
			create("UIStroke")({
				Color = Color3.new(1, 1, 1),
				Thickness = 1.5,
				Transparency = 0.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			}),
			create("CanvasGroup")({
				Name = "Deco",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				create("UICorner")({ CornerRadius = radius }),
				studs,
				glow,
			}),
		}),
	})
	local children: { any } = {
		create("UICorner")({ CornerRadius = radius }),
		create("UIStroke")({
			Color = OUTLINE,
			Thickness = spec.Stroke or 2.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
		}),
		face,
	}
	for _, c in spec.Children or {} do
		table.insert(children, c)
	end
	return create("Frame")({
		Name = spec.Name,
		Position = pos,
		Size = size,
		BackgroundColor3 = spec.Lip,
		BorderSizePixel = 0,
		children,
	})
end

local hex = Color3.fromHex

-- Children of a chunky are positioned in its own space: convert a reference box to local.
local function rel(parent: Box, box: Box): Box
	return { box[1] - parent[1], box[2] - parent[2], box[3], box[4] }
end

local function menuButton(name: string, box: Box, top: string, bottom: string, lip: string, icon: string,
	iconBox: Box, text: string?): Instance
	local kids: { Instance } = { img("Icon", icon, rel(box, iconBox), { ZIndex = 2 }) }
	if text then
		table.insert(kids, label({ Text = text, Box = { 0, box[4] - 27, box[3], 20 }, TextSize = 18, Stroke = 2.8, Font = FONT_LABEL }))
	end
	return chunky({
		Name = name,
		Box = box,
		Top = hex(top),
		Bottom = hex(bottom),
		Lip = hex(lip),
		LipH = 6,
		Children = kids,
	})
end

local function tab(name: string, y: number, top: string, bottom: string, lip: string): Instance
	local box = { 937, y, 125, 43 }
	return chunky({
		Name = name,
		Box = box,
		Top = hex(top),
		Bottom = hex(bottom),
		Lip = hex(lip),
		LipH = 5,
		Children = { label({ Text = name, Box = { 0, 0, 125, 38 }, TextSize = 30, Stroke = 3.2 }) },
	})
end

local function priceButton(name: string, box: Box, price: string, textSize: number): Instance
	local h = box[4]
	return chunky({
		Name = name,
		Box = box,
		Top = hex("#AEFF00"),
		Mid = hex("#89FF02"),
		Bottom = hex("#3CE100"),
		Lip = hex("#026F00"),
		StudTile = UDim2.fromScale(0.3, 1),
		StudAlpha = 0.7,
		LipH = 5,
		Children = {
			create("Frame")({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, -5),
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 2),
				}),
				create("ImageLabel")({
					LayoutOrder = 1,
					BackgroundTransparency = 1,
					Image = ASSET.Robux,
					Size = UDim2.fromOffset(math.floor(h * 0.6), math.floor(h * 0.66)),
					ZIndex = 3,
				}),
				create("TextLabel")({
					LayoutOrder = 2,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, textSize),
					Text = price,
					TextSize = textSize,
					TextColor3 = Color3.new(1, 1, 1),
					FontFace = FONT,
					ZIndex = 3,
					create("UIStroke")({ Color = OUTLINE, Thickness = 2.4, LineJoinMode = Enum.LineJoinMode.Round }),
				}),
			}),
		},
	})
end

local function badge(name: string, cx: number, cy: number, innerTop: string, innerBottom: string, icon: string,
	iconBox: Box): Instance
	-- ring 145x142 centered; inner disc (white PNG) tinted with a gradient + rays on top, then icon, sparkle, "2x"
	local ring: Box = { cx - 72.5, cy - 71, 145, 142 }
	local inner: Box = { cx - 53.5, cy - 52, 107, 104 }
	return create("Frame")({
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		img("Ring", ASSET.BadgeRing, ring, { ZIndex = 2 }),
		img("Inner", ASSET.BadgeInner, inner, {
			ZIndex = 3,
			create("UIGradient")({ Color = ColorSequence.new(hex(innerTop), hex(innerBottom)), Rotation = 90 }),
		}),
		img("Rays", ASSET.Rays, { cx - 40, cy - 40, 80, 80 }, { ZIndex = 4, ImageTransparency = 0.82 }),
		img("Icon", icon, iconBox, { ZIndex = 5 }),
		img("Sparkle", ASSET.Sparkle, { cx + 22, cy - 50, 22, 22 }, { ZIndex = 6 }),
		img("Sparkle2", ASSET.Sparkle, { cx - 42, cy + 18, 14, 14 }, { ZIndex = 6, ImageTransparency = 0.2 }),
		label({ Text = "2x", Box = { cx + 4, cy + 10, 60, 44 }, TextSize = 46, Stroke = 4, ZIndex = 7, Rotation = -6 }),
	})
end

local function gamepassCard(name: string, box: Box, top: string, bottom: string, lip: string, title: string,
	badgeKids: Instance, mid: string, glow: string): Instance
	return chunky({
		Name = name,
		Box = box,
		Top = hex(top),
		Bottom = hex(bottom),
		Lip = hex(lip),
		LipH = 7,
		Mid = hex(mid),
		Glow = hex(glow),
		Children = {
			label({ Text = title, Box = { 12, 8, 200, 34 }, TextSize = 36, Stroke = 3.6, XAlign = Enum.TextXAlignment.Left }),
			create("TextLabel")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(13, 45),
				Size = UDim2.fromOffset(140, 64),
				Text = "Doubles your\ncatapult\npower",
				TextSize = 23,
				LineHeight = 0.84,
				TextColor3 = Color3.new(1, 1, 1),
				FontFace = FONT,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 3,
				create("UIStroke")({ Color = OUTLINE, Thickness = 2.8, LineJoinMode = Enum.LineJoinMode.Round }),
			}),
			-- card-local box, same for every card (a ref-absolute box fell off the second card)
			priceButton("Buy", { 14, 121, 128, 44 }, "149", 30),
			badgeKids,
		},
	})
end

local function bannerCard(name: string, x: number, char: string, charBox: Box): Instance
	local box: Box = { x, 217, 112, 110 }
	return create("Frame")({
		Name = name,
		Position = UDim2.fromOffset(box[1], box[2]),
		Size = UDim2.fromOffset(box[3], box[4]),
		BackgroundColor3 = hex("#9C08C8"),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		create("UICorner")({ CornerRadius = UDim.new(0, 4) }),
		img("Rays", ASSET.Rays, { -24, -10, 160, 160 }, { ImageTransparency = 0.86, ZIndex = 2 }),
		img("Char", char, rel(box, charBox), { ZIndex = 3 }),
		label({ Text = name, Box = { 0, 2, 112, 26 }, TextSize = 24, Stroke = 3, ZIndex = 4 }),
		label({ Text = "$??/s", Box = { 0, 82, 112, 26 }, TextSize = 27, Stroke = 3, Color = hex("#86FF0A"), ZIndex = 4 }),
	})
end

export type Props = {
	Scale: (() -> number)?,
}

local function SimShop(props: Props): Instance
	local scale = function(): number
		return if props.Scale then math.max(props.Scale(), 0.01) else 1
	end
	local panel: Box = { 358, 200, 572, 386 }
	return create("Frame")({
		Name = "SimShop",
		BackgroundTransparency = 1,
		Size = function()
			local s = scale()
			return UDim2.fromScale(1 / s, 1 / s)
		end,
		create("UIScale")({ Scale = scale }),

		-- left menu
		menuButton("Shop", { 10, 295, 68, 68 }, "#FF5A86", "#E8235A", "#8C1D45", ASSET.Basket, { 21, 297, 44, 40 }, "SHOP"),
		menuButton("Class", { 83, 295, 68, 68 }, "#1FD0FF", "#0A86F2", "#0B4C8E", ASSET.Sword, { 95, 295, 46, 44 }, "CLASS"),
		menuButton("Vote", { 10, 371, 68, 68 }, "#FFC61A", "#F28A00", "#8C4A0E", ASSET.Map, { 23, 372, 42, 40 }, "VOTE"),
		menuButton("Boost", { 83, 371, 68, 68 }, "#30EA70", "#10B044", "#0A6A2A", ASSET.Faces, { 94, 373, 45, 42 }, "BOOST"),
		menuButton("Settings", { 10, 447, 45, 45 }, "#DCE6F2", "#8EA2BE", "#4A5A72", ASSET.Gear, { 12, 448, 40, 40 }, nil),
		menuButton("Gift", { 58, 447, 45, 45 }, "#FF3A62", "#D0103C", "#7A1030", ASSET.Gift, { 61, 450, 37, 33 }, nil),
		img("Notify", ASSET.Excl, { 68, 283, 14, 26 }, { Rotation = 12, ZIndex = 5 }),

		-- shop panel: dark studded body, content clipped (scrolling list in the real game)
		chunky({
			Name = "Panel",
			Box = panel,
			Top = hex("#2E2E34"),
			Bottom = hex("#26262B"),
			Lip = hex("#1C1C20"),
			LipH = 4,
			Stroke = 3,
			StudAlpha = 0.93,
			Children = {
				create("Frame")({
					Name = "Content",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 4),
					Size = UDim2.new(1, 0, 1, -8),
					ClipsDescendants = true,
					create("Frame")({
						Name = "Scroll",
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(-panel[1], -panel[2] - 4),
						Size = UDim2.fromOffset(1275, 769),
						-- featured pack banner
						chunky({
							Name = "Banner",
							Box = { 368, 210, 554, 129 },
							Top = hex("#E600FF"),
							Bottom = hex("#C400EE"),
							Lip = hex("#7A0098"),
							LipH = 5,
							Stroke = 3,
							StudAlpha = 0.9,
							Children = {},
						}),
						bannerCard("Avocadini", 381, ASSET.CharOwl, { 413, 247, 49, 65 }),
						bannerCard("Esok", 500, ASSET.CharHouse, { 528, 250, 58, 61 }),
						bannerCard("Lerulere", 619, ASSET.CharBlocky, { 648, 244, 58, 70 }),
						img("OldRobux", ASSET.Robux, { 797, 244, 26, 29 }, { ZIndex = 4 }),
						label({ Text = "449", Box = { 826, 242, 60, 32 }, TextSize = 32, Stroke = 3.2, XAlign = Enum.TextXAlignment.Left, ZIndex = 4 }),
						create("Frame")({
							Name = "Strike",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromOffset(838, 258),
							Size = UDim2.fromOffset(92, 4),
							Rotation = 8,
							BackgroundColor3 = hex("#FF1414"),
							BorderSizePixel = 0,
							ZIndex = 5,
						}),
						priceButton("BuyPack", { 774, 282, 133, 44 }, "249", 30),
						label({ Text = "Gamepass!", Box = { 545, 352, 200, 28 }, TextSize = 27, Stroke = 3 }),
						gamepassCard("Cash2x", { 365, 387, 274, 180 }, "#37FF00", "#37FF00", "#034D00", "2x Cash",
							badge("Badge", 571 - 365, 466 - 387, "#D21CF0", "#7A10C8", ASSET.Cash, { 529 - 365, 422 - 387, 96, 82 }), "#B6FF6D", "#30DC00"),
						gamepassCard("Catapult2x", { 649, 387, 273, 180 }, "#00A6FF", "#00A6FF", "#003B63", "2x Catapult",
							badge("Badge", 854 - 649, 466 - 387, "#4A4A52", "#2A2A30", ASSET.Catapult, { 811 - 649, 409 - 387, 90, 97 }), "#00FFFF", "#0291FF"),
						-- next row peeking under the fold
						chunky({ Name = "NextA", Box = { 365, 573, 274, 180 }, Top = hex("#FFB400"), Bottom = hex("#F08A00"), Lip = hex("#8C4A00") }),
						chunky({ Name = "NextB", Box = { 649, 573, 273, 180 }, Top = hex("#F03A48"), Bottom = hex("#C81E2C"), Lip = hex("#7A1018") }),
					}),
				}),
			},
		}),
		img("TitleBasket", ASSET.TitleBasket, { 345, 172, 56, 50 }, { Rotation = -14, ZIndex = 6 }),
		label({ Text = "Shop", Box = { 400, 178, 110, 48 }, TextSize = 48, Stroke = 4.2, XAlign = Enum.TextXAlignment.Left, ZIndex = 6 }),
		chunky({
			Name = "Close",
			Box = { 904, 180, 47, 46 },
			Top = hex("#FF3A3A"),
			Bottom = hex("#E01414"),
			Lip = hex("#8A0A0A"),
			LipH = 5,
			Stroke = 3,
			Children = { label({ Text = "X", Box = { 0, 0, 47, 41 }, TextSize = 38, Stroke = 3.6 }) },
		}),

		-- category tabs
		tab("Exclusive", 276, "#12CCFF", "#0A88E2", "#0A4C8A"),
		tab("Packs", 324, "#FFF000", "#F4B400", "#A86600"),
		tab("Gamepass", 371, "#FA7272", "#DC3030", "#8A1C1C"),
		tab("Cash", 419, "#9CF000", "#34CC00", "#1C7A0E"),
		tab("Free", 466, "#F000F2", "#9800E8", "#580090"),
	})
end

return SimShop
