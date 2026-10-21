--!strict
-- Anomaly Tablet (TASK-335, TASK-345 book -> tablet; owner request 2026-10-15, Provisional). One page per anomaly of the V2 agenda (every
-- Content.Anomalies row with a Family, DEC-254): the page unlocks for a player the first time an occurrence of that
-- anomaly ends while they took part (JournalService, saved in profile.Journal, kept across runs). Keys are the
-- Anomalies keys, so the Journal packet's bitfield and the AnomalyService events share one name.
-- Texts: English, short, for kids. Signs = what shows up; Not = what does NOT show up (tells it apart from the
-- others); Fight = what to do. They repeat Walt's debut calls (Content.BossCalls), so nothing here is a secret the
-- client did not already hear (T10 keeps only windows, deadlines and criticality on the server).
-- Tablet order = debut night (Content.Anomalies Night, so a change of the night table reorders it), ties in the
-- order written here. The picture of each page lives in the
-- AnomalyTablet component (Images.luau, uploaded art from tools/icons/journal_art.py).
local Table = require(script.Parent.Table)
local Anomalies = require(script.Parent.Anomalies)

export type Tag = "Refuse" | "Hide" | "Lights" | "Careful"

export type Page = {
	Key: string, -- Content.Anomalies key
	Title: string,
	Tag: Tag, -- the chip on the page (family A refuse, B hide, C lights, D careful)
	Signs: { string },
	Not: { string },
	Fight: { string },
}

export type Rules = {
	Action: string, -- Content.Actions key of the tablet prompt
	Model: string, -- name of the tablet Model (tools/assetplace/anomaly_tablet.luau)
	Anchor: string, -- name of the prompt Attachment inside the tablet
	-- Gems paid once per page, the first time the player opens it on the tablet (owner request 2026-10-17,
	-- Provisional). JournalService pays it and keeps the flag in profile.JournalClaimed.
	Reward: number,
	ToastText: string,
	LockedTitle: string,
	LockedText: string,
}

local function page(key: string, title: string, tag: Tag, signs: { string }, notSigns: { string }, fight: { string }): Page
	return { Key = key, Title = title, Tag = tag, Signs = signs, Not = notSigns, Fight = fight }
end

const written: { Page } = {
	page("anm_001_blank_folks", "The Blank Folks", "Refuse", {
		"A customer with no face.",
		"No eyes, no nose, no mouth.",
	}, { "Real customers always have a face." }, { "Refuse them: close the window.", "Never take their order." }),

	-- TASK-591 (owner 2026-10-19, Provisional Q-399): starving, not a monster
	page("anm_011_shaker", "The Shaker", "Careful", {
		"Shakes fast, all over.",
		"Even while standing still in line.",
	}, { "He is just starving." }, { "Serve him a PLAIN hot dog.", "Nothing on it. Never shut him out." }),

	page("anm_012_turned_neck", "The Turned Neck", "Refuse", {
		"The head is turned all the way back.",
		"Sometimes it spins, slowly.",
	}, { "The body still faces you." }, { "Refuse it: close the window.", "It leaves with a CRACK." }),

	page("anm_020_blackout", "The Blackout", "Lights", {
		"Pop! Everything goes dark.",
		"A shadow waits in the corner.",
	}, { "No bell, no fog. Just dark." }, { "Run to the breaker out back.", "Hold it until the lights are on. Be fast!" }),

	-- ANM-021 (owner 2026-10-18)
	page("anm_021_red_fog", "The Red Fog", "Careful", {
		"A red fog rolls down the street.",
		"A bell rings. Everything turns red.",
	}, { "Grey fog is just weather." }, { "Close the window before it reaches the glass.", "Keep it shut until it goes." }),

	page("anm_013_white_eyes", "The White Eyes", "Refuse", {
		"Eyes all white.",
		"A smile way too big.",
	}, { "No pupils at all." }, { "Refuse them: close the window." }),

	page("anm_004_copies", "The Copies", "Refuse", {
		"Two customers that look the same.",
		"The copy is mirrored: backwards shirt text.",
	}, { "The real one is not mirrored." }, { "Close the window on the mirrored one.", "Serve the real one." }),

	page("anm_005_raincoat_lady", "The Raincoat Lady", "Careful", {
		"Yellow raincoat, eyes closed.",
		"She drips water on a dry night.",
	}, { "She is NOT a monster." }, { "Serve her! Never refuse her.", "Don't make her wait." }),

	page("anm_014_big_head", "The Big Head", "Refuse", {
		"The head is way too big.",
		"Or way too tiny.",
	}, { "The body looks normal." }, { "Refuse them: close the window." }),

	page("anm_015_floater", "The Floater", "Refuse", {
		"Floats a little above the ground.",
	}, { "No footsteps. No shadow." }, { "Refuse them: close the window." }),

	page("anm_017_crawler", "The Crawler", "Hide", {
		"Fast scratching under the trailer.",
		"A low rumble.",
	}, { "The lights do NOT flicker." }, { "Out the back and hide.", "Quick! It is fast." }),

	page("anm_006_stalker", "The Stalker", "Careful", {
		"A tall figure across the street.",
		"It only moves when you look at it.",
	}, { "It never moves while nobody watches." }, { "Look away. Do not stare.", "Close the window if it gets close." }),

	page("anm_016_starer", "The Starer", "Refuse", {
		"Never blinks. Never moves.",
		"The head follows you everywhere.",
	}, { "Looking at it on the cameras is safe." }, { "Refuse them: close the window.", "When it reaches you, it makes you look." }),

	-- TASK-591 (Provisional Q-399)
	page("anm_022_head_banger", "The Head Banger", "Careful", {
		"Stands at the window and will not leave.",
		"Shut the window and it beats its head on it.",
	}, { "Closing the window does nothing." }, { "Turn OFF the shop lights.", "Never take its order." }),

	page("anm_008_long_car", "The Long Car", "Careful", {
		"A long car stops by the trailer.",
		"Its headlights get brighter.",
	}, { "It never honks for food." }, { "Shut the window before the beam.", "Stay inside until it drives away." }),

	page("anm_019_roof_walker", "The Roof Walker", "Careful", {
		"Slow, heavy steps on the roof.",
		"Dust falls. The lamps swing.",
	}, { "It is never Walt." }, { "Keep your head down.", "Don't look up until it's gone." }),

	page("anm_009_knock", "The Knock", "Careful", {
		"Knock knock knock at the back door.",
		"It says it is Walt.",
	}, { "Walt never knocks." }, { "Don't open the back door.", "Just wait." }),

	page("anm_010_hush", "The Hush", "Lights", {
		"Fog rolls in.",
		"Street lamps go out one by one.",
	}, { "No bell this time." }, { "Run inside the Mart.", "Stay until the lamps come back." }),
}

local function nightOf(key: string): number
	const row = Anomalies.ByKey[key]
	return if row then row.Night else math.huge
end

const order: { [string]: number } = {}
for index, row in written do
	order[row.Key] = index
end
const sorted = table.clone(written)
table.sort(sorted, function(a: Page, b: Page): boolean
	const na, nb = nightOf(a.Key), nightOf(b.Key)
	if na ~= nb then
		return na < nb
	end
	return order[a.Key] < order[b.Key]
end)
const pages = Table.new(sorted)

const rules: Rules = {
	Action = "read_journal",
	Model = "TRL-TABLET",
	Anchor = "Prompt_Tablet",
	Reward = 100,
	ToastText = "New entry on the Anomaly Tablet!",
	LockedTitle = "???",
	LockedText = "Meet this one to unlock the entry.",
}

-- Every V2 agenda anomaly has a page, and every page is a real anomaly (tablet and agenda never drift)
for _, row in Anomalies.List do
	if row.Family ~= nil and pages.ByKey[row.Key] == nil then
		error(`[Content.Journal] {row.Ref} ({row.Key}) is in the V2 agenda but has no page`)
	end
end
for _, row in pages.List do
	if Anomalies.ByKey[row.Key] == nil then
		error(`[Content.Journal] page {row.Key} is not a Content.Anomalies key`)
	end
end

return Table.with(pages, {
	Rules = Table.record(rules),
})
