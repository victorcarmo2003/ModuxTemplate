--!strict
-- AnimController/Clips: resolves Content.Animations rows into playable clips (architecture.md §19.20, T47;
-- content-data.md §3.20). Pure data + one Animation instance per id; no Modux, no network.
--
-- Fallback (Content.Animations header): Id "" (or an id whose preload failed) means
--   * Locomotion role -> the stock R6 clip of Roblox for that role (Roblox-owned ids, public);
--   * one-shot -> nothing plays (nil), silently.
-- A role missing from a set also falls back to the stock R6 clip (PROVISIONAL: e.g. Walt has only `walk`, so he
-- idles with the R6 idle instead of the rest pose until AST-069 ships his idle).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Clip = {
	Key: string, -- Content key, or "r6:<role>" for a stock fallback
	Id: string,
	Looped: boolean,
	Priority: Enum.AnimationPriority,
	FadeTime: number,
	Speed: number,
}

-- Stock R6 Animate ids (Roblox-owned). Run reuses walk, as the R6 Animate does.
const R6: { [string]: string } = {
	idle = "rbxassetid://180435571",
	walk = "rbxassetid://180426354",
	run = "rbxassetid://180426354",
	jump = "rbxassetid://125750702",
	fall = "rbxassetid://180436148",
	climb = "rbxassetid://180436334",
	sit = "rbxassetid://178130996",
}
const R6_PRIORITY: { [string]: Enum.AnimationPriority } = {
	idle = Enum.AnimationPriority.Idle,
	sit = Enum.AnimationPriority.Idle,
}
const R6_LOOPED: { [string]: boolean } = { jump = false }
const DEFAULT_FADE = 0.15

const Clips = {}

const animations: { [string]: Animation } = {}
const failed: { [string]: boolean } = {}
const warned: { [string]: boolean } = {}

local function warnOnce(tag: string, message: string)
	if warned[tag] then
		return
	end
	warned[tag] = true
	warn(`[AnimController] {message}`)
end

local function priorityOf(name: string): Enum.AnimationPriority
	const ok, value = pcall(function()
		return (Enum.AnimationPriority :: any)[name]
	end)
	if ok and typeof(value) == "EnumItem" then
		return value :: any
	end
	warnOnce("priority:" .. name, `unknown AnimationPriority "{name}"; using Action`)
	return Enum.AnimationPriority.Action
end

local function usable(id: string): boolean
	return id ~= "" and not failed[id]
end

local function fromRow(row: Content.Animation): Clip
	return {
		Key = row.Key,
		Id = row.Id,
		Looped = row.Looped,
		Priority = priorityOf(row.Priority),
		FadeTime = row.FadeTime,
		Speed = row.Speed,
	}
end

local function stock(role: string): Clip?
	const id = R6[role]
	if id == nil then
		return nil
	end
	return {
		Key = "r6:" .. role,
		Id = id,
		Looped = R6_LOOPED[role] ~= false,
		Priority = R6_PRIORITY[role] or Enum.AnimationPriority.Movement,
		FadeTime = DEFAULT_FADE,
		Speed = 1,
	}
end

-- true = `set` is a key of Content.Animations.Locomotion (warns once when it is not).
function Clips.HasSet(set: string): boolean
	if (Content.Animations.Locomotion :: any)[set] ~= nil then
		return true
	end
	warnOnce("set:" .. set, `unknown locomotion set "{set}"`)
	return false
end

-- true = the set defines `role` (with or without an id).
function Clips.HasRole(set: string, role: string): boolean
	const roles = (Content.Animations.Locomotion :: any)[set] :: { [string]: string }?
	return roles ~= nil and roles[role] ~= nil
end

-- Clip for a locomotion role of a set; the stock R6 clip when the row has no usable id. nil = no clip at all.
function Clips.Locomotion(set: string, role: string): Clip?
	const roles = (Content.Animations.Locomotion :: any)[set] :: { [string]: string }?
	const key = if roles ~= nil then roles[role] else nil
	const row = if key ~= nil then Content.Animations.ByKey[key] else nil
	if row ~= nil and usable(row.Id) then
		return fromRow(row)
	end
	return stock(role)
end

-- Clip of a one-shot (or looped action) key. nil = empty id / failed id (silent) or unknown key (warns once).
function Clips.Action(key: string): Clip?
	const row = Content.Animations.ByKey[key]
	if row == nil then
		warnOnce("key:" .. key, `unknown animation key "{key}"`)
		return nil
	end
	if not usable(row.Id) then
		return nil
	end
	return fromRow(row)
end

-- Shared Animation instance for an id (never parented; LoadAnimation only reads AnimationId).
function Clips.Animation(id: string): Animation
	const cached = animations[id]
	if cached ~= nil then
		return cached
	end
	const animation = Instance.new("Animation")
	animation.Name = id
	animation.AnimationId = id
	animations[id] = animation
	return animation
end

-- Every id worth preloading: the stock R6 locomotion plus every non-empty id of the table.
function Clips.PreloadList(): { Animation }
	const seen: { [string]: boolean } = {}
	const list: { Animation } = {}
	local function add(id: string)
		if id == "" or seen[id] then
			return
		end
		seen[id] = true
		table.insert(list, Clips.Animation(id))
	end
	for _, id in R6 do
		add(id)
	end
	for _, row in Content.Animations.List do
		add(row.Id)
	end
	return list
end

-- Preload result of one id: a failed id falls back from now on (TASK-086: invalid id -> fallback, no error).
function Clips.Report(id: string, ok: boolean)
	if ok then
		return
	end
	for _, stockId in R6 do
		if stockId == id then
			return
		end
	end
	if not failed[id] then
		failed[id] = true
		warnOnce("failed:" .. id, `animation {id} failed to load; using the fallback`)
	end
end

return table.freeze(Clips)
