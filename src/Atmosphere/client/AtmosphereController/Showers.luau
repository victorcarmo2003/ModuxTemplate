--!strict
-- Rain showers (owner 2026-10-21: "a chuva cai esporadicamente ao longo da noite e sempre que cair faz um barulho alto de
-- raio e um flash"). Pure timing, same on every client without a packet: each Every-second window of server time
-- draws from Random(window) whether it has a shower (Chance), how long (Length) and when it starts (inside the window,
-- so two never overlap). Level eases in and out over Fade seconds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

type Spec = Content.AtmosphereShowers

const SEED_SALT = 7703

const Showers = {}

-- Level 0..1 of a shower from `start` lasting `length` s, at `now`.
function Showers.Span(start: number, length: number, fade: number, now: number): number
	const finish = start + length
	if now < start or now > finish then
		return 0
	end
	const ease = math.max(fade, 1e-3)
	return math.min(1, (now - start) / ease, (finish - now) / ease)
end

-- Level 0..1 of the rain at server time `now`, and the start time of the shower on now (nil = none).
function Showers.Level(spec: Spec, now: number): (number, number?)
	const window = math.floor(now / spec.Every)
	const rng = Random.new(window * SEED_SALT + 5)
	if rng:NextNumber() >= spec.Chance then
		return 0, nil
	end
	const length = math.min(rng:NextNumber(spec.Length[1], spec.Length[2]), spec.Every)
	const start = window * spec.Every + rng:NextNumber(0, spec.Every - length)
	const level = Showers.Span(start, length, spec.Fade, now)
	return level, if level > 0 then start else nil
end

return Showers
