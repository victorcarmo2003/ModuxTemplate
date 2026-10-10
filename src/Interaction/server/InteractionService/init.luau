--!strict
-- Single responder of Interact (network.md §4.1, T6 Provisional by Q-130; architecture.md §4, §18.3).
-- Owns the EntityId of every Interactable anchor in the Workspace and dispatches each Interact to the action
-- registered by its owner (RegisterAction, called from the owner's OnInit). The client never decides: every packet
-- is checked for rate, target, member state, gates, range and the owner's own rules before Run.
-- Wave 2 (TASK-051, architecture.md §19.3, §19.26 A2, T49): AddGate (life/hide/cutscene owners refuse without a
-- Require back to them, T42), Performed after a clean Run, binding wave from Content, member via RunStateService.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Registry = require(script.Registry)
local Modux = require(ServerScriptService.server.Modux)

-- Reasons fired by Rejected (board TASK-011 v1.1, R4). One reason per discarded packet:
-- rate = above RATE per second; target = unknown id, anchor out of the Workspace, action not on the anchor, not
-- registered or not active in this wave; state = player not an active member, no live character, prompt disabled
-- or the owner's Validate said no; range = farther than Actions[a].Radius + RANGE_SLACK.
-- A gate refusal uses the gate name as reason ("<name>", or "<name>:<detail>" when the gate returns one), so
-- Rejected carries a plain string (Provisional format, TASK-051).
export type RejectReason = "rate" | "range" | "target" | "state"

-- Gate: true lets the request go on; false refuses it, with an optional detail ("Down", "Hidden"...).
export type GateFn = (player: Player, action: string, anchor: Instance) -> (boolean, string?)
export type Gate = { Name: string, Fn: GateFn }

export type Handler = {
	-- Owner's rules (slot free, stock, hand, phase...). Runs serialized per target, right before Run.
	Validate: (player: Player, anchor: Instance, id: number) -> boolean,
	Run: (player: Player, anchor: Instance, id: number) -> (),
}

export type Request = { Player: Player, Action: string }

export type Bucket = { Tokens: number, At: number }

const TAG = "Interactable"
const RATE = 8 -- Interact per second per player, burst included (network.md §4.1)
const RANGE_SLACK = 2 -- studs added to Actions[a].Radius on the server (network.md §4.1)
-- Wave this build binds (content-data.md §6.8 RunParams.BindingWave). Actions with Content.Actions[a].Wave above it
-- are refused even if someone registers them.
-- DEPENDS ON TASK-047: RunParams has no BindingWave field yet, so it is read untyped with fallback 1 (wave 1
-- behavior). When 047 lands, replace with the typed `Content.RunParams.BindingWave` and drop the cast.
const BINDING_WAVE: number = (Content.RunParams :: any).BindingWave or 1

const InteractionService = Modux.Service(
	"InteractionService",
	{ Require = { "PlaceService", "PlayerService", "NetService", "RunStateService" }, Priority = 730 }
)

function InteractionService:Setup()
	self.Registry = Registry.new() :: Registry.Registry
	self.Handlers = {} :: { [string]: Handler }
	self.Queues = {} :: { [number]: { Request } }
	self.Buckets = {} :: { [Player]: Bucket }
	self.Watched = {} :: { [Instance]: RBXScriptConnection }
	self.Gates = {} :: { Gate }
	self.Rejected = self.Libs.Signal.new() :: SignalLib.Signal<Player, number, string, string>
	-- Fired after Run returned without error (player, action, anchor, id). Listeners run inside the per-target
	-- queue: they must not yield (BossService hints, architecture.md §19.10).
	self.Performed = self.Libs.Signal.new() :: SignalLib.Signal<Player, string, Instance, number>
end

-- Called by owners in their OnInit (lower priority than 730, so Handlers exists). One owner per action key.
function InteractionService:RegisterAction(key: string, handler: Handler)
	if Content.Actions.ByKey[key] == nil then
		error(`[InteractionService] unknown action "{key}" (not in Content.Actions)`, 2)
	end
	if self.Handlers[key] ~= nil then
		error(`[InteractionService] action "{key}" already registered`, 2)
	end
	self.Handlers[key] = handler
end

-- Called by state owners in their OnInit (VitalService "Vital", HideService "Hide", ...; T42, T49). Gates run in
-- registration order; the first one that refuses stops the request. One gate per name.
function InteractionService:AddGate(name: string, fn: GateFn)
	for _, gate in self.Gates do
		if gate.Name == name then
			error(`[InteractionService] gate "{name}" already added`, 2)
		end
	end
	table.insert(self.Gates, { Name = name, Fn = fn })
end

function InteractionService:Get(id: number): Instance?
	return Registry.get(self.Registry, id)
end

function InteractionService:IdOf(anchor: Instance): number?
	return Registry.idOf(self.Registry, anchor)
end

function InteractionService:Position(anchor: Instance): Vector3?
	return Registry.position(anchor)
end

-- Global prompt state of an anchor (architecture.md §18.2). text = nil falls back to Content.Actions[a].Text.
function InteractionService:SetPrompt(anchor: Instance, enabled: boolean, text: string?)
	anchor:SetAttribute("PromptEnabled", enabled)
	anchor:SetAttribute("PromptText", text)
end

-- Only when the hold differs from the table; nil falls back to Content.Actions[a].Hold.
function InteractionService:SetPromptHold(anchor: Instance, hold: number?)
	anchor:SetAttribute("PromptHold", hold)
end

function InteractionService:IsActive(action: string): boolean
	const row = Content.Actions.ByKey[action]
	return row ~= nil and row.Wave <= BINDING_WAVE and self.Handlers[action] ~= nil
end

function InteractionService:Track(anchor: Instance)
	const inWorkspace = anchor:IsDescendantOf(workspace)
	const id = Registry.idOf(self.Registry, anchor)
	if inWorkspace and id == nil then
		const newId = Registry.add(self.Registry, anchor, os.clock())
		if newId == nil then
			warn(`[InteractionService] no free EntityId for {anchor:GetFullName()}`)
			return
		end
		if anchor:GetAttribute("PromptEnabled") == nil then
			const action = anchor:GetAttribute("PromptAction")
			anchor:SetAttribute("PromptEnabled", type(action) == "string" and self:IsActive(action))
		end
		anchor:SetAttribute("EntityId", newId)
	elseif not inWorkspace and id ~= nil then
		Registry.remove(self.Registry, anchor, os.clock())
		anchor:SetAttribute("EntityId", nil)
	end
end

function InteractionService:Watch(anchor: Instance)
	if self.Watched[anchor] ~= nil then
		return
	end
	-- CollectionService only reports entering/leaving the DataModel; moving in or out of the Workspace (NPC rig
	-- pooled in ServerStorage) comes through AncestryChanged.
	self.Watched[anchor] = anchor.AncestryChanged:Connect(function()
		self:Track(anchor)
	end)
	self:Track(anchor)
end

function InteractionService:Unwatch(anchor: Instance)
	const connection = self.Watched[anchor]
	if connection ~= nil then
		connection:Disconnect()
		self.Watched[anchor] = nil
	end
	if Registry.remove(self.Registry, anchor, os.clock()) ~= nil and anchor.Parent ~= nil then
		anchor:SetAttribute("EntityId", nil)
	end
end

-- Token bucket: RATE tokens, refilled at RATE per second.
function InteractionService:Allow(player: Player): boolean
	const now = os.clock()
	local bucket = self.Buckets[player]
	if bucket == nil then
		bucket = { Tokens = RATE, At = now }
		self.Buckets[player] = bucket
	end
	bucket.Tokens = math.min(RATE, bucket.Tokens + (now - bucket.At) * RATE)
	bucket.At = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

-- Member check (TASK-051, closes the TASK-011 note): on the Run place only an Active member of RunStateService acts;
-- other places (lobby) have no members, only the live character counts. Down/Spectator/hidden come from gates.
function InteractionService:IsMemberActive(player: Player): boolean
	if not self.Dependencies.PlaceService:Is("Run") then
		return true
	end
	return self.Dependencies.RunStateService:IsActive(player)
end

-- Root of a live character, or nil.
function InteractionService:RootOf(player: Player): BasePart?
	if player.Parent == nil then
		return nil
	end
	const character = player.Character
	if character == nil then
		return nil
	end
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	const root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

function InteractionService:Reject(player: Player, id: number, action: string, reason: RejectReason | string)
	self.Rejected:Fire(player, id, action, reason)
end

-- Runs the gates in registration order; returns the reject reason of the first refusal, nil when all pass.
-- A gate that errors refuses (fail closed) with its name as reason.
function InteractionService:CheckGates(player: Player, action: string, anchor: Instance): string?
	for _, gate in self.Gates do
		const ok, allowed, detail = pcall(gate.Fn, player, action, anchor)
		if not ok then
			warn(`[InteractionService] gate "{gate.Name}" errored: {allowed}`)
			return gate.Name
		end
		if allowed ~= true then
			return if type(detail) == "string" and detail ~= "" then `{gate.Name}:{detail}` else gate.Name
		end
	end
	return nil
end

-- Full check + Run of one request. Called only from Drain, so requests on the same target never overlap.
function InteractionService:Process(player: Player, id: number, action: string)
	const anchor = Registry.get(self.Registry, id)
	if anchor == nil or not anchor:IsDescendantOf(workspace) then
		return self:Reject(player, id, action, "target")
	end
	if anchor:GetAttribute("PromptAction") ~= action then
		return self:Reject(player, id, action, "target")
	end
	const row = Content.Actions.ByKey[action]
	const handler = self.Handlers[action]
	if row == nil or row.Wave > BINDING_WAVE or handler == nil then
		return self:Reject(player, id, action, "target")
	end

	if not self:IsMemberActive(player) then
		return self:Reject(player, id, action, "state")
	end
	const root = self:RootOf(player)
	if root == nil then
		return self:Reject(player, id, action, "state")
	end

	const refused = self:CheckGates(player, action, anchor)
	if refused ~= nil then
		return self:Reject(player, id, action, refused)
	end

	const position = Registry.position(anchor)
	if position == nil or (root.Position - position).Magnitude > row.Radius + RANGE_SLACK then
		return self:Reject(player, id, action, "range")
	end

	if anchor:GetAttribute("PromptEnabled") == false then
		return self:Reject(player, id, action, "state")
	end

	const validated, allowed = pcall(handler.Validate, player, anchor, id)
	if not validated then
		warn(`[InteractionService] Validate of "{action}" errored: {allowed}`)
		return self:Reject(player, id, action, "state")
	end
	if allowed ~= true then
		return self:Reject(player, id, action, "state")
	end

	const ran, err = pcall(handler.Run, player, anchor, id)
	if not ran then
		warn(`[InteractionService] Run of "{action}" errored: {err}`)
		return
	end
	self.Performed:Fire(player, action, anchor, id)
end

-- Serializes requests per target: the first request on an id drains the queue; requests arriving meanwhile (same
-- frame, or while a Run yields) wait their turn and are validated against the state the previous one left.
-- Base of "only one receives" (FEAT-006, network.md §3.5).
function InteractionService:Drain(player: Player, id: number, action: string)
	const pending = self.Queues[id]
	if pending ~= nil then
		table.insert(pending, { Player = player, Action = action })
		return
	end
	const queue: { Request } = { { Player = player, Action = action } }
	self.Queues[id] = queue
	local index = 1
	while index <= #queue do
		const request = queue[index]
		self:Process(request.Player, id, request.Action)
		index += 1
	end
	self.Queues[id] = nil
end

InteractionService:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Interact:onServer(function(value, player: Player)
		const id = value.Id
		const action = value.Action
		if not self:Allow(player) then
			self:Reject(player, id, action, "rate")
			return
		end
		self:Drain(player, id, action)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.Buckets[player] = nil
	end)
end)

-- Scan in OnStart (README): every owner registered its actions in OnInit, so the default PromptEnabled is right.
-- Initial ids follow GetFullName order (architecture.md §18.3).
InteractionService:OnStart(function(self)
	const anchors = CollectionService:GetTagged(TAG)
	const names: { [Instance]: string } = {}
	for _, anchor in anchors do
		names[anchor] = anchor:GetFullName()
	end
	table.sort(anchors, function(a: Instance, b: Instance): boolean
		return names[a] < names[b]
	end)
	for _, anchor in anchors do
		self:Watch(anchor)
	end

	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(anchor)
		self:Watch(anchor)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(anchor)
		self:Unwatch(anchor)
	end)
end)

return InteractionService
