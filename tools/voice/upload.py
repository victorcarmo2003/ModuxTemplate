"""Upload the generated voice lines (Assets/audio/voice/<speaker>/<key>.ogg) to Roblox as Audio assets (Open Cloud).

  python upload.py [--group 773736808] [--only KEY]

Resumable: lines with an assetId (or status rejected) in assets.json are skipped. ~1 request/s, backoff on 429.
The API key is read only from ROBLOX_API_KEY (env, or the user registry on Windows) and is never printed.
assets.json[key] gets: assetId, status ("ok" | "rejected" | "error"), reason.
"""
import argparse, json, os, sys, time, uuid, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
META = os.path.join(HERE, "assets.json")
BASE = "https://apis.roblox.com/assets/v1/"


def api_key():
    k = os.environ.get("ROBLOX_API_KEY")
    if not k:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as h:
            k = winreg.QueryValueEx(h, "ROBLOX_API_KEY")[0]
    return k


def req(method, url, key, body=None, ctype=None):
    for attempt in range(8):
        r = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key, **({"Content-Type": ctype} if ctype else {})})
        try:
            with urllib.request.urlopen(r, timeout=120) as resp:
                return resp.status, json.loads(resp.read() or b"{}")
        except urllib.error.HTTPError as e:
            text = e.read().decode("utf-8", "replace")[:600]
            if e.code == 429 or e.code >= 500:
                time.sleep(min(5 * 2 ** attempt, 120))
                continue
            return e.code, {"error": text}
    return 429, {"error": "rate limited after retries"}


def upload(key_id, path, group, key):
    meta = {"assetType": "Audio", "displayName": key_id, "description": "Sell Hotdogs voice line (AI generated, Kokoro-82M)",
            "creationContext": {"creator": {"groupId": str(group)}}}
    b = uuid.uuid4().hex
    body = (f"--{b}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n"
            + json.dumps(meta) + f"\r\n--{b}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{key_id}.ogg\"\r\n"
            "Content-Type: audio/ogg\r\n\r\n").encode() + open(path, "rb").read() + f"\r\n--{b}--\r\n".encode()
    st, js = req("POST", BASE + "assets", key, body, f"multipart/form-data; boundary={b}")
    if st >= 300:
        return None, "error", f"HTTP {st} {js.get('error', '')}"
    op = js.get("path") or ("operations/" + js.get("operationId", ""))
    for _ in range(90):
        if js.get("done"):
            break
        time.sleep(2)
        st, js = req("GET", BASE + op, key)
        if st >= 300:
            return None, "error", f"poll HTTP {st} {js.get('error', '')}"
    if not js.get("done"):
        return None, "error", "operation timeout"
    if "error" in js:
        return None, "rejected", json.dumps(js["error"])[:300]
    aid = (js.get("response") or {}).get("assetId")
    return (aid, "ok", "") if aid else (None, "rejected", f"no assetId: {json.dumps(js)[:300]}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--group", default="773736808")
    ap.add_argument("--only")
    a = ap.parse_args()
    key = api_key()
    meta = json.load(open(META))
    todo = [k for k, m in meta.items() if (not a.only or k == a.only) and not m.get("assetId") and m.get("status") not in ("rejected",)]
    print(f"{len(todo)} to upload", flush=True)
    for n, k in enumerate(todo, 1):
        m = meta[k]
        path = os.path.join(ROOT, "Assets", "audio", "voice", m["speaker"], k + ".ogg")
        aid, status, reason = upload(k, path, a.group, key)
        m.update(status=status, reason=reason)
        if aid:
            m["assetId"] = str(aid)
        json.dump(meta, open(META, "w"), indent=1)
        print(n, len(todo), k, status, aid or reason, flush=True)
        time.sleep(1)


if __name__ == "__main__":
    main()
