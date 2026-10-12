--!strict
-- Stage Build (tab Build, steps `bun` and `build`; docs/tech/prep-mode.md §2 b / c, §3; docs/art/prep-ui-spec.md §5.3; TASK-178).
-- The one stage of the tab (Stage.luau: one per tab); its pieces sit next to it:
--   Session   the plate: PrepBegin / PrepFinish / PrepTrash and their PrepResult, the scores, the pips
--   Director  the gesture of each moment (knife, sausage, sauces, cheese, bacon, potato sticks) and its score
--   Overlay   the chip of the sausage, the stroke canvas and meter, the Hold pill, the cheese ghost, the bacon rings
--   Rail      the sausages waiting on the rail (the chip is only draggable with one)
-- Flow of one plate: entering the tab opens a plate (PrepBegin) -> bun: drag the knife along the dashed line (Cut pip) ->
-- Next -> build: drag the sausage into the bun (Place pip), then up to 3 toppings in ANY order, one gesture each (Top pip) ->
-- Next sends the summary (PrepFinish) and goes to Serve with the seal of the plate. The server decides everything: the bun and
-- the toppings are only taken from stock at Finish, the sausage comes off the front of the rail, an invalid or too fast
-- summary is refused and the plate stays here (Next tries again). The bin (shell) trashes the plate (PrepTrash).
-- Next to the stage in the controller: Gestures/* (sampling, measures, Score), Parts (plate, panel), Stage (contract).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Gestures = script.Parent.Parent.Gestures
local Parts = require(script.Parent.Parent.Parts)
local Stage = require(script.Parent.Parent.Stage)
local Director = require(script.Director)
local Overlay = require(script.Overlay)
local Rail = require(script.Rail)
local Session = require(script.Session)

const prep = Content.Prep
const texts = prep.Build.Texts

-- The table test of the gestures runs once per session, the first time the dev preview opens the Build tab.
local specRan = false

local function runSpec()
	if specRan then
		return
	end
	specRan = true
	const result = require(Gestures.Spec).Run(prep)
	for _, line in result.Failed do
		warn(`[PrepController] gestures spec FAIL {line}`)
	end
	print(`[PrepController] gestures spec: {result.Total - #result.Failed}/{result.Total} ok`)
end

local function hintFor(gesture: string): string
	const holdMode = Session.Hold()
	const hints = texts.Hints :: { [string]: string }
	if holdMode and (gesture == "trace" or gesture == "slide") then
		return hints[gesture .. "_hold"]
	end
	return hints[gesture] or hints.add
end

const Build: Stage.Stage = {
	Tab = "Build",
	HasPanel = true,
	Board = function(controller: any): any
		const ctx = Overlay.New(controller)
		return Parts.Plate(controller, function(mat: Frame, bun: Frame)
			ctx.Mat = mat
			ctx.Bun = bun
			Overlay.Attach(ctx)
			Director.Mount(ctx)
		end, ctx.Overlay)
	end,
	Panel = function(controller: any, layout: () -> any): any
		return Parts.Ingredients(controller, layout)
	end,
	Hint = function(controller: any): string
		if controller.View.Seal() ~= false then
			return texts.Ready
		end
		if controller.Step() == "bun" then
			return if Session.Hold() then texts.Hints.slice_hold else texts.Hints.slice
		end
		if not Session.Placed() then
			if Rail.Count(controller) == 0 then
				return prep.Texts.Waiting
			end
			return if Session.Hold() then texts.Hints.place_hold else texts.Hints.place
		end
		const key = Session.Active()
		const tolerance = if key ~= "" then prep.Tolerances.ByKey[key] else nil
		if tolerance ~= nil then
			return hintFor(tolerance.Gesture)
		end
		return if #Session.Toppings() >= Content.OrderRules.MaxToppings then texts.Full else texts.Hints.add
	end,
	Next = function(controller: any): Stage.Next
		if controller.View.Seal() ~= false then
			return { Label = prep.Texts.Next, Enabled = false }
		end
		const needs = controller.Needs()
		const ready = if controller.Step() == "bun" then needs.BunCut == true else needs.PlateBuilt == true and Session.Pending() == ""
		return { Label = prep.Texts.Next, Enabled = ready, Pulse = ready }
	end,
	OnEnter = function(controller: any)
		if controller.Mock then
			runSpec()
		end
		Session.Sync(controller)
		const view = controller.View
		if view.Seal() ~= false then
			return
		end
		-- the step follows the plate (coming back from another tab, the controller put the first step of the tab)
		controller.Step(if view.Bun() == "Open" then "build" else "bun")
		if view.Bun() == "None" and not Session.Open() then
			Session.Begin(controller)
		end
	end,
	OnNext = function(controller: any)
		if controller.Step() == "bun" then
			controller:SetStage("build")
		else
			Session.Finish(controller)
		end
	end,
	OnGesture = function(_controller: any, event: any)
		if event.Kind == "Pick" then
			Director.Pick(event.Key, false)
		end
	end,
	OnGrab = function(_controller: any, key: string, _position: Vector2)
		Director.Pick(key, true)
	end,
	OnResult = function(controller: any, result: any)
		Session.OnResult(controller, result)
	end,
}

return Build
