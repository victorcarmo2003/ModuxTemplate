--!strict
-- Horror score in steps (TASK-443, owner request 2026-10-17; the director is Anomaly/client/AnomalyController/Score).
-- Every number Provisional (frontend-coder; tune in play, the owner decides).
--
-- One director, one theme at a time: Calm -> Uneasy -> Tension -> Climax -> Release -> Calm.
--   Calm     the shift as it is (shift track once + street bed, AudioController). No theme of its own.
--   Uneasy   the reserved omen ("O Frio", anomalies-v3-restaurant.md §1 rule 2): a cold sting and a low horror bed.
--            Only before an outside anomaly (the rows of Anomalies below); never anywhere else.
--   Tension  the owner's violins, PlaybackSpeed and volume rising in a ramp until "it" arrives (Ramp s of the row).
--   Climax   "it is here" / the anomaly failed: the owner's horror choir.
--   Release  resolved or gone: a relief sting, the theme fades and the score is back to Calm after Hold s.
-- The stage of the moment = the highest Priority stage among the live anomaly records the client sees (Anomalies set);
-- Resolved records map to Release. Family A (the customer at the tablet) is NOT listed: the customer is the sign, the
-- music never gives it away. Outside Rules.Phases (and while a cue / cutscene owns the music) the score is Calm.
-- While the stage is Uneasy, Tension or Climax the street "Last window" horror layer and the shift track are held off
-- (never two tension themes at once); the kitchen SFX (Rules.KitchenKeys) duck to the stage's DuckKitchen.
-- Rules.Enabled = false: no director, the AnomalyController stings come back (the published behaviour).
local Table = require(script.Parent.Table)

export type StageKey = "Calm" | "Uneasy" | "Tension" | "Climax" | "Release"

export type Stage = {
	Key: StageKey,
	Priority: number, -- higher wins when two records want different stages
	Sound: string?, -- Content.Sounds key of the theme (looped); nil = no theme
	Volume: number, -- theme volume at the start of the stage (absolute, under the Music group)
	VolumeTo: number, -- theme volume at the end of the ramp (= Volume when there is no ramp)
	Speed: number, -- PlaybackSpeed at the start
	SpeedTo: number, -- PlaybackSpeed at the end of the ramp
	Curve: number, -- ramp shape: progress ^ Curve (1 linear, > 1 slow start and fast end)
	FadeIn: number, -- s: the theme rises from 0
	FadeOut: number, -- s: the theme of the stage we leave fades over this
	Sting: string?, -- one-shot on entering the stage (Content.Sounds key, on screen)
	DuckKitchen: number, -- kitchen SFX volume multiplier while in this stage (1 = none)
	Hold: number, -- s: minimum time in the stage before a lower one may replace it (Release: then Calm)
}

-- How one anomaly drives the score, by Ref (Content.Anomalies[k].Ref). Missing phase = that phase does not score.
export type AnomalyScore = {
	Signal: StageKey?,
	Active: StageKey?,
	Failed: StageKey?, -- default Climax
	Ramp: number, -- s of the Tension ramp (presentation only; the real windows live in AnomalyService/Rules)
	RampTrailer: number?, -- Ramp with Content.Restaurant.Rules.Enabled false (nil = Ramp)
	Caption: string?, -- key of Captions shown when the record turns Active (fresh only)
}

-- Big short warning on screen (TASK-444). Title + Line, English, gone by itself.
export type Caption = {
	Key: string,
	Title: string,
	Line: string,
	LineTrailer: string?, -- Line with Content.Restaurant.Rules.Enabled false (nil = Line)
	Duration: number, -- s on screen (fade in + hold, then fade out)
}

export type Rules = {
	Enabled: boolean,
	Phases: { string }, -- Shift keys where the score may leave Calm
	KitchenKeys: { string }, -- Content.Sounds keys that duck in Tension / Climax (AudioController Kitchen group)
	DuckTime: number, -- s of the kitchen duck tween
	CaptionFresh: number, -- s: a record seen Active later than this after it turned Active shows no caption
	PhaseFresh: number, -- s: a record that reaches the client older than this does not sting
}

local function stage(row: Stage): Stage
	return row
end

const stages = Table.new({
	stage({
		Key = "Calm",
		Priority = 0,
		Sound = nil,
		Volume = 0,
		VolumeTo = 0,
		Speed = 1,
		SpeedTo = 1,
		Curve = 1,
		FadeIn = 0,
		FadeOut = 2.5,
		Sting = nil,
		DuckKitchen = 1,
		Hold = 0,
	}),
	stage({
		Key = "Release",
		Priority = 1,
		Sound = nil,
		Volume = 0,
		VolumeTo = 0,
		Speed = 1,
		SpeedTo = 1,
		Curve = 1,
		FadeIn = 0,
		FadeOut = 3,
		Sting = "horror_chase_stop",
		DuckKitchen = 1,
		Hold = 4,
	}),
	stage({
		Key = "Uneasy",
		Priority = 2,
		Sound = "amb_horror",
		Volume = 0.22,
		VolumeTo = 0.22,
		Speed = 0.9,
		SpeedTo = 0.9,
		Curve = 1,
		FadeIn = 1.5,
		FadeOut = 1.5,
		Sting = "horror_sting", -- the cold sting of "O Frio" (1.5 s)
		DuckKitchen = 0.8,
		Hold = 1.5,
	}),
	stage({
		Key = "Tension",
		Priority = 3,
		Sound = "score_violins",
		Volume = 0.12,
		VolumeTo = 0.6,
		Speed = 0.8,
		SpeedTo = 1.3,
		Curve = 1.6,
		FadeIn = 0.8,
		FadeOut = 1.2,
		Sting = nil,
		DuckKitchen = 0.35,
		Hold = 1,
	}),
	stage({
		Key = "Climax",
		Priority = 4,
		Sound = "score_coral",
		Volume = 0.55,
		VolumeTo = 0.55,
		Speed = 1,
		SpeedTo = 1,
		Curve = 1,
		FadeIn = 0.25,
		FadeOut = 2,
		Sting = nil,
		DuckKitchen = 0.25,
		Hold = 3,
	}),
} :: { Stage })

-- Outside anomalies only (rule 2: the omen is reserved). Ramps mirror the Rules windows (Provisional).
const anomalies: { [string]: AnomalyScore } = {
	["ANM-003"] = { Signal = "Uneasy", Active = "Tension", Ramp = 20 }, -- the bell
	["ANM-006"] = { Signal = "Uneasy", Active = "Tension", Ramp = 20 }, -- the stalker at the bus stop
	["ANM-007"] = { Signal = "Tension", Active = "Climax", Ramp = 9 }, -- family B: the warning IS the approach
	["ANM-008"] = { Signal = "Uneasy", Active = "Tension", Ramp = 8 }, -- the long car
	["ANM-009"] = { Signal = "Uneasy", Active = "Tension", Ramp = 10 }, -- knock at the back
	["ANM-010"] = { Signal = "Uneasy", Active = "Tension", Ramp = 15 }, -- the Hush
	["ANM-017"] = { Signal = "Tension", Active = "Climax", Ramp = 9 },
	["ANM-018"] = { Signal = "Tension", Active = "Climax", Ramp = 9 },
	["ANM-019"] = { Signal = "Tension", Active = "Climax", Ramp = 9 },
	-- the blackout (TASK-444): omen flicker -> dark + violins up to the attack -> choir if nobody reset the power
	["ANM-020"] = {
		Signal = "Uneasy",
		Active = "Tension",
		Failed = "Climax",
		Ramp = 15, -- Rules/ANM-020 RestaurantWindow
		RampTrailer = 30, -- Rules/ANM-020 Window
		Caption = "power_out",
	},
}

const captions = Table.new({
	{
		Key = "power_out",
		Title = "POWER OUT",
		Line = "HIDE IN THE BACK",
		LineTrailer = "FIND THE BREAKER",
		Duration = 2.6,
	},
} :: { Caption })

const rules: Rules = {
	Enabled = true,
	Phases = { "Night" },
	KitchenKeys = {
		"grill_sizzle",
		"grill_drop",
		"grill_ready",
		"grill_collect",
		"grill_burnt",
		"bun_slice",
		"topping_squirt",
		"topping_sprinkle",
		"hotdog_assemble",
		"plate_put",
		"coffee_brew",
		"coffee_ready",
		"restock",
		"trash",
		"drawer",
		"drawer_close",
		"order_take",
		"serve",
		"ticket_pop",
		"dialog_blip",
	},
	DuckTime = 0.8,
	CaptionFresh = 3,
	PhaseFresh = 3,
}

return Table.with(stages, {
	Anomalies = Table.record(anomalies),
	Captions = captions,
	Rules = Table.record(rules),
})
