--!strict
--[[
	HintService (owner request 2026-10-22, Provisional; Content.Hints). Run place only.

	Walt's notes: the sheet of paper on the front counter where the tip jar used to be (MapId Content.Hints.Rules.MapId,
	MAP01_Restaurant.Trailer.Front.HintNote). Single writer of the Hints set (record 1).
	  Written  the last night whose tip is on the paper (0 = none). Night k's tip is written while Walt says the night's rule:
	           its night call (NightCall k, or the NightRepeat) reaches its last line (owner 2026-10-22; was: after the Call
	           phase, Rules.CallWait s at most). The client hears the pencil when the record rises.
	  Snapshot "Hn" = Written (a repeated night goes back to the shift start, so its tip is written again after its call;
	           a Resume keeps the paper).
	  Prompt   read_hints on the Attachment Rules.Anchor of the paper (made at runtime when the place has none; attributes
	           before the tag, InteractionService reads them when tagged): HintOpen to that player. Reading changes nothing
	           on the server.
	Dev (Commands/Hint.luau): DevWrite, DevReset, Open, ArmScare, DevState.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

const RULES = Content.Hints.Rules
const RECORD = 1
const ANCHOR_TAG = "Interactable"
const SNAPSHOT = "Hn"
const NIGHT_MAX = 255 -- Hints.Night wire range
const TICK_RATE = 4 -- Hz
-- Calls of a night's Call phase: the tip waits for them
const CALL_KINDS: { [string]: boolean } =
	{ NightCall = true, NightRepeat = true, LostCritical = true, LostLastChance = true, Tutorial = true }
-- Player attribute the dev scare test sets (HintController reads it when the player leaves the paper)
const SCARE_ATTRIBUTE = "HintScareTest"

const HintService = Modux.Service("HintService", {
	Require = { "PlaceService", "NetService", "RoundService", "BossService", "InteractionService", "RunStateService" },
	Priority = 530,
})

function HintService:Setup()
	self.Enabled = false :: boolean
	self.Written = self.Libs.Charm.atom(0) :: Charm.Atom<number>
	-- os.clock() the current night's tip started waiting for Walt's call after the Call phase; nil = not waiting
	self.WaitSince = nil :: number?
	self.Paper = nil :: Instance?
	self.Anchor = nil :: Attachment?
	self.ScareSerial = 0 :: number
end

-- Reads -------------------------------------------------------------------------------------------------------------

function HintService:GetWritten(): number
	return self.Written()
end

-- A call of the night's Call phase rings, talks or waits in the queue
function HintService:CallPending(): boolean
	const boss = self.Dependencies.BossService
	if boss:GetState() ~= "Idle" then
		const row = Content.BossCalls.ByKey[boss:GetCall()]
		if row ~= nil and CALL_KINDS[row.Trigger.Kind] then
			return true
		end
	end
	for _, row in Content.BossCalls.List do
		if CALL_KINDS[row.Trigger.Kind] and boss:IsQueued(row.Key) then
			return true
		end
	end
	return false
end

-- Writes ------------------------------------------------------------------------------------------------------------

function HintService:Write(night: number)
	self.WaitSince = nil
	self.Written(math.clamp(math.floor(night), 0, NIGHT_MAX))
end

-- Walt is saying this night's rule now: the night's own call (NightCall of `night`, or the NightRepeat with its Short
-- lines) is Talking and has reached its last line, the rule's short form (owner 2026-10-22: "somente ser escrito quando o
-- Walt falar sobre a anomalia")
function HintService:WaltSaysRule(night: number): boolean
	const boss = self.Dependencies.BossService
	const record = boss.Record()
	if record.State ~= "Talking" then
		return false
	end
	const row = Content.BossCalls.ByKey[record.Call]
	if row == nil then
		return false
	end
	const trigger = row.Trigger
	if not ((trigger.Kind == "NightCall" and trigger.Night == night) or trigger.Kind == "NightRepeat") then
		return false
	end
	const lines = boss:LinesOf(record.Call)
	return #lines > 0 and Content.BossCalls.LineAt(lines, workspace:GetServerTimeNow() - record.StartedAt) >= #lines
end

function HintService:Step()
	const round = self.Dependencies.RoundService
	if not round:IsStarted() or not round:IsNight() then
		return
	end
	const night = round:GetNight()
	if night <= self.Written() or Content.Hints.ByNight[night] == nil then
		return
	end
	-- the pencil writes while Walt says the rule, never on its own (a night whose call the tutorial call replaced gets no
	-- tip until Walt says it)
	if self:WaltSaysRule(night) then
		self:Write(night)
	end
end

-- Paper and prompt --------------------------------------------------------------------------------------------------

-- The paper of the place (MapId Rules.MapId, a BasePart or a Model), nil when the map has none
local function findPaper(): Instance?
	for _, descendant in workspace:GetDescendants() do
		if descendant:GetAttribute("MapId") == RULES.MapId and (descendant:IsA("BasePart") or descendant:IsA("Model")) then
			return descendant
		end
	end
	return nil
end

local function topPart(paper: Instance): BasePart?
	if paper:IsA("BasePart") then
		return paper
	end
	local best: BasePart? = nil
	local bestTop = -math.huge
	for _, descendant in paper:GetDescendants() do
		if descendant:IsA("BasePart") then
			const top = descendant.Position.Y + descendant.Size.Y / 2
			if top > bestTop then
				bestTop = top
				best = descendant
			end
		end
	end
	return best
end

function HintService:Build()
	const paper = findPaper()
	if paper == nil then
		warn(`[HintService] no {RULES.MapId} paper in the Workspace: Walt's notes have no "Read" prompt`)
		return
	end
	local anchor = paper:FindFirstChild(RULES.Anchor, true)
	if anchor == nil or not anchor:IsA("Attachment") then
		const part = topPart(paper)
		if part == nil then
			warn(`[HintService] {paper:GetFullName()} has no part to hold the "Read" prompt`)
			return
		end
		const made = Instance.new("Attachment")
		made.Name = RULES.Anchor
		made.Parent = part
		made.WorldPosition = part.Position + Vector3.new(0, part.Size.Y / 2 + RULES.AnchorLift, 0)
		anchor = made
	end
	const attachment = anchor :: Attachment
	-- attributes before the tag: InteractionService reads them when the anchor is tagged
	attachment:SetAttribute("PromptAction", RULES.Action)
	self.Paper = paper
	self.Anchor = attachment
	CollectionService:AddTag(attachment, ANCHOR_TAG)
end

-- Opens the close-up of the paper on this player's screen (the prompt, and /dev hint open)
function HintService:Open(player: Player)
	const net = self.Dependencies.NetService
	if net:IsRunning() then
		self.Libs.Net.HintOpen:fireClient(player, nil)
	end
end

-- Dev ---------------------------------------------------------------------------------------------------------------

-- Writes night n's tip now (nil = the next one: the current night, or one past what is written). Returns the night.
function HintService:DevWrite(night: number?): number
	const round = self.Dependencies.RoundService
	const target = night or math.max(round:GetNight(), self.Written() + 1)
	self:Write(math.clamp(target, 0, Content.RunParams.Nights))
	return self.Written()
end

function HintService:DevReset()
	self:Write(0)
end

-- The arrival scare without waiting for a customer: the player's next way out of the paper plays it (on the customer at
-- the counter if there is one, else at Q1). Opens the paper too.
function HintService:ArmScare(player: Player)
	self.ScareSerial += 1
	player:SetAttribute(SCARE_ATTRIBUTE, self.ScareSerial)
	self:Open(player)
end

function HintService:DevState(): string
	const round = self.Dependencies.RoundService
	const paper = self.Paper
	return `written {self.Written()} (night {round:GetNight()}, phase {round:GetPhase()}, night shift {round:IsNight()}); `
		.. `Walt's night call pending {self:CallPending()}; waiting {if self.WaitSince then string.format("%.1f s", os.clock() - self.WaitSince) else "no"}; `
		.. `paper {if paper then paper:GetFullName() else "none"}`
end

HintService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	-- Priority 530 < 730: InteractionService already built its handler table
	self.Dependencies.InteractionService:RegisterAction(RULES.Action, {
		Validate = function(_player: Player, _anchor: Instance, _id: number): boolean
			return true
		end,
		Run = function(player: Player, _anchor: Instance, _id: number)
			self:Open(player)
		end,
	})

	self.Dependencies.RunStateService:RegisterSnapshot(SNAPSHOT, function()
		return self.Written()
	end, function(data, _mode)
		self:Write(if type(data) == "number" and data == data then data else 0)
	end)
end)

HintService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- The map is loaded (StreamingEnabled off, T57)
	self:Build()

	-- Lync.start already ran (NetService OnStart, priority 1000). Late joiners get the record from the set.
	self.Libs.Net.Hints:add(RECORD, { Night = self.Written() })
	self.Libs.Charm.effect(function()
		const night = self.Written()
		if self.Dependencies.NetService:IsRunning() then
			self.Libs.Net.Hints:update(RECORD, { Night = night })
		end
	end)
end)

HintService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return HintService
