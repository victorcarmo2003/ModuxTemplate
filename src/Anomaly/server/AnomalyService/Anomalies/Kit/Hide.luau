--!strict
-- V2 family B "something is coming", verb HIDE (DEC-254, DEC-255, DEC-256; TASK-272; anomalies-v2-proposal.md §3 B).
-- One body for every family B monster (ANM-007 The Walker, ANM-017 crawler, ANM-018 grin; ANM-019 left with TASK-484); each
-- Anomalies/<Ref>.luau is a thin call to Hide.Module and each Rules/<Ref>.luau a call to Hide.Rule. Lives in a Folder
-- (Kit/), so AnomalyService:LoadModules never schedules it.
--
-- Timeline of one occurrence (numbers in Rules/<Ref>.luau Params, T10):
--   Start   Phase Signal, cue "hide_warn" (client: trailer lights flicker, low rumble, Walt on the radio "Hide!").
--           The party has WarnFor s to leave the trailer by the back door and stand in a HideZone.
--   Pass    after WarnFor: Phase Active, cue "monster_pass". The monster crosses the street, leans on the service
--           window and looks inside, then leaves (client, PassFor s).
--   Look    from LookFrom to LookTo s into the pass: every tick, each Active player whose root is not inside a HideZone
--           is scared: cue "jumpscare" (Entity = UserId % 65536, only that client shows the face) and ScareFaint s
--           later VitalService:Fall (Down, revivable; Spectator when the revives of the night are spent, DEC-129).
--           Once per player per occurrence. Not -RuleBroken and not a lost night by itself (DEC-255).
--   End     PassFor s into the pass: Phase Resolved when nobody was scared, then Finish.
--
-- Hiding spot: every BasePart in workspace tagged "HideZone" (CollectionService) or with the attribute HideZone = true
-- (MAP-01, behind the trailer; tools/assetplace/hide_zone.luau creates one). The test is the part's box in its own
-- space plus Margin studs around (and a generous height: the root stands ~3 studs above the feet). No zone in the
-- place = Start false (the scheduler retries) and one warning.
--
-- Test "Floor" (TASK-483, DEC-294: the crawler in the restaurant, "get off the floor"): no HideZone. The safe players are
-- the ones OFF THE FLOOR: the ground under the feet (raycast down from the root, characters ignored) is more than
-- Params.Lift studs above Params.FloorY (counter tops, tables, crates). Feet on the floor for Params.Ground s in a row
-- inside the look window = scared (a jump does not save: landing counts again; a quick hop is forgiven). Mid-air (no
-- ground within GROUND_DOWN) counts as off the floor.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Parent.Api)

const ZONE_TAG = "HideZone"
const ZONE_ATTRIBUTE = "HideZone"
const WARN_CUE = "hide_warn"
const PASS_CUE = "monster_pass"
const SCARE_CUE = "jumpscare"
const ENTITY_MOD = 65536 -- AnomalyCue.Entity is 0..65535
const HEIGHT_SLACK = 6 -- studs above/below the zone box the root may be (root ~3 above the feet)
-- Defaults when Rules/<Ref> is missing (same numbers as the rule files; Provisional)
const DEFAULT_WARN_FOR = 9
const DEFAULT_PASS_FOR = 10
const DEFAULT_LOOK_FROM = 4
const DEFAULT_LOOK_TO = 7
const DEFAULT_MARGIN = 1
const DEFAULT_SCARE_FAINT = 0.7
-- Test "Floor" (TASK-483; Provisional): kitchen / patio floor top (tools/assetplace/restaurant_bind.luau FLOOR)
const DEFAULT_FLOOR_Y = 0.45
const DEFAULT_LIFT = 1.2 -- studs above the floor the ground under the feet must be (counter top = 3.0)
const DEFAULT_GROUND = 0.4 -- s on the floor in a row that count
const GROUND_DOWN = 12 -- studs the floor raycast looks below the root

export type Test = "Zone" | "Floor"

export type Options = {
	Ref: string,
	-- "Zone" (default) = stand in a HideZone; "Floor" = get off the floor (TASK-483). A function = decided at Start
	Test: (Test | () -> Test)?,
}

type State = {
	Ref: string,
	PassAt: number, -- server time the monster starts its pass
	LookFrom: number,
	LookTo: number,
	EndsAt: number,
	Margin: number,
	ScareFaint: number,
	Passing: boolean,
	Scared: { [Player]: boolean },
	Failed: boolean,
	Zones: { BasePart },
	Test: Test,
	FloorY: number,
	Lift: number,
	Ground: number,
	OnFloor: { [Player]: number }, -- server time the feet touched the floor (Test "Floor")
}

type Live = { Ctx: Api.Context, Occ: Api.Occurrence }

type Vital = { Fall: (self: any, player: Player, forced: string?) -> () }

export type HideModule = Api.Module & {
	-- Dev (Commands/Walker.luau calls it on ANM-007): skips the warning, the monster passes now
	DevStep: (step: number) -> string,
}

const Hide = {}

local vitalCache: Vital? = nil
local zonesWarned = false
const live: { [string]: Live } = {} -- Ref -> running occurrence (one per monster at a time)

local function vital(): Vital
	if vitalCache == nil then
		vitalCache = (require :: any)(ServerScriptService.server.Vital.VitalService) :: Vital
	end
	return vitalCache :: Vital
end

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 then value else default
end

-- Content key of a Ref (ANM-017 -> anm_017_...). The Ref itself when the row does not exist yet: Rules then warns
-- and skips the file instead of breaking.
function Hide.KeyOf(ref: string): string
	for _, row in Content.Anomalies.List do
		if row.Ref == ref then
			return row.Key
		end
	end
	return ref
end

-- Rule of one family B monster (Rules/<Ref>.luau). Verb "hide", party signal, personal error (each player who is
-- not hidden faints). Params override the defaults (WarnFor, PassFor, LookFrom, LookTo, Margin, ScareFaint).
function Hide.Rule(ref: string, params: { [string]: any }?): Api.Rule
	const merged: { [string]: any } = {
		WarnFor = DEFAULT_WARN_FOR,
		PassFor = DEFAULT_PASS_FOR,
		LookFrom = DEFAULT_LOOK_FROM,
		LookTo = DEFAULT_LOOK_TO,
		Margin = DEFAULT_MARGIN,
		ScareFaint = DEFAULT_SCARE_FAINT,
		FloorY = DEFAULT_FLOOR_Y,
		Lift = DEFAULT_LIFT,
		Ground = DEFAULT_GROUND,
	}
	for key, value in params or {} do
		merged[key] = value
	end
	return {
		Anomaly = Hide.KeyOf(ref),
		Verb = "hide",
		LikelyWrongVerb = "stay",
		Window = 0,
		IsCritical = false, -- DEC-255: the night is lost only when everyone is down (TASK-270)
		Params = merged,
	}
end

-- Every hiding zone in the workspace (tag or attribute).
function Hide.Zones(): { BasePart }
	const out: { BasePart } = {}
	const seen: { [BasePart]: boolean } = {}
	for _, instance in CollectionService:GetTagged(ZONE_TAG) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) and not seen[instance] then
			seen[instance] = true
			table.insert(out, instance)
		end
	end
	if #out == 0 then
		for _, instance in workspace:GetDescendants() do
			if instance:IsA("BasePart") and instance:GetAttribute(ZONE_ATTRIBUTE) == true and not seen[instance] then
				seen[instance] = true
				table.insert(out, instance)
			end
		end
	end
	return out
end

-- true when `position` is inside one of the zones (box in the part's own space, `margin` studs around).
function Hide.Inside(zones: { BasePart }, position: Vector3, margin: number): boolean
	for _, zone in zones do
		if zone.Parent == nil then
			continue
		end
		const offset = zone.CFrame:PointToObjectSpace(position)
		const half = zone.Size / 2
		if
			math.abs(offset.X) <= half.X + margin
			and math.abs(offset.Z) <= half.Z + margin
			and math.abs(offset.Y) <= half.Y + HEIGHT_SLACK
		then
			return true
		end
	end
	return false
end

-- Test "Floor": true when the ground under the player's feet is the floor (not a counter, table or crate).
local function onFloor(player: Player, floorY: number, lift: number): boolean
	const character = player.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = {}
	for _, other in game:GetService("Players"):GetPlayers() do
		if other.Character ~= nil then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	const hit = workspace:Raycast(root.Position, Vector3.new(0, -GROUND_DOWN, 0), params)
	return hit ~= nil and hit.Position.Y <= floorY + lift
end

local function rootOf(player: Player): Vector3?
	const character = player.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

-- Entity of the jumpscare cue: only the client of this player shows the face.
function Hide.EntityOf(player: Player): number
	return player.UserId % ENTITY_MOD
end

local function scare(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player)
	state.Scared[player] = true
	if not state.Failed then
		state.Failed = true
		ctx.Publish(occ, { Phase = "Failed" })
	end
	ctx.Cue(occ, SCARE_CUE, Hide.EntityOf(player))
	task.delay(state.ScareFaint, function()
		if player.Parent ~= nil then
			vital():Fall(player)
		end
	end)
end

local function beginPass(ctx: Api.Context, occ: Api.Occurrence, state: State, now: number)
	state.Passing = true
	-- a dev skip moves the whole pass to now
	const shift = now - state.PassAt
	state.PassAt = now
	state.LookFrom += shift
	state.LookTo += shift
	state.EndsAt += shift
	ctx.Publish(occ, { Phase = "Active", Step = 1 })
	ctx.Cue(occ, PASS_CUE, 0)
end

-- Builds the module of one family B monster.
function Hide.Module(options: Options): HideModule
	const ref = options.Ref

	const module: HideModule = {
		Ref = ref,

		Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
			const option = options.Test
			const test: Test = if type(option) == "function" then option() elseif option ~= nil then option else "Zone"
			const zones = if test == "Zone" then Hide.Zones() else {}
			if test == "Zone" and #zones == 0 then
				if not zonesWarned then
					zonesWarned = true
					ctx.Log(occ, `no HideZone part in the workspace (run tools/assetplace/hide_zone.luau); not started`)
				end
				return false
			end
			const rule = ctx.Rule(occ.Key)
			const warnFor = param(rule, "WarnFor", DEFAULT_WARN_FOR)
			const passFor = math.max(1, param(rule, "PassFor", DEFAULT_PASS_FOR))
			const lookFrom = math.clamp(param(rule, "LookFrom", DEFAULT_LOOK_FROM), 0, passFor)
			const lookTo = math.clamp(param(rule, "LookTo", DEFAULT_LOOK_TO), lookFrom, passFor)
			const passAt = occ.StartedAt + warnFor
			const state: State = {
				Ref = ref,
				PassAt = passAt,
				LookFrom = passAt + lookFrom,
				LookTo = passAt + lookTo,
				EndsAt = passAt + passFor,
				Margin = param(rule, "Margin", DEFAULT_MARGIN),
				ScareFaint = param(rule, "ScareFaint", DEFAULT_SCARE_FAINT),
				Passing = false,
				Scared = {},
				Failed = false,
				Zones = zones,
				Test = test,
				FloorY = param(rule, "FloorY", DEFAULT_FLOOR_Y),
				Lift = param(rule, "Lift", DEFAULT_LIFT),
				Ground = param(rule, "Ground", DEFAULT_GROUND),
				OnFloor = {},
			}
			occ.State = state
			live[ref] = { Ctx = ctx, Occ = occ }
			ctx.Publish(occ, { Phase = "Signal", Step = 0, Anchor = 0 })
			ctx.Cue(occ, WARN_CUE, 0)
			return true
		end,

		Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
			const state = occ.State :: State
			if not state.Passing then
				if now < state.PassAt then
					return
				end
				beginPass(ctx, occ, state, state.PassAt)
			end
			if now >= state.EndsAt then
				if not state.Failed then
					ctx.Succeed(occ)
				end
				ctx.Finish(occ)
				return
			end
			if now < state.LookFrom or now > state.LookTo then
				return
			end
			const zones = state.Zones
			for _, player in ctx.Active() do
				if state.Scared[player] then
					continue
				end
				if state.Test == "Floor" then
					if not onFloor(player, state.FloorY, state.Lift) then
						state.OnFloor[player] = nil
					else
						const since = state.OnFloor[player]
						if since == nil then
							state.OnFloor[player] = now
						elseif now - since >= state.Ground then
							scare(ctx, occ, state, player)
						end
					end
					continue
				end
				const position = rootOf(player)
				if position ~= nil and not Hide.Inside(zones, position, state.Margin) then
					scare(ctx, occ, state, player)
				end
			end
		end,

		Stop = function(_ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
			const current = live[ref]
			if current ~= nil and current.Occ == occ then
				live[ref] = nil
			end
			occ.State = nil
		end,

		DevStep = function(_step: number): string
			const current = live[ref]
			if current == nil or current.Occ.State == nil then
				error(`no {ref} running: /dev anomaly {ref} first (Night phase)`, 0)
			end
			const state = current.Occ.State :: State
			if state.Passing then
				return `{ref}: the monster is already passing`
			end
			beginPass(current.Ctx, current.Occ, state, current.Ctx.Now())
			return `{ref}: warning skipped, the monster passes now`
		end,
	}
	return module
end

return table.freeze(Hide)
