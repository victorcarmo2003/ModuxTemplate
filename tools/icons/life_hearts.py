# AST-165 life heart (white, tintable) and AST-166 revive icon (heart + plus + sparkles). Pillow only.
import math, sys
from PIL import Image, ImageDraw, ImageFilter
OUT = sys.argv[1]
S = 4  # supersample
N = 256
INK = (23, 17, 28, 255)

def heart_poly(cx, cy, size, steps=400):
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * size, cy - y * size))
    return pts

def heart(fill, gloss=True, plus=False, sparkles=False):
    W = N * S
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = W / 2, W * 0.52
    size = W * (0.026 if not plus else 0.024)
    outline = W * 0.045
    # ink outline: same heart drawn bigger with a round stroke
    d.polygon(heart_poly(cx, cy, size), fill=INK)
    for p in heart_poly(cx, cy, size, 900):
        d.ellipse([p[0] - outline, p[1] - outline, p[0] + outline, p[1] + outline], fill=INK)
    # lip (darker bottom band) then face
    r, g, b, a = fill
    lip = (int(r * 0.72), int(g * 0.72), int(b * 0.72), 255)
    d.polygon(heart_poly(cx, cy, size), fill=lip)
    d.polygon(heart_poly(cx, cy - W * 0.022, size * 0.93), fill=fill)
    if gloss:
        # one rounded highlight arc that follows the left lobe (owner 2026-10-20: more white, down the left side,
        # rounder): points of the heart outline, pulled in towards the lobe centre, thick in the middle, round ends
        gl = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        gd = ImageDraw.Draw(gl)
        lx, ly = -6.5, 4.0
        steps = 60
        for i in range(steps + 1):
            u = i / steps
            t = 2 * math.pi - (0.95 + 1.15 * u)
            hx = 16 * math.sin(t) ** 3
            hy = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
            px, py = lx + (hx - lx) * 0.66, ly + (hy - ly) * 0.66
            r = size * (0.55 + 1.05 * math.sin(math.pi * u) ** 0.7)
            x, y = cx + px * size, cy - py * size - W * 0.011
            gd.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, 240))
        img.alpha_composite(gl)
    if plus:
        arm, thick = W * 0.15, W * 0.075
        px, py = cx, cy - W * 0.03
        for (w, h, col) in ((arm + thick * 0.45, thick + thick * 0.9, INK), (arm, thick, (255, 255, 255, 255))):
            d.rounded_rectangle([px - w, py - h / 2, px + w, py + h / 2], radius=h / 2, fill=col)
            d.rounded_rectangle([px - h / 2, py - w, px + h / 2, py + w], radius=h / 2, fill=col)
    if sparkles:
        for (sx, sy, sr) in ((0.83, 0.17, 0.085), (0.15, 0.78, 0.06), (0.9, 0.62, 0.05)):
            spark(d, W * sx, W * sy, W * sr)
    return img.resize((N, N), Image.LANCZOS)

def spark(d, x, y, r):
    def star(rr):
        pts = []
        for i in range(8):
            a = math.pi / 4 * i - math.pi / 2
            k = rr if i % 2 == 0 else rr * 0.32
            pts.append((x + math.cos(a) * k, y + math.sin(a) * k))
        return pts
    d.polygon(star(r * 1.35), fill=INK)
    d.polygon(star(r), fill=(255, 218, 92, 255))

heart((255, 255, 255, 255)).save(f"{OUT}/AST-165_life_heart.png")
heart((242, 112, 140, 255), plus=True, sparkles=True).save(f"{OUT}/AST-166_revive_heart.png")
print("ok")
