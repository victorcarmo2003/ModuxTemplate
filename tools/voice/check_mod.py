"""Moderation state of every uploaded line (Open Cloud GET assets/{id}); marks declined ones as rejected in assets.json."""
import json, sys, time, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import upload as U
key = U.api_key()
meta = json.load(open(U.META))
from collections import Counter
c = Counter()
for k, m in meta.items():
    if not m.get("assetId"):
        continue
    st, js = U.req("GET", f"{U.BASE}assets/{m['assetId']}?readMask=moderationResult", key)
    s = (js.get("moderationResult") or {}).get("moderationState", f"http{st}")
    c[s] += 1
    m["moderation"] = s
    if s == "Rejected":
        m["status"] = "rejected"; m["reason"] = "moderation"
        m.pop("assetId")
    time.sleep(0.2)
json.dump(meta, open(U.META, "w"), indent=1)
print(dict(c))
