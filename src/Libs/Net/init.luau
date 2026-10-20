--!strict
-- Net v3 (waves 1-3) + v3.1 (TASK-144: Tables set, Customers.Order2/Leader; network.md §14) + v3.2 (TASK-160..162:
-- shop, codes, ClassBuy; network.md §15). Contract: docs/tech/network.md v4 (wave 1), v5 §13.1-§13.4 (wave 2) and
-- §13.5-§13.7 (wave 3): schema, writer, reader and rate of every entry.
-- Rules: set = state the party sees (late joiners get it ready); packet = event or private data.
-- No keyBy (T14). Enums and bitfields come from Content keys (T13): Lync sorts the names, both sides require the
-- same Content, code reads and writes strings. Owner of this file: TASK-004 (wave 1), TASK-048 (wave 2), TASK-097
-- (wave 3) (board conflict point). Legacy Round packet and Health/Armor/Stamina Vitals are gone (§13.11).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)
local Content = require(ReplicatedStorage.shared.Content)
local PartyRules = require(ReplicatedStorage.shared.Party.PartyRules) -- squad notices (§16, TASK-154)
local SessionRules = require(ReplicatedStorage.shared.Session.SessionRules) -- rejoin offer (TASK-360)

-- §13.7 Cutscene record (set and its CutsceneSnapshot fallback packet)
local function cutsceneRecord()
	return Lync.struct({
		Scene = Lync.enum(Content.Cutscenes.Keys),
		StartedAt = Lync.f64(),
		Votes = Lync.int(0, 4),
		Needed = Lync.int(0, 4),
		-- true while the server holds the chain for the participants' ClientReady (Scene = "none" meanwhile)
		Waiting = Lync.bool(),
	})
end

-- Player settings record (Settings and SettingsSave packets; TASK-279). Volumes are percents (SettingsRules)
local function settingsRecord()
	return Lync.struct({
		Music = Lync.int(0, 100),
		Sfx = Lync.int(0, 100),
		Voice = Lync.int(0, 100),
		Scare = Lync.int(0, 100),
		PromptMode = Lync.enum({ "Single", "Multi" }),
		PrepAssist = Lync.bool(),
		ReducedMotion = Lync.bool(),
		Vibration = Lync.bool(),
		ShopTips = Lync.bool(),
	})
end

-- Restaurant sets (wave R0) live in their own namespace and module, Net.Restaurant: required here so both machines
-- define it before Lync.start; code reaches them with require(ReplicatedStorage.shared.Libs.Net.Restaurant).
require(script.Restaurant)

return Lync.define("game", {
	-- c -> s handshake (NetService.Audience)
	Ready = Lync.packet(Lync.empty()),

	-- s -> owner (network.md §4.5; DEC-186). Private by construction: fireClient, never a set
	Profile = Lync.packet(Lync.struct({
		Gems = Lync.int(0, 2147483647),
		Classes = Lync.bitfield(Content.Classes.Keys), -- unlocked classes
		Selected = Lync.enum(Content.Classes.Keys),
		-- Legacy (data.md §1.1): no longer read by anyone, the tutorial runs on Day 1 of every run (Provisional, 2026-10-11)
		TutorialDone = Lync.bool(),
	})),

	-- c -> s, at most once per session (Provisional, user request 2026-10-11). Responder: TutorialService. The
	-- first-hot-dog tutorial ended (finished or skipped) on this client: closed for this run in server memory (nothing
	-- is saved). Cosmetic only (no money, item or stat rides on it), so the client is trusted to say it.
	-- How (analytics, 2026-10-17): "done" finished, "skip" skipped, "over" the day ended first (onboarding funnel)
	TutorialComplete = Lync.packet(Lync.struct({
		How = Lync.enum({ "done", "skip", "over" }),
	})),
	-- c -> s (Provisional, user request 2026-10-11). Responder: TutorialService. The rookie answered Walt's tutorial
	-- call (or it never came): the server spawns the tutorial customer (CustomerService:RequestTutorial) when this
	-- player has the tutorial pending (Day 1 of the run, not finished or skipped). Idempotent while one is around.
	TutorialBegin = Lync.packet(Lync.empty()),
	-- c -> s (owner request 2026-10-14, Provisional). Responder: TutorialService. The rookie skipped the Day 1 upgrade
	-- lesson (Gear Stand at 6 PM): no longer a rookie for the lesson, so the Closing hold lets go once nobody is left.
	-- Cosmetic, idempotent.
	TutorialLessonSkip = Lync.packet(Lync.empty()),
	-- s -> owner, dev mode only (Studio Run place; user request 2026-10-11, Provisional). Writer: TutorialService
	-- (DevSend, from the DevService chat commands tutorial / voice / tutdebug). Responder: TutorialController (OnInit).
	-- Client-side dev tools: Command = what to run on the client, Text = its arguments (free text, trimmed).
	DevClient = Lync.packet(Lync.struct({
		Command = Lync.str(0, 32),
		Text = Lync.str(0, 200),
	})),
	-- s -> owner, dev mode only (user request 2026-10-11, Provisional). Writer: DevService command `audio` (through
	-- NetService). Responder: AudioController (OnInit). Command = "report": the client prints its audio counters.
	DevAudio = Lync.packet(Lync.struct({
		Command = Lync.str(0, 32),
	})),
	-- c -> s, dev mode only (TASK-332; owner request 2026-10-15, Provisional). Writer: SettingsController (dev row of the
	-- settings panel). Responder: DevService (OnInit, only when PlaceService:IsDev; runs the `mycoffee` / `infsanity`
	-- commands for the sender). Nothing listens in a published server.
	DevTool = Lync.packet(Lync.struct({
		Tool = Lync.enum({ "Coffee", "InfiniteSanity" }),
		On = Lync.bool(),
	})),

	-- Dev showcase (docs/tech/showcase.md; user request 2026-10-12, Provisional). Packets only, dev mode only (Studio
	-- Run place): the responder lives in ShowcaseService, which refuses unless PlaceService:IsDev and
	-- AdminSettings.IsAllowed on EVERY request. Nothing here exists in a published server (no responder, no sender).
	-- c -> s. Action = open | close | trigger | resolve | stop | reset | extra | scare | ctl; Id = item id ("ANM-007",
	-- "mech_thief", "fake_call") or control name; Arg / Value = parameters of that action.
	ShowcaseDo = Lync.packet(Lync.struct({
		Action = Lync.str(0, 24),
		Id = Lync.str(0, 40),
		Arg = Lync.str(0, 80),
		Value = Lync.f64(),
	})),
	-- s -> owner, on open. The item list (names, descriptions and the correct verb come from the server: T10 keeps the
	-- verbs off the client in production, and this packet never goes out there).
	ShowcaseCatalog = Lync.packet(Lync.struct({
		Items = Lync.array(
			Lync.struct({
				Tab = Lync.str(0, 12),
				Group = Lync.str(0, 24),
				Id = Lync.str(0, 40),
				Name = Lync.str(0, 48),
				Ref = Lync.str(0, 16),
				Desc = Lync.str(0, 300),
				Verb = Lync.str(0, 160),
				Actions = Lync.array(
					Lync.struct({
						Id = Lync.str(0, 24),
						Label = Lync.str(0, 28),
						Arg = Lync.str(0, 80),
					}),
					0,
					8
				),
			}),
			0,
			80
		),
	})),
	-- s -> owner, 2 Hz while the panel is open. Live readout of the run (night, clock, sanity, flags, occurrences)
	ShowcaseState = Lync.packet(Lync.struct({
		Night = Lync.int(0, 10),
		Phase = Lync.str(0, 16),
		Clock = Lync.f64(),
		Sanity = Lync.int(0, 200),
		SanityMax = Lync.int(0, 200),
		Life = Lync.str(0, 16),
		Revives = Lync.int(0, 99),
		Frozen = Lync.bool(),
		God = Lync.bool(),
		Dark = Lync.str(0, 8),
		Held = Lync.bool(),
		Switch = Lync.bool(),
		Shutter = Lync.bool(),
		Vehicle = Lync.str(0, 24),
		Running = Lync.array(
			Lync.struct({
				Ref = Lync.str(0, 12),
				Phase = Lync.str(0, 12),
				Step = Lync.int(0, 20),
				Age = Lync.f64(),
				Live = Lync.bool(),
			}),
			0,
			32
		),
	})),
	-- s -> owner. Result line of a request ("ok" / "error" / "info"); "open" = the panel must open (chat / Conch)
	ShowcaseLog = Lync.packet(Lync.struct({
		Kind = Lync.enum({ "info", "ok", "error", "open" }),
		Text = Lync.str(0, 400),
	})),
	-- s -> owner. Plays one hallucination / sting on THIS client (client-only effects, HallucinationController)
	ShowcaseScare = Lync.packet(Lync.struct({
		Id = Lync.str(0, 40),
		Stop = Lync.bool(),
	})),
	-- s -> player(s). Family D scare (DEC-254, TASK-274; writer HallucinationService:Scare): the client plays ONE
	-- Content.Hallucinations row with FamilyD among `Keys` (empty = any) that it can show right now. Client-only effect.
	HallucinationScare = Lync.packet(Lync.struct({
		Keys = Lync.array(Lync.str(1, 40), 0, 32),
	})),

	-- s -> Audience. Suspense event (TASK-481, DEC-294; tech/suspense.md; writer SuspenseService): the creature of Event
	-- appears now on Spot and stays Content.Suspense.Rules.Life s. Id = event id of the night (1..255, cyclic). Not an
	-- anomaly: no set, a late joiner simply misses it. Client-only presentation; the cost is the server's.
	Suspense = Lync.packet(Lync.struct({
		Id = Lync.int(0, 255),
		Event = Lync.enum(Content.Suspense.Keys),
		Spot = Lync.enum(Content.Suspense.SpotKeys),
		Seed = Lync.int(0, 65535),
	})),
	-- c -> s. "I caught it at a glance" (sender SuspenseController; responder SuspenseService, which checks the event is
	-- live, the player Active and the Gaze plausible, then charges Content.Suspense.Rules.Cost once per player per event)
	SuspenseSeen = Lync.packet(Lync.struct({
		Id = Lync.int(0, 255),
	})),

	-- Run sets, wave 1 ---------------------------------------------------------------------------------------------

	-- §3.1, record 1. Writer: RoundService. Wave 1 writes only day fields (Night = 0, IsNight = false...)
	Shift = Lync.replicate(Lync.struct({
		Day = Lync.int(1, 10000),
		Night = Lync.int(0, 10),
		IsNight = Lync.bool(),
		Attempt = Lync.int(0, 9),
		Phase = Lync.enum(Content.Shift.PhaseKeys),
		PhaseStartedAt = Lync.f64(),
		PhaseDuration = Lync.int(0, 3600),
		ClockFrom = Lync.int(0, 2880), -- game minutes
		ClockTo = Lync.int(0, 2880),
		Vehicle = Lync.enum(Content.Vehicles.Keys),
		Chances = Lync.int(0, 9), -- DEC-110, DEC-112; not shown on the HUD (DEC-053)
		WipeEndsAt = Lync.f64(), -- 0 = no wipe window (DEC-094)
		WipeFrozen = Lync.bool(), -- DEC-118
		Paused = Lync.bool(), -- shop switch on Closed during Open: no new customers (2026-10-12)
	})),

	-- §3.2, record 1. Writer: RunStateService
	RunState = Lync.replicate(Lync.struct({
		PriceParty = Lync.int(0, 4), -- 0 until the end of Day 1, then fixed (DEC-121)
		RosterSize = Lync.int(1, 4),
		Endless = Lync.bool(), -- DEC-084
	})),

	-- §3.3, record 1. Writer: EconomyService
	Economy = Lync.replicate(Lync.struct({
		Cash = Lync.int(0, 2147483647),
		Drawer = Lync.int(0, 1000000), -- tips in the TIP JAR since DEC-239 (name kept for the wire)
	})),

	-- §3.4, record = Content.Ingredients.IndexOf[key] (all 9 always). Writer: KitchenService
	Stock = Lync.replicate(Lync.struct({
		Amount = Lync.int(0, 999),
		Capacity = Lync.int(0, 999), -- Cooler level of the current vehicle (DEC-184)
		Blocked = Lync.bool(), -- not unlocked yet: bowl lid, Mart "Out of stock", order draw (DEC-156, DEC-180)
		-- Gift bowl (owner request 2026-10-14, Provisional): unlocked but still closed (Ingredients.GiftKeys, not opened this
		-- run). nil = false. Optional so a record that never had it reads as an open bowl; 9 records with Amount 10 bits wide,
		-- so the drop.section floor of README does not apply
		Wrapped = Lync.optional(Lync.bool()),
	})),

	-- §3.5, record = StationId * 100 + Slot (Slot 0 = single-record station). Writer: KitchenService
	Stations = Lync.replicate(Lync.struct({
		Kind = Lync.enum(Content.Stations.RecordKeys), -- grill, rail, board (2 records, DEC-190)
		-- Cleaning: coffee machine only (TASK-328), the wait after a cup is taken, StartedAt/Duration like Working
		-- Burnt: restaurant grill slot left Ready past Content.Restaurant.Grill.BurnAfter (design FEAT-045; wave R0, no writer yet)
		State = Lync.enum({ "Empty", "Working", "Ready", "Cleaning", "Burnt" }),
		StartedAt = Lync.f64(), -- 0 = idle
		Duration = Lync.quant(0, 120, 0.1), -- real duration (level and class applied)
		Count = Lync.int(0, 30), -- rail: sausages on it; others 0
		-- Wave 3 (§13.5, ANM-002): 0 or nil = nothing altered; grill/board: 1 = this slot; rail: position 1..Count.
		-- Optional so the wave 1-2 writer keeps compiling and encoding until TASK-109 writes it (nil reads as 0).
		Altered = Lync.optional(Lync.int(0, 30)),
		-- prep-3d.md §7.2 N2 (TASK-194): grill slot only. Flip score of the sausage + 1 (1..101) once flipped, nil or 0 =
		-- not flipped. Written by the grill on Flip, cleared on Collect / Place. Optional like Altered: the set has 8+ records
		-- and the value needs 7 bits (101 < 128), so Lync's drop.section floor does not apply
		Flip = Lync.optional(Lync.int(0, 101)),
	})),

	-- §3.6, record = NpcId. Writer: CustomerService. Looks are model attributes (network.md §5), not here
	Customers = Lync.replicate(Lync.struct({
		State = Lync.enum({ "Arriving", "Queued", "Ordering", "Waiting", "Leaving" }),
		Slot = Lync.int(0, 8), -- 0 = out of the queue; 1..5 = Q1..Q5
		Order = Lync.bitfield(Content.Ingredients.ToppingKeys), -- empty until "Take Order" (FEAT-011)
		PatienceEndsAt = Lync.f64(), -- deadline of the current patience phase (server time); 0 = no clock running (Q-192)
		-- Q-192 (Provisional): which patience clock runs. Queue = at Q1 until "Take Order"; Order = from "Take Order"
		-- until served; None = not running (arriving, behind Q1, tutorial customer). Written with PatienceEndsAt.
		Phase = Lync.enum({ "None", "Queue", "Order" }),
		-- Q-192: length of the current phase in whole seconds (the client's bar is (EndsAt - now) / Span). 8 bits on
		-- purpose (the set has 8+ records, Lync keyframe floor); 0 = none. Capped at OrderRules.WireSpanMax (255).
		PatienceSpan = Lync.int(0, 255),
		Mood = Lync.enum(Content.Moods.Keys), -- Provisional (Q-164)
		-- §14.2 (TASK-144; FEAT-038). Pair leader: the 2nd hot dog still pending (nil = none or a lone customer; the
		-- record always shows the pending items, Order = the 1st pending one). Written with Order at "Take Order".
		Order2 = Lync.optional(Lync.bitfield(Content.Ingredients.ToppingKeys)),
		-- §14.2 (TASK-144; FEAT-038). Pair partner: NpcId of its leader (nil = not a partner). A partner never shows a
		-- balloon nor prompts; its State is Arriving / Queued / Leaving only
		Leader = Lync.optional(Lync.int(1, 65535)),
		-- Restaurant (tech/restaurant-flow.md rev. 2 §2.6; wave R0, no writer until R1-C / R3). nil = the trailer flow.
		-- Place in the pickup line PU-1..n after "Take Order" (n <= Content.Restaurant.Rules.PickupSlotsMax); nil = not in it
		Pickup = Lync.optional(Lync.int(1, 12)),
		-- #n of the order over the head, on the plate ticket and on the HUD note (design FEAT-043; 1..Rules.OrderNumberMax)
		Number = Lync.optional(Lync.int(1, 255)),
		-- §3.4 (wave R3): drive-thru lane spot (DriveCars id); nil = a walking customer
		Drive = Lync.optional(Lync.int(1, 3)),
	})),

	-- §3.7, record = Content.Upgrades.IndexOf[key]; levels of the current vehicle only (DEC-184). Writer: UpgradeService
	Upgrades = Lync.replicate(Lync.struct({
		-- Real range 0..9 (UpgradeService clamps). The wire is 8 bits on purpose: Lync 4.0.2 bounds a keyframe at
		-- >= 1 byte per record, but 8 records x 4 bits + 1-bit id steps pack below that, so a keyframe that ended its
		-- frame was refused on the client ("drop.section ... more records than its own bytes could hold").
		Level = Lync.int(0, 255),
		-- Gear Stand cooldown (Q-203 Provisional): shifts left before the line is on sale again, 0 = on sale. 8 bits for
		-- the same keyframe reason as Level.
		Wait = Lync.int(0, 255),
	})),

	-- §14.1 (TASK-144; FEAT-037), record = table index 1..Content.Seating.Tables (TBL-n; Pad 1..5, Trailer 6..9, Q-209).
	-- 9 records: every field of the struct is wide (Price 10 bits, Npc 16, Tip 10; State 3 bits rides with them), so a
	-- record is far above the 1 byte Lync 4.0.2 bounds a keyframe record at (see Upgrades.Level, 8 bits for that). Writer: SeatingService. Locked = before Seating.UnlockDay (hidden); Ghost = not bought (Price > 0 only on
	-- the next one for sale); Free / Occupied / Dirty = bought. Npc1/Npc2 = NpcId of the diners (0 = none). Tip = $
	-- on the table (Dirty), moved to the drawer by "Clean Table"
	Tables = Lync.replicate(Lync.struct({
		State = Lync.enum(Content.Seating.States),
		Price = Lync.int(0, 1000),
		Npc1 = Lync.int(0, 65535),
		Npc2 = Lync.int(0, 65535),
		Tip = Lync.int(0, 1000),
	})),

	-- Packets, wave 1 ----------------------------------------------------------------------------------------------

	-- §4.1 c -> s. Single responder: InteractionService (T6). <= 8/s per player
	Interact = Lync.packet(Lync.struct({
		Id = Lync.int(1, 65535), -- EntityId of the target anchor (T33)
		Action = Lync.enum(Content.Actions.Keys),
	})),

	-- §4.2 s -> player or group, through RunStateService:Notify
	Notice = Lync.packet(Lync.struct({
		Kind = Lync.enum(Content.Notices.Keys),
		Value = Lync.int(-1000000, 1000000), -- {value} of the text, or a table index
	})),

	-- §4.3 s -> group. Writer: CustomerService
	Sale = Lync.packet(Lync.struct({
		Npc = Lync.int(1, 65535), -- NpcId
		Result = Lync.enum({ "Perfect", "Complete", "Incomplete", "Wrong", "Left", "Refused", "Slow" }), -- Left = never attended (queue clock), Slow = food took too long (order clock, Q-192)
		Amount = Lync.int(0, 1000), -- what was paid (price into Cash, tip into the jar)
	})),

	-- §4.3b s -> group. Writer: TipJarService ("Collect Tips", DEC-239): the tip jar went to Cash. Presentation only
	CashCollected = Lync.packet(Lync.struct({
		Amount = Lync.int(1, 1000000),
	})),

	-- §4.4 s -> group, start of Summary. Writer: EconomyService
	ShiftReport = Lync.packet(Lync.struct({
		Day = Lync.int(1, 10000),
		Night = Lync.int(0, 10),
		IsNight = Lync.bool(),
		Arrived = Lync.int(0, 999),
		Completed = Lync.int(0, 999),
		Drawer = Lync.int(0, 1000000), -- the day take (Sales + Tips + Catches - Stolen); name kept for the wire
		Tips = Lync.int(0, 100000),
		Stolen = Lync.int(0, 1000000), -- wave 1: 0
		Grade = Lync.enum({ "A", "B", "C", "D" }), -- no customer = C (DEC-051)
		Bonus = Lync.int(0, 1000000),
		Deposited = Lync.int(0, 1000000),
		Gems = Lync.int(0, 100000), -- wave 1: 0; x75 gem economy (TASK-308): a night pays up to ~2,500 + finale
		AfkLocked = Lync.bool(), -- wave 1: false
		LastChanceUsed = Lync.bool(), -- wave 1: false
	})),

	-- §4.6 c -> s. Responder: ClassService. <= 2/s
	ClassAction = Lync.packet(Lync.struct({
		Action = Lync.enum({ "Buy", "Select" }),
		Class = Lync.enum(Content.Classes.Keys),
	})),

	-- Wave 2 (network.md §13.1-§13.4) ----------------------------------------------------------------------------

	-- §13.1, record = UserId. Writer: VitalService (single writer). Replaces the legacy Health/Armor/Stamina set
	Vitals = Lync.replicate(Lync.struct({
		State = Lync.enum({ "Active", "Down", "Reviving", "Spectator", "Away" }),
		StateEndsAt = Lync.f64(), -- Down: 6:00 AM of the night of the fall (DEC-115); 0 = no deadline
		KnockedUntil = Lync.f64(), -- hit by a car until (wave 3); 0 = standing
		Class = Lync.enum(Content.Classes.Keys),
	})),

	-- s -> owner. Writer: VitalService, on the fall (DEC-317 etapa D): what drained the last sanity (LastCause:
	-- "anomaly:<key>", "stare:<key>", "see:<key>", "suspense:<key>", "dark", ...); Known = the player had met that anomaly
	FaintCause = Lync.packet(Lync.struct({
		Cause = Lync.str(0, 64),
		Known = Lync.bool(),
	})),

	-- §13.1 s -> owner. Writer: VitalService. Max = 0: no sanity (day), the HUD hides the meter
	Sanity = Lync.packet(Lync.struct({
		Value = Lync.int(0, 200),
		Max = Lync.int(0, 200),
	})),

	-- §13.1 s -> owner. Writer: VitalService (user request 2026-10-11, Provisional). Night 1 coffee lesson and the
	-- coffee gain feedback: Hint = emphasise the sanity bar and the coffee machine until `Until` (server time);
	-- Gain = a coffee gave `Amount` (bar glows green, "+N" floats); End = emphasis over (drunk, timed out, night end)
	SanityCue = Lync.packet(Lync.struct({
		Kind = Lync.enum({ "Hint", "Gain", "End" }),
		Amount = Lync.int(0, 200),
		Until = Lync.f64(),
	})),

	-- §13.1 s -> group. Writers: VitalService, TrafficService (Hit, wave 3). The state itself is in Vitals
	LifeEvent = Lync.packet(Lync.struct({
		UserId = Lync.f64(),
		Event = Lync.enum({ "Down", "Revived", "Spectating", "Hit", "Wipe", "WipeCleared" }),
	})),

	-- §13.1 s -> group. Writer: TrailerDoorService (VehicleSwap / TrailerFocus are legacy values, nobody sends them since 2026-10-12)
	Transition = Lync.packet(Lync.struct({
		-- TrailerDoor: 0.6 s fade of Exit/Enter Trailer (only to who used the door). DoorLocked (ANM-004, DEC-247): the
		-- back door is locked by the anomaly and the player tried it; only the "Locked door" sound plays (StartedAt unused)
		Kind = Lync.enum({ "VehicleSwap", "TrailerFocus", "TrailerDoor", "DoorLocked" }),
		StartedAt = Lync.f64(),
	})),

	-- §13.1 s -> each player on RunEnded. Writer: RoundService. Gems of this run for this player (RunRewards)
	RunReport = Lync.packet(Lync.struct({
		Result = Lync.enum({ "Success", "Failed" }),
		Day = Lync.int(1, 10000),
		Night = Lync.int(0, 10),
		Gems = Lync.int(0, 100000),
	})),

	-- §13.2, record = Content.LightGroups.IndexOf[key]. Writer: LightService
	Lights = Lync.replicate(Lync.struct({
		On = Lync.bool(), -- group lit now (night, switch/upgrade, no Hush)
		At = Lync.f64(), -- last change; Hush: start (posts go out by Order x Step)
	})),

	-- §13.3, record 1. Writer: BossService. Line = floor((now - StartedAt) / BossCallRules.LineTime) (T44)
	Call = Lync.replicate(Lync.struct({
		Call = Lync.enum(Content.BossCalls.Keys), -- includes "none"
		State = Lync.enum({ "Idle", "Ringing", "Talking" }),
		StartedAt = Lync.f64(),
	})),

	-- §13.4, record 1. Writer: ThiefService. Bar over Bar_Thief by StartedAt / Duration
	Thief = Lync.replicate(Lync.struct({
		State = Lync.enum({ "None", "Lurking", "Approaching", "Opening", "Fleeing" }),
		StartedAt = Lync.f64(),
		Duration = Lync.quant(0, 30, 0.1), -- Opening: 8 s (16 s with UPG-004)
	})),

	-- Wave 3 (network.md §13.5-§13.7) ----------------------------------------------------------------------------

	-- §13.5, record = occurrence 1..255 (cyclic, per night). Writer: AnomalyService. No verb or deadline (T10)
	Anomalies = Lync.replicate(Lync.struct({
		Anomaly = Lync.enum(Content.Anomalies.Keys),
		Phase = Lync.enum({ "Signal", "Active", "Resolved", "Failed" }),
		StartedAt = Lync.f64(),
		-- Walker: step 0..Steps (4); Hush: posts out; others 0
		Step = Lync.int(0, 20),
		-- NpcId of the customer anomaly, or anchor index (AnchorId/MapPoint); 0 = none
		Anchor = Lync.int(0, 65535),
	})),

	-- §13.5 s -> group (everyone sees the sign, DEC-204). Writer: AnomalyService
	AnomalyCue = Lync.packet(Lync.struct({
		Anomaly = Lync.enum(Content.Anomalies.Keys),
		Cue = Lync.enum(Content.AnomalyCues.Keys),
		Entity = Lync.int(0, 65535),
		Seed = Lync.int(0, 65535),
	})),

	-- §13.5 c -> s, 10 Hz, latest wins. Sender: CameraController (night, Active). Responder: AnomalyService.
	-- Degrees 0..360, 1 degree steps; angle is cyclic, so a pitch of -20 travels as 340 (reader maps > 180 to -).
	Gaze = Lync.packet(Lync.struct({
		Yaw = Lync.angle(1),
		Pitch = Lync.angle(1),
	})):newest(10),

	-- §13.7 (§6.2 schema), record 1. Writer: CutsceneService. Needed = ceil(0.5 x connected participants) (DEC-194)
	Cutscene = Lync.replicate(cutsceneRecord()),
	-- s -> Audience, on every Cutscene write and in reply to ClientReady. Writer: CutsceneService. Same record as the
	-- set; the client (CutsceneController) uses it only while its Cutscene set has no record 1 (a backlog lost to
	-- drop.unready before NetService:Resync landed): a scene must never wait on one lost keyframe
	CutsceneSnapshot = Lync.packet(cutsceneRecord()),

	-- §13.7 c -> s, <= 1 per segment. Responder: CutsceneService
	SkipVote = Lync.packet(Lync.empty()),

	-- c -> s, once per join: this client finished its loading screen (game loaded, controllers started, crew kit,
	-- images preloaded; LoadingController). Responder: CutsceneService (a scene waits
	-- for every participant, up to Content.Cutscenes.Rules.ReadyTimeout). Not the Net handshake (`Ready`).
	ClientReady = Lync.packet(Lync.empty()),

	-- §13.7 (§6.2 schema; architecture.md §8.1), record = car slot 1..8. Writer: TrafficService, on events only.
	-- Route = Content.Traffic.Routes.IndexOf; Look = Content.Traffic.LookIndex (4 shapes x 5 paints = 20; room to 32).
	-- Position = Traffic/shared/Motion from the last record (AnchorAt/AnchorDist, stop at StopDist until HeldUntil)
	Traffic = Lync.replicate(Lync.struct({
		Route = Lync.int(1, 32),
		Look = Lync.int(1, 32),
		AnchorAt = Lync.f64(),
		AnchorDist = Lync.f32(),
		StopDist = Lync.f32(),
		HeldUntil = Lync.f64(),
	})),

	-- §13.7 (§6.2 schema; architecture.md §8.2) c -> s, own character only. Responder: TrafficService (+-8 studs)
	CarHit = Lync.packet(Lync.struct({
		Car = Lync.int(1, 8),
	})),

	-- §13.7, record = pedestrian slot 1..8. Writer: PedestrianService. Looks ride here (rule 9 exception: no server
	-- model, T46); same 1D record as Traffic, read with Traffic/shared/Motion
	Pedestrians = Lync.replicate(Lync.struct({
		-- Content.WalkPaths.IndexOf
		Path = Lync.int(1, 64),
		Species = Lync.enum(Content.Species.Keys),
		Outfit = Lync.enum(Content.Outfits.Keys),
		Speed = Lync.quant(4, 12, 0.5),
		AnchorAt = Lync.f64(),
		AnchorDist = Lync.f32(),
		-- stop at a crosswalk waiting for the reservation (§8.1); 0 = no stop
		StopDist = Lync.f32(),
		HeldUntil = Lync.f64(),
	})),

	-- Shop, codes, classes by Robux (network.md §15; user request 2026-10-11, Provisional; TASK-160..162) -------------
	-- Balance and owned classes ride the existing private Profile packet (Gems, Classes): no Wallet set.

	-- §15.1 c -> s, <= 2/s (shared with ClassAction). Responder: ClassService. "Gems" buys; "Robux" is a pre-check
	-- (answer "Prompt" = the client may PromptGamePassPurchase Content.Shop.GamePasses[Class].PassId; TASK-291)
	ClassBuy = Lync.packet(Lync.struct({
		Class = Lync.enum(Content.Classes.Keys),
		Currency = Lync.enum({ "Gems", "Robux" }),
	})),
	-- §15.1 s -> owner. Writers: ClassService (answer to ClassBuy), ShopService (Robux receipt: Granted / Converted)
	ClassBuyResult = Lync.packet(Lync.struct({
		Class = Lync.enum(Content.Classes.Keys),
		Ok = Lync.bool(),
		Reason = Lync.enum({
			"Ok",
			"Prompt",
			"Granted",
			"Converted",
			"Owned",
			"NotEnoughGems",
			"NotForSale",
			"Unavailable",
			"Busy",
		}),
	})),

	-- Class skins (owner request 2026-10-17, Provisional; design/skins-proposal.md). Robux only: the client prompts the
	-- Developer Product of Content.Skins itself, SkinService grants on the receipt.
	-- s -> owner, on load and on every change. Writer: SkinService. Owned = skins in profile.Skins; Equipped = the skin worn
	-- per class (profile.EquippedSkins). Private by construction (fireClient).
	SkinState = Lync.packet(Lync.struct({
		Owned = Lync.bitfield(Content.Skins.Keys),
		Equipped = Lync.array(
			Lync.struct({
				Class = Lync.enum(Content.Classes.Keys),
				Skin = Lync.enum(Content.Skins.Keys),
			}),
			0,
			16
		),
	})),
	-- c -> s. Responder: SkinService (own rate limit). Wear `Skin` with `Class` ("none" = the crew uniform); refused when
	-- the skin is not owned, is of another class, or the class is not owned.
	SkinEquip = Lync.packet(Lync.struct({
		Class = Lync.enum(Content.Classes.Keys),
		Skin = Lync.enum(Content.Skins.Choices),
	})),

	-- §15.2 c -> s. Responder: CodesService (normalizes: trim, no spaces, upper case; own rate limit)
	CodeRedeem = Lync.packet(Lync.struct({
		Code = Lync.str(0, 32),
	})),
	-- §15.2 s -> owner. Writer: CodesService. Reward = what was credited (Gems includes a class converted to gems)
	CodeRedeemResult = Lync.packet(Lync.struct({
		Ok = Lync.bool(),
		Reason = Lync.enum({ "Ok", "Invalid", "Expired", "Already", "Busy" }),
		Reward = Lync.struct({
			Gems = Lync.int(0, 1000000),
			Class = Lync.optional(Lync.enum(Content.Classes.Keys)),
		}),
	})),

	-- Player settings (TASK-279; owner request 2026-10-14, Provisional). Shape and clamp: Settings/shared/SettingsRules.
	-- s -> owner, once per session when the profile is loaded and the client is ready. Writer: SettingsService.
	-- Responder: SettingsController (OnInit). Private by construction (fireClient).
	Settings = Lync.packet(settingsRecord()),
	-- c -> s. Responder: SettingsService (sanitizes, own rate limit, saves to the profile). The client sends the whole
	-- record a moment after the last change (debounced), never per slider frame.
	SettingsSave = Lync.packet(settingsRecord()),

	-- HUD cart utilities (TASK-290; owner request 2026-10-14, Provisional; Content.Shop.Utilities).
	-- c -> s, right before PromptProductPurchase. Responder: ShopUtilityService (own rate limit). The target of the next
	-- receipt of that product: Mate = UserId, Ingredient = Content.Ingredients index; 0 = none (the server picks).
	ShopPick = Lync.packet(Lync.struct({
		Product = Lync.enum(Content.Shop.Utilities.Keys),
		Target = Lync.f64(),
	})),
	-- s -> one player. Writer: ShopUtilityService, after a receipt was granted. Responder: ShopController.
	-- To the buyer (Value = Cash dollars / Radar seconds / ingredient index; util_scare: Value 0, From = the mate, 0 = none),
	-- or to the scared mate (util_scare, Value 1, From = buyer UserId)
	ShopGrant = Lync.packet(Lync.struct({
		Product = Lync.enum(Content.Shop.Utilities.Keys),
		Value = Lync.int(0, 100000),
		From = Lync.f64(),
	})),
	-- Contextual offers (TASK-361; owner request 2026-10-17, Provisional; Content.Shop.Offers). s -> one player.
	-- Writer: EconomyService (Spend without enough Cash: the Cash pack covering the difference, instead of opening the
	-- Roblox prompt by itself). Responder: OfferController, which shows it in the HUD nudge slot if its rules allow.
	-- Product = Content.Shop.Utilities key the click buys; Value = missing dollars.
	ShopOffer = Lync.packet(Lync.struct({
		Offer = Lync.enum(Content.Shop.Offers.Keys),
		Product = Lync.enum(Content.Shop.Utilities.Keys),
		Value = Lync.int(0, 100000),
	})),
	-- Gifts (TASK-352; owner request 2026-10-16, Provisional; Content.Shop.Gifts). Responder/writer: GiftService.
	-- c -> s, right before PromptProductPurchase of Content.Shop.Gifts[Key].ProductId (own rate limit). Stores Recipient
	-- (UserId) as the target of this buyer's next receipt of that gift product. Answer: GiftResult (Ok = may prompt).
	GiftPrompt = Lync.packet(Lync.struct({
		Key = Lync.enum(Content.Shop.Gifts.Keys),
		Recipient = Lync.f64(),
	})),
	-- s -> owner (the giver). Answer to GiftPrompt (Ok / Self / NotFound / Unavailable / Rate / Busy) and, after the
	-- receipt, Sent (the message reached the recipient's profile) or Failed (receipt retried by Roblox later).
	GiftResult = Lync.packet(Lync.struct({
		Ok = Lync.bool(),
		Reason = Lync.enum({ "Ok", "Sent", "Self", "NotFound", "Unavailable", "Rate", "Busy", "Failed" }),
		Key = Lync.enum(Content.Shop.Gifts.Keys),
	})),
	-- s -> owner (the recipient), when a gift is delivered to the loaded profile (now, or on the next join if offline).
	-- Kind Class: Key = class key, Amount 0. Kind Gems: Key = gem pack key ("" for an admin gift), Amount = gems; a
	-- class the recipient already owned arrives as Kind Gems, Key = that class key, Amount = its gem Price.
	GiftReceived = Lync.packet(Lync.struct({
		Kind = Lync.enum({ "Class", "Gems" }),
		Key = Lync.str(0, 32),
		Amount = Lync.int(0, 2147483647),
		FromName = Lync.str(0, 40),
	})),
	-- Revive Kit (TASK-317). s -> owner. Writer: ReviveKitService. The profile.ReviveCredits of this player (sent on
	-- Ready, on load and after every change). Responder: ReviveKitController (self button, mate prompt gate)
	ReviveKits = Lync.packet(Lync.struct({
		Count = Lync.int(0, 99),
	})),
	-- c -> s. Responder: ReviveKitService (own rate limit). The Down player spends one credit on itself
	ReviveKitUse = Lync.packet(Lync.empty()),

	-- Squad (party) in the lobby and the way back (network.md §16; architecture.md §20; user request 2026-10-11,
	-- Provisional; TASK-154..156). Responders: PartyService (lobby roles), PartyRunService (LobbyReturn, game role).
	-- UserIds travel as f64 (exact up to 2^53). Every c -> s entry shares PartyRules.Rules.RateMax per RateWindow.

	-- §16.1, record = PartyId (1..PartyRules.Rules.PartyIdMax). Writer: PartyService (lobby only). Everyone in the
	-- lobby sees every squad (no keyBy); a client finds its own by looking for its UserId in Members
	Party = Lync.replicate(Lync.struct({
		Leader = Lync.f64(),
		Members = Lync.array(Lync.f64(), 1, 4), -- party order, leader first; max = PartyRules.Rules.MaxSize
		Ready = Lync.map(Lync.f64(), Lync.bool(), 0, 4), -- every member; the leader is always true
		-- Forming = invite squad; Configuring = platform squad being set up (platform red); Starting = countdown, then
		-- reserve + teleport (platform green)
		State = Lync.enum({ "Forming", "Configuring", "Starting" }),
		-- §16.6 squad platforms (user request 2026-10-11, Provisional)
		Platform = Lync.int(0, 8), -- PartyRules.Rules.Platforms (LOBBY v2: 8); LOBBY-SQUAD-n owned by this squad; 0 = none (invite squad)
		-- §16.9 who may join: "Setup" private while the leader chooses, Open, Friends (friends of the leader), Invite
		-- (invites only), Closed. Small enum: the record is wide (f64 ids), so no drop.section risk
		Access = Lync.enum(PartyRules.Access),
		MaxPlayers = Lync.int(1, 4), -- set by the leader, never below the member count
		StartAt = Lync.f64(), -- workspace:GetServerTimeNow() when the teleport starts; 0 = no countdown
	})),
	-- §16.2 c -> s. New squad with the sender as leader (refused when already in one)
	PartyCreate = Lync.packet(Lync.empty()),
	-- §16.2 c -> s. Leader invites a player of this server (no squad yet = one is created first)
	PartyInvite = Lync.packet(Lync.struct({
		UserId = Lync.f64(),
	})),
	-- §16.2 s -> invited player. From = leader UserId. Valid PartyRules.Rules.InviteTtl s
	PartyInviteReceived = Lync.packet(Lync.struct({
		From = Lync.f64(),
		PartyId = Lync.int(1, 65535),
	})),
	-- §16.2 c -> s. Answer to an invite (Accept = leave the current squad and join)
	PartyRespond = Lync.packet(Lync.struct({
		PartyId = Lync.int(1, 65535),
		Accept = Lync.bool(),
	})),
	-- §16.2 c -> s
	PartyLeave = Lync.packet(Lync.empty()),
	-- §16.2 c -> s. Leader only, Forming only
	PartyKick = Lync.packet(Lync.struct({
		UserId = Lync.f64(),
	})),
	-- §16.2 c -> s. Members other than the leader; Forming only
	PartyReady = Lync.packet(Lync.struct({
		Ready = Lync.bool(),
	})),
	-- §16.2 c -> s. Leader only, every member Ready: reserve a server and teleport the squad (Role "Game")
	PartyStart = Lync.packet(Lync.empty()),
	-- §16.6 c -> s. Leader only, not Starting: platform squad settings (MaxPlayers clamped to the member count)
	PartyConfigure = Lync.packet(Lync.struct({
		Access = Lync.enum(PartyRules.Access), -- "Setup" is only kept (stage 1: count change while still private)
		MaxPlayers = Lync.int(1, 4),
	})),
	-- §16.7 c -> s. Lobby Play button outside a squad: Solo = a squad of one started at once (countdown + teleport);
	-- Squad = an open invite squad (Platform 0) to set up and invite into
	PartyQuickPlay = Lync.packet(Lync.struct({
		Mode = Lync.enum({ "Solo", "Squad" }),
	})),
	-- §16.8 c -> s. Leader only, State "Starting" and still before StartAt - Rules.CancelCutoff: aborts the countdown
	-- (idle state again; a solo quick play squad is disbanded). Idempotent: later or repeated = notice / no-op
	PartyCancel = Lync.packet(Lync.empty()),
	-- §16.3 s -> player. Key = PartyRules.NoticeKeys; UserId = the other player when the notice names one
	PartyNotice = Lync.packet(Lync.struct({
		Key = Lync.enum(PartyRules.NoticeKeys),
		UserId = Lync.optional(Lync.f64()),
	})),
	-- §16.4 c -> s, game role only. Responder: PartyRunService. Go back to the lobby now (end-of-run screen button;
	-- also accepted mid-run: leaving is always allowed, DEC-067)
	LobbyReturn = Lync.packet(Lync.empty()),

	-- Rejoin a run in progress (owner request 2026-10-17; DEC-063; architecture.md §5.4; network.md §13.8; TASK-360,
	-- Provisional). Responder: SessionService (lobby roles). Enums from SessionRules
	-- s -> player (lobby): Mode Rejoin / Resume = show the top-right offer; None = hide it (Reason says why, None =
	-- silently). Resume (DEC-080, Q-291): nobody is in the run, it can be resumed from the start of its shift for Left s
	Reconnect = Lync.packet(Lync.struct({
		Mode = Lync.enum(SessionRules.Modes),
		Day = Lync.int(0, 10000), -- 0 = not known yet (run still starting)
		IsNight = Lync.bool(),
		Reason = Lync.enum(SessionRules.Reasons),
		Left = Lync.int(0, 3600), -- Resume: seconds of the resume window still open; 0 otherwise
	})),
	-- c -> s (lobby). Accept = teleport back to that run; false = dismiss (the offer is forgotten)
	ReconnectReply = Lync.packet(Lync.struct({ Accept = Lync.bool() })),

	-- Analytics (RoMetrics, owner request 2026-10-16; Content.Metrics). c -> s, responder MetricsService (OnInit); the
	-- server rate-limits (Content.Metrics.UiRate) and never trusts them for anything but the analytics event.
	-- A client-only UI moment. Key = what it was about (a Content.Shop key for product_prompt), "" = none; the server
	-- keeps it only when it is a known Content.Shop key
	MetricUi = Lync.packet(Lync.struct({
		Event = Lync.enum(Content.Metrics.UiEvents),
		Key = Lync.optional(Lync.enum(Content.Shop.Keys)),
		-- offer_* events (TASK-361): which contextual offer (Content.Shop.Offers key)
		Offer = Lync.optional(Lync.enum(Content.Shop.Offers.Keys)),
	})),
	-- The local tutorial reached a step (index into Content.Metrics.TutorialSteps); logged once per step per player
	MetricTutorial = Lync.packet(Lync.struct({
		Step = Lync.int(1, 64),
	})),

	-- Players online in the whole game (TASK-312; owner request 2026-10-15, Provisional). Set, record 1,
	-- lobby roles only. Writer: PresenceService (MemoryStore sum of every server, at most every 30 s; never under the
	-- local count). Reader: LobbyController (LobbyHud online pill). One record, 24 bits: no drop.section floor
	Online = Lync.replicate(Lync.struct({
		Count = Lync.int(0, 16777215),
	})),

	-- Security cameras (FEAT-040, TASK-285; owner request 2026-10-14). s -> owner (fireClient, private): the watch_cameras
	-- prompt went through, open the camera view (the body is frozen meanwhile). Writer: SecurityService
	SecurityOpen = Lync.packet(Lync.empty()),
	-- c -> s: the client left the camera view (any way out); the server releases the freeze. Idempotent
	SecurityLeave = Lync.packet(Lync.empty()),

	-- Anomaly Tablet (TASK-335, TASK-345; owner request 2026-10-15, Provisional). s -> owner (fireClient, private). Writer:
	-- JournalService, once the profile is loaded and the client is ready, and again on every new page or claim. Pages =
	-- the unlocked pages (Content.Journal keys, from profile.Journal); Claimed = the pages whose gems were paid
	-- (profile.JournalClaimed, owner request 2026-10-17); New = the page that just unlocked (toast + glow), nil on the
	-- first send; Gained = the page just claimed (the client plays the gem collect). Responder: JournalController (OnInit)
	Journal = Lync.packet(Lync.struct({
		Pages = Lync.bitfield(Content.Journal.Keys),
		Claimed = Lync.bitfield(Content.Journal.Keys),
		New = Lync.optional(Lync.enum(Content.Journal.Keys)),
		Gained = Lync.optional(Lync.enum(Content.Journal.Keys)),
	})),
	-- c -> s: the player opened this page on the tablet; the server pays Content.Journal.Rules.Reward gems once per page
	-- (unlocked and not claimed yet, else ignored). Idempotent. Responder: JournalService (OnInit)
	JournalClaim = Lync.packet(Lync.enum(Content.Journal.Keys)),
	-- s -> owner: the read_journal prompt went through, open the tablet. Writer: JournalService
	JournalOpen = Lync.packet(Lync.empty()),
})
