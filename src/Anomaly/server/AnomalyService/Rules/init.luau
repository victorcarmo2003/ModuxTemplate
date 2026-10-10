--!strict
-- AnomalyRules, server only (content-data.md §3.17, §6.10; architecture.md §19.13, T10; FEAT-023, FEAT-024; DEC-054,
-- DEC-073, DEC-074; TASK-106). The correct verb, deadlines and steps never reach ReplicatedStorage.
--
-- One file per anomaly next to this one, named by its Ref (Rules/ANM-007.luau), returning an Api.Rule. Added by the
-- task that writes the anomaly (TASK-111/113/115/117); files starting with "_" are skipped. Loaded once on the first
-- require. Validate (DEC-054, DEC-074):
--   Anomaly is a key of Content.Anomalies and the file name is its Ref
--   Verb is one of the 7 (Api.Verbs); Window >= 0; Params is a table
--   IsCritical only on ANM-007 (any other critical rule is loaded with IsCritical = false and a warning)
-- A broken file is warned and skipped: the anomaly then runs without a rule (its module decides what that means).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Api)

-- DEC-074: the critical rule is fixed on The Walker. Not a tuning number: a decision Validate enforces.
const CRITICAL_REF = "ANM-007"

const Rules = {}

const byKey: { [string]: Api.Rule } = {}
local loaded = false

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Checks one rule value against its file name. Returns the frozen rule or (nil, problem).
function Rules.Validate(name: string, value: any): (Api.Rule?, string?)
	if type(value) ~= "table" then
		return nil, `{name}: must return a table`
	end
	const row = if type(value.Anomaly) == "string" then Content.Anomalies.ByKey[value.Anomaly] else nil
	if row == nil then
		return nil, `{name}: Anomaly "{tostring(value.Anomaly)}" is not a key of Content.Anomalies`
	end
	if row.Ref ~= name then
		return nil, `{name}: Anomaly {row.Key} has Ref {row.Ref}; the file must be named {row.Ref}`
	end
	if type(value.Verb) ~= "string" or not Api.Verbs[value.Verb] then
		return nil, `{name}: Verb "{tostring(value.Verb)}" is not one of the 7 verbs (DEC-054)`
	end
	if value.LikelyWrongVerb ~= nil and type(value.LikelyWrongVerb) ~= "string" then
		return nil, `{name}: LikelyWrongVerb must be a string or nil`
	end
	if not finite(value.Window) or value.Window < 0 then
		return nil, `{name}: Window must be a number >= 0`
	end
	if value.Params ~= nil and type(value.Params) ~= "table" then
		return nil, `{name}: Params must be a table`
	end
	local critical = value.IsCritical == true
	if critical and row.Ref ~= CRITICAL_REF then
		warn(`[AnomalyService] Rules/{name}: IsCritical is only allowed on {CRITICAL_REF} (DEC-074); ignored`)
		critical = false
	end
	const params: { [string]: any } = table.clone((value.Params or {}) :: { [string]: any })
	table.freeze(params)
	const rule: Api.Rule = {
		Anomaly = row.Key,
		Verb = value.Verb :: Api.Verb,
		LikelyWrongVerb = value.LikelyWrongVerb :: string?,
		Window = value.Window :: number,
		IsCritical = critical,
		Params = params,
	}
	table.freeze(rule :: any)
	return rule, nil
end

local function load()
	if loaded then
		return
	end
	loaded = true
	const children = script:GetChildren()
	table.sort(children, function(a: Instance, b: Instance): boolean
		return a.Name < b.Name
	end)
	for _, child in children do
		if not child:IsA("ModuleScript") or string.sub(child.Name, 1, 1) == "_" then
			continue
		end
		const ok, value = pcall((require :: any), child)
		if not ok then
			warn(`[AnomalyService] Rules/{child.Name} failed to load: {value}`)
			continue
		end
		const rule, problem = Rules.Validate(child.Name, value)
		if rule == nil then
			warn(`[AnomalyService] Rules/{problem}`)
			continue
		end
		if byKey[rule.Anomaly] ~= nil then
			warn(`[AnomalyService] Rules/{child.Name}: {rule.Anomaly} already has a rule, skipped`)
			continue
		end
		byKey[rule.Anomaly] = rule
	end
end

-- Rule of an anomaly by key (anm_007_walker) or Ref (ANM-007); nil = no rule file.
function Rules.Get(anomaly: string): Api.Rule?
	load()
	const direct = byKey[anomaly]
	if direct ~= nil then
		return direct
	end
	for _, row in Content.Anomalies.List do
		if row.Ref == anomaly then
			return byKey[row.Key]
		end
	end
	return nil
end

-- DEC-074: true only for ANM-007 with its rule file loaded.
function Rules.IsCritical(anomaly: string): boolean
	const rule = Rules.Get(anomaly)
	return rule ~= nil and rule.IsCritical
end

-- Keys with a rule, in Content order (dev listing).
function Rules.Keys(): { string }
	load()
	const out: { string } = {}
	for _, row in Content.Anomalies.List do
		if byKey[row.Key] ~= nil then
			table.insert(out, row.Key)
		end
	end
	return out
end

return Rules
