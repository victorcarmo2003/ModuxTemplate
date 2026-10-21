# Halloween lobby kit helpers (AST-167..176, DEC-346). Run inside headless Blender after toylib:
#   exec(open(TOYLIB).read()); exec(open("tools/halloween/hwlib.py").read())
# Units = studs, Blender +Y = front, pivot = base centre (hanging pieces: hang point).
import bpy, bmesh, math, os
from mathutils import Vector

ROOT = "D:/UserData/Documents/ModuxGames/Sell Hotdogs/"
ATLAS = ROOT + "Assets/textures/props/T_HW_Atlas.png"
BLEND_DIR = ROOT + "Assets/blender/props/"
RENDER_DIR = ROOT + "docs/art/mockups/halloween-2026-10-21/renders/"

# Atlas bands (row, col) of T_HW_Atlas (tools/halloween/gen_atlas.py)
PUMPKIN, PUMPKIN_DK, STEM, AMBER, VIOLET, VIOLET_DK, IRON, POTION = (0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (0, 5), (0, 6), (0, 7)
CREAM, INK, WOOD, MAGENTA, WHITE, STONE, PINK, TEAL = (1, 0), (1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7)
WOOD_DK, ORANGE, YELLOW, DEEP, LILAC, MINT, SAND, PLUM = (2, 0), (2, 1), (2, 2), (2, 3), (2, 4), (2, 5), (2, 6), (2, 7)


def lathe(name, profile, band, segs=16, center=(0, 0, 0), smooth=True):
    """Revolve a (r, z) profile around Z. r = 0 points become single pole vertices."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((center[0], center[1], center[2] + z))])
        else:
            rings.append([bm.verts.new((center[0] + r * math.cos(2 * math.pi * j / segs),
                                        center[1] + r * math.sin(2 * math.pi * j / segs), center[2] + z)) for j in range(segs)])
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for j in range(segs):
            if len(a) == 1:
                bm.faces.new((a[0], b[(j + 1) % segs], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[j], a[(j + 1) % segs], b[0]))
            else:
                bm.faces.new((a[j], a[(j + 1) % segs], b[(j + 1) % segs], b[j]))
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(bm, name, band, smooth=smooth)


def lobed(name, d, h, band, lobes=8, segs=24, rings=8, depth=0.12, dip=0.18, center=(0, 0, 0)):
    """Pumpkin body: lobed squashed sphere, base at z = 0, dimples at both poles."""
    R = d / 2
    bm = bmesh.new()
    cx, cy, cz = center
    bottom = bm.verts.new((cx, cy, cz + dip * h * 0.5))
    top = bm.verts.new((cx, cy, cz + h - dip * h))
    grid = []
    for i in range(1, rings):
        th = math.pi * i / rings
        row = []
        for j in range(segs):
            ph = 2 * math.pi * j / segs
            k = 1 - depth * (1 - math.cos(lobes * ph)) / 2
            r = R * math.sin(th) * k
            z = h * (0.5 - 0.5 * math.cos(th))
            row.append(bm.verts.new((cx + r * math.cos(ph), cy + r * math.sin(ph), cz + z)))
        grid.append(row)
    for j in range(segs):
        bm.faces.new((bottom, grid[0][(j + 1) % segs], grid[0][j]))
        bm.faces.new((top, grid[-1][j], grid[-1][(j + 1) % segs]))
    for a, b in zip(grid, grid[1:]):
        for j in range(segs):
            bm.faces.new((a[j], a[(j + 1) % segs], b[(j + 1) % segs], b[j]))
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(bm, name, band, smooth=True)


def slab(name, pts, thick, band, y=0.0, surface=None, lift=0.03):
    """Extrude a 2D polygon drawn in the XZ plane (x right, z up) along +Y (front).
    surface(x, z) -> y of a curved front surface: the slab then hugs it (front = surface + lift, back = front - thick)."""
    bm = bmesh.new()
    fr, bk = [], []
    for x, z in pts:
        yf = (surface(x, z) + lift) if surface else y + thick / 2
        fr.append(bm.verts.new((x, yf, z)))
        bk.append(bm.verts.new((x, yf - thick, z)))
    n = len(pts)
    caps = [bm.faces.new(fr), bm.faces.new(list(reversed(bk)))]
    bmesh.ops.triangulate(bm, faces=caps, quad_method="BEAUTY", ngon_method="EAR_CLIP")  # concave outlines (bat, moon)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bk[i], bk[j], fr[j], fr[i]))
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(bm, name, band)


def circle_pts(cx, cz, rx, rz, n=12, a0=0.0, a1=2 * math.pi):
    return [(cx + rx * math.cos(a0 + (a1 - a0) * i / n), cz + rz * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n)]


def rotz(o, deg):
    o.data.transform(__import__("mathutils").Matrix.Rotation(math.radians(deg), 4, "Z"))


def move(o, v):
    o.data.transform(__import__("mathutils").Matrix.Translation(Vector(v)))


def ship(ast, name, renders=True, dirs=((0, 1, 0.35), (1, 0, 0.35), (0.8, 1, 0.6))):
    """Save the scene as Assets/blender/props/<ast>_<name>.blend and render front / side / 3-quarter previews."""
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    tris = sum(tris_of(o) for o in meshes)
    lo, hi = bbox(meshes)
    stem = f"{ast}_{name}"
    if renders:
        for k, d in zip(("front", "side", "q34"), dirs):
            render(f"{RENDER_DIR}{stem}_{k}.png", meshes, direction=d, res=(480, 480), world=(0.22, 0.2, 0.3))
    for o in list(bpy.data.objects):
        if o.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(o, do_unlink=True)
    save_blend(f"{BLEND_DIR}{stem}.blend")
    print(f"SHIP {stem} tris={tris} size=({hi.x - lo.x:.2f}, {hi.y - lo.y:.2f}, {hi.z - lo.z:.2f}) zmin={lo.z:.2f} parts={[o.name for o in meshes]}")


print("hwlib loaded")
