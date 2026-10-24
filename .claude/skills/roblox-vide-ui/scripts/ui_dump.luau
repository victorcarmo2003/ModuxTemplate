-- ui_dump.luau — read an existing Roblox UI's real structure (paste into execute_luau, Edit datamodel).
-- Use it to LEARN how a production UI is built before imitating it: layering, strokes, gradients, textures,
-- which parts are images vs native. Set ROOT and DEPTH, run, read the output. Read-only: changes nothing.
--
-- What to look for (lessons from a production simulator UI, 2026-10-05):
--   * CanvasGroup + UICorner used as a ROUNDED CLIP for textures/glows (ClipsDescendants clips only rectangles)
--   * UIStroke StrokeSizingMode=ScaledSize (fractional Thickness) and BorderStrokePosition=Inner/Outer
--   * UIGradient Transparency with hard steps = light bands/rays without images
--   * TextScaled + UIAspectRatioConstraint everywhere (Scale layout), RichText for mixed colors/sizes
--   * the same texture asset id repeated everywhere (studs) with different TileSize/ImageTransparency

local ROOT = game.StarterGui:FindFirstChild("Shop") -- <- set
local DEPTH = 6
local SKIP_CLASSES = { UIAspectRatioConstraint = true } -- noisy; set to {} to include

local function fmt(v: any): string
	local t = typeof(v)
	if t == "UDim2" then return string.format("{%.3g,%g,%.3g,%g}", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
	elseif t == "UDim" then return string.format("{%.3g,%g}", v.Scale, v.Offset)
	elseif t == "Color3" then return "#" .. v:ToHex()
	elseif t == "Vector2" then return string.format("(%g,%g)", v.X, v.Y)
	elseif t == "Rect" then return string.format("Rect(%g,%g,%g,%g)", v.Min.X, v.Min.Y, v.Max.X, v.Max.Y)
	elseif t == "Font" then return (v.Family:match("([%w]+)%.json") or v.Family) .. "/" .. v.Weight.Name
	elseif t == "ColorSequence" then
		local s = {}
		for _, k in v.Keypoints do table.insert(s, string.format("%.2f:#%s", k.Time, k.Value:ToHex())) end
		return "CS[" .. table.concat(s, " ") .. "]"
	elseif t == "NumberSequence" then
		local s = {}
		for _, k in v.Keypoints do table.insert(s, string.format("%.2f:%.2f", k.Time, k.Value)) end
		return "NS[" .. table.concat(s, " ") .. "]"
	elseif t == "EnumItem" then return v.Name
	elseif t == "number" then return string.format("%.4g", v)
	end
	return tostring(v)
end

local PROPS = {
	GuiObject = { "AnchorPoint", "Position", "Size", "BackgroundColor3", "BackgroundTransparency", "ZIndex", "Rotation", "ClipsDescendants", "Visible" },
	ImageLabel = { "Image", "ImageColor3", "ImageTransparency", "ScaleType", "TileSize", "SliceCenter", "SliceScale", "ResampleMode", "ImageRectOffset", "ImageRectSize" },
	ImageButton = { "Image", "ImageColor3", "ImageTransparency", "ScaleType", "SliceCenter" },
	TextLabel = { "Text", "TextSize", "TextScaled", "RichText", "FontFace", "TextColor3", "TextXAlignment", "LineHeight" },
	TextButton = { "Text", "TextScaled", "FontFace", "AutoButtonColor" },
	ScrollingFrame = { "CanvasSize", "AutomaticCanvasSize", "ScrollBarThickness", "ScrollingDirection" },
	CanvasGroup = { "GroupTransparency", "GroupColor3" },
	UIStroke = { "Color", "Thickness", "Transparency", "ApplyStrokeMode", "StrokeSizingMode", "BorderStrokePosition", "LineJoinMode" },
	UICorner = { "CornerRadius" },
	UIGradient = { "Color", "Transparency", "Rotation", "Offset" },
	UIListLayout = { "FillDirection", "Padding", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "Wraps" },
	UIGridLayout = { "CellSize", "CellPadding", "FillDirectionMaxCells" },
	UIPadding = { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" },
	UIScale = { "Scale" },
	UIAspectRatioConstraint = { "AspectRatio", "DominantAxis", "AspectType" },
	UITextSizeConstraint = { "MaxTextSize", "MinTextSize" },
}
local DEFAULT = {
	BackgroundTransparency = "0", ZIndex = "1", Rotation = "0", ClipsDescendants = "false", Visible = "true",
	ImageTransparency = "0", GroupTransparency = "0", Transparency = "0", ImageColor3 = "#ffffff",
	GroupColor3 = "#ffffff", AnchorPoint = "(0,0)", ScaleType = "Stretch", ResampleMode = "Default",
	ImageRectOffset = "(0,0)", ImageRectSize = "(0,0)", SliceScale = "1", SliceCenter = "Rect(0,0,0,0)",
	Offset = "(0,0)", RichText = "false", LineHeight = "1", AutoButtonColor = "true",
}

local out = {}
local classes = {}
local images = {}

local function props(inst: Instance): string
	local s = {}
	local lists = {}
	if inst:IsA("GuiObject") then table.insert(lists, PROPS.GuiObject) end
	if PROPS[inst.ClassName] then table.insert(lists, PROPS[inst.ClassName]) end
	for _, list in lists do
		for _, p in list do
			local ok, v = pcall(function() return (inst :: any)[p] end)
			if ok then
				local f = fmt(v)
				local hiddenBg = p == "BackgroundColor3" and (inst :: any).BackgroundTransparency == 1
				if DEFAULT[p] ~= f and not hiddenBg then table.insert(s, p .. "=" .. f) end
				if p == "Image" and f ~= "" then images[f] = (images[f] or 0) + 1 end
			end
		end
	end
	return table.concat(s, " ")
end

local function walk(inst: Instance, depth: number)
	classes[inst.ClassName] = (classes[inst.ClassName] or 0) + 1
	if SKIP_CLASSES[inst.ClassName] then return end
	if depth <= DEPTH then
		table.insert(out, string.rep("  ", depth) .. inst.Name .. " [" .. inst.ClassName .. "] " .. props(inst))
	elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		-- below the print depth: still inventory every image id (the asset list is half the lesson)
		local img = (inst :: any).Image
		if img ~= "" then images[img] = (images[img] or 0) + 1 end
	end
	for _, c in inst:GetChildren() do walk(c, depth + 1) end
end

assert(ROOT, "set ROOT")
walk(ROOT, 0)
local cs, is = {}, {}
for k, v in classes do table.insert(cs, k .. "=" .. v) end
for k, v in images do table.insert(is, k .. " x" .. v) end
table.sort(cs)
table.sort(is)
return "CLASSES " .. table.concat(cs, " ") .. "\nIMAGES " .. table.concat(is, ", ") .. "\n\n" .. table.concat(out, "\n")
