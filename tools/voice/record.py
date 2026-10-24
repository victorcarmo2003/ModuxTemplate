"""Record the voice lines with your own microphone, one after the other (owner 2026-10-22: "vou gravar as falas").

  .venv/Scripts/python record.py                 # the lines without an uploaded voice (no assetId), not recorded yet
  .venv/Scripts/python record.py --source Steps  # only lines whose source contains "Steps" (tutorial)
  .venv/Scripts/python record.py --only v_1dcefd5818,v_adacd686b6
  .venv/Scripts/python record.py --all [--redo]  # every line of lines.json (--redo: also the ones already recorded)
  .venv/Scripts/python record.py --list          # print the queue and exit
  options: --fx full|phone|none (default full), --device N (sounddevice input index), --devices (list them)

Per line (single keys, no Enter):
  SPACE  start recording / stop recording       L  listen to the current voice of the line (Kokoro or an old take)
  S      skip      B  back one line      Q  quit
  after a take (it plays back with the effect; nothing moves on until you keep or skip):
    P with effect, O without effect (the raw take, trimmed), F next effect for this take (full -> phone -> none),
    SPACE / ENTER keep and go on, R redo, S skip

A kept take: raw wav in tools/voice/recordings/<key>.wav (git-ignored), processed ogg in
Assets/audio/voice/<speaker>/<key>.ogg (same place and format as generate.py), assets.json gets the length and
recorded=true, and its assetId / status are cleared so upload.py sends the new audio. Then, as usual:
  python upload.py   ->   python build_content.py

--fx full  = the same chain as the Kokoro lines (config.json post.<role> + the phone band on phone lines)
--fx phone = only the phone band on phone lines + loudness (your voice untouched otherwise)
--fx none  = loudness only
"""
import argparse, json, msvcrt, os, re, sys, time
import numpy as np, soundfile as sf, sounddevice as sd
import generate as G

HERE = G.HERE
RAW = os.path.join(HERE, "recordings")
META_PATH = os.path.join(HERE, "assets.json")
SR = 48000  # capture rate; post() resamples to config out_rate
EDGE = 0.15  # s cut at the end (the key press that stops)
# s cut at the start: was EDGE too, and a take started right on the key lost its first word (owner takes 2026-10-23:
# "Rockie, just take the sauce." came out as "just take the sauce")
START_EDGE = 0.03
PAD = 0.08  # s of silence kept around the voice after trimming
FX_MODES = ["full", "phone", "none"]


def key():
    ch = msvcrt.getwch()
    if ch in ("\x00", "\xe0"):  # arrows / function keys: ignore
        msvcrt.getwch()
        return ""
    return ch.lower()


def meta_load():
    return json.load(open(META_PATH, encoding="utf-8")) if os.path.exists(META_PATH) else {}


def meta_save(meta):
    json.dump(meta, open(META_PATH, "w"), indent=1)


def order_of(entry):
    # sources like "Steps.luau:112 (Done)": file, then line number, so a script is read in its own order
    src = entry["sources"][0] if entry["sources"] else ""
    m = re.match(r"([^:]+):(\d+)", src)
    return (m.group(1), int(m.group(2))) if m else (src, 0)


def queue(args, meta):
    keys = []
    only = set(args.only.split(",")) if args.only else None
    for k, e in G.LINES.items():
        m = meta.get(k, {})
        if only is not None:
            if k in only:
                keys.append(k)
            continue
        if args.source and not any(args.source in s for s in e["sources"]):
            continue
        if m.get("recorded") and not args.redo:
            continue
        if not args.all and m.get("assetId"):
            continue
        keys.append(k)
    keys.sort(key=lambda k: order_of(G.LINES[k]))
    return keys


def fx_filters(entry, mode):
    role = G.CFG["voices"][entry["speaker"]]["post"]
    phone = G.is_phone(entry)
    if mode == "full":
        return G.filters(role, phone)
    f = []
    if mode == "phone" and phone:
        ph = G.CFG["phone"]
        f += [f"highpass=f={ph['highpass']}", f"lowpass=f={ph['lowpass']}", f"volume={ph['gain_db']}dB"]
    f += ["alimiter=limit=0.9", "loudnorm=I=-18:TP=-2:LRA=7", f"aresample={G.CFG['out_rate']}"]
    return ",".join(f)


def process(wav_in, out_path, entry, mode):
    # the chain's pitch shift (asetrate) assumes config sample_rate: bring the capture down to it first
    chain = f"aresample={G.SR}," + fx_filters(entry, mode)
    # the line noise (config phone.noise) on phone lines, unless --fx none
    G.encode(wav_in, out_path, chain, mode != "none" and G.is_phone(entry))


def trim(audio):
    edge = int(EDGE * SR)
    a = audio[int(START_EDGE * SR):len(audio) - edge] if len(audio) > 3 * edge else audio
    win = int(0.02 * SR)
    n = len(a) // win
    if n == 0:
        return a
    rms = np.sqrt(np.mean(a[:n * win].reshape(n, win) ** 2, axis=1))
    loud = np.where(rms > max(rms.max() * 0.06, 0.004))[0]
    if len(loud) == 0:
        return a
    pad = int(PAD * SR)
    return a[max(loud[0] * win - pad, 0):min((loud[-1] + 1) * win + pad, len(a))]


def play_file(path):
    if not os.path.exists(path):
        print("   (nothing to play)")
        return
    data, rate = sf.read(path, dtype="float32")
    sd.play(data, rate)
    sd.wait()


def record(device):
    frames = []

    def cb(indata, _n, _t, status):
        frames.append(indata[:, 0].copy())

    with sd.InputStream(samplerate=SR, channels=1, dtype="float32", device=device, callback=cb):
        while True:
            time.sleep(0.05)
            level = float(np.sqrt(np.mean(frames[-1] ** 2))) if frames else 0.0
            bar = "#" * min(int(level * 300), 40)
            secs = sum(len(f) for f in frames) / SR
            print(f"\r   REC {secs:5.1f}s |{bar:<40}| SPACE stop", end="", flush=True)
            if msvcrt.kbhit() and key() in (" ", "\r"):
                break
    print()
    return np.concatenate(frames) if frames else np.zeros(1, dtype=np.float32)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--all", action="store_true")
    p.add_argument("--redo", action="store_true")
    p.add_argument("--only")
    p.add_argument("--source")
    p.add_argument("--fx", choices=["full", "phone", "none"], default="full")
    p.add_argument("--device", type=int)
    p.add_argument("--devices", action="store_true")
    p.add_argument("--list", action="store_true")
    args = p.parse_args()

    if args.devices:
        print(sd.query_devices())
        return
    meta = meta_load()
    keys = queue(args, meta)
    if args.list:
        for n, k in enumerate(keys, 1):
            e = G.LINES[k]
            print(f"{n:3} {k} [{'phone' if G.is_phone(e) else 'clean'}] {e['text']}   <- {', '.join(e['sources'])}")
        print(f"{len(keys)} line(s)")
        return
    if not keys:
        print("Nothing to record (try --all, --redo or --only).")
        return

    os.makedirs(RAW, exist_ok=True)
    mic = sd.query_devices(args.device, kind="input")["name"]
    print(f"Mic: {mic}   fx: {args.fx}   {len(keys)} line(s). SPACE record, L listen, S skip, B back, Q quit.\n")
    i, kept = 0, 0
    while 0 <= i < len(keys):
        k = keys[i]
        e = G.LINES[k]
        out = os.path.join(G.OUT, e["speaker"], k + ".ogg")
        raw = os.path.join(RAW, k + ".wav")
        print(f"[{i + 1}/{len(keys)}] {e['speaker']} {'(phone)' if G.is_phone(e) else '(in person)'}  {k}")
        print(f"   {', '.join(e['sources'])}")
        print(f"\n      \"{e['text']}\"\n")
        ch = key()
        if ch == "q":
            break
        if ch == "s":
            i += 1
            continue
        if ch == "b":
            i = max(i - 1, 0)
            continue
        if ch == "l":
            play_file(out)
            continue
        if ch != " ":
            continue
        while True:
            take = trim(record(args.device))
            tmp = os.path.join(HERE, "_take.ogg")
            sf.write(raw + ".tmp.wav", take, SR)
            fx = args.fx
            process(raw + ".tmp.wav", tmp, e, fx)
            print(f"   take {len(take) / SR:.1f}s - playing WITH effect ({fx})...")
            play_file(tmp)
            ch = ""
            while True:
                print(f"   P with effect ({fx}) | O without effect | F next effect | SPACE/ENTER keep | R redo | S skip")
                ch = key()
                if ch == "p":
                    play_file(tmp)
                elif ch == "o":
                    play_file(raw + ".tmp.wav")
                elif ch == "f":
                    # this take only: full -> phone -> none
                    fx = FX_MODES[(FX_MODES.index(fx) + 1) % len(FX_MODES)]
                    process(raw + ".tmp.wav", tmp, e, fx)
                    print(f"   effect now: {fx}")
                    play_file(tmp)
                elif ch in (" ", "\r", "r", "s"):
                    break
            if ch == "r":
                print("   again: SPACE to start")
                while key() != " ":
                    pass
                continue
            if ch in (" ", "\r"):
                os.makedirs(os.path.dirname(out), exist_ok=True)
                os.replace(tmp, out)
                os.replace(raw + ".tmp.wav", raw)
                m = meta.setdefault(k, {})
                m.update(speaker=e["speaker"], length=round(G.duration(out), 3), gen_text=e["text"], recorded=True, fx=fx)
                for field in ("assetId", "status", "reason"):
                    m.pop(field, None)
                meta_save(meta)
                kept += 1
                print(f"   kept ({m['length']}s)\n")
            else:
                for f in (tmp, raw + ".tmp.wav"):
                    if os.path.exists(f):
                        os.remove(f)
                print("   skipped\n")
            break
        i += 1
    print(f"\n{kept} take(s) kept. Next: python upload.py   then   python build_content.py")


if __name__ == "__main__":
    main()
