"""Validate publisher metadata before embedding a CazeTV ID in a signed build."""
import json
import os
import re
from pathlib import Path
from urllib.parse import urlencode, urlsplit
from urllib.request import Request, urlopen

OFFICIAL_PATHS = {"/@cazetv", "/channel/UCZiYbVptd3PVPf4f6eR6UaQ"}

def official_author(value):
    if not isinstance(value, str):
        return False
    uri = urlsplit(value)
    return (uri.scheme == "https" and uri.netloc == "www.youtube.com"
            and not uri.query and not uri.fragment
            and (uri.path.lower() == "/@cazetv"
                 or uri.path in OFFICIAL_PATHS))

def download(url):
    request = Request(url, headers={"Accept": "application/json"})
    with urlopen(request, timeout=10) as response:
        data = response.read(65537)
        if len(data) > 65536:
            raise ValueError("Oversized metadata")
        return json.loads(data)

def validate(video_id, fetch=download):
    if not re.fullmatch(r"[A-Za-z0-9_-]{11}", video_id):
        raise ValueError("Invalid YouTube video ID")
    url = "https://www.youtube.com/watch?" + urlencode({"v": video_id})
    payload = fetch("https://www.youtube.com/oembed?" +
                    urlencode({"url": url, "format": "json"}))
    if (not isinstance(payload, dict) or payload.get("type") != "video"
            or payload.get("provider_name") != "YouTube"
            or not official_author(payload.get("author_url"))):
        raise ValueError("Official CazeTV publisher could not be verified")
    return {"video_url": url, "author_url": payload["author_url"],
            "metadata_verified": True, "playback_verified": False}

def main():
    video_id = os.environ.get("CAZETV_YOUTUBE_VIDEO_ID", "")
    evidence = {"metadata_verified": False, "playback_verified": False}
    if video_id:
        try:
            evidence = validate(video_id)
        except Exception:
            raise SystemExit("CazeTV source unavailable or not official; build stopped.")
    evidence["commit"] = os.environ.get("GITHUB_SHA", "")
    path = Path("build/qa/cazetv-source.json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(evidence, indent=2), encoding="utf-8")
    print("CazeTV metadata verified; physical playback pending." if video_id
          else "No CazeTV source configured; playback unavailable.")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as stream:
            stream.write("\n### CazeTV source\n")
            stream.write("Official metadata checked; Android/TV playback pending.\n"
                         if video_id else "No video configured. CazeTV unavailable.\n")

if __name__ == "__main__":
    main()
