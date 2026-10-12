--!strict
-- Stage: the contract of Stages/*.luau (docs/tech/prep-mode.md §6 `Stages/{Order,Grill,Build,Serve}`; TASK-173). Every
-- ModuleScript in Stages/ is discovered at boot and checked here, so a new stage is a new file and the controller's init is
-- never edited. One stage per TAB of Content.Prep.Tabs (Build serves both the `bun` and the `build` steps; the step lives
-- in `controller.Step`). The functions get the PrepController (`controller`) and talk to it only through its public API:
--   controller.View    view-model sources the stage writes (plate, toppings, seal, hint line, pips, strokes)
--   controller.Step    the current step key of Content.Prep.Steps; :SetStage(step) changes it
--   controller.Needs   what the corner button waits for (BunCut, PlateBuilt, TicketPicked): `controller:Need(name, bool)`
--   controller.Gestures  the Gestures recogniser (Drag, Trace, Tap, Hold, normalised)
--   controller:Toast(text, kind)   one line at the bottom
-- A stage never reads UserInputService, never binds a key and never touches the camera (the controller does). The result of a
-- gesture is scored with Prep/shared/Grade only (TASK-176), and sent with the Net packets only by the stage (P7).
export type Next = {
	Label: string,
	Enabled: boolean,
	-- Pulses when it becomes ready (Next / Serve).
	Pulse: boolean?,
}

export type Stage = {
	-- Content.Prep.Tabs key this stage owns.
	Tab: string,
	-- The ingredient panel is part of this tab (Build only).
	HasPanel: boolean,
	-- Content of the board (a Vide component, built in the shell's scope; use Vide.cleanup to disarm gestures).
	Board: (controller: any) -> any,
	-- Content of the panel slot (only when HasPanel).
	Panel: ((controller: any, layout: () -> any) -> any)?,
	-- The one-line hint of the board header, read reactively.
	Hint: (controller: any) -> string,
	-- The corner button, read reactively.
	Next: (controller: any) -> Next,
	-- The tab came to the front / went to the back.
	OnEnter: ((controller: any) -> ())?,
	OnLeave: ((controller: any) -> ())?,
	-- The corner button was pressed (Enabled was true).
	OnNext: ((controller: any) -> ())?,
	-- A gesture event the stage armed (the controller forwards what it receives through :OnGesture).
	OnGesture: ((controller: any, event: any) -> ())?,
	-- The press landed on a box with `PrepGrab` = key (an ingredient box dragged from).
	OnGrab: ((controller: any, key: string, position: Vector2) -> ())?,
	-- A PrepResult arrived while this stage is in front.
	OnResult: ((controller: any, result: any) -> ())?,
	-- Every stage with this field gets the events the controller broadcasts whatever tab is in front (:Broadcast): `{ Kind =
	-- "Result", Result = PrepResult }`, `{ Kind = "Sale", Npc, Result, Amount }` (the Sale packet), `{ Kind = "Cycle" }` (the
	-- ticket rail was tapped). Order uses it for the line and the grill (Feed.luau); others leave it nil.
	OnEvent: ((controller: any, event: any) -> ())?,
}

-- Stage3D: the contract of World/Stages/*.luau (docs/tech/prep-3d.md §11.3, TASK-194). Same discovery as Stages/ (a new stage is a
-- new file), other folder, no Board and no Panel: the 3D stage draws in the world through the World layer (Aim, Targets, Fx), never
-- with GuiObjects of its own (the HUD chrome is PrepShell). A module serves one or more TABS of Content.Prep.Tabs3D (Build.luau
-- serves Board and Toppings). It is used for a tab only when Stage.Armed(rules, tab) is true; otherwise the 2D Stage of the same
-- tab runs (per-stage rollback, no code). Everything is Provisional until the dono approves prep-3d.md.
--   Tabs        Content.Prep.Tabs3D keys this stage owns
--   Enter       a tab of the stage came to the front (the world: register targets, show the ghosts, arm the tool)
--   Leave       it went to the back (disarm everything Enter did; the controller destroys the World pools on leaving the mode)
--   Step        the plate step changed to `step` (a Content.Prep.Steps3D key of this stage, e.g. bun -> place); also called once
--               right after Enter with the current step
--   Hint        one line (<= 36 characters), reactive
--   Next        the corner button, reactive
--   OnNext      the corner button was pressed
--   OnAim       a World aim message (World/Types.luau `AimMsg`): Hover, Press, Move, Release, Drop, Cancel
--   OnResult    a PrepResult arrived while the stage is in front
--   OnEvent     events the controller broadcasts whatever tab is in front (same shape as Stage.OnEvent)
export type Stage3D = {
	Tabs: { string },
	Enter: (controller: any, tab: string) -> (),
	Leave: (controller: any, tab: string) -> (),
	Step: (controller: any, step: string) -> (),
	Hint: (controller: any) -> string,
	Next: (controller: any) -> Next,
	OnNext: ((controller: any) -> ())?,
	OnAim: ((controller: any, message: any) -> ())?,
	OnResult: ((controller: any, result: any) -> ())?,
	OnEvent: ((controller: any, event: any) -> ())?,
}

const Stage = {}

-- A problem with a module returned by World/Stages/<name>.luau, nil when it is a Stage3D.
function Stage.check3D(module: any, name: string, tabs3D: { [string]: any }): string?
	if type(module) ~= "table" then
		return `{name}: must return a table`
	end
	if type(module.Tabs) ~= "table" or #module.Tabs == 0 then
		return `{name}: Tabs (a list of Content.Prep.Tabs3D keys) is missing`
	end
	for _, tab in module.Tabs do
		if tabs3D[tab] == nil then
			return `{name}: Tabs has '{tostring(tab)}', not a Content.Prep.Tabs3D key`
		end
	end
	for _, field in { "Enter", "Leave", "Step", "Hint", "Next" } do
		if type(module[field]) ~= "function" then
			return `{name}: {field} must be a function`
		end
	end
	if module.Board ~= nil or module.Panel ~= nil or module.HasPanel ~= nil then
		return `{name}: a 3D stage has no Board, Panel or HasPanel (it draws in the world)`
	end
	return nil
end

-- Whether the 3D stage serves `tab` right now: Rules.ThreeD and the World.Stages switch of the tab (the Serve switch also arms
-- the Take in the Window view; Order is its own switch for the Take on the customer).
function Stage.Armed(rules: any, tab: string): boolean
	return rules.ThreeD == true and rules.World.Stages[tab] == true
end

-- A problem with a module returned by Stages/<name>.luau, nil when it is a stage.
function Stage.check(module: any, name: string): string?
	if type(module) ~= "table" then
		return `{name}: must return a table`
	end
	if type(module.Tab) ~= "string" then
		return `{name}: Tab (a Content.Prep.Tabs key) is missing`
	end
	if type(module.HasPanel) ~= "boolean" then
		return `{name}: HasPanel is missing`
	end
	for _, field in { "Board", "Hint", "Next" } do
		if type(module[field]) ~= "function" then
			return `{name}: {field} must be a function`
		end
	end
	if module.HasPanel and type(module.Panel) ~= "function" then
		return `{name}: HasPanel needs a Panel function`
	end
	return nil
end

return Stage
