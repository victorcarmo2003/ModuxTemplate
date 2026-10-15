"""Generates src/Crew/shared/CrewLooks.luau (TASK-006, architecture.md §18.9.3).

Sources (never edit CrewLooks.luau by hand; change the sources and run this again):
  - Assets/textures/character/_texture_ids.json  texture ids (faithful copy: a key missing there never enters)
  - Assets/textures/character/_blank_texture_ids.json  ANM-001/ANM-004 "blank" variant: T_Head_<A>_Blank and
                                                   T_Atlas_Kitchen_<Pack>_Blank_<A> (AST-060). Optional per species: a
                                                   missing one is a hard error only if the file lists the species
  - Assets/textures/character/T_Head_<A>.png      fur colour = RGB stored under the alpha-0 texels (the head painter
                                                   keeps the fur there; same values as the skill's colors.json)
  - CAP_PLAIN below                                species wearing the plain Cap (floppy ears / no ears); every other
                                                   species has ears up and wears AST-053_CrewCap_EarsUp. Read from the
                                                   REF_Cap object (mesh "Cap" vs "Cap_EarsUp") of each
                                                   Assets/blender/character/AST-053_Animal_<A>.blend (2026-10-10).
  - SPECIES / OUTFITS below                        keys of Content.Species / Content.Outfits (content-data.md v4,
                                                   §3.10a and §3.10b). The run fails if the JSON does not cover them.

Usage (repo root):  python tools/assetplace/gen_crew_looks.py [--check]
  --check  only verifies that the file on disk is up to date (exit 1 if not).
Needs Pillow (fur colours).
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEX_JSON = ROOT / "Assets/textures/character/_texture_ids.json"
BLANK_JSON = ROOT / "Assets/textures/character/_blank_texture_ids.json"
TEX_DIR = ROOT / "Assets/textures/character"
OUT = ROOT / "src/Crew/shared/CrewLooks.luau"

# Bump when the kit tree in ReplicatedStorage.Assets changes shape (build_kits.luau writes the same number).
KIT_VERSION = 1

PACKS = ("Day", "Mid", "Night")

# Content.Species keys (content-data.md §3.10a) -> Asset suffix (AST-053_Animal_<Asset>, T_Head_<Asset>)
SPECIES = {
    "dog": "Dog", "rabbit": "Rabbit", "cat": "Cat", "bear": "Bear", "fox": "Fox", "owl": "Owl",
    "panda": "Panda", "lion": "Lion", "penguin": "Penguin", "hamster": "Hamster", "mouse": "Mouse",
    "frog": "Frog", "monkey": "Monkey", "turtle": "Turtle", "sheep": "Sheep", "koala": "Koala",
    "pig": "Pig", "raccoon": "Raccoon",
}

# Content.Outfits keys (content-data.md §3.10b) -> texture stem T_<stem>_<Pack>
OUTFITS = {
    "crew": "Crew_Uniform",
    "civil_a": "Civil_A", "civil_b": "Civil_B", "civil_c": "Civil_C", "civil_d": "Civil_D",
    "civil_e": "Civil_E", "civil_f": "Civil_F", "civil_g": "Civil_G", "civil_h": "Civil_H",
    "thief": "Civil_Thief",  # Day only (DEC-159)
}

# Outfits whose sheets exist but are not uploaded yet (Provisional, owner has not approved the look): registered in
# CrewLooks only once _texture_ids.json has their Day id, so nothing breaks before the upload. raincoat = AST-059
# (ANM-005 Raincoat Lady, Content.Outfits Use "Reserved", sheets from gen_raincoat_textures.py).
PENDING_OUTFITS = {"raincoat": "Civil_Raincoat"}

# Plain Cap (REF_Cap = AST-053_CrewCap, 224 tris): floppy ears or no ears. Everyone else: ears up.
CAP_PLAIN = {"Dog", "Frog", "Monkey", "Penguin", "Pig", "Sheep", "Turtle"}

# HatAttachment / ear sockets of the round heads are 0.30 above the old box head (DEC-152; hcommon.CAP_DZ)
CAP_RAISE = 0.30


def fur_hex(asset: str) -> str:
    from PIL import Image

    im = Image.open(TEX_DIR / f"T_Head_{asset}.png").convert("RGBA")
    counts = Counter(p[:3] for p in im.getdata() if p[3] == 0)
    if not counts:
        raise SystemExit(f"T_Head_{asset}.png has no alpha-0 texel: cannot read the fur colour")
    r, g, b = counts.most_common(1)[0][0]
    return f"{r:02X}{g:02X}{b:02X}"


def sheet_alpha_problems(stem: str) -> list[str]:
    """Day/Mid outfit sheets: fur texels (hands, forearms) must be alpha 0 so MeshPart.Color (species fur) shows.
    Roblox renders partial alpha on a MeshPart TextureID almost opaque: a shared grey overlay hid every species'
    fur on the arms (Mid pack, NPCs at night). Night keeps its navy overlay on purpose (matches the navy heads)."""
    from PIL import Image

    out: list[str] = []
    for pack in ("Day", "Mid"):
        path = TEX_DIR / f"T_{stem}_{pack}.png"
        if not path.exists():
            continue
        partial = sum(1 for p in Image.open(path).convert("RGBA").getdata() if 0 < p[3] < 255)
        if partial:
            out.append(f"{path.name}: {partial} partial-alpha texels (fur must be alpha 0 or the arms lose the fur colour)")
    return out


def build() -> str:
    tex: dict[str, str] = json.loads(TEX_JSON.read_text(encoding="utf-8"))
    blank: dict[str, str] = json.loads(BLANK_JSON.read_text(encoding="utf-8")) if BLANK_JSON.exists() else {}
    problems: list[str] = []
    outfits = dict(OUTFITS)
    for key, stem in PENDING_OUTFITS.items():
        if f"T_{stem}_Day" in tex:
            outfits[key] = stem
        else:
            print(f"gen_crew_looks: outfit '{key}' skipped (no id for T_{stem}_Day in _texture_ids.json yet)")
    for stem in [*OUTFITS.values(), *PENDING_OUTFITS.values()]:
        problems.extend(sheet_alpha_problems(stem))

    def need(key: str) -> str:
        v = tex.get(key)
        if not v:
            problems.append(f"missing texture id {key}")
            return ""
        if not v.startswith("rbxassetid://"):
            problems.append(f"{key} is not an rbxassetid: {v}")
        return v

    # every species head in the JSON must be a known Content.Species key (and vice versa)
    json_heads = {k[len("T_Head_"):] for k in tex if k.startswith("T_Head_") and k.count("_") == 2}
    unknown = json_heads - set(SPECIES.values())
    if unknown:
        problems.append(f"T_Head_* without a Content.Species key: {sorted(unknown)}")

    def need_blank(key: str) -> str:
        v = blank.get(key)
        if not v:
            problems.append(f"missing blank texture id {key}")
            return ""
        if not v.startswith("rbxassetid://"):
            problems.append(f"{key} is not an rbxassetid: {v}")
        return v

    lines: list[str] = []
    w = lines.append
    w("--!strict")
    w("-- GENERATED by tools/assetplace/gen_crew_looks.py from Assets/textures/character/_texture_ids.json")
    w("-- (fur = RGB under the alpha-0 texels of T_Head_<A>.png). Do not edit by hand: change the sources and rerun.")
    w("-- Character texture ids by Content keys (architecture.md §18.9.3, content-data.md §1.3 rule 8). TASK-006.")
    w("-- Missing pack -> Day. Atlas.Day does not exist: the Day atlas is the piece's own texture (DayTextureID).")
    w("")
    w('export type Pack = "Day" | "Mid" | "Night"')
    w("export type BlankLook = { Head: string, Atlas: { [Pack]: string } }")
    w("-- Blank variant (ANM-001 / ANM-004, AST-060): smooth skin-colour head + atlas pieces (ears, tail, nose, snout, beak,")
    w("-- eyes) repainted in the head colour. Absent (nil) for a species without it: Dress falls back to the ordinary look.")
    w("export type SpeciesLook = {")
    w("	Fur: Color3,")
    w("	EarsUp: boolean,")
    w("	CapRaise: number,")
    w("	Head: { [Pack]: string },")
    w("	Blank: BlankLook?,")
    w("}")
    w("export type OutfitLook = { [Pack]: string }")
    w("export type CrewLooks = {")
    w("\tKitVersion: number,")
    w("\tSpecies: { [string]: SpeciesLook },")
    w("\tOutfits: { [string]: OutfitLook },")
    w("\tAtlas: { [Pack]: string },")
    w("}")
    w("")
    w("const looks: CrewLooks = {")
    w(f"\tKitVersion = {KIT_VERSION},")
    w("\tSpecies = { -- keys of Content.Species (18); kit model = Assets.Crew.Animals[Content.Species[k].Asset]")
    for key, asset in SPECIES.items():
        heads = []
        for pack in PACKS:
            suffix = "" if pack == "Day" else "_" + pack
            heads.append(f'{pack} = "{need("T_Head_" + asset + suffix)}"')
        ears_up = "false" if asset in CAP_PLAIN else "true"
        w(f"\t\t{key} = {{ -- {asset}: T_Head_{asset}[_Mid|_Night]")
        w(f'\t\t\tFur = Color3.fromHex("{fur_hex(asset)}"),')
        w(f"\t\t\tEarsUp = {ears_up},")
        w(f"\t\t\tCapRaise = {CAP_RAISE:.2f},")
        w(f"\t\t\tHead = {{ {', '.join(heads)} }},")
        if f"T_Head_{asset}_Blank" in blank:
            atlas = ", ".join(
                f'{pack} = "{need_blank(f"T_Atlas_Kitchen_{pack}_Blank_{asset}")}"' for pack in PACKS
            )
            w(f'\t\t\tBlank = {{ Head = "{need_blank(f"T_Head_{asset}_Blank")}", Atlas = {{ {atlas} }} }},')
        w("\t\t},")
    w("\t},")
    w("\tOutfits = { -- keys of Content.Outfits")
    for key, stem in outfits.items():
        packs = []
        for pack in PACKS:
            k = f"T_{stem}_{pack}"
            if k in tex:
                packs.append(f'{pack} = "{need(k)}"')
        if not any(p.startswith("Day ") for p in packs):
            need(f"T_{stem}_Day")
        w(f"\t\t{key} = {{ {', '.join(packs)} }}, -- T_{stem}_<Pack>")
    w("\t},")
    w(f'\tAtlas = {{ Mid = "{need("T_Atlas_Kitchen_Mid")}", Night = "{need("T_Atlas_Kitchen_Night")}" }},')
    w("}")
    w("")
    w("for _, s in looks.Species do")
    w("\ttable.freeze(s.Head)")
    w("\tif s.Blank then")
    w("\t\ttable.freeze(s.Blank.Atlas)")
    w("\t\ttable.freeze(s.Blank)")
    w("\tend")
    w("\ttable.freeze(s)")
    w("end")
    w("for _, o in looks.Outfits do")
    w("\ttable.freeze(o)")
    w("end")
    w("table.freeze(looks.Species)")
    w("table.freeze(looks.Outfits)")
    w("table.freeze(looks.Atlas)")
    w("return table.freeze(looks)")
    w("")

    if problems:
        raise SystemExit("gen_crew_looks: " + "; ".join(problems))
    return "\n".join(lines)


def main() -> None:
    text = build()
    if "--check" in sys.argv:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != text:
            print(f"{OUT.relative_to(ROOT)} is out of date: run tools/assetplace/gen_crew_looks.py")
            sys.exit(1)
        print("CrewLooks up to date")
        return
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(SPECIES)} species, {len(OUTFITS)} outfits")


if __name__ == "__main__":
    main()
