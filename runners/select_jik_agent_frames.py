#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import json

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "apps/dashboard/public/assets/jik"
CHAR_DIR = ASSET_DIR / "metrocity-characters"
CONFIG = CHAR_DIR / "agent-frame-map.json"

DEFAULT_CONFIG = {
    "source": "agent-suit.png",
    "frame_width": 32,
    "frame_height": 32,
    "agents": {
        "pm": [0, 0],
        "engineer": [1, 0],
        "qa": [2, 0],
        "devops": [3, 0],
        "owner": [4, 0]
    }
}

def main():
    CHAR_DIR.mkdir(parents=True, exist_ok=True)

    if not CONFIG.exists():
        CONFIG.write_text(json.dumps(DEFAULT_CONFIG, indent=2))

    config = json.loads(CONFIG.read_text())

    source = CHAR_DIR / config["source"]
    if not source.exists():
        fallback = ASSET_DIR / "_processed/metrocity-2/MetroCity 2.0/Suit.png"
        if fallback.exists():
            source = fallback
        else:
            raise SystemExit(f"Missing sprite source: {source}")

    sheet = Image.open(source).convert("RGBA")
    frame_w = int(config.get("frame_width", 32))
    frame_h = int(config.get("frame_height", 32))

    for agent, coords in config["agents"].items():
        x, y = coords
        frame = sheet.crop((x * frame_w, y * frame_h, x * frame_w + frame_w, y * frame_h + frame_h))
        out = CHAR_DIR / f"{agent}.png"
        frame.save(out)
        print(f"{agent}: frame=({x},{y}) -> {out}")

if __name__ == "__main__":
    main()
