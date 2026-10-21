--!strict
--[[
	ProximityFadeController (owner request 2026-10-20, Provisional)

	Players never collide (CharacterService DEC-175, LobbyService), so two players can stand inside each other. When
	another player's character is very close to ours, it turns half see-through on this client, so it never blocks the
	view. Fade starts at FADE_START studs (root to root) and reaches MAX_FADE at FADE_FULL studs.

	Local only (LocalTransparencyModifier): the server and the other clients never see it. Only parts this controller
	faded are written, and they go back to 0 when the player walks away. Run and lobby alike.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const FADE_START = 4 -- studs: no fade from here out
const FADE_FULL = 2 -- studs: MAX_FADE from here in
const MAX_FADE = 0.6 -- LocalTransparencyModifier at FADE_FULL

const ProximityFadeController = Modux.Controller("ProximityFadeController", { Priority = 300 })

function ProximityFadeController:Setup()
	-- characters faded right now, with the last fade written
	self.Faded = setmetatable({}, { __mode = "k" }) :: { [Model]: number }
end

local function rootOf(character: Model?): BasePart?
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function apply(character: Model, fade: number)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.LocalTransparencyModifier = fade
		end
	end
end

function ProximityFadeController:Step()
	const myRoot = rootOf(Players.LocalPlayer.Character)
	const seen: { [Model]: boolean } = {}
	if myRoot ~= nil then
		for _, player in Players:GetPlayers() do
			const character = player.Character
			const root = rootOf(character)
			if player == Players.LocalPlayer or character == nil or root == nil then
				continue
			end
			const distance = (root.Position - myRoot.Position).Magnitude
			if distance >= FADE_START then
				continue
			end
			const t = math.clamp((FADE_START - distance) / (FADE_START - FADE_FULL), 0, 1)
			const fade = math.floor(t * MAX_FADE * 20 + 0.5) / 20 -- steps of 0.05: rewrite only on change
			seen[character] = true
			if self.Faded[character] ~= fade then
				self.Faded[character] = fade
				apply(character, fade)
			end
		end
	end
	for character in self.Faded do
		if not seen[character] then
			self.Faded[character] = nil
			apply(character, 0)
		end
	end
end

ProximityFadeController:OnStart(function(self)
	self:Setup()
	RunService.Heartbeat:Connect(function()
		self:Step()
	end)
end)

return ProximityFadeController
