#!/usr/bin/env python3
"""Creates (or resets) the Vastra demo account used for screenshots and the Devpost video.

Uploads a portrait and a small closet, then runs the real backend on it: Gemini tagging,
YouCam background removal, today's looks, one YouCam try-on, one Dress up outfit and a
Recreate-a-look result. Costs roughly 20 YouCam units.

Usage (from the vastra/ folder): python3 scripts/seed_demo.py
"""

import json
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path.home() / ".cursor/projects/Users-vin-YouCam-Hackathon/assets"
ENV = dict(
    line.split("=", 1)
    for line in (ROOT / ".env.local").read_text().splitlines()
    if "=" in line and not line.startswith("#")
)
API_KEY = ENV["NEXT_PUBLIC_FIREBASE_API_KEY"]
PROJECT = ENV["NEXT_PUBLIC_FIREBASE_PROJECT_ID"]
BUCKET = ENV["NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET"]
FIRESTORE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"

EMAIL = "maya.demo@vastra-demo.dev"
PASSWORD = "VastraDemo!2026"
DAY_MS = 86_400_000

# file, wear count, days since last worn (None = never)
CLOSET = [
    ("g_cardigan.jpg", 4, 3),
    ("g_jeans.jpg", 9, 1),
    ("g_dress.jpg", 0, None),
    ("g_trench.jpg", 3, 6),
    ("g_sneakers.jpg", 12, 1),
    ("g_skirt.jpg", 1, 41),
    ("g_stripes.jpg", 5, 4),
    ("g_boots.jpg", 2, 12),
    ("g_blouse.jpg", 2, 9),
]


def fn_url(fn):
    return f"https://{fn.lower()}-u2ibcbbb7a-ew.a.run.app"


def request(method, url, body=None, headers=None, raw=False, timeout=300):
    data = body if raw else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    if body is not None and not raw:
        req.add_header("Content-Type", "application/json")
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as res:
                return json.loads(res.read().decode() or "{}")
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"{method} {url.split('?')[0]} -> {e.code}: {e.read().decode()[:300]}")
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            if attempt == 4:
                raise
            time.sleep(3 * (attempt + 1))


def fs_value(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if v is None:
        return {"nullValue": None}
    if isinstance(v, list):
        return {"arrayValue": {"values": [fs_value(x) for x in v]}}
    return {"stringValue": str(v)}


def fields(d):
    return {"fields": {k: fs_value(v) for k, v in d.items()}}


def auth(endpoint):
    return request("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:{endpoint}?key={API_KEY}",
                   {"email": EMAIL, "password": PASSWORD, "returnSecureToken": True})


def main():
    try:
        old = auth("signInWithPassword")
        print("resetting existing demo account…")
        request("POST", fn_url("deleteAccount"), {}, {"Authorization": f"Bearer {old['idToken']}"})
    except RuntimeError:
        pass
    session = auth("signUp")
    token, uid = session["idToken"], session["localId"]
    bearer = {"Authorization": f"Bearer {token}"}

    def call(fn, body):
        started = time.time()
        out = request("POST", fn_url(fn), body, bearer)
        print(f"  {fn} ok in {time.time() - started:.1f}s")
        return out

    def upload(path, file):
        content = (ASSETS / file).read_bytes()
        meta = request("POST",
                       f"https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o?uploadType=media&name={urllib.parse.quote(path, safe='')}",
                       content, {"Authorization": f"Firebase {token}", "Content-Type": "image/jpeg"}, raw=True)
        return f"https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o/{urllib.parse.quote(path, safe='')}?alt=media&token={meta['downloadTokens']}"

    now = int(time.time() * 1000)
    print("▸ Profile + portrait")
    portrait_path = f"users/{uid}/tryon/person-{now}.jpg"
    portrait_url = upload(portrait_path, "demo_portrait.jpg")
    request("PATCH", f"{FIRESTORE}/users/{uid}", fields({
        "uid": uid, "email": EMAIL, "displayName": "Maya", "createdAt": now - 21 * DAY_MS, "updatedAt": now,
        "onboardingComplete": True, "onboardingStep": 6, "preferredCity": "London",
        "vibes": ["Minimal", "Cottagecore", "Old money"], "favouriteColours": ["Cream", "Beige", "Green"],
        "occasions": ["work", "casual", "date"], "genderPresentation": "feminine",
        "styleNotes": "Soft neutrals, a little floral, comfy shoes always",
        "tryOnPhotoPath": portrait_path, "tryOnPhotoUrl": portrait_url,
    }), bearer)

    print("▸ Closet: upload, Gemini tagging, YouCam background removal")
    ids = []
    for i, (file, worn, days) in enumerate(CLOSET):
        path = f"users/{uid}/wardrobe/{now + i}.jpg"
        url = upload(path, file)
        item_id = f"demo{i:02d}"
        request("PATCH", f"{FIRESTORE}/users/{uid}/wardrobeItems/{item_id}", fields({
            "userId": uid, "name": "New piece", "category": "tops", "colour": "", "pattern": None,
            "seasonTags": [], "occasionTags": [], "imagePath": path, "imageUrl": url, "tagging": True,
            "wearCount": worn, "lastWornAt": None if days is None else now - days * DAY_MS, "youcamFileId": None,
            "createdAt": now - (len(CLOSET) - i) * DAY_MS, "updatedAt": now,
        }), bearer)
        ids.append(item_id)
    with ThreadPoolExecutor(4) as pool:
        tags = list(pool.map(lambda i: call("tagGarment", {"itemId": i}), ids))
        list(pool.map(lambda i: call("cutoutImage", {"itemId": i}), ids))
    call("cutoutImage", {"portrait": True})
    by_name = {}
    for item_id, tag in zip(ids, tags):
        item = tag["item"]
        by_name[item_id] = item
        print(f"    {item_id}: {item['name']} · {item['category']} · {item['colour']}")

    def pick(*cats):
        return next(i for i in ids if by_name[i]["category"] in cats)

    print("▸ Today's looks")
    day = time.strftime("%Y-%m-%d")
    for occasion in ("casual", "work", "date"):
        looks = call("dressMeToday", {"occasion": occasion, "day": day})
        print(f"    {occasion}: {[s['title'] for s in looks.get('suggestions', [])]}")

    print("▸ YouCam try-on (floral dress)")
    dress = pick("dresses")
    job = call("startTryOn", {"wardrobeItemId": dress, "garmentCategory": "full_body", "title": by_name[dress]["name"]})
    for _ in range(50):
        time.sleep(3)
        poll = request("POST", fn_url("pollTryOn"), {"jobId": job["jobId"]}, bearer)
        if poll["status"] != "processing":
            break
    print(f"    {poll['status']}")
    if poll["status"] == "success":
        request("PATCH", f"{FIRESTORE}/users/{uid}/tryOnJobs/{job['jobId']}?updateMask.fieldPaths=favourite",
                fields({"favourite": True}), bearer)

    print("▸ Dress up (cardigan + jeans + sneakers)")
    outfit = [pick("tops", "outerwear"), pick("trousers"), pick("shoes")]
    look = call("dressUp", {"itemIds": outfit})
    print(f"    stage cutout: {bool(look.get('cutoutUrl'))}")

    print("▸ Recreate a look (Paris street style)")
    inspo_path = f"users/{uid}/inspiration/{now}.jpg"
    inspo = call("recreateLook", {"imagePath": inspo_path, "imageUrl": upload(inspo_path, "inspo_street.jpg")})
    print(f"    {inspo['title']} · {inspo['score']}% — {inspo['summary']}")

    print(f"\nDemo account ready: {EMAIL} / {PASSWORD}")


if __name__ == "__main__":
    main()
