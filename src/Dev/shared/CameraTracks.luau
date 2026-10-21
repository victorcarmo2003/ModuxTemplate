--!strict
-- Camera tracks for trailer capture (docs/marketing/trailer-camera-tracks.md). Data only; played by DevCameraController.
-- Axes (MAP-01 r4, checked in Studio 2026-10-20): +Z = north = shop front / patio, +X = west, floor y 0.45, kitchen
-- ceiling y ~9.4, eye height ~4.5. Every interior key keeps >= 0.8 stud from the listed walls and ceiling.
-- Blackout scene clock (Content.HorrorScenes, ANM-020): `/dev scene blackout` at S -> phone glitch (Signal) -> power
-- cut at S+2 -> whispers +5 -> heart +14 -> shadow at the pantry door +24.8 -> rattle +27, push +28.2, latch +29 ->
-- heart stops +29.4 -> Failed (face) +30. Notes below give the owner's cue times for each track.
export type Key = {
	T: number, -- seconds from track start, ascending; the first key is T = 0
	Pos: Vector3, -- camera position (world)
	Look: Vector3, -- point the camera looks at (world)
	Fov: number?, -- degrees; nil keeps the previous key's (default 70)
	Ease: ("Linear" | "Sine" | "Quad" | "Cubic" | "Hold")?, -- how to reach THIS key from the previous one; Hold = jump cut at this key
	Roll: number?, -- degrees, dutch angle; nil = 0
	Note: string?, -- what should be happening in the scene (for the doc / console)
}
export type Track = {
	Key: string, -- lowercase id used by `/dev track <key>` ("front", "blackout", "tour"...)
	Name: string,
	Duration: number, -- seconds; the player stops here (last key may end earlier and hold)
	HideUi: boolean, -- hide the game HUD during playback
	Keys: { Key },
}

-- FRONT framing (shots #9, #43A, #46 of the 60 s script): high, far, 16-18 deg plongee, the shop in the lower third,
-- the queue (z 39) at the bottom edge, both street lamps (z 46.4) just outside the frame.
const FRONT_POS = Vector3.new(-47, 17, 54)
const FRONT_LOOK = Vector3.new(-43, 4, 10)

const Tracks: { Track } = {
	-- 1. The night from outside. Owner cue: `/dev scene blackout` at T = 44 (cut lands at ~46 on the FRONT framing);
	--    `/dev trigger stop blackout` (or a 2nd client holding E at the breaker) at T = 54 for the lights-back stinger.
	{
		Key = "front",
		Name = "The night from outside",
		Duration = 60,
		HideUi = true,
		Keys = {
			{
				T = 0,
				Pos = FRONT_POS,
				Look = FRONT_LOOK,
				Fov = 70,
				Ease = "Linear",
				Note = "FRONT lit (#9): sign on, torches, full tables, queue backs at the bottom edge; cozy music",
			},
			{
				T = 10,
				Pos = Vector3.new(-46.5, 16, 47.5),
				Look = Vector3.new(-43, 4.5, 10),
				Fov = 68,
				Ease = "Sine",
				Note = "slow push-in (0.7 stud/s) toward the shop; nothing wrong yet",
			},
			{
				T = 20,
				Pos = Vector3.new(-57, 5.5, 28.3),
				Look = Vector3.new(-42, 4, 13.2),
				Fov = 66,
				Ease = "Sine",
				Note = "descends to the west end of the aisle between the two table rows; torches pass close on both sides",
			},
			{
				T = 28,
				Pos = Vector3.new(-44, 5, 28.3),
				Look = Vector3.new(-42.5, 4.6, 13.2),
				Fov = 64,
				Ease = "Linear",
				Note = "glide east down the aisle (1.6 stud/s): diners at both tables, the service window ahead",
			},
			{
				T = 36,
				Pos = Vector3.new(-42.5, 5, 17.5),
				Look = Vector3.new(-42.5, 4.6, 13.2),
				Fov = 55,
				Ease = "Sine",
				Note = "push to the service window (tele): the owner's critter behind the counter, plate in hand, Pick Up sign at frame right",
			},
			{
				T = 40,
				Pos = Vector3.new(-42.5, 5, 17),
				Look = Vector3.new(-42.5, 4.8, 13.2),
				Fov = 52,
				Ease = "Sine",
				Note = "hold on the window (micro push). Owner: start typing `/dev scene blackout` now, send it at T = 44",
			},
			{
				T = 46,
				Pos = FRONT_POS,
				Look = FRONT_LOOK,
				Fov = 70,
				Ease = "Sine",
				Note = "pull-out back to FRONT (6 stud/s, slow-in slow-out); phone glitch 44-46; POWER CUT lands at ~46 as the camera settles",
			},
			{
				T = 54,
				Pos = Vector3.new(-47, 17.2, 55),
				Look = FRONT_LOOK,
				Fov = 70,
				Ease = "Linear",
				Note = "FRONT dark (#43A): sign dim, torches and lamps out, only the emergency red leaking; ultra-slow dolly-out; nothing moves",
			},
			{
				T = 60,
				Pos = Vector3.new(-47, 17.4, 56),
				Look = FRONT_LOOK,
				Fov = 70,
				Ease = "Linear",
				Note = "stinger (#46): power back at ~54 (trigger stop / breaker reset) -> lamps cascade on; same framing to the end",
			},
		},
	},

	-- 2. The night from inside. Two clients: A = this camera, B = the actor cooking. Owner cue (in B's chat):
	--    `/dev drive car` at T = 12, `/dev scene blackout` at T = 41 (cut at ~43 inside the high-corner wide shot).
	{
		Key = "kitchen",
		Name = "The night from inside",
		Duration = 60,
		HideUi = true,
		Keys = {
			{
				T = 0,
				Pos = Vector3.new(-49.6, 6, 1.2),
				Look = Vector3.new(-52.8, 3.3, -2),
				Fov = 50,
				Ease = "Linear",
				Note = "grill detail (#4) from the east, over the sausage rail; B at the grill (x -55.5) drops a sausage, it sizzles",
			},
			{
				T = 6,
				Pos = Vector3.new(-50.6, 5.5, 0.4),
				Look = Vector3.new(-52.8, 3.3, -2),
				Fov = 50,
				Ease = "Sine",
				Note = "slow push-in on the grill; B flips -> Perfect",
			},
			{
				T = 6.1,
				Pos = Vector3.new(-40, 5.2, 8.8),
				Look = Vector3.new(-40, 4, 5.2),
				Fov = 50,
				Ease = "Hold",
				Note = "CUT. plate on the assembly bench (#5/#6) from the north side; B on the south side (z 3.5) faces camera; ketchup S over the plate",
			},
			{
				T = 10,
				Pos = Vector3.new(-40.6, 5.1, 8.6),
				Look = Vector3.new(-40, 4, 5.2),
				Fov = 50,
				Ease = "Sine",
				Note = "drift; the finished hot dog matches the order card on the plate",
			},
			{
				T = 10.1,
				Pos = Vector3.new(-33.5, 6.4, 9.6),
				Look = Vector3.new(-36.5, 3.8, 5.6),
				Fov = 62,
				Ease = "Hold",
				Note = "CUT. lateral dolly start, east end of the assembly bench (#7 feel); B works at the plate mark x -43",
			},
			{
				T = 18,
				Pos = Vector3.new(-51.5, 6.4, 9.6),
				Look = Vector3.new(-48.5, 3.8, 5.6),
				Fov = 62,
				Ease = "Linear",
				Note = "dolly west along the bench (2.3 stud/s), passes B at ~T 14, ends over the grill side",
			},
			{
				T = 18.1,
				Pos = Vector3.new(-69.5, 6.5, 27),
				Look = Vector3.new(-63, 3, 10),
				Fov = 60,
				Ease = "Hold",
				Note = "CUT. drive-thru (#8) from outside the west wall: lane x -63.5 and the window; the car sent by `/dev drive car` (T 12) arrives, critter at the wheel",
			},
			{
				T = 24,
				Pos = Vector3.new(-68.7, 6.2, 26),
				Look = Vector3.new(-63, 3, 10.5),
				Fov = 60,
				Ease = "Sine",
				Note = "slight push toward the car; headlights on the wall. B walks from the plate to the tablet meanwhile (off camera)",
			},
			{
				T = 24.1,
				Pos = Vector3.new(-29.8, 6, -2.4),
				Look = Vector3.new(-25.8, 4.9, -1.1),
				Fov = 50,
				Ease = "Hold",
				Note = "CUT. order tablet (FEAT-043) over B's shoulder; B stands at x -27.3 z 0.8, frame right; mini-dialogue on screen",
			},
			{
				T = 29,
				Pos = Vector3.new(-29.4, 5.9, -2.2),
				Look = Vector3.new(-25.8, 4.9, -1.1),
				Fov = 50,
				Ease = "Sine",
				Note = "drift; the order is taken",
			},
			{
				T = 29.1,
				Pos = Vector3.new(-27, 8.4, 11.6),
				Look = Vector3.new(-45, 2.5, 1),
				Fov = 72,
				Ease = "Hold",
				Note = "CUT. high NE corner wide (#7/#22/#25): whole kitchen, phone on the far west wall; B cooks tablet -> grill -> plate",
			},
			{
				T = 42,
				Pos = Vector3.new(-28, 8.3, 11),
				Look = Vector3.new(-45, 2.5, 1),
				Fov = 72,
				Ease = "Linear",
				Note = "creep (0.1 stud/s). B sends `/dev scene blackout` at T 41 and turns to the ringing phone (glitch 41-43); CUT TO DARK at ~43",
			},
			{
				T = 60,
				Pos = Vector3.new(-30.5, 7.7, 9.8),
				Look = Vector3.new(-44, 2.5, 0),
				Fov = 70,
				Ease = "Linear",
				Note = "dark kitchen, emergency red only; B frozen 43-48 then walks slowly out of frame left toward the pantry door; whispers 48, heart 57",
			},
		},
	},

	-- 3. The way to the breaker. One client, eye height, game UI kept (words, POWER OUT caption, prompt ring).
	--    Owner cue: `/dev scene blackout` sent at T = 4 -> cut at T = 6; shadow at the back door 30.8, rattle 33,
	--    push 34.2, latch 35, heart stops 35.4, Failed face 36 (ending B) or hold E from 32.3 to reset (ending A).
	{
		Key = "blackout",
		Name = "The way to the breaker",
		Duration = 60,
		HideUi = false,
		Keys = {
			{
				T = 0,
				Pos = Vector3.new(-28.6, 4.5, -1.4),
				Look = Vector3.new(-59, 4.9, 0.9),
				Fov = 70,
				Ease = "Linear",
				Note = "kitchen lit, POV at the east end looking down the back bench at the wall phone (30 studs). Owner: send `/dev scene blackout` at T 4; critter parked 1 stud north of the camera",
			},
			{
				T = 6,
				Pos = Vector3.new(-28.7, 4.48, -1.45),
				Look = Vector3.new(-59, 4.8, 0.9),
				Fov = 70,
				Ease = "Sine",
				Note = "breathing drift; phone glitch at ~4; POWER CUT at ~6: clunk, hum dies, bell; emergency red only",
			},
			{
				T = 9,
				Pos = Vector3.new(-28.7, 4.5, -1.5),
				Look = Vector3.new(-58, 4.6, 1),
				Fov = 69,
				Ease = "Sine",
				Note = "still in the dark (#27): breath, cinema bars, caption POWER OUT / FIX THE BREAKER; nothing moves",
			},
			{
				T = 11.5,
				Pos = Vector3.new(-28.6, 4.5, -1.8),
				Look = Vector3.new(-28.1, 4, -3.9),
				Fov = 70,
				Ease = "Sine",
				Note = "slow turn to the pantry door DOOR-P; first words at ~11 (WHERE'S THE BREAKER?)",
			},
			{
				T = 14.5,
				Pos = Vector3.new(-28.3, 4.5, -5.6),
				Look = Vector3.new(-28.5, 3.9, -9.6),
				Fov = 70,
				Ease = "Sine",
				Note = "through the doorway into the pantry (1.3 stud/s). Owner: one W tap (~0.3 s) at T 12.5 so the critter goes in first, then one tap west",
			},
			{
				T = 16.5,
				Pos = Vector3.new(-28.6, 4.5, -6.4),
				Look = Vector3.new(-29.5, 3.2, -10.9),
				Fov = 68,
				Ease = "Sine",
				Note = "glance at the back door DOOR-B and the light slit under it: nothing there yet",
			},
			{
				T = 18.5,
				Pos = Vector3.new(-29, 4.5, -7.6),
				Look = Vector3.new(-49.5, 4.5, -7.3),
				Fov = 70,
				Ease = "Sine",
				Note = "turn west down the pantry corridor: 20 studs of dark, the mustard pulse of the breaker at the far end",
			},
			{
				T = 20.5,
				Pos = Vector3.new(-32.4, 4.42, -7.9),
				Look = Vector3.new(-49.5, 4.4, -7.3),
				Fov = 70,
				Ease = "Linear",
				Roll = 0.6,
				Note = "walk, uneven step (1.7 stud/s); heart starts at ~20 (62 BPM). Owner: W tap 1 (~4 studs) at 20.5",
			},
			{
				T = 22.3,
				Pos = Vector3.new(-35.6, 4.55, -7.5),
				Look = Vector3.new(-41.5, 4.2, -5.6),
				Fov = 70,
				Ease = "Sine",
				Roll = -0.5,
				Note = "look slides to the stock shelves (z -5.2): cans in the halo. Owner: W tap 2 at 22.5",
			},
			{
				T = 23.5,
				Pos = Vector3.new(-36.6, 4.45, -7.7),
				Look = Vector3.new(-49.6, 4.6, -7.2),
				Fov = 70,
				Ease = "Sine",
				Roll = 0.3,
				Note = "hesitation, almost stops (0.8 stud/s); eyes back on the breaker glow",
			},
			{
				T = 25.3,
				Pos = Vector3.new(-41.2, 4.52, -7.5),
				Look = Vector3.new(-50, 4.6, -7.2),
				Fov = 70,
				Ease = "Linear",
				Roll = -0.6,
				Note = "faster (2.6 stud/s); Walker on the cameras 24-32 (not seen here). Owner: W tap 3 at 24.5",
			},
			{
				T = 26.8,
				Pos = Vector3.new(-45, 4.44, -7.8),
				Look = Vector3.new(-50.4, 4.7, -7.2),
				Fov = 70,
				Ease = "Linear",
				Roll = 0.4,
				Note = "last steps; breath_held at ~26. Owner: W tap 4 at 26.5, then a short W+A tap at 27.5 to the shelf-side mark (x -48.2, z -6.0)",
			},
			{
				T = 28,
				Pos = Vector3.new(-46.8, 4.6, -7.9),
				Look = Vector3.new(-50.4, 4.7, -7.2),
				Fov = 55,
				Ease = "Sine",
				Roll = 0,
				Note = "arrival (#32): breaker detail, prompt Reset Breaker; the critter beside the shelves, within 4 studs, out of frame",
			},
			{
				T = 32,
				Pos = Vector3.new(-46.85, 4.58, -7.92),
				Look = Vector3.new(-50.4, 4.7, -7.2),
				Fov = 54,
				Ease = "Sine",
				Note = "camera FIXED 4 s on the breaker (#34/#36/#38): owner holds E 28.5-30.0 (ring ~1/2) and RELEASES, holds 30.5-31.8 and RELEASES; shadow reaches the back door at 30.8, steps stop at 32",
			},
			{
				T = 33,
				Pos = Vector3.new(-46.6, 4.55, -7.5),
				Look = Vector3.new(-29.5, 3.4, -10.6),
				Fov = 62,
				Ease = "Sine",
				Note = "slow whip east (1 s) and STOP in the halo (#41): near shelves lit white, red corridor, the back door 17 studs away",
			},
			{
				T = 38.9,
				Pos = Vector3.new(-46.5, 4.5, -7.5),
				Look = Vector3.new(-29.5, 3.5, -10.6),
				Fov = 62,
				Ease = "Sine",
				Note = "FIXED 6 s facing the door: rattle 33, forced 34.2, latch holds 35, heart stops 35.4 = SILENCE; 36 = face (ending B) or lights cascade back (ending A: hold E from 32.3 without releasing); 37-38.2 the shadow leaves the slit",
			},
			{
				T = 39,
				Pos = Vector3.new(-47, 17.4, 56),
				Look = FRONT_LOOK,
				Fov = 70,
				Ease = "Hold",
				Note = "HARD CUT to FRONT (bridge, #43A): the shop small and far, lit or dark depending on the ending",
			},
			{
				T = 60,
				Pos = Vector3.new(-47, 17.6, 57.2),
				Look = FRONT_LOOK,
				Fov = 70,
				Ease = "Linear",
				Note = "ultra-slow dolly-out to the end; room for the title in the upper third",
			},
		},
	},
}

return Tracks
