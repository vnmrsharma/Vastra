#!/usr/bin/env python3
"""End-to-end check of the live Vastra backend.

Creates a throwaway account, uploads a portrait and a closet photo, runs
Gemini tagging, Dress me today and one real YouCam try-on (2 units), then
deletes every file, document and the account itself.

Usage: python3 scripts/smoke_test.py [--skip-tryon]   (run from the vastra/ folder)
"""

import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ENV = dict(
    line.split("=", 1)
    for line in Path(".env.local").read_text().splitlines()
    if "=" in line and not line.startswith("#")
)
API_KEY = ENV["NEXT_PUBLIC_FIREBASE_API_KEY"]
PROJECT = ENV["NEXT_PUBLIC_FIREBASE_PROJECT_ID"]
BUCKET = ENV["NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET"]
FUNCTIONS = ENV["NEXT_PUBLIC_FUNCTIONS_URL"].rstrip("/")
def fn_url(fn):
    # Direct Cloud Run host (some networks block *.cloudfunctions.net), same as the app uses.
    return f"https://{fn.lower()}-u2ibcbbb7a-ew.a.run.app"


FIRESTORE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"

PERSON_URL = "https://plugins-media.makeupar.com/strapi/assets/clothes_03_cccd5d4803.jpeg"
GARMENT_URL = "https://plugins-media.makeupar.com/strapi/assets/clothes_reference_full_body_01_5a000d999f.png"


def request(method, url, body=None, headers=None, raw=False):
    data = body if raw else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    if body is not None and not raw:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=120) as res:
            text = res.read().decode() or "{}"
            return json.loads(text)
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {url.split('?')[0]} -> {e.code}: {e.read().decode()[:300]}")


def fs_value(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if v is None:
        return {"nullValue": None}
    return {"stringValue": str(v)}


def step(name):
    print(f"\n▸ {name}")


def main():
    email = f"smoke-{uuid.uuid4().hex[:8]}@vastra-test.dev"
    step(f"Create temp account {email}")
    auth = request("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
                   {"email": email, "password": uuid.uuid4().hex, "returnSecureToken": True})
    token, uid = auth["idToken"], auth["localId"]
    bearer = {"Authorization": f"Bearer {token}"}
    uploaded_paths = []

    def upload(path, source_url):
        content = urllib.request.urlopen(source_url, timeout=60).read()
        ctype = "image/png" if source_url.endswith(".png") else "image/jpeg"
        meta = request("POST",
                       f"https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o?uploadType=media&name={urllib.parse.quote(path, safe='')}",
                       content, {"Authorization": f"Firebase {token}", "Content-Type": ctype}, raw=True)
        uploaded_paths.append(path)
        return f"https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o/{urllib.parse.quote(path, safe='')}?alt=media&token={meta['downloadTokens']}"

    def call(fn, body):
        started = time.time()
        result = request("POST", fn_url(fn), body, bearer)
        print(f"  {fn} ok in {time.time() - started:.1f}s")
        return result

    try:
        step("Upload portrait + profile")
        person_path = f"users/{uid}/tryon/person-smoke.jpg"
        person_url = upload(person_path, PERSON_URL)
        now = int(time.time() * 1000)
        request("PATCH", f"{FIRESTORE}/users/{uid}", {"fields": {k: fs_value(v) for k, v in {
            "uid": uid, "email": email, "displayName": "Smoke Test", "createdAt": now,
            "onboardingComplete": True, "preferredCity": "London",
            "tryOnPhotoPath": person_path, "tryOnPhotoUrl": person_url}.items()}}, bearer)

        step("Add two closet pieces + Gemini tagging")
        item_ids = []
        for i in range(2):
            path = f"users/{uid}/wardrobe/smoke-{i}.png"
            url = upload(path, GARMENT_URL)
            item_id = f"smoke{i}"
            request("PATCH", f"{FIRESTORE}/users/{uid}/wardrobeItems/{item_id}", {"fields": {k: fs_value(v) for k, v in {
                "userId": uid, "name": "New piece", "category": "tops", "colour": "", "imagePath": path,
                "imageUrl": url, "tagging": True, "createdAt": now + i}.items()}}, bearer)
            item_ids.append(item_id)
        tag = call("tagGarment", {"itemId": item_ids[0]})
        print(f"  tagged as: {tag['item']['name']} · {tag['item']['category']} · {tag['item']['colour']}")
        call("tagGarment", {"itemId": item_ids[1]})

        step("Dress me today")
        day = time.strftime("%Y-%m-%d")
        today = call("dressMeToday", {"occasion": "casual", "day": day})
        saved = request("GET", f"{FIRESTORE}/users/{uid}/dailyLooks/{day}_casual", headers=bearer)
        print(f"  saved for instant reopen: {'suggestions' in saved.get('fields', {})}")
        weather = today.get("weather") or {}
        print(f"  weather: {weather.get('location')} {weather.get('temperatureC')}° {weather.get('description')}")
        print(f"  looks: {[s['title'] for s in today.get('suggestions', [])]} {today.get('note') or ''}")
        for s in today.get("suggestions", []):
            print(f"    - {s['title']}: {[i['name'] for i in s['items']]}")

        step("Recreate a look from an outfit photo")
        for i, (name, cat, colour) in enumerate([("Camel ribbed tee", "tops", "camel"),
                                                  ("Charcoal slim jeans", "trousers", "charcoal grey"),
                                                  ("Black chelsea boots", "shoes", "black"),
                                                  ("Red floral midi dress", "dresses", "red")]):
            item_id = f"smokeextra{i}"
            request("PATCH", f"{FIRESTORE}/users/{uid}/wardrobeItems/{item_id}", {"fields": {k: fs_value(v) for k, v in {
                "userId": uid, "name": name, "category": cat, "colour": colour, "imagePath": "",
                "imageUrl": "", "tagging": False, "createdAt": now + 10 + i}.items()}}, bearer)
            item_ids.append(item_id)
        insp_path = f"users/{uid}/inspiration/smoke.jpg"
        insp_url = upload(insp_path, PERSON_URL)
        look = call("recreateLook", {"imagePath": insp_path, "imageUrl": insp_url})
        print(f"  {look['title']} · {look['vibe']} · {look['score']}% — {look['summary']}")
        for p in look["pieces"]:
            print(f"    - {p['piece']} → {p['closeness']}: {(p.get('item') or {}).get('name', '—')}")
        assert all(p["item"] is None or p["item"]["id"] in item_ids for p in look["pieces"])

        if "--cutouts" in sys.argv:
            step("Optimised cutout (1 unit)")
            cut = call("cutoutImage", {"itemId": item_ids[0]})
            with urllib.request.urlopen(cut["cutoutUrl"], timeout=60) as r:
                print(f"  {len(r.read()) // 1024} KB · {r.headers.get('Content-Type')} · {r.headers.get('Cache-Control')}")
            doc = request("GET", f"{FIRESTORE}/users/{uid}/wardrobeItems/{item_ids[0]}", headers=bearer)["fields"]
            with urllib.request.urlopen(doc["cutoutThumbUrl"]["stringValue"], timeout=60) as r:
                print(f"  thumbnail {len(r.read()) // 1024} KB")

        if "--dress-up" in sys.argv:
            step("Background removal: closet piece + portrait (2 units)")
            cut = call("cutoutImage", {"itemId": item_ids[0]})
            print(f"  piece cutout saved: {'firebasestorage' in cut['cutoutUrl']}")
            cut = call("cutoutImage", {"portrait": True})
            print(f"  portrait cutout saved: {'firebasestorage' in cut['cutoutUrl']}")

            step("Dress up: full outfit + jacket layered on top (5 units)")
            request("PATCH", f"{FIRESTORE}/users/{uid}/wardrobeItems/{item_ids[0]}?updateMask.fieldPaths=category",
                    {"fields": {"category": fs_value("outerwear")}}, bearer)
            request("PATCH", f"{FIRESTORE}/users/{uid}/wardrobeItems/{item_ids[1]}?updateMask.fieldPaths=category",
                    {"fields": {"category": fs_value("dresses")}}, bearer)
            look = call("dressUp", {"itemIds": [item_ids[0], item_ids[1]]})
            print(f"  result saved: {'firebasestorage' in look['resultUrl']} · stage cutout: {bool(look.get('cutoutUrl'))}")
            again = call("dressUp", {"itemIds": [item_ids[1], item_ids[0]]})
            print(f"  same combo again served from cache: {again.get('cached') is True}")

        if "--skip-tryon" in sys.argv:
            return

        step("YouCam try-on (2 units)")
        job = call("startTryOn", {"wardrobeItemId": item_ids[0], "garmentCategory": "full_body", "title": "Smoke test"})
        for _ in range(40):
            time.sleep(3)
            poll = request("POST", fn_url("pollTryOn"), {"jobId": job["jobId"]}, bearer)
            if poll["status"] != "processing":
                break
        print(f"  status: {poll['status']} {poll.get('error') or ''}")
        if poll["status"] == "success":
            print(f"  result persisted to Storage: {'firebasestorage' in poll['resultUrl']}")
    finally:
        step("Clean up")
        listing = request("GET", f"https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o?prefix={urllib.parse.quote(f'users/{uid}/', safe='')}",
                          headers={"Authorization": f"Firebase {token}"})
        for obj in listing.get("items", []):
            request("DELETE", f"https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o/{urllib.parse.quote(obj['name'], safe='')}",
                    headers={"Authorization": f"Firebase {token}"})
        for sub in ("wardrobeItems", "tryOnJobs", "inspirations"):
            docs = request("GET", f"{FIRESTORE}/users/{uid}/{sub}", headers=bearer).get("documents", [])
            for d in docs:
                request("DELETE", f"https://firestore.googleapis.com/v1/{d['name']}", headers=bearer)
        request("DELETE", f"{FIRESTORE}/users/{uid}", headers=bearer)
        request("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:delete?key={API_KEY}", {"idToken": token})
        print("  temp account, files and documents deleted")


if __name__ == "__main__":
    main()
