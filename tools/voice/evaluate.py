"""Objective check of voice samples: ASR round-trip word error (faster-whisper base.en), seconds per word,
leading/trailing silence, longest internal silence (ffmpeg silencedetect), peak.

  .venv/Scripts/python evaluate.py samples/*_clean.wav
"""
import json, os, re, subprocess, sys, glob
import numpy as np, soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
LINES = json.load(open(os.path.join(HERE, "lines.json"), encoding="utf-8"))
sys.path.insert(0, HERE)
import generate as G


def wer(ref, hyp):
    r = re.findall(r"[a-z']+", ref.lower()); h = re.findall(r"[a-z']+", hyp.lower())
    d = list(range(len(h) + 1))
    for i in range(1, len(r) + 1):
        p, d[0] = d[0], i
        for j in range(1, len(h) + 1):
            p, d[j] = d[j], min(d[j] + 1, d[j - 1] + 1, p + (r[i - 1] != h[j - 1]))
    return d[len(h)] / max(1, len(r))


def silences(path):
    out = subprocess.run([G.ffmpeg_exe(), "-i", path, "-af", "silencedetect=n=-40dB:d=0.12", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    st = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", out)]
    du = [float(x) for x in re.findall(r"silence_duration: ([\d.]+)", out)]
    return list(zip(st, du))


def main(paths):
    from faster_whisper import WhisperModel
    model = WhisperModel("base.en", device="cpu", compute_type="int8")
    for p in paths:
        m = re.search(r"(v_[0-9a-f]{10})", p)
        ref = LINES[m.group(1)]["text"] if m else "I really need a job right now but nobody's hiring"
        raw = subprocess.run([G.ffmpeg_exe(), "-loglevel", "error", "-i", p, "-f", "f32le", "-ac", "1", "-ar", "16000", "-"], capture_output=True).stdout
        segs, _ = model.transcribe(np.frombuffer(raw, dtype=np.float32), language="en")
        hyp = " ".join(s.text for s in segs)
        a, sr = sf.read(p)
        dur = len(a) / sr
        words = len(re.findall(r"[A-Za-z']+", ref))
        sil = silences(p)
        lead = sil[0][1] if sil and sil[0][0] < 0.05 else 0
        mid = max([d for s, d in sil if s > 0.05 and s + d < dur - 0.05] or [0])
        print(f"{os.path.basename(p):45s} dur={dur:5.2f}s s/word={dur / words:4.2f} lead={lead:4.2f} maxgap={mid:4.2f} peak={np.abs(a).max():4.2f} WER={wer(ref, hyp):4.2f} | {hyp.strip()}")


if __name__ == "__main__":
    main(sorted(sum((glob.glob(a) for a in sys.argv[1:]), [])))
