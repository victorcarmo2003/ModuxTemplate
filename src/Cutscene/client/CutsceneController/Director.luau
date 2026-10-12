--!strict
-- Director: pure reads of the camera language of a scene at a given elapsed time (Content.Cutscenes[].Shots,
-- Rules.Cinema; owner request 2026-10-12). Like Timeline, every value is a function of (scene, elapsed), so a client
-- that joins late shows the same frame. No instance, no Vide, no network.
--
--   Rig(scene, elapsed, shake)  the camera rig of this instant: eye offset, detached boom, orbit, roll, fov, depth of
--                               field, hand-held shake (CameraController:SetRig). nil = the scene has no shots
--   Dip(scene, elapsed)         0..1 black of a fade through black at a Dip shot (0 = clear)
--   Bars(scene, elapsed)        0..1 how closed the letterbox is (1 = fully in)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

type Scene = Content.Cutscene
type Shot = Content.CutsceneShot

export type Rig = {
	Name: string,
	Dolly: Vector3, -- eye offset, camera space (X right, Y up, Z forward)
	Boom: Vector3?, -- detached eye, walker space (nil = the head)
	BoomLook: Vector3?, -- point looked at from a boom, walker space
	Orbit: number, -- radians the eye circles the focus
	Roll: number, -- radians
	Fov: number?,
	Far: number?,
	Rack: number?,
	Shake: Vector3, -- camera space, studs
	Tilt: Vector3, -- radians (pitch, yaw, roll)
}

const Director = {}

const RAD = math.pi / 180

local function ease(kind: string?, x: number): number
	if kind == "Quad" then
		return if x < 0.5 then 2 * x * x else 1 - (-2 * x + 2) ^ 2 / 2
	end
	return -(math.cos(math.pi * x) - 1) / 2
end

local function smooth(x: number): number
	const c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

local function pairAt(pair: { number }?, x: number): number?
	if pair == nil then
		return nil
	end
	return pair[1] + (pair[2] - pair[1]) * x
end

local function vectorAt(pair: { Vector3 }?, x: number): Vector3?
	if pair == nil then
		return nil
	end
	return pair[1]:Lerp(pair[2], x)
end

-- Shot of this instant and its index (nil before the first shot)
function Director.ShotAt(scene: Scene, elapsed: number): (Shot?, number)
	const shots = scene.Shots
	if shots == nil then
		return nil, 0
	end
	local found: Shot? = nil
	local index = 0
	for i, shot in shots do
		if shot.At > elapsed then
			break
		end
		found = shot
		index = i
	end
	return found, index
end

type Sample = {
	Dolly: Vector3,
	Orbit: number,
	Roll: number,
	Fov: number?,
	Far: number?,
	Sway: number,
}

local function sample(shot: Shot, x: number): Sample
	const e = ease(shot.Ease, math.clamp(x, 0, 1))
	return {
		Dolly = vectorAt(shot.Dolly, e) or Vector3.zero,
		Orbit = (pairAt(shot.Orbit, e) or 0) * RAD,
		Roll = (pairAt(shot.Roll, e) or 0) * RAD,
		Fov = pairAt(shot.Fov, e),
		Far = shot.Far,
		Sway = shot.Sway or 0,
	}
end

local function mix(a: number?, b: number?, w: number): number?
	if a == nil then
		return b
	elseif b == nil then
		return a
	end
	return a + (b - a) * w
end

function Director.Rig(scene: Scene, elapsed: number, shake: boolean): Rig?
	const shots = scene.Shots
	const shot, index = Director.ShotAt(scene, elapsed)
	if shots == nil or shot == nil then
		return nil
	end
	const nextShot = shots[index + 1]
	const length = math.max((if nextShot ~= nil then nextShot.At else scene.Duration) - shot.At, 1e-3)
	const x = (elapsed - shot.At) / length
	local now = sample(shot, x)

	-- cross-fade from where the previous shot ended (a Dip changes under the black; a boom never blends)
	const previous = shots[index - 1]
	const blend = shot.Blend or Content.Cutscenes.Rules.Cinema.Blend
	if previous ~= nil and shot.Cut == nil and shot.Boom == nil and previous.Boom == nil then
		const w = smooth((elapsed - shot.At) / math.max(blend, 1e-3))
		if w < 1 then
			const last = sample(previous, 1)
			now = {
				Dolly = last.Dolly:Lerp(now.Dolly, w),
				Orbit = last.Orbit + (now.Orbit - last.Orbit) * w,
				Roll = last.Roll + (now.Roll - last.Roll) * w,
				Fov = mix(last.Fov, now.Fov, w),
				Far = mix(last.Far, now.Far, w),
				Sway = last.Sway + (now.Sway - last.Sway) * w,
			}
		end
	end

	-- hand-held: smooth noise, two octaves, fixed seeds per axis
	local offset = Vector3.zero
	local tilt = Vector3.zero
	const cinema = Content.Cutscenes.Rules.Cinema
	if shake and now.Sway > 0 then
		const t = elapsed * cinema.Sway.Rate
		const amp = cinema.Sway.Amp * now.Sway
		const rot = cinema.Sway.Tilt * RAD * now.Sway
		offset = Vector3.new(
			math.noise(t, 11.3, 0) * amp,
			math.noise(t * 1.1, 47.1, 0) * amp,
			math.noise(t * 0.9, 83.7, 0) * amp * 0.5
		)
		tilt = Vector3.new(
			math.noise(t * 1.2, 5.5, 0) * rot,
			math.noise(t * 1.0, 29.9, 0) * rot,
			math.noise(t * 0.8, 71.3, 0) * rot * 0.6
		)
	end

	return {
		Name = shot.Name,
		Dolly = now.Dolly,
		Boom = vectorAt(shot.Boom, ease(shot.Ease, math.clamp(x, 0, 1))),
		BoomLook = shot.BoomLook,
		Orbit = now.Orbit,
		Roll = now.Roll,
		Fov = now.Fov,
		Far = now.Far,
		Rack = shot.Rack,
		Shake = offset,
		Tilt = tilt,
	}
end

-- Black of the fade through black around a Dip shot: down over DipDown, back over DipUp
function Director.Dip(scene: Scene, elapsed: number): number
	const shots = scene.Shots
	if shots == nil then
		return 0
	end
	const cinema = Content.Cutscenes.Rules.Cinema
	local black = 0
	for _, shot in shots do
		if shot.Cut ~= "Dip" then
			continue
		end
		const dt = elapsed - shot.At
		if dt >= -cinema.DipDown and dt < 0 then
			black = math.max(black, smooth((dt + cinema.DipDown) / cinema.DipDown))
		elseif dt >= 0 and dt < cinema.DipUp then
			black = math.max(black, 1 - smooth(dt / cinema.DipUp))
		end
	end
	return black
end

-- Instants of the Dip shots: [At - DipDown, At) is the way down
function Director.DipStarting(scene: Scene, elapsed: number, last: number): Shot?
	const shots = scene.Shots
	if shots == nil then
		return nil
	end
	const down = Content.Cutscenes.Rules.Cinema.DipDown
	for _, shot in shots do
		if shot.Cut == "Dip" and last < shot.At - down and shot.At - down <= elapsed then
			return shot
		end
	end
	return nil
end

-- How closed the letterbox is: in over BarsIn from the start, out over BarsOut before the last fade out (or the end)
function Director.Bars(scene: Scene, elapsed: number): number
	const cinema = Content.Cutscenes.Rules.Cinema
	local outAt = scene.Duration - cinema.BarsOut
	for _, beat in scene.Beats do
		if beat.Kind == "Fade" and beat.Target == "Out" then
			outAt = math.min(outAt, beat.At)
		end
	end
	const opening = smooth(elapsed / math.max(cinema.BarsIn, 1e-3))
	const closing = smooth((elapsed - outAt) / math.max(cinema.BarsOut, 1e-3))
	return opening * (1 - closing)
end

return table.freeze(Director)
