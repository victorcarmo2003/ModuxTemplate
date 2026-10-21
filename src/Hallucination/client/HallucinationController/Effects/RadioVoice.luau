--!strict
-- radio_voice (< 40, family D; anomalies-v2-proposal.md §3 D; DEC-254): the vehicle's radio catches static and ONE
-- line from nobody ("Radio: ..."), then static again. No prompt, no answer, not a call (FEAT-018). Only while no
-- real boss call is up and the player is in or next to the vehicle; a real call cancels it at once.
-- Source: a part named like "Radio" in the vehicle; else the vehicle's centre (the trailer has no radio model yet).
-- Static = `phone_glitch` (Provisional until a radio static key exists), once and cut in the middle (Context.Glitch,
-- owner 2026-10-21: it used to play again at the end, on top of the first one). Lines are original, short and Mild.
local Context = require(script.Parent.Parent.Context)
local Lines = require(script.Parent.Parent.Lines)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VehicleRoot = require(ReplicatedStorage.shared.Vehicle.VehicleRoot)

const SPEAKER = "Radio"
-- TASK-601: the lines are Content.Hallucinations.RadioLines, by night (Lines.Next "Radio")
const NEAR = 8 -- studs of margin around the vehicle box
const LINE_TIME = 2.6
const STEP = 0.1

local function source(env: Context.Env): Instance?
	const vehicle = env.Vehicle()
	if vehicle == nil then
		return nil
	end
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("BasePart") and string.find(string.lower(descendant.Name), "radio", 1, true) then
			return descendant
		end
	end
	return vehicle
end

local function near(env: Context.Env): boolean
	const vehicle = env.Vehicle()
	const root = Context.Root()
	if vehicle == nil or root == nil or not (vehicle:IsA("Model") or vehicle:IsA("Folder")) then
		return false
	end
	const frame, size = VehicleRoot.Box(vehicle)
	const point = frame:PointToObjectSpace(root.Position)
	const half = size / 2 + Vector3.new(NEAR, NEAR, NEAR)
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

-- Waits `seconds` while no real call comes up; false = cancelled or a real call.
local function hold(env: Context.Env, run: Context.Run, seconds: number): boolean
	const started = os.clock()
	while os.clock() - started < seconds do
		if not env.CallIdle() or not run:Wait(STEP) then
			return false
		end
	end
	return true
end

const RadioVoice: Context.Effect = {
	CanRun = function(env: Context.Env): boolean
		return env.CallIdle() and near(env)
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const host = source(env)
		if host == nil then
			return
		end
		const at: Vector3 | Instance = if host:IsA("Model") then host:GetPivot().Position else host
		run:Cleanup(function()
			env.Subtitle(SPEAKER, "")
		end)
		Context.Glitch(env, at, { Volume = 0.6, Speed = 0.9 })
		if not hold(env, run, 0.9) then
			return
		end
		const picked = Lines.Next("Radio", env.Night(), env.Random)
		if picked == nil then
			return
		end
		const line = picked.Text
		env.Subtitle(SPEAKER, line)
		-- owner 2026-10-18: the stranger is voiced (pre-generated "radio" voice, Speech through BossController)
		pcall(function()
			const client = script:FindFirstAncestor("client")
			const feature = if client then client:FindFirstChild("Boss") else nil
			const module = if feature then feature:FindFirstChild("BossController") else nil
			if module ~= nil and module:IsA("ModuleScript") then
				const boss: any = (require :: any)(module)
				boss:Speak(line, "radio")
			end
		end)
		if not hold(env, run, LINE_TIME) then
			return
		end
		env.Subtitle(SPEAKER, "")
	end,
}

return RadioVoice
