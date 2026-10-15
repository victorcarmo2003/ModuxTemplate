"""Generate the water drop and puddle textures for ANM-005 (TASK-326).

Original work, synthetic shapes only (PIL + numpy). White with alpha: the ParticleEmitter tints it.

  Assets/textures/vfx/T_VFX_Drop.png    64x128 teardrop, tip up, round belly down, soft edge, faint highlight
  Assets/textures/vfx/T_VFX_Puddle.png  128x128 soft disc with a brighter rim (water spreading on the ground)

Run: python tools/assetplace/gen_vfx_drop.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "Assets" / "textures" / "vfx"
SS = 4  # supersampling


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def drop(w=64, h=128):
    W, H = w * SS, h * SS
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u = (x + 0.5) / W * 2 - 1  # -1..1
    v = (y + 0.5) / H  # 0 top .. 1 bottom
    # belly: circle centred low; body: radius grows from the tip (v=0.04) to the belly
    cy, r = 0.72, 0.27  # belly centre and radius (v units)
    # half-width profile along v (u units)
    tip = 0.04
    t = np.clip((v - tip) / (cy - tip), 0, 1)
    upper = 0.92 * np.sin(t * np.pi / 2) ** 1.6  # tapered top
    dv = np.clip((v - cy) / r, -1, 1)
    lower = 0.92 * np.sqrt(np.clip(1 - dv**2, 0, 1))
    half = np.where(v < cy, upper, lower)
    half = np.where(v < tip, 0, half)
    half = np.where(v > cy + r, 0, half)
    edge = 0.06
    alpha = smoothstep(0, edge, half - np.abs(u))
    # body slightly translucent, edge a bit denser (reads as a refracting drop)
    rim = 1 - smoothstep(0.0, 0.35, half - np.abs(u))
    alpha = alpha * (0.78 + 0.22 * rim)
    # highlight: small bright spot upper left of the belly
    hl = np.exp(-(((u + 0.32) / 0.16) ** 2 + ((v - 0.62) / 0.07) ** 2))
    alpha = np.clip(alpha + 0.2 * hl * (alpha > 0), 0, 1)
    rgb = np.ones((H, W, 3), np.float32)
    img = np.dstack([rgb, alpha]) * 255
    im = Image.fromarray(img.astype(np.uint8)).resize((w, h), Image.LANCZOS)
    return im


def puddle(n=128):
    N = n * SS
    y, x = np.mgrid[0:N, 0:N].astype(np.float32)
    u = (x + 0.5) / N * 2 - 1
    v = (y + 0.5) / N * 2 - 1
    d = np.sqrt(u**2 + v**2)
    body = 1 - smoothstep(0.82, 0.96, d)
    rim = np.exp(-(((d - 0.86) / 0.06) ** 2))
    alpha = np.clip(0.55 * body + 0.45 * rim * body, 0, 1)
    rgb = np.ones((N, N, 3), np.float32)
    img = np.dstack([rgb, alpha]) * 255
    return Image.fromarray(img.astype(np.uint8)).resize((n, n), Image.LANCZOS)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    drop().save(OUT / "T_VFX_Drop.png")
    puddle().save(OUT / "T_VFX_Puddle.png")
    print("wrote", OUT / "T_VFX_Drop.png", OUT / "T_VFX_Puddle.png")
