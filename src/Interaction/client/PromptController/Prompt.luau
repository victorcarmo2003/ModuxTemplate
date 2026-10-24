--!strict
-- One prompt per `Interactable` anchor (port of AnimalPlane `Prompt`, architecture.md §13 and §18.3).
-- Reads the anchor's attributes (EntityId, PromptAction, PromptEnabled, PromptText, PromptHold, Ingredient, Package,
-- Slot) and keeps Vide sources for the PromptBillboard. Owns no input and no network: PromptController targets,
-- holds and fires Interact. Plain module (not a Modux module); dependencies come in through `Hooks`.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local PromptBillboard = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PromptBillboard)
local Rules = require(script.Parent.Rules)

export type State = PromptBillboard.State

export type Hooks = {
	Parent: Instance, -- PlayerGui: taps on the pill only arrive there
	KeyLabel: () -> string,
	Tappable: () -> boolean, -- the pill takes taps (touch only: a clickable pill under the locked cursor stops the camera)
	OnPress: (prompt: Prompt) -> (),
	OnRelease: (prompt: Prompt) -> (),
}

export type Prompt = {
	Anchor: Instance,
	Owner: Instance?, -- Station ancestor (StationId, Ingredient)
	Rig: Instance?, -- AnimalRig ancestor (NpcId), runtime customer anchors
	Vehicle: Instance?, -- `Vehicle`-tagged ancestor (its `Shutter` attribute names the `shutter_toggle` pill)
	MemberId: number?, -- UserId of the player character the anchor sits on (Prompt_Give); resolved lazily
	Id: number?, -- EntityId; nil = not registered by the server yet
	Enabled: boolean, -- PromptEnabled (absent = true)
	Radius: number,
	Hold: number,
	Target: Rules.Target,
	State: Vide.Source<State>,
	Text: Vide.Source<string>,
	Hint: Vide.Source<string>, -- suffix on the pill ("hold R: Refuse"): the controller owns it, never part of `Text`
	Holding: Vide.Source<boolean>,
	HoldDuration: Vide.Source<number>,
	Done: Vide.Source<number>, -- completion counter: +1 = the billboard plays its pop
	Gui: BillboardGui?,
	Unmount: (() -> ())?,
	Connections: { RBXScriptConnection },
}

const NO_ACTION = ""
const SHUTTER_ACTION = "shutter_toggle"

local function numberAttribute(instance: Instance?, name: string): number?
	if instance == nil then
		return nil
	end
	const value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

local function stringAttribute(instance: Instance?, name: string): string?
	if instance == nil then
		return nil
	end
	const value = instance:GetAttribute(name)
	return if typeof(value) == "string" and value ~= "" then value else nil
end

local function ancestorWith(instance: Instance, test: (Instance) -> boolean): Instance?
	local current = instance.Parent
	while current and current ~= workspace do
		if test(current) then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- "Add {item}" -> "Add Ketchup"; "Buy {item} — ${price}" -> "Buy Buns — $4". {upgrade} is filled by the owner
-- through PromptText; the fallback keeps the sentence readable.
local function format(text: string, ingredient: string?, package: string?): string
	const packageRow = if package then Content.Packages.ByKey[package] else nil
	const ingredientRow = if ingredient then Content.Ingredients.ByKey[ingredient] else nil
	const item = if packageRow then packageRow.Name elseif ingredientRow then ingredientRow.Name else "Item"
	return (
		string.gsub(text, "{(%w+)}", function(field: string): string
			if field == "item" then
				return item
			elseif field == "price" then
				return if packageRow then tostring(packageRow.Price) else "?"
			elseif field == "upgrade" then
				return "Upgrade"
			end
			return field
		end)
	)
end

const Prompt = {}

-- UserId of the player whose character holds the anchor. Player.Character may replicate after the anchor, so it is
-- retried on every Refresh until found (TASK-078).
local function memberOf(anchor: Instance): number?
	local current = anchor.Parent
	while current and current ~= workspace do
		if current:IsA("Model") then
			const player = Players:GetPlayerFromCharacter(current)
			if player then
				return player.UserId
			end
		end
		current = current.Parent
	end
	return nil
end

-- Rereads every attribute the prompt depends on. Cheap; called on any attribute change of the anchor or owners.
function Prompt.Refresh(self: Prompt)
	const anchor = self.Anchor
	if self.MemberId == nil then
		self.MemberId = memberOf(anchor)
	end
	self.Id = numberAttribute(anchor, "EntityId")
	const enabled = anchor:GetAttribute("PromptEnabled")
	self.Enabled = enabled ~= false

	const actionKey = stringAttribute(anchor, "PromptAction") or NO_ACTION
	const action = Content.Actions.ByKey[actionKey]
	const ingredient = stringAttribute(anchor, "Ingredient") or stringAttribute(self.Owner, "Ingredient")
	const package = stringAttribute(anchor, "Package")

	self.Target = {
		Action = actionKey,
		Ingredient = ingredient,
		StationId = numberAttribute(self.Owner, "StationId"),
		Slot = numberAttribute(anchor, "Slot"),
		NpcId = numberAttribute(self.Rig, "NpcId"),
		MemberId = self.MemberId,
		OutsideOnly = anchor:GetAttribute("OutsideOnly") == true,
	}

	if action == nil then
		self.Radius = 0
		self.Hold = 0
		self.Text("")
		self.HoldDuration(0)
		return
	end

	self.Radius = action.Radius
	self.Hold = math.max(numberAttribute(anchor, "PromptHold") or action.Hold, 0)
	if actionKey == SHUTTER_ACTION and self.Vehicle then
		-- The window state is the vehicle's attribute (DEC-221): read it, so the pill never lags the flap.
		self.Text(Rules.ShutterText(self.Vehicle:GetAttribute("Shutter") == true))
	else
		self.Text(stringAttribute(anchor, "PromptText") or format(action.Text, ingredient, package))
	end
	self.HoldDuration(self.Hold)
end

-- Registered by the server, with a known action, enabled for the party.
function Prompt.IsLive(self: Prompt): boolean
	return self.Id ~= nil and self.Enabled and self.Radius > 0 and self.Anchor:IsDescendantOf(workspace)
end

function Prompt.Position(self: Prompt): Vector3?
	const anchor = self.Anchor
	if anchor:IsA("Attachment") then
		return anchor.WorldPosition
	elseif anchor:IsA("BasePart") then
		return anchor.Position
	end
	return nil
end

function Prompt.SetState(self: Prompt, state: State)
	if self.State() ~= state then
		self.State(state)
	end
end

function Prompt.SetHolding(self: Prompt, holding: boolean)
	if self.Holding() ~= holding then
		self.Holding(holding)
	end
end

-- The interaction was just sent: the billboard plays its completion pop.
function Prompt.Celebrate(self: Prompt)
	self.Done(self.Done() + 1)
end

function Prompt.new(anchor: Instance, hooks: Hooks): Prompt
	const owner = ancestorWith(anchor, function(instance)
		return CollectionService:HasTag(instance, "Station")
	end)
	const rig = ancestorWith(anchor, function(instance)
		return CollectionService:HasTag(instance, "AnimalRig") or instance:GetAttribute("NpcId") ~= nil
	end)
	const vehicle = ancestorWith(anchor, function(instance)
		return CollectionService:HasTag(instance, "Vehicle")
	end)

	const self: Prompt = {
		Anchor = anchor,
		Owner = owner,
		Rig = rig,
		Vehicle = vehicle,
		MemberId = nil,
		Id = nil,
		Enabled = false,
		Radius = 0,
		Hold = 0,
		Target = { Action = NO_ACTION },
		State = Vide.source("Hidden" :: State),
		Text = Vide.source(""),
		Hint = Vide.source(""),
		Holding = Vide.source(false),
		HoldDuration = Vide.source(0),
		Done = Vide.source(0),
		Gui = nil,
		Unmount = nil,
		Connections = {},
	}

	Prompt.Refresh(self)

	const refresh = function()
		Prompt.Refresh(self)
	end
	table.insert(self.Connections, anchor.AttributeChanged:Connect(refresh))
	if owner then
		table.insert(self.Connections, owner.AttributeChanged:Connect(refresh))
	end
	if rig then
		table.insert(self.Connections, rig:GetAttributeChangedSignal("NpcId"):Connect(refresh))
	end
	if vehicle then
		table.insert(self.Connections, vehicle:GetAttributeChangedSignal("Shutter"):Connect(refresh))
	end

	const unmount, gui = Vide.root(function()
		return PromptBillboard({
			Name = "Prompt",
			Adornee = anchor,
			State = self.State,
			Text = function()
				return self.Text() .. self.Hint()
			end,
			KeyLabel = hooks.KeyLabel,
			Tappable = hooks.Tappable,
			Holding = self.Holding,
			HoldDuration = self.HoldDuration,
			Done = self.Done,
			OnPress = function()
				hooks.OnPress(self)
			end,
			OnRelease = function()
				hooks.OnRelease(self)
			end,
		})
	end)
	gui.Parent = hooks.Parent
	self.Gui = gui
	self.Unmount = unmount

	return self
end

function Prompt.Destroy(self: Prompt)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)

	const unmount = self.Unmount
	if unmount then
		self.Unmount = nil
		unmount()
	end
	const gui = self.Gui
	if gui then
		self.Gui = nil
		gui:Destroy()
	end
end

return table.freeze(Prompt)
