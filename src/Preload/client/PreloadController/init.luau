--!strict
--[[
	PreloadController (owner 2026-10-18: "fazer prelude de tudo": every image and asset loaded before it is needed; the
	customers' faces turned grey / white for a moment while they were served and players could take that for an
	anomaly).

	What loads where:
	  * Critical images (Images.CriticalUi / CriticalWorld: jumpscare face, anomaly looks, horror overlays, HUD icons, tablet photos):
	    the loading screen waits for them (LoadingController:StepAssets).
	  * Face shelf: once RigController warmed the kit, one hidden copy of the face shell per CrewExpressions entry and
	    one head per species head texture (every pack, Blank) and per skin texture (SkinLooks: outfit sheet, atlas, head;
	    every pack) sit far under the map on this client (Folder Workspace.PreloadShelf, local only). The textures stay in
	    use, so a mood swap, the Night pack or a skin previewed on the class screen never shows a texture that is still
	    being fetched or was dropped from memory (owner 2026-10-20: the limited skins were always loading).
	  * Background, after the curtain (LoadingController.Ready), BATCH items per PreloadAsync, GAP s apart:
	    the skin circle icons first (SkinIcons: the class screen is the lobby's first shop), then
	    Images.BackgroundUi / BackgroundWorld (crew / NPC looks, skins, UI art), then every kit under ReplicatedStorage.Assets but Crew
	    (RigController loads that one), then the pre-generated voice lines (Content.VoiceLines) through the one audio
	    LoadQueue as background jobs, Walt's first.
	Image ids go to PreloadAsync wrapped in an ImageLabel (UI) or a Decal (world): a plain id string is reported
	Failure and never downloaded (checked in Studio 2026-10-17). Presentation only: nothing here feeds a rule.
]]
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewLooks = require(ReplicatedStorage.shared.Crew.CrewLooks)
local SkinLooks = require(ReplicatedStorage.shared.Crew.SkinLooks)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local LoadQueue = require(StarterPlayer.StarterPlayerScripts.client.Audio.AudioController.LoadQueue)
local SkinIcons = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassSelect.SkinIcons)
local Images = require(script.Images)

const BATCH = 16 -- items per background PreloadAsync
const GAP = 0.35 -- s between two background batches
const READY_FAILSAFE = 60 -- s: the background starts even if the loading gate never reports Ready
const WARM_FAILSAFE = 20 -- s: the shelf is built even if the kit warm-up never ends
const SHELF_NAME = "PreloadShelf"
const SHELF_ORIGIN = Vector3.new(0, -400, 0) -- under the map, above FallenPartsDestroyHeight (-500)
const SHELF_STEP = 6 -- studs between two shelf pieces
const POLL = 0.25
const VOICE_FIRST = "walt" -- the calls of every night: their lines first
const STAGE_ATTRIBUTE = "PreloadStage" -- local attribute on the LocalPlayer: where the preload is (debug)

const PreloadController = Modux.Controller("PreloadController", {
	Require = { "LoadingController", "RigController" },
	Priority = -900,
})

-- PreloadAsync items for image ids: an ImageLabel for a UI image, a Decal for a world texture (a Decal asks for the
-- 3D texture of the asset, which a UI image may not have: "Asset content representation is being generated")
local function holders(ui: { string }, world: { string }): { Instance }
	const out: { Instance } = {}
	for _, id in ui do
		const label = Instance.new("ImageLabel")
		label.Image = id
		table.insert(out, label)
	end
	for _, id in world do
		const decal = Instance.new("Decal")
		decal.Texture = id
		table.insert(out, decal)
	end
	return out
end

-- PreloadAsync of `items` BATCH at a time, GAP s apart; returns when every batch ran
local function trickle(items: { Instance })
	for first = 1, #items, BATCH do
		const batch = table.move(items, first, math.min(first + BATCH - 1, #items), 1, {})
		pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)
		task.wait(GAP)
	end
end

local function stage(name: string)
	Players.LocalPlayer:SetAttribute(STAGE_ATTRIBUTE, name)
end

local function waitUntil(check: () -> boolean, timeout: number)
	const deadline = os.clock() + timeout
	while not check() and os.clock() < deadline do
		task.wait(POLL)
	end
end

-- shelf copy of a kit piece: its children dropped, out of physics and queries
local function bare(source: MeshPart, name: string): MeshPart
	const part = source:Clone()
	for _, child in part:GetChildren() do
		child:Destroy()
	end
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- any animal's face shell and head mesh will do: the shelf only keeps the textures in use
local function shells(animals: Instance): (MeshPart?, MeshPart?)
	local face: MeshPart? = nil
	local head: MeshPart? = nil
	for _, animal in animals:GetChildren() do
		for _, piece in animal:GetChildren() do
			if piece:IsA("MeshPart") then
				const prefix = string.sub(piece.Name, 1, 5)
				if face == nil and prefix == "Face_" then
					face = piece
				elseif head == nil and prefix == "Head_" then
					head = piece
				end
			end
		end
		if face ~= nil and head ~= nil then
			break
		end
	end
	return face, head
end

function PreloadController:Setup()
	self.Shelf = nil :: Folder?
	self.Done = false :: boolean
end

-- One face shell per expression and one head per head texture, far under the map (local only)
function PreloadController:BuildShelf()
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const crew = if assets ~= nil then assets:FindFirstChild("Crew") else nil
	const animals = if crew ~= nil then crew:FindFirstChild("Animals") else nil
	const expressions = ReplicatedStorage:FindFirstChild("CrewExpressions")
	if animals == nil or expressions == nil then
		warn("[PreloadController] no kit (Assets.Crew.Animals / CrewExpressions): face shelf skipped")
		return
	end
	const faceShell, headShell = shells(animals)
	const shelf = Instance.new("Folder")
	shelf.Name = SHELF_NAME
	local slot = 0
	local function place(part: BasePart)
		part.CFrame = CFrame.new(SHELF_ORIGIN + Vector3.new(slot * SHELF_STEP, 0, 0))
		slot += 1
		part.Parent = shelf
	end
	if faceShell ~= nil then
		for _, expression in expressions:GetChildren() do
			if expression:IsA("SurfaceAppearance") then
				const face = bare(faceShell, "Face_" .. expression.Name)
				face.TextureID = ""
				expression:Clone().Parent = face
				place(face)
			end
		end
	end
	if headShell ~= nil then
		const seen: { [string]: boolean } = {}
		local function head(id: string?, name: string?)
			if id == nil or id == "" or seen[id] then
				return
			end
			seen[id] = true
			const part = bare(headShell, name or "Head")
			part.TextureID = id
			place(part)
		end
		local function sheets(set: SkinLooks.Sheets?, name: string)
			if set ~= nil then
				head(set.Day, name)
				head(set.Mid, name)
				head(set.Night, name)
			end
		end
		for _, look in CrewLooks.Species do
			for _, id in look.Head do
				head(id)
			end
			if look.Blank ~= nil then
				head(look.Blank.Head)
			end
		end
		-- skin textures: any mesh keeps them in use, the UV does not matter here
		for key, look in SkinLooks.BySkin do
			const name = `Skin_{key}`
			sheets({ Day = look.Day, Mid = look.Mid, Night = look.Night }, name)
			sheets(look.Atlas, name)
			sheets(look.Head, name)
		end
	end
	shelf.Parent = Workspace
	self.Shelf = shelf
	shelf:SetAttribute("Pieces", slot)
end

function PreloadController:Background()
	-- images written in code (looks, skins, UI art)
	-- skin circles of the class screen first (their textures are on the shelf)
	stage("Skins")
	const icons: { string } = {}
	for _, id in SkinIcons do
		table.insert(icons, id)
	end
	trickle(holders(icons, {}))
	stage("Images")
	trickle(holders(Images.BackgroundUi, Images.BackgroundWorld))
	-- every kit but the crew (RigController warms that one)
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets ~= nil then
		const kits: { Instance } = {}
		for _, child in assets:GetChildren() do
			if child.Name ~= "Crew" then
				table.insert(kits, child)
			end
		end
		stage("Kits")
		trickle(kits)
	end
	-- pre-generated voice lines: background jobs of the one audio queue (never a burst next to the sounds)
	const ids: { string } = {}
	const rest: { string } = {}
	for _, line in Content.VoiceLines.Lines do
		if line.Id ~= "" then
			table.insert(if line.Speaker == VOICE_FIRST then ids else rest, line.Id)
		end
	end
	table.move(rest, 1, #rest, #ids + 1, ids)
	stage("Voices")
	LoadQueue.Preload(ids)
	stage("Done")
	self.Done = true
end

PreloadController:OnStart(function(self)
	const loading = self.Dependencies.LoadingController
	const rig = self.Dependencies.RigController
	stage("Waiting")
	task.spawn(function()
		waitUntil(function()
			return rig.Warm
		end, WARM_FAILSAFE)
		const ok, problem = pcall(function()
			self:BuildShelf()
		end)
		if not ok then
			warn(`[PreloadController] face shelf failed: {problem}`)
		end
	end)
	task.spawn(function()
		waitUntil(function()
			return Vide.untrack(loading.Ready)
		end, READY_FAILSAFE)
		const ok, problem = pcall(function()
			self:Background()
		end)
		if not ok then
			warn(`[PreloadController] background preload failed: {problem}`)
		end
	end)
end)

return PreloadController
