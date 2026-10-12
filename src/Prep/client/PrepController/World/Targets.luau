--!strict
-- World/Targets: the registry of the PrepTarget hitboxes (docs/tech/prep-3d.md §2.2, §8; TASK-196). A target is an invisible
-- Part with the tag Rules.World.Tag and the attributes Rules.World.Attr (Kind, Slot, Key) under the real object; a stage can also
-- add targets in code (`Add`). The registry knows which are enabled right now (their `Enabled()` function), sizes the hitboxes so
-- a touch target is never under Rules.World.Hitbox.MinPx on the screen (x AssistScale with Assist), and keeps the one
-- RaycastParams (Include, enabled hitboxes only) the Aim casts against. Nothing is created per frame: Refresh runs at 10 Hz and
-- only writes a property that changed. Everything it makes (fallback boxes) is destroyed by Clear / Destroy.
-- No ProximityPrompt, no ClickDetector. No Modux, no Vide.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Ray = require(script.Parent.Ray)
local Types = require(script.Parent.Types)

-- What a target does (all optional; the stage also hears the same events through Aim's listener).
export type Handlers = {
	Hover: ((entered: boolean) -> ())?, -- the pointer entered (true) or left (false)
	Press: ((point: Vector3) -> ())?, -- a press started on it
	Drop: ((source: Types.Target, point: Vector3) -> ())?, -- something dragged from `source` was released over it
	Tap: ((point: Vector3) -> ())?, -- pressed and released in place
}

export type Spec = {
	Target: Content.PrepTarget,
	Parts: { BasePart },
	Model: Instance?, -- the real object (Highlight adornee); default: the model of the first hitbox
	Enabled: (() -> boolean)?, -- default: always
	Pulse: boolean?, -- invite by pulsing even without hover (touch has no hover)
	Handlers: Handlers?,
}

export type Registry = {
	-- Bumps when the enabled set changes (Aim and Highlight recompute on it).
	Version: number,
	Add: (self: Registry, spec: Spec) -> Types.Target,
	Remove: (self: Registry, id: string) -> (),
	-- A stage changed `Pulse` / `Model` of a target it owns: wakes Aim and Highlight (the version moves).
	Touch: (self: Registry) -> (),
	Get: (self: Registry, id: string) -> Types.Target?,
	-- The target a raycast part belongs to (nil when none, or it is disabled).
	ByPart: (self: Registry, part: Instance) -> Types.Target?,
	-- Every target in registration order (the order of the stage; `X` walks it).
	List: (self: Registry) -> { Types.Target },
	Handlers: (self: Registry, target: Types.Target) -> Handlers?,
	IsEnabled: (self: Registry, target: Types.Target) -> boolean,
	HasEnabled: (self: Registry) -> boolean,
	-- Builds the registry from the tagged hitboxes under `root` that belong to seat `station` (the other seats are puppets).
	-- `enabled` = whether the scanned targets answer the ray until a stage re-adds them with its own Enabled (default true; the 3D
		-- stages pass false and opt in, so a hitbox of another section never hovers).
		Scan: (self: Registry, root: Instance, station: number, enabled: boolean?) -> number,
	-- Re-evaluates Enabled and resizes the hitboxes for the camera; true when the enabled set changed.
	Refresh: (self: Registry, camera: Camera, assist: boolean) -> boolean,
	Params: (self: Registry) -> RaycastParams,
	Clear: (self: Registry) -> (),
	Destroy: (self: Registry) -> (),
}

type Entry = {
	Target: Types.Target,
	Original: { [BasePart]: Vector3 }, -- the authored size of each hitbox
	Enabled: boolean,
	Handlers: Handlers?,
}

const Targets = {}

local function off(): boolean
	return false
end

-- the Station_n model a hitbox sits in (nil when none): only the hitboxes of the own seat are targets
local function stationOf(instance: Instance): number?
	local current: Instance? = instance
	while current ~= nil do
		const number = string.match(current.Name, "^Station_(%d+)$")
		if number ~= nil then
			return tonumber(number)
		end
		current = current.Parent
	end
	return nil
end

function Targets.new(rules: Content.PrepWorldRules, folder: Folder?): Registry
	const entries: { Entry } = {}
	const byId: { [string]: Entry } = {}
	const byPart: { [Instance]: Entry } = {}
	const fallbacks: { Instance } = {}
	const params = Ray.NewParams()
	const kinds = Content.Prep.TargetKinds :: { string }
	local version = 0
	local listDirty = true
	local ordered: { Types.Target } = {}
	local warned: { [string]: boolean } = {}

	const self = { Version = 0 } :: any

	local function warnOnce(key: string, message: string)
		if not warned[key] then
			warned[key] = true
			warn(`[PrepWorld] {message}`)
		end
	end

	local function prepare(part: BasePart)
		-- a hitbox is only ever seen by a ray
		part.CanQuery = true
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = true
		part.Transparency = 1
	end

	function self.Add(_: any, spec: Spec): Types.Target
		const target: Types.Target = {
			Target = spec.Target,
			Parts = spec.Parts,
			Model = spec.Model or (if spec.Parts[1] ~= nil then spec.Parts[1]:FindFirstAncestorOfClass("Model") else nil),
			Enabled = spec.Enabled or function(): boolean
				return true
			end,
			Pulse = spec.Pulse == true,
		}
		const original: { [BasePart]: Vector3 } = {}
		for _, part in spec.Parts do
			prepare(part)
			original[part] = part.Size
		end
		const old = byId[spec.Target.Id]
		if old ~= nil then
			self:Remove(spec.Target.Id)
		end
		const entry: Entry = { Target = target, Original = original, Enabled = false, Handlers = spec.Handlers }
		table.insert(entries, entry)
		byId[spec.Target.Id] = entry
		for _, part in spec.Parts do
			byPart[part] = entry
		end
		listDirty = true
		version += 1
		self.Version = version
		return target
	end

	function self.Remove(_: any, id: string)
		const entry = byId[id]
		if entry == nil then
			return
		end
		for part, size in entry.Original do
			byPart[part] = nil
			if part.Parent ~= nil then
				part.Size = size
			end
		end
		byId[id] = nil
		const index = table.find(entries, entry)
		if index ~= nil then
			table.remove(entries, index)
		end
		listDirty = true
		version += 1
		self.Version = version
	end

	function self.Touch(_: any)
		version += 1
		self.Version = version
	end

	function self.Get(_: any, id: string): Types.Target?
		const entry = byId[id]
		return if entry ~= nil then entry.Target else nil
	end

	function self.ByPart(_: any, part: Instance): Types.Target?
		const entry = byPart[part]
		if entry ~= nil and entry.Enabled then
			return entry.Target
		end
		return nil
	end

	function self.List(_: any): { Types.Target }
		if listDirty then
			table.clear(ordered)
			for _, entry in entries do
				table.insert(ordered, entry.Target)
			end
			listDirty = false
		end
		return ordered
	end

	function self.Handlers(_: any, target: Types.Target): Handlers?
		const entry = byId[target.Target.Id]
		return if entry ~= nil then entry.Handlers else nil
	end

	function self.IsEnabled(_: any, target: Types.Target): boolean
		const entry = byId[target.Target.Id]
		return entry ~= nil and entry.Enabled
	end

	function self.HasEnabled(_: any): boolean
		for _, entry in entries do
			if entry.Enabled then
				return true
			end
		end
		return false
	end

	function self.Scan(_: any, root: Instance, station: number, enabled: boolean?): number
		const found: { [string]: { Kind: string, Slot: number, Key: string, Parts: { BasePart }, Model: Instance? } } = {}
		const order: { string } = {}
		const attr = rules.Attr
		for _, instance in CollectionService:GetTagged(rules.Tag) do
			if not instance:IsDescendantOf(root) then
				continue
			end
			const seat = stationOf(instance)
			if seat ~= nil and seat ~= station then
				continue
			end
			const kind = instance:GetAttribute(attr.Kind)
			if type(kind) ~= "string" or table.find(kinds, kind) == nil then
				warnOnce(instance:GetFullName(), `{instance:GetFullName()} has the tag {rules.Tag} but no valid {attr.Kind}`)
				continue
			end
			const slotValue = instance:GetAttribute(attr.Slot)
			const keyValue = instance:GetAttribute(attr.Key)
			const slot = if type(slotValue) == "number" then slotValue else 0
			const key = if type(keyValue) == "string" then keyValue else ""
			-- the board is the one of the own seat
			if kind == "Board" and slot ~= 0 and slot ~= station then
				continue
			end
			const id = Types.IdOf(kind :: Content.PrepTargetKind, slot, key)
			local part: BasePart? = nil
			local model: Instance? = nil
			if instance:IsA("BasePart") then
				part = instance
				model = instance:FindFirstAncestorOfClass("Model")
			elseif instance:IsA("Model") and folder ~= nil then
				-- no hitbox authored: a box from the model, once, loudly
				const cframe, size = instance:GetBoundingBox()
				const box = Instance.new("Part")
				box.Name = `Hitbox_{id}`
				box.Anchored = true
				box.Size = size
				box.CFrame = cframe
				box.Parent = folder
				table.insert(fallbacks, box)
				part = box
				model = instance
				warnOnce(`fallback:{id}`, `{instance:GetFullName()} has no hitbox part: a box from the model is used`)
			end
			if part == nil then
				continue
			end
			local record = found[id]
			if record == nil then
				record = { Kind = kind, Slot = slot, Key = key, Parts = {}, Model = model }
				found[id] = record
				table.insert(order, id)
			end
			table.insert(record.Parts, part)
		end
		-- the order of a stage: by kind, then slot, then id
		table.sort(order, function(a: string, b: string): boolean
			const ra, rb = found[a], found[b]
			const ka, kb = table.find(kinds, ra.Kind) or 0, table.find(kinds, rb.Kind) or 0
			if ka ~= kb then
				return ka < kb
			end
			if ra.Slot ~= rb.Slot then
				return ra.Slot < rb.Slot
			end
			return a < b
		end)
		for _, id in order do
			const record = found[id]
			self:Add({
				Target = Types.Target(record.Kind :: Content.PrepTargetKind, record.Slot, record.Key),
				Parts = record.Parts,
				Model = record.Model,
				-- `enabled` false: off until a stage re-adds the target with its own Enabled (a hitbox of another section never hovers)
				Enabled = if enabled == false then off else nil,
			})
		end
		if #entries > rules.Budget.Hitboxes then
			warnOnce("budget", `{#entries} targets over the budget of {rules.Budget.Hitboxes}`)
		end
		return #order
	end

	-- the studs a screen size of `px` covers at `distance` from the camera
	local function studsOf(camera: Camera, distance: number, px: number): number
		const viewport = camera.ViewportSize
		const perStud = viewport.Y / (2 * math.max(distance, 0.1) * math.tan(math.rad(camera.FieldOfView) / 2))
		return px / math.max(perStud, 1e-3)
	end

	function self.Refresh(_: any, camera: Camera, assist: boolean): boolean
		const hitbox = rules.Hitbox
		const scale = if assist then hitbox.AssistScale else 1
		local changed = false
		for _, entry in entries do
			const enabled = entry.Target.Enabled()
			if enabled ~= entry.Enabled then
				entry.Enabled = enabled
				changed = true
			end
			if not enabled then
				continue
			end
			-- max(visual size, the 44 px of a finger at this distance and 0.31 stud) x 1.3 with Assist
			for part, original in entry.Original do
				if part.Parent == nil then
					continue
				end
				const distance = (part.Position - camera.CFrame.Position).Magnitude
				const minimum = math.max(hitbox.MinStuds, studsOf(camera, distance, hitbox.MinPx))
				const want = Vector3.new(math.max(original.X, minimum) * scale, math.max(original.Y, minimum) * scale, math.max(original.Z, minimum) * scale)
				if (part.Size - want).Magnitude > want.Magnitude * 0.02 then
					part.Size = want
				end
			end
		end
		if changed then
			const list: { Instance } = {}
			for _, entry in entries do
				if entry.Enabled then
					for part in entry.Original do
						table.insert(list, part)
					end
				end
			end
			params.FilterDescendantsInstances = list
			version += 1
			self.Version = version
		end
		return changed
	end

	function self.Params(_: any): RaycastParams
		return params
	end

	function self.Clear(_: any)
		for _, entry in entries do
			for part, size in entry.Original do
				if part.Parent ~= nil then
					part.Size = size
				end
			end
		end
		table.clear(entries)
		table.clear(byId)
		table.clear(byPart)
		table.clear(ordered)
		for _, box in fallbacks do
			box:Destroy()
		end
		table.clear(fallbacks)
		params.FilterDescendantsInstances = {}
		listDirty = true
		version += 1
		self.Version = version
	end

	function self.Destroy(_: any)
		self:Clear()
		table.clear(warned)
	end

	return self :: Registry
end

return Targets
