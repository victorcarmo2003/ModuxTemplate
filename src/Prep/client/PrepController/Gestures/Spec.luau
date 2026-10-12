--!strict
-- Spec: the table test of the gestures (TASK-176 acceptance): for 10 synthetic inputs per gesture, the 0..100 the gesture
-- module gives is the one Prep/shared/Grade gives for the raw error the input was built to have; plus Assist (x1.3) and the
-- sampling rows, and the plane mapping of the 3D mode (ray -> top of the bun -> uv and back, TASK-197). Pure: `cfg` is Content.Prep. The PrepController runs it once when the dev preview opens (`/dev prep ui`,
-- prints "gestures spec: N/N ok") and the same file runs in plain Luau (docs/AGENT-BRIEF.md §3b).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local hold = require(script.Parent.hold)
local place = require(script.Parent.place)
local slice = require(script.Parent.slice)
local slide = require(script.Parent.slide)
local Score = require(script.Parent.Score)
local taps = require(script.Parent.taps)
local trace = require(script.Parent.trace)
local Plane = require(script.Parent.Parent.World.Plane)

export type Result = { Total: number, Failed: { string } }

const Spec = {}

const ASPECT = 3.1

-- errors that sit clear of the band edges (no float fuzz on a limit)
const BAND_ERRORS = { 0, 3, 5.9, 6.1, 10, 14.9, 15.1, 25, 39, 60 }
const TAP_ERRORS = { 0, 100, 119, 130, 200, 249, 260, 400, 599, 700 }
const SAUCES = { 0, 0.5, 0.8, 0.85, 0.9, 1.0, 1.1, 1.2, 1.3, 1.6 }

function Spec.Run(cfg: Score.Config & { Build: any, Gestures: any }): Result
	const failed: { string } = {}
	local total = 0
	const build = cfg.Build
	local function check(name: string, got: any, want: any)
		total += 1
		if got ~= want then
			table.insert(failed, `{name}: got {tostring(got)}, want {tostring(want)}`)
		end
	end
	local function row(key: string): Grade.Tolerance
		return cfg.Tolerances.ByKey[key]
	end
	local function minPoints(key: string): number
		return cfg.Gestures.ByKey[key].MinPoints
	end

	-- slice: 12 samples across the line, every one `percent` of the width off it
	const sliceParams: slice.Params = { Aspect = ASPECT, Y = build.Cut.Y, From = build.Cut.From, To = build.Cut.To, MinPoints = minPoints("slice") }
	local function cutStroke(percent: number): { any }
		const points: { any } = {}
		for index = 1, 12 do
			table.insert(points, { X = build.Cut.From + (build.Cut.To - build.Cut.From) * (index - 1) / 11, Y = build.Cut.Y + percent / 100 * ASPECT })
		end
		return points
	end
	for _, error in BAND_ERRORS do
		check(`slice {error}`, Score.Value(cfg, "bun_cut", slice.Measure(cutStroke(error), sliceParams), nil, false), Grade.Score(cfg, row("bun_cut"), error, false))
	end
	check("slice too few samples", Score.Value(cfg, "bun_cut", slice.Measure({ { X = 0.1, Y = 0.5 } }, sliceParams), nil, false), 0)
	check("slice a half line costs", slice.Measure({ { X = 0.04, Y = 0.5 }, { X = 0.1, Y = 0.5 }, { X = 0.2, Y = 0.5 }, { X = 0.3, Y = 0.5 }, { X = 0.4, Y = 0.5 }, { X = 0.5, Y = 0.5 }, { X = 0.5, Y = 0.5 }, { X = 0.5, Y = 0.5 } }, sliceParams) > 30, true)
	check("slice assist 7.5 is Perfect", Score.Band(cfg, Score.Value(cfg, "bun_cut", slice.Measure(cutStroke(7.5), sliceParams), nil, true)), "Perfect")
	check("slice no assist 7.5 is Good", Score.Band(cfg, Score.Value(cfg, "bun_cut", slice.Measure(cutStroke(7.5), sliceParams), nil, false)), "Good")

	-- place: dropped `percent` of the bun length from the groove (sideways, then up and down)
	const placeParams: place.Params = { Aspect = ASPECT, X = build.Groove.X, Y = build.Groove.Y, MinPoints = minPoints("place") }
	for index, error in BAND_ERRORS do
		const points = if index % 2 == 0
			then { { X = 0.1, Y = 0.9 }, { X = 0.3, Y = 0.6 }, { X = build.Groove.X + error / 100, Y = build.Groove.Y } }
			else { { X = 0.1, Y = 0.9 }, { X = 0.3, Y = 0.6 }, { X = build.Groove.X, Y = build.Groove.Y - error / 100 * ASPECT } }
		check(`place {error}`, Score.Value(cfg, "sausage_place", place.Measure(points, placeParams), nil, false), Grade.Score(cfg, row("sausage_place"), error, false))
	end
	check("place a tap is no drag", Score.Value(cfg, "sausage_place", place.Measure({ { X = 0.5, Y = 0.5 } }, placeParams), nil, false), 0)
	check("place assist 11 is Perfect", Score.Band(cfg, Score.Value(cfg, "sausage_place", place.Measure({ { X = 0, Y = 0 }, { X = 0, Y = 0 }, { X = 0.61, Y = 0.5 } }, placeParams), nil, true)), "Perfect")

	-- slide: settles at the mean of the last 3 samples (a jittery start does not count)
	const slideParams: slide.Params = { Aspect = ASPECT, X = build.Groove.X, Y = build.Groove.Y, MinPoints = minPoints("slide"), Settle = 3 }
	for _, error in BAND_ERRORS do
		const x = build.Groove.X - error / 100
		const points = { { X = 0.9, Y = 0.1 }, { X = 0.7, Y = 0.9 }, { X = x, Y = build.Groove.Y }, { X = x, Y = build.Groove.Y }, { X = x, Y = build.Groove.Y } }
		check(`slide {error}`, Score.Value(cfg, "cheese", slide.Measure(points, slideParams), nil, false), Grade.Score(cfg, row("cheese"), error, false))
	end
	check("slide too few samples", Score.Value(cfg, "cheese", slide.Measure({ { X = 0.5, Y = 0.5 } }, slideParams), nil, false), 0)

	-- hold: released `percent` of the bar from the target (before and after it)
	const holdParams: hold.Params = { Target = build.Potato.Target }
	for index, error in BAND_ERRORS do
		const progress = build.Potato.Target + (if index % 2 == 0 then -1 else 1) * error / 100
		check(`hold {error}`, Score.Value(cfg, "potato_sticks", hold.Measure(math.clamp(progress, 0, 1), holdParams), nil, false), Grade.Score(cfg, row("potato_sticks"), math.abs(math.clamp(progress, 0, 1) - build.Potato.Target) * 100, false))
	end
	check("hold exact", Score.Value(cfg, "potato_sticks", hold.Measure(build.Potato.Target, holdParams), nil, false), 100)

	-- taps: three rings, every tap `ms` early or late; a ring not tapped is a miss
	const tapsParams: taps.Params = { Count = build.Bacon.Count, Miss = build.Bacon.Miss }
	const ideal = { 10, 10.55, 11.1 }
	for _, ms in TAP_ERRORS do
		const tapped: { number? } = { ideal[1] + ms / 1000, ideal[2] - ms / 1000, ideal[3] + ms / 1000 }
		check(`taps {ms}`, Score.Value(cfg, "bacon", taps.Measure(ideal, tapped, tapsParams), nil, false), Grade.Score(cfg, row("bacon"), math.min(ms, build.Bacon.Miss), false))
	end
	check("taps a missing ring", Score.Value(cfg, "bacon", taps.Measure(ideal, { ideal[1], ideal[2] } :: { number? }, tapsParams), nil, false), Grade.Score(cfg, row("bacon"), build.Bacon.Miss / 3, false))
	check("taps none", Score.Value(cfg, "bacon", taps.Measure(ideal, {} :: { number? }, tapsParams), nil, false), 0)
	check("taps need the 3 of the row", minPoints("taps"), build.Bacon.Count)

	-- trace: the pour (coverage / excess from an amount) and the geometry of a drawn stroke
	for _, amount in SAUCES do
		const coverage, excess = trace.Poured(amount)
		check(`pour {amount}`, Score.Value(cfg, "ketchup", coverage, excess, false), Grade.Score(cfg, row("ketchup"), Grade.CoverageError(row("ketchup"), math.min(100, amount * 100), math.max(0, amount - 1) * 100), false))
	end
	const traceParams: trace.Params = { Aspect = ASPECT, Path = build.Sauce.Path, Reach = build.Sauce.Reach, Spill = build.Sauce.Spill }
	local function along(count: number, last: number): { any }
		-- `count` samples over the first `last` (0..1) of the path
		const points: { any } = {}
		const path = build.Sauce.Path
		const legs = #path - 1
		for index = 0, count - 1 do
			const position = index / (count - 1) * last * legs
			const leg = math.min(math.floor(position), legs - 1)
			const alpha = position - leg
			table.insert(points, { X = path[leg + 1].X + (path[leg + 2].X - path[leg + 1].X) * alpha, Y = path[leg + 1].Y + (path[leg + 2].Y - path[leg + 1].Y) * alpha })
		end
		return points
	end
	const fullCoverage, fullExcess = trace.Measure(along(40, 1), traceParams)
	check("trace the whole path: coverage", fullCoverage >= 99, true)
	check("trace the whole path: no excess", fullExcess <= 1, true)
	check("trace the whole path is near 100", Score.Value(cfg, "mustard", fullCoverage, fullExcess, false) >= 95, true)
	const halfCoverage = trace.Measure(along(40, 0.5), traceParams)
	check("trace half the path covers about half", halfCoverage > 40 and halfCoverage < 65, true)
	const lineCoverage = trace.Measure({ { X = 0.1, Y = 0.5 }, { X = 0.3, Y = 0.5 }, { X = 0.5, Y = 0.5 }, { X = 0.7, Y = 0.5 }, { X = 0.9, Y = 0.5 } }, traceParams)
	check("trace a straight line is not Perfect", lineCoverage < 70, true)
	const offCoverage, offExcess = trace.Measure({ { X = 0.1, Y = 1.5 }, { X = 0.5, Y = 1.5 }, { X = 0.9, Y = 1.5 } }, traceParams)
	check("trace off the bun covers nothing", offCoverage, 0)
	check("trace off the bun is all excess", offExcess, 100)
	check("trace a dot paints nothing", trace.Measure({ { X = 0.5, Y = 0.5 } }, traceParams), 0)
	check("trace amount of the whole path", math.abs(trace.Amount(along(40, 1), traceParams) - 1) < 0.02, true)
	check("trace Perfect coverage 90 excess 5", Score.Band(cfg, Score.Value(cfg, "ketchup", 90, 5, false)), "Perfect")
	check("trace assist widens the limits", Score.Value(cfg, "ketchup", 80, 0, true) > Score.Value(cfg, "ketchup", 80, 0, false), true)

	-- the sampling rows the recogniser reads: 30 Hz, the minimum of points, the cap of the stroke reuse
	for _, key in { "slice", "place", "trace", "slide", "hold" } do
		check(`row {key} samples at 30 Hz`, cfg.Gestures.ByKey[key].Hz, 30)
	end
	check("row trace keeps at most 64 points", cfg.Gestures.ByKey.trace.MaxPoints, 64)
	check("row taps is discrete", cfg.Gestures.ByKey.taps.Hz, 0)

	-- plane (3D mode): a pinhole camera over the top of the bun. The uv of the bun space must survive the trip uv -> world ->
	-- pixel -> ray -> plane -> uv for a flat bun, a bun turned on the board, a tilted bun and a rolled camera, and a stroke
	-- drawn on the plane must score what the same stroke scores in bun space.
	const viewport = Vector2.new(844, 390)
	const fov = 55
	const bunLength = 1.0
	const bunWidth = bunLength / ASPECT
	local function lookDown(focus: Vector3, extra: Vector3, roll: number): CFrame
		const eye = focus + Vector3.new(0, math.sin(math.rad(55)) * 2.5, math.cos(math.rad(55)) * 2.5) + extra
		return CFrame.lookAt(eye, focus) * CFrame.Angles(0, 0, math.rad(roll))
	end
	const center = Vector3.new(10, 3, -4)
	const poses = {
		{ Name = "flat", Bun = CFrame.new(center), Camera = lookDown(center, Vector3.zero, 0) },
		{ Name = "turned 35", Bun = CFrame.new(center) * CFrame.Angles(0, math.rad(35), 0), Camera = lookDown(center, Vector3.zero, 0) },
		{ Name = "rolled camera", Bun = CFrame.new(center), Camera = lookDown(center + Vector3.new(0.1, 0, 0), Vector3.new(0.3, 0.1, 0.2), 10) },
		{ Name = "tilted bun", Bun = CFrame.new(center) * CFrame.Angles(math.rad(8), math.rad(-20), math.rad(-5)), Camera = lookDown(center, Vector3.new(-0.2, 0, 0), -6) },
	}
	const grid = { Vector2.new(0.1, 0.2), Vector2.new(0.5, 0.2), Vector2.new(0.9, 0.2), Vector2.new(0.1, 0.5), Vector2.new(0.5, 0.5), Vector2.new(0.9, 0.5), Vector2.new(0.1, 0.8), Vector2.new(0.5, 0.8), Vector2.new(0.9, 0.8) }
	local function near(a: Vector2, b: Vector2): boolean
		return (a - b).Magnitude < 1e-3
	end
	local function rayOf(camera: CFrame): Plane.RayOf
		return function(px: Vector2): (Vector3?, Vector3?)
			return Plane.PinholeRay(camera, fov, viewport, px)
		end
	end
	for _, pose in poses do
		const plane = Plane.new(pose.Bun, bunLength, bunWidth)
		const region = Plane.Region(plane, rayOf(pose.Camera))
		for _, uv in grid do
			const px = Plane.PinholeProject(pose.Camera, fov, viewport, Plane.ToWorld(plane, uv, 0))
			check(`plane {pose.Name} uv {uv.X},{uv.Y} is on screen`, px ~= nil, true)
			check(`plane {pose.Name} uv {uv.X},{uv.Y} round trip`, px ~= nil and near(region.Normalise(px), uv), true)
		end
		check(`plane {pose.Name} aspect`, math.abs(region.Aspect - ASPECT) < 1e-6, true)
		-- a stroke built in bun space, drawn on the plane (uv -> pixel) and read back: same measure, same score
		for _, error in { 0, 5.9, 10, 25 } do
			const drawn: { any } = {}
			for _, point in cutStroke(error) do
				const px = Plane.PinholeProject(pose.Camera, fov, viewport, Plane.ToWorld(plane, Vector2.new(point.X, point.Y), 0))
				table.insert(drawn, if px ~= nil then region.Normalise(px) else { X = 0, Y = 0 })
			end
			check(`plane {pose.Name} slice {error}`, Score.Value(cfg, "bun_cut", slice.Measure(drawn, sliceParams), nil, false), Grade.Score(cfg, row("bun_cut"), error, false))
		end
	end
	const flat = Plane.new(CFrame.new(center), bunLength, bunWidth)
	const flatRegion = Plane.Region(flat, rayOf(poses[1].Camera))
	const middle = Plane.PinholeProject(poses[1].Camera, fov, viewport, center) :: Vector2
	check("plane the bun centre is the middle of the screen", near(middle, viewport / 2), true)
	check("plane the middle of the screen is uv 0.5 0.5", near(flatRegion.Normalise(middle), Vector2.new(0.5, 0.5)), true)
	check("plane moving right grows u", flatRegion.Normalise(middle + Vector2.new(20, 0)).X > 0.5, true)
	check("plane moving down grows v", flatRegion.Normalise(middle + Vector2.new(0, 20)).Y > 0.5, true)
	check("plane the bun centre is inside", flatRegion.Inside(middle), true)
	check("plane a screen corner is outside", flatRegion.Inside(Vector2.new(0, 0)), false)
	check("plane past the bun edge u goes over 1", flatRegion.Normalise(middle + Vector2.new(400, 0)).X > 1, true)
	check("plane a lifted point reads the uv under it", near(Plane.ToUV(flat, Plane.ToWorld(flat, Vector2.new(0.3, 0.7), 0.35)), Vector2.new(0.3, 0.7)), true)
	check("plane lift goes along the normal", math.abs(Plane.ToWorld(flat, Vector2.new(0.5, 0.5), 0.35).Y - center.Y - 0.35) < 1e-6, true)
	check("plane corner to corner is the bun diagonal", math.abs((Plane.ToWorld(flat, Vector2.zero, 0) - Plane.ToWorld(flat, Vector2.one, 0)).Magnitude - math.sqrt(bunLength * bunLength + bunWidth * bunWidth)) < 1e-6, true)
	check("plane a parallel ray misses", Plane.FromRay(flat, center + Vector3.new(0, 1, 0), Vector3.new(1, 0, 0)), nil)
	check("plane a ray looking away misses", Plane.FromRay(flat, center + Vector3.new(0, 1, 0), Vector3.new(0, 1, 0)), nil)
	check("plane a ray with no camera reads (0, 0)", Plane.Region(flat, function(_: Vector2): (Vector3?, Vector3?) return nil, nil end).Normalise(middle), Vector2.zero)
	check("plane a ray with no camera is outside", Plane.Region(flat, function(_: Vector2): (Vector3?, Vector3?) return nil, nil end).Inside(middle), false)
	check("plane a point behind the camera has no pixel", Plane.PinholeProject(poses[1].Camera, fov, viewport, poses[1].Camera.Position - poses[1].Camera.LookVector * 3), nil)

	return { Total = total, Failed = failed }
end

return Spec
