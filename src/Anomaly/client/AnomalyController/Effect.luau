--!strict
--[[
	Effect API of the AnomalyController (TASK-107; architecture.md §19.13, network.md §13.5, T43, T53).

	One ModuleScript per anomaly in `AnomalyController/Effects/<Ref>.luau` (ANM-001 .. ANM-010), discovered at boot.
	A missing module = that anomaly shows nothing on the client (no error). The module only PRESENTS: it never
	decides a verb, a failure or a payment (the server's Anomalies/<Ref>.luau does, T10).

	```lua
	local Vide = require(ReplicatedStorage.Packages.Vide)
	local Effect = require(script.Parent.Parent.Effect)

	return {
		Ref = "ANM-006",
		-- Called once per occurrence record (set `Anomalies`), inside its own Vide root. Read `occ.Record()` in a
		-- Vide.effect to follow Phase/Step/Anchor; register Vide.cleanup for what you create. The root is destroyed
		-- when the record leaves the set (night over, restore) or the record id is reused by another anomaly.
		-- A late joiner gets the same call with the current record: show the state, skip intros
		-- (`occ.Elapsed() > x`).
		Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
			Vide.effect(function()
				const record = occ.Record()
				...
			end)
			Vide.cleanup(function() ... end)
		end,
		-- One shot from the `AnomalyCue` packet (knock, honk, smoke...). Runs in its own thread; may yield.
		-- `cue.Occurrence` = the newest live occurrence of the same anomaly (nil if the record is not here yet).
		Cue = function(ctx: Effect.Context, cue: Effect.Cue) ... end,
	} :: Effect.Module
	```

	Rules for effect modules:
	  - Local instances go under `ctx.Folder()` (or are cleaned with Vide.cleanup); never touch server-owned parts
	    except purely visual properties that the LightController / RigController do not own.
	  - Sounds through `ctx.Play` / `ctx.Audio` (opts.Scare for a startle, DEC-173). Animations through `ctx.Anim`.
	  - No VFX points at the correct target (anomalies.md §4.4). No network sends from here.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local AnimTypes = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AnimController)
local AudioTypes = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AudioController)
local LightTypes = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.LightController)
local RigTypes = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RigController)
local RoundTypes = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RoundController)

export type Phase = "Signal" | "Active" | "Resolved" | "Failed"

-- One record of the `Anomalies` set (network.md §13.5), copied (the set may reuse its table).
export type Record = {
	Anomaly: string, -- Content.Anomalies key
	Phase: Phase,
	StartedAt: number, -- server time (workspace:GetServerTimeNow)
	Step: number, -- Walker: step 0..Steps (4); Hush: posts out; others 0
	Anchor: number, -- NpcId of the customer anomaly, or anchor index; 0 = none (meaning is per anomaly)
}

export type Occurrence = {
	Id: number, -- record id 1..255 (cyclic per night)
	Key: string,
	Ref: string,
	Row: Content.Anomaly,
	Record: () -> Record, -- reactive (Vide source): read it inside Vide.effect / derive
	Elapsed: () -> number, -- seconds since StartedAt (server clock); not reactive
	Rng: Random, -- same seed on every client (Id, StartedAt): shared local randomness
	MountedAt: number, -- server time of this Mount
}

export type Cue = {
	Anomaly: string,
	Ref: string,
	Cue: string, -- Content.AnomalyCues key
	Row: Content.AnomalyCue, -- Kind, Duration
	Entity: number, -- NpcId or anchor index; 0 = none (meaning is per cue)
	Seed: number,
	Rng: Random, -- Random.new(Seed): same on every client
	At: number, -- server time on arrival
	Occurrence: Occurrence?,
}

export type Context = {
	Now: () -> number, -- server time
	Night: () -> number, -- RoundController.Night (reactive)
	Play: (key: string, at: AudioTypes.At?, scare: boolean?) -> Sound?, -- AudioController:Play shorthand
	Point: (id: string) -> CFrame?, -- MapPoint by PointId (AN-04, AS-1, SS...); nil if not streamed in
	Anchor: (anchorId: string) -> Instance?, -- `AnomalyAnchor` tag by AnchorId (WV-1..3)
	Npc: (npcId: number) -> Model?, -- customer rig by NpcId (CustomerController)
	Occurrences: (key: string?) -> { Occurrence }, -- live occurrences, oldest first; nil key = all
	Folder: () -> Folder, -- Workspace folder for local actors (Walker, long car, fog); emptied at night end
	Audio: AudioTypes.Public,
	Light: LightTypes.Public,
	Rig: RigTypes.Public,
	Anim: AnimTypes.Public,
	Round: RoundTypes.Public,
}

export type Module = {
	Ref: string,
	Mount: ((ctx: Context, occ: Occurrence) -> ())?,
	Cue: ((ctx: Context, cue: Cue) -> ())?,
}

const Effect = {}

-- Validates a required Effects/<name> value. Returns the module or nil + reason.
function Effect.check(name: string, value: unknown): (Module?, string?)
	if type(value) ~= "table" then
		return nil, `{name} must return a table`
	end
	const module = value :: any
	if module.Ref ~= name then
		return nil, `{name}: Ref "{tostring(module.Ref)}" must match the file name`
	end
	local known = false
	for _, row in Content.Anomalies.List do
		if row.Ref == name then
			known = true
			break
		end
	end
	if not known then
		return nil, `{name}: no anomaly with this Ref in Content.Anomalies`
	end
	if module.Mount ~= nil and type(module.Mount) ~= "function" then
		return nil, `{name}: Mount must be a function`
	end
	if module.Cue ~= nil and type(module.Cue) ~= "function" then
		return nil, `{name}: Cue must be a function`
	end
	if module.Mount == nil and module.Cue == nil then
		return nil, `{name}: needs Mount or Cue`
	end
	return module :: Module, nil
end

return table.freeze(Effect)
