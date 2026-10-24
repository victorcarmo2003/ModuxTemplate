"""Generate the anomaly talk blip (owner 2026-10-22): one short 80 Hz triangle-wave tone, played per typed letter while an
anomaly customer speaks (the ordinary customers get a keyboard click instead).

  python tools/sfx/gen_anomaly_blip.py [--out Assets/audio/sfx/anomaly_blip.wav] [--freq 80] [--ms 110]

Standard library only (wave + math), deterministic. Mono 44.1 kHz 16-bit PCM WAV.
Envelope: 4 ms attack, short hold, exponential decay, so back-to-back letters read as separate pulses.
"""
import argparse
import math
import os
import struct
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RATE = 44100


def triangle(phase: float) -> float:
    # phase in [0, 1): -1 -> 1 -> -1
    return 4 * abs(phase - math.floor(phase + 0.5)) - 1


def render(freq: float, ms: float, peak: float) -> list:
    n = int(RATE * ms / 1000)
    attack = int(RATE * 0.004)
    hold = int(RATE * 0.015)
    out = []
    for i in range(n):
        t = i / RATE
        if i < attack:
            env = i / attack
        elif i < attack + hold:
            env = 1.0
        else:
            k = (i - attack - hold) / max(1, n - attack - hold)
            env = math.exp(-4.5 * k) * (1 - k)  # decays to exactly 0 at the end (no click)
        out.append(triangle(freq * t) * env * peak)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "Assets", "audio", "sfx", "anomaly_blip.wav"))
    ap.add_argument("--freq", type=float, default=80.0)
    ap.add_argument("--ms", type=float, default=110.0)
    ap.add_argument("--peak", type=float, default=0.89)  # about -1 dBFS
    a = ap.parse_args()
    samples = render(a.freq, a.ms, a.peak)
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with wave.open(a.out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    print(a.out, len(samples), "samples")


if __name__ == "__main__":
    main()
