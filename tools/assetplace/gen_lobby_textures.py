"""Generates the tileable lobby textures (original work, no third-party source -> no licence needed).
Usage: python tools/assetplace/gen_lobby_textures.py   (writes Assets/textures/lobby/*.png)
All outputs are seamless: noise is filtered with mode='wrap' and joint lines sit on the tile edges."""
import os
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "Assets", "textures", "lobby")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1013)


def noise(n, sigma, aspect=(1, 1)):
    a = rng.standard_normal((n, n))
    a = gaussian_filter(a, (sigma * aspect[0], sigma * aspect[1]), mode="wrap")
    return (a - a.mean()) / (a.std() + 1e-9)


def save(name, arr):
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    Image.fromarray(arr).save(os.path.join(OUT, name), optimize=True)


def pave(n, slabs, base, grout, jitter, bond=False):
    """slabs x slabs paving slabs per tile. base/grout = RGB; bond = running bond (every other row offset by half)."""
    s = n // slabs
    img = np.zeros((n, n, 3))
    y, x = np.mgrid[0:n, 0:n]
    row = (y // s)
    xo = (x + (row % 2) * (s // 2) * (1 if bond else 0)) % n
    col = xo // s
    ids = row * slabs + col
    tone = rng.uniform(-jitter, jitter, slabs * slabs)
    warm = rng.uniform(-6, 6, slabs * slabs)
    lum = tone[ids % (slabs * slabs)]
    for c, d in zip(range(3), (1.0, 0.92, 0.80)):
        img[..., c] = base[c] * (1 + lum) + warm[ids % (slabs * slabs)] * d
    # surface: soft blotches + fine grain
    img *= (1 + 0.06 * noise(n, 24))[..., None]
    img *= (1 + 0.035 * noise(n, 1.2))[..., None]
    # joints (distance to slab edge)
    lx = xo % s
    ly = y % s
    d = np.minimum.reduce([lx, s - 1 - lx, ly, s - 1 - ly]).astype(float)
    j = np.clip(1 - (d - 3.5) / 4.0, 0, 1) ** 1.2  # 0 inside .. 1 on joint
    jn = j * (0.85 + 0.15 * noise(n, 2))
    for c in range(3):
        img[..., c] = img[..., c] * (1 - jn) + grout[c] * jn
    # bevel highlight just inside the top/left edge
    hl = ((d >= 4) & (d < 6) & ((lx < 8) | (ly < 8))).astype(float) * 0.05
    img *= (1 + hl)[..., None]
    # a few hairline cracks
    for _ in range(max(2, slabs)):
        cx, cy = rng.integers(0, n, 2)
        ang = rng.uniform(0, 6.28)
        for t in range(rng.integers(12, 40)):
            ang += rng.normal(0, 0.45)
            cx = (cx + np.cos(ang) * 1.3) % n
            cy = (cy + np.sin(ang) * 1.3) % n
            img[int(cy), int(cx)] *= 0.62
    return img


def stain(n):
    a = noise(n, 18)
    b = noise(n, 6)
    m = np.clip((a * 0.8 + b * 0.35 - 0.55) / 0.9, 0, 1)
    alpha = m ** 1.4 * 0.30
    # sparse gum / oil dots
    dots = noise(n, 1.0) > 2.9
    alpha = np.maximum(alpha, gaussian_filter(dots.astype(float), 1.1, mode="wrap") * 1.6)
    rgb = np.zeros((n, n, 3))
    rgb[...] = (48, 36, 30)
    out = np.dstack([rgb, np.clip(alpha, 0, 0.4) * 255])
    return out


def planks(n, count, base, gap):
    h = n // count
    img = np.zeros((n, n, 3))
    y, x = np.mgrid[0:n, 0:n]
    row = y // h
    tone = rng.uniform(-0.10, 0.10, count)
    shift = rng.integers(0, n, count)
    grain = noise(n, 1.0, aspect=(1, 14))
    ring = np.sin((y * 0.55 + noise(n, 6) * 5) * 0.8) * 0.5
    xs = (x + shift[row]) % n
    for c in range(3):
        img[..., c] = base[c] * (1 + tone[row]) * (1 + 0.07 * grain + 0.03 * ring)
    ly = y % h
    d = np.minimum(ly, h - 1 - ly).astype(float)
    j = np.clip(1 - (d - 0.5) / 2.2, 0, 1)
    # butt joints every half tile, staggered per plank
    jx = np.minimum(xs % (n // 2), n // 2 - 1 - xs % (n // 2)).astype(float)
    j = np.maximum(j, np.clip(1 - (jx - 0.5) / 2.0, 0, 1))
    for c in range(3):
        img[..., c] = img[..., c] * (1 - j) + gap[c] * j
    return img


def brick(n, rows, cols, brick_rgb, mortar):
    bh = n // rows
    bw = n // cols
    y, x = np.mgrid[0:n, 0:n]
    row = y // bh
    xo = (x + (row % 2) * (bw // 2)) % n
    col = xo // bw
    ids = (row * cols + col) % (rows * cols)
    tone = rng.uniform(-0.14, 0.12, rows * cols)
    img = np.zeros((n, n, 3))
    for c in range(3):
        img[..., c] = brick_rgb[c] * (1 + tone[ids])
    img *= (1 + 0.06 * noise(n, 1.5))[..., None]
    img *= (1 + 0.05 * noise(n, 14))[..., None]
    lx = xo % bw
    ly = y % bh
    d = np.minimum.reduce([lx, bw - 1 - lx, ly, bh - 1 - ly]).astype(float)
    j = np.clip(1 - (d - 0.5) / 1.8, 0, 1)
    for c in range(3):
        img[..., c] = img[..., c] * (1 - j) + mortar[c] * j
    return img


# warm grey-beige paving, darker than the old white/lilac Kenney tile so the amber lights do not blow out
save("T_LobbyPave.png", pave(512, 2, (150, 135, 125), (82, 72, 66), 0.07))
# lighter paving for the semantic aprons (they must still read as "special" ground)
save("T_LobbyPaveLight.png", pave(512, 2, (206, 188, 160), (128, 108, 92), 0.04, bond=True))
# transparent stain overlay (second Texture, ZIndex above the paving)
save("T_LobbyStain.png", stain(512))
# wood planks (stage top, food-court deck)
save("T_LobbyWood.png", planks(256, 8, (158, 108, 70), (60, 38, 26)))
# greyscale-ish brick, tinted per part through Texture.Color3 (keeps semantic colours, e.g. the red stage front)
save("T_LobbyBrick.png", brick(256, 8, 4, (205, 190, 178), (230, 222, 210)))
print("ok ->", os.path.abspath(OUT))
