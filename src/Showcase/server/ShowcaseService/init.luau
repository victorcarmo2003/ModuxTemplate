--!strict
-- ShowcaseService: dev showcase for the owner (docs/tech/showcase.md; user request 2026-10-12, Provisional). Lets the
-- owner TEST every anomaly (ANM-001..010), every hallucination / scare and every mechanic around them without playing
-- the run: a panel (ShowcaseController, F9 / `/dev showcase` / Conch `showcase`) sends ShowcaseDo packets, this service
-- forces the thing through the REAL services and answers with ShowcaseLog / ShowcaseState.
--
-- Safety: Studio Run place only (PlaceService:IsDev, which is false in any published server) AND
-- AdminSettings.IsAllowed(player), checked on EVERY request in Allowed(). In a published server OnInit returns before
-- any responder exists, so the packets have no listener and nothing can be forced. No state is saved.
--
-- No logic is duplicated: anomalies go through AnomalyService (DevForce / DevStopKey / DevEmit), world commands through
-- DevService:Execute (the same Commands/ as chat /dev, restricted to DEV_ALLOWED), clock and life through the Dev*
-- hooks of RoundService / VitalService, hallucinations are played on the client (ShowcaseScare).
-- Hooks created for this (all dev-checked): AnomalyService:DevHoldAgenda / DevRuns / DevOccurrence / DevStopKey /
-- DevEmit, VitalService:DevGod / DevRevive / DevDarkMode, RoundService:DevSetPhaseElapsed, HallucinationController:DevPlay.
--
-- Public entry for other callers (Conch, DevService command): Run(player, action, id, arg, value) -> (ok, text), Open(player).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AdminSettings = require(ReplicatedStorage.shared.Admin.AdminSettings)
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Catalog = require(script.Catalog)
local Resolve = require(script.Resolve)
local Rules = require(ServerScriptService.server.Anomaly.AnomalyService.Rules)
local Modux = require(ServerScriptService.server.Modux)

const PREFIX = "[ShowcaseService]"
const TICK_RATE = 5 -- Hz: keeps the clock frozen and the ended-occurrence memory
const STATE_EVERY = 0.5 -- s between two state packets to an open panel
const NIGHT_WAIT = 8 -- s to wait for the Night phase after a jump
const ENDED_KEEP = 20 -- s an ended occurrence stays in the panel readout
const LIFT = Vector3.new(0, 3, 0)

-- DevService commands the panel may run (the Catalog uses exactly these). Anything else is refused.
const DEV_ALLOWED: { [string]: boolean } = {
	night = true,
	skip = true,
	win = true,
	lose = true,
	down = true,
	spectate = true,
	sanity = true,
	thief = true,
	traffic = true,
	customer = true,
	light = true,
	shutter = true,
	trailer = true,
	alter = true,
	coffee = true,
	walker = true,
}

type Ended = { Phase: string, Step: number, At: number }

const ShowcaseService = Modux.Service("ShowcaseService", {
	Require = {
		"PlaceService",
		"NetService",
		"DevService",
		"AnomalyService",
		"RoundService",
		"VitalService",
		"LightService",
		"VehicleService",
		"CustomerService",
		"NpcService",
		"KitchenService",
	},
	Priority = 60, -- below DevService (100) and every service it uses; above AdminService (50), which calls us
})

function ShowcaseService:Setup()
	self.Enabled = false :: boolean
	self.Viewers = {} :: { [Player]: boolean }
	-- clock freeze: seconds the phase had run when it was frozen, and which phase
	self.FrozenElapsed = nil :: number?
	self.FrozenPhase = "" :: string
	-- last phase seen per anomaly Ref once it left the set (Resolved / Failed / Ended), for the panel readout
	self.Ended = {} :: { [string]: Ended }
	self.Alive = {} :: { [string]: Ended }
	self.NextStateAt = 0 :: number
	self.Catalog = nil :: { Catalog.Item }?
end

-- Access --------------------------------------------------------------------------------------------------------------

-- The gate. Called by every entry point; never cached.
function ShowcaseService:Allowed(player: Player): boolean
	return self.Enabled
		and self.Dependencies.PlaceService:IsDev()
		and player.Parent == Players
		and AdminSettings.IsAllowed(player)
end

function ShowcaseService:Reply(player: Player, kind: "info" | "ok" | "error" | "open", text: string)
	if not self.Dependencies.NetService:IsRunning() or player.Parent ~= Players then
		return
	end
	self.Libs.Net.ShowcaseLog:fireClient(player, { Kind = kind, Text = string.sub(text, 1, 400) })
end

-- Helpers -------------------------------------------------------------------------------------------------------------

local function words(text: string): { string }
	const out = {}
	for word in string.gmatch(text, "%S+") do
		table.insert(out, word)
	end
	return out
end

local function row(anomaly: string): Content.Anomaly?
	const byKey = Content.Anomalies.ByKey[anomaly]
	if byKey ~= nil then
		return byKey
	end
	const upper = string.upper(anomaly)
	const number = tonumber(anomaly)
	for _, candidate in Content.Anomalies.List do
		if candidate.Ref == upper or (number ~= nil and candidate.Night == number) then
			return candidate
		end
	end
	return nil
end

function ShowcaseService:Dev(player: Player, line: string): string
	const parts = words(line)
	const name = table.remove(parts, 1)
	if name == nil or not DEV_ALLOWED[string.lower(name)] then
		error(`dev command "{tostring(name)}" is not allowed from the showcase`, 0)
	end
	return self.Dependencies.DevService:Execute(name, parts, player) or "ok"
end

function ShowcaseService:Teleport(player: Player, point: string): boolean
	const at = MapIndex.FindPoint(point)
	const character = player.Character
	if at == nil or character == nil then
		return false
	end
	character:PivotTo(at + LIFT)
	return true
end

function ShowcaseService:ResolveEnv(player: Player): Resolve.Env
	const deps = self.Dependencies :: any
	return {
		Player = player,
		Anomaly = deps.AnomalyService,
		Customers = deps.CustomerService,
		Npcs = deps.NpcService,
		Lights = deps.LightService,
		Vehicles = deps.VehicleService,
		Kitchen = deps.KitchenService,
		Teleport = function(who: Player, point: string): boolean
			return self:Teleport(who, point)
		end,
		Rule = function(ref: string): { [string]: any }?
			return Rules.Get(ref) :: any
		end,
	}
end

-- World ---------------------------------------------------------------------------------------------------------------

-- Puts the run in the Night phase of `night` (nil = keep the night shift we are in). Yields up to NIGHT_WAIT s.
function ShowcaseService:EnsureNight(player: Player, night: number?, force: boolean?)
	const round = self.Dependencies.RoundService
	const wanted = night or (if round:IsNight() then round:GetNight() else 1)
	if force == true or not round:IsNight() or round:GetNight() ~= wanted then
		self.FrozenElapsed = nil
		self:Dev(player, `night {wanted}`)
	end
	const deadline = os.clock() + NIGHT_WAIT
	while round:GetPhase() ~= "Night" and os.clock() < deadline do
		pcall(function()
			self:Dev(player, "skip")
		end)
		task.wait(0.5)
	end
	if round:GetPhase() ~= "Night" then
		error(`could not reach the Night phase (stuck in {round:GetPhase()})`, 0)
	end
end

function ShowcaseService:SetClock(player: Player, minutes: number)
	const round = self.Dependencies.RoundService
	self:EnsureNight(player, nil)
	const timing = round:Timing("Night")
	const span = timing.ClockTo - timing.ClockFrom
	if span <= 0 then
		error("the Night clock has no span", 0)
	end
	const alpha = math.clamp((minutes - timing.ClockFrom) / span, 0, 0.995)
	const elapsed = alpha * timing.Duration
	round:DevSetPhaseElapsed(elapsed)
	if self.FrozenElapsed ~= nil then
		self.FrozenElapsed = elapsed
	end
end

function ShowcaseService:Clear(player: Player)
	-- everything the anomaly modules or the panel may have left in the world
	const deps = self.Dependencies :: any
	pcall(function()
		deps.LightService:SetSwitch(true, nil)
	end)
	pcall(function()
		deps.LightService:EndHush()
	end)
	pcall(function()
		deps.VehicleService:SetShutter(false, nil)
	end)
	pcall(function()
		deps.KitchenService:ClearAltered()
	end)
	pcall(function()
		self:Dev(player, "traffic hold ambulance off")
	end)
end

function ShowcaseService:StopAll(player: Player): string
	const stopped = self.Dependencies.AnomalyService:DevStop()
	self:Clear(player)
	if self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.ShowcaseScare:fireClient(player, { Id = "", Stop = true })
	end
	return stopped
end

-- Anomalies -----------------------------------------------------------------------------------------------------------

function ShowcaseService:Trigger(player: Player, id: string): string
	const found = row(id)
	if found == nil then
		error(`unknown anomaly "{id}" (ANM-###, key or night number)`, 0)
	end
	const anomalies = self.Dependencies.AnomalyService
	self:EnsureNight(player, if self.Dependencies.RoundService:IsNight() then nil else found.Night)
	anomalies:DevHoldAgenda(true)
	-- a second copy of the same anomaly would confuse the readout and the shared module state: replace it
	anomalies:DevStopKey(found.Key)
	self:Clear(player)
	return anomalies:DevForce(found.Key, false)
end

function ShowcaseService:StopAnomaly(player: Player, id: string): string
	const found = row(id)
	if found == nil then
		error(`unknown anomaly "{id}"`, 0)
	end
	const count = self.Dependencies.AnomalyService:DevStopKey(found.Key)
	self:Clear(player)
	self.Ended[found.Ref] = nil
	return `{found.Ref}: stopped {count} occurrence(s), world restored`
end

-- Sanity --------------------------------------------------------------------------------------------------------------

function ShowcaseService:SetSanity(player: Player, spec: string): string
	const vital = self.Dependencies.VitalService
	const value, max = vital:GetSanity(player)
	if max <= 0 then
		error("no sanity by day: go to a night first", 0)
	end
	local target: number
	if spec == "max" then
		target = max
	else
		const number = tonumber(spec)
		if number == nil then
			error(`bad sanity "{spec}"`, 0)
		end
		const sign = string.sub(spec, 1, 1)
		target = if sign == "+" or sign == "-" then value + number else number
	end
	vital:DevSetSanity(player, target)
	const after = vital:GetSanity(player)
	return `sanity {after}/{max}`
end

-- "sc" helpers --------------------------------------------------------------------------------------------------------

function ShowcaseService:Helper(player: Player, arg: string): string
	const deps = self.Dependencies :: any
	if arg == "revive" then
		return deps.VitalService:DevRevive(player)
	elseif string.sub(arg, 1, 3) == "tp:" then
		const point = string.sub(arg, 4)
		if not self:Teleport(player, point) then
			error(`MapPoint {point} not found or no character`, 0)
		end
		return `teleported to {point}`
	elseif string.sub(arg, 1, 7) == "sanity:" then
		return self:SetSanity(player, string.sub(arg, 8))
	elseif string.sub(arg, 1, 5) == "dark:" then
		const mode = string.sub(arg, 6)
		self:Dev(player, `sanity dark {mode}`)
		return `dark {mode}`
	elseif arg == "cust:random" then
		const outcome, npc = deps.CustomerService:DevSpawn()
		return `{outcome}{if npc then ` (NpcId {npc})` else ""}`
	elseif arg == "carhit" then
		pcall(function()
			self:Dev(player, "traffic spawn")
		end)
		return self:Dev(player, "traffic hit")
	end
	error(`unknown helper "{arg}"`, 0)
end

-- Controls ------------------------------------------------------------------------------------------------------------

function ShowcaseService:Control(player: Player, name: string, value: number, arg: string): string
	const deps = self.Dependencies :: any
	if name == "night" then
		const night = math.floor(value)
		if night < 1 or night > 10 then
			error("night must be 1..10", 0)
		end
		self:EnsureNight(player, night, true)
		deps.AnomalyService:DevHoldAgenda(true)
		return `Night {night}, phase Night`
	elseif name == "clock" then
		self:SetClock(player, value)
		return `clock set ({self:ClockText()})`
	elseif name == "freeze" then
		const round = deps.RoundService
		if self.FrozenElapsed ~= nil then
			self.FrozenElapsed = nil
			return "clock running"
		end
		self.FrozenElapsed = round:DevPhaseElapsed()
		self.FrozenPhase = round:GetPhase()
		return `clock frozen at {self:ClockText()}`
	elseif name == "god" then
		const on = not deps.VitalService:IsDevGod()
		deps.VitalService:DevGod(on)
		return `no-faint {if on then "on" else "off"}`
	elseif name == "hold" then
		const on = not deps.AnomalyService:DevIsHeld()
		deps.AnomalyService:DevHoldAgenda(on)
		return `natural anomaly agenda {if on then "held" else "running"}`
	elseif name == "dawn" then
		self.FrozenElapsed = nil
		self:EnsureNight(player, nil)
		return self:Dev(player, "skip")
	elseif name == "stopall" then
		return self:StopAll(player)
	elseif name == "resetall" then
		self.FrozenElapsed = nil
		deps.VitalService:DevGod(false)
		pcall(function()
			self:Dev(player, "sanity dark auto")
		end)
		deps.AnomalyService:DevHoldAgenda(false)
		self.Ended = {}
		return `reset: {self:StopAll(player)}`
	elseif name == "sanity" then
		return self:SetSanity(player, arg)
	end
	error(`unknown control "{name}"`, 0)
end

-- Dispatcher ----------------------------------------------------------------------------------------------------------

-- One request. Returns (ok, text). Yields (night jumps); callers run it in their own thread.
function ShowcaseService:Run(player: Player, action: string, id: string, arg: string, value: number): (boolean, string)
	if not self:Allowed(player) then
		return false, "showcase is not available here (Studio dev mode and an allowed admin only)"
	end
	const ok, result = pcall(function(): string
		if action == "trigger" then
			return self:Trigger(player, id)
		elseif action == "resolve" then
			return `{id}: {Resolve.Correct(id, self:ResolveEnv(player))}`
		elseif action == "wrong" then
			return `{id}: {Resolve.Wrong(id, self:ResolveEnv(player))}`
		elseif action == "stop" or action == "reset" then
			return self:StopAnomaly(player, id)
		elseif action == "dev" then
			return self:Dev(player, arg)
		elseif action == "sc" then
			return self:Helper(player, arg)
		elseif action == "ctl" then
			return self:Control(player, id, value, arg)
		elseif action == "scare" then
			self.Libs.Net.ShowcaseScare:fireClient(player, { Id = id, Stop = false })
			return `{id}: sent to your client`
		elseif action == "scarestop" then
			self.Libs.Net.ShowcaseScare:fireClient(player, { Id = "", Stop = true })
			return "hallucination stop sent"
		end
		error(`unknown action "{action}"`, 0)
	end)
	if ok then
		return true, result
	end
	return false, tostring(result)
end

-- Panel stream --------------------------------------------------------------------------------------------------------

function ShowcaseService:ClockText(): string
	const total = math.floor(self.Dependencies.RoundService:Minutes())
	return string.format("%02d:%02d", (total // 60) % 24, total % 60)
end

function ShowcaseService:SendCatalog(player: Player)
	local list = self.Catalog
	if list == nil then
		list = Catalog.Build()
		self.Catalog = list
	end
	self.Libs.Net.ShowcaseCatalog:fireClient(player, { Items = list :: any })
end

-- Live occurrences + the ones that ended in the last ENDED_KEEP s
function ShowcaseService:Occurrences(): { { Ref: string, Phase: string, Step: number, Age: number, Live: boolean } }
	const out: { { Ref: string, Phase: string, Step: number, Age: number, Live: boolean } } = {}
	const t = workspace:GetServerTimeNow()
	const seen: { [string]: boolean } = {}
	for _, run in self.Dependencies.AnomalyService:DevRuns() do
		seen[run.Ref] = true
		table.insert(out, { Ref = run.Ref, Phase = run.Phase, Step = run.Step, Age = run.Age, Live = true })
	end
	for ref, ended in self.Ended do
		if not seen[ref] and t - ended.At <= ENDED_KEEP and #out < 32 then
			table.insert(out, { Ref = ref, Phase = ended.Phase, Step = ended.Step, Age = t - ended.At, Live = false })
		end
	end
	return out
end

function ShowcaseService:SendState(player: Player)
	const deps = self.Dependencies :: any
	const vital = deps.VitalService
	const round = deps.RoundService
	const sanity, max = vital:GetSanity(player)
	const darkMode = vital:DevDarkMode()
	local revives = 0
	pcall(function()
		revives = vital:Ensure(player).RevivesTonight
	end)
	self.Libs.Net.ShowcaseState:fireClient(player, {
		Night = if round:IsNight() then math.clamp(round:GetNight(), 0, 10) else 0,
		Phase = round:GetPhase(),
		Clock = round:Minutes(),
		Sanity = math.clamp(math.floor(sanity), 0, 200),
		SanityMax = math.clamp(math.floor(max), 0, 200),
		Life = vital:GetState(player.UserId) or "none",
		Revives = math.clamp(revives, 0, 99),
		Frozen = self.FrozenElapsed ~= nil,
		God = vital:IsDevGod(),
		Dark = if darkMode < 0 then "dark" elseif darkMode > 0 then "lit" else "auto",
		Held = deps.AnomalyService:DevIsHeld(),
		Switch = deps.LightService:IsSwitchOn(),
		Shutter = deps.VehicleService:IsShutterClosed(),
		Vehicle = deps.VehicleService:Current(),
		Running = self:Occurrences(),
	})
end

-- Remembers the last phase of every live anomaly so the panel can say "Resolved 4 s ago" after the record left the set
function ShowcaseService:Track()
	const t = workspace:GetServerTimeNow()
	const live: { [string]: boolean } = {}
	for _, run in self.Dependencies.AnomalyService:DevRuns() do
		live[run.Ref] = true
		self.Alive[run.Ref] = { Phase = run.Phase, Step = run.Step, At = t }
	end
	for ref, last in self.Alive do
		if not live[ref] then
			self.Alive[ref] = nil
			const phase = if last.Phase == "Resolved" or last.Phase == "Failed" then last.Phase else "Ended"
			self.Ended[ref] = { Phase = phase, Step = last.Step, At = t }
		end
	end
end

function ShowcaseService:Step()
	const round = self.Dependencies.RoundService
	const frozen = self.FrozenElapsed
	if frozen ~= nil then
		if round:GetPhase() ~= self.FrozenPhase then
			self.FrozenElapsed = nil
		else
			pcall(function()
				round:DevSetPhaseElapsed(frozen)
			end)
		end
	end
	self:Track()
	const t = os.clock()
	if t < self.NextStateAt then
		return
	end
	self.NextStateAt = t + STATE_EVERY
	for player in self.Viewers do
		if self:Allowed(player) then
			self:SendState(player)
		else
			self.Viewers[player] = nil
		end
	end
end

-- Open / close --------------------------------------------------------------------------------------------------------

-- Asks the player's panel to open (chat command, Conch). The panel then sends "open".
function ShowcaseService:Open(player: Player): (boolean, string)
	if not self:Allowed(player) then
		return false, "showcase is not available here (Studio dev mode and an allowed admin only)"
	end
	self:Reply(player, "open", "open")
	return true, "showcase opening (F9 toggles it)"
end

function ShowcaseService:OnOpen(player: Player)
	self.Viewers[player] = true
	-- the natural agenda would start random anomalies under the test
	self.Dependencies.AnomalyService:DevHoldAgenda(true)
	self:SendCatalog(player)
	self:SendState(player)
end

function ShowcaseService:OnClose(player: Player)
	self.Viewers[player] = nil
	if next(self.Viewers) == nil then
		self.Dependencies.AnomalyService:DevHoldAgenda(false)
		self.FrozenElapsed = nil
	end
end

function ShowcaseService:OnRequest(player: Player, data: { Action: string, Id: string, Arg: string, Value: number })
	if not self:Allowed(player) then
		warn(`{PREFIX} refused {player.Name}: {data.Action}`)
		return
	end
	const action = data.Action
	if action == "open" then
		self:OnOpen(player)
		return
	elseif action == "close" then
		self:OnClose(player)
		return
	end
	task.spawn(function()
		const ok, text = self:Run(player, action, data.Id, data.Arg, data.Value)
		self:Reply(player, if ok then "ok" else "error", text)
	end)
end

ShowcaseService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:IsDev() then
		return
	end
	self.Enabled = true
	self.Libs.Net.ShowcaseDo:onServer(function(data, player: Player)
		self:OnRequest(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		if self.Viewers[player] then
			self:OnClose(player)
		end
	end)
end)

ShowcaseService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return ShowcaseService
