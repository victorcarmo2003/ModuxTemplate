--!strict
--[[
	HallucinationController (TASK-119; architecture.md §19.15; FEAT-019; script.md §8; content-data.md §6.11;
	DEC-038, DEC-123, DEC-168, DEC-169, DEC-173; AST-085)

	Low-sanity hallucinations on THIS client only. Never a prompt, never a packet, never a set, never a server state;
	never counts as an anomaly seen, never opens a test, never moves the Walker, never costs the -5 of "seeing".
	The low band no longer dresses NPCs Night (Provisional 2026-10-14); the player's own Night is the server's.

	Rolls (Content.Hallucinations, local seed):
	  * eligible while own sanity exists (VitalController.Max > 0), the shift is the Night phase (Rules.NightOnly,
	    RoundController.IsNight + Phase "Night"; no cutscene, finale or night-lost) and the own life state is Active;
	  * every Rules.Interval {min, max} seconds one roll: rows with Sanity < MaxSanity (60 / 40 / 20), out of their
	    Cooldown, whose Effects/<Effect> module exists and whose CanRun holds; pick by Weight;
	  * nothing to play -> retry in RETRY seconds; one effect at a time; leaving the eligible state cancels it and the
	    run's cleanups undo every local write (lamps, rigs, cards, subtitle).

	Effects/<Effect>.luau are discovered (module name = Hallucinations.Effect). Contract in Context.luau.
	Sound keys that Content.Sounds does not have yet (SFX-130/131/133/134) are skipped silently (Q-168).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local CollectionService = game:GetService("CollectionService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Components = StarterPlayer.StarterPlayerScripts.client.Interface.Components
local CallSubtitle = require(Components.CallSubtitle)
local WhisperLine = require(Components.WhisperLine)
local Context = require(script.Context)

const RULES = Content.HallucinationRules
const ROWS = Content.Hallucinations.List
const NIGHT_PHASE = "Night"
const VEHICLE_TAG = "Vehicle"
const TICK_RATE = 4 -- Hz: eligibility and roll checks
const RETRY = 5 -- s: next try when nothing could play
const SPEAKER = "Walt"

const HallucinationController = Modux.Controller("HallucinationController", {
	Require = { "VitalController", "RoundController", "AudioController", "BossController", "KitchenController" },
	Priority = 600,
})

function HallucinationController:Setup()
	self.Random = Random.new() :: Random -- local seed (architecture.md §19.15)
	self.Effects = {} :: { [string]: Context.Effect }
	self.CooldownUntil = {} :: { [string]: number }
	self.NextRollAt = 0 :: number -- 0 = not scheduled (not eligible)
	self.Active = nil :: Context.Run?
	self.ActiveKey = "" :: string
	-- what the screen shows (fake call strip, whisper line)
	self.Speaker = Vide.source(SPEAKER) :: Vide.Source<string>
	self.Line = Vide.source("") :: Vide.Source<string>
	self.Showing = Vide.source(false) :: Vide.Source<boolean>
	self.WhisperText = Vide.source("") :: Vide.Source<string>
	self.Env = nil :: Context.Env?
	self.Gui = nil :: ScreenGui?
end

-- Effects/<name> modules; rows naming a missing module warn once and never roll.
function HallucinationController:LoadEffects()
	const folder = script:FindFirstChild("Effects")
	for _, row in ROWS do
		const module = if folder then folder:FindFirstChild(row.Effect) else nil
		if module and module:IsA("ModuleScript") then
			const ok, result = pcall(require, module)
			if ok and type(result) == "table" and type((result :: any).Play) == "function" then
				self.Effects[row.Effect] = result :: Context.Effect
			else
				warn(`[HallucinationController] Effects/{row.Effect} failed to load: {result}`)
			end
		else
			warn(`[HallucinationController] no Effects/{row.Effect} for '{row.Key}'`)
		end
	end
end

function HallucinationController:FindVehicle(): Instance?
	const key = self.Dependencies.RoundController.Vehicle()
	for _, vehicle in CollectionService:GetTagged(VEHICLE_TAG) do
		if vehicle:GetAttribute("Vehicle") == key then
			return vehicle
		end
	end
	return nil
end

function HallucinationController:BuildEnv(): Context.Env
	const deps = self.Dependencies
	const audio = deps.AudioController
	return {
		Random = self.Random,
		Sound = function(key: string, at: (Vector3 | Instance)?, opts: Context.PlayOptions?): Sound?
			if Content.Sounds.ByKey[key] == nil then
				return nil -- no key yet (Q-168): silent on purpose, no warning
			end
			return audio:Play(key, at, opts)
		end,
		Loop = function(key: string, at: (Vector3 | Instance)?, on: boolean)
			if Content.Sounds.ByKey[key] == nil then
				return
			end
			audio:Loop(key, at, on)
		end,
		VehicleKey = function(): string
			return Vide.untrack(deps.RoundController.Vehicle)
		end,
		Vehicle = function(): Instance?
			return self:FindVehicle()
		end,
		CallIdle = function(): boolean
			return Vide.untrack(deps.BossController.State) == "Idle"
		end,
		SlotState = function(recordId: number): string?
			const record = Vide.untrack(function()
				return deps.KitchenController:SlotOf(recordId)
			end)
			return if record then record.State else nil
		end,
		Subtitle = function(speaker: string, text: string)
			-- "" hides the strip but keeps the last line while it fades out
			Vide.batch(function()
				if text ~= "" then
					self.Speaker(speaker)
					self.Line(text)
				end
				self.Showing(text ~= "")
			end)
		end,
		Whisper = function(text: string)
			self.WhisperText(text)
		end,
	}
end

-- Eligible for hallucinations right now (own sanity, Night phase, Active).
function HallucinationController:Eligible(): boolean
	const vital = self.Dependencies.VitalController
	const round = self.Dependencies.RoundController
	if Vide.untrack(vital.Max) <= 0 or Vide.untrack(vital.LocalState) ~= "Active" then
		return false
	end
	if RULES.NightOnly and not (Vide.untrack(round.IsNight) and Vide.untrack(round.Phase) == NIGHT_PHASE) then
		return false
	end
	return true
end

function HallucinationController:Cancel()
	const run = self.Active
	self.Active = nil
	self.ActiveKey = ""
	if run then
		run:Finish()
	end
end

function HallucinationController:Schedule(now: number, seconds: number?)
	const interval = RULES.Interval
	self.NextRollAt = now + (seconds or self.Random:NextNumber(interval[1], interval[2]))
end

-- Rows that may play now, in table order.
function HallucinationController:Candidates(now: number, env: Context.Env): { Content.Hallucination }
	const sanity = Vide.untrack(self.Dependencies.VitalController.Sanity)
	const out: { Content.Hallucination } = {}
	for _, row in ROWS do
		const effect = self.Effects[row.Effect]
		if effect and sanity < row.MaxSanity and now >= (self.CooldownUntil[row.Key] or 0) then
			local can = true
			if effect.CanRun then
				const ok, result = pcall(effect.CanRun, env)
				can = ok and result == true
			end
			if can then
				table.insert(out, row)
			end
		end
	end
	return out
end

function HallucinationController:Start(row: Content.Hallucination, env: Context.Env, now: number)
	const effect = self.Effects[row.Effect]
	const run = Context.NewRun()
	self.Active = run
	self.ActiveKey = row.Key
	self.CooldownUntil[row.Key] = now + row.Cooldown
	task.spawn(function()
		const ok, err = pcall(effect.Play, env, run)
		if not ok then
			warn(`[HallucinationController] {row.Key} failed: {err}`)
		end
		run:Finish()
		if self.Active == run then
			self.Active = nil
			self.ActiveKey = ""
		end
	end)
end

function HallucinationController:Step()
	const now = os.clock()
	if not self:Eligible() then
		self:Cancel()
		self.NextRollAt = 0
		return
	end
	if self.NextRollAt == 0 then
		self:Schedule(now) -- first roll one Interval after becoming eligible
		return
	end
	if self.Active ~= nil or now < self.NextRollAt then
		return
	end
	const env = self.Env
	if env == nil then
		return
	end
	const row = Context.Pick(self.Random, self:Candidates(now, env), function(candidate: Content.Hallucination): number
		return candidate.Weight
	end)
	if row == nil then
		self:Schedule(now, RETRY)
		return
	end
	self:Start(row, env, now)
	self:Schedule(now)
end

-- Showcase (ShowcaseController; docs/tech/showcase.md): plays one effect now, ignoring sanity, the night phase, the
-- cooldowns and the roll timer (the natural roll resumes afterwards). A failed CanRun is reported, not obeyed, so the
-- effect can be seen even where its usual precondition is missing (it may then show nothing). Returns a result line.
function HallucinationController:DevPlay(key: string): string
	const env = self.Env
	if env == nil then
		return "hallucination env not ready yet"
	end
	local found: Content.Hallucination? = nil
	for _, row in ROWS do
		if row.Key == key then
			found = row
			break
		end
	end
	if found == nil then
		return `no hallucination "{key}"`
	end
	const effect = self.Effects[found.Effect]
	if effect == nil then
		return `{key}: Effects/{found.Effect} is not loaded`
	end
	self:Cancel()
	local note = ""
	if effect.CanRun then
		const ok, can = pcall(effect.CanRun, env)
		if not (ok and can == true) then
			note = " (CanRun was false: forced anyway)"
		end
	end
	self:Start(found, env, os.clock())
	return `{key} playing{note}`
end

function HallucinationController:DevStop(): string
	const was = self.ActiveKey
	self:Cancel()
	return if was ~= "" then `stopped {was}` else "nothing playing"
end

function HallucinationController:DevActive(): string
	return self.ActiveKey
end

function HallucinationController:Mount(playerGui: Instance)
	const boss = self.Dependencies.BossController
	const round = self.Dependencies.RoundController
	const _, gui = Vide.root(function()
		return Vide.create("ScreenGui")({
			Name = "Hallucination",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 2, -- same layer as the real call strip (BossCall)

			CallSubtitle({
				Name = "FakeCall",
				Visible = self.Showing,
				Speaker = self.Speaker,
				Text = self.Line,
				Phone = round.Vehicle,
				Scale = boss.Scale,
			}),
			WhisperLine({
				Text = self.WhisperText,
				Scale = boss.Scale,
			}),
		})
	end)
	self.Gui = gui
	gui.Parent = playerGui
end

HallucinationController:OnInit(function(self)
	self:Setup()
	self:LoadEffects()
end)

HallucinationController:OnStart(function(self)
	self.Env = self:BuildEnv()
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

HallucinationController:OnTick(function(self)
	self:Step()
end, TICK_RATE)

return HallucinationController
