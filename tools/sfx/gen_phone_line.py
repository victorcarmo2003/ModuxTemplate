"""Generate the phone line noise (owner 2026-10-23: "coloca mais ruído"): a seamless loop of pink hiss with sparse crackle,
band-limited like the phone (tools/voice/config.json phone band), played at the phone while Walt's call talks
(Content.Sounds "phone_line", BossController). Own work, no third-party audio.

  python tools/sfx/gen_phone_line.py [--out Assets/audio/sfx/phone_line.ogg] [--seconds 12]

Needs ffmpeg on the PATH. The head of the render is cross-faded into its tail so the loop has no seam.
"""
import argparse
import os
import shutil
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RATE = 24000
FADE = 1.0  # s of overlap at the loop point
BAND = "highpass=f=300,lowpass=f=3400"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "Assets", "audio", "sfx", "phone_line.ogg"))
    ap.add_argument("--seconds", type=float, default=12)
    a = ap.parse_args()
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise SystemExit("ffmpeg not on the PATH")
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    total = a.seconds + FADE
    tmp = os.path.join(HERE, "_phone_line.wav")
    # hiss + crackle, phone band, fixed loudness
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-filter_complex",
                    f"anoisesrc=color=pink:amplitude=0.35:sample_rate={RATE}:duration={total}:seed=7,{BAND}[hiss];"
                    f"anoisesrc=color=velvet:density=0.0015:amplitude=0.6:sample_rate={RATE}:duration={total}:seed=11,{BAND}[crackle];"
                    f"[hiss][crackle]amix=inputs=2:normalize=0,loudnorm=I=-26:TP=-6:LRA=5,aresample={RATE}",
                    "-ac", "1", tmp], check=True)
    # loop: the body (FADE .. end) whose last FADE s cross-fade into the first FADE s of the render
    loop = (
        "[0:a]asplit[a][b];"
        f"[a]atrim=start={FADE},asetpts=PTS-STARTPTS[body];"
        f"[b]atrim=end={FADE},asetpts=PTS-STARTPTS[head];"
        f"[body][head]acrossfade=d={FADE}:c1=tri:c2=tri"
    )
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", tmp, "-filter_complex", loop, "-ac", "1",
                    "-c:a", "libvorbis", "-q:a", "5", a.out], check=True)
    os.remove(tmp)
    print(a.out)


if __name__ == "__main__":
    main()
