"""Import Walt's lines generated on ElevenLabs (owner 2026-10-23; script: tools/voice/elevenlabs_script.md).

  .venv/Scripts/python import_elevenlabs.py [--dir elevenlabs] [--fx phone|none] [--dry]

Takes every <key>.mp3 / .wav / .ogg in tools/voice/elevenlabs/ whose key is a line of lines.json (the subtitle stays the
game's text; the audio may say it differently), trims the silence around it, and writes
Assets/audio/voice/<speaker>/<key>.ogg like record.py: phone lines get the phone band + line noise (--fx phone, default),
in-person lines (the finale) only the loudness. assets.json gets the length and source "elevenlabs"; its assetId /
status are cleared so upload.py sends the new audio. Then: python upload.py, python build_content.py.
Unknown file names are listed and skipped.
"""
import argparse, json, os, subprocess
import numpy as np, soundfile as sf
import generate as G
import record as R

TYPES = (".mp3", ".wav", ".ogg", ".flac")


def decode(path, out_wav):
    # any format -> mono wav at the capture rate record.trim expects
    subprocess.run([G.ffmpeg_exe(), "-y", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(R.SR), out_wav], check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=os.path.join(G.HERE, "elevenlabs"))
    ap.add_argument("--fx", choices=["phone", "none"], default="phone")
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()
    meta = R.meta_load()
    files = sorted(f for f in os.listdir(a.dir) if os.path.splitext(f)[1].lower() in TYPES) if os.path.isdir(a.dir) else []
    tmp = os.path.join(G.HERE, "_import.wav")
    done, unknown = 0, []
    for name in files:
        k = os.path.splitext(name)[0]
        e = G.LINES.get(k)
        if e is None:
            unknown.append(name)
            continue
        if a.dry:
            print("would import", k, e["text"])
            continue
        decode(os.path.join(a.dir, name), tmp)
        audio, _ = sf.read(tmp, dtype="float32")
        sf.write(tmp, R.trim(audio), R.SR)
        out = os.path.join(G.OUT, e["speaker"], k + ".ogg")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        # phone lines: band + line noise; in-person (finale): loudness only
        R.process(tmp, out, e, a.fx if G.is_phone(e) else "none")
        m = meta.setdefault(k, {})
        m.update(speaker=e["speaker"], length=round(G.duration(out), 3), gen_text=e["text"], source="elevenlabs")
        m.pop("recorded", None)
        for field in ("assetId", "status", "reason"):
            m.pop(field, None)
        done += 1
        print(done, k, m["length"], "s", e["text"])
    if os.path.exists(tmp):
        os.remove(tmp)
    if not a.dry:
        R.meta_save(meta)
    missing = [k for k in G.LINES if not any(os.path.splitext(f)[0] == k for f in files)]
    print(f"\n{done} imported, {len(unknown)} unknown file(s), {len(missing)} game line(s) without an ElevenLabs file")
    for name in unknown:
        print("  unknown:", name)
    if done:
        print("Next: python upload.py   then   python build_content.py")


if __name__ == "__main__":
    main()
