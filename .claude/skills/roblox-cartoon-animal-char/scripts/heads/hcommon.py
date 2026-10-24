# Shared constants for the AST-053 round heads (Blender + paint scripts). Units = studs, Blender axes (+Y front, Z up).
import os as _os
WORK = _os.environ.get("CHAR_WORK", _os.getcwd()).replace("\\", "/")
PROJECT = _os.environ.get("CHAR_PROJECT", "").replace("\\", "/").rstrip("/") + "/"
SP = WORK
HD = SP + "/heads"
ROOT = PROJECT
TEX = ROOT + "Assets/textures/character/"
ORDER = ["Dog", "Cat", "Rabbit", "Fox", "Bear", "Panda", "Turtle", "Owl"]

# ---- cap line: the head is taller than the old box head; the cap/ear sockets ride up with HatAttachment
CAP_DZ = 0.30                  # Hat/Ear attachments +0.30 vs the old head (cap files unchanged)
BASE_Z = 3.95                  # bottom of the head (same as before; Neck at the torso top z=4.0)
TOP_Z = 5.70 + CAP_DZ          # 6.00
CAP_UNDER = 5.02 + CAP_DZ      # crown underside of Cap / Cap_EarsUp once attached

# ---- features: drawn in "design" coordinates, placed in the world by a uniform scale FS around the anchor
# (ANCH design z 4.60 <-> world z 4.80; the marks of T_Head_* depend on this mapping, keep it fixed)
FS = 1.10
ANCH_DZ, ANCH_WZ = 4.60, 4.80
def w2d(x, z):
    """world (x, z) -> design (x, z)"""
    return x / FS, ANCH_DZ + (z - ANCH_WZ) / FS
def d2w_z(zd):
    return ANCH_WZ + (zd - ANCH_DZ) * FS
def w2d_z(zw):
    return ANCH_DZ + (zw - ANCH_WZ) / FS
# 2026-10-10 fix (eyes "caidos"): eyes closer to the centre and higher, on the flat front of the head
EYE_X, EYE_Z = 0.40, 4.86                       # world eye centre (v3: 4.83 -> 4.86, eyes off the snout slope)
NOSE_Z, MOUTH_Z = 4.47, 4.33                    # world: nose on the snout tip (v3 snout lowered), mouth right below
D_EYE_X, D_EYE_Z = EYE_X / FS, w2d_z(EYE_Z)     # 0.3636, 4.6545
D_NOSE_Z, D_MOUTH_Z = w2d_z(NOSE_Z), w2d_z(MOUTH_Z)   # 4.36, 4.2364

# ---- standard Face_<A> UV v2 (frontal projection, identical on every animal)
K = 0.40                       # UV units per stud (was 0.38) -> 205 px/stud on a 512 sheet
UV_Z0 = EYE_Z                  # world height mapped to V_EYE
V_EYE = 0.30                   # image-space v (from the TOP of the image) of the eye centres (was 0.42)
FACE_RES = 512
FACE_MIN_DOT = 0.50            # Face shell = head faces whose (flat) normal . front >= this, below the cap,
FACE_MAX_X = 1.20              # ... and inside |x| <= 1.20 (u stays in 0.02..0.98, no wrap)
def face_uv(x, z):
    """world (x, z) -> image-space (u, v_from_top); image left = viewer's left (character's right, +x)"""
    return 0.5 - K * x, V_EYE + K * (UV_Z0 - z)
def face_xz(u, v_top):
    return (0.5 - u) / K, UV_Z0 - (v_top - V_EYE) / K

# ---- head lattice: z, half-width a, front depth bf, back depth bb, superellipse exponent n
N_AZ = 26
RING_INSERT = (4.33, 4.51, 4.69, 4.87)   # v3: extra rings in the eye/snout zone (smoother front)
RINGS = [(3.95, .78, .78, .58, 2.2), (4.07, 1.08, .98, .82, 2.3), (4.24, 1.30, 1.09, .96, 2.35),   # v4: fuller front-bottom = round chin
         (4.42, 1.40, 1.11, 1.03, 2.4), (4.60, 1.43, 1.13, 1.06, 2.45), (4.78, 1.42, 1.12, 1.06, 2.55),
         (4.96, 1.37, 1.09, 1.04, 2.7), (5.14, 1.28, 1.04, 1.01, 3.1), (CAP_UNDER, 1.19, .99, .99, 4.2),
         (5.80, 1.10, .90, .90, 4.0)]

# per animal (design units, scaled by FS around the eyes): ring tweaks (world z keys) + snout bump + cheek tufts
A = {
    "Dog":    dict(snout=dict(A=.30, wx=.40, wz=.22, zc=4.34, p=1.4)),
    "Cat":    dict(da={4.24: .04, 4.42: .05, 4.60: .03}, snout=dict(A=.13, wx=.30, wz=.16, zc=4.32, p=1.5),
                   tuft=dict(A=.16, z=4.30, wz=.12)),
    "Rabbit": dict(da={4.07: .02, 4.24: .03, 4.78: -.04, 4.96: -.03}, snout=dict(A=.14, wx=.30, wz=.16, zc=4.32, p=1.5)),
    "Fox":    dict(snout=dict(A=.44, wx=.30, wz=.20, zc=4.34, p=1.0), tuft=dict(A=.24, z=4.24, wz=.14)),
    "Bear":   dict(da={4.24: .03, 4.42: .02}, snout=dict(A=.30, wx=.44, wz=.24, zc=4.32, p=1.7)),
    "Panda":  dict(da={4.24: .04, 4.42: .03}, snout=dict(A=.20, wx=.38, wz=.20, zc=4.32, p=1.6)),
    "Turtle": dict(da={4.24: -.06, 4.42: -.08, 4.60: -.08, 4.78: -.06, 4.96: -.03}, dbf={4.42: .03, 4.60: .03},
                   snout=dict(A=.08, wx=.60, wz=.30, zc=4.36, p=1.0)),
    "Owl":    dict(da={4.42: .02, 4.60: .02}, dbf={4.42: -.03, 4.60: -.04, 4.78: -.03}, snout=None),
}
SNOUT3 = {   # v4: rounder tip + chin. bump = A * (1 - r2)^1.5; rz above zc, rzd (chin) below zc
    "Dog": dict(A=.34, rx=.52, rz=.30, zc=4.40), "Cat": dict(A=.15, rx=.40, rz=.24, zc=4.40),
    "Rabbit": dict(A=.16, rx=.40, rz=.24, zc=4.40), "Fox": dict(A=.48, rx=.42, rz=.28, zc=4.40),
    "Bear": dict(A=.34, rx=.56, rz=.32, zc=4.40), "Panda": dict(A=.23, rx=.50, rz=.28, zc=4.40),
    "Turtle": dict(A=.10, rx=.72, rz=.34, zc=4.40), "Owl": None,
}
CAP = {"Dog": "Cap", "Turtle": "Cap"}
