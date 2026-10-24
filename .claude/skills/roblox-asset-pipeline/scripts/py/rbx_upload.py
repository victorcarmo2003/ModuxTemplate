"""Upload FBX files to Roblox as Model assets via Open Cloud (Assets API v1), owned by a group.

  python rbx_upload.py --group 773736808 --map Assets/import/_asset_ids.json file1.fbx [file2.fbx ...]

Reads the API key from the ROBLOX_API_KEY user environment variable (registry HKCU\\Environment if the
current process does not have it). Never prints the key. Writes/updates the name -> assetId map after each file.
"""
import argparse, json, os, sys, time, uuid, urllib.request, urllib.error


def api_key():
    k = os.environ.get("ROBLOX_API_KEY")
    if not k:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as h:
            k = winreg.QueryValueEx(h, "ROBLOX_API_KEY")[0]
    return k


def req(method, url, key, body=None, ctype=None):
    r = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key, **({"Content-Type": ctype} if ctype else {})})
    try:
        with urllib.request.urlopen(r, timeout=120) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.read().decode("utf-8", "replace")[:500]}


def upload(path, group, key):
    name = os.path.splitext(os.path.basename(path))[0]
    meta = {"assetType": "Model", "displayName": name, "description": "Sell Hotdogs asset " + name,
            "creationContext": {"creator": {"groupId": str(group)}}}
    b = uuid.uuid4().hex
    data = open(path, "rb").read()
    body = (f"--{b}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n"
            + json.dumps(meta) + f"\r\n--{b}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.fbx\"\r\n"
            "Content-Type: model/fbx\r\n\r\n").encode() + data + f"\r\n--{b}--\r\n".encode()
    st, js = req("POST", "https://apis.roblox.com/assets/v1/assets", key, body, f"multipart/form-data; boundary={b}")
    if st >= 300:
        return name, None, f"HTTP {st} {js}"
    op = js.get("path") or ("operations/" + js.get("operationId", ""))
    for _ in range(60):
        if js.get("done"):
            break
        time.sleep(2)
        st, js = req("GET", "https://apis.roblox.com/assets/v1/" + op, key)
        if st >= 300:
            return name, None, f"poll HTTP {st} {js}"
    resp = js.get("response") or {}
    aid = resp.get("assetId")
    return name, aid, None if aid else f"no assetId: {js}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--group", required=True)
    ap.add_argument("--map", required=True)
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()
    key = api_key()
    m = json.load(open(a.map)) if os.path.exists(a.map) else {}
    for f in a.files:
        name = os.path.splitext(os.path.basename(f))[0]
        if name in m:
            print("SKIP", name, m[name]); continue
        name, aid, err = upload(f, a.group, key)
        if aid:
            m[name] = aid
            json.dump(m, open(a.map, "w"), indent=1, sort_keys=True)
            print("OK", name, aid, flush=True)
        else:
            print("FAIL", name, err, flush=True)
        time.sleep(1.0)


if __name__ == "__main__":
    main()
