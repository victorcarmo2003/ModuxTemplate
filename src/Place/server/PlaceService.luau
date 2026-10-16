--!strict
-- Place role and dev mode (architecture.md §1, §2.1, §3.1, §20.1; TASK-010, TASK-154).
-- Role = "Lobby" | "Run", derived from RoleService (one place, server roles; architecture.md §20): Game = "Run",
-- Lobby and PrivateLobby = "Lobby". Same code runs on every server; services that belong to one role return at the
-- top of OnInit/OnStart when Is(role) is false (architecture.md §3.1) — this is the single switch that keeps the run
-- loop (Round, Customer, Traffic...) off in the lobby while Profile, Class and Shop keep running.
-- The authored Workspace.PlaceRole is now read only by RoleService, in Studio (legacy).
-- Dev mode = Run in Studio without PrivateServerId: roster = whoever joins, no MemoryStore, snapshot in memory.
-- OnStart runs MapIndex.Validate (architecture.md §18.8) against Required.ForWave(Content.RunParams.BindingWave)
-- (§19.22, TASK-048): problem in Studio = error (loud), published = warn. Provisional (TASK-048): while the binding of
-- the configured wave is still being authored (TASK-083), a place that passes the previous wave only warns, so the
-- other wave 2 tasks keep play-testing; a place that fails the previous wave too is an error as before.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Roles = require(ReplicatedStorage.shared.ServerRole.Roles)
local Modux = require(ServerScriptService.server.Modux)
local Verbose = require(ReplicatedStorage.shared.Verbose)

export type Role = "Lobby" | "Run"

const PlaceService = Modux.Service("PlaceService", { Require = { "RoleService" }, Priority = 950 })

function PlaceService:Setup()
	const role = Roles.PlaceRole(self.Dependencies.RoleService:Get())
	self.Role = role :: Role
	self.Dev = (role == "Run" and game.PrivateServerId == "" and RunService:IsStudio()) :: boolean
	-- read by PlaceController (the client cannot check PrivateServerId without an engine message)
	ReplicatedStorage:SetAttribute("PlaceDev", self.Dev)
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

-- Problems that break the game, and rule 4 (anchor spacing: prompt comfort only, warned, never an error)
-- Soft notes (optional items, fallbacks in use): one summary line; the details only in dev with Workspace attribute
-- VerboseBinding = true. Hard problems and Seating's required parts stay warnings.
local function soft(self: any, title: string, notes: { string })
	if #notes == 0 then
		return
	end
	if self.Dev and (workspace:GetAttribute("VerboseBinding") == true or Verbose.On()) then
		print(`[PlaceService] {title} has {#notes} note(s):\n  {table.concat(notes, "\n  ")}`)
	end
end

local function split(all: { string }): ({ string }, { string })
	const hard: { string } = {}
	const spacing: { string } = {}
	for _, problem in all do
		table.insert(if string.sub(problem, 1, 2) == "4:" then spacing else hard, problem)
	end
	return hard, spacing
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
		soft(self, "Gear Stand binding (Mart v2)", notes)
	end
	-- Pad tables (TASK-144): soft, warnings only (SeatingService falls back); the optional anchors are no longer noted.
	const seats = MapIndex.SeatingNotes(MapIndex.Required.ForWave(wave))
	if #seats > 0 then
		warn(`[PlaceService] Pad tables binding has {#seats} problem(s):\n  {table.concat(seats, "\n  ")}`)
	end
	-- the cutscene's NO HELP WANTED stop falls back to Rules.Sign.Fallback without a tagged sign: a note, not a problem
	const signTag = Content.Cutscenes.Rules.Sign.Tag
	if #CollectionService:GetTagged(signTag) == 0 then
		soft(self, "intro sign", { `no instance tagged {signTag}: the intro stops at MapPoint {Content.Cutscenes.Rules.Sign.Fallback}` })
	end
	const problems, spacing = split(MapIndex.Validate(MapIndex.Required.ForWave(wave)))
	if #spacing > 0 then
		soft(self, "anchor spacing (rule 4)", spacing)
	end
	if #problems == 0 then
		return
	end
	local fatal = true
	if wave > 1 and #(split(MapIndex.Validate(MapIndex.Required.ForWave(wave - 1)))) == 0 then
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
