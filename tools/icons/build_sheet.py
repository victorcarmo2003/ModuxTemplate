"""AST-071: post-process renders (cartoon outline), draw vector icons, pack the 1024 atlas + JSON + contact sheet.
   python build_sheet.py <renders_dir> <repo_root>"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

RENDERS, ROOT = sys.argv[1], sys.argv[2]
CELL = 128
SS = 4
W = CELL * SS             # 512 working cell
OUTLINE = 4 * SS          # 4 px at 128 (AST-086 / style guide 7.1 "contorno grosso")
MARGIN = 4 * SS           # free border inside the cell (no bleeding between ImageRects)
BOX = W - 2 * (OUTLINE + MARGIN)
INK = (0x2B, 0x22, 0x33)

def hx(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

# ---------------------------------------------------------------- helpers
def fit(im, box=BOX, canvas=W, scale=1.0):
    a = np.array(im)[..., 3]
    ys, xs = np.where(a > 8)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    k = box * scale / max(im.size)
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.alpha_composite(im, ((canvas - im.width) // 2, (canvas - im.height) // 2))
    return out

def outline(im, r=OUTLINE, ink=INK, fill_under=(255, 248, 236)):
    """Silhouette outline (anti-aliased disk dilation) + opaque light fill under semi-transparent parts (glass)."""
    a = np.array(im)[..., 3].astype(np.float32) / 255
    solid = ndimage.binary_fill_holes(a > 0.08)
    dist = ndimage.distance_transform_edt(~solid)
    ring = np.clip(r + 0.5 - dist, 0, 1)
    base = np.zeros((im.height, im.width, 4), np.float32)
    base[..., :3] = ink; base[..., 3] = ring * 255
    under = np.zeros_like(base); under[..., :3] = fill_under; under[..., 3] = solid * 255
    out = Image.fromarray(base.astype(np.uint8))
    out.alpha_composite(Image.fromarray(under.astype(np.uint8)))
    out.alpha_composite(im)
    return out

def down(im):
    return im.convert("RGBa").resize((CELL, CELL), Image.LANCZOS).convert("RGBA")

def grad(mask, top, bot, y0=None, y1=None):
    """Vertical gradient (top light -> bottom dark, palette pairs) clipped to an L mask."""
    m = np.array(mask).astype(np.float32) / 255
    ys = np.where(m.max(1) > 0)[0]
    y0 = ys.min() if y0 is None else y0; y1 = ys.max() if y1 is None else y1
    t = np.clip((np.arange(m.shape[0]) - y0) / max(1, y1 - y0), 0, 1)[:, None]
    top, bot = np.array(hx(top), np.float32), np.array(hx(bot), np.float32)
    rgb = top[None, None, :] * (1 - t[..., None]) + bot[None, None, :] * t[..., None]
    rgb = np.broadcast_to(rgb, (m.shape[0], m.shape[1], 3))
    out = np.dstack([rgb, m * 255]).astype(np.uint8)
    return Image.fromarray(out)

def flat(mask, col, alpha=1.0):
    m = np.array(mask).astype(np.float32) / 255 * alpha
    rgb = np.zeros((m.shape[0], m.shape[1], 3), np.float32); rgb[:] = hx(col)
    return Image.fromarray(np.dstack([rgb, m * 255]).astype(np.uint8))

def M(draw_fn, size=W):
    m = Image.new("L", (size, size), 0); draw_fn(ImageDraw.Draw(m)); return m

def mul(m1, m2):
    return Image.fromarray((np.array(m1).astype(np.float32) * np.array(m2) / 255).astype(np.uint8))

def stroke_ink(img, fn):
    """Interior ink lines (same colour as the outline)."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0)); fn(ImageDraw.Draw(layer)); img.alpha_composite(layer)

def highlight(img, mask, box, alpha=0.35):
    hm = M(lambda d: d.ellipse(box, fill=255))
    img.alpha_composite(flat(mul(hm, mask), "#FFFFFF", alpha))

def star_pts(cx, cy, ro, ri, n=5, rot=-90):
    pts = []
    for i in range(2 * n):
        r = ro if i % 2 == 0 else ri
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

def rounded_poly(pts, rad):
    """Rounded polygon mask by dilating an eroded polygon."""
    m = M(lambda d: d.polygon(pts, fill=255))
    a = np.array(m) > 0
    er = ndimage.distance_transform_edt(a) > rad
    di = ndimage.distance_transform_edt(~er) <= rad
    return Image.fromarray((di * 255).astype(np.uint8))

# ---------------------------------------------------------------- vector icons (drawn at 512)
def v_coin():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cx, cy, rx, ry, th = 256, 236, 210, 196, 44
    edge = M(lambda d: (d.ellipse((cx - rx, cy - ry + th, cx + rx, cy + ry + th), fill=255),
                        d.rectangle((cx - rx, cy, cx + rx, cy + th), fill=255)))
    img.alpha_composite(grad(edge, "#E0A51E", "#9C6A0C"))
    face = M(lambda d: d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255))
    img.alpha_composite(grad(face, "#FFF1D6", "#EAD6B0"))            # Cream rim (AST-082)
    inner = M(lambda d: d.ellipse((cx - rx + 30, cy - ry + 28, cx + rx - 30, cy + ry - 28), fill=255))
    img.alpha_composite(grad(inner, "#F6C12B", "#C98E12"))            # Mustard face
    # shallow relief: hot dog of the logo (DEC-206), simplified
    bun = rounded_poly([(cx - 125, cy - 5), (cx + 125, cy - 5), (cx + 100, cy + 85), (cx - 100, cy + 85)], 38)
    saus = rounded_poly([(cx - 160, cy - 52), (cx + 160, cy - 52), (cx + 160, cy + 18), (cx - 160, cy + 18)], 34)
    shade = (0xA8, 0x74, 0x0E)
    for dx, dy, col in ((7, 9, "#A8740E"), (0, 0, None)):
        sm = Image.fromarray(np.roll(np.roll(np.array(saus), dy, 0), dx, 1)); bm = Image.fromarray(np.roll(np.roll(np.array(bun), dy, 0), dx, 1))
        if col:
            img.alpha_composite(flat(sm, col)); img.alpha_composite(flat(bm, col))
        else:
            img.alpha_composite(grad(sm, "#E09A1A", "#B9770C"))
            img.alpha_composite(grad(bm, "#FFE07A", "#E3AA1C"))
    stroke_ink(img, lambda d: d.line([(cx - 110, cy - 22), (cx - 55, cy - 36), (cx, cy - 20), (cx + 55, cy - 36), (cx + 112, cy - 22)],
                                     fill=(0xFF, 0xF1, 0xD6, 255), width=14, joint="curve"))
    highlight(img, face, (cx - 170, cy - 180, cx + 10, cy - 60), 0.45)
    return img

def v_gem():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    top, mid, bot = 110, 200, 440
    l, r, cx = 70, 442, 256
    crown = [(150, top), (362, top), (r, mid), (l, mid)]
    body = [(l, mid), (r, mid), (cx, bot)]
    img.alpha_composite(flat(M(lambda d: d.polygon(body, fill=255)), "#2E8C99"))
    img.alpha_composite(flat(M(lambda d: d.polygon([(l, mid), (190, mid), (cx, bot)], fill=255)), "#5FC0CC"))
    img.alpha_composite(flat(M(lambda d: d.polygon([(322, mid), (r, mid), (cx, bot)], fill=255)), "#256E7A"))
    img.alpha_composite(flat(M(lambda d: d.polygon(crown, fill=255)), "#8FD8E0"))
    img.alpha_composite(flat(M(lambda d: d.polygon([(200, top), (312, top), (330, mid), (182, mid)], fill=255)), "#C6F0F2"))
    stroke_ink(img, lambda d: (d.line([(l, mid), (r, mid)], fill=INK + (255,), width=8),
                               d.line([(190, mid), (cx, bot)], fill=INK + (255,), width=6),
                               d.line([(322, mid), (cx, bot)], fill=INK + (255,), width=6)))
    img.alpha_composite(flat(M(lambda d: d.polygon(star_pts(170, 150, 34, 9, 4, -90), fill=255)), "#FFFFFF", 0.9))
    return img

def v_sun():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cx = cy = 256
    rays = Image.new("L", (W, W), 0)
    for i in range(8):
        a = math.radians(i * 45)
        p = [(cx + 150 * math.cos(a - 0.22), cy + 150 * math.sin(a - 0.22)), (cx + 236 * math.cos(a), cy + 236 * math.sin(a)),
             (cx + 150 * math.cos(a + 0.22), cy + 150 * math.sin(a + 0.22))]
        rays = Image.fromarray(np.maximum(np.array(rays), np.array(rounded_poly(p, 14))))
    img.alpha_composite(grad(rays, "#FFD45A", "#E8A92A"))
    disc = M(lambda d: d.ellipse((cx - 140, cy - 140, cx + 140, cy + 140), fill=255))
    ring = M(lambda d: d.ellipse((cx - 152, cy - 152, cx + 152, cy + 152), fill=255))
    img.alpha_composite(flat(ring, "#2B2233"))
    img.alpha_composite(grad(disc, "#FFE58A", "#F6C12B"))
    highlight(img, disc, (cx - 110, cy - 115, cx + 10, cy - 30), 0.5)
    return img

def v_moon():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    big = M(lambda d: d.ellipse((60, 50, 440, 430), fill=255))
    cut = M(lambda d: d.ellipse((190, 0, 530, 340), fill=255))
    cres = Image.fromarray((np.array(big) * (np.array(cut) == 0)).astype(np.uint8))
    img.alpha_composite(grad(cres, "#FFF1D6", "#EAD6B0"))
    for (x, y, r) in ((140, 300, 26), (215, 380, 18), (110, 200, 14)):
        img.alpha_composite(flat(mul(M(lambda d: d.ellipse((x - r, y - r, x + r, y + r), fill=255)), cres), "#D9C49A"))
    img.alpha_composite(flat(M(lambda d: d.polygon(star_pts(400, 380, 56, 16, 4, -90), fill=255)), "#FFF1D6"))
    return img

def v_star(scale=1.0):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    m = rounded_poly(star_pts(256, 276, 236 * scale, 104 * scale, 5), 22)
    img.alpha_composite(grad(m, "#FFE07A", "#F6A81B"))
    highlight(img, m, (150, 120, 300, 260), 0.45)
    return img

def v_cloud():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    m = M(lambda d: [d.ellipse(b, fill=255) for b in ((50, 190, 230, 370), (140, 110, 340, 310), (270, 160, 460, 350), (90, 250, 420, 400))])
    img.alpha_composite(grad(m, "#B4AEBB", "#7E7788"))
    pts = []
    for i in range(46):
        t = i / 45
        x = 150 + 220 * t + 28 * math.sin(t * 22)
        y = 270 + 50 * math.cos(t * 19) - 20 * math.sin(t * 7)
        pts.append((x, y))
    stroke_ink(img, lambda d: d.line(pts, fill=INK + (255,), width=16, joint="curve"))
    # little lightning tick under the cloud
    bolt = M(lambda d: d.polygon([(250, 380), (300, 380), (275, 430), (310, 430), (230, 500), (255, 445), (225, 445)], fill=255))
    img.alpha_composite(flat(bolt, "#F6C12B"))
    return img

def v_steam():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    m = Image.new("L", (W, W), 0)
    for x0, h, ph in ((136, 300, 0.0), (256, 380, 2.2), (376, 300, 4.4)):
        pts = [(x0 + 22 * math.sin(ph + t / 34), 460 - t) for t in range(0, h, 4)]
        rr = 23
        lm = M(lambda d: d.line(pts, fill=255, width=2 * rr, joint="curve"))
        caps = M(lambda d: [d.ellipse((q[0] - rr, q[1] - rr, q[0] + rr, q[1] + rr), fill=255) for q in (pts[0], pts[-1])])
        lm = Image.fromarray(np.maximum(np.array(lm), np.array(caps)))
        m = Image.fromarray(np.maximum(np.array(m), np.array(lm)))
    img.alpha_composite(grad(m, "#FFFFFF", "#D6DCE2"))
    return img

def v_sparkle():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for (x, y, ro, ri) in ((230, 270, 210, 52), (390, 130, 90, 24), (395, 390, 60, 16)):
        m = rounded_poly(star_pts(x, y, ro, ri, 4, -90), 8)
        img.alpha_composite(grad(m, "#FFE9A6", "#D9A21E"))   # Gold: AST-051 rare item only (style guide 2.1)
    return img

def badge(content, ring="#F6C12B", disc="#2B2233"):
    """Notice family: dark disc + Mustard ring, item centred."""
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    img.alpha_composite(flat(M(lambda d: d.ellipse((0, 0, W - 1, W - 1), fill=255)), ring))
    img.alpha_composite(flat(M(lambda d: d.ellipse((40, 40, W - 41, W - 41), fill=255)), disc))
    img.alpha_composite(fit(content, box=int(W * 0.56)))
    return img

# ---------------------------------------------------------------- the 54 icons (order = atlas order)
ING = ["bun", "sausage", "ketchup", "mustard", "cheese", "bacon", "potato_sticks", "cream_cheese", "coffee"]
PACKS = ["pack_sausages", "pack_buns", "pack_ketchup", "pack_mustard", "pack_cheese", "pack_bacon", "pack_potato_sticks", "pack_cream_cheese", "pack_coffee"]
PACK_ING = {"pack_sausages": "sausage", "pack_buns": "bun", "pack_ketchup": "ketchup", "pack_mustard": "mustard", "pack_cheese": "cheese",
            "pack_bacon": "bacon", "pack_potato_sticks": "potato_sticks", "pack_cream_cheese": "cream_cheese", "pack_coffee": "coffee"}
SRC = {
    "bun": "blender/food/AST-001_Bun.blend:Bun_Open", "sausage": "blender/food/AST-002_Sausage.blend:Sausage_Grilled",
    "ketchup": "blender/food/AST-004_KetchupBottle.blend", "mustard": "blender/food/AST-005_MustardBottle.blend",
    "cheese": "blender/food/AST-006_Cheese.blend:Cheese_Slice", "bacon": "blender/food/AST-007_Bacon.blend:Bacon_Pile",
    "potato_sticks": "blender/food/AST-008_PotatoSticks.blend:PotatoSticks_Pile", "cream_cheese": "blender/food/AST-009_CreamCheese.blend:CreamCheese_Jar",
    "coffee": "blender/equipment/AST-022_CoffeeMachine.blend:Jar+JarHandle+Coffee",
}
ENTRIES = []  # (name, group, ref, build_fn, source, placeholder_note)
for k in ING:
    ENTRIES.append(("Ingredient/" + k, "Ingredients", k, ("render", "ing_" + k), SRC[k], None))
ENTRIES.append(("Item/hot_dog", "Tools", "ITM-010", ("render", "tool_hot_dog"), "blender/food/AST-003_HotDog.blend:HotDog_Display", None))
for k in PACKS:
    ENTRIES.append(("Item/" + k, "Tools", k, ("pack", k), "import/food/AST-011_*.fbx (recolor AST-011 table) + Ingredient badge",
                    "pacote sem recolor/rotulo final no modelo (AST-011/AST-072): cor so no icone"))
ENTRIES.append(("Item/coffee", "Tools", "ITM-009", ("render", "tool_coffee"), "blender/food/AST-010_Coffee.blend:Handle", None))
ENTRIES.append(("Item/revive_kit", "Tools", "ITM-021", ("render", "tool_rescue_whistle"), "blender/market/AST-051_ReviveKit.blend:Handle", None))
for lv in (1, 2, 3):
    ENTRIES.append(("Upgrade/grill/%d" % lv, "Upgrades", "UPG-001 L%d" % lv, ("render", "upg_grill_%d" % lv), "blender/equipment/AST-012_RollerGrill.blend:Grill_L%d + Sausage_Grilled" % lv, None))
for lv in (1, 2, 3):
    ENTRIES.append(("Upgrade/cooler/%d" % lv, "Upgrades", "UPG-002 L%d" % lv, ("render", "upg_cooler_%d" % lv),
                    "blender/equipment/AST-018_CoolerL%d.blend" % lv if lv < 3 else "import/equipment/AST-018_CoolerL3.fbx", None))
for lv in (1, 2, 3):
    ENTRIES.append(("Upgrade/counter/%d" % lv, "Upgrades", "UPG-003 L%d" % lv, ("render", "upg_counter_%d" % lv),
                    "import/equipment/AST-019_CounterStraight/Corner/Stool.fbx (composicao)",
                    "Counter L1-L3 sem modelo final: composicao de pecas KayKit; L3 sem toldo" ))
ENTRIES.append(("Upgrade/cash_drawer_lock", "Upgrades", "UPG-004", ("render", "upg_cash_drawer_lock"), "blender/equipment/AST-020_CashRegister.blend:Register+Drawer+Lock", None))
ENTRIES.append(("Upgrade/trailer_lights", "Upgrades", "UPG-005", ("render", "upg_trailer_lights"), "blender/equipment/AST-023_TrailerLights.blend:Lights_Mast", None))
ENTRIES.append(("Upgrade/food_trailer", "Upgrades", "UPG-006 / Vehicles.trailer", ("render", "upg_food_trailer"), "blender/vehicle/AST-027_OpenLateTrailer.blend", None))
ENTRIES.append(("Upgrade/coffee_machine", "Upgrades", "UPG-007", ("render", "upg_coffee_machine"), "blender/equipment/AST-022_CoffeeMachine.blend", None))
for a in ("dog", "rabbit", "cat", "bear", "fox", "owl", "panda", "lion"):
    ENTRIES.append(("Class/class_" + a, "Classes", "class_" + a, ("render", "class_" + a),
                    "blender/character/AST-053_Animal_%s.blend:Head+Ears+Face(Normal)+REF_Cap" % a.capitalize(),
                    "render provisorio da cabeca Day+Normal; trocar pelo retrato High do AST-086 quando existir"))
ENTRIES += [
    ("Hud/coin", "HUD", "AST-082", ("vec", v_coin), "vetorial (Pillow)", "AST-082 sem malha: moeda desenhada; re-renderizar quando a malha existir"),
    ("Hud/gem", "HUD", "gemas (FEAT lobby)", ("vec", v_gem), "vetorial (Pillow)", "cor da gema nao definida no style guide: Teal provisorio"),
    ("Hud/sun", "HUD", "Day", ("vec", v_sun), "vetorial (Pillow)", None),
    ("Hud/moon", "HUD", "Night", ("vec", v_moon), "vetorial (Pillow)", None),
    ("Hud/phone", "HUD", "AST-042", ("render", "hud_phone"), "blender/equipment/AST-042_VehiclePhone.blend:Phone_Trailer", None),
    ("Hud/ambulance", "HUD", "AST-052", ("render", "hud_ambulance"), "blender/vehicle/AST-052_Ambulance.blend", None),
    ("Reaction/star", "Reactions", "reacao feliz", ("vec", v_star), "vetorial (Pillow)", None),
    ("Reaction/scribble_cloud", "Reactions", "reacao irritada", ("vec", v_cloud), "vetorial (Pillow)", None),
    ("Reaction/steam", "Reactions", "reacao impaciente", ("vec", v_steam), "vetorial (Pillow)", None),
    ("Notice/lock", "Notices", "bloqueado", ("badge_render", "note_lock"), "blender/equipment/AST-020_Padlock.blend:Padlock", None),
    ("Notice/trailer", "Notices", "Trailer only", ("badge_render", "note_trailer"), "blender/vehicle/AST-027_OpenLateTrailer.blend", None),
    ("Notice/rare", "Notices", "S1 / AST-051", ("badge_vec", v_sparkle), "vetorial (Pillow)", "brilho em Gold (cor do AST-051); confirmar com art-director"),
]
assert len(ENTRIES) == 54, len(ENTRIES)

def load(key):
    return Image.open(os.path.join(RENDERS, key + ".png")).convert("RGBA")

cache = {}
def build(entry):
    kind, arg = entry[3]
    if kind == "render":
        big = outline(fit(load(arg)))
    elif kind == "vec":
        big = outline(fit(arg()))
    elif kind == "pack":
        body = outline(fit(load("tool_" + arg), box=int(BOX * 0.86)))
        body = body.transform(body.size, Image.AFFINE, (1, 0, 28, 0, 1, 24))   # nudge up-left for the badge
        ing = cache["Ingredient/" + PACK_ING[arg]]
        small = ing.resize((int(W * 0.48), int(W * 0.48)), Image.LANCZOS)
        body.alpha_composite(small, (W - small.width - 2, W - small.height - 2))
        big = body
    elif kind == "badge_render":
        big = outline(badge(outline(fit(load(arg)), r=OUTLINE // 2)), r=OUTLINE // 2)
    elif kind == "badge_vec":
        big = outline(badge(outline(fit(arg()), r=OUTLINE // 2)), r=OUTLINE // 2)
    cache[entry[0]] = big
    return down(big)

atlas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
meta = {}
for i, e in enumerate(ENTRIES):
    ic = build(e)
    x, y = (i % 8) * CELL, (i // 8) * CELL
    atlas.alpha_composite(ic, (x, y))
    meta[e[0]] = {"ImageRectOffset": [x, y], "ImageRectSize": [CELL, CELL], "group": e[1], "ref": e[2],
                  "source": "Assets/" + e[4] if not e[4].startswith("vetorial") else e[4],
                  "placeholder": e[5] is not None, **({"note": e[5]} if e[5] else {})}

ui = os.path.join(ROOT, "Assets", "textures", "ui")
os.makedirs(ui, exist_ok=True)
atlas.save(os.path.join(ui, "AST-071_icons.png"))
doc = {
    "asset": "AST-071",
    "image": "Assets/textures/ui/AST-071_icons.png",
    "imageSize": [1024, 1024],
    "cell": CELL,
    "grid": [8, 8],
    "free": [[(i % 8) * CELL, (i // 8) * CELL] for i in range(len(ENTRIES), 64)],
    "usage": "ImageLabel.Image = <asset id da folha>; ImageRectOffset/ImageRectSize do icone. Asset id: upload em lote (fora deste arquivo).",
    "outline": "#2B2233, 4 px",
    "icons": meta,
}
json.dump(doc, open(os.path.join(ui, "AST-071_icons.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)

# ---------------------------------------------------------------- contact sheet (review)
font = ImageFont.load_default()
try:
    font = ImageFont.truetype("arialbd.ttf", 13)
    small_font = ImageFont.truetype("arial.ttf", 11)
except Exception:
    small_font = font
CW, CH = 300, 196
cols = 6
rows = (len(ENTRIES) + cols - 1) // cols
cs = Image.new("RGB", (cols * CW, rows * CH + 40), (0xE9, 0xE4, 0xDA))
d = ImageDraw.Draw(cs)
d.text((10, 10), "AST-071 icon sheet - 54 icons, 128 px cells, 1024 atlas. Left: on HUD pill (#2B2233 70%). Middle: on light. Right: 48 / 32 px (phone).", fill=INK, font=font)
for i, e in enumerate(ENTRIES):
    x0, y0 = (i % cols) * CW, (i // cols) * CH + 40
    ic = atlas.crop(tuple(meta[e[0]]["ImageRectOffset"]) + tuple(np.add(meta[e[0]]["ImageRectOffset"], CELL)))
    pill = Image.new("RGBA", (CELL + 8, CELL + 8), (0, 0, 0, 0))
    ImageDraw.Draw(pill).rounded_rectangle((0, 0, CELL + 7, CELL + 7), radius=26, fill=(0x2B, 0x22, 0x33, 178))
    bgp = Image.new("RGBA", pill.size, (0x8F, 0xA6, 0xB8, 255)); bgp.alpha_composite(pill); bgp.alpha_composite(ic, (4, 4))
    cs.paste(bgp.convert("RGB"), (x0 + 4, y0 + 4))
    cs.paste(Image.alpha_composite(Image.new("RGBA", (CELL, CELL), (0xFF, 0xF8, 0xEC, 255)), ic).convert("RGB"), (x0 + 142, y0 + 8))
    for j, s in enumerate((48, 32)):
        sm = ic.resize((s, s), Image.LANCZOS)
        cs.paste(Image.alpha_composite(Image.new("RGBA", (s, s), (0x5A, 0x5F, 0x69, 255)), sm).convert("RGB"), (x0 + 274 - s // 2 - 2, y0 + 10 + j * 56))
    col = (0xA8, 0x26, 0x1B) if meta[e[0]]["placeholder"] else INK
    d.text((x0 + 6, y0 + 142), e[0], fill=col, font=font)
    d.text((x0 + 6, y0 + 160), "%s  @ %d,%d" % (e[2], *meta[e[0]]["ImageRectOffset"]), fill=(80, 80, 90), font=small_font)
    if meta[e[0]]["placeholder"]:
        d.text((x0 + 6, y0 + 175), "placeholder", fill=col, font=small_font)
ref = os.path.join(ROOT, "Assets", "reference")
cs.save(os.path.join(ref, "AST-071_icons_contact.png"))
print("atlas + json + contact sheet written;", sum(1 for v in meta.values() if v["placeholder"]), "placeholders")
