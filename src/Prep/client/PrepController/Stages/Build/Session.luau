--!strict
-- Session: the plate of the Build tab (docs/tech/prep-mode.md §2 Bun / Build / Finish, §3; TASK-178). One plate at a time:
--   PrepBegin   opens it (the server reserves a bun and the board slot of the seat), PrepResult Begin answers; Value 1 = the
--               bun came already sliced (ANM-002 altered bun)
--   gestures    the Director measures every gesture, scores it with Gestures/Score (the same Grade as the server) and writes
--               the scores here (Cut, Place, one per topping)
--   PrepFinish  ONE summary per plate: Cut, Place, Toppings in the order added, Ms (client time of the plate). The server checks
--               it by plausibility and answers PrepResult Finish with the plate grade. A refusal changes nothing: the plate
--               stays here (Parked) and Next tries again
-- The client predicts and presents; the server decides the band, the stock, the sausage and the hot dog. Nothing here touches
-- money, stock or items. With `controller.Mock` (the dev preview) no packet leaves and the verdict is computed locally.
-- State lives at module level (the board is rebuilt every time the tab comes to the front; the plate must survive that) and
-- is reset whenever the view-model says the board is empty again (Sync).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local Score = require(script.Parent.Parent.Parent.Gestures.Score)
local Sauce = require(ReplicatedStorage.shared.Item.HotDogVisual.Sauce)

const source = Vide.source
const untrack = Vide.untrack

const cfg = Content.Prep
const build = cfg.Build
const MAX = Content.OrderRules.MaxToppings
const PENDING_TIMEOUT = 3 -- s without an answer: the request is forgotten and may be sent again
const PRE_CUT_SCORE = 100 -- the altered bun comes sliced: the cut counts as a clean one
const PIP_CUT, PIP_PLACE, PIP_TOP = 1, 2, 3

-- Path = the drawn sauce strokes in bun space (3D trace only): sent packed in PrepFinish.Sauces (owner request 2026-10-14)
export type Topping = { Key: string, Score: number, Path: { { Vector2 } }? }

type Data = {
	StartedAt: number,
	Cut: number?,
	Place: number?,
	Toppings: { Topping },
	Stamp: number,
	RefusalId: number,
}

const data: Data = { StartedAt = 0, Cut = nil, Place = nil, Toppings = {}, Stamp = 0, RefusalId = 0 }

const Session = {}

-- A plate is open (the server reserved the bun / the dev preview has one).
Session.Open = source(false)
-- "" or the request waiting for its PrepResult: "Begin" | "Finish".
Session.Pending = source("")
-- The sausage is in the bun.
Session.Placed = source(false)
-- The topping being worked on (a key of Content.Ingredients.ToppingKeys), "" = none picked.
Session.Active = source("")
-- Hold instead of drag (touch accessibility, docs/tech/prep-mode.md §5).
Session.Hold = source(false)
-- The active device is a gamepad (TASK-268; PrepController sets it every frame from InputController.Device).
Session.Pad = source(false)
-- Gamepad only: the player switched the sauce to free drawing (cursor + trigger) instead of the guided pour (X / Square).
Session.PadFree = source(false)
-- The live grade of the plate (polish 2026-10-12, U-3): the mean of the scores 0..100 of the stages done so far and how many they
-- are (0 = nothing scored yet). A PREVIEW for the progress card and the seal (the server's verdict, with the sausage and the time
-- floor, is the one that counts); it uses the same Score the gestures use and writes nothing to the wire.
Session.Note = source(0)
Session.Counted = source(0)

-- Current value of a source without tracking it. `untrack` of an `any` picks the overload that returns nothing, so a source
-- of the controller (typed any here) is read through this.
function Session.Peek(value: any): any
	return untrack(function(): any
		return value()
	end)
end

local function toast(controller: any, text: string, kind: ("Info" | "Good" | "Alert")?)
	controller:Toast(text, kind)
end

local function bandOf(score: number): Grade.Band
	return Score.Band(cfg, score)
end

-- State ------------------------------------------------------------------------------------------------------------------

-- Recomputes the live note from the stage scores.
local function refreshNote()
	local sum, count = 0, 0
	if data.Cut ~= nil then
		sum += data.Cut
		count += 1
	end
	if data.Place ~= nil then
		sum += data.Place
		count += 1
	end
	for _, entry in data.Toppings do
		sum += entry.Score
		count += 1
	end
	Vide.batch(function()
		Session.Counted(count)
		Session.Note(if count > 0 then sum / count else 0)
	end)
end

function Session.Reset()
	Vide.batch(function()
		Session.Open(false)
		Session.Pending("")
		Session.Placed(false)
		Session.Active("")
	end)
	data.Cut = nil
	data.Place = nil
	table.clear(data.Toppings)
	data.StartedAt = 0
	data.Stamp += 1
	refreshNote()
end

-- The board went empty (Trash, Leave, Serve reset it, an expired plate): forget the plate. A request on its way stays.
function Session.Sync(controller: any)
	const empty = Session.Peek(controller.View.Bun) == "None"
	if empty and (untrack(Session.Open) or untrack(Session.Placed) or data.Cut ~= nil or #data.Toppings > 0) then
		const pending = untrack(Session.Pending)
		Session.Reset()
		Session.Pending(pending)
	end
end

function Session.Cut(): number?
	return data.Cut
end

function Session.Place(): number?
	return data.Place
end

function Session.Toppings(): { Topping }
	return data.Toppings
end

-- Seconds since the plate opened.
function Session.Elapsed(): number
	return if data.StartedAt > 0 then os.clock() - data.StartedAt else 0
end

-- Pips of the header (Cut, Place, Top) --------------------------------------------------------------------------------

function Session.SetCut(controller: any, score: number)
	data.Cut = score
	refreshNote()
	controller:SetPip(PIP_CUT, bandOf(score))
	controller:Need("BunCut", true)
end

function Session.SetPlace(controller: any, score: number)
	data.Place = score
	refreshNote()
	Session.Placed(true)
	controller:SetPip(PIP_PLACE, bandOf(score))
	controller:Need("PlateBuilt", true)
end

-- A topping is on the plate (the gesture is over): the view-model, the box, the pip of the toppings (the mean of their scores).
function Session.AddTopping(controller: any, key: string, score: number, amount: number, path: { { Vector2 } }?)
	if #data.Toppings >= MAX then
		return
	end
	table.insert(data.Toppings, { Key = key, Score = score, Path = path })
	refreshNote()
	const view = controller.View
	const list = table.clone(Session.Peek(view.Toppings) :: { any })
	table.insert(list, { Key = key, Amount = amount })
	const used = table.clone(Session.Peek(view.Used) :: { [string]: boolean })
	used[key] = true
	local sum = 0
	for _, entry in data.Toppings do
		sum += entry.Score
	end
	Vide.batch(function()
		view.Toppings(list)
		view.Used(used)
		view.Focus(key)
		view.Stroke({})
		view.StrokeGuide({})
		view.Meter(false)
		Session.Active("")
	end)
	controller:SetPip(PIP_TOP, bandOf(sum / #data.Toppings))
	if #data.Toppings >= MAX then
		toast(controller, build.Texts.Full, "Info")
	end
end

-- Network ----------------------------------------------------------------------------------------------------------------

local function expect(kind: string)
	Session.Pending(kind)
	data.Stamp += 1
	const stamp = data.Stamp
	task.delay(PENDING_TIMEOUT, function()
		if data.Stamp == stamp and untrack(Session.Pending) == kind then
			Session.Pending("")
		end
	end)
end

-- The plate is open: a closed bun with the guide (or an open one when it came sliced).
local function opened(controller: any, preCut: boolean)
	const view = controller.View
	data.StartedAt = os.clock()
	Vide.batch(function()
		Session.Open(true)
		view.Message("")
		view.Bun("Closed")
		view.Guide(true)
		view.Cut(0)
	end)
	if preCut then
		Vide.batch(function()
			view.Bun("Open")
			view.Guide(false)
		end)
		Session.SetCut(controller, PRE_CUT_SCORE)
		if Session.Peek(controller.Tab) == "Build" then
			controller.Step("build")
		end
	end
end

-- Opens a plate when none is open (entering the tab, after a trash or a serve).
function Session.Begin(controller: any)
	if untrack(Session.Open) or untrack(Session.Pending) ~= "" then
		return
	end
	if controller.Mock then
		opened(controller, false)
		return
	end
	expect("Begin")
	controller.View.Message("")
	controller.Libs.Net.PrepBegin:fireServer()
end

local function refusalLine(reason: string): string
	if reason == "NoStock" then
		return build.Texts.NoBun
	elseif reason == "NotSelling" then
		return build.Texts.Closed
	end
	return build.Texts.Retry
end

-- The server has no plate for us (expired, dropped): start clean and say so.
local function lost(controller: any)
	controller:ResetPlate()
	Session.Reset()
	toast(controller, build.Texts.Expired, "Alert")
	controller.Step("bun")
end

-- Time rule of the server after a refusal: the plate is aged back to a plausible age (PrepService Finish), so the client
-- clock does the same or its Ms would exceed the server's by more than MsSlack.
local function parked()
	const floor = cfg.Rules.PerfectMin + cfg.Rules.PerTopping * #data.Toppings
	data.StartedAt = os.clock() - math.min(Session.Elapsed(), floor)
end

-- PrepResult of the acts this tab owns (Begin, Finish, Trash). Returns nothing; the PrepController already toasted the Notice
-- of a refusal reason.
function Session.OnResult(controller: any, result: any)
	const view = controller.View
	if result.Act == "Begin" then
		Session.Pending("")
		if result.Ok then
			opened(controller, result.Value == 1)
		elseif result.Reason == "Invalid" then
			-- the server already has our plate (a lost answer): take it over
			opened(controller, false)
		else
			view.Message(refusalLine(result.Reason))
		end
	elseif result.Act == "Finish" then
		Session.Pending("")
		if result.Ok then
			const grade: string = result.Grade
			const band: Grade.Band = if grade == "Perfect" then "Perfect" elseif grade == "Messy" then "Messy" else "Good"
			Vide.batch(function()
				Session.Open(false)
				view.Seal(band)
			end)
			toast(controller, cfg.Grades.Labels[band], "Good")
			controller:Need("PlateBuilt", false)
			if cfg.Rules.Delivery == "Prompt" then
				-- the hot dog is in the hand (the server equips it when the seat ends): the seal and the confetti stay a moment,
				-- then the mode ends by itself and the customer's `serve` prompt delivers it
				task.delay(cfg.Rules.DoneHold, function()
					if controller.InMode and not controller.Leaving then
						controller:Leave("done", false, false)
					end
				end)
				return
			end
			controller:SetTab("Serve")
			controller:SetStage("serve")
			return
		end
		if result.Reason == "NoSession" then
			lost(controller)
			return
		end
		parked()
		if result.Reason == "NoStock" and result.Value > 0 then
			const row = Content.Ingredients.List[result.Value]
			if row ~= nil then
				data.RefusalId += 1
				view.Refused({ Key = row.Key, Id = data.RefusalId })
			end
		elseif cfg.Reasons.ByKey[result.Reason] ~= nil and cfg.Reasons.ByKey[result.Reason].Notice == nil then
			toast(controller, build.Texts.Retry, "Alert")
		end
	elseif result.Act == "Trash" and result.Value == 0 and not result.Ok and result.Reason == "NoSession" then
		lost(controller)
	end
end

-- Sends the summary (or, in the dev preview, grades it here). False = not ready or already sent.
function Session.Finish(controller: any): boolean
	const cut, place = data.Cut, data.Place
	if untrack(Session.Pending) ~= "" or not untrack(Session.Open) or cut == nil or place == nil then
		return false
	end
	const toppings: { { Key: string, Score: number } } = {}
	const scores: { number } = {}
	-- the sauce lines as drawn (Sauce.Pack: <= Sauce.Max ints each); the server cleans them and the hot dog shows them
	const sauces: { { Key: string, Points: { number } } } = {}
	for _, entry in data.Toppings do
		table.insert(toppings, { Key = entry.Key, Score = math.clamp(math.floor(entry.Score), 0, 100) })
		table.insert(scores, entry.Score)
		const path = entry.Path
		if path ~= nil then
			const points = Sauce.Pack(path)
			if #points >= 2 then
				table.insert(sauces, { Key = entry.Key, Points = points })
			end
		end
	end
	const elapsed = Session.Elapsed()
	if controller.Mock then
		const verdict = Grade.Plate(cfg, { Cut = cut, Place = place, Toppings = scores, Sausage = nil }, elapsed)
		Session.OnResult(controller, { Act = "Finish", Ok = true, Reason = "None", Grade = verdict.Band, Value = Grade.Points(cfg, verdict.Band) })
		return true
	end
	expect("Finish")
	controller.Libs.Net.PrepFinish:fireServer({
		Cut = math.clamp(math.floor(cut), 0, 100),
		Place = math.clamp(math.floor(place), 0, 100),
		Toppings = toppings,
		Sauces = if #sauces > 0 then sauces else nil,
		-- capped at TutorialPlateAge: the server ages a rookie's plate to that (PrepService Sweep), never past it
		Ms = math.clamp(math.floor(math.min(elapsed, cfg.Rules.TutorialPlateAge) * 1000), 0, 120000),
	})
	return true
end

-- TASK-260 (owner request 2026-10-14): the plate left by Leave / a forced exit stays on the board (the server parks it), so the
-- client keeps its picture and scores and gives them back on the next Enter. The server is still the authority: if it dropped
-- the plate meanwhile (shop closed, expired), the next PrepFinish answers NoSession and `lost` starts clean.
type Parked = {
	Data: { StartedAt: number, Cut: number?, Place: number?, Toppings: { Topping } },
	Placed: boolean,
	View: { [string]: any },
}
local parked: Parked? = nil
const VIEW_KEYS = { "Bun", "Cut", "Guide", "Sausage", "Toppings", "Used", "Pips" }

-- Mode ends with an open plate (nothing on its way): remember it
function Session.Park(controller: any)
	if not untrack(Session.Open) or untrack(Session.Pending) ~= "" or Session.Peek(controller.View.Seal) ~= false then
		parked = nil
		return
	end
	const view: { [string]: any } = {}
	for _, key in VIEW_KEYS do
		view[key] = Session.Peek(controller.View[key])
	end
	parked = {
		Data = { StartedAt = data.StartedAt, Cut = data.Cut, Place = data.Place, Toppings = table.clone(data.Toppings) },
		Placed = untrack(Session.Placed),
		View = view,
	}
end

-- Mode starts: the parked plate comes back (picture, pips, scores, clock). `held` = the server still holds it (the seat record
-- carries its mask); false forgets the picture. true = there was one
function Session.Unpark(controller: any, held: boolean): boolean
	const saved = parked
	parked = nil
	if saved == nil or not held then
		return false
	end
	Session.Reset()
	data.StartedAt = saved.Data.StartedAt
	data.Cut = saved.Data.Cut
	data.Place = saved.Data.Place
	for _, entry in saved.Data.Toppings do
		table.insert(data.Toppings, entry)
	end
	refreshNote()
	const view = controller.View
	Vide.batch(function()
		for key, value in saved.View do
			view[key](value)
		end
		Session.Open(true)
		Session.Placed(saved.Placed)
	end)
	if data.Cut ~= nil then
		controller:Need("BunCut", true)
	end
	if saved.Placed then
		controller:Need("SausagePlaced", true)
		controller:Need("PlateBuilt", true)
	end
	return true
end

function Session.SetHold(on: boolean)
	Session.Hold(on)
end

-- Whether a gesture runs in its hold form (the tool runs the path by itself; the press only chooses when to let go). The touch
-- "Hold" pill turns it on for every gesture that has one; on a gamepad (TASK-268) the sauce (trace) and the knife (slice) are
-- guided by default, unless the player switched the sauce to free drawing. Reactive (reads sources).
function Session.Guided(gesture: string): boolean
	if Session.Hold() then
		return true
	end
	if not Session.Pad() then
		return false
	end
	if gesture == "slice" then
		return true
	end
	return gesture == "trace" and not Session.PadFree()
end

return Session
