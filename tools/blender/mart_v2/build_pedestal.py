# AST-105 Display pedestal for the Gear Stand (MAP-01 18.4): Quaternius "Column Round" (CC0, Poly Pizza) scaled to a
# 1.6 top, shaft stretched (only the shaft grows) to 3.0, flat materials remapped onto KitchenPack atlas bands by
# height zone, plus a separate "Ring" (Neon in Roblox) on the top. Variants: B (Teal ring) and S1 (Mustard, + Lamp).
import os, sys
HERE = os.path.dirname(os.path.abspath(sys.argv[sys.argv.index("--python") + 1]))
exec(open(os.path.join(HERE, "common.py"), encoding="utf-8").read())
SRC = ROOT + "Assets/PolyPizza/ColumnRound_n8ZvVFcJhl/ColumnRound.glb"
H, TOP = 3.0, 1.6


def band_faces(o, zones):
    """zones = [(z_max, band)] ascending; each face gets the band of its centre height, gradient over that zone."""
    me = o.data
    uv = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    cols, rows = GRID
    lo_z = 0.0
    bounds = []
    for zmax, band in zones:
        bounds.append((lo_z, zmax, band)); lo_z = zmax
    for p in me.polygons:
        zc = p.center.z
        z0, z1, band = next((b for b in bounds if zc <= b[1]), bounds[-1])
        row, col, lo, hi = band
        for li in p.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            t = min(1, max(0, (z - z0) / (z1 - z0)))
            uv.data[li].uv = ((col + 0.5) / cols, 1 - (row + hi - t * (hi - lo)) / rows)
    me.materials.clear(); me.materials.append(mat)


def build(variant):
    reset(ATLAS)
    setup_render()
    ms = import_piece(SRC)
    for o in [o for o in ms if o.name.startswith("Cube")]:  # stray default cube inside the .glb
        ms.remove(o); bpy.data.objects.remove(o, do_unlink=True)
    body = join(ms, "Body") if len(ms) > 1 else ms[0]
    body.name = "Body"
    lo, hi = bbox([body])
    s = TOP / max(hi.x - lo.x, hi.y - lo.y)
    place_piece([body], scale=s)
    lo, hi = bbox([body])
    h0 = hi.z
    # cut in the largest vertex-free gap of the middle third (the plain shaft) and lift everything above it
    zs = sorted({round(v.co.z, 4) for v in body.data.vertices})
    gaps = [(zs[i + 1] - zs[i], (zs[i] + zs[i + 1]) / 2) for i in range(len(zs) - 1) if 0.3 * h0 < zs[i] < 0.8 * h0]
    cut = max(gaps)[1]
    for v in body.data.vertices:
        if v.co.z > cut:
            v.co.z += H - h0
    body.data.update()
    # collar at the shaft/block junction (hides the original low-poly seam, adds a trim line)
    ztop = min(v.co.z for v in body.data.vertices if v.co.z > cut)
    r = max(math.hypot(v.co.x, v.co.y) for v in body.data.vertices if abs(v.co.z - ztop) < 1e-3)
    collar = cyl("Collar", 2 * r * 1.12, 0.16, (0, 0, ztop - 0.05), "z", (1, 6, 0.10, 0.50) if variant == "S1" else TEAL, segs=12)
    # zones (from the stretched geometry): base, shaft, collar+cap
    zs = sorted(v.co.z for v in body.data.vertices)
    accent = TEAL_D if variant == "B" else (1, 6, 0.10, 0.70)
    band_faces(body, [(0.62, accent), (H - 0.55, CREAM), (H - 0.22, accent), (H + 1, (1, 4, 0.0, 0.25))])
    body = join([body, collar], "Body")
    # Neon ring laid on the top surface
    ring = torus("Ring", TOP * 0.36, 0.045, (0, 0, H + 0.03), "z", YELLOW if variant == "S1" else TEAL, segs=20, rsegs=4)
    objs = [body, ring]
    if variant == "S1":
        bulbs = []
        for cx in (-1, 1):
            for cy in (-1, 1):
                b = cyl("Bulb", 0.16, 0.16, (cx * TOP * 0.42, cy * TOP * 0.42, H + 0.1), "z", YELLOW, segs=8, d2=0.06)
                bulbs.append(b)
        lamp = join(bulbs, "Lamp")
        objs.append(lamp)
    empty("Mini_Anchor", (0, 0, H + 1.2))
    empty("Price_Anchor", (0, TOP / 2 + 0.02, H - 0.2))
    empty("Prompt_Buy", (0, 0.5, 4.2))
    recentre(objs)
    info = report(objs)
    stem = "AST-105_Pedestal" + ("" if variant == "B" else "S1")
    atts_json(ROOT + "Assets/import/market/%s_atts.json" % stem,
              {"_note": "Price_Anchor: front face of the cap, tilt the price plate 30 deg; Mini_Anchor: mini centre"})
    views(stem, objs, fp=((0.0, 2.6, 4.5), (0.0, 0.0, 3.4)))
    save_all("market", stem, info)


build("B")
build("S1")
