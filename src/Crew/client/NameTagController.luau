--!strict
--[[
	NameTagController (owner request 2026-10-16, Provisional): over the head of every OTHER player a name tag (the
	Mates.Tag card: his colour chip, his display name, stroke in his colour) and an outline Highlight on his character
	in the same colour (Crew/shared/CrewColor). The colour is the one the co-op prep uses for his arm, his ghost item and
	his grill claim, so the crew tells who is who anywhere.

	  - Built on every character spawn, recoloured when the `CrewColor` attribute arrives or changes.
	  - Both live inside the character, so the prep mode (Prep/Mates, which switches off the BillboardGui / Highlight of
	    other characters while the player cooks) hides and restores them like the rest.
	  - Highlight: outline only, Occluded (never seen through walls: hiding stays fair at night); at most MAX_OUTLINES
	    (the nearest), none at Budget.LowQuality. The tag fades out past Presence.Range.
	Local only; the server never sees these instances.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local CrewColor = require(ReplicatedStorage.shared.Crew.CrewColor)
local Mates = require(StarterPlayer.StarterPlayerScripts.client.Prep.PrepController.Mates)

const TAG_NAME = "CrewTag"
const OUTLINE_NAME = "CrewOutline"
const MAX_OUTLINES = 8 -- of the Highlight budget (31 per client)
const REFRESH = 0.5 -- s between two nearest-outline passes
const HEAD_LIFT = 1.4 -- studs over the head (Mates.Tag adds Presence.Tag.Lift)

type Entry = { Connections: { RBXScriptConnection } }

const LOBBY_INK = Color3.fromHex("#2B2233") -- lobby tag: name only, neutral Ink edge, no colour chip, no outline

const NameTagController = Modux.Controller("NameTagController", { Require = { "PlaceController" }, Priority = 300 })

function NameTagController:Setup()
	self.Entries = {} :: { [Player]: Entry }
end

-- Colours and outlines are for the run only (owner 2026-10-16): in the lobby the tag shows just the name
function NameTagController:InRun(): boolean
	return self.Dependencies.PlaceController:Is("Run")
end

-- Tag + outline on `character` of `player`, replacing any older ones
function NameTagController:Decorate(player: Player, character: Model)
	const head = character:WaitForChild("Head", 10)
	if head == nil or character.Parent == nil then
		return
	end
	for _, name in { TAG_NAME, OUTLINE_NAME } do
		const old = character:FindFirstChild(name)
		if old ~= nil then
			old:Destroy()
		end
	end
	const inRun = self:InRun()
	const color = if inRun then CrewColor.Of(player) else LOBBY_INK
	const tag = Mates.Tag(player.DisplayName, color, head, character)
	tag.Name = TAG_NAME
	tag.StudsOffsetWorldSpace += Vector3.new(0, HEAD_LIFT, 0)
	if not inRun then
		const chip = tag:FindFirstChild("Chip", true)
		if chip ~= nil and chip:IsA("GuiObject") then
			chip.Visible = false
		end
		return -- no outline in the lobby
	end

	const outline = Instance.new("Highlight")
	outline.Name = OUTLINE_NAME
	outline.FillTransparency = 1
	outline.OutlineColor = color
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Adornee = character
	outline.Enabled = false -- the nearest-pass turns it on
	outline.Parent = character
end

-- Recolour in place (attribute arrived / changed)
function NameTagController:Recolor(player: Player)
	const character = player.Character
	if character == nil or not self:InRun() then
		return
	end
	const color = CrewColor.Of(player)
	const tag = character:FindFirstChild(TAG_NAME)
	if tag ~= nil then
		for _, item in tag:GetDescendants() do
			if item:IsA("UIStroke") and item.Parent ~= nil and item.Parent.Name == "Card" then
				item.Color = color
			elseif item:IsA("Frame") and item.Name == "Chip" then
				item.BackgroundColor3 = color
			end
		end
	end
	const outline = character:FindFirstChild(OUTLINE_NAME)
	if outline ~= nil and outline:IsA("Highlight") then
		outline.OutlineColor = color
	end
end

function NameTagController:Track(player: Player)
	if player == Players.LocalPlayer or self.Entries[player] ~= nil then
		return
	end
	const entry: Entry = { Connections = {} }
	self.Entries[player] = entry
	table.insert(entry.Connections, player.CharacterAdded:Connect(function(character)
		self:Decorate(player, character)
	end))
	table.insert(entry.Connections, player:GetAttributeChangedSignal(CrewColor.Attribute):Connect(function()
		self:Recolor(player)
	end))
	const character = player.Character
	if character ~= nil then
		task.spawn(function()
			self:Decorate(player, character)
		end)
	end
end

function NameTagController:Untrack(player: Player)
	const entry = self.Entries[player]
	if entry == nil then
		return
	end
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
	self.Entries[player] = nil
end

-- Outline on the MAX_OUTLINES nearest characters only (the others keep their tag)
function NameTagController:RefreshOutlines()
	const me = Players.LocalPlayer.Character
	if me ~= nil and me:GetAttribute("Working") ~= nil then
		return -- cooking: Prep/Mates owns the other characters' Highlights until it restores them
	end
	const myRoot = if me ~= nil then me:FindFirstChild("HumanoidRootPart") else nil
	const origin = if myRoot ~= nil and myRoot:IsA("BasePart") then myRoot.Position else workspace.CurrentCamera.CFrame.Position
	const low = Mates.LowQuality()
	type Item = { Outline: Highlight, Distance: number }
	const list: { Item } = {}
	for player in self.Entries do
		const character = player.Character
		const outline = if character ~= nil then character:FindFirstChild(OUTLINE_NAME) else nil
		if character ~= nil and outline ~= nil and outline:IsA("Highlight") then
			table.insert(list, { Outline = outline, Distance = (character:GetPivot().Position - origin).Magnitude })
		end
	end
	table.sort(list, function(a: Item, b: Item): boolean
		return a.Distance < b.Distance
	end)
	for index, item in list do
		const on = not low and index <= MAX_OUTLINES
		if item.Outline.Enabled ~= on then
			item.Outline.Enabled = on
		end
	end
end

NameTagController:OnStart(function(self)
	self:Setup()
	Players.PlayerAdded:Connect(function(player)
		self:Track(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Untrack(player)
	end)
	for _, player in Players:GetPlayers() do
		self:Track(player)
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= REFRESH then
			elapsed = 0
			self:RefreshOutlines()
		end
	end)
end)

return NameTagController
