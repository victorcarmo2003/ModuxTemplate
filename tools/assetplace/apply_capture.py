"""Write a Place.capture JSON (place_assets.luau) back into MAP-01_placements.luau.

Usage: python tools/assetplace/apply_capture.py <capture.json> [--dry]

Entries are the one-line `{ asset = ... },` tables of the placement list, numbered in file order (the same order as
the Luau array Place.capture saw). For each change the pose fields x/y/z/rotY are rewritten and parts/copies are
replaced (drop is merged). Removed entries become comments (their blockout `replaces` are kept on a stub entry with
`drop` of every part would be wrong, so a removed entry that replaces blockout pieces is reported instead of removed).
Added entries are appended before the closing brace of the list with a "captured" note.
"""

import json
import re
import sys
from pathlib import Path

PLACEMENTS = Path(__file__).with_name("MAP-01_placements.luau")
ENTRY = re.compile(r"^\t\{ asset = ")
DATE = "2026-10-11"


def num(v):
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    if isinstance(v, float):
        return repr(round(v, 3))
    return str(v)


def lua(v):
    if isinstance(v, str):
        return '"' + v + '"'
    if isinstance(v, (int, float)):
        return num(v)
    if isinstance(v, list):
        return "{ " + ", ".join(lua(x) for x in v) + " }"
    if isinstance(v, dict):
        return "{ " + ", ".join(k + " = " + lua(x) for k, x in v.items()) + " }"
    raise TypeError(v)


def pose_table(o):
    """{ x, y, z, rotY = .., size = {..} } from the capture record of one part (list with optional keys)."""
    if isinstance(o, list):
        return "{ " + ", ".join(num(x) for x in o) + " }"
    pos = o.get("pos") or [o.get("1"), o.get("2"), o.get("3")]
    items = [num(x if x is not None else 0) for x in pos]
    for k in ("rotY", "rotX", "rotZ"):
        if k in o:
            items.append(f"{k} = {num(o[k])}")
    if "size" in o:
        items.append("size = " + lua(o["size"]))
    if "part" in o:
        items.insert(0, f'part = "{o["part"]}"')
    return "{ " + ", ".join(items) + " }"


def set_field(line, key, value):
    pat = re.compile(r"(?<![\w.])" + key + r" = (-?[\d.]+)")
    if pat.search(line):
        return pat.sub(f"{key} = {value}", line, count=1)
    # insert after the previous pose field
    anchor = {"x": "asset", "y": "x", "z": "y", "rotY": "z"}[key]
    m = re.search(r"(?<![\w.])" + anchor + r' = ("[^"]*"|-?[\d.]+)', line)
    return line[: m.end()] + f", {key} = {value}" + line[m.end():]


def balanced_span(line, key):
    """(start, end) of `key = { ... }` with balanced braces, or None."""
    m = re.search(r"(?<![\w.])" + key + r" = \{", line)
    if not m:
        return None
    depth, i = 0, m.end() - 1
    while i < len(line):
        if line[i] == "{":
            depth += 1
        elif line[i] == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                if line[end:end + 2] == ", ":
                    end += 2
                return m.start(), end
        i += 1
    return None


def set_table(line, key, text):
    span = balanced_span(line, key)
    if span:
        line = line[: span[0]] + line[span[1]:]
    if text is None:
        return line
    m = re.search(r"(?<![\w.])group = ", line) or re.search(r"(?<![\w.])id = ", line)
    insert = m.start() if m else line.rindex("}")
    return line[:insert] + f"{key} = {text}, " + line[insert:]


def get_list(line, key):
    span = balanced_span(line, key)
    if not span:
        return []
    return re.findall(r'"([^"]+)"', line[span[0]:span[1]])


def main():
    capture = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    dry = "--dry" in sys.argv
    lines = PLACEMENTS.read_text(encoding="utf-8").split("\n")
    entry_lines = [n for n, l in enumerate(lines) if ENTRY.match(l)]
    print(f"{len(entry_lines)} entries in the file")
    report = []
    for rec in capture.get("changes", []):
        n = entry_lines[rec["i"] - 1]
        line = lines[n]
        for k in ("x", "y", "z", "rotY"):
            line = set_field(line, k, num(rec[k]))
        parts = rec.get("parts")
        line = set_table(line, "parts", None if not parts else "{ " + ", ".join(f'["{k}"] = {pose_table(v)}' for k, v in parts.items()) + " }")
        copies = rec.get("copies")
        line = set_table(line, "copies", None if not copies else "{ " + ", ".join(pose_table(c) for c in copies) + " }")
        if rec.get("drop"):
            merged = get_list(line, "drop") + [d for d in rec["drop"] if d not in get_list(line, "drop")]
            line = set_table(line, "drop", lua(merged))
        if "note = " not in line:
            line = line.rstrip().rstrip("},").rstrip() + f', note = "user {DATE}: edited in Studio (captured)" }},'
        lines[n] = line
        for w in rec.get("warn") or []:
            report.append(f"#{rec['i']}: {w}")
    removed = set(capture.get("removed", []))
    for i in sorted(removed, reverse=True):
        n = entry_lines[i - 1]
        if re.search(r"replaces = \{ *\"", lines[n]):
            report.append(f"#{i} removed live but replaces blockout pieces: kept, check by hand: {lines[n].strip()[:90]}")
            continue
        lines[n] = f"\t-- removed by the user in Studio {DATE}: " + lines[n].strip()
    added = capture.get("added", [])
    if added:
        close = max(n for n, l in enumerate(lines) if l.strip() == "}")
        new = [f"\t-- captured from Studio {DATE} (user additions)"]
        for rec in added:
            fields = [f'asset = "{rec["asset"]}"', f"x = {num(rec['x'])}", f"y = {num(rec['y'])}", f"z = {num(rec['z'])}", f"rotY = {num(rec['rotY'])}"]
            if rec.get("parts"):
                fields.append("parts = { " + ", ".join(f'["{k}"] = {pose_table(v)}' for k, v in rec["parts"].items()) + " }")
            if rec.get("copies"):
                fields.append("copies = { " + ", ".join(pose_table(c) for c in rec["copies"]) + " }")
            if rec.get("drop"):
                fields.append("drop = " + lua(rec["drop"]))
            fields += [f'group = "{rec["group"]}"', f'id = "{rec["id"]}"', "replaces = {  }", f'note = "user {DATE}: added in Studio (captured)"']
            new.append("\t{ " + ", ".join(fields) + " },")
            for w in rec.get("warn") or []:
                report.append(f"added {rec['asset']}: {w}")
        lines[close:close] = new
    if not dry:
        PLACEMENTS.write_text("\n".join(lines), encoding="utf-8")
    print(f"changes {len(capture.get('changes', []))}, removed {len(removed)}, added {len(added)}" + (" (dry run)" if dry else ""))
    for r in report:
        print(r)


if __name__ == "__main__":
    main()
