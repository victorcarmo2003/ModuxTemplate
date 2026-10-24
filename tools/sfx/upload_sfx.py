"""Upload one generated SFX file (wav/ogg/mp3) to Roblox as an Audio asset of the game's group (Open Cloud).

  python tools/sfx/upload_sfx.py <path> <displayName> [--group 773736808]

Same key and group as tools/voice/upload.py (ROBLOX_API_KEY from env or the user registry; never printed).
Prints the asset id.
"""
import argparse
import json
import os
import sys
import time
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "voice"))
from upload import BASE, api_key, req  # noqa: E402

TYPES = {".wav": "audio/wav", ".ogg": "audio/ogg", ".mp3": "audio/mpeg"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("name")
    ap.add_argument("--group", default="773736808")
    a = ap.parse_args()
    ext = os.path.splitext(a.path)[1].lower()
    ctype = TYPES[ext]
    key = api_key()
    meta = {"assetType": "Audio", "displayName": a.name, "description": "Sell Hotdogs SFX (generated)",
            "creationContext": {"creator": {"groupId": str(a.group)}}}
    b = uuid.uuid4().hex
    body = (f"--{b}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n"
            + json.dumps(meta) + f"\r\n--{b}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{a.name}{ext}\"\r\n"
            f"Content-Type: {ctype}\r\n\r\n").encode() + open(a.path, "rb").read() + f"\r\n--{b}--\r\n".encode()
    st, js = req("POST", BASE + "assets", key, body, f"multipart/form-data; boundary={b}")
    if st >= 300:
        sys.exit(f"HTTP {st} {js.get('error', '')}")
    op = js.get("path") or ("operations/" + js.get("operationId", ""))
    for _ in range(90):
        if js.get("done"):
            break
        time.sleep(2)
        st, js = req("GET", BASE + op, key)
        if st >= 300:
            sys.exit(f"poll HTTP {st} {js.get('error', '')}")
    if not js.get("done") or "error" in js:
        sys.exit(f"not done / rejected: {json.dumps(js)[:300]}")
    print((js.get("response") or {}).get("assetId"))


if __name__ == "__main__":
    main()
