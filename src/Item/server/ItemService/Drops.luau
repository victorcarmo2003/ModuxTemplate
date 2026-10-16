--!strict
-- Items on the ground (FEAT-036; FEAT-025; DEC-103, DEC-197; architecture.md §19.12; TASK-066). Plain module, no
-- Modux and no network: ItemService owns one Drops and routes pick_up_item here when the anchor is not a free package.
-- World contract with the client (ItemController, TASK-067): every model lives in Workspace.ItemDrops, carries the
-- tag "ItemDrop", attribute Item (key of Content.Items) and attribute Drop = "Keep" (recoverable: pulsing ring) or
-- "Lost" (splat / spill drawn locally for Items[k].DropDespawn seconds). Lost models are named "Splat".
--   Keep: display copy of the kit Tool (a Model, never a Tool) with an Interactable anchor -> pick_up_item (hold
--         DROP_HOLD). Item, Count and Toppings stay on the server (entry by anchor), not on the model. On the street
--         it vanishes after Items[k].DropDespawn seconds (90 s, blinking in the last BLINK_TIME s); on the counter
--         (spectator, DROP-T) at the end of the next shift. A drop that lands on a carriageway moves to the nearest
--         sidewalk NpcNode. Car-hit drops (Owner = userId of who dropped) are tossed from the body to the ground
--         (pastelao arc) and go BACK to the owner (Deps.Return) when the phase changes (Drops.recall) or, while
--         Deps.ReturnOnExpire() holds (day 1 / tutorial), when the timer runs out. The exact state travels in Extra
--         (Stash form: hot dog "ketchup,cheese" / "!..." altered, coffee Restore), so Give rebuilds the same Tool.
--   Lost: invisible anchored marker named "Splat" for Items[k].DropDespawn seconds (2 s); nothing to pick up.
-- Nothing here enters the snapshot (FEAT-036): Clear on every restore.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Required = require(ReplicatedStorage.shared.Place.MapIndex.Required)
local Stash = require(script.Parent.Stash)

export type Deps = {
	Template: (item: string) -> Tool?,
	Display: (template: Tool?, item: string, name: string) -> Model,
	Give: (player: Player, item: string, count: number, extra: string?) -> Tool?,
		-- Item goes back to who dropped it (hands, else stash): phase change, or expiry while ReturnOnExpire().
		Return: (userId: number, item: string, count: number, extra: string?) -> (),
		ReturnOnExpire: () -> boolean,
	IsActive: (player: Player) -> boolean,
	SetPrompt: (anchor: Instance, enabled: boolean) -> (),
	SetPromptHold: (anchor: Instance, hold: number) -> (),
}

export type Entry = {
	Item: string,
	Count: number,
	Extra: string?, -- Stash.Entry.Extra: hot dog toppings ("!" prefix = altered), coffee Restore
	Owner: number?, -- UserId of who dropped it (car hit); nil = counter drop
	Model: Model,
	Anchor: Attachment?,
	-- Counter drops: removed on the ShiftEnded whose shift index reaches this value (nil = timed street drop).
	UntilShift: number?,
}

export type Drops = {
	Deps: Deps,
	Live: { [Entry]: boolean },
	ByAnchor: { [Instance]: Entry },
	Folder: Folder?,
}

const ACTION = "pick_up_item"
const TAG = "Interactable"
const DROP_TAG = "ItemDrop"
const FOLDER = "ItemDrops"
const NODE_TAG = "NpcNode"
-- FEAT-036 "Take" hold 0.5 s. Content.Actions.pick_up_item keeps Hold 0 for the free package and documents the
-- per-anchor PromptHold of dropped items in a comment: no table field yet (Provisional, registered on the board).
const DROP_HOLD = 0.5
const PROMPT_LIFT = 0.5 -- studs above the model top for the prompt anchor
const RAY_UP = 3 -- studs above the drop point where the ground ray starts
const RAY_DOWN = 20 -- studs the ground ray travels
const COUNTER_SPREAD = 1.25 -- studs between items dropped together on the counter
const MARKER_SIZE = 0.2
const BLINK_TIME = 10 -- seconds of blinking before a street drop vanishes
const BLINK_STEP = 0.25
const BLINK_TRANSPARENCY = 0.75
const TOSS_MIN = 0.35 -- seconds of the pastelao toss (grows with the distance, capped at TOSS_MAX)
const TOSS_MAX = 1
const TOSS_LIFT = 2 -- studs above the body where the item leaves
const TOSS_ARC = 3 -- studs of arc height (plus 10% of the distance)
const TOSS_SPIN = math.rad(540)
-- Where a car hit drops the held item (owner request 2026-10-16): right where the player stood, on the floor, out of
-- any prop. The free spot is searched in rings around him; the old "nearest sidewalk" is the last resort.
const SPOT_BOX = Vector3.new(1.4, 1.2, 1.4) -- studs: room the item needs above the floor
const SPOT_RINGS = { 0, 1.5, 3, 4.5 } -- studs from the player
const SPOT_ANGLES = 8
const SPOT_BELOW = 8 -- studs under the root the floor may be (the root stands ~3 above the feet)
const SPOT_ABOVE = 1 -- studs above the root: never a roof or a shelf over his head

const Drops = {}

Drops.Action = ACTION
Drops.Hold = DROP_HOLD

function Drops.new(deps: Deps): Drops
	return { Deps = deps, Live = {}, ByAnchor = {}, Folder = nil }
end

local function folderOf(drops: Drops): Folder
	const existing = drops.Folder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	const folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = Workspace
	drops.Folder = folder
	return folder
end

local function inRoad(position: Vector3, roads: { Required.Rect }): boolean
	for _, road in roads do
		if position.X > road.X0 and position.X < road.X1 and position.Z > road.Z0 and position.Z < road.Z1 then
			return true
		end
	end
	return false
end

-- Ground under a point (characters, drops and untouchable parts ignored); the point itself when nothing is hit.
function Drops.ground(drops: Drops, position: Vector3, ignore: { Instance }): Vector3
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const exclude = table.clone(ignore)
	table.insert(exclude, folderOf(drops))
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	const origin = position + Vector3.yAxis * RAY_UP
	const hit = Workspace:Raycast(origin, Vector3.yAxis * -(RAY_UP + RAY_DOWN), params)
	return if hit then hit.Position else position
end

-- Free floor spot for a car-hit drop at `position` (the player's root): the floor right under it when nothing is in the
-- way, else the nearest free one in rings around it; nil when there is none (the caller falls back to the sidewalk).
function Drops.spot(drops: Drops, position: Vector3, ignore: { Instance }): Vector3?
	const exclude = table.clone(ignore)
	table.insert(exclude, folderOf(drops))
	const rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = exclude
	rayParams.RespectCanCollide = true
	const boxParams = OverlapParams.new()
	boxParams.FilterType = Enum.RaycastFilterType.Exclude
	boxParams.FilterDescendantsInstances = exclude
	boxParams.RespectCanCollide = true
	for _, radius in SPOT_RINGS do
		const count = if radius == 0 then 1 else SPOT_ANGLES
		for index = 0, count - 1 do
			const angle = index / count * math.pi * 2
			const at = position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			const origin = at + Vector3.yAxis * SPOT_ABOVE
			const hit = Workspace:Raycast(origin, Vector3.yAxis * -(SPOT_ABOVE + SPOT_BELOW), rayParams)
			if hit == nil or hit.Normal.Y < 0.7 then
				continue -- no floor, or a wall / slope too steep to rest on
			end
			const room = CFrame.new(hit.Position + Vector3.yAxis * (SPOT_BOX.Y / 2 + 0.05))
			if #Workspace:GetPartBoundsInBox(room, SPOT_BOX, boxParams) == 0 then
				return hit.Position
			end
		end
	end
	return nil
end

-- Off the carriageway (FEAT-036): a point on a road of the binding moves to the nearest NpcNode that is not a
-- crosswalk node and not on a road; any other point stays.
function Drops.sidewalk(position: Vector3): Vector3
	const roads = Required.ForWave(Content.RunParams.BindingWave).Roads
	if not inRoad(position, roads) then
		return position
	end
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, node in CollectionService:GetTagged(NODE_TAG) do
		if not node:IsA("BasePart") or not node:IsDescendantOf(Workspace) or node:GetAttribute("Crosswalk") ~= nil then
			continue
		end
		const spot = node.Position
		if inRoad(spot, roads) then
			continue
		end
		const distance = (Vector3.new(spot.X, position.Y, spot.Z) - position).Magnitude
		if distance < bestDistance then
			best = spot
			bestDistance = distance
		end
	end
	return best or position
end

local function remove(drops: Drops, entry: Entry)
	if not drops.Live[entry] then
		return
	end
	drops.Live[entry] = nil
	if entry.Anchor then
		drops.ByAnchor[entry.Anchor] = nil
	end
	entry.Model:Destroy()
end

local function expire(drops: Drops, entry: Entry)
	if not drops.Live[entry] then
		return
	end
	if entry.Owner ~= nil and drops.Deps.ReturnOnExpire() then
		drops.Deps.Return(entry.Owner, entry.Item, entry.Count, entry.Extra)
	end
	remove(drops, entry)
end

-- Parts blink (server side, replicated) for the last BLINK_TIME seconds, then the drop expires.
local function lifetime(drops: Drops, entry: Entry, despawn: number)
	task.spawn(function()
		const deadline = os.clock() + despawn
		task.wait(math.max(0, despawn - BLINK_TIME))
		const parts: { [BasePart]: number } = {}
		for _, part in entry.Model:GetDescendants() do
			if part:IsA("BasePart") then
				parts[part] = part.Transparency
			end
		end
		local on = false
		while drops.Live[entry] and os.clock() < deadline do
			on = not on
			for part, base in parts do
				part.Transparency = if on then math.max(base, BLINK_TRANSPARENCY) else base
			end
			task.wait(BLINK_STEP)
		end
		expire(drops, entry)
	end)
end

-- Pastelao toss: the anchored model flies from `from` to its resting pivot on a short arc, spinning a little.
local function toss(drops: Drops, entry: Entry, from: Vector3, final: CFrame)
	const model = entry.Model
	const start = from + Vector3.yAxis * TOSS_LIFT
	const distance = (final.Position - start).Magnitude
	const duration = math.clamp(TOSS_MIN + distance / 40, TOSS_MIN, TOSS_MAX)
	const arc = TOSS_ARC + distance * 0.1
	const rotation = final - final.Position
	model:PivotTo(CFrame.new(start) * rotation)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration and drops.Live[entry] do
			elapsed += RunService.Heartbeat:Wait()
			const alpha = math.min(1, elapsed / duration)
			const position = start:Lerp(final.Position, alpha) + Vector3.yAxis * (arc * 4 * alpha * (1 - alpha))
			model:PivotTo(CFrame.new(position) * CFrame.Angles(0, TOSS_SPIN * (1 - alpha), 0) * rotation)
		end
		if drops.Live[entry] then
			model:PivotTo(final)
		end
	end)
end

-- Recoverable item resting on `ground` (bottom of the model there). untilShift = counter rule, nil = street timer.
-- owner = who dropped it (car hit); from = where the body was (toss start), nil = appears in place.
function Drops.keep(
	drops: Drops,
	item: string,
	count: number,
	extra: string?,
	ground: Vector3,
	untilShift: number?,
	owner: number?,
	from: Vector3?
): Entry?
	const row = Content.Items.ByKey[item]
	if row == nil then
		return nil
	end
	const model = drops.Deps.Display(drops.Deps.Template(item), item, `Drop_{item}`)
	model:SetAttribute("Item", item)
	model:SetAttribute("Drop", "Keep")
	const cframe, size = model:GetBoundingBox()
	const offset = model:GetPivot().Position - cframe.Position
	const final = CFrame.new(ground + Vector3.yAxis * (size.Y / 2) + offset)
	model:PivotTo(final)

	const primary = model.PrimaryPart :: BasePart
	const anchor = Instance.new("Attachment")
	anchor.Name = "Prompt_Take"
	anchor.Parent = primary
	anchor.WorldPosition = ground + Vector3.yAxis * (size.Y + PROMPT_LIFT)
	anchor:SetAttribute("PromptAction", ACTION)
	drops.Deps.SetPromptHold(anchor, DROP_HOLD)
	drops.Deps.SetPrompt(anchor, true)

	const entry: Entry = {
		Item = item,
		Count = count,
		Extra = extra,
		Owner = owner,
		Model = model,
		Anchor = anchor,
		UntilShift = untilShift,
	}
	drops.Live[entry] = true
	drops.ByAnchor[anchor] = entry
	CollectionService:AddTag(model, DROP_TAG)
	model.Parent = folderOf(drops)
	-- Tag last: InteractionService gives the EntityId as soon as the tagged anchor is in the Workspace.
	CollectionService:AddTag(anchor, TAG)
	if from ~= nil then
		toss(drops, entry, from, final)
	end

	const despawn = row.DropDespawn
	if untilShift == nil and type(despawn) == "number" then
		lifetime(drops, entry, despawn)
	end
	return entry
end

-- Phase change: every street drop goes back to who dropped it (no litter between phases); counter drops stay.
function Drops.recall(drops: Drops)
	const all: { Entry } = {}
	for entry in drops.Live do
		if entry.Anchor ~= nil and entry.UntilShift == nil then
			table.insert(all, entry)
		end
	end
	for _, entry in all do
		if entry.Owner ~= nil then
			drops.Deps.Return(entry.Owner, entry.Item, entry.Count, entry.Extra)
		end
		remove(drops, entry)
	end
end

-- Altered hot dogs never outlive the Night phase (ITM-020), on the ground either.
function Drops.clearAltered(drops: Drops)
	const all: { Entry } = {}
	for entry in drops.Live do
		if Stash.isAltered({ Kind = entry.Item, Count = entry.Count, Extra = entry.Extra }) then
			table.insert(all, entry)
		end
	end
	for _, entry in all do
		remove(drops, entry)
	end
end

-- Lost item (hot dog splat, spilled coffee): marker named "Splat" for Items[k].DropDespawn seconds.
function Drops.lost(drops: Drops, item: string, ground: Vector3): Entry?
	const row = Content.Items.ByKey[item]
	if row == nil then
		return nil
	end
	const model = Instance.new("Model")
	model.Name = "Splat"
	const marker = Instance.new("Part")
	marker.Name = "Marker"
	marker.Size = Vector3.one * MARKER_SIZE
	marker.Transparency = 1
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.CFrame = CFrame.new(ground)
	marker.Parent = model
	model.PrimaryPart = marker
	model:SetAttribute("Item", item)
	model:SetAttribute("Drop", "Lost")

	const entry: Entry = { Item = item, Count = 1, Extra = nil, Owner = nil, Model = model, Anchor = nil, UntilShift = nil }
	drops.Live[entry] = true
	CollectionService:AddTag(model, DROP_TAG)
	model.Parent = folderOf(drops)
	const despawn = row.DropDespawn
	task.delay(if type(despawn) == "number" then despawn else 0, function()
		remove(drops, entry)
	end)
	return entry
end

-- Point i of n items laid side by side on the counter around `center` (along its right vector).
function Drops.spread(center: CFrame, index: number, total: number): Vector3
	const shift = (index - (total + 1) / 2) * COUNTER_SPREAD
	return (center * CFrame.new(shift, 0, 0)).Position
end

function Drops.owns(drops: Drops, anchor: Instance): boolean
	return drops.ByAnchor[anchor] ~= nil
end

-- InteractionService Validate: a live drop and an active member. Hotbar and package limit are checked by Give.
function Drops.validate(drops: Drops, player: Player, anchor: Instance): boolean
	const entry = drops.ByAnchor[anchor]
	return entry ~= nil and drops.Live[entry] == true and drops.Deps.IsActive(player)
end

-- InteractionService Run (serialized per target). Refused Give = Notice from Give and the item stays.
function Drops.take(drops: Drops, player: Player, anchor: Instance)
	const entry = drops.ByAnchor[anchor]
	if entry == nil or not drops.Live[entry] then
		return
	end
	if drops.Deps.Give(player, entry.Item, entry.Count, entry.Extra) ~= nil then
		remove(drops, entry)
	end
end

-- ShiftEnded of shift number `index`: counter drops whose last shift was this one vanish.
function Drops.shiftEnded(drops: Drops, index: number)
	const expired: { Entry } = {}
	for entry in drops.Live do
		if entry.UntilShift ~= nil and index >= entry.UntilShift then
			table.insert(expired, entry)
		end
	end
	for _, entry in expired do
		remove(drops, entry)
	end
end

-- Restore (lost night, resume): items on the ground are not in the snapshot.
function Drops.clear(drops: Drops)
	const all: { Entry } = {}
	for entry in drops.Live do
		table.insert(all, entry)
	end
	for _, entry in all do
		remove(drops, entry)
	end
end

return table.freeze(Drops)
