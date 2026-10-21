# Lot 2 of the Halloween lobby kit (TASK-626): candy, crate, bat, cobweb, pennants, ghost, moon arch, signs, crystals.
#   sh <skill>/scripts/blender/bl.sh tools/halloween/lot2.py [-- <name filter>]
import math, sys
from mathutils import Matrix
TOYLIB = "C:/Users/hakor/.claude/skills/roblox-asset-pipeline/scripts/blender/toylib.py"
exec(open(TOYLIB, encoding="utf-8").read())
exec(open("D:/UserData/Documents/ModuxGames/Sell Hotdogs/tools/halloween/hwlib.py", encoding="utf-8").read())

ONLY = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else ""


def want(n):
    return not ONLY or ONLY in n


def xform(o, rx=0, ry=0, rz=0, t=(0, 0, 0)):
    o.data.transform(Matrix.Translation(Vector(t)) @ Matrix.Rotation(math.radians(rz), 4, "Z")
                     @ Matrix.Rotation(math.radians(ry), 4, "Y") @ Matrix.Rotation(math.radians(rx), 4, "X"))
    return o


def candy(name, band, at, rz=0, s=1.0):
    mid = cyl(name, 0.3 * s, 0.34 * s, (0, 0, 0), "x", band, segs=8)
    ends = [xform(cyl(name + f"E{k}", 0.06 * s, 0.16 * s, (0, 0, 0), "x", band, segs=6, d2=0.3 * s), ry=0 if k else 180,
                  t=(k * 0.25 * s - (1 - k) * 0.25 * s, 0, 0)) for k in (0, 1)]
    c = join([mid] + ends, name)
    return xform(c, rz=rz, t=at)


# ---------- AST-170 candy ----------
if want("Candy_Bucket"):
    reset(ATLAS)
    body = lathe("Body", [(0, 0.0), (0.5, 0.0), (0.7, 0.3), (0.74, 0.7), (0.62, 1.1), (0.55, 1.12), (0.52, 1.0), (0, 1.0)],
                 PUMPKIN, segs=14)
    R = 0.72

    def surf(x, z):
        return math.sqrt(max(R * R - x * x, 0.01))
    eyes = [slab(f"Eye{s}", [(s * 0.22 - 0.1, 0.62), (s * 0.22 + 0.1, 0.62), (s * 0.22, 0.8)], 0.06, INK, surface=surf, lift=0.03)
            for s in (-1, 1)]
    mouth = slab("Mouth", [(-0.3, 0.42), (-0.1, 0.33), (0.1, 0.33), (0.3, 0.42), (0.1, 0.38), (-0.1, 0.38)], 0.06, INK,
                 surface=surf, lift=0.03)
    handle = tube("Handle", [(-0.62, 0, 1.05)] + [(-0.62 * math.cos(math.pi * i / 8), 0, 1.05 + 0.75 * math.sin(math.pi * i / 8))
                                                  for i in range(1, 8)] + [(0.62, 0, 1.05)], 0.05, INK, sides=4)
    sweets = [candy("C1", PINK, (-0.15, 0.1, 1.08), 20), candy("C2", VIOLET, (0.2, -0.1, 1.1), -35),
              candy("C3", CREAM, (0.05, 0.25, 1.15), 80), candy("C4", TEAL, (-0.2, -0.2, 1.12), 120)]
    join([body, handle, mouth] + eyes + sweets, "CandyBucket")
    ship("AST-170", "HW_Candy_Bucket")

if want("Candy_Cluster"):
    reset(ATLAS)
    spots = [((0, 0), PINK, 10), ((0.45, 0.2), VIOLET, 70), ((-0.4, 0.25), CREAM, -30), ((0.2, -0.4), TEAL, 45),
             ((-0.3, -0.35), MAGENTA, 100), ((0.55, -0.25), YELLOW, -60)]
    parts = [candy(f"C{i}", b, (x, y, 0.15), rz) for i, ((x, y), b, rz) in enumerate(spots)]
    parts.append(candy("Top", PINK, (0.1, 0.0, 0.42), 35))
    join(parts, "CandyCluster")
    ship("AST-170", "HW_Candy_Cluster")

# ---------- AST-171 crate ----------
if want("Crate"):
    reset(ATLAS)
    core = box("Core", (1.9, 1.9, 1.5), (0, 0, 0.75), WOOD, bevel=0.04)
    slats = []
    for z in (0.25, 1.25):
        slats.append(box(f"SX{z}", (2.0, 2.0, 0.22), (0, 0, z), WOOD_DK, bevel=0.03))
    for sx in (-1, 1):
        for sy in (-1, 1):
            slats.append(box(f"Post{sx}{sy}", (0.22, 0.22, 1.6), (sx * 0.92, sy * 0.92, 0.8), WOOD_DK, bevel=0.03))
    mark = slab("Mark", circle_pts(0, 0.75, 0.32, 0.26, 10), 0.04, PUMPKIN, y=0.97)
    stem = slab("MarkStem", [(-0.05, 0.98), (0.05, 0.98), (0.08, 1.12), (-0.02, 1.1)], 0.04, STEM, y=0.97)
    join([core, mark, stem] + slats, "Crate")
    ship("AST-171", "HW_Crate")

# ---------- AST-172 bat + cobweb ----------
if want("Bat"):
    reset(ATLAS)
    right = [(0.0, 0.62), (0.1, 0.62), (0.17, 0.82), (0.24, 0.56), (0.45, 0.66), (0.8, 0.8), (1.2, 0.72), (1.1, 0.48),
             (0.95, 0.3), (0.8, 0.4), (0.66, 0.22), (0.5, 0.32), (0.32, 0.14), (0.15, 0.08), (0.0, 0.0)]
    left = [(-x, z) for x, z in reversed(right[1:-1])]
    body = slab("Bat", right + left, 0.12, DEEP)
    eyes = [slab(f"Eye{s}", circle_pts(s * 0.08, 0.46, 0.05, 0.065, 8), 0.04, CREAM, y=0.07) for s in (-1, 1)]
    join([body] + eyes, "Bat")
    ship("AST-172", "HW_Bat_Silhouette")

if want("Cobweb"):
    reset(ATLAS)
    strands = []
    angs = [0, 22.5, 45, 67.5, 90]
    for a in angs:  # corner at origin, web in the x >= 0, z <= 0 quadrant (under a ceiling, against a wall)
        r = math.radians(a)
        strands.append(tube(f"S{a}", [(0, 0, 0), (2.0 * math.cos(r), 0, -2.0 * math.sin(r))], 0.03, CREAM, sides=3))
    for k, rad in enumerate((0.6, 1.1, 1.6)):
        pts = []
        for i, a in enumerate(angs):
            r = math.radians(a)
            pts.append((rad * math.cos(r), 0, -rad * math.sin(r)))
            if i < len(angs) - 1:  # sag toward the corner between strands
                m = math.radians(a + 11.25)
                pts.append((rad * 0.86 * math.cos(m), 0, -rad * 0.86 * math.sin(m)))
        strands.append(tube(f"A{k}", pts, 0.025, CREAM, sides=3))
    join(strands, "Cobweb")
    ship("AST-172", "HW_Cobweb_Corner")

# ---------- AST-173 pennants ----------
if want("Pennant"):
    reset(ATLAS)
    L, SAG = 8.0, 0.45

    def cz(x):
        return -SAG * math.sin(math.pi * x / L)
    cord = tube("Cord", [(L * i / 12, 0, cz(L * i / 12)) for i in range(13)], 0.035, INK, sides=4)
    flags = []
    for i in range(6):
        x = L * (i + 0.75) / 6.5
        z = cz(x) - 0.03
        flags.append(slab(f"F{i}", [(x - 0.42, z), (x + 0.42, z), (x, z - 0.95)], 0.04, PUMPKIN if i % 2 == 0 else VIOLET))
    join([cord] + flags, "Pennants")
    ship("AST-173", "HW_Pennant_String")

# ---------- AST-174 ghost ----------
if want("Ghost"):
    reset(ATLAS)
    g = lathe("Ghost", [(0, 0.35), (0.82, 0.18), (0.86, 0.7), (0.82, 1.25), (0.72, 1.65), (0.52, 1.95), (0.27, 2.12), (0, 2.18)], CREAM, segs=16)
    for v in g.data.vertices:  # wavy hem
        if v.co.z < 0.25:
            ph = math.atan2(v.co.y, v.co.x)
            v.co.z += 0.16 * (1 + math.cos(5 * ph)) / 2
    arms = [xform(cyl(f"Arm{s}", 0.32, 0.4, (0, 0, 0), "x", CREAM, segs=6, d2=0.18), ry=s * -25, t=(s * 0.9, 0.05, 1.1))
            for s in (-1, 1)]

    def surf(x, z):
        rz = 0.84 if z < 1.25 else 0.82 - (z - 1.25) * 0.25
        return math.sqrt(max(rz * rz - x * x, 0.01))
    eyes = [slab(f"Eye{s}", circle_pts(s * 0.24, 1.42, 0.1, 0.15, 10), 0.08, INK, surface=surf, lift=0.05) for s in (-1, 1)]
    cheeks = [slab(f"Cheek{s}", circle_pts(s * 0.42, 1.2, 0.09, 0.06, 8), 0.06, MAGENTA, surface=surf, lift=0.04) for s in (-1, 1)]
    mouth = slab("Mouth", circle_pts(0, 1.18, 0.07, 0.05, 8), 0.06, INK, surface=surf, lift=0.04)
    join([g, mouth] + arms + eyes + cheeks, "Ghost")
    ship("AST-174", "HW_Ghost_Cute")

# ---------- AST-175 moon arch + signs ----------
def crescent(name, thick, band, n=20):
    """Crescent opening to +X: outer circle R 4 centred (0, 4), inner circle through the same tips. Quad strip
    between matching outer/inner points (an ear-clipped n-gon filled the hollow)."""
    bm = bmesh.new()
    ring = []
    for i in range(n + 1):
        t = i / n
        ao, ai = math.radians(40 + 280 * t), math.radians(54 + 252 * t)
        o = (4 * math.cos(ao), 4 + 4 * math.sin(ao))
        q = (1.2 + 3.17 * math.cos(ai), 4 + 3.17 * math.sin(ai))
        ring.append([bm.verts.new((p[0], y, p[1])) for p in (o, q) for y in (thick / 2, -thick / 2)])
    for a, b in zip(ring, ring[1:]):
        bm.faces.new((a[0], b[0], b[2], a[2]))  # front
        bm.faces.new((a[1], a[3], b[3], b[1]))  # back
        bm.faces.new((a[0], a[1], b[1], b[0]))  # outer rim
        bm.faces.new((a[2], b[2], b[3], a[3]))  # inner rim
    for e in (ring[0], ring[-1]):
        bm.faces.new((e[0], e[1], e[3], e[2]))
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(bm, name, band)


if want("Moon"):
    reset(ATLAS)
    moon = crescent("Moon", 0.9, SAND)
    face_eye = slab("Eye", [(-2.95, 5.2), (-2.35, 5.2), (-2.4, 5.05), (-2.9, 5.05)], 0.06, INK, y=0.48)
    smile = slab("Smile", [(-3.0, 4.2), (-2.55, 3.95), (-2.15, 4.15), (-2.55, 4.05)], 0.06, INK, y=0.48)
    cheek = slab("Cheek", circle_pts(-3.1, 4.65, 0.22, 0.14, 8), 0.06, MAGENTA, y=0.48)
    base = box("Base", (3.4, 1.8, 0.5), (-0.6, 0, 0.25), INK, bevel=0.08)
    xform(moon, t=(0, 0, 0.35))
    for o in (face_eye, smile, cheek):
        xform(o, t=(0, 0, 0.35))
    cords = []
    for i, (x, z) in enumerate(((1.3, 6.3), (2.3, 4.6), (1.0, 3.0))):  # stars hang from the inner rim
        top = 4 + math.sqrt(3.17 ** 2 - (x - 1.2) ** 2) + 0.35
        cords.append(tube(f"Cord{i}", [(x, 0, z + 0.35 + 0.3), (x, 0, top + 0.1)], 0.03, INK, sides=4))
    join([moon, base, face_eye, smile, cheek] + cords, "MoonArch")
    stars = []
    for i, (x, z, s) in enumerate(((1.3, 6.3, 0.45), (2.3, 4.6, 0.32), (1.0, 3.0, 0.38))):
        pts = []
        for k in range(10):
            r = s if k % 2 == 0 else s * 0.45
            a = math.pi / 2 + math.pi * k / 5
            pts.append((x + r * math.cos(a), z + r * math.sin(a)))
        stars.append(xform(slab(f"Star{i}", pts, 0.12, WHITE), t=(0, 0, 0.35)))
    join(stars, "Glow_Stars")
    ship("AST-175", "HW_Moon_Arch")

if want("Photo_Sign"):
    reset(ATLAS)
    posts = [box(f"Post{s}", (0.28, 0.28, 3.4), (s * 2.35, 0, 1.7), WOOD_DK, bevel=0.04) for s in (-1, 1)]
    board = box("Board", (5.2, 0.24, 1.5), (0, 0, 2.75), VIOLET_DK, bevel=0.06)
    trim = box("Trim", (5.4, 0.16, 1.7), (0, -0.06, 2.75), PUMPKIN, bevel=0.04)
    caps = [cyl(f"Cap{s}", 0.36, 0.2, (s * 2.35, 0, 3.5), "z", PUMPKIN, segs=8) for s in (-1, 1)]
    join(posts + [board, trim] + caps, "PhotoSign")
    ship("AST-175", "HW_Photo_Sign")

if want("Hotdog_Pumpkin"):
    reset(ATLAS)
    lobes = []
    for k in range(40):
        a = 2 * math.pi * k / 40
        r = 1.0 * (1 - 0.06 * (1 - math.cos(5 * a)) / 2)
        lobes.append((1.25 * r * math.cos(a), 1.25 + 1.0 * r * math.sin(a)))
    pumpkin = slab("Pumpkin", lobes, 0.22, PUMPKIN)
    stem = slab("Stem", [(-0.1, 2.15), (0.12, 2.15), (0.22, 2.5), (0.04, 2.45)], 0.18, STEM)
    eyes = [slab(f"Eye{s}", [(s * 0.42 - 0.15, 1.55), (s * 0.42 + 0.15, 1.55), (s * 0.42, 1.8)], 0.06, INK, y=0.13) for s in (-1, 1)]
    bun = slab("Bun", circle_pts(0, 0.95, 1.05, 0.3, 14), 0.2, SAND, y=0.22)
    dog = slab("Sausage", circle_pts(0, 1.08, 1.25, 0.2, 14), 0.16, PLUM, y=0.34)
    must = tube("Mustard", [(-0.95 + 0.19 * i, 0.44, 1.08 + (0.08 if i % 2 else -0.06)) for i in range(11)], 0.035, YELLOW, sides=4)
    legs = [box(f"Leg{s}", (0.18, 0.18, 0.5), (s * 0.7, -0.05, 0.25), INK) for s in (-1, 1)]
    join([pumpkin, stem, bun, dog, must] + eyes + legs, "HotdogPumpkinSign")
    ship("AST-175", "HW_Hotdog_Pumpkin_Sign")


# ---------- AST-176 crystals ----------
def crystals(band):
    rock = cyl("Rock", 1.6, 0.45, (0, 0, 0.22), "z", STONE, segs=7, d2=1.2)
    bodies, tips = [rock], []
    for i, (h, d, rx, ry, x, y) in enumerate(((1.7, 0.62, 0, 0, 0, 0), (1.1, 0.46, 0, 28, 0.42, 0.05),
                                              (1.25, 0.5, -26, -12, -0.3, 0.32), (0.8, 0.38, 24, -22, -0.25, -0.38))):
        b = cyl(f"B{i}", d, h, (0, 0, h / 2), "z", band, segs=6)
        t = cyl(f"T{i}", 0.04, d * 0.8, (0, 0, h + d * 0.4), "z", WHITE, segs=6, d2=d)
        t.data.transform(Matrix.Rotation(math.pi, 4, "X") @ Matrix.Translation((0, 0, -(h + d * 0.4))))
        t.data.transform(Matrix.Translation((0, 0, h + d * 0.4)))
        for o in (b, t):
            xform(o, rx=rx, ry=ry, t=(x, y, 0.3))
        bodies.append(b); tips.append(t)
    join(bodies, "Crystals")
    join(tips, "Glow_Tips")


for key, band in (("A", VIOLET), ("B", PUMPKIN)):
    if want("Crystal_" + key):
        reset(ATLAS)
        crystals(band)
        ship("AST-176", f"HW_Crystal_Cursed_{key}")
