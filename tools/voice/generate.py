"""Generate every line of lines.json with Kokoro-82M (offline, Apache 2.0) + ffmpeg post-processing.

  .venv/Scripts/python generate.py samples            # Walt candidates -> tools/voice/samples/ (git-ignored)
  .venv/Scripts/python generate.py all [--only KEY]   # Assets/audio/voice/<speaker>/<key>.ogg + assets.json lengths

All knobs live in config.json (voice, speed, post-processing, pauses). The key stays the one of the SPOKEN text;
gen_text (what Kokoro reads) comes from gen_text() / config gen_text_overrides.
"""
import json, os, re, subprocess, sys, shutil
import numpy as np, soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CFG = json.load(open(os.path.join(HERE, "config.json"), encoding="utf-8"))
LINES = json.load(open(os.path.join(HERE, "lines.json"), encoding="utf-8"))
OUT = os.path.join(ROOT, "Assets", "audio", "voice")
SR = CFG["sample_rate"]


def ffmpeg_exe():
    p = shutil.which("ffmpeg")
    if p:
        return p
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def gen_text(key, text):
    if key in CFG["gen_text_overrides"]:
        return CFG["gen_text_overrides"][key]
    t = text.replace("…", "...").replace("—", ",").replace("–", ",")
    t = re.sub(r"\bMr\.", "Mister", t)
    t = re.sub(r"\bOPEN\b", "open", t)
    t = re.sub(r"\bFOR SALE\b", "for sale", t)
    t = re.sub(r"\bHeh\b", "Heh heh", t)
    t = re.sub(r"(?<![A-Za-z])'em\b", "them", t)
    t = t.replace('"', "")
    t = re.sub(r"\s*\.\.\.\s*", "... ", t)
    t = re.sub(r"\s+", " ", t).strip()
    t = re.sub(r"\s*,\s*$", ".", t)
    return t


def pieces(text):
    """Sentence pieces + pause after each (mirrors Speech.Pieces)."""
    out, pos = [], 0
    while pos < len(text):
        m = re.search(r"[.?!]+", text[pos:])
        if not m:
            body, punct, pos = text[pos:], "", len(text)
        else:
            body, punct = text[pos:pos + m.start()], m.group(0)
            pos += m.end()
        body = body.strip(' "')
        if re.search(r"\w", body):
            pz = CFG["pauses"]["dots"] if "..." in punct else CFG["pauses"]["ask"] if re.search(r"[?!]", punct) else CFG["pauses"]["stop"]
            out.append([body + punct, pz])
        elif out and "..." in punct:
            out[-1][1] += 0.3
    if out:
        out[-1][1] = 0
    return out


_pipes = {}


def pipe(lang):
    if lang not in _pipes:
        from kokoro import KPipeline
        _pipes[lang] = KPipeline(lang_code=lang, repo_id=CFG["model"])
    return _pipes[lang]


def synth(text, voice, lang, speed):
    chunks = []
    for part, pz in pieces(text):
        for _, _, a in pipe(lang)(part, voice=voice, speed=speed):
            chunks.append(np.asarray(a, dtype=np.float32))
        chunks.append(np.zeros(int(SR * pz), dtype=np.float32))
    return np.concatenate(chunks) if chunks else np.zeros(SR // 4, dtype=np.float32)


def filters(role, phone):
    p = CFG["post"][role]
    f = []
    if p.get("pitch_semitones"):
        r = 2 ** (p["pitch_semitones"] / 12)
        f += [f"asetrate={SR * r:.2f}", f"aresample={SR}", f"atempo={1 / r:.5f}"]
    f += [f"highpass=f={p['highpass']}", f"lowpass=f={p['lowpass']}"]
    if p.get("compress"):
        f.append(p["compress"])
    if p.get("saturate", 1) > 1:
        g = p["saturate"]
        f += [f"volume={g}", "asoftclip=type=tanh", f"volume={1 / g ** 0.5:.3f}"]
    if p.get("reverb"):
        f.append(p["reverb"])
    if phone:
        ph = CFG["phone"]
        f += [f"highpass=f={ph['highpass']}", f"lowpass=f={ph['lowpass']}", f"volume={ph['gain_db']}dB"]
    f += ["alimiter=limit=0.9", "loudnorm=I=-18:TP=-2:LRA=7", f"aresample={CFG['out_rate']}"]
    return ",".join(f)


def line_noise():
    """Phone line under the voice (owner 2026-10-22): pink hiss + sparse velvet crackle, band-limited like the phone,
    mixed after loudnorm so its level stays fixed. Empty when config phone.noise is off."""
    ph = CFG["phone"]
    n = ph.get("noise")
    if not n:
        return ""
    rate = CFG["out_rate"]
    band = f"highpass=f={ph['highpass']},lowpass=f={ph['lowpass']}"
    return (f"anoisesrc=color=pink:amplitude={n['hiss']}:sample_rate={rate},{band}[hiss];"
            f"anoisesrc=color=velvet:density={n['crackle_density']}:amplitude={n['crackle']}:sample_rate={rate},{band}[crackle];")


def encode(wav_in, out_path, chain, phone):
    """ffmpeg: wav_in through `chain` (+ the line noise on phone lines) into out_path (.ogg = vorbis)."""
    noise = line_noise() if phone else ""
    cmd = [ffmpeg_exe(), "-y", "-loglevel", "error", "-i", wav_in]
    if noise:
        cmd += ["-filter_complex", f"[0:a]{chain}[voice];{noise}[voice][hiss][crackle]amix=inputs=3:duration=first:normalize=0"]
    else:
        cmd += ["-af", chain]
    cmd += ["-ac", "1", "-ar", str(CFG["out_rate"])]
    if os.path.splitext(out_path)[1] == ".ogg":
        cmd += ["-c:a", "libvorbis", "-q:a", str(CFG["ogg_quality"])]
    subprocess.run(cmd + [out_path], check=True)


def post(wav_in, out_path, role, phone):
    encode(wav_in, out_path, filters(role, phone), phone)


def is_phone(entry):
    if entry["speaker"] == "radio":
        return True  # the stranger on the radio (owner 2026-10-18)
    if entry["speaker"] != "walt":
        return False
    for s in entry["sources"]:
        f, _, rest = s.partition(":")
        # the intro call is Walt on the phone; the finale lines are in person (tagged [finale] by collect_lines.py)
        if f != "Cutscenes.luau" or "[intro]" in rest:
            return True
    return False


def duration(path):
    i = sf.info(path)
    return i.frames / i.samplerate


def samples():
    d = os.path.join(HERE, "samples")
    os.makedirs(d, exist_ok=True)
    keys = ["v_79975d4a51", "v_ddb13fb986", "v_0520e8b100"]
    tmp = os.path.join(d, "_t.wav")
    for voice in ["bm_george", "am_michael", "am_fenrir"]:
        for k in keys:
            a = synth(gen_text(k, LINES[k]["text"]), voice, "b" if voice.startswith("b") else "a", CFG["voices"]["walt"]["speed"])
            sf.write(tmp, a, SR)
            for ph in (False, True):
                post(tmp, os.path.join(d, f"{voice}_{k}_{'phone' if ph else 'clean'}.wav"), "walt", ph)
    for voice in ["af_heart", "am_puck"]:
        k = "v_43c6981888"
        a = synth(gen_text(k, LINES[k]["text"]), voice, "a", 1.0)
        sf.write(tmp, a, SR)
        post(tmp, os.path.join(d, f"crew_{voice}.wav"), "crew", False)
    os.remove(tmp)


def allv(only=None, new_only=False):
    meta_path = os.path.join(HERE, "assets.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    tmp = os.path.join(HERE, "_t.wav")
    for n, (k, e) in enumerate(LINES.items()):
        if only and k != only:
            continue
        if new_only and k in meta and meta[k].get("length") and os.path.exists(os.path.join(OUT, e["speaker"], k + ".ogg")):
            continue
        sp = e["speaker"]
        v = CFG["voices"][sp]
        out = os.path.join(OUT, sp, k + ".ogg")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        a = synth(gen_text(k, e["text"]), v["voice"], v["lang"], v["speed"])
        sf.write(tmp, a, SR)
        post(tmp, out, v["post"], is_phone(e))
        m = meta.setdefault(k, {})
        m.update(speaker=sp, length=round(duration(out), 3), gen_text=gen_text(k, e["text"]))
        print(n + 1, len(LINES), k, m["length"], flush=True)
        json.dump(meta, open(meta_path, "w"), indent=1)
    if os.path.exists(tmp):
        os.remove(tmp)


if __name__ == "__main__":
    if sys.argv[1] == "samples":
        samples()
    else:
        allv(sys.argv[3] if len(sys.argv) > 3 and sys.argv[2] == "--only" else None, "--new" in sys.argv)
