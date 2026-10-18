--!strict
--[[
	AnomalyController (TASK-107; architecture.md §19.13, network.md §13.5, T43, T53; DEC-195, DEC-204)

	Client core of the anomalies: presents what AnomalyService decides. Never decides a verb, a failure or a payment.

	  - Effects/<Ref>.luau are discovered at boot and checked by Effect.check (API and rules in Effect.luau). An
	    anomaly without a module shows nothing; a broken module warns and is skipped.
	  - set `Anomalies` (record id = occurrence 1..255): one Vide source per record, one Vide root per occurrence
	    running `Effect.Mount`. Changed fields update the source; a reused id with another anomaly remounts; removed
	    record destroys the root. A late joiner gets the current records through onAdded (T53).
	  - packet `AnomalyCue`: routed to `Effect.Cue` of that anomaly in its own thread. Cues not listed in the
	    anomaly's Content row are dropped (warn once). Losing one on reconnect changes no rule (§13.5).
	  - `Folder()` (Workspace.AnomalyEffects) holds local actors; emptied when the night ends (safety net: the server
	    also clears the set).

	  - Breaker.luau (TASK-334): the breaker panel shows the guide arrow while the power is out and a grey "No power
	    issue" pill when the power is on.
	  - Score/ (TASK-443, TASK-444): the horror score director (Calm / Uneasy / Tension / Climax / Release) and the
	    "POWER OUT" caption, driven by these records; started in OnStart (Content.Score.Rules.Enabled).
	  - Scene/ (TASK-462): the horror scene player (Content.HorrorScenes), fed by Write / Unmount / OnCue, started in
	    OnStart; plays a scene's steps on the timeline of its record (no packet of its own).
	  - stings (user request 2026-10-10, Content.SoundRules.Stings): AnomalyStart (horror_sting) when a record
	    appears less than STING_FRESH s after its StartedAt (a late joiner hears nothing); AnomalyResolved
	    (horror_chase_stop) when a live record turns Resolved. Both on screen with the DEC-173 scare cap.
	    With the horror score on (Content.Score.Rules.Enabled, Score/, TASK-443) the AnomalyStart sting is gone
	    (the score's Uneasy is the one reserved omen, and family A must not be given away by a sound) and
	    AnomalyResolved plays only for anomalies the score does not drive (its Release stage has the relief sting).

	Public reads: `Count` (Vide source, live occurrences), `RecordOf(id)`, `Occurrences(key?)`.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Effect = require(script.Effect)
local Breaker = require(script.Breaker)
local Score = require(script.Score)
local Scene = require(script.Scene)
local SceneKits = require(script.Scene.Kits)

export type Phase = Effect.Phase
export type Record = Effect.Record
export type Occurrence = Effect.Occurrence
export type Cue = Effect.Cue
export type Context = Effect.Context
export type Module = Effect.Module

-- Live occurrence: its source and the destroy of its Vide root (nil = no effect module, kept for Occurrences()).
export type Live = {
	Occurrence: Occurrence,
	Source: Vide.Source<Record>,
	Destroy: (() -> ())?,
}

const ANCHOR_TAG = "AnomalyAnchor"
const ANCHOR_ATTRIBUTE = "AnchorId"
const FOLDER_NAME = "AnomalyEffects"
const SEED_SPAN = 65536
const STING_FRESH = 3 -- s: a record older than this when it reaches the client does not sting
const STINGS = Content.SoundRules.Stings
const SCORE_ON = Content.Score.Rules.Enabled
const SCORED = Content.Score.Anomalies :: { [string]: Content.ScoreAnomaly }

const AnomalyController = Modux.Controller("AnomalyController", {
	Require = {
		"RoundController",
		"AudioController",
		"LightController",
		"RigController",
		"AnimController",
		"CustomerController",
		"CameraController", -- TASK-467: horror scene camera steps (Scene/Kits)
	},
	Priority = 660,
})

function AnomalyController:Setup()
	-- Ref -> effect module
	self.Effects = {} :: { [string]: Module }
	self.Lives = {} :: { [number]: Live }
	self.Count = Vide.source(0) :: Vide.Source<number>
	self.Warned = {} :: { [string]: boolean }
	self.LocalFolder = nil :: Folder?
	self.Ctx = nil :: Context?
end

function AnomalyController:WarnOnce(tag: string, message: string)
	if self.Warned[tag] then
		return
	end
	self.Warned[tag] = true
	warn(`[AnomalyController] {message}`)
end

-- Effects ---------------------------------------------------------------------------------------------------------

function AnomalyController:LoadEffects()
	const folder = script:FindFirstChild("Effects")
	if folder == nil then
		return
	end
	for _, child in folder:GetChildren() do
		if not child:IsA("ModuleScript") then
			continue
		end
		const ok, value = pcall((require :: any), child)
		if not ok then
			warn(`[AnomalyController] Effects/{child.Name} failed to load: {value}`)
			continue
		end
		const module, problem = Effect.check(child.Name, value)
		if module == nil then
			warn(`[AnomalyController] Effects/{problem}`)
			continue
		end
		self.Effects[module.Ref] = module
	end
end

-- Context ---------------------------------------------------------------------------------------------------------

function AnomalyController:Folder(): Folder
	local folder = self.LocalFolder
	if folder == nil or folder.Parent ~= Workspace then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = Workspace
		self.LocalFolder = folder
	end
	return folder :: Folder
end

function AnomalyController:Point(id: string): CFrame?
	local found = MapIndex.FindPoint(id)
	if found == nil then
		MapIndex.Refresh() -- the point may have streamed in after the last scan
		found = MapIndex.FindPoint(id)
	end
	return found
end

function AnomalyController:Anchor(anchorId: string): Instance?
	for _, instance in CollectionService:GetTagged(ANCHOR_TAG) do
		if instance:GetAttribute(ANCHOR_ATTRIBUTE) == anchorId and instance:IsDescendantOf(Workspace) then
			return instance
		end
	end
	return nil
end

-- Live occurrences, oldest first (StartedAt, then id); nil key = all.
function AnomalyController:Occurrences(key: string?): { Occurrence }
	const out: { Occurrence } = {}
	for _, live in self.Lives do
		if key == nil or live.Occurrence.Key == key then
			table.insert(out, live.Occurrence)
		end
	end
	table.sort(out, function(a: Occurrence, b: Occurrence): boolean
		const ra, rb = a.Record(), b.Record()
		if ra.StartedAt ~= rb.StartedAt then
			return ra.StartedAt < rb.StartedAt
		end
		return a.Id < b.Id
	end)
	return out
end

function AnomalyController:Context(): Context
	const existing = self.Ctx
	if existing then
		return existing
	end
	const deps = self.Dependencies
	const ctx: Context = {
		Now = function(): number
			return Workspace:GetServerTimeNow()
		end,
		Night = function(): number
			return deps.RoundController.Night()
		end,
		Play = function(key: string, at: any, scare: boolean?): Sound?
			return deps.AudioController:Play(key, at, if scare then { Scare = true } else nil)
		end,
		Point = function(id: string): CFrame?
			return self:Point(id)
		end,
		Anchor = function(anchorId: string): Instance?
			return self:Anchor(anchorId)
		end,
		Npc = function(npcId: number): Model?
			return deps.CustomerController.Models[npcId]
		end,
		Occurrences = function(key: string?): { Occurrence }
			return self:Occurrences(key)
		end,
		Folder = function(): Folder
			return self:Folder()
		end,
		Audio = deps.AudioController,
		Light = deps.LightController,
		Rig = deps.RigController,
		Anim = deps.AnimController,
		Round = deps.RoundController,
	}
	self.Ctx = ctx
	return ctx
end

-- Set `Anomalies` -------------------------------------------------------------------------------------------------

-- Copy: the set may reuse its record table, and Vide needs a new value to notice a change.
local function copy(record: any): Record
	return {
		Anomaly = record.Anomaly,
		Phase = record.Phase,
		StartedAt = record.StartedAt,
		Step = record.Step,
		Anchor = record.Anchor,
	}
end

function AnomalyController:Mount(id: number, record: Record)
	const row = Content.Anomalies.ByKey[record.Anomaly]
	if row == nil then
		self:WarnOnce(`key:{record.Anomaly}`, `unknown anomaly "{record.Anomaly}" in record {id}`)
		return
	end
	const source = Vide.source(record)
	const occurrence: Occurrence = {
		Id = id,
		Key = row.Key,
		Ref = row.Ref,
		Row = row,
		Record = function(): Record
			return source()
		end,
		Elapsed = function(): number
			return math.max(0, Workspace:GetServerTimeNow() - source().StartedAt)
		end,
		Rng = Random.new(id * SEED_SPAN + math.floor(record.StartedAt) % SEED_SPAN),
		MountedAt = Workspace:GetServerTimeNow(),
	}
	const live: Live = { Occurrence = occurrence, Source = source, Destroy = nil }
	self.Lives[id] = live
	self.Count(self.Count() + 1)

	const module = self.Effects[row.Ref]
	const found = if module then module.Mount else nil
	if found == nil then
		return -- sem efeito = nada
	end
	const mount: (Context, Occurrence) -> () = found
	const ctx = self:Context()
	const ok, result = pcall(Vide.root, function(destroy: () -> ())
		mount(ctx, occurrence)
		return destroy
	end)
	if not ok then
		warn(`[AnomalyController] Effects/{row.Ref} Mount (record {id}): {result}`)
		return
	end
	live.Destroy = result
end

function AnomalyController:Unmount(id: number)
	const live = self.Lives[id]
	if live == nil then
		return
	end
	self.Lives[id] = nil
	self.Count(math.max(0, self.Count() - 1))
	Scene.Remove(id)
	const destroy = live.Destroy
	if destroy then
		const ok, problem = pcall(destroy)
		if not ok then
			warn(`[AnomalyController] Effects/{live.Occurrence.Ref} cleanup (record {id}): {problem}`)
		end
	end
end

function AnomalyController:Write(id: number, raw: any?)
	if raw == nil then
		self:Unmount(id)
		return
	end
	const record = copy(raw)
	const live = self.Lives[id]
	if live and live.Occurrence.Key == record.Anomaly then
		const previous = Vide.untrack(live.Source).Phase
		live.Source(record)
		Scene.Record(id, record)
		if record.Phase == "Resolved" and previous ~= "Resolved" and not (SCORE_ON and SCORED[live.Occurrence.Ref] ~= nil) then
			self:Sting(STINGS.AnomalyResolved)
		end
		return
	end
	-- new record, or the cyclic id now carries another anomaly
	self:Unmount(id)
	self:Mount(id, record)
	Scene.Record(id, record)
	const fresh = Workspace:GetServerTimeNow() - record.StartedAt <= STING_FRESH
	if fresh and not SCORE_ON and record.Phase ~= "Resolved" and record.Phase ~= "Failed" then
		self:Sting(STINGS.AnomalyStart)
	end
end

function AnomalyController:Sting(key: string)
	self.Dependencies.AudioController:Play(key, nil, { Scare = true })
end

-- Reactive read of a record (nil = no such occurrence). For other controllers and debugging.
function AnomalyController:RecordOf(id: number): Record?
	const live = self.Lives[id]
	return if live then live.Source() else nil
end

-- Packet `AnomalyCue` ---------------------------------------------------------------------------------------------

function AnomalyController:OnCue(raw: any)
	const row = Content.Anomalies.ByKey[raw.Anomaly]
	const cueRow = Content.AnomalyCues.ByKey[raw.Cue]
	if row == nil or cueRow == nil then
		self:WarnOnce(`cue:{raw.Anomaly}:{raw.Cue}`, `unknown cue {raw.Anomaly}/{raw.Cue}`)
		return
	end
	if table.find(row.Cues, cueRow.Key) == nil then
		self:WarnOnce(`cue:{row.Key}:{cueRow.Key}`, `cue "{cueRow.Key}" is not listed for {row.Key}`)
		return
	end
	Scene.Cue(row.Key, cueRow.Key, raw.Entity)
	const module = self.Effects[row.Ref]
	const handler = if module then module.Cue else nil
	if handler == nil then
		return -- sem efeito = nada
	end
	const live = self:Occurrences(row.Key)
	const cue: Cue = {
		Anomaly = row.Key,
		Ref = row.Ref,
		Cue = cueRow.Key,
		Row = cueRow,
		Entity = raw.Entity,
		Seed = raw.Seed,
		Rng = Random.new(raw.Seed),
		At = Workspace:GetServerTimeNow(),
		Occurrence = live[#live],
	}
	const ctx = self:Context()
	task.spawn(function()
		const ok, problem = pcall(handler, ctx, cue)
		if not ok then
			warn(`[AnomalyController] Effects/{row.Ref} Cue {cueRow.Key}: {problem}`)
		end
	end)
end

-- Night end safety net: local actors left behind by a broken cleanup go away with the night.
function AnomalyController:WatchNight()
	const round = self.Dependencies.RoundController
	Vide.root(function()
		Vide.effect(function()
			if not round.IsNight() then
				const folder = self.LocalFolder
				if folder then
					folder:ClearAllChildren()
				end
			end
		end)
	end)
end

AnomalyController:OnInit(function(self)
	self:Setup()
	self:LoadEffects()

	const net = self.Libs.Net

	net.Anomalies:onAdded(function(id, record)
		self:Write(id, record)
	end)
	net.Anomalies:onChanged(function(id, record)
		self:Write(id, record)
	end)
	net.Anomalies:onRemoved(function(id)
		self:Write(id, nil)
	end)

	net.AnomalyCue:onClient(function(cue)
		self:OnCue(cue)
	end)
end)

AnomalyController:OnStart(function(self)
	self:WatchNight()
	-- TASK-334: breaker arrow in the blackout, "No power issue" outside it
	Breaker.Start()
	-- TASK-462: horror scenes on the records' timeline
	Scene.Start(self:Context())
	-- TASK-467: camera, screen, door, shadow and eyes steps (sibling kits TASK-463/464/465)
	SceneKits.Register(Scene.Handle, self.Dependencies.CameraController :: any)
	-- TASK-443: the horror score in steps (narrow views; the director only reads them)
	Score.Start({
		Audio = self.Dependencies.AudioController :: any,
		Round = self.Dependencies.RoundController :: any,
		Occurrences = function(): { Score.Live }
			return self:Occurrences(nil) :: any
		end,
	})
end)

return AnomalyController
