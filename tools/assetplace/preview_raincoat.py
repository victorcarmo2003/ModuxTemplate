"""AST-059 preview: software render (numpy + Pillow, no Blender) of the sheep in the raincoat outfit.

Writes (repo root):  python tools/assetplace/preview_raincoat.py
  Assets/reference/AST-059_RaincoatSheep_<Day|Mid|Night>.png   front, 3/4 and back views
  Assets/reference/AST-059_RaincoatSheep_Sheets.png            the three outfit sheets + EyesClosed face on grey

Parts are placed like the kit: node translation (cm) / 100 + (x, z, -y) of the Blender-space vertices (the FBX nodes carry
a -90 deg X rotation). Orthographic camera, smooth normals, Lambert + ambient. Alpha-0 texels show the species fur colour
(MeshPart.Color) like Roblox does; the face shell is the T_Expr sheet blended over the head. It is a review aid, not a
substitute for Studio (the Night overlay in particular looks different there).
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
import fbx_mesh as F
import gen_crew_looks as G

ROOT = G.ROOT
TEX = G.TEX_DIR
MODELS = ROOT / "Assets/models/character"
REF = ROOT / "Assets/reference"


def load(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)


def sample(tex: np.ndarray, uv: np.ndarray) -> np.ndarray:
    h, w = tex.shape[:2]
    x = np.clip(uv[:, 0] * w - 0.5, 0, w - 1.001)
    y = np.clip((1 - uv[:, 1]) * h - 0.5, 0, h - 1.001)
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    return (tex[y0, x0] * (1 - fx) * (1 - fy) + tex[y0, x0 + 1] * fx * (1 - fy)
            + tex[y0 + 1, x0] * (1 - fx) * fy + tex[y0 + 1, x0 + 1] * fx * fy)


def world(mesh: dict) -> np.ndarray:
    v = np.array(mesh["V"], np.float32).reshape(-1, 3)
    t = np.array(mesh["T"], np.float32) / 100.0
    return np.stack([v[:, 0], v[:, 2], -v[:, 1]], 1) + t  # Y-up, front = -Z


def normals(pos: np.ndarray, tris: np.ndarray) -> np.ndarray:
    n = np.zeros_like(pos)
    a, b, c = pos[tris[:, 0]], pos[tris[:, 1]], pos[tris[:, 2]]
    fn = np.cross(b - a, c - a)
    for k in range(3):
        np.add.at(n, tris[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)


class Scene:
    def __init__(self, size: int, yaw: float, night: bool):
        self.S = size
        self.rgb = np.zeros((size, size, 3), np.float32)
        self.alpha = np.zeros((size, size), np.float32)
        self.z = np.full((size, size), 1e9, np.float32)
        a = math.radians(yaw)
        self.R = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]], np.float32)
        self.night = night
        self.scale = size / 7.4

    def draw(self, mesh: dict, tex: np.ndarray, fur: np.ndarray, face: bool = False, flat: np.ndarray | None = None) -> None:
        pos = world(mesh) - np.array([0, 3.55, 0], np.float32)
        tris = np.array(mesh["tris"])
        nrm = normals(pos, tris) @ self.R.T
        p = pos @ self.R.T  # camera space: +x right, +y up, camera looks along +z (front of the model is -z)
        uvs = np.array(mesh["uvs"], np.float32)
        S = self.S
        sx = p[:, 0] * self.scale + S / 2
        sy = S / 2 - p[:, 1] * self.scale
        light = np.array([-0.35, 0.55, -0.75], np.float32)
        light /= np.linalg.norm(light)
        for ti, tri in enumerate(tris):
            xs, ys, zs = sx[tri], sy[tri], p[tri, 2]
            x0, x1 = max(int(xs.min()), 0), min(int(xs.max()) + 1, S - 1)
            y0, y1 = max(int(ys.min()), 0), min(int(ys.max()) + 1, S - 1)
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
            if abs(d) < 1e-9:
                continue
            l0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
            l1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
            l2 = 1 - l0 - l1
            m = (l0 >= -1e-4) & (l1 >= -1e-4) & (l2 >= -1e-4)
            if not m.any():
                continue
            fy_, fx_ = np.nonzero(m)
            b0, b1, b2 = l0[m], l1[m], l2[m]
            z = b0 * zs[0] + b1 * zs[1] + b2 * zs[2] - (0.01 if face else 0)
            py_, px_ = fy_ + y0, fx_ + x0
            ok = z < self.z[py_, px_]
            if not ok.any():
                continue
            b0, b1, b2, z, py_, px_ = b0[ok], b1[ok], b2[ok], z[ok], py_[ok], px_[ok]
            n = (b0[:, None] * nrm[tri[0]] + b1[:, None] * nrm[tri[1]] + b2[:, None] * nrm[tri[2]])
            n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
            uv = b0[:, None] * uvs[ti][0] + b1[:, None] * uvs[ti][1] + b2[:, None] * uvs[ti][2]
            c = sample(tex, uv)
            a = c[:, 3:4] / 255.0
            base = c[:, :3] * a + fur * (1 - a) if not face else c[:, :3]
            lam = np.clip(-(n @ light) * 0.5 + 0.5, 0, 1)[:, None]
            lit = 0.80 + 0.32 * lam
            if self.night:
                lit = lit * np.array([0.8, 0.86, 1.0], np.float32)
            col = np.clip(base * lit, 0, 255)
            if face:
                fa = a[:, 0]
                cur = self.rgb[py_, px_]
                self.rgb[py_, px_] = cur * (1 - fa[:, None]) + col * fa[:, None]
            else:
                self.rgb[py_, px_] = col
                self.z[py_, px_] = z
                self.alpha[py_, px_] = 1

    def image(self, bg) -> Image.Image:
        out = np.where(self.alpha[..., None] > 0, self.rgb, np.array(bg, np.float32))
        return Image.fromarray(out.astype(np.uint8))


def render_pack(pack: str, yaw: float, size: int = 640) -> Image.Image:
    night = pack == "Night"
    fur = np.array([int(G.fur_hex("Sheep")[i:i + 2], 16) for i in (0, 2, 4)], np.float32)
    outfit = load(TEX / f"T_Civil_Raincoat_{pack}.png")
    head = load(TEX / ("T_Head_Sheep.png" if pack == "Day" else f"T_Head_Sheep_{pack}.png"))
    atlas = load(TEX / f"T_Atlas_Kitchen_{pack}.png")
    face = load(TEX / "face/T_Expr_EyesClosed.png")
    base = F.meshes(str(MODELS / "AST-053_CrewBase.fbx"))
    arms = F.meshes(str(MODELS / "AST-053_CivilArms.fbx"))
    sheep = F.meshes(str(MODELS / "AST-053_Animal_Sheep.fbx"))
    sc = Scene(size * 2, yaw, night)
    for name in ("Torso", "Left Leg", "Right Leg"):
        sc.draw(base[name], outfit, fur)
    for name in ("Left Arm", "Right Arm"):
        sc.draw(arms[name], outfit, fur)
    sc.draw(sheep["Head_Sheep"], head, fur)
    sc.draw(sheep["Face_Sheep"], face, fur, face=True)
    for name in ("Ears_Sheep", "Tail_Sheep", "Wool_Sheep"):
        sc.draw(sheep[name], atlas, fur)
    bg = (176, 214, 236) if not night else (27, 33, 64)
    return sc.image(bg).resize((size, size), Image.LANCZOS)


def label(im: Image.Image, text: str) -> Image.Image:
    ImageDraw.Draw(im).text((10, 8), text, fill=(255, 255, 255) if "Night" in text else (30, 30, 40))
    return im


def main() -> None:
    REF.mkdir(parents=True, exist_ok=True)
    for pack in ("Day", "Mid", "Night"):
        views = [label(render_pack(pack, y), f"{pack} yaw {y}") for y in (0, 35, 180)]
        sheet = Image.new("RGB", (views[0].width * 3, views[0].height))
        for i, v in enumerate(views):
            sheet.paste(v, (i * v.width, 0))
        sheet.save(REF / f"AST-059_RaincoatSheep_{pack}.png")
        print("wrote", pack)
    tiles = [Image.open(TEX / f"T_Civil_Raincoat_{p}.png").convert("RGBA") for p in ("Day", "Mid", "Night")]
    tiles.append(Image.open(TEX / "face/T_Expr_EyesClosed.png").convert("RGBA"))
    sheet = Image.new("RGB", (512 * 2, 512 * 2), (140, 140, 148))
    for i, t in enumerate(tiles):
        bg = Image.new("RGBA", t.size, (140, 140, 148, 255))
        bg.alpha_composite(t)
        sheet.paste(bg.convert("RGB"), ((i % 2) * 512, (i // 2) * 512))
    sheet.save(REF / "AST-059_RaincoatSheep_Sheets.png")
    print("wrote sheets")


if __name__ == "__main__":
    main()
