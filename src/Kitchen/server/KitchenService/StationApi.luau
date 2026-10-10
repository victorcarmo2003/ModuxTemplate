--!strict
-- Contract between KitchenService and the station modules in KitchenService/Stations/*.luau (architecture.md §18.12,
-- T37; TASK-025). Each file there returns a Module. Plain module: no Modux, Lync, atoms or other Services.
-- Additions to §18.12 made by TASK-025 (Provisional, architect to fold back into the doc):
--   Station.Key      stable snapshot key ("cart/grill"; "/2", "/3"... for a repeated kind on the same vehicle)
--   Station.Anchors  Interactable anchors owned by the station (nearest Station ancestor)
--   Station.Records  set records of the station by Slot (0 = single-record station). The module writes here and calls
--                    ctx.Publish(station); KitchenService diffs it into the Stations set (add/update/remove).
--   Module.Refresh   optional: called after Station.Slots was rebuilt (upgrade level of the station changed)

export type SlotState = "Empty" | "Working" | "Ready"

-- network.md §3.5. Id on the wire = Station.Id * 100 + Slot. Kind must be a Content.Stations.RecordKeys key.
export type Record = {
	Kind: string,
	State: SlotState,
	StartedAt: number, -- workspace:GetServerTimeNow(); 0 = idle
	Duration: number, -- seconds, level and class already applied (0..120)
	Count: number, -- rail: sausages on it; others 0 (0..30)
}

export type Station = {
	Kind: string, -- StationKind
	Vehicle: string, -- Vehicle attribute of the Vehicle ancestor
	Instance: Model,
	Id: number, -- StationId (runtime, 1..99)
	Key: string, -- stable snapshot key
	Ingredient: string?, -- station's single ingredient (attribute or Content.Stations row); nil for PerAnchor/none
	Slots: { [number]: Attachment }, -- Attachment with Slot, filtered by the Level of the station's upgrade
	Anchors: { Instance },
	Records: { [number]: Record },
	State: any, -- module's private state, created in Bind
}

-- Only functions: the module never sees Lync, an atom or a whole Service.
export type Context = {
	Now: () -> number, -- workspace:GetServerTimeNow()
	TakeStock: (ingredient: string, n: number) -> boolean,
	GetStock: (ingredient: string) -> (number, number), -- current, capacity
	Give: (player: Player, item: string, attrs: { [string]: any }?) -> boolean, -- attrs: Toppings, Count
	Held: (player: Player) -> Tool?,
	Consume: (player: Player, tool: Tool) -> (),
	Modifier: (player: Player, stat: string) -> number, -- ClassService
	Effect: (stat: string) -> number, -- UpgradeService, current vehicle
	Publish: (station: Station) -> (), -- KitchenService writes the Stations set from station.Records
	Notify: (player: Player, notice: string, value: number?) -> (),
	SetPrompt: (anchor: Instance, enabled: boolean, text: string?) -> (),
}

-- Validate returns (ok, notice?): a Content.Notices key in the second value is sent to the player on refusal.
export type Action = {
	Validate: (ctx: Context, station: Station, player: Player, anchor: Instance) -> (boolean, string?),
	Run: (ctx: Context, station: Station, player: Player, anchor: Instance) -> (),
}

export type Module = {
	Kinds: { string },
	Actions: { [string]: Action }, -- keys of Content.Actions ("restock" belongs to the core)
	Bind: (ctx: Context, station: Station) -> (),
	Tick: ((ctx: Context, station: Station, now: number) -> ())?, -- 10 Hz
	Capture: (ctx: Context, station: Station) -> any, -- stable keys (Slot, Ingredient); nil = nothing to keep
	Restore: (ctx: Context, station: Station, data: any) -> (), -- data nil = start empty
	Refresh: ((ctx: Context, station: Station) -> ())?,
}

const RESERVED_ACTION = "restock"

local function isFunction(value: any): boolean
	return type(value) == "function"
end

const StationApi = {}

-- Runtime shape check of a required Stations/*.luau. Returns the module or the problem. Kind/action keys are checked
-- against the given tables (Content.Stations.ByKey, Content.Actions.ByKey) so this file stays free of Content.
function StationApi.check(
	name: string,
	value: any,
	kinds: { [string]: any },
	actions: { [string]: any }
): (Module?, string?)
	if type(value) ~= "table" then
		return nil, `{name}: must return a table`
	end
	if type(value.Kinds) ~= "table" or #value.Kinds == 0 then
		return nil, `{name}: Kinds must be a non-empty list`
	end
	for _, kind in value.Kinds do
		if type(kind) ~= "string" or kinds[kind] == nil then
			return nil, `{name}: Kinds has "{kind}", not a key of Content.Stations`
		end
	end
	if type(value.Actions) ~= "table" then
		return nil, `{name}: Actions must be a table`
	end
	for key, action in value.Actions do
		if type(key) ~= "string" or actions[key] == nil then
			return nil, `{name}: action "{key}" is not a key of Content.Actions`
		end
		if key == RESERVED_ACTION then
			return nil, `{name}: "{RESERVED_ACTION}" belongs to KitchenService, not to a station module`
		end
		if type(action) ~= "table" or not isFunction(action.Validate) or not isFunction(action.Run) then
			return nil, `{name}: action "{key}" needs Validate and Run`
		end
	end
	for _, field in { "Bind", "Capture", "Restore" } do
		if not isFunction(value[field]) then
			return nil, `{name}: {field} must be a function`
		end
	end
	for _, field in { "Tick", "Refresh" } do
		if value[field] ~= nil and not isFunction(value[field]) then
			return nil, `{name}: {field} must be a function or nil`
		end
	end
	return value :: Module, nil
end

-- Idle record of a slot.
function StationApi.empty(kind: string): Record
	return { Kind = kind, State = "Empty", StartedAt = 0, Duration = 0, Count = 0 }
end

return table.freeze(StationApi)
