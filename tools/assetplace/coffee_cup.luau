--!nocheck
--[[
	coffee_cup.luau: prepares the coffee cup the OWNER built next to the coffee machine (2026-10-12) so that
	CoffeeCupController can rise / sink its inner coffee surface. Studio snippet, Edit mode. Moves and deletes NOTHING:
	it tags the model, writes attributes and (only if needed) anchors parts that were left unanchored.

	Call (tools/studio/README.md, run_snippet):
		run("coffee_cup")                 -- report only (DRY_RUN): what it found and what it would write
		run("coffee_cup", "apply")        -- tag + attributes (idempotent: marks `CoffeeCupV1`)
		run("coffee_cup", "undo")         -- removes tag + attributes, restores Anchored of the parts it anchored

	What it reads from Studio (nothing is typed by hand):
	  * the cup = Model named MODEL_NAME (Workspace root), or the one that already has the tag
	  * the surface = the Part named SURFACE (the brown inner coffee), the body = the BODY MeshPart/Union (the cream cup)
	  * CupFullCFrame = surface CFrame in body space RIGHT NOW (the owner left it full); CupFullY = its height above the body
	  * CupStation = MapId of the coffee machine station (the nearest Model tagged Station with StationKind coffee_machine)
	  * CupEmptyOffset = how far the surface sinks: the surface height minus a small margin, kept inside the body
	Values are Provisional (Content.CoffeeCup).
]]

local CollectionService = game:GetService("CollectionService")
local MODE = (...) or "report"
local APPLY = MODE == "apply"
local UNDO = MODE == "undo"
local MARK = "CoffeeCupV1"
local TAG = "CoffeeCup"
local MODEL_NAME = "ManFaceMug"
local SURFACE = "Part" -- inner coffee (brown cylinder)
local BODY = "Intersection" -- cream cup body (carries the face texture)
local EMPTY_MARGIN = 0.05 -- the empty surface stays this far above the cup bottom

local out = {}
local function say(...)
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	table.insert(out, table.concat(parts, " "))
end

local cup
for _, inst in CollectionService:GetTagged(TAG) do
	cup = inst
	break
end
if not cup then
	local found = workspace:FindFirstChild(MODEL_NAME)
	if found and found:IsA("Model") then
		cup = found
	end
end
if not cup then
	return "ERROR: cup model not found (Workspace." .. MODEL_NAME .. " or any instance tagged " .. TAG .. ")"
end

local ATTRS = { "CupStation", "CupFillSurface", "CupBody", "CupFullCFrame", "CupFullY", "CupEmptyOffset", MARK }

if UNDO then
	for _, d in cup:GetDescendants() do
		local was = d:GetAttribute("CupOrigAnchored")
		if d:IsA("BasePart") and was ~= nil then
			d.Anchored = was
			d:SetAttribute("CupOrigAnchored", nil)
			say("restored Anchored", tostring(was), d.Name)
		end
	end
	for _, a in ATTRS do
		cup:SetAttribute(a, nil)
	end
	CollectionService:RemoveTag(cup, TAG)
	say("undo: tag + attributes removed from", cup:GetFullName())
	return table.concat(out, "\n")
end

local surface = cup:FindFirstChild(SURFACE)
local body = cup:FindFirstChild(BODY)
if not (surface and surface:IsA("BasePart")) then
	return "ERROR: surface part '" .. SURFACE .. "' not found in " .. cup:GetFullName()
end
if not (body and body:IsA("BasePart")) then
	return "ERROR: body part '" .. BODY .. "' not found in " .. cup:GetFullName()
end

-- full pose: only first time (a second run keeps the stored one, so a half-tweened surface can not corrupt it)
local fullRel = cup:GetAttribute("CupFullCFrame")
if typeof(fullRel) ~= "CFrame" then
	fullRel = body.CFrame:ToObjectSpace(surface.CFrame)
end
local fullY = fullRel.Position.Y

-- Station: nearest coffee machine
local station, best = nil, math.huge
for _, s in CollectionService:GetTagged("Station") do
	if s:GetAttribute("StationKind") == "coffee_machine" and s:IsA("Model") then
		local d = (s:GetPivot().Position - body.Position).Magnitude
		if d < best then
			station, best = s, d
		end
	end
end
local stationId = station and station:GetAttribute("MapId") or "TRL-COFFEE"

-- how far down: the surface top stays above the cup bottom
local bodyBottom = -body.Size.Y / 2 -- body space (the body is upright: Intersection rotation checked below)
local surfaceHeight = surface.Size.X -- the owner's cylinder lies on its X axis (rotated -90 about Z): X = height
local emptyOffset = math.max(0.1, math.floor((surfaceHeight - EMPTY_MARGIN) * 100) / 100)

say("cup", cup:GetFullName(), "| surface", surface.Name, surface.ClassName, "| body", body.Name, body.ClassName)
say(string.format("surface size (%.2f, %.2f, %.2f) pos y %.3f | body size (%.2f, %.2f, %.2f) pos y %.3f",
	surface.Size.X, surface.Size.Y, surface.Size.Z, surface.Position.Y, body.Size.X, body.Size.Y, body.Size.Z, body.Position.Y))
say(string.format("CupFullY %.3f (above body centre) | CupEmptyOffset %.2f | bottom of body %.3f", fullY, emptyOffset, bodyBottom))
say("CupStation", stationId, station and ("(nearest coffee machine " .. string.format("%.1f", best) .. " studs away)") or "(no station found, default)")

local unanchored = {}
for _, d in cup:GetDescendants() do
	if d:IsA("BasePart") and not d.Anchored then
		table.insert(unanchored, d)
	end
end
say("unanchored parts (would fall in Play):", #unanchored)
for _, d in unanchored do
	say("   ", d.Name, d.ClassName)
end

if not APPLY then
	say("DRY_RUN: nothing written. run('coffee_cup', 'apply') to write; 'undo' to revert.")
	return table.concat(out, "\n")
end

cup:SetAttribute("CupStation", stationId)
cup:SetAttribute("CupFillSurface", surface.Name)
cup:SetAttribute("CupBody", body.Name)
cup:SetAttribute("CupFullCFrame", fullRel)
cup:SetAttribute("CupFullY", fullY)
cup:SetAttribute("CupEmptyOffset", emptyOffset)
cup:SetAttribute(MARK, true)
CollectionService:AddTag(cup, TAG)
for _, d in unanchored do
	if d:GetAttribute("CupOrigAnchored") == nil then
		d:SetAttribute("CupOrigAnchored", false)
	end
	d.Anchored = true
end
say("applied: tag", TAG, "+ attributes; anchored", #unanchored, "part(s)")
return table.concat(out, "\n")
