#!/usr/bin/env python3
"""
generate-wishdrop.py

Parses Documentation/MacAppStore付费游戏.md and generates .wishdrop preset files
compatible with AppDrop for single-click import.

Only true upfront-paid games (with direct purchase prices in App Store) are included.
Free-to-download / in-app buyout games (showing Free / $0.00) and games with missing
base prices in iTunes API are excluded.
"""

import os
import re
import json
from datetime import datetime, timezone

DOC_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Documentation", "MacAppStore付费游戏.md")
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Excluded from wishdrop presets:
# - Free-to-try prologue downloads that unlock via in-app purchase (base price reported as $0.00/Free)
# - Games where the App Store API does not provide a direct upfront purchase price ("价格待获取")
EXCLUDED_TRACK_IDS = {
    "6462360082",  # 生化危机 4 重制版 / Resident Evil 4 (Remake) - Free
    "1640629241",  # 生化危机 7 / RESIDENT EVIL 7 biohazard - Free
    "1640632432",  # 生化危机 2 重制版 / RESIDENT EVIL 2 (Remake) - Free
    "1640630077",  # 生化危机 3 重制版 / RESIDENT EVIL 3 (Remake) - Free
    "6477828959",  # 狙击精英 4 / Sniper Elite 4 - Free
    "6526463862",  # 渔帆暗涌 / DREDGE - Free
    "1615755735",  # 无人深空 / No Man's Sky - 价格待获取
    "1639580858",  # 咩咩启示录 / Cult of the Lamb - 价格待获取
}

def parse_markdown(doc_path: str):
    with open(doc_path, "r", encoding="utf-8") as f:
        text = f.read()

    # Split by game item headers: ### 🎯 <Title>
    sections = re.split(r'###\s+🎯\s+', text)[1:]
    apps = []
    excluded = []

    for idx, s in enumerate(sections, 1):
        lines = s.strip().split('\n')
        title = lines[0].strip()

        # Find App Store URLs: [text](https://apps.apple.com/...)
        links = re.findall(r'\[([^\]]+)\]\((https://apps\.apple\.com/[^\)]+)\)', s)
        if not links:
            raise ValueError(f"No store links found for entry {idx}: {title}")

        # Prefer the direct desktop link with ?mt=12
        first_lbl, first_url = links[0]
        m = re.search(r'apps\.apple\.com/([a-zA-Z]{2})/app/(?:[^/]+/)?id(\d+)', first_url)
        if not m:
            raise ValueError(f"Could not parse country and track ID from URL: {first_url}")

        country = m.group(1).lower()
        track_id = m.group(2)

        if track_id in EXCLUDED_TRACK_IDS:
            excluded.append((track_id, title))
            continue

        # Basic integrity checks matching WishdropCodec.swift
        if not (6 <= len(track_id) <= 12 and track_id.isdigit()):
            raise ValueError(f"Invalid track ID '{track_id}' for {title}")
        if country not in ["us", "cn", "hk", "tw", "jp", "gb", "de", "ca", "au", "fr", "kr", "sg", "tr", "ng", "ar", "br", "in"]:
            raise ValueError(f"Unsupported country '{country}' for {title}")
        if not title:
            raise ValueError(f"Empty title for entry {idx}")

        apps.append({
            "appStoreURL": first_url,
            "countryCode": country,
            "name": title,
            "trackId": track_id
        })

    return apps, excluded

def build_preset(apps, title="Mac App Store 官方认证付费游戏大全", author="AppDrop"):
    now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "apps": apps,
        "author": author,
        "exportedAt": now_utc,
        "formatIdentifier": "com.appdrop.wishdrop",
        "title": title,
        "version": 1
    }

def main():
    print(f"Reading markdown source from {DOC_PATH}...")
    apps, excluded = parse_markdown(DOC_PATH)
    print(f"Excluded {len(excluded)} non-upfront/pending entries:")
    for tid, name in excluded:
        print(f"  - [{tid}] {name}")
    print(f"Retained {len(apps)} pure upfront-paid game entries.")

    preset_cn = build_preset(apps, title=f"Mac App Store 官方认证纯付费游戏大全 ({len(apps)}款)", author="AppDrop")
    preset_en = build_preset(apps, title=f"Mac App Store Paid Games Collection ({len(apps)} Games)", author="AppDrop")

    targets = [
        os.path.join(ROOT_DIR, "MacAppStore付费游戏.wishdrop"),
        os.path.join(ROOT_DIR, "MacAppStore-Paid-Games.wishdrop"),
        os.path.join(ROOT_DIR, "Documentation", "MacAppStore付费游戏.wishdrop")
    ]

    for target in targets:
        preset = preset_en if "Paid-Games" in target else preset_cn
        with open(target, "w", encoding="utf-8") as f:
            # Use sorted keys and 2-space indentation matching Swift JSONEncoder
            json.dump(preset, f, ensure_ascii=False, indent=2, sort_keys=True)
            f.write("\n")
        print(f"Generated: {target} ({os.path.getsize(target)} bytes)")

if __name__ == "__main__":
    main()
