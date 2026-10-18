--!strict
--[[
	OutsideService (owner 2026-10-18: "quando o player está fora do trailer ... se ele passar 30 segundos lá de fora, pega
	um dos modos ... e faz ele perseguir o player"). Run place only, Night phase. Server-authoritative (T10): the clock, the
	chaser's position and the catch are here; OutsideController shows it (whispers, bars, edges, heart, bell, the runner).

	Per Active player, every tick:
	  Count    outside the vehicle interior (VehicleService:IsInside) the clock runs; inside = back to zero. The clock
	           pauses (does not reset) while an anomaly with Tension runs (the street is the anomaly's then).
	  Rise     after Rules.Start s outside: attribute OutsideStage = "Rise", OutsideAt = server time; it lasts Rules.Rise s.
	  Chase    then OutsideStage = "Chase": a chaser appears Rules.SpawnDistance studs away (on the side away from the shop)
	           and runs at the player (Rules.Speed, up to Rules.MaxSpeed after Rules.Ramp s). Attribute ChasePos =
	           its feet, every tick. Inside = escaped (stage cleared). Within Rules.Catch studs (flat) = caught.
	  Caught   OutsideStage = "Caught" (the client shows the face), Rules.Faint s later VitalService:Fall; the stage
	           clears after Rules.Linger s.
	Down / Spectator / not Active = cleared. Never in the lobby.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(ServerScriptService.server.Modux)

type Stage = "" | "Rise" | "Chase" | "Caught"

type Track = {
	Outside: number,
	Stage: Stage,
	StageAt: number,
	Chaser: Vector3?,
}

const RULES = {
	Start = 3, -- s outside before the rise begins (the first words)
	Rise = 30, -- s of rising dread before the chaser comes (owner: "30 segundos")
	SpawnDistance = 60, -- studs from the player where the chaser appears
	Pause = 2.5, -- s it stands and stares before it runs (the bell, the moment to react)
	Speed = 9, -- studs/s at first (the player walks 16: running inside saves him)
	MaxSpeed = 17,
	Ramp = 15, -- s to reach MaxSpeed
	Catch = 3.5, -- studs (flat)
	Faint = 0.7, -- s from the face to the faint
	Linger = 3,
}
const TICK_RATE = 8 -- Hz
const NIGHT_PHASE = "Night"
const SHOP_POINT = "TRL"
const STAGE = "OutsideStage"
const STAGE_AT = "OutsideAt"
const CHASE_POS = "ChasePos"

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	const character = player.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function characters(): { Instance }
	const ignore: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character ~= nil then
			table.insert(ignore, other.Character)
		end
	end
	return ignore
end

local function params(): RaycastParams
	const p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = characters()
	return p
end

-- ground under `at`, looked for from `fromY` (the player's height: never a roof above the street)
local function ground(at: Vector3, fromY: number, p: RaycastParams): Vector3
	const hit = workspace:Raycast(Vector3.new(at.X, fromY + 3, at.Z), Vector3.new(0, -12, 0), p)
	return if hit ~= nil then hit.Position else Vector3.new(at.X, fromY - 3, at.Z)
end

const OutsideService = Modux.Service("OutsideService", {
	Require = { "PlaceService", "RoundService", "RunStateService", "VehicleService", "VitalService", "AnomalyService" },
	Priority = 545,
})

function OutsideService:Setup()
	self.Enabled = false :: boolean
	self.Tracks = {} :: { [Player]: Track }
	self.LastTick = 0 :: number
end

function OutsideService:SetStage(player: Player, track: Track, stage: Stage, t: number)
	track.Stage = stage
	track.StageAt = t
	player:SetAttribute(STAGE, if stage == "" then nil else stage)
	player:SetAttribute(STAGE_AT, if stage == "" then nil else t)
	if stage ~= "Chase" then
		track.Chaser = nil
		player:SetAttribute(CHASE_POS, nil)
	end
end

function OutsideService:Clear(player: Player, track: Track)
	track.Outside = 0
	if track.Stage ~= "" and track.Stage ~= "Caught" then
		self:SetStage(player, track, "", now())
	end
end

-- where the chaser appears: SpawnDistance away from the player, on the side away from the shop
function OutsideService:SpawnFor(root: BasePart): Vector3
	const shop = MapIndex.FindPoint(SHOP_POINT)
	local away = Vector3.new(0, 0, 1)
	if shop ~= nil then
		const d = (root.Position - shop.Position) * Vector3.new(1, 0, 1)
		if d.Magnitude > 1e-3 then
			away = d.Unit
		end
	end
	-- the clearest line among a few headings around "away": as far as SpawnDistance, stopping short of a wall
	const p = params()
	local best = root.Position + away * 20
	local bestDistance = 0
	for _, degrees in { 0, 35, -35, 70, -70, 110, -110, 180 } do
		const dir = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(degrees)):VectorToWorldSpace(away)
		const hit = workspace:Raycast(root.Position, dir * RULES.SpawnDistance, p)
		const distance = if hit ~= nil then (hit.Position - root.Position).Magnitude - 3 else RULES.SpawnDistance
		if distance > bestDistance then
			bestDistance = distance
			best = root.Position + dir * distance
			if distance >= RULES.SpawnDistance - 0.5 then
				break
			end
		end
	end
	return ground(best, root.Position.Y, p)
end

function OutsideService:Step(dt: number)
	const t = now()
	const round = self.Dependencies.RoundService
	const night = round:IsStarted() and round:GetPhase() == NIGHT_PHASE
	const tension = self.Dependencies.AnomalyService:IsTension()
	const vehicles = self.Dependencies.VehicleService
	for _, player in Players:GetPlayers() do
		const existing: Track? = self.Tracks[player]
		const tr: Track = if existing ~= nil then existing else { Outside = 0, Stage = "", StageAt = 0, Chaser = nil } :: Track
		self.Tracks[player] = tr
		const root = rootOf(player)
		if tr.Stage == "Caught" then
			if t - tr.StageAt >= RULES.Linger then
				tr.Outside = 0
				self:SetStage(player, tr, "", t)
			end
			continue
		end
		if not night or root == nil or not self.Dependencies.RunStateService:IsActive(player) or vehicles:IsInside(player) then
			self:Clear(player, tr)
			continue
		end
		if tension then
			continue -- the anomaly owns the street: the clock waits
		end
		tr.Outside += dt
		if tr.Stage == "" and tr.Outside >= RULES.Start then
			self:SetStage(player, tr, "Rise", t)
		elseif tr.Stage == "Rise" and t - tr.StageAt >= RULES.Rise then
			self:SetStage(player, tr, "Chase", t)
			tr.Chaser = self:SpawnFor(root)
			player:SetAttribute(CHASE_POS, tr.Chaser)
		elseif tr.Stage == "Chase" and tr.Chaser ~= nil then
			const into = t - tr.StageAt - RULES.Pause
			if into < 0 then
				continue -- it stands and stares first
			end
			const speed = RULES.Speed + (RULES.MaxSpeed - RULES.Speed) * math.clamp(into / RULES.Ramp, 0, 1)
			const target = Vector3.new(root.Position.X, tr.Chaser.Y, root.Position.Z)
			const offset = target - tr.Chaser
			const flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flat <= RULES.Catch then
				self:SetStage(player, tr, "Caught", t)
				task.delay(RULES.Faint, function()
					if player.Parent ~= nil then
						self.Dependencies.VitalService:Fall(player)
					end
				end)
			else
				const move = math.min(speed * dt, flat)
				const next = tr.Chaser + Vector3.new(offset.X, 0, offset.Z).Unit * move
				tr.Chaser = ground(next, root.Position.Y, params())
				player:SetAttribute(CHASE_POS, tr.Chaser)
			end
		end
	end
	for player in self.Tracks do
		if player.Parent == nil then
			self.Tracks[player] = nil
		end
	end
end

OutsideService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true
end)

OutsideService:OnTick(function(self)
	if not self.Enabled then
		return
	end
	const t = os.clock()
	const dt = if self.LastTick > 0 then math.min(t - self.LastTick, 0.5) else 1 / TICK_RATE
	self.LastTick = t
	self:Step(dt)
end, TICK_RATE)

return OutsideService
