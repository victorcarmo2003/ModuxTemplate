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
}

const Stage = {}

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
