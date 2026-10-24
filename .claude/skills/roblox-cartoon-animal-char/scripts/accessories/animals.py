import os
# AST-053 HotDog Crew animal pieces: Head_<A>, Ears_<A>, Tail_<A> (+ Shell_Turtle, Beak_Owl) over the CrewBase body.
# Run: ANIMAL=Dog sh bl.sh animals.py   (no ANIMAL = all eight)
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import crewlib
from crewlib import *

ONLY = [a for a in os.environ.get("ANIMAL", "").split(",") if a]
NORENDER = os.environ.get("NORENDER") == "1"

BLACK = (0, 0, 0.62, 0.95)
WHITE = (0, 4, 0.0, 0.28)
WARMW = (1, 4, 0.0, 0.25)
PINK = (2, 5, 0.04, 0.32)
HILITE = (0, 4, 0.0, 0.04)

HEAD_R = (0.0, 0.375, 1.0, 1.0)
EARS_R = (0.0, 0.0, 0.5, 0.375)
TAIL_R = (0.5, 0.0, 0.75, 0.375)
EXTRA_R = (0.75, 0.0, 1.0, 0.375)

ROT = lambda ax, d: Matrix.Rotation(math.radians(d), 4, ax)
T = Matrix.Translation


# ------------------------------------------------------------------ shared face features
def eyes(z=4.65, x=0.50, rx=0.13, rz=0.165, band=BLACK, hl=True):
    out = []
    for s in (-1, 1):
        out.append((bm_cyl(rx, rz, 0.14, 8, T((s * x, 0.93, z))), band))
        if hl:
            out.append((bm_cyl(0.045, 0.045, 0.06, 6, T((s * x - 0.035, 0.995, z + 0.06))), HILITE))
    return out


def mouth(yf, z, band=BLACK, w=0.15, ang=17):
    out = []
    for s in (-1, 1):
        M = T((s * 0.065, yf - 0.005, z)) @ ROT("Y", -s * ang)
        out.append((bm_box((w, 0.04, 0.045), M), band))
    return out


def rbox(size, c, band, r=0.1, seg=2):
    return (bm_box(size, T(c), r=r, seg=seg), band)


def side_tufts(base_c, hx, hy, tip, band):
    out = []
    for s in (1, -1):
        bm = bm_loft([ring_rrect(base_c, (0, 1, 0), (0, 0, 1), hx, hy, 0.04), Vector(tip)])
        if s < 0:
            mirror_x(bm)
        out.append((bm, band))
    return out


def plate_on_face(p1, p2, p3, pts_xz, front=0.035, back=0.03):
    """Thin prism lying on the plane (p1,p2,p3) (oriented to +y), outline given in (x, z)."""
    p1, p2, p3 = Vector(p1), Vector(p2), Vector(p3)
    n = (p2 - p1).cross(p3 - p1).normalized()
    if n.y < 0:
        n = -n
    on = [Vector((x, p1.y - (n.x * (x - p1.x) + n.z * (z - p1.z)) / n.y, z)) for x, z in pts_xz]
    return bm_loft([[p - n * back for p in on], [p + n * front for p in on]])


# ------------------------------------------------------------------ ears (right side, ear-local frame; mirrored)
def ear_pointed(hx0, hy0, hx1, hy1, tip, inner_band, outer_band, plate_xz, tip_split=None, tip_band=None):
    tip = Vector(tip)
    r0 = ring_rrect((0, 0, -0.15), (1, 0, 0), (0, 1, 0), hx0, hy0, 0.05)
    r1 = ring_rrect((0.01, 0, 0.15), (1, 0, 0), (0, 1, 0), hx1, hy1, 0.05)
    rings = [r0, r1]
    if tip_split:
        t = (tip_split - 0.15) / (tip.z - 0.15)
        rings.append([p.lerp(tip, t) for p in r1])
    rings.append(tip)
    bm = bm_loft(rings)
    lay = bm.faces.layers.int["seg"]
    def spec(f, b, _lay=None):
        s = f[b.faces.layers.int["seg"]]
        if tip_split and s == 2:
            return tip_band
        return outer_band
    e = hx1 - 0.05
    plate = plate_on_face((0.01 - e, hy1, 0.15), (0.01 + e, hy1, 0.15), tip, plate_xz)
    return [(bm, spec), (plate, inner_band)]


def ear_rabbit(outer, inner):
    L = lambda z: -math.tan(math.radians(30)) * max(z, 0)
    spec = [(-0.15, .17, .1), (0.1, .17, .1), (0.5, .22, .1), (1.0, .22, .1), (1.3, .16, .09), (1.45, .08, .06)]
    rings = [ring_rrect((L(z), 0, z), (1, 0, 0), (0, 1, 0), hx, hy, 0.06) for z, hx, hy in spec]
    bm = bm_loft(rings)
    pts = [(-.08, .3), (-.12, .55), (-.12, .95), (-.06, 1.15), (.06, 1.15), (.12, .95), (.12, .55), (.08, .3)]
    on = [Vector((x + L(z), 0, z)) for x, z in pts]
    plate = bm_loft([[p + Vector((0, 0.07, 0)) for p in on], [p + Vector((0, 0.13, 0)) for p in on]])
    return [(bm, outer), (plate, inner)]


def ear_round(outer, inner=None):
    out = [(bm_box((0.36, 0.18, 0.32), T((0, 0, -0.04)), r=0.04, seg=1), outer),
           (bm_cyl(0.36, 0.36, 0.22, 10, T((0.02, 0, 0.32))), outer)]
    if inner:
        out.append((bm_cyl(0.2, 0.2, 0.06, 10, T((0.03, 0.115, 0.30))), inner))
    return out


def ear_tuft(band, tip_band):
    r0 = ring_rrect((0, 0, -0.15), (1, 0, 0), (0, 1, 0), 0.2, 0.12, 0.04)
    r1 = ring_rrect((0.02, 0, 0.2), (1, 0, 0), (0, 1, 0), 0.17, 0.10, 0.04)
    bm = bm_loft([r0, r1, Vector((0.22, -0.02, 0.62))])
    return [(bm, lambda f, b: tip_band if f[b.faces.layers.int["seg"]] == 1 else band)]


def ear_dog(band):
    """World-space right floppy ear hanging under the cap rim (no hole needed)."""
    spec = [(4.97, 1.08, .12, .27), (4.80, 1.24, .11, .33), (4.52, 1.31, .11, .35), (4.33, 1.31, .10, .29), (4.25, 1.29, .08, .17)]
    rings = [ring_rrect((cx, -0.05, z), (1, 0, 0), (0, 1, 0), hx, hy, 0.07) for z, cx, hx, hy in spec]
    return [(bm_loft(rings), band)]


# ------------------------------------------------------------------ animals
def front_lower(S, P, zcut, xcut=None):
    def spec(f, bm):
        c, n = f.calc_center_median(), f.normal
        if n.y > 0.3 and c.z < zcut and (xcut is None or abs(c.x) < xcut):
            return S
        return P
    return spec


A = {}

# Dog: brown + white blaze/muzzle, floppy ears under the plain Cap
P, S = (0, 6, 0.05, 0.45), WARMW
A["Dog"] = dict(
    P=P, S=S, hand=P, cap="Cap",
    cuts=[((0.34, 0, 0), (1, 0, 0)), ((-0.34, 0, 0), (1, 0, 0)), ((0, 0, 4.62), (0, 0, 1))],
    head_spec=(lambda P, S: (lambda f, bm: S if (f.normal.y > 0.3 and (abs(f.calc_center_median().x) < 0.34 or f.calc_center_median().z < 4.62)) or f.normal.z < -0.6 else P))(P, S),
    feats=lambda P=P, S=S: eyes() + [rbox((0.72, 0.44, 0.44), (0, 1.05, 4.38), S, r=0.14),
                            rbox((0.30, 0.16, 0.20), (0, 1.27, 4.53), BLACK, r=0.06, seg=1)] + mouth(1.27, 4.34),
    ears=("world", lambda P=P, S=S: ear_dog((0, 6, 0.35, 0.85))),
    tail=lambda P=P, S=S: [(tube([(0, -0.42, 2.46), (0, -0.72, 2.56), (0, -0.92, 2.8), (0, -0.98, 3.08), (0, -0.97, 3.24)],
                        [0.16, 0.15, 0.13, 0.11, 0]), lambda f, b, P=P, S=S: S if f[b.faces.layers.int["seg"]] >= 3 else P)],
)

# Cat: grey + white muzzle, pointed ears with pink inner, long S tail
P, S = (0, 3, 0.40, 0.85), WHITE
A["Cat"] = dict(
    P=P, S=S, hand=S, cap="Cap_EarsUp",
    cuts=[((0, 0, 4.55), (0, 0, 1)), ((0.5, 0, 0), (1, 0, 0)), ((-0.5, 0, 0), (1, 0, 0))],
    head_spec=front_lower(S, P, 4.55, 0.5),
    feats=lambda P=P, S=S: eyes() + [rbox((0.34, 0.30, 0.28), (0.15, 1.02, 4.42), S), rbox((0.34, 0.30, 0.28), (-0.15, 1.02, 4.42), S),
                            rbox((0.18, 0.10, 0.11), (0, 1.17, 4.56), PINK, r=0.04, seg=1)]
                  + side_tufts((1.05, 0.15, 4.42), 0.18, 0.16, (1.36, 0.22, 4.25), P),
    ears=("local", lambda P=P, S=S: ear_pointed(.25, .15, .24, .145, (0.07, -0.02, 0.72), PINK, P,
                                       [(-0.12, 0.27), (0.15, 0.27), (0.06, 0.6)])),
    tail=lambda P=P, S=S: [(tube([(0, -0.42, 2.45), (0.08, -0.8, 2.48), (0.22, -1.12, 2.68), (0.32, -1.22, 3.0), (0.3, -1.12, 3.33),
                         (0.22, -1.02, 3.48), (0.17, -0.97, 3.52)], [0.12, 0.12, 0.12, 0.12, 0.11, 0.08, 0]),
                   lambda f, b, P=P: (0, 3, 0.75, 0.95) if f[b.faces.layers.int["seg"]] >= 4 else P)],
)

# Rabbit: white, pink inner ears/nose, cheek puffs + teeth, pompom tail
P, S = WHITE, WARMW
A["Rabbit"] = dict(
    P=P, S=S, hand=P, cap="Cap_EarsUp",
    cuts=[((0, 0, 4.5), (0, 0, 1))],
    head_spec=front_lower(S, P, 4.5, None),
    feats=lambda P=P, S=S: eyes() + [rbox((0.34, 0.30, 0.28), (0.15, 1.02, 4.42), P), rbox((0.34, 0.30, 0.28), (-0.15, 1.02, 4.42), P),
                            rbox((0.18, 0.10, 0.11), (0, 1.17, 4.56), PINK, r=0.04, seg=1),
                            rbox((0.16, 0.08, 0.13), (0, 1.11, 4.25), WHITE, r=0.02, seg=1)],
    ears=("local", lambda P=P, S=S: ear_rabbit(P, PINK)),
    tail=lambda P=P, S=S: [(bm_ico(0.3, (0, -0.68, 2.62), sub=2), P)],
)

# Fox: orange + white cheeks/muzzle, black ear tips, big bushy tail with white tip
P, S = (0, 5, 0.05, 0.40), WHITE
A["Fox"] = dict(
    P=P, S=S, hand=P, cap="Cap_EarsUp",
    cuts=[((0, 0, 4.5), (0, 0, 1))],
    head_spec=(lambda P, S: (lambda f, bm: S if (f.calc_center_median().z < 4.5 and f.normal.y > -0.3) else P))(P, S),
    feats=lambda P=P, S=S: eyes() + [
        (bm_loft([ring_rrect((0, 0.85, 4.36), (1, 0, 0), (0, 0, 1), 0.36, 0.22, 0.08),
                  ring_rrect((0, 1.15, 4.33), (1, 0, 0), (0, 0, 1), 0.22, 0.15, 0.06),
                  ring_rrect((0, 1.33, 4.31), (1, 0, 0), (0, 0, 1), 0.10, 0.08, 0.03)]), S),
        rbox((0.18, 0.12, 0.13), (0, 1.36, 4.34), BLACK, r=0.04, seg=1)]
        + side_tufts((1.05, 0.1, 4.36), 0.22, 0.2, (1.45, 0.2, 4.12), S),
    ears=("local", lambda P=P, S=S: ear_pointed(.27, .16, .26, .155, (0.09, -0.02, 0.86), WHITE, P,
                                       [(-0.13, 0.28), (0.16, 0.28), (0.06, 0.56)], tip_split=0.6, tip_band=BLACK)),
    tail=lambda P=P, S=S: [(tube([(0, -0.42, 2.42), (0, -0.75, 2.55), (0.1, -1.12, 2.72), (0.22, -1.4, 3.05), (0.28, -1.5, 3.4),
                         (0.25, -1.42, 3.68), (0.2, -1.32, 3.82)], [0.14, 0.3, 0.4, 0.42, 0.36, 0.2, 0], n=8),
                   lambda f, b, P=P, S=S: S if f[b.faces.layers.int["seg"]] >= 4 or f[b.faces.layers.int["seg"]] == -2 else P)],
)

# Bear: brown + tan muzzle, round ears with tan inner, ball tail
P, S = (0, 6, 0.35, 0.80), (1, 5, 0.10, 0.45)
A["Bear"] = dict(
    P=P, S=S, hand=P, cap="Cap_EarsUp",
    cuts=[],
    head_spec=P,
    feats=lambda P=P, S=S: eyes() + [rbox((0.78, 0.40, 0.48), (0, 1.05, 4.38), S, r=0.18),
                            rbox((0.32, 0.15, 0.20), (0, 1.25, 4.52), BLACK, r=0.07, seg=1)] + mouth(1.25, 4.31),
    ears=("local", lambda P=P, S=S: ear_round(P, S)),
    tail=lambda P=P, S=S: [(bm_sphere(0.22, (0, -0.62, 2.55)), P)],
)

# Panda: white + black ears/eye patches/arms
P, S = WHITE, (0, 0, 0.60, 0.95)
A["Panda"] = dict(
    P=P, S=S, hand=S, cap="Cap_EarsUp",
    cuts=[],
    head_spec=P,
    feats=lambda P=P, S=S: [(bm_cyl(0.22, 0.25, 0.1, 10, T((s * 0.46, 0.925, 4.64)) @ ROT("Y", s * 25)), S) for s in (-1, 1)]
                  + eyes() + [rbox((0.62, 0.34, 0.40), (0, 1.02, 4.36), P, r=0.15),
                              rbox((0.30, 0.15, 0.19), (0, 1.20, 4.49), BLACK, r=0.06, seg=1)] + mouth(1.19, 4.29),
    ears=("local", lambda P=P, S=S: ear_round(S)),
    tail=lambda P=P, S=S: [(bm_sphere(0.22, (0, -0.62, 2.55)), P)],
)

# Turtle: green + yellow-olive chin, no ears (plain Cap), shell on the back + stub tail
P, S = (2, 1, 0.10, 0.45), (2, 0, 0.05, 0.35)
SHELL, SHELL_LT = (2, 1, 0.62, 0.95), (2, 1, 0.30, 0.50)


def shell(S=S):
    rings = []
    for y, rx, rz in ((-0.46, .86, .74), (-0.56, .92, .80), (-0.68, .92, .80), (-0.74, .80, .70), (-0.92, .62, .54), (-1.04, .36, .32)):
        rings.append(ring_ellipse((0, y, 3.05), (1, 0, 0), (0, 0, 1), rx, rz, 12, phase=0.0))
    bm = bm_loft(rings)
    def spec(f, b):
        s = f[b.faces.layers.int["seg"]]
        if s in (0, 1, -1):
            return S
        if s == -2:
            return SHELL_LT
        return SHELL
    plate = bm_cyl(0.3, 0.27, 0.06, 6, T((0, -1.05, 3.05)) @ ROT("Y", 30))
    return [(bm, spec), (plate, SHELL_LT)]


A["Turtle"] = dict(
    P=P, S=S, hand=P, cap="Cap",
    cuts=[((0, 0, 4.45), (0, 0, 1))],
    head_spec=(lambda P, S: (lambda f, bm: S if (f.normal.y > 0.3 and f.calc_center_median().z < 4.45) or f.normal.z < -0.6 else P))(P, S),
    feats=lambda P=P, S=S: eyes() + [(bm_cyl(0.035, 0.035, 0.06, 6, T((s * 0.08, 0.95, 4.52))), BLACK) for s in (-1, 1)]
                  + [(bm_box((0.3, 0.04, 0.045), T((s * 0.14, 0.955, 4.37)) @ ROT("Y", -s * 12)), BLACK) for s in (-1, 1)],
    ears=None,
    tail=lambda P=P, S=S: [(tube([(0, -0.5, 2.36), (0, -0.75, 2.3), (0, -0.95, 2.2)], [0.08, 0.07, 0]), P)],
    extras={"Shell_Turtle": dict(make=shell, att="BodyBackAttachment", pos=(0, -0.5, 3.0), region=EARS_R)},
)

# Owl: taupe + cream facial disc, big ringed eyes, ear tufts, beak (accessory), tail feathers
P, S = (0, 7, 0.05, 0.50), (1, 4, 0.10, 0.45)
BEAK, RING = (2, 3, 0.55, 0.95), (2, 3, 0.20, 0.45)


def owl_feathers():
    out = []
    for fan in (-24, 0, 24):
        M = T((0, -0.48, 2.62)) @ ROT("Y", fan) @ ROT("X", -55) @ T((0, 0, -0.275))
        out.append((bm_box((0.24, 0.08, 0.55), M, r=0.03, seg=1), (0, 7, 0.30, 0.90)))
    return out


def owl_beak():
    bm = bm_loft([ring_rrect((0, 0.93, 4.5), (1, 0, 0), (0, 0, 1), 0.13, 0.11, 0.04),
                  ring_rrect((0, 1.08, 4.44), (1, 0, 0), (0, 0, 1), 0.10, 0.09, 0.03),
                  Vector((0, 1.13, 4.27))])
    return [(bm, BEAK)]


A["Owl"] = dict(
    P=P, S=S, hand=P, cap="Cap_EarsUp",
    cuts=[],
    head_spec=P,
    feats=lambda P=P, S=S: [(bm_cyl(0.86, 0.36, 0.1, 14, T((0, 0.925, 4.55))), S)]
                  + [(bm_cyl(0.19, 0.19, 0.1, 10, T((s * 0.40, 0.95, 4.60))), RING) for s in (-1, 1)]
                  + [(bm_cyl(0.11, 0.11, 0.1, 8, T((s * 0.40, 0.975, 4.60))), BLACK) for s in (-1, 1)]
                  + [(bm_cyl(0.04, 0.04, 0.06, 6, T((s * 0.40 - 0.04, 1.02, 4.65))), HILITE) for s in (-1, 1)],
    ears=("local", lambda P=P, S=S: ear_tuft(P, (0, 7, 0.45, 0.95))),
    tail=owl_feathers,
    extras={"Beak_Owl": dict(make=owl_beak, att="SnoutAttachment", pos=(0, FRONT, HC - 0.225), region=EXTRA_R)},
)

ORDER = ["Dog", "Cat", "Rabbit", "Fox", "Bear", "Panda", "Turtle", "Owl"]

HEAD_ATT = {"HatAttachment": (0, 0, TOPZ), "HairAttachment": (0, 0, TOPZ), "FaceFrontAttachment": (0, FRONT, HC),
            "FaceCenterAttachment": (0, 0, HC), "EarLeftAttachment": (-SOCK_X, 0, SOCK_Z), "EarRightAttachment": (SOCK_X, 0, SOCK_Z),
            "SnoutAttachment": (0, FRONT, HC - 0.225)}
ATT_ORI = {"EarLeftAttachment": [0, 0, 30], "EarRightAttachment": [0, 0, -30]}
ATT_ROT_BL = {"EarLeftAttachment": (0, math.radians(-TILT), 0), "EarRightAttachment": (0, math.radians(TILT), 0)}
BODY = ["Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Apron"]


def build_list(items, name):
    objs = []
    for i, (bm, spec) in enumerate(items):
        objs.append(to_obj(f"{name}_p{i}", bm, spec))
    return join(objs, name)


def att_empty(name, pos, parent, key):
    e = empty(name, pos, parent=parent, size=0.2)
    if key in ATT_ROT_BL:
        e.rotation_euler = ATT_ROT_BL[key]
    return e


def remap_hands(o, band):
    uv = o.data.uv_layers["UVMap"].data
    r0, c0, lo0, hi0 = FUR_BASE
    for l in uv:
        u, v = l.uv
        if abs(u - (c0 + 0.5) / 8) < 1e-4 and r0 <= (1 - v) * 4 <= r0 + 1:
            frac = (1 - v) * 4 - r0
            t = (hi0 - frac) / (hi0 - lo0)
            l.uv = band_uv(band, min(1, max(0, t)))


def load_ref(cap):
    with bpy.data.libraries.load(BASE) as (src, dst):
        dst.objects = BODY + (["Cap"] if cap == "Cap" else [])
    objs = list(dst.objects)
    if cap != "Cap":
        with bpy.data.libraries.load(CAPUP_BLEND) as (src, dst2):
            dst2.objects = ["Cap_EarsUp"]
        objs += list(dst2.objects)
    for o in objs:
        bpy.context.scene.collection.objects.link(o)
        o.name = "REF_" + ("Cap" if o.name.startswith("Cap") else o.name)
    bpy.context.view_layer.update()
    return {o.name: o for o in objs}


def build(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    crewlib.MAT = None
    D = A[name]
    ref = load_ref(D["cap"])
    for o in ref.values():
        for p in o.data.polygons:
            p.use_smooth = False
    get_mat()
    pieces = {}
    # head
    main = to_obj("Head_main", head_bm(D["cuts"]), D["head_spec"], zr=(HZ0, TOPZ))
    feats = [to_obj(f"Head_f{i}", bm, sp) for i, (bm, sp) in enumerate(D["feats"]())]
    head = join([main] + feats, "Head_" + name)
    set_origin(head, (0, 0, 4.0))
    pieces[head.name] = dict(obj=head, att=None, region=HEAD_R)
    # ears
    if D["ears"]:
        kind, fn = D["ears"]
        objs = []
        for side in (1, -1):
            for i, (bm, sp) in enumerate(fn()):
                if kind == "local":
                    xform(bm, ear_frame(1))
                if side < 0:
                    mirror_x(bm)
                objs.append(to_obj(f"Ear{side}_{i}", bm, sp))
        ears = join(objs, "Ears_" + name)
        set_origin(ears, HEAD_ATT["EarLeftAttachment"])
        pieces[ears.name] = dict(obj=ears, att="EarLeftAttachment", pos=HEAD_ATT["EarLeftAttachment"], region=EARS_R)
    # tail
    tail = build_list(D["tail"](), "Tail_" + name)
    set_origin(tail, (0, -0.5, 2.25))
    pieces[tail.name] = dict(obj=tail, att="TailAttachment", pos=(0, -0.5, 2.25), region=TAIL_R)
    for ename, ed in D.get("extras", {}).items():
        o = build_list(ed["make"](), ename)
        set_origin(o, ed["pos"])
        pieces[ename] = dict(obj=o, att=ed["att"], pos=ed["pos"], region=ed["region"])
    # attachments
    for an, p in HEAD_ATT.items():
        att_empty(an, p, head, an)
    for pn, pd in pieces.items():
        if pd["att"]:
            att_empty(f"{pn}_{pd['att']}", pd["pos"], pd["obj"], pd["att"])
    # paint UVs (one 512 sheet per animal, fixed region per piece type)
    for pn, pd in pieces.items():
        paint_uv(pd["obj"], pd["region"])
    uvbad, uvused = uv_overlap_px([pd["obj"] for pd in pieces.values()])
    # checks
    capo = ref["REF_Cap"]
    allobjs = list(ref.values()) + [pd["obj"] for pd in pieces.values()]
    no_touch = [(head.name, "REF_Cap", {0})]
    for pn in pieces:
        if pn != head.name:
            no_touch.append((pn, "REF_Cap", set()))
            for b in ("REF_Left Arm", "REF_Right Arm", "REF_Left Leg", "REF_Right Leg"):
                no_touch.append((pn, b, set()))
    zf, bad, inter = check(allobjs, no_touch)
    # run-cycle extreme: legs +-45, arms -+45 around the R6 joints
    poses = {}
    rest = {o.name: o.matrix_world.copy() for o in ref.values()}
    for tag, rot in (("run60", {"REF_Right Leg": 60, "REF_Left Leg": -60, "REF_Right Arm": -60, "REF_Left Arm": 60}),
                     ("run60b", {"REF_Right Leg": -60, "REF_Left Leg": 60, "REF_Right Arm": 60, "REF_Left Arm": -60})):
        for nm, d in rot.items():
            o = ref[nm]
            pv = o.matrix_world.translation.copy()
            o.matrix_world = T(pv) @ ROT("X", d) @ T(-pv) @ o.matrix_world
        bpy.context.view_layer.update()
        nt = [(pn, b, set()) for pn in pieces if pn != head.name for b in rot]
        _, bad2, _ = check([ref[b] for b in rot] + [pd["obj"] for pn, pd in pieces.items() if pn != head.name], nt)
        poses[tag] = bad2
        for nm in rot:
            ref[nm].matrix_world = rest[nm]
    bpy.context.view_layer.update()
    # numbers
    bpy.context.view_layer.update()
    info = {"pieces": {}, "cap": D["cap"], "zfight_pairs": len(zf), "zfight": zf[:10], "touch_rest": bad, "touch_run": poses,
            "uv_overlap_texels": uvbad, "uv_sheet_used": round(uvused, 3)}
    for pn, pd in pieces.items():
        o = pd["obj"]; mn, mx = bbox([o])
        info["pieces"][pn] = {"tris": tris(o), "size_bl": [round(x, 3) for x in (mx - mn)], "center_bl": [round(x, 3) for x in (mn + mx) / 2],
                              "att": pd["att"], "att_pos_bl": list(pd.get("pos", (0, 0, 0))), "uv_region": pd["region"]}
    body_tris = sum(tris(ref[n]) for n in ["REF_" + b for b in BODY])
    info["body_tris_no_head"] = body_tris
    info["cap_tris"] = tris(capo)
    info["animal_tris"] = sum(p["tris"] for p in info["pieces"].values())
    info["total_tris"] = body_tris + info["cap_tris"] + info["animal_tris"]
    print("INFO", name, json.dumps({k: v for k, v in info.items() if k != "pieces"}))
    for pn, p in info["pieces"].items():
        print("  PIECE", pn, p["tris"], p["size_bl"])
    # preview recolor of the forearms/hands
    for nm in ("REF_Left Arm", "REF_Right Arm"):
        remap_hands(ref[nm], D["hand"])
    # UV polygons for the layout sheet
    json.dump(uv_polys([pd["obj"] for pd in pieces.values()]), open(OUTDIR + f"/uv_{name}.json", "w"))
    # save
    exp = []
    for pd in pieces.values():
        exp.append(pd["obj"]); exp += list(pd["obj"].children)
    save("character", f"AST-053_Animal_{name}", exp)
    json.dump(info, open(OUTDIR + f"/info_{name}.json", "w"), indent=1)
    if not NORENDER:
        render_views(name)


def render_views(name):
    scn = bpy.context.scene
    scn.render.film_transparent = True
    try:
        scn.render.engine = "BLENDER_EEVEE"
    except TypeError:
        pass
    cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam")); scn.collection.objects.link(cam)
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN")); scn.collection.objects.link(key)
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN")); scn.collection.objects.link(fill)
    scn.camera = cam; cam.data.lens = 50
    scn.render.resolution_x, scn.render.resolution_y = 420, 560
    if scn.world is None:
        scn.world = bpy.data.worlds.new("W")
    scn.world.color = (0.75, 0.78, 0.85)
    for suffix, d, tgt, dist in (("front", (0, 1, 0.1), (0, 0, 3.5), 13.2), ("34", (0.85, 1, 0.3), (0, 0, 3.5), 13.2),
                                 ("back", (-0.75, -1, 0.3), (0, 0, 3.5), 13.2), ("face", (0.35, 1, 0.25), (0, 0.3, 4.75), 5.2),
                                 ("top", (0.5, 0.4, 1.0), (0, 0, 5.2), 5.5)):
        tgt = Vector(tgt); dv = Vector(d).normalized(); loc = tgt + dv * dist
        key.data.energy = 2.6; fill.data.energy = 1.6
        key.rotation_euler = (dv + Vector((0.35, 0, 0.7))).normalized().to_track_quat("Z", "Y").to_euler()
        fill.rotation_euler = (Vector((dv.x * 0.3 - 0.4, dv.y, 0.15))).normalized().to_track_quat("Z", "Y").to_euler()
        cam.location = loc
        cam.rotation_euler = (tgt - loc).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = OUTDIR + f"/r_{name}_{suffix}.png"
        bpy.ops.render.render(write_still=True)


for nm in (ONLY or ORDER):
    build(nm)
print("ALL DONE")
