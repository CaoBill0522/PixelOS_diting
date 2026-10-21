#!/usr/bin/env python3
"""Generate the Updater JSON (net.pixelos.ota) for a PixelOS diting build.

Usage:
  gen_ota_json.py <PixelOS_diting-*.zip> [--base-url URL] [--out DIR]

Writes <out>/deploy/<device>/index.json, the body the phone must get from
https://update.jcao.dev/<device> (HTTP 200, no redirect), and a
<out>/deploy/<device>/changelog.md stub if none exists yet.
"""
import argparse
import hashlib
import json
import os
import re
import sys
import zipfile

DEFAULT_BASE_URL = "https://update.jcao.dev/diting/builds"


def read_metadata(zip_path):
    with zipfile.ZipFile(zip_path) as z:
        text = z.read("META-INF/com/android/metadata").decode()
    meta = {}
    for line in text.splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            meta[k.strip()] = v.strip()
    return meta


def sha256sum(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("zip")
    ap.add_argument("--base-url", default=DEFAULT_BASE_URL,
                    help="https URL of the folder that hosts the zip")
    ap.add_argument("--out", default=os.path.dirname(os.path.abspath(__file__)))
    args = ap.parse_args()

    if not args.base_url.startswith("https://"):
        sys.exit("base URL must be https (the updater rejects anything else)")

    filename = os.path.basename(args.zip)
    m = re.match(r"PixelOS_(\w+)-([\d.]+)-(\d{8}-\d{4})\.zip$", filename)
    if not m:
        sys.exit(f"unexpected file name: {filename}")
    device, version, _ = m.groups()

    meta = read_metadata(args.zip)
    if meta.get("ota-type") != "AB":
        sys.exit("not an A/B OTA package")

    entry = {
        "datetime": int(meta["post-timestamp"]),
        "version": version,
        "files": [{
            "filename": filename,
            "os_patch_level": meta["post-security-patch-level"],
            "os_sdk_level": int(meta["post-sdk-level"]),
            "ota_property_files": meta["ota-property-files"],
            "sha256": sha256sum(args.zip),
            "size": os.path.getsize(args.zip),
            "url": f"{args.base_url.rstrip('/')}/{filename}",
        }],
    }

    out_dir = os.path.join(args.out, "deploy", device)
    os.makedirs(out_dir, exist_ok=True)
    body = json.dumps([entry], indent=2) + "\n"
    with open(os.path.join(out_dir, "index.json"), "w") as f:
        f.write(body)
    changelog = os.path.join(out_dir, "changelog.md")
    if not os.path.exists(changelog):
        with open(changelog, "w") as f:
            f.write(f"## {filename}\n\n- \n")
    print(body)


if __name__ == "__main__":
    main()
