--!strict
-- ANM-011 the shaker's tantrum (condition Plain "JUST BREAD", owner 2026-10-22, Provisional; design/anomalies-after-accept-
-- proposal.md §9.9). Every number here is Provisional (no DEC), judged in Play.
-- Owner: "ele vai jogar o prato longe e vai falar 'eu só quero pão'... o prato sendo arremessado em direção à parede, batendo
-- na parede e caindo no chão... a anomalia faz um som de batida, tum, e aparece o texto... rosto macabro de raiva... o corpo
-- tremendo, uma animação meio bugada, sem suavidade". Owner adjustment (same day): "quando ele arremessar o prato, retira 15
-- de sanidade e na segunda vez 5".
--   Sanity   Throw = lost by who served each topping hot dog he throws back while he keeps waiting; Leave = lost by who
--            served the throw that sends him away (the last one: Rules/ANM-011 Returns + 1). Read by Rules/ANM-011
--   LeaveDelay  s from that last throw until he stomps off (the throw, the TUM and the line play with him still there)
--   Throw    the plate (a local copy of THE hot dog served, on the kit dish; client Effects/Kit/Tantrum): WindUp s in his
--            raised hand, Flight s of the arc (Arc studs over the straight line), Reach studs the wall is searched along
--            his facing (Fan degrees either side when straight ahead has none; none at all = Fallback studs ahead, onto the
--            floor), stuck Stick s, Slide s down the wall (eases in), Fall s off it flat onto the floor, Fade s to nothing.
--            Spin = turns a second in the air. Wall = the smallest the two big sides of a part must be to count as a wall
--   Rage     his reaction: Delay s after the throw cue (just after the plate hits the wall) the TUM, the line and the face;
--            the rig attribute AnomalyRage (server) keeps him enraged until he leaves or is served plain. Text typed at
--            TypeRate chars/s in the order talk style Style (Content.OrderTalk.Styles), shown TextHold s after typed.
--            Face = CrewExpressions name of the eyes (the thumbnails' monster face: white eyes) + the Grin below (teeth,
--            tongue). Ticks: every TicEvery {min, max} s the head, arms and torso jump straight to a crooked pose (no tween)
--            and stay Hold {min, max} s, then jump back; degrees of each joint (+-), Tremor = studs / degrees of the body
--            tremor every frame. Reduced motion (Settings / Roblox): x Reduced of every angle and tremor, ticks x2 apart.
--            Stomp: while he walks enraged, the Stomp sound every StompEvery s (over StompSpeed studs/s)
--   Grin     the thumbnails' grin (tools/thumbnails/thumb_project_helpers.luau T.addGrin), in studs for a CrewRig head
--            HeadWidth wide (scaled with the head): W x H mouth, Y under the head centre, Z in front of it, Up / Lo teeth,
--            Teeth = tooth length x
--   Kick     camera kick of the TUM for who stands within Radius studs of him (none with reduced motion)
--   Sounds   Content.Sounds keys: Smash = the plate on the wall, Drop = on the floor, Thud = the TUM, Stomp = his feet

export type Range = { number }

export type PlateThrow = {
	Sanity: { Throw: number, Leave: number },
	LeaveDelay: number,
	Text: string,
	Throw: {
		WindUp: number,
		Flight: number,
		Arc: number,
		Reach: number,
		Fan: number,
		Fallback: number,
		Wall: number,
		Stick: number,
		Slide: number,
		Fall: number,
		Fade: number,
		Spin: number,
	},
	Rage: {
		Delay: number,
		Style: string,
		TypeRate: number,
		TextHold: number,
		Face: string,
		TicEvery: Range,
		Hold: Range,
		Neck: Vector3,
		Shoulder: Vector3,
		Torso: Vector3,
		Tremor: number,
		TremorTurn: number,
		Reduced: number,
		StompEvery: number,
		StompSpeed: number,
	},
	Grin: { HeadWidth: number, W: number, H: number, Y: number, Z: number, Up: number, Lo: number, Teeth: number },
	Kick: { Radius: number, Angle: number, Time: number },
	Sounds: { Smash: string, Drop: string, Thud: string, Stomp: string },
}

const data: PlateThrow = {
	Sanity = { Throw = 15, Leave = 5 },
	LeaveDelay = 2.4,
	-- English, Provisional (no voice yet: the owner wants it shouted later)
	Text = "I ONLY WANT BREAD.",
	Throw = {
		WindUp = 0.14,
		Flight = 0.34,
		Arc = 1.6,
		Reach = 40,
		Fan = 25,
		Fallback = 10,
		Wall = 3, -- the trailer's inner wall is 9 x 19.5; the menu strip over it (2.7 tall) is not a wall
		Stick = 1,
		Slide = 1.6,
		Fall = 0.22,
		Fade = 0.9,
		Spin = 2.5,
	},
	Rage = {
		Delay = 0.5,
		Style = "Shake",
		TypeRate = 30,
		TextHold = 2.6,
		-- owner 2026-10-22: its own face (T_Expr_Rage, CrewExpressions.Rage), not the white eyes (the ANM-013 sign) nor the
		-- Angry the shaker always wears; the grin of teeth and tongue stays on top
		Face = "Rage",
		TicEvery = { 0.1, 0.4 },
		Hold = { 0.05, 0.16 },
		-- degrees around the joint's X, Y, Z (+-)
		Neck = Vector3.new(30, 45, 35),
		Shoulder = Vector3.new(50, 35, 70),
		Torso = Vector3.new(12, 22, 14),
		Tremor = 0.12,
		TremorTurn = 5,
		Reduced = 0.3,
		StompEvery = 0.42,
		StompSpeed = 2,
	},
	-- checked on a cat rig in Studio 2026-10-22: the white eyes stay clear above the teeth (as the T2 thumbnail)
	Grin = { HeadWidth = 3.2, W = 1.6, H = 0.7, Y = -0.62, Z = 1.2, Up = 8, Lo = 7, Teeth = 1 },
	Kick = { Radius = 18, Angle = 2.6, Time = 0.22 },
	Sounds = { Smash = "plate_smash", Drop = "plate_drop", Thud = "anger_thud", Stomp = "steps_stop" },
}

return table.freeze(data)
