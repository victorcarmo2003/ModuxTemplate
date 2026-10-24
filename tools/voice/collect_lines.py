"""Collect every voiced line (intro/cutscenes, tutorial, boss calls) from the Luau sources into tools/voice/lines.json.

  python tools/voice/collect_lines.py

Key = v_<sha1(speaker + NUL + spoken)[:10]>, where `spoken` mirrors Speech.Spoken (src/Cutscene/client/CutsceneController/
Speech.luau): digit runs removed, leading punctuation cut, whitespace collapsed. Lines with nothing speakable are skipped.
"""
import hashlib, json, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "src")
FILES = {
    "cutscenes": "Shared/Content/Cutscenes.luau",
    "bosscalls": "Shared/Content/BossCalls.luau",
    "steps": "Tutorial/client/TutorialController/Steps.luau",
    # owner 2026-10-18: every voiced line, one voice per character
    "hush": "Anomaly/client/AnomalyController/Effects/ANM-010.luau",
    "radiovoice": "Hallucination/client/HallucinationController/Effects/RadioVoice.luau",
}


def tokenize(code):
    """Yield (kind, value, line): kind in str / id / num / sym. Comments dropped."""
    i, n, line = 0, len(code), 1
    out = []
    while i < n:
        c = code[i]
        if c == "\n":
            line += 1; i += 1; continue
        if c.isspace():
            i += 1; continue
        if code.startswith("--", i):
            m = re.match(r"--\[(=*)\[", code[i:])
            if m:
                end = code.find("]" + m.group(1) + "]", i)
                end = n if end < 0 else end + len(m.group(1)) + 2
                line += code.count("\n", i, end); i = end
            else:
                j = code.find("\n", i); i = n if j < 0 else j
            continue
        if c in "\"'`":
            j, buf, start = i + 1, [], line
            while j < n and code[j] != c:
                if code[j] == "\\" and j + 1 < n:
                    e = code[j + 1]
                    buf.append({"n": "\n", "t": "\t"}.get(e, e)); j += 2
                    continue
                buf.append(code[j]); j += 1
            out.append(("tpl" if c == "`" else "str", "".join(buf), start))
            i = j + 1; continue
        m = re.match(r"[A-Za-z_][A-Za-z_0-9]*", code[i:])
        if m:
            out.append(("id", m.group(0), line)); i += len(m.group(0)); continue
        m = re.match(r"\d+(\.\d+)?", code[i:])
        if m:
            out.append(("num", m.group(0), line)); i += len(m.group(0)); continue
        out.append(("sym", c, line)); i += 1
    return out


def spoken(text):
    t = text.replace("\u2026", "...")
    t = re.sub(r"\d[\d\-\s]*\d", "", t)
    t = re.sub(r"^[\s\.,!\?]+", "", t)
    t = re.sub(r"\s+", " ", t)
    return t.strip()


def key_of(speaker, text):
    return "v_" + hashlib.sha1((speaker + "\0" + text).encode("utf-8")).hexdigest()[:10]


def sentence_like(s):
    return " " in s.strip() and re.search(r"[A-Za-z]", s) is not None and not re.fullmatch(r"[a-z0-9_]+", s)


def main():
    lines = {}

    def add(speaker, text, source):
        sp = spoken(text)
        if not re.search(r"[A-Za-z]", sp):
            return
        k = key_of(speaker, sp)
        e = lines.setdefault(k, {"speaker": speaker, "text": sp, "sources": []})
        if source not in e["sources"]:
            e["sources"].append(source)

    toks = {n: tokenize(open(os.path.join(SRC, p), encoding="utf-8").read()) for n, p in FILES.items()}

    # cutscenes: walt(at, "text", variant?) / crew(...)
    t = toks["cutscenes"]
    scene = ""
    for i in range(len(t) - 4):
        if t[i][0] == "id" and t[i][1] == "Key" and t[i + 1][1] == "=" and t[i + 2][0] == "str":
            scene = t[i + 2][1]
        if t[i][0] == "id" and t[i][1] in ("walt", "crew") and t[i + 1][1] == "(" and t[i + 2][0] == "num" \
                and t[i + 3][1] == "," and t[i + 4][0] == "str":
            variant = t[i + 6][1] if i + 6 < len(t) and t[i + 5][1] == "," and t[i + 6][0] == "str" else ""
            add(t[i][1], t[i + 4][1], f"Cutscenes.luau:{t[i + 4][2]} [{scene}]" + (f" ({variant})" if variant else ""))

    # boss calls: every sentence-like string literal (keys/enums have no spaces); Speaker nil = walt
    for kind, val, line in toks["bosscalls"]:
        if kind == "str" and sentence_like(val):
            add("walt", val, f"BossCalls.luau:{line}")

    # tutorial steps: Say / SayAgain / Done / Remind fields + GREETING / GOODBYE / SKIP_GOODBYE tables
    t = toks["steps"]
    field = None
    depth_field = 0
    skip_to = -1
    for i, (kind, val, line) in enumerate(t):
        if i < skip_to:
            continue
        if kind == "id" and val in ("Say", "SayAgain", "Done", "Remind", "GREETING", "GOODBYE", "SKIP_GOODBYE"):
            field = val; depth_field = 0
            if val in ("GREETING", "GOODBYE", "SKIP_GOODBYE"):
                # `const X: { string } = { ... }`: skip the type annotation, start at the "=" (before, its braces closed the field)
                j = i
                while j < len(t) and not (t[j][0] == "sym" and t[j][1] == "="):
                    j += 1
                skip_to = j
        elif kind == "id" and val in ("Text", "Hint", "Key", "Action"):
            field = None
        elif kind == "sym" and val == "{" and field in ("Say", "SayAgain", "GREETING", "GOODBYE", "SKIP_GOODBYE"):
            depth_field += 1
        elif kind == "sym" and val == "}" and depth_field:
            depth_field -= 1
            if depth_field == 0:
                field = None
        elif kind == "str" and field and (sentence_like(val) or (field in ("Done", "Remind", "Say", "SayAgain") and re.search(r"[A-Za-z]", val))):
            add("walt", val, f"Steps.luau:{line} ({field})")
            if field in ("Done", "Remind"):
                field = None

    # Walt on the anomalies' radio (Kit/Radio.Say): the RUN_LINE / SHOP_LINE constants of the Hush
    t = toks["hush"]
    for i in range(len(t) - 2):
        if t[i][0] == "id" and t[i][1] in ("RUN_LINE", "SHOP_LINE") and t[i + 1][1] == "=" and t[i + 2][0] == "str":
            add("walt", t[i + 2][1], f"Radio:ANM-010.luau:{t[i + 2][2]}")

    # the stranger on the radio (hallucination radio_voice): every string of its LINES table
    t = toks["radiovoice"]
    inside = False
    depth = 0
    for i, (kind, val, line) in enumerate(t):
        if kind == "id" and val == "LINES":
            inside = True
            depth = 0
        elif inside and kind == "sym" and val == "{":
            depth += 1
        elif inside and kind == "sym" and val == "}":
            depth -= 1
            if depth == 0:
                inside = False
        elif inside and depth > 0 and kind == "str":
            add("radio", val, f"RadioVoice.luau:{line}")

    out = dict(sorted(lines.items(), key=lambda kv: (kv[1]["speaker"], kv[1]["text"])))
    path = os.path.join(ROOT, "tools", "voice", "lines.json")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
    chars = sum(len(v["text"].encode("utf-8")) for v in out.values())
    by = {}
    for v in out.values():
        by[v["speaker"]] = by.get(v["speaker"], 0) + 1
    print(f"{len(out)} lines, {chars} UTF-8 bytes, per speaker {by} -> {path}")


if __name__ == "__main__":
    sys.exit(main())
