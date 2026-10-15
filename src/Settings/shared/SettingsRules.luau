--!strict
-- Player settings (TASK-279; owner request 2026-10-14, Provisional): the shape, the defaults and the one sanitizer used by
-- the profile (ProfileService Template), the server (SettingsService, on every save) and the client (SettingsController).
-- Volumes are whole percents 0..100 (what the panel shows, what travels, what is saved). Pure: no Vide, no Charm.
--   Music / Sfx / Voice   SoundGroup volume of that group (Sfx also drives Ambient and Ui)
--   Scare                 jumpscare sounds (AudioController opts.Scare, own SoundGroup), still capped by
--                         SoundRules.ScareMaxVolume (DEC-173)
--   PromptMode            "Single" = one ProximityPrompt at a time on mouse/keyboard, "Multi" = up to 3 (TASK-278 reads
--                         the LocalPlayer attribute PromptMode)
--   PrepAssist            step-by-step hint line and the drag paw of the prep mode (PrepController / World.Coach)
--   ReducedMotion         game-side switch for Motion.Reduced (on top of the Roblox setting, never instead of it)
--   Vibration             controller / phone vibration (Input/client/Haptics, TASK-268); off = nothing ever vibrates

export type PromptMode = "Single" | "Multi"

export type Settings = {
	Music: number,
	Sfx: number,
	Voice: number,
	Scare: number,
	PromptMode: PromptMode,
	PrepAssist: boolean,
	ReducedMotion: boolean,
	Vibration: boolean,
}

export type Key = "Music" | "Sfx" | "Voice" | "Scare" | "PromptMode" | "PrepAssist" | "ReducedMotion" | "Vibration"

const DEFAULTS: Settings = {
	Music = 100,
	Sfx = 100,
	Voice = 100,
	Scare = 100,
	PromptMode = "Single",
	PrepAssist = true,
	ReducedMotion = false,
	Vibration = true,
}
-- Read only (frozen at run time); callers that need a record of their own use table.clone(Defaults).
const Defaults: Settings = table.freeze(DEFAULTS) :: any

const PROMPT_MODES = table.freeze({ "Single", "Multi" })

local function percent(value: any, default: number): number
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return math.clamp(math.floor(value + 0.5), 0, 100)
end

local function flag(value: any, default: boolean): boolean
	return if type(value) == "boolean" then value else default
end

-- Any table (saved data, a packet, a story) -> a full, valid Settings. Unknown or broken fields fall back to Defaults.
local function sanitize(raw: any): Settings
	const data: { [string]: any } = if type(raw) == "table" then raw else {}
	const mode = data.PromptMode
	const value: Settings = {
		Music = percent(data.Music, Defaults.Music),
		Sfx = percent(data.Sfx, Defaults.Sfx),
		Voice = percent(data.Voice, Defaults.Voice),
		Scare = percent(data.Scare, Defaults.Scare),
		PromptMode = if mode == "Single" or mode == "Multi" then mode else Defaults.PromptMode,
		PrepAssist = flag(data.PrepAssist, Defaults.PrepAssist),
		ReducedMotion = flag(data.ReducedMotion, Defaults.ReducedMotion),
		Vibration = flag(data.Vibration, Defaults.Vibration),
	}
	return value
end

local function same(a: Settings, b: Settings): boolean
	return a.Music == b.Music
		and a.Sfx == b.Sfx
		and a.Voice == b.Voice
		and a.Scare == b.Scare
		and a.PromptMode == b.PromptMode
		and a.PrepAssist == b.PrepAssist
		and a.ReducedMotion == b.ReducedMotion
		and a.Vibration == b.Vibration
end

return table.freeze({
	Defaults = Defaults,
	PromptModes = PROMPT_MODES,
	Sanitize = sanitize,
	Same = same,
})
