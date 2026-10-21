"""T_HW_Atlas: 8x4 grid of vertical gradients (light top -> darker bottom) for the Halloween lobby kit (AST-167..176)."""
from PIL import Image
import sys

CELL = 64
GRID = [
    ["F28C28", "C9651A", "5E8C3A", "FFB25A", "7B4BC4", "4A2F7A", "3A2E4F", "5FD38D"],
    ["FFF3DC", "2B2233", "8A5A3B", "C45BB8", "FFFFFF", "6B6478", "F59AC8", "4FC3C7"],
    ["5C3A26", "E0662A", "FFD45A", "1E1828", "B9A6E8", "9FE3B8", "D8C8A8", "8C2F5C"],
    ["FFFFFF", "FFFFFF", "FFFFFF", "FFFFFF", "FFFFFF", "FFFFFF", "FFFFFF", "FFFFFF"],
]
FLAT = {"FFFFFF"}


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


img = Image.new("RGB", (8 * CELL, 4 * CELL))
px = img.load()
for r, row in enumerate(GRID):
    for c, h in enumerate(row):
        base = rgb(h)
        for y in range(CELL):
            t = y / (CELL - 1)
            k = 1.0 if h in FLAT else 1.12 - 0.37 * t  # light top, darker bottom
            col = tuple(max(0, min(255, round(v * k))) for v in base)
            for x in range(CELL):
                px[c * CELL + x, r * CELL + y] = col
img.save(sys.argv[1])
print("atlas", sys.argv[1])
