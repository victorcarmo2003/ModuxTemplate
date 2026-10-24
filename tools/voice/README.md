# Pre-generated voice lines (Kokoro-82M, offline)

Decision of the owner (2026-10-12): free commercial offline TTS **Kokoro-82M** (Apache 2.0) instead of Fish Audio (not
enough credits). Roblox `AudioTextToSpeech` stays only as the fallback (it allows 1 + 6 x players requests per minute and
filters fixed text). Credits and licence: `docs/art/credits.md`, section Voz.

## Pipeline

| Step | Command (from `tools/voice`) | Output |
|---|---|---|
| Collect the lines | `python collect_lines.py` | `lines.json` (175 active lines: walt 171, crew 4; lines removed from the game stay in `assets.json`). Key = `v_<sha1(speaker NUL spoken)[:10]>`, spoken = `Speech.Spoken(text)` |
| Generate | `.venv/Scripts/python generate.py all [--new] [--only KEY]` (`--new` = only keys without an ogg yet) | `Assets/audio/voice/<speaker>/<key>.ogg` (ogg vorbis q4, mono 24 kHz), `assets.json` (length, gen_text) |
| Record (own voice, optional) | `.venv/Scripts/python record.py [--source Steps] [--only KEY,KEY] [--all] [--fx full\|phone\|none]` (needs `sounddevice` in the venv) | replaces `Assets/audio/voice/<speaker>/<key>.ogg`, raw take in `recordings/` (git-ignored), `assets.json` recorded=true and assetId cleared (upload sends it again) |
| Record in a window | `.venv/Scripts/python record_gui.py` | same as `record.py`; **E** rewrites a line as it will be said (split / remove): `edits.json` (old -> new + sources), takes saved under the key of the new text. Claude applies `edits.json` to the Luau sources, then `collect_lines.py` |
| Upload | `python upload.py [--only KEY]` (needs env `ROBLOX_API_KEY`, never printed) | `assets.json` (assetId, status ok / rejected / error); resumable; ~1 req/s, backoff on 429 |
| Catalog | `python build_content.py` | `src/Shared/Content/VoiceLines.luau` (`Lines[key] = { Id, Length, Speaker }`, `Index[speaker NUL spoken] = key`) |
| Compare voices | `.venv/Scripts/python generate.py samples` then `.venv/Scripts/python evaluate.py "samples/*.wav"` | `samples/` (git-ignored, never uploaded) |

Setup (Windows): `winget install eSpeak-NG.eSpeak-NG`, `py -3.12 -m venv .venv` (inside `tools/voice`, git-ignored),
`.venv/Scripts/pip install "kokoro>=0.9.4" soundfile numpy faster-whisper`; ffmpeg on the PATH (`winget install Gyan.FFmpeg`).
The first run downloads the model (~330 MB) and a spaCy model into the venv.

## Everything is in `config.json`

- `voices.<speaker>`: `voice` (Kokoro id), `lang` (`a` US, `b` UK), `speed`, `post` (profile in `post`).
- `post.<profile>`: `pitch_semitones` (asetrate + atempo, duration kept), `highpass`/`lowpass`, `compress`,
  `saturate` (soft tanh clip = hoarseness), `reverb`.
- `phone`: band-pass 300-3400 Hz + gain. Applied to Walt's phone lines: BossCalls, tutorial steps, and the intro call
  (Cutscenes.luau, scene `[intro]`, tagged by `collect_lines.py`); his in-person cutscene lines stay clean.
- `pauses`: seconds after `.` / `? !` / `...` (same as `Speech.Pieces`; the sentences are synthesized one by one and
  joined with that silence). `gen_text_overrides[key]`: text Kokoro reads when the spoken text loses meaning
  (e.g. `Since '.` -> `Since nineteen seventy-nine.`). `gen_text()` in `generate.py` also fixes `Mr.`, `OPEN`, `Heh`, dashes.

To change a voice: edit `voices.walt.voice` (or speed / post), run `generate.py all`, `upload.py` (new audio = new asset:
clear the `assetId`/`status` of the keys in `assets.json` first), `build_content.py`. To redo one line: `--only KEY`.

## Voice choice (automatic, objective)

Walt = warm hoarse old man. Candidates `bm_george`, `am_michael`, `am_fenrir` on 3 Walt lines, same post-processing
(pitch -1.5 st, band 120-6500 Hz, compression, soft saturation, short echo), measured by `evaluate.py`: ASR round trip
(faster-whisper base.en) word error, seconds per word, longest internal silence, peak.

| Voice | mean WER (clean+phone, 3 lines) | s/word | longest gap |
|---|---|---|---|
| am_fenrir | 0.08 (only the number "1979" differs) | 0.62-0.80 | 1.0-1.3 s |
| bm_george | 0.12 | 0.77-0.95 | 1.1-1.3 s |
| am_michael | 0.15 ("Rookie" misheard) | 0.74-0.95 | 1.2-1.5 s |

`am_fenrir` wins on clarity and has the tightest rhythm, with `speed 0.9` for an older man's pace. Crew = `af_heart`
(WER 0, clear, neutral, short tone); `am_puck` was equal in clarity. Nobody listened yet: if the owner prefers another
timbre, change `voices.walt.voice` (candidates above) and regenerate.

## In the game

`Speech.luau` (src/Cutscene/client/CutsceneController): a line found in `Content.VoiceLines.Index` plays as a `Sound`
(volume = Master x Voice x speaker volume, through the LoadQueue, urgent) and never creates an `AudioTextToSpeech`;
a line not in the catalog (or rejected) uses text-to-speech as before. `SoundService:SetAttribute("SpeechLog", true)`
prints `voiced from asset` / `TTS` per line.

Nothing under `samples/` or `.venv/` is committed. Rejected or failed uploads are listed in `assets.json`
(`status`, `reason`) and are simply absent from `VoiceLines.luau`.
