--!strict
--[[
	SecurityService (TASK-285; FEAT-040; owner request 2026-10-14; Provisional)

	Server half of the security cameras. The client does the viewing (SecurityController); this service only owns the
	prompt and keeps the watcher in place:

	  Prompt   `Prompt_Cameras` (Content.Security.Rules.Anchor), an Attachment made here in front of the screen face of the
	           CCTV monitor (`Workspace.<Folder>.<Monitor>`, or a `<Monitor>` model anywhere in the Workspace while the place
	           still has it loose), tagged `Interactable`, PromptAction `watch_cameras`. InteractionService checks range, life
	           state and the other gates; Run freezes the body (CharacterService:Freeze, reason "Security") and fires
	           `SecurityOpen` to that player.
	  Leave    `SecurityLeave` (c -> s, idempotent), a life state other than Active, or the player leaving releases the freeze.
	  Gate     a watcher's world prompts are refused ("Watching"): the view is far from the body.

	Nothing about the cameras themselves is decided here (which camera, Normal / Night): that is local presentation.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

const rules = Content.Security.Rules
const ANCHOR_TAG = "Interactable"
const GATE = "Security"
const MONITOR_WAIT = 30 -- s the first lookup of the monitor keeps trying (the place may still be loading)

const SecurityService = Modux.Service("SecurityService", {
	Require = { "PlaceService", "PlayerService", "NetService", "RunStateService", "InteractionService", "CharacterService" },
	Priority = 640,
})

function SecurityService:Setup()
	-- players watching the cameras now
	self.Watching = {} :: { [Player]: boolean }
	self.Active = false :: boolean
	self.Anchor = nil :: Attachment?
end

-- The CCTV monitor model: inside the security folder, else a loose one in the Workspace (owner layout before the move).
function SecurityService:Monitor(): Model?
	const folder = workspace:FindFirstChild(rules.Folder)
	const inFolder = if folder ~= nil then folder:FindFirstChild(rules.Monitor) else nil
	const monitor = inFolder or workspace:FindFirstChild(rules.Monitor, true)
	return if monitor ~= nil and monitor:IsA("Model") then monitor else nil
end

-- Makes (once) the prompt anchor in front of the screen face. An authored anchor with the same name is used as it is.
function SecurityService:EnsureAnchor(): Attachment?
	const monitor = self:Monitor()
	if monitor == nil then
		return nil
	end
	const screen = monitor:FindFirstChild(rules.Screen)
	if screen == nil or not screen:IsA("BasePart") then
		warn(`[SecurityService] {monitor:GetFullName()} has no Part "{rules.Screen}": no camera prompt`)
		return nil
	end
	const existing = screen:FindFirstChild(rules.Anchor)
	if existing ~= nil and existing:IsA("Attachment") then
		return existing
	end
	const normal = Vector3.FromNormalId(rules.Face)
	const half = (screen.Size * normal).Magnitude / 2
	const anchor = Instance.new("Attachment")
	anchor.Name = rules.Anchor
	anchor.Position = normal * (half + rules.AnchorOut)
	anchor:SetAttribute("PromptAction", rules.Action)
	anchor.Parent = screen
	CollectionService:AddTag(anchor, ANCHOR_TAG)
	return anchor
end

-- Starts watching: freeze and tell the client.
function SecurityService:Open(player: Player)
	if not self.Watching[player] then
		self.Watching[player] = true
		self.Dependencies.CharacterService:Freeze(player, rules.FreezeReason, true)
	end
	self.Libs.Net.SecurityOpen:fireClient(player, nil)
end

-- Stops watching (any reason). `gone` = the player left: nothing to unfreeze.
function SecurityService:Release(player: Player, gone: boolean?)
	if not self.Watching[player] then
		return
	end
	self.Watching[player] = nil
	if not gone then
		self.Dependencies.CharacterService:Freeze(player, rules.FreezeReason, false)
	end
end

function SecurityService:Register()
	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction(rules.Action, {
		Validate = function(player: Player, _anchor: Instance, _id: number): boolean
			return not self.Watching[player] and self.Dependencies.RunStateService:IsActive(player)
		end,
		Run = function(player: Player, _anchor: Instance, _id: number)
			self:Open(player)
		end,
	})
	interaction:AddGate(GATE, function(player: Player, _action: string, _anchor: Instance): (boolean, string?)
		if self.Watching[player] then
			return false, "Watching"
		end
		return true, nil
	end)
end

SecurityService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Active = true
	self:Register()

	self.Libs.Net.SecurityLeave:onServer(function(_value, player: Player)
		self:Release(player, nil)
	end)
	self.Dependencies.RunStateService.LifeChanged:Connect(function(userId, _old, new)
		if new ~= "Active" then
			const player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				self:Release(player, nil)
			end
		end
	end)
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Release(player, true)
	end)
end)

SecurityService:OnStart(function(self)
	if not self.Active then
		return
	end
	task.spawn(function()
		const deadline = os.clock() + MONITOR_WAIT
		while self:EnsureAnchor() == nil and os.clock() < deadline do
			task.wait(1)
		end
		if self:Monitor() == nil then
			warn(`[SecurityService] no "{rules.Monitor}" monitor in the Workspace: no camera prompt`)
		end
	end)
end)

return SecurityService
