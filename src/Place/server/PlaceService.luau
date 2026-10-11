--!strict
-- Place role and dev mode (architecture.md §1, §2.1, §3.1; TASK-010).
-- Role = authored attribute Workspace.PlaceRole ("Lobby" | "Run"). Same code runs on both places; services that
-- belong to one role return at the top of OnInit/OnStart when Is(role) is false (architecture.md §3.1).
-- Dev mode = Run place in Studio without PrivateServerId: roster = whoever joins, no MemoryStore, snapshot in memory.
-- Provisional (TASK-010): a missing PlaceRole reads as "Run" (wave 1 ships only the Run place), and dev mode also
-- needs RunService:IsStudio(), so a public Run server can never expose dev commands (gems, skip day).
-- OnStart runs MapIndex.Validate (architecture.md §18.8) against Required.ForWave(Content.RunParams.BindingWave)
-- (§19.22, TASK-048): problem in Studio = error (loud), published = warn. Provisional (TASK-048): while the binding of
-- the configured wave is still being authored (TASK-083), a place that passes the previous wave only warns, so the
-- other wave 2 tasks keep play-testing; a place that fails the previous wave too is an error as before.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(ServerScriptService.server.Modux)

export type Role = "Lobby" | "Run"

const ROLE_ATTRIBUTE = "PlaceRole"
const DEFAULT_ROLE: Role = "Run"

local function readRole(): (Role, string?)
	const raw = workspace:GetAttribute(ROLE_ATTRIBUTE)
	if raw == "Lobby" or raw == "Run" then
		return raw, nil
	end
	if raw == nil then
		return DEFAULT_ROLE, `Workspace.{ROLE_ATTRIBUTE} is not set; reading as "{DEFAULT_ROLE}" (wave 1)`
	end
	return DEFAULT_ROLE, `Workspace.{ROLE_ATTRIBUTE} = {tostring(raw)} is not "Lobby"/"Run"; reading as "{DEFAULT_ROLE}"`
end

const PlaceService = Modux.Service("PlaceService", { Priority = 950 })

function PlaceService:Setup()
	const role, problem = readRole()
	if problem then
		warn(`[PlaceService] {problem}`)
	end
	self.Role = role :: Role
	self.Dev = (role == "Run" and game.PrivateServerId == "" and RunService:IsStudio()) :: boolean
end

function PlaceService:Is(role: Role): boolean
	return self.Role == role
end

function PlaceService:IsDev(): boolean
	return self.Dev
end

local function report(wave: number, problems: { string }): string
	return `[PlaceService] map binding (wave {wave}) has {#problems} problem(s):\n  {table.concat(problems, "\n  ")}`
end

-- Runtime twin of the edit-time check (architecture.md §18.7). No binding root yet = TASK-005 pending: warn only.
function PlaceService:ValidateMap()
	if not self:Is("Run") then
		return
	end
	if not MapIndex.HasBinding() then
		warn("[PlaceService] no MapBinding in the Workspace (TASK-005 pending): map checks skipped")
		return
	end
	const wave = Content.RunParams.BindingWave
	-- Mart v2 Gear Stand (TASK-135): soft, warnings only while TASK-138 builds the kiosk.
	const notes = MapIndex.KioskNotes(MapIndex.Required.ForWave(wave))
	if #notes > 0 then
		warn(`[PlaceService] Gear Stand binding (Mart v2) has {#notes} note(s):\n  {table.concat(notes, "\n  ")}`)
	end
	-- Pad tables (TASK-144): soft, warnings only until TASK-149 binds them (SeatingService falls back).
	const seats = MapIndex.SeatingNotes(MapIndex.Required.ForWave(wave))
	if #seats > 0 then
		warn(`[PlaceService] Pad tables binding has {#seats} note(s):\n  {table.concat(seats, "\n  ")}`)
	end
	const problems = MapIndex.Validate(MapIndex.Required.ForWave(wave))
	if #problems == 0 then
		return
	end
	local fatal = true
	if wave > 1 and #MapIndex.Validate(MapIndex.Required.ForWave(wave - 1)) == 0 then
		fatal = false
		warn(`[PlaceService] binding passes wave {wave - 1} but not wave {wave} yet (binding task pending)`)
	end
	const text = report(wave, problems)
	if fatal and RunService:IsStudio() then
		error(text, 0)
	end
	warn(text)
end

PlaceService:OnInit(function(self)
	self:Setup()
end)

PlaceService:OnStart(function(self)
	self:ValidateMap()
end)

return PlaceService
