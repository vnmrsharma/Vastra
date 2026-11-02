#!/usr/bin/env python3
"""Cuts Pip out of her plain-background poses with YouCam AI Background Removal
(1 unit per image) and saves transparent PNGs into vastra_app/assets/pip/.

Usage (from the vastra/ folder): python3 scripts/pip_cutouts.py
Already-generated poses are skipped, so re-running only processes new ones.
"""

import json
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "Pip"
OUT = ROOT / "vastra_app" / "assets" / "pip"

POSES = {
    "happy": "Happy.png",
    "cheeky": "Cheeky.png",
    "cheerful": "Cheerful.png",
    "curious": "Curious.png",
    "excited": "Excited.png",
    "searching": "Searching.png",
    "thoughtful": "Thoughtful.png",
    "celebration": "Celebration.png",
    "rampwalk": "Rampwalk.png",
    "lets_style": "Lets style this.png",
    "loving_it": "loving it.png",
    "outfit_reveal": "Outfit Reveal.png",
    "waiting": "Waiting Sweetly with an Hourglass.png",
}

ENV = dict(
    line.split("=", 1)
    for line in (ROOT / "vastra" / ".env.local").read_text().splitlines()
    if "=" in line and not line.startswith("#")
)
KEY = ENV["YOUCAM_API_KEY"]
BASE = "https://yce-api-01.makeupar.com/s2s/v2.0"


def api(method, path, body=None):
    req = urllib.request.Request(
        f"{BASE}{path}",
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            return json.loads(res.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {path} -> {e.code}: {e.read().decode()[:300]}")


def upload(path: Path) -> str:
    data = path.read_bytes()
    init = api("POST", "/file", {"files": [{"content_type": "image/png", "file_name": "pip.png", "file_size": len(data)}]})
    file = init["data"]["files"][0]
    put = file["requests"][0]
    headers = {k: v for k, v in put["headers"].items() if k.lower() != "content-length"}
    urllib.request.urlopen(urllib.request.Request(put["url"], data=data, method="PUT", headers=headers), timeout=120)
    return file["file_id"]


def remove_background(path: Path) -> bytes:
    task = api("POST", "/task/sod", {"src_file_id": upload(path)})["data"]["task_id"]
    for _ in range(60):
        time.sleep(2)
        data = api("GET", f"/task/sod/{task}")["data"]
        if data.get("task_status") == "success":
            return urllib.request.urlopen(data["results"]["url"], timeout=120).read()
        if data.get("task_status") == "error":
            raise RuntimeError(data.get("error"))
    raise RuntimeError("timed out")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, file in POSES.items():
        out = OUT / f"{name}.png"
        if out.exists():
            print(f"skip {name}")
            continue
        try:
            out.write_bytes(remove_background(SRC / file))
            print(f"ok   {name}")
        except Exception as e:  # keep going so one bad pose doesn't block the rest
            print(f"FAIL {name}: {e}")


if __name__ == "__main__":
    main()
