# Lot 1 of the Halloween lobby kit (TASK-625): cauldron, pumpkins, lanterns. Headless:
#   sh <skill>/scripts/blender/bl.sh tools/halloween/lot1.py
import math, sys
TOYLIB = "C:/Users/hakor/.claude/skills/roblox-asset-pipeline/scripts/blender/toylib.py"
exec(open(TOYLIB, encoding="utf-8").read())
exec(open("D:/UserData/Documents/ModuxGames/Sell Hotdogs/tools/halloween/hwlib.py", encoding="utf-8").read())

ONLY = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else ""


def want(n):
    return not ONLY or ONLY in n


# ---------- AST-167 cauldron ----------
if want("Cauldron"):
    reset(ATLAS)
    body = lathe("Body", [(0, 0.55), (1.5, 0.65), (2.6, 1.15), (3.3, 2.1), (3.45, 2.9), (3.2, 3.7), (2.85, 4.15),
                          (2.55, 4.2), (2.5, 3.9), (0, 3.85)], IRON, segs=18)
    rim = torus("Rim", 2.75, 0.34, (0, 0, 4.22), "z", AMBER, segs=18, rsegs=6)
    belt = torus("Belt", 3.43, 0.13, (0, 0, 2.75), "z", PUMPKIN, segs=18, rsegs=4)
    legs = []
    for i in range(3):
        a = math.radians(90 + 120 * i)
        legs.append(cyl(f"Leg{i}", 0.85, 1.1, (1.95 * math.cos(a), 1.95 * math.sin(a), 0.55), "z", VIOLET_DK, segs=8, d2=0.6))
    handles = [torus(f"Handle{s}", 0.55, 0.13, (s * 3.55, 0, 3.35), "x", AMBER, segs=10, rsegs=4) for s in (-1, 1)]
    join([body, rim, belt] + legs + handles, "Cauldron")
    liquid = lathe("Glow_Liquid", [(0, 4.12), (1.6, 4.05), (2.62, 3.95), (2.62, 3.9), (0, 3.9)], WHITE, segs=18)
    ship("AST-167", "HW_Cauldron_Main")

# ---------- AST-168 pumpkins ----------
SIZES = {"Small": (1.4, 1.0), "Medium": (2.2, 1.55), "Large": (3.2, 2.2)}


def pumpkin(d, h):
    b = lobed("Body", d, h, PUMPKIN, lobes=8, segs=24, rings=8)
    stem = tube("Stem", [(0, 0, h * 0.78), (0, 0.02 * d, h * 0.98), (0.08 * d, 0.06 * d, h * 1.12), (0.16 * d, 0.06 * d, h * 1.16)],
                0.07 * d + 0.03, STEM, sides=6, radii=[0.075 * d + 0.03, 0.07 * d + 0.03, 0.055 * d + 0.02, 0.04 * d + 0.02])
    leaf = slab("Leaf", [(0, 0), (0.18 * d, 0.07 * d), (0.3 * d, 0), (0.18 * d, -0.05 * d)], 0.04, STEM)
    rotz(leaf, -90)
    move(leaf, (-0.05 * d, -0.02 * d, h * 0.9))
    p = join([b, stem, leaf], "Pumpkin")
    move(p, (0, 0, -0.038 * h))  # lowest ring sits under the bottom dimple: put it on the ground
    return p


for size, (d, h) in SIZES.items():
    if want("Pumpkin_" + size):
        reset(ATLAS)
        pumpkin(d, h)
        ship("AST-168", f"HW_Pumpkin_{size}")

# Faces: glowing features hugging the front of a Medium pumpkin
FD, FH = 2.2, 1.55
R, HZ = FD / 2 * 0.985, FH / 2


def front(x, z):
    q = 1 - (x / R) ** 2 - ((z - HZ) / HZ) ** 2
    return R * math.sqrt(max(q, 0.02))


def tri_eye(cx, cz, s, up=True):
    return [(cx - s, cz - s * 0.6), (cx + s, cz - s * 0.6), (cx, cz + s * 0.9)] if up else \
        [(cx - s, cz + s * 0.6), (cx, cz - s * 0.9), (cx + s, cz + s * 0.6)]


def grin(cz, w, hgt, teeth=2):
    pts = []
    n = 10
    for i in range(n + 1):  # lower arc
        t = math.pi + math.pi * i / n
        pts.append((w * math.cos(t), cz + hgt * math.sin(t)))
    top = []
    for i in range(n + 1):  # top edge with square teeth
        x = w - 2 * w * i / n
        tooth = teeth and (i in (3, 7))
        top.append((x, cz + (-hgt * 0.35 if tooth else 0.04)))
    return pts + top[1:-1]


FACES = {
    "A": lambda: [tri_eye(-0.36, 1.0, 0.19), tri_eye(0.36, 1.0, 0.19), grin(0.62, 0.5, 0.26)],  # happy grin
    "B": lambda: [circle_pts(-0.34, 0.98, 0.15, 0.2, 10), circle_pts(0.34, 0.98, 0.15, 0.2, 10),
                  circle_pts(0, 0.55, 0.16, 0.2, 12)],  # surprised "o"
    "C": lambda: [tri_eye(-0.36, 1.0, 0.19),
                  [(0.18, 1.0), (0.54, 1.0), (0.54, 1.08), (0.18, 1.08)],  # wink
                  grin(0.62, 0.46, 0.22, teeth=1)],
}
for key, shapes in FACES.items():
    if want("Face_" + key):
        reset(ATLAS)
        pumpkin(FD, FH)
        feats = [slab(f"F{i}", s, 0.12, WHITE, surface=front, lift=0.04) for i, s in enumerate(shapes())]
        move(join(feats, "Glow_Face"), (0, 0, -0.038 * FH))
        ship("AST-168", f"HW_Pumpkin_Face_{key}")


# ---------- AST-169 lanterns ----------
def lantern(z0):
    """Lantern hanging from z0 (top of ring) downwards. Returns (frame, glow)."""
    zt = z0 - 0.3
    ring = torus("Ring", 0.16, 0.045, (0, 0, z0 - 0.16), "y", INK, segs=8, rsegs=4)
    roof = cyl("Roof", 1.15, 0.38, (0, 0, zt - 0.19), "z", PUMPKIN_DK, segs=4, d2=0.22)
    rotz(roof, 45)
    cap = box("Cap", (0.95, 0.95, 0.1), (0, 0, zt - 0.43), INK, bevel=0.02)
    posts = [box(f"P{i}", (0.09, 0.09, 1.0), (sx * 0.42, sy * 0.42, zt - 0.98), INK)
             for i, (sx, sy) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1)))]
    base = box("Base", (1.0, 1.0, 0.16), (0, 0, zt - 1.56), INK, bevel=0.03)
    frame = join([ring, roof, cap, base] + posts, "Lantern")
    glow = box("Glow_Lamp", (0.72, 0.72, 0.98), (0, 0, zt - 0.98), WHITE, bevel=0.06)
    return frame, glow


if want("Lantern_Hanging"):
    reset(ATLAS)
    lantern(0.0)
    ship("AST-169", "HW_Lantern_Hanging")

if want("Lantern_Post"):
    reset(ATLAS)
    foot = box("Foot", (0.9, 0.9, 0.3), (0, 0, 0.15), INK, bevel=0.06)
    pole = cyl("Pole", 0.22, 4.4, (0, 0, 2.5), "z", INK, segs=8)
    arm = box("Arm", (0.12, 0.95, 0.12), (0, 0.45, 4.55), INK)
    knob = cyl("Knob", 0.32, 0.25, (0, 0, 4.8), "z", PUMPKIN, segs=8)
    frame, glow = lantern(4.5)
    move(frame, (0, 0.85, 0))
    move(glow, (0, 0.85, 0))
    join([foot, pole, arm, knob, frame], "LanternPost")
    ship("AST-169", "HW_Lantern_Post")
